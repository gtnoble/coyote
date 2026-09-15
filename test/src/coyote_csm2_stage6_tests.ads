--  Coyote_CSM2_Stage6_Tests — generated CSM-2 qualification.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_CSM2_Stage6_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Generated_Valid_Boundaries_And_Journals
     (T : in out Test);
   procedure Test_Generated_Malformed_Source_Conservation
     (T : in out Test);
   procedure Test_Root_Identity_Chunkings_And_Finish
     (T : in out Test);
   procedure Test_Parser_Long_Stream_Scaling
     (T : in out Test);
   procedure Test_Parser_Reset_Lifecycle_Stress
     (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_CSM2_Stage6_Tests;
