--  Coyote_SQC.UI.Detail_Panel body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.App;
with Coyote_SQC.Metrics;
with Coyote_SQC.Data_Model;
with Coyote_SQC.UI.Chart_Canvas;
with Coyote_SQC.UI.Dialogs;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Coyote_SQC.Workspace;
with Glib;                   use Glib;
with Glib.Object;
with Glib.Properties;        use Glib.Properties;
with Gtk.Box;
with Gtk.Drawing_Area;
with Gtk.Button;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Label;
with Gtk.List_Box;
with Gtk.List_Box_Row;
with Gtk.Scrolled_Window;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Unchecked_Deallocation;
with Ada.Strings.Unbounded.Hash;
with Glib;
with Gtk.Adjustment;
with Gtk.Paned;
with Coyote_Renderer.Session_View;
with Gtk.Window;
with Coyote_SQC.UI.Tool_Detail_Window;
with Coyote_SQC.Charts;
with Coyote_SQC.Statistics.I_Chart;
with Coyote_SQC.Statistics.Xbar;
with Coyote_SQC.UI.Histogram_Canvas;
with Coyote_SQC.Statistics.Tests;
with Coyote_SQC.Statistics.Bootstrap;
with Gtk.Grid;

package body Coyote_SQC.UI.Detail_Panel is
   use type Gtk.Paned.Gtk_Paned;
   use type Gtk.Adjustment.Gtk_Adjustment;
   use type Gtk.Window.Gtk_Window;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Label.Gtk_Label;
   use type Coyote_SQC.App.App_State_Access;

   use Coyote_SQC.Data_Model;

   --  The outer container box returned by Build.
   Panel_Box   : Gtk.Box.Gtk_Box   := null;

   --  Current view widgets (replaced on each Refresh).
   Inner_Box   : Gtk.Box.Gtk_Box   := null;

   --  Session replay view (kept across refreshes for the same session).

   --  Comment entry for the current single-session view.
   Comment_Entry    : Gtk.Text_View.Gtk_Text_View := null;
   Comment_Sess_Id  : Unbounded_String;

   --  Multi-select comment entry.
   Multi_Comment_Entry : Gtk.Text_View.Gtk_Text_View := null;
   --  Summary-statistics and test-result labels for the multi-select view.
   --  Replaced on every Build_Multi_View call; null when not displayed.
   Stats_Mean_Lbl      : Gtk.Label.Gtk_Label := null;
   Stats_Median_Lbl    : Gtk.Label.Gtk_Label := null;
   Stats_StdDev_Lbl    : Gtk.Label.Gtk_Label := null;
   Stats_KS_Normal_Lbl : Gtk.Label.Gtk_Label := null;
   Stats_KS_Exp_Lbl    : Gtk.Label.Gtk_Label := null;
   Stats_Runs_Lbl      : Gtk.Label.Gtk_Label := null;
   Stats_Dip_Lbl       : Gtk.Label.Gtk_Label := null;
   Stats_Mean_Key_Lbl   : Gtk.Label.Gtk_Label := null;
   Stats_Median_Key_Lbl : Gtk.Label.Gtk_Label := null;
   Stats_StdDev_Key_Lbl : Gtk.Label.Gtk_Label := null;

   --  Reference to the current session replay scrolled window (to save
   --  scroll position before rebuilding the detail panel).
   Current_Replay_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window := null;
   Current_Replay_Sid    : Ada.Strings.Unbounded.Unbounded_String :=
     Ada.Strings.Unbounded.Null_Unbounded_String;

   --  When a row in "Selected Sessions" is clicked, we show the single
   --  view for that session while preserving the multi-selection.
   Pinned_Session_Id : Ada.Strings.Unbounded.Unbounded_String :=
     Ada.Strings.Unbounded.Null_Unbounded_String;

   --  Per-session scroll position cache (session UUID → vertical adjustment value).
   package Scroll_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Ada.Strings.Unbounded.Unbounded_String,
      Element_Type    => Glib.Gdouble,
      Hash            => Ada.Strings.Unbounded.Hash,
      Equivalent_Keys => Ada.Strings.Unbounded."=");
   Scroll_Cache : Scroll_Maps.Map;

   --  Session IDs in the current "Selected Sessions" list rows (max 256).
   Max_Selected_Rows : constant := 256;
   Selected_Row_Ids : array (0 .. Max_Selected_Rows - 1) of Unbounded_String;
   Selected_Row_Count : Natural := 0;

   --  ── Helpers ───────────────────────────────────────────────────────────

   function Format_Cal (T : Ada.Calendar.Time) return String is
      use Ada.Calendar.Formatting;
      use Ada.Strings.Fixed;
   begin
      return Image (T, Time_Zone => 0);
   end Format_Cal;

   function Trim_Path (P : String) return String is
      use Ada.Strings.Fixed;
   begin
      declare
         Home : constant String := GNAT.OS_Lib.Getenv ("HOME").all;
      begin
         if P'Length > Home'Length
           and then P (P'First .. P'First + Home'Length - 1) = Home
         then
            return "~" & P (P'First + Home'Length .. P'Last);
         end if;
         return P;
      end;
   end Trim_Path;

   --  ── "Back" callback (from pinned single-session view) ─────────────────

   procedure On_Back_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      Pinned_Session_Id := Null_Unbounded_String;
      Refresh;
   end On_Back_Clicked;

   --  ── Selected Sessions row activation ──────────────────────────────────

   procedure On_Selected_Row_Activated
     (LB  : access Gtk.List_Box.Gtk_List_Box_Record'Class;
      Row : not null access Gtk.List_Box_Row.Gtk_List_Box_Row_Record'Class)
   is
      pragma Unreferenced (LB);
      Idx : constant Glib.Gint := Row.Get_Index;
   begin
      if Integer (Idx) < Selected_Row_Count then
         Pinned_Session_Id := Selected_Row_Ids (Integer (Idx));
         Refresh;
      end if;
   end On_Selected_Row_Activated;

   --  ── Add_Comment callback ──────────────────────────────────────────────

   procedure On_Add_Comment_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
      use Ada.Calendar;
      use Coyote_SQC.Workspace;
   begin
      if Coyote_SQC.App.State = null
        or else Comment_Entry = null
        or else To_String (Comment_Sess_Id) = ""
      then
         return;
      end if;

      declare
         Buf    : constant Gtk.Text_Buffer.Gtk_Text_Buffer :=
           Comment_Entry.Get_Buffer;
         SI, EI : Gtk.Text_Iter.Gtk_Text_Iter;
         Text   : Unbounded_String;
      begin
         Buf.Get_Start_Iter (SI);
         Buf.Get_End_Iter (EI);
         Text := To_Unbounded_String (Buf.Get_Text (SI, EI));
         if To_String (Text) = "" then return; end if;

         declare
            New_Comment : Comment_Record :=
              (Comment_Id => To_Unbounded_String
                               (Coyote_SQC.Workspace.New_UUID),
               Session_Id => Comment_Sess_Id,
               Timestamp  => Ada.Calendar.Clock,
               Text       => Text);
         begin
            Coyote_SQC.App.State.Workspace.Comments.Append (New_Comment);
            Coyote_SQC.App.State.Workspace.Commented_Session_Ids.Include (Comment_Sess_Id);
            Coyote_SQC.App.State.Modified := True;
            Coyote_SQC.App.Update_Title;
            Coyote_SQC.App.Refresh_Comment_State;
         end;
         Buf.Set_Text ("");
         Refresh;
      end;
   end On_Add_Comment_Clicked;

   procedure On_Add_Multi_Comment_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
      use Ada.Calendar;
   begin
      if Coyote_SQC.App.State = null
        or else Multi_Comment_Entry = null
      then
         return;
      end if;

      declare
         Buf    : constant Gtk.Text_Buffer.Gtk_Text_Buffer :=
           Multi_Comment_Entry.Get_Buffer;
         SI, EI : Gtk.Text_Iter.Gtk_Text_Iter;
         Text   : Unbounded_String;
      begin
         Buf.Get_Start_Iter (SI);
         Buf.Get_End_Iter (EI);
         Text := To_Unbounded_String (Buf.Get_Text (SI, EI));
         if To_String (Text) = "" then return; end if;

         declare
            Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         begin
            for Sid of Coyote_SQC.App.State.Selection loop
               Coyote_SQC.App.State.Workspace.Comments.Append
                 ((Comment_Id => To_Unbounded_String
                                   (Coyote_SQC.Workspace.New_UUID),
                   Session_Id => Sid,
                   Timestamp  => Now,
                   Text       => Text));
               Coyote_SQC.App.State.Workspace.Commented_Session_Ids.Include (Sid);
            end loop;
         end;
         Coyote_SQC.App.State.Modified := True;
         Coyote_SQC.App.Update_Title;
         Coyote_SQC.App.Refresh_Comment_State;
         Buf.Set_Text ("");
         Refresh;
      end;
   end On_Add_Multi_Comment_Clicked;

   procedure On_Set_Setup_Interval_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      if Coyote_SQC.App.State = null then return; end if;
      --  Confirm if setup interval already set.
      if not Coyote_SQC.App.State.Workspace.Setup_Session_Ids.Is_Empty then
         if not Coyote_SQC.UI.Dialogs.Confirm
           (Coyote_SQC.App.State.Main_Window,
            "Replace Setup Interval",
            "Replace existing setup interval for this workspace?")
         then
            return;
         end if;
      end if;
      Coyote_SQC.App.State.Workspace.Setup_Session_Ids :=
        Coyote_SQC.App.State.Selection;
      Coyote_SQC.App.State.Modified := True;
      Coyote_SQC.App.Update_Title;
      Coyote_SQC.App.Recompute_Charts;
      Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      Refresh;
   end On_Set_Setup_Interval_Clicked;

   --  Forward declarations.

   --  ── Tool call click callback ──────────────────────────────────────────
   --
   --  Registered with Render_Session so that clicking a tool call button
   --  in the session replay opens a Tool_Detail_Window.

   procedure On_Session_Tool_Click
     (Tool_Name    : in String;
      Arguments    : in String;
      Result_Text  : in String;
      Is_Image     : in Boolean;
      Status  : Coyote_Renderer.Session_View.Tool_End_Status;
      Turn_Index   : in Positive;
      Call_In_Turn : in Positive;
      Session : Coyote_SQC.Data_Model.Session_Record)
   is
   begin
      if Coyote_SQC.App.State = null
        or else Coyote_SQC.App.State.Main_Window = null
      then
         return;
      end if;
      Coyote_SQC.UI.Tool_Detail_Window.Show
        (Tool_Name    => Tool_Name,
         Arguments    => Arguments,
         Result_Text  => Result_Text,
         Is_Image     => Is_Image,
         Status       => Status,
         Turn_Index   => Turn_Index,
         Call_In_Turn => Call_In_Turn,
         Session      => Session,
         Main_Window  => Coyote_SQC.App.State.Main_Window);
   end On_Session_Tool_Click;

   procedure Build_Single_View (Sid : String);
   procedure Build_Pinned_View (Sid : String);
   procedure Build_Two_Set_View;

   --  ── Build single-session view ─────────────────────────────────────────

   procedure Build_Single_View (Sid : String) is
      use Gtk.Box;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Text_View;
      use Gtk.Text_Buffer;
      use Gtk.Scrolled_Window;
      use Gtk.Button;
      use Gtk.Enums;

      VBox    : Gtk.Box.Gtk_Box;
      Frame   : Gtk.Frame.Gtk_Frame;
      Lbl     : Gtk.Label.Gtk_Label;
      Btn     : Gtk.Button.Gtk_Button;
      Scroll  : Gtk.Scrolled_Window.Gtk_Scrolled_Window;

      Sess    : Session_Record;
      Found   : Boolean := False;

      procedure Find_Session is
      begin
         for S of Coyote_SQC.App.State.Sessions loop
            if To_String (S.Session_Id) = Sid then
               Sess := S;
               Found := True;
               return;
            end if;
         end loop;
      end Find_Session;

   begin
      Find_Session;
      if not Found then return; end if;

      Comment_Sess_Id := To_Unbounded_String (Sid);

      Gtk.Box.Gtk_New_Vbox (VBox);
      VBox.Set_Spacing (6);
      VBox.Set_Border_Width (6);

      --  Header: datetime, model, source dir, token counts.
      Gtk.Frame.Gtk_New (Frame, "Session");
      declare
         Grid_Lbl : Gtk.Label.Gtk_Label;
      begin
         Gtk.Label.Gtk_New
           (Grid_Lbl,
            Format_Cal (Sess.Start_Time) & "  "
            & To_String (Sess.Model) & ASCII.LF
            & Trim_Path (To_String (Sess.Source_Directory)) & ASCII.LF
            & "Input: "
            & Ada.Strings.Fixed.Trim
                (Natural'Image (Sess.Total_Input_Tokens), Ada.Strings.Left)
            & "  Output: "
            & Ada.Strings.Fixed.Trim
                (Natural'Image (Sess.Total_Output_Tokens), Ada.Strings.Left)
            & ASCII.LF
            & To_String (Sess.Session_Id));
         Grid_Lbl.Set_Xalign (0.0);
         Grid_Lbl.Set_Line_Wrap (True);
         Grid_Lbl.Set_Selectable (True);
         Frame.Add (Grid_Lbl);
      end;
      VBox.Pack_Start (Frame, False, False, 0);

      --  Subgroup Distribution histogram and Summary Statistics.
      --  Always built; Refresh_Histogram_If_Single populates them.
      declare
         Hist_Frame : Gtk.Frame.Gtk_Frame;
         Hist_DA    : constant Gtk.Drawing_Area.Gtk_Drawing_Area :=
           Coyote_SQC.UI.Histogram_Canvas.Build;
      begin
         Gtk.Frame.Gtk_New (Hist_Frame, "Distribution");
         Hist_Frame.Add (Hist_DA);
         VBox.Pack_Start (Hist_Frame, False, False, 0);
      --  Summary statistics frame.
      declare
         use Gtk.Grid;
         Stats_Frame  : Gtk.Frame.Gtk_Frame;
         Grid         : Gtk.Grid.Gtk_Grid;
         Key_Lbl      : Gtk.Label.Gtk_Label;
      begin
         --  Reset stale references from any previous view build.
         Stats_Mean_Lbl      := null;
         Stats_Median_Lbl    := null;
         Stats_StdDev_Lbl    := null;
         Stats_KS_Normal_Lbl := null;
         Stats_KS_Exp_Lbl    := null;
         Stats_Runs_Lbl      := null;
         Stats_Dip_Lbl       := null;
         Stats_Mean_Key_Lbl   := null;
         Stats_Median_Key_Lbl := null;
         Stats_StdDev_Key_Lbl := null;

         Gtk.Frame.Gtk_New (Stats_Frame, "Summary Statistics");
         Gtk.Grid.Gtk_New (Grid);
         Grid.Set_Column_Spacing (12);
         Grid.Set_Row_Spacing (3);
         Grid.Set_Border_Width (4);

         --  Row 0: Mean
         Gtk.Label.Gtk_New (Key_Lbl, "Mean:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 0);
         Stats_Mean_Key_Lbl := Key_Lbl;
         Gtk.Label.Gtk_New (Stats_Mean_Lbl, "-");
         Stats_Mean_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_Mean_Lbl, 1, 0);

         --  Row 1: Median
         Gtk.Label.Gtk_New (Key_Lbl, "Median:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 1);
         Stats_Median_Key_Lbl := Key_Lbl;
         Gtk.Label.Gtk_New (Stats_Median_Lbl, "-");
         Stats_Median_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_Median_Lbl, 1, 1);

         --  Row 2: Std Dev
         Gtk.Label.Gtk_New (Key_Lbl, "Std Dev:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 2);
         Stats_StdDev_Key_Lbl := Key_Lbl;
         Gtk.Label.Gtk_New (Stats_StdDev_Lbl, "-");
         Stats_StdDev_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_StdDev_Lbl, 1, 2);

         --  Row 3: KS normality p-value
         Gtk.Label.Gtk_New (Key_Lbl, "KS Normal p:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 3);
         Gtk.Label.Gtk_New (Stats_KS_Normal_Lbl, "-");
         Stats_KS_Normal_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_KS_Normal_Lbl, 1, 3);

         --  Row 4: KS exponential p-value
         Gtk.Label.Gtk_New (Key_Lbl, "KS Exp p:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 4);
         Gtk.Label.Gtk_New (Stats_KS_Exp_Lbl, "-");
         Stats_KS_Exp_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_KS_Exp_Lbl, 1, 4);

         --  Row 5: Runs test p-value
         Gtk.Label.Gtk_New (Key_Lbl, "Runs Test p:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 5);
         Gtk.Label.Gtk_New (Stats_Runs_Lbl, "-");
         Stats_Runs_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_Runs_Lbl, 1, 5);
         --  Row 6: Dip test p-value
         Gtk.Label.Gtk_New (Key_Lbl, "Dip Test p:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 6);
         Gtk.Label.Gtk_New (Stats_Dip_Lbl, "-");
         Stats_Dip_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_Dip_Lbl, 1, 6);

         Stats_Frame.Add (Grid);
         VBox.Pack_Start (Stats_Frame, False, False, 0);
      end;
      end;

      --  Prompt.
      Gtk.Frame.Gtk_New (Frame, "Prompt");
      declare
         TV  : Gtk.Text_View.Gtk_Text_View;
         Buf : Gtk.Text_Buffer.Gtk_Text_Buffer;
         Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      begin
         Gtk.Text_Buffer.Gtk_New (Buf);
         Gtk.Text_View.Gtk_New (TV, Buf);
         TV.Set_Editable (False);
         TV.Set_Wrap_Mode (Wrap_Word);
         Buf.Get_End_Iter (Iter);
         Buf.Insert (Iter, To_String (Sess.First_User_Message));
         Gtk.Scrolled_Window.Gtk_New (Scroll);
         Scroll.Set_Policy (Policy_Never, Policy_Automatic);
         Scroll.Set_Size_Request (-1, 80);
         Scroll.Add (TV);
         Frame.Add (Scroll);
      end;
      VBox.Pack_Start (Frame, False, False, 0);

      --  Session replay.
      Gtk.Frame.Gtk_New (Frame, "Session Replay");
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Policy_Automatic, Policy_Automatic);
      Scroll.Set_Size_Request (-1, 200);
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Policy_Automatic, Policy_Automatic);
      Scroll.Set_Size_Request (-1, 200);
      --  Always create a fresh replay view (widgets are destroyed on rebuild).
      declare
         R_Buf  : Gtk.Text_Buffer.Gtk_Text_Buffer;
         R_View : Gtk.Text_View.Gtk_Text_View;
      begin
         Gtk.Text_Buffer.Gtk_New (R_Buf);
         Gtk.Text_View.Gtk_New (R_View, R_Buf);
         R_View.Set_Editable (False);
         R_View.Set_Wrap_Mode (Wrap_Word);
         Coyote_Renderer.Session_View.Render_Session
           (Session       => Sess,
            Buffer        => R_Buf,
            View          => R_View,
            On_Tool_Click => On_Session_Tool_Click'Access);
         Scroll.Add (R_View);
      end;
      --  Track the scroll window for position preservation.
      Current_Replay_Scroll := Scroll;
      Current_Replay_Sid    := Sess.Session_Id;
      Frame.Add (Scroll);
      VBox.Pack_Start (Frame, True, True, 0);

      --  Comments.
      Gtk.Frame.Gtk_New (Frame, "Comments");
      declare
         CBox     : Gtk.Box.Gtk_Box;
         CLbl     : Gtk.Label.Gtk_Label;
         CE_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
         CE       : Gtk.Text_View.Gtk_Text_View;
      begin
         Gtk.Box.Gtk_New_Vbox (CBox);
         --  List existing comments.
         for C of Coyote_SQC.App.State.Workspace.Comments loop
            if To_String (C.Session_Id) = Sid then
               Gtk.Label.Gtk_New
                 (CLbl, Format_Cal (C.Timestamp) & ASCII.LF
                  & To_String (C.Text));
               CLbl.Set_Xalign (0.0);
               CLbl.Set_Line_Wrap (True);
               CBox.Pack_Start (CLbl, False, False, 2);
            end if;
         end loop;
         --  New comment entry.
         Gtk.Text_View.Gtk_New (CE);
         CE.Set_Wrap_Mode (Wrap_Word);
         Comment_Entry := CE;
         Gtk.Scrolled_Window.Gtk_New (CE_Scroll);
         CE_Scroll.Set_Policy (Policy_Never, Policy_Automatic);
         CE_Scroll.Set_Size_Request (-1, 60);
         CE_Scroll.Add (CE);
         CBox.Pack_Start (CE_Scroll, False, False, 2);
         --  Add Comment button.
         Gtk.Button.Gtk_New_With_Mnemonic (Btn, "_Add Comment");
         Btn.On_Clicked (On_Add_Comment_Clicked'Access);
         CBox.Pack_Start (Btn, False, False, 2);
         Frame.Add (CBox);
      end;
      VBox.Pack_Start (Frame, False, False, 0);

      Refresh_Histogram_If_Single;
      Inner_Box := VBox;
      Panel_Box.Pack_Start (VBox, True, True, 0);
      Panel_Box.Show_All;
      --  Restore saved scroll position (if any).
      declare
         use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
         Sid_Key : constant Ada.Strings.Unbounded.Unbounded_String :=
           Sess.Session_Id;
         Cursor  : constant Scroll_Maps.Cursor :=
           Scroll_Cache.Find (Sid_Key);
      begin
         if Scroll_Maps.Has_Element (Cursor) and then
            Current_Replay_Scroll /= null
         then
            declare
               Adj : constant Gtk.Adjustment.Gtk_Adjustment :=
                 Current_Replay_Scroll.Get_Vadjustment;
            begin
               if Adj /= null then
                  Adj.Set_Value (Scroll_Maps.Element (Cursor));
               end if;
            end;
         end if;
      end;
   end Build_Single_View;
   --  ── Build pinned single-session view (from multi-select) ──────────────

   procedure Build_Pinned_View (Sid : String) is
      use Gtk.Box;
      use Gtk.Button;

      Outer : Gtk.Box.Gtk_Box;
      Back  : Gtk.Button.Gtk_Button;
   begin
      Gtk.Box.Gtk_New_Vbox (Outer);

      --  "Back" button at the top.
      Gtk.Button.Gtk_New_With_Mnemonic (Back, "< _Back to Selection");
      Back.On_Clicked (On_Back_Clicked'Access);
      Outer.Pack_Start (Back, False, False, 2);

      --  Build the regular single-session content into a nested VBox.
      --  We call Build_Single_View; it sets Inner_Box.  We then reparent
      --  Inner_Box into Outer.
      Build_Single_View (Sid);
      if Inner_Box /= null then
         Glib.Object.Ref (Glib.Object.GObject (Inner_Box));
         Panel_Box.Remove (Inner_Box);
         Outer.Pack_Start (Inner_Box, True, True, 0);
         Glib.Object.Unref (Glib.Object.GObject (Inner_Box));
      end if;

      Inner_Box := Outer;
      Panel_Box.Pack_Start (Outer, True, True, 0);
      Panel_Box.Show_All;
   end Build_Pinned_View;


   --  ── Build multi-select view ───────────────────────────────────────────

   procedure Build_Multi_View is
      use Gtk.Box;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Button;
      use Gtk.Enums;
      use Gtk.Text_View;
      use Gtk.Scrolled_Window;

      VBox : Gtk.Box.Gtk_Box;
      Lbl  : Gtk.Label.Gtk_Label;
      Frame : Gtk.Frame.Gtk_Frame;
      Btn   : Gtk.Button.Gtk_Button;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      MC_Entry : Gtk.Text_View.Gtk_Text_View;

      N : constant Natural := Natural (Coyote_SQC.App.State.Selection.Length);
   begin
      Gtk.Box.Gtk_New_Vbox (VBox);
      VBox.Set_Spacing (6);
      VBox.Set_Border_Width (6);

      Gtk.Label.Gtk_New
        (Lbl,
         Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left)
         & " sessions selected");
      VBox.Pack_Start (Lbl, False, False, 0);
      --  Date range label.
      --  Date range label: min/max of selected sessions' start times.
      declare
         use Ada.Calendar;
         Date_Lbl : Gtk.Label.Gtk_Label;
         T_Min    : Ada.Calendar.Time :=
           Ada.Calendar.Time_Of (2100, 1, 1, 0.0);
         T_Max    : Ada.Calendar.Time :=
           Ada.Calendar.Time_Of (1970, 1, 2, 0.0);
         Found    : Boolean := False;
      begin
         for Sess of Coyote_SQC.App.State.Sessions loop
            if Coyote_SQC.App.State.Selection.Contains (Sess.Session_Id) then
               if Sess.Start_Time < T_Min then T_Min := Sess.Start_Time; end if;
               if Sess.Start_Time > T_Max then T_Max := Sess.Start_Time; end if;
               Found := True;
            end if;
         end loop;
         if Found then
            declare
               D1 : constant String :=
                 Ada.Calendar.Formatting.Image (T_Min, Time_Zone => 0);
               D2 : constant String :=
                 Ada.Calendar.Formatting.Image (T_Max, Time_Zone => 0);
            begin
               Gtk.Label.Gtk_New
                 (Date_Lbl,
                  D1 (D1'First .. D1'First + 9) & " - "
                  & D2 (D2'First .. D2'First + 9));
               VBox.Pack_Start (Date_Lbl, False, False, 0);
            end;
         end if;
      end;
      --  Distribution histogram.
      declare
         Hist_Frame : Gtk.Frame.Gtk_Frame;
         Hist_DA    : constant Gtk.Drawing_Area.Gtk_Drawing_Area :=
           Coyote_SQC.UI.Histogram_Canvas.Build;
      begin
         Gtk.Frame.Gtk_New (Hist_Frame, "Distribution");
         Hist_Frame.Add (Hist_DA);
         VBox.Pack_Start (Hist_Frame, False, False, 0);
      --  Summary statistics frame (mean, median, std dev, test p-values).
      declare
         use Gtk.Grid;
         Stats_Frame  : Gtk.Frame.Gtk_Frame;
         Grid         : Gtk.Grid.Gtk_Grid;
         Key_Lbl      : Gtk.Label.Gtk_Label;
      begin
         --  Reset stale references from any previous multi-view build.
         Stats_Mean_Lbl      := null;
         Stats_Median_Lbl    := null;
         Stats_StdDev_Lbl    := null;
         Stats_KS_Normal_Lbl := null;
         Stats_KS_Exp_Lbl    := null;
         Stats_Runs_Lbl      := null;
         Stats_Dip_Lbl       := null;
         Stats_Mean_Key_Lbl   := null;
         Stats_Median_Key_Lbl := null;
         Stats_StdDev_Key_Lbl := null;

         Gtk.Frame.Gtk_New (Stats_Frame, "Summary Statistics");
         Gtk.Grid.Gtk_New (Grid);
         Grid.Set_Column_Spacing (12);
         Grid.Set_Row_Spacing (3);
         Grid.Set_Border_Width (4);

         --  Row 0: Mean
         Gtk.Label.Gtk_New (Key_Lbl, "Mean:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 0);
         Stats_Mean_Key_Lbl := Key_Lbl;
         Gtk.Label.Gtk_New (Stats_Mean_Lbl, "-");
         Stats_Mean_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_Mean_Lbl, 1, 0);

         --  Row 1: Median
         Gtk.Label.Gtk_New (Key_Lbl, "Median:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 1);
         Stats_Median_Key_Lbl := Key_Lbl;
         Gtk.Label.Gtk_New (Stats_Median_Lbl, "-");
         Stats_Median_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_Median_Lbl, 1, 1);

         --  Row 2: Std Dev
         Gtk.Label.Gtk_New (Key_Lbl, "Std Dev:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 2);
         Stats_StdDev_Key_Lbl := Key_Lbl;
         Gtk.Label.Gtk_New (Stats_StdDev_Lbl, "-");
         Stats_StdDev_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_StdDev_Lbl, 1, 2);

         --  Row 3: KS normality p-value
         Gtk.Label.Gtk_New (Key_Lbl, "KS Normal p:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 3);
         Gtk.Label.Gtk_New (Stats_KS_Normal_Lbl, "-");
         Stats_KS_Normal_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_KS_Normal_Lbl, 1, 3);

         --  Row 4: KS exponential p-value
         Gtk.Label.Gtk_New (Key_Lbl, "KS Exp p:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 4);
         Gtk.Label.Gtk_New (Stats_KS_Exp_Lbl, "-");
         Stats_KS_Exp_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_KS_Exp_Lbl, 1, 4);

         --  Row 5: Runs test p-value
         Gtk.Label.Gtk_New (Key_Lbl, "Runs Test p:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 5);
         Gtk.Label.Gtk_New (Stats_Runs_Lbl, "-");
         Stats_Runs_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_Runs_Lbl, 1, 5);
         --  Row 6: Dip test p-value
         Gtk.Label.Gtk_New (Key_Lbl, "Dip Test p:");
         Key_Lbl.Set_Xalign (0.0);
         Grid.Attach (Key_Lbl, 0, 6);
         Gtk.Label.Gtk_New (Stats_Dip_Lbl, "-");
         Stats_Dip_Lbl.Set_Xalign (1.0);
         Grid.Attach (Stats_Dip_Lbl, 1, 6);

         Stats_Frame.Add (Grid);
         VBox.Pack_Start (Stats_Frame, False, False, 0);
      end;
      end;
      --  Set as Setup Interval button.
      Gtk.Button.Gtk_New_With_Mnemonic (Btn, "_Set as Setup Interval");
      Btn.On_Clicked (On_Set_Setup_Interval_Clicked'Access);
      VBox.Pack_Start (Btn, False, False, 4);

      --  Bulk comment.
      Gtk.Frame.Gtk_New (Frame, "Add Comment to All Selected");
      declare
         CBox : Gtk.Box.Gtk_Box;
         CBt  : Gtk.Button.Gtk_Button;
         CE_S : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      begin
         Gtk.Box.Gtk_New_Vbox (CBox);
         Gtk.Text_View.Gtk_New (MC_Entry);
         MC_Entry.Set_Wrap_Mode (Wrap_Word);
         Multi_Comment_Entry := MC_Entry;
         Gtk.Scrolled_Window.Gtk_New (CE_S);
         CE_S.Set_Policy (Policy_Never, Policy_Automatic);
         CE_S.Set_Size_Request (-1, 60);
         CE_S.Add (MC_Entry);
         CBox.Pack_Start (CE_S, False, False, 2);
         Gtk.Button.Gtk_New_With_Mnemonic (CBt, "_Add Comment to All");
         CBt.On_Clicked (On_Add_Multi_Comment_Clicked'Access);
         CBox.Pack_Start (CBt, False, False, 2);
         Frame.Add (CBox);
      end;
      VBox.Pack_Start (Frame, False, False, 0);
      --  ── Selected Sessions listbox ──────────────────────────────────────
      declare
         use Gtk.List_Box;
         use Gtk.List_Box_Row;
         use Coyote_SQC.Data_Model;
         Sel_Frame  : Gtk.Frame.Gtk_Frame;
         Sel_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
         Sel_LB     : Gtk.List_Box.Gtk_List_Box;
         Row_N      : Natural := 0;
      begin
         Selected_Row_Count := 0;
         Gtk.Frame.Gtk_New (Sel_Frame, "Selected Sessions");
         Gtk.Scrolled_Window.Gtk_New (Sel_Scroll);
         Sel_Scroll.Set_Policy (Gtk.Enums.Policy_Never,
                                Gtk.Enums.Policy_Automatic);
         Sel_Scroll.Set_Size_Request (-1, 150);
         Gtk.List_Box.Gtk_New (Sel_LB);
         Sel_LB.Set_Selection_Mode (Gtk.Enums.Selection_None);
         Sel_LB.On_Row_Activated (On_Selected_Row_Activated'Access);

         for I in 1 .. Positive (Coyote_SQC.App.State.Sessions.Length) loop
            declare
               Sess : constant Session_Record :=
                 Coyote_SQC.App.State.Sessions.Element (I);
            begin
               if Coyote_SQC.App.State.Selection.Contains (Sess.Session_Id)
                 and then Row_N < Max_Selected_Rows
               then
                  declare
                     Row_W  : Gtk.List_Box_Row.Gtk_List_Box_Row;
                     RLabel : Gtk.Label.Gtk_Label;
                     TS     : constant String :=
                       Ada.Calendar.Formatting.Image
                         (Sess.Start_Time, Time_Zone => 0);
                     Text : constant String :=
                       TS (TS'First .. TS'First + 9) & "  "
                       & To_String (Sess.Model);
                  begin
                     Gtk.List_Box_Row.Gtk_New (Row_W);
                     Gtk.Label.Gtk_New (RLabel, Text);
                     RLabel.Set_Halign (Gtk.Widget.Align_Start);
                     Row_W.Add (RLabel);
                     Sel_LB.Add (Row_W);
                     Selected_Row_Ids (Row_N) := Sess.Session_Id;
                     Row_N := Row_N + 1;
                  end;
               end if;
            end;
         end loop;

         Selected_Row_Count := Row_N;
         Sel_Scroll.Add (Sel_LB);
         Sel_Frame.Add (Sel_Scroll);
         VBox.Pack_Start (Sel_Frame, True, True, 0);
      end;
      Refresh_Histogram_If_Multi;

      Inner_Box := VBox;
      Panel_Box.Pack_Start (VBox, True, True, 0);
      Panel_Box.Show_All;
   end Build_Multi_View;

   procedure Build_Two_Set_View is
      use Gtk.Box;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Button;
      use Gtk.Grid;
      use Gtk.Enums;
      use Gtk.Text_View;
      use Gtk.Scrolled_Window;
      use Ada.Strings.Fixed;
      use Ada.Strings;
      use Ada.Calendar;
      use Coyote_SQC.App;
      use Coyote_SQC.Statistics.Tests;

      Active : constant Coyote_SQC.Charts.Chart_Kind :=
        State.Active_Chart;
      CD     : constant Coyote_SQC.App.Chart_Data :=
        State.Charts (Active);
      Props  : constant Coyote_SQC.Charts.Chart_Properties :=
        Coyote_SQC.Charts.Properties (Active);

      package LF_Vectors renames Long_Float_Vectors;
      Vals_A_Vec : LF_Vectors.Vector;
      Vals_B_Vec : LF_Vectors.Vector;
      N_A     : Natural := 0;
      N_B     : Natural := 0;
      CL      : Long_Float := 0.0;
      UCL     : Long_Float := 0.0;
      Has_UCL : Boolean    := False;
      LCL     : Long_Float := 0.0;
      Has_LCL : Boolean    := False;
      Got_CL  : Boolean    := False;

      --  Date ranges.
      T_Min_A : Ada.Calendar.Time := Ada.Calendar.Time_Of (2100, 1, 1, 0.0);
      T_Max_A : Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 2, 0.0);
      T_Min_B : Ada.Calendar.Time := Ada.Calendar.Time_Of (2100, 1, 1, 0.0);
      T_Max_B : Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 2, 0.0);

      VBox : Gtk.Box.Gtk_Box;
      Frame : Gtk.Frame.Gtk_Frame;
      MC_Entry : Gtk.Text_View.Gtk_Text_View;

      --  Formatting helpers (same rules as in Refresh_Histogram_If_Multi).
      function Fmt_V (V : Long_Float) return String is
         Av : constant Long_Float := abs V;
      begin
         if Av >= 100.0 then
            return (if V < 0.0 then "-" else "")
              & Trim (Long_Long_Integer'Image
                  (Long_Long_Integer (Long_Float'Rounding (Av))),
                  Ada.Strings.Left);
         else
            declare
               IV : constant Long_Long_Integer :=
                 Long_Long_Integer (Long_Float'Rounding (Av * 100.0));
            begin
               return (if V < 0.0 then "-" else "")
                 & Trim (Long_Long_Integer'Image (IV / 100),
                         Ada.Strings.Left)
                 & "."
                 & (if IV mod 100 < 10 then "0" else "")
                 & Trim (Long_Long_Integer'Image (IV mod 100),
                         Ada.Strings.Left);
            end;
         end if;
      end Fmt_V;

      function Fmt_P (P : Long_Float) return String is
         IV : Natural;
      begin
         if P < 0.0 then
            return "N/A";
         elsif P < 0.001 then
            return "< 0.001";
         else
            IV := Natural (Long_Float'Rounding (P * 1000.0));
            if IV >= 1000 then
               return "1.000";
            end if;
            return "0."
              & (if IV < 100 then "0" else "")
              & (if IV < 10 then "0" else "")
              & Trim (Natural'Image (IV), Ada.Strings.Left);
         end if;
      end Fmt_P;

      function Fmt_N (N : Natural) return String is
      begin
         return Trim (Natural'Image (N), Ada.Strings.Left);
      end Fmt_N;

      function Fmt_Date_Range
        (T_Min : Ada.Calendar.Time;
         T_Max : Ada.Calendar.Time;
         Found : Boolean) return String is
      begin
         if not Found then
            return "-";
         end if;
         declare
            D1 : constant String :=
              Ada.Calendar.Formatting.Image (T_Min, Time_Zone => 0);
            D2 : constant String :=
              Ada.Calendar.Formatting.Image (T_Max, Time_Zone => 0);
         begin
            return D1 (D1'First .. D1'First + 9) & " - "
              & D2 (D2'First .. D2'First + 9);
         end;
      end Fmt_Date_Range;

      function Fmt_CI
        (CI : Coyote_SQC.Statistics.Bootstrap.CI_Result) return String is
      begin
         if not CI.Valid then
            return "N/A";
         end if;
         return Fmt_V (CI.Point_Estimate)
           & " [" & Fmt_V (CI.Lower)
           & ", " & Fmt_V (CI.Upper) & "]";
      end Fmt_CI;

      Found_A : Boolean := False;
      Found_B : Boolean := False;

   begin
      --  Reset stale references from any previous view build.
      Stats_Mean_Lbl      := null;
      Stats_Median_Lbl    := null;
      Stats_StdDev_Lbl    := null;
      Stats_KS_Normal_Lbl := null;
      Stats_KS_Exp_Lbl    := null;
      Stats_Runs_Lbl      := null;
      Stats_Dip_Lbl       := null;
      Stats_Mean_Key_Lbl   := null;
      Stats_Median_Key_Lbl := null;
      Stats_StdDev_Key_Lbl := null;
      --  ── Collect Set A and Set B values from the active chart ──────────
      for P of CD.Points loop
         if not P.Excluded then
            if State.Selection.Contains (P.Session_Id) then
               N_A := N_A + 1;
               Vals_A_Vec.Append (P.Stat_Value);
               if P.Session_Time < T_Min_A then
                  T_Min_A := P.Session_Time;
               end if;
               if P.Session_Time > T_Max_A then
                  T_Max_A := P.Session_Time;
               end if;
               Found_A := True;
               if not Got_CL then
                  CL      := P.CL;
                  UCL     := P.UCL;
                  Has_UCL := P.Has_UCL;
                  LCL     := P.LCL;
                  Has_LCL := P.Has_LCL;
                  Got_CL  := True;
               end if;
            end if;
            if State.Set_B.Contains (P.Session_Id) then
               N_B := N_B + 1;
               Vals_B_Vec.Append (P.Stat_Value);
               if P.Session_Time < T_Min_B then
                  T_Min_B := P.Session_Time;
               end if;
               if P.Session_Time > T_Max_B then
                  T_Max_B := P.Session_Time;
               end if;
               Found_B := True;
            end if;
         end if;
      end loop;

      --  ── Apply display transform (same rules as Refresh_Histogram_If_Multi)
      if (Props.Is_MR_Chart
          and then CD.MR_Transform_Active /= Coyote_SQC.Data_Model.None)
        or else (not Props.Is_MR_Chart
                 and then CD.Transform_Active /= Coyote_SQC.Data_Model.None)
      then
         declare
            use Coyote_SQC.Data_Model;
            Eff_Active : constant Coyote_SQC.Data_Model.Transform_Kind :=
              (if Props.Is_MR_Chart
               then CD.MR_Transform_Active
               else CD.Transform_Active);
            Eff_Lambda : constant Long_Float :=
              (if Props.Is_MR_Chart
               then CD.MR_Transform_Lambda
               else CD.Transform_Lambda);
         begin
            for I in 1 .. N_A loop
               if Vals_A_Vec (I) > 0.0
                 or else (Eff_Active /= Box_Cox
                          and then Vals_A_Vec (I) >= 0.0)
                 or else Eff_Active = Arcsinh_VS
               then
                  Vals_A_Vec.Replace_Element
                    (I, Coyote_SQC.Statistics.I_Chart.Apply_Transform
                          (Vals_A_Vec (I), Eff_Active, Eff_Lambda));
               end if;
            end loop;
            for I in 1 .. N_B loop
               if Vals_B_Vec (I) > 0.0
                 or else (Eff_Active /= Box_Cox
                          and then Vals_B_Vec (I) >= 0.0)
                 or else Eff_Active = Arcsinh_VS
               then
                  Vals_B_Vec.Replace_Element
                    (I, Coyote_SQC.Statistics.I_Chart.Apply_Transform
                          (Vals_B_Vec (I), Eff_Active, Eff_Lambda));
               end if;
            end loop;
         end;
      end if;

      --  ── Compute bootstrap CIs ────────────────────────────────────────
      declare
         BS_Result : Coyote_SQC.Statistics.Bootstrap.Three_CI_Results;
         X_Label   : constant String :=
           Ada.Strings.Unbounded.To_String (Props.Y_Axis_Label);
      begin
         BS_Result := Coyote_SQC.Statistics.Bootstrap.Compute
           (Set_A => Vals_A_Vec, Set_B => Vals_B_Vec);

         --  ── Refresh two-set histogram ─────────────────────────────────
         Coyote_SQC.UI.Histogram_Canvas.Refresh_Two_Set
           (Values_A  => Vals_A_Vec,
            Values_B  => Vals_B_Vec,
            CL        => CL,
            UCL       => UCL,
            Has_UCL   => Has_UCL,
            LCL       => LCL,
            Has_LCL   => Has_LCL,
            X_Label   => X_Label,
            Has_Data  => N_A > 0 or else N_B > 0);

         --  ── Build widget tree ─────────────────────────────────────────
         Gtk.Box.Gtk_New_Vbox (VBox);
         VBox.Set_Spacing (6);
         VBox.Set_Border_Width (6);

         --  Set headers grid (2 rows × 3 cols).
         declare
            Header_Grid : Gtk.Grid.Gtk_Grid;
            Lbl         : Gtk.Label.Gtk_Label;
         begin
            Gtk.Grid.Gtk_New (Header_Grid);
            Header_Grid.Set_Column_Spacing (8);
            Header_Grid.Set_Row_Spacing (2);

            --  Row 0: Set A (blue).
            Gtk.Label.Gtk_New (Lbl, "Set A");
            Lbl.Set_Xalign (0.0);
            Lbl.Set_Markup
              ("<span foreground=""#1a4ec2""><b>Set A</b></span>");
            Header_Grid.Attach (Lbl, 0, 0);

            Gtk.Label.Gtk_New (Lbl, Fmt_N (N_A) & " sessions");
            Lbl.Set_Xalign (0.0);
            Header_Grid.Attach (Lbl, 1, 0);

            Gtk.Label.Gtk_New
              (Lbl, Fmt_Date_Range (T_Min_A, T_Max_A, Found_A));
            Lbl.Set_Xalign (0.0);
            Header_Grid.Attach (Lbl, 2, 0);

            --  Row 1: Set B (orange).
            Gtk.Label.Gtk_New (Lbl, "Set B");
            Lbl.Set_Xalign (0.0);
            Lbl.Set_Markup
              ("<span foreground=""#c76000""><b>Set B</b></span>");
            Header_Grid.Attach (Lbl, 0, 1);

            Gtk.Label.Gtk_New (Lbl, Fmt_N (N_B) & " sessions");
            Lbl.Set_Xalign (0.0);
            Header_Grid.Attach (Lbl, 1, 1);

            Gtk.Label.Gtk_New
              (Lbl, Fmt_Date_Range (T_Min_B, T_Max_B, Found_B));
            Lbl.Set_Xalign (0.0);
            Header_Grid.Attach (Lbl, 2, 1);

            VBox.Pack_Start (Header_Grid, False, False, 0);
         end;

         --  Distribution histogram (two-set overlay).
         declare
            Hist_Frame : Gtk.Frame.Gtk_Frame;
            Hist_DA    : constant Gtk.Drawing_Area.Gtk_Drawing_Area :=
              Coyote_SQC.UI.Histogram_Canvas.Build;
         begin
            Gtk.Frame.Gtk_New (Hist_Frame, "Distribution");
            Hist_Frame.Add (Hist_DA);
            VBox.Pack_Start (Hist_Frame, False, False, 0);
         end;

         --  Summary Statistics (9 rows × 3 columns).
         declare
            Stats_Frame : Gtk.Frame.Gtk_Frame;
            Grid        : Gtk.Grid.Gtk_Grid;
            Key_Lbl     : Gtk.Label.Gtk_Label;
            Val_A_Lbl   : Gtk.Label.Gtk_Label;
            Val_B_Lbl   : Gtk.Label.Gtk_Label;

            type LF_Arr_Ptr is access Long_Float_Array;
            procedure Free_LF_Arr is new Ada.Unchecked_Deallocation
              (Long_Float_Array, LF_Arr_Ptr);
            Test_A_Ptr : LF_Arr_Ptr :=
              new Long_Float_Array (1 .. N_A);
            Test_B_Ptr : LF_Arr_Ptr :=
              new Long_Float_Array (1 .. N_B);
            Test_A     : Long_Float_Array renames Test_A_Ptr.all;
            Test_B     : Long_Float_Array renames Test_B_Ptr.all;

            procedure Add_Row
              (Row    :     Glib.Gint;
               Key    :     String;
               Val_A  :     String;
               Val_B  :     String)
            is
            begin
               Gtk.Label.Gtk_New (Key_Lbl, Key);
               Key_Lbl.Set_Xalign (0.0);
               Grid.Attach (Key_Lbl, 0, Row);
               Gtk.Label.Gtk_New (Val_A_Lbl, Val_A);
               Val_A_Lbl.Set_Xalign (1.0);
               Grid.Attach (Val_A_Lbl, 1, Row);
               Gtk.Label.Gtk_New (Val_B_Lbl, Val_B);
               Val_B_Lbl.Set_Xalign (1.0);
               Grid.Attach (Val_B_Lbl, 2, Row);
            end Add_Row;

         begin
            --  Populate heap-allocated arrays from Set A / Set B vectors.
            for I in 1 .. N_A loop
               Test_A (I) := Vals_A_Vec (I);
            end loop;
            for I in 1 .. N_B loop
               Test_B (I) := Vals_B_Vec (I);
            end loop;
            Gtk.Frame.Gtk_New (Stats_Frame, "Summary Statistics");
            Gtk.Grid.Gtk_New (Grid);
            Grid.Set_Column_Spacing (12);
            Grid.Set_Row_Spacing (3);
            Grid.Set_Border_Width (4);

            --  Column headers.
            Gtk.Label.Gtk_New (Key_Lbl, "");
            Grid.Attach (Key_Lbl, 0, 0);
            Gtk.Label.Gtk_New (Key_Lbl, "Set A");
            Key_Lbl.Set_Xalign (1.0);
            Key_Lbl.Set_Markup ("<b>Set A</b>");
            Grid.Attach (Key_Lbl, 1, 0);
            Gtk.Label.Gtk_New (Key_Lbl, "Set B");
            Key_Lbl.Set_Xalign (1.0);
            Key_Lbl.Set_Markup ("<b>Set B</b>");
            Grid.Attach (Key_Lbl, 2, 0);

            Add_Row (1, "N:",
                     Fmt_N (N_A),
                     Fmt_N (N_B));
            Add_Row (2, "Mean:",
                     (if N_A > 0 then Fmt_V (Mean_Of (Test_A)) else "-"),
                     (if N_B > 0 then Fmt_V (Mean_Of (Test_B)) else "-"));
            Add_Row (3, "Median:",
                     (if N_A > 0
                      then Fmt_V (Coyote_SQC.Statistics.I_Chart.Median_Of
                                    (Test_A))
                      else "-"),
                     (if N_B > 0
                      then Fmt_V (Coyote_SQC.Statistics.I_Chart.Median_Of
                                    (Test_B))
                      else "-"));
            Add_Row (4, "Std Dev:",
                     (if N_A > 0 then Fmt_V (Std_Dev_Of (Test_A)) else "-"),
                     (if N_B > 0 then Fmt_V (Std_Dev_Of (Test_B)) else "-"));
            Add_Row (5, "KS Normal p:",
                     Fmt_P (if N_A > 0
                            then KS_Normality_P_Value (Test_A) else -1.0),
                     Fmt_P (if N_B > 0
                            then KS_Normality_P_Value (Test_B) else -1.0));
            Add_Row (6, "KS Exp p:",
                     Fmt_P (if N_A > 0
                            then KS_Exponential_P_Value (Test_A) else -1.0),
                     Fmt_P (if N_B > 0
                            then KS_Exponential_P_Value (Test_B) else -1.0));
            Add_Row (7, "Runs Test p:",
                     Fmt_P (if N_A > 0
                            then Runs_Test_P_Value (Test_A) else -1.0),
                     Fmt_P (if N_B > 0
                            then Runs_Test_P_Value (Test_B) else -1.0));
            Add_Row (8, "Dip Test p:",
                     Fmt_P (if N_A > 0
                            then Dip_Test_P_Value (Test_A) else -1.0),
                     Fmt_P (if N_B > 0
                            then Dip_Test_P_Value (Test_B) else -1.0));

            Free_LF_Arr (Test_A_Ptr);
            Free_LF_Arr (Test_B_Ptr);
            Stats_Frame.Add (Grid);
            VBox.Pack_Start (Stats_Frame, False, False, 0);
         end;

         --  Comparison (Bootstrap 95% CI) frame.
         declare
            CI_Frame : Gtk.Frame.Gtk_Frame;
            CI_Grid  : Gtk.Grid.Gtk_Grid;
            Key_Lbl  : Gtk.Label.Gtk_Label;
            Val_Lbl  : Gtk.Label.Gtk_Label;
         begin
            Gtk.Frame.Gtk_New (CI_Frame, "Comparison (Bootstrap 95% CI)");
            Gtk.Grid.Gtk_New (CI_Grid);
            CI_Grid.Set_Column_Spacing (12);
            CI_Grid.Set_Row_Spacing (3);
            CI_Grid.Set_Border_Width (4);

            Gtk.Label.Gtk_New (Key_Lbl, "Mean diff (B" & "-" & "A):");
            Key_Lbl.Set_Xalign (0.0);
            CI_Grid.Attach (Key_Lbl, 0, 0);
            Gtk.Label.Gtk_New (Val_Lbl, Fmt_CI (BS_Result.Mean_Diff));
            Val_Lbl.Set_Xalign (1.0);
            CI_Grid.Attach (Val_Lbl, 1, 0);

            Gtk.Label.Gtk_New (Key_Lbl, "Median diff (B" & "-" & "A):");
            Key_Lbl.Set_Xalign (0.0);
            CI_Grid.Attach (Key_Lbl, 0, 1);
            Gtk.Label.Gtk_New (Val_Lbl, Fmt_CI (BS_Result.Median_Diff));
            Val_Lbl.Set_Xalign (1.0);
            CI_Grid.Attach (Val_Lbl, 1, 1);

            Gtk.Label.Gtk_New (Key_Lbl, "SD ratio (B/A):");
            Key_Lbl.Set_Xalign (0.0);
            CI_Grid.Attach (Key_Lbl, 0, 2);
            Gtk.Label.Gtk_New (Val_Lbl, Fmt_CI (BS_Result.SD_Ratio));
            Val_Lbl.Set_Xalign (1.0);
            CI_Grid.Attach (Val_Lbl, 1, 2);

            CI_Frame.Add (CI_Grid);
            VBox.Pack_Start (CI_Frame, False, False, 0);
         end;

         --  Add Comment to All Selected (applies to Set A = Selection).
         declare
            CBox : Gtk.Box.Gtk_Box;
            CBt  : Gtk.Button.Gtk_Button;
            CE_S : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
         begin
            Gtk.Frame.Gtk_New (Frame, "Add Comment to All Selected");
            Gtk.Box.Gtk_New_Vbox (CBox);
            Gtk.Text_View.Gtk_New (MC_Entry);
            MC_Entry.Set_Wrap_Mode (Wrap_Word);
            Multi_Comment_Entry := MC_Entry;
            Gtk.Scrolled_Window.Gtk_New (CE_S);
            CE_S.Set_Policy (Policy_Never, Policy_Automatic);
            CE_S.Set_Size_Request (-1, 60);
            CE_S.Add (MC_Entry);
            CBox.Pack_Start (CE_S, False, False, 2);
            Gtk.Button.Gtk_New_With_Mnemonic (CBt, "_Add Comment to All");
            CBt.On_Clicked (On_Add_Multi_Comment_Clicked'Access);
            CBox.Pack_Start (CBt, False, False, 2);
            Frame.Add (CBox);
            VBox.Pack_Start (Frame, False, False, 0);
         end;

         Inner_Box := VBox;
         Panel_Box.Pack_Start (VBox, True, True, 0);
         Panel_Box.Show_All;
      end;
   end Build_Two_Set_View;


   --  ── Histogram ─────────────────────────────────────────────────────────

   procedure Refresh_Histogram_If_Multi is
      use Ada.Strings.Unbounded;
      use Coyote_SQC.Charts;
   begin
      if Coyote_SQC.App.State = null
        or else Natural (Coyote_SQC.App.State.Selection.Length) < 2
      then
         return;
      end if;

      declare
         Active    : constant Chart_Kind :=
           Coyote_SQC.App.State.Active_Chart;
         CD        : constant Coyote_SQC.App.Chart_Data :=
           Coyote_SQC.App.State.Charts (Active);
         Max_Pts   : constant Natural :=
           Natural (CD.Points.Length);
         Vals      : Coyote_SQC.UI.Histogram_Canvas.Long_Float_Array
                       (1 .. Max_Pts);
         N_Vals    : Natural := 0;
         CL        : Long_Float := 0.0;
         UCL       : Long_Float := 0.0;
         Has_UCL   : Boolean    := False;
         LCL       : Long_Float := 0.0;
         Has_LCL   : Boolean    := False;
         Got_Lims  : Boolean    := False;
         Props     : constant Coyote_SQC.Charts.Chart_Properties :=
           Coyote_SQC.Charts.Properties (Active);
      begin
         for P of CD.Points loop
            if not P.Excluded
              and then Coyote_SQC.App.State.Selection.Contains (P.Session_Id)
            then
               N_Vals := N_Vals + 1;
               Vals (N_Vals) := P.Stat_Value;
               if not Got_Lims then
                  CL       := P.CL;
                  UCL      := P.UCL;
                  Has_UCL  := P.Has_UCL;
                  LCL      := P.LCL;
                  Has_LCL  := P.Has_LCL;
                  Got_Lims := True;
               end if;
            end if;
         end loop;


         --  Box-Cox: for I/MR charts with active transformation, convert
         --  values and limits to the transformed space for the histogram.
         declare
            --  Lambda symbol UTF-8: U+03BB = 0xCE 0xBB.
            Lambda_Sym : constant String :=
              (1 => Character'Val (16#CE#),
               2 => Character'Val (16#BB#));
            X_Lbl_Str  : Ada.Strings.Unbounded.Unbounded_String :=
              Props.Y_Axis_Label;
         begin
            if CD.Transform_Active /= Coyote_SQC.Data_Model.None
              and then (Props.Is_I_Chart
                        or else (Props.Is_Xbar_S_Chart
                                 and then not Props.Is_S_Chart)
                        or else Props.Is_EWMA_Chart)
            then
               --  I/Xbar/EWMA chart: Stat_Value is original space; transform to z-space.
               for K in 1 .. N_Vals loop
                  if Vals (K) > 0.0
                     or else (CD.Transform_Active /=
                                Coyote_SQC.Data_Model.Box_Cox
                              and then Vals (K) >= 0.0)
                     or else CD.Transform_Active =
                               Coyote_SQC.Data_Model.Arcsinh_VS
                  then
                     Vals (K) := Coyote_SQC.Statistics.I_Chart.Apply_Transform
                       (Vals (K), CD.Transform_Active, CD.Transform_Lambda);
                  end if;
               end loop;
               --  Re-transform back-transformed limits to transformed space.
               if Got_Lims then
                  if CL > 0.0 then
                     CL := Coyote_SQC.Statistics.I_Chart.Apply_Transform
                       (CL, CD.Transform_Active, CD.Transform_Lambda);
                  end if;
                  if Has_UCL and then UCL > 0.0 then
                     UCL := Coyote_SQC.Statistics.I_Chart.Apply_Transform
                       (UCL, CD.Transform_Active, CD.Transform_Lambda);
                  end if;
                  if Has_LCL and then LCL > 0.0 then
                     LCL := Coyote_SQC.Statistics.I_Chart.Apply_Transform
                       (LCL, CD.Transform_Active, CD.Transform_Lambda);
                  end if;
               end if;
            elsif CD.MR_Transform_Active /= Coyote_SQC.Data_Model.None
              and then Props.Is_MR_Chart
            then
               --  MR-chart: Stat_Value is raw original-space |x_i - x_{i-1}|;
               --  transform to the MR transformed space using MR lambda.
               for K in 1 .. N_Vals loop
                  if Vals (K) > 0.0
                     or else (CD.MR_Transform_Active /=
                                Coyote_SQC.Data_Model.Box_Cox
                              and then Vals (K) >= 0.0)
                     or else CD.MR_Transform_Active =
                               Coyote_SQC.Data_Model.Arcsinh_VS
                  then
                     Vals (K) := Coyote_SQC.Statistics.I_Chart.Apply_Transform
                       (Vals (K), CD.MR_Transform_Active,
                        CD.MR_Transform_Lambda);
                  end if;
               end loop;
               --  Re-transform back-transformed limits to transformed space.
               if Got_Lims then
                  if CL > 0.0 then
                     CL := Coyote_SQC.Statistics.I_Chart.Apply_Transform
                       (CL, CD.MR_Transform_Active, CD.MR_Transform_Lambda);
                  end if;
                  if Has_UCL and then UCL > 0.0 then
                     UCL := Coyote_SQC.Statistics.I_Chart.Apply_Transform
                       (UCL, CD.MR_Transform_Active, CD.MR_Transform_Lambda);
                  end if;
                  if Has_LCL and then LCL > 0.0 then
                     LCL := Coyote_SQC.Statistics.I_Chart.Apply_Transform
                       (LCL, CD.MR_Transform_Active, CD.MR_Transform_Lambda);
                  end if;
               end if;
            end if;
            --  Append transform annotation to x-axis label.
            if (Props.Is_MR_Chart
                and then CD.MR_Transform_Active /= Coyote_SQC.Data_Model.None)
              or else (not Props.Is_MR_Chart
                       and then CD.Transform_Active /=
                                  Coyote_SQC.Data_Model.None)
            then
               declare
                  use Coyote_SQC.Data_Model;
                  Eff_Active : constant Coyote_SQC.Data_Model.Transform_Kind :=
                    (if Props.Is_MR_Chart
                     then CD.MR_Transform_Active
                     else CD.Transform_Active);
                  Eff_Lambda : constant Long_Float :=
                    (if Props.Is_MR_Chart
                     then CD.MR_Transform_Lambda
                     else CD.Transform_Lambda);
                  function Format_Lambda (V : Long_Float) return String is
                     use Ada.Strings.Fixed;
                     IV : constant Long_Long_Integer :=
                       Long_Long_Integer
                         (Long_Float'Rounding (abs V * 100.0));
                  begin
                     return (if V < 0.0 then "-" else "")
                       & Trim (Long_Long_Integer'Image (IV / 100),
                               Ada.Strings.Left)
                       & "."
                       & (if IV mod 100 < 10 then "0" else "")
                       & Trim (Long_Long_Integer'Image (IV mod 100),
                               Ada.Strings.Left);
                  end Format_Lambda;
                  Suffix : constant String :=
                    (case Eff_Active is
                       when Box_Cox =>
                         Lambda_Sym & "=" & Format_Lambda (Eff_Lambda),
                       when Sqrt_VS       => (1 => Character'Val (16#E2#),
                                              2 => Character'Val (16#88#),
                                              3 => Character'Val (16#9A#)),
                       when Anscombe      => "Anscombe",
                       when Arcsinh_VS    => "arcsinh",
                       when Freeman_Tukey => "F-T",
                       when None          => "");
               begin
                  Ada.Strings.Unbounded.Append
                    (X_Lbl_Str, " (" & Suffix & ")");
               end;
            end if;

            Coyote_SQC.UI.Histogram_Canvas.Refresh
              (Values   => Vals (1 .. N_Vals),
               CL       => CL,
               UCL      => UCL,
               Has_UCL  => Has_UCL,
               LCL      => LCL,
               Has_LCL  => Has_LCL,
               X_Label  => Ada.Strings.Unbounded.To_String (X_Lbl_Str),
               Has_Data => N_Vals > 0);
         end;
         --  ── Update summary-statistics labels ──────────────────────────
         declare
            use Coyote_SQC.Statistics.Tests;
            use Ada.Strings.Fixed;
            Test_Vals : constant Long_Float_Array :=
              Long_Float_Array (Vals (1 .. N_Vals));

            function Fmt_V (V : Long_Float) return String is
               Av : constant Long_Float := abs V;
            begin
               if Av >= 100.0 then
                  return (if V < 0.0 then "-" else "")
                    & Trim (Long_Long_Integer'Image
                        (Long_Long_Integer (Long_Float'Rounding (Av))),
                        Ada.Strings.Left);
               else
                  declare
                     IV : constant Long_Long_Integer :=
                       Long_Long_Integer (Long_Float'Rounding (Av * 100.0));
                  begin
                     return (if V < 0.0 then "-" else "")
                       & Trim (Long_Long_Integer'Image (IV / 100),
                               Ada.Strings.Left)
                       & "."
                       & (if IV mod 100 < 10 then "0" else "")
                       & Trim (Long_Long_Integer'Image (IV mod 100),
                               Ada.Strings.Left);
                  end;
               end if;
            end Fmt_V;

            function Fmt_P (P : Long_Float) return String is
               IV : Natural;
            begin
               if P < 0.0 then
                  return "N/A";
               elsif P < 0.001 then
                  return "< 0.001";
               else
                  IV := Natural (Long_Float'Rounding (P * 1000.0));
                  if IV >= 1000 then
                     return "1.000";
                  end if;
                  return "0."
                    & (if IV < 100 then "0" else "")
                    & (if IV < 10 then "0" else "")
                    & Trim (Natural'Image (IV), Ada.Strings.Left);
               end if;
            end Fmt_P;

         begin
            --  Update summary-statistics key labels to indicate
            --  z-space when a transform is active.
            if Stats_Mean_Key_Lbl /= null then
               Stats_Mean_Key_Lbl.Set_Text
                 (if CD.Transform_Active /= None
                  then "Mean (z):" else "Mean:");
            end if;
            if Stats_Median_Key_Lbl /= null then
               Stats_Median_Key_Lbl.Set_Text
                 (if CD.Transform_Active /= None
                  then "Median (z):" else "Median:");
            end if;
            if Stats_StdDev_Key_Lbl /= null then
               Stats_StdDev_Key_Lbl.Set_Text
                 (if CD.Transform_Active /= None
                  then "Std Dev (z):" else "Std Dev:");
            end if;
            if Stats_Mean_Lbl /= null then
               Stats_Mean_Lbl.Set_Text
                 (if N_Vals > 0 then Fmt_V (Mean_Of (Test_Vals)) else "-");
            end if;
            if Stats_Median_Lbl /= null then
               Stats_Median_Lbl.Set_Text
                 (if N_Vals > 0
                  then Fmt_V (Coyote_SQC.Statistics.I_Chart.Median_Of
                                (Test_Vals))
                  else "-");
            end if;
            if Stats_StdDev_Lbl /= null then
               Stats_StdDev_Lbl.Set_Text
                 (if N_Vals > 0 then Fmt_V (Std_Dev_Of (Test_Vals)) else "-");
            end if;
            if Stats_KS_Normal_Lbl /= null then
               Stats_KS_Normal_Lbl.Set_Text
                 (Fmt_P (if N_Vals > 0
                         then KS_Normality_P_Value (Test_Vals)
                         else -1.0));
            end if;
            if Stats_KS_Exp_Lbl /= null then
               Stats_KS_Exp_Lbl.Set_Text
                 (Fmt_P (if N_Vals > 0
                         then KS_Exponential_P_Value (Test_Vals)
                         else -1.0));
            end if;
            if Stats_Runs_Lbl /= null then
               Stats_Runs_Lbl.Set_Text
                 (Fmt_P (if N_Vals > 0
                         then Runs_Test_P_Value (Test_Vals)
                         else -1.0));
            end if;
            if Stats_Dip_Lbl /= null then
               Stats_Dip_Lbl.Set_Text
                 (Fmt_P (if N_Vals > 0
                         then Dip_Test_P_Value (Test_Vals)
                         else -1.0));
            end if;
         end;
      end;
   end Refresh_Histogram_If_Multi;
   --  ── Subgroup histogram for single-session view ─────────────────────────

   procedure Refresh_Histogram_If_Single is
      use Ada.Strings.Unbounded;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics.Tests;
      use type Coyote_SQC.App.Subgroup_Accessor;
      use type Coyote_SQC.App.LF_Subgroup_Accessor;
   begin
      if Coyote_SQC.App.State = null
        or else Natural (Coyote_SQC.App.State.Selection.Length) /= 1
      then
         return;
      end if;

      declare
         Active  : constant Chart_Kind :=
           Coyote_SQC.App.State.Active_Chart;
         Props   : constant Chart_Properties :=
           Coyote_SQC.Charts.Properties (Active);
         Dsc     : constant Coyote_SQC.App.Chart_Descriptor :=
           Coyote_SQC.App.Descriptor (Active);
         CD      : constant Coyote_SQC.App.Chart_Data :=
           Coyote_SQC.App.State.Charts (Active);
         Sid     : constant Ada.Strings.Unbounded.Unbounded_String :=
           Coyote_SQC.Data_Model.UUID_Sets.Element
             (Coyote_SQC.App.State.Selection.First);
         X_Lbl_Str : Ada.Strings.Unbounded.Unbounded_String :=
           Props.Y_Axis_Label;

         --  Formatting helpers shared with Refresh_Histogram_If_Multi.
         function Fmt_V (V : Long_Float) return String is
            use Ada.Strings.Fixed;
            Av : constant Long_Float := abs V;
         begin
            if Av >= 100.0 then
               return (if V < 0.0 then "-" else "")
                 & Trim (Long_Long_Integer'Image
                     (Long_Long_Integer (Long_Float'Rounding (Av))),
                     Ada.Strings.Left);
            else
               declare
                  IV : constant Long_Long_Integer :=
                    Long_Long_Integer (Long_Float'Rounding (Av * 100.0));
               begin
                  return (if V < 0.0 then "-" else "")
                    & Trim (Long_Long_Integer'Image (IV / 100),
                            Ada.Strings.Left)
                    & "."
                    & (if IV mod 100 < 10 then "0" else "")
                    & Trim (Long_Long_Integer'Image (IV mod 100),
                            Ada.Strings.Left);
               end;
            end if;
         end Fmt_V;

         function Fmt_P (P : Long_Float) return String is
            IV : Natural;
         begin
            if P < 0.0 then
               return "N/A";
            elsif P < 0.001 then
               return "< 0.001";
            else
               IV := Natural (Long_Float'Rounding (P * 1000.0));
               if IV >= 1000 then
                  return "1.000";
               end if;
               return "0."
                 & (if IV < 100 then "0" else "")
                 & (if IV < 10 then "0" else "")
                 & Ada.Strings.Fixed.Trim
                     (Natural'Image (IV), Ada.Strings.Left);
            end if;
         end Fmt_P;

         procedure Clear_Stats is
         begin
            if Stats_Mean_Lbl      /= null then
               Stats_Mean_Lbl.Set_Text ("-");
            end if;
            if Stats_Median_Lbl    /= null then
               Stats_Median_Lbl.Set_Text ("-");
            end if;
            if Stats_StdDev_Lbl    /= null then
               Stats_StdDev_Lbl.Set_Text ("-");
            end if;
            if Stats_KS_Normal_Lbl /= null then
               Stats_KS_Normal_Lbl.Set_Text ("-");
            end if;
            if Stats_KS_Exp_Lbl    /= null then
               Stats_KS_Exp_Lbl.Set_Text ("-");
            end if;
            if Stats_Runs_Lbl      /= null then
               Stats_Runs_Lbl.Set_Text ("-");
            end if;
            if Stats_Dip_Lbl       /= null then
               Stats_Dip_Lbl.Set_Text ("-");
            end if;
         end Clear_Stats;

      begin
         if not Props.Is_Xbar_S_Chart
           or else (Dsc.Get_Subgroup = null
                    and then Dsc.LF_Get_Subgroup = null)
         then
            --  Not an Xbar/s chart or no subgroup accessor — no data.
            Coyote_SQC.UI.Histogram_Canvas.Refresh
              (Values   => Coyote_SQC.UI.Histogram_Canvas.Long_Float_Array'
                             (1 .. 0 => 0.0),
               CL       => 0.0,
               UCL      => 0.0,
               Has_UCL  => False,
               LCL      => 0.0,
               Has_LCL  => False,
               X_Label  => To_String (X_Lbl_Str),
               Has_Data => False);
            Clear_Stats;
            return;
         end if;

         --  Locate the session and compute its metrics.
         declare
            use Coyote_SQC.Data_Model;
            Found   : Boolean := False;
            CL      : Long_Float := 0.0;
            UCL     : Long_Float := 0.0;
            Has_UCL : Boolean    := False;
            LCL     : Long_Float := 0.0;
            Has_LCL : Boolean    := False;
            Got_Pt  : Boolean    := False;
         begin
            --  Find CL/UCL/LCL from the chart point for this session.
            for P of CD.Points loop
               if P.Session_Id = Sid and then not P.Excluded then
                  CL      := P.CL;
                  UCL     := P.UCL;
                  Has_UCL := P.Has_UCL;
                  LCL     := P.LCL;
                  Has_LCL := P.Has_LCL;
                  Got_Pt  := True;
                  exit;
               end if;
            end loop;

            --  Find the session record and collect subgroup values.
            for Sess of Coyote_SQC.App.State.Sessions loop
               if Sess.Session_Id = Sid then
                  declare
                     Metrics : constant Session_Metrics_Record :=
                       Coyote_SQC.Metrics.Compute (Sess, Coyote_SQC.App.State.Pricing);
                     Max_N   : constant Natural :=
                       Natural (Metrics.Per_Turn_Output_Tokens.Length)
                       + Natural (Metrics.Per_Turn_Tool_Tokens.Length)
                       + Natural (Metrics.Per_Turn_Thinking_Tokens.Length)
                       + Natural (Metrics.Per_Consecutive_Tool_S.Length)
                       + Natural (Metrics.Per_Consecutive_Tool_MI.Length)
                       + 1;
                     Vals    : Coyote_SQC.UI.Histogram_Canvas.Long_Float_Array
                                 (1 .. Max_N);
                     N_Vals  : Natural := 0;
                  begin
                     --  Extract per-turn values via the chart's subgroup
                     --  accessor.
                     if Dsc.LF_Get_Subgroup /= null then
                        declare
                           V : constant Long_Float_Vectors.Vector :=
                             Dsc.LF_Get_Subgroup (Metrics);
                        begin
                           for X of V loop
                              N_Vals := N_Vals + 1;
                              Vals (N_Vals) := X;
                           end loop;
                        end;
                     elsif Dsc.Get_Subgroup /= null then
                        declare
                           V : constant Natural_Vectors.Vector :=
                             Dsc.Get_Subgroup (Metrics);
                        begin
                           for X of V loop
                              N_Vals := N_Vals + 1;
                              Vals (N_Vals) := Long_Float (X);
                           end loop;
                        end;
                     end if;

                     --  Apply transform to per-turn values when active.
                     if CD.Transform_Active /= None then
                        declare
                           K_Out      : Natural := 0;
                           --  Lambda symbol UTF-8: U+03BB = 0xCE 0xBB.
                           Lambda_Sym : constant String :=
                             (1 => Character'Val (16#CE#),
                              2 => Character'Val (16#BB#));
                           function Format_Lambda
                             (V : Long_Float) return String
                           is
                              use Ada.Strings.Fixed;
                              IV : constant Long_Long_Integer :=
                                Long_Long_Integer
                                  (Long_Float'Rounding (abs V * 100.0));
                           begin
                              return (if V < 0.0 then "-" else "")
                                & Trim (Long_Long_Integer'Image (IV / 100),
                                        Ada.Strings.Left)
                                & "."
                                & (if IV mod 100 < 10 then "0" else "")
                                & Trim
                                    (Long_Long_Integer'Image (IV mod 100),
                                     Ada.Strings.Left);
                           end Format_Lambda;
                           Suffix : constant String :=
                             (case CD.Transform_Active is
                                when Box_Cox =>
                                  Lambda_Sym & "="
                                  & Format_Lambda (CD.Transform_Lambda),
                                when Sqrt_VS =>
                                  (1 => Character'Val (16#E2#),
                                   2 => Character'Val (16#88#),
                                   3 => Character'Val (16#9A#)),
                                when Anscombe      => "Anscombe",
                                when Arcsinh_VS    => "arcsinh",
                                when Freeman_Tukey => "F-T",
                                when None          => "");
                        begin
                           for K in 1 .. N_Vals loop
                              if Vals (K) > 0.0
                                 or else (CD.Transform_Active /= Box_Cox
                                          and then Vals (K) >= 0.0)
                                 or else CD.Transform_Active = Arcsinh_VS
                              then
                                 K_Out := K_Out + 1;
                                 Vals (K_Out) :=
                                   Coyote_SQC.Statistics.I_Chart.Apply_Transform
                                     (Vals (K), CD.Transform_Active,
                                      CD.Transform_Lambda);
                              end if;
                           end loop;
                           N_Vals := K_Out;
                           --  For Xbar charts recompute limits in z-space;
                           --  S chart limits in CD.Points are already in
                           --  z-space (S chart never back-transforms).
                           if Props.Is_Xbar_S_Chart
                              and then not Props.Is_S_Chart
                              and then N_Vals > 0
                           then
                              declare
                                 Z_Lim : constant
                                   Coyote_SQC.Statistics.Limits_Record :=
                                     Coyote_SQC.Statistics.Xbar.Compute_Limits
                                       (Grand_Mean => CD.Params.Grand_Mean,
                                        Pooled_S   => CD.Params.Pooled_S,
                                        N          => N_Vals);
                              begin
                                 CL      := Z_Lim.CL;
                                 UCL     := Z_Lim.UCL;
                                 Has_UCL := Z_Lim.Has_UCL;
                                 LCL     := Z_Lim.LCL;
                                 Has_LCL := Z_Lim.Has_LCL;
                                 Got_Pt  := True;
                              end;
                           end if;
                           Ada.Strings.Unbounded.Append
                             (X_Lbl_Str, " (" & Suffix & ")");
                        end;
                     end if;
                     Coyote_SQC.UI.Histogram_Canvas.Refresh
                       (Values   => Vals (1 .. N_Vals),
                        CL       => CL,
                        UCL      => UCL,
                        Has_UCL  => Has_UCL and Got_Pt,
                        LCL      => LCL,
                        Has_LCL  => Has_LCL and Got_Pt,
                        X_Label  => To_String (X_Lbl_Str),
                        Has_Data => N_Vals > 0);

                     --  Update summary-statistics labels.
                     declare
                        Test_Vals : constant Long_Float_Array :=
                          Long_Float_Array (Vals (1 .. N_Vals));
                     begin
                        --  Update summary-statistics key labels to indicate
                        --  z-space when a transform is active.
                        if Stats_Mean_Key_Lbl /= null then
                           Stats_Mean_Key_Lbl.Set_Text
                             (if CD.Transform_Active /= None
                              then "Mean (z):" else "Mean:");
                        end if;
                        if Stats_Median_Key_Lbl /= null then
                           Stats_Median_Key_Lbl.Set_Text
                             (if CD.Transform_Active /= None
                              then "Median (z):" else "Median:");
                        end if;
                        if Stats_StdDev_Key_Lbl /= null then
                           Stats_StdDev_Key_Lbl.Set_Text
                             (if CD.Transform_Active /= None
                              then "Std Dev (z):" else "Std Dev:");
                        end if;
                        if Stats_Mean_Lbl /= null then
                           Stats_Mean_Lbl.Set_Text
                             (if N_Vals > 0
                              then Fmt_V (Mean_Of (Test_Vals))
                              else "-");
                        end if;
                        if Stats_Median_Lbl /= null then
                           Stats_Median_Lbl.Set_Text
                             (if N_Vals > 0
                              then Fmt_V
                                     (Coyote_SQC.Statistics.I_Chart.Median_Of
                                        (Test_Vals))
                              else "-");
                        end if;
                        if Stats_StdDev_Lbl /= null then
                           Stats_StdDev_Lbl.Set_Text
                             (if N_Vals > 0
                              then Fmt_V (Std_Dev_Of (Test_Vals))
                              else "-");
                        end if;
                        if Stats_KS_Normal_Lbl /= null then
                           Stats_KS_Normal_Lbl.Set_Text
                             (Fmt_P (if N_Vals > 0
                                     then KS_Normality_P_Value (Test_Vals)
                                     else -1.0));
                        end if;
                        if Stats_KS_Exp_Lbl /= null then
                           Stats_KS_Exp_Lbl.Set_Text
                             (Fmt_P (if N_Vals > 0
                                     then KS_Exponential_P_Value (Test_Vals)
                                     else -1.0));
                        end if;
                        if Stats_Runs_Lbl /= null then
                           Stats_Runs_Lbl.Set_Text
                             (Fmt_P (if N_Vals > 0
                                     then Runs_Test_P_Value (Test_Vals)
                                     else -1.0));
                        end if;
                        if Stats_Dip_Lbl /= null then
                           Stats_Dip_Lbl.Set_Text
                             (Fmt_P (if N_Vals > 0
                                     then Dip_Test_P_Value (Test_Vals)
                                     else -1.0));
                        end if;
                     end;
                  end;
                  Found := True;
                  exit;
               end if;
            end loop;

            if not Found then
               --  Session missing from workspace (unusual): clear all.
               Coyote_SQC.UI.Histogram_Canvas.Refresh
                 (Values   => Coyote_SQC.UI.Histogram_Canvas.Long_Float_Array'
                                (1 .. 0 => 0.0),
                  CL       => 0.0,
                  UCL      => 0.0,
                  Has_UCL  => False,
                  LCL      => 0.0,
                  Has_LCL  => False,
                  X_Label  => To_String (X_Lbl_Str),
                  Has_Data => False);
               Clear_Stats;
            end if;
         end;
      end;
   end Refresh_Histogram_If_Single;


   --  ── Public ────────────────────────────────────────────────────────────

   function Build return Gtk.Box.Gtk_Box is
   begin
      Gtk.Box.Gtk_New_Vbox (Panel_Box);
      return Panel_Box;
   end Build;

   procedure Refresh is
      use Ada.Calendar;
   begin
      if Panel_Box = null or else Coyote_SQC.App.State = null then
         return;
      end if;

      --  Remove previous inner content.
      --  Save scroll position of the current replay view (if any).
      if Current_Replay_Scroll /= null then
         declare
            use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
            Adj : constant Gtk.Adjustment.Gtk_Adjustment :=
              Current_Replay_Scroll.Get_Vadjustment;
         begin
            if Adj /= null and then
               To_String (Current_Replay_Sid)'Length > 0
            then
               Scroll_Cache.Include (Current_Replay_Sid, Adj.Get_Value);
            end if;
         end;
         Current_Replay_Scroll := null;
         Current_Replay_Sid    := Null_Unbounded_String;
      end if;
      if Inner_Box /= null then
         Panel_Box.Remove (Inner_Box);
         Inner_Box := null;
         Comment_Entry := null;
         Multi_Comment_Entry := null;
         --  Null stats-label pointers so no dangling reference survives
         --  across a widget-tree teardown (Build_Two_Set_View does not
         --  reset these itself).
         Stats_Mean_Lbl      := null;
         Stats_Median_Lbl    := null;
         Stats_StdDev_Lbl    := null;
         Stats_KS_Normal_Lbl := null;
         Stats_KS_Exp_Lbl    := null;
         Stats_Runs_Lbl      := null;
         Stats_Dip_Lbl       := null;
         Stats_Mean_Key_Lbl   := null;
         Stats_Median_Key_Lbl := null;
         Stats_StdDev_Key_Lbl := null;
      end if;

      --  Rebuild based on selection size and pinned state.
      declare
         N : constant Natural :=
           Natural (Coyote_SQC.App.State.Selection.Length);
         Pinned : constant String := To_String (Pinned_Session_Id);
      begin
         if not Coyote_SQC.App.State.Set_B.Is_Empty then
            Pinned_Session_Id := Null_Unbounded_String;
            Set_Visible (True);
            Build_Two_Set_View;
         elsif N = 0 then
            Pinned_Session_Id := Null_Unbounded_String;
            Set_Visible (False);
         elsif N = 1 then
            Pinned_Session_Id := Null_Unbounded_String;
            Set_Visible (True);
            Build_Single_View
              (To_String
                 (Coyote_SQC.Data_Model.UUID_Sets.Element
                    (Coyote_SQC.App.State.Selection.First)));
         elsif Pinned'Length > 0 then
            --  Multi-select with a pinned session: show single-session
            --  view with a Back button.
            Set_Visible (True);
            Build_Pinned_View (Pinned);
         else
            Set_Visible (True);
            Build_Multi_View;
         end if;
      end;
   end Refresh;

   procedure Set_Visible (Visible : Boolean) is
      use Coyote_SQC.App;
   begin
      if State /= null and then State.Detail_Pane /= null then
         if Visible then
            declare
               Total : constant Gint :=
                 State.Detail_Pane.Get_Allocated_Width;
            begin
               if Total > 400 then
                  State.Detail_Pane.Set_Position (Total - 380);
               end if;
            end;
         else
            --  Collapse: set position to the full allocated width so
            --  the right child (detail) has zero size.
            State.Detail_Pane.Set_Position
              (State.Detail_Pane.Get_Allocated_Width);
         end if;
      end if;
   end Set_Visible;

end Coyote_SQC.UI.Detail_Panel;
