--  Coyote_SQC.Data_Model — internal data model types.
--
--  All downstream logic (statistics, charts, UI) operates on these types,
--  not on raw session files.  Only Coyote_SQC.Session_Parser may reference
--  the raw JSONL field names.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Ordered_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;
with Coyote_SQC.Charts;

package Coyote_SQC.Data_Model is
   use type Ada.Strings.Unbounded.Unbounded_String;


   --  ── Tool call ──────────────────────────────────────────────────────────

   type Tool_Call_Record is record
      Tool_Name     : Ada.Strings.Unbounded.Unbounded_String;
      Input_Tokens  : Natural := 0;
      Output_Tokens : Natural := 0;
      Failed        : Boolean := False;
      Arguments     : Ada.Strings.Unbounded.Unbounded_String;
      --  Raw JSON argument string; stored at parse time to support JSD
      --  consecutive tool-call similarity computation (§7.14 of spec).
   end record;

   package Tool_Call_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Tool_Call_Record);

   --  ── Turn ───────────────────────────────────────────────────────────────

   type Turn_Record is record
      Turn_Index       : Positive := 1;
      Input_Tokens     : Natural  := 0;
      Output_Tokens    : Natural  := 0;
      Thinking_Tokens  : Natural  := 0;
      Thinking_Enabled : Boolean  := False;
      Tool_Calls       : Tool_Call_Vectors.Vector;
   end record;

   package Turn_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Turn_Record);

   --  ── Session ────────────────────────────────────────────────────────────

   type Session_Record is record
      Session_Id          : Ada.Strings.Unbounded.Unbounded_String;
      Start_Time          : Ada.Calendar.Time;
      Source_Directory    : Ada.Strings.Unbounded.Unbounded_String;
      Model               : Ada.Strings.Unbounded.Unbounded_String;
      First_User_Message  : Ada.Strings.Unbounded.Unbounded_String;
      Total_Input_Tokens  : Natural := 0;
      Total_Output_Tokens : Natural := 0;
      Total_Cache_Read_Tokens  : Natural := 0;
      Total_Cache_Write_Tokens : Natural := 0;
      Total_Uncached_Input_Tokens : Natural := 0;
      Turns               : Turn_Vectors.Vector;
      File_Path           : Ada.Strings.Unbounded.Unbounded_String;
      File_Mtime          : Ada.Calendar.Time;
   end record;

   package Session_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Session_Record);

   --  ── Metrics ────────────────────────────────────────────────────────────

   package Natural_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Natural);

   package Long_Float_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Long_Float);

   type Session_Metrics_Record is record
      Session_Id                 : Ada.Strings.Unbounded.Unbounded_String;
      N_Turns                    : Positive := 1;
      N_Tool_Call_Turns          : Natural  := 0;
      N_Tool_Call_Turns_For_Chart : Natural  := 0;
      N_Thinking_Turns           : Natural  := 0;
      N_Tool_Calls               : Natural  := 0;
      N_Failed_Tool_Calls        : Natural  := 0;
      Any_Thinking               : Boolean  := False;
      Per_Turn_Input_Tokens      : Natural_Vectors.Vector;
      Per_Turn_Output_Tokens     : Natural_Vectors.Vector;
      Per_Turn_Tool_Tokens       : Natural_Vectors.Vector;
      Per_Turn_Thinking_Tokens   : Natural_Vectors.Vector;
      N_Thinking_Turns_For_Chart : Natural  := 0;
      Total_Input_Tokens         : Natural  := 0;
      Total_Output_Tokens        : Natural  := 0;
      Total_Cache_Read_Tokens  : Natural  := 0;
      Total_Cache_Write_Tokens : Natural  := 0;
      Total_Thinking_Tokens         : Natural  := 0;
      Total_Tool_Call_Input_Tokens  : Natural  := 0;
      Total_Tool_Call_Result_Tokens : Natural  := 0;
      Total_Uncached_Input_Tokens    : Natural  := 0;
      --  JSD consecutive tool-call similarity (see §7.14 of spec).
      --  One Sᵢ = Nᵢ·(1−D_bc) value per eligible consecutive pair.
      Per_Consecutive_Tool_S   : Long_Float_Vectors.Vector;
      N_Consecutive_Tool_Pairs : Natural := 0;
      Total_Tool_Call_JSD_S    : Long_Float := 0.0;
      --  MI consecutive tool-call mutual information (see §7.14b of spec).
      --  One MI_k = C_a_k + C_b_k − C_ab_k value per eligible consecutive pair.
      Per_Consecutive_Tool_MI   : Long_Float_Vectors.Vector;
      N_Consecutive_Tool_MI_Pairs : Natural := 0;
      Total_Tool_Call_MI    : Long_Float := 0.0;
      --  Sum of all Per_Consecutive_Tool_S values across every consecutive
      --  tool call pair in the session.  0.0 when N_Consecutive_Tool_Pairs = 0.
   end record;

   package Metrics_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Session_Metrics_Record);

   --  ── Comment ────────────────────────────────────────────────────────────

   type Comment_Record is record
      Comment_Id : Ada.Strings.Unbounded.Unbounded_String;
      Session_Id : Ada.Strings.Unbounded.Unbounded_String;
      Timestamp  : Ada.Calendar.Time;
      Text       : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Comment_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Comment_Record);

   --  ── UUID sets ──────────────────────────────────────────────────────────

   package UUID_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Ada.Strings.Unbounded.Unbounded_String,
      Hash                => Ada.Strings.Unbounded.Hash,
      Equivalent_Elements => Ada.Strings.Unbounded."=");

   subtype UUID_Set is UUID_Sets.Set;

   --  ── Variance-stabilization transform configuration ─────────────────────

   --  Selects which variance-stabilization transform is applied to a chart.
   --  None          — no transformation; raw data used directly.
   --  Box_Cox       — Box-Cox family (x**λ − 1)/λ; λ estimated or fixed.
   --  Sqrt_VS       — square root: f(x) = √x; inverse f⁻¹(z) = z².
   --  Anscombe      — Anscombe: f(x) = 2√(x + 3/8); for Poisson counts.
   --  Arcsinh_VS    — inverse hyperbolic sine: f(x) = ln(x + √(x²+1));
   --                  tolerates zero and negative inputs.
   --  Freeman_Tukey — Freeman-Tukey: f(x) = √x + √(x+1); for Poisson counts.
   type Transform_Kind is
     (None, Box_Cox, Sqrt_VS, Anscombe, Arcsinh_VS, Freeman_Tukey);

   --  Identifies how the Box-Cox lambda parameter is determined.
   --  Only consulted when Transform_Config.Kind = Box_Cox.
   type Box_Cox_Lambda_Source is (Auto, Robust_Auto, Fixed);

   --  Variance-stabilization transform configuration for a single chart.
   --  Stored per-chart in Workspace_Record.Chart_Settings; see below.
   --  Lambda_Source and Fixed_Lambda are only meaningful when Kind = Box_Cox.
   type Transform_Config is record
      Kind          : Transform_Kind         := None;
      Lambda_Source : Box_Cox_Lambda_Source  := Auto;
      Fixed_Lambda  : Long_Float             := 0.0;
      --  Lambda_Source = Auto: estimate lambda at runtime from the
      --  setup interval by MLE (profile log-likelihood); not persisted.
      --  Lambda_Source = Robust_Auto: estimate lambda at runtime using
      --  the Qn robust scale estimator (Rousseeuw & Croux 1993) instead
      --  of the sample variance; 50% breakdown point, 82% Gaussian
      --  efficiency; not persisted.
      --  Lambda_Source = Fixed: use Fixed_Lambda directly.
      --  Common fixed values: 0.0 (ln), 0.5 (sqrt), 1.0 (identity).
   end record;


   --  ── Estimation method ──────────────────────────────────────────────────

   --  Selects the statistical estimators for a single chart's control limits.
   --  Classical uses arithmetic mean / pooled s / mean MR.
   --  Robust_Median uses median / Qₙ residuals / median MR.
   --  p-charts always use the classical grand proportion regardless.
   --  See §7.13 of the spec.
   --  Controls how plotted session statistics (markers on the chart) are
   --  computed from the session's own subgroup data.  Applies only to Xbar
   --  and s charts; ignored for all other chart kinds.  Default: Classical.
   --  See §7.13a of the spec.
   type Plot_Method_Kind is (Classical, Robust_Median);

   type Estimation_Method_Kind is (Classical, Robust_Median);

   --  ── Per-chart settings ────────────────────────────────────────────────

   --  Per-chart configuration: Box-Cox transformation, estimation method,
   --  and (for EWMA charts) smoothing weight and sigma multiplier.
   --  Charts at all-default settings are omitted from the workspace map to
   --  keep the file compact.  Absent entries are treated as all-default.
   type Chart_Settings_Record is record
      Transform         : Transform_Config;
      Estimation_Method : Estimation_Method_Kind := Classical;
      --  EWMA_Weight and EWMA_L are consulted only for EWMA chart kinds;
      --  they are ignored for all other chart kinds.
      EWMA_Weight       : Long_Float := 0.2;
      EWMA_L            : Long_Float := 3.0;
      Plot_Method        : Plot_Method_Kind := Classical;
   end record;

   --  Map from Chart_Kind to per-chart settings.
   --  Ada.Containers.Ordered_Maps is used because Chart_Kind is an
   --  enumeration type — the implicit "<" from the enumeration definition
   --  is well-defined and strict.
   package Chart_Settings_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Coyote_SQC.Charts.Chart_Kind,
      Element_Type => Chart_Settings_Record,
      "<"          => Coyote_SQC.Charts."<");

   --  ── Workspace ──────────────────────────────────────────────────────────

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Ada.Strings.Unbounded.Unbounded_String,
      "="          => Ada.Strings.Unbounded."=");

   type Workspace_Record is record
      Workspace_Id       : Ada.Strings.Unbounded.Unbounded_String;
      Name               : Ada.Strings.Unbounded.Unbounded_String;
      Source_Directories : String_Vectors.Vector;
      Model_Filter       : String_Vectors.Vector;
      Setup_Session_Ids  : UUID_Set;
      Comments           : Comment_Vectors.Vector;
      --  Per-chart Box-Cox, estimation method, and EWMA parameter settings.
      --  Charts at default settings (Box-Cox disabled, Classical estimation,
      --  EWMA_Weight = 0.2, EWMA_L = 3.0) are omitted from the map to keep
      --  the workspace file compact.
      Chart_Settings     : Chart_Settings_Maps.Map;
      Log_Y_Mode         : Boolean := False;
      --  When True, sessions from every project directory are loaded,
      --  ignoring Source_Directories.  Source_Directories is preserved so
      --  the prior list is restored when the option is unchecked.
      Analyze_All_Directories : Boolean := False;
      Interpolate_Quantile_Limits : Boolean := False;
      --  When True, Quantile CC charts use interpolated control limits
      --  instead of exact bootstrap for every subgroup size (§5.18.1).
      Quantile_Bonferroni : Boolean := True;
      --  When True, Quantile CC charts use Bonferroni multiplicity
      --  correction (α_B = α/5 = 0.00054 per component).  When False,
      --  each component is tested at the unadjusted α = 0.0027.
   end record;
end Coyote_SQC.Data_Model;
