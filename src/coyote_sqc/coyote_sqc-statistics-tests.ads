--  Coyote_SQC.Statistics.Tests — descriptive statistics and goodness-of-fit
--  tests for the multi-select detail panel.
--
--  All functions accept a Long_Float_Array of sample values and return a
--  scalar result.  Functions that require a minimum sample size return -1.0
--  when the precondition is not met.
--
--  Project: coyote

with Coyote_SQC.Statistics.I_Chart;

package Coyote_SQC.Statistics.Tests is

   subtype Long_Float_Array is Coyote_SQC.Statistics.I_Chart.Long_Float_Array;

   --  ── Descriptive statistics ────────────────────────────────────────────

   --  Arithmetic mean.  Returns 0.0 for an empty array.
   function Mean_Of (Values : Long_Float_Array) return Long_Float;

   --  Sample standard deviation (N-1 denominator).
   --  Returns 0.0 for N < 2.
   function Std_Dev_Of (Values : Long_Float_Array) return Long_Float;

   --  ── Goodness-of-fit tests ─────────────────────────────────────────────

   --  One-sample Kolmogorov-Smirnov test of normality.
   --  Null hypothesis: the sample comes from a Normal distribution with mean
   --  and standard deviation estimated from the data (composite hypothesis).
   --  Returns the asymptotic p-value in [0, 1].
   --  Returns -1.0 when Values'Length < 3 or the sample standard deviation
   --  is zero (degenerate sample).
   function KS_Normality_P_Value
     (Values : Long_Float_Array) return Long_Float;

   --  One-sample Kolmogorov-Smirnov test for an exponential distribution.
   --  Null hypothesis: the sample comes from Exponential(lambda) where
   --  lambda = 1 / Mean_Of(Values) is estimated from the data.
   --  Returns the asymptotic p-value in [0, 1].
   --  Returns -1.0 when Values'Length < 3 or Mean_Of(Values) <= 0.0.
   function KS_Exponential_P_Value
     (Values : Long_Float_Array) return Long_Float;

   --  Wald-Wolfowitz runs test for randomness.
   --  Tests whether the values (in the order provided, i.e. chronological)
   --  form a random, independent sequence relative to their median.
   --  Observations equal to the median are excluded from the run count.
   --  Returns the two-sided asymptotic p-value in [0, 1].
   --  Returns -1.0 when Values'Length < 10 or when one side of the median
   --  has no observations (degenerate split).
   function Runs_Test_P_Value
     (Values : Long_Float_Array) return Long_Float;

   --  Hartigan dip test for unimodality.
   --  Null hypothesis: the sample is drawn from a unimodal distribution.
   --  P-value estimated via Monte Carlo simulation: K independent samples
   --  of size N drawn from Uniform[0,1] are generated (the uniform
   --  distribution maximises the expected dip among all unimodal CDFs),
   --  the dip statistic is computed for each, and the p-value is the
   --  fraction of simulated dips that are >= the observed dip.
   --  Returns -1.0 (displayed as "N/A") when Values'Length < 4.
   --  A small p-value (e.g. < 0.05) is evidence of multimodality.
   function Dip_Test_P_Value
     (Values : Long_Float_Array;
      K      : Positive := 2_000) return Long_Float;

end Coyote_SQC.Statistics.Tests;
