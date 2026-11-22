with Glib;

package body Coyote_Canvas.Ink is
   procedure Draw_Dot
     (Point : Revisions.Sample; Context : Cairo.Cairo_Context) is
   begin
      Cairo.Arc
        (Context, Glib.Gdouble (Point.X), Glib.Gdouble (Point.Y),
         Glib.Gdouble (Point.Width / 2.0), 0.0, 6.283_185_307_179_586);
      Cairo.Fill (Context);
   end Draw_Dot;

   procedure Draw_Segment
     (Previous, Point : Revisions.Sample;
      Context : Cairo.Cairo_Context) is
   begin
      Cairo.Set_Line_Width
        (Context, Glib.Gdouble ((Previous.Width + Point.Width) / 2.0));
      Cairo.Move_To
        (Context, Glib.Gdouble (Previous.X), Glib.Gdouble (Previous.Y));
      Cairo.Line_To
        (Context, Glib.Gdouble (Point.X), Glib.Gdouble (Point.Y));
      Cairo.Stroke (Context);
   end Draw_Segment;

   procedure Draw
     (Points : Revisions.Samples.Vector; Context : Cairo.Cairo_Context)
   is
      Previous : Revisions.Sample := (0.0, 0.0, 1.0);
      First    : Boolean := True;
   begin
      Cairo.Set_Line_Cap (Context, Cairo.Cairo_Line_Cap_Round);
      for Point of Points loop
         if First then
            Draw_Dot (Point, Context);
            First := False;
         else
            Draw_Segment (Previous, Point, Context);
         end if;
         Previous := Point;
      end loop;
   end Draw;

end Coyote_Canvas.Ink;
