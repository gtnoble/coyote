--  Coyote_App — main application state and entry point.
--
--  App_State is a protected object holding all mutable state shared between
--  tasks.  Run_GUI starts the GTK frontend and blocks until it closes.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package Coyote_App is

   --  ── App_State ────────────────────────────────────────────────────────
   --
   --  All fields are read under the shared lock (protected functions) and
   --  written under the exclusive lock (protected procedures).
   --  Signal_Shutdown / Wait_Shutdown implement the application shutdown
   --  barrier.

   protected type App_State is

      --  Readers
      function Session_Id         return String;
      function Current_Model      return String;
      function Current_Thinking   return String;
      function Current_Sandbox    return String;
      function Source_Directory   return String;
      function Session_Start      return String;
      function Current_Tool_Call  return Natural;
      function Is_Streaming       return Boolean;
      function Is_Compacting      return Boolean;
      function Was_Aborted        return Boolean;
      --  True while the agentic loop is blocked at a turn boundary.
      function Is_Paused          return Boolean;
      --  True after Pause is clicked and before the pause actually fires.
      function Is_Pause_Armed     return Boolean;
      function Text_Emitted       return Boolean;
      --  True while an auto-retry sequence is in progress.  Set by
      --  auto_retry_start, cleared by auto_retry_end and explicit reset
      --  points (new_session response, session reload).  Used to suppress
      --  the spurious "No response" message for all but the first failed
      --  attempt: the agent emits agent_end before auto_retry_start, so
      --  the first failure always arrives before we know a retry is coming.
      function Is_Retrying        return Boolean;
      --  True only when at least one text_delta arrived in the current
      --  agent turn (tool-only turns leave this False).
      function Has_Text_Delta     return Boolean;
      --  True when tool_execution_start fired in the current agent turn.
      --  Reset at agent_start alongside Has_Text_Delta.
      function Has_Tool_In_Turn   return Boolean;
      function Tools_Running        return Natural;
      function Tools_Done           return Natural;
      --  stopReason from the last assistant message_end event in the
      --  current agent run.  Reset to "" at agent_start.  Possible values:
      --  "stop" (normal completion), "length" (max tokens),
      --  "toolUse" (intermediate turn — another LLM call follows),
      --  "aborted", "error".  A value of "stop" or "length" means the
      --  agent's final LLM call produced a text response; "toolUse" means
      --  more turns are still pending (not possible at agent_end, but
      --  tracked for safety).
      function Last_Stop_Reason   return String;
      --  errorMessage from the last assistant message_end with
      --  stopReason "error".  Empty when the last turn did not produce
      --  an error, or when no message was supplied.  Reset at
      --  agent_start alongside Last_Stop_Reason.
      function Last_Error_Message return String;
      function Pending_Stats        return Boolean;
      function Context_Window     return Natural;
      function Turn_Input_Tokens  return Natural;
      function Turn_Output_Tokens return Natural;
      function Turn_Count            return Natural;
      --  Per-turn cost captured from message_end (units of $0.0001).
      function Turn_Cost_Dmil        return Natural;
      --  Cumulative session stats from the last get_session_stats response.
      function Session_Cost_Dmil     return Natural;
      function Session_Input_Tokens  return Natural;
      function Session_Output_Tokens return Natural;
      function Session_Cache_Read    return Natural;
      function Session_Cache_Write   return Natural;
      function Session_Total_Tokens  return Natural;
      --  Effective prompt filter command (CLI flag overrides settings.json).
      --  Empty when no filter is configured.
      function Prompt_Filter         return String;
      function Agent_Ready        return Boolean;
      entry     Wait_Agent_Ready;
      function Agent_Stopped      return Boolean;
      entry     Wait_Agent_Stopped;
      function Frontend_Ready     return Boolean;
      entry     Wait_Frontend_Ready;
      function Shutdown_Requested  return Boolean;

      --  Writers
      procedure Set_Session_Id     (Id    : String);
      procedure Set_Model          (Model : String);
      procedure Set_Thinking       (Level : String);
      procedure Set_Sandbox        (Profile : String);
      procedure Set_Source_Directory (Directory : String);
      procedure Set_Session_Start    (Start : String);
      procedure Set_Streaming      (Value : Boolean);
      procedure Set_Compacting     (Value : Boolean);
      procedure Set_Aborted        (Value : Boolean);
      procedure Set_Paused         (Value : Boolean);
      procedure Set_Pause_Armed    (Value : Boolean);
      procedure Set_Is_Retrying    (Value : Boolean);
      procedure Set_Text_Emitted   (Value : Boolean);
      procedure Set_Has_Text_Delta   (Value : Boolean);
      procedure Set_Has_Tool_In_Turn (Value : Boolean);
      procedure Increment_Tools_Running;
      procedure Increment_Tools_Done;
      procedure Increment_Tool_Call;
      procedure Reset_Tool_Counts;
      procedure Set_Last_Stop_Reason  (Value : String);
      procedure Set_Last_Error_Message (Value : String);
      procedure Set_Pending_Stats  (Value : Boolean);
      procedure Set_Context_Window (N     : Natural);
      procedure Set_Turn_Tokens    (Input, Output : Natural);
      --  Per-turn cost from message_end usage.cost.total (units of $0.0001).
      procedure Set_Turn_Cost      (Dmil : Natural);
      --  Store the full get_session_stats payload atomically.
      procedure Set_Session_Stats
        (Cost_Dmil   : Natural;
         Input       : Natural;
         Output      : Natural;
         Cache_Read  : Natural;
         Cache_Write : Natural;
         Total       : Natural);
      procedure Set_Prompt_Filter  (Cmd   : String);
      procedure Set_Agent_Ready    (Value : Boolean);
      procedure Set_Agent_Stopped  (Value : Boolean);
      procedure Set_Frontend_Ready (Value : Boolean);

      --  Turn counter — incremented after each completed agent turn,
      --  reset on new_session, and restored from history on session reload.
      procedure Increment_Turn_Count;
      procedure Set_Turn_Count     (N     : Natural);
      procedure Reset_Turn_Count;

      --  Turn step counter — tracks which assistant message within the
      --  current agent turn (1-based).  Incremented before each step-level
      --  fork footer; reset at agent_start alongside turn-scope state.
      function  Turn_Step          return Natural;
      procedure Increment_Turn_Step;
      procedure Reset_Turn_Step;
      procedure Set_Turn_Step      (N     : Natural);

      --  True when any tool in the current batch was cancelled (aborted).
      --  Reset at agent_start.  Used to suppress step-level fork footers
      --  when tool results are incomplete.
      function  Tool_Cancelled     return Boolean;
      procedure Set_Tool_Cancelled (Value : Boolean);

      --  One-shot result: set once by Pi_Stdout_Task before signalling
      --  shutdown; read by Run after Wait_Shutdown returns.  Only the
      --  first call to Set_One_Shot_Result has effect (subsequent calls
      --  are silently ignored), so the exception handler can call it
      --  safely without overwriting an already-captured success result.
      --  Returns "" until a result has been stored.
      procedure Set_One_Shot_Result (Json : String);
      function  One_Shot_Result     return String;

      --  Shutdown synchronisation
      procedure Signal_Shutdown;
      entry     Wait_Shutdown;

   private
      P_Session_Id    : Ada.Strings.Unbounded.Unbounded_String;
      P_Model         : Ada.Strings.Unbounded.Unbounded_String;
      P_Thinking      : Ada.Strings.Unbounded.Unbounded_String;
      P_Sandbox       : Ada.Strings.Unbounded.Unbounded_String;
      P_Source_Directory : Ada.Strings.Unbounded.Unbounded_String;
      P_Session_Start : Ada.Strings.Unbounded.Unbounded_String;
      P_Streaming     : Boolean := False;
      P_Compacting    : Boolean := False;
      P_Aborted       : Boolean := False;
      P_Paused        : Boolean := False;
      P_Pause_Armed   : Boolean := False;
      P_Is_Retrying   : Boolean := False;
      P_Text_Emitted  : Boolean := False;
      P_Has_Text_Delta   : Boolean := False;
      P_Has_Tool_In_Turn : Boolean := False;
      P_Tools_Running : Natural := 0;
      P_Tools_Done    : Natural := 0;
      P_Last_Stop_Reason  : Ada.Strings.Unbounded.Unbounded_String;
      P_Last_Error_Message : Ada.Strings.Unbounded.Unbounded_String;
      P_Pending_Stats : Boolean := False;

      P_Ctx_Win       : Natural := 0;
      P_Turn_In       : Natural := 0;
      P_Turn_Out      : Natural := 0;
      --  Per-turn cost (units of $0.0001); set from message_end.
      P_Turn_Cost     : Natural := 0;
      --  Cumulative session stats; set from get_session_stats response.
      P_Sess_Cost     : Natural := 0;
      P_Sess_In       : Natural := 0;
      P_Sess_Out      : Natural := 0;
      P_Sess_Cache_R  : Natural := 0;
      P_Sess_Cache_W  : Natural := 0;
      P_Sess_Total    : Natural := 0;

      P_Prompt_Filter : Ada.Strings.Unbounded.Unbounded_String;

      P_Agent_Ready   : Boolean := False;
      P_Agent_Stopped : Boolean := False;
      P_Frontend_Ready : Boolean := False;
      P_Shutdown      : Boolean := False;
      P_Turn_Count    : Natural := 0;
      P_Turn_Step     : Natural := 0;   --  step counter within turn (1-based)
      P_Tool_Call     : Natural := 0;   --  1-based call ordinal within turn
      P_Tool_Cancelled : Boolean := False;  --  any tool in current batch cancelled
      --  One-shot result (empty until set)
      P_One_Shot_Result  : Ada.Strings.Unbounded.Unbounded_String;
   end App_State;

   --  ── Options ──────────────────────────────────────────────────────────

   --  ── Frontend_Kind ────────────────────────────────────────────────────
   --
   --  Which presentation frontend to use.  Set by coyote.adb at startup.
   --
   --    GUI_Frontend   — GTK3 window        (default when a display is set)
   --    Plain_Frontend — line-oriented text (one-shot / no display)

   type Frontend_Kind is (GUI_Frontend, Plain_Frontend, RPC_Frontend);

   type Options is record
      Session_Id     : Ada.Strings.Unbounded.Unbounded_String;
      Model          : Ada.Strings.Unbounded.Unbounded_String;
      Agent          : Ada.Strings.Unbounded.Unbounded_String;
      No_Tools       : Boolean := False;
      No_Session     : Boolean := False;
      No_Compact     : Boolean := False;
      --  When non-empty, sent as the first prompt immediately after the
      --  bootstrap get_state exchange.  Only meaningful with One_Shot.
      Initial_Prompt : Ada.Strings.Unbounded.Unbounded_String;
      --  When True, the window closes and the process exits after the first
      --  complete agent turn, printing a JSON result line to stdout.
      One_Shot       : Boolean := False;
      --  When True, the agent was spawned as a headful subagent
      --  (--subagent flag): exits after one turn like One_Shot but
      --  does not force the Plain frontend.
      Subagent       : Boolean := False;
      --  When True, launch as an independent physical GUI window.
      Physical_Window : Boolean := False;
      --  Optional label appended to the GUI window title.
      Name           : Ada.Strings.Unbounded.Unbounded_String;
      --  Shell command through which interactive prompts are filtered before
      --  being sent to the agent.  CLI flag wins over settings.json.
      --  Empty means no filter.
      Prompt_Filter  : Ada.Strings.Unbounded.Unbounded_String;
      --  When non-empty, a warning message to display after startup
      --  (and on stderr).  Set by coyote.adb when the working
      --  directory stored in the resumed session no longer exists.
      Work_Dir_Warning : Ada.Strings.Unbounded.Unbounded_String;
      --  Which frontend to use; set by the entry point before startup.
      Frontend       : Frontend_Kind := Plain_Frontend;
      --  True when --frontend was explicitly set on the command line.
      --  When True, the automatic detection logic is skipped.
      Frontend_Explicit : Boolean := False;
      --  When True, conversation debug logging is printed to stderr.
      Debug_Logging   : Boolean := False;
   end record;

   --  ── Section_Kind ─────────────────────────────────────────────────────
   --
   --  Tracks which kind of streaming content is currently being appended to
   --  the window body.  Shared between Dispatch_Event (in
   --  Coyote_App.Dispatch) and the agent task in the selected runner.

   type Section_Kind is
     (No_Section, Thinking_Section, Text_Section, Tool_Section);

   --  ── Entry points ──────────────────────────────────────────────────────

   --  Run the GTK3 graphical frontend.
   procedure Run_GUI (Opts : Options);
end Coyote_App;
