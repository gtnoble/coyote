# Component Development Log — Frontends

## 2026-10-22 — Scope libcmark ownership and string boundary (PCR-118)

Production Markdown consumers now use scope-owned `Coyote_Cmark.Document` and
`Coyote_Cmark.Iterator` values. Finalization handles normal scope exit,
early-return, and exception paths; accessors return copied Ada strings, with
null values normalized to empty strings. Legacy low-level manual entry points
remain public for binding tests and are not access-restricted; production
renderer paths use scoped owners. Borrowed nodes and iterators depend on the
document lifetime: finalize iterators first and do not `Parse` a replacement
while an iterator still borrows the document. Ada does not statically enforce
this relationship. PCR-117's dated cmark deferral is superseded for the
current baseline.

Verification: The root and test development builds passed with both generated
profiles set to development. The full suite passed 1014/1014, zero errors, in
78.70 seconds wall. Focused cmark passed 17/17 (three added PCR-118 tests),
renderer passed 10/10, and native ownership instrumentation passed 27
assertions. No general Ada/native allocation-failure injection, live-provider
qualification, or end-user visual acceptance was performed. Developer
self-evaluation/read-only review is not independent user acceptance.

## 2026-10-22 — Synchronous detached exec-status contract (PCR-119)

The Ada Boolean status reflects setup and status-pipe completion, not eventual
application exit. An errno payload reports setup/exec errors. EOF with the
intermediate child reaped means no error was reported and normally indicates
successful exec, but unexpected pre-exec grandchild death is indistinguishable.
Linux `pipe2(O_CLOEXEC)` and C/POSIX-only post-fork mechanics remain; no Ada
runtime calls occur after fork. The post-fork `execvp` behavior retains a
Linux/glibc assumption and is not claimed portable or async-signal-safe.
Both final normal and ASan/UBSan logs report 28 dynamically counted native
detached-spawn checks passed. The intermediate unused-counter strict-build
failure was corrected before both runs.
## 2026-10-22 — Move selected frontend native-boundary policy into Ada (PCR-117)

This approved behavior-preserving refactor moves libnotify initialization,
notification creation/show/error cleanup, object release, and finalization into
`Coyote_Notify` using private Ada imports. The obsolete
`src/coyote_notify_c.c` implementation is removed. The isolated worker
`test/tools/notify_test_worker.adb` exercises repeated show/finalize calls; its
registered lifecycle smoke test runs it with a timeout and an unavailable
D-Bus address. The isolated lifecycle test passed 1/1; this verifies lifecycle
cleanup under an unavailable bus, not successful daemon delivery.

`Coyote_Cmark` now calls libcmark string accessors directly and normalizes null
results to an Ada-owned empty C string. Non-null accessor values remain borrowed
libcmark pointers, not copies; their lifetime is bounded by the owning node or
document. `coyote_cmark_c.c` retains enum constants, GFM parser construction,
and scalar table metadata only. The focused cmark suite passed 14/14,
including the existing null-string regression (whose registered name says
"shim" although it exercises the Ada accessor contract).

Root `alr build --development` and test `cd test && alr build --development
--profiles=coyote=development` passed, each with `Build_Profile=development`.
The full Xvfb suite passed 1005/1005 with zero errors in 74.98 seconds wall
(exit 0). Help passed 12/12 core and 1/1 display-backed GUI; Mallard validation,
link, and CLI checks passed. Existing GTK theme CSS warnings appeared in the
GUI check. `git diff --check` passed. The source reduction is seven to six C
files and 761 to 575 physical lines (186 fewer, approximately 24%). The final run includes all parser assertions and live-process
readiness changes. Physical GUI qualification remains pending; developer
self-evaluation/read-only review is not human acceptance.
## 2026-10-22 — Refactor local image loading into Ada (PCR-116)

PCR-116 implementation and automated verification are complete; image behavior
is preserved. The synchronous Ada `Coyote_Image_Loader` owns URI parsing, root
containment, secure traversal, encoded limits, PNG/JPEG signature and dimension
checks, and thumbnail scaling. Typed private decoder handles bind opaque Gdk
worker results to GTK-main-task adoption. Typed Ada POSIX I/O is isolated from
the minimal 74-line C interoperability shim (macros/stat, EINTR, signal hookup,
and GError access only; no loader policy or scheduler).

`Coyote_Image_Jobs` uses 32 fixed protected slots and two Ada workers. A GLib
main-loop pump performs lazy submission and termination; no worker accesses
widgets. `Coyote_GUI.Rich_Text` consumes typed interfaces and has no raw C
callback. PNG/JPEG-only support and visible alt-text fallback are preserved;
SVG, remote fetching, Plain/SQC image widgets, and table-cell image widgets
remain unsupported. The former 460-line C loader was removed. Loader tests
pass 8/8, jobs tests 3/3, and native shim checks pass 15/15 in normal and
ASan/UBSan modes. The complete suite passes 1001/1001 under Xvfb with zero
errors in 70.87 seconds (exit 0); Help, CLI/Mallard, and headless help checks
also pass. DEM-060 desktop visual and interaction qualification remains
pending.

## 2026-10-22 — Implement session-contained assistant Markdown images (PCR-114; historical C implementation)

Completed assistant Markdown blocks in GTK now resolve local raster images
against the active session source directory. The persisted session header's
`workDir` is read through `LLM.Session_Store.Session_Work_Dir`; live dispatch,
history replay, and coordinator RPC carry that source context. Ordinary Clear
clears conversation widgets but preserves the source root; session replay sets
the root from its session header (including an empty value when absent), and
`Reset_Agents` remains the distinct accepted-session reset operation.

The sole loader implementation is `src/coyote_gui/coyote_image_loader.c`.
It uses two workers, a 32-job cap, an 8 MiB file limit, 8192-pixel dimension
limits, a 16-million-pixel limit, 640×600 no-upscale thumbnails, and at most
16 inserted images per response. PNG and JPEG are supported; GIF, WebP, SVG,
remote images, table-cell image widgets, and image loading without a source root
are not supported. Alt captions remain visible/selectable/searchable beside the
inline anchored image; when linked, the caption remains clickable. There is no
full-size viewer or resize reflow. No remote assets are fetched or persisted.

Verification: production and test development builds pass; the full Xvfb suite
passes 990/990 on the final repeat (66.37 s wall, exit 0). Focused renderer
tests pass 10/10 and `Conversation_Stack` 38/38. Additional assertions verify
UTF-8 anchor positions, images around native tables/math, a shared 16-image
budget across split text segments, and source-root preservation after Clear. Renderer, GUI, and RPC additions contribute eight AUnit tests (three,
three, and two respectively); history coverage was extended. The native C
loader check, `test/tools/check-image-loader.sh`, passes all 20 checks in both
normal and AddressSanitizer/UndefinedBehaviorSanitizer modes with zero failures.
Help coverage passes 12/12 core and 1/1 display-backed widget tests; Mallard
validation/link and CLI checks pass. DEM-060 remains pending for human desktop
qualification of allocation, fonts, scrolling, links, and clipboard behavior.
Developer self-review and a separate read-only worker review are not independent
acceptance.

## 2026-10-06 — Search conversation text

Added Edit → Find (Ctrl+F) with an inline query row, case-insensitive match
highlighting, Next/Previous navigation with wraparound, match counts, and
Escape/Close dismissal with prior-focus restoration. Search covers request
text, assistant text, and thinking text in native GTK text buffers, including
active streaming content. Highlighting uses a dedicated buffer tag and does not
replace the conversation's selection or clipboard state. Native table/math
widgets and tool-card content are not searched.

Conversation-stack coverage exercises matching across request, thinking, and
streaming response text, navigation, refresh during streaming, and clearing.
Focused stack suite passed 32/32. A full-suite run with a 90-second timeout
reached the pre-existing display-backed GUI window tests and timed out at
Sandbox Profiles manager coverage; focused search coverage passed independently.

## 2026-10-06 — Show image tool-result thumbnails in conversation cards

The native conversation stack now decodes image tool results and displays a
bounded thumbnail in the completed tool card. The thumbnail is scaled to fit
within 320×320 while preserving aspect ratio; invalid or oversized encoded
data displays a compact fallback without affecting tool completion. Image
payloads remain captured for the Details window and are omitted from inline
status text.

The implementation uses the existing GTK-thread tool completion path and
secure temporary-file helper. Conversation-stack regression coverage checks
valid image display, invalid image handling, payload retention, and status
redaction. Manual visual qualification remains useful for representative
large and animated images.

