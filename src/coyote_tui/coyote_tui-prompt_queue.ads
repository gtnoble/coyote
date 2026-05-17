--  Coyote_TUI.Prompt_Queue — thread-safe bounded FIFO for user prompts.
--
--  Unlike the previous single-slot latch, this is a true circular-buffer
--  FIFO.  Enqueue raises Constraint_Error when the queue is full
--  (Max_Depth items); in practice this is unreachable from the TUI.
--  Dequeue blocks until an item is available or Shutdown has been called.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package Coyote_TUI.Prompt_Queue is

   Max_Depth : constant := 64;


   type Entry_T is record
      Text : Ada.Strings.Unbounded.Unbounded_String;
   end record;
   type Entry_Array is array (1 .. Max_Depth) of Entry_T;


   protected type Queue is

      --  Enqueue a prompt.  Raises Constraint_Error when the queue is full.
      procedure Enqueue (Text : String);

      --  Block until an item is available or Shutdown has been called.
      --  When Shutdown has been called, E.Text will be Null_Unbounded_String.
      entry Dequeue (E : out Entry_T);

      --  Signal shutdown: unblocks any waiting Dequeue call.
      procedure Shutdown;

      function Is_Shutdown return Boolean;

      function Depth return Natural;

   private
      Items : Entry_Array;
      Head  : Natural  := 1;
      Tail  : Natural  := 1;
      N     : Natural  := 0;
      Shut  : Boolean  := False;
   end Queue;

end Coyote_TUI.Prompt_Queue;
