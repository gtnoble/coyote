--  LLM.Auth body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.IO_Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNATCOLL.JSON;

package body LLM.Auth is

   use type GNATCOLL.JSON.JSON_Value_Type;

   function Agent_Dir return String is
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "");
   begin
      if Home'Length = 0 then
         return "";
      end if;

      return Home & "/.pi/agent";
   end Agent_Dir;

   function Auth_Path return String is
      Base : constant String := Agent_Dir;
   begin
      if Base'Length = 0 then
         return "";
      end if;

      return Base & "/auth.json";
   end Auth_Path;

   function Temp_Path (Path : String) return String is
   begin
      return Path & ".tmp";
   end Temp_Path;

   function Empty_Credentials return Provider_Credentials is
   begin
      return (others => <>);
   end Empty_Credentials;

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Append (Content, Line);
            Append (Content, ASCII.LF);
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return "";
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
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return String
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

   function Find_Provider_Value
     (Root     : GNATCOLL.JSON.JSON_Value;
      Provider : String) return GNATCOLL.JSON.JSON_Value
   is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Provider);
   begin
      if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return GNATCOLL.JSON.JSON_Null;
      end if;

      if Root.Has_Field (Provider)
        and then Root.Get (Provider).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Root.Get (Provider);
      end if;

      if Lower /= Provider
        and then Root.Has_Field (Lower)
        and then Root.Get (Lower).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Root.Get (Lower);
      end if;

      return GNATCOLL.JSON.JSON_Null;
   end Find_Provider_Value;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Path'Length > 0 and then Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   procedure Write_Atomically (Path : String; Content : String) is
      File      : Ada.Text_IO.File_Type;
      Tmp_Path  : constant String := Temp_Path (Path);
      Renamed   : Boolean         := False;
      Dir_Path  : constant String :=
        Ada.Directories.Containing_Directory (Path);
   begin
      if Path'Length = 0 then
         raise Ada.IO_Exceptions.Use_Error with
           "HOME is not set; cannot write auth.json";
      end if;

      Ada.Directories.Create_Path (Dir_Path);
      Delete_If_Exists (Tmp_Path);

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp_Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);

      GNAT.OS_Lib.Rename_File (Tmp_Path, Path, Renamed);

      if not Renamed then
         Delete_If_Exists (Tmp_Path);
         raise Ada.IO_Exceptions.Use_Error with
           "Failed to rename temporary auth file";
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Write_Atomically;

   function Load_Credentials (Provider : String) return Provider_Credentials is
      Root         : constant GNATCOLL.JSON.JSON_Value :=
        Load_Json_File (Auth_Path);
      Provider_Val : constant GNATCOLL.JSON.JSON_Value :=
        Find_Provider_Value (Root, Provider);
   begin
      if Provider_Val.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return Empty_Credentials;
      end if;

      return
        (Credential_Type =>
           To_Unbounded_String (Get_String_Field (Provider_Val, "type")),
         Refresh_Token   =>
           To_Unbounded_String (Get_String_Field (Provider_Val, "refresh")),
         Access_Token    =>
           To_Unbounded_String (Get_String_Field (Provider_Val, "access")),
         Expires_Ms      => Get_Long_Long_Field (Provider_Val, "expires"));
   end Load_Credentials;

   procedure Save_Credentials
     (Provider : String;
      Creds    : Provider_Credentials)
   is
      Path         : constant String := Auth_Path;
      Existing     : constant GNATCOLL.JSON.JSON_Value :=
        Load_Json_File (Path);
      Root         : constant GNATCOLL.JSON.JSON_Value :=
        (if Existing.Kind = GNATCOLL.JSON.JSON_Object_Type
         then Existing
         else GNATCOLL.JSON.Create_Object);
      Provider_Obj : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Provider_Obj.Set_Field ("type", To_String (Creds.Credential_Type));
      Provider_Obj.Set_Field ("refresh", To_String (Creds.Refresh_Token));
      Provider_Obj.Set_Field ("access", To_String (Creds.Access_Token));
      Provider_Obj.Set_Field
        ("expires", Long_Integer (Creds.Expires_Ms));

      Root.Set_Field (Provider, Provider_Obj);
      Write_Atomically (Path, GNATCOLL.JSON.Write (Root));
   end Save_Credentials;

end LLM.Auth;
