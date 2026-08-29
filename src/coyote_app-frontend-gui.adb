--  Coyote_App.Frontend.GUI body.
--
--  Project: coyote

with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Gdk.Cursor;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Gdk.Window;
use type Gdk.Types.Gdk_Modifier_Type;
use type Gdk.Event.Gdk_Event_Type;
use type Gdk.Event.Gdk_Event;
with Glib;                       use Glib;
with Glib.Main;
with Gtk.Adjustment;
with Glib.Properties;            use Glib.Properties;
with Gtk.Accel_Group;
with Gtk.Box;
with Gtk.Button;
with Gtk.Check_Button;
with Gtk.Clipboard;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Label;
with Gtk.Main;
with Gtk.Menu;
with Gtk.Menu_Item;
with Gtk.Menu_Shell;
with Gtk.Check_Menu_Item;
with Gtk.Settings;
with Gtk.Scrolled_Window;
with Gtk.Selection_Data;
with Gtk.Separator_Menu_Item;
with Gtk.Layout;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;
with Gtk.Window;
with Pango.Enums;
with Pango.Font;
with Pango.Context;
with Pango.Font_Metrics;
with Pango.Language;
with Ada.Directories;
with Ada.Environment_Variables;
with Glib.Values;
with Gtk.Cell_Renderer_Text;
with Gtk.Dialog;
with Gtk.Combo_Box_Text;
with Gtk.Spin_Button;
with Gtk.List_Store;
with LLM.Settings;
with Gtk.Search_Entry;
with Gtk.Tree_Model;
with Gtk.Tree_Model_Filter;
with Gtk.Tree_Model_Sort;
with Gtk.Tree_Selection;
with Gtk.Tree_View;
with Gtk.Tree_View_Column;
with Gtk.Tree_Store;
with Session_Lister;
with Coyote_Spawn;
with Ada.Command_Line;
with GNATCOLL.OS.Process;
with LLM.Agent;
with LLM.Providers;
with Coyote_App.Utils;
with Coyote_Help;
with Coyote_GUI.Session_Stats_Window;
with Coyote_GUI.Tool_Detail_Window;
with Coyote_GUI.Zoom;
with LLM.Model_Registry;
with LLM.Tools.Sandbox;
with Coyote_Notify;
with Coyote_GUI.Notification_Policy;