## 2026-09-26 — Preserve conversation step boundaries after tool cancellation

Cancelled tool batches ending a `toolUse` step now finalize the current GUI
step without rendering a normal footer or fork action. The following assistant
response therefore starts in a separate step frame. The boundary is exposed by
the frontend contract, marshalled through the GTK update queue and coordinator
RPC protocol, and is a no-op for line-oriented Plain output.

**Regression coverage:** Conversation_Stack verifies cancelled-step
finalization and continuation into a new frame; Agent_RPC verifies the new
`endStep` event round trip.

## Historical — 2026-09-15 — Complete CSM retirement and Markdown-only frontend baseline (PCR-105; math superseded by PCR-123)

The frontend no longer selects or presents CSM. The environment toggle, prompt
branch, response-format fields/events, persistence metadata writing, replay
selection, and deleted parser/semantic/presenter/streaming-owner units have no
operational path. Assistant output followed direct libcmark-gfm Markdown;
Conversation_Stack retained native GFM tables and Lasem-backed Presentation
MathML display blocks in that 2026-09-15 baseline. The math implementation and
qualification claims in this entry are superseded by the 2026-10-23 native Ada
math engine record below. Plain output remains line-oriented.

New assistant JSONL records have no `format` or `formatVersion` fields. Legacy
records containing those fields remain readable because the fields are ignored
and content is handled as Markdown. The prior CSM entries below are retained as
historical records and are superseded wherever they describe the current
frontend architecture.

**Historical verification (PCR-105, 2026-09-15):** The full suite passed
890/890 at that checkpoint. Focused frontend results included
Conversation_Stack 28/28 and GUI Updates 9/9; the retained Markdown, table,
MathML, Math_Element, selection, lifecycle, and reset paths were covered. New
native-stack regressions covered configured font inheritance for response views
and native table labels, plus focus-safe Clear. This historical count is
superseded by the current PCR-114 990/990 verification recorded above.

**Historical boundary:** Older CSM implementation and qualification entries
below are retained for factual chronology and are superseded by PCR-105; they
do not describe the current frontend baseline.

## Historical — 2026-09-14 — Final CSM-2 renderer migration audit and closure (PCR-104 Stage 9; superseded by PCR-105)

The staged migration is complete. Production CSM-2 presentation now consists of
`Coyote_Renderer.Incremental` semantic mutations and canonical
`Coyote_Renderer.Semantics`, owned per response by the
`Coyote_GUI.Streaming_Response` transaction and reconciled by the persistent
`Coyote_GUI.Semantic_Response_Presenter`. `Conversation_Stack` no longer owns a
live renderer or provisional-subtree replacement path. Normal finish performs
`Flush` and snapshot reconciliation directly; `Response_Renderer.Replace` is
not called by the streaming path.

Architecture decisions: semantic document state is authoritative; provider
delta boundaries are observational only; root identity is stable across
snapshots and local reconciliation; malformed source is conserved visibly;
native table/MathML promotion occurs at committed boundaries; GTK cleanup
runs on the GTK main task with presenter widgets cleared before the response
section is detached. The parser `Event`/`Event_Handler` facade is retained as
deprecated test-only compatibility because bounded parser qualification still
uses it and removing it would add parser-regression risk. `Live_Event` and
`Coyote_GUI.Live_Response_Renderer` are retired and absent from production.

Defects fixed during final audit: semantic handles now include document
identity (including copied nested references), response cleanup preserves GTK
ownership order, and response-section detachment prevents stale roots during
reuse. New tests cover cross-document handle rejection, semantic mutations,
root/range/lifecycle invariance, presenter reconciliation, response-owner
handles, identity, scaling, and reset stress.

**Verification:** Production/test development builds passed. The complete
registered suite passed 990/990 twice. Focused suites passed: semantic mutation 6/6; Semantics model 6/6; Stage 6 5/5;
presenter 4/4; streaming owner 18/18; CSM-2 GUI 16/16;
Conversation_Stack 25/25; Response_Renderer 3/3; and Zoom 12/12. Display tests
ran on X11 and emitted only existing GTK theme color-parser warnings.

## Historical — 2026-09-13 — CSM-2 localized live recovery enhancement (PCR-101 follow-on; superseded by PCR-105)

This historical entry records the superseded live-renderer implementation.
The completed implementation is documented in the PCR-104 Stage 9 closure entry above;
at that historical checkpoint, the production path used semantic mutations,
`Streaming_Response`, and the persistent `Semantic_Response_Presenter`.
The shared semantic path presents inline corruption as escaped, unstyled
`Raw_Markup`; tables, code, terminal MathML, and structural containers remain
atomic.

**Verification:** Production and test development builds succeeded. The
complete AUnit suite passed 955/955; CSM-2 focused qualification passed 49/49;
semantic qualification passed 5/5. Historical PCR-101 closure evidence and its
919/919 baseline remain unchanged below.

## Current baseline amendment (2026-08-31)

The native GTK conversation cutover is complete. The historical Phase 6 checkpoint was 934/934; the superseded pre-Stage-9 baseline was 955/955. The PCR-104 Stage 9 closure entry above is historical superseded evidence for the CSM-2 presentation record; it is not the current suite baseline. `Coyote_GUI.Conversation_Stack`
is the sole GTK conversation presentation; the custom `Gtk.Layout`/Cairo/Pango
renderer, its test accessors, and the `COYOTE_NATIVE_STACK` runtime flag were
removed after native qualification. The Plain frontend remains supported and
unchanged.

Historical implementation notes below that mention the retired renderer are
retained for chronology only and do not describe active source or behavior.

The Acme frontend and Nine_P subsystem were removed from the supported
product, along with Acme-only plumbing, `coyote_open`, and their tests. The
current frontends are GTK and Plain. Historical rationale and PCR entries
below are retained as historical records; they no longer describe active
components.

**Components:** `Coyote_App`, `Coyote_App.Dispatch`, `Coyote_App.History`,
`Coyote_App.Utils`, `Coyote_App.Frontend`, `Coyote_App.Frontend.GUI`,
`Coyote_App.Frontend.Plain`, `Coyote_GUI.*`,
`Coyote_GUI.Conversation_Stack`, `Coyote_Renderer.*`, and `Coyote_Cmark`

**Source files:** `src/coyote_app*.ads/.adb`, `src/coyote_gui/*`,
`src/coyote_help.ads/.adb`, `share/help/C/coyote/*.page`,
`share/applications/coyote.desktop`, and
`share/icons/hicolor/scalable/apps/coyote.svg`,
`src/coyote_cmark*.ads/.adb`, `src/coyote_cmark_c.c`,
`src/coyote_lasem*.ads/.adb`, `src/coyote_lasem_c.c`,
`src/coyote_renderer/*.ads/.adb`
---

## Historical — 2026-09-12 — Live CSM-2 event rendering and final reconciliation (superseded by PCR-105)

This historical implementation note describes the superseded `Live_Event`/
`Live_Response_Renderer` path. It is retained for chronology only; current
production uses semantic mutations, `Streaming_Response`, and the persistent
`Semantic_Response_Presenter` as recorded in the PCR-104 Stage 9 closure entry.

At `End_Text_Block`, `Conversation_Stack` calls parser `Flush`, finalizes the
live renderer, takes the typed `Snapshot`, removes the provisional subtree, and
replaces it authoritatively through `Coyote_GUI.Response_Renderer`. Native
tables/math are therefore created only at complete boundaries/final
reconciliation; malformed source remains visible, and invalid live events roll
back optimistic content. Clear, repeated finalization, format changes, and
session reset are idempotent and do not retain stale widgets.

**Verification:** Production and test development builds passed. The complete
historical development-suite checkpoint passed 934/934 with zero failed
assertions or unexpected errors. The CSM-2 parser/live/headless/GUI aggregate filter passed 32/32; the
CSM-2 GUI qualification passed 7/7, standalone live renderer 4/4,
`Conversation_Stack` 24/24, and `Coyote.GUI.Updates` 10/10. GUI qualification
ran on the available X11 display with existing GTK theme warnings only.
Provider, Plain, and RPC behavior was unchanged.

## Design Rationale

### Historical — CSM-2 Phase 10 consolidated GUI qualification (2026-09-12; superseded by PCR-105)

