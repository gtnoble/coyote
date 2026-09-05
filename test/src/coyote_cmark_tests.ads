--  Coyote_Cmark_Tests — unit tests for the libcmark Ada binding.
--
--  Tests cover:
--    - Package elaboration: all enum constants are non-negative integers.
--    - Parse_Document: a valid CommonMark document returns a non-null root.
--    - Node_Get_Type: the document root has type NODE_DOCUMENT.
--    - Iterator: walking "hello" produces ENTER/EXIT TEXT events.
--    - Node_Get_Literal: TEXT node literal matches the input string.
--    - Free/Iter_Free: both complete without raising an exception.
--
--  No ncurses is initialised; all tests run headlessly.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_Cmark_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Enum constants are non-negative after elaboration.
   procedure Test_Constants_Are_Non_Negative (T : in out Test);

   --  Parse_Document on a minimal input returns a non-null root.
   procedure Test_Parse_Returns_Non_Null (T : in out Test);

   --  The document root has type NODE_DOCUMENT.
   procedure Test_Root_Type_Is_Document (T : in out Test);

   --  Walking a single-word paragraph yields at least one TEXT event.
   procedure Test_Iterator_Yields_Text_Event (T : in out Test);

   --  The TEXT node literal matches the source word.
   procedure Test_Literal_Matches_Input (T : in out Test);

   --  Node_Free and Iter_Free complete without raising an exception.
   procedure Test_Free_Does_Not_Raise (T : in out Test);

   --  Node_Get_Heading_Level returns the correct level for # and ###.
   procedure Test_Heading_Level (T : in out Test);

   --  Node_Get_List_Type returns LIST_BULLET for an unordered list.
   procedure Test_List_Type_Is_Bullet (T : in out Test);

   --  Node_Get_List_Type returns LIST_ORDERED for an ordered list.
   procedure Test_List_Type_Is_Ordered (T : in out Test);

   --  Node_Get_List_Start returns the declared starting ordinal.
   procedure Test_List_Start_Ordinal (T : in out Test);

   --  Node_Get_Literal on a code block returns the fenced code text.
   procedure Test_Code_Block_Literal (T : in out Test);

   --  Node_Get_Literal (via shim) on a non-text node returns "" not null.
   procedure Test_Get_Literal_Null_Safety (T : in out Test);

   --  EVENT_ENTER, EVENT_EXIT, and EVENT_DONE are mutually distinct.
   procedure Test_Event_Constants_Are_Distinct (T : in out Test);

   --  Key node-type constants used by Render_Markdown are mutually distinct.
   procedure Test_Node_Constants_Are_Distinct (T : in out Test);

   --  Shared Pango markup preserves two-space indentation per nested list
   --  level.
   procedure Test_Pango_Markup_Nested_List_Indentation (T : in out Test);

   --  Display-math extraction must preserve Markdown code blocks.
   procedure Test_Display_Math_Extraction_Is_Code_Safe (T : in out Test);

   --  A complete display-math block yields source and inner MathML.
   procedure Test_Display_Math_Extraction_Preserves_Source (T : in out Test);

   --  An unmatched display delimiter remains ordinary Markdown.
   procedure Test_Display_Math_Extraction_Preserves_Unmatched (T : in out Test);

   --  Plain Markdown does not cause an empty table-vector lookup.
   procedure Test_Table_Extraction_Preserves_Plain_Text (T : in out Test);

   --  GFM table metadata and copied cell values are extracted correctly.
   procedure Test_Table_Extraction_Preserves_Metadata (T : in out Test);

   --  Table masking preserves one source line per input line.
   procedure Test_Table_Extraction_Preserves_Line_Count (T : in out Test);

   --  Table placeholders preserve their position between surrounding prose.
   procedure Test_Table_Extraction_Preserves_Source_Order (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Cmark_Tests;
