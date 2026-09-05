with AUnit;
with AUnit.Test_Fixtures;

package LLM_Settings_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Load_Settings (T : in out Test);
   procedure Test_Resolve_Api_Key_Literal (T : in out Test);
   procedure Test_Resolve_Api_Key_Interpolated_Env (T : in out Test);
   procedure Test_Resolve_Api_Key_Default_Env (T : in out Test);
   procedure Test_Append_System_Prompt_Loaded (T : in out Test);
   procedure Test_Append_System_Prompt_Missing (T : in out Test);
   procedure Test_Append_Prompt_In_Built_Prompt (T : in out Test);

   --  promptFilter field round-trips through Load_Settings.
   procedure Test_Prompt_Filter_Loaded (T : in out Test);

   --  Absent promptFilter field defaults to the empty string.
   procedure Test_Prompt_Filter_Missing (T : in out Test);

   procedure Test_Default_Sandbox_Profile_Loaded (T : in out Test);
   procedure Test_Rename_Default_Sandbox (T : in out Test);
   procedure Test_Max_Recursion_Depth_Invalid_Defaults (T : in out Test);
   procedure Test_Termination_Grace_Load_And_Clamp (T : in out Test);
   procedure Test_Completion_Notifications_Default_Enabled (T : in out Test);
   procedure Test_Save_Preferences_Preserves_And_Clears (T : in out Test);
   procedure Test_Price_Display_Load_And_Default (T : in out Test);
   procedure Test_Skill_Paths_Loaded (T : in out Test);

end LLM_Settings_Tests;
