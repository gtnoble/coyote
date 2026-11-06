#!/usr/bin/env python3
"""Emit the pinned KaTeX function-name predicate used by Math_Expander."""
import hashlib
import json
import sys
from pathlib import Path

VERSION = "0.16.22"
INVENTORY_SHA256 = "445511f22cbf79b0300a505c4f096bc57066b40daaa095bd9d39fc614943604d"
DIST_SHA256 = "8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33"
ARCHIVE_SHA256 = "e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365"


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load(path):
    raw = Path(path).read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != INVENTORY_SHA256:
        raise ValueError(f"inventory SHA-256 mismatch: {digest}")
    data = json.loads(raw, object_pairs_hook=unique)
    provenance = data.get("provenance", {})
    if (data.get("schema") != "coyote.native-math.katex-inventory.v2"
            or provenance.get("name") != "katex"
            or provenance.get("version") != VERSION
            or provenance.get("distPath") != "dist/katex.js"
            or provenance.get("distSha256") != DIST_SHA256
            or provenance.get("npmArchiveSha256") != ARCHIVE_SHA256):
        raise ValueError("inventory provenance/version mismatch")
    names = data.get("registries", {}).get("functions", {})
    if len(names) != 309 or any(not isinstance(name, str) for name in names):
        raise ValueError("unexpected function registry")
    return sorted(names)


def ada_string(text):
    parts = []
    for byte in text.encode("utf-8"):
        if 32 <= byte <= 126 and byte not in (34, 92):
            parts.append('"' + chr(byte) + '"')
        elif byte == 34:
            parts.append('""""')
        elif byte == 92:
            parts.append('"\\"')
        else:
            parts.append(f"Character'Val ({byte})")
    return " & ".join(parts) if parts else '""'


def render(names):
    lines = ["   --  GENERATED from KaTeX 0.16.22 function registry.",
             f"   --  Inventory SHA-256: {INVENTORY_SHA256}",
             f"   --  dist/katex.js SHA-256: {DIST_SHA256}",
             "   function Is_Registered_Function_Name (Name : String)",
             "      return Boolean is", "   begin"]
    for name in names:
        lines += [f"      if Name = {ada_string(name)} then",
                  "         return True;", "      end if;"]
    lines += ["      return False;", "   end Is_Registered_Function_Name;"]
    return "\n".join(lines) + "\n"


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_math_functions.py INVENTORY OUTPUT_FRAGMENT")
    try:
        text = render(load(sys.argv[1]))
        Path(sys.argv[2]).write_text(text, encoding="utf-8")
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"error: {error}") from error
    print(f"generated 309 KaTeX {VERSION} function-name checks")


if __name__ == "__main__":
    main()
