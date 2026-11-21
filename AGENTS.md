# coyote — Agent Instructions

## Project Overview

Coyote is a native Ada 2022 LLM coding-agent harness with two frontends:

- **GUI frontend** — GTK3 graphical conversation view, menus, session tools,
  tool-detail windows, Help, and protected GTK update/prompt queues.
- **Plain frontend** — synchronous line-oriented output for pipes, scripts,
  one-shot runs, and no-display environments.

The former Acme frontend, Nine_P 9P stack, plumber integration, and
`coyote_open` utility were removed from the current product baseline on
2026-08-30. Do not add Acme, 9P, `$winid`, `PLAN9`, or plumber assumptions to
current code or documentation. The current native-math evidence and open
qualification status belong in §11 of the coordinator-owned
`plan/native-math-parity-test-report.md`; treat §10 and earlier sections as
historical snapshots. No parity or product acceptance is implied.

The current implementation includes typed literal/box primitives, CD diagrams,
expanded accents/delimiters, contour integrals, array rules, color enclosures,
native font measurements and conditional Pango Unicode text-run shaping.
System fallback-font resolution remains unpinned. Cooperative checks reach
pipeline loops and phase boundaries but cannot preempt individual native calls
or guarantee hard deadlines. The shared 64 MiB retained-raster ledger covers
tracked worker results, display surfaces and inline Pixbufs, not whole-job
allocation. Inline math rasterization now runs on workers; GTK adopts Pixbufs
in bounded row batches (report §11.11). `Conversation_Stack` has
57 registered cases; registration is not qualification. Consult report §11,
“Current implementation and qualification reconciliation — 2026-11-06”, for
recorded evidence, unavailable-artifact limits and open gates. Earlier dated
implementation checkpoints are historical.
Executables:

- `bin/coyote` — selects GUI or Plain and runs the native agent loop.
- `bin/coyote_list_sessions` — prints UUID/name/date/snippet rows for the
  current directory.
- `bin/coyote_sqc` — reads session JSONL files and displays SQC charts.

## Documentation and governance

Engineering artifacts use the MIL-STD-498-based structure:

- `plan/` — project plan, test plan, problem/change log, test reports.
- `requirements/` — SRS documents.
- `design/` — SDD documents and software-unit inventory.
- `sdfs/` — component development logs.

Current frontend work is recorded in `sdfs/frontends.md`; core agent work is
recorded in `sdfs/core-agent.md`. Historical Acme migration records remain
factual and are superseded by the 2026-08-30 removal entry.

## Language and build system

- Language: Ada 2022 (GNAT/GCC).
- Build: Alire/GPRbuild (`alr`).
- Development build: `alr build`.
- Tests: `cd test && alr run coyote_test`.
- Release builds are not to be used unless explicitly requested.

The generated configuration must select the `development` profile. Object
files are under `obj/<profile>/`; executables are under `bin/`.

Dependencies include GNATCOLL, GtkAda/GTK3, libcurl, libcmark-gfm, and Yelp
for the GUI Help menu. Bundled KaTeX 0.16.22 math fonts and MIT notices are
under `share/coyote/math/fonts/`; Lasem is not a runtime dependency.
There is no plan9port dependency.

## Source layout

```text
src/
  coyote.adb                         entry point and frontend selection
  coyote_app.ads/.adb                App_State and GUI runner
  coyote_app-plain.ads/.adb          headless/plain runner
  coyote_app-frontend.ads            abstract frontend contract
  coyote_app-frontend-gui.*          GTK frontend
  coyote_app-frontend-plain.*        line-oriented frontend
  coyote_app-dispatch.*              native event dispatcher
  coyote_app-history.*               session JSONL replay
  coyote_app-utils.*                 formatting and UTF-8 helpers
  coyote_gui/                        GTK queues, conversation, dialogs
  coyote_renderer/                   shared renderer support
  coyote_sqc/                        SQC application
  llm/                               agent, providers, tools, sessions
  session_lister.*                   session listing/fork support
  coyote_utils.*                     CLI and session-prefix helpers
tools/
  coyote_list_sessions.adb           session-listing utility
test/src/                             AUnit tests
```

