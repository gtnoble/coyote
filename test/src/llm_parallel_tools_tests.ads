--  LLM_Parallel_Tools_Tests — AUnit tests for parallel tool-call execution.
--
--  These tests verify that when the agent receives multiple tool calls in a
--  single assistant turn they are dispatched in parallel rather than
--  sequentially, and that abort during a parallel batch leaves session history
--  in a valid state.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package LLM_Parallel_Tools_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Two bash "sleep 0.4" tools run in parallel; elapsed wall time must be
   --  less than 0.75 s and both results must appear in the correct order.
   procedure Test_Parallel_Tools_Run_Concurrently (T : in out Test);

   --  Abort is requested while two tools are running; the agent ends with
   --  Was_Aborted = True and only the user prompt is persisted.
   procedure Test_Parallel_Abort_During_Batch (T : in out Test);

end LLM_Parallel_Tools_Tests;
