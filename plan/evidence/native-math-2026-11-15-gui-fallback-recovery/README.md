# GUI-component math fallback and recovery

Parent8cb4694,project date2026-11-15;host timestamps differ. Report §11.31.
Only `test/src/coyote_gui_conversation_stack_tests.adb` and engineering records
change. Product/API/requirements/limits/coverage fingerprints unchanged.

## Two new registered cases

Filter `Coyote.GUI.Conversation_Stack recovers` selects exactly:

- `recovers inline math fallback`:fill8 public worker slots while paused;
  insert valid fraction through Rich_Text.Insert;assert visible/full buffer
  source,no Pixbuf,and exact Copy_Selection clipboard content. Replace with
  z+1 while Busy;verify current source/copy only. Abandon fixture jobs,change
  view font12→18,Reflow while paused,verify visible source and no synchronous
  render. Resume,commit exactly1 Pixbuf,hide source for display but retain it
  in hidden-inclusive text and exact clipboard copy. Destroy view and return
  retained-raster ledger to captured baseline.
- `recovers display math fallback`:drive one real Math_Element through invalid
  fraction→valid x+y→four100em rule width overflow→real fraction→queued a/z+1
  replacement. Independent Build/Measure preflight proves width>8192 at24px/em
  and bounded height. Poll terminal state;check exact selectable source label
  and hidden area for failure,opposite visibility for valid adoption,Show_All
  behavior,adopted positive raster delta and return to entry baseline. Explicit
  Shutdown/Start(Paused=>True)/Resume makes replacement deterministically queued.

Real worker parse/layout/raster and GTK adoption run;no new test-only product
API or smaller limits. Direct Rich_Text.Insert and Math_Element creation bypass
conversation Markdown extraction/placement,so this is GUI-COMPONENT integration,
not a whole conversation workflow or painted-pixel/human visual oracle.

## Final checks

- Exact-final source9c5ec844c7227f1c6a11af11f02ffb4d3bcac6016c8155e242e99f1550d6cbb7.
- Focused2/2 twice;full1078/1078 twice,zero failures/errors,148.229304s and
  149.106815s cumulative. Coarse timestamps show148/150 seconds elapsed.
- Fresh private1280×1024 WM-free Xvfb;XAUTHORITY preserved;fatal GTK criticals.
- Conversation_Stack59 registered cases,AUnit1078;counts are not qualification.
- Development root/test builds pass;final pause/resume and measured-log edits
  followed by exact test build. Prior root build remains valid:product unchanged.
- Post-final-build GTK9/9,interaction containment,tool-layout3/3,layout-runner36
  assertions and offline HTTP pass. Synthetic interaction children7/9 include
  expected kill/timeout;the harness passes,not every synthetic child.
- Source/binary hashes,patch and checksums retained;no executables or obj trees.
  Required GTK child logs external to the archived aggregate are not all retained;
  do not treat their original temporary paths as guaranteed accessible artifacts.

Exact full logs report retained raster baseline1000 and final1000 for BOTH new
fixtures;focused logs baseline0/final0. Wide rejection also equals entry baseline.
Positive adopted-raster deltas are asserted. This establishes no NET tracked
raster growth from the tested sequence,NOT ownership isolation,whole-process
leak freedom or legitimacy of the pre-existing1000-byte charge. Its origin is
not resolved here. Broader native losses remain open.

## Rejected drafts and provenance

`development/initial-validation/` retains TWO full1077/1078 failures at the new
hardcoded ledger-zero assertion. Focused drafts2/2 passed because their baseline
was zero. Final captured-baseline oracle corrects scope;it does not waive any
pre-existing charge. Initial file SHA197c3d... is a FILE HASH,not a git revision.

Initial invalid-inline loop merely waited without observing terminal state and
could pass for pending work:removed,not promoted to coverage. Initial fraction
used doubled backslashes:corrected to actual fraction. Start(Paused=>True) does
not pause a running pool;exact-final explicitly restarts paused. Intermediate
refined1078 passes are retained but precede that last pause/resume/log correction;
only exact-final/full-*.log establish final full results. Final rejection log
uses observed Wide_Rejection_Bytes rather than echoing the expected baseline.

Initial wrong-cwd build log is retained separately. A final-validation worker
reported an earlier wrong-cwd launch exit127,but separate raw launch log was not
retained in its final directory;this is report-only setup failure,NOT test
execution or a passing attempt. Earlier worker interpretation of197c3d as an
unavailable git base is erroneous and not a source comparison claim. Final
manifest/patch hashes govern. No automated rerun-until-pass loop.

## Reproduce

From root `alr build --development`;from test
`alr build --development --profiles=coyote=development`.

From root:

- `xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' sh -c 'unset WAYLAND_DISPLAY; export GDK_BACKEND=x11 G_DEBUG=fatal-criticals; cd test; timeout -k 10s 300s ./bin/coyote_test "Coyote.GUI.Conversation_Stack recovers"'`
- Same command without the quoted filter for full suite;repeat on fresh display.
- `python3 test/tools/check-gtk-interactions.py`
- `python3 test/tools/check-gtk-interaction-runner.py`
- `python3 test/tools/check-gtk-tool-layout.py`
- `python3 test/tools/check-gtk-tool-layout-runner.py`
- `python3 test/tools/check-http-timeout-lifecycle.py`

Retain XAUTHORITY;do not use env-i without copying it. No live-provider checks.
Bounded GUI waits are test watchdogs,not hard native preemption/timing guarantees.

## Limits and review

Wide measured preflight plus GUI fallback does not expose authoritative worker
status/diagnostic;expiry could win. No deterministic exact rejection-reason claim.
Queued replacement is not forced in-flight cancellation. Font reflow is before
first successful inline commit,not committed-image resize qualification. Display
selectable fallback is not a display clipboard or accessibility acceptance test.
Net ledger equality does not prove isolated ownership;1000-byte prior charge
unresolved. No physical-worker affinity or allocation-failure injection.

Agent/coordinator review found no material blocker,not independent acceptance.
No new runtime bug selected. No browser/geometry/raster comparator/fuzz/Valgrind
rerun. Fonts,cache/repaint,whole-conversation placement/copy/replay,forced active
worker failures,timing/native lifecycle/parity/human gates remain open. Historical
unclassified GTK allocation failures and strict raster losses are not waived.
PCR-125 OPEN. No release/install/commit.
