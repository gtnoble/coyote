--  LLM.Tools.Spawn_Subagent — spawn an ephemeral subagent window.
--
--  Provides the built-in spawn_subagent tool descriptor and its
--  JSON-argument executor.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Tools.Spawn_Subagent is

   --  Return the descriptor for the built-in spawn_subagent tool.
   function Descriptor return Tool_Descriptor;

   --  Execute the spawn_subagent tool with Args_Json.
   --
   --  Args_Json must provide a required non-empty string field "prompt"
   --  and may provide optional string fields "model", "agent", and
   --  "name".
   --
   --  Result receives the final subagent output text on success or a
   --  diagnostic message on failure.  Is_Error is True when the arguments
   --  are invalid, the subprocess reports an error, or no valid JSON
   --  result line is produced.
   procedure Execute
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

end LLM.Tools.Spawn_Subagent;
