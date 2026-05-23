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
      Assert (not L.Undefined, "n=5 Xbar limits must be defined");
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
      Assert (L.Undefined, "n=1 Xbar limits must be Undefined");
      Assert (L.CL = 50.0, "n=1 CL must still equal Grand_Mean");
   end Test_Xbar_N1_Undefined;

   --  §7.5: Pooled_S=0 → Xbar limits must be Undefined (no OOC detection).
   procedure Test_Xbar_Pooled_S_Zero (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        Xbar.Compute_Limits
          (Grand_Mean => 50.0, Pooled_S => 0.0, N => 5);
   begin
      Assert (L.Undefined,
              "Pooled_S=0 Xbar limits must be Undefined");
      Assert (L.CL = 50.0,
              "CL must still equal Grand_Mean when Pooled_S=0");
      Assert (L.UCL >= Long_Float'Last / 2.0,
              "UCL must be sentinel (infinity) when Pooled_S=0");
   end Test_Xbar_Pooled_S_Zero;

   --  ── s chart tests ────────────────────────────────────────────────────

   procedure Test_S_Chart_Limits_Basic (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        S_Chart.Compute_Limits (Pooled_S => 10.0, N => 4);
   begin
      Assert (not L.Undefined, "n=4 s chart limits must be defined");
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
      Assert (L.Undefined, "n=1 s chart must be Undefined");
   end Test_S_Chart_N1_Undefined;

   --  §7.5: Pooled_S=0 → S_Chart limits must be Undefined.
   procedure Test_S_Chart_Pooled_S_Zero (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        S_Chart.Compute_Limits (Pooled_S => 0.0, N => 5);
   begin
      Assert (L.Undefined,
              "Pooled_S=0 S_Chart limits must be Undefined");
      Assert (L.CL = 0.0,
              "CL must be 0 when Pooled_S=0");
      Assert (L.UCL >= Long_Float'Last / 2.0,
              "UCL must be sentinel when Pooled_S=0");
   end Test_S_Chart_Pooled_S_Zero;

   procedure Test_S_Chart_LCL_Clamped (T : in out Test) is
      pragma Unreferenced (T);
      --  For n=2 the LCL formula yields a negative value; it must be
      --  clamped to 0.
      L : constant Limits_Record :=
        S_Chart.Compute_Limits (Pooled_S => 10.0, N => 2);
   begin
      Assert (not L.Undefined, "n=2 s chart must be defined");
      Assert (L.LCL = 0.0, "LCL for n=2 must be clamped to 0.0");
   end Test_S_Chart_LCL_Clamped;

   --  ── p chart tests ────────────────────────────────────────────────────

   procedure Test_P_Chart_Limits_Basic (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        P_Chart.Compute_Limits (Grand_P => 0.3, N => 20);
   begin
      Assert (not L.Undefined, "p chart n=20 must be defined");
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
   end Test_P_Chart_Limits_Basic;

   procedure Test_P_Chart_N0_Undefined (T : in out Test) is
      pragma Unreferenced (T);
      L : constant Limits_Record :=
        P_Chart.Compute_Limits (Grand_P => 0.2, N => 0);
   begin
      Assert (L.Undefined, "p chart n=0 must be Undefined");
   end Test_P_Chart_N0_Undefined;

   procedure Test_P_Chart_LCL_Clamped (T : in out Test) is
      pragma Unreferenced (T);
      --  Grand_P = 0.5, N = 1: 3*sqrt(0.5*0.5/1) = 1.5 → LCL = 0.5 - 1.5 < 0
      L : constant Limits_Record :=
        P_Chart.Compute_Limits (Grand_P => 0.5, N => 1);
   begin
      Assert (not L.Undefined, "p chart n=1 is defined");
      Assert (L.LCL = 0.0, "LCL must be clamped to 0");
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

end Coyote_SQC_Statistics_Tests;