When adding source files, update `design/coyote-design.md §4.1` and the
relevant SDF.

## Frontend selection

The current executable selects the frontend in this order:

1. Explicit `--frontend gui|plain`.
2. Non-subagent `--one-shot` → Plain.
3. `COYOTE_FRONTEND=gui`, `$DISPLAY`, or `$WAYLAND_DISPLAY` → GUI.
4. Otherwise → Plain.

Coordinator-launched `--subagent` processes use a headless RPC presentation
channel instead of opening a GUI window. Ordinary child processes intended to
open their own physical GUI window may still inherit `COYOTE_FRONTEND=gui`.
Plain one-shot presentation goes to standard error so the final JSON result is
the only standard-output record. There is no Acme frontend context.

## Architecture

The GUI path has the GTK main task plus an agent task. The agent task emits
`LLM.Events.Agent_Event'Class` values synchronously through
`Coyote_App.Dispatch.Dispatch_Event`; GUI updates cross the GTK boundary via
`Coyote_GUI.Updates`, and input crosses back via `Coyote_GUI.Prompt_Queue`.
Assistant output uses direct libcmark-gfm Markdown rendering, native GFM tables,
and the native Ada math engine in the GTK conversation stack. Math delimiters
are `$...$`/`\(...\)` inline and `$$...$$`/`\[...\]` display; code is
protected, unsupported input remains visible, and no full TeX compatibility is
claimed. The engine supports common symbols, fractions, scripts, roots,
text/roman content, arrays, font styles, delimiters, limits, and accents. All
GTK widget operations execute on the GTK main task.

The Plain path is synchronous. `Coyote_App.Plain` owns the agent session,
replays requested history, dispatches native events through the same dispatcher,
and reads additional prompts from standard input. It does not initialize GTK,
open desktop windows, or use external integration services.

Session headers persist sandbox profiles, thinking levels, and parent lineage.
Child processes inherit the relevant `COYOTE_*` values. Tool subprocesses are
tracked by `Coyote_Process_Control`; process-wide SIGTERM uses the configured
grace period before escalation.

## Coding conventions

- Use three-space indentation as enforced by the Alire-generated GNAT development profile and `--  double-dash` comments.
- Omit standalone `in` parameter modes as required by GNAT `-gnatyI`; retain `out` and `in out` modes.
- Keep public API documentation in package specifications.
- Use `Ada.Strings.Unbounded.Unbounded_String` for variable-length record data.
- Use `GNATCOLL.JSON` `Read`, `Get_Str`, and `Get_Int` helpers.
- Use `Coyote_App.Utils.UC_*` constants for non-Latin-1 glyphs.
- Keep GTK operations on the GTK main task.
- Catch exceptions at task boundaries, report errors through the appropriate
  frontend, and always signal shutdown.
- Use `aged` for exact replacement edits. Load
  `/home/gtnoble/.alire/share/agents/skills/aged/SKILL.md` before invoking it.

## Testing

PCR-128 adds conversation `Text_Safety`: first Configure must be on GTK and
binds its Ada task; later off-task boundary mutations are rejected. Other GTK
calls remain caller responsibilities. Preserve decoder feed/flush/reset and the
PCR-127 zero-below-line policy. After development builds, run
`python3 test/tools/check-gtk-interactions.py` and
`python3 test/tools/check-gtk-interaction-runner.py`. Full suite1074/1074; evidence:
`plan/evidence/gtk-text-safety-2026-11-07/`. Source-only recovery and document-model
redesign remain unimplemented.

