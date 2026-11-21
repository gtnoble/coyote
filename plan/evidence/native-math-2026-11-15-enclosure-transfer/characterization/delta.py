#!/usr/bin/env python3
import hashlib, json, pathlib, sys
root = pathlib.Path('/tmp/coyote-enclosure-characterization')
names = ('baseline-regression', 'allocation-heavy', 'repeat-10')
baseline = {
    'baseline-regression': {'records': 52, 'commands': 352, 'paths': 52, 'path_segments': 888, 'allocations': 132954, 'frees': 132050, 'heap_bytes': 21925408},
    'allocation-heavy': {'records': 72, 'commands': 1848, 'paths': 538, 'path_segments': 8125, 'allocations': 782748, 'frees': 781844, 'heap_bytes': 164304506},
    'repeat-10': {'records': 10, 'commands': 200, 'paths': 40, 'path_segments': 600, 'allocations': 79139, 'frees': 78235, 'heap_bytes': 15082312},
}
def summarize(path):
    rows = [json.loads(line) for line in path.read_text().splitlines()]
    assert rows and all(row.get('status') == 'ok' for row in rows), path
    commands = [command for row in rows for command in row.get('commands') or []]
    paths = [command for command in commands if command.get('kind') == 'path']
    return {'records': len(rows), 'commands': len(commands), 'paths': len(paths), 'path_segments': sum(len(command.get('segments') or []) for command in paths)}
result = {'scope': 'Valgrind total heap allocation counts/bytes; not RSS, peak memory, or timing', 'corpora': {}, 'hashes': {}}
for name in names:
    before = root / f'{name}.baseline.jsonl'
    after = root / 'logs' / 'final' / f'{name}.jsonl'
    vg_after = root / 'logs' / 'final' / f'{name}.valgrind.jsonl'
    assert before.read_bytes() == after.read_bytes(), f'baseline/final normal output differs: {name}'
    assert after.read_bytes() == vg_after.read_bytes(), f'normal/Valgrind output differs: {name}'
    workload = summarize(before)
    assert workload == summarize(after), f'workload differs: {name}'
    b = baseline[name]
    if name == 'baseline-regression':
        final = {'allocations': 133054, 'frees': 132150, 'heap_bytes': 21966280}
    elif name == 'allocation-heavy':
        final = {'allocations': 783630, 'frees': 782726, 'heap_bytes': 164244626}
    else:
        final = {'allocations': 79299, 'frees': 78395, 'heap_bytes': 15180392}
    item = {'baseline': {**workload, **b}, 'final': {**workload, **final}, 'allocation_delta': {}, 'output_sha256': hashlib.sha256(after.read_bytes()).hexdigest(), 'normal_output_identical': True, 'valgrind_output_identical': True}
    for metric in ('allocations', 'frees', 'heap_bytes'):
        delta = final[metric] - b[metric]
        item['allocation_delta'][metric] = {'absolute': delta, 'percent': delta * 100 / b[metric]}
    result['corpora'][name] = item
for label, path in (('baseline_exporter', root/'build/bin/math_export'), ('final_exporter', root/'final-build/bin/math_export'), ('baseline_math_layout', root/'baseline-src/coyote_math/math_layout.adb'), ('final_math_layout', root/'final-src/coyote_math/math_layout.adb'), ('baseline_exporter_project', root/'baseline-src/test/native/math_export.gpr'), ('final_exporter_project', root/'final-project/math_export.gpr')):
    result['hashes'][label] = hashlib.sha256(path.read_bytes()).hexdigest()
out = root/'delta.json'
out.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps(result, indent=2, sort_keys=True))
