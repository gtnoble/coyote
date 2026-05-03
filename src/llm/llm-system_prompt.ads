--  LLM.System_Prompt — construct the default coding-agent system prompt.
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
   --  Custom_Prompt    : when non-empty, replaces the default preamble +
   --                     tools + guidelines block verbatim.
   --  Append_Prompt    : appended verbatim after the preamble/guidelines
   --                     block (and after Custom_Prompt when that is
   --                     used).
   --  Context_Sections : pre-formatted project-context block (produced by
   --                     Load_Context_Sections in Task D); appended after
   --                     the preamble block when non-empty.
   --  Skills_Section   : pre-formatted skills block (produced by
   --                     LLM.Skills in Task E); appended after
   --                     Context_Sections when non-empty.
   --
   --  The current date (YYYY-MM-DD) and Cwd are always appended last,
   --  regardless of which other parameters are set.
   function Build_System_Prompt
     (Cwd              : String;
      No_Tools         : Boolean := False;
      Custom_Prompt    : String  := "";
      Append_Prompt    : String  := "";
      Context_Sections : String  := "";
      Skills_Section   : String  := "") return String;

   --  Scan the filesystem for project-context markdown files and return a
   --  pre-formatted block suitable for injection into Build_System_Prompt.
   --
   --  Returns "" when no context files are found.
   --
   --  Search order (mirrors the pi coding agent):
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
