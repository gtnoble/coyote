--  Coyote_TUI.Store — thread-safe conversation buffer.
--
--  A thin protected wrapper around a Segment vector; all logic is delegated
--  to the pure subprograms in Coyote_TUI.Segment_Ops.  The Snapshot
--  function returns an atomic copy of the current vector, which the UI_Task
--  uses for rendering without holding the lock during ncurses calls.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_TUI.Segments;

package Coyote_TUI.Store is

   protected type Conversation is

      --  If the last segment is an Assistant_Text (not complete), append
      --  Text to it.  Otherwise create a new incomplete Assistant_Text.
      procedure Append_Assistant_Text (Text : String);

      --  If the last segment is a Thinking_Block, append Text to it.
      --  Otherwise create a new Thinking_Block.
      procedure Append_Thinking_Text (Text : String);

      procedure Append_New (S : Coyote_TUI.Segments.Segment);

      procedure Update_Last_Content (Text : String);

      procedure Set_Last_Complete;

      procedure End_Tool
        (Tool_Id : String;
         Result  : String;
         Stat    : Coyote_TUI.Segments.Tool_Run_Status);

      --  Return an atomic copy of the current segment vector.
      function Snapshot return Coyote_TUI.Segments.Vector;

      function Count return Natural;

      procedure Clear;

   private
      Vec : Coyote_TUI.Segments.Vector;
   end Conversation;

end Coyote_TUI.Store;
