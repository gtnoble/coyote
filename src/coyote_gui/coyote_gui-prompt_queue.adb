--  Coyote_GUI.Prompt_Queue body.
--
--  Project: coyote

package body Coyote_GUI.Prompt_Queue is

   protected body Queue is

      procedure Enqueue (I : Item) is
         Tail : Natural;
      begin
         if Count < Max_Depth then
            Tail := (Head - 1 + Count) mod Max_Depth + 1;
            Items (Tail) := I;
            Count := Count + 1;
         end if;
      end Enqueue;

      entry Dequeue (I : out Item)
        when Count > 0 or else Stopped
      is
      begin
         if Count > 0 then
            I    := Items (Head);
            Head := Head mod Max_Depth + 1;
            Count := Count - 1;
         else
            I := (Kind => Shutdown_Item);
         end if;
      end Dequeue;

      procedure Shutdown is
      begin
         Stopped := True;
      end Shutdown;

   end Queue;

end Coyote_GUI.Prompt_Queue;
