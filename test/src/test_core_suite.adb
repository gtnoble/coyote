with Session_Lister_Tests;
with Coyote_App_Agent_Registry_Tests;
with Coyote_App_Agent_RPC_Service_Tests;
with Coyote_App_Agent_RPC_Tests;
with Coyote_App_Agent_RPC_Transport_Tests;
with Coyote_App_Tests;
with Coyote_Utils_Tests;
with Collapse_Utils_Tests;
with Model_Row_Match_Tests;
with Coyote_Cmark_Tests;
with Sandbox_Tests;
with Coyote_Help_Tests;
with Coyote_Lasem_Tests;
with AUnit.Test_Suites;

package body Test_Core_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Session_Lister_Tests.Suite);
      Result.Add_Test (Coyote_App_Agent_Registry_Tests.Suite);
      Result.Add_Test (Coyote_App_Agent_RPC_Service_Tests.Suite);
      Result.Add_Test (Coyote_App_Agent_RPC_Tests.Suite);
      Result.Add_Test (Coyote_App_Agent_RPC_Transport_Tests.Suite);
      Result.Add_Test (Coyote_App_Tests.Suite);
      Result.Add_Test (Coyote_Utils_Tests.Suite);
      Result.Add_Test (Collapse_Utils_Tests.Suite);
      Result.Add_Test (Model_Row_Match_Tests.Suite);
      Result.Add_Test (Coyote_Cmark_Tests.Suite);
      Result.Add_Test (Sandbox_Tests.Suite);
      Result.Add_Test (Coyote_Help_Tests.Suite);
      Result.Add_Test (Coyote_Lasem_Tests.Suite);

      return Result;
   end Suite;

end Test_Core_Suite;
