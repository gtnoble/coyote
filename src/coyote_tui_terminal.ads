--  Coyote_TUI_Terminal — residual Ada bindings to the C terminal helpers.
--
--  termios, raw-mode, TIOCGWINSZ, and wcwidth are now managed by ncurses
--  (see Coyote_Ncurses).  This package retains only the three utilities
--  that ncurses does not provide:
--
--    Is_TTY       — stdout TTY detection, used at startup before ncurses init
--    Make_Tempfile — create /tmp/coyote-XXXXXX for pager / editor flows
--    Close_FD      — close an fd returned by Make_Tempfile
--
--  Thread safety: none required; all three subprograms are reentrant C calls.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Interfaces.C;
use Interfaces.C;

package Coyote_TUI_Terminal is

   --  ── Temporary-file buffer ─────────────────────────────────────────────

   TMP_PATH_CAP : constant := 32;   --  > len("/tmp/coyote-XXXXXX\0") = 19

   subtype Tmp_Path_Buf is
     Interfaces.C.char_array (0 .. TMP_PATH_CAP - 1);

   --  ── Unicode column width ──────────────────────────────────────────────

   --  Display column width of a single Unicode code point.
   --  Returns -1 for non-printable, 0 for combining, 1 or 2 for normal.
   function Wcwidth (CP : Natural) return Integer;

   --  Display column width of a UTF-8 encoded string.
   --  Decodes each multi-byte sequence and sums Wcwidth across code points.
   function Utf8_Display_Width (S : String) return Natural;

   --  ── TTY detection ─────────────────────────────────────────────────────

   --  Return True when stdout is connected to a terminal.
   --  Used at startup to select the TUI vs plain-text frontend, before
   --  ncurses is initialised.
   function Is_TTY return Boolean;

   --  ── Temporary file creation ───────────────────────────────────────────

   --  Create /tmp/coyote-XXXXXX and return the open file descriptor.
   --  On success Path is filled with the NUL-terminated path and FD >= 0.
   --  On failure FD = -1 and Path is undefined.
   --  The caller must close(2) the descriptor and unlink the path when done.
   procedure Make_Tempfile
     (Path : out Tmp_Path_Buf;
      FD   : out Integer);

   --  ── File descriptor close ─────────────────────────────────────────────

   --  Close a file descriptor returned by Make_Tempfile.
   procedure Close_FD (FD : Integer);

end Coyote_TUI_Terminal;
