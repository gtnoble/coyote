#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const executable = path.resolve(process.argv[2] || '/tmp/coyote-math-export/bin/math_export');
const reportPath = process.argv[3] ? path.resolve(process.argv[3]) : null;
const TIME = '/usr/bin/time';
const CASE_TIMEOUT_MS = 15000;
const MAX_RSS_KIB = 256 * 1024;
const MAX_BUFFER = 16 * 1024 * 1024;
const MAX_SOURCE_BYTES = 65536;
const MAX_NODES = 32768;
const MAX_DEPTH = 128;
const MAX_ROWS = 64;
const MAX_DRAW = 131072;
const CAPTURE = 4096;

function caseFor(id, source, expected = 'ok') { return { id, source, expected }; }
function request(c) { return JSON.stringify({ id: c.id, source: c.source, displayMode: false }) + '\n'; }
function invoke(c, timeout = CASE_TIMEOUT_MS) {
  const child = spawnSync(TIME, ['-v', executable], {
    input: request(c), encoding: 'utf8', timeout,
    maxBuffer: MAX_BUFFER, env: { ...process.env, HOME: os.tmpdir(), http_proxy: '', https_proxy: '', HTTP_PROXY: '', HTTPS_PROXY: '' },
  });
  if (child.error || child.status !== 0) {
    const reason = child.error ? `${child.error.code || child.error.message}` : `exit ${child.status}, signal ${child.signal}`;
    throw new Error(`${c.id}: ${child.error && child.error.code === 'ETIMEDOUT' ? 'TIMEOUT' : 'PROCESS FAILURE'}: ${reason}; stderr=${String(child.stderr || '').slice(0, CAPTURE)}`);
  }
  const lines = child.stdout.trimEnd().split('\n');
  assert.equal(lines.length, 1, `${c.id}: expected exactly one exporter row`);
  let row;
  try { row = JSON.parse(lines[0]); } catch (e) { throw new Error(`${c.id}: invalid JSON: ${e.message}`); }
  assert.equal(row.id, c.id, `${c.id}: exporter identity`);
  assert.equal(row.source, c.source, `${c.id}: original source echoed`);
  assert.equal(row.engine, 'native', `${c.id}: native engine`);
  assert.equal(row.status, c.expected, `${c.id}: expected ${c.expected}, got ${row.status}: ${String(row.error?.message || '').slice(0, CAPTURE)}`);
  const rssMatch = String(child.stderr).match(/Maximum resident set size \(kbytes\): (\d+)/);
  const userMatch = String(child.stderr).match(/User time \(seconds\): ([0-9.]+)/);
  const systemMatch = String(child.stderr).match(/System time \(seconds\): ([0-9.]+)/);
  assert(rssMatch && userMatch && systemMatch, `${c.id}: GNU time resource record missing`);
  const resources = { maxRssKiB: Number(rssMatch[1]), userSeconds: Number(userMatch[1]), systemSeconds: Number(systemMatch[1]) };
  assert(resources.maxRssKiB < MAX_RSS_KIB, `${c.id}: exporter RSS ${resources.maxRssKiB} KiB exceeds 256 MiB headless cap`);
  if (c.id === 'source-over-limit-original-prefix')
    assert.equal(row.source.length, MAX_SOURCE_BYTES + 1, `${c.id}: original oversized source retained`);
  if (row.status === 'ok') {
    assert(row.nodes.length <= MAX_NODES, `${c.id}: node cap`);
    assert(row.commands.length <= MAX_DRAW, `${c.id}: draw cap`);
  }
  return { row, resources };
}
function main() {
  assert(fs.existsSync(executable), `native exporter missing: ${executable}`);
  const cases = [
    caseFor('base', 'x'),
    caseFor('path-resource', '\\sqrt{x}'),
    caseFor('source-limit-original-prefix', '%'.repeat(MAX_SOURCE_BYTES), 'parse-error'),
    caseFor('source-over-limit-original-prefix', '%'.repeat(MAX_SOURCE_BYTES + 1), 'parse-error'),
    caseFor('deep-group-over-limit', '{'.repeat(MAX_DEPTH + 1) + 'x' + '}'.repeat(MAX_DEPTH + 1), 'parse-error'),
    caseFor('rows-at-limit', `\\begin{matrix}${Array(MAX_ROWS).fill('x').join('\\\\')}\\end{matrix}`),
    caseFor('rows-over-limit', `\\begin{matrix}${Array(MAX_ROWS + 1).fill('x').join('\\\\')}\\end{matrix}`, 'parse-error'),
    caseFor('node-budget', 'x+'.repeat(MAX_NODES / 2), 'parse-error'),
    caseFor('draw-budget-source-bounded', 'x'.repeat(MAX_SOURCE_BYTES), 'parse-error'),
    caseFor('macro-repeat-default-expand-budget', '\\def\\a{x}\\a'.repeat(1000)),
  ];
  const results = [];
  for (const c of cases) {
    const start = Date.now();
    const { row, resources } = invoke(c);
    results.push({ id: c.id, status: row.status, elapsedMs: Date.now() - start, sourceBytes: Buffer.byteLength(c.source), ...resources });
  }
  const report = {
    harness: 'check-math-resources.cjs', executable, timeoutMsPerIsolatedProcess: CASE_TIMEOUT_MS,
    processMaxBufferBytes: MAX_BUFFER,
    maxExporterRssKiB: MAX_RSS_KIB,
    measurement: 'GNU /usr/bin/time -v around each isolated exporter process; CPU and peak RSS apply to exporter child only',
    limits: { sourceBytes: MAX_SOURCE_BYTES, nodes: MAX_NODES, depth: MAX_DEPTH, rows: MAX_ROWS, drawCommands: MAX_DRAW, macroDefaultExpand: 1000 },
    sourceBoundary: '65536 and 65537 byte inputs exercise parser boundary; original 65537-byte request source remains in response; syntax/node errors can precede source validation in this exporter',
    processModel: 'one isolated native exporter process per case; timeouts/process failures are failures, never accepted budget outcomes',
    memory: 'per-exporter RSS measured; no whole-job, API, or browser memory claim',
    results,
  };
  if (reportPath) fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
  process.stdout.write(JSON.stringify(report, null, 2) + '\n');
}
try { main(); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 1; }
