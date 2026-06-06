--  Coyote_SQC.Statistics.Bootstrap — percentile bootstrap 95% CI
--  for the two-set comparison (SRS-SQC §5.17, PCR-016).
--
--  B = 10 000 resamples; fixed random seed 12 345
--  (Ada.Numerics.Discrete_Random); 95% CI (2.5th and 97.5th percentiles
--  of the bootstrap distribution).  Computation is synchronous on the
--  GTK main-loop thread; typical dataset sizes make this negligible.
--
--  Project: coyote

with Coyote_SQC.Data_Model;
with Coyote_SQC.Statistics.I_Chart;

package Coyote_SQC.Statistics.Bootstrap is

   subtype Long_Float_Array is Coyote_SQC.Statistics.I_Chart.Long_Float_Array;

   --  Result record for one bootstrap confidence interval.
   type CI_Result is record
      Point_Estimate : Long_Float := 0.0;
      Lower          : Long_Float := 0.0;
      Upper          : Long_Float := 0.0;
      Valid          : Boolean    := False;
      --  Valid = False when N < 2 in either set, or when SD(A) = 0 for
      --  the ratio statistic, or when >50% of ratio replicates are
      --  undefined (SD(A*) = 0).  Point_Estimate, Lower, Upper are
      --  undefined when Valid = False; display as "N/A".
   end record;

   --  Result record for all three bootstrap confidence intervals.
   type Three_CI_Results is record
      Mean_Diff   : CI_Result;
      Median_Diff : CI_Result;
      SD_Ratio    : CI_Result;
   end record;

   --  Compute all three bootstrap CIs for the comparison Set_B − Set_A
   --  (mean and median differences) and Set_B / Set_A (SD ratio).
   --  Set_A and Set_B are heap-backed vectors of contributing session
   --  statistics; caller has already applied active-chart exclusion rules.
   --  Vectors avoid large stack allocations when session counts are high.
   --  Returns Valid = False for any statistic where fewer than 2
   --  observations are available in the relevant set.
   --  The generator is seeded with Seed before the resample loop; the
   --  same Seed always produces identical CI bounds (reproducible output).
   function Compute
     (Set_A : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
      Set_B : Coyote_SQC.Data_Model.Long_Float_Vectors.Vector;
      B     : Positive := 10_000;
      Seed  : Integer  := 12_345) return Three_CI_Results;

end Coyote_SQC.Statistics.Bootstrap;
