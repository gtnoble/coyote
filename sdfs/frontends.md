# Component Development Log — Frontends

**Components:** `Coyote_App`, `Coyote_App.Dispatch`, `Coyote_App.History`,
`Coyote_App.Utils`, `Coyote_App.Frontend`, `Coyote_App.Frontend.Acme_Win`,
`Coyote_App.Frontend.GUI`, `Coyote_App.Frontend.Plain`,
`Coyote_GUI.*`, `Coyote_GUI.Conversation`, `Coyote_Cmark`, `Acme.*`, `Nine_P.*`

**Source files:** `src/coyote_app*.ads/.adb`, `src/coyote_gui/*`,
`src/coyote_cmark*.ads/.adb`, `src/coyote_cmark_c.c`,
`src/coyote_lasem*.ads/.adb`, `src/coyote_lasem_c.c`,
`src/acme*.ads/.adb`, `src/nine_p*.ads/.adb`

---

## Design Rationale

### GTK Change Model dialog filter (2026-08-22)

The Change Model dialog wraps the registry `GtkListStore` in
`GtkTreeModelFilter` + `GtkTreeModelSort` so column-header sort survives
filtering. A `GtkSearchEntry` drives `Refilter` via library-level callbacks
and package-level picker state (no `Unrestricted_Access`). Matching is a
case-insensitive substring of provider, display name, and hidden
`provider/id`, implemented as the display-free `Model_Row_Matches` helper.
The count label shows `N models` when unfiltered and `N matches` when a
query is active. Escape clears a non-empty query, then cancels the dialog.
Typeahead search is disabled so it does not fight the filter.

### Dedicated subagent model in GTK Preferences (2026-08-08)

The Preferences dialog now provides a separate subagent model selector with a
`Use default model` fallback. The selected provider/model is carried through
the typed `Set_Preferences` queue item and persisted by the agent task without
changing the active session. `--subagent` consumes the dedicated preference;
ordinary sessions continue using the ordinary default.

### GTK completion desktop notifications (2026-08-15)

The GTK Preferences dialog now persists `completionNotifications` in
`~/.coyote/settings.json`, defaulting to enabled when absent. The existing typed
`Set_Preferences` queue item carries the value; the agent task writes it
atomically and applies the successful change to the current GUI through the
agent-to-GTK update queue. Subagents and one-shot executions remain disabled by
an independent mode gate.

A non-aborted interactive GUI turn queues a completion update after the final
`Session_Stats_Event`. The GTK idle callback checks `Gtk.Window.Is_Active` and
calls the native `Coyote_Notify` libnotify binding only when the window is
inactive. Notification-daemon absence or delivery failure does not affect the
agent session.

### Why three frontends share one `Dispatch_Event` function

### GUI Preferences implementation (2026-08-06)

The GTK Preferences dialog is implemented as an `Edit → Preferences...`
workflow. It edits persistent model, thinking-level, and sandbox defaults on
the GTK main task, then sends a typed `Set_Preferences` payload through the
protected prompt queue to the agent task. The agent task owns settings-file
persistence and reports write success or failure through the frontend. Saving
defaults does not change the active session; the existing Agent menu controls
remain the runtime override path. New GUI sessions reload the persisted
preferences before agent creation.

Automated coverage includes the typed queue round-trip, settings persistence,
and agent sandbox-default precedence tests. Display-backed DEM-033 remains
pending because no GTK display is available in this environment.

`Coyote_App.Dispatch.Dispatch_Event` is the single function that maps
`LLM.Events.Agent_Event'Class` values to `Frontend'Class` primitives. All
three execution paths (Acme, GUI, Plain) use the same dispatcher. The
alternative — per-frontend dispatch functions — would duplicate the event
→ action logic and make adding a new event type a multi-file change.
The cost is that `Dispatch_Event` must use `App_State` for side effects
(e.g. accumulating statistics) that are not part of the frontend interface.

### `Frontend'Class` interface at structured-event granularity

