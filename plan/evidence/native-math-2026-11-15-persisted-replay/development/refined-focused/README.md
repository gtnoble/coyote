# Persisted mixed-math replay focused verification

Date: 2026-11-22

## Scope

Four test-only files: frontend GUI test declaration/body and frontend GUI
observer spec/body. The replay test uses native `SessionStore.Create_Session`,
`Append_Message`, `Load_Messages`, `History.Render_Session_History`, and the
GTK `copy-clipboard` signal. It checks exact persisted assistant source,
completed replay, exact display delimiters, invalid-display fallback, inline
GTK visibility/copy, two replay/clear cycles, and restoration of HOME plus the
four GUI-mutated `COYOTE_*` variables (without logging inherited values).

The repository already contained uncommitted replay-test scaffold and related
read-only GUI observers before this edit; no registration or spec declaration
for the replay test was newly added here. The only new observer operation is
`Conversation_Is_Completed`. No product source, docs, requirements, subagents,
full suite, install, or commit.

## Verification

Development build passed:

`cd test && alr build --development --profiles=coyote=development`

Focused replay test passed three times, each on a fresh WM-free 1280x1024 Xvfb
display with `WAYLAND_DISPLAY` unset:

`cd test && env -u WAYLAND_DISPLAY xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' ./bin/coyote_test 'Coyote_App.Frontend.GUI replays persisted mixed math'`

Each run: 1 test, 1 success, 0 failed assertions, 0 unexpected errors.
`git diff --check` passed. Existing GTK theme CSS parse warnings remain.

Third-run output: `focused-repeat-3.log`. Final worktree diff:
`worktree-diff.patch`. Final source hashes: `source-sha256.txt`.
