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
with GNATCOLL.JSON;

package LLM.Tools.Sandbox is

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   type Profile is record
      Allow_Write : String_Vectors.Vector := String_Vectors.Empty_Vector;
      Deny_Write  : String_Vectors.Vector := String_Vectors.Empty_Vector;
      Deny_Read   : String_Vectors.Vector := String_Vectors.Empty_Vector;
      Allow_Read  : String_Vectors.Vector := String_Vectors.Empty_Vector;
   end record;

   Sandbox_Error : exception;

   --  Return whether Name is safe for use as a profile file stem.
   function Is_Valid_Profile_Name (Name : String) return Boolean;

   --  Load a validated, typed profile.  Raises Sandbox_Error when the name
   --  or profile file is invalid, missing, malformed, or cannot be read.
   function Load_Profile_Typed (Name : String) return Profile;

   --  Save a profile, replacing an existing regular file atomically.
   procedure Save_Profile (Name : String; Value : Profile);

   --  Edit_Profile is the explicit replacement form of Save_Profile.
   procedure Edit_Profile (Name : String; Value : Profile);

   --  Create a profile without replacing an existing profile.
   procedure Create_Profile (Name : String; Value : Profile);

   --  Copy a profile to a new name without sharing mutable vector state.
   procedure Copy_Profile (Source_Name : String; Target_Name : String);

   --  Create New_Name from Old_Name and retain Old_Name for session history.
   procedure Rename_Profile (Old_Name : String; New_Name : String);

   --  Return the names of all available sandbox profiles (stems of
   --  *.json files under ~/.coyote/sandbox/).  Returns an empty vector
   --  when no profiles exist or the sandbox directory is absent.
   function Available_Profiles return String_Vectors.Vector;

   --  Load the legacy JSON representation.  Returns JSON_Null when the
   --  profile is not found, invalid, or malformed.
   function Load_Profile
     (Name : String) return GNATCOLL.JSON.JSON_Value;

   --  Build the bwrap argument list for the given profile and working
   --  directory.  Returns an empty list when Profile_Name is empty
   --  (no sandbox).  Paths are resolved relative to Cwd and checked
   --  for existence; missing paths are silently skipped to match
   --  sandshell's behaviour.  A non-empty invalid, missing, or malformed
   --  profile raises Sandbox_Error.
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