See `sdfs/core-agent.md` §Design Rationale for the full motivation.
In the frontend context: the `Begin_Tool` / `End_Tool` distinction exists
so the GUI can insert a box-drawing text block at `Begin_Tool` time and
replace the placeholder footer in-place when `End_Tool` arrives.  A simpler
"emit text" interface would require the GUI to buffer the tool-call content
and insert it retrospectively, which is harder to implement.

### 9P connection-per-task rule

Each task that accesses the acme 9P VFS creates its own `Nine_P.Client.Fs`
connection (`Ns_Mount ("acme")` or `Ns_Mount ("plumb")`). The rule is enforced
by the type system: `Fs` is `limited` and cannot be shared or copied. This
avoids cross-task I/O interleaving, which would corrupt 9P message framing.

### Acme addr→data write pair serialisation

Writing text to an acme window body requires two sequential 9P writes:
(1) write to `/N/addr` to set the insertion point, (2) write to `/N/data`
to insert the text. If two tasks interleave these writes, the wrong task's
text is inserted at the wrong position. The `Addr_Mutex` protected object
inside `Acme.Window.Win` serialises the addr→data pair within one window
across the `Agent_Task` and `Acme_Event_Task`. Each task holds its own `Fs`
but shares the `Win` object (which contains the mutex).

### GTK event-loop separation via `Coyote_GUI.Updates`

The GTK event loop and the agent loop run in separate tasks. The
`Coyote_GUI.Updates` bounded queue (8192 items) decouples them: the agent
task enqueues update records; a GLib idle callback drains the queue on the
GTK thread. Enqueue applies backpressure when the queue is full rather than
dropping an update; shutdown closes the queue and releases blocked producers.
The idle callback is registered on demand when the update queue transitions
from empty to non-empty and fires until the queue is empty.

Each GUI text stream also owns a stateful UTF-8 decoder. It retains incomplete
multibyte suffixes across update records and emits U+FFFD only for malformed
bytes or an incomplete sequence at stream end. This applies independently to
assistant text and thinking output.

### Thinking-text buffering and collapsing (PCR-022)

SSE streaming from LLM providers delivers thinking tokens as short chunks with
leading/trailing newlines and internal line breaks. Naive per-chunk rendering
produced illegible fragmented output. The solution: each frontend buffers all
thinking deltas between `Begin_Thinking` and `End_Thinking` events, then
collapses them to flowing prose on flush.

**Implementation:** `Coyote_App.Utils.Collapse_Thinking_Delta` (pure function)
replaces single `\n`/`\r` with spaces, preserves `\n\n` as paragraph breaks,
and trims leading/trailing whitespace. Both Acme and GUI frontends apply the
same pattern: buffer during accumulation, collapse and emit once on `End_Thinking`.

**Rationale:** Display layer owns rendering semantics. Providers remain
wire-format-neutral. Buffering occurs in the frontend, not the provider or
dispatch layer, keeping concerns isolated and allowing different frontends to
apply different rendering strategies if needed (e.g., the plain frontend could
preserve more whitespace for line-by-line thinking output).

**Test coverage:** `Test_Dispatch_Thinking_Delta` in `test/src/dispatch_tests.adb`
emits both `Thinking_Delta` and `Thinking_End` events, verifying the collapsing
and buffer-management semantics.

### PCR-044 session sandbox synchronization (2026-08-04)

The Acme and GUI agent tasks keep sandbox state synchronized at the frontend
boundary. After agent creation, new-session creation, and session switching,
they copy `LLM.Agent.Current_Sandbox` into the frontend-local state and
`App_State`, then republish `COYOTE_SANDBOX_PROFILE` before bootstrap or the
next tool call. Session-info events query the agent directly, avoiding stale
frontend-local values. A resumed or switched session with no `sandboxProfile`
field therefore clears the displayed profile as well as the agent and child
process state.

**Test status:** The agent and session-store portions are covered by the PCR-044
AUnit regressions. End-to-end frontend and child-process behavior remains in
manual qualification demonstrations DEM-031 and DEM-032.

### PCR-046 GUI status sandbox display (2026-08-06)

