with AUnit.Assertions;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Tools.Bash;
with LLM.Tools.File_Ops;

package body LLM_Tools_Tests is

   use AUnit.Assertions;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element_Offset;

   Test_Root : constant String := "/tmp/pi_acme_llm_tools_tests";

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   procedure Ensure_Test_Root is
   begin
      Ada.Directories.Create_Path (Test_Root);
   end Ensure_Test_Root;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
            Ada.Directories.Delete_Directory (Path);
         else
            Ada.Directories.Delete_File (Path);
         end if;
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   procedure Cleanup_Test_Root is
   begin
      Delete_If_Exists (Test_Root & "/write/nested/out.txt");
      Delete_If_Exists (Test_Root & "/write/nested");
      Delete_If_Exists (Test_Root & "/write");
      Delete_If_Exists (Test_Root & "/read.txt");
      Delete_If_Exists (Test_Root & "/edit_unique.txt");
      Delete_If_Exists (Test_Root & "/edit_non_unique.txt");
      Delete_If_Exists (Test_Root & "/edit_missing.txt");
      Delete_If_Exists (Test_Root);
   end Cleanup_Test_Root;

   procedure Write_Text (Path : String; Content : String) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Ensure_Test_Root;
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
   end Write_Text;

   function Read_Text (Path : String) return String is
      File   : Ada.Streams.Stream_IO.File_Type;
      Chunk  : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Result : Unbounded_String;
   begin
      Ada.Streams.Stream_IO.Open
        (File,
         Ada.Streams.Stream_IO.In_File,
         Path);

      while not Ada.Streams.Stream_IO.End_Of_File (File) loop
         Ada.Streams.Stream_IO.Read (File, Chunk, Last);

         exit when Last < Chunk'First;

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

            Append (Result, Text);
         end;
      end loop;

      Ada.Streams.Stream_IO.Close (File);
      return To_String (Result);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Read_Text;

   procedure Test_Bash_Success (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Bash.Execute
        (Args_Json => "{""command"":""echo hello""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "echo hello should succeed");
      Assert
        (Contains (To_String (Result), "hello"),
         "bash result should contain command output");
   end Test_Bash_Success;

   procedure Test_Bash_Failure (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Bash.Execute
        (Args_Json => "{""command"":""exit 1""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "exit 1 should report a tool error");
      Assert
        (Contains (To_String (Result), "status 1"),
         "non-zero exit should mention the failing status");
   end Test_Bash_Failure;

   procedure Test_Read (T : in out Test) is
      pragma Unreferenced (T);

      Path     : constant String := Test_Root & "/read.txt";
      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      Cleanup_Test_Root;
      Write_Text (Path, "read me");

      LLM.Tools.File_Ops.Execute_Read
        (Args_Json => "{""path"":""" & Path & """}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "read should succeed for an existing file");
      Assert (To_String (Result) = "read me", "read should return file text");

      Cleanup_Test_Root;
   exception
      when others =>
         Cleanup_Test_Root;
         raise;
   end Test_Read;

   procedure Test_Write (T : in out Test) is
      pragma Unreferenced (T);

      Path     : constant String := Test_Root & "/write/nested/out.txt";
      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      Cleanup_Test_Root;
      Ensure_Test_Root;

      LLM.Tools.File_Ops.Execute_Write
        (Args_Json =>
           "{""path"":""" & Path & """,""content"":""written""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "write should succeed");
      Assert
        (Ada.Directories.Exists (Path),
         "write should create the target file and parent directories");
      Assert (Read_Text (Path) = "written", "write should persist content");

      Cleanup_Test_Root;
   exception
      when others =>
         Cleanup_Test_Root;
         raise;
   end Test_Write;

   procedure Test_Edit_Unique (T : in out Test) is
      pragma Unreferenced (T);

      Path     : constant String := Test_Root & "/edit_unique.txt";
      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      Cleanup_Test_Root;
      Write_Text (Path, "before UNIQUE after");

      LLM.Tools.File_Ops.Execute_Edit
        (Args_Json =>
           "{""path"":""" & Path & """,""oldText"":""UNIQUE"""
           & ",""newText"":""changed""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "edit should succeed for a unique match");
      Assert
        (Read_Text (Path) = "before changed after",
         "edit should replace the unique match");

      Cleanup_Test_Root;
   exception
      when others =>
         Cleanup_Test_Root;
         raise;
   end Test_Edit_Unique;

   procedure Test_Edit_Non_Unique (T : in out Test) is
      pragma Unreferenced (T);

      Path     : constant String := Test_Root & "/edit_non_unique.txt";
      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      Cleanup_Test_Root;
      Write_Text (Path, "repeat target and target again");

      LLM.Tools.File_Ops.Execute_Edit
        (Args_Json =>
           "{""path"":""" & Path & """,""oldText"":""target"""
           & ",""newText"":""changed""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "edit should fail when oldText appears twice");
      Assert
        (Contains (To_String (Result), "more than once"),
         "edit should explain the non-unique match failure");

      Cleanup_Test_Root;
   exception
      when others =>
         Cleanup_Test_Root;
         raise;
   end Test_Edit_Non_Unique;

   procedure Test_Edit_Missing (T : in out Test) is
      pragma Unreferenced (T);

      Path     : constant String := Test_Root & "/edit_missing.txt";
      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      Cleanup_Test_Root;
      Write_Text (Path, "there is nothing to replace here");

      LLM.Tools.File_Ops.Execute_Edit
        (Args_Json =>
           "{""path"":""" & Path & """,""oldText"":""missing"""
           & ",""newText"":""changed""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "edit should fail when oldText is absent");
      Assert
        (Contains (To_String (Result), "not found"),
         "edit should explain the missing-match failure");

      Cleanup_Test_Root;
   exception
      when others =>
         Cleanup_Test_Root;
         raise;
   end Test_Edit_Missing;

   procedure Test_Find (T : in out Test) is
      pragma Unreferenced (T);

      Fixture_Root : constant String :=
        Ada.Directories.Current_Directory & "/fixtures/llm_tools";
      Result       : Unbounded_String;
      Is_Error     : Boolean;
   begin
      LLM.Tools.File_Ops.Execute_Find
        (Args_Json =>
           "{""path"":""" & Fixture_Root & """,""pattern"":""*.json""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "find should succeed on the fixture tree");
      Assert
        (Contains (To_String (Result), "alpha.json"),
         "find should include the top-level JSON fixture");
      Assert
        (Contains (To_String (Result), "beta.json"),
         "find should include the nested JSON fixture");
      Assert
        (not Contains (To_String (Result), "gamma.txt"),
         "find should exclude non-matching fixture files");
   end Test_Find;

end LLM_Tools_Tests;
