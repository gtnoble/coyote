with AUnit.Assertions;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Coyote_Utils;

package body Coyote_Utils_Tests is

   use AUnit.Assertions;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_If_Exists;

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   end Write_File;

   procedure Write_Multiline_File
     (Path : String; Line_1 : String; Line_2 : String)
   is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, Line_1);
      Ada.Text_IO.Put_Line (File, Line_2);
      Ada.Text_IO.Close (File);
   end Write_Multiline_File;

   procedure Test_Reads_File_When_Path_Exists (T : in out Test) is
      pragma Unreferenced (T);

      Path     : constant String := "/tmp/coyote_utils_test_a.txt";
      Expected : constant String := "you are helpful";
   begin
      Delete_If_Exists (Path);
      Write_File (Path, Expected);

      declare
         Read_Result : constant String :=
           Coyote_Utils.Read_File_If_Exists (Path);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Read_Result, Expected) > 0,
            "existing file contents should be returned");
      end;

      Delete_If_Exists (Path);
   exception
      when others =>
         Delete_If_Exists (Path);
         raise;
   end Test_Reads_File_When_Path_Exists;

   procedure Test_Returns_Arg_When_Not_A_File (T : in out Test) is
      pragma Unreferenced (T);

      Result : constant String :=
        Coyote_Utils.Read_File_If_Exists ("you are helpful");
   begin
      Assert
        (Result = "",
         "non-file path should return an empty string");
   end Test_Returns_Arg_When_Not_A_File;

   procedure Test_Returns_Empty_For_Empty_Path (T : in out Test) is
      pragma Unreferenced (T);

      Result : constant String := Coyote_Utils.Read_File_If_Exists ("");
   begin
      Assert
        (Result = "",
         "empty path should return an empty string");
   end Test_Returns_Empty_For_Empty_Path;

   procedure Test_Reads_Multiline_File (T : in out Test) is
      pragma Unreferenced (T);

      Path   : constant String := "/tmp/coyote_utils_test_b.txt";
      Line_1 : constant String := "first line";
      Line_2 : constant String := "second line";
   begin
      Delete_If_Exists (Path);
      Write_Multiline_File (Path, Line_1, Line_2);

      declare
         Result : constant String := Coyote_Utils.Read_File_If_Exists (Path);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, Line_1) > 0,
            "first line should appear in multiline result");
         Assert
           (Ada.Strings.Fixed.Index (Result, Line_2) > 0,
            "second line should appear in multiline result");
      end;

      Delete_If_Exists (Path);
   exception
      when others =>
         Delete_If_Exists (Path);
         raise;
   end Test_Reads_Multiline_File;

end Coyote_Utils_Tests;
