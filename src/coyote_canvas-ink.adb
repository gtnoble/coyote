with Glib;

package body Coyote_Canvas.Ink is
   procedure Draw
     (Points : Revisions.Samples.Vector; Context : Cairo.Cairo_Context)
   is
      Prev  : Revisions.Sample := (0.0, 0.0, 1.0);
      First : Boolean    := True;
   begin
      Cairo.Set_Line_Cap (Context, Cairo.Cairo_Line_Cap_Round);
      for Point of Points loop
         if not First then
            Cairo.Set_Line_Width
              (Context, Glib.Gdouble ((Prev.Width + Point.Width) / 2.0));
            Cairo.Move_To
              (Context, Glib.Gdouble (Prev.X), Glib.Gdouble (Prev.Y));
            Cairo.Line_To
              (Context, Glib.Gdouble (Point.X), Glib.Gdouble (Point.Y));
            Cairo.Stroke (Context);
         else
            Cairo.Arc
              (Context, Glib.Gdouble (Point.X), Glib.Gdouble (Point.Y),
               Glib.Gdouble (Point.Width / 2.0), 0.0, 6.283_185_307_179_586);
            Cairo.Fill (Context);
         end if;
         Prev  := Point;
         First := False;
      end loop;
   end Draw;

end Coyote_Canvas.Ink;
