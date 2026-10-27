#!/usr/bin/env python3
"""Map the pinned KaTeX registry census to native parser evidence.

This is a name/source crosswalk, not semantic qualification or a test report.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INVENTORY = ROOT / "plan/native-math-katex-0.16.22-inventory.json"
DEFAULT_JSON = ROOT / "plan/native-math-coverage.json"
DEFAULT_MD = ROOT / "plan/native-math-coverage.md"
PINNED_SCHEMA = "coyote.native-math.katex-inventory.v2"
PINNED_SHA256 = "8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33"

# Reviewed explicit Parse_Atom branches; branch/name presence is not support evidence.
FUNCTION_ALLOWLIST = {
    "tag", "tag@literal", "tag@paren", "notag", "nonumber", "relax",
    "mathchoice", "hbox", "genfrac", "cfrac",
    "hskip", "kern", "mkern", "mskip", "mathrel", "mathord", "mathbin",
    "mathop", "mathopen", "mathclose", "mathpunct", "mathinner",
    "html@mathml", "not", "mathrlap", "mathllap", "mathclap",
    "operatorname", "operatorname@", "operatornamewithlimits", "char",
    "@char", "message", "errmessage", "show", "dots", "cdots", "dotso",
    "dotsb", "dotsc", "dotsi", "dotsm", "dotsx",
    "def", "edef", "gdef", "xdef", "global", "let",
    "big", "Big", "bigg", "Bigg", "bigl", "Bigl", "biggl", "Biggl",
    "bigr", "Bigr", "biggr", "Biggr", "bigm", "Bigm", "biggm", "Biggm",
    "left", "right", "begin", "end", "frac", "dfrac", "tfrac", "binom", "dbinom",
    "tbinom", "overset", "underset", "overbrace", "underbrace",
    "cancel", "bcancel", "xcancel", "sout", "rule", "raisebox",
    "tiny", "sixptsize", "scriptsize", "footnotesize", "small", "normalsize",
    "large", "Large", "LARGE", "huge", "Huge", "smash",
    "boxed", "fbox", "phantom", "hphantom", "vphantom", "color", "textcolor",
    "displaystyle", "textstyle", "scriptstyle", "scriptscriptstyle",
    "mathbf", "mathbb", "mathcal", "Bbb", "mathit", "mathsf", "mathtt",
    "mathfrak", "mathscr", "boldsymbol", "bm", "bold", "mathnormal", "mathsfit",
    "textbf", "textit", "textmd", "textnormal", "textrm", "textsf", "texttt",
    "textup", "emph", "hat", "widehat", "bar", "vec", "dot", "ddot",
    "tilde", "widetilde", "check", "breve", "acute", "grave", "mathring",
    "overline", "underline", "overrightarrow", "overleftarrow", "r", "H",
    "u", "v", "href", "url", "includegraphics", "htmlClass", "htmlId",
    "htmlStyle", "htmlData", "textregistered", "text", "mathrm", "sqrt",
    ",", ";", "!", "quad", "sum", "prod", "int", "lim", "max", "min",
    "sin", "cos", "tan", "log", "ln", "exp", "sinh", "cosh", "tanh",
    "arcsin", "arccos", "arctan", "cot", "sec", "csc", "det", "arg",
    "ne", "neq", "notin", "to", "dots", "le", "ge", "implies", "iff",
    "limsup", "liminf", "sup", "inf", "argmax", "argmin", "ker", "dim",
    "deg", "gcd", "Pr", "arcctg", "arctg", "cotg", "ctg", "cth", "coth",
    "cosec", "hom", "lg", "sh", "tg", "th", "ch",
}
EXPLICIT_REFUSAL_NAMES = {"overleftrightarrow", "underleftarrow", "underrightarrow"}
ENVIRONMENT_ALLOWLIST = {
    "matrix", "matrix*", "smallmatrix", "pmatrix", "pmatrix*", "bmatrix", "bmatrix*",
    "Bmatrix", "Bmatrix*", "vmatrix", "vmatrix*", "Vmatrix", "Vmatrix*",
    "cases", "dcases", "drcases", "rcases", "aligned", "align", "align*", "gathered", "gather", "gather*",
    "array", "darray", "subarray", "alignat", "alignat*", "alignedat",
    "split", "equation", "equation*",
}

SYMBOL_EVIDENCE = {"src/coyote_math/math_symbols.ads": "Lookup_Math/Lookup_Text public contract", "src/coyote_math/math_symbols.adb": "generated mode-specific Find tables", "src/coyote_math/math_syntax.adb": "Parse_Atom registry and raw-Unicode lookup"}
CALLABLE_MACRO_ALLOWLIST = {
    "\\@firstoftwo", "\\@ifnextchar", "\\@secondoftwo", "\\TextOrMath",
    "\\bra@ket", "\\bra@set",
    "\\cdots", "\\dots", "\\dotsc", "\\dotso", "\\char",
    "\\errmessage", "\\expandafter", "\\message", "\\newcommand",
    "\\noexpand", "\\providecommand", "\\renewcommand", "\\show",
    "\\tag@literal", "\\futurelet", "\\long", "\\long\\def",
    "\\long\\gdef", "\\long\\edef", "\\long\\xdef",
}
SETTING_EVIDENCE = {
    "strict": ("partial-implemented-unqualified", "src/coyote_math/math_syntax.ads", "Strict_Warn/Ignore/Error diagnostics exist; callback and policy equivalence are unqualified."),
    "maxExpand": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "Finite expansion limit is accepted through 10000; unbounded/equivalent policy is not claimed."),
    "displayMode": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "Request style selects display parsing; API option parity is unqualified."),
    "minRuleThickness": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "Finite nonnegative scalar is validated and passed to layout; parity is unqualified."),
    "errorColor": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "RGBA validated and used in fallback; reference error rendering is unqualified."),
    "throwOnError": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "False enables literal-source fallback after parse error; not equivalent error fragments."),
    "globalGroup": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "Explicit context flag controls macro grouping; invocation metadata propagation and policy equivalence are unqualified."),
    "maxSize": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "Values in 1..100 are accepted and passed to layout; geometry is bounded and maxSize scaling behavior is not established as equivalent."),
    "leqno": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "True is accepted, propagated into tagged syntax, and places equation tags on the left in layout; parity remains unqualified."),
    "fleqn": ("missing", "src/coyote_math/math_engine.adb", "Setting exists in the request record but nondefault use is explicitly rejected; no left-aligned equation layout is established."),
    "trust": ("partial-implemented-unqualified", "src/coyote_math/math_engine.adb", "The API exposes a trust field whose default false profile is enforced and trust=True is explicitly rejected; no trusted rendering policy is implemented."),
    "colorIsTextColor": ("partial-implemented-unqualified", "src/coyote_math/math_syntax.adb", "A color/textcolor parser branch exists, but the colorIsTextColor API option is not exposed or wired; candidate parser behavior is unvalidated."),
    "macros": ("partial-implemented-unqualified", "src/coyote_math/math_macros.adb", "Shared macro context and scoped definitions exist; complete per-request macro option and invocation semantics are unqualified."),
}
UNSUPPORTED_SETTINGS = {}

APPROVED_SETTING_DEVIATIONS = {"output"}
SOURCE_PATHS = tuple(
    f"src/coyote_math/{name}"
    for stem in ("coyote_math_jobs", "coyote_math_resources", "math_builtin_macros",
                 "math_engine", "math_expander", "math_font_data", "math_unicode", "math_layout",
                 "math_macros", "math_metrics", "math_model", "math_painter",
                 "math_paths", "math_radical_paths", "math_raster", "math_semantics", "math_source",
                 "math_stretchy", "math_symbols", "math_syntax", "math_tokens")
    for name in (f"{stem}.ads", f"{stem}.adb")
    if (ROOT / f"src/coyote_math/{stem}.ads").exists() or
       (ROOT / f"src/coyote_math/{stem}.adb").exists()
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stable_id(registry: str, key: str, mode: str | None = None) -> str:
    raw = f"{registry}\0{mode or ''}\0{key}".encode("utf-8")
    return f"MATH-{registry.upper()}-{hashlib.sha256(raw).hexdigest()[:12]}"


def evidence(paths: list[str], claim: str) -> dict[str, Any]:
    return {"claim": claim, "source": paths}


def status_row(registry: str, key: str, status: str, *, mode: str | None = None,
               entry: Any = None, evidence_obj: dict[str, Any] | None = None,
               note: str = "") -> dict[str, Any]:
    return {
        "id": stable_id(registry, key, mode), "registry": registry,
        "key": key, "mode": mode, "status": status,
        "inventory_entry": entry,
        "native_evidence": evidence_obj or {"claim": "No direct native name correspondence found.", "source": []},
        "qualification": "unqualified; name/source correspondence only",
        "note": note,
    }


def generated_symbol_keys(inventory_path: Path) -> dict[str, set[str]]:
    """Return retained generator keys after proving generated sources match."""
    generator_path = ROOT / "tools/generate_math_symbols.py"
    spec = importlib.util.spec_from_file_location("coyote_generate_math_symbols", generator_path)
    if spec is None or spec.loader is None:
        raise ValueError("cannot load symbol table generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    modes = module.load(inventory_path)
    keys = {mode: {row[0] for row in module.entries(table)}
            for mode, table in modes.items()}
    with tempfile.TemporaryDirectory(prefix="coyote-math-coverage-") as directory:
        generated_spec = Path(directory) / "math_symbols.ads"
        generated_body = Path(directory) / "math_symbols.adb"
        module.emit(generated_spec, generated_body, modes)
        for generated, actual in (
                (generated_spec, ROOT / "src/coyote_math/math_symbols.ads"),
                (generated_body, ROOT / "src/coyote_math/math_symbols.adb")):
            if generated.read_bytes() != actual.read_bytes():
                raise ValueError(
                    f"generated symbol source differs from {actual.relative_to(ROOT)}")
    return keys


def inventory_rows(data: dict[str, Any], inventory_path: Path) -> list[dict[str, Any]]:
    regs = data["registries"]
    rows: list[dict[str, Any]] = []
    parser = "src/coyote_math/math_syntax.adb"
    symbol_keys = generated_symbol_keys(inventory_path)
    for name, entry in sorted(regs["functions"].items()):
        bare = name[1:] if name.startswith("\\") else name
        if bare in EXPLICIT_REFUSAL_NAMES:
            note = "Explicit parser branch refuses this command because required geometry is unsupported."
            ev = evidence([parser], "Parse_Atom branch explicitly fails with unsupported geometry; this is not implementation evidence.")
            state = "missing"
        elif bare in FUNCTION_ALLOWLIST or bare in {"def", "edef", "gdef", "xdef", "global", "let"} or bare in {"big", "Big", "bigg", "Bigg", "bigl", "Bigl", "biggl", "Biggl", "bigr", "Bigr", "biggr", "Biggr", "bigm", "Bigm", "biggm", "Biggm"}:
            if bare in {"right", "end"}:
                note = "Contextual parser path only: \\right closes a matching \\left group and \\end is consumed with a matching environment; these commands are not standalone atoms."
                ev = evidence([parser], "Parse_Atom/Parse_Expression delimiter and Parse_Array environment-end handling identified; context matching is implemented, broader command semantics remain unqualified.")
            else:
                note = "Native parser or expander handling path identified; runtime success, arguments, semantics, and geometry remain unqualified."
                ev = evidence([parser, "src/coyote_math/math_expander.adb"], "Reviewed explicit Parse_Atom/expander implementation path; source correspondence does not establish successful support.")
            state = "partial-implemented-unqualified"
        elif ("\\" + bare) in symbol_keys.get("math", set()) or ("\\" + bare) in symbol_keys.get("text", set()):
            note = "The generic command path falls back to a retained mode-specific Math_Symbols lookup key; parser reachability and semantics remain unqualified."
            ev = evidence([parser, "src/coyote_math/math_symbols.ads", "src/coyote_math/math_symbols.adb"], "Generic Parse_Atom command fallback looks up the backslash-prefixed name in the mode-specific generated symbol registry; regenerated table sources are byte-identical. No per-entry runtime or semantic qualification.")
            state = "partial-implemented-unqualified"
        else:
            note = "No corresponding implementation path identified in the explicit Parse_Atom allowlist or exact generated-symbol fallback."
            ev = evidence([parser], "Reviewed explicit Parse_Atom dispatch and exact generated-symbol fallback; no corresponding implementation branch/key identified.")
            state = "missing"
        rows.append(status_row("function", name, state, entry=entry, evidence_obj=ev, note=note))

    for name, entry in sorted(regs["environments"].items()):
        if name in ENVIRONMENT_ALLOWLIST:
            state = "partial-implemented-unqualified"
            ev = evidence([parser], "Parse_Array explicit allowlist and structural handling; not full environment semantics.")
            note = ("Parse_Array handles display equation/tag forms; aliases, starred variants, column specifications, and other semantics are not implied."
                    if name in {"equation", "equation*"} else
                    "Name is explicitly handled by Parse_Array; column specifications, tags, and other environment semantics are not implied.")
        else:
            state = "missing"
            ev = evidence([parser], "Reviewed Parse_Array explicit environment allowlist; name absent.")
            note = "Not accepted by the explicit Parse_Array environment allowlist."
        rows.append(status_row("environment", name, state, entry=entry, evidence_obj=ev, note=note))

    # Keys remain distinct by registry mode. Generator membership is not proof
    # of parser reachability or glyph/layout equivalence.
    for mode, table in sorted(regs["symbolsByMode"].items()):
        for name, entry in sorted(table.items()):
            emitted = name in symbol_keys.get(mode, set())
            math_accents = {"\\acute", "\\bar", "\\breve", "\\check", "\\ddot", "\\dot", "\\grave", "\\hat", "\\mathring", "\\tilde", "\\vec"}
            text_accents = {'\\\"', "\\'", "\\.", "\\=", "\\H", "\\^", "\\`", "\\r", "\\u", "\\v", "\\~"}
            accent_handled = (mode == "math" and name in math_accents) or (mode == "text" and name in text_accents)
            literal_space = name in {" ", "\\ "}
            if emitted or accent_handled or literal_space:
                state = "partial-implemented-unqualified"
                if emitted:
                    note = "Exact mode-specific lookup key is retained by the pinned generator (single valid replacement code point, supported group/font); parser reachability and glyph/font/layout behavior are unqualified."
                    claim = "Key is returned by generate_math_symbols.entries(); regenerated spec/body are byte-identical to checked-in lookup sources; no runtime or semantic qualification."
                elif accent_handled:
                    note = "This mode's Parse_Atom path maps the explicit accent command to an Accent_Node; text \\c and \\textcircled are deliberately not included. Accent shaping and geometry remain unqualified."
                    claim = "Mode-specific Parse_Atom accent mapping/Accent_Node path identified; generated symbol lookup absence does not mean the explicit accent path is absent. No shaping or geometry qualification."
                else:
                    note = "Literal whitespace is consumed by tokenization/parser spacing; this does not establish named \\space or nonbreaking-space command support."
                    claim = "Literal whitespace token/parser spacing path identified; no named space-command or semantic-equivalence claim."
                ev = evidence([parser, *SYMBOL_EVIDENCE.keys()], claim)
            else:
                state = "missing"
                note = "Key is not retained by the pinned lookup generator and no explicit mode-specific parser handling is established (including \\allowbreak, \\nobreak, \\nobreakspace, text \\c, and \\textcircled)."
                ev = evidence(list(SYMBOL_EVIDENCE), "Generator-filtered key membership checked against regenerated, byte-identical lookup sources; no specific parser branch identified for this key.")
            rows.append(status_row("symbol", name, state, mode=mode, entry=entry,
                                   evidence_obj=ev, note=note))
    # Generated string templates are lazily looked up; presence is not proof
    # that every individual template expands successfully.
    for name, entry in sorted(regs["builtinMacros"].items()):
        callable_entry = entry == "[function]"
        primitive = name in CALLABLE_MACRO_ALLOWLIST
        if not callable_entry:
            state = "partial-implemented-unqualified"
            claim = "Generated string-template lookup and expansion path exists; individual template behavior remains unqualified."
            note = "Lazy expansion-table entry exists; not a success claim for this template."
            paths = ["src/coyote_math/math_builtin_macros.ads", "src/coyote_math/math_builtin_macros.adb", "src/coyote_math/math_expander.adb"]
        elif primitive and name not in {"\\bra@ket", "\\bra@set"}:
            state = "partial-implemented-unqualified"
            claim = "Named callable primitive has explicit native argument/token-selection logic in the expander; behavior remains unqualified."
            note = "Explicit implementation found for this callable name only; no general callback support implied."
            paths = ["src/coyote_math/math_expander.adb"]
        else:
            state = "missing"
            claim = "Callable registry name is core functionality; no matching native handler in the explicit callable dispatch."
            note = "Missing core callable implementation. D12 covers only user-supplied function-valued JavaScript macros, not KaTeX built-in registry entries."
            paths = ["src/coyote_math/math_expander.adb", "requirements/native-math-compatibility.md"]
        if callable_entry and name in {"\\bra@ket", "\\bra@set"}:
            state = "partial-implemented-unqualified"
            claim = "Helper-level expansion probes exist, including the expected 499-case budget; no full KaTeX registry implementation or semantic qualification is claimed."
            note = "Tested helper-level expansion remains partial/unqualified, not missing and not qualified."
            paths = ["src/coyote_math/math_expander.adb", "test/tools/math_macros_probe.adb"]
        rows.append(status_row("builtin-macro", name, state, entry=entry,
            evidence_obj=evidence(paths, claim), note=note))

    defaults = regs["effectiveSettings"]
    for name, entry in sorted(regs["settingsSchema"].items()):
        if name in APPROVED_SETTING_DEVIATIONS:
            state = "approved-deviation-not-applicable"
            ev = evidence(["src/coyote_math/math_engine.ads", "requirements/native-math-compatibility.md"], "Markup serialization modes are excluded by approved D01-D03; native visual/semantic channels are not markup output modes.")
            note = "Approved API-format deviation; no core-default trust behavior is excluded."
        elif name in SETTING_EVIDENCE:
            state, path, claim = SETTING_EVIDENCE[name]
            ev = evidence([path, parser], claim)
            if name == "globalGroup":
                note = "Invocation metadata currently tracks two positions; full macro expansion provenance is not propagated."
            elif name == "fleqn":
                note = "Option exists in the request record but true is explicitly rejected; left-aligned equation layout is not implemented."
            elif name == "trust":
                note = "trust=False is the enforced profile and trust=True is explicitly rejected; no trusted rendering policy is implemented."
            elif name == "colorIsTextColor":
                note = "Candidate color/textcolor parser branch exists, but this API option is not exposed or wired; parser behavior remains unvalidated."
            else:
                note = "Current native scalar/context surface only; reference option parity remains unqualified."
        elif name in UNSUPPORTED_SETTINGS:
            state = "missing"
            ev = evidence(["src/coyote_math/math_engine.ads", "src/coyote_math/math_engine.adb"], UNSUPPORTED_SETTINGS[name])
            note = "Core setting is known but nondefault use is expressly rejected; this is missing required behavior, not an approved deviation."
        else:
            state = "missing"
            ev = evidence(["src/coyote_math/math_engine.ads", "src/coyote_math/math_engine.adb", parser], "Reviewed current engine options and syntax settings; no equivalent scalar implementation found.")
            note = "Not implemented as a current engine option; pinned default is not support evidence."
        rows.append(status_row("setting", name, state,
                               entry={"schema": entry, "pinned_effective_default": defaults.get(name)},
                               evidence_obj=ev, note=note))
    return rows


def supplemental_rows(data: dict[str, Any]) -> list[dict[str, Any]]:
    regs = data["registries"]
    rows: list[dict[str, Any]] = []
    runtime = regs["runtimeTables"]
    for family, table in sorted(runtime.items()):
        if isinstance(table, dict):
            items = table.items()
        elif family == "scriptData":
            items = ((f"item-{i:04d}", item) for i, item in enumerate(table))
        else:
            continue
        for name, value in sorted(items, key=lambda pair: str(pair[0])):
            if family == "unicodeSymbols":
                state = "partial-implemented-unqualified"
                claim = "The pinned Unicode decomposition table is generated into Math_Unicode and integrated with tokenization; shaping and per-symbol geometry remain unqualified."
                note = "Runtime table/token path is present; this does not establish full Unicode shaping or KaTeX output parity."
            elif family == "unicodeAccents":
                state = "partial-implemented-unqualified"
                claim = "The pinned text/math accent mappings are generated into Math_Unicode and integrated with tokenization; shaping and accent geometry remain unqualified."
                note = "Runtime accent mapping/token path is present; this is not full shaping or parity."
            elif family == "uSubsAndSups":
                state = "partial-implemented-unqualified"
                claim = "The pinned Unicode sub/superscript substitutions are generated into Math_Unicode and integrated with tokenization; per-entry behavior remains unqualified."
                note = "Runtime substitution/token path is present; the separate scriptData block ranges remain unmapped."
            elif family == "implicitCommands" and (name in {"\\limits", "\\nolimits", "^", "_"} or name.startswith("\\Big")):
                state = "partial-implemented-unqualified"
                claim = "Parse_Expression/Parse_Atom explicitly handles this implicit syntax or sized-delimiter command; equivalent semantics and geometry are not qualified."
                note = "Native parser path identified; not a complete implicit-syntax equivalence claim."
            elif family == "implicitCommands" and name in {"\\def", "\\edef", "\\gdef", "\\xdef", "\\global", "\\let"}:
                state = "partial-implemented-unqualified"
                claim = "Math_Expander has explicit directive handling; complete semantics remain unqualified."
                note = "Expansion directive source path identified; not semantic qualification."
            elif family == "scriptData":
                state = "missing"
                claim = "The Math_Unicode.Is_Script_Data predicate recognizes these ranges, but no equivalent item-specific scriptData substitution table/path is implemented."
                note = "Range predicate presence is not KaTeX scriptData substitution/shaping support; general Pango Unicode handling is not engine table evidence."
            else:
                state = "missing"
                claim = "No direct native counterpart identified."
                note = "No mapped native behavior established."
            paths = ["src/coyote_math/math_unicode.ads", "src/coyote_math/math_unicode.adb", "src/coyote_math/math_tokens.ads", "src/coyote_math/math_tokens.adb", "src/coyote_math/math_syntax.adb", "src/coyote_math/math_layout.adb"]
            rows.append(status_row(f"supplemental-{family}", str(name), state, entry=value,
                evidence_obj=evidence(paths, claim), note=note))
    font_source = (ROOT / "src/coyote_math/math_font_data.adb").read_text(encoding="utf-8")
    faces = data.get("supportingInventory", {}).get("fontFaceFiles", [])
    for face in faces:
        stem = face if face.startswith("KaTeX_") else f"KaTeX_{face}"
        command_faces = {"KaTeX_Caligraphic-Bold": {"bold", "mathcal", "cal"}, "KaTeX_Caligraphic-Regular": {"mathcal", "cal"}, "KaTeX_Fraktur-Bold": {"bold", "mathfrak", "frak"}, "KaTeX_Fraktur-Regular": {"mathfrak", "frak"}, "KaTeX_Main-Bold": {"mathbf", "boldsymbol", "bm", "bf", "textbf", "bold"}, "KaTeX_Main-Italic": {"mathit", "it", "textit", "emph"}, "KaTeX_SansSerif-Regular": {"mathsf", "sf", "textsf"}, "KaTeX_Typewriter-Regular": {"mathtt", "tt", "texttt"}, "KaTeX_Main-Regular": {"mathrm", "rm", "textrm", "textnormal", "textmd", "textup"}}
        syntax_source = (ROOT / "src/coyote_math/math_syntax.adb").read_text(encoding="utf-8")
        hit = f'"{stem}"' in font_source or any(f'"{command}"' in syntax_source for command in command_faces.get(stem, set()))
        rows.append(status_row("supplemental-font-face", face,
            "partial-implemented-unqualified" if hit else "missing",
            entry={"face": face, "font_assets": [f"share/coyote/math/fonts/{stem}.ttf"] if hit else []},
            evidence_obj=evidence(["src/coyote_math/math_model.ads", "src/coyote_math/math_metrics.ads", "src/coyote_math/math_metrics.adb", "src/coyote_math/math_font_data.ads", "src/coyote_math/math_font_data.adb"], "Generated face mapping and metric tables are present; per-face geometry/render equivalence is unqualified."),
            note="Font declaration command branch or generated face/metric mapping has name-level evidence only. Legacy bf/cal/frak/rm/sf/tt paths are partial, not false-missing; per-face geometry/render equivalence is unqualified." if hit else "No direct generated native font face mapping identified."))
    rows.append(status_row(
        "supplemental-symbol-alias", "point1", "partial-implemented-unqualified",
        entry={"alias_case": "point1", "pinned_registry_key": None},
        evidence_obj=evidence(["src/coyote_math/math_syntax.adb", "src/coyote_math/math_symbols.adb"],
            "Parser symbol alias resolution can miss the point1-style lookup key; exact lookup/filter behavior has not been semantically qualified."),
        note="Known generated-lookup alias/filter gap. Partial/unqualified despite related aliases; no full symbol support claim."))
    return rows


def validate(data: dict[str, Any], rows: list[dict[str, Any]], inventory_path: Path) -> None:
    if not inventory_path.is_file():
        raise ValueError(f"pinned inventory does not exist: {inventory_path}")
    expected = data["counts"]
    required = {"functions": 309, "environments": 33, "symbols": 2236,
                "settings": 14, "builtinMacros": 338}
    for key, value in required.items():
        if expected.get(key) != value:
            raise ValueError(f"inventory count mismatch for {key}: {expected.get(key)} != {value}")
    core_types = {"function", "environment", "symbol", "builtin-macro", "setting"}
    core = [r for r in rows if r["registry"] in core_types]
    actual = Counter(r["registry"] for r in core)
    wanted = {"function": 309, "environment": 33, "symbol": 2236,
              "builtin-macro": 338, "setting": 14}
    if actual != Counter(wanted):
        raise ValueError(f"row count mismatch: {dict(actual)} != {wanted}")
    ids = [r["id"] for r in rows]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate stable row IDs")
    if any(r["status"] == "qualified" for r in rows):
        raise ValueError("coverage mapping cannot assert qualification")
    supplemental = Counter(r["registry"] for r in rows)
    if any(supplemental[f"supplemental-{family}"] != count for family, count in
           {"unicodeSymbols": 344, "unicodeAccents": 12,
            "uSubsAndSups": 102, "scriptData": 7}.items()):
        raise ValueError("pinned Unicode supplemental row counts changed")
    if len(REQ_MATRIX) != 15 or [item[0] for item in REQ_MATRIX] != [f"REQ-MATH-{i:03d}" for i in range(1, 16)]:
        raise ValueError("REQ-MATH matrix must contain each requirement exactly once")
    for row in rows:
        if row["status"] not in {"missing", "partial-implemented-unqualified", "implemented-unqualified", "qualified", "approved-deviation-not-applicable", "unassessed"}:
            raise ValueError(f"invalid status: {row['status']}")
        if not row["id"] or not row["registry"] or row["key"] is None:
            raise ValueError("incomplete coverage row")


REQ_MATRIX = [
    ("REQ-MATH-001", "partial-implemented-unqualified", "Census/crosswalk exist; reviewed qualification decisions and case links remain absent."),
    ("REQ-MATH-002", "partial-implemented-unqualified", "Expander/templates exist; complete argument, scope, and built-in semantics remain unqualified."),
    ("REQ-MATH-003", "partial-implemented-unqualified", "Fresh/shared contexts exist; complete state-sequence qualification remains open."),
    ("REQ-MATH-004", "partial-implemented-unqualified", "Generated Math_Unicode decompositions, 12 accent mappings, and 102 script substitutions now feed tokenization; 344 raw Unicode symbol paths are inventoried. Runtime coverage is partial: scriptData's seven block ranges remain absent as a substitution table, and full Unicode shaping/geometry is unqualified."),
    ("REQ-MATH-005", "partial-implemented-unqualified", "Font/style mappings and size commands are source-present, including tiny (0.5) and sixptsize (0.6); the latest focused geometry corpus passes 145/145 cases. This remains scoped evidence and does not establish full-width origin/measurement or qualification."),
    ("REQ-MATH-006", "partial-implemented-unqualified", "Partial parser/environment support mapped; parser-present environments and aliases remain partial/unqualified, and remaining constructs are missing or partial."),
    ("REQ-MATH-007", "partial-implemented-unqualified", "Several settings have partial native surfaces; exact option parity remains unqualified. fleqn is explicitly rejected. trust=False is the enforced profile and trust=True is rejected; colorIsTextColor has a parser candidate branch but no option wiring and remains unvalidated. D11/D12 apply only to their approved callback/API deviations."),
    ("REQ-MATH-008", "partial-implemented-unqualified", "Diagnostics/source fallback exist; error-fragment and source-position parity unqualified."),
    ("REQ-MATH-009", "partial-implemented-unqualified", "The core default trust=false is maintained and sensitive commands are refused; full policy equivalence unqualified."),
    ("REQ-MATH-010", "partial-implemented-unqualified", "Job queue/source ledger exist; ledger is not CPU/work budgeting or cooperative cancellation."),
    ("REQ-MATH-011", "partial-implemented-unqualified", "Native integration exists; complete compatibility regression evidence remains open."),
    ("REQ-MATH-012", "partial-implemented-unqualified", "Semantic-tree source exists; no completed human assistive-technology review."),
    ("REQ-MATH-013", "partial-implemented-unqualified", "The frozen 16-case differential pilot and 3-image pilot are scoped evidence only; later focused geometry evidence includes failures, and full-width origin/measurement remains unmeasured. Full per-entry corpus, browser/platform pins, recorded outcome snapshots, approved thresholds, and qualification remain incomplete."),
    ("REQ-MATH-014", "partial-implemented-unqualified", "Regression-suite chronology and the latest authoritative result are recorded in the current STR; earlier run counts are historical evidence only. A green regression count is not compatibility qualification."),
    ("REQ-MATH-015", "partial-implemented-unqualified", "Pinned generators/provenance exist; full repeatable qualification and upgrade review unqualified."),
]


def render_markdown(result: dict[str, Any]) -> str:
    counts = result["summary"]["by_registry"]
    lines = [
        "# Native math registry coverage map", "",
        f"Pinned inventory: [KaTeX 0.16.22 census](native-math-katex-0.16.22-inventory.md); file SHA-256 `{result['pinned_inventory']['sha256']}`, archive SHA-256 `{result['pinned_inventory']['archive_sha256']}`, bundle SHA-256 `{result['pinned_inventory']['dist_sha256']}`.",
        "Generated by `tools/map_math_coverage.py`. Rows are stable per-entry crosswalks; no semantic parity, qualification, or percentage is claimed.",
        f"Inventory evidence: {result['pinned_inventory']['source_module_count']} source-module hashes and {result['pinned_inventory']['package_font_hash_count']} package/font hashes; inventory generator `tools/inventory_katex.cjs` SHA-256 `{result['pinned_inventory']['inventory_generator_sha256']}`. Regeneration validates archive files, anchor checks, counts, and pinned bundle; this map also validates native generated-symbol sources byte-identical.", "",
        "## Status counts", "", "| Registry | Total | Missing | Partial, unqualified | Approved deviation |", "|---|---:|---:|---:|---:|",
    ]
    for registry, values in sorted(counts.items()):
        lines.append(f"| {registry} | {values['total']} | {values.get('missing', 0)} | {values.get('partial-implemented-unqualified', 0)} | {values.get('approved-deviation-not-applicable', 0)} |")
    core = result["summary"]["core_status"]
    lines += ["", f"Core registry rows: {result['summary']['core_registry_rows']}; missing core rows: {core['missing']}. Missing means no direct native implementation evidence; partial/unqualified rows remain unqualified. These are counts, not a coverage percentage.", "", "## Requirement disposition", "", "| Requirement | Status | Evidence / unmet work |", "|---|---|---|"]
    for req, state, unmet in REQ_MATRIX:
        lines.append(f"| {req} | {state} | {unmet} |")
    lines += ["", "REQ-MATH status is evidence only, not acceptance. D11 excludes only function-valued strict/trust callbacks; D12 excludes only caller-supplied function-valued JavaScript macros. Neither excludes callable KaTeX core built-ins; unresolved core work stays visible.", "", "## Interpretation and limits", "",
        "* Partial means source-path/name evidence only; for explicit parser handlers it records actual command handling, not arguments, success, errors, semantics, geometry, or parity.",
        "* Function classification records explicit Parse_Atom branches, explicitly contextual parser commands, and exact generated-symbol registry fallback keys. Contextual right/end are only recognized in matching delimiter/environment contexts. Lookup-path evidence is not successful command or semantic support; explicit refusals and names with no path/key remain missing. Environment evidence reflects explicit Parse_Array names; one inventory environment remains absent. Equation/equation* are display-tag paths, not general aliases/starred semantics. Brace-parser context syntax/data-path/layout integration remains genuinely unimplemented; no qualification is claimed.",
        "* Generated string templates have lazy lookup/expansion paths but no per-template success qualification. Callable bra@ket and bra@set have helper-level expansion probes (including the expected 499-case budget); those tests are not full KaTeX registry-semantic qualification. Both remain partial/unqualified core rows and neither has a D12 exception. @ifstar is a string template using @ifnextchar. TextOrMath has dynamic text/math mode selection; remaining callable paths are partial only where actual handlers exist, and otherwise remain missing.",
        "* Settings with partial native surfaces include strict, maxExpand, displayMode, minRuleThickness, errorColor, throwOnError, globalGroup, macros, maxSize, trust, and colorIsTextColor. maxSize is accepted and passed to bounded layout; exact scaling parity remains unqualified. fleqn is explicitly rejected; trust=False is enforced while trust=True is explicitly rejected. colorIsTextColor has a color/textcolor parser candidate branch but no API option wiring and is unvalidated. D11/D12 record only approved function-valued callback/macro deviations.",
        "* Unicode symbol/accent/substitution rows are partial where generated Math_Unicode lookups feed tokenization; this is not complete shaping or parity. The seven scriptData block ranges remain missing: generic Pango Unicode handling is not the engine's scriptData substitution table.",
        "* Symbols are mode-specific generated lookup rows; generator membership is not parser reachability, runtime lookup, glyph/font/layout equivalence, or qualification.", "",
        "## Supplemental family totals", ""]
    for family, values in sorted(result["summary"]["supplemental"].items()):
        lines.append(f"* `{family}`: {values['total']} rows ({values.get('partial-implemented-unqualified', 0)} partial/unqualified; {values.get('missing', 0)} missing).")
    lines += ["", "## Highest missing families", ""]
    for family, count in result["summary"]["top_missing_families"]:
        lines.append(f"* `{family}`: {count}")
    lines += ["", "## Census reconciliation", "", "| Registry | Inventory count | Map rows | Difference |", "|---|---:|---:|---:|"]
    for family, mapped in sorted(counts.items()):
        inventory_count = mapped["total"] if family in {"function", "environment", "symbol", "builtin-macro", "setting"} else "supplemental"
        difference = "0" if inventory_count == mapped["total"] else "—"
        lines.append(f"| {family} | {inventory_count} | {mapped['total']} | {difference} |")
    lines.append("")
    return "\n".join(lines)

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, default=DEFAULT_INVENTORY)
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON)
    parser.add_argument("--markdown", type=Path, default=DEFAULT_MD)
    parser.add_argument("--check", action="store_true", help="validate and report without writing outputs")
    parser.add_argument("--summary-only", action="store_true", help="print recomputed counts without writing coverage artifacts")
    args = parser.parse_args()
    try:
        inventory_path = args.inventory.resolve()
        raw = inventory_path.read_bytes()
        inv = json.loads(raw)
        if inv.get("schema") != PINNED_SCHEMA:
            raise ValueError(f"unexpected inventory schema: {inv.get('schema')!r}")
        if inv.get("provenance", {}).get("distSha256") != PINNED_SHA256:
            raise ValueError("pinned KaTeX dist SHA-256 does not match expected reference")
        rows = inventory_rows(inv, inventory_path)
        rows.extend(supplemental_rows(inv))
        validate(inv, rows, inventory_path)
        by_registry: dict[str, dict[str, int]] = {}
        for row in rows:
            bucket = by_registry.setdefault(row["registry"], Counter())
            bucket["total"] += 1
            bucket[row["status"]] += 1
        top_missing = sorted(((key, value.get("missing", 0)) for key, value in by_registry.items() if value.get("missing", 0)), key=lambda item: (-item[1], item[0]))[:10]
        source_hashes = {path: sha256(ROOT / path) for path in SOURCE_PATHS if (ROOT / path).is_file()}
        core_status = Counter(row["status"] for row in rows if row["registry"] in {"function", "environment", "symbol", "builtin-macro", "setting"})
        result = {
            "schema": "coyote.native-math-coverage.v1",
            "pinned_inventory": {
                "path": str(inventory_path.relative_to(ROOT)) if inventory_path.is_relative_to(ROOT) else str(inventory_path),
                "sha256": hashlib.sha256(raw).hexdigest(), "dist_sha256": PINNED_SHA256, "schema": PINNED_SCHEMA,
                "archive_sha256": inv["provenance"]["npmArchiveSha256"],
                "source_module_count": len(inv["supportingInventory"]["sourceModuleSha256"]),
                "source_module_sha256": inv["supportingInventory"]["sourceModuleSha256"],
                "package_font_hash_count": len(inv["supportingInventory"]["packageAndFontSha256"]),
                "package_font_sha256": inv["supportingInventory"]["packageAndFontSha256"],
                "inventory_generator": "tools/inventory_katex.cjs",
                "inventory_generator_sha256": sha256(ROOT / "tools/inventory_katex.cjs"),
                "generation_validation": "Generator verifies every relevant package/archive file byte-for-byte, exact instrumentation anchors, registry counts, and pinned archive/dist hashes; this map validates the pinned inventory and regenerates native symbol tables byte-identically against checked-in sources.",
            },
            "evidence_source_sha256": source_hashes,
            "method": "Reviewed actual parser branches/refusals, contextual parser handling and exact mode-specific generated-symbol fallback keys; builtin macros by generated templates and explicit callable allowlist; symbols by pinned generated tables; Unicode runtime rows by Math_Unicode token paths; scriptData by item-specific substitution evidence; settings by engine surfaces/rejections. Stable IDs and ordered source hashes make regeneration deterministic; no semantic or qualification status is claimed.",
            "requirements": [{"id": req, "status": status, "evidence_and_unmet": evidence_text} for req, status, evidence_text in REQ_MATRIX],
            "summary": {"core_registry_rows": sum(by_registry[k]["total"] for k in ("function", "environment", "symbol", "builtin-macro", "setting")), "core_status": dict(sorted(core_status.items())), "by_registry": {k: dict(v) for k, v in sorted(by_registry.items())}, "top_missing_families": top_missing, "supplemental": {k: dict(v) for k, v in sorted(by_registry.items()) if k.startswith("supplemental-")}},
            "rows": rows,
        }
        json_output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
        markdown_output = render_markdown(result)
        if args.check:
            for path, expected in ((args.json, json_output), (args.markdown, markdown_output)):
                if not path.is_file() or path.read_text(encoding="utf-8") != expected:
                    raise ValueError(f"generated coverage output is stale: {path}")
            print(json.dumps(result["summary"], indent=2, sort_keys=True))
        elif args.summary_only:
            print(json.dumps(result["summary"], indent=2, sort_keys=True))
        elif args.summary_only:
            print(json.dumps(result["summary"], indent=2, sort_keys=True))
        else:
            args.json.parent.mkdir(parents=True, exist_ok=True)
            args.markdown.parent.mkdir(parents=True, exist_ok=True)
            args.json.write_text(json_output, encoding="utf-8")
            args.markdown.write_text(markdown_output, encoding="utf-8")
            print(json.dumps(result["summary"], indent=2, sort_keys=True))
        return 0
    except (OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
        print(f"map_math_coverage.py: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
