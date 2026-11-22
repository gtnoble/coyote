# Persisted mixed-math replay validation

Date: 2026-11-22

## Scope and freeze

Validation-only; no code edits were made by this validation turn, no subagents were spawned, and no commit/install/release action was performed. HEAD before and after validation: `e61fd4346dd5614fbbf6ec69a5fc1ecf096d1e76`.

The pre-existing worktree change set is exactly these four test files (no product source, tools, requirements, or documentation):

- `test/src/coyote_app-frontend-gui-testing.ads`
- `test/src/coyote_app-frontend-gui-testing.adb`
- `test/src/coyote_app_frontend_gui_tests.ads`
- `test/src/coyote_app_frontend_gui_tests.adb`

Hashes before testing and at final check are in `test-source-before.sha256`; all four matched. `git diff --check` passed. Build profiles are `development` in `config/coyote_config.gpr` and `test/config/coyote_test_config.gpr`.

## Builds and tests

| Validation | Result | Evidence |
|---|---:|---|
| Root `alr build --development` | PASS, exit 0, 2.00 s wall | `root-build.log`, `root-build.time` |
| Test `cd test && alr build --development --profiles=coyote=development` | PASS, exit 0, 4.43 s wall | `test-build.log`, `test-build.time` |
| Persisted GUI replay case, final controlled run on fresh WM-free 1280x1024x24 Xvfb, X11 backend, Wayland unset, fatal GTK criticals, 300 s/10 s TERM/KILL bound | PASS, 1/1 | `focused-final.log`, `focused-final.time` |
| Same new replay case, two other fresh private displays | PASS, 1/1 each | `focused-private-1.log`, `focused-private-2.log` and `.time` files |
| Full suite, two sequential independent private WM-free Xvfb displays, test cwd, Wayland unset, X11 backend, `G_DEBUG=fatal-criticals`, 300 s timeout with 10 s kill grace | PASS, 1081/1081 each; 144.19 s and 144.28 s wall | `full-qualified-1.log/.time`, `full-qualified-2.log/.time` |
| Existing `Coyote_App.History` prefix | PASS, 2/2 | `history-prefix.log` |
| Existing `Coyote.GUI clear conversation preserves agents` prefix | PASS, 1/1 | `clear-conversation-prefix.log` |
| GTK interaction checks under fatal-critical environment | PASS, 9/9 | `gtk-interactions-qualified.log` and child logs under `gtk-interactions-qualified/` |
| GTK interaction runner containment self-test | PASS | `gtk-interaction-runner-selftest.log` (synthetic 7/9 expected) |
| GTK tool-layout exact-size test on three fresh private displays under fatal-critical environment | PASS, 3/3 | `gtk-tool-layout-qualified.log`, child logs and `summary.json` under `gtk-tool-layout-qualified/` |
| GTK tool-layout runner self-test under fatal-critical environment | PASS, 36 assertions | `gtk-tool-layout-runner-qualified.log` |
| Offline HTTP lifecycle check | INCOMPLETE, not a pass | `http-timeout-lifecycle.time` (outer `timeout` exit 124 at 65.00 s); both captured logs empty. Diagnostic observation showed the helper blocked in its first `run_no_prompt` Plain child (`coyote --one-shot ...`); only that diagnostic helper process was stopped. No matching helper child remained afterward. |

The first unqualified full suite pair and GTK/layout runs are also retained in their `full-1/2`, `gtk-interactions`, and `gtk-tool-layout` files. Required qualified repeats are distinguished above. Existing GTK theme CSS parse warnings were visible during the focused case; GTK interaction and full-suite runs with fatal criticals passed. This does not represent a new GTK warning qualification.

## Commands

Builds:

```sh
alr build --development
cd test && alr build --development --profiles=coyote=development
```

Full suite command (run twice sequentially; each `xvfb-run` starts a fresh display):

```sh
cd test && timeout -k 10s 300s env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' ./bin/coyote_test
```

Focused replay command:

```sh
cd test && timeout -k 10s 300s env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' ./bin/coyote_test 'Coyote_App.Frontend.GUI replays persisted mixed math'
```

Other check commands:

```sh
env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals python3 test/tools/check-gtk-interactions.py --output-dir /tmp/coyote-persisted-math-validation/gtk-interactions-qualified
env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals python3 test/tools/check-gtk-tool-layout.py --output-dir /tmp/coyote-persisted-math-validation/gtk-tool-layout-qualified --repeats 3
env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals python3 test/tools/check-gtk-tool-layout-runner.py
python3 test/tools/check-gtk-interaction-runner.py
```

The HTTP check command attempted was `python3 test/tools/check-http-timeout-lifecycle.py --binary bin/coyote`, guarded by an outer 65-second timeout; it must not be reported as passing.

## Fingerprints and limits

`bin/coyote` SHA-256: `8c468f8a5a74eda4c1cb5507afecf1360a4c854e7182972e871d10fd862c02d8`.

`test/bin/coyote_test` SHA-256 (also recorded by GTK layout metadata): `cd428106dddefc3832630c4c8aed9acedeb405c33ec8733d0726df4a53fd4c00`.

The replay test constructs the persisted session through native `SessionStore` writer calls, reloads exact source with `Load_Messages`, invokes `History.Render_Session_History`, observes GTK math rendering/fallback and clipboard source copy, then clears and reloads for two cycles. It does not qualify browser parity, raster corpus behavior, Valgrind, fuzzing, timing guarantees, global ledger ownership, or human acceptance. No such claims are made here.

Final `git status --short` contains only the four listed modified test files. No validation-created repository artifacts remain.
