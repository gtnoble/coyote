--  Coyote_SQC_MI_Tests — AUnit test suite for the MI statistics package.
--
--  Covers: Compute_MI_Values, Metrics MI fields,
--  and Estimate_Parameters for Session_Tool_Call_MI_Sum_* chart kinds.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_SQC_MI_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Compute_MI_Values tests.
   procedure Test_MI_Identical_Calls        (T : in out Test);
   procedure Test_MI_Different_Tool_Names   (T : in out Test);
   procedure Test_MI_One_Side_Absent        (T : in out Test);
   procedure Test_MI_Integer_Key_Skipped    (T : in out Test);
   procedure Test_MI_Both_Sides_Empty       (T : in out Test);

   --  Metrics MI field tests (via Coyote_SQC.Metrics.Compute).
   procedure Test_Metrics_MI_Two_Identical_Calls (T : in out Test);
   procedure Test_Metrics_MI_Single_Tool_Call    (T : in out Test);
   procedure Test_Metrics_MI_No_Tool_Calls       (T : in out Test);
   procedure Test_Metrics_MI_Total_Sum           (T : in out Test);
   procedure Test_Metrics_MI_Cross_Turn_Pairs    (T : in out Test);

   --  Estimate_Parameters for MI sum chart kinds.
   procedure Test_Estimate_MI_Sum_I_Grand_Mean    (T : in out Test);
   procedure Test_Estimate_MI_Sum_I_Mean_MR       (T : in out Test);
   procedure Test_Estimate_MI_Sum_Excludes_No_Pairs (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_SQC_MI_Tests;
