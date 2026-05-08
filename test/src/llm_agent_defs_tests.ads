--  Unit tests for LLM.Agent_Defs.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit;
with AUnit.Test_Fixtures;

package LLM_Agent_Defs_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Empty_When_No_Roots (T : in out Test);
   procedure Test_Loads_Valid_Agent_Def (T : in out Test);
   procedure Test_Skips_Missing_Frontmatter (T : in out Test);
   procedure Test_Skips_Missing_Name (T : in out Test);
   procedure Test_Skips_Missing_Description (T : in out Test);
   procedure Test_Project_Local_Shadows_Global (T : in out Test);
   procedure Test_Resolve_Returns_Body (T : in out Test);
   procedure Test_Resolve_Raises_When_Not_Found (T : in out Test);
   procedure Test_Format_Empty_Returns_Empty (T : in out Test);
   procedure Test_Format_Includes_Name (T : in out Test);
   procedure Test_Format_Includes_Description (T : in out Test);
   procedure Test_Format_Includes_Location (T : in out Test);

end LLM_Agent_Defs_Tests;
