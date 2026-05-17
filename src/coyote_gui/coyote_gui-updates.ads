--  Coyote_GUI.Updates — protected Update queue (agent → GTK).
--
--  Project: coyote

package Coyote_GUI.Updates is

   Max_Depth : constant Positive := 8_192;

   type Update_Array is array (1 .. Max_Depth) of Update;

   protected type Queue is
      procedure Enqueue (U : Update);
      --  Enqueue an update.  Sets the Idle_Needed flag when the queue
      --  transitions from empty to non-empty.
      procedure Take_Idle_Request (Needed : out Boolean);
      --  Atomically reads and clears the Idle_Needed flag.  Returns True the
      --  first time after the queue transitions from empty to non-empty;
      --  False otherwise.  The caller should register a GLib idle callback
      --  when True is returned.
      procedure Dequeue (U : out Update; Got : out Boolean);
      function Has_Pending return Boolean;
   private
      Items       : Update_Array;
      Head        : Natural := 1;
      Count       : Natural := 0;
      Idle_Needed : Boolean := False;
   end Queue;

end Coyote_GUI.Updates;
