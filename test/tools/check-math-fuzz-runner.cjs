#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const fuzz = require('./check-math-fuzz.cjs');

let checks = 0;
function check(fn) { fn(); checks++; }
function rejects(fn, pattern) {
  assert.throws(fn, pattern);
  checks++;
}
function request(overrides = {}) {
  return {
    id: 'case-1', source: 'x', displayMode: false,
    expectedStatus: null, expectedError: null, expectedGlyphs: null,
    ...overrides,
  };
}
function row(overrides = {}) {
  return {
    schema: 'coyote.math-export.v1', engine: 'native', id: 'case-1',
    source: 'x', displayMode: false, status: 'ok',
    box: { width: 1, ascent: 1, descent: 0 }, commands: [],
    macroStateComplete: true, macroState: {},
    ...overrides,
  };
}
function glyphCommand(codePoint) {
  return { kind: 'glyph', x: 0, y: 0, scale: 1, width: 1, height: 1, codePoint };
}
function validPath() {
  return { kind: 'path', x: 0, y: 0, scale: 1, width: 1, height: 1, segments: [{ x: 0, y: 0 }] };
}
function run() {
  check(() => assert.equal(fuzz.alphaName(0), 'a'));
  check(() => assert.equal(fuzz.alphaName(25), 'z'));
  check(() => assert.equal(fuzz.alphaName(26), 'aa'));

  const firstCorpus = fuzz.generateCases();
  const counts = Object.fromEntries(fuzz.families.map(name => [name, 0]));
  for (const item of firstCorpus) counts[item.family]++;
  check(() => assert.equal(firstCorpus.length, 10000));
  check(() => assert.deepEqual(Object.values(counts), Array(8).fill(1250)));
  const fuzzPath = require.resolve('./check-math-fuzz.cjs');
  delete require.cache[fuzzPath];
  const freshFuzz = require(fuzzPath);
  check(() => assert.equal(JSON.stringify(firstCorpus), JSON.stringify(freshFuzz.generateCases())));
  for (const family of ['valid-grammar', 'malformed', 'unicode', 'scripts', 'macro-expansion', 'arrays', 'dimensions', 'comments-accents-policy']) {
    check(() => assert.equal(counts[family], 1250, `${family} count`));
  }
  const macroCases = firstCorpus.filter(item => item.family === 'macro-expansion');
  check(() => assert(macroCases.some(item => item.expectedStatus === 'parse-error' && item.expectedError === 'macro expansion: EXPANSION_LIMIT' && /\\def\\fuzzm[a-z]+\{\\fuzzn/.test(item.source))));
  check(() => assert(macroCases.some(item => item.expectedStatus === 'parse-error' && item.expectedError === 'macro expansion: EXPANSION_LIMIT' && item.source.includes('\\fuzzd'))));
  check(() => assert(macroCases.filter(item => item.expectedError === 'macro expansion: EXPANSION_LIMIT').every(item => item.expectedStatus === 'parse-error')));

  const baseRequest = request();
  check(() => assert.equal(fuzz.validateRow(row(), baseRequest, 'positive').id, 'case-1'));
  rejects(() => fuzz.validateRow(row({ id: undefined }), baseRequest, 'missing-identity'), /id\/source\/display mismatch/);
  rejects(() => fuzz.validateRow(row({ status: 'mystery' }), baseRequest, 'invalid-status'), /unexpected status/);
  rejects(() => fuzz.validateRow(row({ status: 'parse-error', error: { message: 'unexpected native exception' }, box: null, commands: null, macroStateComplete: undefined, macroState: null }), request({ sequence: 'same-context', expectedStatus: 'parse-error' }), 'exception-no-snapshot'), /incomplete shared macro snapshot/);
  rejects(() => fuzz.validateRow(row(), request({ expectedStatus: 'parse-error' }), 'wrong-status'), /expected parse-error/);
  rejects(() => fuzz.validateRow(row({ status: 'parse-error', error: { message: 'other' } }), request({ expectedStatus: 'parse-error', expectedError: 'wanted' }), 'wrong-error'), /expected diagnostic/);
  rejects(() => fuzz.validateRow(row({ status: 'parse-error', error: null }), request(), 'missing-rejection-error'), /rejection missing diagnostic/);
  rejects(() => fuzz.validateRow(row({ status: 'layout-error', error: { message: 'bad geometry' }, box: { width: 1, ascent: 1, descent: 0 } }), request(), 'rejection-geometry'), /rejection contains geometry/);
  rejects(() => fuzz.validateRow(row({ box: { width: -1, ascent: 1, descent: 0 } }), baseRequest, 'negative-box'), /invalid\/out-of-bounds width/);
  rejects(() => fuzz.validateRow(row({ commands: [{ ...glyphCommand(120), scale: 0 }] }), baseRequest, 'bad-scale'), /invalid\/out-of-bounds scale/);
  check(() => assert.equal(fuzz.validateRow(row({ commands: [validPath()] }), baseRequest, 'positive-path').commands.length, 1));
  rejects(() => fuzz.validateRow(row({ commands: [{ ...validPath(), segments: [{ x: Infinity, y: 0 }] }] }), baseRequest, 'nonfinite-path'), /non-finite number/);
  rejects(() => fuzz.validateRow(row({ commands: [{ ...glyphCommand(120), kind: 'text-run' }] }), baseRequest, 'missing-text'), /text-run missing text/);
  rejects(() => fuzz.validateRow(row({ status: 'policy-visible-command', policy: { refusal: false, diagnostic: 'refused untrusted command: href' }, commands: [glyphCommand(120)] }), baseRequest, 'bad-policy'), /policy refusal invariant failed/);

  const recoveryRequest = request({ id: 'sentinel', source: '\\fuzzsentinel', expectedGlyphs: [0x7a] });
  const recovery = row({ id: 'sentinel', source: recoveryRequest.source, commands: [glyphCommand(0x7a)], macroState: { '\\fuzzsentinel': { tokens: [{ text: 'z' }] } } });
  check(() => fuzz.checkRecovery(recovery, { ...recoveryRequest, checkSentinel: true }));
  rejects(() => fuzz.checkRecovery({ ...recovery, commands: [glyphCommand(0x7a), glyphCommand(0x78)] }, { ...recoveryRequest, checkSentinel: true }), /exact recovery glyph sequence mismatch/);
  rejects(() => fuzz.checkRecovery({ ...recovery, macroState: { '\\fuzzsentinel': { tokens: [{ text: 'z' }, { text: 'x' }] } } }, { ...recoveryRequest, checkSentinel: true }), /sentinel body is not exactly z/);
  rejects(() => fuzz.checkRecovery({ ...recovery, commands: [glyphCommand(0x78)] }, { ...recoveryRequest, checkSentinel: true }), /exact recovery glyph sequence mismatch/);
  const ordinaryRequest = request({ id: 'ordinary', expectedGlyphs: [0x78, 0x2b, 0x3b1] });
  const ordinary = row({ id: 'ordinary', commands: [glyphCommand(0x78), glyphCommand(0x2b), glyphCommand(0x3b1)] });
  check(() => fuzz.checkRecovery(ordinary, ordinaryRequest));
  rejects(() => fuzz.checkRecovery({ ...ordinary, commands: [...ordinary.commands, glyphCommand(0x79)] }, ordinaryRequest), /exact recovery glyph sequence mismatch/);
  const setup = fuzz.setupFor(request({ id: 'primary', source: 'y' }));
  check(() => assert.deepEqual(setup.map(item => item.role), ['setup', 'primary', 'sentinel-recovery', 'ordinary-recovery']));

  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'math-fuzz-runner-'));
  const report = path.join(temp, 'evidence', 'batch');
  function executable(mode) {
    const file = path.join(temp, `child-${mode}.cjs`);
    const script = `#!/usr/bin/env node\n'use strict';\nconst readline=require('node:readline');\nconst mode=${JSON.stringify(mode)};\nconst lines=[];\nconst rl=readline.createInterface({input:process.stdin});\nrl.on('line',line=>lines.push(JSON.parse(line)));\nrl.on('close',()=>{\n if(mode==='crash'){process.stdout.write('partial-output');process.stderr.write('intentional-stderr');process.exit(7);}\n if(mode==='malformed'){process.stdout.write('{not-json\\n'.repeat(4));return;}\n if(mode==='truncate'){process.stdout.write('\\n');return;}\n if(mode==='hang'){setTimeout(()=>process.stdout.write('late'),5000);return;}\n if(mode==='huge'){process.stdout.write('H'.repeat(200000));return;}\n const rows=lines.map((input,index)=>{\n  const setup=input.id.endsWith('-setup');\n  const sentinel=input.id.endsWith('-sentinel-recovery');\n  const ordinary=input.id.endsWith('-ordinary-recovery');\n  const primary=input.id==='primary';\n  const state=setup||sentinel?{'\\\\fuzzsentinel':{tokens:[{text:'z'}]}}:{};\n  if(mode==='leak'&&primary)state['\\\\fuzzlocal']={tokens:[{text:'x'}]};\n  const glyphs=sentinel?[0x7a]:ordinary?[0x78,0x2b,0x3b1]:[];\n  return {schema:'coyote.math-export.v1',engine:'native',id:mode==='wrongid'&&index===0?'wrong':input.id,source:input.source,displayMode:input.displayMode,status:'ok',box:{width:1,ascent:1,descent:0},commands:glyphs.map(codePoint=>({kind:'glyph',x:0,y:0,scale:1,width:1,height:1,codePoint})),macroStateComplete:true,macroState:state};\n });\n process.stdout.write(rows.map(row=>JSON.stringify(row)).join('\\n')+'\\n');\n});\n`;
    fs.writeFileSync(file, script, { mode: 0o755 });
    return file;
  }
  const unit = [request({ id: 'primary', source: 'y' })];
  const deadline = () => Date.now() + 10000;
  const options = mode => ({ executable: executable(mode), reportPath: report, timeoutMs: 1000 });
  const successRows = fuzz.runBatch(unit, 'success', deadline(), options('success'));
  check(() => assert.equal(successRows.length, 4));
  check(() => assert.deepEqual(fuzz.glyphs(successRows[2]), [0x7a]));
  rejects(() => fuzz.runBatch(unit, 'leak', deadline(), options('leak')), /local macro leaked/);
  rejects(() => fuzz.runBatch(unit, 'wrongid', deadline(), options('wrongid')), /id\/source\/display mismatch/);
  rejects(() => fuzz.runBatch(unit, 'malformed', deadline(), options('malformed')), /invalid JSON/);
  rejects(() => fuzz.runBatch(unit, 'truncate', deadline(), options('truncate')), /expected 4 rows, got 0/);
  rejects(() => fuzz.runBatch(unit, 'crash', deadline(), options('crash')), /CRASH/);
  rejects(() => fuzz.runBatch(unit, 'hang', deadline(), { ...options('hang'), timeoutMs: 100 }), /TIMEOUT/);
  rejects(() => fuzz.runBatch(unit, 'huge', deadline(), { ...options('huge'), maxBuffer: 1024 }), /CRASH/);

  const inputPath = `${report}.failure-batch-crash.input.jsonl`;
  const outputPath = `${report}.failure-batch-crash.partial.stdout`;
  const failurePath = `${report}.failure-batch-crash.failure.json`;
  check(() => assert(fs.existsSync(inputPath) && fs.existsSync(outputPath) && fs.existsSync(failurePath)));
  const savedRequests = fs.readFileSync(inputPath, 'utf8').trim().split('\n').map(line => JSON.parse(line));
  check(() => assert.deepEqual(savedRequests.map(item => item.id), ['primary-setup', 'primary', 'primary-sentinel-recovery', 'primary-ordinary-recovery']));
  check(() => assert.equal(fs.readFileSync(outputPath, 'utf8'), 'partial-output'));
  const failure = JSON.parse(fs.readFileSync(failurePath, 'utf8'));
  check(() => assert.equal(failure.firstCase, 'primary'));
  check(() => assert.equal(failure.lastCase, 'primary'));
  check(() => assert.equal(failure.stderr, 'intentional-stderr'));
  const hugeFailure = JSON.parse(fs.readFileSync(`${report}.failure-batch-huge.failure.json`, 'utf8'));
  check(() => assert(hugeFailure.stdout.length <= 8192));
  check(() => assert.equal(fs.statSync(`${report}.failure-batch-huge.partial.stdout`).size, fs.readFileSync(`${report}.failure-batch-huge.partial.stdout`, 'utf8').length));
  check(() => assert.match(fs.readFileSync(`${report}.failure-batch-hang.failure.json`, 'utf8'), /ETIMEDOUT/));

  process.stdout.write(JSON.stringify({ result: 'PASS', checks, families: counts, evidenceDirectory: path.dirname(report) }, null, 2) + '\n');
}

try { run(); } catch (error) {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exitCode = 1;
}
