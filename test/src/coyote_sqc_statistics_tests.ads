--  Coyote_SQC.Statistics — AUnit test suite.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

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

   --  Fraction thinking/tool-call tokens p-chart tests.
   procedure Test_Fraction_Thinking_Tokens_Grand_Mean  (T : in out Test);
   procedure Test_Fraction_Tool_Call_Tokens_Grand_Mean (T : in out Test);
   procedure Test_Fraction_Token_Charts_Zero_Output  (T : in out Test);
   procedure Test_Fraction_Thinking_Per_Tool_Call_Grand_Mean (T : in out Test);
   procedure Test_Fraction_Uncached_Input_Grand_Mean          (T : in out Test);
   procedure Test_Fraction_New_Charts_Zero_Denominator        (T : in out Test);

   --  EWMA + Box-Cox combined tests.
   procedure Test_EWMA_Box_Cox_Asymmetric_Limits     (T : in out Test);

   --  Robust estimation + EWMA interaction tests.
   --  Robust plot method tests (§7.13a).
   procedure Test_Robust_Xbar_Plot_Median           (T : in out Test);
   procedure Test_Robust_S_Plot_Qn                  (T : in out Test);
   procedure Test_Robust_Plot_Round_Trip             (T : in out Test);
   procedure Test_Robust_Plot_I_Chart_Unaffected     (T : in out Test);
   procedure Test_Robust_Plot_P_Chart_Unaffected     (T : in out Test);
   procedure Test_Robust_Plot_Quantile_Unaffected    (T : in out Test);
   procedure Test_Robust_Plot_Single_Turn_Xbar       (T : in out Test);
   procedure Test_Robust_Plot_Single_Turn_S          (T : in out Test);
   procedure Test_Robust_Plot_Box_Cox_Interaction    (T : in out Test);

   procedure Test_Robust_EWMA_Outlier_Grand_Mean     (T : in out Test);


   --  New variance-stabilization transform tests.
   procedure Test_Sqrt_VS_Round_Trip      (T : in out Test);
   procedure Test_Anscombe_Round_Trip     (T : in out Test);
   procedure Test_Arcsinh_VS_Round_Trip   (T : in out Test);
   procedure Test_Freeman_Tukey_Round_Trip (T : in out Test);
   procedure Test_Apply_Invert_Dispatch   (T : in out Test);

   --  Dip test for unimodality.
   procedure Test_Dip_NA_Too_Small        (T : in out Test);
   procedure Test_Dip_Bimodal_Significant (T : in out Test);
   procedure Test_Dip_Unimodal_Not_Sig    (T : in out Test);

   --  Bootstrap CI tests (SRS-SQC §15.6, PCR-016).
   procedure Test_Bootstrap_Point_Estimates  (T : in out Test);
   procedure Test_Bootstrap_CI_Coverage      (T : in out Test);
   procedure Test_Bootstrap_NA_Insufficient  (T : in out Test);
   procedure Test_Bootstrap_NA_SD_Zero       (T : in out Test);
   procedure Test_Bootstrap_Reproducibility  (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_SQC_Statistics_Tests;
