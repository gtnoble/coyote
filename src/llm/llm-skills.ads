--  LLM.Skills — discover and format agent skills for the system prompt.
--
--  Skills are SKILL.md files found under:
--    ~/.coyote/skills/*/SKILL.md       (global)
--    {Cwd}/.coyote/skills/*/SKILL.md   (project-local)
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

   --  Scan ~/.coyote/skills/ and {Cwd}/.coyote/skills/ for SKILL.md files.
   --  Returns an empty vector when no skills are found.
   --  Skills missing a name or description are silently skipped.
   function Load_Skills (Cwd : String) return Skill_Vectors.Vector;

   --  Format a vector of skills into the XML-style block used in the
   --  system prompt. Returns "" when Skills is empty.
   function Format_Skills_For_Prompt
     (Skills : Skill_Vectors.Vector) return String;

end LLM.Skills;
