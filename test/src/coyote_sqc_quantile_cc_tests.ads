--  Coyote_SQC_Quantile_CC_Tests — AUnit tests for Quantile Control Charts.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_SQC_Quantile_CC_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Compute_Quantiles_Basic        (T : in out Test);
   procedure Test_Compute_Quantiles_N1           (T : in out Test);
   procedure Test_Build_Distribution_Limits      (T : in out Test);
   procedure Test_Build_Distribution_Single      (T : in out Test);
   procedure Test_Build_Distribution_Seeding     (T : in out Test);
   procedure Test_Extract_Limits_Known           (T : in out Test);
   procedure Test_Is_OOC_Above                   (T : in out Test);
   procedure Test_Is_OOC_No_UCL                  (T : in out Test);
   procedure Test_Session_Is_OOC_All_In          (T : in out Test);
   procedure Test_Session_Is_OOC_One_Out         (T : in out Test);
   procedure Test_OOC_Components                 (T : in out Test);
   procedure Test_Cache_Hit                      (T : in out Test);
   procedure Test_Cache_Invalidation             (T : in out Test);
   procedure Test_Sort_Through_Quantiles_Reverse   (T : in out Test);
   procedure Test_Sort_Through_Quantiles_All_Equal (T : in out Test);
   procedure Test_Sort_Through_Quantiles_Two_Desc  (T : in out Test);
   procedure Test_Sort_Through_Quantiles_Larger    (T : in out Test);

end Coyote_SQC_Quantile_CC_Tests;
