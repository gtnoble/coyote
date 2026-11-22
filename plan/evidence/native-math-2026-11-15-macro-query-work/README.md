# Cooperative macro query scans — developer evidence

Project date2026-11-15,parent1a765ce. Original host dates are preserved and may
differ. Controlling report §11.28;PCR-125 remains OPEN. This is practical abuse
protection,not exhaustive accounting or independent acceptance.

## Selected runtime change

Math_Macros.Is_Defined/Lookup accept optional borrowed Work (default null).
Private Find polls BEFORE each visited definition comparison;empty contexts
have0 polls. All12 queries in Math_Expander.Next pass Item.Work:10 Is_Defined,
2 Lookup including nested Definition_Token. No Work is stored in a Context.
Default-null callers retain existing behavior and missing Lookup still raises
Constraint_Error. Lookup result construction/copying after scanning is not
preemptible. Query exceptions propagate before publishing a result.

Mutation,Copy_Definition internals and scope unwind continue using null-work
queries. No stop is inserted between definition and optional-default publication.
End_Group/Restore_To_Depth must finish undo. Cursor-local queues/counters may
already have changed before an expander stop;discard the interrupted cursor and
use a fresh one. This change does not eliminate linear scans or remaining
quadratic Save/undo work,and provides no hard deadline/native-call preemption.
No index,context retention cap,pool,lease or accounting expansion selected.
Requirements,numerical limits and worker250ms budget are unchanged.

## Exact-final tests and controls

- Full macro probe941/941 twice,under macros/run1 and run2.
- New focused CLI `--query-work`:68/68 normally and under Valgrind.
- Fixture:128 global definitions plus caller-owned scope/local definition.
  Empty scans poll0;first/middle/late found names poll1/64/128;missing names
  visit129 entries. Both missing-name query behaviors are checked.
- Sixteen direct stop injections:present-last/missing × cancellation/deadline ×
  thresholds32/128 × Is_Defined/Lookup. Exact exception reason and count checked.
  After each stop,Definition_At compares order and complete replacement,prefix,
  delimiter,optional-default token payloads,parameter counts and names. Caller
  scope/local definition/diagnostic state survive;fresh null-work queries recover.
- Two expander stop injections at threshold32 check exact exception identity,
  state preservation and fresh-cursor expansion of the last definition. Caller
  scope subsequently unwinds normally. These exercise a query dispatch path,
  not every expander branch or each of the12 forwarding sites independently.
- Counts/thresholds are source-informed regression hooks,not independent work or
  timing oracles. No forced active-worker scan interruption was added.

Exact-final focused probe on two isolated49-file runtime snapshots:

| Mutation | Checks | Expected failures | Exit |
| --- | ---: | ---: | ---: |
| Remove Find scan poll | 68 | 26 | 1 |
| Replace Work with null at all12 expander query sites | 68 | 2 | 1 |

Each snapshot matches final production except its stated source mutation;probe
hash is byte-identical. Patches,projects,source manifests and original logs are
retained. These negative controls establish sensitivity to scan/forwarding loss,
not complete per-site or full resource qualification.

Initial906-check draft queried snapshots by name rather than table index and
mislabelled a present-name case as absent. It passed but did not prove ordering;
its log is retained as intermediate only. Final941/focused68 supersede those
claims and add complete indexed payload checks and both missing/present stops.
The original source gate predates the final spec comment clarification;the
manifest and implementation patch identify the final source. The gate's reference
to an absent requested runtime baseline does not mean a required checker failed:
no performance baseline script was implemented or promised by this increment.
Direct cooperative-stop controls and exact mutants supply the relevant evidence.

## Validation

Final root/test development builds pass (35.60s/18.64s wall). Final full Xvfb
1076/1076,zero failures/errors,147.112601s cumulative/147.23s wall. The earlier
full147.765024s cumulative/147.88s wall is retained separately. Standalone macro
checks are not added AUnit cases;registration remains unchanged. Engine3553 and
worker380 pass on the same runtime before final test-only refinements and spec
comment clarification;they were not rerun afterward. Final full suite and
mandatory GTK9/9,runner containment and offline HTTP ran after those refinements.
Runner synthetic child7/9 outcomes include expected kill/timeout containment;
the harness passes,not all nine child criteria. Active Alire GNAT15.2 toolchain
is retained;host13.3 is not the build compiler. Existing warnings remain;these
are development checks,not warning-free or release qualification.

Focused Valgrind reports68 checks,zero errors,zero definite/indirect/possible
lost bytes,37392 reachable,570104 cumulative allocated bytes. These quantities
are for a small query fixture,not memory/RSS/peak limits. Whole-macro Valgrind
was NOT rerun:focused CLI excludes the previously slow32768-definition test,
so it does not resolve the historical incomplete whole-macro attempt. No worker
Valgrind,raster/images,browser/reference geometry or seeded fuzz rerun. Prior
strict raster losses remain unresolved and are not waived by focused cleanliness.

## Exploration and review limitations

An isolated snapshot-vs-per-token-lookup candidate demonstrated no reliable
allocation/timing benefit and was NOT selected. Its original README/source hashes,
projects,driver,diff and small Memcheck summaries are retained separately under
unselected-snapshot-candidate. Full serialized token streams and large profiler
artifacts are not retained here;this optional exploration is not qualification
or a selected runtime behavior change. Its large Memcheck pair was incomplete.

A worker-cancellation audit originally misattributed Abandon's documented discard
behavior to Cancel. Coordinator/source review established no such contract defect;
production worker code is unchanged. One review RPC failed,and follow-up review/
probe-refinement workers hit provider usage limits. Coordinator completed the
source/call-site mapping,test refinements and evidence checks directly. There is
no completed independent review or user acceptance implied.

## Reproduce

From repository root:

- `MATH_MACROS_ROOT=/tmp/coyote-macro-query-exact1 sh test/tools/check-math-macros.sh`;repeat exact2.
- `/tmp/coyote-macro-query-exact2/bin/math_macros_probe --query-work`.
- `valgrind --error-exitcode=1 --leak-check=full /tmp/coyote-macro-query-exact2/bin/math_macros_probe --query-work`.
- `MATH_ENGINE_ROOT=/tmp/coyote-macro-query-validation/engine sh test/tools/check-math-engine.sh`.
- `MATH_JOBS_ROOT=/tmp/coyote-macro-query-validation/jobs sh test/tools/check-math-jobs.sh`.
- `alr build --development`;from test `alr build --development --profiles=coyote=development`.
- From test `timeout -k 10s 300s xvfb-run -a ./bin/coyote_test`.
- `python3 test/tools/check-gtk-interactions.py`;
  `python3 test/tools/check-gtk-interaction-runner.py`;
  `python3 test/tools/check-http-timeout-lifecycle.py`.
- `python3 tools/map_math_coverage.py`:fingerprints only;2930 core rows remain
  2929 partial/unqualified and1 deviation. Not parity/completion evidence.

Manifests preserve original absolute host paths and executable hashes;no binaries
or obj trees retained. Implementation patch covers three runtime files and the
standalone probe. Source identities and checksums support reconstruction.

Resource/timing/font/cache/GTK/lifecycle/parity/human gates remain open. Developer
self-review is not independent acceptance. No release/install/commit.