`Coyote_GUI_CSM2_Qualification_Tests` adds three display-gated AUnit tests for
paired CSM-2 versus semantically equivalent Markdown presentation. The fixture
checks normalized visible text and representative block order, native table
cells/geometry/alignment, terminal MathML validity and retained source,
introspectable response styles, selection/copy, deterministic response child
counts, split-delta reconciliation, and malformed completion without stale
native content. It emits an explicit `[SKIP display unavailable]` diagnostic and
returns only when neither `DISPLAY` nor `WAYLAND_DISPLAY` is available. The
checks use normalized snapshots and geometry properties, not pixel identity.

**Verification:** With the available display, the consolidated GUI qualification
passes 3/3. Existing GUI CSM-2 parity/reconciliation tests remain unchanged and
pass. GTK theme color warnings are environmental and do not affect assertions.

### Historical — CSM-2 Phase 9 version-aware persistence and replay compatibility (2026-09-12; superseded by PCR-105)

At this historical checkpoint, the response-format type distinguished
`Format_Coyote_Stream` (the then-current CSM-1 value) from
`Format_Coyote_Stream_2`. New live CSM selection in `Coyote_App` used CSM-2;
Markdown and Plain remained unchanged. Assistant JSONL
records retain the existing `format: "coyote-stream"` spelling for readability,
and CSM-2 records add integer `formatVersion: 2`. CSM-1 records remain
versionless, so old JSONL is readable without migration or reinterpretation.

Replay maps versionless `coyote-stream` to CSM-1, maps exactly version 2 to
CSM-2, and maps missing/unknown format or version metadata to Markdown. Since
the CSM-1 parser is no longer available, CSM-1 replay selects an isolated raw,
selectable source path; it is never passed to the CSM-2 parser or Markdown/cmark
table interpretation. The GUI and headless RPC response-format event carry
`formatVersion: 2` for CSM-2, while legacy events remain accepted. Replay
restores the configured live CSM-2 selection after mixed-format history.

**Verification:** Session-store tests cover CSM-2 version persistence,
versionless CSM-1 persistence, and unknown/missing fallback; history tests cover
mixed CSM-1/CSM-2/Markdown replay and live restoration; RPC tests cover the
versioned event payload. Production and test development builds pass.

### Historical — CSM-2 Phase 8 shared CSM GUI presentation (2026-09-12; superseded by PCR-105)

CSM-2 GUI responses now use `Coyote_Renderer.Incremental.Snapshot` and the
shared `Coyote_GUI.Response_Renderer` semantic backend. `Conversation_Stack`
retains exchange, step, stream, tool, and selection lifecycle; it no longer
constructs CSM-specific heading, quote, code, rule, table, or MathML widgets,
reparses explicit CSM tables as Markdown, or slices raw tag wrappers. Each
delta is processed synchronously. One provisional selectable source view is
kept for incomplete content; complete structural boundaries reconcile through
the shared renderer, and `End_Text_Block` flushes, snapshots, and authoritatively
reconciles malformed/incomplete source so no stale widgets remain. CSM table
rows/cells and alignment are consumed directly from typed semantics. Terminal
MathML is normalized to a complete `<math>` document for Lasem while original
CSM source is retained for fallback/copy.

Focused GUI parity, malformed fallback, parser, semantic, cmark, and selection
coverage pass; GTK theme warnings remain environmental.

### Historical — CSM-2 Phase 7 shared GUI response presentation (2026-09-12; superseded by Phase 8)

`Coyote_GUI.Response_Renderer` now owns shared completed-response semantic
presentation. It consumes `Coyote_Renderer.Semantics` and centralizes the
existing Markdown visual policy: Pango inline/block styles, headings, lists,
quotes, code, rules, response CSS/layout, native table grids, native MathML,
source-order packing, selectable response text, and font/zoom hooks.
`Conversation_Stack` remains responsible for exchange/step/tool lifecycle,
streaming state, selection routing, and the independent CSM parser lifecycle.
CSM snapshot presentation is migrated to this backend in Phase 8.

The completed Markdown path parses into the existing semantic document before
rendering. Native table cells and MathML are retained through the renderer's
non-owning inspection registries; heap-stable MathML elements are detached and
freed exactly once during stack clear. A presentation-only display-math
boundary fallback preserves the previous adjacent-prose Markdown behavior.

The focused GUI suite passes 25/25 after adding direct semantic response table
coverage; existing Cmark, MathML, and semantic Pango/model regressions remain
passing. Production and test development builds pass and `git diff --check` is
clean. GTK theme parsing warnings remain an environment/theme limitation.

### Historical — CSM-2 Phase 12 GUI closure evidence (PCR-101, 2026-09-12; superseded by PCR-105)

The independent CSM-2 GUI presentation is qualified through the shared
semantic-to-GTK/Pango response renderer and `Conversation_Stack` lifecycle.
Display-backed qualification passed 3/3 on `DISPLAY=:0.0` (X11; no Wayland
display), covering paired Markdown parity, normalized visible content and block
order, semantic styles, shared spacing, native table cells/alignment, terminal
MathML validity/source, selection/copy, deterministic child counts, split-delta
reconciliation, and malformed stale-widget recovery. The native
`Conversation_Stack` suite passed 24/24. GTK theme color-parser warnings were
environmental and did not affect assertions.

At that historical checkpoint, versionless CSM-1 replay was recorded as visible raw source because the CSM-1
parser is retired; it is not rendered as CSM-1 and is not reinterpreted as
Markdown. Pixel identity and clipboard retrieval are outside the contract.
Manual demonstrations assigned to other historical GUI procedures remain
pending and are not implied by this automated CSM-2 closure.

### Historical — Accepted incremental-markup decisions (2026-09-06; superseded by PCR-105)

`COYOTE_INCREMENTAL_MARKUP=1` is the opt-in flag for incremental markup.
When the flag is unset or set to `0`, the existing Markdown behavior is
preserved. `coyote`, not the model, owns format selection and the associated
metadata. When enabled, provider deltas are processed and rendered
immediately; this mode does not use timer batching.

The implemented CSM-2 path wires the independent bounded parser and shared
semantic response renderer into `Coyote_GUI.Conversation_Stack` when
`COYOTE_INCREMENTAL_MARKUP=1`. Each provider delta is processed synchronously;
complete semantic boundaries reconcile into native/selectable components,
while incomplete or malformed fragments remain visible source. CSM-2 tables
use typed explicit rows/cells, terminal Presentation MathML remains native, and
selection/copy follows the shared response policy. Markdown remains the default
path, and Plain remains unchanged. The selected response format also controls
model-facing prompt guidance: CSM-2 receives its restricted grammar
instructions, while Markdown and Plain retain the Markdown-only response
contract and do not receive the active CSM policy from auto-loaded repository
instructions. Versionless CSM-1 records remain replay compatibility input and
are shown as raw source because the CSM-1 parser is retired.

### Historical — CSM-1 focused incremental-markup implementation verification (2026-09-06)

The CSM-1 implementation is covered by focused parser, message-format,
persistence, legacy-fallback, environment-flag, and incremental
native-component lifecycle tests. The code-block test verifies literal
characters, delimiter removal, and prefix/code/suffix order; parser coverage
also verifies empty complete table, MathML, and code blocks. The complete
development suite passes 854/854 with zero failed assertions and zero
unexpected errors; the display-backed conversation-stack suite passes 26/26.
README documents the opt-in flag and restricted CSM scope.

### Historical — CSM-1 horizontal-rule extension verification (2026-09-07)

The display-backed suite now verifies split-boundary `<hr/>` and `<hr />`
recognition, native `GtkHSeparator` realization, and ordered
text-rule-text-rule-text components. The complete development suite had passed
856/856 with zero failed assertions and zero unexpected errors; the focused
parser suite had passed 14/14 and the display-backed conversation-stack suite
had passed 27/27 before the heading slice. Existing Markdown/default-off
behavior remains unchanged.

### Historical — CSM-1 heading extension verification (2026-09-07)

The display-backed suite verifies split h1/h4 headings, native selectable
heading labels, literal heading text, and text-heading-text-heading-text order.
The complete development suite passes 858/858 with zero failed assertions and
zero unexpected errors; the focused parser suite passes 15/15 and the
display-backed conversation-stack suite passes 28/28. Existing Markdown and
COYOTE_INCREMENTAL_MARKUP default-off behavior are unchanged.

### Historical — CSM-1 blockquote extension verification (2026-09-07)

The display-backed suite verifies split-boundary blockquote recognition, framed
selectable native text, literal-character preservation, and ordered
text-blockquote-text components. The complete development suite passes 862/862
with zero failed assertions and zero unexpected errors; the focused parser suite
passes 16/16 and the display-backed conversation-stack suite passes 29/29.
Existing Markdown and COYOTE_INCREMENTAL_MARKUP default-off behavior are
unchanged.

