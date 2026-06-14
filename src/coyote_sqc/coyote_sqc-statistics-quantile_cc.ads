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
     (Dist : Bootstrap_Distribution) return Quantile_Limits_Array;

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
      Entries : Cache_Maps.Vector;
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

   --  Discard all cached distributions.
   procedure Clear_Cache (Cache : in out Quantile_CC_Cache);

   --  ── Interpolated limits ─────────────────────────────────────────────
   --
   --  Interpolation parameters for anchor-based quantile limit computation.
   --  δ = tolerance for relative half-width error from O(1/n) bias.
   --  C = quantile finite-sample bias constant.
   --  Discrete_Max = smallest n where 1/√n scaling is reliable (padded to
   --  at least 16 for discrete-index safety).
   --
   --  Anchors are every integer 2 .. Discrete_Max, then uniformly in
   --  1/√n space thereafter, grown lazily as larger subgroup sizes
   --  are encountered.

   Interp_Delta        : constant Long_Float  := 0.15;
   Interp_C            : constant Long_Float  := 0.5;
   Interp_Discrete_Max : constant Positive    := 16;

   --  Interpolate control limits for subgroup size N_I using
   --  anchor-distribution scaling in 1/√N space.
   --
   --  Exact bootstrap distributions are computed only at a small set of
   --  anchor subgroup sizes (cached in Cache).  For a non-anchor N_I,
   --  the limits are derived from the nearest lower anchor N_a by
   --  scaling half-widths:  HW'(j) = HW_a(j) × √(N_a / N_I).
   --  The relative interpolation error in half-width is bounded
   --  by Interp_Delta² ≈ 2.25% in the continuous regime.
   --
   --  For N_I = 1 (degenerate), exact computation is used.
   --  Requires Pool_Count > 0 (caller must check).
   function Interpolate_Limits
     (Cache        : in out Quantile_CC_Cache;
      Pool_Values  : Long_Float_Array;
      Pool_Offsets : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      Pool_Lengths : Coyote_SQC.Data_Model.Natural_Vectors.Vector;
      N_I          : Positive;
      Seed         : Integer := Bootstrap_Seed)
     return Quantile_Limits_Array;


end Coyote_SQC.Statistics.Quantile_CC;
