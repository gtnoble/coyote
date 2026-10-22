--  Coyote_Spawn body.
--  Project: coyote

with Ada.Strings.Fixed;
with Interfaces.C;
with Interfaces.C.Strings;

package body Coyote_Spawn is

   function Spawn_Detached
     (Args : GNATCOLL.OS.Process.Argument_List;
      Cwd  : String := "")
      return Boolean
   is
      use Interfaces.C;
      use Interfaces.C.Strings;

      function C_Detach_Spawn
        (Argv : chars_ptr_array; Cwd : chars_ptr) return int with
        Import, Convention => C, External_Name => "coyote_detach_spawn";

      Argc : constant size_t := size_t (Args.Length);
      Argv : chars_ptr_array (0 .. Argc);
      C_Cwd : chars_ptr := Null_Ptr;
   begin
      if Argc = 0
        or else Ada.Strings.Fixed.Index
          (Cwd, String'(1 => Character'Val (0))) /= 0
      then
         return False;
      end if;
      for I in 0 .. Argc - 1 loop
         if Ada.Strings.Fixed.Index
           (Args.Element (Natural (I)),
            String'(1 => Character'Val (0))) /= 0
         then
            return False;
         end if;
      end loop;

      for I in Argv'Range loop
         Argv (I) := Null_Ptr;
      end loop;

      begin
         for I in 0 .. Argc - 1 loop
            Argv (I) := New_String (Args.Element (Natural (I)));
         end loop;
         if Cwd'Length > 0 then
            C_Cwd := New_String (Cwd);
         end if;

         declare
            Result : constant int := C_Detach_Spawn (Argv, C_Cwd);
         begin
            if C_Cwd /= Null_Ptr then
               Free (C_Cwd);
            end if;
            for I in 0 .. Argc - 1 loop
               Free (Argv (I));
            end loop;
            return Result = 0;
         end;
      exception
         when others =>
            if C_Cwd /= Null_Ptr then
               Free (C_Cwd);
            end if;
            for I in 0 .. Argc - 1 loop
               if Argv (I) /= Null_Ptr then
                  Free (Argv (I));
               end if;
            end loop;
            raise;
      end;
   end Spawn_Detached;

end Coyote_Spawn;
