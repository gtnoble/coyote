#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const executable = path.resolve(process.argv[2] || '/tmp/coyote-math-export/bin/math_export');
const reportPath = process.argv[3] ? path.resolve(process.argv[3]) : null;
const SEED = 0x6d617468;
const CASES = 10000;
const BATCH = 256;
const TIMEOUT_MS = 30000;
const MAX_SOURCE_BYTES = 512;
const schema = 'coyote.math-export.v1';

function assert(condition, message) {
  if (!condition) throw new Error(message);
}
function rng(seed) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13; state >>>= 0;
    state ^= state >>> 17; state >>>= 0;
    state ^= state << 5; state >>>= 0;
    return state >>> 0;
  };
}
const random = rng(SEED);
const pick = values => values[random() % values.length];
const atoms = ['x', 'y', '1', '+', '-', '=', '\\alpha', '\\beta', '\\sqrt{x}', '\\frac{a}{b}', '^2', '_{i}', '\\text{hi}', '\\sum_{i=0}^n', '\\unknown', '{', '}', '\\left(', '\\right)', '\\color{red}{x}', '\\href{javascript:alert(1)}{x}', '\\def\\a{\\a}\\a', '\\def\\a{\\b}\\def\\b{\\a}\\a', '% comment\n', '\\begin{matrix}a&b\\\\c&d\\end{matrix}', '\\begin{array}{cc}x&y\\\\z&w\\end{array}', '\\path{M0 0L1 1}', '\\includegraphics{../../sentinel}', '\\unicode{1F642}', '😀', '𝛼', 'é', '\u0301', '∑', '\\unknowncommand'];
const types = ['validish', 'invalidish', 'unicode', 'scripts', 'macros', 'comments', 'arrays', 'paths'];
function makeSource() {
  const kind = types[random() % types.length];
  let source;
  switch (kind) {
    case 'validish': source = `${pick(['', '$'])}${pick(['x', '\\alpha', '\\sqrt{x}', '\\frac{a}{b}', 'a+b'])}${pick(['', '$'])}`; break;
    case 'invalidish': source = pick(['\\unknowncommand{', '{x', '\\frac{a}', '\\left(x', '\\begin{bad}x\\end{bad}', '\\sqrt{', '\\href{javascript:bad}{x}']); break;
    case 'unicode': source = `${pick(['😀', '𝛼', 'é', '∑', '𐐷'])}${pick(['x', '^2', '_i'])}`; break;
    case 'scripts': source = `${pick(['x', 'a', '\\alpha'])}${pick(['^2', '_i', '^{n+1}', '_{i=0}'])}${pick(['', '^3', '_j'])}`; break;
    case 'macros': source = pick(['\\def\\a{x}\\a', '\\def\\a{\\b}\\def\\b{y}\\a', '\\def\\a{\\a}\\a', '\\newcommand{\\x}{x}\\x', '\\def\\x{\\y}\\def\\y{\\x}\\x']); break;
    case 'comments': source = `${pick(['x', '\\alpha', '{'])}%${pick([' ignored', '😀', '\\def\\a{x}'])}\n${pick(['+y', '}', '\\unknown'])}`; break;
    case 'arrays': source = pick(['\\begin{matrix}a&b\\\\c&d\\end{matrix}', '\\begin{array}{cc}x&y\\\\z&w\\end{array}', '\\begin{matrix}\\alpha&\\frac{1}{2}\\end{matrix}', '\\begin{matrix}x']); break;
    default: source = pick(['\\path{M0 0L1 1}', '\\widehat{abc}', '\\overline{x}', '\\includegraphics{../../sentinel}', '\\href{file:///etc/passwd}{x}', '\\color{red}{\\sqrt{x}}']);
  }
  while (Buffer.byteLength(source, 'utf8') >= MAX_SOURCE_BYTES) source = source.slice(0, -1);
  return { kind, source, displayMode: (random() & 1) === 1 };
}
function finiteTree(value, label) {
  if (typeof value === 'number') assert(Number.isFinite(value), `${label}: non-finite number`);
  else if (Array.isArray(value)) value.forEach((x, i) => finiteTree(x, `${label}[${i}]`));
  else if (value && typeof value === 'object') for (const [key, child] of Object.entries(value)) finiteTree(child, `${label}.${key}`);
}
function runBatch(cases, batchNo) {
  const input = cases.map(c => JSON.stringify({ id: c.id, source: c.source, displayMode: c.displayMode }) + '\n').join('');
  const child = spawnSync(executable, [], { input, encoding: 'utf8', timeout: TIMEOUT_MS, maxBuffer: 32 * 1024 * 1024 });
  if (child.error || child.status !== 0) {
    const reason = child.error ? `${child.error.code || child.error.message}` : `exit ${child.status}, signal ${child.signal}`;
    throw new Error(`batch ${batchNo} ${child.error && child.error.code === 'ETIMEDOUT' ? 'TIMEOUT' : 'CRASH'} cases ${cases[0].id}..${cases[cases.length - 1].id}: ${reason}; stderr=${(child.stderr || '').slice(0, 1000)}`);
  }
  const lines = child.stdout.split('\n').filter(Boolean);
  assert(lines.length === cases.length, `batch ${batchNo}: expected ${cases.length} output rows, got ${lines.length}`);
  return lines.map((line, index) => {
    let row;
    try { row = JSON.parse(line); } catch (error) { throw new Error(`batch ${batchNo} row ${index}: invalid JSON: ${error.message}`); }
    const c = cases[index];
    assert(row.schema === schema && row.engine === 'native', `batch ${batchNo} ${c.id}: schema/engine mismatch`);
    assert(row.id === c.id && row.source === c.source && row.displayMode === c.displayMode, `batch ${batchNo} ${c.id}: id/source/display identity mismatch`);
    assert(['ok', 'parse-error', 'layout-error', 'policy-visible-command'].includes(row.status), `batch ${batchNo} ${c.id}: unexpected status ${row.status}`);
    if (row.status === 'ok' || row.status === 'policy-visible-command') {
      assert(row.box && Array.isArray(row.commands), `batch ${batchNo} ${c.id}: successful output missing box/commands`);
      finiteTree(row.box, `${c.id}.box`);
      assert(Number.isFinite(row.box.width) && Number.isFinite(row.box.ascent) && Number.isFinite(row.box.descent), `${c.id}: invalid box geometry`);
      if (row.status === 'policy-visible-command') validatePolicyVisible(row, c.id);
      for (const [i, command] of row.commands.entries()) {
        finiteTree(command, `${c.id}.commands[${i}]`);
        if (command.kind === 'glyph') assert(Number.isInteger(command.codePoint) && command.codePoint > 0, `${c.id}: invalid glyph code point`);
        if (command.kind === 'path') assert(Array.isArray(command.segments) && command.segments.length > 0, `${c.id}: empty path sentinel`);
        assert(['glyph', 'rule', 'path'].includes(command.kind), `${c.id}: invalid command kind ${command.kind}`);
      }
    }
    return row;
  });
}
function validatePolicyVisible(row, label) {
  assert(row.policy && row.policy.refusal === true, `${label}: policy-visible status without policy.refusal=true`);
  assert(typeof row.policy.diagnostic === 'string' && row.policy.diagnostic.length > 0 && /refused untrusted command:/.test(row.policy.diagnostic), `${label}: missing policy refusal diagnostic`);
  assert(row.commands.length > 0, `${label}: policy-visible output has empty geometry commands`);
}
function assertPolicyNegativeControls() {
  const base = { status: 'policy-visible-command', box: { width: 1, ascent: 1, descent: 0 }, commands: [{ kind: 'glyph', codePoint: 120 }] };
  for (const policy of [{ refusal: false, diagnostic: 'refused untrusted command: \\href' }, { diagnostic: 'refused untrusted command: \\href' }]) {
    let rejected = false;
    try { validatePolicyVisible({ ...base, policy }, 'negative-control'); }
    catch { rejected = true; }
    assert(rejected, 'negative control: policy-visible record without refusal=true was accepted');
  }
}
function main() {
  assertPolicyNegativeControls();
  assertPolicyNegativeControls();
  assert(fs.existsSync(executable), `native exporter not found: ${executable}`);
  const started = Date.now(), cases = [];
  for (let i = 0; i < CASES; i++) cases.push({ id: `fuzz-${String(i).padStart(5, '0')}`, ...makeSource() });
  assert(cases.every(c => Buffer.byteLength(c.source, 'utf8') < MAX_SOURCE_BYTES), 'source limit exceeded');
  const statuses = { ok: 0, 'parse-error': 0, 'layout-error': 0, 'policy-visible-command': 0 };
  let errors = 0;
  for (let start = 0; start < cases.length; start += BATCH) {
    const rows = runBatch(cases.slice(start, start + BATCH), Math.floor(start / BATCH));
    for (const row of rows) { statuses[row.status]++; if (row.error) errors++; }
  }
  const subset = cases.slice(0, 32);
  const repeatA = runBatch(subset, 'repro-a').map(JSON.stringify).join('\n');
  const repeatB = runBatch(subset, 'repro-b').map(JSON.stringify).join('\n');
  assert(repeatA === repeatB, 'stateless 32-case reproducibility comparison failed');
  const report = {
    harness: 'check-math-fuzz.cjs', seed: `0x${SEED.toString(16)}`, cases: CASES,
    batchSize: BATCH, batches: Math.ceil(CASES / BATCH), timeoutMsPerBatch: TIMEOUT_MS,
    maxSourceBytesExclusive: MAX_SOURCE_BYTES, geometryValidation: 'finite boxes and commands; policy-visible refusal diagnostic and nonempty commands; nonempty paths',
    statuses, rowsWithError: errors, reproducibility: { cases: subset.length, identical: true },
    memory: 'job limit 256 MiB; memory usage not measured', elapsedMs: Date.now() - started,
  };
  if (reportPath) fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  process.stdout.write(JSON.stringify(report, null, 2) + '\n');
}
try { main(); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
