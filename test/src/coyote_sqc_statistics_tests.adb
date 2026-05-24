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
      Estimate_Parameters (Metrics, Setup, Turn_Tokens_Xbar, Params);

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

      Estimate_Parameters (Metrics, Setup, Turn_Tokens_Xbar, Params);

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

      Estimate_Parameters (Metrics, Setup, Tool_Call_Failure_Rate, Params);

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

      Estimate_Parameters (Metrics, Setup, Tool_Call_Failure_Rate, Params);

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

      Estimate_Parameters (Metrics, Setup, Turn_Tokens_Xbar, Params);

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

      Estimate_Parameters (Metrics, Setup, Turn_Tokens_Xbar, Params);

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

      Estimate_Parameters (Metrics, Setup, Thinking_Tokens_Xbar, Params);

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

      Estimate_Parameters (Metrics, Setup, Tool_Call_Tokens_Xbar, Params);

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

      Estimate_Parameters (Metrics, Setup, Tool_Call_Tokens_Xbar, Params);

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
        Compute_I_Limits (Grand_Mean, Mean_MR);
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
        Compute_I_Limits (Grand_Mean, Mean_MR);
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
      Lim : constant Limits_Record := Compute_I_Limits (1.0, 10.0);
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

      Estimate_Parameters (Metrics, Setup, Session_Input_Tokens_I, Params);

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

      Estimate_Parameters (Metrics, Setup, Session_Input_Tokens_I, Params);

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
   procedure Test_Estimate_Lambda_Few_Obs (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_SQC.Statistics.I_Chart;
      Tol : constant Long_Float := 1.0e-12;
      L1  : constant Long_Float :=
        Estimate_Lambda (Long_Float_Array'(1 => 1000.0));
      L2  : constant Long_Float :=
        Estimate_Lambda (Long_Float_Array'(1 => 100.0, 2 => 200.0));
   begin
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
        Compute_I_Limits (Mean_Z, Mean_MR_Z);
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

end Coyote_SQC_Statistics_Tests;
