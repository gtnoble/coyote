--  Coyote_SQC.Statistics.C4 body.
--
--  Project: coyote

with Ada.Numerics;
with Ada.Numerics.Long_Elementary_Functions;

package body Coyote_SQC.Statistics.C4 is

   use Ada.Numerics.Long_Elementary_Functions;

   --  Compute log Gamma(X) for X > 0 using the recurrence
   --    log Γ(x+1) = log Γ(x) + log(x)
   --  seeded from Γ(0.5) = sqrt(π) and Γ(1.0) = 1.0.
   function Log_Gamma (X : Long_Float) return Long_Float is
      V : Long_Float := X;
      R : Long_Float := 0.0;
   begin
      --  Descend to a seed point by applying the recurrence in reverse:
      --    log Γ(v) = log Γ(v-1) + log(v-1)  →  subtract log(v-1) and v:=v-1
      --  We stop when V < 1.5, leaving V ≈ 1.0 (integer seed) or V ≈ 0.5.
      while V >= 1.5 loop
         V := V - 1.0;
         R := R + Log (V);
      end loop;
      --  V is now in (0, 1.5).  The two relevant seeds are at 0.5 and 1.0.
      if V > 0.75 then
         --  V ≈ 1.0: log Γ(1.0) = 0.0
         return R;
      else
         --  V ≈ 0.5: log Γ(0.5) = 0.5 * log(π)
         return R + 0.5 * Log (Ada.Numerics.Pi);
      end if;
   end Log_Gamma;

   --  Precomputed table: Table(N) = c4(N) for N = 2..100.
   Table : array (2 .. 100) of Long_Float;

   function C4 (N : Positive) return Long_Float is
   begin
      if N = 1 then
         raise Constraint_Error with "c4 undefined for n=1";
      end if;
      if N <= 100 then
         return Table (N);
      end if;
      --  Approximation for n > 100:  c4(n) ≈ 1 − 1/(4*(n−1))
      return 1.0 - 1.0 / (4.0 * Long_Float (N - 1));
   end C4;

begin
   --  Populate the lookup table at package elaboration.
   for N in 2 .. 100 loop
      declare
         NF : constant Long_Float := Long_Float (N);
         --  c4(n) = sqrt(2/(n-1)) * Γ(n/2) / Γ((n-1)/2)
         --        = exp(0.5*log(2/(n-1)) + log_Γ(n/2) - log_Γ((n-1)/2))
         Log_C4 : constant Long_Float :=
           0.5 * Log (2.0 / (NF - 1.0))
           + Log_Gamma (NF / 2.0)
           - Log_Gamma ((NF - 1.0) / 2.0);
      begin
         Table (N) := Exp (Log_C4);
      end;
   end loop;
end Coyote_SQC.Statistics.C4;
