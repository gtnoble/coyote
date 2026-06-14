--  Coyote_SQC.UI.Workspace_Settings body.
--
--  Accessible via Workspace → Workspace Settings…
--
--  Per-chart Box-Cox, estimation method, and EWMA parameters are configured
--  through the Chart Settings dialog (§11.12), not through this dialog.
--
--  Project: coyote

with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.App;
with Coyote_SQC.Data_Model;
with Coyote_SQC.UI.Chart_Canvas;
with Glib;
with Gtk.Box;
with Gtk.Button;
with Gtk.Check_Button;
with Gtk.Toggle_Button;
with Gtk.Dialog;             use Gtk.Dialog;
with Gtk.Enums;
with Gtk.GEntry;
with Gtk.Label;
with Gtk.List_Box;
with Gtk.List_Box_Row;
with Gtk.Scrolled_Window;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
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
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Coyote_SQC.Data_Model.String_Vectors.Vector;
   use Glib;

   --  Module-level state for the currently-open settings dialog.
   WS_Dir_LB   : Gtk.List_Box.Gtk_List_Box := null;
   WS_New_Dirs : Coyote_SQC.Data_Model.String_Vectors.Vector;
   WS_Dialog   : Gtk.Dialog.Gtk_Dialog     := null;
   WS_Analyze_All_CB : Gtk.Check_Button.Gtk_Check_Button     := null;
   WS_Dir_Scroll     : Gtk.Scrolled_Window.Gtk_Scrolled_Window := null;
   WS_Dir_HBox       : Gtk.Box.Gtk_Box                         := null;
   WS_Interp_CB : Gtk.Check_Button.Gtk_Check_Button := null;

   --  ── Directory management callbacks ─────────────────────────────────────

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
            PUS  : constant Unbounded_String :=
              To_Unbounded_String (Path);
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

   --  ── Analyze-all toggle callback ─────────────────────────────────────────

   procedure On_Analyze_All_Toggled
     (Self : access Gtk.Toggle_Button.Gtk_Toggle_Button_Record'Class)
   is
      Active : constant Boolean := Self.Get_Active;
   begin
      if WS_Dir_Scroll /= null then
         WS_Dir_Scroll.Set_Sensitive (not Active);
      end if;
      if WS_Dir_HBox /= null then
         WS_Dir_HBox.Set_Sensitive (not Active);
      end if;
   end On_Analyze_All_Toggled;


   --  ── Show_Dialog ─────────────────────────────────────────────────────────

   procedure Show_Dialog is
      use Coyote_SQC.Data_Model;

      D          : Gtk_Dialog;
      VBox       : Gtk.Box.Gtk_Box;
      Name_E     : Gtk.GEntry.Gtk_Entry;
      Dir_LB     : Gtk.List_Box.Gtk_List_Box;
      Filter_Buf : Gtk.Text_Buffer.Gtk_Text_Buffer := null;
      Res        : Gtk_Response_Type;

      New_Name : Unbounded_String :=
        Coyote_SQC.App.State.Workspace.Name;
      New_Dirs : String_Vectors.Vector :=
        Coyote_SQC.App.State.Workspace.Source_Directories;

   begin
      if Coyote_SQC.App.State = null then return; end if;

      Gtk.Dialog.Gtk_New
        (D, "Workspace Settings", Coyote_SQC.App.State.Main_Window,
         Gtk.Dialog.Modal);
      D.Set_Default_Size (500, 480);
      WS_Dialog := D;

      Gtk.Box.Gtk_New_Vbox (VBox);
      VBox.Set_Spacing (6);
      VBox.Set_Border_Width (8);

      --  ── Name field ──────────────────────────────────────────────────────
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

      --  ── Source directories ──────────────────────────────────────────────
      declare
         Lbl    : Gtk.Label.Gtk_Label;
         HBox   : Gtk.Box.Gtk_Box;
         Add_B  : Gtk.Button.Gtk_Button;
         Rm_B   : Gtk.Button.Gtk_Button;
         Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
         Analyze_CB : Gtk.Check_Button.Gtk_Check_Button;
      begin
         Gtk.Label.Gtk_New (Lbl, "Source Directories:");
         Lbl.Set_Halign (Gtk.Widget.Align_Start);
         VBox.Pack_Start (Lbl, False, False, 0);

         Gtk.Check_Button.Gtk_New
           (Analyze_CB,
            "Analyze all source directories");
         Analyze_CB.Set_Tooltip_Text
           ("Load sessions from every project directory, "
            & "ignoring the list below.");
         Analyze_CB.Set_Active
           (Coyote_SQC.App.State.Workspace.Analyze_All_Directories);
         Analyze_CB.On_Toggled (On_Analyze_All_Toggled'Access);
         VBox.Pack_Start (Analyze_CB, False, False, 4);

         --  Quantile CC interpolation toggle (§5.18.1).
         declare
            Interp_CB : Gtk.Check_Button.Gtk_Check_Button;
         begin
            Gtk.Check_Button.Gtk_New
              (Interp_CB,
               "Use interpolated quantile control limits (faster)");
            Interp_CB.Set_Tooltip_Text
              ("When enabled, bootstrap control limits are computed at"
               & " a small set of anchor subgroup sizes and interpolated"
               & " for other sizes using 1/sqrt(N) scaling.  Approximately"
               & " 10× faster; negligible accuracy loss for N >= 10.");
            Interp_CB.Set_Active
              (Coyote_SQC.App.State.Workspace
                 .Interpolate_Quantile_Limits);
            VBox.Pack_Start (Interp_CB, False, False, 0);
            WS_Interp_CB := Interp_CB;
         end;
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
         WS_Analyze_All_CB := Analyze_CB;
         WS_Dir_Scroll     := Scroll;
         WS_Dir_HBox       := HBox;
         --  Apply initial sensitivity based on current checkbox state.
         if Coyote_SQC.App.State.Workspace.Analyze_All_Directories then
            Scroll.Set_Sensitive (False);
            HBox.Set_Sensitive   (False);
         end if;
      end;

      --  ── Model filter ────────────────────────────────────────────────────
      declare
         Filter_Lbl    : Gtk.Label.Gtk_Label;
         Filter_TV     : Gtk.Text_View.Gtk_Text_View;
         Filter_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
         Filter_Text   : Unbounded_String;
      begin
         Gtk.Label.Gtk_New (Filter_Lbl,
           "Model Filter (one per line; empty = all):");
         Filter_Lbl.Set_Halign (Gtk.Widget.Align_Start);
         VBox.Pack_Start (Filter_Lbl, False, False, 0);

         Gtk.Text_Buffer.Gtk_New (Filter_Buf);
         for F of Coyote_SQC.App.State.Workspace.Model_Filter loop
            Append (Filter_Text, F);
            Append (Filter_Text,
              To_Unbounded_String ("" & ASCII.LF));
         end loop;
         declare
            Iter : Gtk.Text_Iter.Gtk_Text_Iter;
         begin
            Filter_Buf.Get_End_Iter (Iter);
            Filter_Buf.Insert (Iter, To_String (Filter_Text));
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

      --  Add OK / Cancel buttons and the VBox to the dialog.
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
         --  Apply name.
         New_Name := To_Unbounded_String (Name_E.Get_Text);
         if New_Name /= Coyote_SQC.App.State.Workspace.Name then
            Coyote_SQC.App.State.Workspace.Name := New_Name;
            Coyote_SQC.App.State.Modified := True;
         end if;

         --  Apply source directories.
         if WS_New_Dirs /= Coyote_SQC.App.State.Workspace.Source_Directories
         then
            Coyote_SQC.App.State.Workspace.Source_Directories := WS_New_Dirs;
            Coyote_SQC.App.State.Modified := True;
         end if;

         --  Apply Analyze_All_Directories.
         if WS_Analyze_All_CB /= null then
            declare
               New_Val : constant Boolean :=
                 WS_Analyze_All_CB.Get_Active;
            begin
               if New_Val /=
                  Coyote_SQC.App.State.Workspace.Analyze_All_Directories
               then
                  Coyote_SQC.App.State.Workspace.Analyze_All_Directories :=
                    New_Val;
                  Coyote_SQC.App.State.Modified := True;
               end if;
            end;
         --  Apply Interpolate_Quantile_Limits.
         if WS_Interp_CB /= null then
            declare
               New_Val : constant Boolean :=
                 WS_Interp_CB.Get_Active;
            begin
               if New_Val /=
                  Coyote_SQC.App.State.Workspace
                    .Interpolate_Quantile_Limits
               then
                  Coyote_SQC.App.State.Workspace
                    .Interpolate_Quantile_Limits := New_Val;
                  Coyote_SQC.App.State.Modified := True;
               end if;
            end;
         end if;

         end if;

         --  Apply model filter (read back from text buffer).
         if Filter_Buf /= null then
            declare
               use Ada.Strings.Fixed;
               use Ada.Strings;
               SI   : Gtk.Text_Iter.Gtk_Text_Iter;
               EI   : Gtk.Text_Iter.Gtk_Text_Iter;
               Text : Unbounded_String;
            begin
               Filter_Buf.Get_Start_Iter (SI);
               Filter_Buf.Get_End_Iter (EI);
               Text := To_Unbounded_String
                 (Filter_Buf.Get_Text (SI, EI));

               declare
                  New_Filter : String_Vectors.Vector;
                  S     : constant String := To_String (Text);
                  Start : Positive := S'First;
                  procedure Add_Token (T : String) is
                     TT : constant String := Trim (T, Both);
                  begin
                     if TT'Length > 0 then
                        New_Filter.Append (To_Unbounded_String (TT));
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
                  if New_Filter /= Coyote_SQC.App.State.Workspace.Model_Filter
                  then
                     Coyote_SQC.App.State.Workspace.Model_Filter :=
                       New_Filter;
                     Coyote_SQC.App.State.Modified := True;
                  end if;
               end;
            end;
         end if;


         Coyote_SQC.App.Reload_Sessions;
         Coyote_SQC.App.Update_Title;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      end if;

      WS_Dialog   := null;
      WS_Dir_LB   := null;
      WS_New_Dirs.Clear;
      WS_Analyze_All_CB := null;
      WS_Dir_Scroll     := null;
      WS_Interp_CB := null;
      WS_Dir_HBox       := null;
      D.Destroy;
   end Show_Dialog;

end Coyote_SQC.UI.Workspace_Settings;
