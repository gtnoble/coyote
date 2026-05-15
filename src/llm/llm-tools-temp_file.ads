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
--  the policy for choosing the threshold lives in LLM.Tools.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package LLM.Tools.Temp_File is

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