### Historical — CSM-1 replay-format compatibility verification (2026-09-07)

The GUI frontend now receives a per-assistant replay-format update through the
protected update queue. Persisted Coyote Stream messages use the incremental
stack, while legacy or missing-format messages use Markdown; the configured
live mode is restored after replay. The coordinator RPC frontend emits a
versioned `responseFormat` event so selected child-agent history retains the
same semantics. Focused replay and RPC codec tests pass; display-backed GUI
qualification remains subject to the available display.

### AUnit GUI fixture hierarchy and shutdown verification (2026-09-05)

GUI fixture packages now expose leaf AUnit `Suite` functions and are composed
under `Test_GUI_Suite`, preserving the existing display-name order. The
product-information fixture explicitly requests frontend shutdown before
 destroying its GTK windows, preventing the RPC service task from surviving
fixture scope. This dated fixture record is historical; the 919-test baseline recorded at that
point was qualified through PCR-101; it is not the current suite baseline.
display-backed GUI tests remain subject to the available display environment.

### Sandbox Profiles manager (2026-09-05, superseded)
The initial manager opened one reusable modeless co-primary window titled
`coyote : Sandbox Profiles` and established the separate quick chooser. Its
browse/edit interaction was superseded by the multi-profile draft editor
recorded below; backend path preservation and Use Profile routing remain
unchanged.

`Coyote_GUI.Sandbox_Profile_Window` is constructed on the GTK main task,
transient for the main window, and reused rather than recreated. The manager
lifecycle/name-validation tests pass; display-backed qualification of the full
manager interaction remains pending under DEM-054.

### Sandbox Profiles manager drafts (2026-09-06)
The manager now uses one always-visible editable form with a single-selection
profile list and multiple typed in-memory drafts. New and Duplicate Profile
stage changes without writing files; dirty drafts are marked in the list; Save
validates and processes all dirty drafts; Cancel reloads persisted profiles and
discards all drafts; Refresh preserves dirty drafts. Rename and Delete are not
provided by the manager. The four path-rule collections are presented in one
single-selection `GtkTreeView` backed by a three-column `GtkListStore`, with
visible Rule category and Path columns plus a hidden numeric rule key. Rows
remain grouped in category order and preserve path order. Add Path, Edit
Selected, and Remove Selected are consolidated into one bottom action row. Add
and Edit use arbitrary-text path dialogs; Add explicitly chooses the category,
preserving `~`, `.`, `./`, absolute, and missing paths. Backend compatibility
rename remains available for historical session support. Use Profile continues
to route through the selected agent's local queue or RPC channel. The focused
path-editor regression passes; full interaction remains display-gated under
DEM-054.

### Native GTK Markdown tables (2026-09-03)

Completed GFM response blocks containing tables now pass through the
GTK-independent `Coyote_Renderer.Tables` extractor. It copies table rows,
cell text, header state, column counts, and cmark alignment metadata before the
cmark tree is released, and masks table source lines with ordered placeholders.
`Coyote_GUI.Conversation_Stack` combines table and display-math placeholders so
mixed responses retain source order, removes the streaming view at completion,
and realizes tables as theme-styled native `Gtk.Grid` components with wrapping,
selectable cells and bold header markup. Retained cells receive font updates
and table state is cleared with the exchange hierarchy.

The shared `Coyote_Renderer.Markup` contract remains unchanged for SQC session
replay and text fallback. cmark column count and alignment are exposed through
scalar C shims; the alignment pointer remains confined to the C boundary.
Headless extraction tests cover metadata and line-preserving masking. Native
GUI tests cover grid/cell realization, alignment, stream replacement, and the
Markdown toggle; display-backed execution remains pending where no virtual
X11 display is available.

### Agent endpoint unification (2026-09-05)

`Coyote_App.Agent_Registry` now records an explicit `Endpoint_Kind` for every
agent node. `Register_Agent` is the common registration primitive; the retained
`Register_Root` and `Register_Child` operations are compatibility wrappers that
select `Local_Endpoint` and `RPC_Endpoint`, respectively. The GTK coordinator
uses the same generic primitive for the root and RPC handshakes for children.

Selected prompt, Stop, Pause, and Resume routing now consults the selected node's
endpoint rather than comparing its runtime identity with the literal `root`.
Local nodes use the existing prompt queue and direct session abort path; RPC
nodes continue through `Agent_RPC.Service`. Local lifecycle/status projection
uses the same endpoint classification. This keeps the root in-process while
making root and subagent nodes uniform at the registry and coordinator-routing
levels.

Focused registry coverage verifies generic local/RPC registration, child
endpoint classification, and endpoint preservation through status updates.
The production and test development builds pass. The full suite reached the
registered tests but timed out with unrelated environment/fixture failures in
recursion-limit, authentication, and SQC session/workspace tests.

### Selected-agent status bar (2026-10-18)

The GUI status bar now follows the selected virtual agent. Local root status
updates and RPC child `Status` events are cached independently by runtime agent
ID; only the selected agent's updates change the visible label. Selecting a row
restores its latest status, with lifecycle state used until an agent reports
status. A session reset clears the cache and returns the selected root to its
Ready state. A GTK regression test covers background-update isolation,
selection changes, and reset behavior.

### Selected virtual-agent controls (2026-09-01)

### Accepted virtual-agent-window amendment (2026-08-31)

The GUI coordinator presents short-lived subagents through a virtual-agent
tree rather than one top-level window per headful subagent. The tree is
implemented as a modeless `coyote : Agents` independent top-level companion
window associated with the coordinator window but not transient for it. This
allows tiling window managers to tile the Agents window normally. It is
visible by default. `View → Agents Window` toggles
its visibility; closing it hides only the support window. The main agent is the
tree root and recursively launched subagents are child virtual windows.
Selecting a live node replaces the conversation shown in the shared
conversation view and routes prompts and applicable controls to that agent,
reproducing the current multi-window "driver's seat" behavior without desktop
pollution.

The amendment is organizational only. Coordinator-launched subagents remain
short-lived `--subagent` processes: they process the initial prompt, accept
steering while active, emit the final response, and exit. Completed, aborted,
failed, or disconnected nodes remain as presentation records for review; they
do not keep a worker process alive or create a persistent interactive session.
The coordinator path now uses a headless, bidirectional local RPC frontend
for structured conversation and lifecycle events. The runtime registry, shared
conversation replay, selected-agent prompt/control routing, active control
polling, and terminal retention are implemented. Focused registry, codec,
transport, and service qualification passes; display-backed and real-provider
end-to-end qualification remain open.

### GTK IRIX alignment slice (2026-08-23)

The GTK main menu now follows the implemented desktop order `File`, `Edit`,
`View`, `Agent`, `Options`, `Help`; Preferences is under Options and Help is
rightmost. Edit provides Cut, Copy, Paste, Select All, and Deselect All. The main window and transient support/dialog windows use
application-identifying titles without lifecycle status, and lifecycle state
remains in the status area. The Help menu launches Yelp topics for Overview,
task help, Index, and Keys & Shortcuts. Product Information is an in-process
dialog with the prominent themed coyote application icon above the name,
version, and license text. Click for Help arms contextual help. Pause uses
Ctrl+Shift+P so the reserved Ctrl+P accelerator remains available for Print.
Help task entries use GTK mnemonics (`_Send a Prompt`, `_Manage Sessions`,
and `_Agent Controls`); standard Help entries also have mnemonics. F1 opens
Overview and Shift+F1 arms Click for Help.

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

### GTK application icon search-path correction (2026-09-01)

The Product Information dialog and main window use the themed icon name
`coyote`, while GTK does not automatically search the checkout or a private
Alire prefix for the application-owned `share/icons` tree. The GUI frontend
now registers the executable-relative `$BASE/share/icons` directory with the
default GTK icon theme before creating windows. A parent-prefix fallback also
covers the nested `test/bin` layout used by display-backed tests. The existing
Product Information regression now verifies that GTK resolves `coyote` to a
source file rather than only checking the widget metadata.

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

The picker is implemented by `Coyote_GUI.Model_Picker` and returns a typed
selection without changing agent state or persisting settings. `Models...`
enqueues `Set_Model`; Preferences invokes the same picker from its primary and
subagent model buttons, retaining draft selections until Save. The subagent
picker adds an explicit `Use default model` row that clears both persisted
subagent fields.

