--  Coyote_SQC.UI.Chart_Canvas body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Numerics;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Cairo;                  use Cairo;
with Coyote_SQC.App;         use Coyote_SQC.App;
with Coyote_SQC.UI.Detail_Panel;
with Coyote_SQC.Charts;
with Coyote_SQC.UI.Hover_Tooltip;
with Coyote_SQC.UI.Toolbar;
with Gdk.Event;
with Gdk.Types;              use Gdk.Types;
with Glib;                   use Glib;
with Gtk.Drawing_Area;
with Gtk.Enums;
with Gtk.Widget;

package body Coyote_SQC.UI.Chart_Canvas is
   use type Gdk.Event.Gdk_Event_Mask;
   use type Coyote_SQC.App.App_State_Access;
   use type Gtk.Drawing_Area.Gtk_Drawing_Area;

   use Coyote_SQC.Charts;

   The_Canvas : Gtk.Drawing_Area.Gtk_Drawing_Area := null;

   --  Forward declarations.
   function  Hit_Test         (MX, MY : Long_Float) return String;
   function  Hit_Test         (MX, MY, Radius_Sq : Long_Float) return String;
   procedure Rubberband_Select;
   procedure Refresh_Detail;


   --  ── Coordinate transforms ─────────────────────────────────────────────

   function Plot_Width  return Long_Float is
     (Long_Float (State.Canvas_St.Width)
      - Long_Float (Margin_Left + Margin_Right));
   function Plot_Height return Long_Float is
     (Long_Float (State.Canvas_St.Height)
      - Long_Float (Margin_Top + Margin_Bottom));

   function Data_To_Screen_X (DX : Long_Float) return Long_Float is
      W : constant Long_Float := Plot_Width;
      R : constant Long_Float := State.Canvas_St.X_Max - State.Canvas_St.X_Min;
   begin
      if R = 0.0 then return Long_Float (Margin_Left); end if;
      return Long_Float (Margin_Left)
        + (DX - State.Canvas_St.X_Min) / R * W;
   end Data_To_Screen_X;

   function Data_To_Screen_Y (DY : Long_Float) return Long_Float is
      H : constant Long_Float := Plot_Height;
      R : constant Long_Float := State.Canvas_St.Y_Max - State.Canvas_St.Y_Min;
   begin
      if R = 0.0 then return Long_Float (Margin_Top); end if;
      --  Y screen is inverted.
      return Long_Float (Margin_Top)
        + (State.Canvas_St.Y_Max - DY) / R * H;
   end Data_To_Screen_Y;

   function Screen_To_Data_X (SX : Long_Float) return Long_Float is
      W : constant Long_Float := Plot_Width;
   begin
      if W = 0.0 then return State.Canvas_St.X_Min; end if;
      return State.Canvas_St.X_Min
        + (SX - Long_Float (Margin_Left)) / W
          * (State.Canvas_St.X_Max - State.Canvas_St.X_Min);
   end Screen_To_Data_X;

   function Screen_To_Data_Y (SY : Long_Float) return Long_Float is
      H : constant Long_Float := Plot_Height;
   begin
      if H = 0.0 then return State.Canvas_St.Y_Min; end if;
      return State.Canvas_St.Y_Max
        - (SY - Long_Float (Margin_Top)) / H
          * (State.Canvas_St.Y_Max - State.Canvas_St.Y_Min);
   end Screen_To_Data_Y;

   --  ── Time helpers ──────────────────────────────────────────────────────

   function Time_To_LF (T : Ada.Calendar.Time) return Long_Float is
      use Ada.Calendar;
      Epoch : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
   begin
      return Long_Float (T - Epoch);
   end Time_To_LF;

   function LF_To_Time (V : Long_Float) return Ada.Calendar.Time is
      use Ada.Calendar;
      Epoch : constant Ada.Calendar.Time :=
        Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
   begin
      return Epoch + Duration (V);
   end LF_To_Time;

   --  ── Run-sequence index helpers ────────────────────────────────────────

   --  Return the Ada.Calendar.Time of the session at run-index Idx.
   --  Rounds to the nearest integer index and clamps to [1, N_Sessions].
   function Run_Index_To_Time (Idx : Long_Float) return Ada.Calendar.Time is
      use Ada.Calendar;
      N : constant Natural := Natural (State.Sessions.Length);
      I : Integer;
   begin
      if N = 0 then
         return Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
      end if;
      I := Integer (Long_Float'Rounding (Idx));
      I := Integer'Max (1, Integer'Min (I, N));
      return State.Sessions (I).Start_Time;
   end Run_Index_To_Time;

   --  Return the 1-based run index (as Long_Float) of the session whose
   --  Start_Time is closest to T.  Returns 1.0 when Sessions is empty.
   function Time_To_Run_Index (T : Ada.Calendar.Time) return Long_Float is
      use Ada.Calendar;
      N        : constant Natural := Natural (State.Sessions.Length);
      Best_I   : Positive := 1;
      Best_Diff: Duration := Duration'Last;
   begin
      if N = 0 then return 1.0; end if;
      for I in State.Sessions.First_Index .. State.Sessions.Last_Index loop
         declare
            Diff : constant Duration :=
              abs (State.Sessions (I).Start_Time - T);
         begin
            if Diff < Best_Diff then
               Best_Diff := Diff;
               Best_I    := I;
            end if;
         end;
      end loop;
      return Long_Float (Best_I);
   end Time_To_Run_Index;

   --  Return the x-coordinate for a chart point in the current scale mode.
   --  Time Scale:    Unix seconds (same as Time_To_LF (P.Session_Time)).
   --  Run Sequence:  1-based integer run index (Long_Float (P.Session_Index)).
   function Point_X (P : Coyote_SQC.App.Chart_Point) return Long_Float is
   begin
      if State.Run_Sequence_Mode then
         return Long_Float (P.Session_Index);
      else
         return Time_To_LF (P.Session_Time);
      end if;
   end Point_X;

   --  Update State.Date_From/Date_To from the current X_Min/X_Max in
   --  Canvas_State, converting from the current coordinate space to
   --  Ada.Calendar.Time.
   procedure Update_Dates_From_X is
      CS : Canvas_State renames State.Canvas_St;
   begin
      if State.Run_Sequence_Mode then
         State.Date_From := Run_Index_To_Time (CS.X_Min);
         State.Date_To   := Run_Index_To_Time (CS.X_Max);
      else
         State.Date_From := LF_To_Time (CS.X_Min);
         State.Date_To   := LF_To_Time (CS.X_Max);
      end if;
   end Update_Dates_From_X;

   --  Format an x-coordinate value as "YYYY-MM-DD HH:MM", converting from
   --  the current scale mode (Unix seconds or run index) to a calendar time.
   --  Uses Ada.Calendar.Formatting.Image with Time_Zone => 0 (consistent with
   --  the rest of the codebase which stores times in local time).
   function Format_Tick_Label (V : Long_Float) return String is
      T   : Ada.Calendar.Time;
      Img : String (1 .. 19);  --  "YYYY-MM-DD HH:MM:SS"
   begin
      if State.Run_Sequence_Mode then
         T := Run_Index_To_Time (V);
      else
         T := LF_To_Time (V);
      end if;
      Img := Ada.Calendar.Formatting.Image
               (T,
                Include_Time_Fraction => False,
                Time_Zone             => 0);
      --  Return only the first 16 characters: "YYYY-MM-DD HH:MM"
      return Img (Img'First .. Img'First + 15);
   end Format_Tick_Label;


   --  ── Drawing utilities ─────────────────────────────────────────────────

   procedure Set_Color (Cr : Cairo_Context;
                        R, G, B, A : Gdouble) is
   begin
      Cairo.Set_Source_Rgba (Cr, R, G, B, A);
   end Set_Color;

   procedure Draw_Circle (Cr       : Cairo_Context;
                          SX, SY  : Gdouble;
                          Radius   : Gdouble;
                          Filled   : Boolean) is
   begin
      Cairo.Arc (Cr, SX, SY, Radius, 0.0,
                 Gdouble (2.0 * Ada.Numerics.Pi));
      if Filled then
         Cairo.Fill (Cr);
      else
         Cairo.Stroke (Cr);
      end if;
   end Draw_Circle;

   --  Format a data-space x value (Unix seconds) as "YYYY-MM-DD".
   function Format_Date (V : Long_Float) return String is
      use Ada.Calendar;
      use Ada.Strings.Fixed;
      T  : constant Ada.Calendar.Time := LF_To_Time (V);
      Y  : constant Year_Number  := Year  (T);
      Mo : constant Month_Number := Month (T);
      D  : constant Day_Number   := Day   (T);
   begin
      return Trim (Y'Image, Ada.Strings.Left)
        & "-" & (if Mo < 10 then "0" else "")
        & Trim (Mo'Image, Ada.Strings.Left)
        & "-" & (if D < 10 then "0" else "")
        & Trim (D'Image, Ada.Strings.Left);
   end Format_Date;

   --  Format a Y value for axis labels.
   function Format_Y (V : Long_Float) return String is
      use Ada.Strings.Fixed;
   begin
      if abs V >= 10000.0 then
         return Trim (Long_Long_Integer'Image (Long_Long_Integer (V)),
                      Ada.Strings.Left);
      elsif abs V >= 100.0 then
         return Trim (Long_Long_Integer'Image (Long_Long_Integer (V)),
                      Ada.Strings.Left);
      elsif abs V >= 1.0 then
         --  One decimal place.
         declare
            IV : constant Long_Long_Integer :=
              Long_Long_Integer (V * 10.0);
         begin
            return Trim (Long_Long_Integer'Image (IV / 10), Ada.Strings.Left)
              & "." & Trim (Long_Long_Integer'Image (abs (IV mod 10)),
                             Ada.Strings.Left);
         end;
      else
         --  Three decimal places.
         declare
            IV : constant Long_Long_Integer :=
              Long_Long_Integer (V * 1000.0);
         begin
            return "0."
              & (if abs (IV) < 100 then "0" else "")
              & (if abs (IV) < 10 then "0" else "")
              & Trim (Long_Long_Integer'Image (abs IV), Ada.Strings.Left);
         end;
      end if;
   end Format_Y;

   procedure Draw_Text (Cr    : Cairo_Context;
                        X, Y  : Gdouble;
                        Text  : String) is
   begin
      Cairo.Move_To (Cr, X, Y);
      Cairo.Show_Text (Cr, Text);
   end Draw_Text;

   --  ── Main render pipeline ─────────────────────────────────────────────

   function On_Draw
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Cr     : Cairo_Context) return Boolean
   is
      use Ada.Calendar;

      CD  : constant Coyote_SQC.App.Chart_Data :=
        State.Charts (State.Active_Chart);
      CS  : Canvas_State renames State.Canvas_St;
      W   : constant Gdouble :=
        Gdouble (Widget.Get_Allocated_Width);
      H   : constant Gdouble :=
        Gdouble (Widget.Get_Allocated_Height);
      PW  : constant Gdouble := Gdouble (Plot_Width);
      PH  : constant Gdouble := Gdouble (Plot_Height);
      ML  : constant Gdouble := Gdouble (Margin_Left);
      MT  : constant Gdouble := Gdouble (Margin_Top);
      MR  : constant Gdouble := W - Gdouble (Margin_Right);
      MB  : constant Gdouble := H - Gdouble (Margin_Bottom);

      X_Min : constant Long_Float := CS.X_Min;
      X_Max : constant Long_Float := CS.X_Max;
      Date_From_LF : constant Long_Float := Time_To_LF (State.Date_From);
      Date_To_LF   : constant Long_Float := Time_To_LF (State.Date_To);
      Props : constant Coyote_SQC.Charts.Chart_Properties :=
        Coyote_SQC.Charts.Properties (State.Active_Chart);

      Pt_Radius : constant Gdouble := 5.0;

      --  Vis: point should be drawn (either normal or hollow-gray).
      function Vis (P : Coyote_SQC.App.Chart_Point) return Boolean is
        ((not P.Excluded or else P.Hollow_Gray)
         and then Time_To_LF (P.Session_Time) >= Date_From_LF
         and then Time_To_LF (P.Session_Time) <= Date_To_LF);


      function SX (P : Coyote_SQC.App.Chart_Point) return Gdouble is
        (Gdouble (Data_To_Screen_X (Point_X (P))));
      function SY (P : Coyote_SQC.App.Chart_Point) return Gdouble is
        (Gdouble (Data_To_Screen_Y (P.Stat_Value)));

   begin
      --  Update canvas size from widget.
      CS.Width  := Gint (W);
      CS.Height := Gint (H);
      Cairo.Set_Font_Size (Cr, 11.0);

      --  ── 1. Clear ──────────────────────────────────────────────────────
      Set_Color (Cr, 1.0, 1.0, 1.0, 1.0);
      Cairo.Rectangle (Cr, ML, MT, PW, PH);
      Cairo.Fill (Cr);
      --  Margins: light gray.
      Set_Color (Cr, 0.95, 0.95, 0.95, 1.0);
      Cairo.Rectangle (Cr, 0.0, 0.0, W, MT);
      Cairo.Fill (Cr);
      Cairo.Rectangle (Cr, 0.0, MB, W, Gdouble (Margin_Bottom));
      Cairo.Fill (Cr);
      Cairo.Rectangle (Cr, 0.0, 0.0, ML, H);
      Cairo.Fill (Cr);
      Cairo.Rectangle (Cr, MR, 0.0, Gdouble (Margin_Right), H);
      Cairo.Fill (Cr);

      --  ── 2. Setup interval band ────────────────────────────────────────
      if not State.Workspace.Setup_Session_Ids.Is_Empty then
         declare
            S1 : Long_Float := Long_Float'Last;
            S2 : Long_Float := Long_Float'First;
         begin
            for P of CD.Points loop
               if P.In_Setup then
                  declare T : constant Long_Float := Point_X (P);
                  begin
                     if T < S1 then S1 := T; end if;
                     if T > S2 then S2 := T; end if;
                  end;
               end if;
            end loop;
            if S1 <= S2 then
               declare
                  BX1 : constant Gdouble :=
                    Gdouble'Max (ML,
                      Gdouble (Data_To_Screen_X (S1)));
                  BX2 : constant Gdouble :=
                    Gdouble'Min (ML + PW,
                      Gdouble (Data_To_Screen_X (S2)));
               begin
                  if BX2 > BX1 then
                     Set_Color (Cr, 1.0, 0.97, 0.6, 0.4);
                     Cairo.Rectangle (Cr, BX1, MT, BX2 - BX1, PH);
                     Cairo.Fill (Cr);
                  end if;
               end;
            end if;
         end;
      end if;

      Cairo.Save (Cr);
      Cairo.Rectangle (Cr, ML, MT, PW, PH);
      Cairo.Clip (Cr);
      --  ── 3. Connecting line ────────────────────────────────────────────
      Set_Color (Cr, 0.0, 0.0, 0.0, 0.7);
      Cairo.Set_Line_Width (Cr, 1.0);
      Cairo.Set_Dash (Cr, No_Dashes, 0.0);
      declare
         Need_Move : Boolean := True;  --  True = use Move_To for next point
      begin
         for P of CD.Points loop
            if not P.Excluded and then not P.Hollow_Gray and then not P.Single_Turn then
               if Need_Move then
                  Cairo.Move_To (Cr, SX (P), SY (P));
                  Need_Move := False;
               else
                  Cairo.Line_To (Cr, SX (P), SY (P));
               end if;
            else
               Need_Move := True;  --  Excluded or hollow-gray: break line
            end if;
         end loop;
      end;
      Cairo.Stroke (Cr);

      --  ── 4. Control limit series ───────────────────────────────────────
      declare
         Retro : constant Boolean := CD.Is_Retro;
         Dash  : constant Dash_Array := (1 => 6.0, 2 => 4.0);
         R, G, B : Gdouble;
      begin
         if Retro then
            R := 0.5; G := 0.5; B := 0.5;
         else
            R := 0.9; G := 0.1; B := 0.1;
         end if;
         Set_Color (Cr, R, G, B, 0.9);
         Cairo.Set_Line_Width (Cr, 1.5);
         Cairo.Set_Dash (Cr, Dash, 0.0);
         --  UCL
         declare Need_Move : Boolean := True; begin
            for P of CD.Points loop
               if not P.Excluded
                 and then not P.Hollow_Gray
                 and then not P.Single_Turn
                 and then P.Has_UCL
               then
                  if Need_Move then
                     Cairo.Move_To (Cr, SX (P),
                       Gdouble (Data_To_Screen_Y (P.UCL)));
                     Need_Move := False;
                  else
                     Cairo.Line_To (Cr, SX (P),
                       Gdouble (Data_To_Screen_Y (P.UCL)));
                  end if;
               else
                  Need_Move := True;
               end if;
            end loop;
         end;
         Cairo.Stroke (Cr);
         --  LCL (only when Has_LCL is True)
         declare Need_Move : Boolean := True; begin
            for P of CD.Points loop
               if not P.Excluded
                 and then not P.Hollow_Gray
                 and then not P.Single_Turn
                 and then P.Has_LCL
               then
                  if Need_Move then
                     Cairo.Move_To (Cr, SX (P),
                       Gdouble (Data_To_Screen_Y (P.LCL)));
                     Need_Move := False;
                  else
                     Cairo.Line_To (Cr, SX (P),
                       Gdouble (Data_To_Screen_Y (P.LCL)));
                  end if;
               else
                  Need_Move := True;
               end if;
            end loop;
         end;
         Cairo.Stroke (Cr);
         --  Retrospective limits label.
         if Retro then
            Set_Color (Cr, 0.5, 0.5, 0.5, 1.0);
            Cairo.Set_Dash (Cr, No_Dashes, 0.0);
            Draw_Text (Cr, ML + 4.0, MT + 14.0,
                       "retrospective limits");
         end if;
      end;

      --  ── 5. Center line (blue/gray) ────────────────────────────────────
      Cairo.Set_Line_Width (Cr, 1.5);
      Cairo.Set_Dash (Cr, No_Dashes, 0.0);
      if CD.Is_Retro then
         Set_Color (Cr, 0.5, 0.5, 0.5, 0.8);
      else
         Set_Color (Cr, 0.2, 0.4, 0.9, 0.8);
      end if;
      declare Need_Move : Boolean := True; begin
         for P of CD.Points loop
            if not P.Excluded and then not P.Hollow_Gray and then not P.Single_Turn then
               if Need_Move then
                  Cairo.Move_To (Cr, SX (P),
                    Gdouble (Data_To_Screen_Y (P.CL)));
                  Need_Move := False;
               else
                  Cairo.Line_To (Cr, SX (P),
                    Gdouble (Data_To_Screen_Y (P.CL)));
               end if;
            else
               Need_Move := True;
            end if;
         end loop;
      end;
      Cairo.Stroke (Cr);

      Cairo.Restore (Cr);
      --  ── 6. Point markers ─────────────────────────────────────────────
      --  Colors per §12.7. Separate fill/stroke where spec differs.
      Cairo.Set_Line_Width (Cr, 1.5);
      Cairo.Set_Dash (Cr, No_Dashes, 0.0);
      for P of CD.Points loop
         if Vis (P) then
            declare
               PX : constant Gdouble := SX (P);
               PY : constant Gdouble := SY (P);
               --  Draw_Filled: fill with (FR,FG,FB), stroke with (SR,SG,SB).
               procedure Draw_Filled
                 (FR, FG, FB : Gdouble;
                  SR, SG, SB : Gdouble)
               is
               begin
                  Cairo.Arc (Cr, PX, PY, Pt_Radius,
                             0.0, Gdouble (2.0 * Ada.Numerics.Pi));
                  Set_Color (Cr, FR, FG, FB, 1.0);
                  Cairo.Fill_Preserve (Cr);
                  Set_Color (Cr, SR, SG, SB, 1.0);
                  Cairo.Stroke (Cr);
               end Draw_Filled;
            begin
               if P.Hollow_Gray then
                  --  Zero-thinking excluded: hollow gray circle.
                  Set_Color (Cr, 0.6, 0.6, 0.6, 1.0);
                  Draw_Circle (Cr, PX, PY, Pt_Radius, False);

               elsif P.Single_Turn then
                  --  Single-turn on Xbar: hollow black circle.
                  Set_Color (Cr, 0.0, 0.0, 0.0, 1.0);
                  Draw_Circle (Cr, PX, PY, Pt_Radius, False);

               else
                  --  Normal filled circle; determine color.
                  declare
                     In_Ctrl : Boolean := True;
                  begin
                     if not P.Excluded and then P.Has_UCL then
                        In_Ctrl :=
                          P.Stat_Value <= P.UCL
                          and then (not P.Has_LCL
                             or else P.Stat_Value >= P.LCL);
                     end if;

                     if P.In_Setup then
                        --  Yellow; darker yellow stroke.
                        Draw_Filled (1.0, 0.85, 0.0,
                                     0.7, 0.60, 0.0);
                     elsif not In_Ctrl and then P.Has_Comment then
                        --  Orange; darker orange stroke.
                        Draw_Filled (0.95, 0.5, 0.0,
                                     0.7,  0.35, 0.0);
                     elsif not In_Ctrl then
                        --  Red; same stroke.
                        Draw_Filled (0.9, 0.1, 0.1,
                                     0.9, 0.1, 0.1);
                     else
                        --  In-control black; same stroke.
                        Draw_Filled (0.0, 0.0, 0.0,
                                     0.0, 0.0, 0.0);
                     end if;
                  end;
               end if;
            end;
         end if;
      end loop;

      --  ── 7. Rubber-band rectangle ──────────────────────────────────────
      if CS.Rubberband_Active then
         declare
            RX1 : constant Gdouble :=
              Gdouble (Long_Float'Min (CS.Rubberband_Start.X,
                                       CS.Rubberband_End.X));
            RY1 : constant Gdouble :=
              Gdouble (Long_Float'Min (CS.Rubberband_Start.Y,
                                       CS.Rubberband_End.Y));
            RW  : constant Gdouble :=
              Gdouble (abs (CS.Rubberband_End.X - CS.Rubberband_Start.X));
            RH  : constant Gdouble :=
              Gdouble (abs (CS.Rubberband_End.Y - CS.Rubberband_Start.Y));
         begin
            Set_Color (Cr, 0.7, 0.7, 1.0, 0.15);
            Cairo.Rectangle (Cr, RX1, RY1, RW, RH);
            Cairo.Fill (Cr);
            Set_Color (Cr, 0.3, 0.3, 0.3, 0.8);
            Cairo.Set_Dash (Cr, (1 => 4.0, 2 => 3.0), 0.0);
            Cairo.Set_Line_Width (Cr, 1.0);
            Cairo.Rectangle (Cr, RX1, RY1, RW, RH);
            Cairo.Stroke (Cr);
            Cairo.Set_Dash (Cr, No_Dashes, 0.0);
         end;
      end if;

      --  ── 8. Selection halos ────────────────────────────────────────────
      Set_Color (Cr, 0.1, 0.3, 0.9, 0.9);
      Cairo.Set_Line_Width (Cr, 2.0);
      for P of CD.Points loop
         if Vis (P)
           and then State.Selection.Contains (P.Session_Id)
         then
            Cairo.Arc (Cr, SX (P), SY (P), Pt_Radius + 3.0, 0.0,
                       Gdouble (2.0 * Ada.Numerics.Pi));
            Cairo.Stroke (Cr);
         end if;
      end loop;

      --  ── 9. Axes ───────────────────────────────────────────────────────
      Set_Color (Cr, 0.0, 0.0, 0.0, 1.0);
      Cairo.Set_Line_Width (Cr, 1.0);
      --  X axis.
      Cairo.Move_To (Cr, ML, MB);
      Cairo.Line_To (Cr, MR, MB);
      Cairo.Stroke (Cr);
      --  Y axis.
      Cairo.Move_To (Cr, ML, MT);
      Cairo.Line_To (Cr, ML, MB);
      Cairo.Stroke (Cr);

      --  X tick marks and labels (density scaled to plot width).
      --  In Time Scale mode: tick values are Unix seconds; labels formatted
      --  as "YYYY-MM-DD HH:MM".  In Run Sequence mode: ticks at integer run
      --  indices; labels show the Start_Time of the session at each index,
      --  formatted as "YYYY-MM-DD HH:MM".
      declare
         --  Target ~140px per x-tick to fit the longer label; min 2, max 10.
         N_Ticks : constant Natural :=
           Natural'Max (2, Natural'Min (10,
             Natural (Plot_Width / 140.0)));
         Step    : constant Long_Float :=
           (X_Max - X_Min) / Long_Float (N_Ticks);
      begin
         for I in 0 .. N_Ticks loop
            declare
               V   : constant Long_Float := X_Min + Long_Float (I) * Step;
               TX  : constant Gdouble    := Gdouble (Data_To_Screen_X (V));
               Lbl : constant String     := Format_Tick_Label (V);
            begin
               Set_Color (Cr, 0.0, 0.0, 0.0, 0.8);
               Cairo.Move_To (Cr, TX, MB);
               Cairo.Line_To (Cr, TX, MB + 5.0);
               Cairo.Stroke (Cr);
               Draw_Text (Cr, TX - 56.0, MB + 16.0, Lbl);
            end;
         end loop;
      end;

      --  Y tick marks and value labels (density scaled to plot height).
      declare
         N_Ticks : constant Natural :=
           Natural'Max (2, Natural'Min (10,
             Natural (Plot_Height / 50.0)));
         Step    : constant Long_Float :=
           (CS.Y_Max - CS.Y_Min) / Long_Float (N_Ticks);
      begin
         for I in 0 .. N_Ticks loop
            declare
               V   : constant Long_Float := CS.Y_Min + Long_Float (I) * Step;
               TY  : constant Gdouble    := Gdouble (Data_To_Screen_Y (V));
               Lbl : constant String     := Format_Y (V);
            begin
               Set_Color (Cr, 0.0, 0.0, 0.0, 0.8);
               Cairo.Move_To (Cr, ML, TY);
               Cairo.Line_To (Cr, ML - 5.0, TY);
               Cairo.Stroke (Cr);
               Draw_Text (Cr, 2.0, TY + 4.0, Lbl);
            end;
         end loop;
      end;
      --  Y-axis label (rotated).
      declare
         Y_Label : constant String := To_String (Props.Y_Axis_Label);
      begin
         Cairo.Save (Cr);
         Cairo.Translate (Cr, 12.0, MT + PH / 2.0);
         Cairo.Rotate (Cr, Gdouble (-Ada.Numerics.Pi / 2.0));
         Draw_Text (Cr, -Gdouble (Y_Label'Length) * 3.0, 0.0, Y_Label);
         Cairo.Restore (Cr);
      end;

      --  X-axis label "Date" centered below tick labels (§12.6 step 10).
      Set_Color (Cr, 0.0, 0.0, 0.0, 0.8);
      Draw_Text (Cr,
                 ML + PW / 2.0 - 12.0,
                 MB + 35.0,
                 "Date");
      return False;
   end On_Draw;

   --  ── Mouse events ──────────────────────────────────────────────────────

   function On_Button_Press
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      pragma Unreferenced (Widget);
      CS : Canvas_State renames State.Canvas_St;
      MX : constant Long_Float := Long_Float (Event.X);
      MY : constant Long_Float := Long_Float (Event.Y);
      In_Plot : constant Boolean :=
        MX >= Long_Float (Margin_Left)
        and then MX <= Long_Float (CS.Width) - Long_Float (Margin_Right)
        and then MY >= Long_Float (Margin_Top)
        and then MY <= Long_Float (CS.Height) - Long_Float (Margin_Bottom);
   begin
      if State = null then return False; end if;

      if Event.Button = 1 then
         --  Check hit testing.
         declare
            Hit_Id : constant String := Hit_Test (MX, MY);
         begin
            if Hit_Id'Length > 0 then
               --  Click on a point.
               declare
                  SID : constant Unbounded_String :=
                    To_Unbounded_String (Hit_Id);
               begin
                  if (Event.State and Shift_Mask) /= 0 then
                     --  Add/remove from selection.
                     if State.Selection.Contains (SID) then
                        State.Selection.Delete (SID);
                     else
                        State.Selection.Include (SID);
                     end if;
                  else
                     State.Selection.Clear;
                     State.Selection.Include (SID);
                  end if;
               end;
               Refresh_Detail;
               Queue_Redraw;
            elsif In_Plot then
               --  Start drag or rubber-band.
               if (Event.State and Shift_Mask) /= 0 then
                  CS.Rubberband_Active := True;
                  CS.Rubberband_Start  := (MX, MY);
                  CS.Rubberband_End    := (MX, MY);
               else
                  CS.Drag_Active  := True;
                  CS.Drag_Start   := (MX, MY);
                  CS.Drag_X_Min   := CS.X_Min;
                  CS.Drag_X_Max   := CS.X_Max;
                  CS.Drag_Y_Min   := CS.Y_Min;
                  CS.Drag_Y_Max   := CS.Y_Max;
               end if;
            else
               --  Click on empty area: clear selection.
               State.Selection.Clear;
               Refresh_Detail;
               Queue_Redraw;
            end if;
         end;
      end if;
      return False;
   end On_Button_Press;

   function On_Button_Release
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      pragma Unreferenced (Widget, Event);
      CS : Canvas_State renames State.Canvas_St;
   begin
      if State = null then return False; end if;
      if CS.Drag_Active then
         CS.Drag_Active := False;
      end if;
      if CS.Rubberband_Active then
         --  Select all points in the rubber-band rectangle.
         Rubberband_Select;
         CS.Rubberband_Active := False;
         Refresh_Detail;
         Queue_Redraw;
      end if;
      return False;
   end On_Button_Release;

   function On_Motion
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event_Motion) return Boolean
   is
      pragma Unreferenced (Widget);
      CS : Canvas_State renames State.Canvas_St;
      MX : constant Long_Float := Long_Float (Event.X);
      MY : constant Long_Float := Long_Float (Event.Y);
   begin
      if State = null then return False; end if;

      if CS.Drag_Active then
         --  Pan: dx/dy in data space.
         declare
            PW : constant Long_Float := Plot_Width;
            PH : constant Long_Float := Plot_Height;
            DX_D : constant Long_Float :=
              (MX - CS.Drag_Start.X) / PW
              * (CS.Drag_X_Max - CS.Drag_X_Min);
            DY_D : constant Long_Float :=
              (MY - CS.Drag_Start.Y) / PH
              * (CS.Drag_Y_Max - CS.Drag_Y_Min);
         begin
            CS.X_Min := CS.Drag_X_Min - DX_D;
            CS.X_Max := CS.Drag_X_Max - DX_D;
            CS.Y_Min := CS.Drag_Y_Min + DY_D;
            CS.Y_Max := CS.Drag_Y_Max + DY_D;
            State.Date_From := LF_To_Time (CS.X_Min);
            Update_Dates_From_X;
            Queue_Redraw;
         end;

      elsif CS.Rubberband_Active then
         CS.Rubberband_End := (MX, MY);
         Queue_Redraw;

      else
         --  Hit test for hover (§11.8 / §12.5).
         --  Show at 6 px; dismiss when beyond 12 px (hysteresis).
         declare
            Dismiss_Sq : constant Long_Float := 144.0;  -- 12 px^2
            Hit_Id     : constant String     := Hit_Test (MX, MY);
         begin
            if Hit_Id'Length > 0 then
               --  New hit within 6 px: show/refresh tooltip.
               if To_String (CS.Hovered_Session_Id) /= Hit_Id then
                  CS.Hovered_Session_Id := To_Unbounded_String (Hit_Id);
                  Coyote_SQC.UI.Hover_Tooltip.Show_For_Session
                    (Hit_Id, MX, MY);
               end if;
            elsif To_String (CS.Hovered_Session_Id) /= "" then
               --  No hit within 6 px; check 12 px for current hovered point.
               declare
                  Still_Id : constant String :=
                    Hit_Test (MX, MY, Dismiss_Sq);
               begin
                  if To_String (CS.Hovered_Session_Id) /= Still_Id then
                     CS.Hovered_Session_Id := Null_Unbounded_String;
                     Coyote_SQC.UI.Hover_Tooltip.Hide;
                  end if;
               end;
            end if;
         end;
      end if;
      return False;
   end On_Motion;

   function On_Scroll
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event_Scroll) return Boolean
   is
      pragma Unreferenced (Widget);
      CS : Canvas_State renames State.Canvas_St;
      MX : constant Long_Float := Long_Float (Event.X);
      MY : constant Long_Float := Long_Float (Event.Y);
      In_Y_Margin : constant Boolean := MX < Long_Float (Margin_Left);

      Factor : Long_Float;
      CX_Data, CY_Data : Long_Float;
   begin
      if State = null then return False; end if;

      case Event.Direction is
         when Gdk.Event.Scroll_Up   => Factor := 1.15;
         when Gdk.Event.Scroll_Down => Factor := 1.0 / 1.15;
         when others => return False;
      end case;

      if In_Y_Margin then
         --  Y-axis zoom.
         CY_Data := Screen_To_Data_Y (MY);
         CS.Y_Min := CY_Data + (CS.Y_Min - CY_Data) / Factor;
         CS.Y_Max := CY_Data + (CS.Y_Max - CY_Data) / Factor;
      else
         --  X-axis zoom.
         CX_Data := Screen_To_Data_X (MX);
         CS.X_Min := CX_Data + (CS.X_Min - CX_Data) / Factor;
         CS.X_Max := CX_Data + (CS.X_Max - CX_Data) / Factor;
         Update_Dates_From_X;
         Coyote_SQC.UI.Toolbar.Sync_Pickers;
      end if;

      Queue_Redraw;
      return False;
   end On_Scroll;


   --  (On_Size_Allocate replaced by Get_Allocated_Width/Height in On_Draw.)

   --  ── Hit testing ───────────────────────────────────────────────────────

   --  Overload with explicit radius; default 6 px (radius_sq = 36).
   function Hit_Test (MX, MY : Long_Float) return String is
   begin
      return Hit_Test (MX, MY, 36.0);
   end Hit_Test;

   function Hit_Test (MX, MY, Radius_Sq : Long_Float) return String is
      CD : constant Chart_Data := State.Charts (State.Active_Chart);
      Date_From_LF : constant Long_Float := Time_To_LF (State.Date_From);
      Date_To_LF   : constant Long_Float := Time_To_LF (State.Date_To);
   begin
      for P of CD.Points loop
         if (not P.Excluded or else P.Hollow_Gray)
           and then Time_To_LF (P.Session_Time) >= Date_From_LF
           and then Time_To_LF (P.Session_Time) <= Date_To_LF
         then
            declare
               PX : constant Long_Float :=
                 Data_To_Screen_X (Point_X (P));
               PY : constant Long_Float := Data_To_Screen_Y (P.Stat_Value);
               D2 : constant Long_Float :=
                 (MX - PX) ** 2 + (MY - PY) ** 2;
            begin
               if D2 <= Radius_Sq then
                  return To_String (P.Session_Id);
               end if;
            end;
         end if;
      end loop;
      return "";
   end Hit_Test;

   --  ── Rubber-band selection ─────────────────────────────────────────────

   procedure Rubberband_Select is
      CS  : Canvas_State renames State.Canvas_St;
      CD  : constant Chart_Data := State.Charts (State.Active_Chart);
      X1  : constant Long_Float :=
        Long_Float'Min (CS.Rubberband_Start.X, CS.Rubberband_End.X);
      X2  : constant Long_Float :=
        Long_Float'Max (CS.Rubberband_Start.X, CS.Rubberband_End.X);
      Y1  : constant Long_Float :=
        Long_Float'Min (CS.Rubberband_Start.Y, CS.Rubberband_End.Y);
      Y2  : constant Long_Float :=
        Long_Float'Max (CS.Rubberband_Start.Y, CS.Rubberband_End.Y);
      Date_From_LF : constant Long_Float := Time_To_LF (State.Date_From);
      Date_To_LF   : constant Long_Float := Time_To_LF (State.Date_To);
   begin
      for P of CD.Points loop
         if (not P.Excluded or else P.Hollow_Gray)
           and then Time_To_LF (P.Session_Time) >= Date_From_LF
           and then Time_To_LF (P.Session_Time) <= Date_To_LF
         then
            declare
               PX : constant Long_Float :=
                 Data_To_Screen_X (Point_X (P));
               PY : constant Long_Float := Data_To_Screen_Y (P.Stat_Value);
            begin
               if PX >= X1 and then PX <= X2
                 and then PY >= Y1 and then PY <= Y2
               then
                  State.Selection.Include (P.Session_Id);
               end if;
            end;
         end if;
      end loop;
   end Rubberband_Select;

   --  ── Refresh_Detail forward ref ────────────────────────────────────────
   --  Calls Detail_Panel.Refresh without a forward declaration issue.

   procedure Refresh_Detail is
   begin
      Coyote_SQC.UI.Detail_Panel.Refresh;
   end Refresh_Detail;

   --  ── Build ─────────────────────────────────────────────────────────────

   function Build return Gtk.Drawing_Area.Gtk_Drawing_Area is
      use Gtk.Drawing_Area;
      use Gtk.Enums;
   begin
      Gtk.Drawing_Area.Gtk_New (The_Canvas);
      The_Canvas.Set_Can_Focus (True);

      --  Enable events.
      The_Canvas.Add_Events
        (Gdk.Event.Button_Press_Mask
         or Gdk.Event.Button_Release_Mask
         or Gdk.Event.Pointer_Motion_Mask
         or Gdk.Event.Scroll_Mask);

      --  Connect signals.
      The_Canvas.On_Draw             (On_Draw'Access);
      The_Canvas.On_Button_Press_Event  (On_Button_Press'Access);
      The_Canvas.On_Button_Release_Event (On_Button_Release'Access);
      The_Canvas.On_Motion_Notify_Event (On_Motion'Access);
      The_Canvas.On_Scroll_Event        (On_Scroll'Access);

      Coyote_SQC.UI.Hover_Tooltip.Attach (The_Canvas);

      --  Set default size.
      State.Canvas_St.Width  := 600;
      State.Canvas_St.Height := 400;

      return The_Canvas;
   end Build;

   procedure Queue_Redraw is
   begin
      if The_Canvas /= null then
         The_Canvas.Queue_Draw;
      end if;
   end Queue_Redraw;

   procedure Reset_View is
      use Ada.Calendar;
      N : constant Natural := Natural (State.Sessions.Length);
   begin
      if State = null then return; end if;
      --  X: span all visible sessions in the current scale mode.
      if State.Sessions.Is_Empty then
         State.Canvas_St.X_Min := 0.0;
         State.Canvas_St.X_Max := 1.0;
      elsif State.Run_Sequence_Mode then
         State.Canvas_St.X_Min := 1.0;
         State.Canvas_St.X_Max := Long_Float (N);
         if State.Canvas_St.X_Min >= State.Canvas_St.X_Max then
            State.Canvas_St.X_Max := State.Canvas_St.X_Min + 1.0;
         end if;
      else
         State.Canvas_St.X_Min :=
           Time_To_LF (State.Sessions.First_Element.Start_Time);
         State.Canvas_St.X_Max :=
           Time_To_LF (State.Sessions.Last_Element.Start_Time);
         if State.Canvas_St.X_Min >= State.Canvas_St.X_Max then
            State.Canvas_St.X_Max := State.Canvas_St.X_Min + 86400.0;
         end if;
      end if;
      State.Canvas_St.Y_Min := 0.0;
      State.Canvas_St.Y_Max := 1.0;
      Update_Dates_From_X;
      Coyote_SQC.App.Y_Fit;
      Queue_Redraw;
   end Reset_View;

   procedure Sync_X_From_Dates is
      CS : Canvas_State renames State.Canvas_St;
   begin
      if State = null then return; end if;
      if State.Run_Sequence_Mode then
         CS.X_Min := Time_To_Run_Index (State.Date_From);
         CS.X_Max := Time_To_Run_Index (State.Date_To);
         if CS.X_Min >= CS.X_Max then
            CS.X_Max := CS.X_Min + 1.0;
         end if;
      else
         CS.X_Min := Time_To_LF (State.Date_From);
         CS.X_Max := Time_To_LF (State.Date_To);
         if CS.X_Min >= CS.X_Max then
            CS.X_Max := CS.X_Min + 86400.0;
         end if;
      end if;
   end Sync_X_From_Dates;


   procedure Switch_X_Scale_Mode (New_Run_Sequence : Boolean) is
      CS : Canvas_State renames State.Canvas_St;
   begin
      if State = null then return; end if;
      if State.Run_Sequence_Mode = New_Run_Sequence then return; end if;
      --  Convert viewport from old coordinate space to new before flipping
      --  the mode flag so the helpers still interpret current values correctly.
      if not State.Run_Sequence_Mode and then New_Run_Sequence then
         --  Time Scale → Run Sequence: convert Unix-second X range to indices.
         CS.X_Min := Time_To_Run_Index (LF_To_Time (CS.X_Min));
         CS.X_Max := Time_To_Run_Index (LF_To_Time (CS.X_Max));
      else
         --  Run Sequence → Time Scale: convert index X range to Unix seconds.
         CS.X_Min := Time_To_LF (Run_Index_To_Time (CS.X_Min));
         CS.X_Max := Time_To_LF (Run_Index_To_Time (CS.X_Max));
      end if;
      State.Run_Sequence_Mode := New_Run_Sequence;
      Update_Dates_From_X;
      Coyote_SQC.UI.Toolbar.Sync_Pickers;
      Queue_Redraw;
   end Switch_X_Scale_Mode;

end Coyote_SQC.UI.Chart_Canvas;
