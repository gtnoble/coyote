with Coyote_SQC_Statistics_Tests;
with Coyote_SQC_Parser_Tests;
with Coyote_SQC_Workspace_Tests;
with Coyote_SQC_Histogram_Tests;
with Coyote_SQC_JSD_Tests;
with Coyote_SQC_MI_Tests;
with Coyote_SQC_Integrity_Tests;
with Coyote_SQC_Quantile_CC_Tests;
with AUnit.Test_Suites;

package body Test_SQC_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_SQC_Statistics_Tests.Suite);
      Result.Add_Test (Coyote_SQC_Parser_Tests.Suite);
      Result.Add_Test (Coyote_SQC_Workspace_Tests.Suite);
      Result.Add_Test (Coyote_SQC_Histogram_Tests.Suite);
      Result.Add_Test (Coyote_SQC_JSD_Tests.Suite);
      Result.Add_Test (Coyote_SQC_MI_Tests.Suite);
      Result.Add_Test (Coyote_SQC_Integrity_Tests.Suite);
      Result.Add_Test (Coyote_SQC_Quantile_CC_Tests.Suite);

      return Result;
   end Suite;

end Test_SQC_Suite;
