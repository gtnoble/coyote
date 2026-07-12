--  LLM.Compaction -- pure helpers for context compaction decisions.
--
--  Provides conservative token estimation, compaction-threshold checks,
--  cut-point selection, transcript serialisation for summarisation,
--  and a circuit breaker to suspend auto-compaction after repeated
--  failures.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with LLM.Types;

package LLM.Compaction is

   --  Settings controlling when context compaction is eligible and how
   --  much recent history must be retained verbatim.
   type Compact_Settings is record
      Enabled              : Boolean := True;
      Reserve_Tokens       : Positive := 16_384;
      Keep_Recent_Tokens   : Positive := 20_000;
      --  Circuit breaker: after Consecutive_Failures reaches
      --  Max_Consecutive_Failures, Tripped is set to True and
      --  auto-compaction is suspended for the remainder of the session.
      --  Manual compaction is still available.  Reset to 0 on success.
      Consecutive_Failures : Natural := 0;
      Tripped              : Boolean := False;
   end record;

   --  Maximum number of consecutive compaction failures before the
   --  circuit breaker trips (REQ-CORE-067).
   Max_Consecutive_Failures : constant Positive := 3;

   --  Default compaction settings used when no override is configured.
   Default_Compact_Settings : constant Compact_Settings :=
     (Enabled              => True,
      Reserve_Tokens       => 16_384,
      Keep_Recent_Tokens   => 20_000,
      Consecutive_Failures => 0,
      Tripped              => False);

   --  System prompt used for one-shot compaction summarisation requests.
   Summarization_System_Prompt : constant String :=
     "You are a context summarization assistant. Your task is to read a"
     & " conversation between a user and an AI coding assistant, then"
     & " produce a structured summary following the exact format"
     & " specified."
     & ASCII.LF & ASCII.LF
     & "Do NOT continue the conversation. Do NOT respond to any"
     & " questions in the conversation. ONLY output the structured"
     & " summary.";

   --  User prompt for the initial nine-section structured compaction
   --  summary (REQ-CORE-065).
   Summarization_Prompt : constant String :=
     "The messages above are a conversation to summarize. Create a"
     & " structured context checkpoint summary that another LLM will use"
     & " to continue the work."
     & ASCII.LF & ASCII.LF
     & "Before writing the summary, draft an <analysis> block where you"
     & " organise your reasoning. The analysis block will be stripped"
     & " from the stored summary; only the summary content is retained"
     & " in context."
     & ASCII.LF & ASCII.LF
     & "<analysis>"
     & ASCII.LF
     & "[Organise your understanding: what is the primary objective,"
     & " what has been accomplished, what is still pending, what"
     & " decisions were made and why, what errors were encountered"
     & " and how they were resolved.  Identify the files and code"
     & " sections that were created or modified, and note any"
     & " non-obvious technical details a future agent will need.]"
     & ASCII.LF
     & "</analysis>"
     & ASCII.LF & ASCII.LF
     & "After the analysis, write the summary using this EXACT format:"
     & ASCII.LF & ASCII.LF
     & "## 1. Primary Request and Intent"
     & ASCII.LF
     & "[What is the user trying to accomplish?  State the task in one"
     & " or two sentences, including any explicit constraints or"
     & " success criteria the user specified.]"
     & ASCII.LF & ASCII.LF
     & "## 2. Key Technical Concepts"
     & ASCII.LF
     & "- [List the technologies, frameworks, patterns, and domain"
     & " concepts that are relevant to the work.]"
     & ASCII.LF & ASCII.LF
     & "## 3. Files and Code Sections"
     & ASCII.LF
     & "For each file that was created, modified, or examined:"
     & ASCII.LF
     & "- `path/to/file` -- [what was done and why.  Include full code"
     & " snippets for files that were created or significantly"
     & " modified.]"
     & ASCII.LF & ASCII.LF
     & "## 4. Errors and Fixes"
     & ASCII.LF
     & "- [Each error encountered, the attempted fix, and the outcome.]"
     & ASCII.LF
     & "- [Or ""(none)"" if no errors were encountered.]"
     & ASCII.LF & ASCII.LF
     & "## 5. Problem Solving"
     & ASCII.LF
     & "- [Non-trivial problems solved: what approach was tried, what"
     & " alternatives were considered, and why the chosen approach was"
     & " selected.]"
     & ASCII.LF
     & "- [Or ""(none)"" if no significant problem-solving occurred.]"
     & ASCII.LF & ASCII.LF
     & "## 6. All User Messages"
     & ASCII.LF
     & "- [Quote or closely paraphrase every message the user sent, in"
     & " chronological order.  Do NOT include tool results -- only"
     & " actual user messages.]"
     & ASCII.LF & ASCII.LF
     & "## 7. Pending Tasks"
     & ASCII.LF
     & "- [ ] [Tasks the user explicitly requested that are not yet"
     & " complete.  Include any deferred sub-tasks.]"
     & ASCII.LF
     & "- [Or ""(none)"" if everything requested has been completed.]"
     & ASCII.LF & ASCII.LF
     & "## 8. Current Work"
     & ASCII.LF
     & "[Describe in detail what was happening in the most recent"
     & " conversation turns.  Include verbatim quotes from the last"
     & " assistant response where relevant -- the continuation agent"
     & " needs to pick up exactly where this agent left off.]"
     & ASCII.LF & ASCII.LF
     & "## 9. Optional Next Step"
     & ASCII.LF
     & "[If the conversation was mid-task, suggest ONE concrete next"
     & " action the continuation agent should take.  Be specific:"
     & " name the file, function, or command.]"
     & ASCII.LF
     & "[Or ""(none)"" if the task appears complete.]"
     & ASCII.LF & ASCII.LF
     & "Keep each section concise. Preserve exact file paths, function"
     & " names, error messages, and verbatim quotes. The <analysis>"
     & " block will be removed automatically -- do not duplicate its"
     & " content in the summary sections.";

   --  User prompt for updating an existing structured compaction summary
   --  with newer conversation messages.
   Update_Summarization_Prompt : constant String :=
     "The messages above are NEW conversation messages to incorporate"
     & " into the existing summary provided in <previous-summary> tags."
     & ASCII.LF & ASCII.LF
     & "Before writing the updated summary, draft an <analysis> block"
     & " where you organise your reasoning. The analysis block will be"
     & " stripped from the stored summary."
     & ASCII.LF & ASCII.LF
     & "<analysis>"
     & ASCII.LF
     & "[Review what has changed: what new work was done, what was"
     & " completed, what new problems arose, what decisions were made.]"
     & ASCII.LF
     & "</analysis>"
     & ASCII.LF & ASCII.LF
     & "Update the existing structured summary with new information."
     & " RULES:"
     & ASCII.LF
     & "- PRESERVE all existing information from the previous summary"
     & ASCII.LF
     & "- ADD new progress, decisions, and context from the new messages"
     & ASCII.LF
     & "- UPDATE sections 3 (Files), 7 (Pending Tasks), 8 (Current"
     & " Work), and 9 (Next Step) based on what was accomplished"
     & ASCII.LF
     & "- PRESERVE exact file paths, function names, and error messages"
     & ASCII.LF
     & "- If a completed task is no longer relevant, you may remove it"
     & ASCII.LF
     & "- The <analysis> block will be removed automatically -- do not"
     & " duplicate its content in the summary sections."
     & ASCII.LF & ASCII.LF
     & "Use this EXACT format:"
     & ASCII.LF & ASCII.LF
     & "## 1. Primary Request and Intent"
     & ASCII.LF
     & "[Preserve existing, update if the task has changed.]"
     & ASCII.LF & ASCII.LF
     & "## 2. Key Technical Concepts"
     & ASCII.LF
     & "- [Preserve existing, add new ones discovered.]"
     & ASCII.LF & ASCII.LF
     & "## 3. Files and Code Sections"
     & ASCII.LF
     & "- [Preserve all existing file entries; add new files that were"
     & " created or modified.]"
     & ASCII.LF & ASCII.LF
     & "## 4. Errors and Fixes"
     & ASCII.LF
     & "- [Preserve all existing; add new errors encountered and how they"
     & " were resolved.]"
     & ASCII.LF & ASCII.LF
     & "## 5. Problem Solving"
     & ASCII.LF
     & "- [Preserve all existing; add new non-trivial problems solved.]"
     & ASCII.LF & ASCII.LF
     & "## 6. All User Messages"
     & ASCII.LF
     & "- [Preserve all existing user messages; append any new user"
     & " messages from the new conversation.]"
     & ASCII.LF & ASCII.LF
     & "## 7. Pending Tasks"
     & ASCII.LF
     & "- [ ] [Update: move completed items from pending; add new pending"
     & " items.]"
     & ASCII.LF & ASCII.LF
     & "## 8. Current Work"
     & ASCII.LF
     & "[Update to describe the most recent conversation turns, with"
     & " verbatim quotes where relevant.]"
     & ASCII.LF & ASCII.LF
     & "## 9. Optional Next Step"
     & ASCII.LF
     & "[Update based on current state -- suggest the one concrete next"
     & " action.]";

   --  Strip the <analysis>...</analysis> block from a compaction summary
   --  before storing it in context (REQ-CORE-066).  The analysis is
   --  drafting-only and must not consume the continuation agent's
   --  context window.
   function Strip_Analysis_Block (Summary : String) return String;

   --  Build a full compaction user prompt including the serialised
   --  conversation, optional previous summary, and the appropriate
   --  summarisation prompt.
   --
   --  When Previous_Summary is non-empty, Update_Summarization_Prompt is
   --  used; otherwise Summarization_Prompt.
   --
   --  When Is_Partial is True, the prompt scopes to the earlier portion
   --  of history only, and the resulting summary will serve as a
   --  continuation preamble (REQ-CORE-068).
   function Build_Compact_Prompt
     (Conversation     : String;
      Previous_Summary : String := "";
      Is_Partial       : Boolean := False) return String;

   --  Estimate the token count for one message conservatively as
   --  ceiling(character_count / 4).
   --
   --  Counts user and assistant text, assistant thinking blocks,
   --  tool-call argument JSON, and tool-result text.
   function Estimate_Tokens (Msg : LLM.Types.Message) return Natural;

   --  Estimate the total context-token usage for a conversation history.
   --
   --  When the most recent assistant message carries non-zero provider
   --  usage, that exact total is returned. Otherwise the estimate is the
   --  sum of Estimate_Tokens over the whole history.
   function Estimate_Context_Tokens
     (History : LLM.Types.Message_Vectors.Vector) return Natural;

   --  Return True when the current context usage has reached the model
   --  window minus the configured reserve, and the circuit breaker
   --  has not tripped.
   --
   --  When compaction is disabled in Settings, or the circuit breaker
   --  has tripped, this function always returns False.
   function Should_Compact
     (Context_Tokens : Natural;
      Context_Window : Natural;
      Settings       : Compact_Settings) return Boolean;

   --  Find the 0-based index of the first message that must be kept after
   --  compaction.
   --
   --  The search walks backward from the newest message until at least
   --  Keep_Recent_Tokens are covered, then moves the cut back to the
   --  nearest user-message boundary so whole turns are preserved.
   --
   --  When Partial_Compact is True, the cut is additionally moved
   --  forward to the user-message boundary that leaves at least
   --  Keep_Recent_Tokens of verbatim tail, producing a partial
   --  compaction that summarises only the earlier portion (REQ-CORE-068).
   --
   --  Returns 0 when the whole history already fits within the retained
   --  budget or when no earlier user boundary exists.
   function Find_Cut_Point
     (History  : LLM.Types.Message_Vectors.Vector;
      Settings : Compact_Settings) return Natural;

   --  Serialise messages into a plain labelled text transcript suitable
   --  for a summarisation prompt.
   --
   --  Messages are separated by one blank line. Tool-result content is
   --  truncated to 2_000 characters. When a future Compaction_Summary
   --  role is present, it is rendered as "[Summary]: ...".
   function Serialize_Conversation
     (Messages : LLM.Types.Message_Vectors.Vector) return String;

end LLM.Compaction;
