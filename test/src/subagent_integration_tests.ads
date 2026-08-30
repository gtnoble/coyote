with AUnit;
with AUnit.Test_Fixtures;

--  Integration tests for the coyote --one-shot (subagent) mode.
--
--  Each test spawns bin/coyote with --one-shot and verifies the JSON
--  result line written to stdout. Tests require the configured
--  github-copilot/gpt-5-mini model.

package Subagent_Integration_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Happy-path: one-shot prints a JSON line whose "output" field
   --  contains the expected word "PONG" and whose "session_id" is a
   --  well-formed 36-character UUID.
   procedure Test_One_Shot_Returns_Json
     (T : in out Test);

   --  --one-shot implies --no-session: each invocation opens a fresh coyote
   --  session, so two consecutive runs must return distinct session IDs.
   procedure Test_One_Shot_Fresh_Session_Each_Run
     (T : in out Test);

   --  Prompt-failure path: when Run_Prompt raises an exception (e.g. an
   --  HTTP 4xx from an invalid API key), the one-shot result JSON must
   --  still carry a "session_id" field alongside the "error" field.
   procedure Test_One_Shot_Prompt_Failure_Has_Session_Id
     (T : in out Test);

   --  A nested --subagent invocation must be rejected before frontend startup
   --  when the configured maximum depth has already been reached.
   procedure Test_Subagent_Recursion_Limit (T : in out Test);

end Subagent_Integration_Tests;
