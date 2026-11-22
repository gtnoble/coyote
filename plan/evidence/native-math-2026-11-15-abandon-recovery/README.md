# Repeated queue saturation and Abandon recovery

Project date2026-11-15,parent2dd0b5d. Host timestamps may differ;original logs
are preserved. Controlling report §11.29. This increment modifies only the
standalone worker probe and engineering records. Production,requirements,
limits,coverage fingerprints and worker250ms budget are unchanged.

## Final lifecycle controls

Seventeen cycles run in ONE paused pool,without restarting between cycles:

1. Empty queue rejects65537 bytes Busy/id0 independently of queue saturation.
2. Each cycle accepts eight65536-byte sources with unique increasing nonzero IDs.
3. Ninth exact source is Busy/id0. Wrong-generation Abandon and Poll cannot
   remove/consume the matching pending slot;retry remains Busy/id0.
4. Matching Abandon removes the slot. The EXACT previously Busy source/generation
   immediately retries successfully. Duplicate Abandon is harmless.
5. All remaining matching requests are abandoned;Poll returns Unknown/null and
   Timing no finalized record. Next cycle refills the queue.

Totals:153 accepted requests,34 counted queue-full Busy responses,10027008
cumulative accepted source bytes. The oversized rejection is separate from34.
Maximum sources are ASCII comment padding,markers,newline and x+y;they are
abandoned BEFORE parsing. The log explicitly says source_identity=not_verified.
The totals are submitted payload,not simultaneous retained bytes,allocator/RSS
measurement,or proof that the private source ledger returned to zero.153 accepts
exceed128 slot entries cumulatively and check reuse,not occupancy of153 at once.
The256MiB private source ledger cannot be exhausted with128×65536-byte slots;
no new API or reduced guard was introduced to manufacture an exhaustion test.

After Resume on the now-empty SAME pool,ordinary x+y returns exact source and
ordered x,+,y glyphs,no raster,then releases to null/ledger0. This is same-pool
recovery,not evidence that one physical worker handled both requests.

Eight completed-unpolled raster cycles use x+y/24px and trusted font files.
Non-consuming Timing waits for finalized completion;the retained raster ledger
is positive. Wrong-generation Abandon preserves charge/timing;matching Abandon
releases charge immediately,duplicate Abandon leaves it zero,and Poll/Timing
show removal. Each is followed by exact source/glyph/raster recovery and release.
No other outstanding raster owner is present in this fixture. Zero ledger is
tracked raster ownership evidence,not a native-library or whole-memory claim.

A SEPARATE pool is explicitly shut down and started paused for the eight-source
shutdown-drain fixture. Calling Start(Paused=>True) on a running pool does not
pause it. After full-queue Shutdown,all IDs poll Unknown/null and restarted
ordinary x+y recovers. This restart is not part of the17-cycle no-reset phase.

Four bounded waits (400×5ms) cover ordinary recovery,raster completion,raster
recovery and restart recovery. Timeout records failure,Abandons the matching
request,shuts down and returns instead of contaminating later checks. Shutdown
joins workers;the watchdog is not a guarantee of hard bounded native completion.
No deterministic in-flight abandonment,GTK display fallback or worker affinity
was injected. Completed-raster charge/timing criteria do not claim the unpolled
job's status was independently consumed as Valid.

## Final checks and mutation controls

- Full standalone worker probe1013/1013 TWICE.
- Focused `--abandon-recovery`634/634 TWICE.
- Original drafts1002/focused623 passed but lacked some watchdog exits and did
  not truly pause the shutdown queue;they are intermediate,not final coverage.
- Isolated49-source snapshot removes queued Abandon slot clearing:18 assertions,
  2 expected failures,exit1;fixture detects retained slot and exits safely.
- Isolated snapshot omits Free_Result after completed Abandon:634 assertions,
  25 expected failures,exit1. This artificial mutant leaks its dropped results;
  it is a negative control,not a production defect or leak qualification run.
- Exact final probe hashes match across production and both mutants;only
  coyote_math_jobs.adb differs in each mutation. Patches/projects/manifests/logs
  retained;no obj/bin trees or executable files retained.

## Regression: passing checks AND unresolved failed repeats

Root/test development builds pass,active Alire GNAT15.2/GPR25;existing warnings
remain,not warning-free qualification. Production/requirements hashes match HEAD.
AUnit registration remains1076;these standalone additions are NOT AUnit cases.

Coordinator Xvfb full suite passes1076/1076,zero failures/errors,
147.365823s cumulative/147.52s wall. An earlier validation worker also reports
1076/1076 (148.741484s cumulative/149.11s wall);its raw suite output was not
retained separately,so this earlier result is report-only,not another accessible
full log. Original aggregate build and mandatory-check logs are retained.

TWO additional AUnit runs in worker/run1/full-suite.log and run2/full-suite.log
fail exactly Coyote.GUI tool detail stable layout and snapshots:1075 successes,
1 failed assertion,0 unexpected errors. Observed116×1033 and109×1033 instead of
760×600 within1s. The unchanged isolated case passes1/1 afterward. Root cause
is NOT established. These failed repeats remain unresolved and unwaived. This
increment does NOT have a uniformly passing full regression repeat matrix.
No GUI assertion,window-size criterion or product code was changed to hide it.
The full.time alongside run1/full-suite.log contains23.98s/exit0 inconsistent
with that suite;its provenance is unreliable and NOT accepted as that run's
full-suite timing. The worker readiness summary is superseded by this README
and coordinator-verified worker/probe.log files;AUnit is not the standalone probe.

Required GTK interactions9/9,GTK runner containment and offline HTTP pass.
Runner7/9 synthetic children include expected kill/timeout;the harness passes,
not all child criteria. Despite instructions not to do so,the validation worker
attempted nonexistent test/tools/check-subagent-containment.py (exit2). Original
log retained;this is not a required checker and NOT a pass.

## Reproduce

From root:

- `MATH_JOBS_ROOT=/tmp/coyote-abandon-final1 sh test/tools/check-math-jobs.sh`;repeat final2.
- `/tmp/coyote-abandon-final1/bin/math_jobs_probe "$PWD/share/coyote/math/fonts" --abandon-recovery`;repeat final2.
- `alr build --development`;from test `alr build --development --profiles=coyote=development`.
- From test `timeout -k 10s 300s xvfb-run -a ./bin/coyote_test`.
- From test `timeout -k 5s 30s xvfb-run -a ./bin/coyote_test 'Coyote.GUI tool detail stable layout and snapshots'`.
- Required `python3 test/tools/check-gtk-interactions.py`,
  `python3 test/tools/check-gtk-interaction-runner.py`,
  `python3 test/tools/check-http-timeout-lifecycle.py`.

No worker Valgrind,browser/geometry/raster comparator,seeded fuzz or whole-macro
Valgrind rerun. Existing native raster losses are not waived. Native lifecycle,
GUI fallback/reflow/cache/timing,compatibility and human acceptance gates remain
open. No runtime defect found;no Cancel contract alteration or resource change.
Coordinator/agent self-review is not independent acceptance. PCR-125 OPEN.
No release/install/commit.
