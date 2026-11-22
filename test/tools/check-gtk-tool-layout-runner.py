#!/usr/bin/env python3
"""Self-test private GTK layout runner containment; not GUI acceptance."""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from unittest import mock

RUNNER = Path(__file__).with_name("check-gtk-tool-layout.py").resolve()
spec = importlib.util.spec_from_file_location("gtk_tool_layout_runner", RUNNER)
runner = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = runner
spec.loader.exec_module(runner)
ASSERTIONS = 0


def check(value: bool, message: str) -> None:
    global ASSERTIONS
    ASSERTIONS += 1
    assert value, message


def executable(root: Path, mode: str) -> Path:
    path = root / "fake-aunit"
    path.write_text(
        "#!/usr/bin/env python3\n"
        "import os, pathlib, signal, subprocess, sys, time\n"
        f"mode = {mode!r}\n"
        "state = pathlib.Path(__file__).with_suffix('.state')\n"
        "count = int(state.read_text()) if state.exists() else 0\n"
        "state.write_text(str(count + 1))\n"
        "if mode == 'timeout-first' and count == 0:\n"
        "    signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
        f"    child = subprocess.Popen([{sys.executable!r}, '-c', "
        "'import signal, time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(60)'])\n"
        "    pathlib.Path(__file__).with_suffix('.pid').write_text(str(child.pid))\n"
        "    time.sleep(120)\n"
        "if mode == 'environment':\n"
        "    assert os.environ.get('G_DEBUG') == 'fatal-criticals', os.environ\n"
        "    assert os.environ.get('GDK_BACKEND') == 'x11', os.environ\n"
        "    assert not os.environ.get('WAYLAND_DISPLAY'), os.environ\n"
        "if mode == 'zero-one': print('Total Tests Run: 1 Successful Tests: 1 Failed Assertions: 0 Unexpected Errors: 01'); sys.exit(0)\n"
        "if mode == 'wrong': print('Total Tests Run: 1 Successful Tests: 0 Failed Assertions: 0 Unexpected Errors: 0'); sys.exit(0)\n"
        "if mode == 'missing': print('no test summary'); sys.exit(0)\n"
        "if mode == 'partial': print('Total Tests Run: 1 Successful Tests: 1 Failed Assertions: 0 Unexpected Errors: 0\\nSuccessful Tests: 1'); sys.exit(0)\n"
        "if mode == 'nonzero': print('Total Tests Run: 1\\nSuccessful Tests: 0\\nFailed Assertions: 1\\nUnexpected Errors: 0'); sys.exit(4)\n"
        "if mode == 'filtered': print('Total Tests Run: 2\\nSuccessful Tests: 2\\nFailed Assertions: 0\\nUnexpected Errors: 0'); sys.exit(0)\n"
        "print('Total Tests Run: 1\\nSuccessful Tests: 1\\nFailed Assertions: 0\\nUnexpected Errors: 0')\n"
    )
    path.chmod(0o700)
    return path


def invoke(aunit: Path, out: Path, repeats: int = 1,
           timeout: str = "3") -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(RUNNER), "--aunit", str(aunit), "--output-dir", str(out),
         "--timeout", timeout, "--repeats", str(repeats)],
        text=True, capture_output=True, timeout=60, check=False,
    )


