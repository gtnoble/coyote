--  LLM.Tools.Bash — execute shell commands for the native harness.
--
--  Provides the built-in bash tool descriptor and its JSON-argument
--  executor.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Tools.Bash is

   --  Descriptor for the built-in bash tool.
   Descriptor : constant Tool_Descriptor :=
     (Name        => Ada.Strings.Unbounded.To_Unbounded_String ("bash"),
      Description => Ada.Strings.Unbounded.To_Unbounded_String
        ("Execute a shell command and return its combined output."),
      Schema_Json => Ada.Strings.Unbounded.To_Unbounded_String
        ("{""type"":""object"",""properties"":{"
         & """command"":{""type"":""string"",""description"":"
         & """The shell command to execute""},"
         & """description"":{""type"":""string"",""description"":"
         & """Optional description of what the command does""}},"
         & """required"":[""command""]}"));

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
