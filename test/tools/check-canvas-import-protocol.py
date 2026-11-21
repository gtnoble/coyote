#!/usr/bin/env python3
"""Offline developer check of the Canvas listener and CLI v1 wire boundary."""

import ctypes as c
import os
from pathlib import Path
import socket
import struct
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
C_SOURCE = ROOT / "src/coyote_canvas_import_c.c"
CLI = ROOT / "bin/coyote"


def exact(conn, count):
    data = bytearray()
    while len(data) < count:
        piece = conn.recv(count - len(data))
        assert piece, "unexpected EOF"
        data.extend(piece)
    return bytes(data)


def response(conn):
    status, size = struct.unpack("!BI", exact(conn, 5))
    assert 0 < size <= 2048
    return status, exact(conn, size)


def run(scratch):
    lib_path = scratch / "transport.so"
    subprocess.run(["cc", "-std=c11", "-Wall", "-Wextra", "-Wpedantic",
                    "-Werror", "-fPIC", "-shared", "-pthread", str(C_SOURCE),
                    "-o", str(lib_path)], check=True, timeout=20)
    lib = c.CDLL(str(lib_path))
    ptr, text, integer = c.c_void_p, c.c_char_p, c.c_int
    for name, args, result in (
        ("start", (text, ptr, ptr), ptr), ("stop", (ptr,), None),
        ("take", (ptr,), ptr), ("free", (ptr,), None),
        ("count", (ptr,), c.c_uint), ("finish", (ptr, integer, text), None),
        ("file", (ptr, c.c_uint, ptr, ptr), ptr),
    ):
        entry = getattr(lib, f"coyote_canvas_import_{name}")
        entry.argtypes, entry.restype = args, result
    path, cap = c.create_string_buffer(108), c.create_string_buffer(65)
    handle = lib.coyote_canvas_import_start(os.fsencode(scratch), path, cap)
    assert handle and len(cap.value) == 64

    def connect():
        conn = socket.socket(socket.AF_UNIX)
        conn.settimeout(3)
        conn.connect(path.value)
        return conn

    def header(op, count, ident, token=cap.value):
        return struct.pack("!4sBB16s64s", b"CCA1", op, count, ident, token)

    def query(ident):
        with connect() as conn:
            conn.sendall(header(2, 0, ident))
            conn.shutdown(socket.SHUT_WR)
            return response(conn)

    def invalid(payload, count=1):
        ident = os.urandom(16)
        with connect() as conn:
            conn.sendall(header(1, count, ident))
            assert exact(conn, 1) == b"\0"
            conn.sendall(payload)
            conn.shutdown(socket.SHUT_WR)
            assert response(conn)[0] == 1
        assert query(ident)[0] == 1
        assert not lib.coyote_canvas_import_take(handle)

    def file(label, data):
        return struct.pack("!IB", len(data), len(label)) + label + data

    try:
        with connect() as conn:
            conn.sendall(header(1, 1, os.urandom(16), b"0" * 64))
            assert conn.recv(1) == b"", "wrong capability admitted"
        fifo = scratch / "never-open"
        os.mkfifo(fifo)
        denied = subprocess.run(
            [str(CLI), "canvas", "add", str(fifo)], capture_output=True,
            env={**os.environ, "COYOTE_CANVAS_SOCKET": os.fsdecode(path.value),
                 "COYOTE_CANVAS_CAPABILITY": "0" * 64}, timeout=3)
        assert denied.returncode and b"no authorized Canvas service" in denied.stderr
        assert not denied.stdout
        invalid(struct.pack("!IB", 8 * 1024 * 1024 + 1, 1))
        invalid(file(b"path/name", b"abc") + b"\xa5")
        invalid(file(b"good", b"abc"))
        invalid(file(b"good", b"abc") + b"\xa5extra")
        invalid(file(b"good", b"abc") + struct.pack("!IB", 8, 1) + b"x?", 2)

        missing = os.urandom(16)
        assert query(missing)[0] == 2
        ident = os.urandom(16)
        with connect() as conn:
            conn.sendall(header(1, 2, ident))
            assert exact(conn, 1) == b"\0"
            conn.sendall(file(b"one.svg", b"\0first") + file(b"two.png", b"second")
                         + b"\xa5")
            conn.shutdown(socket.SHUT_WR)
        pending = query(ident)
        assert pending[0] == 3, pending
        batch = lib.coyote_canvas_import_take(handle)
        assert batch and lib.coyote_canvas_import_count(batch) == 2
        try:
            actual = []
            for i in range(2):
                size, label = c.c_uint(), text()
                data = lib.coyote_canvas_import_file(batch, i, c.byref(size),
                                                     c.byref(label))
                actual.append((label.value, c.string_at(data, size.value)))
            assert actual == [(b"one.svg", b"\0first"), (b"two.png", b"second")]
        finally:
            lib.coyote_canvas_import_free(batch)
        lib.coyote_canvas_import_finish(handle, 0, b"committed receipt\n")
        assert query(ident) == (0, b"committed receipt\n")
        with connect() as conn:
            conn.sendall(header(1, 2, ident))
            assert exact(conn, 1) == b"\1", "duplicate upload admitted"
        assert not lib.coyote_canvas_import_take(handle)
        assert query(ident) == (0, b"committed receipt\n")
    finally:
        lib.coyote_canvas_import_stop(handle)
    assert not Path(os.fsdecode(path.value)).exists()
    print("Canvas protocol: authentication, bounded framing, ordered bytes, "
          "lost-reply receipt and revocation passed.")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="coyote-proto-") as directory:
        run(Path(directory))
