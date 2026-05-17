--  Coyote_TUI.Prompt_Queue body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Coyote_TUI.Prompt_Queue is

   protected body Queue is

      procedure Enqueue (Text : String) is
      begin
         if N >= Max_Depth then
            raise Constraint_Error with
              "Coyote_TUI.Prompt_Queue: queue full";
         end if;
         Items (Tail) := (Text => To_Unbounded_String (Text));
         Tail := (Tail mod Max_Depth) + 1;
         N    := N + 1;
      end Enqueue;

      entry Dequeue (E : out Entry_T) when N > 0 or else Shut is
      begin
         if N > 0 then
            E    := Items (Head);
            Head := (Head mod Max_Depth) + 1;
            N    := N - 1;
         else
            E := (Text => Null_Unbounded_String);
         end if;
      end Dequeue;

      procedure Shutdown is
      begin
         Shut := True;
      end Shutdown;

      function Is_Shutdown return Boolean is
      begin
         return Shut;
      end Is_Shutdown;

      function Depth return Natural is
      begin
         return N;
      end Depth;

   end Queue;

end Coyote_TUI.Prompt_Queue;
