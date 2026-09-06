# Integration Test Guide

This project keeps all live integration tests **opt-in**. The default AUnit run
must stay CI-safe and must not require network access, API credentials, or a
display unless a test is explicitly guarded.

## Current Status

The Acme and 9P integration surface was removed on 2026-08-30. The active
suite contains no Acme/9P tests. Live provider tests remain opt-in; the
standard suite is safe without network access, credentials, or a display.

PCR-090 records the removal. GUI sandbox/session qualification remains covered
by the existing manual procedures; Plain subprocess tests use the neutral
`COYOTE_TEST_SUBAGENT=1` guard.

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
- Subagent subprocess integration: `COYOTE_TEST_SUBAGENT=1`

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
2. In one GUI instance, switch from A to B and verify the displayed
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
session switching in the GUI. At each boundary verify that the
status display, the agent's next shell command, and the inherited
`COYOTE_SANDBOX_PROFILE` value identify the same profile, including the empty
value when sandboxing is cleared.

### DEM-054 — Sandbox Profiles manager

Use a disposable profile directory and test paths; do not use a profile that
can modify important user data. In a display-backed GUI, open `Options →
Sandbox Profiles...` and verify the reusable modeless `coyote : Sandbox
Profiles` window. Verify the left list permits one selection and the right pane
is always editable. Edit profile A, switch to profile B, edit it, and verify
both drafts remain present and visibly dirty. Exercise New and Duplicate
Profile without writing files, then Save once and verify every dirty draft is
persisted. Verify invalid names, duplicate names, and empty path entries block
all writes before Save. Verify Cancel discards edits to multiple profiles and
removes unsaved New/Duplicate drafts. Verify Refresh preserves dirty drafts and
loads clean external changes. Verify Rename and Delete are absent from the
manager; compatibility rename remains covered separately by backend tests.
Verify the four rule lists preserve `~`, `.`, `./`, absolute, and missing path
spellings. Verify Use Profile queues the active-session `Set_Sandbox` command
and rejects an unsaved new profile. Full interaction remains display-backed
qualification.

## Non-Goals

- Do not add tests that require real credentials in CI.
- Do not record real API responses containing secrets.
- Do not make the default `alr run coyote_test` depend on network access.
