#!/usr/bin/env python3
"""Extract and safely evaluate the five pinned KaTeX radical path templates."""
import ast
import hashlib
import json
import re
import sys
from pathlib import Path

SHA256 = "e7bb196633f23cab95da9d010ffbbdad37d2c942c2f96a33f8094f260ecfd892"
NAMES = ("sqrtMain", "sqrtSize1", "sqrtSize2", "sqrtSize3", "sqrtSize4")


def arithmetic(expression, values):
    tree = ast.parse(expression, mode="eval")
    def visit(node):
        if isinstance(node, ast.Expression): return visit(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)): return node.value
        if isinstance(node, ast.Name) and node.id in values: return values[node.id]
        if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub, ast.Div)):
            left, right = visit(node.left), visit(node.right)
            return left + right if isinstance(node.op, ast.Add) else left - right if isinstance(node.op, ast.Sub) else left / right
        raise ValueError("unapproved interpolation arithmetic")
    return visit(tree)


def extract(source):
    paths = {}
    for name in NAMES:
        match = re.search(r"const " + name + r" = function\([^)]*\): string \{([\s\S]*?)\n\};", source)
        if not match: raise ValueError("missing function " + name)
        body = match.group(1)
        template = re.search(r"return `([\s\S]*?)`;", body)
        if not template: raise ValueError("missing path template " + name)
        parts = re.split(r"\$\{([^}]+)\}", template.group(1))
        paths[name] = parts
    return paths


def render(parts, extra):
    values = {"extraVinculum": extra, "hLinePad": 80}
    out = ""
    for i, part in enumerate(parts):
        if i % 2 == 0: out += part
        else:
            # Template expressions may only reference approved parameters/constants.
            if not re.fullmatch(r"[0-9.]+|extraVinculum|hLinePad|[0-9.]+ [+/\-*] (extraVinculum|hLinePad)|[0-9.]+ \+ extraVinculum \+ hLinePad|extraVinculum / [0-9.]+", part.strip()):
                raise ValueError("unapproved template expression: " + part)
            value = arithmetic(part.strip(), values)
            out += str(int(value)) if isinstance(value, float) and value.is_integer() else str(value)
    return " ".join(out.split())


def main():
    if len(sys.argv) != 3: raise SystemExit("usage: generate_math_radical_paths.py svgGeometry.js output.json")
    raw = Path(sys.argv[1]).read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != SHA256: raise ValueError("KaTeX source SHA-256 mismatch: " + digest)
    paths = extract(raw.decode("utf-8"))
    cases = {str(extra): {name: render(parts, extra) for name, parts in paths.items()} for extra in (0, 100)}
    Path(sys.argv[2]).write_text(json.dumps({"sha256": digest, "paths": cases}, sort_keys=True, separators=(",", ":")) + "\n")
    print(digest)

if __name__ == "__main__": main()
