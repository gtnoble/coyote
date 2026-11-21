#!/usr/bin/env node
'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const executable = path.resolve(process.argv[2] || '/tmp/coyote-math-export/bin/math_export');
const reportPath = process.argv[3] ? path.resolve(process.argv[3]) : null;
const SEED = 0x6d617468;
const CASES = 10000;
const PER_FAMILY = 1250;
const BATCH_UNITS = 32;
const TIMEOUT_MS = 30000;
const OVERALL_TIMEOUT_MS = 300000;
const MAX_SOURCE_BYTES = 8192;
const MAX_COMMANDS = 131072;
const MAX_GEOMETRY = 16384;
const schema = 'coyote.math-export.v1';
const families = ['valid-grammar', 'malformed', 'unicode', 'scripts', 'macro-expansion', 'arrays', 'dimensions', 'comments-accents-policy'];

function assert(condition, message) { if (!condition) throw new Error(message); }
function rng(seed) {
  let state = seed >>> 0;
  return () => { state ^= state << 13; state >>>= 0; state ^= state >>> 17; state >>>= 0; state ^= state << 5; state >>>= 0; return state >>> 0; };
}
const random = rng(SEED);
const pick = values => values[random() % values.length];
function alphaName(value) {
  let n = value + 1, name = '';
  while (n > 0) { n--; name = String.fromCharCode(97 + n % 26) + name; n = Math.floor(n / 26); }
  return name;
}
function knownAtom(depth) {
  const terminals = ['x', 'y', 'a', 'b', '1', '2', '\\alpha', '\\beta', '\\gamma', '\\pi', '\\text{hi}', '\\text{a b}'];
  if (depth <= 0 || random() % 4 === 0) return pick(terminals);
  switch (random() % 7) {
    case 0: return `\\sqrt{${knownAtom(depth - 1)}}`;
    case 1: return `\\frac{${knownAtom(depth - 1)}}{${knownAtom(depth - 1)}}`;
    case 2: return `{${knownAtom(depth - 1)}+${knownAtom(depth - 1)}}`;
    case 3: return `${pick(['x', 'a', '\\alpha', '2'])}^{${pick(['2', 'n+1', 'i'])}}`;
    case 4: return `${pick(['x', 'y', '\\alpha'])}_{${pick(['i', 'j', 'k'])}}`;
    case 5: { const delimiter = pick([['(', ')'], ['[', ']'], ['|', '|']]); return `\\left${delimiter[0]}${knownAtom(depth - 1)}\\right${delimiter[1]}`; }
    default: return `\\color{${pick(['red', 'blue', 'green'])}}{${knownAtom(depth - 1)}}`;
  }
}
function exploratoryAtom(depth) {
  const tokens = ['x', 'y', '1', '+', '-', '=', '\\alpha', '\\sin', '\\log', '\\sum_{i=0}^n', '\\text{hi}'];
  if (depth <= 0 || random() % 3 === 0) return pick(tokens);
  return `${knownAtom(depth - 1)}${pick(['+', '-', '=', '^', '_'])}${pick(tokens)}`;
}
function validExpression() {
  const count = 1 + random() % 4;
  let result = knownAtom(3);
  for (let i = 1; i < count; i++) result += `${pick(['+', '-', '=', '\\,'])}${knownAtom(2)}`;
  return result;
}
function makeCase(index) {
  const family = families[Math.floor(index / PER_FAMILY)];
  let source, expectedStatus = null, expectedError = null, expectedGlyphs = null;
  switch (family) {
    case 'valid-grammar': source = validExpression(); expectedStatus = 'ok'; break;
    case 'malformed': source = pick(['\\frac{a}', '\\sqrt{', '{x', '\\begin{matrix}x', '\\left(x', '\\begin{bad}x\\end{bad}']); expectedStatus = 'parse-error'; break;
    case 'unicode': source = `${pick(['😀', '𝛼', 'é', '∑', '𐐷', '中', 'क', '\u0301', '\u0000'])}${pick(['', 'x', '^2', '_i', `\\text{${pick(['é', '漢', '😀'])}}`])}`; break;
    case 'scripts':
      source = pick([`${pick(['x', 'a', '\\alpha'])}^{${pick(['2', 'n+1', 'i=0'])}}`, `${pick(['x', 'y'])}_{${pick(['i', 'j+1'])}}`, `x^{${exploratoryAtom(2)}}_{${exploratoryAtom(1)}}`, 'x^^2', 'x__i', 'x^2^3', 'x_1_2']);
      if (['x^^2', 'x__i', 'x^2^3', 'x_1_2'].includes(source)) expectedStatus = 'parse-error';
      break;
    case 'macro-expansion': {
      const n = index % 10000, name = `\\fuzzm${alphaName(n)}`, cycle = `\\fuzzn${alphaName(n)}`;
      const leaf = pick(['x', 'y', '\\alpha', '\\frac{a}{b}', '\\sqrt{z}']);
      const nesting = 1 + random() % 3, mode = index % 5;
      if (mode === 0) { source = `\\def${name}{${cycle}}\\def${cycle}{${name}}${name}`; expectedStatus = 'parse-error'; expectedError = 'macro expansion: EXPANSION_LIMIT'; }
      else if (mode === 1 || mode === 4) {
        source = `\\def${name}{${leaf}}${name}`;
        expectedGlyphs = leaf === 'x' ? [0x78] : leaf === 'y' ? [0x79] : leaf === '\\alpha' ? [0x3b1] : leaf === '\\frac{a}{b}' ? [0x61, 0x62] : [0x7a];
      } else if (mode === 2) {
        const depth = 12 + random() % 8;
        const names = Array.from({ length: depth + 1 }, (_, i) => `\\fuzzd${alphaName(i)}`);
        source = `${names.slice(0, depth).map((macro, i) => `\\def${macro}{${names[i + 1]}${names[i + 1]}}`).join('')}\\def${names[depth]}{x}${names[0]}`;
        expectedStatus = 'parse-error'; expectedError = 'macro expansion: EXPANSION_LIMIT';
      } else source = `\\def${name}{${leaf}}${Array(nesting).fill(name).join('')}`;
      break;
    }
    case 'arrays': {
      const mode = index % 10;
      if (mode === 0) { source = `\\begin{matrix}${Array.from({ length: 65 }, (_, i) => i % 2 ? 'x' : 'y').join('\\\\')}\\end{matrix}`; expectedStatus = 'parse-error'; expectedError = 'array row limit exceeded'; }
      else if (mode === 1) { source = `\\begin{array}{${'c'.repeat(65)}}x\\end{array}`; expectedStatus = 'parse-error'; expectedError = 'invalid array column specification'; }
      else { const rows = 1 + random() % 5, env = pick(['matrix', 'pmatrix', 'bmatrix']); source = `\\begin{${env}}${Array.from({ length: rows }, () => Array.from({ length: 1 + random() % 4 }, () => knownAtom(1)).join('&')).join('\\\\')}\\end{${env}}`; }
      break;
    }
    case 'dimensions': {
      const mode = index % 8;
      if (mode === 0) { source = '\\kern{16385em}'; expectedStatus = 'parse-error'; expectedError = 'dimension exceeds bounded geometry'; }
      else if (mode === 1) { source = '\\kern{100em}'.repeat(165); expectedStatus = 'layout-error'; expectedError = 'layout geometry limit exceeded'; }
      else source = `\\kern{${pick(['0.1em', '1em', '10em', '-1em', '100em'])}}${validExpression()}`;
      break;
    }
    default: {
      const mode = index % 6;
      if (mode === 0) source = `${exploratoryAtom(2)}% ignored \\unknowncommand\n+${knownAtom(1)}`;
      else if (mode === 1) source = `\\widehat{${knownAtom(2)}}`;
      else if (mode === 2) source = `\\overline{\\underline{${knownAtom(2)}}}`;
      else if (mode === 3) { source = `\\href{javascript:alert(1)}{${knownAtom(1)}}`; expectedStatus = 'policy-visible-command'; }
      else if (mode === 4) source = `\\text{${pick(['é', '漢', '😀', '𝛼'])}}`;
      else source = `\\color{${pick(['red', 'blue'])}}{\\widehat{${knownAtom(1)}}}`;
    }
  }
  const result = { id: `fuzz-${String(index).padStart(5, '0')}`, family, source, displayMode: (random() & 1) === 1, expectedStatus, expectedError, expectedGlyphs };
  assert(Buffer.byteLength(source, 'utf8') <= MAX_SOURCE_BYTES, `${result.id}: source exceeds ${MAX_SOURCE_BYTES} bytes`);
  return result;
}
function writeEvidence(suffix, content, basePath = reportPath) {
  const base = basePath || path.resolve(`check-math-fuzz-${SEED.toString(16)}.json`), target = `${base}.${suffix}`;
  fs.mkdirSync(path.dirname(target), { recursive: true }); fs.writeFileSync(target, content); return target;
}
function finiteTree(value, label) {
  if (typeof value === 'number') assert(Number.isFinite(value), `${label}: non-finite number`);
  else if (Array.isArray(value)) value.forEach((x, i) => finiteTree(x, `${label}[${i}]`));
  else if (value && typeof value === 'object') for (const [key, child] of Object.entries(value)) finiteTree(child, `${label}.${key}`);
}
function validateRow(row, request, batchNo) {
  const label = `${batchNo}/${request.id}`;
  assert(row.schema === schema && row.engine === 'native', `${label}: schema/engine mismatch`);
  assert(row.id === request.id && row.source === request.source && row.displayMode === request.displayMode, `${label}: id/source/display mismatch`);
  assert(['ok', 'parse-error', 'layout-error', 'policy-visible-command'].includes(row.status), `${label}: unexpected status ${row.status}`);
  if (request.expectedStatus) assert(row.status === request.expectedStatus, `${label}: expected ${request.expectedStatus}, got ${row.status}: ${row.error?.message || ''}`);
  if (request.expectedError) assert(row.error?.message === request.expectedError, `${label}: expected diagnostic ${JSON.stringify(request.expectedError)}, got ${JSON.stringify(row.error?.message)}`);
  if (row.status === 'parse-error' || row.status === 'layout-error') {
    assert(row.error && typeof row.error.message === 'string' && row.error.message.length > 0, `${label}: rejection missing diagnostic`);
    assert(!row.box && !Array.isArray(row.commands), `${label}: rejection contains geometry`);
  } else {
    assert(row.box && Array.isArray(row.commands), `${label}: success missing box/commands`); finiteTree(row.box, `${label}.box`);
    for (const field of ['width', 'ascent', 'descent']) assert(Number.isFinite(row.box[field]) && row.box[field] >= 0 && row.box[field] <= MAX_GEOMETRY, `${label}: invalid/out-of-bounds ${field}`);
    assert(row.commands.length <= MAX_COMMANDS, `${label}: command count exceeds ${MAX_COMMANDS}`);
    for (const [i, command] of row.commands.entries()) {
      const tag = `${label}.commands[${i}]`;
      finiteTree(command, tag);
      assert(['glyph', 'rule', 'path', 'text-run'].includes(command.kind), `${tag}: invalid command kind ${command.kind}`);
      assert(Number.isFinite(command.x) && Math.abs(command.x) <= MAX_GEOMETRY && Number.isFinite(command.y) && Math.abs(command.y) <= MAX_GEOMETRY, `${tag}: invalid/out-of-bounds position`);
      assert(Number.isFinite(command.scale) && command.scale > 0 && command.scale <= MAX_GEOMETRY, `${tag}: invalid/out-of-bounds scale`);
      for (const field of ['width', 'height']) assert(Number.isFinite(command[field]) && command[field] >= 0 && command[field] <= MAX_GEOMETRY, `${tag}: invalid/out-of-bounds ${field}`);
      if (command.hasClip) for (const field of ['clipX', 'clipY', 'clipW', 'clipH']) assert(Number.isFinite(command[field]), `${tag}: missing/non-finite clip ${field}`);
      if (command.hasShadow) for (const field of ['shadowX', 'shadowY', 'shadowBlurPx']) assert(Number.isFinite(command[field]), `${tag}: missing/non-finite shadow ${field}`);
      if (command.kind === 'glyph') assert(Number.isInteger(command.codePoint) && command.codePoint > 0 && command.codePoint <= 0x10ffff, `${tag}: invalid glyph code point`);
      if (command.kind === 'text-run') assert(typeof command.text === 'string', `${tag}: text-run missing text`);
      if (command.kind === 'path') assert(Array.isArray(command.segments) && command.segments.length > 0, `${tag}: empty path`);
    }
    if (row.status === 'policy-visible-command') assert(row.policy?.refusal === true && /refused untrusted command:/.test(row.policy.diagnostic || '') && row.commands.length > 0, `${label}: policy refusal invariant failed`);
  }
  if (Object.hasOwn(request, 'expectedGlyphs') && request.expectedGlyphs !== null) assert(JSON.stringify(glyphs(row)) === JSON.stringify(request.expectedGlyphs), `${label}: expected glyphs ${request.expectedGlyphs}, got ${glyphs(row)}`);
  if (request.sequence) assert(row.macroStateComplete === true && row.macroState && typeof row.macroState === 'object', `${label}: incomplete shared macro snapshot`);
  return row;
}
function glyphs(row) { return row.commands.filter(c => c.kind === 'glyph').map(c => c.codePoint); }
function setupFor(test) {
  return [
    { id: `${test.id}-setup`, source: '\\gdef\\fuzzsentinel{z}', displayMode: false, sequence: test.id, role: 'setup', expectedStatus: 'ok' },
    { ...test, source: `\\def\\fuzzlocal{x}${test.source}`, sequence: test.id, role: 'primary' },
    { id: `${test.id}-sentinel-recovery`, source: '\\fuzzsentinel', displayMode: false, sequence: test.id, role: 'sentinel-recovery', expectedStatus: 'ok', expectedGlyphs: [0x7a], checkSentinel: true },
    { id: `${test.id}-ordinary-recovery`, source: 'x+\\alpha', displayMode: false, sequence: test.id, role: 'ordinary-recovery', expectedStatus: 'ok', expectedGlyphs: [0x78, 0x2b, 0x3b1], checkOrdinary: true },
  ];
}
function checkRecovery(row, request) {
  assert(JSON.stringify(glyphs(row)) === JSON.stringify(request.expectedGlyphs), `${request.id}: exact recovery glyph sequence mismatch`);
  if (request.checkSentinel) {
    assert(Object.hasOwn(row.macroState, '\\fuzzsentinel'), `${request.id}: setup macro absent from state`);
    assert(row.macroState['\\fuzzsentinel'].tokens.map(t => t.text).join('') === 'z', `${request.id}: sentinel body is not exactly z`);
  }
}
function runBatch(units, batchNo, deadline, options = {}) {
  const exe = options.executable || executable, evidenceBase = options.reportPath || reportPath;
  const timeoutMs = options.timeoutMs === undefined ? TIMEOUT_MS : options.timeoutMs;
  const maxBuffer = options.maxBuffer === undefined ? 32 * 1024 * 1024 : options.maxBuffer;
  assert(Number.isInteger(timeoutMs) && timeoutMs > 0 && timeoutMs <= TIMEOUT_MS, 'test timeout override must be in (0, TIMEOUT_MS]');
  assert(Number.isInteger(maxBuffer) && maxBuffer > 0 && maxBuffer <= 32 * 1024 * 1024, 'test maxBuffer override must be in (0, 32 MiB]');
  const requests = units.flatMap(setupFor), input = requests.map(c => JSON.stringify({ id: c.id, source: c.source, displayMode: c.displayMode, sequence: c.sequence }) + '\n').join('');
  const remaining = deadline - Date.now(); assert(remaining > 0, `overall timeout before batch ${batchNo}`);
  const child = spawnSync(exe, [], { input, encoding: 'utf8', timeout: Math.min(timeoutMs, remaining), maxBuffer });
  if (child.error || child.status !== 0) {
    const info = { batch: batchNo, firstCase: units[0].id, lastCase: units[units.length - 1].id, requests: requests.map(r => ({ id: r.id, role: r.role, source: r.source })), reason: child.error ? `${child.error.code || child.error.message}` : `exit ${child.status}, signal ${child.signal}`, stderr: String(child.stderr || '').slice(0, 8192), stdout: String(child.stdout || '').slice(0, 8192), timeoutMs: Math.min(timeoutMs, remaining), maxBuffer };
    const inputPath = writeEvidence(`failure-batch-${batchNo}.input.jsonl`, input, evidenceBase);
    const outputPath = writeEvidence(`failure-batch-${batchNo}.partial.stdout`, String(child.stdout || ''), evidenceBase);
    const stderrPath = writeEvidence(`failure-batch-${batchNo}.stderr`, String(child.stderr || ''), evidenceBase);
    const failurePath = writeEvidence(`failure-batch-${batchNo}.failure.json`, JSON.stringify({ ...info, inputPath, outputPath, stderrPath }, null, 2) + '\n', evidenceBase);
    throw new Error(`batch ${batchNo} ${child.error?.code === 'ETIMEDOUT' ? 'TIMEOUT' : 'CRASH'}; evidence=${failurePath}; ${info.reason}; stderr=${info.stderr}`);
  }
  const lines = child.stdout.split('\n').filter(Boolean);
  try {
    assert(lines.length === requests.length, `batch ${batchNo}: expected ${requests.length} rows, got ${lines.length}`);
    const rows = lines.map((line, index) => {
      let row; try { row = JSON.parse(line); } catch (error) { throw new Error(`row ${index}: invalid JSON: ${error.message}`); }
      const request = requests[index]; validateRow(row, request, batchNo);
      if (request.role === 'setup') {
        assert(row.macroState['\\fuzzsentinel'], `${request.id}: setup macro definitions absent`);
        assert(row.macroState['\\fuzzsentinel'].tokens.map(t => t.text).join('') === 'z', `${request.id}: sentinel body is not exactly z`);
      }
      if (request.role === 'primary') assert(!Object.hasOwn(row.macroState, '\\fuzzlocal'), `${request.id}: local macro leaked into primary snapshot`);
      if (request.role === 'sentinel-recovery' || request.role === 'ordinary-recovery') {
        checkRecovery(row, request);
        assert(!Object.hasOwn(row.macroState, '\\fuzzlocal'), `${request.id}: local macro leaked into recovery snapshot`);
      }
      return row;
    });
    return rows;
  } catch (error) {
    const inputPath = writeEvidence(`failure-batch-${batchNo}.input.jsonl`, input, evidenceBase), outputPath = writeEvidence(`failure-batch-${batchNo}.output.jsonl`, child.stdout, evidenceBase);
    const failurePath = writeEvidence(`failure-batch-${batchNo}.failure.json`, JSON.stringify({ batch: batchNo, firstCase: units[0].id, lastCase: units[units.length - 1].id, message: error.message, inputPath, outputPath, stderr: String(child.stderr || '').slice(0, 8192) }, null, 2) + '\n', evidenceBase);
    throw new Error(`${error.message}; evidence=${failurePath}`);
  }
}
function generateCases() { return Array.from({ length: CASES }, (_, i) => makeCase(i)); }
function main() {
  const started = Date.now(), cases = generateCases();
  const distinctSources = new Set(cases.map(c => c.source)).size;
  assert(distinctSources > CASES / 2, `generated corpus variety too low: ${distinctSources}`);
  const corpus = cases.map(c => JSON.stringify(c)).join('\n') + '\n';
  const corpusSha256 = crypto.createHash('sha256').update(corpus).digest('hex');
  const corpusPath = writeEvidence('cases.jsonl', corpus), deadline = started + OVERALL_TIMEOUT_MS;
  assert(fs.existsSync(executable), `native exporter not found: ${executable}; corpus=${corpusPath}`);
  let previousPassHash = null; const passes = [];
  for (let pass = 1; pass <= 2; pass++) {
    const counts = { primary: Object.fromEntries(families.map(f => [f, { cases: 0, statuses: {}, diagnosticCategories: {} }])), controls: { setup: 0, sentinelRecovery: 0, ordinaryRecovery: 0 }, statuses: { ok: 0, 'parse-error': 0, 'layout-error': 0, 'policy-visible-command': 0 } };
    const hash = crypto.createHash('sha256'); let batchNo = 0;
    for (let start = 0; start < cases.length; start += BATCH_UNITS) {
      const units = cases.slice(start, start + BATCH_UNITS), rows = runBatch(units, `p${pass}-${batchNo}`, deadline);
      for (let j = 0; j < units.length; j++) {
        const group = rows.slice(j * 4, j * 4 + 4), primary = group[1], metric = counts.primary[units[j].family];
        metric.cases++; metric.statuses[primary.status] = (metric.statuses[primary.status] || 0) + 1;
        if (primary.error?.message) { const category = primary.error.message.split(/[\s:]/).filter(Boolean)[0].slice(0, 64) || 'unspecified'; metric.diagnosticCategories[category] = (metric.diagnosticCategories[category] || 0) + 1; }
        counts.statuses[primary.status]++;
        counts.controls.setup++; counts.controls.sentinelRecovery++; counts.controls.ordinaryRecovery++;
        for (const row of group) hash.update(JSON.stringify(row)).update('\n');
      }
      batchNo++;
    }
    const outputSha256 = hash.digest('hex');
    if (previousPassHash !== null && outputSha256 !== previousPassHash) {
      const mismatchPath = writeEvidence('failure-output-hash.failure.json', JSON.stringify({ seed: `0x${SEED.toString(16)}`, corpusSha256, firstPassSha256: previousPassHash, secondPassSha256: outputSha256, pass, message: 'full corpus output differs between repeat runs' }, null, 2) + '\n');
      throw new Error(`full corpus output differs: pass1=${previousPassHash} pass2=${outputSha256}; evidence=${mismatchPath}`);
    }
    previousPassHash = outputSha256; passes.push({ pass, batchCount: batchNo, outputSha256, counts });
  }
  const report = {
    harness: 'check-math-fuzz.cjs', executable, seed: `0x${SEED.toString(16)}`, primaryCases: CASES,
    strata: Object.fromEntries(families.map(f => [f, PER_FAMILY])), distinctSources, canonicalCorpusSha256: corpusSha256, persistedCorpus: corpusPath,
    requestsPerPrimary: 4, primaryRequestsPerPass: CASES, controlRequestsPerPass: CASES * 3,
    batchesPerPass: Math.ceil(CASES / BATCH_UNITS), unitsPerBatch: BATCH_UNITS, maxBatchTimeoutMs: TIMEOUT_MS, overallCooperativeTimeoutMs: OVERALL_TIMEOUT_MS,
    maxSourceBytesInclusive: MAX_SOURCE_BYTES,
    validation: 'status class; exact status and selected diagnostic for stable limit fixtures; rejection diagnostic and empty geometry; non-negative bounded box/command dimensions and positive scale; finite coordinates without bounding SVG path coordinates; policy refusal; request identity; exact shared macro state and glyph recovery; full-output repeat hash',
    geometryValidationScope: 'Bounds box width/ascent/descent, command positions, positive scale, and non-negative width/height; path segment coordinates are checked for finiteness but not capped because valid paths may retain source-coordinate scale. Clip/shadow fields are checked for finiteness when present; no unsupported unit-bound claim is made.',
    stateModel: 'each primary starts with a local fuzzlocal definition and shares a unique sequence with setup and controls; primary and both recoveries assert the local definition is absent; setup sentinel is exact z; recovery glyph streams are exact; four-request units are never split between process batches',
    coverageLimits: 'Unicode coverage is a narrow invariant probe, not a full grammar oracle. Macro cycles and nested duplication have explicit EXPANSION_LIMIT expectations. Uncertain subsets assert structural/status invariants, not fabricated semantics.',
    memory: 'No job memory/RSS measurement; source and bounded geometry fields are validation bounds, not whole-job resource qualification.', passes, elapsedMs: Date.now() - started,
  };
  if (reportPath) { fs.mkdirSync(path.dirname(reportPath), { recursive: true }); fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n'); }
  process.stdout.write(JSON.stringify(report, null, 2) + '\n');
}
if (require.main === module) {
  try { main(); } catch (error) { process.stderr.write(`${error.stack || error.message}\n`); process.exitCode = 1; }
}
module.exports = { alphaName, makeCase, setupFor, validateRow, checkRecovery, runBatch, generateCases, main, glyphs, rng, families };
