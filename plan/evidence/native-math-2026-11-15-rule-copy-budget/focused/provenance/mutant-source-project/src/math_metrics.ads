with Math_Model;

--  Generated glyph dimensions from KaTeX 0.16.22, in em units. The matching
--  pinned fonts must be used when painting.
--  See ../../share/coyote/math/PROVENANCE.md.
package Math_Metrics is
   --  Supplies measured advances in Cairo user-space pixels.
   type Advance_Source is limited interface;
   type Advance_Source_Access is access all Advance_Source'Class;

   function Advance
     (Item       : Advance_Source;
      Font       : Math_Model.Font_Kind;
      Code_Point : Natural;
      Pixel_Em   : Long_Float) return Long_Float is abstract;

   --  Font extents are measured from the selected face at Pixel_Em.
   type Font_Line_Extent is record
      Ascent  : Long_Float := 0.0;
      Descent : Long_Float := 0.0;
      Height  : Long_Float := 0.0;
   end record;

   function Font_Line_Extents
     (Item     : Advance_Source;
      Font     : Math_Model.Font_Kind;
      Pixel_Em : Long_Float) return Font_Line_Extent is abstract;

   --  Return the font's recommended baseline distance at the requested size.
   function Font_Line_Height
     (Item     : Advance_Source;
      Font     : Math_Model.Font_Kind;
      Pixel_Em : Long_Float) return Long_Float is abstract;

   type Glyph_Metric is record
      Found   : Boolean := False;
      Width   : Long_Float := 0.0;
      Ascent  : Long_Float := 0.0;
      Descent : Long_Float := 0.0;
      Italic  : Long_Float := 0.0;
      Skew    : Long_Float := 0.0;
   end record;

   function Lookup
     (Font       : Math_Model.Font_Kind;
      Code_Point : Natural) return Glyph_Metric;

   --  Resolve only pinned reference exceptions; never search arbitrary faces.
   function Font_For
     (Font       : Math_Model.Font_Kind;
      Code_Point : Natural) return Math_Model.Font_Kind;
end Math_Metrics;
