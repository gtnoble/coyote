--  Coyote_Utils body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Streams.Stream_IO;
with GNAT.OS_Lib;

package body Coyote_Utils is

   --  Read the entire file at Path using Stream_IO chunk-based reading.
   --  Unlike Text_IO.Get_Line, this handles files with very long lines
   --  (including single-line JSON) without stack overflow.
   function Read_Whole_File (Path : String) return String is
      File    : Ada.Streams.Stream_IO.File_Type;
      Content : Unbounded_String;
      Buffer  : Ada.Streams.Stream_Element_Array (1 .. 8_192);
      pragma Suppress_Initialization (Buffer);
      Last : Ada.Streams.Stream_Element_Offset;
      use type Ada.Streams.Stream_Element_Offset;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);

      loop
         Ada.Streams.Stream_IO.Read (File, Buffer, Last);
         exit when Last = 0;
         for I in 1 .. Last loop
            Append (Content, Character'Val (Buffer (I)));
         end loop;
      end loop;

      Ada.Streams.Stream_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         return "";
   end Read_Whole_File;

   function Read_File_If_Exists (Path : String) return String is
   begin
      return Read_Whole_File (Path);
   end Read_File_If_Exists;

   function Resolve_Active_Executable_Path return String is
   begin
      if Ada.Directories.Exists ("/proc/self/exe") then
         declare
            Resolved : constant String :=
              GNAT.OS_Lib.Normalize_Pathname
                ("/proc/self/exe", Resolve_Links => True);
         begin
            if Resolved'Length > 0
              and then GNAT.OS_Lib.Is_Absolute_Path (Resolved)
            then
               return Resolved;
            end if;
         end;
      end if;

      declare
         Command : constant String := Ada.Command_Line.Command_Name;
         Resolved : constant String :=
           GNAT.OS_Lib.Normalize_Pathname
             (Command, Resolve_Links => True);
      begin
         if Resolved'Length > 0
           and then GNAT.OS_Lib.Is_Absolute_Path (Resolved)
         then
            return Resolved;
         end if;

         return Ada.Directories.Full_Name (Command);
      end;
   exception
      when others =>
         begin
            return Ada.Directories.Full_Name
              (Ada.Command_Line.Command_Name);
         exception
            when others =>
               return Ada.Command_Line.Command_Name;
         end;
   end Resolve_Active_Executable_Path;

   --  Package elaboration captures the image before a later atomic rebuild
   --  can detach /proc/self/exe from its original pathname.
   Cached_Executable_Path : constant String :=
     Resolve_Active_Executable_Path;

   function Active_Executable_Path return String is
   begin
      return Cached_Executable_Path;
   end Active_Executable_Path;

   function Available_Executable_Path return String is
      use type Ada.Directories.File_Kind;
   begin
      if not GNAT.OS_Lib.Is_Absolute_Path (Cached_Executable_Path)
        or else not GNAT.OS_Lib.Is_Executable_File (Cached_Executable_Path)
      then
         return "";
      end if;

      if Ada.Directories.Kind (Cached_Executable_Path)
        /= Ada.Directories.Ordinary_File
      then
         return "";
      end if;

      return Cached_Executable_Path;
   exception
      when others =>
         return "";
   end Available_Executable_Path;

   function Shell_Quote (Value : String) return String is
      Result : Unbounded_String;
   begin
      Append (Result, "'");
      for Character_Value of Value loop
         if Character_Value = ''' then
            Append (Result, "'\''");
         else
            Append (Result, Character_Value);
         end if;
      end loop;
      Append (Result, "'");
      return To_String (Result);
   end Shell_Quote;

   function Resolve_Text_Arg (Arg : String) return String is
   begin
      if Arg'Length = 0 then
         return "";
      end if;

      if Arg (Arg'First) /= '@' then
         return Arg;
      end if;

      declare
         Path : constant String := Arg (Arg'First + 1 .. Arg'Last);
      begin
         if Path'Length = 0 then
            raise Bad_Arg_Error with "missing file path after '@'";
         end if;

         if not Ada.Directories.Exists (Path) then
            raise Bad_Arg_Error with "file not found: " & Path;
         end if;

         declare
            Content : constant String := Read_File_If_Exists (Path);
         begin
            return Content;
         end;
      end;
   end Resolve_Text_Arg;

   function Strip_Session_Prefix (S : String) return String is
      Prefix : constant String := "coyote-session+";
   begin
      if S'Length > Prefix'Length
        and then S (S'First .. S'First + Prefix'Length - 1) = Prefix
      then
         return S (S'First + Prefix'Length .. S'Last);
      end if;
      return S;
   end Strip_Session_Prefix;

end Coyote_Utils;
