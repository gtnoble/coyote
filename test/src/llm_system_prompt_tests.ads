with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_System_Prompt_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Default_Prompt_Contains_Preamble (T : in out Test);
   procedure Test_Default_Prompt_Lists_Tools (T : in out Test);
   procedure Test_Prompt_Uses_Injected_Executable_Path (T : in out Test);
   procedure Test_Prompt_Quotes_Executable_Path (T : in out Test);
   procedure Test_Default_Prompt_Contains_Guidelines (T : in out Test);
   procedure Test_Default_Prompt_Contains_Display_Math_Guidance
     (T : in out Test);
   procedure Test_Default_Prompt_Contains_Cwd (T : in out Test);
   procedure Test_Default_Prompt_Contains_Date (T : in out Test);
   procedure Test_Agent_Appended (T : in out Test);
   procedure Test_Agent_Prompt_Appears (T : in out Test);
   procedure Test_No_Tools_Suppresses_Tool_List (T : in out Test);
   procedure Test_Context_Sections_Injected (T : in out Test);
   procedure Test_Skills_Section_Injected (T : in out Test);
   procedure Test_Empty_Context_Sections_Silent (T : in out Test);
   procedure Test_Default_Prompt_Contains_Shell (T : in out Test);
   procedure Test_Section_Order (T : in out Test);
   procedure Test_Memory_Block_Injected (T : in out Test);
   procedure Test_Memory_Block_Absent_When_Empty (T : in out Test);
   procedure Test_Static_Template_Markers_Rendered (T : in out Test);
   procedure Test_No_Tools_Removes_Template_Sections (T : in out Test);
   procedure Test_Terminal_Tool_Policy_Rendered (T : in out Test);
   procedure Test_Coordinator_Section_Rendered (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_System_Prompt_Tests;
