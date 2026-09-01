--  Coyote_Utils — small utility functions shared across coyote entry points.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_Utils is

   --  If Path names an existing regular file, read its entire contents and
   --  return them as a String.  Returns "" when Path is empty, does not
   --  exist, or cannot be read.
   function Read_File_If_Exists (Path : String) return String;

   --  Read the entire contents of Path as a String using Stream_IO.
   --  Returns "" when Path is empty or does not exist.
   --  Unlike Read_File_If_Exists, this does not use Text_IO.Get_Line
   --  and therefore handles files with very long (or no) line breaks
   --  without stack overflow.
   function Read_Whole_File (Path : String) return String;

   --  Return the absolute path of the executable image running this process.
   --  On Linux, prefer /proc/self/exe so the result is independent of argv[0].
   function Active_Executable_Path return String;

   --  Quote a value for use as one POSIX shell word.
   function Shell_Quote (Value : String) return String;

   --  Raised by Resolve_Text_Arg when the argument begins with '@' but
   --  the referenced file cannot be found or read.
   Bad_Arg_Error : exception;

   --  Resolve a CLI text argument that may be either a file reference or
   --  inline text.
   --
   --  When Arg begins with '@' the '@' is stripped and the remainder is
   --  treated as a file path; the file contents are read and returned.
   --  Raises Bad_Arg_Error when the path portion is empty, the file does
   --  not exist, or the file cannot be read.
   --
   --  When Arg does not begin with '@' it is returned unchanged as inline
   --  text.
   function Resolve_Text_Arg (Arg : String) return String;

   --  Strip the "coyote-session+" prefix from S if present.
   --  Returns the UUID portion; returns S unchanged if the prefix
   --  is absent.
   --
   --  Examples:
   --    "coyote-session+abc-123" -> "abc-123"
   --    "abc-123"                -> "abc-123"
   --    ""                       -> ""
   function Strip_Session_Prefix (S : String) return String;

end Coyote_Utils;
