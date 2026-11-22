# Persisted mixed-math GUI replay

Project2026-11-15; host logs2026-11-22. Parent e61fd43. Report §11.33.
Test-only increment: four existing test files, no runtime/API/requirements/limits
or budget changes. Conversation_Stack registration61 unchanged; full1081.

## Fixture and assertions

One registered frontend case creates a unique temporary HOME, writes a session
with native Session_Store.Create_Session/Append_Message, then verifies exact
assistant source with Load_Messages. At this HEAD the native writer emits v1
header/bare-message JSONL. No v3-envelope qualification is implied. Source is
static mixed Markdown with valid/unsupported inline and display math.

Actual History.Render_Session_History reads the SAME saved UUID twice. The GUI
frontend queues updates; bounded GTK pumping waits for replay completion and
terminal display elements. Each pass asserts restored turn count1 and working
source directory, exact display source/delimiters, valid drawing area, invalid
fallback/hidden drawing area, exactly1 inline Pixbuf, exact source-inclusive and
visible closing paragraph, and exact clipboard text from the real copy signal.
Both queued clears remove the exchange/math elements and return tracked raster
bytes to captured entry baseline after worker shutdown. Adoption must increase
tracked bytes. No direct text injection stands in for saved-session replay.

Cleanup stops frontend/local RPC service, destroys its window, shuts down math
workers, restores HOME plus four GUI-mutated COYOTE variables (presence/value),
and removes only the owned unique temporary directory. Inherited values are not
logged. Test observers live exclusively in test/src; borrowed active view is not
retained across clear. Global HOME manipulation assumes sequential AUnit runs;
concurrent environment isolation is not qualified. No agent/provider is started.

## Exact-final results

- Development root/test builds pass (1.95s/4.85s wall), active GNAT15.2/GPRbuild25
  via Alire. Existing warnings retained, not warning-free.
- Focused1/1 twice, cumulative0.294904s/0.287346s.
- Full1081/1081 twice, zero assertion failures/unexpected errors;
  cumulative144.235521s/144.221978s, wall144.35s/144.33s.
- Fresh private WM-free1280×1024 Xvfb, X11, preserved XAUTHORITY,
  WAYLAND_DISPLAY unset, fatal GTK criticals.
- GTK interactions9/9, containment harness passes (expected synthetic children
  summary7/9), tool layout3/3, layout-runner36 assertions pass.
- Offline Plain/RPC HTTP lifecycle passes in coordinator run with110-second
  outer allowance,4+4 stalled requests and zero-disable delayed success. Product
  unchanged across final test refinement, so this result is reused rather than
  pretending the earlier cut-off attempt passed.

`exact-final/` contains final builds, focused/full logs, identities and checks.
`offline-http-final.log` is the passing coordinator result. Manifest contains
four exact test hashes and built binary identities. Final main test body:
25421f65c0968de634503acd3a1736ef0be7801e84f1538b30cd7539ef0e8f9b.
No executable or obj payloads. Generated native fixture is deleted by each test,
not separately archived; its actual construction and source remain in the patch.
Detailed child logs are retained where present, but other original temporary
paths printed by aggregates are not guaranteed accessible artifacts.

## Failed/incomplete and evolving runs

`exact-final/full-1.log` is a WRONG-CWD raw execution:960/1081 successful,
28 failed assertions and95 unexpected errors, exit1, cumulative79.251966s,
wall79.36s. It ran from root rather than test/ and encountered fixture-path
failures. It is real failed execution, not no execution, and not a passing or
valid product qualification run. Correct-cwd results are specifically
`full-1-correct-cwd.log` and `full-2.log`. No retry-until-green loop.

`development/validation/` contains earlier source4c161... results before final
source-directory and both-cycle raster cleanup assertions. Do not call these
exact-final results. Its HTTP outer timeout65s ended exit124 with no output;
that is INCOMPLETE, not pass and not proof of application hang. A diagnostic
was stopped; the sufficient110-second coordinator run subsequently passes.
Readonly-zsh-status-variable and shell-quote wrapper errors are setup issues.

The archived worker README describes wrong-cwd output as not a test result;
this checkpoint explicitly qualifies that wording: it is retained failed AUnit
execution under invalid cwd, not accepted product test evidence. Earlier worker
refinement README describes two replay/clear cycles, but its source only cleared
between rounds; exact-final source adds the final clear and ledger assertions.
Manifest/patch/final log names govern scope, not evolving prose summaries.

## Reproduce

Root: `alr build --development`.
Test directory: `alr build --development --profiles=coyote=development`.

From test/ (fresh display for each repeat):

`env -u WAYLAND_DISPLAY GDK_BACKEND=x11 G_DEBUG=fatal-criticals xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' timeout -k 10s 300s ./bin/coyote_test 'Coyote_App.Frontend.GUI replays persisted mixed math'`

Remove the filter for full suite. Preserve XAUTHORITY; do not use env-i.
From root run the five Python tools under test/tools/:
check-gtk-interactions.py, check-gtk-interaction-runner.py,
check-gtk-tool-layout.py, check-gtk-tool-layout-runner.py,
check-http-timeout-lifecycle.py. Allow110s outside the HTTP harness rather than
65s; its own bounded subprocess checks remain unchanged.

## Limits and review

Agent/coordinator review is developer verification, not independent acceptance.
Ordinary native-writer session replay only: compaction, branching/forks, legacy
format matrix, tool-interleaved or malformed/large saved sessions remain open.
Selected paragraph copy is not whole-response cross-widget selection. Visibility
and Pixbuf presence are not pixel/human correctness; visible unsupported inline
source is not an independent terminal-state oracle. Net ledger baseline equality
is not ownership isolation or whole-process/native leak freedom.

No reference/browser, geometry/raster corpus, fuzz or Valgrind rerun. No hard
native timing, forced in-flight, font/cache/repaint/parity or human acceptance
gate closed. Historical GTK allocation failures remain unwaived. No further
fine-grained memory accounting or pool/lease redesign selected. PCR-125 OPEN.
No release, installation or commit.
