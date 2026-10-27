# Native math compatibility design — SDD-MATH

**Component:** coyote shared math engine and GTK presentation
**Version:** 0.5
**Date:** 2026-10-26
**Change:** PCR-125
**Status:** Approved design and execution basis; implementation and qualification incomplete
**Requirements:** `requirements/native-math-compatibility.md` v1.0 (approved)

## Contents

1. Authority, decisions, and reference
2. Decomposition and interfaces
3. Execution, state, and ownership
4. Typography and native presentation
5. Resources, scheduling, and security
6. P1 differential harness and migration
7. Affected sites and requirements traceability
8. Evaluation, risks, and review gate

## 1. Authority, decisions, and reference

The user approved the phased native-port plan and compatibility requirements
on 2026-10-24, then explicitly approved this native design and continued P0–P6
execution on 2026-10-25. This version records design approval and authorization
to continue implementation and qualification; it does not record an achieved
compatibility result or product acceptance. The approved target is KaTeX 0.16.22
core mathematical behavior in the finite native/untrusted profile, with
individually approved D01–D15 deviations. General trusted browser/API behavior
is not silently reintroduced. Requirements resource budgets are normative
targets; whole-job allocator/memory instrumentation, visual calibration and
final test readiness remain open. The current project is NOT COMPLETE.
Implemented source ledgers and deadline checks do not bound all REQ-MATH-010
allocations or preempt blocking native calls. Do not wait for another P1
approval to continue the already approved execution, do not mark P1–P6 complete,
and do not claim full KaTeX parity or acceptance. Current results and open
blockers are recorded in
`plan/native-math-parity-test-report.md`.

References: SRS-MATH above; `design/coyote-design.md`; approved
`plan/native-math-parity-plan.md`; updated combined STP/STD v0.5 (readiness review and approval open)
`plan/native-math-compatibility-tests.md`; generated pinned inventory;
`share/coyote/math/PROVENANCE.md`; current `src/coyote_math/` interfaces.
KaTeX Parser/Lexer/MacroExpander/Namespace/Options/Style, registered functions and
environments, delimiter/stretchy/SVG and font data are reference inputs. Their
hashes/notices are retained. This is a behavioral port, not a browser engine or
wholesale translation of markup serialization.

Primary decisions:

- Typed tokens and parser-driven expansion replace direct string command scanning.
- Syntax, visual layout, and semantic content are distinct immutable products.
- Job-local bounded arenas own data; no source pointers or mutable macro tables
  are borrowed across task or GUI lifetimes.
- Shared macro contexts are explicit and serialized; publication follows reference
  namespace semantics, not visual success or an assumed all-error rollback.
- Two native workers perform bounded computation and offscreen painting with
  isolated font/Cairo state. GTK widget updates and final composition remain on
  the GTK main task. Worker/native-library feasibility must be qualified.
- P1 first adds development-only exports and comparisons around the existing
  engine. It does not prematurely switch production APIs or mark gaps as passes.

## 2. Decomposition and interfaces

Names below are proposed software units, not files that already exist. Existing
package names are retained where practical; exact Ada specifications are a
per-increment detailed-design artifact before code edits.

