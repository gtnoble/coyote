#!/usr/bin/env python3
"""Generate bounded Ada symbol lookups from the pinned KaTeX inventory."""
import hashlib
import json
import sys
from pathlib import Path

VERSION = "0.16.22"
INVENTORY_SHA256 = "445511f22cbf79b0300a505c4f096bc57066b40daaa095bd9d39fc614943604d"
DIST_SHA256 = "8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33"
ARCHIVE_SHA256 = "e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365"
GROUPS = {"mathord": "Ordinary", "textord": "Ordinary", "op-token": "Operator_Atom", "bin": "Binary_Atom", "rel": "Relation_Atom", "open": "Opening", "close": "Closing", "punct": "Punctuation", "inner": "Inner"}
FONTS = {"main": "Main_Regular", "ams": "AMS_Regular"}

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
    modes = data.get("registries", {}).get("symbolsByMode", {})
    if len(modes.get("math", {})) != 1487 or len(modes.get("text", {})) != 749:
        raise ValueError("unexpected symbol registry counts")
    return modes

def codepoint(text):
    if not isinstance(text, str) or len(text) != 1:
        return None
    point = ord(text)
    return point if point <= 0x10ffff and not 0xd800 <= point <= 0xdfff else None

def entries(table):
    result = []
    for alias, record in table.items():
        if not isinstance(record, dict):
            raise ValueError(f"invalid symbol record for {alias!r}")
        group, face = record.get("group"), record.get("font")
        point = codepoint(record.get("replace"))
        if point is None or group not in GROUPS or face not in FONTS:
            continue
        font = FONTS[face]
        if face == "main" and group == "mathord":
            font = "Math_Italic"
        result.append((alias, point, GROUPS[group], font))
    return sorted(set(result))

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

def emit(spec_path, body_path, modes):
    math = entries(modes["math"])
    text = entries(modes["text"])
    header = ["--  GENERATED from the pinned KaTeX 0.16.22 dist inventory.",
              f"--  Inventory SHA-256: {INVENTORY_SHA256}",
              f"--  dist/katex.js SHA-256: {DIST_SHA256}", ""]
    spec = header + ["with Math_Model; use Math_Model;", "",
        "package Math_Symbols is",
        "   type Symbol_Record is record", "      Found : Boolean := False;",
        "      Code_Point : Natural := 0;", "      Class : Atom_Class := Ordinary;",
        "      Font : Font_Kind := Main_Regular;", "   end record;",
        "   function Lookup_Math (Name : String) return Symbol_Record;",
        "   function Lookup_Text (Name : String) return Symbol_Record;",
        "end Math_Symbols;", ""]
    body = header + ["with Math_Model; use Math_Model;", "",
        "package body Math_Symbols is",
        "   function Find (Name : String; Text_Mode : Boolean) return Symbol_Record is",
        "   begin"]
    for enabled, table in ((False, math), (True, text)):
        body.append(f"      if Text_Mode = {str(enabled)} then")
        for alias, point, group, font in table:
            body += ["         if Name =", f"           {ada_string(alias)} then",
                     "            return", f"              (True, {point},",
                     f"               {group}, {font});", "         end if;"]
        body.append("      end if;")
    body += ["      return (others => <>);", "   end Find;",
        "   function Lookup_Math (Name : String) return Symbol_Record is",
        "   begin", "      return Find (Name, False);", "   end Lookup_Math;",
        "   function Lookup_Text (Name : String) return Symbol_Record is",
        "   begin", "      return Find (Name, True);", "   end Lookup_Text;",
        "end Math_Symbols;", ""]
    Path(spec_path).write_text("\n".join(spec), encoding="ascii")
    Path(body_path).write_text("\n".join(body), encoding="ascii")

def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: generate_math_symbols.py INVENTORY OUTPUT_ADS OUTPUT_ADB")
    try:
        emit(sys.argv[2], sys.argv[3], load(sys.argv[1]))
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"error: {error}") from error
    print(f"generated Math_Symbols from KaTeX {VERSION}")

if __name__ == "__main__":
    main()
