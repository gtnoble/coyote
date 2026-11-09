#!/usr/bin/env python3
"""Run deterministic GTK interaction cases in separate bounded processes."""

from __future__ import annotations

import argparse
import math
import os
from pathlib import Path
import resource
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TEST_DIR = ROOT / "test"
SCENARIOS = ("plain", "unicode", "bidi", "inline-math", "multiline", "plain")
AUNIT_CASES = (
    ("link-click", "Coyote.GUI.Conversation_Stack launches Markdown link clicks"),
    ("link-hover", "Coyote.GUI.Conversation_Stack updates Markdown link cursor"),
    ("math-boundary", "Coyote.GUI.Conversation_Stack hit-tests inline math line"),
)


def core_limit() -> None:
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def stop_group(child: subprocess.Popen) -> None:
    # Kill the process group even if its leader has exited: a wrapper can leave
    # worker/display descendants behind. Each case has its own session/group.
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        child.wait(timeout=1)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    child.wait(timeout=3)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worker", type=Path,
                        default=TEST_DIR / "bin" / "gtk_interaction_worker")
    parser.add_argument("--aunit", type=Path, default=TEST_DIR / "bin" / "coyote_test")
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--timeout", type=float, default=30)
    parser.add_argument("--no-xvfb", action="store_true",
                        help="use an existing DISPLAY instead of Xvfb")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be finite and positive")
    worker = args.worker.expanduser().resolve()
    if not worker.is_file() or not os.access(worker, os.X_OK):
        parser.error(f"worker not executable: {worker}")
    aunit = args.aunit.expanduser().resolve()
    if not aunit.is_file() or not os.access(aunit, os.X_OK):
        parser.error(f"AUnit binary not executable: {aunit}")
    if not args.no_xvfb and not shutil.which("xvfb-run"):
        parser.error("xvfb-run is required (or use --no-xvfb)")
    if args.no_xvfb and not os.environ.get("DISPLAY"):
        parser.error("--no-xvfb requires DISPLAY")
    os.umask(0o077)
    if args.output_dir:
        parent = args.output_dir.expanduser().resolve()
        parent.mkdir(parents=True, exist_ok=True)
    else:
        parent = None
    # Never overwrite existing logs or follow an existing case-log symlink.
    output = Path(tempfile.mkdtemp(prefix="gtk-interactions-", dir=parent))
    print(f"Logs: {output}", flush=True)
    try:
        version = subprocess.run(
            ["pkg-config", "--modversion", "gtk+-3.0", "pango"],
            capture_output=True, text=True, timeout=3, check=False)
        versions = version.stdout.strip() or version.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as error:
        versions = str(error)
    (output / "versions.log").write_text(versions + "\n")
    env = dict(os.environ, G_DEBUG="fatal-criticals")
    failed = 0
    cases = [(name, [str(worker), name]) for name in SCENARIOS]
    cases += [(name, [str(aunit), prefix]) for name, prefix in AUNIT_CASES]
    for index, (name, command) in enumerate(cases, 1):
        if not args.no_xvfb:
            command = ["xvfb-run", "-a", *command]
        log_path = output / f"{index:02d}-{name}.log"
        status = "launch-error"
        child = None
        with log_path.open("xb") as log:
            log.write(f"scenario={name} timeout={args.timeout}\n".encode())
            log.flush()
            try:
                child = subprocess.Popen(
                    command, cwd=TEST_DIR, env=env,
                    stdin=subprocess.DEVNULL, stdout=log,
                    stderr=subprocess.STDOUT, start_new_session=True,
                    preexec_fn=core_limit)
                try:
                    status = child.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    status = "timeout"
            except OSError as error:
                log.write(f"launch-error: {error}\n".encode())
            finally:
                if child is not None:
                    stop_group(child)
            log.write(f"\nresult={status}\n".encode())
        if status == 0:
            print(f"PASS {name}: {log_path}", flush=True)
        else:
            failed += 1
            print(f"FAIL {name} ({status}): {log_path}", flush=True)
    print(f"Summary: {len(cases) - failed}/{len(cases)} passed")
    return int(failed > 0)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
