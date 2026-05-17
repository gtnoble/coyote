--  Coyote_TUI.Scroll — pure scroll arithmetic.
--
--  All subprograms are pure functions/procedures that take snapshots and
--  height arrays as values and return new cursors or natural numbers.
--  No protected objects, no tasks, no I/O.  Fully testable in AUnit.
--
--  Heights must have been populated for all segments accessed; a height of
--  0 means "not yet measured" and is treated as 1 for arithmetic purposes.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_TUI.Segments;
with Coyote_TUI.Viewport;

package Coyote_TUI.Scroll is

   use Coyote_TUI.Segments;
   use Coyote_TUI.Viewport;

   --  Return the measured height of segment I, defaulting to 1 for an
   --  unmeasured (0) entry.
   function Eff_Height
     (Heights : Height_Array;
      I       : Positive) return Positive
   is (if I <= Heights'Last and then Heights (I) > 0 then Heights (I) else 1);

   --  ── Advance ──────────────────────────────────────────────────────────
   --
   --  Move cursor C by Shift display lines (negative = upward).
   --  Clamps to the first line of the first segment and the last line of
   --  the last segment.  Returns Following_Cursor when Snap is empty.
   function Advance
     (Snap    : Vector;
      Heights : Height_Array;
      C       : Cursor;
      Shift   : Integer) return Cursor;

   --  ── To_Segment ───────────────────────────────────────────────────────
   --
   --  Return a cursor positioned at the first display line of segment Seg.
   --  Clamps to valid segment range.
   function To_Segment
     (Seg : Positive) return Cursor
   is ((Seg => Seg, Offset => 0));

   --  ── Total_Lines ──────────────────────────────────────────────────────
   --
   --  Sum of all segment heights.  Returns 0 when Snap is empty.
   function Total_Lines
     (Snap    : Vector;
      Heights : Height_Array) return Natural;

   --  ── Follow_Start ─────────────────────────────────────────────────────
   --
   --  In tail-follow mode the renderer shows the last Visible_Rows lines.
   --  This function returns the cursor at which rendering should begin so
   --  that exactly (or nearly) Visible_Rows lines fill the window.
   function Follow_Start
     (Snap         : Vector;
      Heights      : Height_Array;
      Visible_Rows : Positive) return Cursor;

   --  ── Cursor_To_Line ───────────────────────────────────────────────────
   --
   --  Convert a cursor to a 1-based absolute display-line number across
   --  the full document.  Returns 1 when C is Following_Cursor.
   function Cursor_To_Line
     (Snap    : Vector;
      Heights : Height_Array;
      C       : Cursor) return Positive;

   --  ── Seg_At_Line ──────────────────────────────────────────────────────
   --
   --  Return the segment index that contains absolute display line Line.
   --  Clamps to the last segment when Line exceeds the total.
   function Seg_At_Line
     (Snap    : Vector;
      Heights : Height_Array;
      Line    : Positive) return Positive;

   --  ── Next / Prev of Kind ──────────────────────────────────────────────
   --
   --  Return the segment index of the next (or previous) segment of the
   --  given Kind, searching from segment From (exclusive).
   --  Returns 0 when no such segment exists.
   function Next_Of_Kind
     (Snap : Vector;
      From : Positive;
      Kind : Segment_Kind) return Natural;

   function Prev_Of_Kind
     (Snap : Vector;
      From : Positive;
      Kind : Segment_Kind) return Natural;

end Coyote_TUI.Scroll;