### GTK model-picker refresh (2026-09-22)

The shared model picker now provides an IRIX-compliant `_Refresh` pushbutton in
its search row, between the expanding search entry and the model count. The
button queues a typed `Refresh_Models` command instead of performing catalogue
work on the GTK task. `Agent_Task` performs a forced catalogue refresh and
publishes `Model_Registry_Refreshed` through the protected GTK update queue.
The picker rebuilds its existing list store on the GTK main task, preserving
its query and selected model where possible; Preferences also receives the
refreshed snapshot. The update is applied even when a different virtual agent
is selected.

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

A non-aborted interactive root-agent turn queues a completion update after
the final `Session_Stats_Event`. The GTK idle callback checks
`Gtk.Window.Is_Active` and calls the native `Coyote_Notify` libnotify binding
only when the window is inactive. This notification is global rather than
scoped to the selected virtual agent, so selecting a child does not hide the
signal that the root agent may need user input. Child request completion only
updates its virtual conversation. Notification-daemon absence or delivery
failure does not affect the agent session.

### Why GUI and Plain share one `Dispatch_Event` function

### GUI Preferences implementation (2026-08-06)

The GTK Preferences dialog is implemented as an `Options → Preferences...`
workflow. It edits persistent model, thinking-level, sandbox, optional
subagent-model, recursion-depth, termination-grace, completion-notification,
price-display, HTTP low-speed timeout, and ordered skill-directory defaults on
the GTK main task, then sends a typed `Set_Preferences` payload through the
protected prompt queue to
the agent task. The agent task owns settings-file persistence and reports write
success or failure through the frontend. Saving defaults does not change the
active session; the existing Agent menu controls remain the runtime override
path. New GUI sessions reload the persisted preferences before agent creation.
Save is the default dialog response, the Default model control receives initial
focus, Escape cancels, and each editable control has a GTK mnemonic association.

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


### Historical — legacy GTK renderer implementation notes

### Historical — Drawing_Area-based virtualized rendering (2026-07-31)

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

### Native GTK conversation presentation (qualified 2026-08-31)

`Coyote_GUI.Conversation_Stack` is now the sole GTK conversation renderer. The
frontend constructs it unconditionally and routes every conversation update,
selection operation, clear operation, font update, zoom event, and auto-scroll
operation directly to the stack. The runtime `COYOTE_NATIVE_STACK` switch and
the retired custom canvas have been removed.

The qualified native presentation provides one outer scroller, exchange and
step frames, streaming and completed Markdown response widgets, localized
Lasem-backed display MathML with selectable fallback, local selection/PRIMARY,
responsive native tool cards, retained Details payloads, focusable Fork
controls, live/replay parity, and session-reset callback invalidation.

| Capability | Native stack | Plain | SQC replay |
|---|---|---|---|
| GFM Markdown response content | Qualified | Plain text | Implemented |
| Markdown toggle and zoom | Qualified | N/A | N/A |
| Display MathML and fallback | Qualified | Plain text | Separate |
| Live/replay native hierarchy | Qualified | N/A | Replay model |
| Large-history behavior | Qualified | N/A | Separate |

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
### Historical — `Coyote_Cmark` C shim for enum resolution

libcmark-gfm exposes `cmark_node_type`, `cmark_list_type`, and
`cmark_event_type` as C enum values. These are resolved once at Ada package
elaboration time by calling the C shim getter functions
(`cmark_shim_node_paragraph()`, etc.) and storing the results in integer
variables. All GUI comparisons use these stored integers.
This means the Ada code is correct regardless of which installed version of
libcmark-gfm is used — it never assumes a specific numeric value.

### Historical — System font integration (2026-07-30)

The GUI frontend reads the system default proportional font from
`Gtk.Settings.Get_Default` (`gtk-font-name`) at startup
(`Init_System_Font`).  The conversation view, prompt `GtkTextView`, and
status bar all use this family and size as their baseline (zoom level 0).
Zoom adjusts ±1 pt from the system baseline. `Coyote_GUI.Conversation_Stack`
propagates the effective font description to native text and math widgets.
Display math is remeasured and rendered through the Lasem resolution scale at
the same factor.  The SQC
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
four-pixel padded status box. The status box retains its outer vertical layout
and contains an inner horizontal box with the lifecycle label and a fixed-width
context-window progress indicator. Typed context updates cross the existing
protected queue and are applied only on the GTK main task; session reset clears
the indicator. This follows the IRIX work-area/control-area/status-area
grouping without adding nested scrolling or changing prompt and status
behavior. The structural regression `Coyote.GUI layout and shutdown lifecycle`
verifies the widget order, configured borders, inner orientation, and initial
progress state. Display-backed human review remains required to confirm the
indicator's sizing and theme contrast.

### Historical — GUI visual spacing and layout

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
The native `Coyote_GUI.Conversation_Stack` presents tool calls as native
frames with status labels, selectable argument fields, retained detail payloads,
and focusable Details buttons. Completed cards use native GTK state and do not
require a custom canvas or coordinate-based hit testing.


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

### Context-local GTK mnemonic validation (2026-09-06)

`Coyote_GUI.Mnemonics` extracts GTK underscore mnemonics, normalizes keys
case-insensitively, and rejects duplicate keys within a menu or dialog
registry. The main File, Edit, Options, Agent, Thinking Level, View, and Help
menus and the Sandbox Profiles menus reserve their labels while constructing
GTK items. The Preferences dialog reserves all labels and action buttons in
one dialog-local registry. Existing collisions were corrected: Agent Session
Stats uses `I`, Sandbox File Cancel uses `L`, and Preferences labels/actions
use distinct keys. Repeated dynamic tool-card controls remain unmarked.
The unit tests cover extraction, escaped underscores, duplicate rejection, and
separate-context reuse.

### Menu keyboard accelerators (2026-09-05, REQ-CORE-132)

The main GTK window attaches visible primary accelerators through one
`Gtk_Accel_Group`: Ctrl+N (New Window), Ctrl+Shift+N (New Session), Ctrl+O
(Open Session), Ctrl+Q (Exit), Ctrl+X/C/V/A (Cut, Copy, Paste, Select All),
Ctrl+Shift+D (Deselect All), Ctrl+, (Preferences), Ctrl+Return (Send), Ctrl+L
(Clear Conversation), Escape (Stop), Ctrl+Shift+P (Pause), Ctrl+R (Resume),
Ctrl+M (Models), Ctrl+1 through Ctrl+6 (Thinking Level: Off through X-High),
Ctrl+Shift+S (Sandbox Profile), Ctrl+Shift+C (Compact Context), Ctrl+Shift+I
(Session Stats), Ctrl+Shift+M (Render Markdown), Ctrl+Shift+A (Auto-scroll),
Ctrl+F (Find), and Ctrl++/Ctrl+-/Ctrl+0 (Zoom In/Out/Reset).

These entries use `Accel_Visible`, so GTK renders their shortcut labels. Every
menu and menu entry also has a mnemonic where GTK supports one. Informational
Help entries have mnemonics but do not require independent accelerators.
The separate conversation context-menu Copy item and Preferences dialog
combo-box choices are outside this main-menu accelerator set.

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

### Historical — Ctrl+mouse-wheel zoom (2026-08-15, REQ-CORE-125)

Ctrl+wheel over the native conversation view now zooms. The frontend
connects the scroll callback to the native stack's scrollable widget.  With
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

- `Coyote_GUI.Tool_Detail_Window`: compiled and linked into the main GUI.
  Implemented redesign: independent render-time snapshots in a modeless co-primary
  transient `coyote : Tool Call Details` window. The accepted contract specifies
  compact fixed selectable metadata, one-line ellipsized long values with
  complete selectable/copyable values and tooltips, File/Edit/Help menus, stationary
  Close and Help actions, and a vertical `Gtk.Paned` without an outer scroller.
  The arguments pane contains one scrollable read-only monospace view for all
  labelled decoded arguments; the result pane contains one scrollable
  read-only monospace result view or image presentation. Hidden-argument
  filtering, image fallback, status meaning, keyboard behavior, and snapshot/no
  session-reread behavior are preserved. Five dedicated display-backed tests
  passed under Xvfb for structure/default/minimum sizing, independent scrolling,
  remapping and resizing, full metadata clipboard selection, independent and
  running snapshots, argument formatting/filtering, image rendering/fallback.
  **Historical verification (2026-10-21):** Full suite: 982/982. This count is
  superseded by the current 990/990 PCR-114 baseline above. DEM-041 desktop,
  theme/font, and physical keyboard qualification remains manual.
