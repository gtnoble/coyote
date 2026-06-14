--  Coyote_SQC.Statistics.JSD — Jensen-Shannon divergence similarity statistic
--  for consecutive tool call pairs.
--
--  Implements per-argument bias-corrected JSD similarity S_k from
--  Grosse et al. (2002):
--
--    D_k   = H[π₁·f⁽¹⁾_k + π₂·f⁽²⁾_k]
--            − π₁·H[f⁽¹⁾_k] − π₂·H[f⁽²⁾_k]     (bits)
--    D_bc_k = D_k − (k_eff_k − 1) / (2·N_k·ln2)                          (Eq. 24)
--    S_k   = N_k·(1 − D_bc_k) = N_k·(1 − D_k) + (k_eff_k − 1)/(2·ln2)
--
--  Each argument key is processed independently, preserving σ²(S_k) = O(1)
--  (Grosse et al. 2002, §IV.B) for every observation and maintaining the
--  poolability of S_k values in grand mean and pooled s estimates.
--
--  Project: coyote

with Coyote_SQC.Data_Model;

package Coyote_SQC.Statistics.JSD is

   --  Compute the pair-level JSD similarity score for a consecutive tool call
   --  pair.  Returns the sum of per-argument bias-corrected S_k values.
   --
   --  For each key in the union of both calls' top-level JSON argument fields
   --  (plus a synthetic "tool_name" key processed first), a token sequence is
   --  produced by extracting all string-valued leaf content, splitting on
   --  whitespace, and lowercasing.  Keys with no string content on either side
   --  (N_k = 0) are skipped.  A key absent from one call contributes
   --  S_k = 0.0.  Keys present on both sides with tokens receive the full
   --  bias-corrected JSD formula.
   --
   --  The per-key S_k values are summed; the pair-level total is returned
   --  as a single scalar.  This preserves equal weighting of each
   --  consecutive pair in subsequent session-level statistics.
   function Compute_S_Values
     (Tool_Name_1 : String;
      Arguments_1 : String;
      Tool_Name_2 : String;
      Arguments_2 : String) return Long_Float;

   --  Return the total token count for a single tool call: prepend tool name,
   --  extract all JSON string values from the whole Arguments blob (character
   --  scan), whitespace-split, lowercase.  Exposed for unit testing.
   function Token_Count
     (Tool_Name : String;
      Arguments : String) return Natural;

end Coyote_SQC.Statistics.JSD;
