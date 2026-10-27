# Native KaTeX compatibility-port plan — coyote

**Version:** 0.5
**Date:** 2026-10-26
**Change:** PCR-125
**Status:** Native design and project execution approved; implementation in
progress; P1 readiness and final qualification pending. No full parity claim.

## Contents

1. Purpose and authority
2. Proposed compatibility contract
3. Work products and process
4. Increments and gates
5. Qualification strategy
6. Resources, risks, and maintenance
7. Review decisions and status

## 1. Purpose and authority

The user selected the native route toward KaTeX parity after reviewing the
limits of the current common-math engine. The approved plan defines a versioned
compatibility port in Ada 2022 with native Cairo/FreeType painting. It does not
authorize a browser or JavaScript production runtime, restore the retired
MathML renderer, or claim that parity has already been achieved.

This is a software-only extension of coyote, governed by
[the project plan](project-plan.md). It expands the scope of PCR-123; the
`requirements/native-math-compatibility.md` v1.0 is the approved target annex.
The running product remains the bounded profile until implementation is
qualified. Plan, requirements, design, execution and approval records are in
place; test-readiness approval and final qualification remain open. Exploratory
and scoped checks are not acceptance results.

References:

- `requirements/coyote-requirements.md`: §3.1.4a, REQ-CORE-111, REQ-CORE-124.
- `design/coyote-design.md`: native math architecture and unit inventory.
- `plan/test-plan.md`: math coverage and manual display demonstrations.
- `plan/native-math-test-report.md`: PCR-123 evidence and limitations.
- `share/coyote/math/README.md`: currently supported profile and bounds.
- `share/coyote/math/PROVENANCE.md`: pinned upstream archive and licenses.
- `test/tools/check-math-reference.cjs`: current narrow development oracle.
- `sdfs/frontends.md`: implementation rationale and development history.

## 2. Proposed compatibility contract

This section records planning proposals subsequently approved in SRS-MATH
v1.0 on 2026-10-24. The annex governs the precise profile, D01–D15 deviations
and resource targets; design/test readiness and visual calibration remain open.

- Pin the initial reference to **KaTeX 0.16.22**, using the recorded archive hash.
  Upstream upgrades are separately assessed changes, not an automatically
  moving target.
- Inventory all core commands, environments, built-in macros, user-macro
  behavior, supported Unicode input, options, and error behavior. Account for
  every item as implemented, missing, not applicable to the agreed native
  interface, or an explicitly approved deviation. Missing features are not
  silently removed from the denominator.
- Target equivalent mathematical behavior and native typesetting. Byte-identical
  HTML/CSS/MathML serialization and a JavaScript API are not proposed deliverables.
  Browser-related commands still need explicit item-by-item disposition; links,
  colors, images, and annotations must not disappear under a general exclusion.
- Propose untrusted input as the default (`trust: false` reference policy).
  Specify display/text mode, strictness, errors, macro state lifetime, sizing,
  and expansion budgets in the reviewed requirements. If trusted features or
  additional option profiles are excluded, label the result profile parity,
  not unrestricted KaTeX parity.
- Preserve visible original-source fallback on parse, layout, resource, or font
  failure. Preserve Markdown code protection, copying, zoom, inline baselines,
  display presentation, and current local-image behavior in surrounding prose.
- Define a shared finite qualification domain for size, depth, expansion count,
  and geometry. The original 4096-byte/2048-node/32-level/32-row-column
  profile was the starting point; current parser limits are 65536 bytes,
  32768 nodes, 128 argument levels and 64 rows/columns. Layout and whole-job
  limits still differ from approved targets; see the current profile guide.
  Record limit-induced
  differences and approve any limit changes explicitly.
- Accessibility, semantic structure, selection, clipboard behavior, and GUI
  interaction require native equivalents and separate acceptance criteria.
  Raster resemblance alone does not establish presentation parity.
- General LaTeX package loading and behavior not provided by the pinned KaTeX
  core are not the target. Assess optional upstream extensions separately.

## 3. Work products and process

Use evolutionary increments with explicit compatibility and regression gates.
The developer owns design, implementation, testing, documentation, risk tracking,
and corrective action; the user approves scope and reviews acceptance results.

