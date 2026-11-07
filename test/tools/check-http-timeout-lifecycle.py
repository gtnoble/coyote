#!/usr/bin/env python3
"""Offline subprocess regression for coyote's HTTP low-speed timeout lifecycle."""

from __future__ import annotations

import argparse
import json
import os
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BINARY = ROOT / "bin" / "coyote"
MODEL = "openrouter/openai/gpt-4o-mini"
OUTER_TIMEOUT = 45.0
STALL_SECONDS = 15.0
EXPECTED_ATTEMPTS = 4
PROMPT = "Exercise repeated stalled SSE."


class StallServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address):
        super().__init__(address, StallHandler)
        self.request_count = 0
        self.lock = threading.Lock()
        self.response_mode = "stall"
        self.response_delay = 0.0


class StallHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        with self.server.lock:
            self.server.request_count += 1
            mode = self.server.response_mode
            delay = self.server.response_delay
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.flush()
        if mode == "success":
            time.sleep(delay)
            text = "delayed success"
            delta = {
                "type": "response.output_text.delta", "item_id": "msg_test",
                "output_index": 0, "content_index": 0, "delta": text,
            }
            completed = {
                "type": "response.completed",
                "response": {
                    "id": "resp_test", "object": "response",
                    "status": "completed",
                    "output": [{
                        "id": "msg_test", "type": "message",
                        "role": "assistant", "status": "completed",
                        "content": [{"type": "output_text", "text": text}],
                    }],
                    "usage": {"input_tokens": 8, "output_tokens": 3,
                              "total_tokens": 11},
                },
            }
            payload = (
                f"event: response.output_text.delta\ndata: {json.dumps(delta)}\n\n"
                f"event: response.completed\ndata: {json.dumps(completed)}\n\n"
            ).encode()
            self.wfile.write(payload)
            self.wfile.flush()
        else:
            # No SSE byte is sent: curl's configured 1 B/s low-speed deadline
            # must interrupt this response; the outer process deadline is separate.
            time.sleep(STALL_SECONDS)

    def log_message(self, *_args):
        pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def make_home(home: Path, low_speed_seconds: int = 1) -> None:
    agent = home / ".coyote"
    agent.mkdir(parents=True)
    settings = {
        "defaultProvider": "openrouter",
        "defaultModel": "openai/gpt-4o-mini",
        "httpLowSpeedTimeSeconds": low_speed_seconds,
        "maxRecursionDepth": 1,
    }
    (agent / "settings.json").write_text(json.dumps(settings), encoding="utf-8")
    (agent / "models.json").write_text(
        json.dumps({"providers": {"openrouter": {"apiKey": "offline-fake-key"}}}),
        encoding="utf-8",
    )
    fixture = ROOT / "test" / "fixtures" / "openrouter_models.json"
    data = json.loads(fixture.read_text(encoding="utf-8"))["data"]
    (agent / "openrouter_models_cache.json").write_text(
        json.dumps({"fetched_at": int(time.time()), "data": data}),
        encoding="utf-8",
    )


def child_environment(home: Path, base_url: str, *, rpc: bool) -> dict[str, str]:
    env = os.environ.copy()
    # Do not inherit provider overrides, sandbox policy, prompt filters, feature
    # toggles, credentials, or proxy routing into this local-only fixture.
    for key in tuple(env):
        upper = key.upper()
        if (key.startswith("COYOTE_") or key.endswith("_API_KEY")
                or key.endswith("_TOKEN")
                or upper in {"HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY"}):
            env.pop(key, None)
    env.update(
        {
            "HOME": str(home),
            "OPENROUTER_API_KEY": "offline-fake-key",
            "COYOTE_OPENROUTER_BASE_URL": base_url,
            "COYOTE_TEST_NO_CATALOGUE_REFRESH": "1",
            "COYOTE_TEST_FAST_RETRY": "1",
            "COYOTE_RECURSION_DEPTH": "0",
            "COYOTE_SANDBOX_PROFILE": "",
            "COYOTE_ENABLE_MEMORY": "0",
        }
    )
    if rpc:
        # coyote replaces this with subagent-<actual child PID> at startup.
        env["COYOTE_FRONTEND"] = "plain"
        env["COYOTE_RUNTIME_AGENT_ID"] = "http-timeout-worker"
        env["COYOTE_AGENT_LABEL"] = "offline-http-timeout"
    return env


