--  Coyote_Process_Control_Tests — shutdown controller coverage.
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_Process_Control_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Grace_Clamps (T : in out Test);
   procedure Test_Launches_Reject_After_Shutdown (T : in out Test);
   procedure Test_Persistence_Freezes (T : in out Test);

end Coyote_Process_Control_Tests;
