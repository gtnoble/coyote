--  LLM.Auth body.
--
--  A provider lock spans Codex refresh activity, while the store lock
--  serializes every read/merge/write transaction. Unique temporary files
--  prevent concurrent writers from replacing one another's staging data.

with Ada.Characters.Handling;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;
with LLM.Credential_Locks;
with LLM.Settings;
with Coyote_Utils;
with GNATCOLL.JSON;
with System;

package body LLM.Auth is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type Interfaces.C.int;
   use type Interfaces.C.long;

   O_WRONLY  : constant Interfaces.C.int := 1;
   O_CREAT   : constant Interfaces.C.int := 64;
   O_EXCL    : constant Interfaces.C.int := 128;
   O_CLOEXEC : constant Interfaces.C.int := 524_288;
   MODE_0600 : constant Interfaces.C.unsigned := 384;

   function C_Open
     (Path  : Interfaces.C.Strings.chars_ptr;
      Flags : Interfaces.C.int;
      Mode  : Interfaces.C.unsigned) return Interfaces.C.int;
   pragma Import (C, C_Open, "open");

   function C_Write
     (FD      : Interfaces.C.int;
      Buffer  : System.Address;
      Count   : Interfaces.C.size_t) return Interfaces.C.long;
   pragma Import (C, C_Write, "write");

   function C_Close (FD : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Close, "close");

   function C_Rename
     (Old_Path : Interfaces.C.Strings.chars_ptr;
      New_Path : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int;
   pragma Import (C, C_Rename, "rename");

   function C_Getpid return Interfaces.C.int;
   pragma Import (C, C_Getpid, "getpid");

   protected Sequence is
      procedure Next (Value : out Natural);
   private
      Count : Natural := 0;
   end Sequence;

   protected body Sequence is
      procedure Next (Value : out Natural) is
      begin
         Count := Count + 1;
         Value := Count;
      end Next;
   end Sequence;

   function Auth_Path return String is
      Base : constant String := LLM.Settings.Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;
      return Base & "/auth.json";
   end Auth_Path;

   function Canonical_Provider (Provider : String) return String is
   begin
      return Ada.Characters.Handling.To_Lower (Provider);
   end Canonical_Provider;

   function Empty_Credentials return Provider_Credentials is
   begin
      return (others => <>);
   end Empty_Credentials;

   function Read_File (Path : String) return String is
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;
      return Coyote_Utils.Read_Whole_File (Path);
   end Read_File;

   function Load_Json_File (Path : String) return GNATCOLL.JSON.JSON_Value is
      Content : constant String := Read_File (Path);
   begin
      if Content'Length = 0 then
         return GNATCOLL.JSON.JSON_Null;
      end if;
      declare
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Content);
      begin
         if Parsed.Success then
            return Parsed.Value;
         end if;
      end;
      return GNATCOLL.JSON.JSON_Null;
   end Load_Json_File;

   function Get_Object_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Value
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Value.Get (Field);
      end if;
      return GNATCOLL.JSON.JSON_Null;
   end Get_Object_Field;

   function Get_String_Field
     (Value : GNATCOLL.JSON.JSON_Value; Field : String) return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;
      return "";
   end Get_String_Field;

   function Get_Long_Long_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return Long_Long_Integer
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type
      then
         declare
            Raw : constant Long_Integer := Value.Get (Field).Get;
         begin
            return Long_Long_Integer (Raw);
         end;
      end if;
      return 0;
   end Get_Long_Long_Field;

   procedure Write_All
     (FD : Interfaces.C.int; Content : String)
   is
      Offset : Natural := 0;
   begin
      while Offset < Content'Length loop
         declare
            Amount : constant Interfaces.C.long :=
              C_Write
                (FD,
                 Content (Content'First + Offset)'Address,
                 Interfaces.C.size_t (Content'Length - Offset));
         begin
            if Amount <= 0 then
               raise Ada.IO_Exceptions.Use_Error
                 with "failed writing auth temporary file";
            end if;
            Offset := Offset + Natural (Amount);
         end;
      end loop;
   end Write_All;

   procedure Write_Atomically (Path : String; Content : String) is
      FD          : Interfaces.C.int := -1;
      Renamed     : Boolean := False;
      Created     : Boolean := False;
      Suffix      : Natural;
      Tmp_Path    : Unbounded_String;
      Dir_Path    : constant String :=
        Ada.Directories.Containing_Directory (Path);
      Open_Flags  : constant Interfaces.C.int :=
        O_WRONLY + O_CREAT + O_EXCL + O_CLOEXEC;
   begin
      if Path'Length = 0 then
         raise Ada.IO_Exceptions.Use_Error
           with "HOME is not set; cannot write auth.json";
      end if;
      Ada.Directories.Create_Path (Dir_Path);

      for Attempt in 1 .. 100 loop
         Sequence.Next (Suffix);
         Tmp_Path := To_Unbounded_String
           (Path & ".tmp." & Interfaces.C.int'Image (C_Getpid)
            & "." & Natural'Image (Suffix));
         declare
            Clean_Path : constant String :=
              Ada.Strings.Fixed.Trim (To_String (Tmp_Path), Ada.Strings.Both);
            Tmp_C      : Interfaces.C.Strings.chars_ptr :=
              Interfaces.C.Strings.New_String (Clean_Path);
         begin
            FD := C_Open (Tmp_C, Open_Flags, MODE_0600);
            Interfaces.C.Strings.Free (Tmp_C);
            if FD >= 0 then
               Created := True;
               Tmp_Path := To_Unbounded_String (Clean_Path);
               exit;
            end if;
         end;
      end loop;
      if FD < 0 then
         raise Ada.IO_Exceptions.Use_Error
           with "cannot create unique auth temporary file";
      end if;

      Write_All (FD, Content);
      if C_Close (FD) /= 0 then
         FD := -1;
         raise Ada.IO_Exceptions.Use_Error
           with "cannot close auth temporary file";
      end if;
      FD := -1;

      declare
         Old_C : Interfaces.C.Strings.chars_ptr :=
           Interfaces.C.Strings.New_String (To_String (Tmp_Path));
         New_C : Interfaces.C.Strings.chars_ptr :=
           Interfaces.C.Strings.New_String (Path);
      begin
         Renamed := C_Rename (Old_C, New_C) = 0;
         Interfaces.C.Strings.Free (Old_C);
         Interfaces.C.Strings.Free (New_C);
      exception
         when others =>
            Interfaces.C.Strings.Free (Old_C);
            Interfaces.C.Strings.Free (New_C);
            raise;
      end;
      if not Renamed then
         raise Ada.IO_Exceptions.Use_Error
           with "failed to atomically replace auth.json";
      end if;
   exception
      when others =>
         if FD >= 0 then
            declare
               Ignored : constant Interfaces.C.int := C_Close (FD);
            begin
               null;
            end;
         end if;
         if Created and then not Renamed and then Length (Tmp_Path) > 0
           and then Ada.Directories.Exists (To_String (Tmp_Path))
         then
            Ada.Directories.Delete_File (To_String (Tmp_Path));
         end if;
         raise;
   end Write_Atomically;

   function Load_Credentials (Provider : String) return Provider_Credentials is
      Root : constant GNATCOLL.JSON.JSON_Value := Load_Json_File (Auth_Path);
      Provider_Val : constant GNATCOLL.JSON.JSON_Value :=
        Get_Object_Field (Root, Canonical_Provider (Provider));
   begin
      if Provider_Val.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return Empty_Credentials;
      end if;
      return
        (Credential_Type => To_Unbounded_String
           (Get_String_Field (Provider_Val, "type")),
         Refresh_Token => To_Unbounded_String
           (Get_String_Field (Provider_Val, "refresh")),
         Access_Token => To_Unbounded_String
           (Get_String_Field (Provider_Val, "access")),
         Expires_Ms => Get_Long_Long_Field (Provider_Val, "expires"),
         Account_Id => To_Unbounded_String
           (Get_String_Field (Provider_Val, "accountId")));
   end Load_Credentials;

   procedure Save_Credentials
     (Provider : String; Creds : Provider_Credentials)
   is
   begin
      if Auth_Path'Length = 0 then
         raise Ada.IO_Exceptions.Use_Error
           with "HOME is not set; cannot write auth.json";
      end if;
      if Canonical_Provider (Provider) = "codex" then
         declare
            Provider_Guard : LLM.Credential_Locks.Lock;
         begin
            LLM.Credential_Locks.Acquire
              (Provider_Guard, LLM.Settings.Agent_Dir & "/codex-refresh.lock");
            Save_Credentials_Unlocked (Provider, Creds);
         end;
      else
         Save_Credentials_Unlocked (Provider, Creds);
      end if;
   end Save_Credentials;

   procedure Save_Credentials_Unlocked
     (Provider : String; Creds : Provider_Credentials)
   is
      Path : constant String := Auth_Path;
      Canonical : constant String := Canonical_Provider (Provider);
      Store_Guard : LLM.Credential_Locks.Lock;
      Root : GNATCOLL.JSON.JSON_Value;
      Provider_Obj : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      if Path'Length = 0 then
         raise Ada.IO_Exceptions.Use_Error
           with "HOME is not set; cannot write auth.json";
      end if;
      LLM.Credential_Locks.Acquire
        (Store_Guard, LLM.Settings.Agent_Dir & "/auth-store.lock");

      if Ada.Directories.Exists (Path) then
         declare
            Content : constant String := Read_File (Path);
            Parsed : constant GNATCOLL.JSON.Read_Result :=
              GNATCOLL.JSON.Read (Content);
         begin
            if not Parsed.Success
              or else Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
            then
               raise Ada.IO_Exceptions.Use_Error
                 with "existing auth.json is malformed; refusing overwrite";
            end if;
            Root := Parsed.Value;
         end;
      else
         Root := GNATCOLL.JSON.Create_Object;
      end if;

      Provider_Obj.Set_Field ("type", To_String (Creds.Credential_Type));
      Provider_Obj.Set_Field ("refresh", To_String (Creds.Refresh_Token));
      Provider_Obj.Set_Field ("access", To_String (Creds.Access_Token));
      Provider_Obj.Set_Field ("expires", Long_Integer (Creds.Expires_Ms));
      if Length (Creds.Account_Id) > 0 then
         Provider_Obj.Set_Field ("accountId", To_String (Creds.Account_Id));
      end if;
      Root.Set_Field (Canonical, Provider_Obj);
      Write_Atomically (Path, GNATCOLL.JSON.Write (Root));
   end Save_Credentials_Unlocked;

end LLM.Auth;
