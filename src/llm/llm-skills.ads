--  LLM.Skills ÃÂÃÂÃÂÃÂ¢ÃÂÃÂÃÂÃÂÃÂÃÂÃÂÃÂ discover and format agent skills for the system prompt.
--
--  Skills are SKILL.md files found under (in scan order):
--    ~/.coyote/skills/*/SKILL.md       (global, coyote-specific)
--    ~/.agents/skills/*/SKILL.md       (global, provider-agnostic)
--    $BASE/share/agents/skills/*/SKILL.md  (installation-relative)
--    configured skillPaths roots, in JSON array order
--    {Cwd}/.coyote/skills/*/SKILL.md   (project-local, coyote-specific)
--    {Cwd}/.agents/skills/*/SKILL.md   (project-local, provider-agnostic)
--
--  Each SKILL.md has YAML frontmatter with "name" and "description"
--  fields. Skills missing either field are silently skipped.
--
--  Project: coyote
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package LLM.Skills is

   type Skill is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      Description : Ada.Strings.Unbounded.Unbounded_String;
      Location    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Skill_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Skill);

   --  Scan the built-in roots and configured skillPaths roots (see package
   --  header) for SKILL.md files. Later roots shadow earlier names.
   --  Returns an empty vector when no skills are found.
   --  Skills missing a name or description are silently skipped.
   function Load_Skills (Cwd : String) return Skill_Vectors.Vector;

   --  Format a vector of skills into the XML-style block used in the
   --  system prompt. Returns "" when Skills is empty.
   function Format_Skills_For_Prompt
     (Skills : Skill_Vectors.Vector) return String;

   --  Derive the installation prefix ($BASE) from the binary path.
   --  Resolves the real path of Executable, then takes the parent of its
   --  parent directory (stripping bin/<name>).  Returns "" when the path
   --  is not of the expected form.
   --  Executable defaults to the active executable image path.
   function Install_Base
     (Executable : String := "") return String;

   --  Return the installation-relative skill root, or "" when
   --  Install_Base is empty (uninstalled / non-standard layout).
   --  Executable is forwarded to Install_Base.
   function Installation_Skills_Base
     (Executable : String := "") return String;

end LLM.Skills;