def start_child(binary: Path, args: list[str], env: dict[str, str]) -> subprocess.Popen:
    return subprocess.Popen(
        [str(binary), *args],
        cwd=ROOT,
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )


def terminate_reap(child: subprocess.Popen | None) -> None:
    if child is None or child.poll() is not None:
        return
    try:
        os.killpg(child.pid, signal.SIGTERM)
        child.wait(timeout=2)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=2)
        except subprocess.TimeoutExpired:
            raise AssertionError(f"failed to reap child pid {child.pid}")


def collect_on_failure(child: subprocess.Popen, message: str) -> AssertionError:
    terminate_reap(child)
    try:
        stdout, stderr = child.communicate(timeout=2)
    except subprocess.SubprocessError:
        stdout, stderr = "<unavailable>", "<unavailable>"
    return AssertionError(f"{message}; child stdout={stdout!r}; stderr={stderr!r}")


def run_no_prompt(binary: Path, home: Path, base_url: str,
                  server: StallServer) -> None:
    before = server.request_count
    child = start_child(
        binary,
        ["--one-shot", "--model", MODEL],
        child_environment(home, base_url, rpc=False),
    )
    try:
        try:
            stdout, stderr = child.communicate(timeout=10)
        except subprocess.TimeoutExpired as exc:
            raise collect_on_failure(
                child, "Plain no-prompt startup did not shut down promptly") from exc
        require(child.returncode == 0,
                f"Plain no-prompt child exited {child.returncode}; stderr={stderr!r}")
        lines = [line for line in stdout.splitlines() if line.strip()]
        require(len(lines) == 1,
                f"Plain no-prompt expected one JSON record, got {len(lines)}; "
                f"stdout={stdout!r}; stderr={stderr!r}")
        result = json.loads(lines[0])
        require(result.get("error") ==
                "one-shot requires --prompt (use --prompt - to read from stdin)",
                f"Plain no-prompt returned unexpected result: {result!r}")
        require(server.request_count == before,
                "Plain no-prompt startup unexpectedly contacted the HTTP fixture")
    except (AssertionError, json.JSONDecodeError, OSError,
            subprocess.SubprocessError) as exc:
        raise collect_on_failure(child, str(exc)) from exc
    finally:
        terminate_reap(child)


def run_plain(binary: Path, home: Path, base_url: str, server: StallServer) -> None:
    env = child_environment(home, base_url, rpc=False)
    child = start_child(binary, ["--one-shot", "--model", MODEL,
                                 "--prompt", PROMPT], env)
    deadline = time.monotonic() + OUTER_TIMEOUT
    try:
        remaining = deadline - time.monotonic()
        require(remaining > 0, "Plain outer deadline expired before child start")
        stdout, stderr = child.communicate(timeout=remaining)
        require(child.returncode == 0,
                f"Plain child should cleanly exit 0 after failure result; got {child.returncode}; stderr={stderr!r}")
        lines = [line for line in stdout.splitlines() if line.strip()]
        require(len(lines) == 1,
                f"Plain expected exactly one JSON record, got {len(lines)}; stdout={stdout!r}; stderr={stderr!r}")
        try:
            result = json.loads(lines[0])
        except json.JSONDecodeError as exc:
            raise AssertionError(
                f"Plain stdout is not one JSON record: {lines[0]!r}; stderr={stderr!r}") from exc
        error = result.get("error")
        require(isinstance(error, str) and error.strip(),
                f"Plain final JSON lacks non-empty error: {result!r}; stderr={stderr!r}")
        require("28" in error and "timeout" in error.lower(),
                f"Plain error must retain curl code 28 timeout evidence: {error!r}; stderr={stderr!r}")
        require(isinstance(result.get("session_id"), str)
                and len(result["session_id"]) == 36,
                f"Plain final JSON lacks session_id: {result!r}; stderr={stderr!r}")
        require(server.request_count == EXPECTED_ATTEMPTS,
                f"Plain expected exactly {EXPECTED_ATTEMPTS} stalled requests, saw {server.request_count}; stderr={stderr!r}")
    except (AssertionError, subprocess.SubprocessError) as exc:
        raise collect_on_failure(child, str(exc)) from exc
    finally:
        terminate_reap(child)