- `Coyote_Lasem`: covered by five AUnit tests for MathML fraction and matrix
  measurement, zoom scaling, relation entities, and invalid MathML error
  handling.  `Coyote_Renderer.MathML` adds headless extraction tests protecting
  fenced and indented code, preserving source, and preserving unmatched
  delimiters. `Coyote_GUI.Conversation_Stack` has 17 native presentation tests
  covering realization, Markdown, MathML, step lifecycle, tool flow, selection,
  reset, and zoom propagation.
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
- Native-stack qualification is complete. Future frontend work is limited to
  independent prompt-editing improvements and maintenance.

### Historical — variable-height block layout (2026-08-15)

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

When a conversation text view has focus, the outer conversation viewport
implements vi-style navigation: `j`/`k` move by one body line, `g` moves to
the top, `G`/Shift+`g` moves to the bottom, and Ctrl+D/Ctrl+U moves by one
page. Native wheel scrolling remains available. Prompt editing, the agents
tree, list dialogs, and other controls retain native key handling. The pure
`Coyote_GUI.Navigation` package clamps movement to the adjustment bounds and
is unit tested.

Native tool cards and fork action strips participate in GTK traversal. Enter,
keypad Enter, or Space activates the focused native control. Escape cancels
armed contextual Help; otherwise the main-window Escape accelerator performs
Stop. Support windows close or hide on Escape.

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
focusable actions through GTK accessibility. The native stack provides local selection, focusable actions, and GTK
accessibility. Display-backed AT-SPI qualification and full color-contrast
measurement remain independent GUI work.

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

### Historical — Visible per-step frame amendment (2026-08-25)

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
rendering. The native stack is now the sole GTK conversation presentation. The
historical fallback and runtime selection flag were removed after qualification.

### Historical — native component-stack migration record (2026-08-24, PCR-073)

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
argument JSON, full results, or image result content. Each card has a focusable
`View Details` pushbutton that opens a captured `coyote : Tool Call Details`
snapshot; active snapshots show invocation metadata, arguments, and `Running`,
while completed snapshots add the captured result. Math remains a localized
Lasem-backed child widget or cached image with
readable source/fallback content.

The native stack is the qualified implementation baseline. Its
Markdown, UTF-8, thinking, tool-ID, and MathML logic uses
`Coyote_Renderer.Markup`. The
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
When the prompt has focus, Copy and Select All target the prompt; otherwise
conversation commands resolve the focused conversation text view, then a
retained conversation selection, then the active response view. CLIPBOARD and
PRIMARY remain independent. This removes the previous global selection/
hit-testing model as a migration requirement.

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

The qualified implementation is present in
`Coyote_GUI.Conversation_Stack`. It realizes one outer vertical scrolled window,
one exchange container per request, native selectable text views for request,
thinking, and response content, native focusable fork controls, structured native
tool-card labels, retained `Tool_Info` payloads, and `View Details` buttons that
are enabled when the card starts. Active cards open captured, non-live detail
snapshots showing invocation metadata, arguments, and `Running`; completed
cards add the captured result. Completed responses with standalone display math
are realized as ordered native text views and Lasem-backed
`Coyote_GUI.Math_Element` widgets; invalid expressions retain selectable source
fallback. The cmark-backed `Coyote_Renderer.MathML` extractor protects code-block
ranges before masking display math. The native stack is constructed unconditionally and is the sole GTK
conversation presentation. The four native MathML tests and parser-safety
regressions are registered. Production and test development builds succeed;
native qualification is closed under DEM-042 through DEM-048. DEM-047
live/replay Markdown parity was accepted by the user on 2026-08-28.
The native footer presentation was refined to use a semantic `Step N summary`
or `Turn summary` heading above the existing non-selectable metadata label. The
footer keeps its native separator and Fork pushbutton, but no longer adds a
second padded/recessed treatment inside the required visible step frame. This
is a GUI-only presentation change; footer transport, Plain output, replay
semantics, and the typed step/final distinction remain unchanged.

The separately named `Exchange_View`, `Text_Element`, `Tool_Card`,
`Math_Element`, and `Footer_Element` abstractions remain private to
`Conversation_Stack`; no separate compilation units are required for the
qualified implementation. Native footers now use a GTK separator, a
non-selectable summary label, and a right-aligned action row with a stable
`Fork` pushbutton. The button captures UUID/turn/step data and invokes the
registered GUI fork handler; normal completion does not add a duplicate
standalone status widget. The typed summary travels separately from the
formatted text through the GUI update queue, so native rendering does not parse
frontend display text. Plain output remains unchanged. Native qualification covers 100, 500, and
2,000 exchanges; streaming first-token latency; widget count and memory; resize
and zoom; auto-scroll; local selection and PRIMARY; tool-card activation;
clear/session-switch callback invalidation; replay/live parity; and keyboard
focus traversal.

### Historical — responsive native tool-card flow (2026-08-30, PCR-089)

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

### Physical Fork and New Window processes (2026-09-02)

The native GTK `Fork` action now creates the durable branch through
`Session_Lister.Fork_Session` and launches it as an independent physical GUI
process using the active executable, explicit `--frontend gui`,
`--physical-window`, the forked `--session` UUID, the target working directory,
and a `Fork @ turn[/step]` window label. `File → New Window` uses the same
physical launch mode without a session argument. Neither path uses
`--subagent`, so neither path is registered as a coordinator virtual agent or
subject to the short-lived one-shot lifecycle. The entry point clears inherited
coordinator and session-lineage variables for these children. Fork-copy failures
are reported through the originating GUI's notice path; detached-spawn callers
now receive and handle initial process-creation status. The existing native
button and session-copy tests pass; display-backed two-window qualification
remains required.

### GTK recursion-depth preference (2026-08-29)

The GTK Preferences dialog now exposes the persistent maximum subagent
recursion depth alongside model, thinking, sandbox, subagent-model, and
completion-notification defaults. The value is carried through the typed
`Set_Preferences` queue item and saved by the agent task as
`maxRecursionDepth`; enforcement remains in the executable entry point before
frontend and session startup. Queue and settings persistence regressions cover
non-default and zero values.

### Historical — GTK footer-summary propagation correction (2026-08-25)

The GUI frontend now preserves the typed footer summary in `Update.Text2` and
passes it to the native conversation stack. The native stack renders the typed footer summary through its native
status row while retaining the update-queue payload round trip. Added
regressions cover the queue payload and native summary visibility.

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

### Sandbox Profiles menu integration (2026-09-06)

The GTK frontend registers the documented `Options → Sandbox Profiles...`
item and opens the reusable modeless manager lazily. Repeated opens reuse the
same window and refresh the selected-agent target immediately before
presentation. The manager now presents the always-visible multi-profile draft
editor; the existing `Agent → Sandbox Profile...` quick chooser remains
unchanged.


Added a display-backed GUI regression for menu-item registration, lazy manager
creation, manager reuse, and title/lifecycle behavior. The focused Sandbox
Profiles test, existing GUI layout/shutdown test, standalone manager lifecycle
test, and `Set_Sandbox` RPC codec test pass. Use Profile routes through the
selected agent's local typed queue or versioned RPC control channel.

## 2026-09-06 — Detailed tool-call statuses (PCR-096)

Native tool cards now render `Queued`, `Running`, `Completed`, `Error`,
`Timed out`, and `Cancelled`. Cards update by stable tool ID; detail windows
and RPC/replay presentations carry the same terminal vocabulary. The card is
created queued and transitions to running only when its worker starts, so
later run groups no longer appear active prematurely.

The native conversation lifecycle regression covers queued → running → timed
out transitions and passes 1/1 focused, 22/22 in the conversation-stack group.

## 2026-09-09 — Icon-assisted action controls and session relations

Native tool-card `View Details`, `Abort`, and `Abort With Message...` buttons
now use semantic GTK theme icons (`document-properties`, `process-stop`, and
`mail-message-new`) while retaining their text labels, focus behavior,
sensitivity, and tooltips. The SQC `Show All` and `Y-Fit` toolbar actions use
`zoom-fit-best` beside their mnemonic labels and expose action-specific
tooltips. The Open Session tree now labels its relation column and renders
`Root`, `Subagent`, or `Fork` text alongside the existing relation glyphs,
so session lineage remains understandable without relying on a glyph alone.

