# Explosive expansion and composed-output guards — developer evidence

Project checkpoint2026-11-15; parent4b11c5d. This increment changes only two
standalone probe mains plus engineering records. Production source, SRSv1.1,
numerical limits and memory-guard policy are unchanged. No new runtime guard
or source defect was identified. Source fingerprints/qualification counts are
unchanged; source hashes and executable identities are in manifest.json.

## Fixtures and coverage

1. Genuine nested duplication:complete small source defines dup(#1)=#1#1.
   Six nesting levels render64 x glyphs. Nineteen levels are rejected at
   Max_Expand1000 and10000, twice per setting, with EXPANSION_LIMIT, original
   source, invalid parsed document, empty invalid geometry, restored scope,
   prior global sentinel reuse and following ordinary same-context success.
   Nominal fully expanded output2^19=524288 glyphs is a fixture derivation,
   NOT a measurement or independent allocation oracle. Actual guard triggers
   before full output. Existing single60000-character duplication separately
   checks TOKEN_LIMIT; that is not relabeled exponential expansion.
2. Nine-stage doubling chain:512 x glyphs,1023 nominal macro invocations.
   Default1000 rejects, sentinel and x recover immediately,10000 accepts with
   exactly512 x glyph commands. Sources remain under1024 bytes.
3. Combined layout width:global macros compactly expand163 legal100em kerns
   plus84em to exact16384em (Ready, valid empty-command spacing geometry).
   Plus83em and x is below limit; plus85em and x is rejected with Layout_Error
   and exact layout geometry limit exceeded. Parsed/semantic views remain
   valid; source stays exact; geometry clears dimensions/commands. Both
   Throw_On_Error settings, twice each, preserve scope/global sentinel and
   immediately recover on sentinel and x. No parse-fallback success is implied.
4. Composed raster dimensions:framed colored box around xcancel and a40em×1em
   rule measures10415×431 at256px/em; the1em×20em counterpart measures431×5295.
   Each crosses only its intended8192/4096 full-raster dimension. Estimated
   ARGB32 output17955460/9128580 bytes is below the64MiB retained cap.
   Each request queues, returns Failed with full raster dimension limit
   exceeded, valid diagnostic parse/layout/source, no raster/dimensions/charge,
   zero charged raster workspace and restored retained ledger. The worker
   reserves its retained output lease BEFORE Render_Into; Paint rejects full
   dimensions BEFORE Cairo workspace allocation, then worker cleanup releases
   the lease. Zero workspace is not proof of no allocations or no lease.
   Same source at24px/em succeeds with measured bounded dimensions and retained
   pixels; release returns ledger to zero. Both fixtures repeat twice through
   the same worker pool, not pinned to the same physical worker.

Worker polling uses400 iterations with5ms sleeps. Pending timeout abandons the
matching failed or recovery request, records failure and returns from the case;
it does not prove completion/cleanup within the watchdog or native preemption.
The completed paths above check cleanup. Local layout/Measure establish fixture
and integration expectations, NOT independent browser/reference geometry.

## Results

| Check | Result |
|---|---|
| Final engine standalone |309/309 twice |
| Final worker standalone |346/346 twice |
| Engine Valgrind |309 assertions,zero errors/lost bytes,216713 reachable |
| Root/test development builds |pass; no warning-free claim |
| Full Xvfb,correct test cwd |1076/1076,zero failures/errors;147.796068s cumulative,147.94s wall |
| Required GTK |9/9 |
| Runner containment |pass;7/9 synthetic children,expected Unicode kill/bidi timeout |
| Offline HTTP lifecycle |pass |

Production source before/after hashes match. Standalone additions are not
compiled into the AUnit suite. Full attempt in repository root exited127 before
running any tests (binary absent); retained beside corrected test-cwd run.
commands.txt distinguishes initially intended commands from actual wrong cwd;
corrected command was `cd test && /usr/bin/time -f 'wall=%e user=%U sys=%S
exit=%x' timeout 300 xvfb-run -a ./bin/coyote_test`. Root and test development
build commands and mandatory Python checks are in validation/commands.txt.

Engine and worker runs use `MATH_ENGINE_ROOT=/tmp/coyote-abuse-engine-final1`
(or final2) with `sh test/tools/check-math-engine.sh`, and
`MATH_JOBS_ROOT=/tmp/coyote-abuse-worker-final1` (or final2) with
`sh test/tools/check-math-jobs.sh`. Engine native check uses
`valgrind --max-stackframe=4194304 --error-exitcode=1 --leak-check=full
/tmp/coyote-abuse-engine-final2/bin/math_engine_probe`. The4MiB classification
threshold avoids misclassifying the existing2.6MiB semantic frame; no suppression
or relaxed leak threshold. Engine results do not waive strict raster losses.
Host timestamps differ from checkpoint date and are preserved verbatim.

## Development provenance and limitations

development/engine-fixture-attempts.log is a developer reconstruction of evolving
failed probe summaries, NOT byte-identical baseline or exact source snapshots.
Initial literal8192em kerns were clamped by maxSize100; another fixture used
incorrect control-word suffixes, then an extra100em piece exceeded the intended
below-limit width. Final fixtures use legal100/83/84/85em pieces and alphabetic
macro names, and pass twice. Earlier composed worker runs are passing evolving
338-assertion probes, not failures or exact346-assertion finals. No baseline
regression fix or mutation-failure result is claimed for this test-only change.

Read-only developer/agent review found no blocker. Self-review is not independent
user acceptance. This finite fixture set does not complete10000 seeded adversarial
cases, command-count/surface boundaries, representative timing, cache/GTK adoption,
font/native lifecycle/parity or human acceptance. Browser/geometry/image/raster
corpora and whole-macro Valgrind were not rerun. Existing strict raster losses
remain OPEN. PCR-125 OPEN; no release/install/commit.
