--  Coyote_SQC.UI.Hover_Tooltip body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.Data_Model;
with Gtk.Drawing_Area;
with Coyote_SQC.App;
with Coyote_SQC.Charts;
with Glib;           use Glib;
with Gdk.Rectangle;
with Gtk.Label;
with Gtk.Popover;
with Coyote_Renderer.Markup;
with Coyote_SQC.Statistics.Quantile_CC;
with Gtk.Widget;

package body Coyote_SQC.UI.Hover_Tooltip is
   use type Coyote_SQC.App.App_State_Access;
   use type Gtk.Popover.Gtk_Popover;

   The_Popover  : Gtk.Popover.Gtk_Popover := null;
   The_Label    : Gtk.Label.Gtk_Label    := null;
   The_Canvas   : Gtk.Drawing_Area.Gtk_Drawing_Area := null;
   Tooltip_Visible : Boolean := False;

   function Is_Visible return Boolean is (Tooltip_Visible);

   procedure Attach
     (Canvas : not null access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class)
   is
      use Gtk.Popover;
      use Gtk.Label;
   begin
      The_Canvas := Gtk.Drawing_Area.Gtk_Drawing_Area (Canvas);
      Gtk.Popover.Gtk_New (The_Popover, The_Canvas);
      The_Popover.Set_Modal (False);
      Gtk.Label.Gtk_New (The_Label, "");
      The_Label.Set_Use_Markup (True);
      The_Popover.Add (The_Label);
   end Attach;

   function Format_Number (N : Long_Long_Integer) return String is
      use Ada.Strings.Fixed;
   begin
      return Trim (N'Image, Ada.Strings.Left);
   end Format_Number;

   --  Format a Long_Float for tooltip display (avoids scientific notation).
   function Format_Float (V : Long_Float) return String is
      use Ada.Strings.Fixed;
   begin
      if not V'Valid then
         return "?";
      end if;
      if abs V >= 100.0 then
         return Trim
           (Long_Long_Integer'Image (Long_Long_Integer (V)),
            Ada.Strings.Left);
      elsif abs V >= 1.0 then
         declare
            IV : constant Long_Long_Integer :=
              Long_Long_Integer (V * 10.0);
         begin
            return Trim (Long_Long_Integer'Image (IV / 10),
                         Ada.Strings.Left)
              & "." & Trim
                       (Long_Long_Integer'Image (abs (IV mod 10)),
                        Ada.Strings.Left);
         end;
      else
         declare
            IV : constant Long_Long_Integer :=
              Long_Long_Integer (V * 1000.0);
         begin
            return "0."
              & (if abs (IV) < 100 then "0" else "")
              & (if abs (IV) < 10  then "0" else "")
              & Trim (Long_Long_Integer'Image (abs IV),
                      Ada.Strings.Left);
         end;
      end if;
   exception
      when Constraint_Error => return "?";
   end Format_Float;

   procedure Show_For_Session
     (Session_Id : String;
      Screen_X   : Long_Float;
      Screen_Y   : Long_Float)
   is
      use Ada.Calendar;
      use Ada.Calendar.Formatting;
      use Ada.Strings.Fixed;
      use Ada.Strings.Unbounded;

      --  Find the session.
      Sess_Found : Boolean := False;
      S_Idx      : Natural := 0;
   begin
      if The_Popover = null or else Coyote_SQC.App.State = null then
         return;
      end if;

      for I in 1 .. Positive (Coyote_SQC.App.State.Sessions.Length) loop
         if To_String
              (Coyote_SQC.App.State.Sessions.Element (I).Session_Id)
            = Session_Id
         then
            Sess_Found := True;
            S_Idx := I;
            exit;
         end if;
      end loop;

      if not Sess_Found then
         return;
      end if;

      declare
         Sess : constant Coyote_SQC.Data_Model.Session_Record :=
           Coyote_SQC.App.State.Sessions.Element (S_Idx);
         Ts   : constant String := Ada.Calendar.Formatting.Image
           (Sess.Start_Time, Time_Zone => 0);
         TS14 : constant String := Ts (Ts'First .. Ts'First + 15);
         Model_Str : constant String := To_String (Sess.Model);
         Src_Str   : constant String := To_String (Sess.Source_Directory);
         Prompt    : constant String := To_String (Sess.First_User_Message);
         P_Len     : constant Natural := Natural'Min (Prompt'Length, 80);
         P_Display : constant String :=
           Prompt (Prompt'First .. Prompt'First + P_Len - 1)
           & (if Prompt'Length > 80 then "..." else "");

         --  Comment count
         N_Comments : Natural := 0;
         Has_Latest  : Boolean                           := False;
         Latest_Time : Ada.Calendar.Time                 := Ada.Calendar.Clock;
         Latest_Text : Ada.Strings.Unbounded.Unbounded_String;
         Pt_Found   : Boolean := False;
         Pt         : Coyote_SQC.App.Chart_Point;
         QP_Found   : Boolean := False;
         QP         : Coyote_SQC.App.Quantile_Point;
      begin
         for C of Coyote_SQC.App.State.Workspace.Comments loop
            if To_String (C.Session_Id) = Session_Id then
               N_Comments := N_Comments + 1;
               if not Has_Latest or else C.Timestamp > Latest_Time then
                  Has_Latest  := True;
                  Latest_Time := C.Timestamp;
                  Latest_Text := C.Text;
               end if;
            end if;
         end loop;
         --  Look up the chart point for this session in the active chart.
         declare
            Active : constant Coyote_SQC.Charts.Chart_Kind :=
              Coyote_SQC.App.State.Active_Chart;
         begin
            for P of Coyote_SQC.App.State.Charts (Active).Points loop
               if To_String (P.Session_Id) = Session_Id then
                  Pt       := P;
                  Pt_Found := True;
                  exit;
               end if;
            end loop;
         end;

         --  Look up the quantile point for this session if active chart
         --  is a Quantile CC chart.
         begin
            if Coyote_SQC.Charts.Properties
                 (Coyote_SQC.App.State.Active_Chart)
                 .Is_Quantile_CC_Chart
            then
               declare
                  Active : constant Coyote_SQC.Charts.Chart_Kind :=
                    Coyote_SQC.App.State.Active_Chart;
               begin
                  for Q of Coyote_SQC.App.State.Charts (Active)
                           .Quantile_Points
                  loop
                     if To_String (Q.Session_Id) = Session_Id then
                        QP       := Q;
                        QP_Found := True;
                        exit;
                     end if;
                  end loop;
               end;
            end if;
         end;

         declare
            --  XML-escape variable strings to prevent Pango markup errors.
            Esc_Model  : constant String :=
              Coyote_Renderer.Markup.Xml_Escape (Model_Str);
            Esc_Src    : constant String :=
              Coyote_Renderer.Markup.Xml_Escape (Src_Str);
            Esc_Prompt : constant String :=
              Coyote_Renderer.Markup.Xml_Escape (P_Display);
            --  Latest comment timestamp and truncated body (for tooltip).
            Latest_Ts_Str   : constant String :=
              (if Has_Latest
               then Ada.Calendar.Formatting.Image
                      (Latest_Time, Time_Zone => 0) (1 .. 16)
               else "");
            C_Text          : constant String :=
              To_String (Latest_Text);
            C_Len           : constant Natural :=
              Natural'Min (C_Text'Length, 80);
            C_Display       : constant String :=
              (if C_Text'Length = 0 then ""
               else C_Text (C_Text'First .. C_Text'First + C_Len - 1)
                    & (if C_Text'Length > 80 then "..." else ""));
            Esc_Latest_Ts   : constant String :=
              Coyote_Renderer.Markup.Xml_Escape (Latest_Ts_Str);
            Esc_Latest_Body : constant String :=
              Coyote_Renderer.Markup.Xml_Escape (C_Display);
            --  Control limits / quantile diagram line.
            function Build_Stats_Line return String is
               use Ada.Strings.Unbounded;
               Result : Unbounded_String;
               NL     : constant String := "" & ASCII.LF;
            begin
               if QP_Found then
                  --  Quantile CC chart: show n and five components.
                  Result := To_Unbounded_String
                    (NL & "n = " & Format_Number
                       (Long_Long_Integer (QP.N)) & " turns" & NL & NL);
                  declare
                     use Coyote_SQC.Statistics.Quantile_CC;
                  begin
                     for Comp in Quantile_Index loop
                        declare
                           V  : constant Long_Float := QP.Values (Comp);
                           L  : constant Quantile_Limits_Record :=
                             QP.Limits (Comp);
                           UCL_Str : constant String :=
                             (if L.Has_UCL
                              then Format_Float (L.UCL)
                              else "-");
                           LCL_Str : constant String :=
                             (if L.Has_LCL
                              then Format_Float (L.LCL)
                              else "-");
                        begin
                           Result := Result
                             & (case Comp is when Min_Q => "min", when Q1 => "Q1", when Median_Q => "med", when Q3 => "Q3", when Max_Q => "max") & ":  "
                             & Format_Float (V)
                             & " (UCL: " & UCL_Str
                             & ", LCL: " & LCL_Str & ")";
                           if QP.OOC_Comps (Comp) then
                              Result := Result
                                & "  " & Character'Val (16#E2#)
                                & Character'Val (16#86#)
                                & Character'Val (16#90#)
                                & " out-of-control";
                           end if;
                           if Comp /= Max_Q then
                              Result := Result & NL;
                           end if;
                        end;
                     end loop;
                  end;
               elsif Pt_Found then
                  Result := To_Unbounded_String
                    (NL & "CL: " & Format_Float (Pt.CL));
                  if Pt.Has_UCL then
                     Result := Result
                       & "   UCL: " & Format_Float (Pt.UCL);
                  end if;
                  if Pt.Has_LCL then
                     Result := Result
                       & "   LCL: " & Format_Float (Pt.LCL);
                  end if;
               end if;
               return To_String (Result);
            end Build_Stats_Line;
            Markup : constant String :=
              "<b>" & TS14 & "</b>"
              & "  " & Esc_Model & ASCII.LF
              & Esc_Src & ASCII.LF & ASCII.LF
              & "&quot;" & Esc_Prompt & "&quot;" & ASCII.LF & ASCII.LF
              & "Input: "
              & Format_Number (Long_Long_Integer (Sess.Total_Input_Tokens))
              & " tokens   Output: "
              & Format_Number (Long_Long_Integer (Sess.Total_Output_Tokens))
              & " tokens"
              & Build_Stats_Line
              & (if N_Comments > 0
                 then ASCII.LF & "Comments: "
                      & Trim (N_Comments'Image, Ada.Strings.Left)
                      & "  " & Esc_Latest_Ts & ": &quot;"
                      & Esc_Latest_Body & "&quot;"
                 else "");
         begin
            The_Label.Set_Markup (Markup);
         end;

         --  Position the popover at the cursor.
         declare
            Rect : Gdk.Rectangle.Gdk_Rectangle :=
              (X      => Glib.Gint (Integer (Screen_X)),
               Y      => Glib.Gint (Integer (Screen_Y)),
               Width  => 1,
               Height => 1);
         begin
            The_Popover.Set_Pointing_To (Rect);
         end;
         The_Popover.Show_All;
         Tooltip_Visible := True;
      end;
   end Show_For_Session;

   procedure Hide is
   begin
      if The_Popover /= null and then Tooltip_Visible then
         The_Popover.Popdown;
         Tooltip_Visible := False;
      end if;
      if Coyote_SQC.App.State /= null then
         Coyote_SQC.App.State.Canvas_St.Hovered_Session_Id :=
           Ada.Strings.Unbounded.Null_Unbounded_String;
      end if;
   end Hide;

end Coyote_SQC.UI.Hover_Tooltip;
