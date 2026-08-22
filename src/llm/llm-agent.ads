--  LLM.Agent — native agentic conversation loop.
--
--  Owns one mutable conversation session, persists messages to the
--  session store, and runs the core agent→tool→agent loop for
--  one user prompt.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with LLM.Compaction;
with LLM.Events;
with LLM.Model_Registry;
with LLM.Providers;
with LLM.Tools;
with LLM.Types;

package LLM.Agent is

   type Session is limited private;

   --  Initialise a session.
   --
   --  Model_Spec uses "provider/model-id" format, for example
   --  "github-copilot/claude-sonnet-4.6" or
   --  "openrouter/anthropic/claude-sonnet-4-20250514".
   --
   --  When Model_Spec is empty, Create falls back to ~/.coyote/settings.json
   --  and then to the first available model in the live registry.
   --
   --  Agent is appended to the system prompt after the default preamble.
   --
   --  Session_Id resumes an existing session when non-empty.
   --  No_Tools disables the built-in tool set when True.
   --  Subagent selects the dedicated default model when Model_Spec is empty.
   procedure Create
     (S             :    out Session;
      Model_Spec    :        String  := "";
      Agent         :        String  := "";
      No_Tools      :        Boolean := False;
      Session_Id    :        String  := "";
      Subagent      :        Boolean := False);

   --  Send Prompt as a new user turn and run the full agentic loop until
   --  the agent completes, is aborted, or raises an error.
   --
   --  On_Event is invoked synchronously in the caller's task for each event
   --  emitted by the loop.
   procedure Run_Prompt
     (S        : in out Session;
      Prompt   :        String;
      On_Event :        not null access procedure
                          (E : LLM.Events.Agent_Event'Class));

   --  Compact the session context by summarising older messages.
   --
   --  Calls the active model once with a compaction-specific system prompt,
   --  replaces the in-memory history with one synthetic
   --  Compaction_Summary message followed by the retained tail of the
   --  transcript, and appends one compaction entry to the session JSONL
   --  file.
   --
   --  Auto_Compaction_Start_Event is emitted before the summarisation call
   --  and Auto_Compaction_End_Event is emitted on every exit path. On any
   --  error the end event carries the error message, Aborted is True, and
   --  S.History is left unchanged.
   --
   --  Reason is forwarded to Auto_Compaction_Start_Event.Reason. Typical
   --  values are "manual", "threshold", and "overflow".
   --
   --  Must not be called while Run_Prompt is executing.
   --  Succeeded is set to True when compaction completes successfully and
   --  False on any abort or error path.
   procedure Compact
     (S         : in out Session;
      On_Event  :        not null access procedure
                           (E : LLM.Events.Agent_Event'Class);
      Reason    :        String := "manual";
      Succeeded :    out Boolean);

   --  Request cancellation of the currently-running Run_Prompt call.
   --  Safe to call from another task.
   procedure Request_Abort (S : in out Session);

   --  Arm a pause that will fire at the next turn boundary inside
   --  Run_Prompt.  The loop emits Agent_Paused_Event and blocks until
   --  Resume is called.  Safe to call from another task.
   procedure Request_Pause (S : in out Session);

   --  Release a paused loop so it continues from the next turn.
   --  Safe to call from another task.
   procedure Resume (S : in out Session);

   --  True when a pause has been armed but has not yet fired.
   function Is_Pause_Armed (S : Session) return Boolean;

   --  True while the loop is blocked at a turn boundary waiting for Resume.
   function Is_Paused (S : Session) return Boolean;

   --  Switch to an existing session UUID and load its persisted history.
   procedure Switch_Session (S : in out Session; UUID : String);

   --  Change the active model using "provider/model-id" format.
   procedure Set_Model (S : in out Session; Spec : String);

   --  Change the requested thinking level for subsequent prompts.
   procedure Set_Thinking
     (S     : in out Session;
      Level :        LLM.Providers.Thinking_Level);

   --  Change the sandbox profile for shell tool commands.
   --  Pass "" to disable sandboxing.
   procedure Set_Sandbox_Profile
     (S       : in out Session;
      Profile :        String);

   --  Return the active sandbox profile name ("" when none).
   function Current_Sandbox (S : Session) return String;

   --  Override the compaction settings for subsequent prompts.
   --  Pass a value with Enabled => False to disable automatic
   --  context compaction entirely (e.g. for ephemeral one-shot sessions).
   procedure Set_Compact_Settings
     (S        : in out Session;
      Settings :        LLM.Compaction.Compact_Settings);

   --  Return the active session UUID.
   function Session_Id (S : Session) return String;

   --  True once Run_Prompt has been called at least once.
   function Has_Submitted_Prompts (S : Session) return Boolean;

   --  Return the normalised active model specification.
   function Current_Model_Spec (S : Session) return String;

   --  Return the active model's context-window size.
   function Context_Window (S : Session) return Natural;

   --  True while Run_Prompt is actively processing a turn.
   function Is_Streaming (S : Session) return Boolean;

private

   EMPTY_MODEL_INFO : constant LLM.Model_Registry.Model_Info :=
     (Model_Id            => Ada.Strings.Unbounded.Null_Unbounded_String,
      Name                => Ada.Strings.Unbounded.Null_Unbounded_String,
      Provider            => Ada.Strings.Unbounded.Null_Unbounded_String,
      Context_Window      => 128_000,
      Max_Tokens          => 4_096,
      Reasoning           => False,
      Supports_Tools      => True,
      Supports_Images     => False,
      Max_Thinking_Budget => 0,
      Min_Thinking_Budget => 0,
      Wire_Format         => Ada.Strings.Unbounded.Null_Unbounded_String,
      Cost                => (others => 0.0));

   --  Return a provider request view that excludes model-bound thinking
   --  blocks not owned by Provider and Model_Id.
   function Compatible_History
     (History  : LLM.Types.Message_Vectors.Vector;
      Provider : String;
      Model_Id : String) return LLM.Types.Message_Vectors.Vector;

   type Session is limited record
      Model_Spec    : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      System_Prompt : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Session_UUID  : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      History       : LLM.Types.Message_Vectors.Vector;
      No_Tools      : Boolean := False;
      Thinking        : LLM.Providers.Thinking_Level := LLM.Providers.Off;
      Sandbox_Profile : aliased Ada.Strings.Unbounded.Unbounded_String;
      Abort_State   : aliased LLM.Tools.Abort_Flag;
      Pause_State   : aliased LLM.Tools.Pause_Flag;
      Streaming     : Boolean := False;
      Cwd           : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Model_Info    : LLM.Model_Registry.Model_Info := EMPTY_MODEL_INFO;
      Compact_Settings : LLM.Compaction.Compact_Settings :=
        LLM.Compaction.Default_Compact_Settings;
      Last_Context_Tokens : Natural := 0;
      Has_Submitted_Prompts : Boolean := False;
   end record;

end LLM.Agent;
