--  Coyote_SQC.Statistics.I_Chart body.
--
--  Project: coyote

with Ada.Numerics.Long_Elementary_Functions;
with Coyote_SQC.Data_Model;
with Ada.Containers.Vectors;

package body Coyote_SQC.Statistics.I_Chart is
   package LF_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Long_Float);

   use Ada.Numerics.Long_Elementary_Functions;

   --  d2 for moving range of span 2.
   D2 : constant Long_Float := 1.128;

   --  D4 for MR chart UCL factor, span 2.
   D4 : constant Long_Float := 3.267;

   --  ── Standard I/MR limit computation ───────────────────────────────────


   function Compute_I_Limits
     (Grand_Mean : Long_Float;
      Sigma      : Long_Float) return Limits_Record
   is
   begin
      if Sigma = 0.0 then
         --  Cannot derive spread estimate; no limits drawn.
         return
           (UCL     => 0.0,
            CL      => Grand_Mean,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      declare
         Spread  : constant Long_Float := 3.0 * Sigma;
         Raw_LCL : constant Long_Float := Grand_Mean - Spread;
         Eff_LCL : constant Long_Float :=
           (if Raw_LCL < 0.0 then 0.0 else Raw_LCL);
      begin
         return
           (UCL     => Grand_Mean + Spread,
            CL      => Grand_Mean,
            LCL     => Eff_LCL,
            Has_UCL => True,
            Has_LCL => Eff_LCL > 0.0);
      end;
   end Compute_I_Limits;
   function Compute_MR_Limits (Mean_MR : Long_Float) return Limits_Record is
   begin
      if Mean_MR = 0.0 then
         return
           (UCL     => 0.0,
            CL      => 0.0,
            LCL     => 0.0,
            Has_UCL => False,
            Has_LCL => False);
      end if;

      return
        (UCL     => D4 * Mean_MR,
         CL      => Mean_MR,
         LCL     => 0.0,
         Has_UCL => True,
         Has_LCL => False);
   end Compute_MR_Limits;

   --  ── Box-Cox transformation ─────────────────────────────────────────────

   function Box_Cox (X : Long_Float; Lambda : Long_Float) return Long_Float is
   begin
      if X <= 0.0 then
         raise Constraint_Error with
           "Box_Cox: X must be strictly positive; got"
           & Long_Float'Image (X);
      end if;
      if abs Lambda < 1.0e-10 then
         return Log (X);
      else
         return (X ** Lambda - 1.0) / Lambda;
      end if;
   end Box_Cox;

   function Box_Cox_Inverse
     (Z : Long_Float; Lambda : Long_Float) return Long_Float
   is
      Base : Long_Float;
   begin
      if abs Lambda < 1.0e-10 then
         return Exp (Z);
      else
         Base := Z * Lambda + 1.0;
         if Base <= 0.0 then
            raise Constraint_Error with
              "Box_Cox_Inverse: non-positive base"
              & " (lambda=" & Long_Float'Image (Lambda)
              & ", z=" & Long_Float'Image (Z) & ")";
         end if;
         return Base ** (1.0 / Lambda);
      end if;
   end Box_Cox_Inverse;

   --  ── Qn scale estimator ─────────────────────────────────────────────────

   --  Internal worker: compute the Qn scale estimate on any Long_Float array.
   --  No positivity check; used both by the public Qn_Scale and internally
   --  by Robust_Log_Likelihood (which operates on transformed z-values).
   function Qn_Scale_Core (Vals : Long_Float_Array) return Long_Float is
      N : constant Positive := Vals'Length;
   begin
      if N < 2 then
         raise Constraint_Error with
           "Qn_Scale: need at least 2 observations";
      end if;

      declare
         package LF_Sorting is new LF_Vectors.Generic_Sorting;

         N_Pairs : constant Positive := N * (N - 1) / 2;
         Half_N  : constant Positive := N / 2 + 1;
         H       : constant Positive := Half_N * (Half_N - 1) / 2;
         Dists   : LF_Vectors.Vector;
         Cn      : Long_Float;
      begin
         Dists.Reserve_Capacity (Ada.Containers.Count_Type (N_Pairs));

         --  Collect all pairwise absolute differences.
         for I in Vals'First .. Vals'Last - 1 loop
            for J in I + 1 .. Vals'Last loop
               Dists.Append (abs (Vals (I) - Vals (J)));
            end loop;
         end loop;

         LF_Sorting.Sort (Dists);

         --  Finite-sample correction factor c_n.
         --  Table 1 values for n = 2..9 from Rousseeuw & Croux (1993).
         --  Even/odd asymptotic formulae for n >= 10 from the same paper.
         if N <= 9 then
            declare
               type Cn_Table is array (2 .. 9) of Long_Float;
               Cn_Values : constant Cn_Table :=
                 (2 => 0.399_0,
                  3 => 0.994_0,
                  4 => 0.512_0,
                  5 => 0.844_0,
                  6 => 0.611_0,
                  7 => 0.857_0,
                  8 => 0.669_0,
                  9 => 0.872_0);
            begin
               Cn := Cn_Values (N);
            end;
         else
            --  For n >= 10: even n -> n/(n-0.9); odd n -> n/(n+1.4).
            if N mod 2 = 0 then
               Cn := Long_Float (N) / (Long_Float (N) - 0.9);
            else
               Cn := Long_Float (N) / (Long_Float (N) + 1.4);
            end if;
         end if;

         return Cn * 2.2219 * Dists (H);
      end;
   end Qn_Scale_Core;

   function Qn_Scale (Values : Long_Float_Array) return Long_Float is
   begin
      for V of Values loop
         if V <= 0.0 then
            raise Constraint_Error with
              "Qn_Scale: all values must be strictly positive; got"
              & Long_Float'Image (V);
         end if;
      end loop;
      return Qn_Scale_Core (Values);
   end Qn_Scale;

   function Qn_Scale_Any (Values : Long_Float_Array) return Long_Float is
   begin
      return Qn_Scale_Core (Values);
   end Qn_Scale_Any;

   function Median_Of (Values : Long_Float_Array) return Long_Float is
      N : constant Natural := Values'Length;
   begin
      if N = 0 then
         return 0.0;
      end if;
      if N = 1 then
         return Values (Values'First);
      end if;
      declare
         package LF_Sorting is new LF_Vectors.Generic_Sorting;
         Copy : LF_Vectors.Vector;
         Mid  : constant Positive := (N - 1) / 2 + 1;  --  1-based middle index
      begin
         for V of Values loop
            Copy.Append (V);
         end loop;
         LF_Sorting.Sort (Copy);
         if N mod 2 = 1 then
            return Copy (Mid);
         else
            return (Copy (Mid) + Copy (Mid + 1)) / 2.0;
         end if;
      end;
   end Median_Of;


   --  ── Lambda estimation ─────────────────────────────────────────────────
   --  Evaluate the Box-Cox MLE profile log-likelihood for a given lambda.
   --  L(lambda) = -(n/2) * ln(var_z) + (lambda-1) * sum ln(x_i)
   --  Returns Long_Float'First when variance is zero or computation overflows.
   function Log_Likelihood
     (Values      : Long_Float_Array;
      Lambda      : Long_Float;
      Sum_Log_X   : Long_Float) return Long_Float
   is
      N      : constant Long_Float := Long_Float (Values'Length);
      Sum_Z  : Long_Float := 0.0;
      Sum_Z2 : Long_Float := 0.0;
      Var_Z  : Long_Float;
      Mean_Z : Long_Float;
   begin
      for X of Values loop
         declare
            Z : constant Long_Float := Box_Cox (X, Lambda);
         begin
            Sum_Z  := Sum_Z  + Z;
            Sum_Z2 := Sum_Z2 + Z * Z;
         end;
      end loop;
      Mean_Z := Sum_Z / N;
      Var_Z  := Sum_Z2 / N - Mean_Z * Mean_Z;
      if Var_Z <= 0.0 then
         return Long_Float'First;
      end if;
      return -(N / 2.0) * Log (Var_Z) + (Lambda - 1.0) * Sum_Log_X;
   exception
      when Constraint_Error | Program_Error =>
         return Long_Float'First;
   end Log_Likelihood;

   --  Evaluate the robust profile log-likelihood for a given lambda.
   --  Substitutes the Qn scale estimator for the sample standard deviation.
   --  L_robust(lambda) = -N * ln(Qn(z)) + (lambda-1) * sum ln(x_i)
   --  Returns Long_Float'First when Qn_Scale is zero or overflows.
   function Robust_Log_Likelihood
     (Values      : Long_Float_Array;
      Lambda      : Long_Float;
      Sum_Log_X   : Long_Float) return Long_Float
   is
      N      : constant Long_Float := Long_Float (Values'Length);
      Z_Vals : Long_Float_Array (1 .. Values'Length);
      S      : Long_Float;
   begin
      for I in Values'Range loop
         Z_Vals (I - Values'First + 1) := Box_Cox (Values (I), Lambda);
      end loop;
      S := Qn_Scale_Core (Z_Vals);
      if S <= 0.0 then
         return Long_Float'First;
      end if;
      return -N * Log (S) + (Lambda - 1.0) * Sum_Log_X;
   exception
      when Constraint_Error | Program_Error =>
         return Long_Float'First;
   end Robust_Log_Likelihood;

   function Estimate_Lambda
     (Values        : Long_Float_Array;
      Use_Robust    : Boolean := False;
      Fallback_Used : out Boolean) return Long_Float
   is
   begin
      Fallback_Used := False;

      --  Need at least 3 observations for meaningful estimation.
      if Values'Length < 3 then
         return 0.0;
      end if;

      --  Constant-data pre-check: if all values are equal (or differ only
      --  by floating-point noise), Var_Z will be a near-zero artefact that
      --  inflates the log-likelihood spuriously.  Detect this before entering
      --  the grid and return the safe fallback immediately.
      declare
         Min_X : Long_Float := Values (Values'First);
         Max_X : Long_Float := Values (Values'First);
      begin
         for X of Values loop
            if X < Min_X then Min_X := X; end if;
            if X > Max_X then Max_X := X; end if;
         end loop;
         if Max_X - Min_X < 1.0e-10 * Max_X then
            Fallback_Used := True;
            return 0.0;
         end if;
      end;

      --  Pre-compute the constant term sum ln(x_i) used in every evaluation.
      declare
         Sum_Log_X : Long_Float := 0.0;
      begin
         for X of Values loop
            if X <= 0.0 then
               raise Constraint_Error with
                 "Estimate_Lambda: all values must be strictly positive";
            end if;
            Sum_Log_X := Sum_Log_X + Log (X);
         end loop;
         --  Coarse grid search: step 0.5 over [0.0, 30.0] (61 evaluations).
         --  Identifies the basin containing the global maximum before Brent
         --  refinement.  Lambda is restricted to [0.0, 30.0]: for positive
         --  token-count data negative lambdas are not meaningful and the UCL
         --  back-transform is always well-defined for lambda >= 0.
         declare
            --  Objective: profile log-likelihood (MLE or robust) at lambda L.
            function Objective (L : Long_Float) return Long_Float is
            begin
               return (if Use_Robust
                       then Robust_Log_Likelihood (Values, L, Sum_Log_X)
                       else Log_Likelihood        (Values, L, Sum_Log_X));
            end Objective;

            Best_Lambda : Long_Float := 0.0;
            Best_LL     : Long_Float := Long_Float'First;
            Lambda      : Long_Float := 0.0;
         begin
            while Lambda <= 30.0 + 1.0e-9 loop
               declare
                  LL : constant Long_Float := Objective (Lambda);
               begin
                  if LL > Best_LL then
                     Best_LL     := LL;
                     Best_Lambda := Lambda;
                  end if;
               end;
               Lambda := Lambda + 0.5;
            end loop;

            --  Degenerate data: every log-likelihood evaluation returned
            --  Long_Float'First (e.g. all observations identical).
            --  Fall back to lambda = 0.0 (log transform).
            if Best_LL = Long_Float'First then
               Fallback_Used := True;
               return 0.0;
            end if;

            --  Brent's method: refine within +-0.5 of the coarse best,
            --  clamped to [0.0, 30.0], to tolerance 1.0e-6 on lambda.
            --  Implements Brent (1973) Chapter 5 adapted for maximisation
            --  by negating the objective (the algorithm minimises internally).
            declare
               GR         : constant Long_Float := 0.381_966_011_250_105;
               --  (3 - sqrt(5)) / 2 — golden-section ratio, used for the
               --  fallback step when parabolic interpolation is rejected.
               Brent_A    : Long_Float :=
                 Long_Float'Max (0.0,  Best_Lambda - 0.5);
               Brent_B    : Long_Float :=
                 Long_Float'Min (30.0, Best_Lambda + 0.5);
               X_Min      : Long_Float := Brent_A + GR * (Brent_B - Brent_A);
               W, V       : Long_Float := X_Min;
               FX         : Long_Float := -Objective (X_Min);
               FW, FV     : Long_Float := FX;
               D, E       : Long_Float := 0.0;
               Tol1, Tol2 : Long_Float;
               Mid        : Long_Float;
               R, Q, P    : Long_Float;
               U, FU      : Long_Float;
            begin
               for Iter in 1 .. 100 loop
                  Mid  := 0.5 * (Brent_A + Brent_B);
                  Tol1 := 1.0e-6 * abs X_Min + 1.0e-10;
                  Tol2 := 2.0 * Tol1;
                  exit when abs (X_Min - Mid) <=
                              Tol2 - 0.5 * (Brent_B - Brent_A);

                  R := 0.0;  Q := 0.0;  P := 0.0;

                  --  Attempt parabolic interpolation from X_Min, W, V.
                  if abs E > Tol1 then
                     R := (X_Min - W) * (FX - FV);
                     Q := (X_Min - V) * (FX - FW);
                     P := (X_Min - V) * Q - (X_Min - W) * R;
                     Q := 2.0 * (Q - R);
                     if Q > 0.0 then P := -P;  else Q := -Q;  end if;
                     R := E;
                     E := D;
                  end if;

                  --  Accept parabolic step when within bounds and small enough.
                  if abs P < abs (0.5 * Q * R)         and then
                     P > Q * (Brent_A - X_Min)         and then
                     P < Q * (Brent_B - X_Min)
                  then
                     D := P / Q;
                     U := X_Min + D;
                     --  U must not land within Tol2 of either bracket end.
                     if (U - Brent_A) < Tol2 or else (Brent_B - U) < Tol2
                     then
                        D := (if X_Min < Mid then Tol1 else -Tol1);
                     end if;
                  else
                     --  Golden-section fallback: step into the larger half.
                     E := (if X_Min >= Mid then Brent_A - X_Min
                                           else Brent_B - X_Min);
                     D := GR * E;
                  end if;

                  --  U must be at least Tol1 away from X_Min.
                  U  := X_Min + (if abs D >= Tol1 then D
                                 else (if D > 0.0 then Tol1 else -Tol1));
                  FU := -Objective (U);

                  --  Update bracket and best point (Brent 1973, pp. 79–80).
                  if FU <= FX then
                     if U < X_Min then Brent_B := X_Min;
                     else              Brent_A := X_Min;
                     end if;
                     V := W;      FV := FW;
                     W := X_Min;  FW := FX;
                     X_Min := U;  FX  := FU;
                  else
                     if U < X_Min then Brent_A := U;
                     else              Brent_B := U;
                     end if;
                     if FU <= FW or else W = X_Min then
                        V := W;   FV := FW;
                        W := U;   FW := FU;
                     elsif FU <= FV or else V = X_Min or else V = W then
                        V := U;   FV := FU;
                     end if;
                  end if;
               end loop;

               return X_Min;
            end;
         end;

      end;
   end Estimate_Lambda;

   --  ── Sqrt_VS ───────────────────────────────────────────────────────────

   function Sqrt_VS (X : Long_Float) return Long_Float is
   begin
      if X < 0.0 then
         raise Constraint_Error with "Sqrt_VS: X must be >= 0";
      end if;
      return Sqrt (X);
   end Sqrt_VS;

   function Sqrt_VS_Inverse (Z : Long_Float) return Long_Float is
   begin
      return Z * Z;
   end Sqrt_VS_Inverse;

   --  ── Anscombe ──────────────────────────────────────────────────────────

   function Anscombe (X : Long_Float) return Long_Float is
   begin
      if X < 0.0 then
         raise Constraint_Error with "Anscombe: X must be >= 0";
      end if;
      return 2.0 * Sqrt (X + 0.375);
   end Anscombe;

   function Anscombe_Inverse (Z : Long_Float) return Long_Float is
   begin
      return (Z / 2.0) * (Z / 2.0) - 0.375;
   end Anscombe_Inverse;

   --  ── Arcsinh_VS ────────────────────────────────────────────────────────

   function Arcsinh_VS (X : Long_Float) return Long_Float is
   begin
      return Log (X + Sqrt (X * X + 1.0));
   end Arcsinh_VS;

   function Arcsinh_VS_Inverse (Z : Long_Float) return Long_Float is
   begin
      return (Exp (Z) - Exp (-Z)) / 2.0;
   end Arcsinh_VS_Inverse;

   --  ── Freeman_Tukey ─────────────────────────────────────────────────────

   function Freeman_Tukey (X : Long_Float) return Long_Float is
   begin
      if X < 0.0 then
         raise Constraint_Error with "Freeman_Tukey: X must be >= 0";
      end if;
      return Sqrt (X) + Sqrt (X + 1.0);
   end Freeman_Tukey;

   function Freeman_Tukey_Inverse (Z : Long_Float) return Long_Float is
      --  Algebraic inverse: x = (z² − 1)² / (4·z²) for z > 0.
      --  For z = 0 the inverse is 0; for z < 0 return 0 (domain guard).
   begin
      if Z <= 0.0 then
         return 0.0;
      end if;
      declare
         Z2 : constant Long_Float := Z * Z;
      begin
         return (Z2 - 1.0) * (Z2 - 1.0) / (4.0 * Z2);
      end;
   end Freeman_Tukey_Inverse;

   --  ── Apply_Transform / Invert_Transform ────────────────────────────────

   function Apply_Transform
     (X      : Long_Float;
      Kind   : Coyote_SQC.Data_Model.Transform_Kind;
      Lambda : Long_Float := 0.0) return Long_Float
   is
      use Coyote_SQC.Data_Model;
   begin
      case Kind is
         when None          => return X;
         when Box_Cox       => return Box_Cox (X, Lambda);
         when Sqrt_VS       => return Sqrt_VS (X);
         when Anscombe      => return Anscombe (X);
         when Arcsinh_VS    => return Arcsinh_VS (X);
         when Freeman_Tukey => return Freeman_Tukey (X);
      end case;
   end Apply_Transform;

   function Invert_Transform
     (Z      : Long_Float;
      Kind   : Coyote_SQC.Data_Model.Transform_Kind;
      Lambda : Long_Float := 0.0) return Long_Float
   is
      use Coyote_SQC.Data_Model;
   begin
      case Kind is
         when None          => return Z;
         when Box_Cox       => return Box_Cox_Inverse (Z, Lambda);
         when Sqrt_VS       => return Sqrt_VS_Inverse (Z);
         when Anscombe      => return Anscombe_Inverse (Z);
         when Arcsinh_VS    => return Arcsinh_VS_Inverse (Z);
         when Freeman_Tukey => return Freeman_Tukey_Inverse (Z);
      end case;
   end Invert_Transform;

end Coyote_SQC.Statistics.I_Chart;
