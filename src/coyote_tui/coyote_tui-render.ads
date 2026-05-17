--  Coyote_TUI.Render — segment renderer.
--
--  All rendering writes through Coyote_TUI.Sink.Instance'Class, making
--  every public subprogram here testable with a String_Sink (no ncurses).
--
--  Measure_Segment is the single authoritative source of segment height:
--  it uses libcmark for complete Assistant_Text blocks and an LF-count
--  heuristic for all other segment kinds (which do not do markdown parsing).
--
--  Render_Frame composes a full screen frame into a content sink and a
--  status-bar sink.  It updates the caller-owned Height_Cache in place
--  for any segment that needed measuring this call.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_TUI.Segments;
with Coyote_TUI.Viewport;
with Coyote_TUI.Sink;

package Coyote_TUI.Render is

   use Coyote_TUI.Segments;
   use Coyote_TUI.Viewport;
   use Coyote_TUI.Sink;

   --  ── Measure_Segment ──────────────────────────────────────────────────
   --
   --  Return the number of display lines S occupies when rendered at the
   --  given terminal width.  At least 1 is always returned.
   function Measure_Segment
     (S    : Segment;
      Cols : Positive) return Positive;

   --  ── Render_Segment ───────────────────────────────────────────────────
   --
   --  Render segment S to Output.  Skip_Lines leading display lines are
   --  suppressed (used to implement intra-segment scroll offsets).
   --  When Match_Start >= 0 and Match_Len > 0, those bytes within the
   --  Content string are highlighted (typically with A_Reverse).
   --  Returns the number of display lines written to Output (after skipping).
   function Render_Segment
     (S           :        Segment;
      Output      : in out Instance'Class;
      Cols        :        Positive;
      Use_Color   :        Boolean  := True;
      Skip_Lines  :        Natural  := 0;
      Match_Start :        Integer  := -1;
      Match_Len   :        Natural  := 0) return Natural;

   --  ── Render_Frame ─────────────────────────────────────────────────────
   --
   --  Render a complete frame: visible segments to Content_Out, status bar
   --  to Status_Out.  Heights is updated in-place.
   --
   --  VP is the current scroll cursor (Following_Cursor → tail-follow mode).
   --  In follow mode the frame is anchored so the most-recent content fills
   --  the bottom of the window.
   --
   --  Search_Seg / Search_Off / Search_Len identify the highlighted match
   --  (all zero → no highlight).
   procedure Render_Frame
     (Content_Out  : in out Instance'Class;
      Status_Out   : in out Instance'Class;
      Snap         :        Segments.Vector;
      VP           :        Cursor;
      Heights      : in out Height_Array_Access;
      Win_Name     :        String;
      Status_Text  :        String;
      Is_Following :        Boolean;
      Search_Seg   :        Natural;
      Search_Off   :        Natural;
      Search_Len   :        Natural;
      Cols         :        Positive;
      Rows         :        Positive;
      Use_Color    :        Boolean);

end Coyote_TUI.Render;
