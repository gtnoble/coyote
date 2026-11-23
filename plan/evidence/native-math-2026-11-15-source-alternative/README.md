# Exact LaTeX source alternative — scoped developer evidence

User decision and current requirements: SRS-MATH v1.2 / report §11.34.
Base commit and final source/binary identities: `identities.txt`.
`implementation.patch` covers production/test/tool changes, including removals.
No binaries or build object directories are retained.

## Passing final evidence

- `validation/root-build-final.log`: root development build, final product code.
- `validation/test-build-final5.log`: test development build, final tests.
- `validation/zoom-final2.log`: final realized font regression1/1.
- `validation/full-final.log`: final full1081/1081;153.831214s cumulative,
  153.87s wall. Includes all61 conversation cases and persisted replay.
- `validation/*-final.log`: GTK9/9, containment expected synthetic7/9,
  layout3/3, layout-runner36, HTTP offline lifecycle, Help/Mallard/CLI.
- `validation/layout-final/`: private-display runner metadata and repeat logs.
- `validation/coverage-final.log`: unchanged coverage counts, updated012 text.

Full command (run from test/):

```sh
env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' /usr/bin/time -f 'wall=%e exit=%x' ./bin/coyote_test
```

Root build: `alr build --development`; test build:
`cd test && alr build --development --profiles=coyote=development`.
Mandatory checks: `python3 test/tools/check-gtk-interactions.py`,
`check-gtk-interaction-runner.py`, `check-gtk-tool-layout.py --output-dir ...`,
`check-gtk-tool-layout-runner.py`, `check-http-timeout-lifecycle.py`.
Help: `xvfb-run -a sh test/check-help.sh`.

## Intermediate and failed attempts — not final passes

Earlier no-font-integration snapshot passes conversation61/full1081 in
`conversation-final.log`/`full.log`. `test-build.log` fails because the test
omitted enum-operator visibility. `conversation.log` aborts with a GTK critical
when an unattached source view tries to copy; fixture fixed by window attachment.
`conversation-font-final.log` has60/61 success; `zoom-final.log`0/1 because font
context was inspected without expanding/realizing the source panel. Final test
expands the actual source view, shows the parent and processes GTK events before
checking exact font identity; `zoom-final2.log` and `full-final.log` pass.
Intermediate source files/binaries were not frozen separately; these logs are
development provenance, not exact-final negative controls or product failures.

## Scope and limits

Display source panel is read-only/selectable, exact and replacement-aware in
pending/rejected/valid states. Existing inline copying remains. Removed the
unused structure-tree adapter/probe/project. Source/fallback fonts follow
conversation settings independently of explicit math scale.
Developer review, not independent acceptance. No semantic screen-reader math,
manual keyboard/narrow-window/large-source usability qualification, browser,
geometry/raster/fuzz/Valgrind rerun or parity/timing/native-lifecycle closure.
Existing theme/compiler warnings persist. External mandatory-harness child logs
mentioned in aggregates are not retained except layout runner children; paths
under /tmp are not guaranteed available. No release/install/commit.
