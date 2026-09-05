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
with AUnit.Test_Suites;

package LLM_Parallel_Tools_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Two bash "sleep 0.4" tools run in parallel; elapsed wall time must be
   --  less than 0.75 s and both results must appear in the correct order.
   procedure Test_Parallel_Tools_Run_Concurrently (T : in out Test);

   --  Abort is requested while two tools are running; the agent ends with
   --  Was_Aborted = True and only the user prompt is persisted.
   procedure Test_Parallel_Abort_During_Batch (T : in out Test);

   --  Two tools without run_group execute sequentially (default behaviour).
   procedure Test_Tools_Run_Sequentially_By_Default (T : in out Test);

   --  Three tools in two groups: group 1 runs first in parallel, then
   --  group 2 runs in parallel after group 1 completes.
   procedure Test_Tools_Run_In_Group_Order (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Parallel_Tools_Tests;