| Unit | Role, data, and dependencies |
|---|---|
| `Math_Limits` | Validated profile/budget values, checked allocation ledger, deadline/cancellation token, work checkpoints; no GTK/Cairo |
| `Math_Source` | Owned UTF-8 source, scalar decoding, byte/scalar/UTF-16 offset map and expansion-origin chains; no lossy normalization of original source |
| `Math_Tokens` | Lexer/token IDs, typed control words/symbols/chars/space/group/parameter tokens with source spans; depends on Source/Limits |
| `Math_Registry` | Versioned command/environment/symbol/macro metadata with dispatch IDs and modes; data generation only for safely representable tables, hand-ported handlers for behavior |
| `Math_Macros` | Text/token macro definitions, namespaces and undo stack, parameter metadata, bounded global mutation journal and caller-owned context handle |
| `Math_Expander` | Parser-driven token stream, arguments, lookahead/pushback, expansion/suppression/control logic; depends on Tokens/Registry/Macros/Limits |
| `Math_Model` | IDs and typed structural payloads for syntax families, including mathchoice branches and generalized-fraction rule parameters; styles, annotations and source links; no GUI-owned or callback pointers |
| `Math_Syntax` | Token-driven parsing and function/environment handlers, tree and diagnostics; preserves grouped structure rather than lowering everything to glyphs |
| `Math_Semantics` | Structured native math tree: fractions, scripts, roots, operators, rows/cells, annotations, and dual visual/semantic branches; source-linked |
| `Math_Metrics` / `Coyote_Math_Resources` | All required pinned font faces/metrics including skew; manifest, missing-glyph diagnostics, trusted asset resolution |
| `Math_Layout` | Full style/options context, spacing/box algorithms, extensible assemblies and draw list; depends on model/metrics/limits, not GTK |
| `Math_Draw` | Backend-independent glyph-run/rule/path/clip/color commands, affine transforms, boxes and semantic-source associations; validated finite geometry |
| `Math_Painter` | Cairo/FreeType path/glyph/rule painting from validated lists; worker-local font state; no widget mutation or formula-controlled resource lookup |
| `Math_Engine` | Request/result facade, semantic/visual products, phase diagnostics and context journal; synchronous headless entry for tests/Plain support |
| `Coyote_Math_Jobs` | Two worker slots, bounded pending/result queues, context-order serialization, cancellation and generation-tagged completion; no GTK access |
| `Coyote_GUI.Math_Element` / `Rich_Text` | GTK-owned fallback, marks, inline installation, display tiles and semantics/accessibility adapter; poll/adopt job results |

No mutable process-global macros. Read-only generated tables are shared. A
limited controlled result handle owns arenas/draw data with explicit retention
and finalization; queue transfer is ownership transfer, not accidental deep
copy. Headless consumers use the same engine, not a second port implementation.

### 2.1 Request/result contract

Request fields: request/formula/view-generation IDs; source plus exact delimited
source reference; inline/display style; scalar options; font/profile revision;
em size and foreground; monotonic submission/deadline; job budget; optional
explicit context handle/epoch; operation kind (evaluate or repaint committed
result). Text definitions are copied/owned token sequences, not JS callbacks.

Result fields: request/generation IDs; status (complete, parse/strict error,
resource/font/layout failure, cancelled, stale); diagnostics vector with severity,
category, native-byte span and reference-position mapping; syntax/semantic tree;
validated draw/box data and dimensions; context publication receipt; budget and
phase timings. Trust refusal can occur inside otherwise valid output: preserve
its diagnostic and reference-visible command representation, not a fatal unknown
command. `throwOnError=false` permits reference error fragments/full error output,
not successful presentation of an arbitrary partial parse.

Read-only accessors never expose reallocatable internal storage. Invalid or
incomplete visual results have no installable successful draw product. Diagnostic
source spans from macro expansion include original call-site and definition
origin; snapshot output records raw reference offsets and translated native
byte positions, avoiding UTF-8/JavaScript UTF-16 confusion.

## 3. Execution, state, and ownership

### 3.1 Independent evaluation

Validate options and admission; create fresh context by default. Decode source,
lex/expand/parse under budgets; unwind local groups on all exits; produce semantic
and visual branches; build layout and paint needed output; post an immutable
result. The GUI keeps source visible until successful current-generation result
installation. A diagnostic/refusal is not conflated with resource failure.

A repaint uses a committed result and new em/color/theme parameters. It cannot
run macro definitions again. If an immutable document must be rebuilt, use the
captured pre-evaluation context snapshot read-only, never the live post-state.
No shared context is created implicitly by a Markdown block or saved session.

### 3.2 Shared contexts and error behavior

Caller creates an explicit context identified by owner/session/agent and epoch.
Only one evaluation per context executes at a time; unrelated contexts can use
the other worker. A request stages a private namespace and mutation journal from
a stable snapshot. Nested local definitions restore using undo records. Global
assignments update the staged global state and remain eligible for publication
even if later parsing fails. With `globalGroup=true`, eligible top-level local
assignments also remain, as in the reference.

