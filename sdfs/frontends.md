# Component Development Log — Frontends

## Current baseline amendment (2026-08-30)

The Acme frontend and Nine_P subsystem were removed from the supported
product, along with Acme-only plumbing, `coyote_open`, and their tests. The
current frontends are GTK and Plain. Historical rationale and PCR entries
below are retained as historical records; they no longer describe active
components.

**Components:** `Coyote_App`, `Coyote_App.Dispatch`, `Coyote_App.History`,
`Coyote_App.Utils`, `Coyote_App.Frontend`, `Coyote_App.Frontend.GUI`,
`Coyote_App.Frontend.Plain`, `Coyote_GUI.*`, `Coyote_GUI.Conversation`,
`Coyote_Renderer.*`, and `Coyote_Cmark`

**Source files:** `src/coyote_app*.ads/.adb`, `src/coyote_gui/*`,
`src/coyote_help.ads/.adb`, `share/help/C/coyote/*.page`,
`share/applications/coyote.desktop`, and
`share/icons/hicolor/scalable/apps/coyote.svg`,
`src/coyote_cmark*.ads/.adb`, `src/coyote_cmark_c.c`,
`src/coyote_lasem*.ads/.adb`, `src/coyote_lasem_c.c`,
`src/coyote_renderer/*.ads/.adb`
---

## Design Rationale

### GTK IRIX alignment slice (2026-08-23)

The GTK main menu now follows the implemented desktop order `File`, `Edit`,
`View`, `Agent`, `Options`, `Help`; Preferences is under Options and Help is
rightmost. Edit provides Cut, Copy, Paste, Select All, and Deselect All. The main window and transient support/dialog windows use
application-identifying titles without lifecycle status, and lifecycle state
remains in the status area. The Help menu launches Yelp topics for Overview,
task help, Index, and Keys & Shortcuts. Product Information is an in-process
dialog. Click for Help arms contextual help. Pause uses Ctrl+Shift+P so the
reserved Ctrl+P accelerator remains available for Print. Help task entries
omit mnemonics; standard Help entries have mnemonics and F1 / Shift+F1.

The implementation does not claim complete IRIX conformance. F1 and Help →
Click for Help arm a question-mark pointer for the whole main window. The
next left click in a menu, prompt, control, transcript, status, or
conversation area is consumed before activation and opens area-specific help.
The GUI publishes the themed `coyote` icon identity and queues a distinct
`coyote-session-<UUID>` window role for each active session. Native desktop
session-manager command serialization remains unavailable through the GTK3
API used by this build. Conversation selection publishes plain text through
PRIMARY independently of CLIPBOARD, and a prompt middle click inserts PRIMARY
at the pointer without highlighting the result.

On the available X11 host, live checks verified the session-specific window
role, F1 Overview, transient support-window parenting, Shift+F1 contextual
help, and Escape cancellation. The light-theme warning and footer colors are
selected for measured contrast of 5.98:1 and 5.74:1 against white; the
corresponding dark-theme values are 9.96:1 and 4.57:1. The desktop entry
passes `desktop-file-validate`. AT-SPI inspection is blocked because the host
has accessibility disabled, and native session-manager restoration remains a
platform-specific follow-up.

The contextual-help mapping was verified independently for all six supported
areas. Contextual requests now map to stable Mallard topic IDs and launch the
corresponding `help:coyote/<topic>` URI in Yelp. The Help menu also exposes the
Mallard guide root, task topics, Index, keyboard shortcuts, and product
information. `Coyote_Help` locates Yelp on `PATH`, launches it detached, and
converts launch failure into a visible frontend error notice. Mallard pages
are validated with `yelp-check validate` and `yelp-check links`.

### GTK IRIX usability increment (2026-08-23)

Added an Edit menu (Cut/Copy/Paste/Select All/Deselect All) with
focus-aware prompt vs conversation behaviour. File, Agent, View, and
standard Help mnemonics are unique within each menu. Overview and Keys
open Yelp; Product Information uses `Coyote_Help.Product_Information_Text`.
Agent Stop/Pause/Resume follow `Coyote_GUI.Stop_Available` /
`Pause_Available` / `Resume_Available`. Support and tool-detail windows
close on Ctrl+W.

