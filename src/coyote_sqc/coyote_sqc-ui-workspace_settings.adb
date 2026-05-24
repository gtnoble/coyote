--  Coyote_SQC.UI.Workspace_Settings body.
--
--  Accessible via Workspace -> Workspace Settings...
--
--  Project: coyote

with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.App;
with Coyote_SQC.Charts;
with Coyote_SQC.Data_Model;
with Coyote_SQC.UI.Chart_Canvas;
with Coyote_SQC.Workspace.Integrity;
with Coyote_SQC.UI.Dialogs;
with Glib;                   use Glib;
with Gtk.Box;
with Gtk.Button;
with Gtk.Check_Button;
with Gtk.Combo_Box;
with Gtk.Combo_Box_Text;
with Gtk.Dialog;             use Gtk.Dialog;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.GEntry;
with Gtk.Label;
with Gtk.List_Box;
with Gtk.List_Box_Row;
with Gtk.Radio_Button;
with Gtk.Scrolled_Window;
with Gtk.Spin_Button;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Toggle_Button;
with Gtk.Widget;
with Gtk.File_Chooser;
with Gtk.File_Chooser_Dialog;

package body Coyote_SQC.UI.Workspace_Settings is
   use type Coyote_SQC.App.App_State_Access;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.List_Box.Gtk_List_Box;
   use type Gtk.List_Box_Row.Gtk_List_Box_Row;
   use type Gtk.Dialog.Gtk_Dialog;
   use type Gtk.Check_Button.Gtk_Check_Button;
   use type Gtk.Radio_Button.Gtk_Radio_Button;
   use type Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
   use type Gtk.Spin_Button.Gtk_Spin_Button;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Box.Gtk_Box;

   --  UTF-8 multi-byte sequences for symbols used in UI labels.
   --  Lambda: U+03BB = 0xCE 0xBB
   Lambda_Sym : constant String :=
     (1 => Character'Val (16#CE#),
      2 => Character'Val (16#BB#));
   --  Square root: U+221A = 0xE2 0x88 0x9A
   Sqrt_Sym : constant String :=
     (1 => Character'Val (16#E2#),
      2 => Character'Val (16#88#),
      3 => Character'Val (16#9A#));
   --  En-dash: U+2013 = 0xE2 0x80 0x93
   Dash_Sym : constant String :=
     (1 => Character'Val (16#E2#),
      2 => Character'Val (16#80#),
      3 => Character'Val (16#93#));

   --  Module-level state for the currently-open settings dialog.
   WS_Dir_LB   : Gtk.List_Box.Gtk_List_Box := null;
   WS_New_Dirs : Coyote_SQC.Data_Model.String_Vectors.Vector;
   WS_Dialog   : Gtk.Dialog.Gtk_Dialog := null;

   --  Box-Cox section widget handles (reset per dialog open).
   BC_Enabled_CB    : Gtk.Check_Button.Gtk_Check_Button := null;
   BC_Sub_VBox      : Gtk.Box.Gtk_Box := null;
   BC_Auto_RB       : Gtk.Radio_Button.Gtk_Radio_Button := null;
   BC_Fixed_RB      : Gtk.Radio_Button.Gtk_Radio_Button := null;
   BC_Lambda_Combo  : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text := null;
   BC_Lambda_Spin   : Gtk.Spin_Button.Gtk_Spin_Button := null;
   BC_Lambda_Lbl    : Gtk.Label.Gtk_Label := null;
   --  Suppress spin->combo feedback while combo is programmatically updated.
   BC_Combo_Updating : Boolean := False;

   --  Xbar/S Box-Cox section widget handles (reset per dialog open).
   XS_Enabled_CB    : Gtk.Check_Button.Gtk_Check_Button := null;
   XS_Sub_VBox      : Gtk.Box.Gtk_Box := null;
   XS_Auto_RB       : Gtk.Radio_Button.Gtk_Radio_Button := null;
   XS_Fixed_RB      : Gtk.Radio_Button.Gtk_Radio_Button := null;
   XS_Lambda_Combo  : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text := null;
   XS_Lambda_Spin   : Gtk.Spin_Button.Gtk_Spin_Button := null;
   XS_Lambda_Lbl    : Gtk.Label.Gtk_Label := null;
   --  EWMA parameter spinners.
   EWMA_Weight_Spin : Gtk.Spin_Button.Gtk_Spin_Button := null;
   EWMA_L_Spin      : Gtk.Spin_Button.Gtk_Spin_Button := null;
   --  Suppress spin->combo feedback while combo is programmatically updated.
   XS_Combo_Updating : Boolean := False;


   --  ── Helpers ────────────────────────────────────────────────────────────

   --  Return the current auto-estimated lambda from the I-chart data,
   --  or Long_Float'Last if not yet computed.
   function Current_Auto_Lambda return Long_Float is
      use Coyote_SQC.Charts;
   begin
      if Coyote_SQC.App.State = null then
         return Long_Float'Last;
      end if;
      declare
         CD : constant Coyote_SQC.App.Chart_Data :=
           Coyote_SQC.App.State.Charts (Session_Input_Tokens_I);
      begin
         if CD.Box_Cox_Active then
            return CD.Box_Cox_Lambda;
         end if;
         return Long_Float'Last;
      end;
   end Current_Auto_Lambda;

   --  Update the "Estimated lambda:" readout label.
   procedure Update_Lambda_Readout is
      use Gtk.Toggle_Button;
   begin
      if BC_Lambda_Lbl = null or BC_Auto_RB = null then return; end if;
      if Get_Active (Gtk_Toggle_Button (BC_Auto_RB)) then
         declare
            L : constant Long_Float := Current_Auto_Lambda;
         begin
            if L = Long_Float'Last then
               BC_Lambda_Lbl.Set_Text
                 ("Estimated " & Lambda_Sym
                  & ":  (not yet computed)");
            else
               declare
                  Img : constant String := Long_Float'Image (L);
               begin
                  BC_Lambda_Lbl.Set_Text
                    ("Estimated " & Lambda_Sym & ":  " & Img);
               end;
            end if;
         end;
         BC_Lambda_Lbl.Set_Sensitive (True);
      else
         BC_Lambda_Lbl.Set_Text
           ("Estimated " & Lambda_Sym & ":  " & Dash_Sym);
         BC_Lambda_Lbl.Set_Sensitive (False);
      end if;
   end Update_Lambda_Readout;

   --  Synchronise fixed-value sub-widgets sensitivity.
   procedure Update_Fixed_Sensitivity is
      use Gtk.Toggle_Button;
      Fixed : constant Boolean :=
        Get_Active (Gtk_Toggle_Button (BC_Fixed_RB));
   begin
      if BC_Lambda_Combo /= null then
         BC_Lambda_Combo.Set_Sensitive (Fixed);
      end if;
      if BC_Lambda_Spin /= null then
         BC_Lambda_Spin.Set_Sensitive (Fixed);
      end if;
   end Update_Fixed_Sensitivity;

   --  ── Directory management callbacks ────────────────────────────────────

   procedure On_Add_Dir_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
      use Gtk.File_Chooser_Dialog;
      use Gtk.File_Chooser;
      use Gtk.Enums;
      D   : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
      Res : Gtk.Dialog.Gtk_Response_Type;
   begin
      if WS_Dir_LB = null then return; end if;
      Gtk.File_Chooser_Dialog.Gtk_New
        (D,
         Title  => "Add Source Directory",
         Parent => WS_Dialog,
         Action => Gtk.File_Chooser.Action_Select_Folder);
      declare
         Dummy : Gtk.Widget.Gtk_Widget;
         DLG   : constant Gtk.Dialog.Gtk_Dialog :=
           Gtk.Dialog.Gtk_Dialog (D);
         pragma Unreferenced (Dummy);
      begin
         Dummy := DLG.Add_Button ("_Add",    Gtk.Dialog.Gtk_Response_OK);
         Dummy := DLG.Add_Button ("_Cancel", Gtk.Dialog.Gtk_Response_Cancel);
      end;
      D.Show_All;
      Res := Gtk.Dialog.Gtk_Dialog (D).Run;
      if Res = Gtk.Dialog.Gtk_Response_OK then
         declare
            Path : constant String := D.Get_Filename;
            Row  : Gtk.List_Box_Row.Gtk_List_Box_Row;
            Lbl  : Gtk.Label.Gtk_Label;
            PUS  : constant Ada.Strings.Unbounded.Unbounded_String :=
              Ada.Strings.Unbounded.To_Unbounded_String (Path);
         begin
            declare
               Is_Dup : Boolean := False;
            begin
               for D2 of WS_New_Dirs loop
                  if D2 = PUS then Is_Dup := True; exit; end if;
               end loop;
               if not Is_Dup then
                  WS_New_Dirs.Append (PUS);
                  Gtk.List_Box_Row.Gtk_New (Row);
                  Gtk.Label.Gtk_New (Lbl, Path);
                  Lbl.Set_Halign (Gtk.Widget.Align_Start);
                  Row.Add (Lbl);
                  WS_Dir_LB.Add (Row);
                  Row.Show_All;
               end if;
            end;
         end;
      end if;
      D.Destroy;
   end On_Add_Dir_Clicked;

   procedure On_Remove_Dir_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      if WS_Dir_LB = null then return; end if;
      declare
         Row : constant Gtk.List_Box_Row.Gtk_List_Box_Row :=
           WS_Dir_LB.Get_Selected_Row;
      begin
         if Row = null then return; end if;
         declare
            Idx : constant Glib.Gint := Row.Get_Index;
         begin
            WS_Dir_LB.Remove (Row);
            if Integer (Idx) < Natural (WS_New_Dirs.Length) then
               WS_New_Dirs.Delete (Positive (Integer (Idx) + 1));
            end if;
         end;
      end;
   end On_Remove_Dir_Clicked;

   --  ── Box-Cox callbacks ─────────────────────────────────────────────────
   --  Note: callback parameter types must exactly match GtkAda's required
   --  Cb_Gtk_Toggle_Button_Void, Cb_Gtk_Combo_Box_Void, and
   --  Cb_Gtk_Spin_Button_Void access types.

   --  ── Xbar/S Box-Cox helpers ────────────────────────────────────────────

   --  Return auto-estimated lambdas for the three Xbar/S chart pairs as a
   --  formatted string, or "(not yet computed)" if none are active.
   function Current_Auto_XS_Lambda_Text return String is
      use Coyote_SQC.Charts;
      use Ada.Strings.Fixed;

      function Fmt (V : Long_Float) return String is
         IV : constant Long_Long_Integer :=
           Long_Long_Integer
             (Long_Float'Rounding (abs V * 100.0));
      begin
         return (if V < 0.0 then "-" else "")
           & Trim (Long_Long_Integer'Image (IV / 100), Ada.Strings.Left)
           & "."
           & (if IV mod 100 < 10 then "0" else "")
           & Trim (Long_Long_Integer'Image (IV mod 100), Ada.Strings.Left);
      end Fmt;

      Turn_Lam  : constant Coyote_SQC.App.Chart_Data :=
        Coyote_SQC.App.State.Charts (Turn_Tokens_Xbar);
      Tool_Lam  : constant Coyote_SQC.App.Chart_Data :=
        Coyote_SQC.App.State.Charts (Tool_Call_Tokens_Xbar);
      Think_Lam : constant Coyote_SQC.App.Chart_Data :=
        Coyote_SQC.App.State.Charts (Thinking_Tokens_Xbar);
   begin
      if Turn_Lam.Box_Cox_Active
        or else Tool_Lam.Box_Cox_Active
        or else Think_Lam.Box_Cox_Active
      then
         return
           "Turn: "    & Lambda_Sym & "=" & Fmt (Turn_Lam.Box_Cox_Lambda)
           & "  Tool: " & Lambda_Sym & "=" & Fmt (Tool_Lam.Box_Cox_Lambda)
           & "  Think: " & Lambda_Sym & "="
           & Fmt (Think_Lam.Box_Cox_Lambda);
      else
         return "(not yet computed)";
      end if;
   end Current_Auto_XS_Lambda_Text;

   procedure Update_XS_Lambda_Readout is
      use Gtk.Toggle_Button;
   begin
      if XS_Lambda_Lbl = null or XS_Auto_RB = null then return; end if;
      if Get_Active (Gtk_Toggle_Button (XS_Auto_RB)) then
         XS_Lambda_Lbl.Set_Text
           ("Estimated " & Lambda_Sym & ":  "
            & Current_Auto_XS_Lambda_Text);
         XS_Lambda_Lbl.Set_Sensitive (True);
      else
         XS_Lambda_Lbl.Set_Text
           ("Estimated " & Lambda_Sym & ":  " & Dash_Sym);
         XS_Lambda_Lbl.Set_Sensitive (False);
      end if;
   end Update_XS_Lambda_Readout;

   procedure Update_XS_Fixed_Sensitivity is
      use Gtk.Toggle_Button;
      Fixed : constant Boolean :=
        Get_Active (Gtk_Toggle_Button (XS_Fixed_RB));
   begin
      if XS_Lambda_Combo /= null then
         XS_Lambda_Combo.Set_Sensitive (Fixed);
      end if;
      if XS_Lambda_Spin /= null then
         XS_Lambda_Spin.Set_Sensitive (Fixed);
      end if;
   end Update_XS_Fixed_Sensitivity;

   --  ── Xbar/S Box-Cox callbacks ──────────────────────────────────────────

   procedure On_XS_Enabled_Toggled
     (CB : access Gtk.Toggle_Button.Gtk_Toggle_Button_Record'Class)
   is
      pragma Unreferenced (CB);
      use Gtk.Toggle_Button;
   begin
      if XS_Enabled_CB = null or XS_Sub_VBox = null then return; end if;
      XS_Sub_VBox.Set_Sensitive
        (Get_Active (Gtk_Toggle_Button (XS_Enabled_CB)));
   end On_XS_Enabled_Toggled;

   procedure On_XS_Source_Toggled
     (RB : access Gtk.Toggle_Button.Gtk_Toggle_Button_Record'Class)
   is
      pragma Unreferenced (RB);
   begin
      Update_XS_Fixed_Sensitivity;
      Update_XS_Lambda_Readout;
   end On_XS_Source_Toggled;

   procedure On_XS_Combo_Changed
     (CB : access Gtk.Combo_Box.Gtk_Combo_Box_Record'Class)
   is
      pragma Unreferenced (CB);
      Idx : constant Glib.Gint :=
        Gtk.Combo_Box.Get_Active
          (Gtk.Combo_Box.Gtk_Combo_Box (XS_Lambda_Combo));
   begin
      if XS_Lambda_Spin = null or XS_Combo_Updating then return; end if;
      XS_Combo_Updating := True;
      case Idx is
         when 0 => XS_Lambda_Spin.Set_Value (0.0);
         when 1 => XS_Lambda_Spin.Set_Value (0.5);
         when 2 => XS_Lambda_Spin.Set_Value (1.0);
         when others => null;
      end case;
      XS_Combo_Updating := False;
   end On_XS_Combo_Changed;

   procedure On_XS_Spin_Value_Changed
     (SB : access Gtk.Spin_Button.Gtk_Spin_Button_Record'Class)
   is
      pragma Unreferenced (SB);
      Val : constant Gdouble :=
        Gtk.Spin_Button.Get_Value (XS_Lambda_Spin);
   begin
      if XS_Lambda_Combo = null or XS_Combo_Updating then return; end if;
      XS_Combo_Updating := True;
      if abs (Val - 0.0) < 0.005 then
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (XS_Lambda_Combo), 0);
      elsif abs (Val - 0.5) < 0.005 then
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (XS_Lambda_Combo), 1);
      elsif abs (Val - 1.0) < 0.005 then
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (XS_Lambda_Combo), 2);
      else
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (XS_Lambda_Combo), 3);
      end if;
      XS_Combo_Updating := False;
   end On_XS_Spin_Value_Changed;

   procedure On_BC_Enabled_Toggled
     (CB : access Gtk.Toggle_Button.Gtk_Toggle_Button_Record'Class)
   is
      pragma Unreferenced (CB);
      use Gtk.Toggle_Button;
   begin
      if BC_Enabled_CB = null or BC_Sub_VBox = null then return; end if;
      BC_Sub_VBox.Set_Sensitive
        (Get_Active (Gtk_Toggle_Button (BC_Enabled_CB)));
   end On_BC_Enabled_Toggled;

   procedure On_BC_Source_Toggled
     (RB : access Gtk.Toggle_Button.Gtk_Toggle_Button_Record'Class)
   is
      pragma Unreferenced (RB);
   begin
      Update_Fixed_Sensitivity;
      Update_Lambda_Readout;
   end On_BC_Source_Toggled;

   procedure On_BC_Combo_Changed
     (CB : access Gtk.Combo_Box.Gtk_Combo_Box_Record'Class)
   is
      pragma Unreferenced (CB);
      Idx : constant Glib.Gint :=
        Gtk.Combo_Box.Get_Active
          (Gtk.Combo_Box.Gtk_Combo_Box (BC_Lambda_Combo));
   begin
      if BC_Lambda_Spin = null or BC_Combo_Updating then return; end if;
      BC_Combo_Updating := True;
      case Idx is
         when 0 => BC_Lambda_Spin.Set_Value (0.0);
         when 1 => BC_Lambda_Spin.Set_Value (0.5);
         when 2 => BC_Lambda_Spin.Set_Value (1.0);
         when others => null;  --  custom: leave spin unchanged
      end case;
      BC_Combo_Updating := False;
   end On_BC_Combo_Changed;

   procedure On_BC_Spin_Value_Changed
     (SB : access Gtk.Spin_Button.Gtk_Spin_Button_Record'Class)
   is
      pragma Unreferenced (SB);
      Val : constant Gdouble :=
        Gtk.Spin_Button.Get_Value (BC_Lambda_Spin);
   begin
      if BC_Lambda_Combo = null or BC_Combo_Updating then return; end if;
      BC_Combo_Updating := True;
      if abs (Val - 0.0) < 0.005 then
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Lambda_Combo), 0);
      elsif abs (Val - 0.5) < 0.005 then
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Lambda_Combo), 1);
      elsif abs (Val - 1.0) < 0.005 then
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Lambda_Combo), 2);
      else
         Gtk.Combo_Box.Set_Active
           (Gtk.Combo_Box.Gtk_Combo_Box (BC_Lambda_Combo), 3);
      end if;
      BC_Combo_Updating := False;
   end On_BC_Spin_Value_Changed;

   --  ── Show_Dialog ────────────────────────────────────────────────────────

   procedure Show_Dialog is
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Gtk.Dialog;
      use Gtk.Toggle_Button;

      D        : Gtk_Dialog;
      VBox     : Gtk.Box.Gtk_Box;
      Name_E   : Gtk.GEntry.Gtk_Entry;
      Dir_LB   : Gtk.List_Box.Gtk_List_Box;
      Filter_Buf : Gtk.Text_Buffer.Gtk_Text_Buffer := null;
      Res      : Gtk_Response_Type;

      New_Name   : Unbounded_String :=
        Coyote_SQC.App.State.Workspace.Name;
      New_Dirs   : String_Vectors.Vector :=
        Coyote_SQC.App.State.Workspace.Source_Directories;

   begin
      if Coyote_SQC.App.State = null then return; end if;

      --  Reset module-level BC widget handles.
      BC_Enabled_CB   := null;
      BC_Sub_VBox     := null;
      BC_Auto_RB      := null;
      BC_Fixed_RB     := null;
      BC_Lambda_Combo := null;
      BC_Lambda_Spin  := null;
      BC_Lambda_Lbl   := null;
      BC_Combo_Updating := False;

      --  Reset Xbar/S Box-Cox handles.
      XS_Enabled_CB    := null;
      XS_Sub_VBox      := null;
      XS_Auto_RB       := null;
      XS_Fixed_RB      := null;
      XS_Lambda_Combo  := null;
      XS_Lambda_Spin   := null;
      XS_Lambda_Lbl    := null;
      XS_Combo_Updating := False;

      Gtk.Dialog.Gtk_New
        (D, "Workspace Settings", Coyote_SQC.App.State.Main_Window,
         Gtk.Dialog.Modal);
      D.Set_Default_Size (500, 540);
      WS_Dialog := D;

      Gtk.Box.Gtk_New_Vbox (VBox);
      VBox.Set_Spacing (6);
      VBox.Set_Border_Width (8);

      --  ── Name field ─────────────────────────────────────────────────────
      declare
         HBox : Gtk.Box.Gtk_Box;
         Lbl  : Gtk.Label.Gtk_Label;
      begin
         Gtk.Box.Gtk_New_Hbox (HBox);
         Gtk.Label.Gtk_New (Lbl, "Name:");
         HBox.Pack_Start (Lbl, False, False, 4);
         Gtk.GEntry.Gtk_New (Name_E);
         Name_E.Set_Text (To_String (New_Name));
         Name_E.Set_Hexpand (True);
         HBox.Pack_Start (Name_E, True, True, 4);
         VBox.Pack_Start (HBox, False, False, 0);
      end;

      --  ── Source directories ─────────────────────────────────────────────
      declare
         Lbl    : Gtk.Label.Gtk_Label;
         HBox   : Gtk.Box.Gtk_Box;
         Add_B  : Gtk.Button.Gtk_Button;
         Rm_B   : Gtk.Button.Gtk_Button;
         Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      begin
         Gtk.Label.Gtk_New (Lbl, "Source Directories:");
         Lbl.Set_Halign (Gtk.Widget.Align_Start);
         VBox.Pack_Start (Lbl, False, False, 0);

         Gtk.List_Box.Gtk_New (Dir_LB);
         for Dir of New_Dirs loop
            declare
               Row  : Gtk.List_Box_Row.Gtk_List_Box_Row;
               DLbl : Gtk.Label.Gtk_Label;
            begin
               Gtk.List_Box_Row.Gtk_New (Row);
               Gtk.Label.Gtk_New (DLbl, To_String (Dir));
               DLbl.Set_Halign (Gtk.Widget.Align_Start);
               Row.Add (DLbl);
               Dir_LB.Add (Row);
            end;
         end loop;
         Gtk.Scrolled_Window.Gtk_New (Scroll);
         Scroll.Set_Policy
           (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
         Scroll.Set_Size_Request (-1, 100);
         Scroll.Add (Dir_LB);
         VBox.Pack_Start (Scroll, True, True, 0);

         Gtk.Box.Gtk_New_Hbox (HBox);
         Gtk.Button.Gtk_New (Add_B, "Add Directory...");
         Gtk.Button.Gtk_New (Rm_B,  "Remove Selected");
         Add_B.On_Clicked (On_Add_Dir_Clicked'Access);
         Rm_B.On_Clicked  (On_Remove_Dir_Clicked'Access);
         HBox.Pack_Start (Add_B, False, False, 0);
         HBox.Pack_Start (Rm_B,  False, False, 4);
         VBox.Pack_Start (HBox, False, False, 0);
         WS_Dir_LB   := Dir_LB;
         WS_New_Dirs := New_Dirs;
      end;

      --  ── Model filter ───────────────────────────────────────────────────
      declare
         Filter_Lbl    : Gtk.Label.Gtk_Label;
         Filter_TV     : Gtk.Text_View.Gtk_Text_View;
         Filter_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
         Filter_Text   : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Gtk.Label.Gtk_New (Filter_Lbl,
           "Model Filter (one per line; empty = all):");
         Filter_Lbl.Set_Halign (Gtk.Widget.Align_Start);
         VBox.Pack_Start (Filter_Lbl, False, False, 0);
         Gtk.Text_Buffer.Gtk_New (Filter_Buf);
         for F of Coyote_SQC.App.State.Workspace.Model_Filter loop
            Ada.Strings.Unbounded.Append (Filter_Text, F);
            Ada.Strings.Unbounded.Append
              (Filter_Text,
               Ada.Strings.Unbounded.To_Unbounded_String ("" & ASCII.LF));
         end loop;
         declare
            Iter : Gtk.Text_Iter.Gtk_Text_Iter;
         begin
            Filter_Buf.Get_End_Iter (Iter);
            Filter_Buf.Insert
              (Iter, Ada.Strings.Unbounded.To_String (Filter_Text));
         end;
         Gtk.Text_View.Gtk_New (Filter_TV, Filter_Buf);
         Filter_TV.Set_Wrap_Mode (Gtk.Enums.Wrap_None);
         Gtk.Scrolled_Window.Gtk_New (Filter_Scroll);
         Filter_Scroll.Set_Policy
           (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
         Filter_Scroll.Set_Size_Request (-1, 70);
         Filter_Scroll.Add (Filter_TV);
         VBox.Pack_Start (Filter_Scroll, False, False, 0);
      end;

      --  ── I/MR Chart Transformation (Box-Cox) ───────────────────────────
      declare
         Frame    : Gtk.Frame.Gtk_Frame;
         Sub_VBox : Gtk.Box.Gtk_Box;
         Inner_VBox : Gtk.Box.Gtk_Box;
         Sub_HBox : Gtk.Box.Gtk_Box;
         CB_EN    : Gtk.Check_Button.Gtk_Check_Button;
         RB_Auto  : Gtk.Radio_Button.Gtk_Radio_Button;
         RB_Fixed : Gtk.Radio_Button.Gtk_Radio_Button;
         Combo    : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
         Spin     : Gtk.Spin_Button.Gtk_Spin_Button;
         Lbl_Est  : Gtk.Label.Gtk_Label;
         Lbl_Note : Gtk.Label.Gtk_Label;
         Lbl_Lam  : Gtk.Label.Gtk_Label;

         BC_Cfg : constant Box_Cox_Config :=
           Coyote_SQC.App.State.Workspace.I_Chart_Box_Cox;
      begin
         Gtk.Frame.Gtk_New (Frame, "I/MR Chart Transformation");
         Gtk.Box.Gtk_New_Vbox (Sub_VBox);
         Sub_VBox.Set_Spacing (4);
         Sub_VBox.Set_Border_Width (6);

         --  Enable checkbox.
         Gtk.Check_Button.Gtk_New
           (CB_EN,
            "Apply Box-Cox transformation to Session Token I/MR charts");
         Set_Active (Gtk_Toggle_Button (CB_EN), BC_Cfg.Enabled);
         Gtk.Toggle_Button.On_Toggled
           (Gtk_Toggle_Button (CB_EN), On_BC_Enabled_Toggled'Access);
         Sub_VBox.Pack_Start (CB_EN, False, False, 0);

         --  Inner sub-section (enabled only when checkbox is on).
         Gtk.Box.Gtk_New_Vbox (Inner_VBox);
         Inner_VBox.Set_Spacing (3);
         Inner_VBox.Set_Sensitive (BC_Cfg.Enabled);

         --  Auto radio button.
         Gtk.Radio_Button.Gtk_New
           (RB_Auto, Label => "Estimate from setup interval");
         Set_Active
           (Gtk_Toggle_Button (RB_Auto), BC_Cfg.Lambda_Source = Auto);
         Gtk.Toggle_Button.On_Toggled
           (Gtk_Toggle_Button (RB_Auto), On_BC_Source_Toggled'Access);
         Inner_VBox.Pack_Start (RB_Auto, False, False, 0);

         --  Fixed radio + combo + spin on one row.
         Gtk.Box.Gtk_New_Hbox (Sub_HBox);
         Gtk.Radio_Button.Gtk_New
           (RB_Fixed, Group => RB_Auto, Label => "Fixed:");
         Set_Active
           (Gtk_Toggle_Button (RB_Fixed), BC_Cfg.Lambda_Source = Fixed);
         Gtk.Toggle_Button.On_Toggled
           (Gtk_Toggle_Button (RB_Fixed), On_BC_Source_Toggled'Access);
         Sub_HBox.Pack_Start (RB_Fixed, False, False, 0);

         --  Combo for named presets.
         Gtk.Combo_Box_Text.Gtk_New (Combo);
         Combo.Append_Text ("ln (" & Lambda_Sym & "=0)");
         Combo.Append_Text (Sqrt_Sym & " (" & Lambda_Sym & "=0.5)");
         Combo.Append_Text ("no transform (" & Lambda_Sym & "=1)");
         Combo.Append_Text ("custom");
         --  Select matching entry or custom.
         if BC_Cfg.Lambda_Source = Fixed then
            if abs (BC_Cfg.Fixed_Lambda - 0.0) < 0.005 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (Combo), 0);
            elsif abs (BC_Cfg.Fixed_Lambda - 0.5) < 0.005 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (Combo), 1);
            elsif abs (BC_Cfg.Fixed_Lambda - 1.0) < 0.005 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (Combo), 2);
            else
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (Combo), 3);
            end if;
         else
            Gtk.Combo_Box.Set_Active
              (Gtk.Combo_Box.Gtk_Combo_Box (Combo), 0);
         end if;
         Gtk.Combo_Box.On_Changed
           (Gtk.Combo_Box.Gtk_Combo_Box (Combo),
            On_BC_Combo_Changed'Access);
         Combo.Set_Sensitive (BC_Cfg.Lambda_Source = Fixed);
         Sub_HBox.Pack_Start (Combo, False, False, 4);

         --  Spin button for custom lambda value.
         Gtk.Spin_Button.Gtk_New
           (Spin,
            Min  => -2.0,
            Max  =>  2.0,
            Step =>  0.01);
         Spin.Set_Digits (2);
         Spin.Set_Value (Gdouble (BC_Cfg.Fixed_Lambda));
         Gtk.Spin_Button.On_Value_Changed
           (Spin, On_BC_Spin_Value_Changed'Access);
         Spin.Set_Sensitive (BC_Cfg.Lambda_Source = Fixed);

         Gtk.Label.Gtk_New (Lbl_Lam, Lambda_Sym & " =");
         Sub_HBox.Pack_Start (Lbl_Lam, False, False, 4);
         Sub_HBox.Pack_Start (Spin, False, False, 0);
         Inner_VBox.Pack_Start (Sub_HBox, False, False, 0);

         --  Estimated lambda readout.
         Gtk.Label.Gtk_New
           (Lbl_Est,
            "Estimated " & Lambda_Sym & ":  (not yet computed)");
         Lbl_Est.Set_Halign (Gtk.Widget.Align_Start);
         Inner_VBox.Pack_Start (Lbl_Est, False, False, 2);

         --  Note label.
         Gtk.Label.Gtk_New
           (Lbl_Note,
            "Note: I chart limits are shown in original (token) units."
            & ASCII.LF
            & "      MR chart y-axis shows values in transformed units.");
         Lbl_Note.Set_Halign (Gtk.Widget.Align_Start);
         Inner_VBox.Pack_Start (Lbl_Note, False, False, 2);

         Sub_VBox.Pack_Start (Inner_VBox, False, False, 0);
         Frame.Add (Sub_VBox);
         VBox.Pack_Start (Frame, False, False, 4);

         --  Capture module-level handles.
         BC_Sub_VBox     := Inner_VBox;
         BC_Enabled_CB   := CB_EN;
         BC_Auto_RB      := RB_Auto;
         BC_Fixed_RB     := RB_Fixed;
         BC_Lambda_Combo := Combo;
         BC_Lambda_Spin  := Spin;
         BC_Lambda_Lbl   := Lbl_Est;

         --  Initialise readout after all handles are captured.
         Update_Lambda_Readout;
      end;


      --  ── Xbar/S Chart Transformation (Box-Cox) ─────────────────────────
      declare
         XS_Frame    : Gtk.Frame.Gtk_Frame;
         XS_Sub_VB   : Gtk.Box.Gtk_Box;
         XS_Inner_VB : Gtk.Box.Gtk_Box;
         XS_Sub_HB   : Gtk.Box.Gtk_Box;
         XS_CB_EN    : Gtk.Check_Button.Gtk_Check_Button;
         XS_RB_Auto  : Gtk.Radio_Button.Gtk_Radio_Button;
         XS_RB_Fixed : Gtk.Radio_Button.Gtk_Radio_Button;
         XS_Combo    : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
         XS_Spin     : Gtk.Spin_Button.Gtk_Spin_Button;
         XS_Lbl_Est  : Gtk.Label.Gtk_Label;
         XS_Lbl_Note : Gtk.Label.Gtk_Label;
         XS_Lbl_Lam  : Gtk.Label.Gtk_Label;

         XS_Cfg : constant Box_Cox_Config :=
           Coyote_SQC.App.State.Workspace.Xbar_S_Box_Cox;
      begin
         Gtk.Frame.Gtk_New
           (XS_Frame, "Xbar/S Chart Transformation");
         Gtk.Box.Gtk_New_Vbox (XS_Sub_VB);
         XS_Sub_VB.Set_Spacing (4);
         XS_Sub_VB.Set_Border_Width (6);

         --  Enable checkbox.
         Gtk.Check_Button.Gtk_New
           (XS_CB_EN,
            "Apply Box-Cox transformation to per-turn Xbar/S charts");
         Set_Active
           (Gtk_Toggle_Button (XS_CB_EN), XS_Cfg.Enabled);
         Gtk.Toggle_Button.On_Toggled
           (Gtk_Toggle_Button (XS_CB_EN), On_XS_Enabled_Toggled'Access);
         XS_Sub_VB.Pack_Start (XS_CB_EN, False, False, 0);

         --  Inner sub-section (sensitive only when checkbox is on).
         Gtk.Box.Gtk_New_Vbox (XS_Inner_VB);
         XS_Inner_VB.Set_Spacing (3);
         XS_Inner_VB.Set_Sensitive (XS_Cfg.Enabled);

         --  Auto radio button.
         Gtk.Radio_Button.Gtk_New
           (XS_RB_Auto,
            Label => "Estimate from setup interval (per-pair)");
         Set_Active
           (Gtk_Toggle_Button (XS_RB_Auto),
            XS_Cfg.Lambda_Source = Auto);
         Gtk.Toggle_Button.On_Toggled
           (Gtk_Toggle_Button (XS_RB_Auto), On_XS_Source_Toggled'Access);
         XS_Inner_VB.Pack_Start (XS_RB_Auto, False, False, 0);

         --  Fixed radio + combo + spin on one row.
         Gtk.Box.Gtk_New_Hbox (XS_Sub_HB);
         Gtk.Radio_Button.Gtk_New
           (XS_RB_Fixed, Group => XS_RB_Auto, Label => "Fixed:");
         Set_Active
           (Gtk_Toggle_Button (XS_RB_Fixed),
            XS_Cfg.Lambda_Source = Fixed);
         Gtk.Toggle_Button.On_Toggled
           (Gtk_Toggle_Button (XS_RB_Fixed), On_XS_Source_Toggled'Access);
         XS_Sub_HB.Pack_Start (XS_RB_Fixed, False, False, 0);

         --  Combo for named presets.
         Gtk.Combo_Box_Text.Gtk_New (XS_Combo);
         XS_Combo.Append_Text ("ln (" & Lambda_Sym & "=0)");
         XS_Combo.Append_Text (Sqrt_Sym & " (" & Lambda_Sym & "=0.5)");
         XS_Combo.Append_Text ("no transform (" & Lambda_Sym & "=1)");
         XS_Combo.Append_Text ("custom");
         if XS_Cfg.Lambda_Source = Fixed then
            if abs (XS_Cfg.Fixed_Lambda - 0.0) < 0.005 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (XS_Combo), 0);
            elsif abs (XS_Cfg.Fixed_Lambda - 0.5) < 0.005 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (XS_Combo), 1);
            elsif abs (XS_Cfg.Fixed_Lambda - 1.0) < 0.005 then
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (XS_Combo), 2);
            else
               Gtk.Combo_Box.Set_Active
                 (Gtk.Combo_Box.Gtk_Combo_Box (XS_Combo), 3);
            end if;
         else
            Gtk.Combo_Box.Set_Active
              (Gtk.Combo_Box.Gtk_Combo_Box (XS_Combo), 0);
         end if;
         Gtk.Combo_Box.On_Changed
           (Gtk.Combo_Box.Gtk_Combo_Box (XS_Combo),
            On_XS_Combo_Changed'Access);
         XS_Combo.Set_Sensitive (XS_Cfg.Lambda_Source = Fixed);
         XS_Sub_HB.Pack_Start (XS_Combo, False, False, 4);

         --  Spin button for custom lambda value.
         Gtk.Spin_Button.Gtk_New
           (XS_Spin,
            Min  => -2.0,
            Max  =>  2.0,
            Step =>  0.01);
         XS_Spin.Set_Digits (2);
         XS_Spin.Set_Value (Gdouble (XS_Cfg.Fixed_Lambda));
         Gtk.Spin_Button.On_Value_Changed
           (XS_Spin, On_XS_Spin_Value_Changed'Access);
         XS_Spin.Set_Sensitive (XS_Cfg.Lambda_Source = Fixed);

         Gtk.Label.Gtk_New (XS_Lbl_Lam, Lambda_Sym & " =");
         XS_Sub_HB.Pack_Start (XS_Lbl_Lam, False, False, 4);
         XS_Sub_HB.Pack_Start (XS_Spin, False, False, 0);
         XS_Inner_VB.Pack_Start (XS_Sub_HB, False, False, 0);

         --  Estimated lambda readout (shows per-pair lambdas for Auto).
         Gtk.Label.Gtk_New
           (XS_Lbl_Est,
            "Estimated " & Lambda_Sym & ":  (not yet computed)");
         XS_Lbl_Est.Set_Halign (Gtk.Widget.Align_Start);
         XS_Inner_VB.Pack_Start (XS_Lbl_Est, False, False, 2);

         --  Note label.
         Gtk.Label.Gtk_New
           (XS_Lbl_Note,
            "Note: Xbar chart limits are shown in original (token)"
            & " units." & ASCII.LF
            & "      s chart y-axis shows values in transformed"
            & " units.");
         XS_Lbl_Note.Set_Halign (Gtk.Widget.Align_Start);
         XS_Inner_VB.Pack_Start (XS_Lbl_Note, False, False, 2);

         XS_Sub_VB.Pack_Start (XS_Inner_VB, False, False, 0);
         XS_Frame.Add (XS_Sub_VB);
         VBox.Pack_Start (XS_Frame, False, False, 4);

         --  ── EWMA parameters frame ─────────────────────────────────────
         declare
            EWMA_Frame  : Gtk.Frame.Gtk_Frame;
            EWMA_VBox   : Gtk.Box.Gtk_Box;
            EWMA_W_Row  : Gtk.Box.Gtk_Box;
            EWMA_L_Row  : Gtk.Box.Gtk_Box;
            EWMA_W_Lbl  : Gtk.Label.Gtk_Label;
            EWMA_L_Lbl  : Gtk.Label.Gtk_Label;
            EWMA_W_Sp   : Gtk.Spin_Button.Gtk_Spin_Button;
            EWMA_L_Sp   : Gtk.Spin_Button.Gtk_Spin_Button;
            Note_Lbl    : Gtk.Label.Gtk_Label;
         begin
            Gtk.Frame.Gtk_New (EWMA_Frame, "EWMA Chart Parameters");
            Gtk.Box.Gtk_New_Vbox (EWMA_VBox);
            EWMA_VBox.Set_Spacing (4);
            EWMA_VBox.Set_Border_Width (6);

            --  Smoothing weight (lambda) row.
            Gtk.Box.Gtk_New_Hbox (EWMA_W_Row);
            EWMA_W_Row.Set_Spacing (8);
            Gtk.Label.Gtk_New
              (EWMA_W_Lbl,
               "Smoothing weight (" & Lambda_Sym & "):  "
               & "(range 0.01 - 1.00)");
            EWMA_W_Row.Pack_Start (EWMA_W_Lbl, False, False, 0);
            Gtk.Spin_Button.Gtk_New
              (EWMA_W_Sp,
               Min  => Glib.Gdouble (0.01),
               Max  => Glib.Gdouble (1.00),
               Step => Glib.Gdouble (0.01));
            EWMA_W_Sp.Set_Digits (2);
            EWMA_W_Sp.Set_Value
              (Glib.Gdouble
                 (Coyote_SQC.App.State.Workspace.EWMA_Weight));
            EWMA_W_Row.Pack_Start (EWMA_W_Sp, False, False, 0);
            EWMA_VBox.Pack_Start (EWMA_W_Row, False, False, 4);

            --  Sigma multiplier (L) row.
            Gtk.Box.Gtk_New_Hbox (EWMA_L_Row);
            EWMA_L_Row.Set_Spacing (8);
            Gtk.Label.Gtk_New
              (EWMA_L_Lbl,
               "Sigma multiplier (L):        "
               & "(range 1.00 - 4.00)");
            EWMA_L_Row.Pack_Start (EWMA_L_Lbl, False, False, 0);
            Gtk.Spin_Button.Gtk_New
              (EWMA_L_Sp,
               Min  => Glib.Gdouble (1.00),
               Max  => Glib.Gdouble (4.00),
               Step => Glib.Gdouble (0.25));
            EWMA_L_Sp.Set_Digits (2);
            EWMA_L_Sp.Set_Value
              (Glib.Gdouble (Coyote_SQC.App.State.Workspace.EWMA_L));
            EWMA_L_Row.Pack_Start (EWMA_L_Sp, False, False, 0);
            EWMA_VBox.Pack_Start (EWMA_L_Row, False, False, 4);

            --  Explanatory note.
            Gtk.Label.Gtk_New
              (Note_Lbl,
               "Smaller " & Lambda_Sym & " gives more smoothing and better"
               & " detection of small sustained shifts.");
            Note_Lbl.Set_Alignment (0.0, 0.5);
            EWMA_VBox.Pack_Start (Note_Lbl, False, False, 2);

            EWMA_Frame.Add (EWMA_VBox);
            VBox.Pack_Start (EWMA_Frame, False, False, 4);

            --  Capture module-level handles.
            EWMA_Weight_Spin := EWMA_W_Sp;
            EWMA_L_Spin      := EWMA_L_Sp;
         end;

         --  Capture module-level handles.
         XS_Sub_VBox     := XS_Inner_VB;
         XS_Enabled_CB   := XS_CB_EN;
         XS_Auto_RB      := XS_RB_Auto;
         XS_Fixed_RB     := XS_RB_Fixed;
         XS_Lambda_Combo := XS_Combo;
         XS_Lambda_Spin  := XS_Spin;
         XS_Lambda_Lbl   := XS_Lbl_Est;

         --  Initialise readout after all handles are captured.
         Update_XS_Lambda_Readout;
      end;

      D.Get_Content_Area.Pack_Start (VBox, True, True, 0);
      declare
         Dummy : Gtk.Widget.Gtk_Widget;
         pragma Unreferenced (Dummy);
      begin
         Dummy := D.Add_Button ("_OK",     Gtk_Response_OK);
         Dummy := D.Add_Button ("_Cancel", Gtk_Response_Cancel);
      end;
      D.Show_All;
      Res := D.Run;
      if Res = Gtk_Response_OK then
         --  Apply name change.
         Coyote_SQC.App.State.Workspace.Name :=
           To_Unbounded_String (Name_E.Get_Text);

         --  Apply source directories.
         Coyote_SQC.App.State.Workspace.Source_Directories := WS_New_Dirs;

         --  Parse model filter from text view.
         if Filter_Buf /= null then
            declare
               use Ada.Strings.Fixed;
               use Ada.Strings;
               SI   : Gtk.Text_Iter.Gtk_Text_Iter;
               EI   : Gtk.Text_Iter.Gtk_Text_Iter;
               Text : Ada.Strings.Unbounded.Unbounded_String;
            begin
               Filter_Buf.Get_Start_Iter (SI);
               Filter_Buf.Get_End_Iter (EI);
               Text := Ada.Strings.Unbounded.To_Unbounded_String
                 (Filter_Buf.Get_Text (SI, EI));
               Coyote_SQC.App.State.Workspace.Model_Filter.Clear;
               declare
                  S     : constant String :=
                    Ada.Strings.Unbounded.To_String (Text);
                  Start : Positive := S'First;
                  procedure Add_Token (T : String) is
                     TT : constant String := Trim (T, Both);
                  begin
                     if TT'Length > 0 then
                        Coyote_SQC.App.State.Workspace.Model_Filter.Append
                          (Ada.Strings.Unbounded.To_Unbounded_String (TT));
                     end if;
                  end Add_Token;
               begin
                  for I in S'Range loop
                     if S (I) = ASCII.LF then
                        Add_Token (S (Start .. I - 1));
                        Start := I + 1;
                     end if;
                  end loop;
                  if Start <= S'Last then
                     Add_Token (S (Start .. S'Last));
                  end if;
               end;
            end;
         end if;

         --  Apply Box-Cox configuration.
         if BC_Enabled_CB /= null then
            declare
               New_BC : Coyote_SQC.Data_Model.Box_Cox_Config;
            begin
               New_BC.Enabled :=
                 Get_Active (Gtk_Toggle_Button (BC_Enabled_CB));
               New_BC.Lambda_Source :=
                 (if Get_Active (Gtk_Toggle_Button (BC_Auto_RB))
                  then Coyote_SQC.Data_Model.Auto
                  else Coyote_SQC.Data_Model.Fixed);
               New_BC.Fixed_Lambda :=
                 Long_Float
                   (Gtk.Spin_Button.Get_Value (BC_Lambda_Spin));
               Coyote_SQC.App.State.Workspace.I_Chart_Box_Cox := New_BC;
            end;
         end if;

         --  Apply Xbar/S Box-Cox configuration.
         if XS_Enabled_CB /= null then
            declare
               New_XS : Coyote_SQC.Data_Model.Box_Cox_Config;
            begin
               New_XS.Enabled :=
                 Get_Active (Gtk_Toggle_Button (XS_Enabled_CB));
               New_XS.Lambda_Source :=
                 (if Get_Active (Gtk_Toggle_Button (XS_Auto_RB))
                  then Coyote_SQC.Data_Model.Auto
                  else Coyote_SQC.Data_Model.Fixed);
               New_XS.Fixed_Lambda :=
                 Long_Float
                   (Gtk.Spin_Button.Get_Value (XS_Lambda_Spin));
               Coyote_SQC.App.State.Workspace.Xbar_S_Box_Cox := New_XS;
            end;
         end if;
         --  Apply EWMA parameters.
         if EWMA_Weight_Spin /= null then
            Coyote_SQC.App.State.Workspace.EWMA_Weight :=
              Long_Float (Gtk.Spin_Button.Get_Value (EWMA_Weight_Spin));
         end if;
         if EWMA_L_Spin /= null then
            Coyote_SQC.App.State.Workspace.EWMA_L :=
              Long_Float (Gtk.Spin_Button.Get_Value (EWMA_L_Spin));
         end if;


         Coyote_SQC.App.State.Modified := True;
         Coyote_SQC.App.Update_Title;
         Coyote_SQC.App.Reload_Sessions;

         --  Check setup interval integrity.
         declare
            Chk : constant Coyote_SQC.Workspace.Integrity.Check_Result :=
              Coyote_SQC.Workspace.Integrity.Check
                (Coyote_SQC.App.State.Workspace,
                 Coyote_SQC.App.State.Sessions);
         begin
            if Chk.Missing_Count > 0 then
               if Coyote_SQC.UI.Dialogs.Confirm
                 (Coyote_SQC.App.State.Main_Window,
                  "Setup Interval Affected",
                  Natural'Image (Chk.Missing_Count)
                  & " setup session(s) are no longer in the filtered data."
                  & " Clear the setup interval?")
               then
                  Coyote_SQC.Workspace.Integrity.Remove_Missing
                    (Coyote_SQC.App.State.Workspace,
                     Coyote_SQC.App.State.Sessions);
               end if;
            end if;
         end;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      end if;

      --  Clean up module-level handles.
      WS_Dir_LB       := null;
      WS_Dialog       := null;
      BC_Enabled_CB   := null;
      BC_Sub_VBox     := null;
      BC_Auto_RB      := null;
      BC_Fixed_RB     := null;
      BC_Lambda_Combo := null;
      BC_Lambda_Spin  := null;
      BC_Lambda_Lbl   := null;
      XS_Enabled_CB   := null;
      XS_Sub_VBox     := null;
      XS_Auto_RB      := null;
      XS_Fixed_RB     := null;
      XS_Lambda_Combo := null;
      XS_Lambda_Spin  := null;
      XS_Lambda_Lbl   := null;
      EWMA_Weight_Spin := null;
      EWMA_L_Spin      := null;
      D.Destroy;
   end Show_Dialog;

end Coyote_SQC.UI.Workspace_Settings;
