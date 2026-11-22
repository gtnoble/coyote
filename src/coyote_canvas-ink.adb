with Ada.Numerics.Long_Elementary_Functions;
with Cairo.Pattern;
with Glib;

package body Coyote_Canvas.Ink is
   use type Glib.Gdouble;
   use type Cairo.Cairo_Status;
   use type Revisions.Stroke_Rendering;

   MINIMUM_SPACING : constant Long_Float := 0.25;
   MAXIMUM_STAMPS_PER_STROKE : constant Long_Float := 262_144.0;

   procedure Set_Color
     (Context : Cairo.Cairo_Context; Color : Revisions.Ink_Color)
   is
      Value : constant Natural := Natural (Color);
      Red   : constant Glib.Gdouble :=
        Glib.Gdouble ((Value / 65_536) mod 256) / 255.0;
      Green : constant Glib.Gdouble :=
        Glib.Gdouble ((Value / 256) mod 256) / 255.0;
      Blue  : constant Glib.Gdouble := Glib.Gdouble (Value mod 256) / 255.0;
   begin
      Cairo.Set_Source_Rgb (Context, Red, Green, Blue);
   end Set_Color;

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

   procedure Draw_Deposited
     (Points : Revisions.Samples.Vector; Context : Cairo.Cairo_Context)
   is
      Previous : Revisions.Sample;
      First    : Boolean := True;
      Spacing_Remaining : Long_Float := 0.0;
      Red, Green, Blue, Source_Alpha : aliased Glib.Gdouble := 0.0;
      Total_Distance : Long_Float := 0.0;
      Previous_Point : Revisions.Sample;
      Need_First : Boolean := True;
      Pitch : Long_Float;
   begin
      for Point of Points loop
         if Need_First then
            Previous_Point := Point;
            Need_First := False;
         else
            declare
               DX : constant Long_Float := Point.X - Previous_Point.X;
               DY : constant Long_Float := Point.Y - Previous_Point.Y;
            begin
               Total_Distance := Total_Distance +
                 Ada.Numerics.Long_Elementary_Functions.Sqrt
                   (DX * DX + DY * DY);
            end;
            Previous_Point := Point;
         end if;
      end loop;
      if Points.Is_Empty then
         return;
      end if;
      --  New gestures capture a single width. Bound the work over the
      --  whole path rather than changing pitch at input-event boundaries.
      Pitch := Long_Float'Max
        (Long_Float'Max (MINIMUM_SPACING, Points.First_Element.Width / 4.0),
         Total_Distance / MAXIMUM_STAMPS_PER_STROKE);
      if Cairo.Pattern.Get_Rgba
        (Cairo.Get_Source (Context), Red'Access, Green'Access,
         Blue'Access, Source_Alpha'Access) /= Cairo.Cairo_Status_Success
      then
         raise Program_Error with
           "Deposited ink requires a solid Cairo source color";
      end if;

      declare
         procedure Stamp (Point : Revisions.Sample) is
         begin
            if Point.Alpha > 0.0 then
               Cairo.Set_Source_Rgba
                 (Context, Red, Green, Blue,
                  Glib.Gdouble (Point.Alpha) * Source_Alpha);
               Cairo.Arc
                 (Context, Glib.Gdouble (Point.X), Glib.Gdouble (Point.Y),
                  Glib.Gdouble (Point.Width / 2.0),
                  0.0, 6.283_185_307_179_586);
               Cairo.Fill (Context);
            end if;
         end Stamp;
      begin
         for Point of Points loop
            if First then
               Stamp (Point);
               Spacing_Remaining := Pitch;
               First := False;
            else
               declare
                  DX : constant Long_Float := Point.X - Previous.X;
                  DY : constant Long_Float := Point.Y - Previous.Y;
                  Distance : constant Long_Float :=
                    Ada.Numerics.Long_Elementary_Functions.Sqrt
                   (DX * DX + DY * DY);
               begin
                  if Distance > 0.0 then
                     declare
                        Position : Long_Float := Spacing_Remaining;
                     begin
                        while Position <= Distance loop
                           declare
                              Fraction : constant Long_Float :=
                                Position / Distance;
                              Stamp_Point : constant Revisions.Sample :=
                                (X => Previous.X + DX * Fraction,
                                 Y => Previous.Y + DY * Fraction,
                                 Width => Previous.Width +
                                   (Point.Width - Previous.Width) * Fraction,
                                 Alpha => Revisions.Ink_Alpha
                                   (Long_Float (Previous.Alpha) +
                                     (Long_Float (Point.Alpha) -
                                      Long_Float (Previous.Alpha)) *
                                         Fraction));
                           begin
                              Stamp (Stamp_Point);
                           end;
                           Position := Position + Pitch;
                        end loop;
                        Spacing_Remaining := Position - Distance;
                     end;
                  end if;
               end;
            end if;
            Previous := Point;
         end loop;
      end;
   end Draw_Deposited;

   procedure Draw
     (Points : Revisions.Samples.Vector; Context : Cairo.Cairo_Context;
      Rendering : Revisions.Stroke_Rendering := Revisions.Classic)
   is
      Previous : Revisions.Sample := (0.0, 0.0, 1.0, 1.0);
      First    : Boolean := True;
   begin
      Cairo.Set_Line_Cap (Context, Cairo.Cairo_Line_Cap_Round);
      if Rendering = Revisions.Deposited then
         Draw_Deposited (Points, Context);
      else
         for Point of Points loop
            if First then
               Draw_Dot (Point, Context);
               First := False;
            else
               Draw_Segment (Previous, Point, Context);
            end if;
            Previous := Point;
         end loop;
      end if;
   end Draw;

end Coyote_Canvas.Ink;