Historical native-math full-suite results include PCR-123 1042/1042, earlier
1057/1057, final3 1060/1060, and final2 1061/1061. Two intermediate frozen
full-suite attempts failed exactly one GTK tool-allocation assertion each;
three isolated focused passes followed, then a test-only correction added a
one-second monotonic GTK poll without changing or weakening the exact 760×600
dimension criterion. The previously recorded frozen full development suite passed 1063/1063
with zero failed assertions or unexpected errors in 82.418882 seconds. This is
historical regression evidence, not a current-snapshot rerun, qualification,
parity or product acceptance. The original `/tmp` evidence files are not
currently available; do not treat them as accessible artifacts. Isolated
non-math repeat failures remain to be reconciled. A fresh scoped accent-width
continuation passes one full suite 1063/1063 (88.930779 seconds cumulative),
207 raster assertions, 235 geometry cases, and the unchanged image pilot and
repeat 29/29. Incremental root/test development builds pass. Evidence is retained
under `plan/evidence/native-math-2026-11-06-accent-width/` and report §11.6;
this does not reconcile failed repeats or establish parity/acceptance. Valgrind
was not rerun and its existing lifecycle failure remains open.
The 2026-11-07 ordinary-accent continuation passes final raster 363/363,
geometry 235/235 and full suite 1063/1063 (82.909971 s cumulative). Original
images pass 29/29 twice; expanded images improve 31/53 to 49/53 and repeat
49/53, retaining overline-vertical and cancel-mask failures at 24/48 px. See
report §11.7 and `plan/evidence/native-math-2026-11-07-accent-skew/`. This is
scoped developer evidence, not parity, resource qualification or acceptance.

Current implementation and checkpoint evidence, including focused probes,
coverage counts and open qualification gates, are recorded in coordinator-owned
report §11. Coverage is a source crosswalk, not completion evidence. Whole-job
memory, hard 250 ms completion, GTK/cache guarantees, full reference behavior,
remaining core behavior and human acceptance remain unqualified. These
development builds are not warning-free or release qualification.

The 2026-11-10 overline continuation passes raster423/423, geometry235/235 and
full Xvfb1074/1074 (142.762374 s cumulative). Expanded images improve49/53 to
51/53 and repeat51/53; original29/29. Only cancel24/48 mask failures remain in
that corpus; broader gates above remain open. Rule 9 overline kerns use style
**default** thickness independently of minimum-clamped paint thickness. Evidence:
report §11.8 and `plan/evidence/native-math-2026-11-10-overline/`. Required GTK
and offline HTTP lifecycle checks pass. No parity/resource/human acceptance,
release or installation is implied; Valgrind was not rerun.

The subsequent 2026-11-10 cancellation continuation passes measured999/999,
geometry235/235 and full Xvfb1074/1074 (146.300164s cumulative). Prior expanded
53/53 and original29/29 pass. Additive95-case images improve baseline51/95 to
89/95 and repeat89/95; six isolated single-T cancel/bcancel/xcancel24/48 mask
failures remain, with unmatched upper ink and one-sided raster bounds. Do not
hide negative-origin overflow with logical padding or case removal. Report
§11.9 and `plan/evidence/native-math-2026-11-10-cancel/` control this checkpoint.
Native cancellation SVG stroke is0.046em, independent of minRuleThickness;
strike-through unchanged. No complete parity or acceptance; broad gates remain.

The 2026-11-10 origin-aware continuation supersedes those scoped raster
failures: corrected independent browser-margin oracle baseline77/95 improves
95/95 and repeats95/95; original29/29. The old X=0 browser viewport clipped
negative-X reference ink, so historical89/95 is not a comparable baseline.
Raster1108/1108, jobs162/162, geometry235/235 and exact-final full1074/1074
(147.547471s cumulative) pass. Full/tile images carry logical origins; worker
baselines and GTK physical paint extents include leading padding without changing
logical math metrics. Fleqn area margin compensates leading X. Inline painting
still runs on GTK. Report §11.10 and
`plan/evidence/native-math-2026-11-10-raster-origin/` control current evidence.
Native bearings/shaped-run ink, parent clipping and broader qualification gates
remain open; no parity/resource/human acceptance, release or installation.

The 2026-11-15 inline-worker continuation moves production inline parse/layout/
rasterization off GTK; GTK adopts padded Pixbufs in eight-row steps with a
cooperative5ms copy target. Fresh font reflow resubmits jobs, without double
zoom. Source stays visible until commit; partial images/results release on
mutation, clear, replacement and destruction. Final development full1076/1076
(148.864532s cumulative), worker170/170 and required GTK9/9, containment and
HTTP lifecycle checks pass. Two new conversation cases bring registration to57.
Evidence: report §11.11 and `plan/evidence/native-math-2026-11-15-inline-worker/`.
Prior browser/geometry/raster results were not rerun; no parity, whole-job memory,
hard deadline/cache/font/lifecycle or human acceptance gate is closed.

