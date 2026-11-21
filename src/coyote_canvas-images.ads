--  Byte-exact operations on canonical, straight-alpha RGBA pixels.
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Streams;
with Coyote_Canvas.Document;

package Coyote_Canvas.Images is
   pragma Pure;

   Invalid_Buffer : exception;

   --  Length of a tightly packed RGBA image; reject arithmetic overflow.
   --  The caller is responsible for applying its resource budget.
   function Packed_Byte_Count (Width, Height : Positive) return Positive;

   --  Copy Region into a separate tightly packed destination. Source_Stride
   --  includes any row padding (no final-row padding is required). Buffer
   --  lower bounds do not affect pixel coordinates. All sizes and bounds
   --  are checked before writing; invalid input raises Invalid_Buffer.
   procedure Copy_RGBA
     (Source                    : Ada.Streams.Stream_Element_Array;
      Image_Width, Image_Height : Positive;
      Source_Stride             : Positive;
      Region                    : Document.Rectangle;
      Destination               : out Ada.Streams.Stream_Element_Array);

end Coyote_Canvas.Images;
