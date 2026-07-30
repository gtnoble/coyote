--  Coyote_Spawn body.
--
--  Project: coyote

with Interfaces.C;
with Interfaces.C.Strings;

package body Coyote_Spawn is

   procedure Spawn_Detached
     (Args : GNATCOLL.OS.Process.Argument_List;
      Cwd  : String := "")
   is
      use Interfaces.C;
      use Interfaces.C.Strings;

      --  C function: int coyote_detach_spawn(char *const argv[], const char *cwd);
      function C_Detach_Spawn
        (Argv : chars_ptr_array;
         Cwd  : chars_ptr) return int
      with Import, Convention => C,
           External_Name => "coyote_detach_spawn";

      Argc : constant size_t := size_t (Args.Length);
      Argv : chars_ptr_array (0 .. Argc);  --  +1 for NULL terminator
      C_Cwd : chars_ptr;
      Dummy  : int;
      pragma Unreferenced (Dummy);
   begin
      --  Build null-terminated argv array.
      for I in 0 .. Argc - 1 loop
         Argv (I) := New_String (Args.Element (Natural (I)));
      end loop;
      Argv (Argc) := Null_Ptr;

      if Cwd'Length > 0 then
         C_Cwd := New_String (Cwd);
      else
         C_Cwd := Null_Ptr;
      end if;

      Dummy := C_Detach_Spawn (Argv, C_Cwd);

      --  Free the C strings.
      if C_Cwd /= Null_Ptr then
         Free (C_Cwd);
      end if;
      for I in 0 .. Argc - 1 loop
         Free (Argv (I));
      end loop;
   end Spawn_Detached;

end Coyote_Spawn;
