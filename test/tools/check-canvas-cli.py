#!/usr/bin/env python3
"""Exercise the additive CLI without a frontend or provider (CAN-CLI-01 subset)."""

import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
COYOTE = ROOT / "bin" / "coyote"
LEGACY = ROOT / "bin" / "coyote_list_sessions"


def run(binary, args, cwd, env, *, success):
    command = [str(binary), *args]
    result = subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                            timeout=10, stdin=subprocess.DEVNULL)
    assert (result.returncode == 0) == success, (command, result)
    if success:
        assert not result.stderr, (command, result.stderr)
    else:
        assert result.stderr.startswith(b"error: "), (command, result.stderr)
        assert not result.stdout, (command, result.stdout)
    return result


def fixture(home, cwd, name, uuid, timestamp, snippet):
    session_dir = home / ".coyote" / "sessions" / (
        "--" + str(cwd).strip("/").replace("/", "-") + "--"
    )
    session_dir.mkdir(parents=True, exist_ok=True)
    rows = [
        dict(type="session", version=3, id=uuid, timestamp=timestamp,
             cwd=str(cwd)),
        dict(type="session_info", name=name),
        dict(type="message", message=dict(role="user", content=[
            dict(type="text", text=snippet)
        ])),
    ]
    (session_dir / f"{uuid}.jsonl").write_text(
        "".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8"
    )


def main():
    with tempfile.TemporaryDirectory(prefix="coyote-canvas-cli-") as directory:
        scratch = Path(directory).resolve()
        home = scratch / "home"
        work = scratch / "work"
        other = scratch / "other"
        for path in (home, work, other):
            path.mkdir()

        # Poison launcher-specific settings and omit credentials and displays.
        # Dispatch must finish before startup even when GUI is requested.
        env = dict(PATH=os.defpath, HOME=str(home), LC_ALL="C",
                   COYOTE_FRONTEND="gui", COYOTE_RECURSION_DEPTH="invalid")
        for scope in ([], ["canvas"], ["canvas", "add"], ["session"],
                      ["session", "list"]):
            short = run(COYOTE, [*scope, "-h"], work, env, success=True)
            long = run(COYOTE, [*scope, "--help"], work, env, success=True)
            assert short.stdout == long.stdout and b"Usage: coyote" in long.stdout
            if not scope:
                for word in (b"session list", b"canvas add", b"--one-shot",
                             b"--subagent", b"--physical-window"):
                    assert word in long.stdout, (word, long.stdout)

        for args in (["session"], ["session", "unknown"],
                     ["session", "list", "extra"], ["canvas"],
                     ["canvas", "unknown"], ["canvas", "add"],
                     ["canvas", "add", "--"], ["canvas", "add", ""],
                     ["canvas", "add", "image.png", "-bad.png"]):
            run(COYOTE, args, work, env, success=False)

        # Literal dash-prefixed and space-containing filenames are operands;
        # the unavailable service is reported without reading either file.
        failure = run(COYOTE, ["canvas", "add", "--", "-bad.png", "my pic.svg"],
                      work, env, success=False)
        assert b"no authorized Canvas service" in failure.stderr
        failure = run(COYOTE, ["canvas", "add", "my pic.svg"], work, env,
                      success=False)
        assert b"no authorized Canvas service" in failure.stderr

        for program, args in ((LEGACY, []), (COYOTE, ["session", "list"])):
            assert run(program, args, work, env, success=True).stdout == b""
        assert not list(home.iterdir()), "CLI created unexpected session/config data"

        fixture(home, work, "older", "old-id", "2026-11-20T12:34:56Z", "old")
        fixture(home, work, "newer", "new-id", "2026-11-21T12:34:56Z", "new")
        fixture(home, other, "other", "other-id", "2026-11-21T15:30:00Z", "else")
        contents = {path: path.read_bytes() for path in home.rglob("*.jsonl")}
        expected_ids = {work: [b"new-id", b"old-id"], other: [b"other-id"]}
        for cwd, ids in expected_ids.items():
            legacy = run(LEGACY, [], cwd, env, success=True).stdout
            current = run(COYOTE, ["session", "list"], cwd, env, success=True).stdout
            assert current == legacy
            rows = [line.split(b"\t") for line in current.splitlines()]
            assert all(len(row) == 4 for row in rows), rows
            assert [row[0] for row in rows] == ids, rows
            assert rows[0][1:] == ([b"newer", b"2026-11-21 12:34", b"new"]
                                    if cwd == work else
                                    [b"other", b"2026-11-21 15:30", b"else"]), rows
        assert {path: path.read_bytes() for path in home.rglob("*.jsonl")} == contents

    print("Canvas CLI: help, errors, no startup, and legacy listing parity passed.")


if __name__ == "__main__":
    main()
