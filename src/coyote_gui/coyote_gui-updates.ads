--  Coyote_GUI.Updates — protected Update queue (agent → GTK).
--
--  Project: coyote

package Coyote_GUI.Updates is

   Max_Depth : constant Positive := 8_192;

   type Update_Array is array (1 .. Max_Depth) of Update;

   protected type Queue is
      procedure Enqueue (U : Update);
      procedure Dequeue (U : out Update; Got : out Boolean);
      function Has_Pending return Boolean;
   private
      Items : Update_Array;
      Head  : Natural := 1;
      Count : Natural := 0;
   end Queue;

end Coyote_GUI.Updates;
