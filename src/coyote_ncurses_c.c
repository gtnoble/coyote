/*  coyote_ncurses_c.c — C glue for ncurses macros, globals, and thin
 *  wrappers used by Coyote_Ncurses (Ada thin binding).
 *
 *  We include ncursesw so that wide-character / Unicode output works
 *  correctly.  Link with -lncursesw.
 *
 *  Project: coyote
 */

#define _XOPEN_SOURCE 700
#include <locale.h>
#include <ncursesw/ncurses.h>
#include <string.h>
#include <wchar.h>

/* ── Initialisation ───────────────────────────────────────────────────────── */

/*  Initialise ncurses and return the stdscr WINDOW pointer.
 *  Also sets locale, enables colour, hides cursor, enables keypad on
 *  stdscr, and activates halfdelay(1) so that wget_wch times out after
 *  0.1 s when no key is pressed.                                        */
WINDOW *ncurses_init(void)
{
    setlocale(LC_ALL, "");
    WINDOW *scr = initscr();
    start_color();
    use_default_colors();
    raw();
    noecho();
    keypad(scr, TRUE);
    nodelay(scr, TRUE);   /* non-blocking input */
    curs_set(0);
    return scr;
}

/*  Tear down ncurses cleanly.                                           */
void ncurses_end(void)
{
    curs_set(1);
    endwin();
}

/*  Suspend ncurses before running an external program (pager / editor).
 *  Restores the terminal to cooked mode.                                */
void ncurses_suspend(void)
{
    curs_set(1);
    endwin();
}

/*  Resume ncurses after returning from an external program.             */
void ncurses_resume(void)
{
    refresh();
    curs_set(0);
}

/* ── Attribute helpers (macros in C → functions for Ada) ─────────────────── */

/*  Wrap wattrset so it is accessible as a plain function.  */
void ncurses_wattrset(WINDOW *win, int attrs)
{
    wattrset(win, attrs);
}

int ncurses_a_normal(void)  { return (int)A_NORMAL;  }
int ncurses_a_bold(void)    { return (int)A_BOLD;    }
int ncurses_a_dim(void)     { return (int)A_DIM;     }
int ncurses_a_reverse(void) { return (int)A_REVERSE; }

int ncurses_color_pair(int n) { return (int)COLOR_PAIR(n); }

/* ── Terminal dimensions ──────────────────────────────────────────────────── */

int ncurses_lines(void) { return LINES; }
int ncurses_cols(void)  { return COLS;  }

/* ── Window background ────────────────────────────────────────────────────── */

/*  Set window background character and attribute (wraps wbkgd macro).  */
void ncurses_wbkgd(WINDOW *win, int attrs)
{
    wbkgd(win, (chtype)(' ' | (chtype)attrs));
}

/* ── Input ────────────────────────────────────────────────────────────────── */

/*  Non-blocking wide-character read from win.
 *  Returns the wint_t value (a Unicode code point or KEY_* constant) on
 *  success, or -1 when no input is available (ERR).                    */
int ncurses_wget_wch(WINDOW *win)
{
    wint_t ch = 0;
    int ret = wget_wch(win, &ch);
    if (ret == ERR)
        return -1;
    return (int)ch;
}

/* ── Waddstr wrapper that takes explicit length ───────────────────────────── */

/*  waddnstr with an Ada String (not NUL-terminated).                   */
void ncurses_waddnstr(WINDOW *win, const char *s, int n)
{
    waddnstr(win, s, n);
}


/* ── Unicode column width ─────────────────────────────────────────────────── */

/*  Display column width of Unicode code point cp.
 *  Returns -1 for non-printable, 0 for combining, 1 or 2 for normal.  */
int ncurses_wcwidth(unsigned int cp)
{
    return wcwidth((wchar_t)cp);
}

/* ── KEY constant accessors (values vary across ncurses builds) ───────────── */

int ncurses_key_up(void)        { return KEY_UP;        }
int ncurses_key_down(void)      { return KEY_DOWN;      }
int ncurses_key_ppage(void)     { return KEY_PPAGE;     }
int ncurses_key_npage(void)     { return KEY_NPAGE;     }
int ncurses_key_backspace(void) { return KEY_BACKSPACE; }
int ncurses_key_resize(void)    { return KEY_RESIZE;    }
int ncurses_key_enter(void)     { return KEY_ENTER;     }
