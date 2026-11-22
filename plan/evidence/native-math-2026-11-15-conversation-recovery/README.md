# Conversation math and surviving-buffer destruction

Project date2026-11-15; host logs2026-11-22. Parent8cb4694. Report §11.32.
The prior §11.31 component increment remains uncommitted and preserved.

## Changes

- `Rich_Text.On_State_Destroy` now removes owned committed formula images and
  restores formula source visibility after abandoning pending/adoption work.
  A surviving GtkTextBuffer no longer retains those inline images simply because
  its view was destroyed. No forced ledger release or whole-buffer erase.
- Public spec documents surviving-buffer cleanup; unrelated images unaffected.
- Mixed-response test uses actual Begin_Request, streamed Append_Text and
  End_Text_Block, split after an opening inline dollar. It verifies four ordered
  response children (text, valid display fraction, text, invalid display), exact
  display source labels/area visibility, and one inline Pixbuf in EACH paragraph.
  Supported source is hidden; unsupported source stays visible. Actual GTK
  copy-clipboard signal returns the exact selected tail line through clipboard.
  Two Clear/reconstruction rounds return raster charges to the entry baseline.
- Deterministic retained-buffer test holds an explicit native Glib.Object.Ref
  across view destruction and checks readable source, zero Pixbufs and baseline
  charge BEFORE releasing that reference.

Requirements, resource limits and budgets unchanged. Other runtime source and
prior component procedures are unchanged. No new test-only product API.

## Final results

Development root/test builds pass; active GNAT15.2 and GPRbuild25 via Alire.
New focused cases each1/1 twice; previous component cases2/2.
Two exact final suites1080/1080, zero assertion failures or unexpected errors:
143.532677s/143.308856s cumulative,143.62s/143.40s wall. Fresh private WM-free
1280×1024 Xvfb, X11, preserved XAUTHORITY and fatal GTK criticals.
Required GTK interactions9/9, containment harness passes (expected synthetic
children7/9), tool layout3/3, layout-runner36 assertions and offline HTTP pass.
Full logs record instrumented GUI entry/final baselines0, including held-buffer
checks. Earlier suite baselines1000 are no longer observed at these checkpoints;
this does not independently trace that earlier charge or establish global leak
freedom. Registration61 conversation cases/full1080 is not qualification.

`final/` retains builds, tests, commands, timings and identities. Exact final:

- Test source23a0ffd86fb05c4a03444f604ffe075dcd215cd1ecece8eb3faf846a003cb8dd.
- Rich_Text body7d28012a978b0963862e809b9e9498e93b23d5af1a5932a56646f0b0926734be.
- Rich_Text spec cf3363a7162fc5df910b2dfb91bfa717b6143c3f0aed72aedd3211a2cbb60762.
- Test binary e630e61bd0a45c49299c15185483bc0ef1a4eb77798c9ea4c65a524b772260bc.

`manifest.json` and SHA256SUMS govern complete identities. Binaries/obj trees
omitted. Detailed mandatory-check child logs outside the archived aggregates
are not all retained; paths printed in logs are not guaranteed accessible.

## Reproduced failure and controls

`ownership-diagnostics/` retains the unchanged pre-fix test snapshot, script,
variant patches, builds and focused failures. Baseline, no-copy and unrealized
variants EACH leave3808 bytes after Clear, Shutdown and a five-second wait.
Copying and realization are therefore not necessary to reproduce the failure;
these observations do not identify every native reference or allocation.

`negative-control/` uses EXACT final tests with only the OLD parent Rich_Text
body. Both tests fail: held-buffer source remains hidden; mixed-response cleanup
leaves3808. The fixed body was restored byte-for-byte and rebuilt before final
validation. No assertion was weakened, no ledger charge manually cleared.
`first-fix/` records the first passing conversation result with the cleanup fix.

`development/initial-weaker/` preserves earlier1079 passes for a weaker test that
checked only the active view's raster and lacked the cleanup assertion. They are
not final1080 evidence. `development/retained-buffer/` preserves evolving focused
builds. A worker reported an intermediate inherited-display1078/1079 full failure
at the pre-existing760×600 tool allocation assertion (observed109×1033). No
separate raw log/display provenance was supplied for archival: report-only,
unclassified and unwaived. Final private-display passes do not classify it.
Wrapper readonly-zsh-variable/quote errors are setup issues, not tests.

File hashes9c5ec/b124899/etc are NOT git commit identifiers. Earlier worker claims
that those Git objects were unavailable are incorrect interpretations, not source
comparison evidence. The coordinator reconstructed the prior test snapshot from
HEAD plus §11.31 patch, verified hash9c5ec844..., and checked both component
procedure bodies byte-identical. `increment-only-tests.patch` compares against
that uncommitted prior test state; `implementation.patch` includes the combined
working-tree runtime/test delta against parent8cb4694.

## Reproduce

From root: `alr build --development`.
From test: `alr build --development --profiles=coyote=development`.

From test, use fresh private displays for each invocation:

- `env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' timeout -k 10s 300s ./bin/coyote_test 'Coyote.GUI.Conversation_Stack preserves mixed math response source'`
- Same with filter `Coyote.GUI.Conversation_Stack releases retained math buffer images`.
- Same without a filter for full suite. Preserve XAUTHORITY; do not use env-i.

From root run `check-gtk-interactions.py`, `check-gtk-interaction-runner.py`,
`check-gtk-tool-layout.py`, `check-gtk-tool-layout-runner.py`, and
`check-http-timeout-lifecycle.py` under `python3 test/tools/` paths.
Coverage mapper rerun leaves tracked crosswalk unchanged: GUI file not covered.

## Limits and review

Conversation test covers a selected paragraph copy, not whole-response
cross-widget selection, and clear/reconstruction, not persisted-session replay.
Widget placement/text/visibility and Pixbuf presence are not a painted-pixel or
human visual oracle. Visible invalid-inline source does not independently prove
its worker's terminal status. No forced in-flight cancellation or hard timing.
Destroy callback retains its existing catch-all exception behavior; injected GTK
mutation failures and multi-view shared-buffer behavior remain unqualified.

Agent/coordinator review found no material blocker; developer review is not
independent acceptance. No browser/reference, geometry, raster, fuzz or Valgrind
rerun. Strict native lifecycle losses, fonts/parity, cache/repaint, timing,
physical-worker affinity and human acceptance remain open. No exhaustive memory
accounting, storage pools or retained-lease redesign selected. PCR-125 OPEN.
No release, installation or commit.
