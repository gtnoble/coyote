--  Coyote_Process_Control — process-group shutdown and signal coordination.
--
--  Owns the process groups created for shell tools, receives deferred
--  SIGTERM notifications, and prevents persistence writes after shutdown
--  begins.
--
--  Project: coyote

package Coyote_Process_Control is

   SIGTERM_Signal : constant Integer := 15;
   SIGKILL_Signal : constant Integer := 9;

   --  Install the process-wide SIGTERM notification channel.
   function Install return Boolean;

   --  Return 0 when no signal is pending, 1 for the first SIGTERM, and 2
   --  when a second SIGTERM has been received.
   function Read_Signal return Natural;

   --  Configure and return the maximum shutdown grace period in seconds.
   --  Values above 30 are clamped to 30.
   procedure Set_Grace_Seconds (Value : Natural);
   function Grace_Seconds return Natural;

   --  Reserve a shell launch.  New launches are rejected after shutdown
   --  begins, closing the Start/Register race.
   procedure Begin_Launch (Accepted : out Boolean);

   --  Complete a reserved launch and register its process-group leader.
   --  Needs_Signal is True when shutdown began during Start.
   procedure Complete_Launch
     (Pid          : Integer;
      Needs_Signal : out Boolean);

   --  Cancel a launch reservation when Start fails.
   procedure Cancel_Launch;

   --  Wait until all launch reservations have completed or been cancelled.
   procedure Wait_For_Launches;

   --  Wait until all registered shell process groups have been unregistered.
   procedure Wait_For_Groups;

   --  Mark shutdown as requested.  First is True only for the first caller.
   procedure Begin_Shutdown (First : out Boolean);

   --  Wait for launch races, send TERM, wait for the configured grace
   --  period, then send KILL to any remaining groups.  A second SIGTERM
   --  during the grace period escalates immediately.
   procedure Complete_Shutdown (Immediate : Boolean := False);

   --  True after the first SIGTERM shutdown sequence has begun.
   function Shutdown_Requested return Boolean;

   --  Stop the signal monitor during ordinary UI-driven shutdown.
   procedure Stop_Monitor;
   function Monitor_Should_Stop return Boolean;

   --  Signal every registered shell process group and nested descendants.
   procedure Signal_All (Signal : Integer);

   --  Signal one registered shell process group and nested descendants.
   procedure Signal_Group (Pid : Integer; Signal : Integer);

   --  Remove a process group after its direct child has been waited for.
   procedure Unregister (Pid : Integer);

   --  Freeze session persistence after any write already in progress ends.
   procedure Freeze_Persistence;

   --  Begin one session-file write.  Accepted is False after persistence
   --  has been frozen.  The operation never blocks.
   procedure Begin_Persistence_Write (Accepted : out Boolean);

   --  Complete a previously accepted session-file write.
   procedure End_Persistence_Write;

end Coyote_Process_Control;
