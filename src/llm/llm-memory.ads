--  LLM.Memory -- structured memory system with four-type taxonomy.
--
--  Discovers MEMORY.md index files from global and project-local paths,
--  caps content at 200 lines / 25 000 bytes per file, and formats a
--  four-type memory taxonomy for inclusion in the system prompt.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package LLM.Memory is

   --  Maximum number of lines to load from a single MEMORY.md file.
   Max_Memory_Lines : constant Positive := 200;

   --  Maximum byte count to load from a single MEMORY.md file.
   Max_Memory_Bytes : constant Positive := 25_000;

   --  Discover and load MEMORY.md files from the global and project-local
   --  paths.  Each file is capped at Max_Memory_Lines lines or
   --  Max_Memory_Bytes bytes, whichever is hit first; excess content is
   --  truncated with a warning comment.  Returns "" when no MEMORY.md
   --  files are found.
   --
   --  Search order:
   --    1. ~/.coyote/memory/MEMORY.md  (global)
   --    2. {Cwd}/.coyote/MEMORY.md     (project-local)
   function Load_Memory_Index (Cwd : String) return String;

   --  Return the four-type memory taxonomy description block for
   --  inclusion in the system prompt.  Describes user, feedback, project,
   --  and reference memory types with when_to_save and how_to_use
   --  guidance for each, plus instructions to search existing memories
   --  before writing and to maintain the MEMORY.md index.
   function Format_Memory_Taxonomy_For_Prompt return String;

end LLM.Memory;
