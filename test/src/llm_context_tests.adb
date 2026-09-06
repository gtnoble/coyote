with AUnit.Assertions;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with LLM.System_Prompt;
with AUnit.Test_Caller;

package body LLM_Context_Tests is

   use AUnit.Assertions;
   use type Ada.Directories.File_Kind;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Mkdir (Path : String) is
   begin
      if Path'Length > 0 then
         Ada.Directories.Create_Path (Path);
      end if;
   end Mkdir;

   procedure Write_File (Path, Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Mkdir (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Write_File;

   procedure Cleanup (Path : String) is
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return;
      end if;

      if Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then
         Ada.Directories.Delete_File (Path);
      else
         Ada.Directories.Delete_Tree (Path);
      end if;
   exception
      when others =>
         null;
   end Cleanup;

   procedure Test_No_Files_Returns_Empty (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_1";
      Cwd          : constant String := "/tmp/coyote_ctx_test_1_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String := LLM.System_Prompt.Load_Context_Sections
           (Cwd);
      begin
         Assert
           (Result = "",
            "no context files should return the empty string");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_No_Files_Returns_Empty;

   procedure Test_Agents_Md_In_Cwd (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_2";
      Cwd          : constant String := "/tmp/coyote_ctx_test_2_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Mkdir (Cwd);
      Write_File
        (Cwd & "/AGENTS.md",
         "# Agent Instructions" & ASCII.LF & "Do stuff.");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String := LLM.System_Prompt.Load_Context_Sections
           (Cwd);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "Agent Instructions") > 0,
            "AGENTS.md content should be loaded from the cwd");
         Assert
           (Ada.Strings.Fixed.Index (Result, "## ") > 0,
            "each context section should include a file header");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Agents_Md_In_Cwd;

   procedure Test_Global_Context_Dir (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_3";
      Cwd          : constant String := "/tmp/coyote_ctx_test_3_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Write_File (Home & "/.coyote/context/global.md", "GLOBAL_CONTENT");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String := LLM.System_Prompt.Load_Context_Sections
           (Cwd);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "GLOBAL_CONTENT") > 0,
            "global context markdown files should be loaded");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Global_Context_Dir;

   procedure Test_Project_Context_Dir (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_4";
      Cwd          : constant String := "/tmp/coyote_ctx_test_4_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Write_File (Cwd & "/.coyote/context/proj.md", "PROJECT_CONTENT");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String := LLM.System_Prompt.Load_Context_Sections
           (Cwd);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "PROJECT_CONTENT") > 0,
            "project context markdown files should be loaded");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Project_Context_Dir;

   procedure Test_Global_Before_Project (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_5";
      Cwd          : constant String := "/tmp/coyote_ctx_test_5_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Write_File (Home & "/.coyote/context/g.md", "GLOBAL");
      Write_File (Cwd & "/.coyote/context/p.md", "PROJECT");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result      : constant String :=
           LLM.System_Prompt.Load_Context_Sections (Cwd);
         Global_Pos  : constant Natural :=
           Ada.Strings.Fixed.Index (Result, "GLOBAL");
         Project_Pos : constant Natural :=
           Ada.Strings.Fixed.Index (Result, "PROJECT");
      begin
         Assert (Global_Pos > 0, "global content should be present");
         Assert (Project_Pos > 0, "project content should be present");
         Assert
           (Global_Pos < Project_Pos,
            "global context should appear before project context");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Global_Before_Project;

   procedure Test_Project_Before_Agents_Md (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_6";
      Cwd          : constant String := "/tmp/coyote_ctx_test_6_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Write_File (Cwd & "/.coyote/context/p.md", "PROJECT_FILE");
      Write_File (Cwd & "/AGENTS.md", "AGENTS_FILE");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result     : constant String :=
           LLM.System_Prompt.Load_Context_Sections (Cwd);
         Project_Pos : constant Natural :=
           Ada.Strings.Fixed.Index (Result, "PROJECT_FILE");
         Agents_Pos : constant Natural :=
           Ada.Strings.Fixed.Index (Result, "AGENTS_FILE");
      begin
         Assert (Project_Pos > 0, "project file should be present");
         Assert (Agents_Pos > 0, "AGENTS.md should be present");
         Assert
           (Project_Pos < Agents_Pos,
            "project context files should appear before AGENTS.md");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Project_Before_Agents_Md;

   procedure Test_Context_Files_Alpha_Order (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_7";
      Cwd          : constant String := "/tmp/coyote_ctx_test_7_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Write_File (Home & "/.coyote/context/b_file.md", "B_CONTENT");
      Write_File (Home & "/.coyote/context/a_file.md", "A_CONTENT");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String :=
           LLM.System_Prompt.Load_Context_Sections (Cwd);
         A_Pos  : constant Natural :=
           Ada.Strings.Fixed.Index (Result, "A_CONTENT");
         B_Pos  : constant Natural :=
           Ada.Strings.Fixed.Index (Result, "B_CONTENT");
      begin
         Assert (A_Pos > 0, "A_CONTENT should be present");
         Assert (B_Pos > 0, "B_CONTENT should be present");
         Assert
           (A_Pos < B_Pos,
            "context files within one directory should be sorted"
            & " alphabetically");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Context_Files_Alpha_Order;

   procedure Test_Outer_Header_Present (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_8";
      Cwd          : constant String := "/tmp/coyote_ctx_test_8_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Write_File (Cwd & "/AGENTS.md", "any content");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String := LLM.System_Prompt.Load_Context_Sections
           (Cwd);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "# Project Context") > 0,
            "non-empty context output should include the outer header");
         Assert
           (Ada.Strings.Fixed.Index
              (Result, "Project-specific instructions") > 0,
            "non-empty context output should include the outer preamble");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Outer_Header_Present;

   procedure Test_No_Header_When_Empty (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_9";
      Cwd          : constant String := "/tmp/coyote_ctx_test_9_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Result : constant String := LLM.System_Prompt.Load_Context_Sections
           (Cwd);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, "# Project Context") = 0,
            "empty context output should not include the outer header");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_No_Header_When_Empty;

   procedure Test_Injected_Into_Built_Prompt (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_ctx_test_10";
      Cwd          : constant String := "/tmp/coyote_ctx_test_10_cwd";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
   begin
      Cleanup (Home);
      Cleanup (Cwd);
      Mkdir (Home & "/.coyote");
      Write_File (Cwd & "/AGENTS.md", "INJECTED_AGENT_INSTRUCTIONS");

      Ada.Environment_Variables.Set ("HOME", Home);

      declare
         Prompt : constant String :=
           LLM.System_Prompt.Build_System_Prompt (Cwd => Cwd);
      begin
         Assert
           (Ada.Strings.Fixed.Index
              (Prompt, "INJECTED_AGENT_INSTRUCTIONS") > 0,
            "Build_System_Prompt should include auto-loaded context files");
      end;

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup (Cwd);
      Cleanup (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup (Cwd);
         Cleanup (Home);
         raise;
   end Test_Injected_Into_Built_Prompt;

   package LLM_Context_Caller is
     new AUnit.Test_Caller (LLM_Context_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections returns empty with no files",
         LLM_Context_Tests.Test_No_Files_Returns_Empty'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections loads AGENTS.md from cwd",
         LLM_Context_Tests.Test_Agents_Md_In_Cwd'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections loads global context dir",
         LLM_Context_Tests.Test_Global_Context_Dir'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections loads project context dir",
         LLM_Context_Tests.Test_Project_Context_Dir'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections: global before project",
         LLM_Context_Tests.Test_Global_Before_Project'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections: project before AGENTS",
         LLM_Context_Tests.Test_Project_Before_Agents_Md'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections sorts files alphabetically",
         LLM_Context_Tests.Test_Context_Files_Alpha_Order'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections adds outer header",
         LLM_Context_Tests.Test_Outer_Header_Present'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections omits header when empty",
         LLM_Context_Tests.Test_No_Header_When_Empty'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Build_System_Prompt injects loaded context",
         LLM_Context_Tests.Test_Injected_Into_Built_Prompt'Access));

      return Result;
   end Suite;

end LLM_Context_Tests;
