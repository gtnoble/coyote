with Subagent_Integration_Tests;
with AUnit.Test_Suites;

package body Test_Integration_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Subagent_Integration_Tests.Suite);

      return Result;
   end Suite;

end Test_Integration_Suite;
