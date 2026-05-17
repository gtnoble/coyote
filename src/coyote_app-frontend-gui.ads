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
with Coyote_GUI.Buffer;
with Coyote_GUI.Prompt_Queue;
with Coyote_GUI.Updates;
with Gtk.Box;
with Gtk.Button;
with Gtk.Label;
with Gtk.Menu_Bar;
with Gtk.Scrolled_Window;
with Gtk.Status_Bar;
with Gtk.Text_Buffer;
with Gtk.Text_View;
with Gtk.Window;

package Coyote_App.Frontend.GUI is

   type Instance is new Coyote_App.Frontend.Instance with private;

   --  Initialise the GTK window and register the idle drain callback.
   --  Must be called from the GTK main loop thread.
   procedure Create (F : in out Instance; Win_Name : String);

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
     (F          : in out Instance;
      Name       : in     String;
      Args_Json  : in     String;
      Session_Id : in     String;
      Tool_Id    : in     String);

   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Coyote_App.Frontend.Tool_End_Status;
      Result_Text : in     String := "");

   overriding
   procedure Append_Turn_Footer
     (F    : in out Instance;
      Text : in     String);

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

   --  Store formatted session stats; shown by Agent > Session Stats menu item.
   procedure Set_Stats_Summary (F : in out Instance; Text : String);

   --  Read (and clear) stats text for display.
   function Stats_Summary_Text (F : Instance) return String;

private

   type Instance is new Coyote_App.Frontend.Instance with record
      --  Update queue: agent task → GTK idle drain.
      Updates   : aliased Coyote_GUI.Updates.Queue;
      --  Prompt queue: GTK callbacks → agent task.
      PQ        : aliased Coyote_GUI.Prompt_Queue.Queue;
      --  Text buffer wrapper.
      Buf       : Coyote_GUI.Buffer.Instance;
      --  GTK widgets.
      Win       : Gtk.Window.Gtk_Window;
      Menu_Bar  : Gtk.Menu_Bar.Gtk_Menu_Bar;
      Conv_View : Gtk.Text_View.Gtk_Text_View;
      Conv_Buf  : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Conv_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Prompt_View : Gtk.Text_View.Gtk_Text_View;
      Prompt_Buf  : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Prompt_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Send_Btn    : Gtk.Button.Gtk_Button;
      Status_Bar  : Gtk.Label.Gtk_Label;
      Outer_Box   : Gtk.Box.Gtk_Box;
      --  State
      Win_Name    : Unbounded_String;
      Stats_Text  : Unbounded_String;
      Current_Mode : Coyote_App.Frontend.Run_Mode :=
        Coyote_App.Frontend.Idle;
   end record;

end Coyote_App.Frontend.GUI;
