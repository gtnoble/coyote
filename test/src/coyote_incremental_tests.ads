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
   procedure Test_Table_Event_Survives_Split    (T : in out Test);
   procedure Test_Math_Event_Survives_Split     (T : in out Test);
   procedure Test_Block_Trailing_Text_Emits     (T : in out Test);
   procedure Test_Adjacent_Blocks_Preserve_Order (T : in out Test);
   procedure Test_Malformed_Math_Opening_Is_Visible (T : in out Test);
   procedure Test_Code_Event_Survives_Split         (T : in out Test);
   procedure Test_Incomplete_Code_Flushes (T : in out Test);
   procedure Test_Empty_Blocks_Are_Valid (T : in out Test);
   procedure Test_Horizontal_Rule_Events (T : in out Test);
   procedure Test_Heading_Events (T : in out Test);
   procedure Test_Blockquote_Events (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Incremental_Tests;
