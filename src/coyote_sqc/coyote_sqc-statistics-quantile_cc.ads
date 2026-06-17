--  Coyote_SQC.Statistics.Quantile_CC — two-stage bootstrap quantile
--  control chart limit computation.
--
--  For each session with subgroup size n_i, computes per-component
--  bootstrap control limits for minimum, first quartile, median, third
--  quartile, and maximum of the per-turn observations.
--
--  Methodology (§5.18 of SRS-SQC):
--    Two-stage bootstrap with B_Replicates resamples per unique n_i.
--    Stage 1: sample a setup-interval session uniformly at random.
--    Stage 2: sample n_i observations with replacement from that session.
--    Compute five quantile statistics from this resample (R type 7).
--    Bonferroni correction: α_B = 0.0027 / 5 = 0.00054 per statistic;
--    two-sided tail α_B/2 = 0.00027; limit ranks computed from B_Replicates.
--    Fixed seed 54 321 for reproducible limits.
--
--  Caching: distributions are computed once per unique n_i per chart
--  and reused across sessions with the same subgroup size.  The cache
--  is cleared when the setup interval or session data changes.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Coyote_SQC.Data_Model;

package Coyote_SQC.Statistics.Quantile_CC is

   --  Subtype for Long_Float arrays used with this package.
   type Long_Float_Array is array (Positive range <>) of Long_Float;

   --  Number of bootstrap replicates.
   B_Replicates : constant Positive := 10_000;

   --  Fixed seed for reproducible bootstrap results.
   Bootstrap_Seed : constant Integer := 54_321;

   --  Bonferroni-adjusted alpha tail rank.
   --  α = 0.0027 (3-sigma family-wise), α_B = α / 5 = 0.00054 per statistic.
   --  Two-sided tail: α_B / 2 = 0.00027.
   --  r = max (1, floor (0.00027 * B_Replicates)).
   Bonferroni_Rank : constant Natural :=
     Natural'Max (1, Natural (Long_Float'Floor
       (0.00027 * Long_Float (B_Replicates))));
   --  LCL_j = b_{(r)}; UCL_j = b_{(B - r + 1)}; CL_j = b_{(B / 2)}.

   --  UCL rank index: B_Replicates - Bonferroni_Rank + 1.
   UCL_Rank : constant Natural := B_Replicates - Bonferroni_Rank + 1;
   --  Unadjusted alpha tail rank (Bonferroni disabled).
   --  α = 0.0027, two-sided tail α/2 = 0.00135.
   --  r = max (1, floor (0.00135 * B_Replicates)).
   Unadjusted_Rank : constant Natural :=
     Natural'Max (1, Natural (Long_Float'Floor
       (0.00135 * Long_Float (B_Replicates))));
   --  When Bonferroni is disabled, LCL_j = b_{(r)}, UCL_j = b_{(B - r + 1)}.

   --  The five quantile statistics computed from a subgroup sample.
   type Quantile_Index is (Min_Q, Q1, Median_Q, Q3, Max_Q);

   type Quantile_Array is array (Quantile_Index) of Long_Float;

   --  Bootstrap distribution for a single unique n_i.
   --  Each component holds B_Replicates sorted Long_Float values.
   package Long_Float_Vecs is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Long_Float);

   type Bootstrap_Distribution is array (Quantile_Index) of
     Long_Float_Vecs.Vector;

   --  Compute the five quantile statistics from a single subgroup sample
   --  of size N using linear interpolation (R type 7 default).
   --  Position p(k) = (N − 1) * (k − 1) / 4 for k = 1…5.
   --  Values (1 .. N) is the sorted sample.
   --  Raises Constraint_Error if N < 1 or Values'Length < N.
   function Compute_Quantiles
     (Values : Long_Float_Array;
      N      : Natural) return Quantile_Array;

   --  Build the bootstrap distribution for a given subgroup size N_I.
   --  Pool_Values is the flattened vector of all setup-interval subgroup
   --  values, grouped by session: Pool_Offsets(I) is the 0-based start
   --  index of session I's subgroup in Pool_Values;
   --  Pool_Lengths(I) is the subgroup size of session I.
   --  Sessions with a zero-length subgroup are excluded by the caller.
   --  Returns a Bootstrap_Distribution containing B_Replicates values
   --  for each of the five quantile statistics, sorted ascending.
   function Build_Distribution
     (Pool_Values  : Long_Float_Array;
      Pool_Offsets : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      Pool_Lengths : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      N_I          : Positive;
      --  Effective seed = Seed + N_I (independent per subgroup size).
      Seed         : Integer := Bootstrap_Seed)
     return Bootstrap_Distribution;

   --  Control limits and center line for one quantile statistic.
   type Quantile_Limits_Record is record
      UCL      : Long_Float := 0.0;
      CL       : Long_Float := 0.0;
      LCL      : Long_Float := 0.0;
      Has_UCL  : Boolean := True;
      Has_LCL  : Boolean := True;
   end record;

   type Quantile_Limits_Array is array (Quantile_Index) of
     Quantile_Limits_Record;

   --  Extract control limits and center line for each of the five
   --  quantile statistics from a precomputed bootstrap distribution.
   --  Uses the Bonferroni-adjusted tail ranks.
   function Extract_Limits
     (Dist : Bootstrap_Distribution; Bonferroni_Enabled : Boolean := True) return Quantile_Limits_Array;

   --  Determine whether a single component is out-of-control.
   --  Returns True when Value strictly exceeds UCL or is strictly below LCL.
   function Is_OOC
     (Value    : Long_Float;
      Limits   : Quantile_Limits_Record) return Boolean;

   --  Determine whether a session is out-of-control on a Quantile CC.
   --  Returns True when any component is out-of-control.
   function Session_Is_OOC
     (Values : Quantile_Array;
      Limits : Quantile_Limits_Array) return Boolean;

   --  A set flagging which components are out-of-control.
   type Quantile_Component_Set is array (Quantile_Index) of Boolean
     with Default_Component_Value => False;

   --  Return the set of components that are out-of-control.
   function OOC_Components
     (Values : Quantile_Array;
      Limits : Quantile_Limits_Array) return Quantile_Component_Set;

   --  Cache of bootstrap distributions keyed by subgroup size n_i.
   --  Distributions are lazily computed on first access and reused.
   --  Clear_Cache discards all entries (call when the setup interval
   --  or session data changes).
   type Cache_Entry is record
      N    : Positive := 1;
      Dist : Bootstrap_Distribution;
   end record;

   package Cache_Maps is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Cache_Entry);

   type Quantile_CC_Cache is record
      Entries       : Cache_Maps.Vector;
      Anchors       : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      Tolerance_Rel : Long_Float := 0.05;
      Tolerance_Abs : Long_Float := 1.0;
      --  When True, Extract_Limits uses Bonferroni-corrected ranks.
      --  When False, each component is tested at the unadjusted α = 0.0027.
      Bonferroni_Enabled : Boolean := True;
   end record;

   --  Look up or compute the bootstrap distribution for subgroup size N_I.
   --  Returns the distribution; on a cache miss, calls Build_Distribution
   --  and stores the result.
   --  The effective seed passed to Build_Distribution is Seed + N_I,
   --  giving each subgroup size an independent random stream.
   function Get_Distribution
     (Cache        : in out Quantile_CC_Cache;
      Pool_Values  : Long_Float_Array;
      Pool_Offsets : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      Pool_Lengths : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := Bootstrap_Seed) return Bootstrap_Distribution;

   --  Discard all cached distributions and anchors.
   procedure Clear_Cache (Cache : in out Quantile_CC_Cache);
   --  ── Adaptive interpolation ───────────────────────────────────────────
   --
   --  Adaptive anchor-based quantile limit interpolation.  Anchors are
   --  placed only where interpolation error exceeds the tolerance.
   --  Interpolation is linear in x = 1/√n space between two consecutive
   --  anchors.  The anchor set is stored per chart kind in
   --  Quantile_CC_Cache.Anchors and is cleared together with the
   --  distribution cache.

   --  Maximum n for which exact bootstrap is always computed.
   Adaptive_Discrete_Max : constant Positive := 16;

   --  Relative tolerance: 5% of the half-width from anchor a.
   Adaptive_Tolerance_Rel : constant Long_Float := 0.05;

   --  Absolute tolerance floor (token units).
   Adaptive_Tolerance_Abs : constant Long_Float := 1.0;

   --  Interpolate control limits for subgroup size N_I using
   --  adaptive anchor-based linear interpolation in x = 1/√N space.
   --
   --  For N_I ≤ Adaptive_Discrete_Max: exact bootstrap at every integer.
   --  For N_I > Adaptive_Discrete_Max: anchors are grown adaptively by
   --  bisecting gaps in x-space and testing the x-midpoint.  Limits
   --  for a non-anchor N_I are computed by linear interpolation in
   --  x-space from the two bounding anchors.  CL, UCL, and LCL are all
   --  interpolated (no piecewise-constant centre line).
   --
   --  The error guarantee: for every anchor pair (a, b), the maximum
   --  absolute error of the interpolated limits anywhere in (a, b) does
   --  not exceed max(HW_a · Adaptive_Tolerance_Rel,
   --  Adaptive_Tolerance_Abs).
   --
   --  For N_I = 1 (degenerate), exact computation is used.
   --  Requires Pool_Count > 0 (caller must check).
   function Interpolate_Limits
     (Cache        : in out Quantile_CC_Cache;
      Pool_Values  : Long_Float_Array;
      Pool_Offsets : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      Pool_Lengths : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := Bootstrap_Seed;
      Bonferroni_Enabled : Boolean := True)
     return Quantile_Limits_Array;



end Coyote_SQC.Statistics.Quantile_CC;