| Activity | Approach and records |
|---|---|
| Planning and oversight | This addendum; review at each gate; re-estimate after the inventory and pilot |
| Requirements | Update SRS with IDs, source objectives, verification methods, option profiles, and limits; obtain approval |
| Design | Update SDD architecture, interfaces, error/lifecycle rules, new-unit inventory, and requirement traceability; obtain approval |
| Implementation/unit test | Ada 2022 and existing development conventions; map affected declarations, callers, tests, and ownership before edits |
| Integration | Integrate each slice with the shared engine and GTK frontend; retain Plain behavior and source fallback |
| Qualification | Update Test Plan; add concrete case descriptions, fixtures, reference exports, and versioned reports |
| Configuration control | PCR-125 and follow-up defect entries; preserve unrelated changes; upstream hashes and license notices retained |
| Evaluation and QA | Self-evaluate against scope, traceability, reproducibility, and resource safety; record limitations and read-only review findings |
| Corrective action | Classify discrepancies by category and priority in `plan/problems.md`; do not hide failures as oracle changes |
| Joint reviews | Plan, requirements, design/test readiness, increment results, final acceptance |
| Security | Treat formulas as untrusted; budget expansion/allocation/work; deny incidental network/file/HTML execution |
| Maintenance | Record algorithms, generated data, commands, results, limitations, and upstream-drift procedure in SDD/SDF/provenance |
| Process improvement | Retrospective and proposed plan adjustments after each increment |

System analysis/design are folded into software activities as in the governing
plan. Hardware integration is not applicable. Installation at external sites,
formal training, and transition to another maintenance team remain deferred.
No new implementation language or runtime dependency is assumed authorized.
JavaScript/Node and a reference browser are development-only oracle tools;
any additional test tooling is documented before adoption.

## 4. Increments and gates

Milestones are dependency-ordered, not calendar commitments. Requirements and
design reviews apply to each increment's scope; later discoveries return to
change review instead of silently expanding the work.

| Increment | Work and deliverables | Exit gate |
|---|---|---|
| P0 — Contract and inventory | Version/option matrix; full upstream feature inventory; finite domain; performance envelope; native output/security decisions; approved SRS and traceability | Completed: approved target/profile and unresolved boundaries recorded |
| P1 — Differential foundation | Native machine-readable layout exports; pinned reference exports; fixtures including the reported heat-balance equation; baseline gap report and automated comparison tooling | Reproducible reports distinguishing pass, fail, unimplemented, and approved deviation; no claim of current parity |
| P2 — Common-notation pilot | Derivative accents, common relations/functions/styles and annotations; correct full-word `lim`/`max`/`min` behavior; necessary model/font changes | Focused differential and GUI regressions pass; re-estimate remaining work using measured pilot effort |
| P3 — Parser and expansion | Tokens, macro arguments/definitions/scope, built-in expansion, Unicode handling, environment/option/error semantics | Corpus and adversarial expansion tests pass under agreed limits |
| P4 — Typography and drawing | Complete required fonts/metrics, spacing/styles, extensible glyph/path assemblies, accents/arrows/braces, arrays/tags, boxes/color/dimensions and remaining core constructs | Feature and interaction corpus passes agreed geometry and visual criteria |
| P5 — Native presentation | Native equivalents for applicable semantics, links/annotations, accessibility, copy/selection, themes, zoom and reflow | Automated integration plus user desktop/accessibility review |
| P6 — Qualification and handover record | Complete inventory reconciliation; differential/stress/fuzz results; full development regression; updated manuals, SDD/SDF/provenance and report | All agreed requirements satisfied; deviations individually approved; user acceptance recorded separately |

Dependencies: P0 precedes P1; P1 precedes feature-port acceptance. P2 is a
bounded pilot, not a substitute for P3/P4. Parser and layout work may overlap
only where reviewed interfaces permit it. Independent corpus, font-data, and
read-only review tasks may be delegated; shared-file edits remain coordinated.

## 5. Qualification strategy

Before accepting feature work, define fixtures and expected outcomes spanning
commands/environments/options, nesting and interactions, valid and invalid input,
macro state, Unicode, boundary conditions, and reported regressions. Reuse
upstream tests where available and licensing permits, supplemented by native
interface and safety cases. Freeze expected results with upstream version and
configuration metadata; reference-engine upgrades require review.

Compare acceptance/errors and semantic/layout structure where equivalent;
compare width, ascent/descent, glyph selection/position and spacing. Use
fixed-font, fixed-scale browser/native image comparisons with explicit masks
and tolerances for rasterization differences. Numerical and image thresholds
must be chosen and reviewed before acceptance runs, not adjusted to conceal
failures. Performance/memory ceilings and maximum GUI work latency likewise
need measured proposals and user agreement at P0/design review.

