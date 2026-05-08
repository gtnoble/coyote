with AUnit.Assertions;
with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with LLM.System_Prompt;

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
        (Ada.Strings.Fixed.Index (P, "bash") > 0,
         "default prompt should mention the bash tool");
      Assert
        (Ada.Strings.Fixed.Index (P, "read") > 0,
         "default prompt should mention the read tool");
      Assert
        (Ada.Strings.Fixed.Index (P, "edit") > 0,
         "default prompt should mention the edit tool");
      Assert
        (Ada.Strings.Fixed.Index (P, "write") > 0,
         "default prompt should mention the write tool");
      Assert
        (Ada.Strings.Fixed.Index (P, "find") > 0,
         "default prompt should mention the find tool");
      Assert
        (Ada.Strings.Fixed.Index (P, "spawn_subagent") > 0,
         "default prompt should mention the spawn_subagent tool");
   end Test_Default_Prompt_Lists_Tools;

   procedure Test_Default_Prompt_Contains_Guidelines (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt (Cwd => Test_Cwd);
   begin
      Assert
        (Ada.Strings.Fixed.Index
           (P, "read to examine files before editing") > 0,
         "default prompt should include the editing guideline");
   end Test_Default_Prompt_Contains_Guidelines;

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

   procedure Test_Agent_Def_Replaces_Preamble (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd       => Test_Cwd,
           Agent_Def => "AGENT_DEF_SENTINEL");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "AGENT_DEF_SENTINEL") > 0,
         "agent definition should be used verbatim");
      Assert
        (Ada.Strings.Fixed.Index (P, "expert coding assistant") = 0,
         "agent definition should replace the default preamble");
   end Test_Agent_Def_Replaces_Preamble;

   procedure Test_Agent_Def_Keeps_Cwd (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd       => Test_Cwd,
           Agent_Def => "AGENT_DEF_SENTINEL");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, Test_Cwd) > 0,
         "agent definition should still include the current working directory");
   end Test_Agent_Def_Keeps_Cwd;

   procedure Test_Custom_Prompt_Appears (T : in out Test) is
      pragma Unreferenced (T);

      P : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd           => Test_Cwd,
           Custom_Prompt => "CUSTOM_PROMPT_SENTINEL");
   begin
      Assert
        (Ada.Strings.Fixed.Index (P, "CUSTOM_PROMPT_SENTINEL") > 0,
         "custom prompt should be appended to the system prompt");
   end Test_Custom_Prompt_Appears;

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
        (Ada.Strings.Fixed.Index (P, "bash") = 0,
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

   procedure Test_Section_Order (T : in out Test) is
      pragma Unreferenced (T);

      P         : constant String :=
        LLM.System_Prompt.Build_System_Prompt
          (Cwd              => Test_Cwd,
           Context_Sections => "CTX",
           Skills_Section   => "SKILL");
      Ctx_Pos   : constant Natural := Ada.Strings.Fixed.Index (P, "CTX");
      Skill_Pos : constant Natural := Ada.Strings.Fixed.Index (P, "SKILL");
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

end LLM_System_Prompt_Tests;
