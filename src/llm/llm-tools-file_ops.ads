--  LLM.Tools.File_Ops — built-in file-manipulation tools.
--
--  Provides the standard read, write, edit, find, and glob tools used by
--  the native harness.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Tools.File_Ops is

   --  Return the descriptor for the built-in read tool.
   function Read_Descriptor return Tool_Descriptor;

   --  Return the descriptor for the built-in write tool.
   function Write_Descriptor return Tool_Descriptor;

   --  Return the descriptor for the built-in edit tool.
   function Edit_Descriptor return Tool_Descriptor;

   --  Return the descriptor for the built-in find tool.
   function Find_Descriptor return Tool_Descriptor;

   --  Return the descriptor for the built-in glob tool.
   function Glob_Descriptor return Tool_Descriptor;

   --  Read a file.
   --
   --  Args_Json must provide a string field "path" and may provide integer
   --  fields "offset" and "limit".  When offset or limit is present, the
   --  result is sliced by lines using 1-based line numbering.
   procedure Execute_Read
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

   --  Write a file.
   --
   --  Args_Json must provide string fields "path" and "content".
   --  Parent directories are created automatically and the target file is
   --  overwritten.
   procedure Execute_Write
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

   --  Edit a file by replacing exactly one occurrence of oldText.
   --
   --  Args_Json must provide string fields "path", "oldText", and
   --  "newText".  The operation fails when oldText is missing or appears
   --  more than once.
   procedure Execute_Edit
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

   --  Recursively list matching files under a directory tree.
   --
   --  Args_Json must provide a string field "path" and may provide a
   --  string field "pattern".  The pattern is matched against simple file
   --  names using shell-style '*' and '?' wildcards.
   procedure Execute_Find
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

   --  Alias for Execute_Find.
   procedure Execute_Glob
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

end LLM.Tools.File_Ops;
