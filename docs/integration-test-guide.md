# Integration Test Guide

This project keeps all live integration tests **opt-in**. The default AUnit run
must stay CI-safe and must not require network access, API credentials, acme, or
plumber state unless a test is explicitly guarded.

## Current Status

As of Phase 12 there are **no live LLM API integration tests checked in**.
This guide documents how they should be written and how to run them once they
exist.

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

## Non-Goals

- Do not add tests that require real credentials in CI.
- Do not record real API responses containing secrets.
- Do not make the default `alr run coyote_test` depend on network access.
