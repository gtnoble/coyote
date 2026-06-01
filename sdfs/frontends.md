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

- The GUI frontend currently uses a `GtkTextView` for the prompt input area.
  A multi-line `GtkSourceView` with syntax highlighting would improve the
  editing experience for long prompts, but adds a dependency on `gtksourceview`.
- The Acme frontend's tag-line button set is rebuilt on each `Set_Mode` call
  by overwriting the entire tag line. A diff-and-patch approach would reduce
  9P write traffic for high-frequency mode changes.
