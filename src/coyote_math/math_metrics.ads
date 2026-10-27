with Math_Model;

--  Generated glyph dimensions from KaTeX 0.16.22, in em units. The matching
--  pinned fonts must be used when painting.
--  See ../../share/coyote/math/PROVENANCE.md.
package Math_Metrics is
   type Glyph_Metric is record
      Found   : Boolean := False;
      Width   : Long_Float := 0.0;
      Ascent  : Long_Float := 0.0;
      Descent : Long_Float := 0.0;
      Italic  : Long_Float := 0.0;
      Skew    : Long_Float := 0.0;
   end record;
   function Lookup
     (Font : Math_Model.Font_Kind;
      Code_Point : Natural) return Glyph_Metric;
end Math_Metrics;
