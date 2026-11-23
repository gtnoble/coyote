#!/usr/bin/env python3
"""Exercise the tiled Canvas workflow under Xvfb with a 20,000-square PNG."""

import os
from pathlib import Path
import struct
import subprocess
import tempfile
import zlib


TEST_DIR = Path(__file__).resolve().parent.parent
SIDE = 20_000
CASE = "Coyote.GUI Canvas tiled PNG import and persistence"


def write_png(path):
    def chunk(out, kind, data):
        out.write(struct.pack(">I", len(data)))
        out.write(kind)
        out.write(data)
        out.write(struct.pack(">I", zlib.crc32(data, zlib.crc32(kind))))

    bands = SIDE // 2
    red = bytes((224, 64, 32))
    green = bytes((32, 192, 48))
    detail = bytearray(red * bands)
    for start in range(64, 256, 16):
        color = green if (start // 16) % 2 else red
        detail[start * 3:(start + 16) * 3] = color * 16
    row = b"\0" + bytes(detail) + bytes((16, 48, 224)) * bands
    with path.open("wb") as out:
        out.write(b"\x89PNG\r\n\x1a\n")
        chunk(out, b"IHDR", struct.pack(">IIBBBBB", SIDE, SIDE, 8, 2, 0, 0, 0))
        codec = zlib.compressobj(1)
        for _ in range(SIDE):
            compressed = codec.compress(row)
            if compressed:
                chunk(out, b"IDAT", compressed)
        chunk(out, b"IDAT", codec.flush())
        chunk(out, b"IEND", b"")


def main():
    with tempfile.TemporaryDirectory(prefix="coyote-tiled-gtk-") as directory:
        image = Path(directory) / "large.png"
        write_png(image)
        env = dict(os.environ, COYOTE_TEST_LARGE_TILE_PNG=str(image))
        result = subprocess.run(
            ["xvfb-run", "-a", "/usr/bin/time", "-f", "wall=%e peak_rss_kib=%M",
             str(TEST_DIR / "bin/coyote_test"), CASE],
            cwd=TEST_DIR, env=env, timeout=240, capture_output=True, text=True,
        )
        print(result.stdout, end="")
        print(result.stderr, end="")
        # AUnit otherwise skips display-dependent cases on setup failure.
        if result.returncode or f"OK    {CASE}" not in result.stdout:
            return 1
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
