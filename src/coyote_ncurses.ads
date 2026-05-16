--  Coyote_Ncurses — thin Ada binding to ncursesw.
--
--  All subprograms are thin wrappers that delegate to C (either the
--  ncursesw library directly or the glue in coyote_ncurses_c.c).
--  No dynamic allocation is performed by this package.
--
--  Thread safety: ncurses is NOT thread-safe.  All calls must be made
--  from a single task (the TUI UI_Task).
--
--  Initialisation sequence (must be called once, in order):
--    1. Init          → returns Stdscr
--    2. Init_Pair     → define colour pairs (if colour output is needed)
--
--  Shutdown sequence:
--    1. Endwin (or Suspend before an external program, Resume after)
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Interfaces.C;
with System;

package Coyote_Ncurses is

   --  ── Window handle ─────────────────────────────────────────────────────
   --
   --  An opaque wrapper around WINDOW*.  Null_Window is the zero address
   --  and is used as a sentinel for "not yet created".

   type Window is private;
   Null_Window : constant Window;

   --  ── Colour pair index ─────────────────────────────────────────────────

   subtype Colour_Pair is Interfaces.C.short range 0 .. 255;

   --  Predefined colour constants matching ncurses COLOR_* values.
   COLOR_BLACK   : constant := 0;
   COLOR_RED     : constant := 1;
   COLOR_GREEN   : constant := 2;
   COLOR_YELLOW  : constant := 3;
   COLOR_BLUE    : constant := 4;
   COLOR_MAGENTA : constant := 5;
   COLOR_CYAN    : constant := 6;
   COLOR_WHITE   : constant := 7;
   COLOR_DEFAULT : constant := -1;  --  requires use_default_colors()

   --  ── KEY_* accessors ───────────────────────────────────────────────────
   --
   --  These are functions because ncurses KEY_* values are C macros that
   --  can vary across builds.  Evaluate once at startup and cache if needed.

   function Key_Up        return Integer;
   function Key_Down      return Integer;
   function Key_Ppage     return Integer;   --  Page Up
   function Key_Npage     return Integer;   --  Page Down
   function Key_Backspace return Integer;
   function Key_Resize    return Integer;
   function Key_Enter     return Integer;

   pragma Import (C, Key_Up,        "ncurses_key_up");
   pragma Import (C, Key_Down,      "ncurses_key_down");
   pragma Import (C, Key_Ppage,     "ncurses_key_ppage");
   pragma Import (C, Key_Npage,     "ncurses_key_npage");
   pragma Import (C, Key_Backspace, "ncurses_key_backspace");
   pragma Import (C, Key_Resize,    "ncurses_key_resize");
   pragma Import (C, Key_Enter,     "ncurses_key_enter");

   --  ── Attribute values ──────────────────────────────────────────────────
   --
   --  Queried from C because ncurses A_* macros differ across builds.

   function A_Normal  return Integer;
   function A_Bold    return Integer;
   function A_Dim     return Integer;
   function A_Reverse return Integer;

   --  Return the combined attribute integer for colour pair N.
   function Color_Pair (N : Integer) return Integer;

   pragma Import (C, A_Normal,   "ncurses_a_normal");
   pragma Import (C, A_Bold,     "ncurses_a_bold");
   pragma Import (C, A_Dim,      "ncurses_a_dim");
   pragma Import (C, A_Reverse,  "ncurses_a_reverse");
   pragma Import (C, Color_Pair, "ncurses_color_pair");

   --  ── Initialisation ────────────────────────────────────────────────────

   --  Initialise ncurses (calls initscr, raw, noecho, keypad, nodelay,
   --  start_color, use_default_colors, curs_set(0)).
   --  Returns the stdscr WINDOW handle.
   function Init return Window;
   pragma Import (C, Init, "ncurses_init");

   --  Shut down ncurses cleanly (restores terminal, shows cursor).
   procedure Endwin;
   pragma Import (C, Endwin, "ncurses_end");

   --  Suspend ncurses before running an external program; restores the
   --  terminal to normal cooked mode.
   procedure Suspend;
   pragma Import (C, Suspend, "ncurses_suspend");

   --  Resume ncurses after returning from an external program.
   procedure Resume;
   pragma Import (C, Resume, "ncurses_resume");

   --  ── Colour ────────────────────────────────────────────────────────────

   --  Define a colour pair.  Pair 0 is always white-on-black in ncurses.
   procedure Init_Pair
     (Pair       : Interfaces.C.short;
      Foreground : Interfaces.C.short;
      Background : Interfaces.C.short);
   pragma Import (C, Init_Pair, "init_pair");

   --  ── Terminal dimensions ───────────────────────────────────────────────

   --  Current number of rows (may change after KEY_RESIZE).
   function Lines return Integer;
   pragma Import (C, Lines, "ncurses_lines");

   --  Current number of columns (may change after KEY_RESIZE).
   function Cols return Integer;
   pragma Import (C, Cols, "ncurses_cols");

   --  ── Window creation and destruction ───────────────────────────────────

   --  Create a new window of Nlines × Ncols starting at (Begin_Y, Begin_X).
   function Newwin
     (Nlines  : Integer;
      Ncols   : Integer;
      Begin_Y : Integer;
      Begin_X : Integer) return Window;
   pragma Import (C, Newwin, "newwin");

   --  Create an off-screen pad with Nlines rows and Ncols columns.
   --  Use Pnoutrefresh to display a viewport of the pad on-screen.
   function Newpad (Nlines : Integer; Ncols : Integer) return Window;
   pragma Import (C, Newpad, "newpad");

   --  Delete a window or pad created with Newwin / Newpad.
   procedure Delwin (Win : Window);
   pragma Import (C, Delwin, "delwin");

   --  ── Cursor movement ───────────────────────────────────────────────────

   procedure Wmove (Win : Window; Y : Integer; X : Integer);
   pragma Import (C, Wmove, "wmove");

   --  ── Output ────────────────────────────────────────────────────────────

   --  Erase all characters in Win (fills with background character).
   procedure Werase (Win : Window);
   pragma Import (C, Werase, "werase");

   --  Erase from the current cursor position to the end of the line.
   procedure Wclrtoeol (Win : Window);
   pragma Import (C, Wclrtoeol, "wclrtoeol");

   --  Erase from the current cursor position to the end of the window.
   procedure Wclrtobot (Win : Window);
   pragma Import (C, Wclrtobot, "wclrtobot");

   --  Write an Ada String (UTF-8, length-delimited) to Win at the cursor.
   --  This is the primary output routine; delegates to ncurses_waddnstr.
   procedure Waddnstr
     (Win  : Window;
      Text : String;
      N    : Integer);
   pragma Import (C, Waddnstr, "ncurses_waddnstr");

   --  Write an Ada String (UTF-8, full length) to Win at the cursor.
   procedure Waddstr (Win : Window; Text : String);

   --  Write a single character to Win at the cursor.
   procedure Waddch (Win : Window; Ch : Character);

   --  Set the background character and attributes for Win.  All blank
   --  (space) cells in the window render with Attrs applied.
   procedure Wbkgd (Win : Window; Attrs : Integer);
   pragma Import (C, Wbkgd, "ncurses_wbkgd");

   --  ── Attributes ────────────────────────────────────────────────────────

   --  Turn on (add) attributes in Win.
   procedure Wattron (Win : Window; Attrs : Integer);
   pragma Import (C, Wattron, "wattron");

   --  Turn off (remove) attributes in Win.
   procedure Wattroff (Win : Window; Attrs : Integer);
   pragma Import (C, Wattroff, "wattroff");

   --  Set the current attributes of Win to exactly Attrs
   --  (replaces all current attributes; A_Normal resets completely).
   procedure Wattrset (Win : Window; Attrs : Integer);
   pragma Import (C, Wattrset, "ncurses_wattrset");

   --  Set cursor visibility: 0 = invisible, 1 = normal, 2 = very visible.
   procedure Curs_Set (Visibility : Integer);
   pragma Import (C, Curs_Set, "curs_set");

   --  ── Refresh ───────────────────────────────────────────────────────────

   --  Copy Win to the physical screen immediately (full round-trip).
   procedure Wrefresh (Win : Window);
   pragma Import (C, Wrefresh, "wrefresh");

   --  Stage Win's changes into the virtual screen (deferred).
   procedure Wnoutrefresh (Win : Window);
   pragma Import (C, Wnoutrefresh, "wnoutrefresh");

   --  Flush all staged virtual-screen changes to the physical terminal
   --  (differential update — only changed cells are written).
   procedure Doupdate;
   pragma Import (C, Doupdate, "doupdate");

   --  Stage a viewport of Pad into the physical screen region
   --  [Sminrow..Smaxrow, Smincol..Smaxcol], reading pad content
   --  starting at (Pminrow, Pmincol).
   procedure Pnoutrefresh
     (Pad     : Window;
      Pminrow : Integer;
      Pmincol : Integer;
      Sminrow : Integer;
      Smincol : Integer;
      Smaxrow : Integer;
      Smaxcol : Integer);
   pragma Import (C, Pnoutrefresh, "pnoutrefresh");

   --  ── Input ─────────────────────────────────────────────────────────────

   --  Read one character or key code from Win.
   --  With nodelay enabled (set by Init) returns -1 immediately when no
   --  input is available.  Printable Unicode code points are returned as
   --  positive integers ≤ 16#10FFFF#.  Special keys (arrows, page-up/dn,
   --  resize, etc.) are returned as KEY_* values (≥ 256); compare against
   --  the Key_* function results above.
   function Wget_Wch (Win : Window) return Integer;
   pragma Import (C, Wget_Wch, "ncurses_wget_wch");

   --  ── Unicode column width ──────────────────────────────────────────────

   --  Display column width of Unicode code point CP.
   --  Returns -1 for non-printable, 0 for combining, 1 or 2 for normal.
   function Wcwidth (CP : Natural) return Integer;
   pragma Import (C, Wcwidth, "ncurses_wcwidth");

private

   type Window is new System.Address;
   Null_Window : constant Window := Window (System.Null_Address);

end Coyote_Ncurses;
