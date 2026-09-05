with AUnit.Test_Suites;
with Test_Core_Suite;
with Test_LLM_Suite;
with Test_SQC_Suite;
with Test_GUI_Suite;
with Test_Integration_Suite;
with Test_Process_Control_Suite;

package body Test_Suites is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Test_Core_Suite.Suite);
      Result.Add_Test (Test_LLM_Suite.Suite);
      Result.Add_Test (Test_SQC_Suite.Suite);
      Result.Add_Test (Test_GUI_Suite.Suite);
      Result.Add_Test (Test_Integration_Suite.Suite);
      --  Process-control tests must remain last because the controller
      --  intentionally retains process-wide shutdown and persistence state.
      Result.Add_Test (Test_Process_Control_Suite.Suite);
      return Result;
   end Suite;

end Test_Suites;
