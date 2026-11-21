# Stratified seeded recovery and stop injection — developer evidence

Checkpoint2026-11-15,parent945b176. Test tools only; production,requirements,
resource limits and accounting policy unchanged. REQ-MATH-003/010/014;
MATH-STATE-001,MATH-LIMIT-002,MATH-REGRESS-002 scoped evidence. This does not
close full adversarial/resource/GTK/native lifecycle or acceptance gates.

## Corpus and controls

The existing check-math-fuzz.cjs now generates10000 primary cases using fixed
xorshift32 seed0x6d617468, eight1250-case strata:valid grammar,malformed,
Unicode,scripts,macro expansion,arrays,dimensions,comments/accents/policy.
There are5007 distinct primary sources, not10000 unique formulas. Sources are
bounded at8192 bytes (observed maximum1980 primary bytes); a local-definition
prefix is additionally present in each actual primary request. No65KiB source
boundary,full surfaces,all node/command limits or allocator admission is claimed.

Per case,one sequence receives four requests:global sentinel z setup,primary
with local fuzzlocal definition,sentinel recovery,ordinary x+alpha recovery.
All four stay in one process/batch and use the same context; each primary has
a distinct sequence. Primary and both recoveries assert fuzzlocal absent;
sentinel body and recovery glyph streams are exact. Exported snapshots observe
macro cleanup, not internal scope-depth telemetry. Full output hashes include
all four responses, not just primary statuses. Stateful contexts end with each
process batch, not a long-running retained-context stress test.

Known-valid bounded recursive grammar requires ok. Known malformed inputs
require parse-error; selected array/dimension/EXPANSION_LIMIT cases require
exact diagnostics. Cycles and depth12–19 doubling chains use alphabetic names;
moderate custom macros check glyph streams. Known JavaScript href probes
require policy-visible-command with refusal diagnostic and nonempty geometry.
Unicode and some exploratory subsets allow documented statuses but require
structural/result invariants; this is not an independent grammar/font oracle.

Success checks cover nonnegative finite box width/ascent/descent within16384,
command count131072, finite/bounded positions, positive scale, nonnegative
width/height. Path coordinates are finite but not em-capped:serialized SVG
source units differ. Clip/shadow fields are required finite when enabled.
No complete ink/clipping/reference parity claim. Error rows have nonempty
messages and no geometry. Unexpected exporter exception paths omit shared
snapshot fields and fail the snapshot requirement; stderr alone cannot be
rejected because ordinary parse/layout diagnostics also use it. An explicit
self-test supplies that missing-snapshot exception record.

## Bounded execution and harness checks

32 primary units per batch,128 requests,32MiB output cap,30s maximum child
execution timeout. Before each batch the remaining300s run budget limits the
child timeout. Parent JSON processing/evidence writes and uninterruptible/native
operations do not gain a hard completion guarantee. A primary is not subjected
to a30s per-job product criterion; these are harness containment values.

Generated corpus is persisted before native execution. Crash/timeout/nonzero
exit retains batch request identities/input,partial stdout,stderr and failure
metadata; invalid response retains exact input/output. Full replay mismatch
retains corpus/output hashes. Only two final output digests are retained, not
all successful response JSONL; full generated corpus and source hashes support
reruns. Each invocation runs all10000 primaries twice,40000 requests/pass,
80000 requests/invocation. Two independent invocations give160000 total requests
but only the same10000 primary cases, not160000 independent inputs.

check-math-fuzz-runner.cjs passes56 checks twice:corpus quotas/reproducibility,
expected status/diagnostic,geometry/policy/state/recovery rejection controls,
fake-child success,wrong identity,local leak,malformed/truncated JSON,crash,
timeout and output-buffer exhaustion. Synthetic failure artifacts under runner/
are intended test inputs,not product failures. They do not prove arbitrary
forked-grandchild containment; spawnSync manages the exporter child.

## Native stop subset

Existing engine probe adds64 seeded valid source cases (seed0x73746f70), each
calibrated with continuing Work, then cancellation and deadline injected at
one seeded ordinal in1..baseline polls:128 injected stops. Four grammar families
vary operands; cases may repeat sources. Every selected source/baseline/target
is logged. No guarantee the selected point occurs after definition mutation or
in every engine phase. Exception identity,scope depth0,No_Error,local definition
absence and global sentinel availability are checked; exact z,+,x recovery uses
null Work. Out results are not read after exceptions. This is direct-engine
cooperative behavior, not worker scheduling/GTK/hard deadline qualification.

## Results and reproduction

| Check | Result |
|---|---|
| Seeded corpus |10000 primaries/pass,two full passes/invocation,two invocations pass |
| Each pass statuses |5742 ok,3893 parse-error,156 layout-error,209 policy-visible |
| Canonical corpus |c2110d62da5239191f161d511206d0c52e793790e504f0c1cdb1240374298f3f |
| Full response digest |083e07d5fd4873f8bbec5405fb63f0a4ca65820ed66da7b5f0572a5da4480caa |
| Elapsed final invocations |39655ms /44989ms;not job latency qualification |
| Runner self-test |56/56 twice |
| Engine probe |758/758 twice,64 sources/128 injected stops |
| Engine Valgrind |758 assertions,zero errors/lost bytes,216713 reachable |
| Root/test development builds |pass;existing warnings remain |
| Full Xvfb from test cwd |1076/1076,zero failures/errors,142.623192s cumulative/142.70s wall |
| Mandatory GTK/runner/HTTP |9/9;synthetic containment pass;offline HTTP pass |

The runner intentionally injects two child failures (Unicode kill,bidi timeout)
and reports7/9 synthetic child criteria while containment/continuation passes.
Full AUnit main does not include standalone engine additions or JS tools.
Production sources matched before/after validation; final probe-only refinements
added exact glyph checks and case logs after the full suite, with fresh standalone
runs/Valgrind. Full suite covers unchanged product,not new standalone test mains.

Build exporter:`MATH_EXPORT_ROOT=/tmp/coyote-math-fuzz-build alr exec -- gprbuild
-p -P test/native/math_export.gpr`. Run `node test/tools/check-math-fuzz.cjs
/tmp/coyote-math-fuzz-build/bin/math_export /tmp/coyote-seeded-fuzz-exact1.json`
(and exact2). The persisted run-report paths are original host paths; corpus
is retained once as fuzz/cases.jsonl with both originals hashed in manifest.
Run `node test/tools/check-math-fuzz-runner.cjs`. Engine uses
`MATH_ENGINE_ROOT=/tmp/coyote-seeded-engine-exact1 sh test/tools/check-math-engine.sh`
(and exact2). Native check:`valgrind --max-stackframe=4194304 --error-exitcode=1
--leak-check=full /tmp/coyote-seeded-engine-exact2/bin/math_engine_probe`.
The4MiB frame-classification threshold is documented handling of an existing
2.6MiB semantic frame,not a suppression or relaxed leak threshold.

## Limits and review

No RSS/memory measurement or major-buffer admission experiment here. No full
surface/raster/cache/GUI/assistive-technology or representative timing corpus.
Prior raster losses remain OPEN; raster/browser/geometry/image/whole-macro
Valgrind not rerun. This10k bounded stratified run improves scoped MATH-REGRESS
coverage; it does not satisfy all classes/limits/failure injection required for
qualification. No new resource policy/storage architecture; no production defect
found. Developer/agent review is not independent acceptance. PCR-125 OPEN.
No release/install/commit. Original host dates differ from checkpoint date.
