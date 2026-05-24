--  Coyote_SQC.UI.Detail_Panel body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.App;
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
with Ada.Strings.Unbounded.Hash;
with Glib;
with Gtk.Adjustment;
with Gtk.Paned;
with Coyote_Renderer.Session_View;
with Gtk.Window;
with Coyote_SQC.UI.Tool_Detail_Window;
with Coyote_SQC.Charts;
with Coyote_SQC.Statistics.I_Chart;
with Coyote_SQC.UI.Histogram_Canvas;

package body Coyote_SQC.UI.Detail_Panel is
   use type Gtk.Paned.Gtk_Paned;
   use type Gtk.Adjustment.Gtk_Adjustment;
   use type Gtk.Window.Gtk_Window;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Box.Gtk_Box;
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
            Coyote_SQC.App.State.Modified := True;
            Coyote_SQC.App.Update_Title;
            Coyote_SQC.App.Recompute_Charts;
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
            end loop;
         end;
         Coyote_SQC.App.State.Modified := True;
         Coyote_SQC.App.Update_Title;
         Coyote_SQC.App.Recompute_Charts;
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
                (Natural'Image (Sess.Total_Output_Tokens), Ada.Strings.Left));
         Grid_Lbl.Set_Xalign (0.0);
         Grid_Lbl.Set_Line_Wrap (True);
         Frame.Add (Grid_Lbl);
      end;
      VBox.Pack_Start (Frame, False, False, 0);

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
         Gtk.Button.Gtk_New (Btn, "Add Comment");
         Btn.On_Clicked (On_Add_Comment_Clicked'Access);
         CBox.Pack_Start (Btn, False, False, 2);
         Frame.Add (CBox);
      end;
      VBox.Pack_Start (Frame, False, False, 0);

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
      Gtk.Button.Gtk_New (Back, "< Back to Selection");
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
      end;
      --  Set as Setup Interval button.
      Gtk.Button.Gtk_New (Btn, "Set as Setup Interval");
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
         Gtk.Button.Gtk_New (CBt, "Add Comment to All");
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
            if CD.Box_Cox_Active
              and then Active in Session_Input_Tokens_I
                               | Session_Output_Tokens_I
                               | Session_Cache_Read_Tokens_I
                               | Session_Cache_Write_Tokens_I
            then
               --  I-chart: Stat_Value is raw; transform to matched space.
               for K in 1 .. N_Vals loop
                  if Vals (K) > 0.0 then
                     Vals (K) := Coyote_SQC.Statistics.I_Chart.Box_Cox
                       (Vals (K), CD.Box_Cox_Lambda);
                  end if;
               end loop;
               --  Re-transform back-transformed limits to transformed space.
               if Got_Lims then
                  if CL > 0.0 then
                     CL := Coyote_SQC.Statistics.I_Chart.Box_Cox
                       (CL, CD.Box_Cox_Lambda);
                  end if;
                  if Has_UCL and then UCL > 0.0 then
                     UCL := Coyote_SQC.Statistics.I_Chart.Box_Cox
                       (UCL, CD.Box_Cox_Lambda);
                  end if;
                  if Has_LCL and then LCL > 0.0 then
                     LCL := Coyote_SQC.Statistics.I_Chart.Box_Cox
                       (LCL, CD.Box_Cox_Lambda);
                  end if;
               end if;
            end if;
            --  Append lambda annotation to x-axis label when BC active.
            if CD.Box_Cox_Active then
               declare
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
                  Lam_Str : constant String :=
                    Format_Lambda (CD.Box_Cox_Lambda);
               begin
                  Ada.Strings.Unbounded.Append
                    (X_Lbl_Str, " (" & Lambda_Sym & "=" & Lam_Str & ")");
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
      end;
   end Refresh_Histogram_If_Multi;

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
      end if;

      --  Rebuild based on selection size and pinned state.
      declare
         N : constant Natural :=
           Natural (Coyote_SQC.App.State.Selection.Length);
         Pinned : constant String := To_String (Pinned_Session_Id);
      begin
         if N = 0 then
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
