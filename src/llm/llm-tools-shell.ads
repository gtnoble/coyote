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
   --  binary image data.  Only supported image MIME types are accepted;
   --  stdout must have the matching image signature before the bytes are
   --  base64-encoded and returned in Result with Media_Type set.
   --  When "media_type" is absent or empty the tool behaves as plain text
   --  (the current default).
   --
   --  When "stdin" is absent or empty the command reads from /dev/null.
   --
   --  When "timeout" is present and positive the command is automatically
   --  terminated after that many seconds.  SIGTERM is sent first, followed
   --  by the configured shell termination grace period and SIGKILL if the
   --  process group is still running.  The combined output collected up to
   --  that point is returned as Result with a timeout notice appended.
   --  A timeout of 0 or a missing / non-integer "timeout" field disables
   --  the timer (the default: no per-command time limit).
   --
   --  Result receives combined stdout/stderr text for plain-text commands.
   --  For image commands, Result contains base64-encoded stdout only after
   --  the MIME type and matching image signature have been validated.
   --  Media_Type receives the canonical image MIME type, or an empty
   --  Unbounded_String when absent or when image validation fails.
   type Execution_Status is (Completed, Failed, Timed_Out, Aborted);

   --  Is_Error is True when the arguments are invalid or the
   --  command exits non-zero.
   procedure Execute
     (Args_Json       :     String;
      Result          : out Ada.Strings.Unbounded.Unbounded_String;
      Media_Type      : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error        : out Boolean;
      Abort_Flg       : access LLM.Tools.Abort_Flag := null;
      Sandbox_Profile :     String := "");

   --  Execute while returning the structured process termination cause.
   procedure Execute_With_Status
     (Args_Json       :     String;
      Result          : out Ada.Strings.Unbounded.Unbounded_String;
      Media_Type      : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error        : out Boolean;
      Status          : out Execution_Status;
      Abort_Flg       : access LLM.Tools.Abort_Flag := null;
      Sandbox_Profile :     String := "");
end LLM.Tools.Shell;
