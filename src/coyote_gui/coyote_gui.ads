--  Coyote_GUI — GTK3 graphical frontend subsystem root package.
--
--  Defines the shared Update_Kind enumeration and Update record used to
--  pass agent events from Agent_Task to the GTK main loop via the
--  Coyote_GUI.Updates protected queue.  The idle callback on the GTK
--  thread dequeues these updates and applies them to the GTK conversation renderer.
--
--  Project: coyote

with Ada.Strings.Unbounded;

package Coyote_GUI is

   --  ── Run mode ──────────────────────────────────────────────────────────
   --  Mirrors Coyote_App.Frontend.Run_Mode.

   type Run_Mode is (Idle, Running, Armed, Paused);

   --  ── Tool end status ───────────────────────────────────────────────────
   --  Mirrors Coyote_App.Frontend.Tool_End_Status.

   type Tool_End_Status is (Success, Error, Cancelled);

   --  ── Notice severity ───────────────────────────────────────────────────
   --  Mirrors Coyote_App.Frontend.Notice_Kind.

   type Notice_Kind is (Info, Warning, Error);

   --  ── Update variant record ─────────────────────────────────────────────
   --
   --  Every Frontend.GUI primitive enqueues exactly one Update value.
   --  Fields unused for a given Kind carry their defaults; the drain
   --  callback ignores them.
   --
   --  Field usage by Kind:
   --
   --    Append_Text        Text = chunk text
   --    End_Text_Block     (no extra fields)
   --    Begin_Thinking     (no extra fields)
   --    Append_Thinking    Text = chunk text
   --    End_Thinking       (no extra fields)
   --    Begin_Tool         Text  = tool name
   --                       Text2 = args JSON
   --                       Text3 = session id
   --                       Text4 = tool id
   --    End_Tool           Text  = tool id
   --                       Text2 = result text
   --                       T_Status = status
   --    Append_Notice      Text = message; N_Kind = severity
   --    Append_Turn_Footer Text = footer line
   --    Append_Action_Strip Text = display label;
   --                        Text2 = action kind ("fork");
   --                        Text3 = action data JSON (uuid, turn, step, pid)
   --    Set_Status         Text = status bar text
   --    Set_Mode           Mode = new mode
   --    Show_Detail        Text = window title; Text2 = content
   --    Shutdown           (no extra fields)


   type Update_Kind is
     (Append_Text,
      End_Text_Block,
      Begin_Thinking,
      Append_Thinking,
      End_Thinking,
      Begin_Tool,
      End_Tool,
      Append_Notice,
      Append_Turn_Footer,
      Append_Action_Strip,
      Set_Status,
      Set_Mode,
      Set_Completion_Notifications,
      Completion_Notification,
      Show_Detail,
      Shutdown);

   type Update is record
      Kind     : Update_Kind := Append_Text;
      Text     : Ada.Strings.Unbounded.Unbounded_String;
      Text2    : Ada.Strings.Unbounded.Unbounded_String;
      Text3    : Ada.Strings.Unbounded.Unbounded_String;
      Text4    : Ada.Strings.Unbounded.Unbounded_String;
      T_Status : Tool_End_Status := Success;
      Mode     : Run_Mode        := Idle;
      N_Kind   : Notice_Kind     := Info;
      Enabled  : Boolean         := False;
   end record;

end Coyote_GUI;