### Yelp/Mallard Help integration (2026-08-23)

The GTK Help menu now launches the external Yelp viewer for the Mallard
application guide. `Coyote_Help` owns URI construction, contextual area
mapping, executable detection, and detached launch. Documentation is installed
under `share/help/C/coyote/`, with `index.page` as the root and task/topic
pages for overview, prompts, sessions, controls, shortcuts, product
information, and each main-window area. Yelp is a required GUI runtime
dependency; `yelp-tools` and `itstool` are contributor-time validation and
translation dependencies. Because Yelp owns its window, Help windows are not
GTK transient children of the coyote window.

### Help data-path correction (2026-08-29)

The initial implementation shipped Mallard pages in the repository but did not
make them discoverable by Yelp from the built checkout or installed binary.
`Coyote_Help.Open` now derives `$BASE/share` from the running `bin/coyote`
path, prepends it to `XDG_DATA_DIRS` when `share/help/C/coyote` exists, launches
Yelp, and restores the coyote process environment. The existing GPR `Install`
artifact declaration installs the complete `share/` tree; use `alr install` to
install under Alire's default prefix. The new Help data-directory regression
covers standard and non-standard executable layouts.

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

### Why GUI and Plain share one `Dispatch_Event` function

### GUI Preferences implementation (2026-08-06)

The GTK Preferences dialog is implemented as an `Options → Preferences...`
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

`Coyote_App.Dispatch.Dispatch_Event` is the single current function that maps
`LLM.Events.Agent_Event'Class` values to `Frontend'Class` primitives. All
the current GUI and Plain execution paths use the same dispatcher. The
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

### Retired 9P connection-per-task rule (historical)

Historical note: each former Acme task accessed the 9P VFS through its own `Nine_P.Client.Fs`
connection (`Ns_Mount ("acme")` or `Ns_Mount ("plumb")`). The rule is enforced
by the type system: `Fs` is `limited` and cannot be shared or copied. This
avoids cross-task I/O interleaving, which would corrupt 9P message framing.

### Retired Acme addr→data write pair serialisation (historical)

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
and trims leading/trailing whitespace. The GUI and Plain frontends apply the
same pattern: buffer during accumulation, collapse and emit once on `End_Thinking`.

**Rationale:** Display layer owns rendering semantics. Providers remain
wire-format-neutral. Buffering occurs in the frontend, not the provider or
dispatch layer, keeping concerns isolated.

**Test coverage:** The current frontend and application tests exercise thinking
delta dispatch and buffer-management semantics. The former dedicated dispatch
fixture was removed with PCR-090.

### PCR-044 session sandbox synchronization (2026-08-04)

The GUI agent task keeps sandbox state synchronized at the frontend boundary; the Plain runner applies the same rules synchronously.
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
active `App_State.Current_Sandbox` profile. The GUI local status-label
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
- The obsolete `Coyote_GUI.Buffer` package was removed; `Coyote_Renderer.Markup` is the maintained shared converter.

### Native Markdown response rendering (2026-08-27)

The native `Coyote_GUI.Conversation_Stack` now retains each streamed assistant
response block and replaces the temporary plain text at `End_Text_Block` with
GFM-to-Pango markup from `Coyote_Renderer.Markup`. The Render Markdown toggle
and zoom route to whichever GUI renderer is selected. Native GTK selection
continues to expose visible plain text, while the accessibility transcript
remains unchanged. This increment covers basic Markdown conversion only;
user acceptance of DEM-046 confirmed the native Markdown content and
interaction behavior on 2026-08-28. User acceptance of DEM-047 confirmed
live/replay native Markdown parity on 2026-08-28. Native display MathML and
large-history qualification remain open under DEM-048 and DEM-044. The
legacy GtkLayout renderer and Plain frontend retain their existing semantics.

