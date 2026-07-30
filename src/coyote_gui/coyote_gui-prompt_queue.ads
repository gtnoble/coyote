--  Coyote_GUI.Prompt_Queue — type-safe protected prompt/command FIFO
--  (GTK thread → agent task).
--
--  Items are discriminated variant records; each command variant carries
--  exactly the payload it needs.  There is no string-encoding convention.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with LLM.Providers;

package Coyote_GUI.Prompt_Queue is

   --  ── Item discriminant ─────────────────────────────────────────────────

   type Item_Kind is
     (User_Prompt,       --  text typed by the user; forward to LLM
      Stop,              --  abort the current response
      Pause,             --  pause after the current tool call
      Resume,            --  resume from pause
      Compact,           --  trigger manual context compaction
      New_Window,        --  spawn a fresh coyote GUI window
      Set_Model,         --  change the active model
      Set_Thinking,      --  change the reasoning level
      Set_Sandbox,       --  change the sandbox profile
      Switch_Session,    --  load a different session by UUID
      Set_Default,       --  persist current model and thinking as defaults
      Shutdown_Item);    --  queue is closing; agent task should exit

   --  ── Payload variant record ────────────────────────────────────────────
   --
   --  Variants without a payload (Stop, Pause, Resume, Compact, New_Window,
   --  Shutdown_Item) use the others branch with no fields.

   type Item (Kind : Item_Kind := User_Prompt) is record
      case Kind is
         when User_Prompt =>
            Text         : Ada.Strings.Unbounded.Unbounded_String;
         when Set_Model =>
            Model_Spec   : Ada.Strings.Unbounded.Unbounded_String;
         when Set_Thinking =>
            Level        : LLM.Providers.Thinking_Level;
         when Set_Sandbox =>
            Profile_Name : Ada.Strings.Unbounded.Unbounded_String;
         when Switch_Session =>
            Session_UUID : Ada.Strings.Unbounded.Unbounded_String;
         when others =>
            null;
      end case;
   end record;

   --  ── Queue ─────────────────────────────────────────────────────────────

   Max_Depth : constant Positive := 64;
   type Item_Array is array (1 .. Max_Depth) of Item;

   protected type Queue is
      --  Enqueue an item.  Silently drops if already at capacity.
      procedure Enqueue (I : Item);
      --  Block until an item is available or Shutdown has been called.
      --  Returns an Item with Kind = Shutdown_Item when the queue is closing.
      entry Dequeue (I : out Item);
      --  Signal shutdown: unblocks any waiting Dequeue.
      procedure Shutdown;
   private
      Items   : Item_Array;
      Head    : Natural := 1;
      Count   : Natural := 0;
      Stopped : Boolean := False;
   end Queue;

end Coyote_GUI.Prompt_Queue;
