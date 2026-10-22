--  Coyote_Image_Jobs_Tests — bounded asynchronous image-job coverage.
--
--  Project: coyote

with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded;

package Coyote_Image_Jobs_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Root : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Queue_Bounds_And_Synchronous_Rejection (T : in out Test);
   procedure Test_Success_And_Failure_Release_Capacity (T : in out Test);
   procedure Test_Callback_Exception_Does_Not_Strands_Jobs (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Image_Jobs_Tests;
