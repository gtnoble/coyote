--  Coyote_TUI.Sink — abstract terminal output sink interface.
--
--  All renderer calls go through this interface.  Concrete implementations:
--    Coyote_TUI.Sink.Ncurses_Sink — wraps a Coyote_Ncurses.Window (production)
--    Coyote_TUI.Sink.String_Sink  — accumulates to Unbounded_String (tests)
--
--  The renderer never imports Coyote_Ncurses directly; all ncurses calls
--  are encapsulated inside Ncurses_Sink.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_TUI.Sink is

   --  ── Instance interface ────────────────────────────────────────────────

   type Instance is interface;

   --  Append a UTF-8 string at the current cursor position.
   procedure Put
     (S    : in out Instance;
      Text :        String) is abstract;

   --  Emit a newline (advance to next row, column 0).
   procedure New_Line (S : in out Instance) is abstract;

   --  Enable a text attribute (A_Bold, A_Dim, A_Reverse, …).
   procedure Attr_On
     (S : in out Instance;
      A :        Integer) is abstract;

   --  Disable a text attribute.
   procedure Attr_Off
     (S : in out Instance;
      A :        Integer) is abstract;

   --  Apply a complete colour-pair attribute (replaces current attrs).
   procedure Color_On
     (S    : in out Instance;
      Pair :        Integer) is abstract;

   --  Reset all attributes and colour to normal.
   procedure Reset_Attrs (S : in out Instance) is abstract;

   --  Move the cursor to (Row, Col) within the window (0-based).
   procedure Move
     (S   : in out Instance;
      Row :        Natural;
      Col :        Natural) is abstract;

   --  Erase the entire window content.
   procedure Erase (S : in out Instance) is abstract;

   --  Flush/stage changes.  Ncurses_Sink calls Wnoutrefresh; String_Sink
   --  is a no-op.
   procedure Refresh (S : in out Instance) is abstract;

end Coyote_TUI.Sink;
