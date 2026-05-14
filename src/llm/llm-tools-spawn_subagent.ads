--  LLM.Tools.Spawn_Subagent — spawn one or more ephemeral subagent windows.
--
--  Provides the built-in spawn_subagent tool descriptor and its
--  JSON-argument executor.
--
--  Single-agent mode (existing behaviour):
--    Provide "prompt" (required) and optionally "model", "agent",
--    "custom_prompt", "name", and "prompt_filter".
--
--  Multi-agent mode (new):
--    Provide "names" (a JSON array of strings) instead of "name".
--    All subagents are spawned in parallel.  Results are returned
--    as labelled sections, one per agent.
--
--  prompt_filter:
--    Optional shell command piped with the raw prompt on stdin.
--    The environment variable COYOTE_SUBAGENT_NAME is set to the
--    current agent name before each invocation.  Stdout becomes the
--    effective prompt for that subagent.  Useful for m4 macro expansion:
--    e.g. "m4 -DAGENT=$COYOTE_SUBAGENT_NAME".
--    Falls back to the raw prompt on any filter error.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Tools.Spawn_Subagent is

   --  Return the descriptor for the built-in spawn_subagent tool.
   function Descriptor return Tool_Descriptor;

   --  Execute the spawn_subagent tool with Args_Json.
   --
   --  Single-agent mode: Args_Json must provide a required non-empty
   --  string field "prompt" and may provide optional string fields
   --  "model", "agent", "custom_prompt", "name", and "prompt_filter".
   --
   --  Multi-agent mode: as above but with "names" (a non-empty JSON
   --  array of strings) in place of "name".  "name" and "names" must
   --  not both be present.
   --
   --  Result receives the final subagent output text on success or a
   --  diagnostic message on failure.  Is_Error is True when the
   --  arguments are invalid, the subprocess reports an error, or no
   --  valid JSON result line is produced.  In multi-agent mode
   --  Is_Error is False as long as at least one subagent succeeds;
   --  individual agent errors are embedded inline in Result.
   procedure Execute
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null);

end LLM.Tools.Spawn_Subagent;
