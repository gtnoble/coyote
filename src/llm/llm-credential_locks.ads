--  LLM.Credential_Locks provides process- and task-safe file locks for
--  credential operations.
--
--  Acquire creates the parent directory; waits are capped at 60 seconds.
--  Cancellation raises LLM.HTTP.Curl_Error; other acquisition failures
--  raise Lock_Error. Release and finalization never propagate exceptions.

with Ada.Finalization;
with LLM.Tools;

package LLM.Credential_Locks is

   Lock_Error : exception;

   type Lock is new Ada.Finalization.Limited_Controlled with private;

   procedure Acquire
     (Object          : in out Lock;
      Path            : String;
      Abort_Check     : LLM.Tools.Abort_Flag_Access := null;
      Timeout_Seconds : Positive := 60);

   procedure Release (Object : in out Lock);

private

   type Lock is new Ada.Finalization.Limited_Controlled with record
      File_Descriptor : Integer := -1;
   end record;

   overriding procedure Finalize (Object : in out Lock);

end LLM.Credential_Locks;
