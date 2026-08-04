--  Coyote_App.Frontend.GUI body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
use type Gdk.Types.Gdk_Modifier_Type;
with Glib;                       use Glib;
with Glib.Main;
with Gtk.Adjustment;
with Glib.Properties;            use Glib.Properties;
with Gtk.Accel_Group;
with Gtk.Box;
with Gtk.Button;
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
with Glib.Values;
with Gtk.Cell_Renderer_Text;
with Gtk.Dialog;
with Gtk.List_Store;
with Gtk.Tree_Model;
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
with LLM.Model_Registry;
with LLM.Tools.Sandbox;

package body Coyote_App.Frontend.GUI is
   use Coyote_GUI.Prompt_Queue;
   use Coyote_App.Utils;

   --  ── Package-body state ────────────────────────────────────────────────

   --  Global access for signal callbacks (single window per process).
   Current_Frontend : access Instance := null;

   --  Prefix character used by menu-item handlers to pass commands through

   --  ── Show-detail secondary window ──────────────────────────────────────

   procedure Show_Text_Window (Title : String; Content : String) is
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
      Win.Set_Default_Size (700, 500);

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

      --  Try tool click first.
      declare
         Result : constant Coyote_GUI.Conversation.Tool_Click_Result :=
           Current_Frontend.Conv.Handle_Tool_Click
             (Glib.Gint (Event.X), Glib.Gint (Event.Y));
      begin
         if Result.Found then
            Show_Text_Window
              (To_String (Result.Title), To_String (Result.Content));
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

   --  ── Apply_Update — called on the GTK main thread by Drain_Idle ────────

   procedure Apply_Update (F : in out Instance; U : Coyote_GUI.Update) is
      use Coyote_GUI;
   begin
      case U.Kind is

         when Append_Text =>
            F.Conv.Append_Text (To_String (U.Text));

         when End_Text_Block =>
            F.Conv.End_Text_Block;

         when Begin_Thinking =>
            F.Conv.Begin_Thinking;

         when Append_Thinking =>
            F.Conv.Append_Thinking (To_String (U.Text));

         when End_Thinking =>
            F.Conv.End_Thinking;

         when Begin_Tool =>
            F.Conv.Begin_Tool
              (Name       => To_String (U.Text),
               Args       => To_String (U.Text2),
               Session_Id => To_String (U.Text3),
               Tool_Id    => To_String (U.Text4));

         when End_Tool =>
            F.Conv.End_Tool
              (Tool_Id => To_String (U.Text),
               Status  => Coyote_GUI.Conversation.Tool_End_Status'Val
                            (Coyote_GUI.Tool_End_Status'Pos (U.T_Status)),
               Result  => To_String (U.Text2));

         when Append_Notice =>
            F.Conv.Append_Notice
              (Kind => Coyote_GUI.Conversation.Line_Style'Val
                         (Coyote_GUI.Notice_Kind'Pos (U.N_Kind)
                          + Coyote_GUI.Conversation.Line_Style'Pos
                              (Coyote_GUI.Conversation.Notice_Info)),
               Text => To_String (U.Text));

         when Append_Turn_Footer =>
            F.Conv.Append_Turn_Footer (To_String (U.Text));

         when Append_Action_Strip =>
            declare
               use Coyote_GUI.Conversation;
               UUID_Str   : constant String := To_String (U.Text2);
               Turn_Str   : constant String := To_String (U.Text3);
               Step_Str   : constant String := To_String (U.Text4);
               Turn_Val   : Positive;
               Step_Val   : Natural := 0;
            begin
               if UUID_Str'Length > 0
                 and then Turn_Str'Length > 0
               then
                  Turn_Val := Positive'Value (Turn_Str);
                  if Step_Str'Length > 0 then
                     Step_Val := Natural'Value (Step_Str);
                  end if;
                  F.Conv.Append_Action_Strip
                    (To_String (U.Text),
                     (Kind        => Fork,
                      Fork_UUID   => U.Text2,
                      Fork_Turn_N => Turn_Val,
                      Fork_Step_N => Step_Val));
               end if;
            end;

         when Set_Status =>
            F.Status_Bar.Set_Text (To_String (U.Text));

         when Set_Mode =>
            declare
               Base  : constant String := To_String (F.Win_Name);
               Title : constant String :=
                 (case U.Mode is
                    when Coyote_GUI.Idle    => Base,
                    when Coyote_GUI.Running => Base & " -- running",
                    when Coyote_GUI.Armed   => Base & " -- armed",
                    when Coyote_GUI.Paused  => Base & " -- paused");
            begin
               F.Win.Set_Title (Title);
               F.Stop_Btn.Set_Sensitive (U.Mode /= Coyote_GUI.Idle);
            end;

         when Show_Detail =>
            Show_Text_Window (To_String (U.Text), To_String (U.Text2));

         when Shutdown =>
            F.PQ.Shutdown;
            Gtk.Main.Main_Quit;

      end case;
   end Apply_Update;

   --  ── GLib idle drain callback ──────────────────────────────────────────

   function Drain_Idle return Boolean is
      U   : Coyote_GUI.Update;
      Got : Boolean;
   begin
      if Current_Frontend = null then
         return False;
      end if;
      Current_Frontend.Updates.Dequeue (U, Got);
      if Got then
         Apply_Update (Current_Frontend.all, U);
      end if;
      --  Keep one source registered for the frontend lifetime.  Processing
      --  one item per invocation lets higher-priority GTK redraw sources run
      --  between updates without creating competing idle sources.
      return True;
   end Drain_Idle;

   --  ── Enqueue_Update — enqueue for the persistent idle drain ────────────

   procedure Enqueue_Update (F : in out Instance; U : Coyote_GUI.Update) is
   begin
      F.Updates.Enqueue (U);
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
      begin
         if Text'Length > 0 then
            Current_Frontend.PQ.Enqueue
              ((User_Prompt,
                Text => To_Unbounded_String (Text)));
            Current_Frontend.Prompt_Buf.Set_Text ("");
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
         if Current_Frontend.Agent_Sess /= null then
            LLM.Agent.Request_Abort (Current_Frontend.Agent_Sess.all);
         end if;
         Current_Frontend.PQ.Enqueue ((Kind => Stop));
      end if;
   end On_Stop_Activate;

   procedure On_Stop_Btn_Clicked
     (Self : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         if Current_Frontend.Agent_Sess /= null then
            LLM.Agent.Request_Abort (Current_Frontend.Agent_Sess.all);
         end if;
         Current_Frontend.PQ.Enqueue ((Kind => Stop));
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
         Show_Text_Window ("Session Stats",
                           To_String (Current_Frontend.Stats_Text));
      end if;
   end On_Stats_Activate;
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
      Dialog.Set_Title ("Open Session");
      Dialog.Set_Default_Size (660, 440);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      Btn := Dialog.Add_Button ("_Open",   Gtk_Response_OK);
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start (Scroll, Expand => True, Fill => True, Padding => 4);
      Dialog.Show_All;

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
      use Gtk.Tree_View;

      Models  : constant LLM.Model_Registry.Model_Info_Vectors.Vector :=
                  LLM.Model_Registry.Available_Models;
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

      --  Tree view: interactive typeahead search on the Name column.
      Gtk.Tree_View.Gtk_New (View, +Store);
      View.Set_Enable_Search (True);
      View.Set_Search_Column (1);
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
      Dialog.Set_Title ("Select Model");
      Dialog.Set_Default_Size (1000, 520);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      Btn := Dialog.Add_Button ("_Select", Gtk_Response_OK);
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start (Scroll, Expand => True, Fill => True, Padding => 4);
      Dialog.Show_All;

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
      Dialog.Set_Title ("Select Sandbox Profile");
      Dialog.Set_Default_Size (400, 300);
      Dialog.Set_Transient_For (Current_Frontend.Win);
      Btn := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      Btn := Dialog.Add_Button ("_Select", Gtk_Response_OK);
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start (Scroll, Expand => True, Fill => True, Padding => 4);
      Dialog.Show_All;

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

   --  ── Markdown rendering toggle ─────────────────────────────────────────

   procedure On_Render_Markdown_Toggled
     (Self : access Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record'Class) is
   begin
      if Current_Frontend /= null then
         Current_Frontend.Conv.Set_Render_Markdown (Self.Get_Active);
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

   --  Point-size increment per zoom step.
   Zoom_Step_Pt : constant := 1;

   --  Apply_Zoom — recompute the font size from Zoom_Level and push it to
   --  both the conversation and prompt text views.
   procedure Apply_Zoom (F : in out Instance) is
      use Pango.Font;
      use type Gtk.Text_View.Gtk_Text_View;
      use Ada.Strings.Unbounded;
      Base_Pt    : constant Integer :=
        (if System_Font_Init then System_Font_Size_Pt else 11);
      Family_Str : constant String :=
        (if System_Font_Init
         then To_String (System_Font_Family)
         else "sans");
      Size_Pt    : constant Integer :=
        Base_Pt + F.Zoom_Level * Zoom_Step_Pt;
      Clamped    : constant Integer :=
        (if Size_Pt < 6 then 6 elsif Size_Pt > 32 then 32 else Size_Pt);
      Font_Str   : constant String :=
        Family_Str & " " & Integer'Image (Clamped)
          (2 .. Integer'Image (Clamped)'Last);
      FD : Pango_Font_Description := From_String (Font_Str);
   begin
      F.Conv.Invalidate_Layout;
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

   procedure On_Zoom_In_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.Zoom_Level := Current_Frontend.Zoom_Level + 1;
         Apply_Zoom (Current_Frontend.all);
      end if;
   end On_Zoom_In_Activate;

   procedure On_Zoom_Out_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.Zoom_Level := Current_Frontend.Zoom_Level - 1;
         Apply_Zoom (Current_Frontend.all);
      end if;
   end On_Zoom_Out_Activate;

   procedure On_Zoom_Reset_Activate
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Frontend /= null then
         Current_Frontend.Zoom_Level := 0;
         Apply_Zoom (Current_Frontend.all);
      end if;
   end On_Zoom_Reset_Activate;

   function On_Window_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
   begin
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
     (F         : in out Instance;
      Win_Name  : String;
      Pop_Under : Boolean := False)
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

      --  Agent menu
      Agent_Menu : Gtk_Menu;
      Stop_Item        : Gtk_Menu_Item;
      Idle_Id          : Glib.Main.G_Source_Id;
      pragma Unreferenced (Idle_Id);
      Pause_Item       : Gtk_Menu_Item;
      Resume_Item      : Gtk_Menu_Item;
      Change_Model_Item : Gtk_Menu_Item;
      Compact_Item     : Gtk_Menu_Item;
      Agent_Item       : Gtk_Menu_Item;

   begin
      Init_System_Font;
      F.Win_Name := To_Unbounded_String (Win_Name);
      Current_Frontend := F'Unchecked_Access;

      --  Top-level window
      Gtk.Window.Gtk_New (F.Win, Window_Toplevel);
      F.Win.Set_Title (Win_Name);
      F.Win.Set_Default_Size (900, 700);
      F.Win.On_Delete_Event (On_Window_Delete'Access);
      F.Win.On_Key_Press_Event (On_Window_Key_Press'Access);

      --  Accel group for menu keyboard shortcuts.
      Gtk.Accel_Group.Gtk_New (F.Accel_Group);
      F.Win.Add_Accel_Group (F.Accel_Group);

      --  Outer vertical box
      Gtk.Box.Gtk_New_Vbox (F.Outer_Box, Homogeneous => False, Spacing => 0);
      F.Win.Add (F.Outer_Box);

      --  ── Menu bar ──────────────────────────────────────────────────────

      Gtk.Menu_Bar.Gtk_New (F.Menu_Bar);
      F.Outer_Box.Pack_Start (F.Menu_Bar, Expand => False, Fill => False,
                              Padding => 0);

      --  File menu
      Gtk.Menu.Gtk_New (File_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (File_Item, "_File");
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
      Open_Sess_Item := Make_Item ("Open _Session...", File_Menu);
      Open_Sess_Item.On_Activate (On_Open_Session_Activate'Access);
      Open_Sess_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_o,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Add_Sep (File_Menu);
      Quit_Item := Make_Item ("_Quit", File_Menu);
      Quit_Item.On_Activate (On_Quit_Activate'Access);
      Quit_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_q,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);

      --  Agent menu
      Gtk.Menu.Gtk_New (Agent_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Agent_Item, "_Agent");
      Agent_Item.Set_Submenu (Agent_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), Agent_Item);

      Stop_Item := Make_Item ("_Stop", Agent_Menu);
      Stop_Item.On_Activate (On_Stop_Activate'Access);
      Stop_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_Escape,
         0,
         Gtk.Accel_Group.Accel_Visible);
      Pause_Item := Make_Item ("_Pause", Agent_Menu);
      Pause_Item.On_Activate (On_Pause_Activate'Access);
      Pause_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_p,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Resume_Item := Make_Item ("_Resume", Agent_Menu);
      Resume_Item.On_Activate (On_Resume_Activate'Access);
      Resume_Item.Add_Accelerator
        ("activate", F.Accel_Group,
         Gdk.Types.Keysyms.GDK_LC_r,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      Add_Sep (Agent_Menu);
      Change_Model_Item := Make_Item ("Change _Model...", Agent_Menu);
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
         Item := Make_Item ("M_inimal", Thinking_Menu);
         Item.On_Activate (On_Thinking_Minimal_Activate'Access);
         Item := Make_Item ("_Low",     Thinking_Menu);
         Item.On_Activate (On_Thinking_Low_Activate'Access);
         Item := Make_Item ("M_edium",  Thinking_Menu);
         Item.On_Activate (On_Thinking_Medium_Activate'Access);
         Item := Make_Item ("_High",    Thinking_Menu);
         Item.On_Activate (On_Thinking_High_Activate'Access);
         Item := Make_Item ("_X-High",  Thinking_Menu);
         Item.On_Activate (On_Thinking_X_High_Activate'Access);
      end;
      Item := Make_Item ("_Sandbox Profile...", Agent_Menu);
      Item.On_Activate (On_Sandbox_Profile_Activate'Access);
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
      Item := Make_Item ("Session _Stats", Agent_Menu);
      Item.On_Activate (On_Stats_Activate'Access);
      Add_Sep (Agent_Menu);
      Item := Make_Item ("Set _Defaults", Agent_Menu);
      Item.On_Activate (On_Set_Default_Activate'Access);
      --  ── View menu ─────────────────────────────────────────────────────
      declare
         View_Menu : Gtk.Menu.Gtk_Menu;
         View_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      begin
         Gtk.Menu.Gtk_New (View_Menu);
         Gtk.Menu_Item.Gtk_New_With_Mnemonic (View_Item, "_View");
         View_Item.Set_Submenu (View_Menu);
         Gtk.Menu_Shell.Append
           (Gtk.Menu_Shell.Gtk_Menu_Shell (F.Menu_Bar), View_Item);
         Gtk.Check_Menu_Item.Gtk_New
           (F.Render_Markdown_Item, "Render Markdown");
         F.Render_Markdown_Item.Set_Active (True);
         F.Render_Markdown_Item.On_Toggled
           (On_Render_Markdown_Toggled'Access);
         Gtk.Menu_Shell.Append
           (Gtk.Menu_Shell.Gtk_Menu_Shell (View_Menu),
            F.Render_Markdown_Item);
         Gtk.Check_Menu_Item.Gtk_New
           (F.Auto_Scroll_Item, "Auto-scroll");
         F.Auto_Scroll_Item.Set_Active (True);
         F.Auto_Scroll_Item.On_Toggled
           (On_Auto_Scroll_Toggled'Access);
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
         Item := Make_Item ("_Reset Zoom", View_Menu);
         Item.On_Activate (On_Zoom_Reset_Activate'Access);
         Item.Add_Accelerator
           ("activate", F.Accel_Group,
            Gdk.Types.Keysyms.GDK_0,
            Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
      end;

      --  ── Conversation view ─────────────────────────────────────────────

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

      F.Conv_Scroll.Add (F.Conv_Layout);
      F.Outer_Box.Pack_Start (F.Conv_Scroll, Expand => True, Fill => True,
                              Padding => 0);
      --  ── Prompt area ───────────────────────────────────────────────────

      Gtk.Box.Gtk_New_Vbox (Prompt_Box, Homogeneous => False, Spacing => 2);

      Gtk.Text_View.Gtk_New (F.Prompt_View);
      F.Prompt_View.Set_Wrap_Mode (Wrap_Word_Char);
      F.Prompt_View.Set_Left_Margin (4);
      F.Prompt_View.Set_Right_Margin (4);
      F.Prompt_View.Set_Pixels_Above_Lines (2);
      F.Prompt_View.Set_Pixels_Below_Lines (2);
      F.Prompt_View.On_Key_Press_Event (On_Prompt_Key_Press'Access);
      Apply_Zoom (F);

      F.Prompt_Buf := F.Prompt_View.Get_Buffer;

      Gtk.Box.Gtk_New_Hbox (Bottom_Box, Homogeneous => False, Spacing => 4);
      Bottom_Box.Pack_Start (F.Prompt_View, Expand => True, Fill => True,
                             Padding => 2);

      Gtk.Button.Gtk_New_From_Icon_Name
         (F.Send_Btn, "mail-send", Gtk.Enums.Icon_Size_Button);
      F.Send_Btn.Set_Always_Show_Image (True);
      F.Send_Btn.On_Clicked (On_Send_Clicked'Access);
      F.Send_Btn.Set_Tooltip_Text
        ("Send prompt (Enter; Shift+Enter for new line)");
      Bottom_Box.Pack_Start (F.Send_Btn, Expand => False, Fill => False,
                             Padding => 2);

      Gtk.Button.Gtk_New_From_Icon_Name
         (F.Stop_Btn, "process-stop", Gtk.Enums.Icon_Size_Button);
      F.Stop_Btn.Set_Always_Show_Image (True);
      F.Stop_Btn.On_Clicked (On_Stop_Btn_Clicked'Access);
      F.Stop_Btn.Set_Tooltip_Text ("Stop agent (Agent > Stop)");
      F.Stop_Btn.Set_Sensitive (False);
      Bottom_Box.Pack_Start (F.Stop_Btn, Expand => False, Fill => False,
                             Padding => 2);

      Prompt_Box.Pack_Start (Bottom_Box, Expand => True, Fill => True,
                             Padding => 0);
      F.Outer_Box.Pack_Start (Prompt_Box, Expand => False, Fill => False,
                              Padding => 2);

      --  ── Status bar ────────────────────────────────────────────────────

      Gtk.Label.Gtk_New (F.Status_Bar, "");
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

      --  Register exactly one idle source for the frontend lifetime.  The
      --  callback processes one queued update per main-loop invocation.
      Idle_Id := Glib.Main.Idle_Add (Drain_Idle'Access);

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
     (F          : in out Instance;
      Name       : in     String;
      Args_Json  : in     String;
      Session_Id : in     String;
      Tool_Id    : in     String)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind  := Coyote_GUI.Begin_Tool;
      U.Text  := To_Unbounded_String (Name);
      U.Text2 := To_Unbounded_String (Args_Json);
      U.Text3 := To_Unbounded_String (Session_Id);
      U.Text4 := To_Unbounded_String (Tool_Id);
      Enqueue_Update (F, U);
   end Begin_Tool;

   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Tool_End_Status;
      Result_Text : in     String := "")
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind     := Coyote_GUI.End_Tool;
      U.Text     := To_Unbounded_String (Tool_Id);
      U.Text2    := To_Unbounded_String (Result_Text);
      U.T_Status :=
        Coyote_GUI.Tool_End_Status'Val (Tool_End_Status'Pos (Status));
      Enqueue_Update (F, U);
   end End_Tool;

   overriding
   procedure Append_Turn_Footer
     (F : in out Instance; Text : in String)
   is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Append_Turn_Footer;
      U.Text := To_Unbounded_String (Text);
      Enqueue_Update (F, U);
   end Append_Turn_Footer;

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

   procedure Set_Stats_Summary (F : in out Instance; Text : String) is
   begin
      F.Stats_Text := To_Unbounded_String (Text);
   end Set_Stats_Summary;


   procedure Register_Session
     (F : in out Instance;
      S : access LLM.Agent.Session) is
   begin
      F.Agent_Sess := S;
   end Register_Session;

   procedure Clear_Conversation (F : in out Instance) is
   begin
      F.Conv.Clear;
   end Clear_Conversation;

   procedure Set_Debug_Logging (F : in out Instance; Enabled : Boolean) is
   begin
      F.Conv.Set_Debug_Logging (Enabled);
   end Set_Debug_Logging;

   function Stats_Summary_Text (F : Instance) return String is
   begin
      return To_String (F.Stats_Text);
   end Stats_Summary_Text;

end Coyote_App.Frontend.GUI;
