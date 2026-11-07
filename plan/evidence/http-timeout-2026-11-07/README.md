# PCR-126 — HTTP timeout wiring and headless completion evidence

Date: 2026-11-07. Baseline: `8bde561` plus the uncommitted PCR-126 changes.
Developer verification only; not independent acceptance or a release.

## Changes under test

- Apply `Settings_Value.Low_Speed_Time_Seconds` in `LLM.Agent.Create` before
  model catalogue refresh. All frontends use this shared session boundary.
- Expose the protected process-scoped policy through the read-only
  `LLM.HTTP.Configured_Low_Speed_Time_Seconds` query.
- Let an unstarted headless control monitor accept Shutdown as well as Start.
  Plain has no control channel and previously deadlocked during cleanup.
- Add five AUnit cases and a standalone offline subprocess lifecycle harness.

Preferences remain defaults for newly created sessions. Zero disables the
low-speed timeout; positive values retain the fixed one-byte-per-second curl
threshold. Retry/cancellation policy and unlimited total streaming duration
are unchanged. Each request snapshots the process policy.

## Commands and results

All commands were run from the repository root unless prefixed with `cd test`.
Both generated root/test profiles select `development`.

| Command | Result | Retained output |
|---|---|---|
| `alr build --development` | Exit 0; existing project warnings remain, not warning-free qualification | `root-build.log` |
| `cd test && alr build --development --profiles=coyote=development` | Exit 0 | `test-build.log` |
| `cd test && timeout 60 ./bin/coyote_test 'LLM.Agent applies persistent HTTP'` | 1/1; default 30, custom 1, zero, clamp 300, subsequent Create reload 7 | `settings-wiring.log` |
| `cd test && timeout -k 3 70 ./bin/coyote_test 'LLM.Agent retries stalled SSE'` | 1/1; 8.120634 s cumulative; actual code 28, recovery text and successful end/retry events | `retry-success.log` |
| `cd test && timeout -k 3 70 ./bin/coyote_test 'LLM.Agent exhausts retries after repeated HTTP'` | 1/1; 32.022389 s cumulative; four attempts, expected Curl_Error/code 28, failed retry event | `retry-exhaustion.log` |
| `cd test && timeout -k 3 40 ./bin/coyote_test 'LLM.Agent cancels'` | 5/5; 10.381531 s cumulative; includes two new HTTP cases plus three existing Responses cancellation cases | `cancellation.log` |
| `timeout -k 3 100 python3 test/tools/check-http-timeout-lifecycle.py` | Exit 0; early no-prompt Plain completion, four stalls each for Plain/RPC, failed terminal/natural socket and pipe EOF/exit, one delayed zero-disable success | `offline-lifecycle.log` |
| `cd test && timeout -k 5 210 xvfb-run -a ./bin/coyote_test` | Exit 0; 1068/1068; zero failed assertions/unexpected errors; 138.877699 s cumulative | `full-suite.log` |
| `timeout -k 3 100 xvfb-run -a sh test/check-help.sh` | Documentation follow-up: 12/12 core Help and 1/1 widget tests, Mallard validation/links and CLI checks pass; existing GTK theme warnings remain | `documentation-help.log` |
| New Markdown evidence links and REQ-CORE-117 table-cell checks | All checked targets exist; crosswalk rows have expected cell counts | Developer inspection/check |
| `git diff --check` | Exit 0 | No diagnostic output |

The suite's five new registrations are:

- `LLM.Agent applies persistent HTTP low-speed settings on Create`
- `LLM.Agent retries stalled SSE and succeeds after timeout`
- `LLM.Agent exhausts retries after repeated HTTP low-speed timeouts`
- `LLM.Agent cancels during HTTP low-speed retry backoff`
- `LLM.Agent cancels an active stalled HTTP request`

The local harness uses fake credentials and an isolated temporary HOME,
clears inherited Coyote overrides/proxies, uses current cached fixture model
metadata, and contacts a loopback server only. Child tests disable catalogue
refresh and shorten retry backoffs; the production default remains 2/4/8 s.
The RPC harness keeps its socket open through natural child termination rather
than inducing shutdown from the coordinator. It verifies the generated child
runtime identity, timeout notice, failed terminal, EOF, and process exit.

## Development failures and corrections

Initial two/three-second response delays did not reliably trigger curl's
low-speed algorithm after request upload and response headers. The agent
fixture now delays eight seconds; the threaded subprocess fixture stalls for
15 seconds. Initial zero-disable success used the wrong SSE wire format
(Chat Completions); it now supplies Responses API events and delays eight
seconds. Final passing logs above supersede those exploratory fixture runs;
their original output was not archived separately. They were not resolved by
weakening final assertions.

The first offline Plain process never exited after its agent turn, exposing
the separate control-monitor rendezvous deadlock. The production selective
accept correction is included in this evidence, with both no-prompt and
post-request completion exercised. One fixture-repair subagent was aborted by
the user after appearing hung; subsequent bounded runs were completed and
no test or repair processes remained at handover.

## Review and limits

Read-only agent review checked production initialization, selective-accept
shutdown, policy snapshots, test task/server cleanup, and lifecycle assertions;
no remaining actionable defect was reported. This is developer/agent review,
not independent user acceptance. Existing warnings and unrelated qualification
limits remain. Optional live-subagent tests are registered in the full suite
but were not enabled; the new offline harness actually spawns both paths.
No live-provider test, interactive GUI startup/Preferences demonstration,
hard completion-deadline qualification, release build, installation, or restart
of running instances was performed. The installed
`/home/gtnoble/.alire/bin/coyote` remains unchanged; the updated executable is
`bin/coyote`. Timeout policy does not retroactively affect existing requests.
