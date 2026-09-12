--  Coyote_Incremental_Tests — focused CSM-2 lexer/parser tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_Incremental_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Valid_Nested_Inlines (T : in out Test);
   procedure Test_Block_Nesting_And_Attributes (T : in out Test);
   procedure Test_Explicit_Table_Model (T : in out Test);
   procedure Test_Table_Alignments_And_Column_Count (T : in out Test);
   procedure Test_Table_Structure_Validation (T : in out Test);
   procedure Test_Table_Inline_Content_And_Source (T : in out Test);
   procedure Test_Table_Delta_Boundaries (T : in out Test);
   procedure Test_Table_Incomplete_And_Malformed_Recovery (T : in out Test);
   procedure Test_Math_And_Code_Are_Opaque (T : in out Test);
   procedure Test_Entities_And_Markdown_Are_Literal (T : in out Test);
   procedure Test_Pipe_Text_Is_Not_A_Table (T : in out Test);
   procedure Test_Malformed_Source_Is_Visible (T : in out Test);
   procedure Test_Incomplete_Flush_Is_Exact (T : in out Test);
   procedure Test_Delta_Boundary_Invariance (T : in out Test);
   procedure Test_UTF8_Splits (T : in out Test);
   procedure Test_Nesting_And_Tag_Limits (T : in out Test);
   procedure Test_Empty_Elements_And_Event_Compatibility (T : in out Test);
   procedure Test_Live_Transitions_And_Order (T : in out Test);
   procedure Test_Live_Opaque_Split_Payloads (T : in out Test);
   procedure Test_Live_Deferred_Completion_And_Flush (T : in out Test);
   procedure Test_Live_Callback_State_Clears_On_Exception (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Incremental_Tests;
