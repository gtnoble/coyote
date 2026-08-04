--  Coyote_GUI.Updates body.
--
--  Project: coyote

package body Coyote_GUI.Updates is

   protected body Queue is

      entry Enqueue (U : Update; Wake_Needed : out Boolean)
        when (Count < Max_Depth) or else Stopped
      is
         Tail : constant Positive :=
           (Head - 1 + Count) mod Max_Depth + 1;
      begin
         Wake_Needed := False;
         if not Stopped then
            if not Idle_Registered then
               Idle_Registered := True;
               Wake_Needed := True;
            end if;
            Items (Tail) := U;
            Count := Count + 1;
         end if;
      end Enqueue;

      procedure Idle_Done (Keep_Active : out Boolean) is
      begin
         Keep_Active := Count > 0;
         if not Keep_Active then
            Idle_Registered := False;
         end if;
      end Idle_Done;

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
