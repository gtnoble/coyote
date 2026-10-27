#!/usr/bin/env python3
"""Generate static Ada stretchy paths from pinned KaTeX 0.16.22 data."""
import hashlib
from pathlib import Path
import re
import sys

PINS = {
    "svgGeometry.js": "e7bb196633f23cab95da9d010ffbbdad37d2c942c2f96a33f8094f260ecfd892",
    "stretchy.js": "5bcda72e30f9768cf65f29e73bd9b8905aabe42e0022cd8de9cbaa60aec69abd",
    "katex.css": "009f1e58806819e90d02e90ffecafa988a3ee4b54418f8cab70f4f2cbf8ce2d8",
    "package.json": "bd6430ca96592a055393a1ce980925162da3d40cd0231813d41ef0c56daacd91",
}


def checked_source(path, label):
    raw = Path(path).read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != PINS[label]:
        raise ValueError(f"{label} SHA-256 mismatch: {digest}")
    return raw.decode("utf-8"), digest


def ada_string(value):
    return " & ".join('"' + part + '"' for part in value.split('"'))


def extract_geometry(source):
    marker = "export const path: {[string]: string} = {"
    if source.count(marker) != 1:
        raise ValueError("expected one literal svgGeometry path object")
    block = source.split(marker, 1)[1].split("\n};", 1)[0]
    entries = re.findall(
        r"^    ([A-Za-z][A-Za-z0-9]*): `([^`]*)`,?\s*$",
        block, re.M)
    if not entries:
        raise ValueError("no literal paths found in svgGeometry path object")
    paths = {}
    for name, value in entries:
        if name in paths or not value or "${" in value or "`" in value:
            raise ValueError(f"duplicate, empty, or dynamic path: {name}")
        paths[name] = " ".join(value.split())
    return paths


def extract_registrations(source, geometry):
    marker = "const katexImagesData:"
    if source.count(marker) != 1:
        raise ValueError("expected one katexImagesData table")
    tail = source.split(marker, 1)[1]
    start = tail.index("{")
    block = tail[start + 1:tail.index("\n};", start)]
    row = re.compile(
        r'^\s*(?:([A-Za-z][A-Za-z0-9]*)|"\\\\([A-Za-z]+)")\s*:\s*'
        r'\[\[([\s\S]*?)\],\s*([0-9.]+),\s*([0-9.]+)'
        r'(?:,\s*"(xMinYMin|xMaxYMin)")?\s*\],?', re.M)
    registrations = {}
    for match in row.finditer(block):
        name = match.group(1) or match.group(2)
        parts = re.findall(r'"([A-Za-z][A-Za-z0-9]*)"', match.group(3))
        minimum, height = float(match.group(4)), int(match.group(5))
        align = match.group(6)
        if not 1 <= len(parts) <= 3 or len(parts) != len(set(parts)):
            raise ValueError(f"invalid part list for registration: {name}")
        if name in registrations or minimum <= 0 or height <= 0:
            raise ValueError(f"duplicate or invalid registration: {name}")
        missing = set(parts) - geometry.keys()
        if missing:
            raise ValueError(f"missing paths for {name}: {sorted(missing)}")
        if len(parts) == 1 and align not in ("xMinYMin", "xMaxYMin"):
            raise ValueError(f"missing single-path alignment: {name}")
        if len(parts) != 1 and align is not None:
            raise ValueError(f"unexpected alignment for multipart entry: {name}")
        registrations[name] = (parts, minimum, height, align)
    if len(registrations) != 40:
        raise ValueError(f"expected 40 literal registrations, found {len(registrations)}")
    return registrations


def write_spec(path):
    lines = [
        "with Math_Paths;", "", "package Math_Stretchy is",
        "   type Accent_Kind is",
        "     (Wide_Hat, Wide_Tilde, Over_Right_Arrow, Over_Left_Arrow,",
        "      Vector_Accent);", "",
        "   type Brace_Kind is (Over_Brace, Under_Brace);",
        "   type Brace_Part is (Left_Part, Middle_Part, Right_Part);",
        "   type Part_Align is (Min_Align, Mid_Align, Max_Align);", "",
        "   --  Names are KaTeX table keys without a leading backslash.",
        "   function Geometry_For (Name : String) return Math_Paths.Path;",
        "   function ViewBoxHeightFor (Name : String) return Long_Float;",
        "   function MinWidthFor (Name : String) return Long_Float;",
        "   function PartCount (Name : String) return Natural;",
        "   function PartPath",
        "     (Name : String; Part : Positive) return Math_Paths.Path;",
        "   function PartAlignFor",
        "     (Name : String; Part : Positive) return Part_Align;", "",
        "   --  Static single-piece geometry; callers compose/slice all parts.",
        "   function Brace_Part_For",
        "     (Kind : Brace_Kind; Part : Brace_Part) return Math_Paths.Path;",
        "   function Brace_View_Width (Part : Brace_Part) return Long_Float;",
        "   function Brace_View_Height (Kind : Brace_Kind) return Long_Float;",
        "   function View_Width (Kind : Accent_Kind) return Long_Float;",
        "   function View_Height (Kind : Accent_Kind) return Long_Float;",
        "   function Path_For",
        "     (Kind : Accent_Kind; Width : Long_Float) return Math_Paths.Path;",
        "   function Tall_Radical",
        "     (Height_Em, Extra_Vinculum, Width_Em : Long_Float)",
        "      return Math_Paths.Path;", "end Math_Stretchy;", "",
    ]
    Path(path).write_text("\n".join(lines), encoding="utf-8")


