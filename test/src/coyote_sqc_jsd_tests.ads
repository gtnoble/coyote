--  Coyote_SQC_JSD_Tests — AUnit test suite for the JSD statistics package.
--
--  Covers: Token_Count, Compute_S_Values, Metrics JSD fields,
--  and Estimate_Parameters for Session_Tool_Call_JSD_Sum_* chart kinds.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_SQC_JSD_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Token_Count tests.
   procedure Test_Token_Count_Tool_Name_Only         (T : in out Test);
   procedure Test_Token_Count_Multi_Word_Tool_Name   (T : in out Test);
   procedure Test_Token_Count_Empty                  (T : in out Test);

   --  Compute_S_Values tests.
   procedure Test_S_Values_Identical_Calls_Length    (T : in out Test);
   procedure Test_S_Values_Identical_Calls_Sum       (T : in out Test);
   procedure Test_S_Values_One_Side_Absent_Zero      (T : in out Test);
   procedure Test_S_Values_One_Side_Absent_Length    (T : in out Test);
   procedure Test_S_Values_Integer_Key_Skipped       (T : in out Test);
   procedure Test_S_Values_Different_Tool_Names      (T : in out Test);
   procedure Test_S_Values_Appends_Not_Clears        (T : in out Test);

   --  Metrics JSD field tests (via Coyote_SQC.Metrics.Compute).
   procedure Test_Metrics_JSD_Two_Identical_Calls    (T : in out Test);
   procedure Test_Metrics_JSD_Single_Tool_Call       (T : in out Test);
   procedure Test_Metrics_JSD_No_Tool_Calls          (T : in out Test);
   procedure Test_Metrics_JSD_Total_S_Sum            (T : in out Test);
   procedure Test_Metrics_JSD_Cross_Turn_Pairs       (T : in out Test);

   --  Estimate_Parameters for JSD sum chart kinds.
   procedure Test_Estimate_JSD_Sum_I_Grand_Mean      (T : in out Test);
   procedure Test_Estimate_JSD_Sum_I_Mean_MR         (T : in out Test);
   procedure Test_Estimate_JSD_Sum_Excludes_No_Pairs (T : in out Test);

end Coyote_SQC_JSD_Tests;
