with AUnit;
with AUnit.Test_Fixtures;

package LLM_Skills_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_No_Skills_Returns_Empty_String  (T : in out Test);
   procedure Test_Parses_Name_And_Description     (T : in out Test);
   procedure Test_Location_Is_Absolute_Path       (T : in out Test);
   procedure Test_Missing_Name_Skipped            (T : in out Test);
   procedure Test_Missing_Description_Skipped     (T : in out Test);
   procedure Test_Global_Skills_Loaded            (T : in out Test);
   procedure Test_Project_Skills_Loaded           (T : in out Test);
   procedure Test_Global_Agents_Skills_Loaded     (T : in out Test);
   procedure Test_Project_Agents_Skills_Loaded    (T : in out Test);
   procedure Test_Format_Contains_Skill_Name      (T : in out Test);
   procedure Test_Format_Contains_Description     (T : in out Test);
   procedure Test_Format_Contains_Location        (T : in out Test);
   procedure Test_Format_Contains_Outer_Tags      (T : in out Test);
   procedure Test_Format_Contains_Preamble        (T : in out Test);
   procedure Test_Format_Two_Skills               (T : in out Test);
   procedure Test_Injected_Into_Built_Prompt      (T : in out Test);

end LLM_Skills_Tests;
