# PCR-128 — first conversation robustness increment

Evidence keyed to the approved robustness continuation of the 2026-11-07
crash investigation; raw logs retain host timestamps. No parity or product
acceptance is claimed.

## Implemented scope

- `Coyote_GUI.Text_Safety` centralizes conversation view configuration,
  NUL-free UTF-8 presentation, fresh-end-iterator append and stream decoding.
- First Configure binds the calling Ada task in a protected owner; the caller
  must ensure that first call is on GTK. Later Configure/Set_Text/Append calls
  on another task raise Program_Error before invoking GTK. Other application
  GTK calls are not covered by this guard.
- Response and thinking streams use separate decoders. Incomplete UTF-8 stays
  outside GTK until completed; invalid bytes and NUL become U+FFFD. Ordinary
  close/new-request/step/abort flush tails; clear discards pending suffixes.
- Final Markdown rendering uses the same sanitized response source. Persisted
  session source and Plain behavior are unchanged. Existing rich-text marks,
  formula source copying, reflow, search and PCR-127 layout policy remain.
- Isolated native interaction worker and runner retain private logs, finite
  deadlines, per-case exit/timeout status and GTK/Pango version metadata. Each
  case has its own process group; cleanup terminates/reaps the leader and sends
  group signals for ordinary descendants. This is not a security sandbox or
  containment guarantee for children which deliberately escape the group.

## Repeatable commands

From repository root:

```sh
alr build --development
(cd test && alr build --development --profiles=coyote=development)
(cd test && G_DEBUG=fatal-criticals xvfb-run -a ./bin/coyote_test \
  'Coyote.GUI.Conversation_Stack text safety')
python3 test/tools/check-gtk-interactions.py --output-dir /tmp/coyote-gtk-checks
python3 test/tools/check-gtk-interaction-runner.py
(cd test && /usr/bin/time -f 'wall=%e user=%U sys=%S exit=%x' \
  xvfb-run -a ./bin/coyote_test)
```

## Recorded results

- Root/test development builds pass with existing warnings; generated profiles
  select development. Final build logs are retained here.
- New focused cases: 5/5, no assertion failures or unexpected errors, 0.112202s
  cumulative, with fatal GTK criticals. Coverage: off-task rejection before GTK,
  request NUL/invalid-byte replacement; bytewise two/three/four-byte response
  assembly; raw/Markdown tail flush; thinking, new request, abort, step and clear.
- Isolated matrix: 9/9. Five named worker scenarios plus a plain repeat, each
  with two create/copy/resize/font/scroll/clear rounds; three existing AUnit
  cases supply actual link click, hover, and hidden-math line-boundary coverage.
  Worker uses public GTK hit-test/selection APIs rather than simulating every
  possible physical event. Logs and GTK3.24.41/Pango1.52.1 metadata are retained
  in `interaction-logs/`. Each process has a default 30-second deadline.
- Offline runner self-test passes: intentional SIGKILL and timeout produce
  failure results, later cases still execute, final summary7/9 is required and
  the runner correctly returns failure. Parent verifies private 0700 directory/
  0600 logs and rejects nonfinite/nonpositive timeouts/missing executables.
  These intentional failures are not application test failures.
- Full suite: 1074/1074, zero failures/errors, 146.502911s cumulative,
  146.65s wall, exit0, run from `test/` (fixture-relative cwd).

## Development corrections and limits

A cancelled subagent left incomplete harness files; coordinator reviewed and
completed them locally. Initial build errors were corrected before verification.
An initial worker matrix passed5/6: multiline source-equality was an incorrect
oracle because Markdown normalizes soft line breaks. The final oracle compares
clipboard output to complete buffer source and retains explicit formula/Unicode
and multiline-content checks. Initial SIGTRAP fault injection was delayed by
the host crash handler and timed out; deterministic SIGKILL checks abnormal
exit independently of core-reporting behavior. No production GTK failures are
suppressed. Existing theme CSS warnings remain nonfatal.

This is not application-wide thread enforcement, native SIGTRAP recovery,
source-only recovery UI, a document-model/source-display separation, whole-GUI
process isolation, exhaustive Unicode/font/theme/selection fuzzing, physical
desktop or accessibility acceptance. No live-provider checks or installed-binary
update/release/commit was made. Developer self-review is not independent user
acceptance. The broader robustness effort remains open.

`implementation.patch` covers tracked integration/test edits; new package and
worker/runner files are retained as normal repository source. `SHA256SUMS` covers
this evidence archive except itself. No user session content is archived.
