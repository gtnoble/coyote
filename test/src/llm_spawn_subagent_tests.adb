with AUnit.Assertions;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with LLM.Tools;
with LLM.Tools.Spawn_Subagent;

package body LLM_Spawn_Subagent_Tests is

   use AUnit.Assertions;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   procedure Restore_Env
     (Name    : String;
      Was_Set : Boolean;
      Value   : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   --  ── Existing tests ───────────────────────────────────────────────────

   procedure Test_Bad_Json (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "spawn_subagent should reject malformed JSON");
      Assert
        (Contains (To_String (Result), "invalid JSON"),
         "spawn_subagent should report invalid JSON arguments");
   end Test_Bad_Json;

   procedure Test_Empty_Prompt (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "spawn_subagent should reject an empty prompt");
      Assert
        (Contains (To_String (Result), "prompt"),
         "spawn_subagent should mention the invalid prompt field");
   end Test_Empty_Prompt;

   procedure Test_Binary_Not_Found (T : in out Test) is
      pragma Unreferenced (T);

      Env_Name  : constant String := "COYOTE_BIN";
      Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists (Env_Name);
      Old_Value : constant String :=
        Ada.Environment_Variables.Value (Env_Name, "");
      Result    : Unbounded_String;
      Is_Error  : Boolean;
   begin
      Ada.Environment_Variables.Set (Env_Name, "/nonexistent/path/coyote");

      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""hello""}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert (Is_Error, "spawn_subagent should fail when coyote is missing");
      Assert
        (Length (Result) > 0,
         "spawn_subagent should return a non-empty error message");

      Restore_Env (Env_Name, Was_Set, Old_Value);
   exception
      when others =>
         Restore_Env (Env_Name, Was_Set, Old_Value);
         raise;
   end Test_Binary_Not_Found;

   procedure Test_Abort_Before_Spawn (T : in out Test) is
      pragma Unreferenced (T);

      Env_Name  : constant String := "COYOTE_BIN";
      Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists (Env_Name);
      Old_Value : constant String :=
        Ada.Environment_Variables.Value (Env_Name, "");
      Abort_Flg : aliased LLM.Tools.Abort_Flag;
      Result    : Unbounded_String;
      Is_Error  : Boolean;
   begin
      Abort_Flg.Set;
      Ada.Environment_Variables.Set (Env_Name, "/nonexistent/path/coyote");

      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""hello""}",
         Result    => Result,
         Is_Error  => Is_Error,
         Abort_Flg => Abort_Flg'Access);

      Assert
        (Is_Error,
         "spawn_subagent should return an error when already aborted");

      Restore_Env (Env_Name, Was_Set, Old_Value);
   exception
      when others =>
         Restore_Env (Env_Name, Was_Set, Old_Value);
         raise;
   end Test_Abort_Before_Spawn;

   --  ── New validation tests ─────────────────────────────────────────────

   procedure Test_Name_And_Names_Conflict (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json =>
           "{""prompt"":""hi"","
           & """name"":""alpha"","
           & """names"":[""alpha"",""beta""]}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert
        (Is_Error,
         "spawn_subagent should reject both 'name' and 'names'");
      Assert
        (Contains (To_String (Result), "name")
         and then Contains (To_String (Result), "names"),
         "error should mention both conflicting fields, got: "
         & To_String (Result));
   end Test_Name_And_Names_Conflict;

   procedure Test_Names_Empty_Array (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""hi"",""names"":[]}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert
        (Is_Error,
         "spawn_subagent should reject an empty 'names' array");
      Assert
        (Contains (To_String (Result), "names"),
         "error should mention the 'names' field, got: "
         & To_String (Result));
   end Test_Names_Empty_Array;

   procedure Test_Names_Non_String_Element (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""hi"",""names"":[42]}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert
        (Is_Error,
         "spawn_subagent should reject non-string elements in 'names'");
      Assert
        (Contains (To_String (Result), "names"),
         "error should mention the 'names' field, got: "
         & To_String (Result));
   end Test_Names_Non_String_Element;

   procedure Test_Names_Empty_String_Element (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json => "{""prompt"":""hi"",""names"":[""valid"",""""]}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert
        (Is_Error,
         "spawn_subagent should reject empty strings in 'names'");
      Assert
        (Contains (To_String (Result), "names"),
         "error should mention the 'names' field, got: "
         & To_String (Result));
   end Test_Names_Empty_String_Element;

   procedure Test_Prompt_Filter_Wrong_Type (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json =>
           "{""prompt"":""hi"",""prompt_filter"":123}",
         Result    => Result,
         Is_Error  => Is_Error);

      Assert
        (Is_Error,
         "spawn_subagent should reject non-string 'prompt_filter'");
      Assert
        (Contains (To_String (Result), "prompt_filter"),
         "error should mention 'prompt_filter', got: "
         & To_String (Result));
   end Test_Prompt_Filter_Wrong_Type;

   --  ── Functional tests ─────────────────────────────────────────────────

   procedure Test_Prompt_Filter_Sets_Subagent_Name (T : in out Test) is
      pragma Unreferenced (T);

      Env_Name   : constant String := "COYOTE_BIN";
      Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists (Env_Name);
      Old_Value  : constant String :=
        Ada.Environment_Variables.Value (Env_Name, "");

      --  Unique temp file for this test invocation.
      Tmp_File   : constant String :=
        "/tmp/coyote_spawn_subagent_filter_test";
      Agent_Name : constant String := "my-test-agent";

      --  Filter writes COYOTE_SUBAGENT_NAME to a temp file so the
      --  test can verify the environment variable was set correctly.
      --  No quoting of the variable: the test name has no spaces.
      Filter_Cmd : constant String :=
        "echo $COYOTE_SUBAGENT_NAME > " & Tmp_File;

      Result   : Unbounded_String;
      Is_Error : Boolean;
   begin
      --  Clean up any leftover file from a previous run.
      if Ada.Directories.Exists (Tmp_File) then
         Ada.Directories.Delete_File (Tmp_File);
      end if;

      --  Use an invalid coyote binary so the spawn phase fails.
      --  The filter runs during job-building, before the spawn, so
      --  the temp file will be written even though Execute returns
      --  an error.
      Ada.Environment_Variables.Set (Env_Name, "/nonexistent/coyote");

      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json =>
           "{""prompt"":""hello"","
           & """names"":[""" & Agent_Name & """],"
           & """prompt_filter"":""" & Filter_Cmd & """}",
         Result    => Result,
         Is_Error  => Is_Error);

      --  Spawn fails, so Is_Error should be set.
      Assert
        (Is_Error,
         "Execute should fail when coyote binary is missing");

      --  The filter must have written the agent name to the temp file.
      Assert
        (Ada.Directories.Exists (Tmp_File),
         "prompt_filter must write the temp file before spawn");

      declare
         File : Ada.Text_IO.File_Type;
         Content : Unbounded_String;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Tmp_File);
         while not Ada.Text_IO.End_Of_File (File) loop
            Append (Content, Ada.Text_IO.Get_Line (File));
         end loop;
         Ada.Text_IO.Close (File);
         Assert
           (Contains (To_String (Content), Agent_Name),
            "COYOTE_SUBAGENT_NAME should equal the agent name;"
            & " file contained: " & To_String (Content));
      end;

      --  Clean up.
      if Ada.Directories.Exists (Tmp_File) then
         Ada.Directories.Delete_File (Tmp_File);
      end if;

      Restore_Env (Env_Name, Was_Set, Old_Value);
   exception
      when others =>
         if Ada.Directories.Exists (Tmp_File) then
            Ada.Directories.Delete_File (Tmp_File);
         end if;
         Restore_Env (Env_Name, Was_Set, Old_Value);
         raise;
   end Test_Prompt_Filter_Sets_Subagent_Name;

   procedure Test_Names_Single_Element_Accepted (T : in out Test) is
      pragma Unreferenced (T);

      Env_Name  : constant String := "COYOTE_BIN";
      Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists (Env_Name);
      Old_Value : constant String :=
        Ada.Environment_Variables.Value (Env_Name, "");
      Result    : Unbounded_String;
      Is_Error  : Boolean;
   begin
      Ada.Environment_Variables.Set (Env_Name, "/nonexistent/path/coyote");

      LLM.Tools.Spawn_Subagent.Execute
        (Args_Json =>
           "{""prompt"":""hello"",""names"":[""solo""]}",
         Result    => Result,
         Is_Error  => Is_Error);

      --  Validation must pass; the error (if any) is from the spawn
      --  phase, not from argument validation.
      Assert
        (Is_Error,
         "spawn_subagent with 'names' should fail when coyote"
         & " binary is missing");
      Assert
        (not Contains (To_String (Result), "invalid JSON")
         and then not Contains (To_String (Result), "must not")
         and then not Contains (To_String (Result), "must be"),
         "error should be from the spawn phase, not from validation;"
         & " got: " & To_String (Result));

      Restore_Env (Env_Name, Was_Set, Old_Value);
   exception
      when others =>
         Restore_Env (Env_Name, Was_Set, Old_Value);
         raise;
   end Test_Names_Single_Element_Accepted;

end LLM_Spawn_Subagent_Tests;
