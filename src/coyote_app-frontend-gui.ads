--  Coyote_App.Frontend.GUI — GTK3 graphical frontend.
--
--  Implements Coyote_App.Frontend.Instance by:
--
--    * Owning a GTK window (GtkWindow with menu, conversation view,
--      prompt input, and status bar).
--
--    * Routing each Frontend primitive to an Update value enqueued in the
--      protected Updates queue.  A GLib idle callback drains the queue on
--      the GTK main loop thread and applies changes to the GtkTextBuffer.
--
--    * Providing a Prompt_Queue for user input: the Send button and menu
--      item activations enqueue prompt strings and :command strings.
--      Agent_Task calls Read_Item (GUI-specific), which blocks on the queue.
--
--  Create must be called from the GTK main loop thread (the begin section
--  of Run_GUI) before Gtk.Main.Main is entered.  All other Frontend
--  primitives may be called from any task.
--
--  Project: coyote

with Ada.Strings.Unbounded;        use Ada.Strings.Unbounded;
with Glib;                          use Glib;
with LLM.Agent;
with Coyote_GUI.Conversation;
with Coyote_GUI.Conversation_Stack;
with Coyote_GUI.Prompt_Queue;
with Coyote_GUI.Session_Stats_Window;
with Coyote_GUI.Updates;
with Gtk.Accel_Group;
with Gtk.Box;
with Gtk.Button;
with Gtk.Check_Button;
with Gtk.Label;
with Gtk.Menu_Bar;
with Gtk.Menu_Item;
with Gtk.Check_Menu_Item;
with Gtk.Scrolled_Window;
with Gtk.Status_Bar;
with Gtk.Separator;
with Gtk.Layout;
with Gtk.Text_Buffer;
with Gtk.Text_View;
with Gtk.Window;

package Coyote_App.Frontend.GUI is

   type Instance is new Coyote_App.Frontend.Instance with private;

   --  Initialise the GTK window and register the idle drain callback.
   --  Must be called from the GTK main loop thread.
   procedure Create
     (F                          : in out Instance;
      Win_Name                   : String;
      Pop_Under                  : Boolean := False;
      Notifications_Allowed      : Boolean := True;
      Notifications_Enabled      : Boolean := True);

   --  ── Frontend.Instance overrides ───────────────────────────────────────

   overriding
   procedure Set_Status
     (F    : in out Instance;
      Text : in     String);

   overriding
   procedure Set_Mode
     (F    : in out Instance;
      Mode : in     Coyote_App.Frontend.Run_Mode);

   overriding
   procedure Begin_Request
     (F    : in out Instance;
      Text : in     String;
      Kind : in     Coyote_App.Frontend.Request_Kind :=
        Coyote_App.Frontend.Prompt);

   overriding
   procedure Append_Text
     (F    : in out Instance;
      Text : in     String);

   overriding procedure End_Text_Block (F : in out Instance);

   overriding procedure Begin_Thinking (F : in out Instance);

   overriding
   procedure Append_Thinking
     (F    : in out Instance;
      Text : in     String);

   overriding procedure End_Thinking (F : in out Instance);

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
      Call_In_Turn    : in     Positive := 1);
   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Coyote_App.Frontend.Tool_End_Status;
      Result_Text : in     String := "";
      Media_Type  : in     String := "");
   overriding
   procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    : in     String;
      Kind    : in     Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary : in     String := "");

   overriding
   procedure Complete_Request
     (F      : in out Instance;
      Status : in     Coyote_App.Frontend.Completion_Status);

   overriding
   procedure Append_Fork_Action
     (F       : in out Instance;
      PID     : in     String;
      UUID    : in     String;
      Turn_N  : in     Positive;
      Step_N  : in     Natural := 0);

   overriding
   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Coyote_App.Frontend.Notice_Kind;
      Text : in     String);

   overriding
   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String);

   --  Read the next item from the prompt queue.  Blocks until an item is
   --  available or Shutdown is called (returns Shutdown_Item in that case).
   --  Called from Agent_Task in Run_GUI; preferred over Read_Prompt.
   function Read_Item (F : in out Instance)
     return Coyote_GUI.Prompt_Queue.Item;

   overriding
   function Read_Prompt (F : in out Instance) return String;

   overriding
   procedure Shutdown (F : in out Instance);

   --  ── GUI-specific (not in abstract interface) ──────────────────────────

   --  Queue a typed session-statistics snapshot for the support window.
   procedure Set_Stats_Summary
     (F     : in out Instance;
      Stats : Coyote_GUI.Session_Stats_Record);

   --  Clear the support-window report for a new or switched session.
   procedure Clear_Stats (F : in out Instance);

   --  Register the agent session so that Stop and application shutdown can
   --  call Request_Abort directly from the GTK callback thread, bypassing
   --  the prompt queue.  Must be called from Agent_Task after
   --  LLM.Agent.Create.
   procedure Register_Session
     (F : in out Instance;
      S : access LLM.Agent.Session);

   --  Request application shutdown from a GTK callback.  This stops the
   --  process-control monitor, aborts any active request, wakes Agent_Task,
   --  and stops update producers.  The callback is responsible for quitting
   --  the GTK main loop.
   procedure Request_Shutdown (F : in out Instance);

   --  Called when replacing the active session with a new one.
   procedure Clear_Conversation (F : in out Instance);

   --  Enable or disable conversation debug logging to stderr.
   procedure Set_Debug_Logging (F : in out Instance; Enabled : Boolean);

   --  Apply a persisted notification setting to the active GUI.
   procedure Set_Completion_Notifications
     (F : in out Instance; Enabled : Boolean);

   --  Queue a completion notification for GTK-thread evaluation.
   procedure Notify_Completion (F : in out Instance);

   --  Update the window-manager identity for the active session.  The
   --  request is queued so the GTK window is changed only on the GTK task.
   procedure Set_Session_Identity
     (F : in out Instance;
      Session_Id : String);