Reference exploration on KaTeX 0.16.22 confirmed:

| Sequence, shared macro object | Post-request definition |
|---|---|
| `\gdef\foo{A}\bogus`, default grouping | `\foo` remains A despite parse error |
| `\def\foo{A}\bogus`, default grouping | `\foo` absent after unwind |
| `{\def\foo{B}}\bogus` | Nested definition absent |
| `\def\foo{A}\bogus`, globalGroup=true | `\foo` remains A |
| `\gdef\foo{A}\frac` | `\foo` remains A despite missing argument |

These are reference-only exploratory observations, not native qualification.
P1 adds frozen state-sequence fixtures. Publish eligible namespace changes once
at parser terminal cleanup, including reference parse/strictness errors. A later
layout/font/painter failure does not roll back already completed namespace
semantics; reference parsing precedes output building too. Policy refusal under
trust=false does not erase unrelated definitions.

Cancellation before parsing has no mutations. During parsing, unwind local
scopes and publish the eligible journal executed before the cooperative checkpoint
unless the caller reset/destroyed the context epoch; cancellation/resource-limit
semantics are native safety behavior, not a claimed reference cancellation API.
Context reset invalidates pending requests and their journals before accepting
new work. An old-epoch completion cannot publish after reset. Surface stale-view
handling is independent of context execution: visual cancellation after semantic
completion must not apply the journal twice or undo a completed evaluation.
Publication uses a single protected coordinator with per-context epoch/revision
and per-request state: Queued → Executing → Publishing → Semantic_Done →
Visual_Done (or Failed/Cancelled). Cancel/reset and entering Publishing are
serialized by that coordinator. A cancellation ordered before Publishing fixes
the executed-prefix journal at the next checkpoint; no later token executes.
Local groups unwind, then the eligible prefix publishes exactly once if the
context epoch still matches. A cancellation ordered after Publishing preserves
the completed journal and cancels only remaining visual work. Parse/strictness
errors publish eligible globals after local cleanup; parser resource failure
publishes only its executed prefix, with native-limit diagnostic. Layout/font/
paint failures preserve already published semantics. Admission/queued cancellation
has an empty journal. Reset/destruction increments epoch and invalidates every
unpublished old-epoch journal, regardless of cancellation order. Publication and
revision/epoch validation are one atomic operation; immutable precharged state
swaps under the lock, and old storage is reclaimed outside it. A reset cannot
interleave with that atomic swap. Request/context/epoch/revision receipts make
retries, stale views and duplicate completion idempotent. No expansion or native
library call occurs inside protected operations.

Deterministic barrier tests pause before/inside/after publication, before/after
cancel, and across reset; assert each outcome and context revision. Timing-only
race tests are supplemental, not the sole evidence. These cancellation rules are
native safety semantics, not a new claim about a reference cancellation API.

### 3.3 Exceptions and lifecycle

Every worker boundary catches exceptions, converts an owned diagnostic/result,
releases arenas/native surfaces/context tickets and signals completion. Limited
owners finalize in reverse dependency order. No Ada task abort is used to stop a
Cairo/FreeType call. A native call that overruns its deadline fails the latency
requirement even if cancellation is observed after it returns. Shutdown rejects new submissions, flags cancellation, drains
results and joins workers through the application shutdown lifecycle; GTK objects
are destroyed only on the main task. New job lifecycle integration must not
introduce a shutdown wait that relies on GTK callbacks after the loop stops.

## 4. Typography and native presentation

Port the reference's eight math styles (display/text/script/scriptscript and
cramped variants), font/size/color/atom-class contexts, metric corrections,
spacing, line and array boxes, tag placement, explicit dimensions and complete
registered handler semantics. Arrays get typed column descriptors, row rules,
gaps and alignment rather than a single generic grid. Operators retain complete
word runs; accents retain base and mark/assembly metadata.

