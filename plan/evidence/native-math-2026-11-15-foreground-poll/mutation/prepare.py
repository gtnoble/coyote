from pathlib import Path
import hashlib, shutil

repo = Path('/home/gtnoble/Projects/coyote/coyote-latex-math')
root = Path('/tmp/coyote-color-mutation')
src = root / 'source'
src.mkdir(parents=True, exist_ok=True)
for path in (repo / 'src/coyote_math').iterdir():
    if path.is_file() and path.suffix.lower() in {'.ads', '.adb'}:
        shutil.copy2(path, src / path.name)
probe_dir = root / 'tools'
probe_dir.mkdir(exist_ok=True)
shutil.copy2(repo / 'test/tools/math_engine_probe.adb', probe_dir / 'math_engine_probe.adb')
layout = src / 'math_layout.adb'
text = layout.read_text()
anchor = '   procedure Apply_Foreground\n'
start = text.index(anchor)
end = text.index('   end Apply_Foreground;', start) + len('   end Apply_Foreground;')
helper = text[start:end]
target = '         Math_Work_Control.Poll (Work);\n'
if helper.count(target) != 1:
    raise SystemExit(f'Expected exactly one poll in Apply_Foreground, got {helper.count(target)}')
mutated = text[:start] + helper.replace(target, '', 1) + text[end:]
layout.write_text(mutated)
project = (repo / 'test/native/math_engine.gpr').read_text()
old = '   for Source_Dirs use ("../../src/coyote_math", "../tools");'
new = f'   for Source_Dirs use ("{src}", "{probe_dir}");'
if project.count(old) != 1:
    raise SystemExit('Could not uniquely locate Source_Dirs in project')
(root / 'math_engine.gpr').write_text(project.replace(old, new, 1))
original = (repo / 'src/coyote_math/math_layout.adb').read_bytes()
copy = layout.read_bytes()
(root / 'original-layout.sha256').write_text(hashlib.sha256(original).hexdigest() + '  src/coyote_math/math_layout.adb\n')
(root / 'mutated-layout.sha256').write_text(hashlib.sha256(copy).hexdigest() + '  source/math_layout.adb\n')
for base, label in ((repo / 'src/coyote_math', 'repo'), (src, 'copy')):
    rows = []
    for path in sorted(base.iterdir()):
        if path.is_file() and path.suffix.lower() in {'.ads', '.adb'}:
            rows.append(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}')
    (root / f'{label}-source-hashes.sha256').write_text('\n'.join(rows) + '\n')
print(f'Ada source files copied: {sum(1 for p in src.iterdir() if p.is_file() and p.suffix.lower() in {".ads", ".adb"})}')
print(f'Apply_Foreground target removed exactly once; other helper content preserved.')
print(f'Probe source SHA256: {hashlib.sha256((probe_dir / "math_engine_probe.adb").read_bytes()).hexdigest()}')
print(f'Temporary GPR: {root / "math_engine.gpr"}')
