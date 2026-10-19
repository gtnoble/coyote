--  Linux-specific implementation.  Each Lock owns a separately opened file
--  description so flock serializes both tasks and independent processes.

with Ada.Directories;
with Ada.Real_Time;
with Interfaces.C;
with Interfaces.C.Strings;
with LLM.HTTP;

package body LLM.Credential_Locks is

   use type Ada.Real_Time.Time;
   use type Interfaces.C.int;
   use type LLM.Tools.Abort_Flag_Access;

   O_WRONLY   : constant Interfaces.C.int := 1;
   O_CREAT    : constant Interfaces.C.int := 64;
   O_CLOEXEC  : constant Interfaces.C.int := 524_288;
   O_NOFOLLOW : constant Interfaces.C.int := 131_072;
   LOCK_EX    : constant Interfaces.C.int := 2;
   LOCK_NB    : constant Interfaces.C.int := 4;
   MODE_0600  : constant Interfaces.C.unsigned := 384;
   EINTR      : constant Interfaces.C.int := 4;
   EAGAIN     : constant Interfaces.C.int := 11;
   EWOULDBLOCK : constant Interfaces.C.int := 11;

   function C_Open
     (Path  : Interfaces.C.Strings.chars_ptr;
      Flags : Interfaces.C.int;
      Mode  : Interfaces.C.unsigned) return Interfaces.C.int;
   pragma Import (C, C_Open, "open");

   function C_Flock
     (FD      : Interfaces.C.int;
      Operation : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Flock, "flock");

   function C_Close (FD : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Close, "close");

   function C_Errno_Location return access Interfaces.C.int;
   pragma Import (C, C_Errno_Location, "__errno_location");

   function Errno return Interfaces.C.int is
   begin
      return C_Errno_Location.all;
   end Errno;

   procedure Close_Descriptor (FD : in out Integer) is
   begin
      if FD >= 0 then
         declare
            Ignored : constant Interfaces.C.int :=
              C_Close (Interfaces.C.int (FD));
         begin
            null;
         end;
         FD := -1;
      end if;
   exception
      when others =>
         FD := -1;
   end Close_Descriptor;

   overriding procedure Finalize (Object : in out Lock) is
   begin
      Release (Object);
   exception
      when others =>
         Object.File_Descriptor := -1;
   end Finalize;

   procedure Release (Object : in out Lock) is
   begin
      Close_Descriptor (Object.File_Descriptor);
   exception
      when others =>
         Object.File_Descriptor := -1;
   end Release;

   procedure Acquire
     (Object          : in out Lock;
      Path            : String;
      Abort_Check     : LLM.Tools.Abort_Flag_Access := null;
      Timeout_Seconds : Positive := 60)
   is
      FD       : Interfaces.C.int := -1;
      Path_C   : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Path);
      Deadline : Ada.Real_Time.Time;
      Open_Flags : constant Interfaces.C.int :=
        O_WRONLY + O_CREAT + O_CLOEXEC + O_NOFOLLOW;
   begin
      Release (Object);
      if Abort_Check /= null and then Abort_Check.Requested then
         raise LLM.HTTP.Curl_Error
           with "credential lock acquisition aborted";
      end if;
      if Path'Length = 0 then
         raise Lock_Error with "empty credential lock path";
      end if;

      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      FD := C_Open (Path_C, Open_Flags, MODE_0600);
      Interfaces.C.Strings.Free (Path_C);
      Path_C := Interfaces.C.Strings.Null_Ptr;
      if FD < 0 then
         raise Lock_Error with "cannot open credential lock file";
      end if;

      Deadline := Ada.Real_Time.Clock
        + Ada.Real_Time.Seconds (Integer (Positive'Min (Timeout_Seconds, 60)));
      Acquire_Loop : loop
         if Abort_Check /= null and then Abort_Check.Requested then
            raise LLM.HTTP.Curl_Error
              with "credential lock acquisition aborted";
         end if;

         if C_Flock (FD, LOCK_EX + LOCK_NB) = 0 then
            Object.File_Descriptor := Integer (FD);
            FD := -1;
            exit Acquire_Loop;
         end if;

         if Errno /= EWOULDBLOCK and then Errno /= EAGAIN
           and then Errno /= EINTR
         then
            raise Lock_Error with "flock failed for credential lock";
         end if;
         if Ada.Real_Time.Clock >= Deadline then
            raise Lock_Error with "timed out acquiring credential lock";
         end if;
         delay 0.05;
      end loop Acquire_Loop;

      Interfaces.C.Strings.Free (Path_C);
   exception
      when LLM.HTTP.Curl_Error | Lock_Error =>
         Interfaces.C.Strings.Free (Path_C);
         if FD >= 0 then
            declare
               Ignored : constant Interfaces.C.int := C_Close (FD);
            begin
               null;
            end;
         end if;
         raise;
      when others =>
         Interfaces.C.Strings.Free (Path_C);
         if FD >= 0 then
            declare
               Ignored : constant Interfaces.C.int := C_Close (FD);
            begin
               null;
            end;
         end if;
         raise Lock_Error with "credential lock acquisition failed";
   end Acquire;

end LLM.Credential_Locks;
