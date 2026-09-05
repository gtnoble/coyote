--  LLM.Tools.Sandbox body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_Utils;
with GNAT.OS_Lib;

package body LLM.Tools.Sandbox is

   use type Ada.Directories.File_Kind;
   use type GNATCOLL.JSON.JSON_Value_Type;

   function Home_Dir return String is
   begin
      if Ada.Environment_Variables.Exists ("HOME") then
         return Ada.Environment_Variables.Value ("HOME");
      end if;
      return "";
   end Home_Dir;

   function Profiles_Dir return String is
      Home : constant String := Home_Dir;
   begin
      if Home'Length = 0 then
         return "";
      end if;
      return Home & "/.coyote/sandbox";
   end Profiles_Dir;

   function Is_Alpha_Numeric (Value : Character) return Boolean is
   begin
      return (Value in 'A' .. 'Z')
        or else (Value in 'a' .. 'z')
        or else (Value in '0' .. '9');
   end Is_Alpha_Numeric;

   function Is_Valid_Profile_Name (Name : String) return Boolean is
      Has_Alpha_Numeric : Boolean := False;
   begin
      if Name'Length = 0
        or else Name = "."
        or else Name = ".."
        or else (Name'Length >= 5
                 and then Name (Name'Last - 4 .. Name'Last) = ".json")
        or else Ada.Characters.Handling.Is_Space (Name (Name'First))
        or else Ada.Characters.Handling.Is_Space (Name (Name'Last))
      then
         return False;
      end if;
      for Value of Name loop
         if Character'Pos (Value) < 32
           or else Character'Pos (Value) = 127
           or else Value = '/'
           or else Value = '\'
         then
            return False;
         elsif not Is_Alpha_Numeric (Value)
           and then Value /= '_'
           and then Value /= '-'
           and then Value /= '.'
         then
            return False;
         end if;

         Has_Alpha_Numeric := Has_Alpha_Numeric
           or else Is_Alpha_Numeric (Value);
      end loop;

      return Has_Alpha_Numeric;
   end Is_Valid_Profile_Name;

   function Profile_Path (Name : String) return String is
      Dir : constant String := Profiles_Dir;
   begin
      if not Is_Valid_Profile_Name (Name) then
         raise Sandbox_Error with "invalid sandbox profile name";
      elsif Dir'Length = 0 then
         raise Sandbox_Error with "HOME is not set";
      end if;

      return Dir & "/" & Name & ".json";
   end Profile_Path;

   procedure Resolve_Path
     (Path : in out Ada.Strings.Unbounded.Unbounded_String;
      Cwd  :        String)
   is
      S : constant String :=
        Ada.Strings.Unbounded.To_String (Path);
   begin
      if S = "." then
         Path := Ada.Strings.Unbounded.To_Unbounded_String (Cwd);
      elsif S'Length >= 2
        and then S (S'First .. S'First + 1) = "./"
      then
         Path := Ada.Strings.Unbounded.To_Unbounded_String
           (Cwd & "/" & S (S'First + 2 .. S'Last));
      elsif S'Length >= 2
        and then S (S'First .. S'First + 1) = "~/"
      then
         declare
            Home : constant String := Home_Dir;
         begin
            if Home'Length > 0 then
               Path := Ada.Strings.Unbounded.To_Unbounded_String
                 (Home & "/" & S (S'First + 2 .. S'Last));
            end if;
         end;
      end if;
   end Resolve_Path;

   procedure Append_JSON_Array
     (Target : in out GNATCOLL.JSON.JSON_Array;
      Values :        String_Vectors.Vector)
   is
   begin
      for Value of Values loop
         GNATCOLL.JSON.Append (Target, GNATCOLL.JSON.Create (Value));
      end loop;
   end Append_JSON_Array;

   function Profile_JSON (Value : Profile) return GNATCOLL.JSON.JSON_Value is
      Root        : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Allow_Write : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Deny_Write  : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Deny_Read   : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Allow_Read  : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Append_JSON_Array (Allow_Write, Value.Allow_Write);
      Append_JSON_Array (Deny_Write, Value.Deny_Write);
      Append_JSON_Array (Deny_Read, Value.Deny_Read);
      Append_JSON_Array (Allow_Read, Value.Allow_Read);
      Root.Set_Field ("allowWrite", Allow_Write);
      Root.Set_Field ("denyWrite", Deny_Write);
      Root.Set_Field ("denyRead", Deny_Read);
      Root.Set_Field ("allowRead", Allow_Read);
      return Root;
   end Profile_JSON;

   function Parse_Array
     (Root  : GNATCOLL.JSON.JSON_Value;
      Name  : String) return String_Vectors.Vector
   is
      Result : String_Vectors.Vector;
   begin
      if not Root.Has_Field (Name) then
         return Result;
      elsif Root.Get (Name).Kind /= GNATCOLL.JSON.JSON_Array_Type then
         raise Sandbox_Error with "profile field is not an array: " & Name;
      end if;

      declare
         Items : constant GNATCOLL.JSON.JSON_Array := Root.Get (Name).Get;
      begin
         for I in 1 .. GNATCOLL.JSON.Length (Items) loop
            declare
               Item : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Get (Items, I);
            begin
               if Item.Kind /= GNATCOLL.JSON.JSON_String_Type then
                  raise Sandbox_Error with
                    "profile field contains a non-string: " & Name;
               end if;
               Result.Append (Item.Get);
            end;
         end loop;
      end;

      return Result;
   end Parse_Array;

   function Parse_Profile
     (Root : GNATCOLL.JSON.JSON_Value) return Profile
   is
      Result : Profile;
   begin
      if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         raise Sandbox_Error with "profile JSON must be an object";
      end if;

      Result.Allow_Write := Parse_Array (Root, "allowWrite");
      Result.Deny_Write  := Parse_Array (Root, "denyWrite");
      Result.Deny_Read   := Parse_Array (Root, "denyRead");
      Result.Allow_Read  := Parse_Array (Root, "allowRead");
      return Result;
   end Parse_Profile;

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
      Tmp_Path  : constant String := Path & ".tmp";
      Renamed   : Boolean := False;
      Dir_Path  : constant String :=
        Ada.Directories.Containing_Directory (Path);
   begin
      Ada.Directories.Create_Path (Dir_Path);
      Delete_If_Exists (Tmp_Path);

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Tmp_Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);

      GNAT.OS_Lib.Rename_File (Tmp_Path, Path, Renamed);
      if not Renamed then
         Delete_If_Exists (Tmp_Path);
         raise Sandbox_Error with "failed to replace sandbox profile";
      end if;
   exception
      when Sandbox_Error =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Delete_If_Exists (Tmp_Path);
         raise;
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Delete_If_Exists (Tmp_Path);
         raise Sandbox_Error with "unable to save sandbox profile";
   end Write_Atomically;

   procedure Save_Profile (Name : String; Value : Profile) is
      Path : constant String := Profile_Path (Name);
   begin
      Write_Atomically (Path, GNATCOLL.JSON.Write (Profile_JSON (Value)));
   exception
      when Sandbox_Error =>
         raise;
      when others =>
         raise Sandbox_Error with "unable to save sandbox profile";
   end Save_Profile;

   procedure Edit_Profile (Name : String; Value : Profile) is
   begin
      Save_Profile (Name, Value);
   end Edit_Profile;

   procedure Create_Profile (Name : String; Value : Profile) is
      Path : constant String := Profile_Path (Name);
   begin
      if Ada.Directories.Exists (Path) then
         raise Sandbox_Error with "sandbox profile already exists";
      end if;

      Write_Atomically (Path, GNATCOLL.JSON.Write (Profile_JSON (Value)));
   exception
      when Sandbox_Error =>
         raise;
      when others =>
         raise Sandbox_Error with "unable to create sandbox profile";
   end Create_Profile;

   function Load_Profile_Typed (Name : String) return Profile is
      Path : constant String := Profile_Path (Name);
   begin
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         raise Sandbox_Error with "sandbox profile does not exist";
      end if;

      declare
         Raw    : constant String := Coyote_Utils.Read_Whole_File (Path);
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Raw);
      begin
         if not Parsed.Success then
            raise Sandbox_Error with "malformed sandbox profile";
         end if;
         return Parse_Profile (Parsed.Value);
      end;
   exception
      when Sandbox_Error =>
         raise;
      when others =>
         raise Sandbox_Error with "unable to load sandbox profile";
   end Load_Profile_Typed;

   procedure Copy_Profile (Source_Name : String; Target_Name : String) is
      Source : constant Profile := Load_Profile_Typed (Source_Name);
      Target : constant String := Profile_Path (Target_Name);
   begin
      if Ada.Directories.Exists (Target) then
         raise Sandbox_Error with "sandbox profile already exists";
      end if;

      Write_Atomically (Target, GNATCOLL.JSON.Write (Profile_JSON (Source)));
   exception
      when Sandbox_Error =>
         raise;
      when others =>
         raise Sandbox_Error with "unable to copy sandbox profile";
   end Copy_Profile;

   procedure Rename_Profile (Old_Name : String; New_Name : String) is
      Old_Profile : constant Profile := Load_Profile_Typed (Old_Name);
      New_Path    : constant String := Profile_Path (New_Name);
   begin
      if Old_Name = New_Name then
         raise Sandbox_Error with "sandbox profile already exists";
      elsif Ada.Directories.Exists (New_Path) then
         raise Sandbox_Error with "sandbox profile already exists";
      end if;

      Write_Atomically
        (New_Path, GNATCOLL.JSON.Write (Profile_JSON (Old_Profile)));
   exception
      when Sandbox_Error =>
         raise;
      when others =>
         raise Sandbox_Error with "unable to rename sandbox profile";
   end Rename_Profile;

   function Available_Profiles return String_Vectors.Vector is
      Dir     : constant String := Profiles_Dir;
      Search  : Ada.Directories.Search_Type;
      Ent     : Ada.Directories.Directory_Entry_Type;
      Result  : String_Vectors.Vector;
      Filter  : constant Ada.Directories.Filter_Type :=
        (Ada.Directories.Ordinary_File => True,
         others                        => False);
   begin
      if Dir'Length = 0
        or else not Ada.Directories.Exists (Dir)
      then
         return Result;
      end if;

      Ada.Directories.Start_Search
        (Search, Dir, "*.json", Filter => Filter);

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Ent);
         declare
            File_Name : constant String := Ada.Directories.Simple_Name (Ent);
            Name      : constant String :=
              (if File_Name'Length > 5
               then File_Name (File_Name'First .. File_Name'Last - 5)
               else "");
         begin
            if Name'Length > 0 and then Is_Valid_Profile_Name (Name) then
               Result.Append (Name);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);

      if Natural (Result.Length) > 1 then
         for I in 1 .. Natural (Result.Length) - 1 loop
            for J in I + 1 .. Natural (Result.Length) loop
               if Result.Element (J) < Result.Element (I) then
                  declare
                     Temp : constant String := Result.Element (I);
                  begin
                     Result.Replace_Element (I, Result.Element (J));
                     Result.Replace_Element (J, Temp);
                  end;
               end if;
            end loop;
         end loop;
      end if;

      return Result;
   end Available_Profiles;

   function Load_Profile
     (Name : String) return GNATCOLL.JSON.JSON_Value
   is
   begin
      if not Is_Valid_Profile_Name (Name) then
         return GNATCOLL.JSON.JSON_Null;
      end if;

      declare
         Path : constant String := Profile_Path (Name);
      begin
         if not Ada.Directories.Exists (Path)
           or else Ada.Directories.Kind (Path) /=
             Ada.Directories.Ordinary_File
         then
            return GNATCOLL.JSON.JSON_Null;
         end if;

         declare
            Raw         : constant String := Coyote_Utils.Read_Whole_File (Path);
            Read_Result : constant GNATCOLL.JSON.Read_Result :=
              GNATCOLL.JSON.Read (Raw);
         begin
            if not Read_Result.Success then
               return GNATCOLL.JSON.JSON_Null;
            end if;
            return Read_Result.Value;
         end;
      end;
   exception
      when others =>
         return GNATCOLL.JSON.JSON_Null;
   end Load_Profile;

   function Build_Bwrap_Args
     (Profile_Name : String;
      Cwd          : String) return String_Vectors.Vector
   is
      type Rule_Entry is record
         Rtype : Ada.Strings.Unbounded.Unbounded_String;
         Path  : Ada.Strings.Unbounded.Unbounded_String;
         Depth : Natural := 0;
      end record;

      type Rule_Entry_Array is array (Positive range <>) of Rule_Entry;

      Value : Profile;
      Args  : String_Vectors.Vector;
      Num   : Natural;
   begin
      if Profile_Name'Length = 0 then
         return Args;
      end if;

      Value := Load_Profile_Typed (Profile_Name);
      Num := Natural (Value.Allow_Write.Length)
        + Natural (Value.Deny_Write.Length)
        + Natural (Value.Deny_Read.Length)
        + Natural (Value.Allow_Read.Length);

      declare
         Entries : Rule_Entry_Array (1 .. Positive'Max (1, Num));
         Idx     : Natural := 0;

         function Path_Depth (Path : String) return Natural is
            Count : Natural := 0;
         begin
            for Value of Path loop
               if Value = '/' then
                  Count := Count + 1;
               end if;
            end loop;
            return Count;
         end Path_Depth;

         procedure Add_Rules
           (Rtype  : String;
            Paths  : String_Vectors.Vector)
         is
         begin
            for Raw of Paths loop
               declare
                  Path : Ada.Strings.Unbounded.Unbounded_String :=
                    Ada.Strings.Unbounded.To_Unbounded_String (Raw);
               begin
                  Resolve_Path (Path, Cwd);
                  if Ada.Directories.Exists
                    (Ada.Strings.Unbounded.To_String (Path))
                  then
                     Idx := Idx + 1;
                     Entries (Idx) :=
                       (Rtype => Ada.Strings.Unbounded
                          .To_Unbounded_String (Rtype),
                        Path  => Path,
                        Depth => Path_Depth
                          (Ada.Strings.Unbounded.To_String (Path)));
                  end if;
               end;
            end loop;
         end Add_Rules;
      begin
         Add_Rules ("allowWrite", Value.Allow_Write);
         Add_Rules ("denyWrite", Value.Deny_Write);
         Add_Rules ("denyRead", Value.Deny_Read);
         Add_Rules ("allowRead", Value.Allow_Read);

         if Idx > 1 then
            declare
               Sorted : Boolean := False;
            begin
               while not Sorted loop
                  Sorted := True;
                  for J in 1 .. Idx - 1 loop
                     if Entries (J).Depth > Entries (J + 1).Depth then
                        declare
                           Temp : constant Rule_Entry := Entries (J);
                        begin
                           Entries (J) := Entries (J + 1);
                           Entries (J + 1) := Temp;
                           Sorted := False;
                        end;
                     end if;
                  end loop;
               end loop;
            end;
         end if;

         if Idx > 0 then
            for J in 1 .. Idx loop
               declare
                  Rtype    : constant String :=
                    Ada.Strings.Unbounded.To_String (Entries (J).Rtype);
                  Resolved : constant String :=
                    Ada.Strings.Unbounded.To_String (Entries (J).Path);
               begin
                  if Rtype = "allowWrite" then
                     Args.Append ("--bind");
                     Args.Append (Resolved);
                     Args.Append (Resolved);
                  elsif Rtype = "denyWrite" or else Rtype = "allowRead" then
                     Args.Append ("--ro-bind");
                     Args.Append (Resolved);
                     Args.Append (Resolved);
                  elsif Rtype = "denyRead" then
                     Args.Append ("--tmpfs");
                     Args.Append (Resolved);
                  end if;
               end;
            end loop;
         end if;
      end;

      return Args;
   end Build_Bwrap_Args;

end LLM.Tools.Sandbox;