The shared `Coyote_App.Dispatch.Format_Status` formatter now includes the
active `App_State.Current_Sandbox` profile. The Acme and GUI local status-label
helpers return only the lifecycle state, preventing duplicate profile suffixes
when explicit menu updates refresh the status. Added formatter and dispatch
regressions; the complete AUnit suite passes with 825 tests.


### Drawing_Area-based virtualized rendering (2026-07-31)

The conversation view was migrated from `GtkTextView`/`GtkTextBuffer` to a
`Gtk.Drawing_Area` with Cairo + Pango rendering (`Coyote_GUI.Conversation`).
The primary motivation was resize performance: `GtkTextView` reflows the entire
document on every width change, which becomes unusably slow with large
conversation buffers.  The Drawing_Area renders only visible lines, giving
acme-like O(visible) resize cost regardless of document size.

**Revision — GtkLayout for native GtkScrollable support (2026-07-31):**
The `Gtk.Drawing_Area` does not implement the `GtkScrollable` interface.
`GtkScrolledWindow` wraps a non-scrollable child in a `GtkViewport` that
translates the entire widget surface by `(-scroll_value)`.  The virtualized
renderer draws content at widget-relative offsets (0..viewport_height),
so content drawn at Y=0 ends up at viewport Y=scroll_value after the
viewport translation — scrolled entirely off-screen.  The fix: replace
`Gtk.Drawing_Area` with `Gtk.Layout`, which natively implements
`GtkScrollable`.  `GtkLayout` has a bin window that GTK repositions at
`(-scroll_x, -scroll_y)` rather than translating the whole widget, so the
`draw` callback's Cairo coordinates remain viewport-relative.  The
`Recompute_Vis_Lines` procedure now calls `Layout_W.Set_Size (Width,
Doc_Height)` to tell GTK the total scrollable extent; the adjustments are
shared automatically.  No document-sized surface allocation — the widget
stays viewport-sized.  Visual-line counts are cached per logical line, and
in-place streaming mutations invalidate the affected line so the canvas
height expands as wrapping changes.

**Trade-offs:**
- Markdown rendering is implemented via `Render_Markdown_Block` in
  `Coyote_GUI.Conversation`.  When enabled (default), `End_Text_Block`
  parses GFM through `Coyote_Cmark` and emits styled `Logical_Line`
  entries with block-level `Line_Style` values and inline Pango markup
  (`Has_Markup = True`).  Tables render as box-drawing ASCII art.
  Nested list markers receive two leading spaces for each level below the
  top-level list, and ordered lists preserve their declared starting ordinal.
  Selection copy strips markup tags for plain-text clipboard output.
- Selection, copy-to-clipboard, tool-click detail windows, action strips,
  thinking blocks, notices, and turn footers are all supported.
- The old `Coyote_GUI.Buffer` package is retained as dead code for reference.

### `Coyote_Lasem` binding

`Coyote_Lasem` wraps the locally installed Lasem 0.6 library through
`coyote_lasem_c.c`. The C shim converts Lasem `GError` values to allocated
messages and releases the document/view GObjects before returning. It parses
Presentation MathML with `lsm_dom_document_new_from_memory`; the primary GUI
renderer retains the original delimiter-wrapped source in the `Display_Math`
logical line for display and selection, while Lasem receives only the inner
MathML document. Inline math and the legacy shared Pango renderer remain
outside this increment. MathML element whitelisting is deferred until a
concrete compatibility problem is observed.
### `Coyote_Cmark` C shim for enum resolution

libcmark-gfm exposes `cmark_node_type`, `cmark_list_type`, and
`cmark_event_type` as C enum values. These are resolved once at Ada package
elaboration time by calling the C shim getter functions
(`cmark_shim_node_paragraph()`, etc.) and storing the results in integer
variables. All comparisons in `Coyote_GUI.Conversation` use these stored integers.
This means the Ada code is correct regardless of which installed version of
libcmark-gfm is used — it never assumes a specific numeric value.

### System font integration (2026-07-30)

