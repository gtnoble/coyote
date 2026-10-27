#!/usr/bin/env python3
"""Generate ASCII-only Ada Unicode math registries from pinned KaTeX."""
import hashlib
import json
import sys
from pathlib import Path

VERSION = "0.16.22"
INVENTORY_SHA256 = "445511f22cbf79b0300a505c4f096bc57066b40daaa095bd9d39fc614943604d"
DIST_SHA256 = "8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33"
ARCHIVE_SHA256 = "e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365"
SUBSCRIPT_RE = "^[₊₋₌₍₎₀₁₂₃₄₅₆₇₈₉ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓᵦᵧᵨᵩᵪ]"


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


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
            or provenance.get("distSha256") != DIST_SHA256
            or provenance.get("npmArchiveSha256") != ARCHIVE_SHA256):
        raise ValueError("inventory provenance/version mismatch")
    registries = data["registries"]
    tables = registries["runtimeTables"]
    regexes = registries["lexerRegexSources"]
    if regexes.get("unicodeSubRegEx") != SUBSCRIPT_RE:
        raise ValueError("unicodeSubRegEx differs from pinned KaTeX")
    symbols = tables["unicodeSymbols"]
    accents = tables["unicodeAccents"]
    scripts = tables["uSubsAndSups"]
    blocks = tables["scriptData"]
    if (len(symbols) != 344 or len(accents) != 12
            or len(scripts) != 102 or len(blocks) != 7):
        raise ValueError("unexpected pinned Unicode registry counts")
    decompositions = []
    for key, value in symbols.items():
        if len(key) != 1 or not isinstance(value, str):
            raise ValueError("invalid unicodeSymbols record")
        if len(value) >= 2 and all(0x300 <= ord(mark) <= 0x36F
                                    for mark in value[1:]):
            decompositions.append((ord(key), value))
    accent_rows = []
    for key, record in accents.items():
        if len(key) != 1 or not isinstance(record, dict):
            raise ValueError("invalid unicodeAccents record")
        math = record.get("math", record["text"])
        text = record["text"]
        accent_rows.append((ord(key), math, text))
    script_rows = []
    for key, value in scripts.items():
        if len(key) != 1 or not isinstance(value, str):
            raise ValueError("invalid uSubsAndSups record")
        script_rows.append((ord(key), value))
    sub_leads = set(SUBSCRIPT_RE[2:-1])
    return sorted(decompositions), sorted(accent_rows), sorted(script_rows), blocks, {ord(c) for c in sub_leads}


def emit(spec_path, body_path, tables):
    decompositions, accents, scripts, blocks, sub_leads = tables
    head = ["--  GENERATED from the pinned KaTeX 0.16.22 runtime inventory.",
            f"--  Inventory SHA-256: {INVENTORY_SHA256}",
            f"--  dist/katex.js SHA-256: {DIST_SHA256}", ""]
    spec = head + ["with Ada.Strings.Unbounded;", "", "package Math_Unicode is",
        "   type Accent_Mode is (Math_Mode, Text_Mode);",
        "   function Lookup_Decomposition (Code_Point : Natural) return String;",
        "   function Lookup_Accent (Code_Point : Natural; Mode : Accent_Mode) return String;",
        "   function Lookup_Script (Code_Point : Natural) return String;",
        "   function Is_Superscript (Code_Point : Natural) return Boolean;",
        "   function Is_Subscript_Lead (Code_Point : Natural) return Boolean;",
        "   function Is_Script_Data (Code_Point : Natural) return Boolean;",
        "end Math_Unicode;", ""]
    body = head + ["package body Math_Unicode is"]
    def lookup(name, rows, value):
        body.extend([f"   function {name} (Code_Point : Natural) return String is", "   begin"])
        for point, result in rows:
            body.extend([f"      if Code_Point = {point} then", f"         return {value(result)};", "      end if;"])
        body.extend(["      return \"\";", f"   end {name};", ""])
    lookup("Lookup_Decomposition", decompositions, ada_string)
    body.extend(["   function Lookup_Accent (Code_Point : Natural; Mode : Accent_Mode) return String is", "   begin"])
    for p, math, text in accents:
        body.extend([f"      if Code_Point = {p} then", "         if Mode = Math_Mode then", f"            return {ada_string(math)};", "         else", f"            return {ada_string(text)};", "         end if;", "      end if;"])
    body.extend(["      return \"\";", "   end Lookup_Accent;", ""])
    lookup("Lookup_Script", scripts, ada_string)
    body.extend(["   function Is_Superscript (Code_Point : Natural) return Boolean is", "   begin"])
    for p, value in scripts:
        if chr(p) not in SUBSCRIPT_RE:
            body.extend([f"      if Code_Point = {p} then", "         return True;", "      end if;"])
    body.extend(["      return False;", "   end Is_Superscript;", ""])
    body.extend(["   function Is_Subscript_Lead (Code_Point : Natural) return Boolean is", "   begin"])
    for p in sorted(sub_leads):
        body.extend([f"      if Code_Point = {p} then", "         return True;", "      end if;"])
    body.extend(["      return False;", "   end Is_Subscript_Lead;", ""])
    body.extend(["   function Is_Script_Data (Code_Point : Natural) return Boolean is",
                 "   begin"])
    for block in blocks:
        for first, last in block["blocks"]:
            body.extend([f"      if Code_Point in {first} .. {last} then",
                         "         return True;", "      end if;"])
    body.extend(["      return False;", "   end Is_Script_Data;",
                 "end Math_Unicode;", ""])
    Path(spec_path).write_text("\n".join(spec), encoding="ascii")
    Path(body_path).write_text("\n".join(body), encoding="ascii")


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: generate_math_unicode.py INVENTORY OUTPUT_ADS OUTPUT_ADB")
    try:
        emit(sys.argv[2], sys.argv[3], load(sys.argv[1]))
    except (OSError, UnicodeError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        raise SystemExit(f"error: {error}") from error
    print(f"generated Math_Unicode from KaTeX {VERSION}")


if __name__ == "__main__":
    main()