No emoji were added: menus, statistical content, chart markers, and user
content remain text- or data-led in accordance with the IRIX interaction and
accessibility guidance. Production and test development builds succeed; the
focused conversation GUI group passes 24/24 and the complete AUnit suite
passes 874/874.

## 2026-09-09 — Horizontal tool-card action row

Tool-card `View Details`, `Abort`, and `Abort With Message...` controls now share
one horizontal GTK action row inside each card instead of being packed directly
into the card's vertical content box. Existing callbacks, sensitivity transitions,
button order, and the responsive flow of multiple cards are unchanged. Added a
conversation-stack regression that verifies the row orientation, child count, and
native button order.

## 2026-09-07 — Options → Subscriptions… manager (Codex provider GUI)

The GTK frontend registers `Options → Subscriptions...` (mnemonic
`b`, no accelerator — account management is not a high-frequency
action) after the Sandbox Profiles item and opens one reusable, modeless
support window titled `coyote : Subscriptions`, transient for the main
window and lazily created on the GTK main task, following the Sandbox
Profiles manager pattern.

The window lists managed provider subscriptions in a single-selection
`GtkTreeView` (Provider / State columns): OpenAI Codex (ChatGPT Plus/Pro)
and GitHub Copilot, with state read live from `~/.coyote/auth.json`.
A detail frame shows the selected provider's login status and — for
Codex — the ChatGPT account id extracted from the access-token JWT.
Buttons enable per selection state: Codex offers Login (browser OAuth
via `LLM.Auth.Codex.Login` running in a background task polled by a
250 ms GLib timeout, so all widget access stays on the main loop),
Refresh (forced token refresh via `Ensure_Valid`), and Logout (clears
the `codex` credential entry).  Copilot rows report state only; CLI
credential management remains authoritative there.  The IRIX guideline
"disable, do not remove" governs all button states, including while a
login is active (all three disabled).  Login progress surfaces in the
bottom status area; Ctrl+W and the close button hide the window without
destroying the instance, matching the Sandbox Profiles manager.

No display-backed GUI regression was added for this window yet; the
underlying OAuth flow is covered by 15 headless AUnit cases in
`LLM.Auth.Codex` / `LLM.Providers.Codex`.  A display-backed
menu-registration and lifecycle test is the natural follow-up, mirroring
the Sandbox Profiles regression.

Post-merge the browser login path was exercised end-to-end and works:
xdg-open launches the authorize URL, the callback lands on the local
listener, and credentials persist to ~/.coyote/auth.json. Fixes made
during bring-up (callback port 1455, CRLF CRLF head terminator,
SO_REUSEADDR + error-path listener cleanup, percent-decoded query
values, and sending the S256 challenge rather than the verifier in the
authorize URL) are recorded in the providers SDF.

## 2026-09-07 — Ephemeral subagent model override (REQ-CORE-143)

The GTK `Agent` menu gains `Subagent Mo_del...` next to `Models...`. The item
opens the shared model picker with `Allow_Default => True`, preselecting the
current override, or `Use default model` when unset. Selecting a model
enqueues a typed `Set_Subagent_Model` item targeting the root agent;
selecting `Use default model` enqueues the same item with an empty spec. The
agent task stores the spec in the package-level
`Coyote_App.Subagent_Model_Override_State` protected object, publishes
`COYOTE_SUBAGENT_MODEL` for subsequently launched subagent processes
(descendants inherit it), and confirms with an informational notice. The
override is runtime-only: it never touches `settings.json`, survives
`File → New Session`, and disappears at process exit. The status bar gains a
persistent `▶sub provider/model-id` segment (via `Format_Status`) while the
override is active, and physical windows clear the variable so independent
GUI sessions do not inherit coordinator-only subagent policy.

**Verification:** Production and test development builds succeed; the full
AUnit suite passes 849/849, including the new `Set_Subagent_Model` queue
round-trip test and GUI lifecycle tests (mnemonic conflict with `Ctrl+M`
fixed by moving the mnemonic to `Subagent Mo_del...`).

## 2026-09-07 — Fix picker crash on empty initial spec

`Coyote_GUI.Model_Picker.Choose` held its pre-selection in a String
constrained by the initial value's bounds; with `Allow_Default => True` and
an empty `Initial_Spec` the object had null bounds (1..0), so assigning
`Default_Spec` raised `Constraint_Error: length check failed` when the new
`Agent → Subagent Model...` dialog opened without an active override. The
holder is now an `Unbounded_String`, which also fixes the latent same crash
in the Preferences subagent-model button when `defaultSubagentModel` is
unset. An unrelated unused-`Button` warning in the same procedure was
silenced with a pragma.

**Verification:** Production and test development builds succeed; the full
Historical AUnit suite passes 864/864 including all GUI domain tests; the suite baseline recorded at that historical point was 919/919.

## 2026-09-09 — Auto-compaction Preferences (REQ-CORE-116..119)

The GTK Preferences dialog now exposes automatic compaction enablement and a
1..100 compaction threshold percentage, defaulting to 80. Values are carried
through `Coyote_GUI.Prompt_Queue.Preferences_Record` and persisted by the agent
task as `autoCompaction` and `compactionThresholdPercent`, while preserving the
existing rule that persistent preference changes apply to new sessions rather
than silently changing the active session.

Verification: queue and settings regressions cover typed transport, persistence,
malformed/out-of-range defaults, and unrelated-field preservation. The complete
AUnit suite passes 875/875.

## 2026-09-21 — RPC targeted-abort delivery while a tool is running

The RPC frontend now has one reader task that owns inbound socket reads and
routes prompt/steer frames and control frames into separate protected FIFO
mailboxes. The headless runner keeps its control monitor active for the entire
child lifetime, including while `LLM.Agent.Run_Prompt` is blocked in provider or
tool I/O. `abortTool` therefore reaches `LLM.Agent.Request_Tool_Abort` without
waiting for another agent event; shutdown closes the prompt mailbox so an idle
prompt read wakes. A focused frontend regression verifies prompt/control
demultiplexing over the coordinator service path; existing RPC, agent, and
shell cancellation tests remain complementary.

## 2026-09-08 — IRIX-style targeted tool actions (REQ-CORE-055c..055d)

Native tool cards now provide focusable `Abort` and `Abort With Message...`
pushbuttons beside `View Details`. The actions are enabled for queued/running
calls and disabled for terminal calls; `View Details` remains available for
review. The Agent menu provides equivalent selected-tool actions, while the
existing Agent `Stop` remains whole-turn cancellation. The message prompt is a
transient `coyote : Prompt` dialog with a multiline field and specific Abort,
Cancel, and Help responses. Local actions call the protected session bridge;
virtual-agent actions send the typed `abortTool` RPC command. Focused GUI tests
cover active/terminal sensitivity and terminal detail availability.

## 2026-10-11 — Open rendered Markdown links

Rendered Markdown link labels now retain their cmark destinations and receive
GTK text tags in live responses and session replay. A left-button release on a
tagged range launches `xdg-open` with the destination as a separate argv item;
control characters and unsupported URI schemes are rejected. Allowed targets
are HTTP(S), mailto, and relative/local paths. Renderer tests cover Unicode
labels and destination capture; the destination policy is covered by the GUI
stack suite. Native table-cell links remain out of scope.


### Follow-up — Connect streamed Markdown link activation

A live-response regression left links tagged but did not connect the release
handler: streaming rerenders deliberately skip signal setup, and no handler was
installed when the response view was created. Signal registration now occurs
once during text-view creation (and once for session replay), independently of
markup insertion. Pointer hit-testing also resolves the event's actual text-view
window before converting coordinates. Focused Conversation_Stack tests pass
33/33, including verification that rendered link ranges receive a target tag.


## 2026-10-18 — Correct native Markdown link click dispatch (PCR-106)

GTK releases normally arrive on `Text_Window_Text`; filtering only for
`Text_Window_Widget` rejected them. The handler now accepts both text windows,
ignores border events, and maps coordinates using the shared Markdown text
subwindow. The tag-list head remains available for freeing. The streamed
response regression dispatches press/release through GTK and checks the exact
`xdg-open` destination, including query and fragment, as well as non-left and
untagged clicks. The corrected regression fails with the old filter and passes
with the fix. Development application and test builds passed; Xvfb-backed
Conversation_Stack passes 34/34 and the full suite passes 911/911 when run from
`test/`. An initial full-suite run from the repository root failed due to the
working-directory requirement. This is developer self-evaluation; independent
confirmation in the user's desktop remains an acceptance check.


## 2026-10-18 — Markdown link hover feedback (PCR-107)

