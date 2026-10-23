--  Shared bounded syntax vocabulary for the native Ada math engine.
package Math_Model is

   type Font_Kind is
     (Main_Regular, Main_Bold, AMS_Regular, Caligraphic_Regular, Math_Italic,
      Size_1, Size_2, Size_3, Size_4);

   type Atom_Class is
     (Ordinary, Operator_Atom, Binary_Atom, Relation_Atom, Opening, Closing,
      Punctuation, Inner);

   type Array_Kind is (Matrix_Array, Aligned_Array, Cases_Array);

   type Fraction_Style is (Default_Fraction, Display_Fraction, Text_Fraction);
   type Script_Layout is (Side_Scripts, Limit_Scripts);

   type Node_Kind is
     (Row_Node, Glyph_Node, Fraction_Node, Radical_Node, Scripts_Node,
      Space_Node, Array_Node, Delimited_Node, Accent_Node, Overlay_Node);

   subtype Node_Id is Natural;
   No_Node : constant Node_Id := 0;

end Math_Model;
