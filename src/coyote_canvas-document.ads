--  Widget-independent geometry in drawing pixels.
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_Canvas.Document is
   pragma Pure;

   --  Edges are half-open. The all-zero rectangle denotes an invalid or
   --  empty selection; callers must validate bounds before applying it.
   type Rectangle is record
      Left   : Natural := 0;
      Top    : Natural := 0;
      Right  : Natural := 0;
      Bottom : Natural := 0;
   end record;

   EMPTY_RECTANGLE : constant Rectangle := (others => 0);

   function Full_Extent (Width, Height : Positive) return Rectangle;

   function Is_Nonempty (Region : Rectangle) return Boolean;

   function Is_Within (Region, Extent : Rectangle) return Boolean;

   --  Exact numeric entry; never round or clamp. Invalid or out-of-image
   --  values return EMPTY_RECTANGLE, including overflow-sized fields.
   function From_Fields
     (X, Y, Width, Height      : Integer;
      Image_Width, Image_Height : Positive) return Rectangle;

   --  Inputs are in drawing coordinates after the caller inverts the view.
   --  Round to the nearest edge (ties upward), clamp to the image, and
   --  normalize reversed drags. A collapsed drag returns EMPTY_RECTANGLE.
   function From_Drag
     (X1, Y1, X2, Y2            : Long_Float;
      Image_Width, Image_Height : Positive) return Rectangle;

   --  Move an existing rectangle to an integer origin, clamping its
   --  position but not changing its size. Reject a bad initial region.
   function Move
     (Region                   : Rectangle;
      X, Y                     : Integer;
      Image_Width, Image_Height : Positive) return Rectangle;

   --  Resolve a crop relative to Current (whose displayed origin is 0,0)
   --  into original drawing coordinates. Reject empty/out-of-bounds
   --  regions. Identity returns Current unchanged so it is not an edit.
   function Source_Extent
     (Current, Relative : Rectangle) return Rectangle;

end Coyote_Canvas.Document;