package body Coyote_App.Frontend.GUI is
   use Coyote_GUI.Prompt_Queue;
   use Coyote_App.Utils;

   --  ── Package-body state ────────────────────────────────────────────────

   --  Global access for signal callbacks (single window per process).
   Current_Frontend : access Instance := null;

   protected body Session_Reference is
      procedure Set (Value : access LLM.Agent.Session) is
      begin
         Session_Reference.Value := Value;
      end Set;

      procedure Request_Abort is
      begin
         if Session_Reference.Value /= null then
            LLM.Agent.Request_Abort (Session_Reference.Value.all);
         end if;
      end Request_Abort;
   end Session_Reference;

   use type Gtk.Dialog.Gtk_Dialog;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Menu_Item.Gtk_Menu_Item;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Coyote_GUI.Conversation.Action_Kind;
   use type Gtk.Tree_Model_Filter.Gtk_Tree_Model_Filter;
   use type Gtk.Tree_View.Gtk_Tree_View;

   procedure On_Change_Model_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_Overview_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_Native_Fork
     (UUID   : String;
      Turn_N : Positive;
      Step_N : Natural);

   function On_Prompt_Button_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean;

   procedure Arm_Click_For_Help (F : in out Instance);
   procedure Reset_Click_For_Help (F : in out Instance);

   procedure Open_Help_Topic (Topic : String);
   procedure Show_Context_Help (Area : String);

   function On_Help_Event
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean;

   procedure On_Click_For_Help_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   function On_Support_Window_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean;

   procedure Apply_Agent_Menu_Sensitivity (F : in out Instance);

   procedure On_Edit_Menu_Show
     (Self : access Gtk.Widget.Gtk_Widget_Record'Class);

   procedure On_Cut_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Copy_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Paste_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Select_All_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Deselect_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   --  Transient widgets for the modal Change Model dialog.  Dialog.Run
   --  is modal, so at most one picker is live at a time.
   type Model_Picker_State is record
      Store  : Gtk.List_Store.Gtk_List_Store := null;
      Filter : Gtk.Tree_Model_Filter.Gtk_Tree_Model_Filter := null;
      Sort   : Gtk.Tree_Model_Sort.Gtk_Tree_Model_Sort := null;
      View   : Gtk.Tree_View.Gtk_Tree_View := null;
      Search : Gtk.Search_Entry.Gtk_Search_Entry := null;
      Count  : Gtk.Label.Gtk_Label := null;
      Dialog : Gtk.Dialog.Gtk_Dialog := null;
      Query  : Unbounded_String := Null_Unbounded_String;
   end record;

   Picker : Model_Picker_State;

   procedure Clear_Model_Picker is
   begin
      Picker := (others => <>);
   end Clear_Model_Picker;

   function Model_Picker_Row_Visible
     (Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter  : Gtk.Tree_Model.Gtk_Tree_Iter) return Boolean
   is
      use Gtk.Tree_Model;
   begin
      if Iter = Null_Iter then
         return False;
      end if;
      return Model_Row_Matches
        (Provider => Get_String (Model, Iter, 0),
         Name     => Get_String (Model, Iter, 1),
         Spec     => Get_String (Model, Iter, 7),
         Query    => To_String (Picker.Query));
   end Model_Picker_Row_Visible;

   procedure Update_Model_Picker_Count is
      use Gtk.Tree_Model;
      use Gtk.Tree_Model_Filter;
      Needle  : constant String :=
        Ada.Strings.Fixed.Trim
          (To_String (Picker.Query), Ada.Strings.Both);
      Visible : Natural := 0;
   begin
      if Picker.Filter = null or else Picker.Count = null then
         return;
      end if;
      Visible := Natural (N_Children (+Picker.Filter));
      Picker.Count.Set_Text
        (Format_Model_Picker_Count
           (Visible  => Visible,
            Filtered => Needle'Length > 0));
   end Update_Model_Picker_Count;

   procedure Ensure_Model_Picker_Selection is
      use Gtk.Tree_Model;
      use Gtk.Tree_Model_Sort;
      Sel    : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Model  : Gtk_Tree_Model;
      Iter   : Gtk_Tree_Iter;
      Path   : Gtk_Tree_Path;
      Needle : constant String :=
        Ada.Strings.Fixed.Trim
          (To_String (Picker.Query), Ada.Strings.Both);
   begin
      if Picker.View = null or else Needle'Length = 0 then
         return;
      end if;
      Sel := Picker.View.Get_Selection;
      Sel.Get_Selected (Model, Iter);
      if Iter /= Null_Iter then
         return;
      end if;
      Iter := Get_Iter_First (+Picker.Sort);
      if Iter = Null_Iter then
         return;
      end if;
      Sel.Select_Iter (Iter);
      Path := Get_Path (+Picker.Sort, Iter);
      Picker.View.Scroll_To_Cell (Path, null, False, 0.0, 0.0);
      Path_Free (Path);
   end Ensure_Model_Picker_Selection;

   procedure Apply_Model_Picker_Filter is
   begin
      if Picker.Filter = null then
         return;
      end if;
      Picker.Filter.Refilter;
      Update_Model_Picker_Count;
      Ensure_Model_Picker_Selection;
   end Apply_Model_Picker_Filter;

   procedure On_Model_Search_Changed
     (Self : access Gtk.Search_Entry.Gtk_Search_Entry_Record'Class) is
   begin
      Picker.Query := To_Unbounded_String (Self.Get_Text);
      Apply_Model_Picker_Filter;
   end On_Model_Search_Changed;

   procedure On_Model_Search_Stop
     (Self : access Gtk.Search_Entry.Gtk_Search_Entry_Record'Class) is
   begin
      if Self.Get_Text_Length > 0 then
         Self.Set_Text ("");
         Picker.Query := Null_Unbounded_String;
         Apply_Model_Picker_Filter;
      elsif Picker.Dialog /= null then
         Picker.Dialog.Response (Gtk.Dialog.Gtk_Response_Cancel);
      end if;
   end On_Model_Search_Stop;

   --  Prefix character used by menu-item handlers to pass commands through

   --  ── Show-detail secondary window ──────────────────────────────────────

   procedure Show_Text_Window
     (Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class;
      Title       : String;
      Content     : String)
   is
      use Gtk.Window;
      use Gtk.Scrolled_Window;
      use Gtk.Text_View;
      use Gtk.Text_Buffer;
      use Gtk.Text_Iter;

      Win    : Gtk_Window;
      Scroll : Gtk_Scrolled_Window;
      View   : Gtk_Text_View;
      Buf    : Gtk_Text_Buffer;
      Iter   : Gtk_Text_Iter;
   begin
      Gtk.Window.Gtk_New (Win, Gtk.Enums.Window_Toplevel);
      Win.Set_Title (Title);
      Win.Set_Transient_For (Main_Window);
      Win.Set_Default_Size (700, 500);
      Win.On_Key_Press_Event (On_Support_Window_Key_Press'Access);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Gtk.Enums.Policy_Automatic,
                         Gtk.Enums.Policy_Automatic);

      Gtk.Text_View.Gtk_New (View);
      View.Set_Editable (False);
      View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);

      declare
         Font_Desc : Pango.Font.Pango_Font_Description :=
           Pango.Font.From_String ("monospace 10");
      begin
         View.Modify_Font (Font_Desc);
         Pango.Font.Free (Font_Desc);
      end;

      Buf := View.Get_Buffer;
      Buf.Get_End_Iter (Iter);
      Buf.Insert (Iter, Content);

      Scroll.Add (View);
      Win.Add (Scroll);
      Win.Show_All;
   end Show_Text_Window;

   function Help_Area
     (Self : access Gtk.Widget.Gtk_Widget_Record'Class) return String
   is
      Name : constant String := Self.Get_Name;
   begin
      if Name = "coyote-help-menu" then
         return "menu";
      elsif Name = "coyote-help-prompt" then
         return "prompt";
      elsif Name = "coyote-help-controls" then
         return "controls";
      elsif Name = "coyote-help-status" then
         return "status";
      elsif Name = "coyote-help-transcript" then
         return "transcript";
      else
         return "conversation";
      end if;
   end Help_Area;

   procedure Open_Help_Topic (Topic : String) is
   begin
      if Current_Frontend /= null
        and then not Coyote_Help.Open (Topic)
      then
         Current_Frontend.Append_Notice
           (Coyote_App.Frontend.Error,
            "Unable to open Help: Yelp is not available.");
      end if;
   end Open_Help_Topic;

   procedure Show_Context_Help (Area : String) is
   begin
      Open_Help_Topic (Coyote_Help.Topic_For_Area (Area));
   end Show_Context_Help;

   function On_Help_Event
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean
   is
   begin
      if Current_Frontend = null
        or else not Current_Frontend.Help_Mode
        or else Event.The_Type /= Gdk.Event.Button_Press
        or else Event.Button /= 1
      then
         return False;
      end if;

      declare
         Area : constant String := Help_Area (Self);
      begin
         Reset_Click_For_Help (Current_Frontend.all);
         Show_Context_Help (Area);
      end;
      return True;
   end On_Help_Event;

   procedure Arm_Click_For_Help (F : in out Instance) is
      Cursor : Gdk.Gdk_Cursor;
   begin
      F.Help_Mode := True;
      Cursor := Gdk.Cursor.Gdk_Cursor_New (Gdk.Cursor.Question_Arrow);
      Gdk.Window.Set_Cursor (F.Win.Get_Window, Cursor);
      Gdk.Cursor.Unref (Cursor);
   end Arm_Click_For_Help;

   procedure Reset_Click_For_Help (F : in out Instance) is
   begin
      F.Help_Mode := False;
      Gdk.Window.Set_Cursor (F.Win.Get_Window, null);
   end Reset_Click_For_Help;

   function On_Support_Window_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      use type Gdk.Types.Gdk_Key_Type;
   begin
      if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_w
        and then (Event.State and Gdk.Types.Control_Mask) /= 0
      then
         Self.Destroy;
         return True;
      end if;
      return False;
   end On_Support_Window_Key_Press;

   procedure Apply_Agent_Menu_Sensitivity (F : in out Instance) is
      Mode : constant Coyote_GUI.Run_Mode :=
        Coyote_GUI.Run_Mode'Val
          (Coyote_App.Frontend.Run_Mode'Pos (F.Current_Mode));
   begin
      F.Stop_Btn.Set_Sensitive (Coyote_GUI.Stop_Available (Mode));
      if F.Stop_Item /= null then
         F.Stop_Item.Set_Sensitive (Coyote_GUI.Stop_Available (Mode));
      end if;
      if F.Pause_Item /= null then
         F.Pause_Item.Set_Sensitive (Coyote_GUI.Pause_Available (Mode));
      end if;
      if F.Resume_Item /= null then
         F.Resume_Item.Set_Sensitive (Coyote_GUI.Resume_Available (Mode));
      end if;
   end Apply_Agent_Menu_Sensitivity;

   procedure On_Edit_Menu_Show
     (Self : access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      pragma Unreferenced (Self);
      Prompt_Sel : Boolean;
      Conv_Sel   : Boolean;
      Clip       : Gtk.Clipboard.Gtk_Clipboard;
   begin
      if Current_Frontend = null then
         return;
      end if;
      Prompt_Sel := Current_Frontend.Prompt_Buf /= null
        and then Current_Frontend.Prompt_Buf.Get_Has_Selection;
      Conv_Sel :=
        (if Current_Frontend.Stack_Enabled
         then Current_Frontend.Stack.Has_Selection
         else Current_Frontend.Conv.Has_Selection);
      Clip := Gtk.Clipboard.Get;
      if Current_Frontend.Cut_Item /= null then
         Current_Frontend.Cut_Item.Set_Sensitive (Prompt_Sel);
      end if;
      if Current_Frontend.Copy_Item /= null then
         Current_Frontend.Copy_Item.Set_Sensitive
           (Prompt_Sel or else Conv_Sel);
      end if;
      if Current_Frontend.Paste_Item /= null then
         Current_Frontend.Paste_Item.Set_Sensitive
           (Clip.Wait_Is_Text_Available);
      end if;
      if Current_Frontend.Select_All_Item /= null then
         Current_Frontend.Select_All_Item.Set_Sensitive (True);
      end if;
      if Current_Frontend.Deselect_Item /= null then
         Current_Frontend.Deselect_Item.Set_Sensitive
           (Prompt_Sel or else Conv_Sel);
      end if;
   end On_Edit_Menu_Show;

   procedure On_Cut_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend = null
        or else Current_Frontend.Prompt_Buf = null
      then
         return;
      end if;
      if Current_Frontend.Prompt_Buf.Get_Has_Selection then
         Current_Frontend.Prompt_Buf.Cut_Clipboard
           (Gtk.Clipboard.Get, True);
      end if;
   end On_Cut_Activate;

   procedure On_Copy_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend = null then
         return;
      end if;
      if Current_Frontend.Prompt_View /= null
        and then Current_Frontend.Prompt_View.Has_Focus
      then
         if Current_Frontend.Prompt_Buf /= null
           and then Current_Frontend.Prompt_Buf.Get_Has_Selection
         then
            Current_Frontend.Prompt_Buf.Copy_Clipboard
              (Gtk.Clipboard.Get);
         end if;
         return;
      end if;
      if Current_Frontend.Stack_Enabled then
         Current_Frontend.Stack.Copy_Selection;
      else
         Current_Frontend.Conv.Copy_Selection;
      end if;
   end On_Copy_Activate;

   procedure On_Paste_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend = null
        or else Current_Frontend.Prompt_Buf = null
      then
         return;
      end if;
      if Current_Frontend.Prompt_View /= null then
         Current_Frontend.Prompt_View.Grab_Focus;
      end if;
      Current_Frontend.Prompt_Buf.Paste_Clipboard (Gtk.Clipboard.Get);
   end On_Paste_Activate;

   procedure On_Select_All_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Current_Frontend = null then
         return;
      end if;
      if Current_Frontend.Prompt_View /= null
        and then Current_Frontend.Prompt_View.Has_Focus
        and then Current_Frontend.Prompt_Buf /= null
      then
         Current_Frontend.Prompt_Buf.Get_Start_Iter (Start_Iter);
         Current_Frontend.Prompt_Buf.Get_End_Iter (End_Iter);
         Current_Frontend.Prompt_Buf.Select_Range
           (Start_Iter, End_Iter);
         return;
      end if;
      if Current_Frontend.Stack_Enabled then
         Current_Frontend.Stack.Select_All;
      else
         Current_Frontend.Conv.Select_All;
      end if;
   end On_Select_All_Activate;

   procedure On_Deselect_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      Insert : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Current_Frontend = null then
         return;
      end if;
      if Current_Frontend.Prompt_Buf /= null
        and then Current_Frontend.Prompt_Buf.Get_Has_Selection
      then
         Current_Frontend.Prompt_Buf.Get_Iter_At_Mark
           (Insert, Current_Frontend.Prompt_Buf.Get_Insert);
         Current_Frontend.Prompt_Buf.Place_Cursor (Insert);
      end if;
      if Current_Frontend.Stack_Enabled then
         Current_Frontend.Stack.Clear_Selection;
      else
         Current_Frontend.Conv.Clear_Selection;
      end if;
   end On_Deselect_Activate;

   function On_Prompt_Button_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      pragma Unreferenced (Self);
      use Gtk.Enums;
      use Gtk.Selection_Data;
      use Gtk.Clipboard;
      Buffer_X : Glib.Gint;
      Buffer_Y : Glib.Gint;
      Iter     : aliased Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Current_Frontend = null
        or else Event.The_Type /= Gdk.Event.Button_Press
        or else Glib.Gint (Event.Button) /= Gdk.Event.Button_Middle
      then
         return False;
      end if;

      Current_Frontend.Prompt_View.Window_To_Buffer_Coords
        (Text_Window_Widget,
         Glib.Gint (Event.X), Glib.Gint (Event.Y), Buffer_X, Buffer_Y);
      if Current_Frontend.Prompt_View.Get_Iter_At_Location
        (Iter'Access, Buffer_X, Buffer_Y)
      then
         Current_Frontend.Prompt_Buf.Place_Cursor (Iter);
         Current_Frontend.Prompt_Buf.Paste_Clipboard
           (Get (Selection_Primary));
         Current_Frontend.Prompt_View.Grab_Focus;
         return True;
      end if;
      return False;
   end On_Prompt_Button_Press;

   --  ── Signal handlers for conversation-scroll follow mode ───────────────

   --  Called after GTK recomputes the text-view layout and updates the
   --  vadjustment upper bound.  When follow mode is active, snap the
   --  viewport to the new bottom so streaming text stays in view.
   procedure On_Conv_Adj_Changed
     (Self : access Gtk.Adjustment.Gtk_Adjustment_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend = null
        or else not Current_Frontend.Auto_Scroll
      then
         return;
      end if;
      declare
         Adj    : constant Gtk.Adjustment.Gtk_Adjustment :=
           Current_Frontend.Conv_Scroll.Get_Vadjustment;
         Target : constant Gdouble :=
           Gdouble'Max (Adj.Get_Upper - Adj.Get_Page_Size, 0.0);
      begin
         Adj.Set_Value (Target);
      end;
   end On_Conv_Adj_Changed;

   --  ── Tool-call click handler ───────────────────────────────────────────

   function On_Conv_Button_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      pragma Unreferenced (Self);
      use type Gdk.Event.Gdk_Event_Type;
   begin
      if Event.The_Type /= Gdk.Event.Button_Press
        or else Event.Button /= 1
        or else Current_Frontend = null
      then
         return False;
      end if;

      if Current_Frontend.Help_Mode then
         Reset_Click_For_Help (Current_Frontend.all);
         Show_Context_Help ("conversation");
         return True;
      end if;

      --  Try tool click first.
      declare
         Result : constant Coyote_GUI.Conversation.Tool_Click_Result :=
           Current_Frontend.Conv.Handle_Tool_Click
             (Glib.Gint (Event.X), Glib.Gint (Event.Y));
      begin
         if Result.Found then
            Coyote_GUI.Tool_Detail_Window.Show
              (Result.Info, Current_Frontend.Win.all'Access);
            return True;
         end if;
      end;

      --  Try action strip click (e.g. fork).
      declare
         use type Coyote_GUI.Conversation.Action_Kind;
         Result : constant Coyote_GUI.Conversation.Action_Click_Result :=
           Current_Frontend.Conv.Handle_Action_Click
             (Glib.Gint (Event.X), Glib.Gint (Event.Y));
      begin
         if Result.Found and then Result.Action.Kind = Coyote_GUI.Conversation.Fork then
            declare
               use Ada.Strings.Unbounded;
               New_UUID : constant String :=
                 Session_Lister.Fork_Session
                   (Source_UUID => To_String (Result.Action.Fork_UUID),
                    After_Turn  => Result.Action.Fork_Turn_N,
                    Target_Cwd  => Ada.Directories.Current_Directory,
                    After_Step  => Result.Action.Fork_Step_N);
            begin
               if New_UUID'Length > 0 then
                  declare
                     use GNATCOLL.OS.Process;
                     Args : Argument_List;
                  begin
                     Args.Append (Ada.Command_Line.Command_Name);
                     Args.Append ("--session");
                     Args.Append (New_UUID);
                     Coyote_Spawn.Spawn_Detached (Args);
                  end;
               end if;
            end;
            return True;
         end if;
      end;
      return False;
   end On_Conv_Button_Press;

   procedure On_Native_Fork
     (UUID   : String;
      Turn_N : Positive;
      Step_N : Natural)
   is
      New_UUID : constant String :=
        Session_Lister.Fork_Session
          (Source_UUID => UUID,
           After_Turn  => Turn_N,
           Target_Cwd  => Ada.Directories.Current_Directory,
           After_Step  => Step_N);
   begin
      if New_UUID'Length > 0 then
         declare
            use GNATCOLL.OS.Process;
            Args : Argument_List;
         begin
            Args.Append (Ada.Command_Line.Command_Name);
            Args.Append ("--session");
            Args.Append (New_UUID);
            Coyote_Spawn.Spawn_Detached (Args);
         end;
      end if;
   end On_Native_Fork;

   function On_Conv_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
      use type Gdk.Types.Gdk_Key_Type;
      Result : Coyote_GUI.Conversation.Tool_Click_Result;
   begin
      if Current_Frontend = null
        or else (Event.Keyval not in Gdk.Types.Keysyms.GDK_Return
                 | Gdk.Types.Keysyms.GDK_KP_Enter
                 | Gdk.Types.Keysyms.GDK_space)
      then
         return False;
      end if;

      Result := Current_Frontend.Conv.Focused_Tool;
      if Result.Found then
         Coyote_GUI.Tool_Detail_Window.Show
           (Result.Info, Current_Frontend.Win.all'Access);
         return True;
      end if;

      declare
         Action : constant Coyote_GUI.Conversation.Action_Click_Result :=
           Current_Frontend.Conv.Focused_Action;
      begin
         if Action.Found
           and then Action.Action.Kind = Coyote_GUI.Conversation.Fork
         then
            declare
               New_UUID : constant String :=
                 Session_Lister.Fork_Session
                   (Source_UUID => To_String (Action.Action.Fork_UUID),
                    After_Turn  => Action.Action.Fork_Turn_N,
                    Target_Cwd  => Ada.Directories.Current_Directory,
                    After_Step  => Action.Action.Fork_Step_N);
            begin
               if New_UUID'Length > 0 then
                  declare
                     use GNATCOLL.OS.Process;
                     Args : Argument_List;
                  begin
                     Args.Append (Ada.Command_Line.Command_Name);
                     Args.Append ("--session");
                     Args.Append (New_UUID);
                     Coyote_Spawn.Spawn_Detached (Args);
                  end;
               end if;
            end;
            return True;
         end if;
      end;
      return False;
   end On_Conv_Key_Press;

   --  ── Apply_Update — called on the GTK main thread by Drain_Idle ────────

   procedure Apply_Update (F : in out Instance; U : Coyote_GUI.Update) is
      use Coyote_GUI;
   begin
      case U.Kind is

         when Begin_Request =>
            if F.Stack_Enabled then
               F.Stack.Begin_Request
                 (Text => To_String (U.Text),
                  Kind => Coyote_GUI.Request_Kind (U.R_Kind));
            else
               F.Conv.Append_Notice
                 (Coyote_GUI.Conversation.Notice_Info,
                  ASCII.LF
                  & (if U.R_Kind = Coyote_GUI.Steer
                     then UC_HOOK_L & " Steer: "
                     else UC_TRI_R & " ")
                  & To_String (U.Text) & ASCII.LF);
            end if;

         when Complete_Request =>
            if F.Stack_Enabled then
               F.Stack.Complete_Request
                 (Coyote_GUI.Completion_Status (U.C_Status));
            end if;

         when Append_Text =>
            if F.Stack_Enabled then
               F.Stack.Append_Text (To_String (U.Text));
            else
               F.Conv.Append_Text (To_String (U.Text));
            end if;

         when End_Text_Block =>
            if F.Stack_Enabled then
               F.Stack.End_Text_Block;
            else
               F.Conv.End_Text_Block;
            end if;

         when Begin_Thinking =>
            if F.Stack_Enabled then
               F.Stack.Begin_Thinking;
            else
               F.Conv.Begin_Thinking;
            end if;

         when Append_Thinking =>
            if F.Stack_Enabled then
               F.Stack.Append_Thinking (To_String (U.Text));
            else
               F.Conv.Append_Thinking (To_String (U.Text));
            end if;

         when End_Thinking =>
            if F.Stack_Enabled then
               F.Stack.End_Thinking;
            else
               F.Conv.End_Thinking;
            end if;

         when Begin_Tool =>
            if F.Stack_Enabled then
               F.Stack.Begin_Tool
                 (Name             => To_String (U.Text),
                  Args             => To_String (U.Text2),
                  Session_Id       => To_String (U.Text3),
                  Tool_Id          => To_String (U.Text4),
                  Model            => To_String (U.Text5),
                  Source_Directory => To_String (U.Text6),
                  Session_Start   => To_String (U.Text7),
                  Turn_Index       => Positive'Max (U.Tool_Turn, 1),
                  Call_In_Turn     => Positive'Max (U.Tool_Call, 1));
            else
            F.Conv.Begin_Tool
              (Name             => To_String (U.Text),
               Args             => To_String (U.Text2),
               Session_Id       => To_String (U.Text3),
               Tool_Id           => To_String (U.Text4),
               Model            => To_String (U.Text5),
               Source_Directory => To_String (U.Text6),
               Session_Start    => To_String (U.Text7),
               Turn_Index       => Positive'Max (U.Tool_Turn, 1),
               Call_In_Turn     => Positive'Max (U.Tool_Call, 1));
            end if;

         when End_Tool =>
            if F.Stack_Enabled then
               F.Stack.End_Tool
                 (Tool_Id    => To_String (U.Text),
                  Status     => Coyote_GUI.Tool_End_Status (U.T_Status),
                  Result     => To_String (U.Text2),
                  Media_Type => To_String (U.Text3));
            else
            F.Conv.End_Tool
              (Tool_Id    => To_String (U.Text),
               Status     => Coyote_GUI.Conversation.Tool_End_Status'Val
                               (Coyote_GUI.Tool_End_Status'Pos (U.T_Status)),
               Result     => To_String (U.Text2),
               Media_Type => To_String (U.Text3));
            end if;

         when Append_Notice =>
            if F.Stack_Enabled then
               F.Stack.Append_Notice
                 (Kind => Coyote_GUI.Notice_Kind (U.N_Kind),
                  Text => To_String (U.Text));
            else
               F.Conv.Append_Notice
                 (Kind => Coyote_GUI.Conversation.Line_Style'Val
                            (Coyote_GUI.Notice_Kind'Pos (U.N_Kind)
                             + Coyote_GUI.Conversation.Line_Style'Pos
                                 (Coyote_GUI.Conversation.Notice_Info)),
                  Text => To_String (U.Text));
            end if;

         when Append_Turn_Footer =>
            if F.Stack_Enabled then
               F.Stack.Append_Turn_Footer
                 (Text    => To_String (U.Text),
                  Kind    => Coyote_GUI.Footer_Kind (U.F_Kind),
                  Summary => To_String (U.Text2));
            else
               F.Conv.Append_Turn_Footer
                 (To_String (U.Text),
                  (if U.F_Kind = Coyote_GUI.Step_Footer
                   then Coyote_GUI.Conversation.Step_Footer
                   else Coyote_GUI.Conversation.Final_Footer));
            end if;

         when Append_Action_Strip =>
            declare
               UUID_Str : constant String := To_String (U.Text2);
               Turn_Str : constant String := To_String (U.Text3);
               Step_Str : constant String := To_String (U.Text4);
               Turn_Val : Positive;
               Step_Val : Natural := 0;
            begin
               if UUID_Str'Length > 0 and then Turn_Str'Length > 0 then
                  Turn_Val := Positive'Value (Turn_Str);
                  if Step_Str'Length > 0 then
                     Step_Val := Natural'Value (Step_Str);
                  end if;
                  if F.Stack_Enabled then
                     F.Stack.Append_Fork_Action
                       (Label  => To_String (U.Text),
                        UUID   => UUID_Str,
                        Turn_N => Turn_Val,
                        Step_N => Step_Val);
                  else
                     F.Conv.Append_Action_Strip
                       (To_String (U.Text),
                        (Kind        => Coyote_GUI.Conversation.Fork,
                         Fork_UUID   => U.Text2,
                         Fork_Turn_N => Turn_Val,
                         Fork_Step_N => Step_Val));
                  end if;
               end if;
            end;

         when Set_Status =>
            F.Status_Bar.Set_Text (To_String (U.Text));

         when Set_Mode =>
            F.Current_Mode :=
              Coyote_App.Frontend.Run_Mode'Val
                (Coyote_GUI.Run_Mode'Pos (U.Mode));
            Apply_Agent_Menu_Sensitivity (F);

         when Set_Stats =>
            Coyote_GUI.Session_Stats_Window.Update
              (F.Stats_Window, U.Stats);

         when Clear_Stats =>
            Coyote_GUI.Session_Stats_Window.Clear (F.Stats_Window);

         when Clear_Conversation =>
            F.Conv.Clear;
            if F.Stack_Enabled then
               F.Stack.Clear;
            end if;
            if F.Transcript_Buf /= null then
               F.Transcript_Buf.Set_Text ("");
            end if;

         when Set_Transcript =>
            if F.Transcript_Buf /= null then
               F.Transcript_Buf.Set_Text (To_String (U.Text));
            end if;

         when Set_Session_Identity =>
            F.Win.Set_Role
              ("coyote-session-" & To_String (U.Text));

         when Set_Completion_Notifications =>
            F.Notifications_Enabled :=
              F.Notifications_Allowed and then U.Enabled;

         when Completion_Notification =>
            if Coyote_GUI.Notification_Policy.Should_Notify_Completion
              (Allowed       => F.Notifications_Allowed,
               Enabled       => F.Notifications_Enabled,
               Window_Active => F.Win.Is_Active)
            then
               if not Coyote_Notify.Show_Completion then
                  null;
               end if;
            end if;

         when Show_Detail =>
            Show_Text_Window
              (Current_Frontend.Win.all'Access,
               "coyote : Detail",
               To_String (U.Text) & ASCII.LF & To_String (U.Text2));

         when Shutdown =>
            F.PQ.Shutdown;
            Gtk.Main.Main_Quit;

      end case;
      if F.Stack_Enabled and then F.Auto_Scroll then
         F.Stack.Scroll_To_End;
      end if;
      if F.Transcript_Buf /= null
        and then U.Kind /= Set_Stats
        and then U.Kind /= Clear_Stats
        and then U.Kind /= Set_Transcript
      then
         F.Transcript_Buf.Set_Text
           (if F.Stack_Enabled
            then F.Stack.Transcript_Text
            else F.Conv.Transcript_Text);
      end if;
   end Apply_Update;

   --  ── GLib idle drain callback ──────────────────────────────────────────

   function Drain_Idle return Boolean is
      U           : Coyote_GUI.Update;
      Got         : Boolean;
      Keep_Active : Boolean;
   begin
      if Current_Frontend = null then
         return False;
      end if;
      Current_Frontend.Updates.Dequeue (U, Got);
      if Got then
         Apply_Update (Current_Frontend.all, U);
      end if;
      Current_Frontend.Updates.Idle_Done (Keep_Active);
      return Keep_Active;
   end Drain_Idle;

   --  ── Enqueue_Update — enqueue and schedule idle drain if needed ────────

   procedure Enqueue_Update (F : in out Instance; U : Coyote_GUI.Update) is
      Wake_Needed : Boolean;
      Idle_Id     : Glib.Main.G_Source_Id;
      pragma Unreferenced (Idle_Id);
   begin
      F.Updates.Enqueue (U, Wake_Needed);
      if Wake_Needed then
         Idle_Id := Glib.Main.Idle_Add (Drain_Idle'Access);
      end if;
   end Enqueue_Update;

   --  ── Signal handlers ───────────────────────────────────────────────────

   function On_Window_Delete
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event) return Boolean
   is
      pragma Unreferenced (Self, Event);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Shutdown;
         Current_Frontend.Updates.Stop;
      end if;
      Gtk.Main.Main_Quit;
      return True;  --  suppress default handler (window destruction)
   end On_Window_Delete;

   procedure On_Send_Clicked
     (Self : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Self);
      use Gtk.Text_Iter;
      SI, EI : Gtk_Text_Iter;
   begin
      if Current_Frontend = null then
         return;
      end if;
      Current_Frontend.Prompt_Buf.Get_Start_Iter (SI);
      Current_Frontend.Prompt_Buf.Get_End_Iter   (EI);
      declare
         Text : constant String :=
           Current_Frontend.Prompt_Buf.Get_Text (SI, EI);
         Accepted : Boolean;
      begin
         if Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both)'Length = 0 then
            return;
         end if;
         Current_Frontend.PQ.Enqueue
           ((User_Prompt,
             Text => To_Unbounded_String (Text)), Accepted);
         if Accepted then
            Current_Frontend.Prompt_Buf.Set_Text ("");
         else
            Current_Frontend.Append_Notice
              (Coyote_App.Frontend.Warning,
               "Input queue is full; prompt retained.");
         end if;
      end;
   end On_Send_Clicked;

   function On_Prompt_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
      use type Gdk.Types.Gdk_Key_Type;
      use type Gdk.Types.Gdk_Modifier_Type;
   begin
      if (Event.Keyval = Gdk.Types.Keysyms.GDK_Return
            or else Event.Keyval = Gdk.Types.Keysyms.GDK_KP_Enter)
        and then (Event.State and Gdk.Types.Shift_Mask) = 0
      then
         On_Send_Clicked (null);
         return True;
      end if;
      return False;
   end On_Prompt_Key_Press;

   --  ── Menu item handlers ────────────────────────────────────────────────

   procedure On_New_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => New_Window));
      end if;
   end On_New_Activate;

   procedure On_New_Session_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => New_Session));
      end if;
   end On_New_Session_Activate;

   procedure On_Clear_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
      Accepted : Boolean;
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Clear), Accepted);
      end if;
   end On_Clear_Activate;

   procedure On_Send_Menu_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      On_Send_Clicked (null);
   end On_Send_Menu_Activate;

   procedure On_Quit_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Shutdown;
         Current_Frontend.Updates.Stop;
      end if;
      Gtk.Main.Main_Quit;
   end On_Quit_Activate;

   procedure On_Stop_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.Agent_Sess.Request_Abort;
      end if;
   end On_Stop_Activate;

   procedure On_Stop_Btn_Clicked
     (Self : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.Agent_Sess.Request_Abort;
      end if;
   end On_Stop_Btn_Clicked;

   procedure On_Pause_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Pause));
      end if;
   end On_Pause_Activate;

   procedure On_Resume_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Resume));
      end if;
   end On_Resume_Activate;

   procedure On_Compact_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Compact));
      end if;
   end On_Compact_Activate;

   procedure On_Set_Default_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue ((Kind => Set_Default));
      end if;
   end On_Set_Default_Activate;
   procedure On_Stats_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         if not Coyote_GUI.Session_Stats_Window.Is_Created
           (Current_Frontend.Stats_Window)
         then
            Coyote_GUI.Session_Stats_Window.Create
              (Current_Frontend.Stats_Window,
               Current_Frontend.Win.all'Access);
         end if;
         Coyote_GUI.Session_Stats_Window.Show
           (Current_Frontend.Stats_Window);
      end if;
   end On_Stats_Activate;

   procedure On_Click_For_Help_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Arm_Click_For_Help (Current_Frontend.all);
      end if;
   end On_Click_For_Help_Activate;

   procedure On_Overview_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      Open_Help_Topic ("overview");
   end On_Overview_Activate;

   procedure On_Keys_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      Open_Help_Topic ("keyboard-shortcuts");
   end On_Keys_Activate;

   procedure On_Product_Information_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
      Dialog  : Gtk.Dialog.Gtk_Dialog;
      Label   : Gtk.Label.Gtk_Label;
      Btn     : Gtk.Widget.Gtk_Widget;
      Content : Gtk.Box.Gtk_Box;
      Resp    : Gtk.Dialog.Gtk_Response_Type;
      pragma Unreferenced (Btn, Resp);
   begin
      if Current_Frontend = null then
         return;
      end if;
      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("coyote : Product Information");
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Dialog.Set_Default_Size (420, 180);
      Btn := Dialog.Add_Button ("_OK", Gtk.Dialog.Gtk_Response_OK);
      Dialog.Set_Default_Response (Gtk.Dialog.Gtk_Response_OK);
      Content := Dialog.Get_Content_Area;
      Gtk.Label.Gtk_New (Label, Coyote_Help.Product_Information_Text);
      Label.Set_Line_Wrap (True);
      Label.Set_Xalign (0.0);
      Label.Set_Margin_Start (12);
      Label.Set_Margin_End (12);
      Label.Set_Margin_Top (10);
      Label.Set_Margin_Bottom (10);
      Content.Pack_Start (Label, True, True, 0);
      Dialog.Show_All;
      Resp := Dialog.Run;
      Dialog.Destroy;
   end On_Product_Information_Activate;

   procedure On_Index_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      Open_Help_Topic ("");
   end On_Index_Activate;

   procedure On_Send_Help_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      Open_Help_Topic ("send-prompt");
   end On_Send_Help_Activate;

   procedure On_Session_Help_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      Open_Help_Topic ("manage-sessions");
   end On_Session_Help_Activate;

   procedure On_Controls_Help_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      Open_Help_Topic ("agent-controls");
   end On_Controls_Help_Activate;

   --  ── Open Session dialog ───────────────────────────────────────────────

   procedure On_Open_Session_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      use Gtk.Dialog;
      use Gtk.Tree_Store;
      use Gtk.Tree_Model;
      use Gtk.Tree_View;

      --  ↳  U+21B3 DOWNWARDS ARROW WITH TIP RIGHTWARDS (subagent)
      UC_Hook_R : constant String :=
        Character'Val (16#E2#) & Character'Val (16#86#)
        & Character'Val (16#B3#);

      --  ⎇  U+2387 ALTERNATIVE KEY SYMBOL (fork)
      UC_Fork_R : constant String :=
        Character'Val (16#E2#) & Character'Val (16#8E#)
        & Character'Val (16#87#);

      --  Column indices (Guint for GType_Array / Set_Tooltip_Column;
      --  cast to Gint at Store.Set / Add_Text_Column / Get_Value call sites).
      Col_Kind    : constant Glib.Guint := 0;
      Col_Name    : constant Glib.Guint := 1;
      Col_Date    : constant Glib.Guint := 2;
      Col_Snippet : constant Glib.Guint := 3;
      Col_UUID    : constant Glib.Guint := 4;

      Sessions : Session_Lister.Session_Vectors.Vector;
      Store    : Gtk_Tree_Store;
      View     : Gtk_Tree_View;
      Scroll   : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Content  : Gtk.Box.Gtk_Box;
      Dialog   : Gtk_Dialog;
      Resp     : Gtk_Response_Type;
      Sel      : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Model    : Gtk_Tree_Model;
      Iter     : Gtk_Tree_Iter;
      Val      : Glib.Values.GValue;
      Dummy    : Glib.Gint;
      pragma Unreferenced (Dummy);
      Btn      : Gtk.Widget.Gtk_Widget;
      pragma Unreferenced (Btn);

      --  ── Column helpers ──────────────────────────────────────────────
      procedure Add_Text_Column (Title : String; Col_Num : Glib.Guint) is
         Col      : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
         Renderer : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      begin
         Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
         Gtk.Tree_View_Column.Gtk_New (Col);
         Col.Set_Title (Title);
         Col.Pack_Start (Renderer, Expand => True);
         Col.Add_Attribute (Renderer, "text", Glib.Gint (Col_Num));
         Dummy := View.Append_Column (Col);
      end Add_Text_Column;

      --  ── Recursive tree population ────────────────────────────────────
      --  Mirrors the Render_Session logic in Coyote_App.Utils.Format_Session_List.
      --  Escape Pango markup special characters so raw text can be used
      --  as a tooltip string rendered by Set_Tooltip_Column.
      function Escape_Markup (S : String) return String is
         use Ada.Strings.Unbounded;
         Result : Unbounded_String;
      begin
         for C of S loop
            case C is
               when '&' => Append (Result, "&amp;");
               when '<' => Append (Result, "&lt;");
               when '>' => Append (Result, "&gt;");
               when others => Append (Result, C);
            end case;
         end loop;
         return To_String (Result);
      end Escape_Markup;

      procedure Render_Session
        (Info   : Session_Lister.Session_Info;
         Parent : Gtk_Tree_Iter)
      is
         use Ada.Strings.Unbounded;
         Row        : Gtk_Tree_Iter;
         Kind_Glyph : constant String :=
           (if Ada.Strings.Unbounded.Length (Info.Parent_Id) = 0
            then ""
            elsif Info.Is_Fork
            then UC_Fork_R
            else UC_Hook_R);
      begin
         Store.Append (Row, Parent);
         Store.Set (Row, Glib.Gint (Col_Kind),    Kind_Glyph);
         Store.Set (Row, Glib.Gint (Col_Name),    To_String (Info.Name));
         Store.Set (Row, Glib.Gint (Col_Date),    To_String (Info.Date));
         Store.Set (Row, Glib.Gint (Col_Snippet), Escape_Markup (To_String (Info.Snippet)));
         Store.Set (Row, Glib.Gint (Col_UUID),    To_String (Info.UUID));

         --  Recurse: attach direct children under this row.
         for Child of Sessions loop
            if To_String (Child.Parent_Id) = To_String (Info.UUID) then
               Render_Session (Child, Row);
            end if;
         end loop;
      end Render_Session;

      --  Return True when the session's parent UUID appears in Sessions.
      function Parent_In_List
        (Info : Session_Lister.Session_Info) return Boolean
      is
         use Ada.Strings.Unbounded;
      begin
         if Length (Info.Parent_Id) = 0 then
            return False;
         end if;

         for Other of Sessions loop
            if To_String (Other.UUID) = To_String (Info.Parent_Id) then
               return True;
            end if;
         end loop;

         return False;
      end Parent_In_List;

   begin
      if Current_Frontend = null then
         return;
      end if;

      Sessions := Session_Lister.List_Sessions
        (Ada.Directories.Current_Directory);

      --  Build the tree store (Kind, Name, Date, Snippet, UUID).
      Gtk.Tree_Store.Gtk_New
        (Store,
         (Col_Kind    => Glib.GType_String,
          Col_Name    => Glib.GType_String,
          Col_Date    => Glib.GType_String,
          Col_Snippet => Glib.GType_String,
          Col_UUID    => Glib.GType_String));

      --  Populate: render roots; children are added recursively.
      for S of Sessions loop
         if not Parent_In_List (S) then
            Render_Session (S, Null_Iter);
         end if;
      end loop;

      Gtk.Tree_View.Gtk_New (View, +Store);
      View.Set_Tooltip_Column (Glib.Gint (Col_Snippet));
      Add_Text_Column ("",     Col_Kind);
      Add_Text_Column ("Name", Col_Name);
      Add_Text_Column ("Date", Col_Date);
      Add_Text_Column ("Snippet", Col_Snippet);
      View.Expand_All;

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Gtk.Enums.Policy_Automatic,
                         Gtk.Enums.Policy_Automatic);
      Scroll.Add (View);

      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("coyote : Open Session");
      Dialog.Set_Default_Size (660, 440);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Open",   Gtk_Response_OK);
      Btn := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start (Scroll, Expand => True, Fill => True, Padding => 4);
      Dialog.Show_All;
      View.Grab_Focus;

      Resp := Dialog.Run;
      if Resp = Gtk_Response_OK then
         Sel := View.Get_Selection;
         Sel.Get_Selected (Model, Iter);
         if Iter /= Null_Iter then
            Gtk.Tree_Model.Get_Value (Model, Iter, Glib.Gint (Col_UUID), Val);
            declare
               UUID : constant String := Glib.Values.Get_String (Val);
            begin
               Glib.Values.Unset (Val);
               if UUID'Length > 0 then
                  Current_Frontend.PQ.Enqueue
                    ((Switch_Session,
                      Session_UUID => To_Unbounded_String (UUID)));
               end if;
            end;
         end if;
      end if;
      Dialog.Destroy;
   end On_Open_Session_Activate;
   --  ── Open Session dialog ───────────────────────────────────────────────



   --  ── Change Model dialog ───────────────────────────────────────────────

   procedure On_Change_Model_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      use Gtk.Dialog;
      use Gtk.List_Store;
      use Gtk.Tree_Model;
      use Gtk.Tree_Model_Filter;
      use Gtk.Tree_Model_Sort;
      use Gtk.Tree_View;

      Models  : constant LLM.Model_Registry.Model_Info_Vectors.Vector :=
                  LLM.Model_Registry.Available_Models;
      Store      : Gtk_List_Store;
      View       : Gtk_Tree_View;
      Scroll     : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Search_Row : Gtk.Box.Gtk_Box;
      Content    : Gtk.Box.Gtk_Box;
      Dialog     : Gtk_Dialog;
      Resp    : Gtk_Response_Type;
      Sel     : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Tmodel  : Gtk_Tree_Model;
      Iter    : Gtk_Tree_Iter;
      Val     : Glib.Values.GValue;
      Dummy   : Glib.Gint;
      pragma Unreferenced (Dummy);
      Btn     : Gtk.Widget.Gtk_Widget;
      pragma Unreferenced (Btn);

      --  Append one text column to View backed by Col_Num of Store.
      --  If Sort_Col >= 0 the column header becomes clickable for sorting.
      procedure Add_Text_Column
        (Title    : String;
         Col_Num  : Glib.Gint;
         Sort_Col : Glib.Gint := -1)
      is
         Col      : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
         Renderer : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      begin
         Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
         Gtk.Tree_View_Column.Gtk_New (Col);
         Col.Set_Title (Title);
         Col.Pack_Start (Renderer, Expand => True);
         Col.Add_Attribute (Renderer, "text", Col_Num);
         Col.Set_Resizable (True);
         if Sort_Col >= 0 then
            Col.Set_Sort_Column_Id (Sort_Col);
         end if;
         Dummy := View.Append_Column (Col);
      end Add_Text_Column;

      --  Convert a price (dollars per MTok) to a Gint sort key
      --  (micro-dollars per MTok).  Clamped to avoid Gint overflow.
      function Price_Sort (P : Long_Float) return Glib.Gint is
         Scale : constant Long_Float := 1.0e6;
         Max   : constant Long_Float := Long_Float (Glib.Gint'Last);
      begin
         if P <= 0.0 then
            return 0;
         elsif P * Scale >= Max then
            return Glib.Gint'Last;
         else
            return Glib.Gint (P * Scale);
         end if;
      end Price_Sort;

   begin
      if Current_Frontend = null then
         return;
      end if;

      --  Store columns: 0=Provider 1=Name 2=Context 3=In 4=Out 5=CR 6=CW
      --  (displayed strings); 7=Spec (hidden string);
      --  8=Ctx 9=In 10=Out 11=CR 12=CW (hidden Gint sort keys).
      Gtk.List_Store.Gtk_New
        (Store,
         (0  => Glib.GType_String,
          1  => Glib.GType_String,
          2  => Glib.GType_String,
          3  => Glib.GType_String,
          4  => Glib.GType_String,
          5  => Glib.GType_String,
          6  => Glib.GType_String,
          7  => Glib.GType_String,
          8  => Glib.GType_Int,
          9  => Glib.GType_Int,
          10 => Glib.GType_Int,
          11 => Glib.GType_Int,
          12 => Glib.GType_Int));

      for M of Models loop
         declare
            use Ada.Strings.Unbounded;
            Provider : constant String := To_String (M.Provider);
            Name     : constant String :=
              (if Length (M.Name) > 0
               then To_String (M.Name)
               else To_String (M.Model_Id));
            Ctx      : constant String :=
              Coyote_App.Utils.Format_SI_Count (M.Context_Window) & " ctx";
            In_P     : constant String :=
              Coyote_App.Utils.Format_SI_Price (M.Cost.Input);
            Out_P    : constant String :=
              Coyote_App.Utils.Format_SI_Price (M.Cost.Output);
            CR_P     : constant String :=
              Coyote_App.Utils.Format_SI_Price (M.Cost.Cache_Read);
            CW_P     : constant String :=
              Coyote_App.Utils.Format_SI_Price (M.Cost.Cache_Write);
            Spec     : constant String :=
              Provider & "/" & To_String (M.Model_Id);
            Row      : Gtk_Tree_Iter;
         begin
            Store.Append (Row);
            Store.Set (Row, 0,  Provider);
            Store.Set (Row, 1,  Name);
            Store.Set (Row, 2,  Ctx);
            Store.Set (Row, 3,  In_P);
            Store.Set (Row, 4,  Out_P);
            Store.Set (Row, 5,  CR_P);
            Store.Set (Row, 6,  CW_P);
            Store.Set (Row, 7,  Spec);
            Store.Set (Row, 8,  Glib.Gint (M.Context_Window));
            Store.Set (Row, 9,  Price_Sort (M.Cost.Input));
            Store.Set (Row, 10, Price_Sort (M.Cost.Output));
            Store.Set (Row, 11, Price_Sort (M.Cost.Cache_Read));
            Store.Set (Row, 12, Price_Sort (M.Cost.Cache_Write));
         end;
      end loop;

      Clear_Model_Picker;

      Gtk.Tree_Model_Filter.Gtk_New (Picker.Filter, +Store);
      Picker.Filter.Set_Visible_Func (Model_Picker_Row_Visible'Access);
      Gtk.Tree_Model_Sort.Gtk_New_With_Model
        (Picker.Sort, +Picker.Filter);

      --  View the sortable filter; typeahead is replaced by the
      --  search-entry filter above the list.
      Gtk.Tree_View.Gtk_New (View, +Picker.Sort);
      View.Set_Enable_Search (False);
      Add_Text_Column ("Provider",   0, Sort_Col => 0);
      Add_Text_Column ("Name",       1, Sort_Col => 1);
      Add_Text_Column ("Context",    2, Sort_Col => 8);
      Add_Text_Column ("In $/MTok",  3, Sort_Col => 9);
      Add_Text_Column ("Out $/MTok", 4, Sort_Col => 10);
      Add_Text_Column ("CR $/MTok",  5, Sort_Col => 11);
      Add_Text_Column ("CW $/MTok",  6, Sort_Col => 12);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Gtk.Enums.Policy_Automatic,
                         Gtk.Enums.Policy_Automatic);
      Scroll.Add (View);

      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("coyote : Select Model");
      Dialog.Set_Default_Size (1000, 520);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Select", Gtk_Response_OK);
      Btn := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Gtk.Search_Entry.Gtk_New (Picker.Search);
      Picker.Search.Set_Placeholder_Text ("Filter models");
      Picker.Search.On_Search_Changed
        (On_Model_Search_Changed'Access);
      Picker.Search.On_Stop_Search
        (On_Model_Search_Stop'Access);

      Gtk.Label.Gtk_New (Picker.Count, "");
      Picker.Count.Set_Xalign (1.0);
      Picker.Count.Set_Width_Chars (12);

      Gtk.Box.Gtk_New_Hbox
        (Search_Row, Homogeneous => False, Spacing => 8);
      Search_Row.Set_Border_Width (4);
      Search_Row.Pack_Start
        (Picker.Search, Expand => True, Fill => True, Padding => 0);
      Search_Row.Pack_Start
        (Picker.Count, Expand => False, Fill => False, Padding => 0);

      Picker.Store  := Store;
      Picker.View   := View;
      Picker.Dialog := Dialog;
      Picker.Query  := Null_Unbounded_String;
      Update_Model_Picker_Count;

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start
        (Search_Row, Expand => False, Fill => True, Padding => 0);
      Content.Pack_Start
        (Scroll, Expand => True, Fill => True, Padding => 4);
      Dialog.Show_All;
      Picker.Search.Grab_Focus;

      Resp := Dialog.Run;
      if Resp = Gtk_Response_OK then
         Sel := View.Get_Selection;
         Sel.Get_Selected (Tmodel, Iter);
         if Iter /= Null_Iter then
            Gtk.Tree_Model.Get_Value (Tmodel, Iter, 7, Val);
            declare
               use Ada.Strings.Unbounded;
               Spec : constant String := Glib.Values.Get_String (Val);
            begin
               Glib.Values.Unset (Val);
               if Spec'Length > 0 then
                  Current_Frontend.PQ.Enqueue
                    ((Set_Model,
                      Model_Spec => To_Unbounded_String (Spec)));
               end if;
            end;
         end if;
      end if;
      Dialog.Destroy;
      Clear_Model_Picker;
   end On_Change_Model_Activate;

   --  ── Thinking level handlers ───────────────────────────────────────────

   procedure On_Thinking_Off_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.Off));
      end if;
   end On_Thinking_Off_Activate;

   procedure On_Thinking_Minimal_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.Minimal));
      end if;
   end On_Thinking_Minimal_Activate;

   procedure On_Thinking_Low_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.Low));
      end if;
   end On_Thinking_Low_Activate;

   procedure On_Thinking_Medium_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.Medium));
      end if;
   end On_Thinking_Medium_Activate;

   procedure On_Thinking_High_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.High));
      end if;
   end On_Thinking_High_Activate;

   procedure On_Thinking_X_High_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.PQ.Enqueue
           ((Set_Thinking, Level => LLM.Providers.X_High));
      end if;
   end On_Thinking_X_High_Activate;

   --  ── Sandbox Profile dialog ────────────────────────────────────────────

   procedure On_Sandbox_Profile_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      use Gtk.Dialog;
      use Gtk.List_Store;
      use Gtk.Tree_Model;
      use Gtk.Tree_View;

      Profiles : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
        LLM.Tools.Sandbox.Available_Profiles;
      Store   : Gtk_List_Store;
      View    : Gtk_Tree_View;
      Scroll  : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Content : Gtk.Box.Gtk_Box;
      Dialog  : Gtk_Dialog;
      Resp    : Gtk_Response_Type;
      Sel     : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Tmodel  : Gtk_Tree_Model;
      Iter    : Gtk_Tree_Iter;
      Val     : Glib.Values.GValue;
      Dummy   : Glib.Gint;
      pragma Unreferenced (Dummy);
      Btn     : Gtk.Widget.Gtk_Widget;
      pragma Unreferenced (Btn);
   begin
      if Current_Frontend = null then
         return;
      end if;

      Gtk.List_Store.Gtk_New
        (Store, (0 => Glib.GType_String));

      --  "None" row first.
      Store.Append (Iter);
      Store.Set (Iter, 0, "None (no sandbox)");

      for P of Profiles loop
         Store.Append (Iter);
         Store.Set (Iter, 0, P);
      end loop;

      Gtk.Tree_View.Gtk_New (View, +Store);
      View.Set_Enable_Search (True);
      View.Set_Search_Column (0);
      declare
         Col      : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
         Renderer : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      begin
         Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
         Gtk.Tree_View_Column.Gtk_New (Col);
         Col.Set_Title ("Profile");
         Col.Pack_Start (Renderer, Expand => True);
         Col.Add_Attribute (Renderer, "text", 0);
         Dummy := View.Append_Column (Col);
      end;

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Gtk.Enums.Policy_Automatic,
                         Gtk.Enums.Policy_Automatic);
      Scroll.Add (View);

      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("coyote : Select Sandbox Profile");
      Dialog.Set_Default_Size (400, 300);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Select", Gtk_Response_OK);
      Btn := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start (Scroll, Expand => True, Fill => True, Padding => 4);
      Dialog.Show_All;
      View.Grab_Focus;

      Resp := Dialog.Run;
      if Resp = Gtk_Response_OK then
         Sel := View.Get_Selection;
         Sel.Get_Selected (Tmodel, Iter);
         if Iter /= Null_Iter then
            Gtk.Tree_Model.Get_Value (Tmodel, Iter, 0, Val);
            declare
               use Ada.Strings.Unbounded;
               Name : constant String := Glib.Values.Get_String (Val);
            begin
               Glib.Values.Unset (Val);
               Current_Frontend.PQ.Enqueue
                 ((Set_Sandbox,
                   Profile_Name =>
                     To_Unbounded_String
                       (if Name = "None (no sandbox)" then "" else Name)));
            end;
         end if;
      end if;
      Dialog.Destroy;
   end On_Sandbox_Profile_Activate;

   --  ── Persistent GUI preferences ───────────────────────────────────────

   procedure On_Preferences_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      Settings_Value : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;
      Models         : constant LLM.Model_Registry.Model_Info_Vectors.Vector :=
        LLM.Model_Registry.Available_Models;
      Profiles       : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
        LLM.Tools.Sandbox.Available_Profiles;
      Dialog         : Gtk.Dialog.Gtk_Dialog;
      Content        : Gtk.Box.Gtk_Box;
      Form           : Gtk.Box.Gtk_Box;
      Model_C             : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
      Subagent_Model_C    : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
      Thinking_C          : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
      Sandbox_C            : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
      Recursion_C         : Gtk.Spin_Button.Gtk_Spin_Button;
      Notification_C       : Gtk.Check_Button.Gtk_Check_Button;
      Resp                 : Gtk.Dialog.Gtk_Response_Type;
      Btn                 : Gtk.Widget.Gtk_Widget;
      Thinking_Index      : Glib.Gint := 0;
      Sandbox_Index       : Glib.Gint := 0;
      Subagent_Model_Index : Glib.Gint := 0;
      Target_Model        : constant String :=
        To_String (Settings_Value.Default_Provider) & "/"
        & To_String (Settings_Value.Default_Model);
      Target_Subagent_Model : constant String :=
        (if Length (Settings_Value.Default_Subagent_Provider) > 0
           and then Length (Settings_Value.Default_Subagent_Model) > 0
         then To_String (Settings_Value.Default_Subagent_Provider) & "/"
           & To_String (Settings_Value.Default_Subagent_Model)
         else "");
      use type Gtk.Dialog.Gtk_Response_Type;

      function Model_Text
        (M : LLM.Model_Registry.Model_Info) return String
      is
      begin
         return To_String (M.Provider) & "/" & To_String (M.Model_Id);
      end Model_Text;

      function Model_Index_Of (Spec : String) return Glib.Gint is
         Index : Glib.Gint := 0;
      begin
         for M of Models loop
            if Model_Text (M) = Spec then
               return Index;
            end if;
            Index := Index + 1;
         end loop;
         return -1;
      end Model_Index_Of;
   begin
      if Current_Frontend = null then
         return;
      end if;
      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("coyote : Preferences");
      Dialog.Set_Default_Size (560, 370);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Save", Gtk.Dialog.Gtk_Response_OK);
      Btn := Dialog.Add_Button ("_Cancel", Gtk.Dialog.Gtk_Response_Cancel);
      Content := Dialog.Get_Content_Area;
      Gtk.Box.Gtk_New_Vbox (Form, Homogeneous => False, Spacing => 6);
      Form.Set_Border_Width (10);

      declare
         Row : Gtk.Box.Gtk_Box;
         Label : Gtk.Label.Gtk_Label;
      begin
         Gtk.Box.Gtk_New_Hbox (Row, Homogeneous => False, Spacing => 8);
         Gtk.Label.Gtk_New (Label, "Default model:");
         Row.Pack_Start (Label, False, False, 0);
         Gtk.Combo_Box_Text.Gtk_New (Model_C);
         for M of Models loop
            Model_C.Append_Text (Model_Text (M));
         end loop;
         if Model_Index_Of (Target_Model) >= 0 then
            Model_C.Set_Active (Model_Index_Of (Target_Model));
         elsif not Models.Is_Empty then
            Model_C.Set_Active (0);
         end if;
         Row.Pack_Start (Model_C, True, True, 0);
         Form.Pack_Start (Row, False, False, 0);
      end;

      declare
         Row : Gtk.Box.Gtk_Box;
         Label : Gtk.Label.Gtk_Label;
      begin
         Gtk.Box.Gtk_New_Hbox (Row, Homogeneous => False, Spacing => 8);
         Gtk.Label.Gtk_New (Label, "Default subagent model:");
         Row.Pack_Start (Label, False, False, 0);
         Gtk.Combo_Box_Text.Gtk_New (Subagent_Model_C);
         Subagent_Model_C.Append_Text ("Use default model");
         for M of Models loop
            Subagent_Model_C.Append_Text (Model_Text (M));
         end loop;
         if Target_Subagent_Model'Length > 0
           and then Model_Index_Of (Target_Subagent_Model) >= 0
         then
            Subagent_Model_Index :=
              Model_Index_Of (Target_Subagent_Model) + 1;
         end if;
         Subagent_Model_C.Set_Active (Subagent_Model_Index);
         Row.Pack_Start (Subagent_Model_C, True, True, 0);
         Form.Pack_Start (Row, False, False, 0);
      end;

      declare
         Row : Gtk.Box.Gtk_Box;
         Label : Gtk.Label.Gtk_Label;
      begin
         Gtk.Box.Gtk_New_Hbox (Row, Homogeneous => False, Spacing => 8);
         Gtk.Label.Gtk_New (Label, "Thinking level:");
         Row.Pack_Start (Label, False, False, 0);
         Gtk.Combo_Box_Text.Gtk_New (Thinking_C);
         for Level in LLM.Providers.Thinking_Level loop
            Thinking_C.Append_Text
              (Ada.Characters.Handling.To_Lower
                 (LLM.Providers.Thinking_Level'Image (Level)));
            if Ada.Characters.Handling.To_Lower
                 (LLM.Providers.Thinking_Level'Image (Level)) =
              To_String (Settings_Value.Default_Thinking)
            then
               Thinking_Index := LLM.Providers.Thinking_Level'Pos (Level);
            end if;
         end loop;
         Thinking_C.Set_Active (Thinking_Index);
         Row.Pack_Start (Thinking_C, True, True, 0);
         Form.Pack_Start (Row, False, False, 0);
      end;

      declare
         Row : Gtk.Box.Gtk_Box;
         Label : Gtk.Label.Gtk_Label;
      begin
         Gtk.Box.Gtk_New_Hbox (Row, Homogeneous => False, Spacing => 8);
         Gtk.Label.Gtk_New (Label, "Default sandbox:");
         Row.Pack_Start (Label, False, False, 0);
         Gtk.Combo_Box_Text.Gtk_New (Sandbox_C);
         Sandbox_C.Append_Text ("None (no sandbox)");
         for Profile of Profiles loop
            Sandbox_C.Append_Text (Profile);
         end loop;
         if Length (Settings_Value.Default_Sandbox) > 0 then
            for Index in Profiles.First_Index .. Profiles.Last_Index loop
               if Profiles.Element (Index) =
                 To_String (Settings_Value.Default_Sandbox)
               then
                  Sandbox_Index := Glib.Gint (Index);
               end if;
            end loop;
         end if;
         Sandbox_C.Set_Active (Sandbox_Index);
         Row.Pack_Start (Sandbox_C, True, True, 0);
         Form.Pack_Start (Row, False, False, 0);
      end;

      declare
         Row : Gtk.Box.Gtk_Box;
         Label : Gtk.Label.Gtk_Label;
      begin
         Gtk.Box.Gtk_New_Hbox (Row, Homogeneous => False, Spacing => 8);
         Gtk.Label.Gtk_New (Label, "Maximum subagent recursion depth:");
         Row.Pack_Start (Label, False, False, 0);
         Gtk.Spin_Button.Gtk_New
           (Recursion_C, 0.0, Gdouble (Natural'Last), 1.0);
         Recursion_C.Set_Value
           (Gdouble (Settings_Value.Max_Recursion_Depth));
         Recursion_C.Set_Width_Chars (8);
         Row.Pack_Start (Recursion_C, False, False, 0);
         Form.Pack_Start (Row, False, False, 0);
      end;

      declare
         Row : Gtk.Box.Gtk_Box;
      begin
         Gtk.Box.Gtk_New_Hbox (Row, Homogeneous => False, Spacing => 8);
         Gtk.Check_Button.Gtk_New
           (Notification_C,
            "Desktop notifications when agent completes");
         Notification_C.Set_Active
           (Settings_Value.Completion_Notifications);
         Row.Pack_Start (Notification_C, True, True, 0);
         Form.Pack_Start (Row, False, False, 0);
      end;

      Content.Pack_Start (Form, True, True, 4);
      Dialog.Show_All;
      Model_C.Grab_Focus;
      Resp := Dialog.Run;
      if Resp = Gtk.Dialog.Gtk_Response_OK then
         declare
            Model          : constant String := Model_C.Get_Active_Text;
            Subagent_Model : constant String :=
              Subagent_Model_C.Get_Active_Text;
            Sand           : constant String := Sandbox_C.Get_Active_Text;
            Slash          : constant Natural := Ada.Strings.Fixed.Index
              (Model, "/");
            Subagent_Slash : constant Natural := Ada.Strings.Fixed.Index
              (Subagent_Model, "/");
            Provider       : Unbounded_String;
            Model_Id       : Unbounded_String;
            Subagent_Provider : Unbounded_String;
            Subagent_Id       : Unbounded_String;
         begin
            if Model'Length > 0 and then Slash > Model'First then
               Provider := To_Unbounded_String
                 (Model (Model'First .. Slash - 1));
               Model_Id := To_Unbounded_String
                 (Model (Slash + 1 .. Model'Last));
            end if;
            if Subagent_Slash > Subagent_Model'First then
               Subagent_Provider := To_Unbounded_String
                 (Subagent_Model
                    (Subagent_Model'First .. Subagent_Slash - 1));
               Subagent_Id := To_Unbounded_String
                 (Subagent_Model
                    (Subagent_Slash + 1 .. Subagent_Model'Last));
            end if;
            Current_Frontend.PQ.Enqueue
              ((Kind => Set_Preferences,
                Preferences =>
                  (Provider          => Provider,
                   Model_Id          => Model_Id,
                   Thinking          => LLM.Providers.Thinking_Level'Val
                     (Thinking_Index),
                   Sandbox           => To_Unbounded_String
                     (if Sand = "None (no sandbox)" then "" else Sand),
                   Subagent_Provider        => Subagent_Provider,
                   Subagent_Model           => Subagent_Id,
                   Max_Recursion_Depth      => Natural
                     (Recursion_C.Get_Value),
                   Completion_Notifications => Notification_C.Get_Active)));
         end;
      end if;
      Dialog.Destroy;
   exception
      when others =>
         null;
   end On_Preferences_Activate;

   --  ── Markdown rendering toggle ─────────────────────────────────────────

   procedure On_Render_Markdown_Toggled
     (Self : access Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record'Class) is
   begin
      if Current_Frontend /= null then
         if Current_Frontend.Stack_Enabled then
            Current_Frontend.Stack.Set_Render_Markdown (Self.Get_Active);
         else
            Current_Frontend.Conv.Set_Render_Markdown (Self.Get_Active);
         end if;
      end if;
   end On_Render_Markdown_Toggled;

   procedure On_Auto_Scroll_Toggled
     (Self : access Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record'Class) is
   begin
      if Current_Frontend /= null then
         Current_Frontend.Auto_Scroll := Self.Get_Active;
      end if;
   end On_Auto_Scroll_Toggled;

   --  System font family and size, read from gtk-font-name at startup.
   System_Font_Family : Ada.Strings.Unbounded.Unbounded_String;
   System_Font_Size_Pt : Integer := 11;  --  fallback default
   System_Font_Init    : Boolean := False;

   --  Init_System_Font — read the system default proportional font
   --  family and point size once from Gtk.Settings.
   procedure Init_System_Font is
      Settings : constant Gtk.Settings.Gtk_Settings :=
        Gtk.Settings.Get_Default;
      Font_Str : constant String :=
        Glib.Properties.Get_Property
          (Settings,
           Gtk.Settings.Gtk_Font_Name_Property);
      FD : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String (Font_Str);
   begin
      System_Font_Family :=
        To_Unbounded_String (Pango.Font.Get_Family (FD));
      System_Font_Size_Pt :=
        Integer (Pango.Font.Get_Size (FD)) / Pango.Enums.Pango_Scale;
      Pango.Font.Free (FD);
      System_Font_Init := True;
   end Init_System_Font;

   --  Apply_Zoom — recompute the font size from Zoom_Level and push it to
   --  both the conversation and prompt text views.
   procedure Apply_Zoom (F : in out Instance) is
      use Pango.Font;
      use type Gtk.Text_View.Gtk_Text_View;
      use Ada.Strings.Unbounded;
      Base_Pt    : constant Integer :=
        (if System_Font_Init then System_Font_Size_Pt else 11);
      Base_Clamped : constant Integer :=
        Coyote_GUI.Zoom.Clamped_Base_Pt (Base_Pt);
      Family_Str : constant String :=
        (if System_Font_Init
         then To_String (System_Font_Family)
         else "sans");
      Clamped    : constant Integer :=
        Coyote_GUI.Zoom.Effective_Size_Pt (F.Zoom_Level, Base_Pt);
      Font_Str   : constant String :=
        Family_Str & " " & Integer'Image (Clamped)
          (2 .. Integer'Image (Clamped)'Last);
      FD : Pango_Font_Description := From_String (Font_Str);
   begin
      if F.Stack_Enabled then
         F.Stack.Set_Font (FD);
      else
         F.Conv.Set_Font
           (FD,
            Math_Scale => Long_Float (Clamped) / Long_Float (Base_Clamped));
      end if;
      if F.Prompt_View /= null then
         F.Prompt_View.Override_Font (FD);
         declare
            use Pango.Context;
            use Pango.Font_Metrics;
            Ctx     : constant Pango.Context.Pango_Context :=
              F.Prompt_View.Get_Pango_Context;
            Metrics : constant Pango.Font_Metrics.Pango_Font_Metrics :=
              Ctx.Get_Metrics (FD, Pango.Language.Null_Pango_Language);
            Line_H  : constant Gint := Metrics.Get_Height;
            --  Fall back to ascent + descent if height is 0.
            H       : constant Gint :=
              (if Line_H > 0 then Line_H
               else Metrics.Get_Ascent + Metrics.Get_Descent);
            One_Line : constant Gint :=
              (if H > 0 then H / Pango.Enums.Pango_Scale else 18);
         begin
            F.Prompt_View.Set_Size_Request
              (-1, One_Line);
            Metrics.Unref;
         end;
      end if;
      Free (FD);
   end Apply_Zoom;

   --  Current system-font baseline used by the zoom menu handlers and the
   --  Ctrl+wheel handler.
   function Current_Base_Pt return Integer is
   begin
      return (if System_Font_Init then System_Font_Size_Pt else 11);
   end Current_Base_Pt;

   procedure On_Zoom_In_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      Changed : Boolean;
   begin
      if Current_Frontend /= null then
         Coyote_GUI.Zoom.Step_Zoom
           (Current_Frontend.Zoom_Level, 1, Current_Base_Pt, Changed);
         if Changed then
            Apply_Zoom (Current_Frontend.all);
         end if;
      end if;
   end On_Zoom_In_Activate;

   procedure On_Zoom_Out_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
      Changed : Boolean;
   begin
      if Current_Frontend /= null then
         Coyote_GUI.Zoom.Step_Zoom
           (Current_Frontend.Zoom_Level, -1, Current_Base_Pt, Changed);
         if Changed then
            Apply_Zoom (Current_Frontend.all);
         end if;
      end if;
   end On_Zoom_Out_Activate;

   procedure On_Zoom_Reset_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null
        and then Current_Frontend.Zoom_Level /= 0
      then
         Current_Frontend.Zoom_Level := 0;
         Apply_Zoom (Current_Frontend.all);
      end if;
   end On_Zoom_Reset_Activate;

   --  Ctrl+mouse-wheel zoom.  Connected on the conversation layout; plain
   --  wheel events return False so the scrolled window scrolls normally.
   --  Smooth-scroll (touchpad) deltas are accumulated until they add up
   --  to at least one wheel notch.
   function On_Conv_Scroll
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Scroll) return Boolean
   is
      pragma Unreferenced (Self);
      use type Gdk.Event.Gdk_Scroll_Direction;

      Notch : constant Gdouble := 1.0;
      Changed : Boolean;
      Steps   : Integer := 0;
   begin
      if Current_Frontend = null
        or else (Event.State and Gdk.Types.Control_Mask) = 0
      then
         return False;
      end if;

      case Event.Direction is
         when Gdk.Event.Scroll_Up =>
            Steps := 1;
         when Gdk.Event.Scroll_Down =>
            Steps := -1;
         when Gdk.Event.Scroll_Smooth =>
            Current_Frontend.Smooth_Zoom_Accumulator :=
              Current_Frontend.Smooth_Zoom_Accumulator - Event.Delta_Y;
            if Current_Frontend.Smooth_Zoom_Accumulator >= Notch then
               Steps := Integer
                 (Gdouble'Floor
                    (Current_Frontend.Smooth_Zoom_Accumulator));
               Current_Frontend.Smooth_Zoom_Accumulator :=
                 Current_Frontend.Smooth_Zoom_Accumulator
                 - Gdouble (Steps) * Notch;
            elsif Current_Frontend.Smooth_Zoom_Accumulator <= -Notch then
               Steps := Integer
                 (Gdouble'Ceiling
                    (Current_Frontend.Smooth_Zoom_Accumulator));
               Current_Frontend.Smooth_Zoom_Accumulator :=
                 Current_Frontend.Smooth_Zoom_Accumulator
                 - Gdouble (Steps) * Notch;
            end if;
         when others =>
            null;
      end case;

      if Steps = 0 then
         --  Swallow the event so Ctrl+wheel never scrolls the view.
         return True;
      end if;

      Coyote_GUI.Zoom.Step_Zoom
        (Current_Frontend.Zoom_Level, Steps, Current_Base_Pt, Changed);
      if Changed then
         Apply_Zoom (Current_Frontend.all);
      end if;
      return True;
   end On_Conv_Scroll;

   function On_Window_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
      use type Gdk.Types.Gdk_Key_Type;
   begin
      if Current_Frontend = null then
         return False;
      end if;

      if Event.Keyval = Gdk.Types.Keysyms.GDK_Escape
        and then Current_Frontend.Help_Mode
      then
         Reset_Click_For_Help (Current_Frontend.all);
         return True;
      end if;

      return False;
   end On_Window_Key_Press;


   --  ── Menu construction helper ──────────────────────────────────────────

   function Make_Item
     (Label : String;
      Menu  : Gtk.Menu.Gtk_Menu)
      return Gtk.Menu_Item.Gtk_Menu_Item
   is
      Item : Gtk.Menu_Item.Gtk_Menu_Item;
   begin
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Item, Label);
      Item.Set_Name ("coyote-help-menu");
      Item.On_Button_Press_Event (On_Help_Event'Access);
      Gtk.Menu_Shell.Append (Gtk.Menu_Shell.Gtk_Menu_Shell (Menu), Item);
      return Item;
   end Make_Item;

   procedure Add_Sep (Menu : Gtk.Menu.Gtk_Menu) is
      Sep : Gtk.Separator_Menu_Item.Gtk_Separator_Menu_Item;
   begin
      Gtk.Separator_Menu_Item.Gtk_New (Sep);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Menu), Sep);
   end Add_Sep;

   --  ── Create ────────────────────────────────────────────────────────────

   procedure Create
     (F                          : in out Instance;
      Win_Name                   : String;
      Pop_Under                  : Boolean := False;
      Notifications_Allowed      : Boolean := True;
      Notifications_Enabled      : Boolean := True)
   is
      use Gtk.Box;
      use Gtk.Button;
      use Gtk.Enums;
      use Gtk.Frame;
      use Gtk.Label;
      use Gtk.Menu;
      use Gtk.Menu_Bar;
      use Gtk.Menu_Item;
      use Gtk.Scrolled_Window;
      use Gtk.Text_Buffer;
      use Gtk.Text_View;
      use Gtk.Window;

      Prompt_Box : Gtk.Box.Gtk_Box;
      Bottom_Box : Gtk.Box.Gtk_Box;

      --  File menu
      File_Menu : Gtk_Menu;
      File_Item : Gtk_Menu_Item;
      New_Win_Item    : Gtk_Menu_Item;
      New_Sess_Item   : Gtk_Menu_Item;
      Open_Sess_Item  : Gtk_Menu_Item;
      Quit_Item      : Gtk_Menu_Item;
      Item           : Gtk_Menu_Item;
      Send_Item       : Gtk_Menu_Item;
      Clear_Item      : Gtk_Menu_Item;

      --  Edit menu
      Edit_Menu : Gtk_Menu;
      Edit_Item : Gtk_Menu_Item;

      --  Agent menu
      Agent_Menu : Gtk_Menu;
      Change_Model_Item : Gtk_Menu_Item;
      Compact_Item     : Gtk_Menu_Item;
      Agent_Item       : Gtk_Menu_Item;

      --  Options menu
      Options_Menu      : Gtk_Menu;
      Options_Item      : Gtk_Menu_Item;
      Preferences_Item  : Gtk_Menu_Item;

      --  Help menu
      Help_Menu         : Gtk_Menu;
      Help_Item         : Gtk_Menu_Item;

   begin
      Init_System_Font;
      F.Win_Name := To_Unbounded_String (Win_Name);
      F.Notifications_Allowed := Notifications_Allowed;
      F.Notifications_Enabled :=
        Notifications_Allowed and then Notifications_Enabled;
      F.Stack_Enabled :=
        Ada.Environment_Variables.Value ("COYOTE_NATIVE_STACK", "") = "1";
      Current_Frontend := F'Unchecked_Access;

      --  Top-level window
      Gtk.Window.Gtk_New (F.Win, Window_Toplevel);
      F.Win.Set_Title (Win_Name);
      F.Win.Set_Default_Size (900, 700);
      F.Win.Set_Icon_Name ("coyote");
      F.Win.Set_Role ("coyote-main");
      F.Win.On_Delete_Event (On_Window_Delete'Access);
      Coyote_GUI.Session_Stats_Window.Create
        (F.Stats_Window, F.Win.all'Access);
      F.Win.On_Key_Press_Event (On_Window_Key_Press'Access);
      F.Win.On_Button_Press_Event (On_Help_Event'Access);

      --  Accel group for menu keyboard shortcuts.
      Gtk.Accel_Group.Gtk_New (F.Accel_Group);
      F.Win.Add_Accel_Group (F.Accel_Group);

      --  Outer vertical box
      Gtk.Box.Gtk_New_Vbox (F.Outer_Box, Homogeneous => False, Spacing => 0);
      F.Win.Add (F.Outer_Box);

      --  ── Menu bar ──────────────────────────────────────────────────────

      Gtk.Menu_Bar.Gtk_New (F.Menu_Bar);
      F.Menu_Bar.Set_Name ("coyote-help-menu");
      F.Menu_Bar.On_Button_Press_Event (On_Help_Event'Access);
      F.Outer_Box.Pack_Start (F.Menu_Bar, Expand => False, Fill => False,
                              Padding => 0);

      --  File menu
      Gtk.Menu.Gtk_New (File_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (File_Item, "_File");
      File_Item.Set_Name ("coyote-help-menu");
      File_Item.On_Button_Press_Event (On_Help_Event'Access);
      File_Item.Set_Submenu (File_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), File_Item);

      New_Win_Item := Make_Item ("_New Window", File_Menu);
      New_Win_Item.On_Activate (On_New_Activate'Access);
      New_Win_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_n,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      New_Sess_Item := Make_Item ("New _Session", File_Menu);
      New_Sess_Item.On_Activate (On_New_Session_Activate'Access);
      New_Sess_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_n,
         Gdk.Types.Control_Mask
         or Gdk.Types.Shift_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Open_Sess_Item := Make_Item ("_Open Session...", File_Menu);
      Open_Sess_Item.On_Activate (On_Open_Session_Activate'Access);
      Open_Sess_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_o,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Add_Sep (File_Menu);
      Quit_Item := Make_Item ("E_xit", File_Menu);
      Quit_Item.On_Activate (On_Quit_Activate'Access);
      Quit_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_q,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);

      --  Edit menu
      Gtk.Menu.Gtk_New (Edit_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Edit_Item, "_Edit");
      Edit_Item.Set_Name ("coyote-help-menu");
      Edit_Item.On_Button_Press_Event (On_Help_Event'Access);
      Edit_Item.Set_Submenu (Edit_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), Edit_Item);
      Edit_Menu.On_Show (On_Edit_Menu_Show'Access);
      F.Cut_Item := Make_Item ("Cu_t", Edit_Menu);
      F.Cut_Item.On_Activate (On_Cut_Activate'Access);
      F.Cut_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_x,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      F.Copy_Item := Make_Item ("_Copy", Edit_Menu);
      F.Copy_Item.On_Activate (On_Copy_Activate'Access);
      F.Copy_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_c,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      F.Paste_Item := Make_Item ("_Paste", Edit_Menu);
      F.Paste_Item.On_Activate (On_Paste_Activate'Access);
      F.Paste_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_v,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Add_Sep (Edit_Menu);
      F.Select_All_Item := Make_Item ("Select _All", Edit_Menu);
      F.Select_All_Item.On_Activate (On_Select_All_Activate'Access);
      F.Select_All_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_a,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      F.Deselect_Item := Make_Item ("D_eselect All", Edit_Menu);
      F.Deselect_Item.On_Activate (On_Deselect_Activate'Access);

      --  Options menu
      Gtk.Menu.Gtk_New (Options_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Options_Item, "_Options");
      Options_Item.Set_Name ("coyote-help-menu");
      Options_Item.On_Button_Press_Event (On_Help_Event'Access);
      Options_Item.Set_Submenu (Options_Menu);
      Preferences_Item := Make_Item ("_Preferences...", Options_Menu);
      Preferences_Item.On_Activate
        (On_Preferences_Activate'Access);
      Preferences_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_comma,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);

      --  Agent menu
      Gtk.Menu.Gtk_New (Agent_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Agent_Item, "_Agent");
      Agent_Item.Set_Name ("coyote-help-menu");
      Agent_Item.On_Button_Press_Event (On_Help_Event'Access);
      Agent_Item.Set_Submenu (Agent_Menu);
      Send_Item := Make_Item ("_Send", Agent_Menu);
      Send_Item.On_Activate (On_Send_Menu_Activate'Access);
      Send_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_Return,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Clear_Item := Make_Item ("C_lear Conversation", Agent_Menu);
      Clear_Item.On_Activate (On_Clear_Activate'Access);
      Clear_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_l,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      F.Stop_Item := Make_Item ("St_op", Agent_Menu);
      F.Stop_Item.On_Activate (On_Stop_Activate'Access);
      F.Stop_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_Escape,
         0,
         Gtk.Accel_Group.Accel_Visible);
      F.Pause_Item := Make_Item ("_Pause", Agent_Menu);
      F.Pause_Item.On_Activate (On_Pause_Activate'Access);
      F.Pause_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_p,
         Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask,
         Gtk.Accel_Group.Accel_Visible);
      F.Resume_Item := Make_Item ("_Resume", Agent_Menu);
      F.Resume_Item.On_Activate (On_Resume_Activate'Access);
      F.Resume_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_r,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Add_Sep (Agent_Menu);
      Change_Model_Item := Make_Item ("_Models...", Agent_Menu);
      Change_Model_Item.On_Activate (On_Change_Model_Activate'Access);
      Change_Model_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_m,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      declare
         Thinking_Menu : Gtk.Menu.Gtk_Menu;
         Thinking_Head : Gtk.Menu_Item.Gtk_Menu_Item;
      begin
         Gtk.Menu.Gtk_New (Thinking_Menu);
         Gtk.Menu_Item.Gtk_New_With_Mnemonic
           (Thinking_Head, "_Thinking Level");
         Thinking_Head.Set_Submenu (Thinking_Menu);
         Gtk.Menu_Shell.Append
           (Gtk.Menu_Shell.Gtk_Menu_Shell (Agent_Menu), Thinking_Head);
         Item := Make_Item ("_Off",     Thinking_Menu);
         Item.On_Activate (On_Thinking_Off_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_1,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Item := Make_Item ("_Minimal", Thinking_Menu);
         Item.On_Activate (On_Thinking_Minimal_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_2,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Item := Make_Item ("_Low",     Thinking_Menu);
         Item.On_Activate (On_Thinking_Low_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_3,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Item := Make_Item ("Medi_um",  Thinking_Menu);
         Item.On_Activate (On_Thinking_Medium_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_4,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Item := Make_Item ("_High",    Thinking_Menu);
         Item.On_Activate (On_Thinking_High_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_5,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Item := Make_Item ("_X-High",  Thinking_Menu);
         Item.On_Activate (On_Thinking_X_High_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_6,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
      end;
      Item := Make_Item ("Sand_box Profile...", Agent_Menu);
      Item.On_Activate (On_Sandbox_Profile_Activate'Access);
      Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_s,
         Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Add_Sep (Agent_Menu);
      Compact_Item := Make_Item ("_Compact Context", Agent_Menu);
      Compact_Item.On_Activate (On_Compact_Activate'Access);
      declare
         use type Gdk.Types.Gdk_Modifier_Type;
         Mods : constant Gdk.Types.Gdk_Modifier_Type :=
           Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask;
      begin
         Compact_Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_LC_c,
            Mods,
            Gtk.Accel_Group.Accel_Visible);
      end;
      Add_Sep (Agent_Menu);
      Item := Make_Item ("Session Sta_ts", Agent_Menu);
      Item.On_Activate (On_Stats_Activate'Access);
      Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_i,
         Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Add_Sep (Agent_Menu);
      Item := Make_Item ("Set _Defaults", Agent_Menu);
      Item.On_Activate (On_Set_Default_Activate'Access);
      Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_d,
         Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask,
         Gtk.Accel_Group.Accel_Visible);
      --  ── View menu ─────────────────────────────────────────────────────
      declare
         View_Menu : Gtk.Menu.Gtk_Menu;
         View_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      begin
         Gtk.Menu.Gtk_New (View_Menu);
         Gtk.Menu_Item.Gtk_New_With_Mnemonic (View_Item, "_View");
         View_Item.Set_Name ("coyote-help-menu");
         View_Item.On_Button_Press_Event (On_Help_Event'Access);
         View_Item.Set_Submenu (View_Menu);
         Gtk.Menu_Shell.Append
           (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), View_Item);
         Gtk.Check_Menu_Item.Gtk_New_With_Mnemonic
           (F.Render_Markdown_Item, "_Render Markdown");
         F.Render_Markdown_Item.Set_Active (True);
         F.Render_Markdown_Item.On_Toggled
           (On_Render_Markdown_Toggled'Access);
         F.Render_Markdown_Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_LC_m,
            Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Gtk.Menu_Shell.Append
           (Gtk.Menu_Shell.Gtk_Menu_Shell (View_Menu),
            F.Render_Markdown_Item);
         Gtk.Check_Menu_Item.Gtk_New_With_Mnemonic
           (F.Auto_Scroll_Item, "_Auto-scroll");
         F.Auto_Scroll_Item.Set_Active (True);
         F.Auto_Scroll_Item.On_Toggled
           (On_Auto_Scroll_Toggled'Access);
         F.Auto_Scroll_Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_LC_a,
            Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Gtk.Menu_Shell.Append
           (Gtk.Menu_Shell.Gtk_Menu_Shell (View_Menu),
            F.Auto_Scroll_Item);
         Add_Sep (View_Menu);
         Item := Make_Item ("Zoom _In",    View_Menu);
         Item.On_Activate (On_Zoom_In_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_plus,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Item := Make_Item ("Zoom _Out",   View_Menu);
         Item.On_Activate (On_Zoom_Out_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_minus,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Item := Make_Item ("Reset _Zoom", View_Menu);
         Item.On_Activate (On_Zoom_Reset_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_0,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
      end;

      --  Attach custom menus after View so the top-level order is
      --  File, Edit, View, Agent, Options, Help.
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), Agent_Item);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), Options_Item);

      Gtk.Menu.Gtk_New (Help_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Help_Item, "_Help");
      Help_Item.Set_Name ("coyote-help-menu");
      Help_Item.On_Button_Press_Event (On_Help_Event'Access);
      Help_Item.Set_Submenu (Help_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), Help_Item);

      Item := Make_Item ("_Click for Help", Help_Menu);
      Item.On_Activate (On_Click_For_Help_Activate'Access);
      Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_F1,
         Gdk.Types.Shift_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Item := Make_Item ("_Overview", Help_Menu);
      Item.On_Activate (On_Overview_Activate'Access);
      Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_F1,
         0,
         Gtk.Accel_Group.Accel_Visible);
      Gtk.Menu_Item.Gtk_New (Item, "Send a Prompt");
      Item.Set_Name ("coyote-help-menu");
      Item.On_Button_Press_Event (On_Help_Event'Access);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Help_Menu), Item);
      Item.On_Activate (On_Send_Help_Activate'Access);
      Gtk.Menu_Item.Gtk_New (Item, "Manage Sessions");
      Item.Set_Name ("coyote-help-menu");
      Item.On_Button_Press_Event (On_Help_Event'Access);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Help_Menu), Item);
      Item.On_Activate (On_Session_Help_Activate'Access);
      Gtk.Menu_Item.Gtk_New (Item, "Agent Controls");
      Item.Set_Name ("coyote-help-menu");
      Item.On_Button_Press_Event (On_Help_Event'Access);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Help_Menu), Item);
      Item.On_Activate (On_Controls_Help_Activate'Access);
      Item := Make_Item ("_Index", Help_Menu);
      Item.On_Activate (On_Index_Activate'Access);
      Item := Make_Item ("_Keys & Shortcuts", Help_Menu);
      Item.On_Activate (On_Keys_Activate'Access);
      Item := Make_Item ("_Product Information", Help_Menu);
      Item.On_Activate (On_Product_Information_Activate'Access);

      --  ── Conversation view ─────────────────────────────────────────────

      --  The native stack is constructed now but remains disabled until its
      --  display-backed qualification gates pass.  The legacy renderer below
      --  remains the active baseline and fallback.
      Coyote_GUI.Conversation_Stack.Create
        (F.Stack, F.Win.all'Access);
      Coyote_GUI.Conversation_Stack.Set_Fork_Handler
        (F.Stack, On_Native_Fork'Access);

      Gtk.Scrolled_Window.Gtk_New (F.Conv_Scroll);
      F.Conv_Scroll.Set_Policy (Policy_Never, Policy_Automatic);
      declare
         Adj : constant Gtk.Adjustment.Gtk_Adjustment :=
           F.Conv_Scroll.Get_Vadjustment;
      begin
         Adj.On_Changed (On_Conv_Adj_Changed'Access);
      end;

      Gtk.Layout.Gtk_New (F.Conv_Layout);

      F.Conv.Attach (F.Conv_Scroll, F.Conv_Layout);

      --  Connect the frontend's tool/action click handler to the layout.
      --  The Conversation's own button-press handler (for selection) returns
      --  False, so both handlers fire.
      F.Conv_Layout.On_Button_Press_Event
        (On_Conv_Button_Press'Access);
      F.Conv_Layout.On_Key_Press_Event
        (On_Conv_Key_Press'Access);

      --  Ctrl+wheel zoom; plain wheel scroll falls through to the
      --  scrolled window's adjustments.
      F.Conv_Layout.On_Scroll_Event
        (On_Conv_Scroll'Access);

      F.Conv_Scroll.Add (F.Conv_Layout);
      if F.Stack_Enabled then
         F.Outer_Box.Pack_Start
           (F.Stack.Widget, Expand => True, Fill => True, Padding => 0);
      else
         F.Outer_Box.Pack_Start
           (F.Conv_Scroll, Expand => True, Fill => True, Padding => 0);
      end if;

      --  Native transcript for keyboard selection and assistive technology.
      Gtk.Expander.Gtk_New (F.Transcript_Expander, "Accessible transcript");
      Gtk.Text_View.Gtk_New (F.Transcript_View);
      F.Transcript_View.Set_Name ("coyote-help-transcript");
      F.Transcript_View.On_Button_Press_Event (On_Help_Event'Access);
      F.Transcript_View.Set_Editable (False);
      F.Transcript_View.Set_Wrap_Mode (Wrap_Word_Char);
      F.Transcript_View.Set_Cursor_Visible (False);
      F.Transcript_View.Set_Tooltip_Text
        ("Read-only plain-text conversation transcript");
      F.Transcript_Buf := F.Transcript_View.Get_Buffer;
      F.Transcript_Expander.Add (F.Transcript_View);
      F.Transcript_Expander.Set_Expanded (False);
      F.Outer_Box.Pack_Start
        (F.Transcript_Expander, Expand => False, Fill => True, Padding => 2);

      --  ── Prompt area ───────────────────────────────────────────────────

      Gtk.Box.Gtk_New_Vbox (Prompt_Box, Homogeneous => False, Spacing => 2);

      Gtk.Text_View.Gtk_New (F.Prompt_View);
      F.Prompt_View.Set_Name ("coyote-help-prompt");
      F.Prompt_View.On_Button_Press_Event (On_Help_Event'Access);
      F.Prompt_View.Set_Wrap_Mode (Wrap_Word_Char);
      F.Prompt_View.Set_Left_Margin (4);
      F.Prompt_View.Set_Right_Margin (4);
      F.Prompt_View.Set_Pixels_Above_Lines (2);
      F.Prompt_View.Set_Pixels_Below_Lines (2);
      F.Prompt_View.On_Key_Press_Event (On_Prompt_Key_Press'Access);
      F.Prompt_View.On_Button_Press_Event
        (On_Prompt_Button_Press'Access);
      Apply_Zoom (F);

      F.Prompt_Buf := F.Prompt_View.Get_Buffer;

      Gtk.Box.Gtk_New_Hbox (Bottom_Box, Homogeneous => False, Spacing => 4);
      Bottom_Box.Set_Name ("coyote-help-controls");
      Bottom_Box.Pack_Start (F.Prompt_View, Expand => True, Fill => True,
                             Padding => 2);

      Gtk.Button.Gtk_New_From_Icon_Name
         (F.Send_Btn, "mail-send", Gtk.Enums.Icon_Size_Button);
      F.Send_Btn.Set_Name ("coyote-help-controls");
      F.Send_Btn.On_Button_Press_Event (On_Help_Event'Access);
      F.Send_Btn.Set_Label ("Send");
      F.Send_Btn.Set_Always_Show_Image (True);
      F.Send_Btn.On_Clicked (On_Send_Clicked'Access);
      F.Send_Btn.Set_Tooltip_Text
        ("Send prompt (Enter; Shift+Enter for new line)");
      Bottom_Box.Pack_Start (F.Send_Btn, Expand => False, Fill => False,
                             Padding => 2);

      Gtk.Button.Gtk_New_From_Icon_Name
         (F.Stop_Btn, "process-stop", Gtk.Enums.Icon_Size_Button);
      F.Stop_Btn.Set_Name ("coyote-help-controls");
      F.Stop_Btn.On_Button_Press_Event (On_Help_Event'Access);
      F.Stop_Btn.Set_Label ("Stop");
      F.Stop_Btn.Set_Always_Show_Image (True);
      F.Stop_Btn.On_Clicked (On_Stop_Btn_Clicked'Access);
      F.Stop_Btn.Set_Tooltip_Text ("Stop agent (Agent > Stop)");
      Apply_Agent_Menu_Sensitivity (F);
      Bottom_Box.Pack_Start (F.Stop_Btn, Expand => False, Fill => False,
                             Padding => 2);

      Prompt_Box.Pack_Start (Bottom_Box, Expand => True, Fill => True,
                             Padding => 0);
      F.Outer_Box.Pack_Start (Prompt_Box, Expand => False, Fill => False,
                              Padding => 2);

      --  ── Status bar ────────────────────────────────────────────────────

      Gtk.Label.Gtk_New (F.Status_Bar, "");
      F.Status_Bar.Set_Name ("coyote-help-status");
      F.Status_Bar.Set_Events (Gdk.Event.Button_Press_Mask);
      F.Status_Bar.On_Button_Press_Event (On_Help_Event'Access);
      F.Status_Bar.Set_Xalign (0.0);

      declare
         use Ada.Strings.Unbounded;
         Status_Font_Str : constant String :=
           (if System_Font_Init
            then To_String (System_Font_Family)
            else "sans")
           & " "
           & Integer'Image (System_Font_Size_Pt)
               (2 .. Integer'Image (System_Font_Size_Pt)'Last);
         Font_Desc : Pango.Font.Pango_Font_Description :=
           Pango.Font.From_String (Status_Font_Str);
      begin
         F.Status_Bar.Modify_Font (Font_Desc);
         Pango.Font.Free (Font_Desc);
      end;

      F.Outer_Box.Pack_Start (F.Status_Bar, Expand => False, Fill => False,
                              Padding => 2);

      --  ── Show and register idle drain ──────────────────────────────────

      F.Win.Set_Focus_On_Map (not Pop_Under);
      F.Win.Show_All;
      if not Pop_Under then
         F.Prompt_View.Grab_Focus;
      end if;

   end Create;

   --  ── Frontend.Instance overrides ───────────────────────────────────────

   overriding
   procedure Set_Status (F : in out Instance; Text : in String) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Set_Status;
      U.Text := To_Unbounded_String (Text);
      Enqueue_Update (F, U);
   end Set_Status;

   procedure Set_Mode (F : in out Instance; Mode : in Run_Mode) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Set_Mode;
      U.Mode := Coyote_GUI.Run_Mode'Val (Run_Mode'Pos (Mode));
      Enqueue_Update (F, U);
   end Set_Mode;

   overriding
   procedure Begin_Request
     (F    : in out Instance;
      Text : in     String;
      Kind : in     Coyote_App.Frontend.Request_Kind :=
        Coyote_App.Frontend.Prompt)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Begin_Request;
      U.Text := To_Unbounded_String (Text);
      U.R_Kind := Coyote_GUI.Request_Kind'Val
        (Coyote_App.Frontend.Request_Kind'Pos (Kind));
      Enqueue_Update (F, U);
   end Begin_Request;

   overriding
   procedure Append_Text (F : in out Instance; Text : in String) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Append_Text;
      U.Text := To_Unbounded_String (Text);
      Enqueue_Update (F, U);
   end Append_Text;

   overriding
   procedure End_Text_Block (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.End_Text_Block;
      Enqueue_Update (F, U);
   end End_Text_Block;

   overriding
   procedure Begin_Thinking (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Begin_Thinking;
      Enqueue_Update (F, U);
   end Begin_Thinking;

   overriding
   procedure Append_Thinking (F : in out Instance; Text : in String) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Append_Thinking;
      U.Text := To_Unbounded_String (Text);
      Enqueue_Update (F, U);
   end Append_Thinking;

   overriding
   procedure End_Thinking (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.End_Thinking;
      Enqueue_Update (F, U);
   end End_Thinking;

   overriding
   procedure Begin_Tool
     (F               : in out Instance;
      Name            : in     String;
      Args_Json       : in     String;
      Session_Id      : in     String;
      Tool_Id          : in     String;
      Model           : in     String := "";
      Source_Directory : in     String := "";
      Session_Start   : in     String := "";
      Turn_Index      : in     Positive := 1;
      Call_In_Turn    : in     Positive := 1)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind  := Coyote_GUI.Begin_Tool;
      U.Text  := To_Unbounded_String (Name);
      U.Text2 := To_Unbounded_String (Args_Json);
      U.Text3 := To_Unbounded_String (Session_Id);
      U.Text4 := To_Unbounded_String (Tool_Id);
      U.Text5 := To_Unbounded_String (Model);
      U.Text6 := To_Unbounded_String (Source_Directory);
      U.Text7 := To_Unbounded_String (Session_Start);
      U.Tool_Turn := Turn_Index;
      U.Tool_Call := Call_In_Turn;
      Enqueue_Update (F, U);
   end Begin_Tool;
   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Tool_End_Status;
      Result_Text : in     String := "";
      Media_Type  : in     String := "")
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind     := Coyote_GUI.End_Tool;
      U.Text     := To_Unbounded_String (Tool_Id);
      U.Text2    := To_Unbounded_String (Result_Text);
      U.Text3    := To_Unbounded_String (Media_Type);
      U.T_Status :=
        Coyote_GUI.Tool_End_Status'Val (Tool_End_Status'Pos (Status));
      Enqueue_Update (F, U);
   end End_Tool;

   overriding
   procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    : in     String;
      Kind    : in     Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary : in     String := "")
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Append_Turn_Footer;
      U.Text := To_Unbounded_String (Text);
      U.Text2 := To_Unbounded_String (Summary);
      U.F_Kind := Coyote_GUI.Footer_Kind'Val
        (Coyote_App.Frontend.Footer_Kind'Pos (Kind));
      Enqueue_Update (F, U);
   end Append_Turn_Footer;

   overriding
   procedure Complete_Request
     (F      : in out Instance;
      Status : in     Coyote_App.Frontend.Completion_Status)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Complete_Request;
      U.C_Status := Coyote_GUI.Completion_Status'Val
        (Coyote_App.Frontend.Completion_Status'Pos (Status));
      Enqueue_Update (F, U);
   end Complete_Request;

   overriding
   procedure Append_Fork_Action
     (F       : in out Instance;
      PID     : in     String;
      UUID    : in     String;
      Turn_N  : in     Positive;
      Step_N  : in     Natural := 0)
   is
      U : Coyote_GUI.Update;
      pragma Unreferenced (PID);
   begin
      U.Kind  := Coyote_GUI.Append_Action_Strip;
      --  Label: "Fork @ turn N" or "Fork @ turn N/S"
      U.Text  := To_Unbounded_String
        ("  [Fork @ " & Natural_Image (Turn_N)
         & (if Step_N > 0 then "/" & Natural_Image (Step_N) else "")
         & "]");
      U.Text2 := To_Unbounded_String (UUID);
      U.Text3 := To_Unbounded_String (Natural_Image (Turn_N));
      U.Text4 := To_Unbounded_String (Natural_Image (Step_N));
      Enqueue_Update (F, U);
   end Append_Fork_Action;

   overriding
   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Notice_Kind;
      Text : in     String)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind   := Coyote_GUI.Append_Notice;
      U.Text   := To_Unbounded_String (Text);
      U.N_Kind :=
        Coyote_GUI.Notice_Kind'Val (Notice_Kind'Pos (Kind));
      Enqueue_Update (F, U);
   end Append_Notice;

   overriding
   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind  := Coyote_GUI.Show_Detail;
      U.Text  := To_Unbounded_String (Title);
      U.Text2 := To_Unbounded_String (Content);
      Enqueue_Update (F, U);
   end Show_Detail;

   function Read_Item (F : in out Instance)
     return Coyote_GUI.Prompt_Queue.Item
   is
      Result : Coyote_GUI.Prompt_Queue.Item;
   begin
      F.PQ.Dequeue (Result);
      return Result;
   end Read_Item;

   overriding
   function Read_Prompt (F : in out Instance) return String is
      It : constant Coyote_GUI.Prompt_Queue.Item := Read_Item (F);
   begin
      case It.Kind is
         when User_Prompt  =>
            return Ada.Strings.Unbounded.To_String (It.Text);
         when Shutdown_Item =>
            return "";
         when others =>
            --  Commands are not representable as plain strings;
            --  callers in the GUI path should use Read_Item instead.
            return "";
      end case;
   end Read_Prompt;

   overriding
   procedure Shutdown (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Shutdown;
      Enqueue_Update (F, U);
   end Shutdown;

   --  ── GUI-specific ──────────────────────────────────────────────────────

   procedure Set_Stats_Summary
     (F     : in out Instance;
      Stats : Coyote_GUI.Session_Stats_Record)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Set_Stats;
      U.Stats := Stats;
      Enqueue_Update (F, U);
   end Set_Stats_Summary;

   procedure Register_Session
     (F : in out Instance;
      S : access LLM.Agent.Session) is
   begin
      F.Agent_Sess.Set (S);
   end Register_Session;

   procedure Set_Session_Identity
     (F : in out Instance;
      Session_Id : String)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Set_Session_Identity;
      U.Text := To_Unbounded_String (Session_Id);
      Enqueue_Update (F, U);
   end Set_Session_Identity;

   procedure Clear_Stats (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Clear_Stats;
      Enqueue_Update (F, U);
   end Clear_Stats;

   procedure Clear_Conversation (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Clear_Conversation;
      Enqueue_Update (F, U);
   end Clear_Conversation;

   procedure Set_Debug_Logging (F : in out Instance; Enabled : Boolean) is
   begin
      F.Conv.Set_Debug_Logging (Enabled);
   end Set_Debug_Logging;

   procedure Set_Completion_Notifications
     (F : in out Instance; Enabled : Boolean)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Set_Completion_Notifications;
      U.Enabled := Enabled;
      Enqueue_Update (F, U);
   end Set_Completion_Notifications;

   procedure Notify_Completion (F : in out Instance) is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Completion_Notification;
      Enqueue_Update (F, U);
   end Notify_Completion;

end Coyote_App.Frontend.GUI;
