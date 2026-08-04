--  Coyote_GUI.Updates body.
--
--  Project: coyote

package body Coyote_GUI.Updates is

   protected body Queue is

      entry Enqueue (U : Update)
        when (Count < Max_Depth) or Stopped
      is
         Tail : constant Positive :=
           (Head - 1 + Count) mod Max_Depth + 1;
      begin
         if not Stopped then
            Items (Tail) := U;
            Count := Count + 1;
         end if;
      end Enqueue;

      procedure Stop is
      begin
         Stopped := True;
      end Stop;

      procedure Dequeue (U : out Update; Got : out Boolean) is
      begin
         Got := Count > 0;
         if Got then
            U     := Items (Head);
            Head  := Head mod Max_Depth + 1;
            Count := Count - 1;
         end if;
      end Dequeue;

      function Has_Pending return Boolean is
      begin
         return Count > 0;
      end Has_Pending;

   end Queue;

end Coyote_GUI.Updates;
