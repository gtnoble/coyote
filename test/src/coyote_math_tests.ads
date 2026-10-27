with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_Math_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Parse_Simple_Glyph (T : in out Test);
   procedure Test_Parse_Unicode_Symbols (T : in out Test);
   procedure Test_Parse_Invalid_UTF8_And_Comments (T : in out Test);
   procedure Test_Parse_Macros_And_Shared_Context (T : in out Test);
   procedure Test_Parse_Macro_Scope_And_Reset (T : in out Test);
   procedure Test_Parse_Macro_Tokens_Across_Requests (T : in out Test);
   procedure Test_Parse_Empty_And_Unknown (T : in out Test);
   procedure Test_Parse_Oversized_Prefix (T : in out Test);
   procedure Test_Parse_Deterministic_Malformed_Input (T : in out Test);
   procedure Test_Parse_MathML_Is_Not_Accepted (T : in out Test);
   procedure Test_Parse_Untrusted_Command_Policies (T : in out Test);
   procedure Test_Metrics_Known_And_Unknown_Glyph (T : in out Test);
   procedure Test_Layout_Simple_Glyph (T : in out Test);
   procedure Test_Layout_Script_Scale_And_Geometry (T : in out Test);
   procedure Test_Layout_Wide_Limit_Geometry (T : in out Test);
   procedure Test_Layout_Radical_Index_Glyph (T : in out Test);
   procedure Test_Layout_Fraction_Text_And_Display (T : in out Test);
   procedure Test_Layout_Requested_Engine_Features (T : in out Test);
   procedure Test_Layout_Explicit_Whitespace (T : in out Test);
   procedure Test_Layout_Double_Bar_Delimiters (T : in out Test);
   procedure Test_Parse_Named_Operators_And_Aliases (T : in out Test);
   procedure Test_Parse_Accents_And_Operator_Words (T : in out Test);
   procedure Test_Layout_Accents_And_Operator_Limits (T : in out Test);
   procedure Test_Parse_Text_And_Roman_Fonts (T : in out Test);
   procedure Test_Layout_Matrix_Cases_And_Aligned (T : in out Test);
   procedure Test_Painter_Exact_Fonts_And_Recovery (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Math_Tests;