The GUI frontend reads the system default proportional font from
`Gtk.Settings.Get_Default` (`gtk-font-name`) at startup
(`Init_System_Font`).  The conversation view, prompt `GtkTextView`, and
status bar all use this family and size as their baseline (zoom level 0).
Zoom adjusts ±1 pt from the system baseline.  `Coyote_GUI.Conversation.Set_Font`
propagates the effective font description to both reusable Pango layouts and
invalidates wrapping and line-height caches.  Display math is remeasured and
rendered through the Lasem resolution scale at the same factor.  The SQC
tool-detail window
reads the same GTK setting lazily (`Ensure_System_Font_Init`) and applies
the point size to its monospace `GtkTextView` widgets while using the
generic `"monospace"` family name, which Pango resolves to the users
configured monospace font.

### GUI visual spacing and layout

The initial GUI conversation view felt cramped — content blocks ran into
each other with no vertical rhythm.  The following changes were applied to
create visual separation between distinct content regions:

**Turn separators:** `Append_Turn_Footer` had been a no-op in the GUI
frontend (the Acme frontend rendered a turn footer with fork tokens, which
are not meaningful in a GTK window).  It now inserts a dim horizontal rule
(60 × `UC_HORIZ` in the `footer` tag, grey `#888888`) with blank lines
above and below, giving each turn a clear visual boundary.

**Inter-block breathing room:** Blank lines (`LF LF`) are now emitted at
every content-section transition:
- `End_Text_Block` — blank line after assistant text
- `End_Thinking` — blank line after thinking blocks
- `Begin_Tool` — blank line before tool-call text block
- `Append_Notice` — blank line before notice text

**Tool-call box-drawing text blocks (2026-07-30; revised 2026-08-04):**
The live conversation renderer originally used plain box-drawing text blocks.
This remains the text content for selection and copying, but the visual layer
now draws graphical cards around those rows.

**Graphical tool cards (2026-08-05):**
The live `Coyote_GUI.Conversation` renderer now assigns typed styles to tool
header, argument, and footer rows.  Cairo draws rounded card backgrounds,
borders, left status accents, and status-specific fills: blue while running,
green on success, red on error, and grey on cancellation.  Tool completion
propagates status through all rows, while the existing compact text remains
available for selection and copying.  Pointer motion highlights completed
cards; clicking a completed card continues to open the structured non-modal
detail window.  The implementation preserves the flat virtualized line model
and the interleaved completion map; no GTK child widgets are added to the live
conversation view.


**Markdown rendering improvements** (in `Coyote_Renderer.Markup`):
- *Headings* sized by level: `<span size="larger">` for h1–2,
  `<span size="medium">` for h3–4, plain bold for h5–6; each preceded by
  `LF` and followed by `LF LF`.
- *Paragraphs* now separated by `LF LF` (blank line) instead of `LF`.
- *Code blocks* wrapped in `<span background="#f4f4f4"><tt>…</tt></span>`
  with a leading `LF` for visual distinction.
- *Blockquotes* prefixed with `UC_BOX_V` (`╎`) and rendered with a single
  `<span alpha="50%" font_style="italic">` instead of nested tags; opened
  with `LF` and closed with `LF LF`.

---
**Conversation view margins** increased from 8/6 px to 16/12 px
(left/right 8→16, top/bottom 6→12) in `Coyote_App.Frontend.GUI.Create`.

### Menu keyboard accelerators (2026-07-30)

All frequently used menu items now carry GTK `Gtk_Accel_Group` accelerator
shortcuts with `Accel_Visible` so labels render in menu text.  The accel
group is created in `Coyote_App.Frontend.GUI.Create` and attached to the
main `GtkWindow`.  Nine menu items that previously used a shared `Item`
local variable were promoted to dedicated named variables so each could
hold its own `Add_Accelerator` call.

The zoom shortcuts (Ctrl++/Ctrl+-/Ctrl+0) were previously implemented as a
raw `On_Window_Key_Press` event handler on the top-level window, which
shadowed the menu items without showing labels.  They are now proper
accelerators; the key-press handler is reduced to a no-op.

