--  Coyote_SQC.Statistics.I_Chart — Individuals (I) and Moving-Range (MR)
--  chart limit computation, with optional Box-Cox transformation support.
--
--  For an I chart every observation is a single session-level value; there
--  is no within-session subgroup.  Control limits are derived from the mean
--  moving range (MR̄) between consecutive setup-interval sessions.
--
--  Constants:
--    d2 = 1.128  (moving range of span 2)
--    D4 = 3.267  (MR chart UCL factor for span 2)
--
--  Project: coyote

package Coyote_SQC.Statistics.I_Chart is

   --  Array of Long_Float observations used by Box-Cox functions.
   type Long_Float_Array is array (Positive range <>) of Long_Float;

   --  ── Standard I/MR limit computation ───────────────────────────────────
   --  Compute the I-chart (Individuals) control limits.
   --
   --  Grand_Mean is the mean (or robust median) of setup-interval session values.
   --  Sigma      is the pre-computed process sigma:
   --               Classical mode: Mean_MR / d2  (d2 = 1.128)
   --               Robust mode:    Qn_Scale_Any (observations) / 2.2219
   --
   --  When Sigma = 0.0, Has_UCL and Has_LCL are both False.
   --  The LCL is clamped to 0 when the formula yields a negative value;
   --  Has_LCL is True only when the clamped LCL value would be > 0.
   function Compute_I_Limits
     (Grand_Mean : Long_Float;
      Sigma      : Long_Float) return Limits_Record;


   --  Compute the MR-chart (Moving Range) control limits.
   --
   --  Mean_MR is the mean moving range from the setup interval (MR̄).
   --
   --  UCL = D4 * MR̄ = 3.267 * MR̄.
   --  LCL = 0 always (Has_LCL is always False).
   --  When Mean_MR = 0.0, Has_UCL is False.
   function Compute_MR_Limits (Mean_MR : Long_Float) return Limits_Record;

   --  ── Box-Cox transformation ─────────────────────────────────────────────

   --  Apply the Box-Cox transform to a single strictly positive observation.
   --
   --  For Lambda = 0.0: returns ln (X).
   --  For Lambda /= 0.0: returns (X ** Lambda - 1.0) / Lambda.
   --
   --  Raises Constraint_Error if X <= 0.0.
   function Box_Cox (X : Long_Float; Lambda : Long_Float) return Long_Float;

   --  Recover the original value from a Box-Cox transformed value.
   --
   --  For Lambda = 0.0: returns exp (Z).
   --  For Lambda /= 0.0: returns (Z * Lambda + 1.0) ** (1.0 / Lambda).
   function Box_Cox_Inverse
     (Z : Long_Float; Lambda : Long_Float) return Long_Float;

   --  Compute the Qn scale estimate (Rousseeuw & Croux 1993).
   --
   --  Returns c_n * 2.2219 * d_(h), where d_(h) is the h-th order statistic
   --  of all C(N,2) pairwise absolute differences |y_i - y_j|,
   --  h = C(floor(N/2)+1, 2), and c_n is a finite-sample correction factor
   --  applied for N <= 9 (Table 1, Rousseeuw & Croux 1993) and an
   --  even/odd asymptotic formula for N >= 10.
   --
   --  Requires Values'Length >= 2.  All values must be strictly positive;
   --  raises Constraint_Error if any value is <= 0.0.
   function Qn_Scale (Values : Long_Float_Array) return Long_Float;

   --  Like Qn_Scale but accepts non-positive values (no positivity guard).
   --  Use when computing sigma directly from token counts (which may include
   --  zero values) rather than from strictly-positive Box-Cox inputs.
   --  Requires Values'Length >= 2; raises Constraint_Error if N < 2.
   function Qn_Scale_Any (Values : Long_Float_Array) return Long_Float;
   --  Return the median of a Long_Float_Array.
   --  For even N, returns the mean of the two middle values.
   --  Returns 0.0 for an empty array; returns the single value for N = 1.
   function Median_Of (Values : Long_Float_Array) return Long_Float;

   --  Estimate the Box-Cox lambda by maximising the profile log-likelihood
   --  under the normality assumption (Box and Cox, 1964), or a robust
   --  variant that substitutes the Qn scale estimator for the variance.
   --
   --  Use_Robust = False (default): maximise MLE log-likelihood.
   --  Use_Robust = True:            maximise robust log-likelihood using
   --                                Qn_Scale in place of sample variance.
   --
   --  All values in Values must be strictly positive.  Raises Constraint_Error
   --  if any value is <= 0.0.
   --
   --  Returns 0.0 (ln transform) when Values'Length < 3.
   --
   --  Fallback_Used is set to True when the data are degenerate (all values
   --  identical or fewer than three observations).  In this case the function
   --  returns 0.0 (log transform).
   --
   --  Lambda is restricted to [0.0, 30.0]; negative values are excluded
   --  because they are not meaningful for positive token-count data and the
   --  UCL back-transform is always well-defined for lambda >= 0.
   --
   --  Algorithm: coarse grid search over [0.0, 30.0] at step 0.5 (61
   --  evaluations) locates the global maximum basin; Brent's method
   --  (Brent 1973) then refines within +-0.5 of the coarse best, clamped to
   --  [0.0, 30.0], converging to tolerance 1.0e-6 on lambda.
   function Estimate_Lambda
     (Values        : Long_Float_Array;
      Use_Robust    : Boolean := False;
      Fallback_Used : out Boolean) return Long_Float;
end Coyote_SQC.Statistics.I_Chart;
