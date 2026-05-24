--  Coyote_SQC.UI.Histogram_Canvas body.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Cairo;                  use Cairo;
with Glib;                   use Glib;
with Gtk.Drawing_Area;
with Gtk.Widget;

package body Coyote_SQC.UI.Histogram_Canvas is

   use type Gtk.Drawing_Area.Gtk_Drawing_Area;

   --  ── Module-level state ────────────────────────────────────────────────

   package Long_Float_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Long_Float);

   Hist_Values   : Long_Float_Vectors.Vector;
   Hist_CL       : Long_Float := 0.0;
   Hist_UCL      : Long_Float := 0.0;
   Hist_LCL      : Long_Float := 0.0;
   Hist_Has_UCL  : Boolean := False;
   Hist_Has_LCL  : Boolean := False;
   Hist_X_Label  : Unbounded_String;
   Hist_Has_Data : Boolean := False;

   The_Widget : Gtk.Drawing_Area.Gtk_Drawing_Area := null;

   --  ── Drawing helpers ───────────────────────────────────────────────────

   procedure Set_Color
     (Cr : Cairo_Context; R, G, B : Gdouble; A : Gdouble := 1.0) is
   begin
      Cairo.Set_Source_Rgba (Cr, R, G, B, A);
   end Set_Color;

   procedure Draw_Text
     (Cr   : Cairo_Context;
      X, Y : Gdouble;
      Text : String) is
   begin
      Cairo.Move_To (Cr, X, Y);
      Cairo.Show_Text (Cr, Text);
   end Draw_Text;

   --  Format a Long_Float value for an axis tick label.
   --  Values with |V| >= 10 are rounded to integers; smaller values are
   --  shown with one or three decimal places.  Non-finite or out-of-range
   --  values are rendered via Long_Float'Image as a safe fallback.
   --
   --  Safe_Max is a conservative ceiling well below Long_Long_Integer'Last
   --  to avoid IEEE 754 rounding issues (Long_Float (Long_Long_Integer'Last)
   --  rounds up to 2**63, which itself overflows Long_Long_Integer).
   function Format_Value (V : Long_Float) return String is
      use Ada.Strings.Fixed;
      use Ada.Strings;
      Safe_Max : constant Long_Float := 1.0e15;
   begin
      if not V'Valid or else abs V > Safe_Max then
         return Trim (Long_Float'Image (V), Left);
      end if;
      declare
         IV : constant Long_Long_Integer := Long_Long_Integer (V);
      begin
         if abs V >= 10.0 then
            return Trim (Long_Long_Integer'Image (IV), Left);
         elsif abs V >= 0.1 then
            declare
               Frac : constant Long_Long_Integer :=
                 Long_Long_Integer (abs (V - Long_Float (IV)) * 10.0);
            begin
               return Trim (Long_Long_Integer'Image (IV), Left)
                 & "." & Trim (Long_Long_Integer'Image (abs Frac), Left);
            end;
         else
            declare
               Frac : constant Long_Long_Integer :=
                 Long_Long_Integer (abs (V - Long_Float (IV)) * 1000.0);
            begin
               return Trim (Long_Long_Integer'Image (IV), Left)
                 & "." & Trim (Long_Long_Integer'Image (abs Frac), Left);
            end;
         end if;
      end;
   end Format_Value;

   --  ── Draw callback ─────────────────────────────────────────────────────

   function On_Histogram_Draw
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Cr     : Cairo_Context) return Boolean
   is
      W  : constant Gdouble := Gdouble (Widget.Get_Allocated_Width);
      H  : constant Gdouble := Gdouble (Widget.Get_Allocated_Height);
      ML : constant Gdouble := 38.0;
      MR : constant Gdouble :=  8.0;
      MT : constant Gdouble :=  8.0;
      MB : constant Gdouble := 28.0;
      PW : constant Gdouble := W - ML - MR;
      PH : constant Gdouble := H - MT - MB;

      --  Data-value to screen-x, given a fixed range.
      function Sx
        (V           : Long_Float;
         Bin_Min_V   : Long_Float;
         Total_Range : Long_Float) return Gdouble
      is (if Total_Range = 0.0 then ML + PW / 2.0
          else ML + Gdouble ((V - Bin_Min_V) / Total_Range) * PW);

      --  Count to screen-y (0 = bottom, max = top of plot).
      function Sy (C : Natural; Max_Count_V : Natural) return Gdouble is
        (if Max_Count_V = 0 then MT + PH
         else MT + PH - Gdouble (C) / Gdouble (Max_Count_V) * PH);

   begin
      Cairo.Set_Font_Size (Cr, 10.0);

      --  ── Clear ──────────────────────────────────────────────────────────
      Set_Color (Cr, 1.0, 1.0, 1.0);
      Cairo.Rectangle (Cr, 0.0, 0.0, W, H);
      Cairo.Fill (Cr);

      --  Light-gray margin areas.
      Set_Color (Cr, 0.95, 0.95, 0.95);
      Cairo.Rectangle (Cr, 0.0, 0.0, ML, H);
      Cairo.Fill (Cr);
      Cairo.Rectangle (Cr, 0.0, 0.0, W, MT);
      Cairo.Fill (Cr);
      Cairo.Rectangle (Cr, 0.0, H - MB, W, MB);
      Cairo.Fill (Cr);
      Cairo.Rectangle (Cr, W - MR, 0.0, MR, H);
      Cairo.Fill (Cr);

      --  ── No data ────────────────────────────────────────────────────────
      if not Hist_Has_Data or else Hist_Values.Is_Empty then
         Set_Color (Cr, 0.45, 0.45, 0.45);
         Draw_Text (Cr,
                    W / 2.0 - 72.0,
                    H / 2.0 + 4.0,
                    "No data for active chart");
         return True;
      end if;

      --  ── Build value array ──────────────────────────────────────────────
      declare
         N    : constant Positive := Positive (Hist_Values.Length);
         Vals : Long_Float_Array (1 .. N);
      begin
         for I in 1 .. N loop
            Vals (I) := Hist_Values (I);
         end loop;

         declare
            N_Bins      : Positive;
            Bin_Min_V   : Long_Float;
            Bin_Width_V : Long_Float;
            Counts      : Bin_Count_Array;
            Max_Count_V : Natural := 0;
         begin
            Compute_Bins (Vals, N_Bins, Bin_Min_V, Bin_Width_V, Counts);
            for I in 1 .. N_Bins loop
               if Counts (I) > Max_Count_V then
                  Max_Count_V := Counts (I);
               end if;
            end loop;

            declare
               Total_Range : constant Long_Float :=
                 Long_Float (N_Bins) * Bin_Width_V;
               Bar_W       : constant Gdouble :=
                 PW / Gdouble (N_Bins);

               --  ── Horizontal grid / y-axis tick labels ──────────────
               procedure Draw_Grid_And_Labels is
               begin
                  for Step in 0 .. 2 loop
                     declare
                        C   : constant Natural :=
                          (case Step is
                             when 0      => 0,
                             when 1      => Max_Count_V / 2,
                             when others => Max_Count_V);
                        TY  : constant Gdouble := Sy (C, Max_Count_V);
                        Lbl : constant String  :=
                          Ada.Strings.Fixed.Trim
                            (Natural'Image (C), Ada.Strings.Left);
                     begin
                        Set_Color (Cr, 0.82, 0.82, 0.82);
                        Cairo.Set_Line_Width (Cr, 1.0);
                        Cairo.Set_Dash (Cr, (1 => 3.0, 2 => 3.0), 0.0);
                        Cairo.Move_To (Cr, ML, TY);
                        Cairo.Line_To (Cr, W - MR, TY);
                        Cairo.Stroke (Cr);
                        Cairo.Set_Dash (Cr, No_Dashes, 0.0);
                        Set_Color (Cr, 0.3, 0.3, 0.3);
                        Draw_Text (Cr,
                                   ML - Gdouble (Lbl'Length) * 6.0 - 2.0,
                                   TY + 4.0,
                                   Lbl);
                     end;
                  end loop;
               end Draw_Grid_And_Labels;

               --  ── Bars ──────────────────────────────────────────────
               procedure Draw_Bars is
               begin
                  Set_Color (Cr, 0.27, 0.51, 0.71);
                  for I in 1 .. N_Bins loop
                     declare
                        BX1 : constant Gdouble :=
                          ML + Gdouble (I - 1) * Bar_W + 1.0;
                        BX2 : constant Gdouble :=
                          ML + Gdouble (I) * Bar_W - 1.0;
                        BY  : constant Gdouble :=
                          Sy (Counts (I), Max_Count_V);
                        Bot : constant Gdouble := MT + PH;
                     begin
                        if BX2 > BX1 and then BY < Bot then
                           Cairo.Rectangle
                             (Cr, BX1, BY, BX2 - BX1, Bot - BY);
                           Cairo.Fill (Cr);
                        end if;
                     end;
                  end loop;
               end Draw_Bars;

               --  ── X-axis ticks (left, centre, right) ───────────────
               procedure Draw_X_Ticks is
               begin
                  for Step in 0 .. 2 loop
                     declare
                        V   : constant Long_Float :=
                          Bin_Min_V
                          + Long_Float (Step) * Long_Float (N_Bins) / 2.0
                            * Bin_Width_V;
                        TX  : constant Gdouble :=
                          Sx (V, Bin_Min_V, Total_Range);
                        Lbl : constant String   := Format_Value (V);
                        LW  : constant Gdouble  :=
                          Gdouble (Lbl'Length) * 5.5;
                     begin
                        Set_Color (Cr, 0.0, 0.0, 0.0);
                        Cairo.Move_To (Cr, TX, MT + PH);
                        Cairo.Line_To (Cr, TX, MT + PH + 4.0);
                        Cairo.Stroke (Cr);
                        Set_Color (Cr, 0.3, 0.3, 0.3);
                        Draw_Text (Cr,
                                   TX - LW / 2.0,
                                   MT + PH + 14.0,
                                   Lbl);
                     end;
                  end loop;
               end Draw_X_Ticks;

               --  ── Overlay lines ─────────────────────────────────────
               procedure Draw_Overlays is
                  X_Lo : constant Long_Float :=
                    Bin_Min_V - Bin_Width_V * 0.5;
                  X_Hi : constant Long_Float :=
                    Bin_Min_V + Total_Range + Bin_Width_V * 0.5;

                  procedure Vline
                    (V     : Long_Float;
                     Solid : Boolean;
                     R, G, B : Gdouble;
                     Width : Gdouble) is
                  begin
                     if V < X_Lo or else V > X_Hi then return; end if;
                     declare
                        TX : constant Gdouble :=
                          Sx (V, Bin_Min_V, Total_Range);
                     begin
                        Set_Color (Cr, R, G, B);
                        Cairo.Set_Line_Width (Cr, Width);
                        if Solid then
                           Cairo.Set_Dash (Cr, No_Dashes, 0.0);
                        else
                           Cairo.Set_Dash (Cr, (1 => 4.0, 2 => 3.0), 0.0);
                        end if;
                        Cairo.Move_To (Cr, TX, MT);
                        Cairo.Line_To (Cr, TX, MT + PH);
                        Cairo.Stroke (Cr);
                        Cairo.Set_Dash (Cr, No_Dashes, 0.0);
                     end;
                  end Vline;

               begin
                  if Hist_Has_UCL then
                     Vline (Hist_UCL, False, 0.85, 0.1, 0.1, 1.0);
                  end if;
                  if Hist_Has_LCL and then Hist_LCL > 0.0 then
                     Vline (Hist_LCL, False, 0.85, 0.1, 0.1, 1.0);
                  end if;
                  Vline (Hist_CL, True, 0.1, 0.3, 0.8, 1.5);
               end Draw_Overlays;

            begin
               Draw_Grid_And_Labels;
               Draw_Bars;

               --  Axes.
               Set_Color (Cr, 0.0, 0.0, 0.0);
               Cairo.Set_Line_Width (Cr, 1.0);
               Cairo.Move_To (Cr, ML, MT);
               Cairo.Line_To (Cr, ML, MT + PH);
               Cairo.Stroke (Cr);
               Cairo.Move_To (Cr, ML, MT + PH);
               Cairo.Line_To (Cr, W - MR, MT + PH);
               Cairo.Stroke (Cr);

               Draw_X_Ticks;

               --  X-axis label centred below tick labels.
               declare
                  Lbl : constant String := To_String (Hist_X_Label);
                  LW  : constant Gdouble := Gdouble (Lbl'Length) * 5.5;
               begin
                  Set_Color (Cr, 0.3, 0.3, 0.3);
                  Draw_Text (Cr,
                             ML + PW / 2.0 - LW / 2.0,
                             MT + PH + 26.0,
                             Lbl);
               end;

               Draw_Overlays;
            end;
         end;
      end;
      return True;
   end On_Histogram_Draw;

   --  ── Public ────────────────────────────────────────────────────────────

   function Build return Gtk.Drawing_Area.Gtk_Drawing_Area is
   begin
      Gtk.Drawing_Area.Gtk_New (The_Widget);
      The_Widget.Set_Size_Request (-1, 160);
      The_Widget.On_Draw (On_Histogram_Draw'Access);
      return The_Widget;
   end Build;

   procedure Refresh
     (Values   : Long_Float_Array;
      CL       : Long_Float;
      UCL      : Long_Float;
      Has_UCL  : Boolean;
      LCL      : Long_Float;
      Has_LCL  : Boolean;
      X_Label  : String;
      Has_Data : Boolean)
   is
   begin
      Hist_Values.Clear;
      for V of Values loop
         Hist_Values.Append (V);
      end loop;
      Hist_CL       := CL;
      Hist_UCL      := UCL;
      Hist_Has_UCL  := Has_UCL;
      Hist_LCL      := LCL;
      Hist_Has_LCL  := Has_LCL;
      Hist_X_Label  := To_Unbounded_String (X_Label);
      Hist_Has_Data := Has_Data;
      if The_Widget /= null then
         The_Widget.Queue_Draw;
      end if;
   end Refresh;

   procedure Compute_Bins
     (Values    :     Long_Float_Array;
      N_Bins    : out Positive;
      Bin_Min   : out Long_Float;
      Bin_Width : out Long_Float;
      Counts    : out Bin_Count_Array)
   is
      use Ada.Numerics.Long_Elementary_Functions;
      N : constant Positive := Values'Length;

      --  Normalise to a 1-based sorted copy for percentile arithmetic.
      Sorted : Long_Float_Array (1 .. N);

      --  Linear-interpolation percentile on Sorted(1..N).
      --  Q in [0.0, 1.0]; uses 0-based virtual indices internally.
      function Percentile (Q : Long_Float) return Long_Float is
         Idx_F : constant Long_Float := Q * Long_Float (N - 1);
         Lo    : constant Natural    := Natural (Long_Float'Floor (Idx_F));
         Hi    : constant Natural    := Natural (Long_Float'Ceiling (Idx_F));
         Frac  : constant Long_Float := Idx_F - Long_Float'Floor (Idx_F);
      begin
         if Lo = Hi then
            return Sorted (Lo + 1);
         else
            return Sorted (Lo + 1) * (1.0 - Frac)
                   + Sorted (Hi + 1) * Frac;
         end if;
      end Percentile;

   begin
      Counts := (others => 0);

      --  Copy values into 1-based Sorted.
      for I in Values'Range loop
         Sorted (I - Values'First + 1) := Values (I);
      end loop;

      --  Insertion sort (adequate for the session counts in this application).
      for I in 2 .. N loop
         declare
            Key : constant Long_Float := Sorted (I);
            J   : Natural             := I - 1;
         begin
            while J >= 1 and then Sorted (J) > Key loop
               Sorted (J + 1) := Sorted (J);
               J := J - 1;
            end loop;
            Sorted (J + 1) := Key;
         end;
      end loop;

      Bin_Min := Sorted (1);

      declare
         V_Max   : constant Long_Float := Sorted (N);
         Range_V : constant Long_Float := V_Max - Bin_Min;
      begin
         if Range_V = 0.0 then
            --  All values equal.
            Bin_Width  := 1.0;
            N_Bins     := 1;
            Counts (1) := N;
         else
            declare
               Q1  : constant Long_Float := Percentile (0.25);
               Q3  : constant Long_Float := Percentile (0.75);
               IQR : constant Long_Float := Q3 - Q1;
            begin
               if IQR <= 0.0 then
                  --  IQR = 0 (heavily concentrated data): single bin.
                  Bin_Width  := Range_V;
                  N_Bins     := 1;
                  Counts (1) := N;
               else
                  --  Freedman-Diaconis: h = 2 * IQR / n^(1/3).
                   declare
                      H     : constant Long_Float :=
                        2.0 * IQR / Exp (Log (Long_Float (N)) / 3.0);
                      Ratio   : constant Long_Float :=
                        Long_Float'Ceiling (Range_V / H);
                      Raw_K_N : constant Natural :=
                        (if Ratio >= Long_Float (Max_Bins)
                         then Natural (Max_Bins)
                         else Natural (Ratio));
                      K_Val   : constant Natural := Natural'Max (1, Raw_K_N);
                      Max_Bins_N : constant Natural := Natural (Max_Bins);
                      K_N     : constant Natural := Natural'Min (Max_Bins_N, K_Val);
                      K       : constant Positive := Positive (K_N);
                   begin
                     N_Bins    := K;
                     Bin_Width := Range_V / Long_Float (K);
                     for V of Values loop
                        declare
                           Raw_Idx : Natural :=
                             Natural (Long_Float'Max (0.0, Long_Float'Floor
                                        ((V - Bin_Min) / Bin_Width))) + 1;
                        begin
                           if Raw_Idx > N_Bins then
                              Raw_Idx := N_Bins;
                           end if;
                           Counts (Raw_Idx) := Counts (Raw_Idx) + 1;
                        end;
                     end loop;
                  end;
               end if;
            end;
         end if;
      end;
   end Compute_Bins;

end Coyote_SQC.UI.Histogram_Canvas;
