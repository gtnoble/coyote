--  LLM.Tools.File_Ops — built-in file-manipulation tools.
--
--  Provides the standard read, write, edit, find, and glob tools used by
--  the native harness.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Tools.File_Ops is

   --  Descriptor for the built-in read tool.
   Read_Descriptor : constant Tool_Descriptor :=
     (Name        => Ada.Strings.Unbounded.To_Unbounded_String ("read"),
      Description => Ada.Strings.Unbounded.To_Unbounded_String
        ("Read a file, optionally restricted to a line range."),
      Schema_Json => Ada.Strings.Unbounded.To_Unbounded_String
        ("{""type"":""object"",""properties"":{"
         & """path"":{""type"":""string"",""description"":"
         & """Path to the file to read""},"
         & """offset"":{""type"":""integer"",""description"":"
         & """Optional 1-based starting line number""},"
         & """limit"":{""type"":""integer"",""description"":"
         & """Optional maximum number of lines to return""}},"
         & """required"":[""path""]}"));

   --  Descriptor for the built-in write tool.
   Write_Descriptor : constant Tool_Descriptor :=
     (Name        => Ada.Strings.Unbounded.To_Unbounded_String ("write"),
      Description => Ada.Strings.Unbounded.To_Unbounded_String
        ("Write a file, creating parent directories when needed."),
      Schema_Json => Ada.Strings.Unbounded.To_Unbounded_String
        ("{""type"":""object"",""properties"":{"
         & """path"":{""type"":""string"",""description"":"
         & """Path to the file to write""},"
         & """content"":{""type"":""string"",""description"":"
         & """Complete file content to write""}},"
         & """required"":[""path"",""content""]}"));

   --  Descriptor for the built-in edit tool.
   Edit_Descriptor : constant Tool_Descriptor :=
     (Name        => Ada.Strings.Unbounded.To_Unbounded_String ("edit"),
      Description => Ada.Strings.Unbounded.To_Unbounded_String
        ("Replace exactly one matching text fragment in a file."),
      Schema_Json => Ada.Strings.Unbounded.To_Unbounded_String
        ("{""type"":""object"",""properties"":{"
         & """path"":{""type"":""string"",""description"":"
         & """Path to the file to edit""},"
         & """oldText"":{""type"":""string"",""description"":"
         & """Exact text to replace""},"
         & """newText"":{""type"":""string"",""description"":"
         & """Replacement text""}},"
         & """required"":[""path"",""oldText"",""newText""]}"));

   --  Descriptor for the built-in find tool.
   Find_Descriptor : constant Tool_Descriptor :=
     (Name        => Ada.Strings.Unbounded.To_Unbounded_String ("find"),
      Description => Ada.Strings.Unbounded.To_Unbounded_String
        ("Recursively list files whose names match an optional pattern."),
      Schema_Json => Ada.Strings.Unbounded.To_Unbounded_String
        ("{""type"":""object"",""properties"":{"
         & """path"":{""type"":""string"",""description"":"
         & """Directory or file path to search""},"
         & """pattern"":{""type"":""string"",""description"":"
         & """Optional file-name glob pattern""}},"
         & """required"":[""path""]}"));

   --  Descriptor for the built-in glob tool.
   Glob_Descriptor : constant Tool_Descriptor :=
     (Name        => Ada.Strings.Unbounded.To_Unbounded_String ("glob"),
      Description => Ada.Strings.Unbounded.To_Unbounded_String
        ("Alias for find: recursively list files matching a pattern."),
      Schema_Json => Ada.Strings.Unbounded.To_Unbounded_String
        ("{""type"":""object"",""properties"":{"
         & """path"":{""type"":""string"",""description"":"
         & """Directory or file path to search""},"
         & """pattern"":{""type"":""string"",""description"":"
         & """Optional file-name glob pattern""}},"
         & """required"":[""path""]}"));

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
