# GTK allocation display qualification

Parent2e3073a,project date2026-11-15;host log timestamps may differ.
Controlling report §11.30. Product,Ada test,requirements and limits unchanged.
This increment adds two Python qualification/containment tools plus engineering
records. It does not implement a product window-manager workaround.

## Investigation and evidence interpretation

The unchanged focused AUnit test asserts a760×600 window allocation within1s.
It passes on private WM-free Xvfb but fails476×1033 on inherited i3 desktop.
A controlled private1280×1024 Xvfb with minimal private i3 fails1276×1000.
Stopping ONLY that private WM and rerunning on the SAME X display passes1/1.
Three additional fresh private-i3 runs reproduce1276×1000. This establishes
window-manager tiling as a sufficient cause for exact-allocation failure in the
controlled setup. It does NOT identify the actual display environment/cause of
historical116×1033 and109×1033 failures in report §11.29. Those remain
unclassified,unwaived,and their original evidence is not changed.

No user desktop settings were modified. Private i3 config/harness/logs retained
under controlled-i3/. Its aggregate shell exit is not the test outcome:inspect
managed_i3_exit_status and fresh_i3_repeat_exit_status (all1),and the same-display
no-WM exit0. The script uses fixed local paths and is a retained experiment,not
the product regression runner. Tiling legitimately controls product geometry;
no forcing float,override-redirect,product resize change or assertion relaxation.

## New tools and exact-final results

`python3 test/tools/check-gtk-tool-layout.py --repeats 6`:

- Fresh private1280×1024×24 Xvfb for EVERY repeat;force X11,exclude Wayland.
- Keep XAUTHORITY. Query root dimensions and require absent/zero WM property.
- Run existing fixed AUnit filter from test cwd;require return0 AND exact
  four-line one-test successful summary. Original760×600/1s criterion unchanged.
- Record binary SHA256,GTK/Pango versions,allowlisted display environment,
  screen and cleanup results in fresh private logs/summary.json.
- Default30s per process group;TERM/KILL with bounded waits;record cleanup
  failure and continue. Does not promise hard OS/native preemption or reaping
  every grandchild. Zombie descendants are non-running,not independently reaped.
- No all-environment dump or inherited-display bypass.

Final6/6 native repeats pass,each existing AUnit1/1 with cleanup_ok=true.
`python3 test/tools/check-gtk-tool-layout-runner.py` passes36 synthetic assertions:
WM property forms/ambiguity,root dimension independence,strict summaries,invalid
arguments/missing executable,child G_DEBUG/GDK propagation,TERM-resistant timeout
process-group escalation and next-repeat recovery. These are harness negative
controls,not GUI or security qualification. Terminal fake-child logs are temporary;
self-test source and aggregate output retained. No full synthetic child corpus is
claimed retained. Final read-only agent review found no material blocker;this is
developer review,not independent acceptance.

Early runner used760×600 root and dropped G_DEBUG before AUnit;those preliminary
native passes are NOT accepted final evidence. Final1280×1024 root is larger
than expected window,so screen clamping does not manufacture the expected size.
An intermediate self-test failed while summary fixtures were being refined;
validation/gtk-layout-runner-selftest.log retains that failure;the final self-test
and final-runner/selftest.log supersede it,not erase it.

## Broader regression and setup failures

- Development root/test builds pass,active GNAT15.2/GPR25,GTK3.24.41/Pango1.52.1.
- Post-build full suite WM-free1280×1024:1076/1076 twice,zero failures/errors.
  First148.611749s cumulative/149s coarse wall;second146.221611s/146.27s wall.
- Pre-build full also1076/1076,147.980539s/148.06s;uses prior binary,not merged
  with post-build identities. Original safe display-only header retained.
- One full attempt launched env-i without XAUTHORITY:exits at GUI initialization
  after114s,authorization error. This is FAILED SETUP,not passing suite or layout
  result. Corrected runs preserve XAUTHORITY;no access control disabled.
- Exploratory `coyote_test --help` is interpreted as an unmatched literal filter:
  zero tests/exit1. Retained,not claimed a product case or successful check.
- Required GTK interactions9/9,GTK runner containment and offline HTTP pass.
  Expected7/9 synthetic interaction children include kill/timeout;harness passes.
- Existing theme CSS warnings appear in focused controlled runs. No claim of
  warning-free build,rendering parity,managed desktop geometry or user acceptance.

Source hashes verify all production,Ada tests and requirements still match
parent2e3073a. AUnit registration remains1076. Executables/obj trees omitted;
manifest identifies pre/post-build binaries and exact final new tool sources.
No browser/reference geometry/raster/fuzz/Valgrind rerun. Existing native raster
losses,macro mutation/undo amplification,GUI visible math fallback/reflow/cache,
resource/timing/font/parity and human gates remain open. Next feature-specific
increment is GUI source fallback and recovery,not further memory accounting.

## Reproduction

From repository root after development builds:

- `python3 test/tools/check-gtk-tool-layout.py --repeats 6`
- `python3 test/tools/check-gtk-tool-layout-runner.py`
- `xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' sh -c 'unset WAYLAND_DISPLAY; export GDK_BACKEND=x11; cd test; timeout -k 10s 300s ./bin/coyote_test'`
- Existing required checks: `check-gtk-interactions.py`,
  `check-gtk-interaction-runner.py`, `check-http-timeout-lifecycle.py` in test/tools.

For the controlled i3 A/B,inspect controlled-i3/run.sh before adapting its local
paths. It creates only private displays and private i3 processes. Do not manage
or terminate the user's desktop WM. No full environment capture is needed.

Current private-display repeat procedure passes;historical failures remain
unclassified rather than retroactively resolved. PCR-125 OPEN.
No release,installation,commit or independent acceptance.