Extensible delimiters/radicals/arrows/braces use pinned assembly and SVG/path
geometry, not raster scaling of the largest available glyph. Draw commands add
filled/stroked paths, color, clip and transform with checked finite coordinates.
Generated data carries upstream source hash and notices; algorithms are reviewed
ports. Full font-face inventory is packaged as needed; fallback shaping for
reference-supported text scripts uses a worker-local Pango font map/context and
explicit pinned fallback faces. Pango is already a GUI dependency, but the new
headless/shaping boundary and thread safety must be qualified before adoption.
Unknown or unpinned fallback in fixtures blocks comparison; it is not a pass.
Worker backend is conditional on a native safety prototype: each worker creates
its own FT_Library/FT_Face, Cairo font faces/image surfaces, and
pango_cairo_font_map_new font map; use pango_font_map_create_context and local
pango_layout_new/shaping operations only on that owning worker. Never call
pango_cairo_font_map_get_default, borrow a widget's Get_Pango_Context, or transfer
mutable FT/Pango objects between workers/GTK. Freeze worker font configuration
before tasks start; audit underlying Fontconfig initialization and global caches.
Release layouts/contexts/font maps/surfaces/faces on the owning worker in reverse
order (Cairo references retain required FT owners). Only immutable geometry or
completed immutable pixel bytes transfer to GTK; pixbuf/widget adoption occurs
there. Prototype concurrent load/shape/paint, missing-font/allocation failure,
reset/cancellation and shutdown under native ownership tools before P5 selection.
If those APIs cannot be safely isolated on the platform, return to design review
for a serialized native backend; do not silently move unbounded shaping to GTK.

`\html@mathml` keeps distinct branches: use its HTML branch for native visuals,
and its semantic branch for accessible structure. No MathML parser/legacy
renderer or XML serialization is added. Untrusted HTML/link/image constructs
produce the reference's validated refused representation; no renderer interprets
arbitrary formula-provided CSS, filenames, URIs, or scripts.

GTK adapter creates accessible math containers and navigable child structures
for fractions, scripts, roots and array cells, with exact source available as
text. Native roles/state/reading order are tested with named AT-SPI desktop tools;
plain alternative text alone cannot close REQ-MATH-012. Precise GTK3 role/AT-SPI
mapping requires a P5 prototype and user demonstration, not an assumed browser
MathML equivalence. No trusted active links are introduced under D04–D05.

### 4.1 Inline and display adoption

Each formula state stores stable source/image marks, logical formula ID, current
generation, pending ticket and committed result handle. Source remains intact
for copying. Reflow increments presentation generation, cancels obsolete paint,
and repaints committed structure without executing macros. Completion validates
buffer identity, live marks, exact source, owning session/agent and generation
before hiding source/inserting pixbuf or replacing display content. Stale results
are released without widget access; raw widget pointers never cross to workers.

Inline surfaces respect final 2000×512 including padding. Display widgets paint
bounded raster tiles prepared offscreen: main-task On_Draw only composites ready
visible tiles and requests missing ones, not the full math draw list. Layout and
complete draw product are committed before visibility. Large displays use viewport
tiling/eviction within the 64 MiB retained-raster budget; pending regions remain
explicitly pending, never accepted as a fully painted qualification artifact.
Tiles are at most 256×256 pixels; workers shape/paint them offscreen under the
owning request's deadline. Each initial visible tile set plus GTK adoption is
part of initial job completion: Semantic_Done/Layout_Done alone is not visible
completion. A scrolled-in tile/repaint is a new bounded presentation request
using immutable layout (no expansion/state effect) with its own submission time.
At expiry cancel incomplete tiles, retain/reveal exact source fallback and report
failure; do not leave absent regions indefinitely or report them successful.
Main-task completion pumps use a 5 ms soft quantum, at most eight tile/adoption
operations per batch and a measured ≤50 ms hard slice; deferred work keeps the
original 250 ms request deadline, not a reset clock. Native Cairo compositing
and GTK adoption can exceed a soft quantum and must be measured. Results are
complete only when required visible tiles are installed; full-image acceptance
requires every tile, not merely the viewport. Queue wait, worker tile generation,
postback delay, adoption/composition and cleanup are recorded separately. Deadline
failure is a real test failure when a successful in-domain case should complete.
Full-image headless
qualification can allocate a temporary bounded surface under the job budget,
then release it rather than retain it in the GUI cache. Tiles do not relax visual
acceptance or permit dropped content. Composite/update batches are time-sliced.

