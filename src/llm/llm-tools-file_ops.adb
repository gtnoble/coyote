--  LLM.Tools.File_Ops body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Exceptions;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;

package body LLM.Tools.File_Ops is

   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNATCOLL.JSON.JSON_Value_Type;

   function Image_Of (Value : Integer) return String is
      Image : constant String := Ada.Strings.Fixed.Trim
        (Integer'Image (Value), Ada.Strings.Both);
   begin
      return Image;
   end Image_Of;

   procedure Set_Error
     (Message  :     String;
      Result   : out Unbounded_String;
      Is_Error : out Boolean) is
   begin
      Result   := To_Unbounded_String (Message);
      Is_Error := True;
   end Set_Error;

   function Load_Args
     (Args_Json : String;
      Result    : out GNATCOLL.JSON.JSON_Value;
      Error     : out Unbounded_String) return Boolean
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Json);
   begin
      if not Parsed.Success
        or else Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
      then
         Error  := To_Unbounded_String ("invalid JSON arguments");
         Result := GNATCOLL.JSON.JSON_Null;
         return False;
      end if;

      Result := Parsed.Value;
      Error  := Null_Unbounded_String;
      return True;
   end Load_Args;

   function Get_Required_String
     (Root  : GNATCOLL.JSON.JSON_Value;
      Field : String;
      Value : out Unbounded_String;
      Error : out Unbounded_String) return Boolean
   is
   begin
      if not Root.Has_Field (Field)
        or else Root.Get (Field).Kind /= GNATCOLL.JSON.JSON_String_Type
      then
         Error := To_Unbounded_String
           ("missing required string field '" & Field & "'");
         Value := Null_Unbounded_String;
         return False;
      end if;

      declare
         Field_Value : constant String := Root.Get (Field).Get;
      begin
         Value := To_Unbounded_String (Field_Value);
      end;
      Error := Null_Unbounded_String;
      return True;
   end Get_Required_String;

   function Get_Optional_Integer
     (Root      : GNATCOLL.JSON.JSON_Value;
      Field     : String;
      Value     : out Long_Integer;
      Was_Given : out Boolean;
      Error     : out Unbounded_String) return Boolean
   is
   begin
      if not Root.Has_Field (Field) then
         Value     := 0;
         Was_Given := False;
         Error     := Null_Unbounded_String;
         return True;
      end if;

      if Root.Get (Field).Kind /= GNATCOLL.JSON.JSON_Int_Type then
         Error := To_Unbounded_String
           ("field '" & Field & "' must be an integer");
         Value     := 0;
         Was_Given := False;
         return False;
      end if;

      declare
         Parsed_Value : constant Long_Integer := Root.Get (Field).Get;
      begin
         Value     := Parsed_Value;
         Was_Given := True;
         Error     := Null_Unbounded_String;
         return True;
      end;
   end Get_Optional_Integer;

   function Parent_Path (Path : String) return String is
   begin
      if Path'Length = 0 then
         return "";
      end if;

      Reverse_Loop :
      for I in reverse Path'Range loop
         if Path (I) = '/' then
            if I = Path'First then
               return Path (Path'First .. Path'First);
            end if;

            return Path (Path'First .. I - 1);
         end if;
      end loop Reverse_Loop;

      return "";
   end Parent_Path;

   procedure Ensure_Parent_Directory (Path : String) is
      Parent : constant String := Parent_Path (Path);
   begin
      if Parent'Length > 0 and then not Ada.Directories.Exists (Parent) then
         Ada.Directories.Create_Path (Parent);
      end if;
   end Ensure_Parent_Directory;

   function Read_File (Path : String) return String is
      File    : Ada.Streams.Stream_IO.File_Type;
      Buffer  : Unbounded_String;
      Chunk   : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last    : Ada.Streams.Stream_Element_Offset;
   begin
      Ada.Streams.Stream_IO.Open
        (File,
         Ada.Streams.Stream_IO.In_File,
         Path);

      while not Ada.Streams.Stream_IO.End_Of_File (File) loop
         Ada.Streams.Stream_IO.Read (File, Chunk, Last);

         if Last < Chunk'First then
            exit;
         end if;

         declare
            Count : constant Natural := Natural (Last - Chunk'First + 1);
            Text  : String (1 .. Count);
         begin
            for I in Text'Range loop
               Text (I) := Character'Val
                 (Chunk (Chunk'First
                  + Ada.Streams.Stream_Element_Offset (I)
                  - 1));
            end loop;

            Append (Buffer, Text);
         end;
      end loop;

      Ada.Streams.Stream_IO.Close (File);
      return To_String (Buffer);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Read_File;

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Ensure_Parent_Directory (Path);
      Ada.Streams.Stream_IO.Create
        (File,
         Ada.Streams.Stream_IO.Out_File,
         Path);
      String'Write (Ada.Streams.Stream_IO.Stream (File), Content);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Write_File;

   function Slice_Lines
     (Text   : String;
      Offset : Positive;
      Limit  : Natural) return String
   is
      Start_Index  : Natural := Text'First;
      Current_Line : Positive := 1;
      Remaining    : Natural := Limit;
   begin
      if Text'Length = 0 then
         return "";
      end if;

      if Limit = 0 then
         return "";
      end if;

      if Offset > 1 then
         for I in Text'Range loop
            exit when Current_Line = Offset;

            if Text (I) = ASCII.LF then
               Current_Line := Current_Line + 1;
               Start_Index  := I + 1;
            end if;
         end loop;

         if Current_Line /= Offset or else Start_Index > Text'Last then
            return "";
         end if;
      end if;

      if Limit = Natural'Last then
         return Text (Start_Index .. Text'Last);
      end if;

      for I in Start_Index .. Text'Last loop
         if Text (I) = ASCII.LF then
            Remaining := Remaining - 1;
            if Remaining = 0 then
               return Text (Start_Index .. I);
            end if;
         end if;
      end loop;

      return Text (Start_Index .. Text'Last);
   end Slice_Lines;

   function Matches_Glob (Name : String; Pattern : String) return Boolean is
      function Match_From (Name_Pos : Natural; Pattern_Pos : Natural)
         return Boolean
      is
         Name_Available : constant Boolean := Name_Pos <= Name'Length;
         Pat_Available  : constant Boolean := Pattern_Pos <= Pattern'Length;
         Pat_Char       : Character;
      begin
         if not Pat_Available then
            return not Name_Available;
         end if;

         Pat_Char := Pattern (Pattern'First + Pattern_Pos - 1);

         if Pat_Char = '*' then
            return Match_From (Name_Pos, Pattern_Pos + 1)
              or else (Name_Available
                       and then Match_From (Name_Pos + 1, Pattern_Pos));
         end if;

         if not Name_Available then
            return False;
         end if;

         if Pat_Char = '?'
           or else Pat_Char = Name (Name'First + Name_Pos - 1)
         then
            return Match_From (Name_Pos + 1, Pattern_Pos + 1);
         end if;

         return False;
      end Match_From;
   begin
      if Pattern'Length = 0 then
         return True;
      end if;

      return Match_From (1, 1);
   end Matches_Glob;

   procedure Append_Path
     (Paths : in out Unbounded_String;
      Path  : String) is
   begin
      if Length (Paths) > 0 then
         Append (Paths, ASCII.LF);
      end if;

      Append (Paths, Path);
   end Append_Path;

   procedure Find_Matches
     (Path    : String;
      Pattern : String;
      Result  : in out Unbounded_String)
   is
      Search  : Ada.Directories.Search_Type;
      Started : Boolean := False;
   begin
      if Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then
         if Matches_Glob (Ada.Directories.Simple_Name (Path), Pattern) then
            Append_Path (Result, Ada.Directories.Full_Name (Path));
         end if;
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    => (others => True));
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         declare
            Dir_Entry : Ada.Directories.Directory_Entry_Type;
         begin
            Ada.Directories.Get_Next_Entry (Search, Dir_Entry);

            declare
               Name : constant String :=
                 Ada.Directories.Simple_Name (Dir_Entry);
               Full : constant String :=
                 Ada.Directories.Full_Name (Dir_Entry);
               Kind : constant Ada.Directories.File_Kind :=
                 Ada.Directories.Kind (Dir_Entry);
            begin
               if Kind = Ada.Directories.Directory then
                  if Name /= "." and then Name /= ".." then
                     Find_Matches (Full, Pattern, Result);
                  end if;
               elsif Matches_Glob (Name, Pattern) then
                  Append_Path (Result, Full);
               end if;
            end;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Find_Matches;

   --  Build a JSON property object with "type" and "description" fields.
   function Make_String_Prop
     (Description : String) return GNATCOLL.JSON.JSON_Value
   is
      Prop : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Prop.Set_Field ("type", "string");
      Prop.Set_Field ("description", Description);
      return Prop;
   end Make_String_Prop;

   function Make_Integer_Prop
     (Description : String) return GNATCOLL.JSON.JSON_Value
   is
      Prop : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Prop.Set_Field ("type", "integer");
      Prop.Set_Field ("description", Description);
      return Prop;
   end Make_Integer_Prop;

   --  Wrap a properties object and required array into a schema object.
   function Make_Object_Schema
     (Props    : GNATCOLL.JSON.JSON_Value;
      Required : GNATCOLL.JSON.JSON_Array) return GNATCOLL.JSON.JSON_Value
   is
      Schema : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
   begin
      Schema.Set_Field ("type", "object");
      Schema.Set_Field ("properties", Props);
      Schema.Set_Field ("required", GNATCOLL.JSON.Create (Required));
      return Schema;
   end Make_Object_Schema;

   function Read_Descriptor return Tool_Descriptor is
      Props    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Props.Set_Field
        ("path",   Make_String_Prop ("Path to the file to read"));
      Props.Set_Field
        ("offset",
         Make_Integer_Prop ("Optional 1-based starting line number"));
      Props.Set_Field
        ("limit",
         Make_Integer_Prop ("Optional maximum number of lines to return"));
      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("path"));
      return
        (Name        => To_Unbounded_String ("read"),
         Description => To_Unbounded_String
           ("Read a file, optionally restricted to a line range."),
         Schema_Json => Make_Object_Schema (Props, Required));
   end Read_Descriptor;

   function Write_Descriptor return Tool_Descriptor is
      Props    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Props.Set_Field
        ("path",    Make_String_Prop ("Path to the file to write"));
      Props.Set_Field
        ("content", Make_String_Prop ("Complete file content to write"));
      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("path"));
      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("content"));
      return
        (Name        => To_Unbounded_String ("write"),
         Description => To_Unbounded_String
           ("Write a file, creating parent directories when needed."),
         Schema_Json => Make_Object_Schema (Props, Required));
   end Write_Descriptor;

   function Edit_Descriptor return Tool_Descriptor is
      Props    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Props.Set_Field
        ("path",    Make_String_Prop ("Path to the file to edit"));
      Props.Set_Field
        ("oldText", Make_String_Prop ("Exact text to replace"));
      Props.Set_Field ("newText", Make_String_Prop ("Replacement text"));
      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("path"));
      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("oldText"));
      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("newText"));
      return
        (Name        => To_Unbounded_String ("edit"),
         Description => To_Unbounded_String
           ("Replace exactly one matching text fragment in a file."),
         Schema_Json => Make_Object_Schema (Props, Required));
   end Edit_Descriptor;

   function Find_Descriptor return Tool_Descriptor is
      Props    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Props.Set_Field
        ("path",    Make_String_Prop ("Directory or file path to search"));
      Props.Set_Field
        ("pattern", Make_String_Prop ("Optional file-name glob pattern"));
      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("path"));
      return
        (Name        => To_Unbounded_String ("find"),
         Description => To_Unbounded_String
           ("Recursively list files whose names match an optional pattern."),
         Schema_Json => Make_Object_Schema (Props, Required));
   end Find_Descriptor;

   function Glob_Descriptor return Tool_Descriptor is
      Props    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Props.Set_Field
        ("path",    Make_String_Prop ("Directory or file path to search"));
      Props.Set_Field
        ("pattern", Make_String_Prop ("Optional file-name glob pattern"));
      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("path"));
      return
        (Name        => To_Unbounded_String ("glob"),
         Description => To_Unbounded_String
           ("Alias for find: recursively list files matching a pattern."),
         Schema_Json => Make_Object_Schema (Props, Required));
   end Glob_Descriptor;

   procedure Execute_Read
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null)
   is
      pragma Unreferenced (Abort_Flg);

      Root         : GNATCOLL.JSON.JSON_Value;
      Error        : Unbounded_String;
      Path         : Unbounded_String;
      Offset_Value : Long_Integer;
      Limit_Value  : Long_Integer;
      Has_Offset   : Boolean;
      Has_Limit    : Boolean;
   begin
      Result   := Null_Unbounded_String;
      Is_Error := False;

      if not Load_Args (Args_Json, Root, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Required_String (Root, "path", Path, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Optional_Integer
        (Root,
         "offset",
         Offset_Value,
         Has_Offset,
         Error)
      then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Optional_Integer
        (Root,
         "limit",
         Limit_Value,
         Has_Limit,
         Error)
      then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      declare
         Path_Str : constant String := To_String (Path);
      begin
         if not Ada.Directories.Exists (Path_Str) then
            Set_Error ("file not found: " & Path_Str, Result, Is_Error);
            return;
         end if;

         if Ada.Directories.Kind (Path_Str)
           /= Ada.Directories.Ordinary_File
         then
            Set_Error ("path is not a file: " & Path_Str, Result, Is_Error);
            return;
         end if;
      end;

      if Has_Offset and then Offset_Value <= 0 then
         Set_Error ("offset must be a positive integer", Result, Is_Error);
         return;
      end if;

      if Has_Limit and then Limit_Value < 0 then
         Set_Error ("limit must be zero or greater", Result, Is_Error);
         return;
      end if;

      declare
         Content      : constant String := Read_File (To_String (Path));
         Start_Line   : constant Positive :=
           (if Has_Offset then Positive (Offset_Value) else 1);
         Max_Lines    : constant Natural :=
           (if Has_Limit then Natural (Limit_Value) else Natural'Last);
      begin
         Result := To_Unbounded_String
           (Slice_Lines (Content, Start_Line, Max_Lines));
      end;
   exception
      when Ex : others =>
         Set_Error
           ("read tool failed: " & Ada.Exceptions.Exception_Message (Ex),
            Result,
            Is_Error);
   end Execute_Read;

   procedure Execute_Write
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null)
   is
      pragma Unreferenced (Abort_Flg);

      Root    : GNATCOLL.JSON.JSON_Value;
      Error   : Unbounded_String;
      Path    : Unbounded_String;
      Content : Unbounded_String;
   begin
      Result   := Null_Unbounded_String;
      Is_Error := False;

      if not Load_Args (Args_Json, Root, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Required_String (Root, "path", Path, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Required_String (Root, "content", Content, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      Write_File (To_String (Path), To_String (Content));
      Result := To_Unbounded_String
        ("wrote "
         & Image_Of (Integer (Length (Content)))
         & " bytes to "
         & To_String (Path));
   exception
      when Ex : others =>
         Set_Error
           ("write tool failed: " & Ada.Exceptions.Exception_Message (Ex),
            Result,
            Is_Error);
   end Execute_Write;

   procedure Execute_Edit
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null)
   is
      pragma Unreferenced (Abort_Flg);

      Root      : GNATCOLL.JSON.JSON_Value;
      Error     : Unbounded_String;
      Path      : Unbounded_String;
      Old_Text  : Unbounded_String;
      New_Text  : Unbounded_String;
   begin
      Result   := Null_Unbounded_String;
      Is_Error := False;

      if not Load_Args (Args_Json, Root, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Required_String (Root, "path", Path, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Required_String (Root, "oldText", Old_Text, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Required_String (Root, "newText", New_Text, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if Length (Old_Text) = 0 then
         Set_Error ("oldText must not be empty", Result, Is_Error);
         return;
      end if;

      declare
         Path_Str      : constant String := To_String (Path);
         Source        : constant String := Read_File (Path_Str);
         Source_U      : constant Unbounded_String :=
           To_Unbounded_String (Source);
         First_Pos     : constant Natural :=
           Index (Source_U, To_String (Old_Text));
         Source_Length : constant Natural := Length (Source_U);
         Second_Pos    : Natural := 0;
      begin
         if First_Pos = 0 then
            Set_Error
              ("oldText was not found in " & Path_Str,
               Result,
               Is_Error);
            return;
         end if;

         if First_Pos < Source_Length then
            declare
               Tail : constant Unbounded_String := To_Unbounded_String
                 (Slice (Source_U, First_Pos + 1, Source_Length));
            begin
               Second_Pos := Index (Tail, To_String (Old_Text));
            end;
         end if;

         if Second_Pos /= 0 then
            Set_Error
              ("oldText appears more than once in " & Path_Str,
               Result,
               Is_Error);
            return;
         end if;

         declare
            Prefix : constant String :=
              (if First_Pos > 1 then Slice (Source_U, 1, First_Pos - 1)
               else "");
            Suffix_Start : constant Natural := First_Pos + Length (Old_Text);
            Suffix : constant String :=
              (if Suffix_Start <= Source_Length
               then Slice (Source_U, Suffix_Start, Source_Length)
               else "");
         begin
            Write_File (Path_Str, Prefix & To_String (New_Text) & Suffix);
         end;

         Result := To_Unbounded_String ("edited " & Path_Str);
      end;
   exception
      when Ex : others =>
         Set_Error
           ("edit tool failed: " & Ada.Exceptions.Exception_Message (Ex),
            Result,
            Is_Error);
   end Execute_Edit;

   procedure Execute_Find
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null)
   is
      pragma Unreferenced (Abort_Flg);

      Root    : GNATCOLL.JSON.JSON_Value;
      Error   : Unbounded_String;
      Path    : Unbounded_String;
      Pattern : Unbounded_String;
   begin
      Result   := Null_Unbounded_String;
      Is_Error := False;

      if not Load_Args (Args_Json, Root, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if not Get_Required_String (Root, "path", Path, Error) then
         Set_Error (To_String (Error), Result, Is_Error);
         return;
      end if;

      if Root.Has_Field ("pattern") then
         if Root.Get ("pattern").Kind /= GNATCOLL.JSON.JSON_String_Type then
            Set_Error ("field 'pattern' must be a string", Result, Is_Error);
            return;
         end if;

         declare
            Pattern_Value : constant String := Root.Get ("pattern").Get;
         begin
            Pattern := To_Unbounded_String (Pattern_Value);
         end;
      else
         Pattern := To_Unbounded_String ("*");
      end if;

      if not Ada.Directories.Exists (To_String (Path)) then
         Set_Error
           ("path not found: " & To_String (Path),
            Result,
            Is_Error);
         return;
      end if;

      Find_Matches (To_String (Path), To_String (Pattern), Result);
   exception
      when Ex : others =>
         Set_Error
           ("find tool failed: " & Ada.Exceptions.Exception_Message (Ex),
            Result,
            Is_Error);
   end Execute_Find;

   procedure Execute_Glob
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null) is
      pragma Unreferenced (Abort_Flg);
   begin
      Execute_Find (Args_Json, Result, Is_Error);
   end Execute_Glob;

end LLM.Tools.File_Ops;
