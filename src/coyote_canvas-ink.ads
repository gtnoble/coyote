with Cairo;
with Coyote_Canvas.Revisions;

--  Geometry shared by canonical coverage and the transient gesture.
package Coyote_Canvas.Ink is
   CHANNEL : constant := 13;
   RGB     : constant := 16#0D0D0D#;

   --  Paint one round dot or pressure-weighted segment in source coordinates.
   procedure Draw_Dot
     (Point : Revisions.Sample; Context : Cairo.Cairo_Context);
   procedure Draw_Segment
     (Previous, Point : Revisions.Sample;
      Context : Cairo.Cairo_Context);

   --  Paint a stored stroke using the caller's source color and transform.
   procedure Draw
     (Points : Revisions.Samples.Vector; Context : Cairo.Cairo_Context);
end Coyote_Canvas.Ink;