PCR-126 HTTP-timeout developer verification (2026-11-07) passes the full
Xvfb suite 1068/1068, zero failures/errors, 138.877699 s cumulative, and the
standalone offline Plain/RPC lifecycle harness. Evidence and commands are in
`plan/evidence/http-timeout-2026-11-07/README.md`. `LLM.Agent.Create` applies
`httpLowSpeedTimeSeconds` before catalogue refresh; retain new-session semantics,
zero-disable behavior, and the absence of a total streaming deadline. Headless
control-monitor shutdown accepts Shutdown before Start, including Plain cleanup.
Run `python3 test/tools/check-http-timeout-lifecycle.py` after development builds
for bounded loopback-only subprocess checks. No live-provider or interactive
GUI qualification, installed-binary update, or native-math acceptance is implied.

The preceding 1017/1017 signal/process
record result is historical (`/tmp/coyote-signal-proc-full-final.log`). PCR-118's 1014/1014 result
below is historical (`/tmp/coyote-ownership-full-tests.log`).
Root `alr build --development` and test
`cd test && alr build --development --profiles=coyote=development` passed;
both generated profiles select `development`. PCR-117's 1005/1005 result
below is historical. PCR-118 focused cmark passes 17/17 (three added tests),
renderer 10/10, and the standalone native ownership probe passes 27
assertions. PCR-119 Ada cases ran in the full suite; native detached-spawn checks passed 28 dynamically counted checks in both normal and ASan/UBSan logs.
See `/tmp/coyote-ownership-native-spawn-final.log` and `/tmp/coyote-ownership-native-spawn-asan-final.log`.
PCR-120/121 focused Process-Control passed 7/7 and isolated signal-shutdown
passed 2/2. `test/tools/check-signal-bridge.sh` passed 48 parent fork/wait/status
checks in each strict C11 and ASan/UBSan run across 16 isolated cases; 48 is
not a count of semantic assertions. The harness covers all eight distinct
`fcntl` failure targets, rollback/retry, errno preservation, descriptor leaks,
and 100,000 sequential signal deliveries under saturation. Simultaneous
standard SIGTERM deliveries may coalesce and are not promised to be counted
individually. See `/tmp/coyote-signal-proc-build-final.log`,
`/tmp/coyote-signal-proc-test-build-final.log`,
`/tmp/coyote-signal-proc-focused-final.log`,
`/tmp/coyote-signal-shutdown-focused.log`,
`/tmp/coyote-signal-native-final.log`, and
`/tmp/coyote-signal-proc-full-final.log`. Run the native check with
`sh test/tools/check-signal-bridge.sh` from the repository root.
Help coverage passes 12/12 core and 1/1 display-backed widget tests; Mallard
validation/links and CLI checks pass, with existing GTK theme CSS warnings.
No end-user visual acceptance or live-provider qualification was performed.
PCR-120's fixtures do not test a live process `comm` rename; PID-reuse races
remain. PCR-121 installation is serialized at startup before agent/frontend
tasks; concurrent initialization and thread-safety are not qualified. The
isolated lifecycle worker invokes `Complete_Shutdown` directly after signal
read/`Begin_Shutdown`; it has no registered process groups and does not verify
full-application shutdown or real group cleanup. Real desktop shutdown remains
manual. There is no production reset API. Developer self-evaluation and
read-only review are not independent user acceptance.

Qualified commands: `alr build --development` and `cd test && alr build --development --profiles=coyote=development`; after builds, `xvfb-run -a sh test/check-help.sh` from the
repository root for focused Help, Mallard validation/links, and CLI checks. GUI
activation and actual Yelp navigation remain manual qualification; see PCR-112.
The standalone headless `bin/coyote --help` should exit 0 without leaving a
worker running. The suite uses root AUnit domain suites for Core, LLM, SQC, GUI,
Integration, and Process-Control; live-provider tests remain opt-in and actual
subagent subprocess tests require `COYOTE_TEST_SUBAGENT=1`. PCR-117's dated
1005/1005 result remains historical, as do PCR-114's former-C results.

