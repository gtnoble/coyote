--  Coyote_SQC.Statistics — AUnit test suite.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_SQC_Statistics_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  c4 accuracy tests.
   procedure Test_C4_Known_Values        (T : in out Test);
   procedure Test_C4_Approximation       (T : in out Test);
   procedure Test_C4_N1_Raises           (T : in out Test);

   --  Xbar chart limit tests.
   procedure Test_Xbar_Limits_Basic      (T : in out Test);
   procedure Test_Xbar_N1_Undefined      (T : in out Test);
   procedure Test_Xbar_Pooled_S_Zero    (T : in out Test);

   --  s chart limit tests.
   procedure Test_S_Chart_Limits_Basic   (T : in out Test);
   procedure Test_S_Chart_N1_Undefined   (T : in out Test);
   procedure Test_S_Chart_Pooled_S_Zero (T : in out Test);
   procedure Test_S_Chart_LCL_Clamped    (T : in out Test);

   --  p chart limit tests.
   procedure Test_P_Chart_Limits_Basic   (T : in out Test);
   procedure Test_P_Chart_N0_Undefined   (T : in out Test);
   procedure Test_P_Chart_LCL_Clamped    (T : in out Test);

   --  Estimate_Parameters tests.
   procedure Test_Estimate_Xbar_S        (T : in out Test);
   procedure Test_Xbar_Known_Dataset     (T : in out Test);
   procedure Test_P_Chart_Known_Dataset  (T : in out Test);
   procedure Test_Estimate_P_Chart       (T : in out Test);
   procedure Test_Estimate_N1_Only       (T : in out Test);
   procedure Test_N1_Excluded_From_Pooled_S (T : in out Test);
   procedure Test_Estimate_Zero_Thinking (T : in out Test);
   procedure Test_Estimate_Zero_Tool_Calls (T : in out Test);
   procedure Test_Tool_Call_Token_Values   (T : in out Test);

   --  I chart limit tests.
   procedure Test_I_Chart_Limits_Basic    (T : in out Test);
   procedure Test_I_Chart_LCL_Positive    (T : in out Test);
   procedure Test_I_Chart_Mean_MR_Zero    (T : in out Test);
   procedure Test_I_Chart_LCL_Clamped     (T : in out Test);

   --  MR chart limit tests.
   procedure Test_MR_Chart_Limits_Basic   (T : in out Test);
   procedure Test_MR_Chart_Mean_MR_Zero   (T : in out Test);

   --  Estimate_Parameters for I/MR chart kinds.
   procedure Test_Estimate_I_Chart_Input  (T : in out Test);
   procedure Test_Estimate_I_Chart_Single (T : in out Test);

   --  Box-Cox transformation tests.
   procedure Test_Box_Cox_Ln_Identity     (T : in out Test);
   procedure Test_Box_Cox_Lambda_One      (T : in out Test);
   procedure Test_Box_Cox_Round_Trip      (T : in out Test);
   procedure Test_Box_Cox_Zero_Raises     (T : in out Test);
   procedure Test_Estimate_Lambda_Few_Obs (T : in out Test);
   procedure Test_I_Limits_Box_Cox_Ln     (T : in out Test);
   procedure Test_Box_Cox_MR_Transformed  (T : in out Test);

   --  Qn scale estimator tests.
   procedure Test_Qn_Scale_N3_Known         (T : in out Test);
   procedure Test_Qn_Scale_N4_Known         (T : in out Test);
   procedure Test_Qn_Scale_N_Less_2_Raises  (T : in out Test);
   procedure Test_Qn_Scale_Zero_Raises      (T : in out Test);
   procedure Test_Qn_Scale_Asymptotic_Even  (T : in out Test);
   procedure Test_Qn_Scale_Asymptotic_Odd   (T : in out Test);

   --  Robust Estimate_Lambda tests.
   procedure Test_Estimate_Lambda_Robust_Few_Obs (T : in out Test);
   procedure Test_Estimate_Lambda_Robust_Basic   (T : in out Test);
   procedure Test_Estimate_Lambda_Degenerate    (T : in out Test);

   --  EWMA chart tests.
   procedure Test_EWMA_Compute_Z_Single_Step (T : in out Test);
   procedure Test_EWMA_Compute_Z_Multi_Step  (T : in out Test);
   procedure Test_EWMA_Limits_T1             (T : in out Test);
   procedure Test_EWMA_Limits_Steady_State   (T : in out Test);
   procedure Test_EWMA_Limits_Zero_Sigma     (T : in out Test);
   procedure Test_EWMA_Limits_LCL_Clamped    (T : in out Test);

   --  Median_Of helper tests.
   procedure Test_Median_Of_Basic   (T : in out Test);
   procedure Test_Median_Of_Even    (T : in out Test);
   procedure Test_Median_Of_Single  (T : in out Test);
   procedure Test_Median_Of_Empty   (T : in out Test);
   procedure Test_Median_Of_Unsorted (T : in out Test);

   --  Robust I/MR estimation tests.
   procedure Test_Robust_I_Chart_Grand_Mean (T : in out Test);
   procedure Test_Robust_I_Chart_Mean_MR    (T : in out Test);
   procedure Test_Robust_I_Limits_Divisor   (T : in out Test);
   procedure Test_Robust_MR_UCL             (T : in out Test);

   --  Robust Xbar/s estimation tests.
   procedure Test_Robust_Xbar_Grand_Mean   (T : in out Test);
   procedure Test_Robust_Xbar_Pooled_S     (T : in out Test);

   --  Robust p-chart unchanged test.
   procedure Test_Robust_P_Chart_Unchanged (T : in out Test);

end Coyote_SQC_Statistics_Tests;