Renderer parity for this increment is defined by supported content and
interaction, not pixel-identical layout:

| Capability | GtkLayout | Native stack | Plain | SQC replay |
|---|---|---|---|---|
| GFM Markdown response content | Implemented | Implemented | Plain text | Implemented |
| Markdown toggle | Implemented | Implemented | N/A | N/A |
| Display MathML | Implemented | Implemented (automated; DEM-048 manual qualification open) | Plain text | Separate |
| Live/replay native hierarchy | Legacy model | Accepted (DEM-047) | N/A | Replay model |
| Large-history qualification | Baseline | Pending | N/A | Separate |

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

### GUI top-level region separation (2026-08-30)

The native GTK main window now makes the three primary regions explicit. The
conversation scroller remains the sole expanding work area. A horizontal
`Gtk.Separator` separates it from a prompt control box with four pixels of
internal border spacing; a second separator divides that control area from a
four-pixel padded status box containing the lifecycle label. This follows the
IRIX work-area/control-area/status-area grouping without adding nested scrolling
or changing prompt and status behavior. The structural regression
`Coyote.GUI separates conversation, prompt, and status` verifies the widget
order and configured borders. Display-backed human review remains required to
confirm the separators have sufficient contrast under the active GTK theme.

### GUI visual spacing and layout

The initial GUI conversation view felt cramped — content blocks ran into
each other with no vertical rhythm.  The following changes were applied to
create visual separation between distinct content regions:

