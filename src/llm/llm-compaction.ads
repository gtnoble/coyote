--  LLM.Compaction — pure helpers for context compaction decisions.
--
--  Provides conservative token estimation, compaction-threshold checks,
--  cut-point selection, and transcript serialisation for summarisation.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with LLM.Types;

package LLM.Compaction is

   --  Settings controlling when context compaction is eligible and how
   --  much recent history must be retained verbatim.
   type Compact_Settings is record
      Enabled            : Boolean := True;
      Reserve_Tokens     : Positive := 16_384;
      Keep_Recent_Tokens : Positive := 20_000;
   end record;

   --  Default compaction settings used when no override is configured.
   Default_Compact_Settings : constant Compact_Settings :=
     (Enabled            => True,
      Reserve_Tokens     => 16_384,
      Keep_Recent_Tokens => 20_000);

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

   --  User prompt for the initial structured compaction summary.
   Summarization_Prompt : constant String :=
     "The messages above are a conversation to summarize. Create a"
     & " structured context checkpoint summary that another LLM will use"
     & " to continue the work."
     & ASCII.LF & ASCII.LF
     & "Use this EXACT format:"
     & ASCII.LF & ASCII.LF
     & "## Goal"
     & ASCII.LF
     & "[What is the user trying to accomplish? Can be multiple items if"
     & " the session covers different tasks.]"
     & ASCII.LF & ASCII.LF
     & "## Constraints & Preferences"
     & ASCII.LF
     & "- [Any constraints, preferences, or requirements mentioned by"
     & " user]"
     & ASCII.LF
     & "- [Or ""(none)"" if none were mentioned]"
     & ASCII.LF & ASCII.LF
     & "## Progress"
     & ASCII.LF
     & "### Done"
     & ASCII.LF
     & "- [x] [Completed tasks/changes]"
     & ASCII.LF & ASCII.LF
     & "### In Progress"
     & ASCII.LF
     & "- [ ] [Current work]"
     & ASCII.LF & ASCII.LF
     & "### Blocked"
     & ASCII.LF
     & "- [Issues preventing progress, if any]"
     & ASCII.LF & ASCII.LF
     & "## Key Decisions"
     & ASCII.LF
     & "- **[Decision]**: [Brief rationale]"
     & ASCII.LF & ASCII.LF
     & "## Next Steps"
     & ASCII.LF
     & "1. [Ordered list of what should happen next]"
     & ASCII.LF & ASCII.LF
     & "## Critical Context"
     & ASCII.LF
     & "- [Any data, examples, or references needed to continue]"
     & ASCII.LF
     & "- [Or ""(none)"" if not applicable]"
     & ASCII.LF & ASCII.LF
     & "Keep each section concise. Preserve exact file paths, function"
     & " names, and error messages.";

   --  User prompt for updating an existing structured compaction summary
   --  with newer conversation messages.
   Update_Summarization_Prompt : constant String :=
     "The messages above are NEW conversation messages to incorporate"
     & " into the existing summary provided in <previous-summary> tags."
     & ASCII.LF & ASCII.LF
     & "Update the existing structured summary with new information."
     & " RULES:"
     & ASCII.LF
     & "- PRESERVE all existing information from the previous summary"
     & ASCII.LF
     & "- ADD new progress, decisions, and context from the new messages"
     & ASCII.LF
     & "- UPDATE the Progress section: move items from ""In Progress"""
     & " to ""Done"" when completed"
     & ASCII.LF
     & "- UPDATE ""Next Steps"" based on what was accomplished"
     & ASCII.LF
     & "- PRESERVE exact file paths, function names, and error messages"
     & ASCII.LF
     & "- If something is no longer relevant, you may remove it"
     & ASCII.LF & ASCII.LF
     & "Use this EXACT format:"
     & ASCII.LF & ASCII.LF
     & "## Goal"
     & ASCII.LF
     & "[Preserve existing goals, add new ones if the task expanded]"
     & ASCII.LF & ASCII.LF
     & "## Constraints & Preferences"
     & ASCII.LF
     & "- [Preserve existing, add new ones discovered]"
     & ASCII.LF & ASCII.LF
     & "## Progress"
     & ASCII.LF
     & "### Done"
     & ASCII.LF
     & "- [x] [Include previously done items AND newly completed items]"
     & ASCII.LF & ASCII.LF
     & "### In Progress"
     & ASCII.LF
     & "- [ ] [Current work - update based on progress]"
     & ASCII.LF & ASCII.LF
     & "### Blocked"
     & ASCII.LF
     & "- [Current blockers - remove if resolved]"
     & ASCII.LF & ASCII.LF
     & "## Key Decisions"
     & ASCII.LF
     & "- **[Decision]**: [Brief rationale] (preserve all previous, add"
     & " new)"
     & ASCII.LF & ASCII.LF
     & "## Next Steps"
     & ASCII.LF
     & "1. [Update based on current state]"
     & ASCII.LF & ASCII.LF
     & "## Critical Context"
     & ASCII.LF
     & "- [Preserve important context, add new if needed]"
     & ASCII.LF & ASCII.LF
     & "Keep each section concise. Preserve exact file paths, function"
     & " names, and error messages.";

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
   --  window minus the configured reserve.
   --
   --  When compaction is disabled in Settings, this function always
   --  returns False.
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
