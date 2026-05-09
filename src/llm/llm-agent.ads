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
   --  Agent_Def is the body text of a loaded agent definition.  When
   --  non-empty it replaces the default system-prompt preamble verbatim.
   --
   --  Custom_Prompt is appended to the system prompt after Agent_Def (or
   --  after the default preamble when Agent_Def is empty).
   --
   --  Session_Id resumes an existing session when non-empty.
   --  No_Tools disables the built-in tool set when True.
   procedure Create
     (S             :    out Session;
      Model_Spec    :        String  := "";
      Agent_Def     :        String  := "";
      Custom_Prompt :        String  := "";
      No_Tools      :        Boolean := False;
      Session_Id    :        String  := "");

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
   procedure Compact
     (S        : in out Session;
      On_Event :        not null access procedure
                          (E : LLM.Events.Agent_Event'Class);
      Reason   :        String := "manual");

   --  Request cancellation of the currently-running Run_Prompt call.
   --  Safe to call from another task.
   procedure Request_Abort (S : in out Session);

   --  Start a new empty conversation with a fresh on-disk session id.
   procedure New_Session (S : in out Session);

   --  Switch to an existing session UUID and load its persisted history.
   procedure Switch_Session (S : in out Session; UUID : String);

   --  Change the active model using "provider/model-id" format.
   procedure Set_Model (S : in out Session; Spec : String);

   --  Change the requested thinking level for subsequent prompts.
   procedure Set_Thinking
     (S     : in out Session;
      Level :        LLM.Providers.Thinking_Level);

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

   type Session is limited record
      Model_Spec    : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      System_Prompt : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Session_UUID  : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      History       : LLM.Types.Message_Vectors.Vector;
      No_Tools      : Boolean := False;
      Thinking      : LLM.Providers.Thinking_Level := LLM.Providers.Off;
      Abort_State   : aliased LLM.Tools.Abort_Flag;
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
