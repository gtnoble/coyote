# Nested array-rule copy budget — developer evidence

Project checkpoint date: 2026-11-15. Controlling report §11.17; PCR-125 OPEN.
Some subordinate logs/paths use host date 2026-11-18; they are preserved as
recorded, not substituted dates. No requirements/deviations changed.

## Implementation and scope

`Math_Syntax.Add` pre-admits existing aggregate rule capacity plus active rule
lengths before outer node-vector growth. Active GNAT15.2 vector Adjust copies
length, not spare capacity. Both scans use short-lived explicit constant
references, ending before polls and node mutation. The post-growth scan
reconciles surviving rule capacities. Charges still end at Parse return;
returned/copyable documents have no new retained ownership.

The initial review's claim that `for ... of` necessarily copies elements was
not established (container indexing/reference aspects matter). Final review
explicitly corrects this; explicit Constant_Reference removes ambiguity, not
an independently proven old-loop allocation defect.

## Exact-final verification

- `root-build-final.log`, `test-build-final.log`: incremental development builds
  pass, both generated profiles development; existing warnings remain.
- `full-final.log`: run from `test/`,1076/1076, zero failed assertions/errors;
  cumulative145.197785s, wall145.30s. `full-wrong-cwd.log` preserves an invalid
  root-directory invocation:955 successful,28 failed assertions,95 errors
  (relative fixture paths unresolved). It is not a passing full-suite run.
- `focused/parser-run-{1,2}/`:719 checks,0 failures each.
- `focused/parser-valgrind/`:719/719; strict Valgrind0 errors/lost bytes,
  113248 bytes reachable. This parser test does not exercise Pango.
- `focused/jobs/`:223 assertions,0 failures; `focused/ledger/`:38/38.
- `focused/geometry/`:235/235 against test-only KaTeX0.16.22.
- `focused/raster/`:1116/1116 normally and under Valgrind, but strict script
  FAILS (exit1),2 native contexts:6656 definite/2183 indirect/26 possible lost
  bytes. No suppressions, relaxed thresholds or production-global cleanup.
- `gtk.log`:9/9. `gtk-runner.log`: containment self-test passes after deliberate
  synthetic7/9 child result. `http.log`:offline Plain/RPC lifecycle pass.
- `coverage.log`: crosswalk generation/check passes; only source hashes change,
  not coverage counts or qualification status.

## Detecting controls and review

The final56-node fixture retains two ordered rules (solid boundary0, dashed
boundary1) across32-to64 outer-node growth. The live-ledger delta is24586 bytes
versus24576 for a rule-free control:10 bytes for two active rule records.
Cancellation/deadline require that exact mixed delta. These exercise the same
cleanup branch with two exception identities, including shared macro scopes.
Measured exact/short/held/reuse controls validate the accounting model, not an
independent allocator measurement or independent timing mechanism.

`focused/provenance/mutant-source-project/` removes only the copy term and
preserves the new pre-allocation poll. Its719-check probe fails5 assertions:
charge detection and four stop/scope checks. Full source/project/logs retained.
`test-worker/` contains intermediate attempts and the earlier69c13ff baseline
with2 expected failures; these are not all exact-final tests. The preserved
poll mutation is the stronger charge-specific negative control.

`review.md` records intermediate concerns; `review-final.md` supersedes its
incorrect iteration inference and confirms the active GNAT15.2 implementation,
scoped references, arithmetic, call-site assumptions and corrected tests.
Developer/agent review is not independent human acceptance.

## Reproduction

From repository root:

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && xvfb-run -a ./bin/coyote_test)
sh test/tools/check-math-parser-memory.sh
sh test/tools/check-math-jobs.sh
sh test/tools/check-math-memory-budget.sh
sh test/tools/check-math-geometry.sh
sh test/tools/check-math-raster.sh
python3 test/tools/check-gtk-interactions.py
python3 test/tools/check-gtk-interaction-runner.py
python3 test/tools/check-http-timeout-lifecycle.py
python3 tools/map_math_coverage.py --check
```

Focused README records isolated output-root commands and strict parser
Valgrind options. Executable hashes are retained before removing generated
obj/bin trees; rerun scripts to rebuild. Raw GTK child logs are copied here.
`SHA256SUMS` covers retained evidence except itself; source/font hashes and
`implementation.patch` identify tested source. Earlier failed experiments
remain explicitly intermediate; no logs are rewritten to manufacture passes.

## Open gates

Other node payloads, strings/lexemes/diagnostics, expander/semantic/layout/native/
font work, allocator overhead, returned/cache lifetime and whole-job256MiB/RSS
remain unaccounted. Hard deadlines/GTK timing, fonts/bearings/shaped ink,
parent clipping, full parity and native lifecycle/human acceptance remain OPEN.
Browser images/resource characterization were not rerun. The retained-budget
ownership proposal remains DRAFT/NOT APPROVED/NOT IMPLEMENTED. No release,
installation, automatic commit or acceptance is implied.

## Final provenance reconciliation

Direct coordinator audit found the initial mutation probe lacked only the final
assertion-label node-count suffix. `mutation-exact/` retains the byte-identical
final probe with the same poll-preserving production mutation. Rebuilt and
rerun:719 checks,5 expected failures, exit1 (`mutant-exact-*.log`).
`mutation-diff.patch` and `audit.md` record the comparison. The final audit
worker was aborted without findings; coordinator self-evaluation completed it.
