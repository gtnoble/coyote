--  LLM.Tools.Spawn_Subagent — spawn an ephemeral subagent window.
--
--  Provides the built-in spawn_subagent tool descriptor and its
--  JSON-argument executor.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Tools.Spawn_Subagent is

   --  Descriptor for the built-in spawn_subagent tool.
   Descriptor : constant Tool_Descriptor :=
     (Name        => Ada.Strings.Unbounded.To_Unbounded_String
        ("spawn_subagent"),
      Description => Ada.Strings.Unbounded.To_Unbounded_String
        ("Spawn a subagent in a new coyote window and return its response."
         & " The window closes automatically when the turn completes."
         & " Subagents are ephemeral and do not persist sessions."),
      Schema_Json => Ada.Strings.Unbounded.To_Unbounded_String
        ("{""type"":""object"",""properties"":{"
         & """prompt"":{""type"":""string"",""description"":"
         & """Task or question for the subagent.""},"
         & """model"":{""type"":""string"",""description"":"
         & """Model to use in provider/model-id form. Defaults to the"
         & " current model.""},"
         & """agent"":{""type"":""string"",""description"":"
         & """System-prompt text or path to an .agent.md file for the"
         & " subagent.""},"
         & """name"":{""type"":""string"",""description"":"
         & """Short label for the subagent window tagline.""}},"
         & """required"":[""prompt""]}"));

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
