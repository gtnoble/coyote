#!/usr/bin/env python3
"""Generate sorted Ada string-template macros from the pinned inventory."""
import hashlib
import json
import sys
from pathlib import Path

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


def ada_string(text):
    parts = []
    literal = []

    def flush():
        if literal:
            joined = "".join(literal).replace('"', '""')
            parts.append('"' + joined + '"')
            literal.clear()

    for byte in text.encode("utf-8"):
        if 32 <= byte <= 126:
            literal.append(chr(byte))
        else:
            flush()
            parts.append(f"Character'Val (16#{byte:02X}#)")
    flush()
    return " &\n          ".join(parts) or '""'


def load(path):
    raw = Path(path).read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != INVENTORY_SHA256:
        raise ValueError(f"inventory SHA-256 mismatch: {digest}")
    data = json.loads(raw, object_pairs_hook=unique)
    provenance = data.get("provenance", {})
    if (data.get("schema") != "coyote.native-math.katex-inventory.v2"
            or provenance.get("name") != "katex"
            or provenance.get("version") != "0.16.22"
            or provenance.get("distSha256") != DIST_SHA256
            or provenance.get("npmArchiveSha256") != ARCHIVE_SHA256):
        raise ValueError("pinned KaTeX provenance mismatch")
    entries = data.get("registries", {}).get("builtinMacros", {})
    if not isinstance(entries, dict) or len(entries) != 338:
        raise ValueError("unexpected builtin macro registry")
    result = []
    callable_count = 0
    for name, value in entries.items():
        if value == "[function]":
            callable_count += 1
            continue
        if not isinstance(value, str):
            raise ValueError(f"unsupported macro entry: {name}")
        markers = []
        position = 0
        while position < len(value):
            if value[position] == "#":
                if position + 1 == len(value):
                    raise ValueError(f"unterminated marker: {name}")
                following = value[position + 1]
                if following == "#":
                    position += 2
                    continue
                if following not in "123456789":
                    raise ValueError(f"unsupported parameter marker: {name}")
                markers.append(int(following))
                position += 2
            else:
                position += 1
        count = max(markers, default=0)
        result.append((name, value, count))
    if len(result) != 318 or callable_count != 20:
        raise ValueError("unexpected string/callable macro counts")
    return sorted(result)


def emit(entries, spec_path, body_path):
    spec = ["--  Generated from KaTeX 0.16.22 builtin macro templates.",
            f"--  Inventory SHA-256: {INVENTORY_SHA256}",
            f"--  dist/katex.js SHA-256: {DIST_SHA256}", "",
            "with Ada.Strings.Unbounded;", "", "package Math_Builtin_Macros is",
            "   Supported_String_Macro_Count : constant := 318;",
            "   Callable_Macro_Count : constant := 20;",
            "   type Macro_Record is record", "      Found : Boolean := False;",
            "      Template : Ada.Strings.Unbounded.Unbounded_String;",
            "      Num_Params : Natural := 0;", "   end record;",
            "   function Lookup (Name : String) return Macro_Record;",
            "end Math_Builtin_Macros;", ""]
    body = ["--  Generated from KaTeX 0.16.22 builtin macro templates.",
            f"--  Inventory SHA-256: {INVENTORY_SHA256}",
            f"--  dist/katex.js SHA-256: {DIST_SHA256}", "",
            "with Ada.Strings.Unbounded;", "", "package body Math_Builtin_Macros is",
            "   use Ada.Strings.Unbounded;", "   type Macro_Entry is record",
            "      Name : Unbounded_String;", "      Template : Unbounded_String;",
            "      Num_Params : Natural;", "   end record;",
            "   Entries : constant array (Positive range 1 .. " +
            str(len(entries)) + ") of Macro_Entry :=", "     ("]
    for index, (name, value, params) in enumerate(entries):
        suffix = "," if index + 1 < len(entries) else ");"
        body.extend([f"      {index + 1} => (To_Unbounded_String ({ada_string(name)}),",
                     f"        To_Unbounded_String ({ada_string(value)}), {params}){suffix}"])
    body.extend(["   function Lookup (Name : String) return Macro_Record is",
                 "      Low : Integer := Entries'First;",
                 "      High : Integer := Entries'Last;", "   begin", "      while Low <= High loop",
                 "         declare", "            Middle : constant Integer := (Low + High) / 2;",
                 "            Candidate : constant String := To_String (Entries (Middle).Name);",
                 "         begin", "            if Name = Candidate then",
                 "               return (True, Entries (Middle).Template,",
                 "                 Entries (Middle).Num_Params);", "            elsif Name < Candidate then",
                 "               High := Middle - 1;", "            else", "               Low := Middle + 1;",
                 "            end if;", "         end;", "      end loop;",
                 "      return (others => <>);", "   end Lookup;", "end Math_Builtin_Macros;", ""])
    Path(spec_path).write_text("\n".join(spec), encoding="ascii")
    generated_body = "\n".join(body)
    if not generated_body.isascii():
        raise ValueError("generated Ada body contains non-ASCII source bytes")
    Path(body_path).write_text(generated_body, encoding="ascii")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: generate_math_macros.py INVENTORY SPEC BODY")
    emit(load(sys.argv[1]), sys.argv[2], sys.argv[3])