## 5. Resources, scheduling, and security

Use checked capacities and IDs, bounded arenas for tokens/nodes/journals and draw
payload, and charged surface stride × height. Container growth must charge new
capacity while old storage still exists, then release old charge; estimates of
logical length alone are insufficient. Native temporary buffers and Pango/Cairo
objects are charged conservatively and checked against isolated peak RSS during
qualification. Font caches/source retention are reported separately as required;
this is not permission to hide per-job buffers there. Shared contexts have an additional process-wide retained-storage ledger:
propose at most 16 live explicit contexts and 64 MiB total context/snapshot/
journal retention, with ≤4 MiB committed definitions per context and the SRS
token/node ceilings. These are **proposed additional shared-context admission boundaries**, not
approved SRS limits or reasons to reject an approved in-domain request. Decision
RD-CTX-01 must be explicitly dispositioned at requirements review before P3
shared-context implementation: approve the caps and resource-rejection behavior
as a bounded-context requirement, or redesign admission without narrowing
REQ-MATH-003. Design approval alone does not authorize those rejections. P1
exports and measurements do not depend on selecting these values. Before cloning/staging a shared context reserve
both the job and global retained-storage charges; in-flight copies count in
both ledgers where applicable, not just logical committed bytes. If RD-CTX-01 is approved, reject new
contexts/requests explicitly on capacity exhaustion; never evict live definitions
silently. Reset releases definitions after outstanding handles drain; destruction
invalidates epochs/cancels queued work and releases storage after worker tickets
return. Completed contexts remain charged until explicit release/session teardown;
no hidden process-global macro cache. All charged ownership transfers and old
snapshot reclamation are tested at exhaustion and teardown. Native allocator/
font-cache measurements still need qualification; ledger values are not RSS.

Job caps are the SRS values, not current constants: source 65536 bytes, emitted
tokens 131072, expansion default 1000/configurable ≤10000, nodes 32768, argument
depth 128, arrays ≤64×64, layout depth 256, draw commands 131072, calculated
extent ≤16384 em and user maxSize=100 em baseline. Additional job memory ≤256 MiB;
retained rasters ≤64 MiB/process; final surfaces inline 2000×512/display 8192×4096.
All bounds apply conjunctively. A large accepted layout is not automatically a
permitted giant persistent raster; 8192×4096 ARGB32 alone is 128 MiB.

Propose two workers and eight pending job descriptors with byte-charged request
payloads; admission is nonblocking. Queue-full rejection is explicit resource
failure with source fallback, not a formula syntax error or a successful pass.
Deadline begins at submission, including waiting behind the same shared context.
Reject expired pending work without parsing. Cooperative checkpoints occur in
lex/expand, node creation, layout traversals, path generation and tile drawing;
checkpoint cadence is profiled, not assumed to bound native-library calls.
Each job must complete/reject and clean up within 250 ms on the named workstation;
p95 for the frozen warm representative corpus ≤50 ms. Every GTK math work slice
is ≤50 ms. Avoid scheduling a monolithic full-surface paint on the GTK task.

These latency limits are **unproven feasibility risks**. Whole native calls,
large finalization, memory contention and slow font loads can violate them.
P1 measures baseline and P2/P3 scheduling pilots must demonstrate worst-case
cleanup and bounded callbacks. If they cannot meet the approved limits, return
to requirements review; do not quietly redefine completion as dispatch only,
kill a worker as a pass, or drop within-domain features to meet timing. Measure
queueing/compute/publication/painting/adoption/cleanup separately. Admission and
cache policy must not bias the measured corpus to hide expensive successes.

