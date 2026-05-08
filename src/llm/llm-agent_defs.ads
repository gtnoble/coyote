--  LLM.Agent_Defs — discover and format agent definitions for the system
--  prompt.
--
--  Agent definitions are AGENT.md files found under (in scan order):
--    ~/.coyote/agents/*/AGENT.md       (global, coyote-specific)
--    ~/.agents/agents/*/AGENT.md       (global, provider-agnostic)
--    {Cwd}/.coyote/agents/*/AGENT.md   (project-local, coyote-specific)
--    {Cwd}/.agents/agents/*/AGENT.md   (project-local, provider-agnostic)
--
--  Each AGENT.md has YAML frontmatter with "name" and "description"
--  fields followed by the agent system-prompt body.  Definitions
--  missing either frontmatter field are silently skipped.  When two
--  definitions share the same name the later entry (more project-local)
--  shadows the earlier one.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Agent_Defs is

   type Agent_Def is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      Description : Ada.Strings.Unbounded.Unbounded_String;
      Location    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Agent_Def_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Agent_Def);

   --  Raised by Resolve_Agent_Def when no definition with the given name
   --  exists in the supplied vector, or when the definition file cannot
   --  be read.
   Agent_Not_Found : exception;

   --  Scan all four agent roots (see package header) for AGENT.md files.
   --  Returns an empty vector when no definitions are found.
   --  Definitions missing a name or description are silently skipped.
   --  When two definitions share the same name the later one wins.
   function Load_Agent_Defs
     (Cwd : String) return Agent_Def_Vectors.Vector;

   --  Return the body text of the AGENT.md identified by Name.
   --  The body is the portion of the file after the closing "---"
   --  frontmatter delimiter.
   --  Raises Agent_Not_Found when no entry with that name exists in Defs
   --  or when the file at its location cannot be read.
   function Resolve_Agent_Def
     (Name : String;
      Defs : Agent_Def_Vectors.Vector) return String;

   --  Format a vector of agent definitions into the XML-style block
   --  injected into the system prompt.  Returns "" when Defs is empty.
   function Format_Agent_Defs_For_Prompt
     (Defs : Agent_Def_Vectors.Vector) return String;

end LLM.Agent_Defs;
