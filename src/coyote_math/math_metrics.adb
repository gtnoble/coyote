--  GENERATED metric adapter for the complete KaTeX 0.16.22 tables.
--  The authoritative glyph values and skew live in Math_Font_Data.
with Math_Font_Data;
with Math_Model;

package body Math_Metrics is
   function Face_For (Font : Math_Model.Font_Kind)
      return Math_Font_Data.Font_Face
   is
   begin
      case Font is
         when Math_Model.AMS_Regular =>
            return Math_Font_Data.AMS_Regular;
         when Math_Model.Caligraphic_Bold =>
            return Math_Font_Data.Caligraphic_Bold;
         when Math_Model.Caligraphic_Regular =>
            return Math_Font_Data.Caligraphic_Regular;
         when Math_Model.Fraktur_Bold =>
            return Math_Font_Data.Fraktur_Bold;
         when Math_Model.Fraktur_Regular =>
            return Math_Font_Data.Fraktur_Regular;
         when Math_Model.Main_Regular =>
            return Math_Font_Data.Main_Regular;
         when Math_Model.Main_Bold =>
            return Math_Font_Data.Main_Bold;
         when Math_Model.Main_Bold_Italic =>
            return Math_Font_Data.Main_BoldItalic;
         when Math_Model.Main_Italic =>
            return Math_Font_Data.Main_Italic;
         when Math_Model.Math_Bold_Italic =>
            return Math_Font_Data.Math_BoldItalic;
         when Math_Model.Math_Italic =>
            return Math_Font_Data.Math_Italic;
         when Math_Model.Sans_Serif_Bold =>
            return Math_Font_Data.SansSerif_Bold;
         when Math_Model.Sans_Serif_Italic =>
            return Math_Font_Data.SansSerif_Italic;
         when Math_Model.Sans_Serif_Regular =>
            return Math_Font_Data.SansSerif_Regular;
         when Math_Model.Script_Regular =>
            return Math_Font_Data.Script_Regular;
         when Math_Model.Size_1 =>
            return Math_Font_Data.Size1_Regular;
         when Math_Model.Size_2 =>
            return Math_Font_Data.Size2_Regular;
         when Math_Model.Size_3 =>
            return Math_Font_Data.Size3_Regular;
         when Math_Model.Size_4 =>
            return Math_Font_Data.Size4_Regular;
         when Math_Model.Typewriter_Regular =>
            return Math_Font_Data.Typewriter_Regular;
      end case;
   end Face_For;

   function Lookup
     (Font : Math_Model.Font_Kind;
      Code_Point : Natural) return Glyph_Metric
   is
      Value : constant Math_Font_Data.Glyph_Metric :=
        Math_Font_Data.Lookup (Face_For (Font), Code_Point);
   begin
      return
        (Found   => Value.Found,
         Width   => Value.Width,
         Ascent  => Value.Ascent,
         Descent => Value.Descent,
         Italic  => Value.Italic,
         Skew    => Value.Skew);
   end Lookup;
end Math_Metrics;
