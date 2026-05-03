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

end LLM_Settings_Tests;
