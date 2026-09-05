with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_Context_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_No_Files_Returns_Empty (T : in out Test);
   procedure Test_Agents_Md_In_Cwd (T : in out Test);
   procedure Test_Global_Context_Dir (T : in out Test);
   procedure Test_Project_Context_Dir (T : in out Test);
   procedure Test_Global_Before_Project (T : in out Test);
   procedure Test_Project_Before_Agents_Md (T : in out Test);
   procedure Test_Context_Files_Alpha_Order (T : in out Test);
   procedure Test_Outer_Header_Present (T : in out Test);
   procedure Test_No_Header_When_Empty (T : in out Test);
   procedure Test_Injected_Into_Built_Prompt (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Context_Tests;
