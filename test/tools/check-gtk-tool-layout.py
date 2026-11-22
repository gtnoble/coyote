#!/usr/bin/env python3
"""Run the single GTK tool-layout AUnit case on private WM-free Xvfb displays."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import resource
import shutil
import signal
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TEST_DIR = ROOT / "test"
FILTER = "Coyote.GUI tool detail stable layout and snapshots"
SCREEN = "1280x1024x24"
SUMMARY = re.compile(
    r"^\s*Total\s+Tests\s+Run\s*:\s*1\s*\r?\n"
    r"\s*Successful\s+Tests\s*:\s*1\s*\r?\n"
    r"\s*Failed\s+Assertions\s*:\s*0\s*\r?\n"
    r"\s*Unexpected\s+Errors\s*:\s*0\s*$",
    re.IGNORECASE | re.MULTILINE,
)
SAFE_ENV = ("DISPLAY", "GDK_BACKEND", "GTK_IM_MODULE", "GTK_MODULES",
            "XDG_SESSION_TYPE", "G_DEBUG")


def core_limit() -> None:
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def stop_group(child: subprocess.Popen) -> tuple[bool, str]:
    """Try TERM, bounded wait, KILL, and reap even when a step errors."""
    problems: list[str] = []
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    except (OSError, PermissionError) as error:
        problems.append(f"SIGTERM failed: {error}")

    try:
        child.wait(timeout=1)
    except subprocess.TimeoutExpired:
        pass
    except (OSError, ChildProcessError) as error:
        problems.append(f"wait after SIGTERM failed: {error}")

    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    except (OSError, PermissionError) as error:
        problems.append(f"SIGKILL failed: {error}")

    try:
        child.wait(timeout=3)
    except subprocess.TimeoutExpired:
        problems.append("leader was not reaped within 3 seconds; no hard process guarantee")
    except (OSError, ChildProcessError) as error:
        problems.append(f"final wait failed: {error}; no hard process guarantee")

    return not problems, "; ".join(problems) if problems else "TERM/KILL/wait completed"


def _wm_property(value: str) -> tuple[bool, str]:
    """Return whether xprop output proves the property is absent or zero."""
    text = value.strip()
    if not text:
        return True, "absent"
    lowered = text.lower()
    if "not found" in lowered or "no such atom" in lowered:
        return True, "absent"

    forms = (
        r"^_NET_SUPPORTING_WM_CHECK\s*\([^)]*\)\s*:\s*window\s+id\s+#\s*(0x[0-9a-f]+|[0-9]+)\s*$",
        r"^_NET_SUPPORTING_WM_CHECK\s*\([^)]*\)\s*=\s*(0x[0-9a-f]+|[0-9]+)\s*$",
    )
    matches = [re.fullmatch(pattern, text, re.IGNORECASE) for pattern in forms]
    parsed = [match.group(1) for match in matches if match]
    if len(parsed) != 1:
        return False, f"ambiguous window-manager property: {text}"
    try:
        number = int(parsed[0], 0) if parsed[0].lower().startswith("0x") else int(parsed[0])
    except ValueError:
        return False, f"ambiguous window-manager property: {text}"
    if number != 0:
        return False, f"window manager property present: {text}"
    return True, text


def display_metadata(env: dict[str, str]) -> tuple[bool, str]:
    try:
        prop = subprocess.run(
            ["xprop", "-root", "_NET_SUPPORTING_WM_CHECK"], env=env,
            capture_output=True, text=True, timeout=3, check=False)
        if prop.returncode != 0:
            return False, f"xprop failed: {prop.stderr.strip()}"
        safe, property_detail = _wm_property(prop.stdout)
        if not safe:
            return False, property_detail
        info = subprocess.run(
            ["xdpyinfo"], env=env, capture_output=True, text=True,
            timeout=3, check=False)
        if info.returncode != 0:
            return False, f"xdpyinfo failed: {info.stderr.strip()}"
        dimensions = re.search(r"dimensions:\s+(\d+)x(\d+) pixels", info.stdout)
        actual = tuple(map(int, dimensions.groups())) if dimensions else None
        if actual != (1280, 1024):
            return False, f"private display root dimensions are {actual}, expected 1280x1024"
        return True, f"root-property={property_detail} dimensions={actual[0]}x{actual[1]}"
    except (OSError, subprocess.TimeoutExpired) as error:
        return False, f"display metadata failed: {error}"


def worker_with_summary(aunit: Path) -> int:
    env = {key: os.environ[key] for key in SAFE_ENV + ("XAUTHORITY",)
           if key in os.environ}
    if not env.get("DISPLAY") or env.get("GDK_BACKEND") != "x11":
        print("worker requires private DISPLAY and GDK_BACKEND=x11", file=sys.stderr)
        return 2
    print("display-environment: " + json.dumps(
        {key: env[key] for key in SAFE_ENV if key in env}, sort_keys=True),
        flush=True)
    ok, detail = display_metadata(env)
    print(f"display-check: {detail}", flush=True)
    if not ok:
        return 2
    result = subprocess.run(
        [str(aunit), FILTER], cwd=TEST_DIR, env=env, stdin=subprocess.DEVNULL,
        capture_output=True, text=True, check=False)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    if result.returncode != 0:
        return result.returncode if result.returncode > 0 else 1
    if len(list(SUMMARY.finditer(result.stdout))) != 1:
        print("required exact one-test AUnit summary missing or unsuccessful", file=sys.stderr)
        return 3
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aunit", type=Path, default=TEST_DIR / "bin" / "coyote_test")
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--timeout", type=float, default=30)
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--_worker-internal", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--_worker-aunit", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args._worker_internal:
        if args._worker_aunit is None:
            parser.error("internal worker requires AUnit path")
        return worker_with_summary(args._worker_aunit)
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be finite and positive")
    if not 1 <= args.repeats <= 20:
        parser.error("--repeats must be between 1 and 20")
    aunit = args.aunit.expanduser().resolve()
    if not aunit.is_file() or not os.access(aunit, os.X_OK):
        parser.error(f"AUnit binary not executable: {aunit}")
    tools = {name: shutil.which(name) for name in ("xvfb-run", "xprop", "xdpyinfo")}
    missing = [name for name, path in tools.items() if path is None]
    if missing:
        parser.error("required private-display tools missing: " + ", ".join(missing))
    os.umask(0o077)
    parent = args.output_dir.expanduser().resolve() if args.output_dir else None
    if parent:
        parent.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="gtk-tool-layout-", dir=parent))
    print(f"Logs: {output}", flush=True)
    binary_hash = hashlib.sha256(aunit.read_bytes()).hexdigest()
    try:
        versions = subprocess.run(
            ["pkg-config", "--modversion", "gtk+-3.0", "pango"],
            capture_output=True, text=True, timeout=3, check=False)
        version_text = versions.stdout.strip() or versions.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as error:
        version_text = str(error)
    records = []
    for index in range(1, args.repeats + 1):
        log_path = output / f"repeat-{index:02d}.log"
        command = [tools["xvfb-run"], "-a", "-s", f"-screen 0 {SCREEN}",
                   sys.executable, str(Path(__file__).resolve()), "--_worker-internal",
                   "--_worker-aunit", str(aunit)]
        env = {key: value for key, value in os.environ.items()
               if key in SAFE_ENV + ("XAUTHORITY",)}
        env.pop("WAYLAND_DISPLAY", None)
        env.update(GDK_BACKEND="x11", G_DEBUG="fatal-criticals")
        status: int | str = "launch-error"
        cleanup_ok: bool | None = None
        cleanup_detail = "not started"
        child = None
        with log_path.open("xb") as log:
            log.write(f"repeat={index} screen={SCREEN} timeout={args.timeout}\n".encode())
            log.flush()
            try:
                child = subprocess.Popen(
                    command, cwd=TEST_DIR, env=env, stdin=subprocess.DEVNULL,
                    stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
                    preexec_fn=core_limit)
                try:
                    status = child.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    status = "timeout"
            except OSError as error:
                log.write(f"launch-error: {error}\n".encode())
            finally:
                if child is not None:
                    cleanup_ok, cleanup_detail = stop_group(child)
                    if not cleanup_ok and status == 0:
                        status = "cleanup-failed"
            log.write(f"\nresult={status}\ncleanup_ok={cleanup_ok}\n"
                      f"cleanup_detail={cleanup_detail}\n".encode())
        record = {"repeat": index, "status": status, "cleanup_ok": cleanup_ok,
                  "cleanup_detail": cleanup_detail, "log": log_path.name,
                  "binary_sha256": binary_hash, "versions": version_text,
                  "screen": SCREEN}
        records.append(record)
        print(f"{'PASS' if status == 0 else 'FAIL'} repeat {index} ({status}); "
              f"cleanup_ok={cleanup_ok}: {log_path}", flush=True)
    summary_path = output / "summary.json"
    summary_path.write_text(json.dumps({"aunit": str(aunit), "filter": FILTER,
                                        "binary_sha256": binary_hash,
                                        "versions": version_text, "screen": SCREEN,
                                        "repeats": records}, indent=2) + "\n")
    passed = sum(record["status"] == 0 for record in records)
    print(f"Summary: {passed}/{args.repeats} passed; metadata: {summary_path}")
    return int(passed != args.repeats)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
