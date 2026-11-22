# GUI math fallback validation

Date: 2026-11-22

## Scope and source identity

Validation only: no source or test edits were made during this validation, no subagents were used, and no release/install/commit was performed. Baseline HEAD was `8cb46948190ade6bfbc2c4c5a52a45c8a74f5d57`. At start, only `test/src/coyote_gui_conversation_stack_tests.adb` was modified: +357 lines, adding registered inline and display worker fallback/recovery tests. These checks characterize that working-tree state, not a final/refined revision. The file's final SHA-256 is `197c3d47759ab09094bdd975c87c0b80eb8742989522941e64019b4d94d9ba33`; test binary SHA-256 is `150949704a76093215cd75f615f480b71bac9ffe2e97fb9f3fab1ac7f148c04f`; root binary SHA-256 is `896f2b4461c9bf62fd97ba03ff3db99bf1ca50e3f2ddacea7ca806f6d94bb4dc`. Initial and final tracked status contains only the test source modification; generated Python `__pycache__` was removed. No product source, requirements, or tools were changed.

Conversation_Stack registration count in this source: 59 (includes both new cases). Full AUnit reported 1,078 tests; that is the observed full registry/run total, not an inferred target.

## Build

Commands:

```sh
alr build --development
cd test && alr build --development --profiles=coyote=development
```

Both passed. The first root build took 3.01 s wall / 3.79 s user / 1.31 s sys. The correctly located test build took 6.22 s wall / 8.83 s user / 2.11 s sys. Generated root and test GPR configuration both declare `Build_Profile := "development"`. `root-build.log` and `test-build-correct-cwd.log` preserve outputs.

A mistakenly invoked test build from repository root is separately retained as `test-build.log`; it only reported root targets up-to-date and is not counted as the test crate build.

## Focused new cases

Command (run twice sequentially; each used fresh Xvfb):

```sh
xvfb-run -a -s '-screen 0 1280x1024x24' sh -c 'export GDK_BACKEND=x11 G_DEBUG=fatal-criticals; xprop -root _NET_SUPPORTING_WM_CHECK; xdpyinfo | grep -E "dimensions:"; cd test && ./bin/coyote_test "Coyote.GUI.Conversation_Stack recovers"'
```

Both runs passed 2/2, 0 failed assertions, 0 unexpected errors; cumulative times were 3.333574 s and 3.353174 s. Both fresh display root properties were absent (`no such atom`) and roots were 1280x1024. First run recorded GTK 3.24.41 and Pango 1.52.1. `XAUTHORITY=/home/gtnoble/.Xauthority` was preserved and readable; no `env -i` was used. GTK theme CSS parsing warnings occurred in focused logs and are retained verbatim.

Logs: `focused-run-1.log`, `focused-run-2.log`.

## Full suite (fresh private Xvfb, sequential)

Command for each run:

```sh
timeout --signal=TERM --kill-after=10 300 xvfb-run -a -s '-screen 0 1280x1024x24' sh -c 'export GDK_BACKEND=x11 G_DEBUG=fatal-criticals; xprop -root _NET_SUPPORTING_WM_CHECK; xdpyinfo | grep -E "dimensions:"; cd test && ./bin/coyote_test'
```

Both runs finished in 152.03 s wall, within the 300 s timeout, with root 1280x1024 and WM property absent. Both reported 1,078 run, 1,077 successful, 1 failed assertion, 0 unexpected errors (cumulative 151.842640 s and 151.851496 s). The same new case failed in both: `Coyote.GUI.Conversation_Stack recovers display math fallback`, assertion `wide rejection releases retained raster charge` at `test/src/coyote_gui_conversation_stack_tests.adb:3708`. No rerun, test change, assertion suppression, or automated pass loop was applied. This remains an unresolved failure; these results are not a passing full-suite claim.

Logs: `full-run-1.log`, `full-run-2.log`.

## Other requested checks

- `python3 test/tools/check-gtk-tool-layout.py --output-dir /tmp/coyote-gui-fallback-validation --repeats 3 --timeout 30`: 3/3 passed on separate fresh private WM-free Xvfb displays. Screen 1280x1024x24; GTK 3.24.41 / Pango 1.52.1; identical AUnit binary SHA above; all cleanup succeeded. See `gtk-tool-layout-repeat3.log` and `gtk-tool-layout-h9j2tzc9/` (including summary JSON and per-repeat logs).
- `python3 test/tools/check-gtk-tool-layout-runner.py`: passed 36 assertions. Synthetic runner checks only, not GUI acceptance. `gtk-tool-layout-runner.log`.
- `python3 test/tools/check-gtk-interaction-runner.py`: its expected synthetic outcome was Summary 7/9, with injected SIGKILL and timeout failures; its own containment assertions passed. This is not a product test failure. `gtk-interaction-runner.log`.
- `python3 test/tools/check-gtk-interactions.py` (default private Xvfb): actual scenarios passed 9/9 (six worker scenarios plus link-click, link-hover, math-boundary AUnit cases); 16.29 s wall. `gtk-interactions-actual.log` and `gtk-interactions/`.
- `python3 test/tools/check-gtk-interactions.py --no-xvfb` (current inherited display): actual scenarios passed 9/9. `gtk-interactions-current-display.log`.
- `python3 test/tools/check-http-timeout-lifecycle.py`: passed offline Plain/RPC timeout lifecycle and zero-disable delayed success, 4+4 stalled requests; 65.71 s wall. Local fixture only. `http-timeout-lifecycle.log`.

## Interpretation and limits

The focused cases and independent GTK/layout/lifecycle checks passed as stated, but the complete AUnit suite is not green because the same retained-raster assertion failed twice. These are development validation results, not independent acceptance, release qualification, human GUI acceptance, native-math parity, memory/timing qualification, or closure of broader project gates. No Valgrind, browser, geometry, or job checks were requested or run. Existing warnings are preserved in logs; no claim that builds are warning-free.

## Log index

- Builds: `root-build.log`, `test-build-correct-cwd.log`, mistaken-cwd `test-build.log`
- Focused: `focused-run-1.log`, `focused-run-2.log`
- Full: `full-run-1.log`, `full-run-2.log`
- Layout: `gtk-tool-layout-repeat3.log`, `gtk-tool-layout-runner.log`, `gtk-tool-layout-h9j2tzc9/`
- GTK interactions: `gtk-interactions-actual.log`, `gtk-interactions/`, `gtk-interactions-current-display.log`, `gtk-interactions-current-display/`, `gtk-interaction-runner.log`
- Offline HTTP: `http-timeout-lifecycle.log`
