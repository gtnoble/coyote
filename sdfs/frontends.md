# Component Development Log — Frontends

**Components:** `Coyote_App`, `Coyote_App.Dispatch`, `Coyote_App.History`,
`Coyote_App.Utils`, `Coyote_App.Frontend`, `Coyote_App.Frontend.Acme_Win`,
`Coyote_App.Frontend.GUI`, `Coyote_App.Frontend.Plain`,
`Coyote_GUI.*`, `Coyote_Cmark`, `Acme.*`, `Nine_P.*`

**Source files:** `src/coyote_app*.ads/.adb`, `src/coyote_gui/*`,
`src/coyote_cmark*.ads/.adb`, `src/coyote_cmark_c.c`,
`src/acme*.ads/.adb`, `src/nine_p*.ads/.adb`

---

## Design Rationale

### Why three frontends share one `Dispatch_Event` function

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
so the GUI can create a `GtkTextChildAnchor` widget at `Begin_Tool` time and
update it when `End_Tool` arrives. A simpler "emit text" interface would
require the GUI to buffer the tool frame content and insert it retrospectively,
which is harder to implement and harder to animate.

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
GTK thread. The 8192-item bound prevents unbounded memory use if the GTK
thread falls behind. The idle callback is registered once at frontend creation
and fires as long as the queue is non-empty.

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

### Markdown re-render on `End_Text_Block`

Streaming markdown tokens are inserted as raw plain text. When `End_Text_Block`
fires, the raw text is deleted from the `GtkTextBuffer` and reinserted as Pango
markup. This approach has one drawback: a very long assistant response causes
a visible "flicker" as the plain text is replaced. The alternative (incremental
markup application) was considered but rejected because libcmark-gfm does not
have a streaming mode — it requires the full document to produce a correct AST.
The flicker is acceptable given the typical response length (< 50 KB).

### `Coyote_Cmark` C shim for enum resolution

libcmark-gfm exposes `cmark_node_type`, `cmark_list_type`, and
`cmark_event_type` as C enum values. These are resolved once at Ada package
elaboration time by calling the C shim getter functions
(`cmark_shim_node_paragraph()`, etc.) and storing the results in integer
variables. All comparisons in `Coyote_GUI.Buffer` use these stored integers.
This means the Ada code is correct regardless of which installed version of
libcmark-gfm is used — it never assumes a specific numeric value.

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
- `Begin_Tool` — blank line before tool-call frame widgets
- `Append_Notice` — blank line before notice text

**Tool-call detail button (2026-07-30):** Replaced the inline `GtkExpander`
in tool-call frames with a `GtkButton` labelled "details..." that opens a
non-modal `GtkWindow` displaying the tool arguments and result in read-only
monospace text views.  The button's widget name is set to the `Tool_Id`
string via `Gtk.Widget.Set_Name`, and the click handler (`On_Tool_Detail_Clicked`)
looks up the entry in the `Tools` map by widget name.  This eliminates the
inline-detail expander pattern and reduces visual clutter in the conversation
view — the frame now shows only the summary label and the button.  Removed
the `Collapse_All_Tools` / `Expand_All_Tools` API and the corresponding View
menu items, as they only made sense with the expander-based design.

**Tool-call frame styling (prior):** Tool frames now have a 6 px border
(`Set_Border_Width`), etched-in shadow (`Shadow_Etched_In`), and the inner
`Outer_Vbox` spacing increased from 2 → 6 px.  Pack_Start padding on the
summary label and expander increased from 2 → 6 px.

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

**Conversation view margins** increased from 8/6 px to 16/12 px
(left/right 8→16, top/bottom 6→12) in `Coyote_App.Frontend.GUI.Create`.

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

- `Coyote_GUI.Buffer`: partially covered; the AUnit suite can create a
  `GtkTextBuffer` without a display (headless GTK); Pango markup generation
  is tested in isolation.
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