def recv_frame(conn: socket.socket, buffer: bytearray, deadline: float) -> dict:
    while b"\n" not in buffer:
        left = deadline - time.monotonic()
        require(left > 0, "RPC outer deadline expired awaiting newline frame")
        conn.settimeout(left)
        data = conn.recv(4096)
        require(data, "RPC child closed socket before terminal frame")
        buffer.extend(data)
    line, _, rest = buffer.partition(b"\n")
    buffer[:] = rest
    try:
        return json.loads(line)
    except json.JSONDecodeError as exc:
        raise AssertionError(f"Malformed RPC JSON frame: {line!r}") from exc


def run_rpc(binary: Path, home: Path, base_url: str, server: StallServer,
            temp: Path) -> None:
    endpoint = temp / "agent.sock"
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    listener.bind(str(endpoint))
    listener.listen(1)
    listener.settimeout(OUTER_TIMEOUT)
    env = child_environment(home, base_url, rpc=True)
    env["COYOTE_RPC_ENDPOINT"] = str(endpoint)
    child = start_child(binary, ["--subagent", "--one-shot", "--model", MODEL,
                                 "--prompt", PROMPT], env)
    deadline = time.monotonic() + OUTER_TIMEOUT
    conn = None
    try:
        left = deadline - time.monotonic()
        require(left > 0, "RPC outer deadline expired awaiting child connect")
        listener.settimeout(left)
        conn, _ = listener.accept()
        buffer = bytearray()
        handshake = recv_frame(conn, buffer, deadline)
        runtime_id = f"subagent-{child.pid}"
        require(handshake.get("protocol") == "coyote-agent-rpc"
                and handshake.get("version") == 2
                and handshake.get("type") == "handshake"
                and handshake.get("agentId") == runtime_id,
                f"Unexpected RPC handshake; expected agentId={runtime_id!r}: {handshake!r}")
        terminal = None
        timeout_evidence = []
        while terminal is None:
            frame = recv_frame(conn, buffer, deadline)
            require(frame.get("protocol") == "coyote-agent-rpc" and frame.get("version") == 2,
                    f"Invalid RPC frame envelope: {frame!r}")
            if frame.get("agentId") is not None:
                require(frame["agentId"] == runtime_id,
                        f"RPC frame used wrong runtime identity, expected {runtime_id!r}: {frame!r}")
            if frame.get("type") == "event" and frame.get("event") == "notice":
                payload = frame.get("payload")
                text = payload.get("text", "") if isinstance(payload, dict) else ""
                if isinstance(text, str) and "28" in text and "timeout" in text.lower():
                    timeout_evidence.append(text)
            if frame.get("type") == "terminal":
                terminal = frame
        require(terminal.get("agentId") == runtime_id
                and terminal.get("status") == "failed",
                f"Expected failed terminal frame for {runtime_id}: {terminal!r}")
        require(timeout_evidence,
                f"RPC emitted no error notice with curl code 28 timeout evidence before terminal: {terminal!r}")
        # Keep the transport open and require the child itself to close it and
        # exit after its natural terminal lifecycle; never trigger shutdown here.
        while True:
            if b"\n" not in buffer:
                left = deadline - time.monotonic()
                require(left > 0, "RPC outer deadline expired awaiting natural socket EOF")
                conn.settimeout(left)
                data = conn.recv(4096)
                if not data:
                    require(not buffer, f"Incomplete trailing RPC frame at EOF: {bytes(buffer)!r}")
                    break
                buffer.extend(data)
            trailing = recv_frame(conn, buffer, deadline)
            require(trailing.get("protocol") == "coyote-agent-rpc"
                    and trailing.get("version") == 2
                    and trailing.get("agentId") == runtime_id,
                    f"Invalid trailing RPC frame identity/envelope: {trailing!r}")
            require(trailing.get("type") != "terminal",
                    f"RPC emitted multiple terminal frames: {trailing!r}")
        left = deadline - time.monotonic()
        require(left > 0, "RPC outer deadline expired before child exit")
        stdout, stderr = child.communicate(timeout=left)
        require(child.returncode == 0,
                f"RPC child should cleanly exit after terminal and natural EOF, got {child.returncode}; stderr={stderr!r}")
        require(stdout is not None and stderr is not None,
                "RPC child stdout/stderr did not reach EOF after communicate")
        require(child.poll() == child.returncode,
                "RPC child process exit was not observed")
        require(server.request_count == EXPECTED_ATTEMPTS,
                f"RPC expected exactly {EXPECTED_ATTEMPTS} stalled requests, saw {server.request_count}; stderr={stderr!r}")
    except (AssertionError, OSError, subprocess.SubprocessError) as exc:
        raise collect_on_failure(child, str(exc)) from exc
    finally:
        if conn is not None:
            conn.close()
        listener.close()
        terminate_reap(child)