def write_body(path, geometry, registrations, hashes):
    lines = [
        "--  Generated from KaTeX 0.16.22 static stretchy data (MIT).",
        "--  Source SHA-256 values:",
        "--  svgGeometry.js: " + hashes["svgGeometry.js"],
        "--  stretchy.js: " + hashes["stretchy.js"],
        "--  katex.css: " + hashes["katex.css"],
        "--  package.json: " + hashes["package.json"],
        "--  Copyright (c) 2013-2020 Khan Academy and contributors.",
        "with Math_Paths;", "package body Math_Stretchy is",
        "   function Geometry (Name : String) return String is", "   begin",
    ]
    for index, (name, data) in enumerate(geometry.items()):
        lines.append(("      if" if index == 0 else "      elsif") +
                     f' Name = "{name}" then')
        lines.append("         return " + ada_string(data) + ";")
    lines.extend(("      else", '         return "";', "      end if;",
                  "   end Geometry;", "",
                  "   function Geometry_For (Name : String) return Math_Paths.Path is",
                  "   begin", "      return Math_Paths.Parse (Geometry (Name));",
                  "   end Geometry_For;", ""))
    for function, field, default in (
            ("ViewBoxHeightFor", 2, "0.0"),
            ("MinWidthFor", 1, "0.0"),
            ("PartCount", 0, "0")):
        result_type = "Natural" if function == "PartCount" else "Long_Float"
        lines.extend((f"   function {function} (Name : String) return {result_type} is",
                      "   begin"))
        for name, (parts, minimum, height, align) in registrations.items():
            value = (str(len(parts)) if field == 0 else
                     f"{height}.0" if field == 2 else
                     f"{minimum:.3f}")
            lines.append(f'      if Name = "{name}" then')
            lines.append(f"         return {value};")
            lines.append("      end if;")
        lines.extend((f"      return {default};", f"   end {function};", ""))
    lines.extend((
        "   function PartPath",
        "     (Name : String; Part : Positive) return Math_Paths.Path is",
        "   begin"))
    for name, (parts, _minimum, _height, _align) in registrations.items():
        lines.append(f'      if Name = "{name}" then')
        lines.append("         case Part is")
        for index, piece in enumerate(parts, 1):
            lines.append(f"            when {index} =>")
            lines.append(f'               return Math_Paths.Parse (Geometry ("{piece}"));')
        lines.extend(("            when others =>", '               return Math_Paths.Parse ("");',
                      "         end case;", "      end if;"))
    lines.extend(('      return Math_Paths.Parse ("");',
                  "   end PartPath;", ""))
    lines.extend((
        "   function PartAlignFor",
        "     (Name : String; Part : Positive) return Part_Align is",
        "   begin"))
    for name, (parts, _minimum, _height, align) in registrations.items():
        if len(parts) == 1:
            value = "Min_Align" if align == "xMinYMin" else "Max_Align"
            lines.append(f'      if Name = "{name}" and then Part = 1 then')
            lines.append(f"         return {value};")
            lines.append("      end if;")
        else:
            lines.append(f'      if Name = "{name}" then')
            lines.append("         case Part is")
            for index in range(1, len(parts) + 1):
                value = ("Min_Align" if index == 1 else
                         "Max_Align" if index == len(parts) else "Mid_Align")
                lines.append(f"            when {index} =>")
                lines.append(f"               return {value};")
            lines.append("            when others =>")
            lines.append("               return Mid_Align;")
            lines.append("         end case;")
            lines.append("      end if;")
    lines.extend(("      return Mid_Align;", "   end PartAlignFor;", ""))
    lines.extend(legacy_body())
    lines.extend(("end Math_Stretchy;", ""))
    Path(path).write_text("\n".join(lines), encoding="utf-8")


