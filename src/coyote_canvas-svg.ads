with Ada.Strings.Unbounded;
with Coyote_Image_Decoder;

package Coyote_Canvas.SVG is
   --  Decodes a bounded, static SVG to an owned raw RGBA GdkPixbuf.
   --  The caller must release Pixels with Coyote_Image_Decoder.Release.
   --  CSS and style attributes are rejected; presentation attributes are
   --  accepted only from a fixed list, with url() restricted to #fragments.
   --  The supported subset includes common SVG shapes, paths, text,
   --  gradients, definitions, groups, transforms and local references.
   --  Scripting, animation, external resources, embedded HTML, DTDs,
   --  entities, non-declaration processing instructions and compressed
   --  SVG are excluded. Raster limits are those in Coyote_Canvas.Rasters.
   procedure Decode
     (Data   :     String;
      Pixels : out Coyote_Image_Decoder.Pixbuf_Handle;
      Error  : out Ada.Strings.Unbounded.Unbounded_String);
end Coyote_Canvas.SVG;
