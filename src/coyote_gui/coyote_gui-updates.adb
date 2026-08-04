--  Coyote_GUI.Updates body.
--
--  Project: coyote

package body Coyote_GUI.Updates is

   protected body Queue is

      procedure Enqueue (U : Update) is
         Tail : Positive;
      begin
         if Count < Max_Depth then
            Tail := (Head - 1 + Count) mod Max_Depth + 1;
            Items (Tail) := U;
            Count := Count + 1;
         end if;
      end Enqueue;

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