def legacy_body():
    return [
        "   function Brace_Part_For",
        "     (Kind : Brace_Kind; Part : Brace_Part) return Math_Paths.Path is",
        "   begin",
        "      return PartPath",
        "        ((if Kind = Over_Brace then \"overbrace\" else \"underbrace\"),",
        "         (case Part is",
        "            when Left_Part => 1,",
        "            when Middle_Part => 2,",
        "            when Right_Part => 3));",
        "   end Brace_Part_For;", "",
        "   function Brace_View_Width (Part : Brace_Part) return Long_Float is",
        "      pragma Unreferenced (Part);", "   begin", "      return 400_000.0;",
        "   end Brace_View_Width;", "",
        "   function Brace_View_Height (Kind : Brace_Kind) return Long_Float is",
        "      pragma Unreferenced (Kind);", "   begin", "      return 548.0;",
        "   end Brace_View_Height;", "",
        "   function View_Width (Kind : Accent_Kind) return Long_Float is",
        "   begin", "      case Kind is",
        "         when Wide_Hat => return 1_053.0;",
        "         when Wide_Tilde => return 554.0;",
        "         when Over_Right_Arrow | Over_Left_Arrow => return 400_000.0;",
        "         when Vector_Accent => return 572.0;", "      end case;",
        "   end View_Width;", "",
        "   function View_Height (Kind : Accent_Kind) return Long_Float is",
        "   begin", "      case Kind is",
        "         when Wide_Hat => return 362.0;",
        "         when Wide_Tilde => return 182.0;",
        "         when Over_Right_Arrow | Over_Left_Arrow => return 532.0;",
        "         when Vector_Accent => return 208.0;", "      end case;",
        "   end View_Height;", "",
        "   function Path_For (Kind : Accent_Kind; Width : Long_Float)",
        "      return Math_Paths.Path is",
        "      Name : constant String :=", "        (case Kind is",
        "           when Wide_Hat =>", '              (if Width < 1_000.0 then "widehat1"',
        '               elsif Width < 2_000.0 then "widehat2"',
        '               elsif Width < 3_000.0 then "widehat3"',
        '               else "widehat4"),', "           when Wide_Tilde =>",
        '              (if Width < 800.0 then "tilde1"',
        '               elsif Width < 1_600.0 then "tilde2"',
        '               elsif Width < 2_400.0 then "tilde3"',
        '               else "tilde4"),', '           when Over_Right_Arrow => "rightarrow",',
        '           when Over_Left_Arrow => "leftarrow",',
        '           when Vector_Accent => "vec");', "   begin",
        "      if not Width'Valid or else Width <= 0.0 or else Width > 16_384.0 then",
        '         return Math_Paths.Parse ("");', "      end if;",
        "      return Geometry_For (Name);", "   end Path_For;", "",
        "   function Tall_Radical (Height_Em, Extra_Vinculum, Width_Em : Long_Float)",
        "      return Math_Paths.Path is",
        "      Height : constant Long_Float :=",
        "        (if Height_Em'Valid then Height_Em * 1_000.0 else 0.0);",
        "      Extra : constant Long_Float :=",
        "        (if Extra_Vinculum'Valid then Extra_Vinculum * 1_000.0 else 0.0);",
        "      View_Height : constant Long_Float :=",
        "        Long_Float'Floor (Height + Extra) + 80.0;",
        "      Right_Edge : constant Long_Float :=",
        "        (if Width_Em'Valid then Width_Em * 1_000.0 else 0.0);",
        "      function Image (Value : Long_Float) return String is",
        "         Text : constant String := Long_Float'Image (Value);", "      begin",
        "         return Text (Text'First + 1 .. Text'Last);", "      end Image;",
        "      Data : constant String :=",
        '        "M702 " & Image (Extra + 80.0) & "H" & Image (Right_Edge) &',
        '        " H742v" & Image (View_Height - 54.0 - 80.0 - Extra) &',
        '        " l-4 4-4 4c-.667.7 -2 1.5-4 2.5s-4.167 1.833-6.5 2.5-5.5 1-9.5 1" &',
        '        " h-12l-28-84c-16.667-52-96.667 -294.333-240-727l-212 -643 -85 170" &',
        '        " c-4-3.333-8.333-7.667-13 -13l-13-13l77-155 77-156c66 199.333 139 419.667" &',
        '        " 219 661 l218 661zM702 80H" & Image (Right_Edge) & "v" &',
        '        Image (40.0 + Extra) & "H742z";', "   begin",
        "      if not Height_Em'Valid or else not Extra_Vinculum'Valid or else",
        "        not Width_Em'Valid or else Height_Em <= 0.0 or else",
        "        Extra_Vinculum < 0.0 or else Width_Em <= 0.0 or else",
        "        Width_Em > 16.0 or else Height_Em > 16.0 or else",
        "        Extra_Vinculum > 16.0 then", '         return Math_Paths.Parse ("");',
        "      end if;", "      return Math_Paths.Parse (Data);", "   end Tall_Radical;", "",
    ]


def main():
    if len(sys.argv) != 7:
        raise SystemExit(
            "usage: generate_math_stretchy.py SVG_GEOMETRY STRETCHY CSS "
            "PACKAGE_JSON OUTPUT_ADS OUTPUT_ADB")
    labels = ("svgGeometry.js", "stretchy.js", "katex.css", "package.json")
    texts, hashes = {}, {}
    for path, label in zip(sys.argv[1:5], labels):
        texts[label], hashes[label] = checked_source(path, label)
    try:
        geometry = extract_geometry(texts["svgGeometry.js"])
        registrations = extract_registrations(texts["stretchy.js"], geometry)
    except (IndexError, ValueError) as error:
        raise SystemExit(f"error: {error}") from error
    write_spec(sys.argv[5])
    write_body(sys.argv[6], geometry, registrations, hashes)
    print("geometry paths=" + str(len(geometry)))
    print("image registrations=" + str(len(registrations)))
    print("unique registered paths=" + str(len({p for row in registrations.values() for p in row[0]})))


if __name__ == "__main__":
    main()
