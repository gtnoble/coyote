with Cairo;
with Coyote_Canvas.Revisions;

--  Geometry shared by canonical coverage and the transient gesture.
package Coyote_Canvas.Ink is
   CHANNEL : constant := 13;
   RGB     : constant := 16#0D0D0D#;

   --  Paint onto a context configured with the caller's source color and
   --  transform. Stored strokes use source coordinates, not view coordinates.
   procedure Draw
     (Points : Revisions.Samples.Vector; Context : Cairo.Cairo_Context);
end Coyote_Canvas.Ink;
