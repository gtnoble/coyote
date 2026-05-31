--  Coyote_SQC_Statistics_Tests body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_SQC.Charts;
with Coyote_SQC.Data_Model;
with Coyote_SQC.Metrics;
with Coyote_SQC.Statistics;
with Coyote_SQC.Statistics.C4;
with Coyote_SQC.Statistics.P_Chart;
with Coyote_SQC.Statistics.S_Chart;
with Coyote_SQC.Statistics.Xbar;
with Coyote_SQC.Statistics.I_Chart;
with Coyote_SQC.Statistics.Tests;
with Coyote_SQC.Statistics.EWMA_Chart;
with Ada.Numerics.Long_Elementary_Functions;

package body Coyote_SQC_Statistics_Tests is

   use AUnit.Assertions;
   use Coyote_SQC.Statistics;

   --  ── c4 tests ─────────────────────────────────────────────────────────

   --  ASTM E2587 Table 1 reference values for c4(n), n = 2..10.
   type C4_Ref_Array is array (2 .. 25) of Long_Float;
   --  ASTM E2587 Table 1 reference values (extended), tolerance 1e-6.
   C4_Ref : constant C4_Ref_Array :=
     (2  => 0.7978846,
      3  => 0.8862269,
      4  => 0.9213177,
      5  => 0.9399856,
      6  => 0.9515329,
      7  => 0.9593688,
      8  => 0.9650305,
      9  => 0.9693107,
      10 => 0.9726593,
      11 => 0.9753501,
      12 => 0.9775594,
      13 => 0.9794056,
      14 => 0.9809714,
      15 => 0.9823162,
      16 => 0.9834835,
      17 => 0.9845064,
      18 => 0.9854100,
      19 => 0.9862141,
      20 => 0.9869343,
      21 => 0.9875829,
      22 => 0.9881703,
      23 => 0.9887045,
      24 => 0.9891927,
      25 => 0.9896404);

   procedure Test_C4_Known_Values (T : in out Test) is
      pragma Unreferenced (T);
      Tol : constant Long_Float := 1.0e-6;
   begin
      for N in C4_Ref'Range loop
         declare
            Computed : constant Long_Float := C4.C4 (N);
            Expected : constant Long_Float := C4_Ref (N);
         begin
            Assert
              (abs (Computed - Expected) <= Tol,
               "c4(" & Positive'Image (N) & ") = " & Long_Float'Image (Computed)
               & " expected ~" & Long_Float'Image (Expected));
         end;
      end loop;
   end Test_C4_Known_Values;

   procedure Test_C4_Approximation (T : in out Test) is
      pragma Unreferenced (T);
      --  §14.1: c4(n) approx = 1 - 1/(4*(n-1)); within 0.1% of exact.
      procedure Check (N : Positive; Exact : Long_Float) is
         Approx : constant Long_Float := C4.C4 (N);
      begin
         Assert (abs (Approx - Exact) / Exact <= 0.001,
                 "c4(" & Positive'Image (N) & ") approx error > 0.1%: "
                 & Long_Float'Image (Approx));
      end Check;
   begin
      Check (101, 0.9975032);   --  1 - 1/400 = 0.9975
      Check (500, 0.9994991);   --  1 - 1/1996 ~= 0.9994991
   end Test_C4_Approximation;

   procedure Test_C4_N1_Raises (T : in out Test) is
      pragma Unreferenced (T);
      Raised : Boolean := False;
   begin
      begin
         declare
            Dummy : constant Long_Float := C4.C4 (1);
            pragma Unreferenced (Dummy);
         begin
            null;
         end;
      exception
         when Constraint_Error => Raised := True;
      end;
      Assert (Raised, "c4(1) should raise Constraint_Error");
   end Test_C4_N1_Raises;

   --  ── Xbar tests ───────────────────────────────────────────────────────

   procedure Test_Xbar_Limits_Basic (T : in out Test) is
      pragma Unreferenced (T);
      --  Grand_Mean = 100, Pooled_S = 10, n = 5.
      --  UCL must be > CL; LCL must be < CL; CL = 100.
      L : constant Limits_Record :=
        Xbar.Compute_Limits
          (Grand_Mean => 100.0, Pooled_S => 10.0, N => 5);
   begin
      Assert (L.Has_UCL, "n=5 Xbar limits must be defined");
      Assert (L.CL = 100.0, "CL must equal Grand_Mean");
      Assert (L.UCL > L.CL, "UCL must be > CL");
      Assert (L.LCL < L.CL, "LCL must be < CL");
      Assert (L.UCL - L.CL = L.CL - L.LCL,
              "Limits must be symmetric about CL");
      --  Numerical values to 4 decimal places (§14.1).
      --  C4(5) ≈ 0.93999; Spread = 3*10/(C4(5)*sqrt(5)) ≈ 14.273.
      Assert (abs (L.UCL - 114.2730) < 5.0e-4,
              "UCL should be ~114.2730; got " & Long_Float'Image (L.UCL));
      Assert (abs (L.LCL - 85.7270) < 5.0e-4,
              "LCL should be ~85.7270; got " & Long_Float'Image (L.LCL));
   end Test_Xbar_Limits_Basic;

   procedure Test_Xbar_N1_Undefined (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        Xbar.Compute_Limits
          (Grand_Mean => 50.0, Pooled_S => 5.0, N => 1);
   begin
      Assert (not L.Has_UCL, "n=1 Xbar limits must be Undefined");
      Assert (L.CL = 50.0, "n=1 CL must still equal Grand_Mean");
   end Test_Xbar_N1_Undefined;

   --  §7.5: Pooled_S=0 → Xbar limits must be Undefined (no OOC detection).
   procedure Test_Xbar_Pooled_S_Zero (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        Xbar.Compute_Limits
          (Grand_Mean => 50.0, Pooled_S => 0.0, N => 5);
   begin
      Assert (not L.Has_UCL,
              "Pooled_S=0 Xbar limits must be Undefined");
      Assert (L.CL = 50.0,
              "CL must still equal Grand_Mean when Pooled_S=0");
   end Test_Xbar_Pooled_S_Zero;

   --  ── s chart tests ────────────────────────────────────────────────────

   procedure Test_S_Chart_Limits_Basic (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        S_Chart.Compute_Limits (Pooled_S => 10.0, N => 4);
   begin
      Assert (L.Has_UCL, "n=4 s chart limits must be defined");
      Assert (L.UCL > L.CL, "UCL must be > CL");
      Assert (L.LCL >= 0.0, "LCL must be >= 0");
      Assert (L.CL > 0.0, "CL must be > 0 for positive Pooled_S");
      --  Numerical values to 4 decimal places (§14.1).
      --  C4(4) ≈ 0.92132; UCL ≈ 20.8775; CL ≈ 9.2132; LCL clamped to 0.
      Assert (abs (L.UCL - 20.8775) < 5.0e-4,
              "S UCL should be ~20.8775; got " & Long_Float'Image (L.UCL));
      Assert (abs (L.CL - 9.2132) < 5.0e-4,
              "S CL should be ~9.2132; got " & Long_Float'Image (L.CL));
      Assert (L.LCL = 0.0,
              "S LCL should be 0 (clamped); got " & Long_Float'Image (L.LCL));
   end Test_S_Chart_Limits_Basic;

   procedure Test_S_Chart_N1_Undefined (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        S_Chart.Compute_Limits (Pooled_S => 5.0, N => 1);
   begin
      Assert (not L.Has_UCL, "n=1 s chart must be Undefined");
   end Test_S_Chart_N1_Undefined;

   --  §7.5: Pooled_S=0 → S_Chart limits must be Undefined.
   procedure Test_S_Chart_Pooled_S_Zero (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        S_Chart.Compute_Limits (Pooled_S => 0.0, N => 5);
   begin
      Assert (not L.Has_UCL,
              "Pooled_S=0 S_Chart limits must be Undefined");
      Assert (L.CL = 0.0,
              "CL must be 0 when Pooled_S=0");
   end Test_S_Chart_Pooled_S_Zero;

   procedure Test_S_Chart_LCL_Clamped (T : in out Test) is
      pragma Unreferenced (T);
      --  For n=2 the LCL formula yields a negative value; it must be
      --  clamped to 0.
      L : constant Limits_Record :=
        S_Chart.Compute_Limits (Pooled_S => 10.0, N => 2);
   begin
      Assert (L.Has_UCL, "n=2 s chart must be defined");
      Assert (L.LCL = 0.0, "LCL for n=2 must be clamped to 0.0");
      Assert (L.Has_LCL,
              "clamped s chart LCL must still be drawn (Has_LCL = True)");
   end Test_S_Chart_LCL_Clamped;

   --  ── p chart tests ────────────────────────────────────────────────────

   procedure Test_P_Chart_Limits_Basic (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        P_Chart.Compute_Limits (Grand_P => 0.3, N => 20);
   begin
      Assert (L.Has_UCL, "p chart n=20 must be defined");
      Assert (L.CL = 0.3, "CL must equal Grand_P");
      Assert (L.UCL > L.CL, "UCL must be > CL");
      Assert (L.LCL >= 0.0, "LCL must be >= 0");
      --  Numerical values to 4 decimal places (§14.1).
      --  p=0.3, N=20: spread = 3*sqrt(0.3*0.7/20) ≈ 0.3074.
      Assert (abs (L.UCL - 0.6074) < 5.0e-4,
              "p UCL should be ~0.6074; got " & Long_Float'Image (L.UCL));
      Assert (L.LCL = 0.0,
              "p LCL should be 0 (clamped from negative); got "
              & Long_Float'Image (L.LCL));
      Assert (L.Has_LCL,
              "p chart LCL drawn even when clamped to 0 (Has_LCL = True)");
   end Test_P_Chart_Limits_Basic;

   procedure Test_P_Chart_N0_Undefined (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        P_Chart.Compute_Limits (Grand_P => 0.2, N => 0);
   begin
      Assert (not L.Has_UCL, "p chart n=0 must be Undefined");
   end Test_P_Chart_N0_Undefined;

   procedure Test_P_Chart_LCL_Clamped (T : in out Test) is
      pragma Unreferenced (T);
      --  Grand_P = 0.5, N = 1: 3*sqrt(0.5*0.5/1) = 1.5 → LCL = 0.5 - 1.5 < 0
      L : constant Limits_Record :=
        P_Chart.Compute_Limits (Grand_P => 0.5, N => 1);
   begin
      Assert (L.Has_UCL, "p chart n=1 is defined");
      Assert (L.LCL = 0.0, "LCL must be clamped to 0");
      Assert (L.Has_LCL,
              "clamped p chart LCL must still be drawn (Has_LCL = True)");
   end Test_P_Chart_LCL_Clamped;

   --  ── Estimate_Parameters tests ─────────────────────────────────────────

   --  Build a minimal Session_Record with a given sequence of output tokens.
   function Make_Session
     (Id     : String;
      Tokens : Coyote_SQC.Data_Model.Natural_Vectors.Vector)
      return Coyote_SQC.Data_Model.Session_Record
   is
      use Coyote_SQC.Data_Model;
      S : Session_Record;
   begin
      S.Session_Id := To_Unbounded_String (Id);
      for I in 1 .. Positive (Tokens.Length) loop
         declare
            Turn : Turn_Record;
         begin
            Turn.Turn_Index    := I;
            Turn.Output_Tokens := Tokens.Element (I);
            S.Turns.Append (Turn);
         end;
      end loop;
      return S;
   end Make_Session;

   procedure Test_Estimate_Xbar_S (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      Metrics  : Metrics_Vectors.Vector;
      Setup    : UUID_Set;
      Params   : Setup_Parameters;

      Tokens_1 : Natural_Vectors.Vector;
      Tokens_2 : Natural_Vectors.Vector;
   begin
      Tokens_1.Append (100);
      Tokens_1.Append (100);
      Tokens_1.Append (100);

      Tokens_2.Append (200);
      Tokens_2.Append (200);
      Tokens_2.Append (200);

      Metrics.Append
        (Coyote_SQC.Metrics.Compute (Make_Session ("s1", Tokens_1)));
      Metrics.Append
        (Coyote_SQC.Metrics.Compute (Make_Session ("s2", Tokens_2)));

      --  Setup interval = all sessions (empty UUID set → retrospective).
      Estimate_Parameters (Metrics, Setup, Turn_Tokens_Xbar, Parameters => Params);

      --  Grand_Mean = (3*100 + 3*200) / 6 = 150.
      Assert
        (abs (Params.Grand_Mean - 150.0) < 1.0e-6,
         "Grand_Mean should be 150; got " & Long_Float'Image (Params.Grand_Mean));

      --  Pooled_S = 0 because all turns within each session are identical.
      Assert
        (abs (Params.Pooled_S) < 1.0e-9,
         "Pooled_S should be 0 for constant subgroups; got "
         & Long_Float'Image (Params.Pooled_S));
   end Test_Estimate_Xbar_S;

   --  §14.1: 5-session dataset with varying subgroup sizes.
   --  Grand_Mean ≈ 19.4706, Pooled_S = 1.5 (exact).
   --  Xbar(N=5): UCL≈21.6115, CL≈19.4706, LCL≈17.3296.
   --  S(N=5):    UCL≈ 2.9454, CL≈ 1.4100, LCL=0.0.
   procedure Test_Xbar_Known_Dataset (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;

      function V (A, B, C : Natural) return Natural_Vectors.Vector is
         Vec : Natural_Vectors.Vector;
      begin Vec.Append (A); Vec.Append (B); Vec.Append (C); return Vec; end V;
      function V (A, B, C, D : Natural) return Natural_Vectors.Vector is
         Vec : Natural_Vectors.Vector;
      begin Vec.Append (A); Vec.Append (B); Vec.Append (C); Vec.Append (D);
            return Vec; end V;
      function V5 (A, B, C, D, E : Natural) return Natural_Vectors.Vector is
         Vec : Natural_Vectors.Vector;
      begin Vec.Append (A); Vec.Append (B); Vec.Append (C); Vec.Append (D);
            Vec.Append (E); return Vec; end V5;
      function V2 (A, B : Natural) return Natural_Vectors.Vector is
         Vec : Natural_Vectors.Vector;
      begin Vec.Append (A); Vec.Append (B); return Vec; end V2;
   begin
      Metrics.Append (Coyote_SQC.Metrics.Compute (Make_Session ("d1", V  (10, 12, 11))));
      Metrics.Append (Coyote_SQC.Metrics.Compute (Make_Session ("d2", V  (20, 22, 21, 19))));
      Metrics.Append (Coyote_SQC.Metrics.Compute (Make_Session ("d3", V5 (15, 17, 16, 18, 14))));
      Metrics.Append (Coyote_SQC.Metrics.Compute (Make_Session ("d4", V2 (30, 34))));
      Metrics.Append (Coyote_SQC.Metrics.Compute (Make_Session ("d5", V  (25, 23, 24))));

      Estimate_Parameters (Metrics, Setup, Turn_Tokens_Xbar, Parameters => Params);

      Assert (abs (Params.Grand_Mean - 19.4706) < 5.0e-4,
              "Grand_Mean ~= 19.4706; got " & Long_Float'Image (Params.Grand_Mean));
      Assert (abs (Params.Pooled_S - 1.5) < 1.0e-6,
              "Pooled_S = 1.5 (exact); got " & Long_Float'Image (Params.Pooled_S));

      --  Verify Xbar limits at N=5.
      declare
         L : constant Limits_Record :=
           Xbar.Compute_Limits
             (Grand_Mean => Params.Grand_Mean,
              Pooled_S   => Params.Pooled_S,
              N          => 5);
      begin
         Assert (abs (L.UCL - 21.6115) < 5.0e-4,
                 "Xbar UCL (N=5) ~= 21.6115; got " & Long_Float'Image (L.UCL));
         Assert (abs (L.CL - 19.4706) < 5.0e-4,
                 "Xbar CL (N=5) ~= 19.4706; got " & Long_Float'Image (L.CL));
         Assert (abs (L.LCL - 17.3296) < 5.0e-4,
                 "Xbar LCL (N=5) ~= 17.3296; got " & Long_Float'Image (L.LCL));
      end;

      --  Verify s chart limits at N=5.
      declare
         L : constant Limits_Record :=
           S_Chart.Compute_Limits (Pooled_S => Params.Pooled_S, N => 5);
      begin
         Assert (abs (L.UCL - 2.9454) < 5.0e-4,
                 "S UCL (N=5) ~= 2.9454; got " & Long_Float'Image (L.UCL));
         Assert (abs (L.CL - 1.4100) < 5.0e-4,
                 "S CL (N=5) ~= 1.4100; got " & Long_Float'Image (L.CL));
         Assert (L.LCL = 0.0,
                 "S LCL (N=5) = 0 (clamped); got " & Long_Float'Image (L.LCL));
      end;
   end Test_Xbar_Known_Dataset;

   --  §14.1: 4-session p chart dataset.
   --  Grand_P = 6/35 ~= 0.17143; at N=10: UCL ~= 0.5290, LCL=0.
   procedure Test_P_Chart_Known_Dataset (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;

      function PM (Id : String; N_Calls, N_Failed : Natural)
                   return Session_Metrics_Record is
         M : Session_Metrics_Record;
      begin
         M.Session_Id        := To_Unbounded_String (Id);
         M.N_Tool_Calls      := N_Calls;
         M.N_Failed_Tool_Calls := N_Failed;
         return M;
      end PM;
   begin
      Metrics.Append (PM ("p1", 10, 2));
      Metrics.Append (PM ("p2",  5, 1));
      Metrics.Append (PM ("p3",  8, 3));
      Metrics.Append (PM ("p4", 12, 0));

      Estimate_Parameters (Metrics, Setup, Tool_Call_Failure_Rate, Parameters => Params);

      --  Grand_P = 6/35 ~= 0.17143.
      Assert (abs (Params.Grand_P - 0.17143) < 5.0e-5,
              "Grand_P ~= 0.17143; got " & Long_Float'Image (Params.Grand_P));

      --  p chart limits at N=10.
      declare
         L : constant Limits_Record :=
           P_Chart.Compute_Limits (Grand_P => Params.Grand_P, N => 10);
      begin
         Assert (abs (L.UCL - 0.5290) < 5.0e-4,
                 "p UCL (N=10) ~= 0.5290; got " & Long_Float'Image (L.UCL));
         Assert (abs (L.CL - 0.1714) < 5.0e-4,
                 "p CL (N=10) ~= 0.1714; got " & Long_Float'Image (L.CL));
         Assert (L.LCL = 0.0,
                 "p LCL (N=10) = 0 (clamped); got " & Long_Float'Image (L.LCL));
      end;
   end Test_P_Chart_Known_Dataset;

   procedure Test_Estimate_P_Chart (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      --  Session 1: 2 tool calls, 1 failure → p1 = 0.5
      --  Session 2: 4 tool calls, 1 failure → p2 = 0.25
      --  Grand_P = 2/6 = 0.3333...
      S1 : Session_Record;
      S2 : Session_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;

      T1, T2, T3, T4, T5, T6 : Turn_Record;
      TC_Ok, TC_Fail : Tool_Call_Record;
   begin
      S1.Session_Id := To_Unbounded_String ("p1");
      TC_Ok.Failed  := False;
      TC_Fail.Failed := True;
      TC_Ok.Tool_Name   := To_Unbounded_String ("shell");
      TC_Fail.Tool_Name := To_Unbounded_String ("shell");

      --  Session 1: 1 turn, 2 tool calls (1 failure).
      T1.Turn_Index := 1;
      T1.Tool_Calls.Append (TC_Ok);
      T1.Tool_Calls.Append (TC_Fail);
      S1.Turns.Append (T1);

      S2.Session_Id := To_Unbounded_String ("p2");
      --  Session 2: 1 turn, 4 tool calls (1 failure).
      T2.Turn_Index := 1;
      T2.Tool_Calls.Append (TC_Ok);
      T2.Tool_Calls.Append (TC_Ok);
      T2.Tool_Calls.Append (TC_Ok);
      T2.Tool_Calls.Append (TC_Fail);
      S2.Turns.Append (T2);

      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));

      Estimate_Parameters (Metrics, Setup, Tool_Call_Failure_Rate, Parameters => Params);

      --  Grand_P = 2 failures / 6 total = 1/3.
      Assert
        (abs (Params.Grand_P - (1.0 / 3.0)) < 1.0e-6,
         "Grand_P should be 1/3; got " & Long_Float'Image (Params.Grand_P));
   end Test_Estimate_P_Chart;

   procedure Test_Estimate_N1_Only (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      --  All sessions have n=1: Pooled_S should be 0.
      S1, S2 : Session_Record;
      Turn   : Turn_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
   begin
      S1.Session_Id := To_Unbounded_String ("n1-1");
      Turn.Turn_Index    := 1;
      Turn.Output_Tokens := 50;
      S1.Turns.Append (Turn);

      S2.Session_Id := To_Unbounded_String ("n1-2");
      Turn.Output_Tokens := 150;
      S2.Turns.Append (Turn);

      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));

      Estimate_Parameters (Metrics, Setup, Turn_Tokens_Xbar, Parameters => Params);

      Assert
        (abs (Params.Grand_Mean - 100.0) < 1.0e-6,
         "Grand_Mean should be (50+150)/2=100; got "
         & Long_Float'Image (Params.Grand_Mean));
      Assert
        (abs (Params.Pooled_S) < 1.0e-9,
         "Pooled_S must be 0 when all sessions have n=1; got "
         & Long_Float'Image (Params.Pooled_S));
   end Test_Estimate_N1_Only;

   --  §14.1 special case: n=1 contributes to grand mean but not pooled s.
   procedure Test_N1_Excluded_From_Pooled_S (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;

      N1_Tokens : Natural_Vectors.Vector;  --  n=1 session
      N3_Tokens : Natural_Vectors.Vector;  --  n=3 session
   begin
      N1_Tokens.Append (50);

      N3_Tokens.Append (90);
      N3_Tokens.Append (100);
      N3_Tokens.Append (110);

      Metrics.Append (Coyote_SQC.Metrics.Compute (Make_Session ("n1", N1_Tokens)));
      Metrics.Append (Coyote_SQC.Metrics.Compute (Make_Session ("n3", N3_Tokens)));

      Estimate_Parameters (Metrics, Setup, Turn_Tokens_Xbar, Parameters => Params);

      --  Grand_Mean: (1*50 + 3*100) / 4 = 87.5.
      Assert (abs (Params.Grand_Mean - 87.5) < 1.0e-6,
              "Grand_Mean should be 87.5 (n=1 contributes); got "
              & Long_Float'Image (Params.Grand_Mean));

      --  Pooled_S: only n=3 session; std_dev([90,100,110]) = 10.
      Assert (abs (Params.Pooled_S - 10.0) < 1.0e-6,
              "Pooled_S should be 10.0 (n=1 excluded); got "
              & Long_Float'Image (Params.Pooled_S));
   end Test_N1_Excluded_From_Pooled_S;

   procedure Test_Estimate_Zero_Thinking (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      --  One session with thinking enabled (one thinking turn, 500 tokens).
      --  One session with no thinking enabled at all.
      --  Estimate_Parameters for Thinking_Tokens_Xbar should only see the
      --  first session.
      S_Thinking, S_No_Thinking : Session_Record;
      Turn_T, Turn_N            : Turn_Record;
      Metrics                   : Metrics_Vectors.Vector;
      Setup                     : UUID_Set;
      Params                    : Setup_Parameters;
   begin
      S_Thinking.Session_Id  := To_Unbounded_String ("thinker");
      Turn_T.Turn_Index      := 1;
      Turn_T.Thinking_Enabled := True;
      Turn_T.Thinking_Tokens  := 500;
      S_Thinking.Turns.Append (Turn_T);

      S_No_Thinking.Session_Id := To_Unbounded_String ("no-think");
      Turn_N.Turn_Index         := 1;
      Turn_N.Thinking_Enabled   := False;
      Turn_N.Output_Tokens      := 100;
      S_No_Thinking.Turns.Append (Turn_N);

      Metrics.Append (Coyote_SQC.Metrics.Compute (S_Thinking));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S_No_Thinking));

      Estimate_Parameters (Metrics, Setup, Thinking_Tokens_Xbar, Parameters => Params);

      --  Only the thinking session contributes; Grand_Mean = 500.
      Assert
        (abs (Params.Grand_Mean - 500.0) < 1.0e-6,
         "Grand_Mean for thinking chart should be 500; got "
         & Long_Float'Image (Params.Grand_Mean));
   end Test_Estimate_Zero_Thinking;


   --  §14.3 Tool_Call_Tokens charts skip sessions without tool calls.
   procedure Test_Estimate_Zero_Tool_Calls (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      --  One session with a tool-call turn:
      --    TC.Input_Tokens = 120, TC.Output_Tokens = 80 → Tool_Sum = 200.
      --  One session with no tool calls at all (output = 100 tokens).
      --  Estimate_Parameters for Tool_Call_Tokens_Xbar should only see the
      --  first session → Grand_Mean = 200.
      S_Tool, S_No_Tool : Session_Record;
      Turn_T, Turn_N    : Turn_Record;
      TC                : Tool_Call_Record;
      Metrics           : Metrics_Vectors.Vector;
      Setup             : UUID_Set;
      Params            : Setup_Parameters;
   begin
      S_Tool.Session_Id    := To_Unbounded_String ("tool");
      Turn_T.Turn_Index    := 1;
      Turn_T.Output_Tokens := 200;
      TC.Tool_Name         := To_Unbounded_String ("shell");
      TC.Input_Tokens      := 120;
      TC.Output_Tokens     := 80;
      Turn_T.Tool_Calls.Append (TC);
      S_Tool.Turns.Append (Turn_T);

      S_No_Tool.Session_Id   := To_Unbounded_String ("no-tool");
      Turn_N.Turn_Index      := 1;
      Turn_N.Output_Tokens   := 100;
      S_No_Tool.Turns.Append (Turn_N);

      Metrics.Append (Coyote_SQC.Metrics.Compute (S_Tool));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S_No_Tool));

      Estimate_Parameters (Metrics, Setup, Tool_Call_Tokens_Xbar, Parameters => Params);

      --  Only the tool-call session contributes; Grand_Mean = 200.
      Assert
        (abs (Params.Grand_Mean - 200.0) < 1.0e-6,
         "Grand_Mean for tool-call chart should be 200; got "
         & Long_Float'Image (Params.Grand_Mean));
   end Test_Estimate_Zero_Tool_Calls;

   --  §14.4 Per_Turn_Tool_Tokens is the sum of estimated per-TC token
   --  costs (Input_Tokens + Output_Tokens), not the whole-turn output.
   --  Session with two turns:
   --    Turn 1: 1 tool call, TC.Input=100, TC.Output=200 → Tool_Sum=300.
   --             Turn1.Output_Tokens=999 (intentionally different).
   --    Turn 2: no tool calls, output = 50 tokens.
   --  Per_Turn_Tool_Tokens should have length 1 (only turn 1), value 300.
   --  Grand_Mean = 300.
   procedure Test_Tool_Call_Token_Values (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;

      S       : Session_Record;
      Turn1, Turn2 : Turn_Record;
      TC      : Tool_Call_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
   begin
      S.Session_Id := To_Unbounded_String ("tc-vals");

      Turn1.Turn_Index    := 1;
      Turn1.Output_Tokens := 999;
      TC.Tool_Name        := To_Unbounded_String ("shell");
      TC.Input_Tokens     := 100;
      TC.Output_Tokens    := 200;
      Turn1.Tool_Calls.Append (TC);
      S.Turns.Append (Turn1);

      Turn2.Turn_Index    := 2;
      Turn2.Output_Tokens := 50;
      S.Turns.Append (Turn2);

      Metrics.Append (Coyote_SQC.Metrics.Compute (S));

      --  Check computed metrics directly.
      declare
         M : constant Session_Metrics_Record := Metrics.First_Element;
      begin
         Assert
           (Natural (M.Per_Turn_Tool_Tokens.Length) = 1,
            "Per_Turn_Tool_Tokens should have 1 entry; got "
            & Natural'Image (Natural (M.Per_Turn_Tool_Tokens.Length)));
         Assert
           (M.Per_Turn_Tool_Tokens.First_Element = 300,
            "Per_Turn_Tool_Tokens(1) should be 300; got "
            & Natural'Image (M.Per_Turn_Tool_Tokens.First_Element));
         Assert
           (M.N_Tool_Call_Turns_For_Chart = 1,
            "N_Tool_Call_Turns_For_Chart should be 1; got "
            & Natural'Image (M.N_Tool_Call_Turns_For_Chart));
      end;

      Estimate_Parameters (Metrics, Setup, Tool_Call_Tokens_Xbar, Parameters => Params);

      Assert
        (abs (Params.Grand_Mean - 300.0) < 1.0e-6,
         "Grand_Mean should be 300; got "
         & Long_Float'Image (Params.Grand_Mean));
   end Test_Tool_Call_Token_Values;


   --  ── I chart and MR chart tests ────────────────────────────────────────

   --  Three-session dataset: values 10, 20, 30.
   --    MR̄ = 10, x̄ = 20, d2 = 1.128
   --    Spread = 3 * 10 / 1.128 ≈ 26.5957...
   --    UCL ≈ 46.5957, LCL = max(0, -6.5957) = 0 → Has_LCL = False.
   procedure Test_I_Chart_Limits_Basic (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Grand_Mean : constant Long_Float := 20.0;
      Mean_MR    : constant Long_Float := 10.0;
      D2         : constant Long_Float := 1.128;
      Spread     : constant Long_Float := 3.0 * Mean_MR / D2;
      Lim        : constant Limits_Record :=
        Compute_I_Limits (Grand_Mean, Mean_MR / D2);
      Tol        : constant Long_Float := 1.0e-6;
   begin
      Assert (Lim.Has_UCL, "I chart basic: Has_UCL should be True");
      Assert (abs (Lim.UCL - (Grand_Mean + Spread)) <= Tol,
              "I chart basic: UCL mismatch; got "
              & Long_Float'Image (Lim.UCL));
      Assert (abs (Lim.CL - Grand_Mean) <= Tol,
              "I chart basic: CL mismatch");
      Assert (Lim.LCL = 0.0,
              "I chart basic: LCL should be clamped to 0; got "
              & Long_Float'Image (Lim.LCL));
      Assert (not Lim.Has_LCL,
              "I chart basic: Has_LCL should be False (clamped)");
   end Test_I_Chart_Limits_Basic;

   --  Dataset where LCL is positive: grand_mean = 1000, Mean_MR = 10.
   --    Spread ≈ 26.5957; LCL = 1000 - 26.5957 ≈ 973.4 > 0 → Has_LCL = True.
   procedure Test_I_Chart_LCL_Positive (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Grand_Mean : constant Long_Float := 1000.0;
      Mean_MR    : constant Long_Float := 10.0;
      D2         : constant Long_Float := 1.128;
      Spread     : constant Long_Float := 3.0 * Mean_MR / D2;
      Lim        : constant Limits_Record :=
        Compute_I_Limits (Grand_Mean, Mean_MR / D2);
      Tol        : constant Long_Float := 1.0e-6;
   begin
      Assert (Lim.Has_UCL, "I chart LCL+: Has_UCL should be True");
      Assert (Lim.Has_LCL, "I chart LCL+: Has_LCL should be True");
      Assert (abs (Lim.UCL - (Grand_Mean + Spread)) <= Tol,
              "I chart LCL+: UCL mismatch");
      Assert (abs (Lim.LCL - (Grand_Mean - Spread)) <= Tol,
              "I chart LCL+: LCL mismatch; got "
              & Long_Float'Image (Lim.LCL));
   end Test_I_Chart_LCL_Positive;

   --  Mean_MR = 0 → Has_UCL and Has_LCL both False; CL = Grand_Mean.
   procedure Test_I_Chart_Mean_MR_Zero (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Lim : constant Limits_Record := Compute_I_Limits (50.0, 0.0);
   begin
      Assert (not Lim.Has_UCL,
              "I chart MR=0: Has_UCL should be False");
      Assert (not Lim.Has_LCL,
              "I chart MR=0: Has_LCL should be False");
      Assert (Lim.CL = 50.0,
              "I chart MR=0: CL should equal Grand_Mean");
   end Test_I_Chart_Mean_MR_Zero;

   --  Verify LCL clamped when formula produces negative value.
   procedure Test_I_Chart_LCL_Clamped (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      --  Grand_Mean = 1, Mean_MR = 10 → Spread ≈ 26.6 → LCL < 0 → clamped.
      Lim : constant Limits_Record := Compute_I_Limits (1.0, 10.0 / 1.128);
   begin
      Assert (Lim.LCL = 0.0,
              "I chart clamped: LCL should be 0; got "
              & Long_Float'Image (Lim.LCL));
      Assert (not Lim.Has_LCL,
              "I chart clamped: Has_LCL should be False");
   end Test_I_Chart_LCL_Clamped;

   --  MR chart: Mean_MR = 10, UCL = 3.267 * 10 = 32.67.
   procedure Test_MR_Chart_Limits_Basic (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Mean_MR : constant Long_Float := 10.0;
      D4      : constant Long_Float := 3.267;
      Lim     : constant Limits_Record := Compute_MR_Limits (Mean_MR);
      Tol     : constant Long_Float := 1.0e-6;
   begin
      Assert (Lim.Has_UCL, "MR chart basic: Has_UCL should be True");
      Assert (abs (Lim.UCL - D4 * Mean_MR) <= Tol,
              "MR chart basic: UCL mismatch; got "
              & Long_Float'Image (Lim.UCL));
      Assert (abs (Lim.CL - Mean_MR) <= Tol,
              "MR chart basic: CL mismatch");
      Assert (Lim.LCL = 0.0,
              "MR chart basic: LCL should always be 0");
      Assert (not Lim.Has_LCL,
              "MR chart basic: Has_LCL should always be False");
   end Test_MR_Chart_Limits_Basic;

   --  MR chart: Mean_MR = 0 → Has_UCL = False.
   procedure Test_MR_Chart_Mean_MR_Zero (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Lim : constant Limits_Record := Compute_MR_Limits (0.0);
   begin
      Assert (not Lim.Has_UCL,
              "MR chart MR=0: Has_UCL should be False");
   end Test_MR_Chart_Mean_MR_Zero;

   --  Estimate_Parameters for Session_Input_Tokens_I:
   --  Three sessions with Total_Input_Tokens = 100, 200, 300.
   --    Grand_Mean = 200, MR1 = 100, MR2 = 100 → Mean_MR = 100.
   procedure Test_Estimate_I_Chart_Input (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      S1, S2, S3 : Session_Record;
      Turn1, Turn2, Turn3 : Turn_Record;
      Metrics    : Metrics_Vectors.Vector;
      Setup      : UUID_Set;
      Params     : Setup_Parameters;
      Tol        : constant Long_Float := 1.0e-6;
   begin
      S1.Session_Id         := To_Unbounded_String ("s1");
      S1.Total_Input_Tokens := 100;
      Turn1.Turn_Index      := 1;
      S1.Turns.Append (Turn1);

      S2.Session_Id         := To_Unbounded_String ("s2");
      S2.Total_Input_Tokens := 200;
      Turn2.Turn_Index      := 1;
      S2.Turns.Append (Turn2);

      S3.Session_Id         := To_Unbounded_String ("s3");
      S3.Total_Input_Tokens := 300;
      Turn3.Turn_Index      := 1;
      S3.Turns.Append (Turn3);

      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S3));

      Estimate_Parameters (Metrics, Setup, Session_Input_Tokens_I, Parameters => Params);

      Assert (abs (Params.Grand_Mean - 200.0) <= Tol,
              "I chart estimate: Grand_Mean should be 200; got "
              & Long_Float'Image (Params.Grand_Mean));
      Assert (abs (Params.Mean_MR - 100.0) <= Tol,
              "I chart estimate: Mean_MR should be 100; got "
              & Long_Float'Image (Params.Mean_MR));
   end Test_Estimate_I_Chart_Input;

   --  Single-session setup interval → only one session → no moving ranges
   --  → Mean_MR = 0.
   procedure Test_Estimate_I_Chart_Single (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      S      : Session_Record;
      Turn1  : Turn_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup  : UUID_Set;
      Params : Setup_Parameters;
   begin
      S.Session_Id         := To_Unbounded_String ("only");
      S.Total_Input_Tokens := 500;
      Turn1.Turn_Index     := 1;
      S.Turns.Append (Turn1);

      Metrics.Append (Coyote_SQC.Metrics.Compute (S));

      Estimate_Parameters (Metrics, Setup, Session_Input_Tokens_I, Parameters => Params);

      Assert (Params.Mean_MR = 0.0,
              "I chart single-session: Mean_MR should be 0; got "
              & Long_Float'Image (Params.Mean_MR));
   end Test_Estimate_I_Chart_Single;


   --  ── Box-Cox transformation tests ─────────────────────────────────────

   --  BC(x, 0) should equal ln(x).
   procedure Test_Box_Cox_Ln_Identity (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      use Ada.Numerics.Long_Elementary_Functions;
      Tol : constant Long_Float := 1.0e-10;
   begin
      for X of Long_Float_Array'(1 => 0.01, 2 => 1.0, 3 => 100.0, 4 => 10000.0)
      loop
         Assert
           (abs (Box_Cox (X, 0.0) - Log (X)) <= Tol,
            "Box_Cox(x,0) should equal ln(x) for x = "
            & Long_Float'Image (X));
      end loop;
   end Test_Box_Cox_Ln_Identity;

   --  BC(x, 1) should equal x - 1.
   procedure Test_Box_Cox_Lambda_One (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Tol : constant Long_Float := 1.0e-10;
   begin
      for X of Long_Float_Array'(1 => 0.01, 2 => 1.0, 3 => 100.0, 4 => 10000.0)
      loop
         Assert
           (abs (Box_Cox (X, 1.0) - (X - 1.0)) <= Tol,
            "Box_Cox(x,1) should equal x-1 for x = "
            & Long_Float'Image (X));
      end loop;
   end Test_Box_Cox_Lambda_One;

   --  Inverse(BC(x, lambda), lambda) should recover x to high precision.
   procedure Test_Box_Cox_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Tol : constant Long_Float := 1.0e-8;
      Xs  : constant Long_Float_Array :=
        (1.0, 10.0, 100.0, 1000.0, 10000.0);
      Ls  : constant Long_Float_Array :=
        (-1.0, 0.0, 0.5, 1.0, 2.0);
   begin
      for X of Xs loop
         for Lam of Ls loop
            declare
               Z   : constant Long_Float := Box_Cox (X, Lam);
               X2  : constant Long_Float := Box_Cox_Inverse (Z, Lam);
            begin
               Assert
                 (abs (X2 - X) <= Tol * (1.0 + abs X),
                  "Round-trip failed for x="
                  & Long_Float'Image (X)
                  & " lambda=" & Long_Float'Image (Lam)
                  & "; got " & Long_Float'Image (X2));
            end;
         end loop;
      end loop;
   end Test_Box_Cox_Round_Trip;

   --  Box_Cox(0.0, ...) should raise Constraint_Error.
   procedure Test_Box_Cox_Zero_Raises (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Raised : Boolean := False;
   begin
      begin
         declare
            Dummy : constant Long_Float := Box_Cox (0.0, 0.0);
            pragma Unreferenced (Dummy);
         begin
            null;
         end;
      exception
         when Constraint_Error => Raised := True;
      end;
      Assert (Raised, "Box_Cox(0.0, 0.0) should raise Constraint_Error");
   end Test_Box_Cox_Zero_Raises;

   --  Estimate_Lambda with fewer than 3 observations returns 0.0.

   --  Estimate_Lambda with fewer than 3 observations returns 0.0.
   procedure Test_Estimate_Lambda_Few_Obs (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Tol      : constant Long_Float := 1.0e-12;
      L1       : Long_Float;
      L2       : Long_Float;
      Fallback : Boolean;
   begin
      L1 := Estimate_Lambda (Long_Float_Array'(1 => 1000.0),
                             Fallback_Used => Fallback);
      L2 := Estimate_Lambda (Long_Float_Array'(1 => 100.0, 2 => 200.0),
                             Fallback_Used => Fallback);
      Assert
        (abs L1 <= Tol,
         "Estimate_Lambda with 1 obs should return 0.0; got "
         & Long_Float'Image (L1));
      Assert
        (abs L2 <= Tol,
         "Estimate_Lambda with 2 obs should return 0.0; got "
         & Long_Float'Image (L2));
   end Test_Estimate_Lambda_Few_Obs;
   --  I chart with Box-Cox (lambda=0): back-transformed UCL should equal
   --  exp(mean_z + 3*mean_mr_z/d2) for a known 3-value dataset.
   --  Values: 10, 100, 1000.
   --  z_i = ln(x_i): ln(10) ~ 2.3026, ln(100) ~ 4.6052, ln(1000) ~ 6.9078.
   --  mean_z = (2.3026 + 4.6052 + 6.9078)/3 = 4.6052.
   --  MR_1 = |4.6052 - 2.3026| = 2.3026.
   --  MR_2 = |6.9078 - 4.6052| = 2.3026.
   --  mean_mr_z = 2.3026.
   --  spread_z = 3 * 2.3026 / 1.128 ~ 6.1275.
   --  UCL_z = 4.6052 + 6.1275 = 10.7327 (approx).
   --  UCL_raw = exp(10.7327) ~ 45787.0 (approx).
   procedure Test_I_Limits_Box_Cox_Ln (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      use Ada.Numerics.Long_Elementary_Functions;
      --  Known data.
      V1        : constant Long_Float := 10.0;
      V2        : constant Long_Float := 100.0;
      V3        : constant Long_Float := 1000.0;
      Z1        : constant Long_Float := Log (V1);
      Z2        : constant Long_Float := Log (V2);
      Z3        : constant Long_Float := Log (V3);
      Mean_Z    : constant Long_Float := (Z1 + Z2 + Z3) / 3.0;
      MR1       : constant Long_Float := abs (Z2 - Z1);
      MR2       : constant Long_Float := abs (Z3 - Z2);
      Mean_MR_Z : constant Long_Float := (MR1 + MR2) / 2.0;
      D2        : constant Long_Float := 1.128;
      Spread    : constant Long_Float := 3.0 * Mean_MR_Z / D2;
      UCL_Z     : constant Long_Float := Mean_Z + Spread;
      UCL_Raw   : constant Long_Float := Exp (UCL_Z);
      --  Compute via Compute_I_Limits + Box_Cox_Inverse.
      Lim_Z     : constant Limits_Record :=
        Compute_I_Limits (Mean_Z, Mean_MR_Z / D2);
      UCL_BT    : constant Long_Float :=
        Box_Cox_Inverse (Lim_Z.UCL, 0.0);
      CL_BT     : constant Long_Float :=
        Box_Cox_Inverse (Lim_Z.CL, 0.0);
      CL_Raw    : constant Long_Float := Exp (Mean_Z);
      Tol       : constant Long_Float := 1.0e-4;
   begin
      Assert
        (Lim_Z.Has_UCL,
         "I chart Box-Cox ln: limits should be computable");
      Assert
        (abs (UCL_BT - UCL_Raw) <= Tol * UCL_Raw,
         "Back-transformed UCL should match exp(UCL_z); got "
         & Long_Float'Image (UCL_BT)
         & " expected " & Long_Float'Image (UCL_Raw));
      Assert
        (abs (CL_BT - CL_Raw) <= Tol * CL_Raw,
         "Back-transformed CL should match exp(mean_z); got "
         & Long_Float'Image (CL_BT)
         & " expected " & Long_Float'Image (CL_Raw));
   end Test_I_Limits_Box_Cox_Ln;

   --  MR chart with Box-Cox: MR values should be differences of
   --  transformed values, not raw differences.
   --  Values: 10, 100, 1000 with lambda=0.
   --  MR_1 = |ln(100) - ln(10)| = ln(10) ~ 2.3026.
   procedure Test_Box_Cox_MR_Transformed (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      use Ada.Numerics.Long_Elementary_Functions;
      V1       : constant Long_Float := 10.0;
      V2       : constant Long_Float := 100.0;
      Expected : constant Long_Float :=
        abs (Log (V2) - Log (V1));
      Got      : constant Long_Float :=
        abs (Box_Cox (V2, 0.0) - Box_Cox (V1, 0.0));
      Tol      : constant Long_Float := 1.0e-10;
   begin
      Assert
        (abs (Got - Expected) <= Tol,
         "BC MR value should be |ln(100)-ln(10)|; got "
         & Long_Float'Image (Got)
         & " expected " & Long_Float'Image (Expected));
   end Test_Box_Cox_MR_Transformed;

   --  ── Qn scale estimator tests ──────────────────────────────────────────

   --  N=3 known value: {10, 20, 30}.
   --  Pairs sorted: {10, 10, 20}.  H=1, d_(1)=10.  c_3=0.994.
   --  Expected = 0.994 * 2.2219 * 10 = 22.086.
   procedure Test_Qn_Scale_N3_Known (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Result : constant Long_Float :=
        Qn_Scale (Long_Float_Array'(10.0, 20.0, 30.0));
      Expected : constant Long_Float := 22.086;
      Tol      : constant Long_Float := 0.01;
   begin
      Assert
        (abs (Result - Expected) <= Tol,
         "Qn_Scale({10,20,30}) expected ~22.086, got "
         & Long_Float'Image (Result));
   end Test_Qn_Scale_N3_Known;

   --  N=4 known value: {1, 2, 4, 8}.
   --  Pairs sorted: {1,2,3,4,6,7}.  H=3, d_(3)=3.  c_4=0.512.
   --  Expected = 0.512 * 2.2219 * 3 = 3.413.
   procedure Test_Qn_Scale_N4_Known (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Result : constant Long_Float :=
        Qn_Scale (Long_Float_Array'(1.0, 2.0, 4.0, 8.0));
      Expected : constant Long_Float := 3.413;
      Tol      : constant Long_Float := 0.01;
   begin
      Assert
        (abs (Result - Expected) <= Tol,
         "Qn_Scale({1,2,4,8}) expected ~3.413, got "
         & Long_Float'Image (Result));
   end Test_Qn_Scale_N4_Known;

   --  N < 2 must raise Constraint_Error.
   procedure Test_Qn_Scale_N_Less_2_Raises (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Raised : Boolean := False;
   begin
      begin
         declare
            Dummy : constant Long_Float :=
              Qn_Scale (Long_Float_Array'(1 => 5.0));
            pragma Unreferenced (Dummy);
         begin
            null;
         end;
      exception
         when Constraint_Error => Raised := True;
      end;
      Assert (Raised, "Qn_Scale with N=1 should raise Constraint_Error");
   end Test_Qn_Scale_N_Less_2_Raises;

   --  Non-positive value must raise Constraint_Error.
   procedure Test_Qn_Scale_Zero_Raises (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Raised : Boolean := False;
   begin
      begin
         declare
            Dummy : constant Long_Float :=
              Qn_Scale (Long_Float_Array'(1.0, 0.0, 3.0));
            pragma Unreferenced (Dummy);
         begin
            null;
         end;
      exception
         when Constraint_Error => Raised := True;
      end;
      Assert (Raised,
              "Qn_Scale with a zero value should raise Constraint_Error");
   end Test_Qn_Scale_Zero_Raises;

   --  N=20 (even asymptotic formula): result is positive and finite.
   procedure Test_Qn_Scale_Asymptotic_Even (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Values : Long_Float_Array (1 .. 20);
      Result : Long_Float;
   begin
      for I in Values'Range loop
         Values (I) := Long_Float (I);
      end loop;
      Result := Qn_Scale (Values);
      Assert (Result > 0.0,
              "Qn_Scale N=20 should return positive value; got "
              & Long_Float'Image (Result));
   end Test_Qn_Scale_Asymptotic_Even;

   --  N=11 (odd asymptotic formula): result is positive and finite.
   procedure Test_Qn_Scale_Asymptotic_Odd (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Values : Long_Float_Array (1 .. 11);
      Result : Long_Float;
   begin
      for I in Values'Range loop
         Values (I) := Long_Float (I);
      end loop;
      Result := Qn_Scale (Values);
      Assert (Result > 0.0,
              "Qn_Scale N=11 should return positive value; got "
              & Long_Float'Image (Result));
   end Test_Qn_Scale_Asymptotic_Odd;

   --  ── Robust Estimate_Lambda tests ─────────────────────────────────────

   --  Fewer than 3 observations returns 0.0 regardless of Use_Robust.

   procedure Test_Estimate_Lambda_Robust_Few_Obs (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      R1       : Long_Float;
      R2       : Long_Float;
      Fallback : Boolean;
   begin
      R1 := Estimate_Lambda (Long_Float_Array'(1 => 5.0),
                             Use_Robust => True, Fallback_Used => Fallback);
      R2 := Estimate_Lambda (Long_Float_Array'(5.0, 10.0),
                             Use_Robust => True, Fallback_Used => Fallback);
      Assert (R1 = 0.0,
              "Robust Estimate_Lambda with 1 obs should return 0.0; got "
              & Long_Float'Image (R1));
      Assert (R2 = 0.0,
              "Robust Estimate_Lambda with 2 obs should return 0.0; got "
              & Long_Float'Image (R2));
   end Test_Estimate_Lambda_Robust_Few_Obs;
   --  Robust estimate on a right-skewed positive dataset returns a
   --  value in [-5.0, 5.0].

   procedure Test_Estimate_Lambda_Robust_Basic (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      --  Exponential-like data: right-skewed, log transform should help.
      Data          : constant Long_Float_Array :=
        (1.0, 2.0, 3.0, 5.0, 8.0, 13.0, 21.0, 34.0, 55.0, 89.0);
      Lambda_MLE    : Long_Float;
      Lambda_Robust : Long_Float;
      Fallback      : Boolean;
   begin
      Lambda_MLE := Estimate_Lambda
                      (Data, Use_Robust => False, Fallback_Used => Fallback);
      Lambda_Robust := Estimate_Lambda
                         (Data, Use_Robust => True, Fallback_Used => Fallback);
      Assert
        (Lambda_MLE >= -5.0 and Lambda_MLE <= 5.0,
         "MLE Estimate_Lambda should be in [-5,5]; got "
         & Long_Float'Image (Lambda_MLE));
      Assert
        (Lambda_Robust >= -5.0 and Lambda_Robust <= 5.0,
         "Robust Estimate_Lambda should be in [-5,5]; got "
         & Long_Float'Image (Lambda_Robust));
   end Test_Estimate_Lambda_Robust_Basic;

   --  All-identical data is degenerate: log-likelihood is undefined for every
   --  lambda.  Estimate_Lambda must return 0.0 and set Fallback_Used = True.
   procedure Test_Estimate_Lambda_Degenerate (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Data     : constant Long_Float_Array := (5.0, 5.0, 5.0, 5.0, 5.0);
      Lambda   : Long_Float;
      Fallback : Boolean;
   begin
      Lambda := Estimate_Lambda (Data, Fallback_Used => Fallback);
      Assert
        (abs Lambda <= 1.0e-12,
         "All-identical data should return lambda = 0.0; got "
         & Long_Float'Image (Lambda));
      Assert
        (Fallback,
         "All-identical data should set Fallback_Used = True");
   end Test_Estimate_Lambda_Degenerate;


   --  ── EWMA chart tests ──────────────────────────────────────────────────

   procedure Test_EWMA_Compute_Z_Single_Step (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.EWMA_Chart;
      Tol      : constant Long_Float := 1.0e-10;
      Weight   : constant Long_Float := 0.2;
      Z0       : constant Long_Float := 80.0;
      X1       : constant Long_Float := 100.0;
      Expected : constant Long_Float := 0.2 * 100.0 + 0.8 * 80.0;  --  84.0
      Got      : constant Long_Float := Compute_Z (X1, Z0, Weight);
   begin
      Assert (abs (Got - Expected) <= Tol,
              "EWMA Z_1 wrong; got " & Long_Float'Image (Got)
              & " expected " & Long_Float'Image (Expected));
   end Test_EWMA_Compute_Z_Single_Step;

   procedure Test_EWMA_Compute_Z_Multi_Step (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.EWMA_Chart;
      Tol    : constant Long_Float := 1.0e-10;
      Weight : constant Long_Float := 0.2;
      Z0     : constant Long_Float := 100.0;
      Z1     : constant Long_Float := Compute_Z (110.0, Z0, Weight);
      --  Z1 = 0.2*110 + 0.8*100 = 102.0
      Z2     : constant Long_Float := Compute_Z (90.0, Z1, Weight);
      --  Z2 = 0.2*90  + 0.8*102 = 18 + 81.6 = 99.6
   begin
      Assert (abs (Z1 - 102.0) <= Tol,
              "EWMA Z_1 wrong; got " & Long_Float'Image (Z1));
      Assert (abs (Z2 - 99.6) <= Tol,
              "EWMA Z_2 wrong; got " & Long_Float'Image (Z2));
   end Test_EWMA_Compute_Z_Multi_Step;

   procedure Test_EWMA_Limits_T1 (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.EWMA_Chart;
      --  Grand_Mean=100, Sigma=10, Weight=0.2, L=3, T=1.
      --  Scale = sqrt(0.2/1.8 * (1 - 0.8^2)) = sqrt(0.04) = 0.2
      --  Half  = 3*10*0.2 = 6
      Lim  : constant Limits_Record :=
        Compute_EWMA_Limits
          (Grand_Mean => 100.0,
           Sigma      => 10.0,
           Weight     => 0.2,
           L          => 3.0,
           T          => 1);
      Tol  : constant Long_Float := 1.0e-8;
   begin
      Assert (Lim.Has_UCL,
              "EWMA T=1 should have UCL");
      Assert (abs (Lim.UCL - 106.0) <= Tol,
              "UCL wrong; got " & Long_Float'Image (Lim.UCL));
      Assert (abs (Lim.CL - 100.0) <= Tol,
              "CL wrong; got " & Long_Float'Image (Lim.CL));
      Assert (Lim.Has_LCL,
              "LCL should be positive at T=1 (100-6=94)");
      Assert (abs (Lim.LCL - 94.0) <= Tol,
              "LCL wrong; got " & Long_Float'Image (Lim.LCL));
   end Test_EWMA_Limits_T1;

   procedure Test_EWMA_Limits_Steady_State (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.EWMA_Chart;
      use Ada.Numerics.Long_Elementary_Functions;
      --  Grand_Mean=100, Sigma=10, Weight=0.2, L=3, T=1000 (near steady state).
      --  Steady-state half-width = 3*10*sqrt(0.2/1.8) = 30/3 = 10.0
      Lim           : constant Limits_Record :=
        Compute_EWMA_Limits
          (Grand_Mean => 100.0,
           Sigma      => 10.0,
           Weight     => 0.2,
           L          => 3.0,
           T          => 1000);
      Steady_HW     : constant Long_Float :=
        3.0 * 10.0 * Sqrt (0.2 / (2.0 - 0.2));
      Tol           : constant Long_Float := 0.001;
   begin
      Assert (Lim.Has_UCL,
              "Steady-state EWMA should have UCL");
      Assert (abs (Lim.UCL - (100.0 + Steady_HW)) <= Tol,
              "UCL near steady-state wrong; got " & Long_Float'Image (Lim.UCL));
      Assert (abs (Lim.LCL - (100.0 - Steady_HW)) <= Tol,
              "LCL near steady-state wrong; got " & Long_Float'Image (Lim.LCL));
   end Test_EWMA_Limits_Steady_State;

   procedure Test_EWMA_Limits_Zero_Sigma (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.EWMA_Chart;
      Lim : constant Limits_Record :=
        Compute_EWMA_Limits
          (Grand_Mean => 100.0,
           Sigma      => 0.0,
           Weight     => 0.2,
           L          => 3.0,
           T          => 5);
   begin
      Assert (not Lim.Has_UCL,
              "Zero sigma should give Has_UCL = False");
      Assert (not Lim.Has_LCL,
              "Zero sigma should give Has_LCL = False");
   end Test_EWMA_Limits_Zero_Sigma;

   procedure Test_EWMA_Limits_LCL_Clamped (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.EWMA_Chart;
      --  Grand_Mean=1, Sigma=5, Weight=0.5, L=3, T=1.
      --  Scale = sqrt(0.5/1.5 * (1 - 0.25)) = sqrt(0.25) = 0.5
      --  Half  = 3*5*0.5 = 7.5
      --  Raw LCL = 1 - 7.5 = -6.5 -> clamped to 0, Has_LCL = False.
      Lim : constant Limits_Record :=
        Compute_EWMA_Limits
          (Grand_Mean => 1.0,
           Sigma      => 5.0,
           Weight     => 0.5,
           L          => 3.0,
           T          => 1);
      Tol : constant Long_Float := 1.0e-8;
   begin
      Assert (Lim.Has_UCL,
              "UCL should be present");
      Assert (abs (Lim.UCL - 8.5) <= Tol,
              "UCL wrong; got " & Long_Float'Image (Lim.UCL));
      Assert (not Lim.Has_LCL,
              "Has_LCL should be False when raw LCL < 0");
      Assert (abs (Lim.LCL - 0.0) <= Tol,
              "Clamped LCL should be 0; got " & Long_Float'Image (Lim.LCL));
   end Test_EWMA_Limits_LCL_Clamped;


   --  ── Median_Of helper tests ────────────────────────────────────────────

   procedure Test_Median_Of_Basic (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Statistics;
      Vals : constant LF_Value_Array := (1.0, 3.0, 2.0, 5.0, 4.0);
      Tol  : constant Long_Float := 1.0e-10;
   begin
      Assert (abs (Median_Of (Vals) - 3.0) <= Tol,
              "Median of 5 elements should be 3.0; got "
              & Long_Float'Image (Median_Of (Vals)));
   end Test_Median_Of_Basic;

   procedure Test_Median_Of_Even (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Statistics;
      Vals : constant LF_Value_Array := (1.0, 4.0, 2.0, 3.0);
      Tol  : constant Long_Float := 1.0e-10;
   begin
      Assert (abs (Median_Of (Vals) - 2.5) <= Tol,
              "Median of 4 elements should be 2.5; got "
              & Long_Float'Image (Median_Of (Vals)));
   end Test_Median_Of_Even;

   procedure Test_Median_Of_Single (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Statistics;
      Vals : constant LF_Value_Array := (1 => 42.0);
      Tol  : constant Long_Float := 1.0e-10;
   begin
      Assert (abs (Median_Of (Vals) - 42.0) <= Tol,
              "Median of 1 element should be 42.0");
   end Test_Median_Of_Single;

   procedure Test_Median_Of_Empty (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Statistics;
      Vals : constant LF_Value_Array (1 .. 0) := (others => 0.0);
      Tol  : constant Long_Float := 1.0e-10;
   begin
      Assert (abs (Median_Of (Vals) - 0.0) <= Tol,
              "Median of empty array should be 0.0");
   end Test_Median_Of_Empty;

   procedure Test_Median_Of_Unsorted (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Statistics;
      Vals : constant LF_Value_Array := (5.0, 1.0, 3.0);
      Tol  : constant Long_Float := 1.0e-10;
   begin
      Assert (abs (Median_Of (Vals) - 3.0) <= Tol,
              "Median of unsorted [5,1,3] should be 3.0; got "
              & Long_Float'Image (Median_Of (Vals)));
   end Test_Median_Of_Unsorted;

   --  ── Robust I/MR estimation tests ─────────────────────────────────────

   procedure Test_Robust_I_Chart_Grand_Mean (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Five sessions: one extreme outlier at the end.
      --  Observations: 100, 110, 90, 120, 5000.
      --  Sorted: 90, 100, 110, 120, 5000.
      --  Median = 110 (middle of 5).
      S1, S2, S3, S4, S5 : Session_Record;
      T1, T2, T3, T4, T5 : Turn_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      S1.Session_Id := To_Unbounded_String ("s1");
      S1.Total_Input_Tokens := 100; T1.Turn_Index := 1; S1.Turns.Append (T1);
      S2.Session_Id := To_Unbounded_String ("s2");
      S2.Total_Input_Tokens := 110; T2.Turn_Index := 1; S2.Turns.Append (T2);
      S3.Session_Id := To_Unbounded_String ("s3");
      S3.Total_Input_Tokens := 90;  T3.Turn_Index := 1; S3.Turns.Append (T3);
      S4.Session_Id := To_Unbounded_String ("s4");
      S4.Total_Input_Tokens := 120; T4.Turn_Index := 1; S4.Turns.Append (T4);
      S5.Session_Id := To_Unbounded_String ("s5");
      S5.Total_Input_Tokens := 5000; T5.Turn_Index := 1; S5.Turns.Append (T5);
      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S3));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S4));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S5));
      Estimate_Parameters
        (Metrics, Setup, Session_Input_Tokens_I,
         Method => Robust_Median, Parameters => Params);
      Assert (abs (Params.Grand_Mean - 110.0) <= Tol,
              "Robust Grand_Mean should be 110 (median); got "
              & Long_Float'Image (Params.Grand_Mean));
      --  Verify classical gives a different (outlier-inflated) result.
      declare
         Params_C : Setup_Parameters;
      begin
         Estimate_Parameters
           (Metrics, Setup, Session_Input_Tokens_I,
            Method => Classical, Parameters => Params_C);
         Assert (Params_C.Grand_Mean > 1000.0,
                 "Classical Grand_Mean should be much larger (outlier "
                 & "inflated); got "
                 & Long_Float'Image (Params_C.Grand_Mean));
      end;
   end Test_Robust_I_Chart_Grand_Mean;

   procedure Test_Robust_I_Chart_Mean_MR (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Observations in order: 100, 110, 90, 120, 130.
      --  MRs: |110-100|=10, |90-110|=20, |120-90|=30, |130-120|=10.
      --  Sorted MRs: 10, 10, 20, 30. Median = (10+20)/2 = 15.
      S1, S2, S3, S4, S5 : Session_Record;
      T1, T2, T3, T4, T5 : Turn_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      S1.Session_Id := To_Unbounded_String ("s1");
      S1.Total_Input_Tokens := 100;
      T1.Turn_Index := 1; S1.Turns.Append (T1);
      S2.Session_Id := To_Unbounded_String ("s2");
      S2.Total_Input_Tokens := 110;
      T2.Turn_Index := 1; S2.Turns.Append (T2);
      S3.Session_Id := To_Unbounded_String ("s3");
      S3.Total_Input_Tokens := 90;
      T3.Turn_Index := 1; S3.Turns.Append (T3);
      S4.Session_Id := To_Unbounded_String ("s4");
      S4.Total_Input_Tokens := 120;
      T4.Turn_Index := 1; S4.Turns.Append (T4);
      S5.Session_Id := To_Unbounded_String ("s5");
      S5.Total_Input_Tokens := 130;
      T5.Turn_Index := 1; S5.Turns.Append (T5);
      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S3));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S4));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S5));
      Estimate_Parameters
        (Metrics, Setup, Session_Input_Tokens_I,
         Method => Robust_Median, Parameters => Params);
      Assert (abs (Params.Mean_MR - 15.0) <= Tol,
              "Robust Mean_MR should be 15 (median of MRs); got "
              & Long_Float'Image (Params.Mean_MR));
      --  I_Sigma: Qn(obs) / 2.2219 (robust mode)
      declare
         use Coyote_SQC.Statistics.I_Chart;
         Obs : constant Long_Float_Array :=
           (100.0, 110.0, 90.0, 120.0, 130.0);
         Expected_Sigma : constant Long_Float :=
           Qn_Scale_Any (Obs) / 2.2219;
      begin
         Assert (abs (Params.I_Sigma - Expected_Sigma) <= Tol,
                 "Robust I_Sigma should equal Qn(obs)/2.2219; got "
                 & Long_Float'Image (Params.I_Sigma)
                 & ", expected " & Long_Float'Image (Expected_Sigma));
      end;
   end Test_Robust_I_Chart_Mean_MR;

   procedure Test_Robust_I_Limits_Divisor (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Statistics.I_Chart;
      --  Verify Compute_I_Limits uses Sigma directly (no internal divisor).
      --  With Grand_Mean=100, Sigma=15 (pre-computed by caller):
      --    UCL = 100 + 3*15 = 145, LCL = 100 - 3*15 = 55.
      Grand_Mean : constant Long_Float := 100.0;
      Sigma      : constant Long_Float := 15.0;
      Lim        : constant Limits_Record :=
        Compute_I_Limits
          (Grand_Mean => Grand_Mean,
           Sigma      => Sigma);
      Tol : constant Long_Float := 1.0e-6;
   begin
      Assert (abs (Lim.UCL - (Grand_Mean + 3.0 * Sigma)) <= Tol,
              "Compute_I_Limits: UCL should be Grand_Mean + 3*Sigma; got "
              & Long_Float'Image (Lim.UCL));
      Assert (abs (Lim.LCL - (Grand_Mean - 3.0 * Sigma)) <= Tol,
              "Compute_I_Limits: LCL should be Grand_Mean - 3*Sigma; got "
              & Long_Float'Image (Lim.LCL));
      Assert (Lim.Has_UCL, "Compute_I_Limits: Has_UCL should be True");
      Assert (Lim.Has_LCL, "Compute_I_Limits: Has_LCL should be True");
   end Test_Robust_I_Limits_Divisor;

   procedure Test_Robust_MR_UCL (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      use Coyote_SQC.Statistics.I_Chart;
      --  Observations: 100, 110, 90, 120, 130.
      --  MRs: 10, 20, 30, 10.  median = 15; mean = 17.5.
      --  Robust UCL = D4 * median = 3.267 * 15 = 49.005.
      --  Classical UCL = D4 * mean  = 3.267 * 17.5 = 57.1725.
      D4  : constant Long_Float := 3.267;
      S1, S2, S3, S4, S5 : Session_Record;
      T1  : Turn_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params_R, Params_C : Setup_Parameters;
      Tol : constant Long_Float := 1.0e-3;
   begin
      S1.Session_Id := To_Unbounded_String ("s1");
      S1.Total_Input_Tokens := 100; T1.Turn_Index := 1;
      S1.Turns.Append (T1);
      S2.Session_Id := To_Unbounded_String ("s2");
      S2.Total_Input_Tokens := 110; S2.Turns.Append (T1);
      S3.Session_Id := To_Unbounded_String ("s3");
      S3.Total_Input_Tokens := 90;  S3.Turns.Append (T1);
      S4.Session_Id := To_Unbounded_String ("s4");
      S4.Total_Input_Tokens := 120; S4.Turns.Append (T1);
      S5.Session_Id := To_Unbounded_String ("s5");
      S5.Total_Input_Tokens := 130; S5.Turns.Append (T1);
      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S3));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S4));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S5));
      Estimate_Parameters
        (Metrics, Setup, Session_Input_Tokens_MR,
         Method => Robust_Median, Parameters => Params_R);
      Estimate_Parameters
        (Metrics, Setup, Session_Input_Tokens_MR,
         Method => Classical, Parameters => Params_C);
      declare
         UCL_R : constant Long_Float :=
           Compute_MR_Limits (Params_R.Mean_MR).UCL;
         UCL_C : constant Long_Float :=
           Compute_MR_Limits (Params_C.Mean_MR).UCL;
      begin
         Assert (abs (UCL_R - D4 * 15.0) <= Tol,
                 "Robust MR UCL should be D4 * median(MR) = "
                 & Long_Float'Image (D4 * 15.0)
                 & "; got " & Long_Float'Image (UCL_R));
         Assert (abs (UCL_C - D4 * 17.5) <= Tol,
                 "Classical MR UCL should be D4 * mean(MR) = "
                 & Long_Float'Image (D4 * 17.5)
                 & "; got " & Long_Float'Image (UCL_C));
         Assert (UCL_R < UCL_C,
                 "Robust MR UCL should be less than classical (median < mean)");
      end;
   end Test_Robust_MR_UCL;

   --  ── Robust Xbar/s estimation tests ────────────────────────────────────

   procedure Test_Robust_Xbar_Grand_Mean (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Three sessions, each with 3 turns.
      --  Session means (equal subgroups): 50, 60, 5000.
      --  Robust Grand_Mean = median([50, 60, 5000]) = 60.
      S1, S2, S3 : Session_Record;
      Metrics    : Metrics_Vectors.Vector;
      Setup      : UUID_Set;
      Params     : Setup_Parameters;
      Tol        : constant Long_Float := 1.0e-6;
   begin
      S1.Session_Id := To_Unbounded_String ("s1");
      for I in 1 .. 3 loop
         declare T1 : Turn_Record; begin
            T1.Turn_Index := I;
            T1.Output_Tokens := 50;
            S1.Turns.Append (T1);
         end;
      end loop;
      S2.Session_Id := To_Unbounded_String ("s2");
      for I in 1 .. 3 loop
         declare T2 : Turn_Record; begin
            T2.Turn_Index := I;
            T2.Output_Tokens := 60;
            S2.Turns.Append (T2);
         end;
      end loop;
      S3.Session_Id := To_Unbounded_String ("s3");
      for I in 1 .. 3 loop
         declare T3 : Turn_Record; begin
            T3.Turn_Index := I;
            T3.Output_Tokens := 5000;
            S3.Turns.Append (T3);
         end;
      end loop;
      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S3));
      Estimate_Parameters
        (Metrics, Setup, Turn_Tokens_Xbar,
         Method => Robust_Median, Parameters => Params);
      Assert (abs (Params.Grand_Mean - 60.0) <= Tol,
              "Robust Xbar Grand_Mean should be 60 (median of session "
              & "means); got " & Long_Float'Image (Params.Grand_Mean));
   end Test_Robust_Xbar_Grand_Mean;

   procedure Test_Robust_Xbar_Pooled_S (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Two sessions, 3 turns each.
      --  Session 1: [90, 100, 110] → mean=100, residuals [-10, 0, 10].
      --  Session 2: [90, 100, 110] → mean=100, residuals [-10, 0, 10].
      --  The pooled residuals are symmetric around 0; Qn should return > 0.
      --  Also verify robust /= classical when sessions differ.
      S1, S2 : Session_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;
      Tol     : constant Long_Float := 1.0e-6;
   begin
      S1.Session_Id := To_Unbounded_String ("s1");
      declare
         T1a, T1b, T1c : Turn_Record;
      begin
         T1a.Turn_Index := 1; T1a.Output_Tokens := 90;
         T1b.Turn_Index := 2; T1b.Output_Tokens := 100;
         T1c.Turn_Index := 3; T1c.Output_Tokens := 110;
         S1.Turns.Append (T1a);
         S1.Turns.Append (T1b);
         S1.Turns.Append (T1c);
      end;
      S2.Session_Id := To_Unbounded_String ("s2");
      declare
         T2a, T2b, T2c : Turn_Record;
      begin
         T2a.Turn_Index := 1; T2a.Output_Tokens := 90;
         T2b.Turn_Index := 2; T2b.Output_Tokens := 100;
         T2c.Turn_Index := 3; T2c.Output_Tokens := 110;
         S2.Turns.Append (T2a);
         S2.Turns.Append (T2b);
         S2.Turns.Append (T2c);
      end;
      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));
      Estimate_Parameters
        (Metrics, Setup, Turn_Tokens_Xbar,
         Method => Robust_Median, Parameters => Params);
      Assert (Params.Pooled_S > 0.0,
              "Robust Pooled_S should be > 0 when residuals are non-zero; "
              & "got " & Long_Float'Image (Params.Pooled_S));
      --  The Qn-based estimate should be close to the classical for
      --  symmetric data (both estimate sigma of the underlying normal).
      Assert (Params.Pooled_S < 20.0,
              "Robust Pooled_S should be finite; got "
              & Long_Float'Image (Params.Pooled_S));
      declare
         Params_C : Setup_Parameters;
      begin
         Estimate_Parameters
           (Metrics, Setup, Turn_Tokens_Xbar,
            Method => Classical, Parameters => Params_C);
         Assert (Params_C.Pooled_S > 0.0,
                 "Classical Pooled_S should also be > 0");
         --  For symmetric data both estimators should be in the same
         --  ballpark (within 50% of each other).
         Assert (abs (Params.Pooled_S / Params_C.Pooled_S - 1.0) < 0.5,
                 "Robust and classical Pooled_S should be in the same "
                 & "ballpark for symmetric data; robust="
                 & Long_Float'Image (Params.Pooled_S)
                 & " classical=" & Long_Float'Image (Params_C.Pooled_S));
      end;
      pragma Unreferenced (Tol);
   end Test_Robust_Xbar_Pooled_S;

   --  ── Robust p-chart unchanged test ─────────────────────────────────────

   procedure Test_Robust_P_Chart_Unchanged (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Two sessions: S1 has 5 failures in 10 tool calls;
      --  S2 has 5 failures in 10 tool calls.  Grand_P = 0.5.
      S1, S2 : Session_Record;
      T1, T2 : Turn_Record;
      TC1, TC2, TC3, TC4, TC5 : Tool_Call_Record;
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params_C, Params_R : Setup_Parameters;
      Tol : constant Long_Float := 1.0e-10;
   begin
      S1.Session_Id := To_Unbounded_String ("s1");
      T1.Turn_Index := 1;
      TC1.Failed := True;  TC2.Failed := True;
      TC3.Failed := False; TC4.Failed := False; TC5.Failed := False;
      T1.Tool_Calls.Append (TC1); T1.Tool_Calls.Append (TC2);
      T1.Tool_Calls.Append (TC3); T1.Tool_Calls.Append (TC4);
      T1.Tool_Calls.Append (TC5);
      S1.Turns.Append (T1);

      S2.Session_Id := To_Unbounded_String ("s2");
      T2.Turn_Index := 1;
      declare
         TC6, TC7, TC8, TC9, TC10 : Tool_Call_Record;
      begin
         TC6.Failed := True;  TC7.Failed := True;
         TC8.Failed := False; TC9.Failed := False; TC10.Failed := False;
         T2.Tool_Calls.Append (TC6); T2.Tool_Calls.Append (TC7);
         T2.Tool_Calls.Append (TC8); T2.Tool_Calls.Append (TC9);
         T2.Tool_Calls.Append (TC10);
      end;
      S2.Turns.Append (T2);

      Metrics.Append (Coyote_SQC.Metrics.Compute (S1));
      Metrics.Append (Coyote_SQC.Metrics.Compute (S2));

      Estimate_Parameters
        (Metrics, Setup, Tool_Call_Failure_Rate,
         Method => Classical, Parameters => Params_C);
      Estimate_Parameters
        (Metrics, Setup, Tool_Call_Failure_Rate,
         Method => Robust_Median, Parameters => Params_R);

      Assert (abs (Params_C.Grand_P - 0.4) <= Tol,
              "Classical Grand_P wrong; got "
              & Long_Float'Image (Params_C.Grand_P));
      Assert (abs (Params_R.Grand_P - 0.4) <= Tol,
              "Robust Grand_P should equal classical for p-charts; got "
              & Long_Float'Image (Params_R.Grand_P));
   end Test_Robust_P_Chart_Unchanged;

   --  ── Fraction thinking / tool-call tokens p-chart tests ─────────────────

   --  Two sessions with known thinking and output token totals;
   --  Grand_P = total_thinking / total_output.
   procedure Test_Fraction_Thinking_Tokens_Grand_Mean (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Session 1: 200 thinking tokens, 800 output tokens → p1 = 0.25
      --  Session 2: 100 thinking tokens, 400 output tokens → p2 = 0.25
      --  Grand_Mean = 300 / 1200 = 0.25
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;

      function MK (Id : String; Think, Output : Natural)
                   return Session_Metrics_Record is
         M : Session_Metrics_Record;
      begin
         M.Session_Id            := To_Unbounded_String (Id);
         M.N_Turns               := 1;
         M.Total_Thinking_Tokens := Think;
         M.Total_Output_Tokens   := Output;
         return M;
      end MK;
   begin
      Metrics.Append (MK ("t1", 200, 800));
      Metrics.Append (MK ("t2", 100, 400));

      Estimate_Parameters
        (Metrics, Setup, Fraction_Thinking_Tokens_I, Parameters => Params);

      Assert (abs (Params.Grand_Mean - 0.25) < 1.0e-9,
              "Grand_Mean should be 0.25; got " & Long_Float'Image (Params.Grand_Mean));
   end Test_Fraction_Thinking_Tokens_Grand_Mean;

   --  Two sessions with known tool-call and output token totals;
   --  Grand_Mean = total_tool_call_input / total_output.
   procedure Test_Fraction_Tool_Call_Tokens_Grand_Mean (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Session 1: 60 tool-call input tokens, 300 output tokens → p1 = 0.2
      --  Session 2: 40 tool-call input tokens, 200 output tokens → p2 = 0.2
      --  Grand_Mean = 100 / 500 = 0.2
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;

      function MK (Id : String; TC_Input, Output : Natural)
                   return Session_Metrics_Record is
         M : Session_Metrics_Record;
      begin
         M.Session_Id                  := To_Unbounded_String (Id);
         M.N_Turns                     := 1;
         M.Total_Tool_Call_Input_Tokens := TC_Input;
         M.Total_Output_Tokens          := Output;
         return M;
      end MK;
   begin
      Metrics.Append (MK ("tc1", 60, 300));
      Metrics.Append (MK ("tc2", 40, 200));

      Estimate_Parameters
        (Metrics, Setup, Fraction_Tool_Call_Tokens_I, Parameters => Params);

      Assert (abs (Params.Grand_Mean - 0.2) < 1.0e-9,
              "Grand_Mean should be 0.2; got " & Long_Float'Image (Params.Grand_Mean));
   end Test_Fraction_Tool_Call_Tokens_Grand_Mean;

   --  Sessions with zero output tokens are excluded from both new p-charts.
   procedure Test_Fraction_Token_Charts_Zero_Output (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Session 1: 0 output tokens → excluded
      --  Session 2: 100 thinking tokens, 500 output tokens → Grand_Mean = 0.2
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params_Think, Params_TC : Setup_Parameters;

      function MK (Id : String; Think, TC_In, Output : Natural)
                   return Session_Metrics_Record is
         M : Session_Metrics_Record;
      begin
         M.Session_Id                  := To_Unbounded_String (Id);
         M.N_Turns                     := 1;
         M.Total_Thinking_Tokens       := Think;
         M.Total_Tool_Call_Input_Tokens := TC_In;
         M.Total_Output_Tokens          := Output;
         return M;
      end MK;
   begin
      Metrics.Append (MK ("z1",   0,   0,   0));  --  excluded
      Metrics.Append (MK ("z2", 100,  50, 500));

      Estimate_Parameters
        (Metrics, Setup, Fraction_Thinking_Tokens_I, Parameters => Params_Think);
      Estimate_Parameters
        (Metrics, Setup, Fraction_Tool_Call_Tokens_I, Parameters => Params_TC);

      --  Grand_Mean computed from session z2 only: 100/500 = 0.2 for thinking.
      Assert (abs (Params_Think.Grand_Mean - 0.2) < 1.0e-9,
              "Thinking Grand_Mean should exclude zero-output session; got "
              & Long_Float'Image (Params_Think.Grand_Mean));

      --  Tool-call: 50/500 = 0.1.
      Assert (abs (Params_TC.Grand_Mean - 0.1) < 1.0e-9,
              "Tool-call Grand_Mean should exclude zero-output session; got "
              & Long_Float'Image (Params_TC.Grand_Mean));
   end Test_Fraction_Token_Charts_Zero_Output;

   --  Two sessions with known thinking and tool-call-input token totals;
   --  Grand_Mean should be the mean of (thinking / tool_call_input) ratios.
   procedure Test_Fraction_Thinking_Per_Tool_Call_Grand_Mean
     (T : in out Test)
   is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Session 1: 300 thinking tokens, 1500 tool-call tokens → ratio = 0.2
      --  Session 2: 100 thinking tokens,  500 tool-call tokens → ratio = 0.2
      --  Grand_Mean = mean(0.2, 0.2) = 0.2
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;

      function MK (Id : String; Think, TC_Input : Natural)
                   return Session_Metrics_Record is
         M : Session_Metrics_Record;
      begin
         M.Session_Id                  := To_Unbounded_String (Id);
         M.N_Turns                     := 1;
         M.Total_Thinking_Tokens       := Think;
         M.Total_Tool_Call_Input_Tokens := TC_Input;
         return M;
      end MK;
   begin
      Metrics.Append (MK ("pt1", 300, 1500));
      Metrics.Append (MK ("pt2", 100,  500));

      Estimate_Parameters
        (Metrics, Setup, Fraction_Thinking_Per_Tool_Call_I,
         Parameters => Params);

      Assert (abs (Params.Grand_Mean - 0.2) < 1.0e-9,
              "Grand_Mean should be 0.2; got "
              & Long_Float'Image (Params.Grand_Mean));
   end Test_Fraction_Thinking_Per_Tool_Call_Grand_Mean;

   --  Two sessions with known uncached and total input token totals;
   --  Grand_Mean should be the mean of (uncached / total_input) ratios.
   procedure Test_Fraction_Uncached_Input_Grand_Mean (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      --  Session 1: 300 uncached / 1000 total → ratio = 0.3
      --  Session 2: 200 uncached /  500 total → ratio = 0.4
      --  Grand_Mean = mean(0.3, 0.4) = 0.35
      Metrics : Metrics_Vectors.Vector;
      Setup   : UUID_Set;
      Params  : Setup_Parameters;

      function MK (Id : String; Uncached, Total_In : Natural)
                   return Session_Metrics_Record is
         M : Session_Metrics_Record;
      begin
         M.Session_Id                    := To_Unbounded_String (Id);
         M.N_Turns                       := 1;
         M.Total_Uncached_Input_Tokens   := Uncached;
         M.Total_Input_Tokens            := Total_In;
         return M;
      end MK;
   begin
      Metrics.Append (MK ("ui1", 300, 1000));
      Metrics.Append (MK ("ui2", 200,  500));

      Estimate_Parameters
        (Metrics, Setup, Fraction_Uncached_Input_I, Parameters => Params);

      Assert (abs (Params.Grand_Mean - 0.35) < 1.0e-9,
              "Grand_Mean should be 0.35; got "
              & Long_Float'Image (Params.Grand_Mean));
   end Test_Fraction_Uncached_Input_Grand_Mean;

   --  Sessions with zero denominators are excluded from the new charts.
   --  Sessions with zero denominators are excluded from the new rate charts.
   --  Tests PTTC (zero tool-call tokens excluded) and UI (zero total-input excluded).
   procedure Test_Fraction_New_Charts_Zero_Denominator (T : in out Test) is
      pragma Unreferenced (T);
      use AUnit.Assertions;
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics;
      Metrics     : Metrics_Vectors.Vector;
      Setup       : UUID_Set;
      Params_PTTC : Setup_Parameters;  --  Fraction_Thinking_Per_Tool_Call_I
      Params_UI   : Setup_Parameters;  --  Fraction_Uncached_Input_I

      function MK
        (Id        : String;
         Think     : Natural;
         TC_Input  : Natural;
         Uncached  : Natural;
         Total_In  : Natural) return Session_Metrics_Record
      is
         M : Session_Metrics_Record;
      begin
         M.Session_Id                   := To_Unbounded_String (Id);
         M.N_Turns                      := 1;
         M.Total_Thinking_Tokens        := Think;
         M.Total_Tool_Call_Input_Tokens := TC_Input;
         M.Total_Uncached_Input_Tokens  := Uncached;
         M.Total_Input_Tokens           := Total_In;
         return M;
      end MK;
   begin
      --  PTTC chart sessions (Total_In=0 → also excluded from UI):
      --    pttc_zero: TC=0 → excluded from PTTC
      --    pttc_a:    Think=100, TC=200 → ratio 0.5
      --    pttc_b:    Think=20,  TC=100 → ratio 0.2
      --    Expected PTTC Grand_Mean = (0.5 + 0.2) / 2 = 0.35
      Metrics.Append (MK ("pttc_zero",  50,   0,   0,   0));
      Metrics.Append (MK ("pttc_a",    100, 200,   0,   0));
      Metrics.Append (MK ("pttc_b",     20, 100,   0,   0));

      --  UI chart sessions (TC_Input=0 → also excluded from PTTC):
      --    ui_zero: Total=0 → excluded from UI
      --    ui_a:    Uncached=300, Total=1000 → ratio 0.3
      --    ui_b:    Uncached=100, Total=500  → ratio 0.2
      --    Expected UI Grand_Mean = (0.3 + 0.2) / 2 = 0.25
      Metrics.Append (MK ("ui_zero",    0,   0,   0,   0));
      Metrics.Append (MK ("ui_a",       0,   0, 300, 1000));
      Metrics.Append (MK ("ui_b",       0,   0, 100,  500));

      Estimate_Parameters
        (Metrics, Setup, Fraction_Thinking_Per_Tool_Call_I,
         Parameters => Params_PTTC);
      Estimate_Parameters
        (Metrics, Setup, Fraction_Uncached_Input_I,
         Parameters => Params_UI);

      Assert (abs (Params_PTTC.Grand_Mean - 0.35) < 1.0e-9,
              "PTTC Grand_Mean should be 0.35 (zero-TC session excluded); got "
              & Long_Float'Image (Params_PTTC.Grand_Mean));

      Assert (abs (Params_UI.Grand_Mean - 0.25) < 1.0e-9,
              "UI Grand_Mean should be 0.25 (zero-total session excluded); got "
              & Long_Float'Image (Params_UI.Grand_Mean));
   end Test_Fraction_New_Charts_Zero_Denominator;


   --  ── EWMA + Box-Cox (Option B) tests ──────────────────────────────────

   --  When Box-Cox (ln) is applied before EWMA limit computation, back-
   --  transforming via exp() produces asymmetric limits in original space:
   --  UCL − CL > CL − LCL.  This verifies the Option B workflow without
   --  the GTK app layer.
   procedure Test_EWMA_Box_Cox_Asymmetric_Limits (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      use Coyote_SQC.Statistics.EWMA_Chart;
      use Ada.Numerics.Long_Elementary_Functions;

      --  Geometric series: each value is 4× the previous.
      --  ln(x_i) = [0.693, 2.079, 3.466, 4.852]
      X1    : constant Long_Float := 2.0;
      X2    : constant Long_Float := 8.0;
      X3    : constant Long_Float := 32.0;
      X4    : constant Long_Float := 128.0;
      Z1    : constant Long_Float := Box_Cox (X1, 0.0);
      Z2    : constant Long_Float := Box_Cox (X2, 0.0);
      Z3    : constant Long_Float := Box_Cox (X3, 0.0);
      Z4    : constant Long_Float := Box_Cox (X4, 0.0);

      Grand_Mean_Z : constant Long_Float := (Z1 + Z2 + Z3 + Z4) / 4.0;
      Mean_MR_Z    : constant Long_Float :=
        (abs (Z2 - Z1) + abs (Z3 - Z2) + abs (Z4 - Z3)) / 3.0;
      Sigma_Z      : constant Long_Float := Mean_MR_Z / 1.128;

      Lim_Z : constant Limits_Record :=
        Compute_EWMA_Limits (Grand_Mean_Z, Sigma_Z, 0.2, 3.0, 1);

      UCL_Orig : constant Long_Float := Box_Cox_Inverse (Lim_Z.UCL, 0.0);
      CL_Orig  : constant Long_Float := Box_Cox_Inverse (Lim_Z.CL,  0.0);
      LCL_Orig : constant Long_Float := Box_Cox_Inverse (Lim_Z.LCL, 0.0);
   begin
      Assert (Lim_Z.Has_UCL, "EWMA ln-space limits must be defined");
      Assert (UCL_Orig > CL_Orig,
              "Back-transformed UCL must be > CL");
      Assert (LCL_Orig < CL_Orig,
              "Back-transformed LCL must be < CL");
      Assert (LCL_Orig > 0.0,
              "Back-transformed LCL must be positive (ln preserves positivity)");
      --  Key assertion: limits are asymmetric in original space.
      --  For [2,8,32,128]: UCL≈33.4, CL≈16.0, LCL≈7.6.
      --  (UCL−CL)≈17.4 >> (CL−LCL)≈8.4.
      Assert ((UCL_Orig - CL_Orig) > (CL_Orig - LCL_Orig) + 3.0,
              "Back-transformed limits must be asymmetric around CL; "
              & "UCL-CL=" & Long_Float'Image (UCL_Orig - CL_Orig)
              & " CL-LCL=" & Long_Float'Image (CL_Orig - LCL_Orig));
   end Test_EWMA_Box_Cox_Asymmetric_Limits;

   --  ── Robust Estimation + EWMA interaction ─────────────────────────────

   --  With a skewed setup interval containing an outlier, the robust Grand_Mean
   --  (median) gives a different EWMA Z_0 than the classical mean, producing
   --  a more resistant first EWMA step when a new observation arrives.
   procedure Test_Robust_EWMA_Outlier_Grand_Mean (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Data_Model;
      use Coyote_SQC.Charts;
      use Coyote_SQC.Statistics.EWMA_Chart;

      --  Setup interval: four sessions at 10 input tokens, one outlier at 100.
      --  Classical mean = 28; robust median = 10.
      function MK (Id : String; Tok : Natural)
                   return Session_Metrics_Record is
         M : Session_Metrics_Record;
      begin
         M.Session_Id           := To_Unbounded_String (Id);
         M.N_Turns              := 1;
         M.Total_Input_Tokens   := Tok;
         return M;
      end MK;

      Metrics  : Metrics_Vectors.Vector;
      Setup    : UUID_Set;
      Classical_Params : Setup_Parameters;
      Robust_Params    : Setup_Parameters;
      Tol      : constant Long_Float := 1.0e-6;

      --  A new observation at 10 tokens.
      X_New    : constant Long_Float := 10.0;
      Weight   : constant Long_Float := 0.2;

      Classical_Z1 : Long_Float;
      Robust_Z1    : Long_Float;
   begin
      Metrics.Append (MK ("r1", 10));
      Metrics.Append (MK ("r2", 10));
      Metrics.Append (MK ("r3", 10));
      Metrics.Append (MK ("r4", 10));
      Metrics.Append (MK ("r5", 100));

      Coyote_SQC.Statistics.Estimate_Parameters
        (Metrics, Setup, Session_Input_Tokens_I,
         Method     => Coyote_SQC.Data_Model.Classical,
         Parameters => Classical_Params);

      Coyote_SQC.Statistics.Estimate_Parameters
        (Metrics, Setup, Session_Input_Tokens_I,
         Method     => Coyote_SQC.Data_Model.Robust_Median,
         Parameters => Robust_Params);

      --  Classical Grand_Mean = (4*10+100)/5 = 28.0.
      Assert (abs (Classical_Params.Grand_Mean - 28.0) <= Tol,
              "Classical Grand_Mean should be 28.0; got "
              & Long_Float'Image (Classical_Params.Grand_Mean));
      --  Robust Grand_Mean = median = 10.0.
      Assert (abs (Robust_Params.Grand_Mean - 10.0) <= Tol,
              "Robust Grand_Mean (median) should be 10.0; got "
              & Long_Float'Image (Robust_Params.Grand_Mean));

      --  EWMA first step with Z_0 = Grand_Mean, new observation = 10.
      Classical_Z1 := Compute_Z (X_New, Classical_Params.Grand_Mean, Weight);
      Robust_Z1    := Compute_Z (X_New, Robust_Params.Grand_Mean, Weight);

      --  Classical: Z_1 = 0.2*10 + 0.8*28 = 24.4.
      Assert (abs (Classical_Z1 - 24.4) <= Tol,
              "Classical EWMA Z1 should be 24.4; got "
              & Long_Float'Image (Classical_Z1));
      --  Robust: Z_1 = 0.2*10 + 0.8*10 = 10.0.
      Assert (abs (Robust_Z1 - 10.0) <= Tol,
              "Robust EWMA Z1 should be 10.0; got "
              & Long_Float'Image (Robust_Z1));
      --  Robust Z_1 is much smaller (closer to the true process level).
      Assert (Robust_Z1 < Classical_Z1,
              "Robust EWMA Z1 must be less than Classical EWMA Z1 when "
              & "setup interval contains an outlier");
   end Test_Robust_EWMA_Outlier_Grand_Mean;


   --  ── Additional variance-stabilization transform tests ─────────────────

   --  Sqrt_VS: f(x)=sqrt(x), f^-1(z)=z^2; zero is valid.
   procedure Test_Sqrt_VS_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Tol : constant Long_Float := 1.0e-10;
   begin
      --  x=4: forward=2, inverse=4.
      Assert (abs (Sqrt_VS (4.0) - 2.0) <= Tol,
              "Sqrt_VS (4.0) should be 2.0");
      Assert (abs (Sqrt_VS_Inverse (2.0) - 4.0) <= Tol,
              "Sqrt_VS_Inverse (2.0) should be 4.0");
      --  x=0: forward=0, inverse=0.
      Assert (abs (Sqrt_VS (0.0)) <= Tol,
              "Sqrt_VS (0.0) should be 0.0");
      Assert (abs (Sqrt_VS_Inverse (0.0)) <= Tol,
              "Sqrt_VS_Inverse (0.0) should be 0.0");
      --  Round-trip for x=9.
      Assert (abs (Sqrt_VS_Inverse (Sqrt_VS (9.0)) - 9.0) <= Tol,
              "Sqrt_VS round-trip should recover 9.0");
   end Test_Sqrt_VS_Round_Trip;

   --  Anscombe: f(x)=2*sqrt(x+0.375), f^-1(z)=(z/2)^2-0.375.
   procedure Test_Anscombe_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Tol : constant Long_Float := 1.0e-10;
   begin
      --  x=0: f(0)=2*sqrt(0.375).
      declare
         use Ada.Numerics.Long_Elementary_Functions;
         Expected : constant Long_Float := 2.0 * Sqrt (0.375);
      begin
         Assert (abs (Anscombe (0.0) - Expected) <= Tol,
                 "Anscombe (0.0) should be 2*sqrt(3/8)");
      end;
      --  Round-trip for x=10.
      Assert (abs (Anscombe_Inverse (Anscombe (10.0)) - 10.0) <= 1.0e-9,
              "Anscombe round-trip should recover 10.0");
      --  Inverse may give slightly negative result for z near 0 (expected).
      declare
         Z_0 : constant Long_Float := Anscombe (0.0);
         Inv : constant Long_Float := Anscombe_Inverse (Z_0);
      begin
         Assert (abs (Inv - 0.0) <= 1.0e-9,
                 "Anscombe round-trip for x=0 should recover ~0; got "
                 & Long_Float'Image (Inv));
      end;
   end Test_Anscombe_Round_Trip;

   --  Arcsinh_VS: accepts zero and negative values.
   procedure Test_Arcsinh_VS_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Tol : constant Long_Float := 1.0e-10;
   begin
      --  x=0: f(0)=0, f^-1(0)=0.
      Assert (abs (Arcsinh_VS (0.0)) <= Tol,
              "Arcsinh_VS (0.0) should be 0.0");
      Assert (abs (Arcsinh_VS_Inverse (0.0)) <= Tol,
              "Arcsinh_VS_Inverse (0.0) should be 0.0");
      --  Round-trip for x=5.
      Assert (abs (Arcsinh_VS_Inverse (Arcsinh_VS (5.0)) - 5.0) <= Tol,
              "Arcsinh_VS round-trip should recover 5.0");
      --  Negative input is valid: round-trip for x=-3.
      Assert (abs (Arcsinh_VS_Inverse (Arcsinh_VS (-3.0)) - (-3.0)) <= Tol,
              "Arcsinh_VS round-trip for x=-3 should recover -3.0");
      --  Antisymmetry: f(-x) = -f(x).
      Assert (abs (Arcsinh_VS (-2.0) + Arcsinh_VS (2.0)) <= Tol,
              "Arcsinh_VS should be antisymmetric: f(-x)=-f(x)");
   end Test_Arcsinh_VS_Round_Trip;

   --  Freeman-Tukey: f(x)=sqrt(x)+sqrt(x+1); approximate inverse.
   procedure Test_Freeman_Tukey_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Tol : constant Long_Float := 1.0e-6;   --  approx inverse
   begin
      --  x=0: f(0)=0+1=1, f^-1(1)=0.
      declare
         use Ada.Numerics.Long_Elementary_Functions;
         FT_0 : constant Long_Float := Freeman_Tukey (0.0);
      begin
         Assert (abs (FT_0 - 1.0) <= 1.0e-10,
                 "Freeman_Tukey (0.0) should be 1.0; got "
                 & Long_Float'Image (FT_0));
         Assert (abs (Freeman_Tukey_Inverse (FT_0)) <= Tol,
                 "Freeman_Tukey round-trip for x=0 should recover ~0; got "
                 & Long_Float'Image (Freeman_Tukey_Inverse (FT_0)));
      end;
      --  Round-trip for x=4 (large x: approximate inverse is accurate).
      Assert (abs (Freeman_Tukey_Inverse (Freeman_Tukey (4.0)) - 4.0) <= Tol,
              "Freeman_Tukey round-trip should recover 4.0");
      --  Round-trip for x=100.
      Assert (abs (Freeman_Tukey_Inverse (Freeman_Tukey (100.0)) - 100.0) <= Tol,
              "Freeman_Tukey round-trip should recover 100.0");
   end Test_Freeman_Tukey_Round_Trip;

   --  Apply_Transform / Invert_Transform dispatchers.
   procedure Test_Apply_Invert_Dispatch (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      use Coyote_SQC.Data_Model;
      Tol : constant Long_Float := 1.0e-9;
      X   : constant Long_Float := 9.0;
   begin
      --  None: identity.
      Assert (abs (Apply_Transform (X, None) - X) <= Tol,
              "Apply_Transform Kind=None should return X unchanged");
      Assert (abs (Invert_Transform (X, None) - X) <= Tol,
              "Invert_Transform Kind=None should return Z unchanged");
      --  Box_Cox (ln): Apply_Transform = ln(9), Invert_Transform = exp(ln(9)).
      declare
         Z_BC : constant Long_Float :=
           Apply_Transform (X, Box_Cox, 0.0);
      begin
         Assert (abs (Invert_Transform (Z_BC, Box_Cox, 0.0) - X) <= Tol,
                 "Box_Cox round-trip via dispatchers should recover X");
      end;
      --  Sqrt_VS.
      declare
         Z_Sqrt : constant Long_Float := Apply_Transform (X, Sqrt_VS);
      begin
         Assert (abs (Invert_Transform (Z_Sqrt, Sqrt_VS) - X) <= Tol,
                 "Sqrt_VS round-trip via dispatchers should recover X");
      end;
      --  Anscombe.
      declare
         Z_A : constant Long_Float := Apply_Transform (X, Anscombe);
      begin
         Assert (abs (Invert_Transform (Z_A, Anscombe) - X) <= 1.0e-9,
                 "Anscombe round-trip via dispatchers should recover X");
      end;
      --  Arcsinh_VS.
      declare
         Z_AS : constant Long_Float := Apply_Transform (X, Arcsinh_VS);
      begin
         Assert (abs (Invert_Transform (Z_AS, Arcsinh_VS) - X) <= Tol,
                 "Arcsinh_VS round-trip via dispatchers should recover X");
      end;
      --  Freeman_Tukey.
      declare
         Z_FT : constant Long_Float := Apply_Transform (X, Freeman_Tukey);
      begin
         Assert (abs (Invert_Transform (Z_FT, Freeman_Tukey) - X) <= 1.0e-6,
                 "Freeman_Tukey round-trip via dispatchers should recover X");
      end;
   end Test_Apply_Invert_Dispatch;

   --  ── Dip test for unimodality ─────────────────────────────────────────

   procedure Test_Dip_NA_Too_Small (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.Tests;
      Small : constant Long_Float_Array (1 .. 3) := (0.1, 0.5, 0.9);
   begin
      Assert (Dip_Test_P_Value (Small) = -1.0,
              "Dip_Test_P_Value should return -1.0 for N < 4");
   end Test_Dip_NA_Too_Small;

   procedure Test_Dip_Bimodal_Significant (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.Tests;
      --  Ten values at 0.0 and ten at 1.0 — extreme bimodal; dip >> uniform.
      Bimodal : Long_Float_Array (1 .. 20) :=
        (0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
         1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0);
      P : Long_Float;
   begin
      P := Dip_Test_P_Value (Bimodal, K => 2_000);
      Assert (P >= 0.0 and then P <= 1.0,
              "Dip p-value must be in [0, 1]");
      Assert (P < 0.05,
              "Strongly bimodal data should yield p < 0.05");
   end Test_Dip_Bimodal_Significant;

   procedure Test_Dip_Unimodal_Not_Sig (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.Tests;
      --  Twenty values tightly clustered: clearly unimodal.
      Unimodal : Long_Float_Array (1 .. 20) :=
        (0.48, 0.482, 0.484, 0.486, 0.488,
         0.490, 0.492, 0.494, 0.496, 0.498,
         0.500, 0.502, 0.504, 0.506, 0.508,
         0.510, 0.512, 0.514, 0.516, 0.518);
      P : Long_Float;
   begin
      P := Dip_Test_P_Value (Unimodal, K => 2_000);
      Assert (P >= 0.0 and then P <= 1.0,
              "Dip p-value must be in [0, 1]");
      Assert (P > 0.10,
              "Tightly unimodal data should not be flagged as multimodal");
   end Test_Dip_Unimodal_Not_Sig;

end Coyote_SQC_Statistics_Tests;