```sh
cd test && alr build
/usr/bin/time -f 'wall=%e user=%U sys=%S exit=%x' ./bin/coyote_test
```

AUnit filters are literal case-sensitive prefixes, not globs. For example:

```sh
./bin/coyote_test LLM.Compaction
./bin/coyote_test Coyote.GUI.Conversation_Stack
```

An unmatched filter is an error. GUI tests require a display when they create
GTK windows; conversation and queue tests can run without starting a GUI
window. Live provider tests require their documented guard variables and
credentials.

## Subagents

The generated system prompt supplies the absolute, shell-quoted path of the
active coyote executable in its subagent invocation and example. Use that
rendered command rather than assuming that `coyote` is available on `PATH`.

A GUI parent propagates GUI context to ordinary physical-window children. The
implemented virtual-agent-window path launches coordinator `--subagent`
processes through the headless RPC frontend: the main agent and short-lived
subagents appear as virtual windows in an agents tree, and selecting a live
node routes prompts and controls to it. The subagent retains its
initial-prompt, active-steering, final-response, and exit lifecycle; completed
nodes remain reviewable but do not become persistent agents. Session lineage
uses `COYOTE_SESSION_ID` and `COYOTE_PARENT_SESSION`; recursion
is limited by `maxRecursionDepth` and `COYOTE_RECURSION_DEPTH`.


## Latest native-math workspace continuation — 2026-11-15

Use report §11.13 and `plan/evidence/native-math-2026-11-15-workspace-budget/`
for new transient raster reservations, independent protected ledgers, in-place
worker output and scoped peak telemetry. Full1076/1076, worker194/194 twice,
ledger30/30 and raster1116/1116 pass. Strict raster Valgrind still fails with
2 contexts and6656/2183/26-byte losses. Charges end at render completion; GNAT
empty-vector capacity admission is not portable allocator/RSS accounting.
Whole-job parser/layout/native/font/copy/cache accounting, hard timing,
full parity and human acceptance remain open. No release/install/commit.


## Latest native-math parser-budget continuation — 2026-11-15

Use coordinator report §11.14 and
`plan/evidence/native-math-2026-11-15-parser-budget/`. Optional pre-admitted
parser workspace and shared worker phase-peak characterization: full1076/1076;
parser674/674 twice, ledger38/38, worker215/215 three finals plus repeat.
Raster1116/1116 normal/Valgrind, but strict script fails with2 contexts and
6656/2183/26-byte losses; shaped lifecycle teardown leaves possible losses.
This is not whole-job or portable allocator accounting. Memory, timing, font,
parity, lifecycle and human acceptance remain open. No release/install/commit.


## Latest native-math AST node-construction accounting continuation — 2026-11-15

Use coordinator report §11.15 and
`plan/evidence/native-math-2026-11-15-ast-budget/` as the controlling AST
checkpoint. Parser pre-admits old+new Node record arrays from seed32, doubling
through32768, reconciles actual capacity after `Reserve_Capacity`, establishes
reservation ownership before `State`, and moves node/diagnostic returns. The
charge ends at `Parse` return, not retained-node lifetime. Existing worker
Parse/Pipeline peak includes AST; worker job body is unchanged.

Scoped parser688/688 twice; fixture has2049 nodes and peak2,443,968. HEAD
baseline688 assertions with5 expected failures. Worker223/223, ledger38/38,
full1076/1076 (cumulative145.992924s; wall146.26s), GTK9/9, containment and
offline HTTP checks pass. Raster1116/1116 normally and under Valgrind; strict
script FAILS with2 contexts and6656/2183/26-byte losses. Geometry attempt is
BLOCKED: `/tmp/coyote-katex-support-check/package` was absent; this is not a
rerun pass. Browser/resource characterization was not rerun. Existing warnings
remain.