private

   protected type Session_Reference is
      procedure Set (Value : access LLM.Agent.Session);
      procedure Request_Abort;
   private
      Value : access LLM.Agent.Session := null;
   end Session_Reference;

   type Instance is new Coyote_App.Frontend.Instance with record
      --  Update queue: agent task → GTK idle drain.
      Updates   : aliased Coyote_GUI.Updates.Queue;
      --  Prompt queue: GTK callbacks → agent task.
      PQ        : aliased Coyote_GUI.Prompt_Queue.Queue;
      --  Text buffer wrapper.
      Conv      : Coyote_GUI.Conversation.Instance;
      --  Native component-stack presentation.  The legacy conversation
      --  renderer remains the default until qualification completes.
      Stack     : Coyote_GUI.Conversation_Stack.Instance;
      Stack_Enabled : Boolean := False;
      --  GTK widgets.
      Win       : Gtk.Window.Gtk_Window;
      Render_Markdown_Item  : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
      Stop_Item             : Gtk.Menu_Item.Gtk_Menu_Item;
      Pause_Item            : Gtk.Menu_Item.Gtk_Menu_Item;
      Resume_Item           : Gtk.Menu_Item.Gtk_Menu_Item;
      Cut_Item              : Gtk.Menu_Item.Gtk_Menu_Item;
      Copy_Item             : Gtk.Menu_Item.Gtk_Menu_Item;
      Paste_Item            : Gtk.Menu_Item.Gtk_Menu_Item;
      Select_All_Item       : Gtk.Menu_Item.Gtk_Menu_Item;
      Deselect_Item         : Gtk.Menu_Item.Gtk_Menu_Item;
      Notification_Check    : Gtk.Check_Button.Gtk_Check_Button;
      Notifications_Allowed : Boolean := False;
      Notifications_Enabled : Boolean := False;
      Accel_Group : Gtk.Accel_Group.Gtk_Accel_Group;
      Menu_Bar  : Gtk.Menu_Bar.Gtk_Menu_Bar;
      Conv_Layout : Gtk.Layout.Gtk_Layout;
      Conv_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Prompt_View              : Gtk.Text_View.Gtk_Text_View;
      Prompt_Buf               : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Send_Btn                 : Gtk.Button.Gtk_Button;
      Stop_Btn                 : Gtk.Button.Gtk_Button;
      Status_Bar               : Gtk.Label.Gtk_Label;
      Prompt_Box               : Gtk.Box.Gtk_Box;
      Status_Box               : Gtk.Box.Gtk_Box;
      Conversation_Prompt_Sep  : Gtk.Separator.Gtk_Separator;
      Prompt_Status_Sep        : Gtk.Separator.Gtk_Separator;
      Outer_Box                : Gtk.Box.Gtk_Box;
      --  State
      Win_Name     : Unbounded_String;
      Stats_Window : Coyote_GUI.Session_Stats_Window.Instance;
      Current_Mode : Coyote_App.Frontend.Run_Mode :=
        Coyote_App.Frontend.Idle;
      Agent_Sess  : Session_Reference;
      --  Auto-scroll: when True, the conversation view snaps to the bottom
      --  whenever its adjustment changes (new content arrives).  Toggled
      --  via View → Auto-scroll check menu item.  Enabled by default.
      Auto_Scroll         : Boolean := True;
      Auto_Scroll_Item    : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
      Zoom_Level          : Integer := 0;
      Smooth_Zoom_Accumulator : Gdouble := 0.0;
      --  True after Shift+F1 until the next click selects a help target.
      Help_Mode : Boolean := False;
   end record;

end Coyote_App.Frontend.GUI;