The user confirmed that activation works in the new GUI instance; absent cursor
feedback, rather than an inactive opener, explained the perceived failure.
Shared Markdown text views now use the same safe-destination hit test for
clicks, pointer motion, and tooltip queries. Actionable links show the desktop
hand cursor and plain-text destination tooltips; ordinary text and leave events
restore the text cursor. A post-draw callback refreshes the physical pointer
after scrolling or rerendering. Ancestor scroll adjustments queue redraws through
view-bound slot connections that disconnect on view finalization; there is no
polling timer. Target changes requery GTK tooltips so stale URLs disappear on
scrolling away. Registration is idempotent and cursor creation references are
released after assignment. Native table cells remain outside this text-view
link path.

Explicit development application and test builds (including the application
as a development dependency) pass. Conversation_Stack passes 35/35 and the full
suite passes 912/912, 39.64 s wall. Real X11 pointer qualification under Xvfb
confirmed hand/text transitions, plain tooltip text containing ampersands and
angle brackets, dismissal on scrolling away, and restoration on scrolling back
beneath a stationary pointer after redraw; hovering did not invoke the fake
opener. Qualification found and corrected a test-tooltip ownership fault and a
scroll-return gap where GTK reused pixels without redrawing the text child.
This is developer self-evaluation; independent user desktop acceptance remains.


## 2026-10-18 — Session-scoped Agents window reset (PCR-108)

Accepted New Session, session Switch, and in-place Fork transitions now queue
an unfiltered GTK reset before bootstrap/replay. The reset removes worker rows
and descendants, clears the runtime registry and every retained in-memory
conversation (including root), recreates/selects the main root in Ready, and
refreshes agent controls. Ordinary conversation Clear and independent physical
Fork windows keep their existing behavior. Saved JSONL files are unchanged.
Switch refreshes COYOTE_SESSION_ID so later workers inherit current lineage.

The RPC service prepares a unique replacement listener before retiring the old
one. Nonblocking best-effort Shutdown commands precede channel closure. Service
callbacks tag frames with their generation and enqueue the reset marker before
polling fresh connections, so delayed old frames cannot restore histories or
rows. Old descendants inherit a retired endpoint. Listener preparation failure
falls back to graceful Detach, clears endpoint inheritance, and displays a
warning while allowing the loaded root session to bootstrap; the still-live
service task can recover on the next transition. Retired listener/channel
allocations are reclaimed. Reset does not force-kill worker processes or wait
for their exit.

Explicit development application and test builds pass (including the coyote
dependency in the test build). Focused RPC is 34/34, display-backed GUI 94/94,
and the final complete suite is 920/920 under Xvfb, 39.66 s wall. New tests cover
selected-worker/nested reset, stale handshake/event/terminal rejection, root
history isolation, ordinary Clear preservation, failed-listener detach/recovery,
shutdown/marker ordering, old-endpoint refusal, and a saturated unread peer.
Existing live-provider and subprocess guards remain opt-in. git diff --check
passes. Verification is developer self-evaluation; the user retains independent
desktop acceptance. One optional hardening subagent invocation was aborted
without edits after the user reported it appeared hung; that check was completed
locally and is included in the final verified suite.


## 2026-10-19 — Help regression coverage (PCR-112)

`Coyote_Help_Tests` now registers 12 cases (previously five). New coverage checks
all area topics and unknown/empty fallback, detached root/topic arguments,
executable-relative share discovery from a prefix containing spaces,
existing/empty/unset XDG child values and exact parent restoration, missing
bundled data, and missing Yelp. Availability no longer requires a desktop Yelp
installation. `Help_Test_Worker` is a test-build main copied into an isolated
bin/share prefix by `test/tools/check-help-launch.sh`; the fake Yelp writes argv,
its environment and completion marker. Polling and subprocess deadlines bound
failures. This exercises production `Open` without test hooks or API changes.

`Coyote_App.Frontend.GUI.Help_Tests` adds one display-backed fixture checking
real top-level and Help submenu order, labels and GTK mnemonic keyvals. With
Yelp unavailable it builds Product Information and verifies title, transient
parent, visible icon and application/version/license text. Lists and widgets
are cleaned up; PATH is restored on success or assertion failure. It follows
the existing no-display fixture convention, so use the dedicated workflow for
qualification rather than interpreting a headless suite pass as GUI evidence.

`test/check-help.sh` combines the 12 core and one GTK test with `yelp-check`
validation/links and CLI `-h`/`--help` stdout/stderr/exit assertions. Run
`xvfb-run -a sh test/check-help.sh` after both development builds. Source/test
inventories and coverage claims are updated. Eight net new registrations bring
the current total from 969 to 977; older baseline totals are historical.

Development builds and focused workflow pass. Full suite from `test/` under
Xvfb passes 977/977, no failures or unexpected errors, 58.39 s wall. An initial
root-cwd full run failed existing fixture lookup assumptions; no production
fix was needed. Existing GTK theme CSS warnings appeared. Live providers were
not enabled. Review found no implementation blocker after prerequisite and
cleanup refinements; this is developer self-evaluation, not independent user
acceptance.

F1/Shift+F1 activation, contextual-click routing and non-activation, cursor state,
Escape, visible launch errors, real Yelp rendering/navigation and installation
remain DEM-036..039 manual checks. Attempts at callback-level GTK probes stalled
and were removed. Fork/spawn failure and exceptional restoration are not injected.
These are explicit remaining coverage gaps, not completed qualification.

## 2026-10-21 — Accepted Tool Call Details redesign

The accepted main Coyote GUI redesign makes Tool Call Details a modeless
co-primary inspection window, still transient for its parent, with independent
captured snapshots. Requirements and design specify fixed selectable metadata,
ellipsized single-line long values with complete selectable/copyable values
and full-value tooltips, File/Edit/Help menus, stationary Close and Help actions,
no outer scroller, and a two-pane arguments/result work area.

Production and test builds explicitly use `alr build --development`. The five
new inspector tests pass under Xvfb. They verify 760 × 600 default and
600 × 400 minimum allocation with long metadata, approximately 40/60 initial
split, exactly two independent scrollers, sash usability/remap preservation,
full argument and metadata clipboard selection, independent snapshots,
running/no-result snapshots, argument decoding/filtering/empty/raw fallback,
and valid/invalid image results. GTK ellipsized-label selection clamps to its
shortened layout; Select All temporarily selects against the full layout and
restores ellipsization synchronously, preserving compact geometry and copying
the full value. Snapshot/file APIs and the separate SQC inspector are unchanged.

Full registered suite: 982/982, zero failed assertions or unexpected errors,
60.36 s wall from `test/` under Xvfb. Help checks pass 12/12 core and 1/1 GUI,
plus Mallard validation/links and CLI aliases. Existing theme CSS warnings occur
on focused GUI runs. Developer self-evaluation and a separate read-only review
were performed; these are not independent human acceptance. DEM-041 desktop,
light/dark theme, enlarged fonts, wheel/touchpad and physical keyboard/menu
interaction, and actual Yelp navigation remain manual qualification.


## 2026-10-22 — Reference-guided native Ada math feasibility slice (superseded)

This earlier prototype entry records the exploratory work and its standalone
results. It was subsequently promoted and replaced by the production engine
recorded below; its non-production status and deferred-scope statements are
historical and no longer describe the current product baseline. PCR-122 remains
a factual record of the feasibility work.

## 2026-10-22 — Production native math cutover qualified (PCR-123)

The user authorized production completion and removal, not preservation, of the
legacy MathML renderer. The production engine now lives in `src/coyote_math/`
with shared font assets/notices under `share/coyote/math/`; duplicated prototype
code and fonts were removed. `Coyote_Renderer.Math` replaces the old extractor.
Inline GTK formulas retain hidden exact source for Copy, stable marks for zoom
reflow, baseline offsets and theme colours. Display formulas draw natively.
Unsupported input and resource-limit/font failures retain visible source.

The MathML/Lasem binding, C bridge, extractor, five registered tests and link
settings are removed. Historical entries are superseded, not current support.
The prompt and active requirements now request LaTeX. Final development builds
pass; Xvfb full suite passes 1042/1042 with no failures/unexpected errors.
Native qualification passes 151 assertions; Valgrind has zero errors/lost bytes;
metrics regenerate byte-identically. See `plan/native-math-test-report.md` for
full evidence and explicit qualification gaps. These are developer/agent checks,
not independent human visual acceptance or a promise of complete TeX support.
