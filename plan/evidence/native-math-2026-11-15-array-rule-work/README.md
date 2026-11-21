# Cooperative array-rule work — developer evidence

Checkpoint2026-11-15,parent9225c7f. PCR-125;REQ-MATH-010/014;
MATH-LIMIT-002/MATH-REGRESS-001/002 scoped continuation. No new limit,
accounting,storage architecture,macro-context policy or public API change.

## Runtime change and reasoning

Compose_Array previously searched the entire rule-metadata prefix again for
each stroke at a boundary. For R rules at the same boundary,the rule-kind
selection visits R(R+1)/2 entries. The renderer now maintains Next_Rule per
boundary and advances it monotonically until the next match. It retains vector
order within that boundary,including mixed solid/dashed metadata,without AST
mutation. Each boundary visits at most R entries; repeated Rules_At scans still
remain O(rows*R),with row count bounded by existing parser/layout limits. No
claim of linear whole-job work or new algorithmic guard threshold is made.

Rules_At,metadata validation and forward lookup now Poll before every visited
entry. Poll exceptions propagate; earlier local result state is discarded by
unwinding. This does not preempt native calls or establish a hard deadline.
R is already checked against Max_Nodes before rendering. No fine-grained
memory accounting or enclosure/macro-index refactor was added.

## Direct-layout regression and mutation controls

Engine probe parses source without Work,then builds directly with counting Work.
Alternating hline/hdashline metadata at boundary0 uses1/16/256/1024 rules;
metadata kind/order/boundary,glyph count,exact polled-vs-null-Work Box equality,
stop-exception identity and subsequent rebuild equality are checked. A separate
mixed-boundary fixture checks boundaries0,1,2 and exact geometry consistency.
The runtime polls for these sizes are48,351,5159,20543;multi-boundary146.

For N>=256,the scoped regression envelope20N<=polls<=21N+128 detects missing
checks and excessive rescans in these specific two-row fixtures. This is a
poll-count regression calibrated to this implementation,not an independent
complexity/allocation/timing oracle or a new product bound. Counting Work makes
visited-entry regressions observable; source reasoning and mutations complement
it. Stop at half the observed build polls is direct-layout evidence,not proof
that each stop hits a particular metadata site. Individual missing-poll mutants
provide per-site sensitivity,not wall-clock latency qualification.

| Exact3404-assertion probe | Result / polls at256 and1024 |
|---|---|
| Final normal,twice |3404/3404;5159 /20543 |
| Remove Rules_At poll |exit1,two failures;1575 /6207 |
| Remove metadata-validation poll |exit1,two failures;4903 /19519 |
| Remove forward-lookup poll |exit1,two failures;4903 /19519 |
| Reset cursor but keep first-match selection |exit1,two failures;4643 /18479 |
| Faithful old prefix search with polls |exit1,three failures;37799 /544319 |

IMPORTANT:the simple cursor-reset mutant repeatedly selects the first rule;
it does NOT restore the old Rule_Index-based prefix search and is NOT evidence
of quadratic traversal. Its original summary label is retained with this
correction. The faithful-rescan mutant separately restores Seen/Rule_Index
lookup and keeps every new poll;it exceeds the upper envelope,including at16
rules (471 polls). All mutants use the byte-identical final probe/hash. Patches,
source hashes,build/probe logs and machine-readable summaries are retained.
No generated mutation binaries/objects or source trees are retained here.

The earlier3396-assertion evolving probe reports three expected failures on
unchanged production:33,95,1063,4159 polls. It is NOT an exact-final baseline.
Its original lower envelope was6N and later strengthened; keep this distinction.

## Geometry compatibility and regression

68 parser-generated array requests (styles,column bars,multiple boundaries,
repeated solid/dashed rules,including1024 metadata entries) run through isolated
baseline HEAD and new exporters. All68 return ok;full JSONL is byte-identical,
3448 commands in each output. This compares prior implementation behavior,not
an independent browser oracle. Same-implementation Box comparisons in the probe
alone do not establish baseline compatibility. Full input/output artifacts and
source/build hashes are retained in comparison/.

Pinned reference geometry script also passes its unchanged case groups;see
geometry/check.log for per-group counts. Focused arrays and worker346/346 pass.
Stratified seeded fuzz against the changed exporter passes10000 primaries across
eight strata with full replay:5742 ok,3893 parse-error,156 layout-error,209
policy-visible per pass;5007 distinct sources and unchanged full-output digest
083e07d5fd4873f8bbec5405fb63f0a4ca65820ed66da7b5f0572a5da4480caa.
Elapsed41746ms is harness time,not per-job/GTK qualification. Original report
paths are host paths;retained corpus is fuzz-cases.jsonl.

## Build and native checks

Root/test development builds pass;existing warnings/style diagnostics remain.
Full Xvfb1076/1076,zero failures/errors,143.548323s cumulative/143.63s wall.
GTK9/9,synthetic runner containment and offline HTTP pass. Synthetic Unicode
kill/bidi timeout are expected runner inputs;7/9 child criteria is not9/9.
Final production hash is stable before/after validation. Full AUnit suite covers
runtime source;new standalone checks are not new AUnit registrations. Probe-only
multi-boundary/envelope refinements were run twice separately after full suite.
Engine Valgrind3404 assertions,zero errors/lost bytes,216713 reachable,using the
existing4MiB semantic-frame classification threshold,no suppression or relaxed
leak criterion. Prior strict raster losses remain failures.

Active Alire toolchain is GNAT15.2.0/GPRbuild25.0.0,recorded in comparison
provenance. A validation worker separately queried host gnatls13.3.0;that was not
the active build toolchain. An initial hash query used nonexistent
src/coyote_renderer/math_layout.adb;the full src hash listing and final correct
src/coyote_math/math_layout.adb hash establish identity. Original logs retained.
A supplementary worker query reported disk exhaustion after completed builds;
coordinator df showed81GiB available,so no persistent filesystem block remained.
Do not infer root cause or silently discard that report.

Commands:root `alr build --development`;test `alr build --development
--profiles=coyote=development`;from test `timeout 300 xvfb-run -a ./bin/coyote_test`.
`MATH_ENGINE_ROOT=/tmp/coyote-array-engine-final1 sh test/tools/check-math-engine.sh`
and final2;`MATH_ARRAYS_ROOT=/tmp/coyote-array-focused sh
test/tools/check-math-arrays-probe.sh`;`MATH_JOBS_ROOT=/tmp/coyote-array-jobs sh
test/tools/check-math-jobs.sh`;`MATH_GEOMETRY_ROOT=/tmp/coyote-array-geometry sh
test/tools/check-math-geometry.sh`. `node test/tools/check-math-fuzz.cjs
/tmp/coyote-array-command-compare/new-build/bin/math_export /tmp/coyote-array-fuzz.json`.
Valgrind:`valgrind --max-stackframe=4194304 --error-exitcode=1 --leak-check=full
/tmp/coyote-array-engine-final2/bin/math_engine_probe`.

Read-only source review finds no correctness blocker. Developer/agent review is
not independent acceptance. Crosswalk source fingerprint updated,counts unchanged.
No browser images/raster/whole-macro Valgrind rerun. Remaining major-buffer,
resource/timing/GTK/font/native lifecycle/full parity/human gates stay OPEN.
No release/install/commit.
