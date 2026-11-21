with Ada.Directories;
with Ada.Real_Time;
with GNAT.OS_Lib;
with GNAT.SHA256;

package body Coyote_Session_Transactions is
   use Interfaces.C;
   use Ada.Real_Time;

   function Native_Lock (Parent, Id : char_array; FD : out int) return int
     with Import, Convention => C,
          External_Name => "coyote_session_transaction_lock";
   function Mkostemp (Name : in out char_array) return int
     with Import, Convention => C,
          External_Name => "coyote_session_stage";
   function Native_Publish (Stage, Target : char_array) return int
     with Import, Convention => C,
          External_Name => "coyote_session_publish";
   function Close (FD : int) return int
     with Import, Convention => C, External_Name => "close";

   function Canonical_UUID (Id : String) return Boolean is
   begin
      if Id'Length /= 36 then
         return False;
      end if;
      for I in Id'Range loop
         if I - Id'First in 8 | 13 | 18 | 23 then
            if Id (I) /= '-' then
               return False;
            end if;
         elsif Id (I) not in '0' .. '9' | 'a' .. 'f' then
            return False;
         end if;
      end loop;
      return True;
   end Canonical_UUID;

   procedure Try_Lock (Parent, Id : String; Lock : in out Guard;
                       Status : out Result) is
   begin
      Status := Unavailable;
      if Lock.FD >= 0 or else Parent'Length not in 1 .. 4_095
        or else Parent (Parent'First) /= '/'
        or else (Parent'Length > 1 and then Parent (Parent'Last) = '/')
        or else Id'Length not in 36 | 64
      then
         return;
      end if;
      for Ch of Parent loop
         if Ch = ASCII.NUL then
            return;
         end if;
      end loop;
      Status := Result'Val (Native_Lock (To_C (Parent), To_C (Id), Lock.FD));
   end Try_Lock;

   procedure Unlock (Lock : in out Guard) is
      Ignored : int;
   begin
      if Lock.FD >= 0 then
         Ignored := Close (Lock.FD);
         Lock.FD := -1;
      end if;
   end Unlock;

   overriding procedure Finalize (Lock : in out Guard) is
   begin
      Unlock (Lock);
   end Finalize;

   function Resolve (Path : String) return String is
     (if Path'Length = 0 then ""
      else GNAT.OS_Lib.Normalize_Pathname (Path, Resolve_Links => True));

   function Identity (Resolved_Path : String) return String is
      Leaf : constant String := Ada.Directories.Simple_Name (Resolved_Path);
      Last : constant Integer := Leaf'Last - 6;
   begin
      if Leaf'Length >= 42 and then Leaf (Last + 1 .. Leaf'Last) = ".jsonl"
        and then (Leaf'Length = 42 or else Leaf (Last - 36) = '_')
        and then Canonical_UUID (Leaf (Last - 35 .. Last))
      then
         return Leaf (Last - 35 .. Last);
      end if;
      return GNAT.SHA256.Digest (Leaf);
   end Identity;

   function Create_Stage (Resolved_Path : String) return String is
      Name : char_array := To_C
        (Ada.Directories.Containing_Directory (Resolved_Path)
         & "/.coyote-session-XXXXXX");
      FD : constant int := Mkostemp (Name);
      Ignored : int;
   begin
      if FD < 0 then
         return "";
      end if;
      Ignored := Close (FD);
      return To_Ada (Name);
   end Create_Stage;

   procedure Publish (Stage, Resolved_Path : String; Status : out Result) is
   begin
      Status := Result'Val (Native_Publish (To_C (Stage), To_C (Resolved_Path)));
   end Publish;

   procedure Replace_Log (Stage, Resolved_Path : String; Status : out Result;
                          Uncertain : out Boolean) is
      function Native_Replace (Stage, Target : char_array) return int
        with Import, Convention => C, External_Name => "coyote_session_replace";
      Code : constant int := Native_Replace (To_C (Stage), To_C (Resolved_Path));
   begin
      Uncertain := Code = 3;
      Status := (if Code = 0 then Acquired else Unavailable);
   end Replace_Log;

   function Sync_Log (Resolved_Path : String) return Boolean is
      function Native_Sync (Path : char_array) return int
        with Import, Convention => C, External_Name => "coyote_session_sync";
   begin
      return Native_Sync (To_C (Resolved_Path)) = 0;
   end Sync_Log;

   procedure Wait_For_Lock (Resolved_Path : String; Lock : in out Guard;
                            Status : out Result) is
      Parent : constant String := Ada.Directories.Containing_Directory
        (Resolved_Path);
      Id : constant String := Identity (Resolved_Path);
      Deadline : constant Time := Clock + Seconds (2);
   begin
      Retry : loop
         Try_Lock (Parent, Id, Lock, Status);
         exit Retry when Status /= Busy or else Clock >= Deadline;
         declare
            Next : constant Time := Clock + Milliseconds (20);
         begin
            delay until (if Next < Deadline then Next else Deadline);
         end;
      end loop Retry;
   end Wait_For_Lock;
end Coyote_Session_Transactions;
