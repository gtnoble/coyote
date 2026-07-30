--  LLM.Tools.Sandbox — sandbox profile discovery and bwrap argument
--  construction for the shell tool.
--
--  Profiles are JSON files stored in ~/.coyote/sandbox/*.json.  Each
--  profile defines four rule types: allowWrite, denyWrite, denyRead,
--  allowRead.  When a profile is active, shell commands are wrapped
--  with bubblewrap (bwrap) to restrict filesystem access.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with GNATCOLL.JSON;

package LLM.Tools.Sandbox is

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   --  Return the names of all available sandbox profiles (stems of
   --  *.json files under ~/.coyote/sandbox/).  Returns an empty vector
   --  when no profiles exist or the sandbox directory is absent.
   function Available_Profiles return String_Vectors.Vector;

   --  Load the rules for a named profile.  Returns a JSON object with
   --  the four rule-type keys, or JSON_Null when the profile is not
   --  found.
   function Load_Profile
     (Name : String) return GNATCOLL.JSON.JSON_Value;

   --  Build the bwrap argument list for the given profile and working
   --  directory.  Returns an empty list when Profile_Name is empty
   --  (no sandbox).  Paths are resolved relative to Cwd and checked
   --  for existence; missing paths are silently skipped to match
   --  sandshell's behaviour.
   --
   --  The returned arguments are the bwrap-specific portion only
   --  (--ro-bind, --bind, --tmpfs directives).  The caller is
   --  responsible for prepending "bwrap" and appending "--" before
   --  the command.
   function Build_Bwrap_Args
     (Profile_Name : String;
      Cwd         : String) return String_Vectors.Vector;

   --  Return the full path to the sandbox profile directory.
   --  Empty string when $HOME is not set.
   function Profiles_Dir return String;

end LLM.Tools.Sandbox;
