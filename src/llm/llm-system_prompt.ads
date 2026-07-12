--  LLM.System_Prompt -- construct the default coding-agent system prompt.
--
--  Build_System_Prompt assembles the complete system prompt sent to the
--  LLM on every request. All parameters are optional; the function is
--  safe to call with only Cwd supplied.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package LLM.System_Prompt is

   --  Build and return the full system prompt string.
   --
   --  Cwd              : working directory appended as "Current working
   --                     directory: <Cwd>" at the very end of the prompt.
   --  No_Tools         : when True the tool list and tool-related
   --                     guidelines are omitted entirely.
   --  Has_Editing_Tools: when True, conditional instructions prefer
   --                     editing tools over printing code blocks; when
   --                     False, code blocks are suggested (REQ-CORE-171).
   --  Agent            : appended verbatim after the preamble/guidelines
   --                     block when non-empty.
   --  Context_Sections : pre-formatted project-context block (produced by
   --                     Load_Context_Sections in Task D); appended after
   --                     the preamble block when non-empty.
   --  Skills_Section   : pre-formatted skills block (produced by
   --                     LLM.Skills in Task E); appended after
   --                     Context_Sections when non-empty.
   --  Memory_Block     : pre-formatted memory index content from
   --                     LLM.Memory.Load_Memory_Index; appended before
   --                     Skills_Section when non-empty.
   --  Coordinator_Mode : when True and No_Tools is False, the prompt
   --                     includes coordinator subagent-orchestration
   --                     guidance (REQ-CORE-190..192).
   --
   --  The current date (YYYY-MM-DD) and Cwd are always appended last,
   --  regardless of which other parameters are set.
   function Build_System_Prompt
     (Cwd                : String;
      No_Tools           : Boolean := False;
      Has_Editing_Tools  : Boolean := False;
      Agent              : String  := "";
      Context_Sections   : String  := "";
      Skills_Section     : String  := "";
      Memory_Block       : String  := "";
      Coordinator_Mode   : Boolean := False) return String;

   --  Return per-turn reminder instructions for appending to each user
   --  prompt (REQ-CORE-172).  The instructions reinforce: persist until
   --  the task is completely resolved; report progress after 3-5 tool
   --  calls with varied, concise updates; avoid repeating verbatim plans;
   --  preface each tool batch with a one-sentence preamble.
   --
   --  Has_Tools: when True, the reminder references tool-call progress;
   --  when False, the tool-specific guidance is omitted.
   function Build_Reminder_Instructions
     (Has_Tools : Boolean := False) return String;

   --  Scan the filesystem for project-context markdown files and return a
   --  pre-formatted block suitable for injection into Build_System_Prompt.
   --
   --  Returns "" when no context files are found.
   --
   --  Search order (mirrors the coyote agent):
   --    1. Global:  ~/.coyote/context/*.md  (alphabetical)
   --    2. Project: {Cwd}/.coyote/context/*.md  (alphabetical)
   --    3. Root:    {Cwd}/AGENTS.md  (if the file exists)
   --
   --  Each file is rendered as:
   --
   --    ## /absolute/path/to/file
   --
   --    <file contents>
   --
   --  The entire result is wrapped in:
   --
   --    # Project Context
   --
   --    Project-specific instructions and guidelines:
   --
   --    <sections>
   function Load_Context_Sections (Cwd : String) return String;

end LLM.System_Prompt;
