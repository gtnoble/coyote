--  Generated from KaTeX 0.16.22 src/fontMetricsData.js (MIT).
--  Copyright (c) 2013-2020 Khan Academy and other contributors.
--  See ../../share/coyote/math/licenses/KaTeX-MIT.txt and
--  ../../share/coyote/math/PROVENANCE.md.
package Math_Font_Data is
   type Font_Face is
     (AMS_Regular,
      Caligraphic_Bold,
      Caligraphic_Regular,
      Fraktur_Bold,
      Fraktur_Regular,
      Main_Bold,
      Main_BoldItalic,
      Main_Italic,
      Main_Regular,
      Math_BoldItalic,
      Math_Italic,
      SansSerif_Bold,
      SansSerif_Italic,
      SansSerif_Regular,
      Script_Regular,
      Size1_Regular,
      Size2_Regular,
      Size3_Regular,
      Size4_Regular,
      Typewriter_Regular);

   type Glyph_Metric is record
      Found   : Boolean := False;
      Width   : Long_Float := 0.0;
      Ascent  : Long_Float := 0.0;
      Descent : Long_Float := 0.0;
      Italic  : Long_Float := 0.0;
      Skew    : Long_Float := 0.0;
   end record;

   function Face_Stem (Face : Font_Face) return String;
   function Asset_Filename (Face : Font_Face) return String;
   function Lookup
     (Face : Font_Face; Code_Point : Natural) return Glyph_Metric;
end Math_Font_Data;
