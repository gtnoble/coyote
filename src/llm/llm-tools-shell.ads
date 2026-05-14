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
   --  executor) and an optional string field "stdin" whose value is
   --  written to the command's standard input before reading output.
   --  When "stdin" is absent or empty the command reads from /dev/null.
   --
   --  Result receives the combined stdout/stderr text.  Is_Error is True
   --  when the arguments are invalid or the command exits non-zero.
   procedure Execute
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

end LLM.Tools.Shell;