### Ctrl+mouse-wheel zoom (2026-08-15, REQ-CORE-125)

Ctrl+wheel over the conversation view now zooms.  The conversation
`GtkLayout` event mask gains `Gdk.Event.Scroll_Mask`, and the frontend
connects `On_Conv_Scroll` to the layout's `scroll-event` signal.  With
Ctrl held, wheel up/down steps the zoom level and calls `Apply_Zoom`;
smooth-scroll (touchpad) deltas are accumulated in a handler-local
`Gdouble` until they reach one wheel notch (±1.0).  Ctrl+wheel events are
always consumed (`return True`) so the viewport never scrolls mid-zoom;
plain wheel events return `False` and fall through to the scrolled
window.

Zoom arithmetic is factored into the new pure-logic package
`Coyote_GUI.Zoom` (`Zoom_Step_Pt`, `Min_Size_Pt`/`Max_Size_Pt`,
`Effective_Size_Pt`, `Clamped_Base_Pt`, `Step_Zoom`).  `Step_Zoom`
advances the level by the requested number of steps, then walks back out
of the clamp plateau so the level never grows unboundedly behind a pinned
font size (this also makes zoom-out immediately responsive after a large
zoom-in).  It reports `Changed := False` when the effective size did not
move, letting callers skip the expensive `Apply_Zoom` redraw at the
bounds.  All three menu handlers and the wheel handler share this policy;
`Apply_Zoom` itself is unchanged apart from delegating size computation
to `Coyote_GUI.Zoom`.

The package is display-independent and unit-tested by
`coyote_gui_zoom_tests.adb` (12 tests, no GTK display required).

**Shortcut assignments:**

| Menu | Item | Shortcut |
|---|---|---|
| File | New Window | Ctrl+N |
| File | New Session | Ctrl+Shift+N |
| File | Open Session… | Ctrl+O |
| File | Quit | Ctrl+Q |
| Agent | Stop | Escape |
| Agent | Pause | Ctrl+P |
| Agent | Resume | Ctrl+R |
| Agent | Change Model… | Ctrl+M |
| Agent | Compact Context | Ctrl+Shift+C |
| View | Zoom In | Ctrl++ |
| View | Zoom Out | Ctrl+- |
| View | Reset Zoom | Ctrl+0 |

The `Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask` expressions for
Ctrl+Shift+C and Ctrl+Shift+N require a `use type Gdk.Types.Gdk_Modifier_Type`
clause at the package-body level because the `or` operator on the modular
type is not directly visible.  (Previously a local `use type` block was used
for Ctrl+Shift+C alone; it was promoted to file scope when Ctrl+Shift+N was
added.)

### Auto-scroll toggle (2026-07-30)

The conversation view includes an explicit `View → Auto-scroll` check menu
item, enabled by default.  When checked, the viewport automatically snaps to
the bottom whenever new content arrives (driven by the
`GtkAdjustment::changed` signal).  When unchecked, the viewport stays
wherever the user has scrolled — there is no automatic detection or override
of user-initiated scrolling.

This toggle replaces the earlier "follow mode" implementation, which used a
`Programmatic_Scroll_Count : Natural` counter with `::value-changed`
auto-detection to distinguish user from programmatic scroll events, along
with a "↓ New output" scroll-to-bottom button.  That design had inherent
complexity from the counter guard (needed to work around GTK's
delete-then-reinsert double-signal pattern in `End_Text_Block`) and did not
let the user explicitly control the behaviour.
---

## Key Constraints

- All GTK widget operations must execute on the main Ada task (the GTK main
  loop task). Ada tasks other than the main task must not call any GTK function
  directly; they communicate via `Coyote_GUI.Updates`.
- `Read_Prompt` in the Acme frontend blocks until the `Acme_Event_Task`
  signals a prompt via `App_State`. It must not hold any 9P file handle open
  while blocking.
- The `Addr_Mutex` in `Acme.Window.Win` must be released promptly; no blocking
  operations (9P reads, waits) inside the critical section.

---

## Unit Test Coverage Notes

