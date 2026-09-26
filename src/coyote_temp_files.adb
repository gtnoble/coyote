--  Coyote_Temp_Files body.
--
--  Project: coyote

with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Interfaces.C.Strings;

package body Coyote_Temp_Files is

   use type GNAT.OS_Lib.File_Descriptor;
   use type GNATCOLL.OS.FS.File_Descriptor;

   function C_Mkstemp_GNAT (Template : Interfaces.C.Strings.chars_ptr)
      return GNAT.OS_Lib.File_Descriptor;
   pragma Import (C, C_Mkstemp_GNAT, "mkstemp");

   function C_Mkstemp_GNATCOLL
     (Template : Interfaces.C.Strings.chars_ptr)
      return GNATCOLL.OS.FS.File_Descriptor;
   pragma Import (C, C_Mkstemp_GNATCOLL, "mkstemp");

   procedure Create
     (FD   : out GNAT.OS_Lib.File_Descriptor;
      Path : out Unbounded_String)
   is
      Template : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("/tmp/coyote-XXXXXX");
   begin
      FD := C_Mkstemp_GNAT (Template);
      if FD = GNAT.OS_Lib.Invalid_FD then
         Path := Null_Unbounded_String;
      else
         Path := To_Unbounded_String
           (Interfaces.C.Strings.Value (Template));
      end if;
      Interfaces.C.Strings.Free (Template);
   exception
      when others =>
         Interfaces.C.Strings.Free (Template);
         raise;
   end Create;

   procedure Create
     (FD   : out GNATCOLL.OS.FS.File_Descriptor;
      Path : out Unbounded_String)
   is
      Template : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String ("/tmp/coyote-XXXXXX");
   begin
      FD := C_Mkstemp_GNATCOLL (Template);
      if FD = GNATCOLL.OS.FS.Invalid_FD then
         Path := Null_Unbounded_String;
      else
         Path := To_Unbounded_String
           (Interfaces.C.Strings.Value (Template));
      end if;
      Interfaces.C.Strings.Free (Template);
   exception
      when others =>
         Interfaces.C.Strings.Free (Template);
         raise;
   end Create;

   procedure Delete (Path : String) is
   begin
      if Path'Length > 0 and then Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete;

end Coyote_Temp_Files;
