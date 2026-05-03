--  LLM.Tools.Bash — execute shell commands for the native harness.
--
--  Provides the built-in bash tool descriptor and its JSON-argument
--  executor.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Tools.Bash is

   --  Return the descriptor for the built-in bash tool.
   function Descriptor return Tool_Descriptor;

   --  Execute the bash tool with Args_Json.
   --
   --  Args_Json must provide a required string field "command" and may
   --  provide an ignored optional string field "description".
   --
   --  Result receives the combined stdout/stderr text.  Is_Error is True
   --  when the arguments are invalid or the command exits non-zero.
   procedure Execute
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

end LLM.Tools.Bash;