def dead(pid: int) -> bool:
    try:
        stat = Path(f"/proc/{pid}/stat").read_text().split()[2]
        return stat == "Z" or not Path(f"/proc/{pid}").exists()
    except FileNotFoundError:
        return True


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="gtk-tool-layout-selftest-") as temp:
        root = Path(temp)
        # xprop accepts both zero-valued spellings and absent/no-atom results.
        for value in (
            "_NET_SUPPORTING_WM_CHECK(WINDOW): window id # 0x0\n",
            "_NET_SUPPORTING_WM_CHECK(WINDOW) = 0x0\n",
            "_NET_SUPPORTING_WM_CHECK(WINDOW) = 0\n",
            "_NET_SUPPORTING_WM_CHECK: not found.\n",
            "_NET_SUPPORTING_WM_CHECK: no such atom on any window.\n",
            "",
        ):
            ok, detail = runner._wm_property(value)
            check(ok, f"zero/absent property rejected: {value!r}: {detail}")
        for value in (
            "_NET_SUPPORTING_WM_CHECK(WINDOW): window id # 0x2400001\n",
            "_NET_SUPPORTING_WM_CHECK(WINDOW) = 0x2400001\n",
            "_NET_SUPPORTING_WM_CHECK(WINDOW) = 1\n",
            "_NET_SUPPORTING_WM_CHECK(WINDOW): window id # 0x0\nextra\n",
            "_NET_SUPPORTING_WM_CHECK(WINDOW) = 0x0\n_NET_SUPPORTING_WM_CHECK(WINDOW) = 0x0\n",
        ):
            ok, detail = runner._wm_property(value)
            check(not ok, f"nonzero/ambiguous property accepted: {value!r}: {detail}")

        # Enforce actual root dimensions; never resize a display to satisfy the gate.
        with mock.patch.object(runner.subprocess, "run", side_effect=[
            subprocess.CompletedProcess([], 0, "_NET_SUPPORTING_WM_CHECK(WINDOW) = 0x0\n", ""),
            subprocess.CompletedProcess([], 0, "dimensions: 1280x1024 pixels\n", ""),
        ]) as mocked:
            ok, detail = runner.display_metadata({"DISPLAY": ":fake"})
            check(ok and "1280x1024" in detail, f"expected root rejected: {detail}")
            check(mocked.call_count == 2, "display metadata did not query xprop and xdpyinfo")
        with mock.patch.object(runner.subprocess, "run", side_effect=[
            subprocess.CompletedProcess([], 0, "_NET_SUPPORTING_WM_CHECK(WINDOW) = 0x0\n", ""),
            subprocess.CompletedProcess([], 0, "dimensions: 760x600 pixels\n", ""),
        ]):
            ok, detail = runner.display_metadata({"DISPLAY": ":fake"})
            check(not ok and "760, 600" in detail, "old small root dimensions were accepted")

        good_dir = root / "good"
        good_dir.mkdir()
        good = executable(good_dir, "success")
        success = invoke(good, root / "success-logs", repeats=2)
        check(success.returncode == 0, success.stdout + success.stderr)
        check("Summary: 2/2 passed" in success.stdout, success.stdout)
        success_root = root / "success-logs"
        summary = json.loads((next(success_root.iterdir()) / "summary.json").read_text())
        check(len(summary["repeats"]) == 2 and all(row["binary_sha256"] for row in summary["repeats"]),
              "repeat metadata missing hashes")
        check(all(row["screen"] == "1280x1024x24" and row["cleanup_ok"] is True
                  for row in summary["repeats"]), "screen/cleanup metadata incorrect")

        env_dir = root / "environment"
        env_dir.mkdir()
        env_result = invoke(executable(env_dir, "environment"), root / "environment-logs")
        check(env_result.returncode == 0, env_result.stdout + env_result.stderr)

        for mode in ("wrong", "missing", "nonzero", "zero-one", "partial", "filtered"):
            bad_dir = root / mode
            bad_dir.mkdir()
            result = invoke(executable(bad_dir, mode), root / f"{mode}-logs")
            check(result.returncode == 1, (mode, result.stdout, result.stderr))

        timeout_dir = root / "timeout"
        timeout_dir.mkdir()
        timed = executable(timeout_dir, "timeout-first")
        result = invoke(timed, root / "timeout-logs", repeats=2, timeout="2")
        check(result.returncode == 1 and "FAIL repeat 1 (timeout)" in result.stdout,
              result.stdout)
        check("cleanup_ok=True" in result.stdout, result.stdout)
        check("PASS repeat 2 (0)" in result.stdout, result.stdout)
        child_pid = int(timed.with_suffix(".pid").read_text())
        deadline = time.monotonic() + 3
        while not dead(child_pid) and time.monotonic() < deadline:
            time.sleep(0.05)
        check(dead(child_pid), f"TERM-resistant timeout descendant {child_pid} survived KILL escalation")
        state = Path(f"/proc/{child_pid}/stat")
        if state.exists():
            check(state.read_text().split()[2] == "Z", "surviving descendant is not a zombie/non-running")

        for option, value in (("--timeout", "nan"), ("--timeout", "inf"),
                              ("--timeout", "0"), ("--timeout", "-1"),
                              ("--repeats", "0"), ("--repeats", "21")):
            result = subprocess.run([sys.executable, str(RUNNER), option, value],
                                    text=True, capture_output=True, timeout=5)
            check(result.returncode == 2, (option, value, result.stderr))
        missing = subprocess.run(
            [sys.executable, str(RUNNER), "--aunit", str(root / "absent")],
            text=True, capture_output=True, timeout=5)
        check(missing.returncode == 2, "missing binary accepted")
    print(f"PASS {ASSERTIONS} assertions: WM property forms, root dimensions, exact summaries,")
    print("PASS child G_DEBUG/GDK environment; TERM-resistant process-group KILL escalation and recovery")
    print("PASS bounded arguments, missing binary, metadata hashes and cleanup status")
    print("Synthetic runner checks only; not GUI acceptance.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
