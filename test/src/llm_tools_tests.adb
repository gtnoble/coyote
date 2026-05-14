with AUnit.Assertions;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Tools;
with LLM.Tools.Shell;
with LLM.Tools.File_Ops;

package body LLM_Tools_Tests is

   use AUnit.Assertions;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element_Offset;

   Test_Root : constant String := "/tmp/coyote_llm_tools_tests";

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   procedure Ensure_Test_Root is
   begin
      Ada.Directories.Create_Path (Test_Root);
   end Ensure_Test_Root;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

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

   procedure Test_Shell_Success (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json => "{""command"":""echo hello""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "echo hello should succeed");
      Assert
        (Contains (To_String (Result), "hello"),
         "shell result should contain command output");
   end Test_Shell_Success;

   procedure Test_Shell_Failure (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json => "{""command"":""exit 1""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "exit 1 should report a tool error");
      Assert
        (Contains (To_String (Result), "status 1"),
         "non-zero exit should mention the failing status");
   end Test_Shell_Failure;

   procedure Test_Shell_Stdin_Piped (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      --  "cat" reads its stdin and writes it to stdout.  The output should
      --  exactly reproduce the text supplied via the "stdin" field.
      LLM.Tools.Shell.Execute
        (Args_Json =>
           "{""command"":""cat"",""stdin"":""hello from stdin\n""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "cat with stdin should succeed");
      Assert
        (Contains (To_String (Result), "hello from stdin"),
         "output should contain the text piped through stdin");
   end Test_Shell_Stdin_Piped;

   procedure Test_Shell_Stdin_Empty_Ignored (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      --  An empty "stdin" field should be treated as absent: the command
      --  reads from /dev/null so it receives EOF immediately and succeeds.
      LLM.Tools.Shell.Execute
        (Args_Json => "{""command"":""cat"",""stdin"":""""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "cat with empty stdin should succeed");
      Assert
        (To_String (Result) = "",
         "output should be empty when stdin field is an empty string");
   end Test_Shell_Stdin_Empty_Ignored;

   procedure Test_Shell_Stdin_Absent_Dev_Null (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      --  When no "stdin" field is present the command should still run
      --  normally, receiving EOF from /dev/null.
      LLM.Tools.Shell.Execute
        (Args_Json => "{""command"":""echo no-stdin""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "echo without stdin should succeed");
      Assert
        (Contains (To_String (Result), "no-stdin"),
         "output should contain the echo'd text");
   end Test_Shell_Stdin_Absent_Dev_Null;

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

   procedure Test_Built_In_Tools_Include_Spawn_Subagent
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Tools : constant LLM.Tools.Tool_Descriptor_Vectors.Vector :=
        LLM.Tools.Built_In_Tools;
      Found : Boolean := False;
   begin
      for Descriptor of Tools loop
         if To_String (Descriptor.Name) = "spawn_subagent" then
            Found := True;
            exit;
         end if;
      end loop;

      Assert (Found, "Built_In_Tools should include spawn_subagent");
   end Test_Built_In_Tools_Include_Spawn_Subagent;

   procedure Test_Spawn_Subagent_Success (T : in out Test) is
      pragma Unreferenced (T);

      Mock_Coyote_Bin : constant String := "bin/mock_coyote";
      Env_Name        : constant String := "COYOTE_BIN";
      Was_Set         : constant Boolean :=
        Ada.Environment_Variables.Exists (Env_Name);
      Saved_Value     : constant String :=
        Ada.Environment_Variables.Value (Env_Name, "");
      Result          : Unbounded_String;
      Is_Error        : Boolean;
   begin
      Ada.Environment_Variables.Set (Env_Name, Mock_Coyote_Bin);

      LLM.Tools.Execute
        (Name      => "spawn_subagent",
         Args_Json =>
           "{""prompt"":""Ping"""
           & ",""model"":""provider/model"""
           & ",""agent"":""worker.agent.md"""
           & ",""name"":""worker""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "spawn_subagent should succeed with JSON output");
      Assert
        (To_String (Result) = "Ping|provider/model|worker.agent.md|worker",
         "spawn_subagent should return the subagent output field");

      Restore_Env (Env_Name, Was_Set, Saved_Value);
      Cleanup_Test_Root;
   exception
      when others =>
         Restore_Env (Env_Name, Was_Set, Saved_Value);
         Cleanup_Test_Root;
         raise;
   end Test_Spawn_Subagent_Success;

   procedure Test_Spawn_Subagent_Requires_Prompt (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Execute
        (Name      => "spawn_subagent",
         Args_Json => "{}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "spawn_subagent should reject missing prompt");
      Assert
        (Contains (To_String (Result), "prompt"),
         "spawn_subagent should mention the missing prompt field");
   end Test_Spawn_Subagent_Requires_Prompt;

   --  ── Pause_Flag unit tests ─────────────────────────────────────────────

   procedure Test_Pause_Flag_Initial_State (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Assert (not Flag.Is_Armed,  "initial Is_Armed must be False");
      Assert (not Flag.Is_Paused, "initial Is_Paused must be False");
   end Test_Pause_Flag_Initial_State;

   procedure Test_Pause_Flag_Arm_Sets_Armed (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Assert (Flag.Is_Armed,      "Arm must set Is_Armed");
      Assert (not Flag.Is_Paused, "Arm must not set Is_Paused");
   end Test_Pause_Flag_Arm_Sets_Armed;

   procedure Test_Pause_Flag_Unarm_Cancels_Arm (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Flag.Unarm;
      Assert (not Flag.Is_Armed,  "Unarm must clear Is_Armed");
      Assert (not Flag.Is_Paused, "Unarm must not set Is_Paused");
   end Test_Pause_Flag_Unarm_Cancels_Arm;

   procedure Test_Pause_Flag_Fire_Transitions (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Flag.Fire;
      Assert (not Flag.Is_Armed,  "Fire must clear Armed");
      Assert (Flag.Is_Paused,     "Fire must set Paused when Armed was True");
   end Test_Pause_Flag_Fire_Transitions;

   procedure Test_Pause_Flag_Fire_No_Op_When_Not_Armed (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Fire;
      Assert (not Flag.Is_Armed,  "Fire without Arm must leave Is_Armed False");
      Assert (not Flag.Is_Paused, "Fire without Arm must leave Is_Paused False");
   end Test_Pause_Flag_Fire_No_Op_When_Not_Armed;

   procedure Test_Pause_Flag_Release_Clears_Paused (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Flag.Fire;
      Assert (Flag.Is_Paused, "precondition: Is_Paused must be True after Fire");
      Flag.Release;
      Assert (not Flag.Is_Paused, "Release must clear Is_Paused");
   end Test_Pause_Flag_Release_Clears_Paused;

   procedure Test_Pause_Flag_Release_Clears_Armed (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Assert (Flag.Is_Armed, "precondition: Is_Armed must be True after Arm");
      Flag.Release;
      Assert (not Flag.Is_Armed, "Release must also clear Is_Armed");
   end Test_Pause_Flag_Release_Clears_Armed;

end LLM_Tools_Tests;
