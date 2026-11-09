#!/usr/bin/env python3
"""Offline checks for GTK runner failure containment (no GTK/display needed)."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile

RUNNER = Path(__file__).with_name("check-gtk-interactions.py").resolve()

with tempfile.TemporaryDirectory(prefix="gtk-runner-selftest-") as temporary:
    root = Path(temporary)
    fake = root / "fake-worker"
    fake.write_text(
        "#!/usr/bin/env python3\n"
        "import os, signal, sys, time\n"
        "name = sys.argv[1]\n"
        "if name == 'unicode': os.kill(os.getpid(), signal.SIGKILL)\n"
        "if name == 'bidi': time.sleep(10)\n"
        "print('PASS', name, flush=True)\n"
    )
    fake.chmod(0o700)
    environment = dict(os.environ, DISPLAY=":selftest-not-used")
    result = subprocess.run(
        [sys.executable, str(RUNNER), "--worker", str(fake),
         "--aunit", str(fake), "--no-xvfb", "--timeout", "1",
         "--output-dir", str(root / "logs")],
        env=environment, text=True, capture_output=True, timeout=20,
    )
    print(result.stdout, end="")
    assert result.returncode == 1, result.stderr
    assert "Summary: 7/9 passed" in result.stdout
    output = next((root / "logs").iterdir())
    assert "result=-9" in (output / "02-unicode.log").read_text()
    assert "result=timeout" in (output / "03-bidi.log").read_text()
    assert "result=0" in (output / "09-math-boundary.log").read_text()
    assert output.stat().st_mode & 0o777 == 0o700
    assert all(path.stat().st_mode & 0o777 == 0o600
               for path in output.iterdir())
    for timeout in ("nan", "inf", "0", "-1"):
        bad = subprocess.run(
            [sys.executable, str(RUNNER), "--timeout", timeout],
            capture_output=True, timeout=5,
        )
        assert bad.returncode == 2
    missing = subprocess.run(
        [sys.executable, str(RUNNER), "--worker", str(root / "missing")],
        capture_output=True, timeout=5,
    )
    assert missing.returncode == 2
    print("PASS: abnormal exit/timeout containment, continuation, private logs, "
          "invalid arguments")
