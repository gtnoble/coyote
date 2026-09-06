--  Coyote_Incremental_Tests — tests for CSM streaming semantics.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_Incremental_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Text_Is_Emitted_Immediately (T : in out Test);
   procedure Test_Tag_Split_Across_Deltas       (T : in out Test);
   procedure Test_Unknown_Tag_Is_Visible        (T : in out Test);
   procedure Test_Flush_Emits_Incomplete_Tag    (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Incremental_Tests;
