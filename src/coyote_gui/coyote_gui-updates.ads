--  Coyote_GUI.Updates — protected Update queue (agent → GTK).
--
--  Project: coyote

package Coyote_GUI.Updates is

   Max_Depth : constant Positive := 8_192;

   type Update_Array is array (1 .. Max_Depth) of Update;

   protected type Queue is
      entry Enqueue (U : Update; Wake_Needed : out Boolean);
      --  Enqueue an update and block while the bounded queue is full.
      --  Wake_Needed is True exactly when the caller must register the
      --  idle source.  No update is stored after Stop.
      procedure Idle_Done (Keep_Active : out Boolean);
      --  Complete one idle callback.  Keep the source registered when work
      --  remains; otherwise clear its registration state atomically.
      procedure Stop;
      --  Close the queue and release any producer blocked in Enqueue.
      procedure Dequeue (U : out Update; Got : out Boolean);
      function Has_Pending return Boolean;
   private
      Items           : Update_Array;
      Head            : Natural := 1;
      Count           : Natural := 0;
      Idle_Registered : Boolean := False;
      Stopped         : Boolean := False;
   end Queue;

end Coyote_GUI.Updates;
