--  Coyote_TUI.Viewport — viewport cursor and height-cache types.
--
--  The Cursor type encodes the current scroll position as a segment index
--  plus an intra-segment line offset.  This representation is stable across
--  terminal resizes: segment indices never change, so only the Height_Cache
--  needs to be invalidated and lazily re-populated after a resize.
--
--  The Height_Cache is an unconstrained array allocated on the heap by
--  Ensure_Capacity.  The UI_Task owns the cache; it is passed in-out to
--  the renderer each frame.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_TUI.Viewport is


   --  ── Cursor ────────────────────────────────────────────────────────────

   type Cursor is record
      Seg    : Natural := 0;
      --  Segment index (1-based).  0 means "follow the tail" (no explicit
      --  scroll position; the renderer always shows the most-recent content).
      Offset : Natural := 0;
      --  Number of display lines to skip at the top of segment Seg before
      --  rendering begins.  Always 0 when Seg = 0.
   end record;

   --  The sentinel value that means "following tail".
   Following_Cursor : constant Cursor := (Seg => 0, Offset => 0);

   --  True iff C is in tail-follow mode.
   function Is_Following (C : Cursor) return Boolean is (C.Seg = 0);

   --  ── Height cache ──────────────────────────────────────────────────────

   --  Per-segment rendered height in display lines (0 = not yet measured).
   --  Indexed by segment number (1-based); the array length always matches
   --  or exceeds the current segment count.
   type Height_Array is array (Positive range <>) of Natural;

   type Height_Array_Access is access Height_Array;

end Coyote_TUI.Viewport;