Use AUnit and standalone native probes; qualify development builds only:
`alr build --development` and, from `test/`,
`alr build --development --profiles=coyote=development`. Run focused tests,
standalone checks, and the full suite from `test/` under Xvfb when required.
Add malformed/adversarial/fuzz and native resource/ownership checks. Verify
runtime dependency inspection still shows no reference engine/browser runtime.
Preserve GUI-main-task widget ownership while addressing measured work latency.

Record exact commands, versions, seeds, counts, failures, exclusions, log paths,
and human-review status. The coordinator-owned
`plan/native-math-parity-test-report.md` §8 supplies current status; earlier
report sections and dated checkpoints remain historical. Latest known full
suite: 1061/1061, 82.378580 s, before subsequent genfrac/mathchoice/color/minRule
edits; a full integration rerun is required. Geometry later passed 145/145,
resolving seven prior failures. The frozen geometry, 16-case structured pilot
and three-case image pilot are separate checks. Only the structured path
comparison uses normalized units (0.01, not em); full origins, widths and option
effects remain unmeasured. Generic frac/infix/cfrac,
mathchoice and hbox fields need full integration rerun. Latest color-candidate
validation aborted; no current color pass is claimed. Trust=false is the
enforced default; trust=true and fleqn are explicitly rejected. Whole-job memory/deadline/GTK
guarantees remain unqualified (resource test10 RSS 44,644 KiB is not whole-job
memory; display64 is a ledger, not process-inline). Readiness, final
qualification and human acceptance remain open. Coverage has been regenerated
for the current source; consult that crosswalk and report §8, not older totals.

## 6. Resources, risks, and maintenance

Use the existing GNAT/Alire/AUnit/GTK/Cairo/FreeType environment, development-only
KaTeX/Node oracle, reference browser, and generated comparison artifacts.
Budget disk space and runtime for broad image/fuzz suites during P0. No credible
calendar or staffing estimate is available before the inventory and pilot.

| Risk | Likelihood / impact | Mitigation; owner |
|---|---|---|
| Open-ended parity or hidden exclusions | High / High | Pin version/profile and reconcile every inventory item; developer, user scope review |
| Parser/model changes invalidate early fixes | High / Medium | Differential harness first; review interfaces; use P2 to inform redesign; developer |
| Native rendering differs from browser typography | High / High | Geometry plus tolerant image tests and human review; preserve discrepancies; developer |
| Macros/geometry exhaust resources or stall GTK | High / High | Explicit budgets, adversarial tests, latency measurements, cancellation/design review; developer |
| Missing fonts, path primitives, or semantic output | Medium / High | Asset/model audit and early presentation prototypes after design approval; developer |
| Upstream changes and derived-source licensing | Medium / Medium | Hash/version pin, notice audit, repeatable data generation, separate upgrade changes; developer |
| Automated checks mistaken for acceptance | Medium / High | Separate developer/agent evaluation from user visual/accessibility acceptance; developer |

## 7. Review decisions and status

The user approved this staged native-port plan and SRS-MATH v1.0 on
2026-10-24, and approved native design and project execution. The design and
test work products are recorded in `design/coyote-design.md`,
`design/native-math-compatibility.md`, and
`plan/native-math-compatibility-tests.md`. Requirements remain authoritative;
implementation progress does not change their scope or approved D01–D15
dispositions.

Phase/status summary: P0 requirements/inventory approved and produced. P1
baseline/browser tooling exists, but full field coverage, matching and readiness
are incomplete. P2 pilot works. P3 and P4 are partial. P5 async jobs, semantic
tree and raster display are partial; inline painting and GTK main-thread timing
are unqualified. P6 checks have run, but final qualification and acceptance are
open. RD-CTX-01 additional context caps remain unauthorized. Do not mark P1–P6
complete or claim full KaTeX parity. Final report reference:
`plan/native-math-parity-test-report.md` (final qualification pending).
Calendar dates and cost remain unestimated; independent human acceptance is
pending.

Developer self-evaluation: current implementation and evidence are separated
from the approved target and final acceptance gates. Existing tooling and
approval are recorded; incomplete comparisons, resource/timing qualification,
remaining capabilities and schedule estimates stay open. The documentation
refresh does not change approved requirements or claim another execution run.
Developer/agent review is not independent human acceptance.