Formula data has no filesystem/network/process authority. Known bundled font
reads and native runtime housekeeping are allowlisted separately in security
traces. Asset resolution uses static manifest IDs, never macro-derived paths.
Color/dimension/URI argument validation is typed and checked; trust stays false,
strictness and throwOnError remain distinct. All job controls and identities
are native data, never function-valued JavaScript callbacks.

## 6. P1 differential harness and migration

### 6.1 P1 deliverables and schema

Development-only proposed files: `test/fixtures/math-compatibility/pilot.json`,
`test/tools/math_export.adb`, `test/tools/export-math-reference.cjs`,
`test/tools/compare-math-layout.cjs`, and `test/tools/check-math-differential.sh`.
These names/interfaces are design proposals, not existing runnable tools.
Use the current standalone GPR pattern (`test/native/native_math.gpr`) for a
separate exporter main; do not change production algorithms just to pass P1.
Register new units and commands when actually added.

Pilot rows contain stable ID, exact formula bytes or JSON string (UTF-8 LF),
source/delimited-source separation, profile/options, mode, shared-context sequence,
inventory/requirement links and expected reference outcome. Include heat-balance,
`x`, scripts, fraction, radical, complete named operators, array, stretch/path,
Unicode, error, trust refusal and macro-on-error sequences. A baseline missing
native feature stays missing/partial rather than invalidating the harness.

Snapshot envelope: schema version; engine/build/environment; version and
archive/bundle/font/source/corpus/config hashes; case ID and context sequence;
original source; raw and normalized outcome/diagnostics/positions; optional
syntax/semantic records; boxes, glyph runs/origins/font/size/italic/skew, rules,
paths/assemblies, baseline and metrics; budgets/timings; comparison capability
flags. Missing export capability is explicit unsupported-export, not empty
valid geometry. Document reference DOM/CSS/SVG coordinate reconstruction and
reference-internal tree API pin; mark private API drift as tool failure.

P1 native adapter exports existing documents/commands without pretending they
already expose full semantics/path/color. Reference exporter verifies provenance,
uses isolated macro state or explicit shared object by case sequence, captures
warnings/errors/UTF-16 offsets, parse structure and HTML visual tree. Normalize
units/styles/position transforms according to a written mapping; raw tree and
normalized exports are both retained. Compare matching semantic constructs, not
DOM-child indices. For reference quantities inaccessible in the tree use pinned
browser measurements with uncertainty; unavailable quantities remain blocked.

Comparator never treats absent fields/records as matching empty data. Validate
schema, input identity, units and mappings first; then outcomes, semantic content,
metrics and matched components. Missing native structure/export yields gap or
blocked, not pass. Report per-assertion result and inventory disposition separately;
a test-run fail does not silently change an inventory item's reviewed status.
P1 deliberate omitted/accent/shift/path/color/hash negative controls must fail.
Geometry target is ≤0.01 em; image masks/colors/component rules follow the approved
SRS, with frozen calibration fixtures and explicit test-readiness approval before
visual acceptance. P1 can be accepted as a functioning harness while product
cases fail, but cannot be called a passing parity suite.

### 6.2 Migration sequence

P1 adds exports/corpus/comparison tooling and tests only. Take a fresh development
baseline before production edits. P2 pilot updates common notation within reviewed
model boundaries, with focused differential evidence and effort accounting.
P3 installs source/tokens/expansion/context infrastructure behind reviewed facade;
P4 extends complete typography/fonts/draw semantics; P5 installs job scheduling,
GTK adoption and accessibility. Scheduling/resource prototypes may run earlier
as isolated design feasibility work after approval. Each increment's detailed
interfaces, mutation semantics and affected callers are reviewed before edits;
this high-level design is not a substitute for that mapping.

Do not maintain a second fallback parser that silently changes behavior. Migrate
public APIs and callers coherently; remove superseded scanner/model paths once
their replacements are qualified. Preserve original-source fallback, not an
unqualified legacy typesetter. Final P6 reconciliation includes all required core
items, approved deviations, security/resource/GUI/fuzz and human review evidence.

