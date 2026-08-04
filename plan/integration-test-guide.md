# Integration Test Guide

This project keeps all live integration tests **opt-in**. The default AUnit run
must stay CI-safe and must not require network access, API credentials, acme, or
plumber state unless a test is explicitly guarded.

## Current Status

There are no live LLM API integration tests checked in. Acme/9P and dispatch
integration tests are opt-in and auto-detect their live environment. PCR-044
adds manual qualification procedures DEM-029..032 for sandbox session
restoration, frontend synchronization, and child-process propagation.

## Principles

- Unit tests run by default.
- Live tests are skipped unless an explicit environment variable enables them.
- Missing credentials should **skip** the test, not fail the whole suite.
- CI should continue to run only the default guarded-off suite.
- Never hardcode secrets in fixtures, source, or session files.

## Recommended Guard Pattern

Each live test should require:

1. a dedicated boolean-style guard variable, and
2. the provider credential required by that test.

Suggested conventions:

- OpenRouter: `COYOTE_RUN_OPENROUTER_LIVE=1`
- Anthropic: `COYOTE_RUN_ANTHROPIC_LIVE=1`
- GitHub Copilot: `COYOTE_RUN_GITHUB_COPILOT_LIVE=1`
- acme / 9P integration: `COYOTE_RUN_ACME_LIVE=1`

A test should return immediately when the guard is absent or not equal to `1`.
If the guard is present but the credential is missing, the test should report a
clear skipped/disabled message.

## Running the Full Default Test Suite

```sh
cd /home/gtnoble/Projects/coyote/test
alr run coyote_test
```

This command should remain safe without any live credentials.

## Example: Run Future OpenRouter Live Tests

```sh
export COYOTE_RUN_OPENROUTER_LIVE=1
export OPENROUTER_API_KEY=your-key-here

cd /home/gtnoble/Projects/coyote/test
alr run coyote_test
```

## Example: Run Future Anthropic Live Tests

```sh
export COYOTE_RUN_ANTHROPIC_LIVE=1
export ANTHROPIC_API_KEY=your-key-here

cd /home/gtnoble/Projects/coyote/test
alr run coyote_test
```

## Example: Run Future GitHub Copilot Live Tests

GitHub Copilot live tests should rely on the existing authenticated pi agent
state (`~/.pi/agent/auth.json`) rather than embedding tokens in the test code.

```sh
export COYOTE_RUN_GITHUB_COPILOT_LIVE=1

cd /home/gtnoble/Projects/coyote/test
alr run coyote_test
```

If a test also needs a fresh login, run `pi login github-copilot` first.

## Example: Run Existing acme / 9P Live Tests

When acme-backed integration tests need a live editor namespace, start acme and
ensure the Plan 9 environment is configured first:

```sh
export PLAN9=/usr/local/plan9
export COYOTE_RUN_ACME_LIVE=1

cd /home/gtnoble/Projects/coyote/test
alr run coyote_test
```

## Test Authoring Notes

- Keep live tests in clearly named `*_integration_tests.adb` units.
- Put guard checks at the top of each test procedure.
- Use short prompts and conservative token budgets.
- Assert broad behavior, not brittle exact wording.
- Prefer provider smoke tests over large multi-turn transcripts.
- Clean up temporary files and windows even on failure.


## Example: Run Future Ollama Live Tests

Ollama can run locally on `localhost:11434` (default) or you can use Ollama Cloud
at `https://ollama.com`.

```sh
# For local Ollama instance (if running on port 11434):
export COYOTE_RUN_OLLAMA_LIVE=1

cd /home/gtnoble/Projects/coyote/test
alr run coyote_test
```

If the local instance is not available, integration tests will skip gracefully.

For Ollama Cloud, set the API key and base URL in `~/.coyote/models.json`:

```json
{
  "providers": {
    "ollama": {
      "baseUrl": "https://ollama.com",
      "apiKey": "your-token-here"
    }
  }
}
```

Then set the guard and run:

```sh
export COYOTE_RUN_OLLAMA_LIVE=1

cd /home/gtnoble/Projects/coyote/test
alr run coyote_test
```

## PCR-044 Sandbox Session Qualification

The automated suite verifies session-header reading and agent-level profile
restoration. The following manual demonstrations verify the remaining
frontend, shell, and child-process behavior. Use a disposable test profile
under `~/.coyote/sandbox/` and a test working directory; do not use a profile
that can modify important user data.

### DEM-029 — Resume restoration

1. Start coyote with a named sandbox profile selected.
2. Complete a turn that invokes the shell tool, then record the session UUID.
3. Exit coyote and resume with `coyote --session UUID`.
4. Verify the frontend status shows the saved profile and a subsequent shell
   command runs with that profile's restrictions.
5. Repeat with a session created without a profile and verify no profile is
   active after resume.

### DEM-030 — Session switching and clearing

1. Create one session with profile A and another with profile B.
2. In one Acme or GUI instance, switch from A to B and verify the displayed
   profile and the next shell command use B.
3. Switch from B to a session with no `sandboxProfile` header field.
4. Verify the displayed profile is cleared and the next shell command is
   unsandboxed.

### DEM-031 — Child-process propagation

1. Run a parent session with a named sandbox profile.
2. Use the shell-based subagent flow to start a child coyote process.
3. Inspect the child session header and run a child shell command.
4. Verify the child header records the effective profile and the command is
   subject to the profile's restrictions.

### DEM-032 — Frontend, agent, and environment synchronization

Exercise startup/resume, explicit profile changes, new-session creation, and
session switching in both Acme and GUI. At each boundary verify that the
status display, the agent's next shell command, and the inherited
`COYOTE_SANDBOX_PROFILE` value identify the same profile, including the empty
value when sandboxing is cleared.

## Non-Goals

- Do not add tests that require real credentials in CI.
- Do not record real API responses containing secrets.
- Do not make the default `alr run coyote_test` depend on network access.