**Turn separators:** `Append_Turn_Footer` had been a no-op in the GUI
frontend (the retired Acme frontend rendered a turn footer with fork tokens, which
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

### Menu keyboard accelerators (2026-08-22, REQ-CORE-132)

Every actionable item in the main GTK menu bar now has a visible accelerator
through the window's `Gtk_Accel_Group`: Ctrl+N (New Window), Ctrl+Shift+N
(New Session), Ctrl+O (Open Session), Ctrl+Q (Exit), Ctrl+, (Preferences),
Escape (Stop), Ctrl+Shift+P (Pause), Ctrl+R (Resume), Ctrl+M (Change Model),
Ctrl+1 through Ctrl+6 (Thinking Level: Off through X-High), Ctrl+Shift+S
(Sandbox Profile), Ctrl+Shift+C (Compact Context), Ctrl+Shift+I (Session
Stats), Ctrl+Shift+D (Set Defaults), Ctrl+Shift+M (Render Markdown),
Ctrl+Shift+A (Auto-scroll), and Ctrl++/Ctrl+-/Ctrl+0 (Zoom In/Out/Reset).
All entries use `Accel_Visible`, so GTK renders the shortcut labels beside
the menu items.  The separate conversation context-menu Copy item and
Preferences dialog combo-box choices are intentionally outside this
main-menu requirement.

The zoom shortcuts remain proper GTK accelerators rather than raw window
key handling; the top-level key-press callback remains a no-op.

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
smooth-scroll (touchpad) deltas are accumulated in persistent frontend
state until they reach one wheel notch (±1.0).  Ctrl+wheel events are
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
| File | Exit | Ctrl+Q |
| Agent | Stop | Escape |
| Agent | Pause | Ctrl+Shift+P |
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
- `Read_Prompt` is owned by the active GUI or Plain frontend and uses the
  typed prompt queue or standard input; no external frontend event task or
  9P file handle is part of the current architecture.
- GTK widget operations remain confined to the GTK main task; the Plain
  frontend remains synchronous and headless.

---

## Unit Test Coverage Notes

- `Coyote_GUI.Conversation`: covered by AUnit tests for tool metadata
  preservation, interleaved tool selection, streaming, layout, and rendering.
- `Coyote_GUI.Tool_Detail_Window`: compiled and linked into the main GUI.
  The modeless transient support window now uses the IRIX functional title,
  selectable render-time metadata, a vertically scrollable content area,
  visible Close and Help actions, deterministic focus, theme-neutral status
  emphasis, and image-result decoding with an explicit fallback.  Live and
  replayed tool cards carry model, source directory, session timestamp,
  turn/call position, result media type, and cancelled-on-missing-result
  semantics.  The abstract frontend uses defaulted metadata parameters so
  Plain output remains line-oriented. Focused and full automated tests
  pass; display-backed visual, keyboard, theme, and image qualification remain
  manual DEM-041.
- `Coyote_Lasem`: covered by five AUnit tests for MathML fraction and matrix
  measurement, zoom scaling, relation entities, and invalid MathML error
  handling.  `Coyote_Renderer.MathML` adds headless extraction tests protecting
  fenced and indented code, preserving source, and preserving unmatched
  delimiters.  `Coyote_GUI.Conversation` has four display-backed tests for
  style selection, source preservation, visual height, and font propagation.
  `Coyote_GUI.Conversation_Stack` has four display-backed tests for native
  realization, invalid fallback, code protection, and zoom propagation.
- `Coyote_Cmark`: covered by AUnit tests — parse round-trips for each GFM
  node type; extension handling; null-safety of `cmark_shim_get_literal`.
- `Coyote_Help`: covered by display-independent AUnit tests for root/topic URI
  construction, contextual-area mapping, and Yelp executable detection.
  Mallard syntax and cross-page links are checked with `yelp-check`.
- Acme/Nine_P integration tests were removed with PCR-090; no active coverage remains.

---

## Open Questions / Future Work

### Historical PCR-021 — Acme session-loading frontend selection (2026-06-07)

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
- Native-stack qualification remains the principal frontend work: complete
  DEM-042 through DEM-044 and DEM-048, then remove the GtkLayout fallback if
  the acceptance gates pass.

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

### Keyboard-driven GUI and accessibility (2026-08-23)

The GTK conversation canvas now implements vi-style viewport navigation:
`j`/`k` move by one body line, `Ctrl+D`/`Ctrl+U` move by one page, and
`g`/`Shift+g` move to the top/bottom. Home, End, Page Up, and Page Down are
also supported. The pure `Coyote_GUI.Navigation` package clamps movement to
the adjustment bounds and is unit tested.

Custom tool cards and fork action strips participate in keyboard traversal.
Tab and Shift+Tab select an interactive item; Enter, keypad Enter, or Space
activates it. Escape clears a selection only when one exists; otherwise it is
left for the global Stop accelerator.

The prompt queue now reports whether an enqueue was accepted. Prompt text is
cleared only after acceptance, and full-queue rejection leaves the text intact
and emits a visible notice. GUI stats and conversation clearing are marshalled
through the GTK update queue. The session reference used by Stop is protected.

The GUI exposes explicit Send and Clear Conversation actions and renames the
model action to Models, with visible accelerators. Send and Stop buttons have
text labels as well as icons. Normal windows focus the prompt on startup;
Open Session, Sandbox Profile, Preferences, and model dialogs establish
initial keyboard focus explicitly.

Native GTK conversation components expose selectable text, labels, and
focusable actions through GTK accessibility. The legacy canvas retains its
local selection and keyboard interaction behavior. The canvas selects a dark
background and light primary text when GTK requests a dark theme. Display-backed
AT-SPI qualification and full color-contrast measurement remain manual work.

Automated coverage added three navigation-policy tests, two prompt-queue
acceptance/overflow tests, and conversation focus-cycle tests.

### Live Session Stats support window (2026-08-23, REQ-CORE-113d)

The GTK `Agent → Session Stats` action now owns one reusable modeless support
window, titled `coyote : Session Stats` and transient for the main window.
`Coyote_GUI.Session_Stats_Window` renders selectable read-only values in
Session, Last Turn, and Session Totals frames, uses the GTK desktop font
family and size, places the report in a vertical scrolled area, and provides
both a visible Close button and Ctrl+W.  Repeated activations present the
same window instead of creating duplicate snapshots.

The agent-to-GTK update record carries a typed `Session_Stats_Record`; the
GTK idle callback updates the visible labels in place.  `Clear_Stats` is a
separate update kind used after new-session and session-switch resets, so an
old session's report cannot remain visible.  Ordinary Clear Conversation
leaves session statistics unchanged.

The support-window package retains the latest typed snapshot even before its
first display, and clears that snapshot with the report.  Snapshot retention,
clear behavior, and idempotent construction are covered by three AUnit tests;
the construction test is display-backed and the other two are display
independent.

### Visible per-step frame amendment (2026-08-25)

The native stack now distinguishes the exchange container from the assistant/tool
steps inside it. The submitted request remains an exchange-level native text
component. The first assistant thinking, response, or tool operation lazily
creates a titled visible `Gtk.Frame` with an inner vertical `Gtk.Box`. Thinking,
assistant response blocks, nested tool-card frames, and the corresponding step or
final footer and fork action are packed into that step box. The frame closes after
the footer's fork action; subsequent assistant/tool content creates a new step
frame. `Complete_Request` closes the enclosing exchange and preserves the partial
step on abort or error.

This is implemented privately by `Coyote_GUI.Conversation_Stack` using
`Step_Frame`, `Step_Box`, `Step_Frames`, `Step_Open`, and `Footer_Pending`. Replay
now emits step footer/fork boundaries for persisted assistant messages with
`stopReason` `toolUse`, so replay can construct the same step hierarchy as live
rendering. The native stack remains selected by `COYOTE_NATIVE_STACK=1`; the
GtkLayout renderer remains the fallback pending display-backed and performance
qualification.

### Native component-stack conversation migration (2026-08-24, PCR-073 tool-summary amendment)

The approved target for the next GUI build is a native component stack rather
than the current single `Gtk.Layout` canvas. One `Exchange_View` represents one
submitted request and its complete agent response, bounded by the final turn
footer. Each exchange is a vertical GTK container stacked in one outer
vertical `Gtk.Scrolled_Window`/`Gtk.Box` host.

The exchange contains separate graphic elements for the user request,
thinking blocks, assistant response blocks, tool calls, step and final footers,
fork actions, notices, and display math. Text-bearing elements use native
read-only `Gtk.Text_View`/`Gtk.Text_Buffer` widgets with local selection where
applicable. Native tool cards use a titled `Gtk.Frame` containing native labels and a
`Gtk.Grid` of top-level argument fields
showing the tool name, individually selectable top-level argument-field labels, and
textual running or terminal status. They do not show raw
argument JSON, full results, or image result content. Each completed card has a
focusable `View Details` pushbutton that opens the existing `coyote : Tool Call Details`
window. Math remains a localized Lasem-backed child widget or cached image with
readable source/fallback content.

The current `Coyote_GUI.Conversation` GtkLayout/Cairo/Pango renderer remains
the implementation baseline until native-stack qualification completes. Its
existing Markdown, UTF-8, thinking, tool-ID, and MathML logic remains the
legacy adapter; basic native Markdown now uses `Coyote_Renderer.Markup`. The
`Coyote_Renderer.Markup` provides the shared GFM-to-Pango conversion used by
both the native conversation stack and GTK session replay.

An exchange remains open across multiple assistant/tool steps. Intermediate
step footers remain inside the exchange; only the final turn footer completes
it. Tool cards are updated by `Tool_Id`, so starts-before-completions and
multiple tool steps do not depend on visual order. Abort and error termination
preserve partial content and mark the exchange terminal without inventing a
normal completion footer.

Selection is intentionally local to one semantic component. The GUI does not
require a range spanning assistant text, thinking, tools, footers, or exchanges.
Copy, Select All, and PRIMARY operate on the focused or most recently selected
text component; CLIPBOARD and PRIMARY remain independent. This removes the
previous global selection/hit-testing model as a migration requirement.

The presentation interface must gain an explicit request-start operation, an
explicit distinction between step and final footers, and an exchange-completion
state. Prompt echoes must not be overloaded as generic notices for determining
exchange boundaries. Live and replayed sessions must construct equivalent
hierarchies. All widget mutation remains on the GTK main task through the
existing `Coyote_GUI.Updates` queue.

The initial realization strategy is one native GTK hierarchy per exchange in a
vertical `Gtk.Box`; no component creates a nested scrolling region for ordinary
content. Text and thinking deltas update existing widgets rather than creating
widgets per token. If large histories make full realization unacceptable,
qualification may select lazy realization or retain the current renderer as a
large-history fallback.

The revised implementation is now present in
`Coyote_GUI.Conversation_Stack`. It realizes one outer vertical scrolled window,
one exchange container per request, native selectable text views for request,
thinking, and response content, native focusable fork controls, structured native
tool-card labels, retained `Tool_Info` payloads, and `View Details` buttons that are
enabled after completion. Completed responses with standalone display math are
realized as ordered native text views and Lasem-backed
`Coyote_GUI.Math_Element` widgets; invalid expressions retain selectable source
fallback. The cmark-backed `Coyote_Renderer.MathML` extractor protects code-block
ranges before masking display math. The stack is selected only when
`COYOTE_NATIVE_STACK=1`; the existing `Coyote_GUI.Conversation` renderer remains
the default baseline and fallback until display-backed qualification completes.
The four native MathML tests and parser-safety regressions are registered.
Production and test development builds succeed; the complete development suite
passes 806/806 with zero failed assertions and zero unexpected errors. Manual
visual/local-selection and large-history qualification remain open under DEM-048
and DEM-044. DEM-047 live/replay Markdown parity was accepted by the user on
2026-08-28.
The separately named `Exchange_View`, `Text_Element`, `Tool_Card`,
`Math_Element` is now implemented; the separately named `Exchange_View`, `Text_Element`, `Tool_Card`, and `Footer_Element` units remain deferred because this slice
keeps their ownership private to `Conversation_Stack` while preserving the
required semantic boundaries. Native footers now use a GTK separator, a
non-selectable summary label, and a right-aligned action row with a stable
`Fork` pushbutton. The button captures UUID/turn/step data and invokes the
registered GUI fork handler; normal completion does not add a duplicate
standalone status widget. The typed summary travels separately from the
formatted text through the GUI update queue, so native rendering does not parse
frontend display text. Plain output and the legacy Cairo renderer are
unchanged. Required qualification still covers 100, 500, and 2,000 exchanges;
streaming first-token latency; widget count and memory; resize and zoom;
auto-scroll; local selection and PRIMARY; tool-card activation;
clear/session-switch callback invalidation; replay/live parity; and keyboard
focus traversal. No production default switch has been made.

### Responsive native tool-card flow (2026-08-30, PCR-089)

Native tool cards in `Coyote_GUI.Conversation_Stack` are now grouped per
assistant/tool step in a non-homogeneous horizontal `Gtk.Flow_Box`. The flow
uses four-pixel row and column spacing and inserts cards in event order, so
multiple natural-width cards can share a row and automatically wrap when the
available step width changes. The flow is created lazily on the first tool card
of a step and is discarded with the active step; footers and fork actions remain
below it in the vertical step box. Stable `Tool_Id` updates, retained details,
callbacks, replay parity, and the single outer scroller are unchanged.

Added the `Coyote.GUI.Conversation_Stack uses responsive tool flow` regression,
which verifies the flow host, variable-width configuration, spacing, child
count, and insertion order. Production/test development builds and the full
941-test suite pass. Display-backed multi-column placement and narrow-window
reflow remain pending under DEM-043.

### GTK recursion-depth preference (2026-08-29)

The GTK Preferences dialog now exposes the persistent maximum subagent
recursion depth alongside model, thinking, sandbox, subagent-model, and
completion-notification defaults. The value is carried through the typed
`Set_Preferences` queue item and saved by the agent task as
`maxRecursionDepth`; enforcement remains in the executable entry point before
frontend and session startup. Queue and settings persistence regressions cover
non-default and zero values.

### GTK footer-summary propagation correction (2026-08-25)

The GUI frontend now preserves the typed footer summary in `Update.Text2` and
passes it to the native conversation stack. The legacy GtkLayout fallback now
renders the formatted footer payload as a styled footer line while retaining
its blank-line separator behavior for empty payloads. Added regressions cover
both the update-queue payload round trip and legacy summary visibility.

### Configurable skill directories in GTK Preferences (2026-08-29)

The GTK `Options → Preferences...` dialog now edits additional skill roots with
a single-selection scrollable list. `Add Directory...` opens a folder chooser;
`Remove Selected`, `Move Up`, and `Move Down` are explicit keyboard-accessible
actions. These four actions use GTK mnemonic buttons (`Alt+A`, `Alt+R`, `Alt+U`,
and `Alt+D`). The pending ordered vector travels through the typed
`Set_Preferences` queue item; the agent task persists it as `skillPaths` without
changing the active session. The dialog default size was increased to provide
room for the resizable directory list. Queue, settings, and skill-discovery
regressions cover the transport and persistence behavior; display-backed
interaction remains part of the Preferences qualification procedure DEM-033.
The main Send and Stop controls, support-window actions, and static SQC action
controls likewise expose context-appropriate GTK mnemonics. Repeated dynamic
tool-card buttons remain unmarked to avoid ambiguous mnemonic groups.

### GTK model-picker price display (2026-08-30, PCR-087)

The GTK Preferences dialog now persists `priceDisplay` as `"si"` or `"db"`.
The Change Model picker reads this preference when opened, formats positive
prices in dB from their true $/tok values (`10 × log10 (p / 1,000,000)` for
stored $/MTok `p`) when selected, and updates the column headers accordingly.
Zero-valued cells display `free`; negative values are blank. Raw prices remain
the sort keys because the logarithm is monotonic for positive values. SI
prefixes remain the default.

### GUI application shutdown correction (2026-08-30, PCR-088)

The GTK window-manager close and File → Exit callbacks now share the
`Request_Shutdown` operation. It requests agent cancellation through the
registered session reference, stops the process-control shutdown monitor,
wakes the prompt queue, and stops update producers. The callbacks then quit
GTK; window-manager close permits the normal GTK destruction handler instead
of suppressing it. This prevents `Run_GUI` from waiting indefinitely for its
nested monitor and agent tasks. A display-backed regression covers monitor
stop and release of a blocked prompt reader.

### Removal of the redundant accessibility transcript (2026-08-30)

The collapsed `Accessible transcript` expander and its plain-text mirror were
removed. Native GTK conversation widgets now provide the GUI accessibility
surface directly; the legacy canvas retains local selection and keyboard
interaction without maintaining a second transcript buffer. The dead
`Set_Transcript` update kind, renderer mirror accumulators, transcript-specific
contextual Help mapping, Mallard page, tests, and qualification wording were
removed. The native component stack's selectable text, labels, and focusable
actions remain unchanged.

### Native response rendering visibility correction (2026-08-30)

The native component-stack response replacement now removes the temporary raw
streaming `Gtk.Text_View` from its response section after the stream buffer and
mark have been finalized, before packing Markdown text and Lasem-backed math.
This prevents the raw response from being restored by later recursive
`Show_All` calls. Rendered response text remains the active selectable text
component when text surrounds display math.

Native MathML drawing areas and source-fallback labels are now excluded from
recursive `Show_All` operations and are explicitly shown or hidden according
to parse validity. Valid MathML therefore presents only the rendered formula;
invalid MathML continues to present selectable source fallback. Response text,
MathML roots, and drawing areas share the theme-aware
`coyote-response-content` GTK style class and use the GTK theme base/text
colors.

Display-backed regressions cover raw-stream removal, rendered-text selection,
valid and invalid MathML visibility after `Show_All`, and shared response
styling. Production and test development builds succeed; the complete suite
passes 806/806 with zero failed assertions and zero unexpected errors.
