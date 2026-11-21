# Command-limit boundary and recovery — developer evidence

Checkpoint2026-11-15,parentacf1cf1. Host dates in original logs may differ and
are preserved. PCR-125;REQ-MATH-010/014;MATH-LIMIT-002/MATH-REGRESS-001/002
scoped continuation. This increment changes only standalone tests and engineering
records. Production,requirements,limits,accounting and the250ms worker budget
are unchanged. No runtime defect was found or product-limit change selected.

## Reachability and facade tests

A one-column array with314 dashed horizontal rules and a100em kern emits130938
commands from3493 source bytes and5 AST nodes. Appending134 x glyphs outside
the array produces exactly131072 commands (3627 bytes,139 nodes);133 produces
131071 and135 exceeds the command cap.315 rules exceed the cap inside rule
construction without trailing glyphs. These controls stay far below independent
source/node/expansion/depth/row limits. Counts characterize this fixed renderer,
not an independent geometry/parity oracle. The source generator is retained.

Engine tests cover one-below,exact and one-above,plus rule-generation overflow.
Color/framed-color/phase fixtures put the entire array AND trailing glyphs inside
the enclosure:decoration totals1/5/1 reach exactly131072;one extra child glyph
makes reconstruction overflow. This exercises the recent Move/Reserve branches
without bypassing Append_Command's existing cap. Maximum tested source3666 bytes
and141 nodes (different fixtures' maxima);no raster requested.

Every overflow is checked once with Throw_On_Error true and once false. Expected
Layout_Error retains exact source,valid syntax and semantic views,clears geometry
and commands,and emits the exact draw-command diagnostic without fallback output.
Local definitions unwind;the prior global z sentinel and ordinary x+y requests
recover in the same context. Failure logs report guard131072 and published0;
nominal generated count is not claimed from empty failure geometry,especially
for315-rule overflow. Exact successful command/glyph counts are asserted.

Final engine3553/3553 twice. Isolated one-line private guard mutation131072→131073
uses the byte-identical final probe and unchanged public Math_Paths limit. It
builds,then fails8 assertions:plain/color/framed/phase one-above return Ready with
131073 commands under both Throw_On_Error values.315-rule overflow still rejects.
This is a negative control only,not a proposed product-cap increase. Forty-nine
math source hashes match HEAD except for the single mutation. Mutation patch,
source/probe hashes,project metadata and original logs are retained,not binaries.

## Worker status, watchdogs and recovery

Final worker380/380 twice. RasterizeFalse requests cover exact-cap,135-glyph
overflow twice and315-rule overflow,each followed by immediate x+y recovery.
Final exact-cap runs return Valid and131072 commands;overflows return Invalid,
retain source/valid syntax and exact layout diagnostic,clear geometry and retain
no raster. Returned results are released and nulled;tracked raster ledger is0.
Recovery asserts the exact x,+,y glyph sequence. Requests use the same worker
pool,not a pinned physical worker. Zero raster charge is not whole-job memory
accounting or proof of no allocations.

An earlier373-assertion attempt required Valid for the exact-cap worker and
failed once:Status Expired even though geometry contained131072 commands. The
250ms cooperative deadline can win;Status is authoritative regardless of retained
geometry. That failed log is preserved. The corrected exact-cap oracle accepts
only Valid or Expired:Valid must contain the exact layout;Expired must retain
source and no raster and is NOT inspected as valid geometry. Both paths release
and immediately recover. Final runs were Valid;the final Expired branch was NOT
deterministically injected or separately qualified. No budget was extended and
no production behavior changed to make the test pass. Earlier364-result drafts
and3553 engine drafts are not exact-final evidence.

Worker overflow assertions still require Invalid with the command-limit diagnostic.
They can fail if the unchanged deadline preempts the guard under load;these runs
show the guard path,not universal completion/timing qualification. The direct
engine has no worker deadline and supplies exact structural boundary coverage.
Each bounded wait is400 polls at5ms;watchdog expiry records failure,Abandons the
matching pending request and returns instead of contaminating recovery checks.
Abandon does not prove that in-flight native cleanup completes within the watchdog.

## Validation and limits

Root/test development builds pass;generated development profile is used. Full
Xvfb1076/1076,zero failures/errors,145.918966s cumulative/146.05s wall. Production
hash lists match before/after;git diff src/tools and requirements is empty.
Full AUnit registration is unchanged;standalone probes are not added AUnit cases.
Full suite preceded final test-only enclosure/watchdog/status-oracle refinements;
those were rerun twice separately. No production change needed another build.
Existing warnings remain;incremental logs do not establish a warning-free build.
Active Alire compiler GNAT15.2 differs from host13.3 queries.

Mandatory GTK9/9,GTK runner containment and offline HTTP pass. The runner's
Unicode kill/bidi timeout are expected synthetic child cases:7/9 child outcomes,
passing containment harness,not all9 criteria. A worker also attempted nonexistent
test/tools/check-subagent-containment.py and got exit2;that auxiliary attempt is
retained and is NOT a pass or a required checker. The actual required GTK runner
checker completed its containment checks. No failed result is silently omitted.

Exact engine Valgrind3553 assertions:zero errors and zero definite/indirect/
possible lost bytes,216713 reachable,using the existing4MiB semantic-frame
classification threshold and no suppression. Its cumulative allocation total is
6005820154 bytes across the full probe,NOT a live-memory/RSS/peak cap measurement.
No worker Valgrind,images/raster,reference geometry,seeded fuzz or whole-macro
Valgrind rerun for this test-only increment. Prior results remain historical;
prior strict raster losses are unresolved and are NOT waived by headless results.

## Reproduction and provenance

From repository root:

- `MATH_ENGINE_ROOT=/tmp/coyote-command-engine-exact1 sh test/tools/check-math-engine.sh`;repeat exact2.
- `MATH_JOBS_ROOT=/tmp/coyote-command-jobs-contract1 sh test/tools/check-math-jobs.sh`;repeat contract2.
- `valgrind --max-stackframe=4194304 --error-exitcode=1 --leak-check=full /tmp/coyote-command-engine-exact2/bin/math_engine_probe`.
- `alr build --development`;from test `alr build --development --profiles=coyote=development`.
- From test `timeout 300 xvfb-run -a ./bin/coyote_test`.
- Required `python3 test/tools/check-gtk-interactions.py`,
  `python3 test/tools/check-gtk-interaction-runner.py`,
  `python3 test/tools/check-http-timeout-lifecycle.py`.

Original projects/manifests contain absolute host paths. Source generators,
probe patch and hashes support reconstruction;no generated obj/bin trees retained.
Early enclosure drafts placed glyphs outside wrappers and did not test decoration
reconstruction. Early worker loops failed to abandon on watchdog expiry. Those
issues were corrected before final exact runs. The test oracle correction for
natural expiry is separately disclosed above. Read-only review found no remaining
material blocker and identified the load-sensitive overflow-worker risk.

Developer/agent self-review is not independent acceptance. No browser parity,
hard deadline,whole-memory,cache/GTK/font/lifecycle or human gate closes here.
PCR-125 remains OPEN. No release/install/commit.
