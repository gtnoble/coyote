--  Coyote_SQC.Statistics.C4 — the c4(n) unbiasing constant.
--
--  c4(n) = sqrt(2/(n-1)) * Gamma(n/2) / Gamma((n-1)/2)
--
--  A lookup table covers n = 2..100, computed at package elaboration.
--  For n > 100 the approximation c4(n) ≈ 1 - 1/(4*(n-1)) is used.
--  Raises Constraint_Error for n = 1 (c4 undefined).
--
--  Project: coyote

package Coyote_SQC.Statistics.C4 is

   --  Return the c4 unbiasing constant for subgroup size N.
   --  Precondition: N >= 2.  Raises Constraint_Error for N = 1.
   function C4 (N : Positive) return Long_Float;

end Coyote_SQC.Statistics.C4;