def run_zero_disable_success(binary: Path, home: Path, base_url: str,
                             server: StallServer) -> None:
    server.response_mode = "success"
    server.response_delay = 8.0
    before = server.request_count
    child = start_child(
        binary,
        ["--one-shot", "--model", MODEL, "--prompt", "Verify delayed SSE succeeds."],
        child_environment(home, base_url, rpc=False),
    )
    try:
        try:
            stdout, stderr = child.communicate(timeout=OUTER_TIMEOUT)
        except subprocess.TimeoutExpired as exc:
            raise collect_on_failure(child, "ZERO-disable delayed success exceeded outer deadline") from exc
        require(child.returncode == 0,
                f"ZERO-disable delayed response process exited {child.returncode}; stderr={stderr!r}")
        lines = [line for line in stdout.splitlines() if line.strip()]
        require(len(lines) == 1,
                f"ZERO-disable expected exactly one JSON record, got {len(lines)}; stdout={stdout!r}; stderr={stderr!r}")
        result = json.loads(lines[0])
        require(isinstance(result.get("output"), str) and "delayed success" in result["output"],
                f"ZERO-disable delayed SSE did not produce success: {result!r}; stderr={stderr!r}")
        require(server.request_count - before == 1,
                f"ZERO-disable expected one delayed request, saw {server.request_count - before}; stderr={stderr!r}")
    except (AssertionError, json.JSONDecodeError, OSError, subprocess.SubprocessError) as exc:
        raise collect_on_failure(child, str(exc)) from exc
    finally:
        terminate_reap(child)
        server.response_mode = "stall"
        server.response_delay = 0.0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=DEFAULT_BINARY,
                        help=f"repository coyote executable (default: {DEFAULT_BINARY})")
    args = parser.parse_args()
    binary = args.binary.resolve()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        print(f"FAIL: executable coyote binary not found: {binary}", file=sys.stderr)
        return 2
    try:
        with tempfile.TemporaryDirectory(prefix="coyote-http-timeout-") as scratch:
            temp = Path(scratch)
            home = temp / "home"
            make_home(home, 1)
            zero_home = temp / "zero-home"
            make_home(zero_home, 0)
            server = StallServer(("127.0.0.1", 0))
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            base_url = f"http://127.0.0.1:{server.server_port}/api/v1"
            try:
                run_no_prompt(binary, home, base_url, server)
                run_plain(binary, home, base_url, server)
                plain_count = server.request_count
                server.request_count = 0
                run_rpc(binary, home, base_url, server, temp)
                rpc_count = server.request_count
                run_zero_disable_success(binary, zero_home, base_url, server)
                print(f"PASS: Plain/RPC timeout lifecycle and ZERO-disable delayed success; "
                      f"{plain_count}+{rpc_count} stalled requests; offline fixture only")
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=2)
        return 0
    except (AssertionError, OSError, subprocess.SubprocessError, TimeoutError) as exc:
        print(f"FAIL: HTTP timeout lifecycle: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
