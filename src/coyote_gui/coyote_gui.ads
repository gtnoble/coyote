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

   --  Agent-menu availability.  Stop applies to any live turn; Pause
   --  applies only while a turn is running; Resume applies only while
   --  paused.  Armed means Pause has been requested but not yet taken.
   function Stop_Available (Mode : Run_Mode) return Boolean
     is (Mode /= Idle);
   function Pause_Available (Mode : Run_Mode) return Boolean
     is (Mode = Running);
   function Resume_Available (Mode : Run_Mode) return Boolean
     is (Mode = Paused);

   --  ── Request lifecycle ─────────────────────────────────────────────────
   --  These types mirror the abstract frontend lifecycle values while
   --  keeping the update queue independent of frontend implementation types.

   type Request_Kind is (Prompt, Steer);
   type Footer_Kind is (Step_Footer, Final_Footer);
   type Completion_Status is (Completed, Aborted, Failed);

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
   --    Begin_Request      Text = submitted prompt; R_Kind = request kind
   --    Complete_Request   C_Status = terminal exchange state
   --    Append_Text        Text = chunk text
   --    End_Text_Block     (no extra fields)
   --    Begin_Thinking     (no extra fields)
   --    Append_Thinking    Text = chunk text
   --    End_Thinking       (no extra fields)
   --    Begin_Tool         Text  = tool name
   --                       Text2 = args JSON
   --                       Text3 = session id
   --                       Text4 = tool id
   --                       Text5 = model
   --                       Text6 = source directory
   --                       Text7 = session start
   --                       Tool_Turn / Tool_Call = position
   --    End_Tool           Text  = tool id
   --                       Text2 = result text
   --                       Text3 = media type
   --                       T_Status = status
   --    Append_Notice      Text = message; N_Kind = severity
   --    Append_Turn_Footer Text = formatted footer; Text2 = typed summary;
   --                       F_Kind = step or final
   --    Append_Action_Strip Text = display label;
   --                        Text2 = action kind ("fork");
   --                        Text3 = action data JSON (uuid, turn, step, pid)
   --    Set_Status         Text = status bar text
   --    Set_Mode           Mode = new mode
   --    Set_Stats          Stats = typed session statistics snapshot
   --    Clear_Stats        (no extra fields)
   --    Clear_Conversation (no extra fields)

   --  Session statistics transported from the agent task to the GTK task.
   --  Strings identify the active session; counters are cumulative unless
   --  explicitly labelled as last-turn values.
   type Session_Stats_Record is record
      Model              : Ada.Strings.Unbounded.Unbounded_String;
      Session_Id         : Ada.Strings.Unbounded.Unbounded_String;
      Turn_Count         : Natural := 0;
      Last_Input         : Natural := 0;
      Last_Output        : Natural := 0;
      Last_Cost_Dmil     : Natural := 0;
      Input              : Natural := 0;
      Cache_Read         : Natural := 0;
      Cache_Write        : Natural := 0;
      Output             : Natural := 0;
      Cost_Dmil          : Natural := 0;
   end record;
   --    Set_Transcript       Text = accessible transcript text
   --    Set_Session_Identity Text = session identifier for window role
   --    Show_Detail          Text = window title; Text2 = content
   --    Shutdown           (no extra fields)


   type Update_Kind is
     (Begin_Request,
      Complete_Request,
      Append_Text,
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
      Set_Stats,
      Clear_Stats,
      Clear_Conversation,
      Set_Transcript,
      Set_Session_Identity,
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
      Text5    : Ada.Strings.Unbounded.Unbounded_String;
      Text6    : Ada.Strings.Unbounded.Unbounded_String;
      Text7    : Ada.Strings.Unbounded.Unbounded_String;
      Tool_Turn : Natural := 0;
      Tool_Call : Natural := 0;
      Stats    : Session_Stats_Record;
      T_Status : Tool_End_Status := Success;
      Mode     : Run_Mode        := Idle;
      N_Kind   : Notice_Kind     := Info;
      R_Kind   : Request_Kind    := Prompt;
      F_Kind   : Footer_Kind     := Final_Footer;
      C_Status : Completion_Status := Completed;
      Enabled  : Boolean         := False;
   end record;

end Coyote_GUI;
