--  LLM.Tools.Temp_File — tool-result size cap with temp-file spill.
--
--  Enforces a byte threshold on a tool-result string.  When the result
--  fits within the threshold the original string is returned unchanged
--  and no file is written.  When it exceeds the threshold the full
--  content is written to a uniquely-named file under /tmp/ and the
--  return value is the first Threshold bytes followed by a trailer that
--  identifies the file and the total byte count.
--
--  This package is the single mechanism for capping tool output size;
--  the policy for choosing the threshold also lives here.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package LLM.Tools.Temp_File is

   --  ── Result-size policy ───────────────────────────────────────────────

   --  Approximate number of UTF-8 bytes per model token for prose and code.
   BYTES_PER_TOKEN : constant := 4;

   --  One tool result may consume at most 1/CONTEXT_SHARE of the estimated
   --  byte capacity of the context window.
   CONTEXT_SHARE : constant := 8;

   --  Hard floor: useful minimum even for very small context windows.
   MIN_RESULT_THRESHOLD : constant Natural := 4 * 1_024;

   --  Hard ceiling: matches the prior fixed default; prevents excessive
   --  memory use for hypothetical very large context windows.
   MAX_RESULT_THRESHOLD : constant Natural := 200 * 1_024;

   --  Return the maximum byte size for a single tool result given a
   --  model's context window in tokens.
   --
   --  Allocates BYTES_PER_TOKEN × Context_Window / CONTEXT_SHARE bytes,
   --  clamped to [MIN_RESULT_THRESHOLD, MAX_RESULT_THRESHOLD].
   --  When Context_Window is 0 MAX_RESULT_THRESHOLD is returned so that
   --  callers with an unknown model get the most permissive safe cap.
   function Result_Threshold (Context_Window : Natural) return Positive;

   --  ── Truncation ───────────────────────────────────────────────────────

   --  Return Text unchanged when Text'Length <= Threshold.
   --
   --  Otherwise write all of Text to a new temp file whose name embeds
   --  Tool_Name, the process ID, and a per-process sequence number, then
   --  return the first Threshold bytes of Text followed by:
   --
   --    [output truncated at THRESHOLD bytes;
   --     full output saved to PATH; total bytes N]
   --
   --  If the temp file cannot be created the excerpt is still returned,
   --  with a note replacing the file path.  The function never raises.
   function Truncated
     (Text      : String;
      Threshold : Positive;
      Tool_Name : String := "tool") return String;

end LLM.Tools.Temp_File;