This is scoped transient Node-array accounting, not whole-job accounting.
Nested payload strings, expander/semantics/layout/native/font, allocator
overhead, copies and cache remain unaccounted. Timing, font, parity, lifecycle
and human acceptance gates remain open; self-review is not independent
acceptance. No release/install/commit.


## 2026-11-15 — Array-rule construction accounting (PCR-125)

Report §11.16 and `plan/evidence/native-math-2026-11-15-array-rule-budget/`
control this continuation. A Parse-local reservation aggregates horizontal
rule-vector capacity across arrays and pre-admits old/new growth overlap
(seed4, doubling). Scoped node references avoid copied-node link mutations;
outer node growth reconciles surviving nested-rule capacity. Review caught
first-row linking compacting the vector while leaving spare capacity charged;
in-place linking fixes that drift. References end before polls/outer mutation.
No new units, semantic limits, SRS requirements or deviations were introduced.

Exact-final parser706/706 twice and under Valgrind (zero lost bytes/errors),
full Xvfb1076/1076 (142.388395s cumulative,142.48s wall), worker223/223,
ledger38/38, restored pinned-KaTeX geometry235/235 and required GTK9/9,
containment and offline HTTP checks pass. HEAD comparison fails4 rule-specific
checks. Raster1116/1116 normally/Valgrind, but strict script FAILS with2 contexts
and6656/2183/26-byte losses. Isolated PangoFC per-map shutdown does not remove
fixed native losses and is not a production change. Existing warnings remain.

Rule charges end at Parse return. Nested copies during outer node growth,
other payloads/strings, expander/semantics/layout/native/font, allocator overhead
and returned/cache lifetimes remain unaccounted. Whole-job memory, timing,
font, full parity, native lifecycle and human acceptance gates remain OPEN.
Developer/agent self-review is not independent acceptance. No release/install/
commit; PCR-125 OPEN, feature NOT COMPLETE.


**Next design gate:** Retained ownership assessment identifies a dangling-account
hazard if call-borrowed Parse reservations escape into returned Documents.
`design/native-math-retained-budget-proposal.md` is a DRAFT, NOT APPROVED and
NOT IMPLEMENTED. It recommends stable per-job account ownership and explicit
retained clone/transfer leases while preserving the current Document API
initially. User design review is required before that ownership/API migration.
This is not a claim that all other scoped project work is technically blocked.

## Latest native-math rule-copy accounting continuation — 2026-11-15

Use coordinator report §11.17 and
`plan/evidence/native-math-2026-11-15-rule-copy-budget/`. Before outer
`Nodes.Reserve_Capacity`, Parse pre-admits current aggregate rule capacity plus
all active rule lengths. GNAT15.2 `Adjust` copies vector length, not spare
capacity; scoped `Constant_Reference` scans end before polls/mutation, then
surviving capacity is reconciled. No API, semantic limit, unit, requirement or
deviation changed.

Parser719/719 twice and under Valgrind (zero errors/lost bytes;113248 reachable);
poll-preserving remove-charge mutation719 with5 expected failures. The56-node
fixture has two ordered rules (solid0, dashed1); measured delta24586 versus
node-only24576 (10 bytes). Exact/short budgets use measured boundaries; paired
cancellation/deadline checks share cleanup and preserve two exception
identities. Ledger evidence is not an independent allocator oracle. Full suite
1076/1076, zero failures/errors (cumulative145.197785s; wall145.30s), correctly
run from `cd test`; the wrong-root run is preserved:28 assertion failures,
95 errors,955 successes from relative fixtures. Incremental root/test
development builds pass; warnings remain.

Worker223/223, ledger38/38, geometry235/235, raster1116/1116 normal/Valgrind;
strict raster Valgrind still FAILS (2 contexts;6656 definite,2183 indirect,26
possible bytes). No suppressions/global teardown. GTK9/9; containment expected
synthetic7/9; offline HTTP passes; crosswalk hashes only. Browser/resource
characterization was not rerun. Retained-budget proposal remains NOT APPROVED.
Whole-job memory, strings, expander/semantics/layout/native/font, allocator,
returned/cache lifetime, timing, parity, lifecycle and human acceptance remain
OPEN. Self-review is not independent acceptance. No release/install/commit.

