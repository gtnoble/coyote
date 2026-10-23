with Coyote_Process_Control_Tests;
with Coyote_Signal_Shutdown_Tests;

package body Test_Process_Control_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_Signal_Shutdown_Tests.Suite);
      Result.Add_Test (Coyote_Process_Control_Tests.Suite);

      return Result;
   end Suite;

end Test_Process_Control_Suite;
