--  LLM.Tools.Shell — execute shell commands for the native harness.
--
--  Provides the built-in shell tool descriptor and its JSON-argument
--  executor.  Commands are run via the user's $SHELL (defaulting to
--  /bin/sh when the variable is unset).
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Tools.Shell is

   --  Return the descriptor for the built-in shell tool.
   function Descriptor return Tool_Descriptor;

   --  Execute the shell tool with Args_Json.
   --
   --  Args_Json must provide a required string field "command" and may
   --  provide an optional string field "description" (ignored by the
   --  executor), an optional string field "stdin" whose value is written to
   --  the command's standard input before reading output, and an optional
   --  string field "media_type".
   --
   --  When "media_type" is non-empty the command's stdout is treated as raw
   --  binary data: the bytes are base64-encoded and returned in Result, and
   --  Media_Type is set to the given MIME type (e.g. "image/png").  The
   --  caller is responsible for forming the appropriate image content block.
   --  When "media_type" is absent or empty the tool behaves as plain text
   --  (the current default).
   --
   --  When "stdin" is absent or empty the command reads from /dev/null.
   --
   --  When "timeout" is present and positive the command is automatically
   --  terminated after that many seconds.  The combined output collected up
   --  to that point is returned as Result with a timeout notice appended.
   --  A timeout of 0 or a missing / non-integer "timeout" field disables
   --  the timer (the default: no per-command time limit).
   --
   --  Result receives the combined stdout/stderr text (or base64-encoded
   --  image bytes when media_type is non-empty).  Media_Type receives the
   --  value of the "media_type" argument, or an empty Unbounded_String when
   --  absent.  Is_Error is True when the arguments are invalid or the
   --  command exits non-zero.
   procedure Execute
     (Args_Json       :     String;
      Result          : out Ada.Strings.Unbounded.Unbounded_String;
      Media_Type      : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error        : out Boolean;
      Abort_Flg       : access LLM.Tools.Abort_Flag := null;
      Sandbox_Profile :     String := "");

end LLM.Tools.Shell;
