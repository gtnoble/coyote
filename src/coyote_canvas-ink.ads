with Cairo;
with Coyote_Canvas.Revisions;

--  Geometry shared by canonical ink and the transient gesture.
package Coyote_Canvas.Ink is
   --  Set the source used by shared Cairo ink drawing procedures.
   procedure Set_Color
     (Context : Cairo.Cairo_Context; Color : Revisions.Ink_Color);

   --  Paint one round dot or pressure-weighted segment in source coordinates.
   procedure Draw_Dot
     (Point : Revisions.Sample; Context : Cairo.Cairo_Context);
   procedure Draw_Segment
     (Previous, Point : Revisions.Sample;
      Context : Cairo.Cairo_Context);

   --  Paint a stored stroke using the caller's source color and transform.
   procedure Draw
     (Points : Revisions.Samples.Vector; Context : Cairo.Cairo_Context;
      Rendering : Revisions.Stroke_Rendering := Revisions.Classic);
end Coyote_Canvas.Ink;
