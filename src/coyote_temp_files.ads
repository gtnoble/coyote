--  Coyote_Temp_Files — secure temporary files under /tmp.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNATCOLL.OS.FS;

package Coyote_Temp_Files is

   --  Create and open a uniquely named file under /tmp.  The caller owns the
   --  descriptor and must close it, and should delete Path when finished.
   procedure Create
     (FD   : out GNAT.OS_Lib.File_Descriptor;
      Path : out Ada.Strings.Unbounded.Unbounded_String);

   procedure Create
     (FD   : out GNATCOLL.OS.FS.File_Descriptor;
      Path : out Ada.Strings.Unbounded.Unbounded_String);

   --  Delete Path if it exists.  Cleanup failures are ignored.
   procedure Delete (Path : String);

end Coyote_Temp_Files;
