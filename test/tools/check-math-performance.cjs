#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const readline = require('node:readline');

const executable = path.resolve(process.argv[2] || '/tmp/coyote-parity-qualified-export/bin/math_export');
const reportPath = process.argv[3] ? path.resolve(process.argv[3]) : null;
const CASE_COUNT = 200;
const ITERATIONS = 10;
const REQUEST_TIMEOUT_MS = 5000;
const SCHEMA = 'coyote.math-export.v1';

const expressions = [
  'x', 'a+b=c', '\\alpha+\\beta', '\\frac{a+b}{c}', 'x_{i}^{2}',
  '\\sqrt{x+y}', '\\sqrt[3]{x}', '\\sum_{i=0}^{n} i^2',
  '\\int_0^1 x\\,dx', '\\left(\\frac{x}{y}\\right)',
  '\\text{native math}', '\\mathbf{A}+\\mathit{b}',
  '\\begin{matrix}a&b\\\\c&d\\end{matrix}',
  '\\begin{array}{cc}x&y\\\\z&w\\end{array}',
  '\\hat{x}+\\overline{y}', '\\left|x\\right|',
  '\\infty+\\leq+\\times', '∑', '\\color{red}{x+y}',
];

function corpus() {
  return Array.from({ length: CASE_COUNT }, (_, index) => {
    const family = index % expressions.length;
    const repetition = 1 + Math.floor(index / expressions.length) % 4;
    const atom = expressions[family];
    const source = repetition === 1 ? atom : `\\left(${atom}\\right)^{${repetition}}`;
    return { id: `perf-${String(index).padStart(3, '0')}`, source, displayMode: index % 2 === 1 };
  });
}

function percentile(sorted, p) {
  const rank = Math.max(0, Math.ceil(p * sorted.length) - 1);
  return sorted[rank];
}

async function main() {
  assert(fs.existsSync(executable), `native exporter missing: ${executable}`);
  const cases = corpus();
  const corpusHash = crypto.createHash('sha256').update(JSON.stringify(cases)).digest('hex');
  const child = spawn(executable, [], { stdio: ['pipe', 'pipe', 'pipe'] });
  const lines = readline.createInterface({ input: child.stdout, crlfDelay: Infinity });
  let stderr = '';
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', chunk => { stderr = (stderr + chunk).slice(-4096); });
  const pending = [];
  lines.on('line', line => {
    const resolve = pending.shift();
    if (resolve) resolve(line);
    else child.kill();
  });
  child.on('error', error => { process.stderr.write(`exporter spawn failed: ${error.message}\n`); });

  function request(item, label) {
    return new Promise((resolve, reject) => {
      const start = process.hrtime.bigint();
      const timer = setTimeout(() => reject(new Error(`${label}: response timeout after ${REQUEST_TIMEOUT_MS} ms`)), REQUEST_TIMEOUT_MS);
      pending.push(line => {
        clearTimeout(timer);
        try {
          const row = JSON.parse(line);
          assert.equal(row.schema, SCHEMA, `${label}: schema`);
          assert.equal(row.engine, 'native', `${label}: engine`);
          assert.equal(row.id, item.id, `${label}: response id/order`);
          assert.equal(row.source, item.source, `${label}: echoed source`);
          assert.equal(row.displayMode, item.displayMode, `${label}: display mode`);
          assert.equal(row.status, 'ok', `${label}: unexpected status ${row.status}: ${row.error?.message || ''}`);
          resolve({ row, elapsedMs: Number(process.hrtime.bigint() - start) / 1e6 });
        } catch (error) { reject(error); }
      });
      child.stdin.write(JSON.stringify(item) + '\n', error => {
        if (error) {
          clearTimeout(timer);
          reject(new Error(`${label}: stdin write failed: ${error.message}`));
        }
      });
    });
  }

  try {
    const startupStart = process.hrtime.bigint();
    await request(cases[0], 'startup probe');
    const startupAndFirstResponseMs = Number(process.hrtime.bigint() - startupStart) / 1e6;
    for (let i = 0; i < cases.length; i++) await request(cases[i], `warm-up ${cases[i].id}`);

    const samples = [];
    for (let iteration = 0; iteration < ITERATIONS; iteration++) {
      for (const item of cases) {
        const { elapsedMs } = await request(item, `iteration ${iteration + 1} ${item.id}`);
        samples.push(elapsedMs);
      }
    }
    child.stdin.end();
    const exit = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('close', (code, signal) => resolve({ code, signal }));
    });
    assert.equal(exit.code, 0, `exporter exited ${exit.code} signal=${exit.signal}; stderr=${stderr}`);
    assert.equal(pending.length, 0, 'all responses consumed');

    const sorted = [...samples].sort((a, b) => a - b);
    const mean = samples.reduce((sum, x) => sum + x, 0) / samples.length;
    const report = {
      harness: 'check-math-performance.cjs', executable,
      processModel: 'one persistent headless native exporter; synchronous serialized newline request/response',
      corpus: { caseCount: cases.length, deterministic: true, sha256: corpusHash, families: expressions.length, status: 'all requests required ok' },
      warmUpRequests: cases.length, measuredIterations: ITERATIONS, measuredRequests: samples.length,
      timing: 'Node.js monotonic hrtime from immediately before stdin write through complete response line receipt; includes serialization, pipe/queueing, native export, and response write; excludes GUI and GTK job scheduling',
      startupAndFirstResponseMs,
      latencyMs: { min: sorted[0], median: percentile(sorted, 0.5), p95: percentile(sorted, 0.95), p99: percentile(sorted, 0.99), max: sorted.at(-1), mean },
      performanceTargetMs: { p95: 50, qualified: percentile(sorted, 0.95) <= 50 },
      memory: 'not measured',
      guiJobQueueLatency: 'not measured; this headless exporter benchmark does not qualify GUI scheduling or the 250 ms component budget',
    };
    if (reportPath) fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
    process.stdout.write(JSON.stringify(report, null, 2) + '\n');
    if (!report.performanceTargetMs.qualified) process.exitCode = 1;
  } finally {
    if (child.exitCode === null && child.signalCode === null) child.kill();
    lines.close();
  }
}

main().catch(error => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exitCode = 1;
});
