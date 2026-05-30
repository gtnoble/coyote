--  Coyote_SQC.UI.Chart_Settings_Dialog body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.App;
with Coyote_SQC.Data_Model;
with Coyote_SQC.Workspace;
with Coyote_SQC.UI.Chart_Canvas;
with Glib;                   use Glib;
with Gtk.Box;
with Gtk.Button;
with Gtk.Check_Button;
with Gtk.Combo_Box;
with Gtk.Combo_Box_Text;
with Gtk.Dialog;             use Gtk.Dialog;
with Gtk.Expander;
with Gtk.Label;
with Gtk.Spin_Button;
with Gtk.Toggle_Button;
with Gtk.Widget;

package body Coyote_SQC.UI.Chart_Settings_Dialog is

   use Coyote_SQC.Data_Model;
   use Coyote_SQC.Charts;
   use type Coyote_SQC.App.App_State_Access;
   use type Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
   use type Gtk.Spin_Button.Gtk_Spin_Button;

   --  Em-dash: U+2014 = 0xE2 0x80 0x94
   EM_Dash : constant String :=
     (1 => Character'Val (16#E2#),
      2 => Character'Val (16#80#),
      3 => Character'Val (16#94#));

   --  Lambda symbol: U+03BB = 0xCE 0xBB
   Lambda_Sym : constant String :=
     (1 => Character'Val (16#CE#),
      2 => Character'Val (16#BB#));

   --  Transform-kind combo indices.
   Tf_None        : constant Glib.Gint := 0;
   Tf_Box_Cox     : constant Glib.Gint := 1;
   Tf_Sqrt_VS     : constant Glib.Gint := 2;
   Tf_Anscombe    : constant Glib.Gint := 3;
   Tf_Arcsinh_VS  : constant Glib.Gint := 4;
   Tf_Freeman_Tukey : constant Glib.Gint := 5;

   --  Source-combo indices (used only when kind = Box-Cox).
   Src_MLE    : constant Glib.Gint := 0;
   Src_Robust : constant Glib.Gint := 1;
   Src_Fixed  : constant Glib.Gint := 2;

   --  Estimation-method combo indices.
   Est_Classical : constant Glib.Gint := 0;
   Est_Robust    : constant Glib.Gint := 1;

   procedure Show (Kind : Coyote_SQC.Charts.Chart_Kind) is

      Props : constant Coyote_SQC.Charts.Chart_Properties :=
        Coyote_SQC.Charts.Properties (Kind);
      Cur   : constant Chart_Settings_Record :=
        Coyote_SQC.Workspace.Chart_Settings
          (Coyote_SQC.App.State.Workspace, Kind);

      D    : Gtk_Dialog;
      VBox : Gtk.Box.Gtk_Box;
      Res  : Gtk_Response_Type;

      --  Variance-stabilization transform kind combo.
      Tf_C   : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;

      --  Box-Cox sub-panel widgets (visible only when kind = Box-Cox).
      BC_Src     : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
      BC_Fixed_C : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
      BC_Spin    : Gtk.Spin_Button.Gtk_Spin_Button;
      BC_Box     : Gtk.Box.Gtk_Box;   --  container for BC-specific widgets

      --  Estimation-method widget.
      Est_C : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;

      --  EWMA parameter widgets.
      Wt_Sp : Gtk.Spin_Button.Gtk_Spin_Button := null;
      L_Sp  : Gtk.Spin_Button.Gtk_Spin_Button := null;

      --  A p-chart or ratio-based chart: show advisory note.
      Is_Ratio : constant Boolean :=
        Props.Is_P_Chart
        or else Kind in Fraction_Thinking_Tokens_I
                       | Fraction_Thinking_Tokens_MR
                       | Fraction_Thinking_Tokens_EWMA
                       | Fraction_Tool_Call_Tokens_I
                       | Fraction_Tool_Call_Tokens_MR
                       | Fraction_Tool_Call_Tokens_EWMA
                       | Fraction_Thinking_Per_Tool_Call_I
                       | Fraction_Thinking_Per_Tool_Call_MR
                       | Fraction_Thinking_Per_Tool_Call_EWMA
                       | Fraction_Uncached_Input_I
                       | Fraction_Uncached_Input_MR
                       | Fraction_Uncached_Input_EWMA;

      --  Map Transform_Kind to combo index.
      function To_Tf_Idx (K : Transform_Kind) return Glib.Gint is
      begin
         case K is
            when None          => return Tf_None;
            when Box_Cox       => return Tf_Box_Cox;
            when Sqrt_VS       => return Tf_Sqrt_VS;
            when Anscombe      => return Tf_Anscombe;
            when Arcsinh_VS    => return Tf_Arcsinh_VS;
            when Freeman_Tukey => return Tf_Freeman_Tukey;
         end case;
      end To_Tf_Idx;

      --  Map combo index to Transform_Kind.
      function From_Tf_Idx return Transform_Kind is
         Idx : constant Glib.Gint :=
           Gtk.Combo_Box.Get_Active
             (Gtk.Combo_Box.Gtk_Combo_Box (Tf_C));
      begin
         if    Idx = Tf_Box_Cox       then return Box_Cox;
         elsif Idx = Tf_Sqrt_VS       then return Sqrt_VS;
         elsif Idx = Tf_Anscombe      then return Anscombe;
         elsif Idx = Tf_Arcsinh_VS    then return Arcsinh_VS;
         elsif Idx = Tf_Freeman_Tukey then return Freeman_Tukey;
         else                              return None;
         end if;
      end From_Tf_Idx;

      --  Return the Gint combo index for a Lambda_Source value.
      function To_Src_Idx (S : Box_Cox_Lambda_Source) return Glib.Gint is
      begin
         case S is
            when Robust_Auto => return Src_Robust;
            when Fixed       => return Src_Fixed;
            when Auto        => return Src_MLE;
         end case;
      end To_Src_Idx;

      --  Read Lambda_Source from the source combo.
      function From_Src_Idx return Box_Cox_Lambda_Source is
         Idx : constant Glib.Gint :=
           Gtk.Combo_Box.Get_Active
             (Gtk.Combo_Box.Gtk_Combo_Box (BC_Src));
      begin
         if Idx = Src_Robust then return Robust_Auto;
         elsif Idx = Src_Fixed then return Fixed;
         else return Auto;
         end if;
      end From_Src_Idx;

      --  Update sensitivity of fixed-lambda widgets.
      procedure Refresh_Fixed_Sens is
         F : constant Boolean :=
           Gtk.Combo_Box.Get_Active
             (Gtk.Combo_Box.Gtk_Combo_Box (BC_Src)) = Src_Fixed;
      begin
         BC_Fixed_C.Set_Sensitive (F);
         BC_Spin.Set_Sensitive (F);
      end Refresh_Fixed_Sens;

      --  Show/hide the Box-Cox sub-panel based on the transform kind combo.
      procedure Refresh_BC_Panel is
         Is_BC : constant Boolean :=
           Gtk.Combo_Box.Get_Active
             (Gtk.Combo_Box.Gtk_Combo_Box (Tf_C)) = Tf_Box_Cox;
      begin
         BC_Box.Set_Visible (Is_BC);
         if Is_BC then
            Refresh_Fixed_Sens;
         end if;
      end Refresh_BC_Panel;

      --  Transform-kind combo callback.
      procedure On_Kind_Changed
        (W : access Gtk.Combo_Box.Gtk_Combo_Box_Record'Class)
      is
         pragma Unreferenced (W);
      begin
         Refresh_BC_Panel;
      end On_Kind_Changed;

      --  Source-combo callback.
      procedure On_Src_Changed
        (W : access Gtk.Combo_Box.Gtk_Combo_Box_Record'Class)
      is
         pragma Unreferenced (W);
      begin
         Refresh_Fixed_Sens;
      end On_Src_Changed;

      --  Fixed-value preset callback.
      procedure On_Fixed_Preset
        (W : access Gtk.Combo_Box.Gtk_Combo_Box_Record'Class)
      is
         pragma Unreferenced (W);
         Idx : constant Glib.Gint :=
           Gtk.Combo_Box.Get_Active
             (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C));
      begin
         if Idx = 0 then BC_Spin.Set_Value (0.0);
         elsif Idx = 1 then BC_Spin.Set_Value (0.5);
         elsif Idx = 2 then BC_Spin.Set_Value (1.0);
         end if;
      end On_Fixed_Preset;

      --  Spin callback: switch preset combo to "custom...".
      procedure On_Spin_Changed
        (W : access Gtk.Spin_Button.Gtk_Spin_Button_Record'Class)
      is
         pragma Unreferenced (W);
         V : constant Gdouble := BC_Spin.Get_Value;
      begin
         if V = 0.0 then
            Gtk.Combo_Box.Set_Active
              (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 0);
         elsif V = 0.5 then
            Gtk.Combo_Box.Set_Active
              (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 1);
         elsif V = 1.0 then
            Gtk.Combo_Box.Set_Active
              (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 2);
         else
            Gtk.Combo_Box.Set_Active
              (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 3);
         end if;
      end On_Spin_Changed;

      --  Reset-to-defaults callback.
      procedure On_Reset
        (W : access Gtk.Button.Gtk_Button_Record'Class)
      is
         pragma Unreferenced (W);
      begin
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (Tf_C), Tf_None);
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Src), Src_MLE);
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 0);
         BC_Spin.Set_Value (0.0);
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (Est_C), Est_Classical);
         if Props.Is_EWMA_Chart and then Wt_Sp /= null then
            Wt_Sp.Set_Value (0.2);
            L_Sp.Set_Value (3.0);
         end if;
      end On_Reset;

   begin
      if Coyote_SQC.App.State = null then return; end if;

      Gtk.Dialog.Gtk_New
        (D,
         "Chart Settings " & EM_Dash & " "
         & To_String (Props.Label),
         Coyote_SQC.App.State.Main_Window,
         Gtk.Dialog.Modal);
      D.Set_Default_Size (420, -1);

      Gtk.Box.Gtk_New_Vbox (VBox);
      VBox.Set_Spacing (6);
      VBox.Set_Border_Width (8);

      --  ── Variance-Stabilization Transform expander ──────────────────────
      declare
         Exp    : Gtk.Expander.Gtk_Expander;
         Innr   : Gtk.Box.Gtk_Box;
         Kd_Rw  : Gtk.Box.Gtk_Box;
         S_Rw   : Gtk.Box.Gtk_Box;
         F_Rw   : Gtk.Box.Gtk_Box;
         Kd_Lb  : Gtk.Label.Gtk_Label;
         S_Lb   : Gtk.Label.Gtk_Label;
         F_Lb   : Gtk.Label.Gtk_Label;
         Adv    : Gtk.Label.Gtk_Label;
         Non_Def : constant Boolean :=
           Cur.Transform.Kind /= None;
      begin
         Gtk.Expander.Gtk_New (Exp, "Variance-Stabilization Transform");
         Exp.Set_Expanded (Non_Def);

         Gtk.Box.Gtk_New_Vbox (Innr);
         Innr.Set_Spacing (4);
         Innr.Set_Border_Width (4);

         --  Transform kind row.
         Gtk.Box.Gtk_New_Hbox (Kd_Rw);
         Kd_Rw.Set_Spacing (4);
         Gtk.Label.Gtk_New (Kd_Lb, "Transform:");
         Kd_Rw.Pack_Start (Kd_Lb, False, False, 0);
         Gtk.Combo_Box_Text.Gtk_New (Tf_C);
         Tf_C.Append_Text ("None (raw data)");
         Tf_C.Append_Text ("Box-Cox (" & Lambda_Sym & ")");
         Tf_C.Append_Text ("Square root (sqrt x)");
         Tf_C.Append_Text ("Anscombe (2*sqrt(x+3/8))");
         Tf_C.Append_Text ("Arcsinh (ln(x+sqrt(x^2+1)))");
         Tf_C.Append_Text ("Freeman-Tukey (sqrt(x)+sqrt(x+1))");
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (Tf_C),
            To_Tf_Idx (Cur.Transform.Kind));
         Gtk.Combo_Box.On_Changed
           (Gtk.Combo_Box.Gtk_Combo_Box (Tf_C),
            On_Kind_Changed'Unrestricted_Access);
         Kd_Rw.Pack_Start (Tf_C, True, True, 0);
         Innr.Pack_Start (Kd_Rw, False, False, 0);

         --  Box-Cox sub-panel (lambda source + fixed-lambda row).
         Gtk.Box.Gtk_New_Vbox (BC_Box);
         BC_Box.Set_Spacing (4);

         Gtk.Box.Gtk_New_Hbox (S_Rw);
         S_Rw.Set_Spacing (4);
         Gtk.Label.Gtk_New (S_Lb, "Lambda source:");
         S_Rw.Pack_Start (S_Lb, False, False, 0);
         Gtk.Combo_Box_Text.Gtk_New (BC_Src);
         BC_Src.Append_Text ("Auto-estimate (MLE)");
         BC_Src.Append_Text ("Auto-estimate (robust)");
         BC_Src.Append_Text ("Fixed");
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Src),
            To_Src_Idx (Cur.Transform.Lambda_Source));
         Gtk.Combo_Box.On_Changed
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Src),
            On_Src_Changed'Unrestricted_Access);
         S_Rw.Pack_Start (BC_Src, True, True, 0);
         BC_Box.Pack_Start (S_Rw, False, False, 0);

         Gtk.Box.Gtk_New_Hbox (F_Rw);
         F_Rw.Set_Spacing (4);
         Gtk.Label.Gtk_New (F_Lb, "Fixed " & Lambda_Sym & ":");
         F_Rw.Pack_Start (F_Lb, False, False, 0);
         Gtk.Combo_Box_Text.Gtk_New (BC_Fixed_C);
         BC_Fixed_C.Append_Text (Lambda_Sym & "=0 (log)");
         BC_Fixed_C.Append_Text (Lambda_Sym & "=0.5 (sqrt)");
         BC_Fixed_C.Append_Text (Lambda_Sym & "=1 (identity)");
         BC_Fixed_C.Append_Text ("custom...");
         Gtk.Combo_Box.On_Changed
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C),
            On_Fixed_Preset'Unrestricted_Access);
         F_Rw.Pack_Start (BC_Fixed_C, False, False, 0);

         Gtk.Spin_Button.Gtk_New (BC_Spin, 0.0, 30.0, 0.01);
         BC_Spin.Set_Digits (2);
         BC_Spin.Set_Value (Gdouble (Cur.Transform.Fixed_Lambda));
         Gtk.Spin_Button.On_Value_Changed
           (BC_Spin, On_Spin_Changed'Unrestricted_Access);
         F_Rw.Pack_Start (BC_Spin, False, False, 0);
         BC_Box.Pack_Start (F_Rw, False, False, 0);

         --  Set the fixed-value preset combo to reflect the current value.
         declare
            V : constant Long_Float := Cur.Transform.Fixed_Lambda;
         begin
            if V = 0.0 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 0);
            elsif V = 0.5 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 1);
            elsif V = 1.0 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 2);
            else
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (BC_Fixed_C), 3);
            end if;
         end;

         Innr.Pack_Start (BC_Box, False, False, 0);

         if Is_Ratio then
            Gtk.Label.Gtk_New
              (Adv,
               "Note: variance-stabilization transforms are not"
               & " recommended for ratio/proportion charts.");
            Adv.Set_Halign (Gtk.Widget.Align_Start);
            Innr.Pack_Start (Adv, False, False, 0);
         end if;

         Exp.Add (Innr);
         VBox.Pack_Start (Exp, False, False, 0);

         --  Initial visibility / sensitivity.
         Refresh_BC_Panel;
      end;

      --  ── Estimation Method expander ─────────────────────────────────────
      declare
         Exp  : Gtk.Expander.Gtk_Expander;
         Innr : Gtk.Box.Gtk_Box;
         M_Rw : Gtk.Box.Gtk_Box;
         M_Lb : Gtk.Label.Gtk_Label;
         Note : Gtk.Label.Gtk_Label;
         Non_Def : constant Boolean :=
           Cur.Estimation_Method /= Classical;
      begin
         Gtk.Expander.Gtk_New (Exp, "Estimation Method");
         Exp.Set_Expanded (Non_Def);

         Gtk.Box.Gtk_New_Vbox (Innr);
         Innr.Set_Spacing (4);
         Innr.Set_Border_Width (4);

         Gtk.Box.Gtk_New_Hbox (M_Rw);
         M_Rw.Set_Spacing (4);
         Gtk.Label.Gtk_New (M_Lb, "Method:");
         M_Rw.Pack_Start (M_Lb, False, False, 0);
         Gtk.Combo_Box_Text.Gtk_New (Est_C);
         Est_C.Append_Text ("Classical (mean / pooled s / mean MR)");
         Est_C.Append_Text ("Robust (median / Qn / median MR)");
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (Est_C),
            (if Cur.Estimation_Method = Robust_Median
             then Est_Robust else Est_Classical));
         M_Rw.Pack_Start (Est_C, True, True, 0);
         Innr.Pack_Start (M_Rw, False, False, 0);

         if Props.Is_P_Chart then
            Gtk.Label.Gtk_New
              (Note,
               "p-charts always use the classical grand proportion"
               & " regardless of this setting.");
            Note.Set_Halign (Gtk.Widget.Align_Start);
            Note.Set_Line_Wrap (True);
            Innr.Pack_Start (Note, False, False, 0);
         elsif Props.Is_EWMA_Chart then
            Gtk.Label.Gtk_New
              (Note,
               "EWMA charts independently apply this method using"
               & " the same setup-interval observations as the"
               & " companion I chart.");
            Note.Set_Halign (Gtk.Widget.Align_Start);
            Note.Set_Line_Wrap (True);
            Innr.Pack_Start (Note, False, False, 0);
         end if;

         Exp.Add (Innr);
         VBox.Pack_Start (Exp, False, False, 0);
      end;

      --  ── EWMA Parameters expander (EWMA charts only) ────────────────────
      if Props.Is_EWMA_Chart then
         declare
            Exp  : Gtk.Expander.Gtk_Expander;
            Innr : Gtk.Box.Gtk_Box;
            W_Rw : Gtk.Box.Gtk_Box;
            L_Rw : Gtk.Box.Gtk_Box;
            W_Lb : Gtk.Label.Gtk_Label;
            L_Lb : Gtk.Label.Gtk_Label;
            Desc : Gtk.Label.Gtk_Label;
            Non_Def : constant Boolean :=
              Cur.EWMA_Weight /= 0.2 or else Cur.EWMA_L /= 3.0;
         begin
            Gtk.Expander.Gtk_New (Exp, "EWMA Parameters");
            Exp.Set_Expanded (Non_Def);

            Gtk.Box.Gtk_New_Vbox (Innr);
            Innr.Set_Spacing (4);
            Innr.Set_Border_Width (4);

            Gtk.Box.Gtk_New_Hbox (W_Rw);
            W_Rw.Set_Spacing (4);
            Gtk.Label.Gtk_New (W_Lb, "Smoothing weight " & Lambda_Sym & ":");
            W_Rw.Pack_Start (W_Lb, False, False, 0);
            Gtk.Spin_Button.Gtk_New (Wt_Sp, 0.01, 1.0, 0.01);
            Wt_Sp.Set_Digits (2);
            Wt_Sp.Set_Value (Gdouble (Cur.EWMA_Weight));
            W_Rw.Pack_Start (Wt_Sp, False, False, 0);
            Innr.Pack_Start (W_Rw, False, False, 0);

            Gtk.Box.Gtk_New_Hbox (L_Rw);
            L_Rw.Set_Spacing (4);
            Gtk.Label.Gtk_New (L_Lb, "Sigma multiplier L:");
            L_Rw.Pack_Start (L_Lb, False, False, 0);
            Gtk.Spin_Button.Gtk_New (L_Sp, 1.0, 4.0, 0.25);
            L_Sp.Set_Digits (2);
            L_Sp.Set_Value (Gdouble (Cur.EWMA_L));
            L_Rw.Pack_Start (L_Sp, False, False, 0);
            Innr.Pack_Start (L_Rw, False, False, 0);

            Gtk.Label.Gtk_New
              (Desc,
               "Smaller " & Lambda_Sym
               & " gives more smoothing and better detection of"
               & " small sustained shifts; "
               & Lambda_Sym & " = 1 reduces to the raw I chart.");
            Desc.Set_Halign (Gtk.Widget.Align_Start);
            Desc.Set_Line_Wrap (True);
            Innr.Pack_Start (Desc, False, False, 0);

            Exp.Add (Innr);
            VBox.Pack_Start (Exp, False, False, 0);
         end;
      end if;

      --  ── Reset to Defaults button ────────────────────────────────────────
      declare
         Btn : Gtk.Button.Gtk_Button;
      begin
         Gtk.Button.Gtk_New (Btn, "Reset to Defaults");
         Btn.On_Clicked (On_Reset'Unrestricted_Access);
         VBox.Pack_Start (Btn, False, False, 4);
      end;

      --  Add content and dialog buttons.
      declare
         Content : constant Gtk.Box.Gtk_Box := D.Get_Content_Area;
         Dummy   : Gtk.Widget.Gtk_Widget;
         pragma Unreferenced (Dummy);
      begin
         Content.Pack_Start (VBox, True, True, 0);
         Dummy := D.Add_Button ("_OK",     Gtk_Response_OK);
         Dummy := D.Add_Button ("_Cancel", Gtk_Response_Cancel);
      end;

      D.Show_All;
      Res := D.Run;

      if Res = Gtk_Response_OK then
         declare
            New_Cfg : Chart_Settings_Record;
         begin
            --  Variance-stabilization transform.
            New_Cfg.Transform.Kind := From_Tf_Idx;
            if New_Cfg.Transform.Kind = Box_Cox then
               New_Cfg.Transform.Lambda_Source := From_Src_Idx;
               New_Cfg.Transform.Fixed_Lambda  :=
                 Long_Float (BC_Spin.Get_Value);
            end if;

            --  Estimation method.
            if Gtk.Combo_Box.Get_Active
              (Gtk.Combo_Box.Gtk_Combo_Box (Est_C)) = Est_Robust
            then
               New_Cfg.Estimation_Method := Robust_Median;
            else
               New_Cfg.Estimation_Method := Classical;
            end if;

            --  EWMA parameters (EWMA charts only).
            if Props.Is_EWMA_Chart
              and then Wt_Sp /= null and then L_Sp /= null
            then
               New_Cfg.EWMA_Weight := Long_Float (Wt_Sp.Get_Value);
               New_Cfg.EWMA_L      := Long_Float (L_Sp.Get_Value);
            end if;

            --  Sparse map update: remove entry if at default.
            if Coyote_SQC.Workspace.Is_Default (New_Cfg) then
               Coyote_SQC.App.State.Workspace.Chart_Settings.Exclude (Kind);
            else
               Coyote_SQC.App.State.Workspace.Chart_Settings.Include
                 (Kind, New_Cfg);
            end if;

            Coyote_SQC.App.State.Modified := True;
            Coyote_SQC.App.Recompute_Chart (Kind);
            Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
         end;
      end if;

      D.Destroy;
   end Show;

end Coyote_SQC.UI.Chart_Settings_Dialog;
