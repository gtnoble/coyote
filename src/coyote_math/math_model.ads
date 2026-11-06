with Ada.Containers.Vectors;

--  Shared bounded syntax vocabulary for the native Ada math engine.
package Math_Model is

   type Script_Profile is
     (Latin_Fallback, Cyrillic_Fallback, Armenian_Fallback,
      Georgian_Fallback, Hebrew_Fallback, Arabic_Fallback,
      Indic_Fallback, CJK_Fallback, Hangul_Fallback,
      Fullwidth_Fallback, Other_Script_Fallback);

   type Font_Kind is
     (AMS_Regular,
      Caligraphic_Bold,
      Caligraphic_Regular,
      Fraktur_Bold,
      Fraktur_Regular,
      Main_Regular,
      Main_Bold,
      Main_Bold_Italic,
      Main_Italic,
      Math_Bold_Italic,
      Math_Italic,
      Sans_Serif_Bold,
      Sans_Serif_Italic,
      Sans_Serif_Regular,
      Script_Regular,
      Size_1,
      Size_2,
      Size_3,
      Size_4,
      Typewriter_Regular);

   type Atom_Class is
     (Ordinary, Operator_Atom, Binary_Atom, Relation_Atom, Opening, Closing,
      Punctuation, Inner);

   type Array_Rule_Kind is (Solid_Array_Rule, Dashed_Array_Rule);
   type Array_Rule is record
      Boundary : Natural := 0;
      Kind : Array_Rule_Kind := Solid_Array_Rule;
   end record;
   package Array_Rule_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Array_Rule);

   type Array_Kind is
     (Matrix_Array, Aligned_Array, Cases_Array, CD_Array);

   type Column_Alignment is (Center_Column, Left_Column, Right_Column);

   type Fraction_Style is (Default_Fraction, Display_Fraction, Text_Fraction);
   type Fraction_Bar_Mode is (Default_Rule, No_Rule, Custom_Rule);
   type Fraction_Alignment is (Center_Fraction, Left_Fraction, Right_Fraction);
   type Script_Layout is (Side_Scripts, Limit_Scripts);
   type Math_Style_Kind is (Natural_Style, Display_Style, Text_Style,
                            Script_Style, Script_Script_Style);
   type Annotation_Kind is (Over_Annotation, Under_Annotation);
   type Dual_Projection is (Visual_First, Semantic_First);
   type Overlap_Alignment is (Right_Overlap, Left_Overlap, Center_Overlap);
   type Enclosure_Kind is
     (Cancel_Enclosure, BCancel_Enclosure, XCancel_Enclosure,
      Strike_Enclosure, Color_Box_Enclosure,
      Framed_Color_Box_Enclosure, Phase_Enclosure,
      Actuarial_Enclosure);
   type Accent_Kind is (Above_Accent, Below_Accent, Full_Accent);
   type Break_Kind is
     (No_Break_Metadata, Allow_Break, Forbid_Break, Forced_Break);
   type Color_Value is record
      Red   : Long_Float := 0.0;
      Green : Long_Float := 0.0;
      Blue  : Long_Float := 0.0;
      Alpha : Long_Float := 1.0;
   end record;

   --  Reserved accent sentinels are layout selectors, never Unicode glyphs.
   Wide_Hat_Code_Point         : constant := 16#11_0001#;
   Wide_Tilde_Code_Point       : constant := 16#11_0002#;
   Over_Right_Arrow_Code_Point : constant := 16#11_0003#;
   Over_Left_Arrow_Code_Point  : constant := 16#11_0004#;
   Over_Brace_Code_Point       : constant := 16#11_0005#;
   Under_Brace_Code_Point      : constant := 16#11_0006#;
   Wide_Check_Code_Point       : constant := 16#11_0007#;
   Under_Tilde_Code_Point      : constant := 16#11_0008#;

   type Node_Kind is
     (Row_Node, Glyph_Node, Fraction_Node, Radical_Node, Scripts_Node,
      Space_Node, Array_Node, Delimited_Node, Accent_Node, Overlay_Node,
      Overlap_Node, Binomial_Node, Annotation_Node, Boxed_Node,
      Phantom_Node, Color_Node, Tagged_Node,
      Style_Node, Dual_Node, Rule_Node, Sized_Node, Raised_Node,
      Enclosed_Node, Stretchy_Node, MathChoice_Node,
      VCenter_Node, Poor_Bold_Node, Verbatim_Node, Text_Run_Node,
      CD_Arrow_Node);

   --  Space-node break metadata is retained for consumers. Forced_Break
   --  separates explicit lines; other break kinds do not wrap formulas.

   subtype Node_Id is Natural;
   No_Node : constant Node_Id := 0;

end Math_Model;