- `Coyote_GUI.Conversation`: covered by AUnit tests for tool metadata
  preservation, interleaved tool selection, streaming, layout, and rendering.
- `Coyote_GUI.Tool_Detail_Window`: compiled and linked into the main GUI;
  argument views use bounded content-aware minimum heights, empty raw
  arguments omit the text view, and the result view is the sole expanding text
  widget. Display-backed visual qualification remains manual.
- `Coyote_Lasem`: covered by five AUnit tests for MathML fraction and matrix
  measurement, zoom scaling, relation entities, and invalid MathML error
  handling.  `Coyote_GUI.Conversation` has four display-backed tests for style
  selection, source preservation, visual height, and font propagation.
- `Coyote_Cmark`: covered by AUnit tests — parse round-trips for each GFM
  node type; extension handling; null-safety of `cmark_shim_get_literal`.
- `Acme.*` / `Nine_P.*`: covered by integration tests in
  `test/src/acme_integration_tests.adb` and `nine_p_integration_tests.adb`
  (require a live acme instance; opt-in).

---

## Open Questions / Future Work

### PCR-021 — Acme session-loading frontend selection (2026-06-07)

**Problem:**  Button-3 on a `coyote-session+UUID` token in the acme Sessions
window spawned `coyote --session UUID` via the plumber, which inherited
`$DISPLAY` but not `$winid`, so the child process selected the GUI frontend
instead of opening a new acme window.

**Fix:**  Two complementary mechanisms:
1. `--frontend acme|gui|plain` CLI flag that overrides all automatic
   detection.  The plumb rule for session tokens now uses `--frontend acme`.
2. `COYOTE_FRONTEND=acme` environment-variable propagation when the Acme
   frontend is selected (symmetric with `COYOTE_FRONTEND=gui` for GUI).


- The GUI frontend currently uses a `GtkTextView` for the prompt input area.
  A multi-line `GtkSourceView` with syntax highlighting would improve the
  editing experience for long prompts, but adds a dependency on `gtksourceview`.
- The Acme frontend's tag-line button set is rebuilt on each `Set_Mode` call
  by overwriting the entire tag line. A diff-and-patch approach would reduce
  9P write traffic for high-frequency mode changes.

### Variable-height block layout (2026-08-15)

`Coyote_GUI.Conversation` no longer places every logical line on a uniform
`Line_Height_Px` grid.  Each `Logical_Line` caches a real `Pixel_Height`
from Pango (`Get_Pixel_Size`) or Lasem.  Document height is the sum of
those heights; `On_Draw` and `Hit_Test` walk pixel boxes rather than
`visual_line_index × Line_Height_Px`.  Headings wrap their already-escaped
inline markup in a bold / sized `<span>` so they measure and draw taller
than body text.  Display math keeps its Lasem measurement instead of being
rounded up to the next body-line multiple.  Wrapped-line selection uses
`Index_To_Pos` rectangles for the start and end glyphs rather than a
single `Line_Height_Px` slab.

`Line_Height_Px` remains the body-text metric (fallback for empty blocks,
zoom baseline, and `Vis_Count` denominator for tests).  The public
streaming API is unchanged.

### PCR-058 — Tool-detail argument sizing (2026-08-15)

The GTK tool-call detail window previously assigned fixed 76 px or 110 px
minimum heights to every argument text view. The implementation now estimates
height from explicit and conservatively estimated wrapped lines, clamps it to
30–120 px, suppresses empty raw argument views, and makes the result view the
expanding child. Display-backed qualification remains manual.

### PCR-057 — Upward drag-select invisible (2026-08-15)

**Problem:** Click-drag downward highlighted text, but an upward or
leftward drag painted nothing.  `On_Draw` and clipboard extraction treated
`Sel_Start_*` as the earlier endpoint, while motion only updated
`Sel_End_*`.  Button-release swapped the pair but never queued a redraw.

**Fix:** `Ordered_Selection` returns the stored endpoints in document
order.  Highlight drawing and clipboard extraction use that ordered pair
during the drag.  Button-release writes the ordered pair back and calls
`Queue_Draw`.
