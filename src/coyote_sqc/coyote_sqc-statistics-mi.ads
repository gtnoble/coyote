--  Coyote_SQC.Statistics.MI — compression-based mutual information
--  statistic for consecutive tool call pairs.
--
--  Implements per-argument compression-based mutual information MI_k
--  using zlib deflate at maximum compression (level 9).
--
--    MI_k = C_a_k + C_b_k − C_ab_k
--
--  where C_a, C_b are the compressed sizes of the argument strings from
--  each call, and C_ab is the compressed size of the concatenated strings.
--
--  Non-positive MI_k values (zlib block-header overhead) are clamped to
--  0.0.  Both-side-empty keys are skipped.
--
--  Project: coyote

with Coyote_SQC.Data_Model;

package Coyote_SQC.Statistics.MI is

   --  Compute per-argument mutual information values for a consecutive
   --  tool call pair and append them to Result.
   --
   --  One MI_k value is appended for each key in the union of:
   --    - a synthetic "tool_name" key (always processed; tool name string)
   --    - every top-level JSON argument key in Arguments_1 or Arguments_2
   --
   --  Keys with no string content on either side are skipped.
   --  Keys present in one call but absent in the other contribute MI_k = 0.0.
   --  Non-positive MI_k values (compression artifacts) are clamped to 0.0.
   --
   --  Each string is lowercased before compression.
   --
   --  Result is not cleared before appending; the caller is responsible
   --  for initialising it.
   procedure Compute_MI_Values
     (Tool_Name_1 : String;
      Arguments_1 : String;
      Tool_Name_2 : String;
      Arguments_2 : String;
      Result      : in out Coyote_SQC.Data_Model.Long_Float_Vectors.Vector);

end Coyote_SQC.Statistics.MI;