## 2026-11-15 — Resource-abuse scope correction (PCR-125)

The user directed practical protection against abusive/pathological LaTeX and
explicitly authorized the requirements update. SRS-MATH v1.1 supersedes earlier
whole-job accounting completion gates:256 MiB is a coarse admission budget for
tracked major workspace/output buffers and known large overlaps, not an exact
all-allocation or RSS cap. Document guard coverage, estimates and exclusions;
verify hostile-input rejection, cleanup, visible-source fallback and ordinary
request recovery. Source/token/expansion/node/depth/array/command/dimension/
surface limits,64 MiB retained-raster process bound and50/250 ms timing targets
are unchanged. Ordinary ownership safety remains mandatory.

Exhaustive string/native/allocator/copy-lifetime accounting, storage pools and
retained-account leases are not acceptance prerequisites. The retained-budget
proposal is optional historical design exploration, not the required next gate.
Existing implementation and evidence are preserved; no historical failure is
converted to a pass and known native lifecycle failures remain open. Practical
abuse-protection qualification, timing, complete compatibility and independent
human acceptance remain pending. Documentation-only; no builds/tests rerun.
Developer self-review is not independent acceptance. See report §11.18.


## 2026-11-15 — Practical abuse rejection/recovery probes (PCR-125)

Report §11.19 and `plan/evidence/native-math-2026-11-15-abuse-guards/` record
standalone engine174/174 twice, worker279/279 twice, parser719/719 and ledger38/38.
No production source changed. Tests cover structural/expansion rejection,
same-context recovery, invalid scales, Busy retry and repeated raster recovery.
NaN bypass hypothesis did not reproduce: GNAT15.2 validity already rejects it.
Root/test development builds pass; full first1075/1076 socket-bind error remains
recorded, focused1/1 and full repeat1076/1076 pass. GTK9/9, containment and offline
HTTP checks pass. Engine Valgrind with4MiB frame threshold passes zero errors/
lost bytes; initial default-threshold stack-frame failure retained. Existing
raster native losses are not resolved. No complete abuse/timing/parity/GUI/font/
lifecycle or human acceptance qualification; no release/install/commit.


## 2026-11-15 — Accepted memory-guard maintenance policy (PCR-125)

The user accepted the port plan §6 policy: stop extending fine-grained memory
accounting, retain working guards, and simplify selectively for a concrete
maintenance benefit rather than undertake wholesale removal. Preserve scoped
references, reduced deep copies and lifetime/finalization safety independently
of tiny-payload accounting. Keep structural/work limits, coarse major-buffer/
large-overlap admission, the 64 MiB retained-raster bound and rejection/cleanup/
source-fallback/recovery tests. Prefer conservative estimates to exact bytes.
GNAT-specific accounting tests may change with a justified simplification;
safety tests are not weakened merely to pass. Storage pools and retained-account
leases are optional only for demonstrated need; their design is not approved.
No implementation or tests removed; no runtime checks rerun. SRS-MATH v1.1,
numeric/timing targets and known qualification gaps remain unchanged. Report
§11.20 records the decision; product acceptance remains pending.


## 2026-11-15 — Scope admission and macro capture recovery (PCR-125)

Report §11.21 and `plan/evidence/native-math-2026-11-15-scope-cancellation/`
record immediate checked parser scope pushes and clearing Scope_Limit only
on actual undo/pop. Empty/admission failure cannot expand gdef; earlier genuine
global assignments still persist. Cancellable newcommand capture/copy stages
body+default before mutation; no claim of allocation-exception transactionality.
Engine216/216 twice, macros873/873 twice, worker279/279, parser719/719 and full
Xvfb1076/1076 pass; root/test development builds and mandatory GTK9/9,
containment/offline HTTP checks pass. Engine Valgrind zero errors/lost bytes;
whole macro Valgrind timed out before new cases, INCOMPLETE. Existing warnings
and strict raster losses remain. Shared-context cumulative admission needs
separate policy review; no new cap or fine-grained accounting. No full timing/
GUI/font/lifecycle/parity/human qualification, release/install/commit.
