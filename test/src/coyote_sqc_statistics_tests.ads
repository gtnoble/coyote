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

end Coyote_SQC_Statistics_Tests;
