--  Coyote_Semantics_Tests — AUnit tests for renderer-neutral semantics.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_Semantics_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Construction_And_Order (T : in out Test);
   procedure Test_Nested_Blocks_And_Inlines (T : in out Test);
   procedure Test_Attributes_And_Source (T : in out Test);
   procedure Test_Table_Model (T : in out Test);
   procedure Test_Clear_Invalidates_Handles (T : in out Test);
   procedure Test_Markdown_Adapter_Constructs_Model (T : in out Test);
   procedure Test_Markdown_Adapter_Constructs_Display_Math
     (T : in out Test);
   procedure Test_Semantic_Pango_Golden (T : in out Test);
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Semantics_Tests;