## 7. Affected sites and requirements traceability

Current sites mapped for later implementation; this design makes no source edits:

| Site | Containing scope and planned treatment |
|---|---|
| `src/coyote_math/math_syntax.ads/.adb` | `Parse`, `Parse_Atom`, `Parse_Array`, `Parse_Expression`, `Document`/`Node`; replace direct scanner and extend ownership/diagnostics via reviewed facade |
| `src/coyote_math/math_model.ads` | Node/style/font enums; expand typed structure, do not reuse fields across unrelated scopes |
| `src/coyote_math/math_layout.ads/.adb` | `Build`, `Compose*`, `Box`/`Draw_Command`; preserve headless behavior while adding draw/geometry exports and complete typesetting |
| `src/coyote_math/math_metrics.ads/.adb` and `tools/generate_metrics.py` | Glyph metrics and generation, skew/font coverage; reproducible pinned data |
| `src/coyote_math/math_radical_paths.ads/.adb` and `tools/generate_math_radical_paths.py` | Pinned radical path templates; dedicated verified generator |
| `src/coyote_math/math_painter.ads/.adb` | `Load`, `Draw`, font owner/finalization; isolated per-worker faces and paths/tiles |
| `src/coyote_gui/coyote_gui-math_element.ads/.adb` | `Measure`, `Render_Inline`, `Create`, `Set_LaTeX`, `Set_Scale`, `On_Draw`, `Detach`/`Free`; replace synchronous parse/paint with ticket/result adoption |
| `src/coyote_gui/coyote_gui-rich_text.adb` | `Formula_State`, `Render_Formula`, `Insert`, `Reflow`, mark/copy/removal lifecycle; preserve exact source and use generations |
| `src/coyote_gui/coyote_gui-conversation_stack.adb` | `Add_Response_Math`, `Build_Response_Elements`, view reset/clear/teardown; own cancellation and source fallback |
| `src/coyote_renderer/coyote_renderer-math.ads/.adb` | Keep Markdown extraction contract; carry stable source identities, no TeX expansion here |
| Tests/probes | `test/src/coyote_math_tests.ads/.adb`, `test/src/coyote_gui_conversation_stack_tests.ads/.adb`, `test/src/coyote_gui-math_element-testing.ads/.adb`, `test/src/coyote_cmark_tests.ads/.adb`, `test/src/test_core_suite.adb`, `test/tools/math_probe.adb`, `test/native/native_math.gpr`; add focused cases/export main and preserve existing suites |

New core unit dependencies are acyclic: source/limits → tokens/registry/macros →
expander/syntax/model → semantics/layout/draw → painter/engine → jobs → GTK adapter.
Model IDs/diagnostic types sit below Syntax to avoid a Model↔Syntax dependency.
Exact engine/job initialization hooks and application shutdown scopes must be
mapped in the scheduling increment before adding tasks.

| Requirement | Proposed implementing units / verification |
|---|---|
| REQ-MATH-001 | Registry, inventory + corpus manifests / MATH-INV |
| REQ-MATH-002 | Source/Tokens/Expander/Macros/Syntax / MATH-PARSE |
| REQ-MATH-003 | Macros/Engine/Jobs/GUI result identity / MATH-STATE |
| REQ-MATH-004 | Source/Registry/Metrics/shaping/Layout / MATH-UNICODE |
| REQ-MATH-005 | Metrics/Model/Layout/Draw/Painter / MATH-LAYOUT, MATH-DIFF |
| REQ-MATH-006 | Registry/Syntax/Model/Layout/Semantics / MATH-CONSTRUCT |
| REQ-MATH-007 | Limits/options/Engine and registry handlers / MATH-OPTIONS |
| REQ-MATH-008 | Source/Engine diagnostics and GTK fallback / MATH-ERROR |
| REQ-MATH-009 | Registry handlers, resource resolver, Engine / MATH-TRUST |
| REQ-MATH-010 | Limits/Engine/Jobs/Painter/cache / MATH-LIMIT |
| REQ-MATH-011 | Jobs/Math_Element/Rich_Text/Conversation_Stack / MATH-GUI |
| REQ-MATH-012 | Semantics + GTK accessibility adapter / MATH-A11Y |
| REQ-MATH-013 | Exporters/corpus/comparator + engine read-only accessors / MATH-DIFF |
| REQ-MATH-014 | All units and integration/lifecycle tests / MATH-REGRESS |
| REQ-MATH-015 | Generator/resources/provenance and license records / MATH-PROVENANCE |

