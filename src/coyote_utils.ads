--  Coyote_Utils — small utility functions shared across coyote entry points.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_Utils is

   --  If Path names an existing regular file, read its entire contents and
   --  return them as a String.  Returns "" when Path is empty, does not
   --  exist, or cannot be read.
   function Read_File_If_Exists (Path : String) return String;

end Coyote_Utils;
