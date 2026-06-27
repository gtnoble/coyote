--  Coyote_SQC.Statistics.MI — compression-based mutual information
--  statistic for consecutive tool call pairs.
--
--  Implements per-argument compression-based mutual information MI_k
--  using zlib deflate streaming dictionary-preloaded compression at
--  level 9.
--
--    MI_k = (|compress(C, dict=∅)| − |compress(C, dict=Q)|
--            + |compress(Q, dict=∅)| − |compress(Q, dict=C)|) / 2
--
--  where C and Q are the argument strings from each call, and
--  |compress(X, dict=D)| is the compressed size of X in bytes when
--  compressed with dictionary D pre-loaded into the compressor.
--
--  Negative MI_k values (when the dictionary misleads the compressor)
--  are retained.  Both-side-empty keys are skipped.
--
--  Project: coyote
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
   --  Negative MI_k values (when the dictionary misleads the compressor)
   --  are retained.
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
