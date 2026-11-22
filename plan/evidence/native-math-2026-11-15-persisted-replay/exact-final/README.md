# Persisted mixed-math GUI replay — exact validation gate

Date: 2026-11-22

## Scope and frozen inputs

Validation only. No product/source edits, requirements edits, subagents, commit,
release, or installation were performed. The test changes were already present
at start: exactly four modified test files. `HEAD` is
`e61fd4346dd5614fbbf6ec69a5fc1ecf096d1e76` before and after validation.
Parent-requested preceding test revision was `4c161...`; this workspace's
current test sources were measured and frozen before builds. `HEAD` is the
product-source baseline (product commit `e61fd43`).

The new AUnit registration is `Coyote_App.Frontend.GUI replays persisted mixed
math`; the existing `Coyote.GUI.Conversation_Stack` registration count remains
61. The test writes the fixture through `LLM.Session_Store`, then replays it
through `Coyote_App.History` into the queued GTK path, checks source directory,
valid/invalid display math, inline Pixbuf adoption and copy-source behavior,
clears after both rounds including the final round, shuts down math jobs, checks
raster ledger equality with entry baseline, and asserts restoration of inherited
HOME and four COYOTE GUI environment values (presence and value). Fixture root
is unique temporary HOME, deleted by the test. The case uses no live LLM service.
No encoded hand-authored session fixture was archived or claimed.

## Commands and outcomes

Builds (development profile):

- `alr build --development` — PASS, 1.95 s wall.
- `cd test && alr build --development --profiles=coyote=development` — PASS,
  4.85 s wall. Existing Ada warning: an unused `with` clause in
  `coyote_app_frontend_gui_tests.ads`; not warning-free.

Focused replay case, twice, in separate fresh private Xvfb invocations:

```sh
xvfb-run -a -s '-screen 0 1280x1024x24' \
  env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals \
  timeout --signal=TERM --kill-after=10s 300s \
  /home/gtnoble/Projects/coyote/coyote-latex-math/test/bin/coyote_test \
  'Coyote_App.Frontend.GUI replays persisted mixed math'
```

Both PASS 1/1, 0 failures/errors (0.294904 s and 0.287346 s AUnit cumulative).
Each display reported 1280x1024, 24-bit root and no window-manager atom.
Existing GTK theme CSS parsing warnings appeared; no criticals.

Full suite, sequentially twice, from the required `test` working directory, each
on a fresh private WM-free Xvfb display with the same screen, GDK, Wayland,
`G_DEBUG`, and timeout settings:

```sh
cd /home/gtnoble/Projects/coyote/coyote-latex-math/test
xvfb-run -a -s '-screen 0 1280x1024x24' \
  env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals \
  sh -c 'cd /home/gtnoble/Projects/coyote/coyote-latex-math/test && \
    exec timeout --signal=TERM --kill-after=10s 300s ./bin/coyote_test'
```

Both exact-cwd runs PASS 1081/1081, zero failed assertions and unexpected
errors. AUnit cumulative times: 2m24.235521s and 2m24.221978s; measured wall
times: 144.35s and 144.33s. No retry was needed.

Required post-build checks:

- `python3 test/tools/check-gtk-interactions.py` — PASS 9/9.
- `python3 test/tools/check-gtk-interaction-runner.py` — PASS. Its expected
  synthetic worker outcomes are 7/9 (forced SIGKILL and timeout cases fail);
  runner containment assertions pass, including continuation, private logs,
  invalid arguments, and cleanup.
- `python3 test/tools/check-gtk-tool-layout.py` — PASS 3/3.
- `python3 test/tools/check-gtk-tool-layout-runner.py` — PASS 36 assertions.

Offline HTTP lifecycle coordinator evidence was already present and reused:
`/tmp/coyote-persisted-math-http-coordinator.log`, timestamp
2026-11-22 16:08:47 -0600. It reports Plain/RPC timeout lifecycle and ZERO-disable
delayed success, 4+4 stalled requests, offline fixture only. No rerun was needed
because product source did not change. This is not live-provider testing.

## Preserved invocation error

The first full-suite attempt was accidentally started from repository root
rather than `cd test`. It is preserved at
`full-1.log` (tool-captured full output also exists as
`/tmp/coyote_shell_617321_1.txt`). It produced fixture-path failures, including
paths resolving at repository root, and is not a test result or pass. After
correcting the working directory, two consecutive full runs passed as above.
The first shell wrapper also encountered zsh's reserved `status` variable after
the first focused test passed; this was a wrapper error, not an AUnit failure.

## Fingerprints and artifacts

- `source-before.txt`, `source-after.txt`: `HEAD`, product tracked source/tools/
  requirements aggregate hash, and all four test source SHA-256 hashes.
- `source-after.txt`: also records built product executable and test executable
  hashes.
- `root-build.log`, `test-build.log`, `focused-1.log`, `focused-2.log`,
  `full-1-correct-cwd.log`, `full-2.log`, and check logs: commands' output.

Before/after `HEAD`, tracked product source/tools/requirements aggregate, and all
four test-source hashes match exactly. Product binaries were fingerprinted;
they were not intentionally rebuilt/installed as a release. `git status --short`
contains only the four test source modifications listed below; no pycache or
other generated repository files remain:

- `test/src/coyote_app-frontend-gui-testing.adb`
- `test/src/coyote_app-frontend-gui-testing.ads`
- `test/src/coyote_app_frontend_gui_tests.adb`
- `test/src/coyote_app_frontend_gui_tests.ads`

Xvfb/display metadata recorded: X11, 1280x1024, 24-bit root, no WM support
property, `GDK_BACKEND=x11`, `G_DEBUG=fatal-criticals`, `WAYLAND_DISPLAY` unset.
No full environment dump or credentials were recorded.

## Qualification limits

These results qualify the stated developer regression runs only. They do not
close managed-window/desktop GTK behavior, native-math parity, geometry/raster
or browser gates, timing/resource qualification, lifecycle/Valgrind gaps, live
provider qualification, or independent human acceptance. Private Xvfb success
is not a historical GTK closure or product acceptance claim.
