with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

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
   procedure Test_Configured_Skills_Loaded        (T : in out Test);
   procedure Test_Configured_Skill_Shadowed_By_Project (T : in out Test);
   procedure Test_Project_Agents_Skills_Loaded    (T : in out Test);
   procedure Test_Format_Contains_Skill_Name      (T : in out Test);
   procedure Test_Format_Contains_Description     (T : in out Test);
   procedure Test_Format_Contains_Location        (T : in out Test);
   procedure Test_Format_Contains_Outer_Tags      (T : in out Test);
   procedure Test_Format_Contains_Preamble        (T : in out Test);
   procedure Test_Format_Two_Skills               (T : in out Test);
   procedure Test_Injected_Into_Built_Prompt      (T : in out Test);
   procedure Test_Install_Base_Bin_Coyote         (T : in out Test);
   procedure Test_Install_Base_Non_Standard       (T : in out Test);
   procedure Test_Install_Base_Explicit_Arg       (T : in out Test);
   procedure Test_Installation_Skills_Base_Path   (T : in out Test);
   procedure Test_Installation_Skills_Base_Empty  (T : in out Test);
   procedure Test_Install_Root_Skills_Loaded      (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Skills_Tests;