## 8. Evaluation, risks, and review gate

Developer evaluation: the approved design covers the approved requirement IDs
and preserves explicitly approved deviations. Shared-state cleanup follows
inspected reference behavior; GUI lifetimes and ownership transfers are
specified. Proposed tool paths and interfaces remain proposals unless separately
implemented. Frozen and subsequent candidate evidence are distinguished below.
The latest known full suite passed 1061/1061 in 82.378580 seconds
(`/tmp/coyote-completion-final2-full.log`) before subsequent genfrac,
mathchoice, color and minRule edits; a full integration rerun remains required.
The later geometry run passed 145/145 (`/tmp/coyote-fraction-final145-r8.log`),
resolving all seven earlier geometry failures. The frozen geometry, structured
and image checks are separate evidence classes. The structured pilot alone
uses a 0.01 normalized-unit path comparison, not em-unit path positioning; full
reference origins, widths and option effects remain unmeasured. Generic fraction/infix/cfrac, mathchoice and hbox fields are
implemented but require full integration rerun. Latest engine color-candidate
validation aborted; the earlier 40/41 default-color result preceded that
candidate, so no current color pass is claimed. Coverage counts are being
regenerated; use the coordinator-owned report/map rather than historical totals.
Trust=false is the enforced default; trust=true and fleqn are explicitly
rejected. Whole-job memory, deadline and GTK guarantees remain unqualified:
resource test10 peak RSS 44,644 KiB is not whole-job memory, and display64 is a
ledger, not process-inline measurement. P1 readiness, resource/GUI evidence,
qualification and human acceptance remain open; no parity or acceptance claim.

Risks requiring later evidence: worker-local native font/shaping thread safety,
worst-case native-call latency and cleanup, bounded publication, context aggregate
retention, exact full reference geometry export, GTK3 semantic role mapping and
human screen-reader navigation. These require prototypes/measurements, not an
unsupported feasibility assurance. Quantitative target changes require a new
requirements review. Schedule remains unestimated until inventory and pilot work
are measured.

RD-CTX-01 remains unauthorized; proposed additional shared-context caps are not
approved SRS limits or acceptance criteria. This open disposition does not pause
the already-approved P0–P6 execution and is not grounds for an approval-wait
loop. Continue to meet approved requirements without narrowing in-domain
behavior unless requirements are explicitly changed.

## Approval and execution status (updated 2026-10-26)

The user approved design version 0.3 and authorized continued P0–P6
implementation and qualification on 2026-10-25. This supersedes the preceding
historical request for approval and the statement that P1 may start only after
approval. No further design-approval wait is required: continue the already
approved execution and do not create an approval-wait loop. This authorization
is not acceptance and does not make any P1–P6 phase complete.

The latest completed full development-suite checkpoint passed 1061/1061 in
82.378580 seconds, after the original accent fixes but before later generalized
fractions, mathchoice, minimum-rule and color-scope candidate edits. Later
focused geometry passed 145/145; frozen structured/image pilots passed 16/16
and 3/3. A full latest-source rerun remains required. Current regenerated
coverage is a source crosswalk with no qualified rows, not completion evidence.
Resource/GTK, readiness and human acceptance gates remain open; see
`plan/native-math-parity-test-report.md` §8 for exact snapshot boundaries.
RD-CTX-01 additional context caps remain unauthorized. Do not claim full KaTeX
parity, project completion, or product acceptance.
