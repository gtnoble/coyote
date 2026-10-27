'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync, spawnSync} = require('node:child_process');

const repo = path.resolve(__dirname, '../..');
const archive = path.resolve(process.argv[2] || '/tmp/coyote-katex-support-check/katex.tgz');
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'coyote-math-inventory-'));
const generator = path.join(repo, 'tools/inventory_katex.cjs');
function run(pkg, tarball, stem) {
  return spawnSync(process.execPath, [generator, pkg, tarball, `${stem}.json`, `${stem}.md`], {encoding: 'utf8'});
}
function copyPackage(target) {
  fs.mkdirSync(target, {recursive: true});
  execFileSync('tar', ['-xzf', archive, '-C', target, '--strip-components=1', 'package']);
  return target;
}
function rejected(pkg, tarball, label) {
  const result = run(pkg, tarball, path.join(temp, label));
  assert.notEqual(result.status, 0, `${label} should be rejected`);
}
try {
  const pkg = copyPackage(path.join(temp, 'package'));
  const first = run(pkg, archive, path.join(temp, 'first'));
  assert.equal(first.status, 0, first.stderr);
  const second = run(pkg, archive, path.join(temp, 'second'));
  assert.equal(second.status, 0, second.stderr);
  assert.deepEqual(fs.readFileSync(path.join(temp, 'first.json')), fs.readFileSync(path.join(temp, 'second.json')));
  assert.deepEqual(fs.readFileSync(path.join(temp, 'first.md')), fs.readFileSync(path.join(temp, 'second.md')));
  const inventory = JSON.parse(fs.readFileSync(path.join(temp, 'first.json'), 'utf8'));
  assert.deepEqual(inventory.counts, {functions:309, environments:33, symbols:2236, mathSymbols:1487, textSymbols:749, settings:14, builtinMacros:338});
  assert.deepEqual(inventory.registries.effectiveSettings.maxSize, {'$number':'Infinity'});
  assert.equal(inventory.registries.effectiveSettings.maxExpand, 1000);
  assert(Object.values(inventory.registries.runtimeTables.unicodeSymbols).some(value => /[α∞≤]/u.test(JSON.stringify(value))), 'Unicode runtime tables retained');
  assert.equal(inventory.provenance.npmArchiveSha256, 'e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365');

  const badArchive = path.join(temp, 'bad.tgz');
  fs.copyFileSync(archive, badArchive);
  fs.appendFileSync(badArchive, 'tamper');
  rejected(pkg, badArchive, 'bad-archive');

  for (const [label, relative, contents] of [
    ['wrong-version', 'package.json', fs.readFileSync(path.join(pkg, 'package.json'), 'utf8').replace('0.16.22', '0.16.21')],
    ['mutated-bundle', 'dist/katex.js', fs.readFileSync(path.join(pkg, 'dist/katex.js'), 'utf8') + '\n'],
    ['mutated-src', 'src/Parser.js', 'mutated'],
    ['mutated-font', 'dist/fonts/KaTeX_Main-Regular.woff2', 'mutated'],
    ['mutated-contrib', 'contrib/auto-render/auto-render.js', 'mutated'],
  ]) {
    const candidate = copyPackage(path.join(temp, `${label}-package`));
    const target = path.join(candidate, relative);
    fs.writeFileSync(target, contents);
    rejected(candidate, archive, label);
  }
  const extra = copyPackage(path.join(temp, 'extra-package'));
  fs.writeFileSync(path.join(extra, 'src/extra.js'), 'extra');
  rejected(extra, archive, 'extra-file');
  console.log('Math inventory provenance checks passed: deterministic artifacts, registry counts, Infinity marker, Unicode, and 7 rejection cases.');
} finally {
  fs.rmSync(temp, {recursive: true, force: true});
}
