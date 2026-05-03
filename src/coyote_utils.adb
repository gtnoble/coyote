--  Coyote_Utils body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Coyote_Utils is

   function Read_File_If_Exists (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Result : Unbounded_String;
   begin
      if Path'Length = 0 then
         return "";
      end if;

      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Append (Result, Line);
            Append (Result, ASCII.LF);
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return To_String (Result);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return "";
   end Read_File_If_Exists;

end Coyote_Utils;
