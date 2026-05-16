/*  coyote_tui_terminal.c — residual low-level helpers for the TUI frontend.
 *
 *  termios, raw-mode, TIOCGWINSZ, and wcwidth are now owned by ncurses
 *  (coyote_ncurses_c.c / libncursesw).  Only three utilities remain here:
 *
 *    tui_stdout_isatty — TTY detection (used by frontend selection at startup)
 *    tui_make_tempfile  — create /tmp/coyote-XXXXXX (pager / editor flows)
 *    tui_close_fd       — close an fd returned by tui_make_tempfile
 *
 *  Project: coyote
 */

#define _XOPEN_SOURCE 700
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <wchar.h>
#include <locale.h>

/* ── Unicode column width ─────────────────────────────────────────────────── */

static void ensure_locale(void) {
    static int done = 0;
    if (!done) { setlocale(LC_ALL, ""); done = 1; }
}

int tui_wcwidth(unsigned int cp)
{
    ensure_locale();
    return wcwidth((wchar_t)cp);
}

/* ── TTY detection ────────────────────────────────────────────────────────── */

int tui_stdout_isatty(void)
{
    return isatty(STDOUT_FILENO) ? 1 : 0;
}

/* ── File descriptor close ────────────────────────────────────────────────── */

void tui_close_fd(int fd)
{
    (void)close(fd);
}

/* ── Tempfile creation ────────────────────────────────────────────────────── */

/*  Fills path_out with "/tmp/coyote-XXXXXX", calls mkstemp, returns fd.
 *  path_out must be at least path_cap bytes (>= 19 for template + NUL). */
#define TUI_TMPL      "/tmp/coyote-XXXXXX"
#define TUI_TMPL_LEN  18

int tui_make_tempfile(char *path_out, int path_cap)
{
    if (path_out == NULL || path_cap <= TUI_TMPL_LEN)
        return -1;
    memcpy(path_out, TUI_TMPL, TUI_TMPL_LEN + 1);
    return mkstemp(path_out);
}
