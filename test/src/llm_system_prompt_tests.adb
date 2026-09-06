with AUnit.Assertions;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with LLM.System_Prompt;
with AUnit.Test_Caller;

package body LLM_System_Prompt_Tests is

   use AUnit.Assertions;

   Test_Cwd : constant String := "/tmp/test_cwd";

   function Today_String return String is
      Raw : constant String :=
        Ada.Calendar.Formatting.Image
          (Ada.Calendar.Clock,
           Include_Time_Fraction => False);
   begin
      if Raw'Length >= 10 then
         return Raw (Raw'First .. Raw'First + 9);
      else
         return Raw;
      end if;
   end Today_String;

   function Count_Substring (Source, Pattern : String) return Natural is
      Count : Natural := 0;
      From  : Positive := 1;
      Match : Natural;
   begin
      if Pattern'Length = 0 then
         return 0;
      end if;

      while From <= Source'Length loop
         Match := Ada.Strings.Fixed.Index
           (Source => Source, Pattern => Pattern, From => From);
         exit when Match = 0;
         Count := Count + 1;
         From := Match + Pattern'Length;
      end loop;

      return Count;
   end Count_Substring;

   procedure Test_Default_Prompt_Contains_Preamble (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt (Cwd => Test_Cwd);
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "expert coding assistant") > 0,
         "default prompt should contain the coding-assistant preamble");
   end Test_Default_Prompt_Contains_Preamble;

   procedure Test_Default_Prompt_Lists_Tools (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt (Cwd => Test_Cwd);
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "shell") > 0,
         "default prompt should mention the shell tool");
      Assert
        (Ada.Strings.Fixed.Index (P, "--subagent --prompt -") > 0,
         "default prompt should explain the subagent shell pattern");
   end Test_Default_Prompt_Lists_Tools;

   procedure Test_Prompt_Uses_Injected_Executable_Path (T : in out Test) is
      pragma Unreferenced (T);

      Path   : constant String := "/opt/coyote/bin/coyote";
      Prompt : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd           => Test_Cwd,
           Executable_Path => Path);
      Command : constant String := "'/opt/coyote/bin/coyote' --subagent";
   begin
      Assert
        (Ada.Strings.Fixed.Index (Prompt, Command) > 0,
         "prompt should use the injected executable path");
      Assert
        (Count_Substring (Prompt, Command) = 2,
         "prompt should repeat the same command in the example");
   end Test_Prompt_Uses_Injected_Executable_Path;

   procedure Test_Prompt_Quotes_Executable_Path (T : in out Test) is
      pragma Unreferenced (T);

      Prompt : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd            => Test_Cwd,
           Executable_Path => "/tmp/coyote agent/bin/coyote");
   begin
      Assert
        (Ada.Strings.Fixed.Index
           (Prompt, "'/tmp/coyote agent/bin/coyote' --subagent") > 0,
         "prompt should shell-quote executable paths containing spaces");
   end Test_Prompt_Quotes_Executable_Path;

   procedure Test_Default_Prompt_Contains_Guidelines (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt (Cwd => Test_Cwd);
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "aged, sed, or perl") > 0,
         "default prompt should include the editing guideline");
   end Test_Default_Prompt_Contains_Guidelines;

   procedure Test_Default_Prompt_Contains_Display_Math_Guidance
     (T : in out Test)
   is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt (Cwd => Test_Cwd);
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "# Display Math") > 0,
         "default prompt should include display-math guidance");
      Assert
        (Ada.Strings.Fixed.Index (P, "Presentation MathML") > 0,
         "display-math guidance should require Presentation MathML");
      Assert
        (Ada.Strings.Fixed.Index (P, "`<math>`") > 0,
         "display-math guidance should require a math root document");
      Assert
        (Ada.Strings.Fixed.Index (P, "http://www.w3.org/1998/Math/MathML") > 0,
         "display-math guidance should require the MathML namespace");
      Assert
        (Ada.Strings.Fixed.Index (P, "`&lt;`") > 0,
         "display-math guidance should require XML escaping");
      Assert
        (Ada.Strings.Fixed.Index (P, "LaTeX") > 0,
         "display-math guidance should prohibit LaTeX commands");
      Assert
        (Ada.Strings.Fixed.Index (P, "\frac") = 0,
         "display-math guidance should not advertise LaTeX commands");
      Assert
        (Ada.Strings.Fixed.Index (P, "# Inline Math") > 0,
         "default prompt should include inline-math guidance");
      Assert
        (Ada.Strings.Fixed.Index (P, "Unicode math symbols directly") > 0,
         "inline-math guidance should require Unicode math symbols");
   end Test_Default_Prompt_Contains_Display_Math_Guidance;
   procedure Test_Default_Prompt_Contains_Cwd (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt (Cwd => Test_Cwd);
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, Test_Cwd) > 0,
         "default prompt should include the current working directory");
   end Test_Default_Prompt_Contains_Cwd;

   procedure Test_Default_Prompt_Contains_Date (T : in out Test) is
      pragma Unreferenced (T);

      P        : constant String :=
        LLM.System_Prompt.Build_System_Prompt (Cwd => Test_Cwd);
      Date_Str : constant String := Today_String;
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, Date_Str) > 0,
         "default prompt should include today's date");
   end Test_Default_Prompt_Contains_Date;

   procedure Test_Agent_Appended (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd    => Test_Cwd,
           Agent  => "AGENT_SENTINEL");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "AGENT_SENTINEL") > 0,
         "agent text should be appended to the system prompt");
      Assert
        (Ada.Strings.Fixed.Index (P, "expert coding assistant") > 0,
         "default preamble should still be present");
   end Test_Agent_Appended;

   procedure Test_Agent_Prompt_Appears (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd   => Test_Cwd,
           Agent => "CUSTOM_PROMPT_SENTINEL");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "CUSTOM_PROMPT_SENTINEL") > 0,
         "agent prompt should be appended to the system prompt");
   end Test_Agent_Prompt_Appears;

   procedure Test_No_Tools_Suppresses_Tool_List (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd      => Test_Cwd,
           No_Tools => True);
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "Available tools:") = 0,
         "No_Tools should suppress the tool heading");
      Assert
        (Ada.Strings.Fixed.Index (P, "- shell:") = 0,
         "No_Tools should suppress the tool list and guidelines");
   end Test_No_Tools_Suppresses_Tool_List;

   procedure Test_Context_Sections_Injected (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd              => Test_Cwd,
           Context_Sections => "CTX_SENTINEL");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "CTX_SENTINEL") > 0,
         "context sections should be injected when provided");
   end Test_Context_Sections_Injected;

   procedure Test_Skills_Section_Injected (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd            => Test_Cwd,
           Skills_Section => "SKILL_SENTINEL");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "SKILL_SENTINEL") > 0,
         "skills section should be injected when provided");
   end Test_Skills_Section_Injected;

   procedure Test_Empty_Context_Sections_Silent (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd              => Test_Cwd,
           Context_Sections => "");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "# Project Context") = 0,
         "empty context sections should not add a project-context header");
   end Test_Empty_Context_Sections_Silent;

   procedure Test_Default_Prompt_Contains_Shell (T : in out Test) is
      pragma Unreferenced (T);

      P          : constant String :=
        LLM.System_Prompt.Build_System_Prompt (Cwd => Test_Cwd);
      Shell_Path : constant String :=
        Ada.Environment_Variables.Value ("SHELL", "/bin/sh");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "Current shell: " & Shell_Path) > 0,
         "default prompt should include the current shell path");
   end Test_Default_Prompt_Contains_Shell;

   procedure Test_Section_Order (T : in out Test) is
      pragma Unreferenced (T);

      P         : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd              => Test_Cwd,
           Context_Sections => "=CTX_MARKER_5E3A2F=",
           Skills_Section   => "=SKILL_MARKER_8B1D4C=");
      Ctx_Pos   : constant Natural :=
        Ada.Strings.Fixed.Index (P, "=CTX_MARKER_5E3A2F=");
      Skill_Pos : constant Natural :=
        Ada.Strings.Fixed.Index (P, "=SKILL_MARKER_8B1D4C=");
      Date_Pos  : constant Natural :=
        Ada.Strings.Fixed.Index (P, "Current date");
   begin
      Assert (Ctx_Pos > 0, "context section should be present");
      Assert (Skill_Pos > 0, "skills section should be present");
      Assert (Date_Pos > 0, "date section should be present");
      Assert
        (Ctx_Pos < Skill_Pos,
         "context section should appear before skills section");
      Assert
        (Ctx_Pos < Date_Pos and then Skill_Pos < Date_Pos,
         "context and skills sections should appear before the date block");
   end Test_Section_Order;

   procedure Test_Memory_Block_Injected (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd          => Test_Cwd,
           Memory_Block => "MEMORY_SENTINEL");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "MEMORY_SENTINEL") > 0,
         "memory block should be injected when provided");
   end Test_Memory_Block_Injected;

   procedure Test_Memory_Block_Absent_When_Empty (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd          => Test_Cwd,
           Memory_Block => "");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "# Memory System") = 0,
         "empty memory block should not inject memory taxonomy");
   end Test_Memory_Block_Absent_When_Empty;

   procedure Test_Static_Template_Markers_Rendered (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd             => Test_Cwd,
           Executable_Path => "/opt/coyote/bin/coyote");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "{{") = 0,
         "rendered prompt should not contain template markers");
      Assert
        (Ada.Strings.Fixed.Index (P, "# Editing Discipline") > 0,
         "static template should retain its final section");
   end Test_Static_Template_Markers_Rendered;

   procedure Test_No_Tools_Removes_Template_Sections (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd      => Test_Cwd,
           No_Tools => True);
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "Available tools:") = 0,
         "No_Tools should remove the resource tool section");
      Assert
        (Ada.Strings.Fixed.Index (P, "# Tool Use Policy") = 0,
         "No_Tools should remove the resource policy section");
      Assert
        (Ada.Strings.Fixed.Index
           (P, "# Coordinator Subagent Orchestration") = 0,
         "No_Tools should remove the coordinator section");
   end Test_No_Tools_Removes_Template_Sections;

   procedure Test_Terminal_Tool_Policy_Rendered (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd              => Test_Cwd,
           No_Tools         => False,
           Has_Editing_Tools => False,
           Coordinator_Mode => False);
   begin
      Assert
        (Ada.Strings.Fixed.Index
           (P, "Terminal tools are available") > 0,
         "terminal-only sessions should render the terminal policy");
      Assert
        (Ada.Strings.Fixed.Index
           (P, "Editing tools are available") = 0,
         "terminal-only sessions should omit the editing policy");
      Assert
        (Ada.Strings.Fixed.Index
           (P, "# Coordinator Subagent Orchestration") = 0,
         "disabled coordinator mode should omit its section");
   end Test_Terminal_Tool_Policy_Rendered;

   procedure Test_Coordinator_Section_Rendered (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd              => Test_Cwd,
           No_Tools         => False,
           Has_Editing_Tools => True,
           Coordinator_Mode => True);
   begin
      Assert
        (Ada.Strings.Fixed.Index
           (P, "# Coordinator Subagent Orchestration") > 0,
         "coordinator mode should render its resource section");
      Assert
        (Ada.Strings.Fixed.Index
           (P, "Never delegate understanding") > 0,
         "coordinator section should retain synthesis guidance");
   end Test_Coordinator_Section_Rendered;

   package LLM_Sys_Prompt_Caller is
     new AUnit.Test_Caller (LLM_System_Prompt_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains preamble",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Preamble'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt lists built-in tools",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Lists_Tools'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt uses injected executable path",
         LLM_System_Prompt_Tests
           .Test_Prompt_Uses_Injected_Executable_Path'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt quotes executable path",
         LLM_System_Prompt_Tests
           .Test_Prompt_Quotes_Executable_Path'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains guidelines",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Guidelines'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains math-formatting guidance",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Display_Math_Guidance'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains cwd",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Cwd'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains date",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Date'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt agent appended to prompt",
         LLM_System_Prompt_Tests
           .Test_Agent_Appended'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt agent prompt appears in built prompt",
         LLM_System_Prompt_Tests
           .Test_Agent_Prompt_Appears'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt no-tools suppresses tool list",
         LLM_System_Prompt_Tests
           .Test_No_Tools_Suppresses_Tool_List'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt injects context sections",
         LLM_System_Prompt_Tests
           .Test_Context_Sections_Injected'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt injects skills section",
         LLM_System_Prompt_Tests
           .Test_Skills_Section_Injected'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt empty context section is silent",
         LLM_System_Prompt_Tests
           .Test_Empty_Context_Sections_Silent'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains current shell",
         LLM_System_Prompt_Tests.Test_Default_Prompt_Contains_Shell'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt preserves section order",
         LLM_System_Prompt_Tests.Test_Section_Order'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt memory block injected when provided",
         LLM_System_Prompt_Tests.Test_Memory_Block_Injected'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt empty memory block absent from prompt",
         LLM_System_Prompt_Tests.Test_Memory_Block_Absent_When_Empty'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt renders all template markers",
         LLM_System_Prompt_Tests.Test_Static_Template_Markers_Rendered'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt removes template sections without tools",
         LLM_System_Prompt_Tests.Test_No_Tools_Removes_Template_Sections'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt renders terminal tool policy",
         LLM_System_Prompt_Tests.Test_Terminal_Tool_Policy_Rendered'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt renders coordinator section",
         LLM_System_Prompt_Tests.Test_Coordinator_Section_Rendered'Access));

      return Result;
   end Suite;

end LLM_System_Prompt_Tests;
