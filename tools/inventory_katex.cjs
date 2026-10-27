#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');

const expectedVersion = '0.16.22';
const expectedDistHash = '8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33';
const archiveHash = 'e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365';
if (process.argv.length !== 6)
  throw new Error('Usage: node tools/inventory_katex.cjs <package-root> <pinned-katex.tgz> <json-output> <markdown-output>');
const root = path.resolve(process.argv[2]);
const archive = path.resolve(process.argv[3]);
const jsonOut = path.resolve(process.argv[4]);
const mdOut = path.resolve(process.argv[5]);
const read = p => fs.readFileSync(p, 'utf8');
const sha256 = data => crypto.createHash('sha256').update(data).digest('hex');
const archiveBytes = fs.readFileSync(archive);
const actualArchiveHash = sha256(archiveBytes);
if (actualArchiveHash !== archiveHash) throw new Error(`Unexpected npm archive SHA-256 ${actualArchiveHash}`);

// tar receives an argument vector (never a shell command); member names are normalized and bounded.
const tarNames = execFileSync('tar', ['-tzf', archive], {encoding: 'utf8'}).split('\n').filter(Boolean);
const archiveMembers = new Map();
for (const raw of tarNames) {
  const name = raw.replace(/^\.\//, '');
  if (!name.startsWith('package/') || name.split('/').includes('..')) throw new Error(`Unsafe/unexpected archive member: ${raw}`);
  const relative = name.slice('package/'.length);
  if (relative) archiveMembers.set(relative, name);
}
function relevant(p) {
  return p === 'package.json' || p === 'dist/katex.js' ||
    (p.startsWith('src/') && p.endsWith('.js')) ||
    (p.startsWith('contrib/') && p.endsWith('.js')) ||
    (p.startsWith('dist/fonts/') && /\.(ttf|woff2?|otf)$/i.test(p));
}
function listRelative(dir) {
  const found = [];
  function visit(at) {
    for (const entry of fs.readdirSync(at, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(at, entry.name);
      if (entry.isDirectory()) visit(full);
      else if (entry.isFile()) found.push(path.relative(root, full).split(path.sep).join('/'));
      else throw new Error(`Unsupported package entry: ${full}`);
    }
  }
  visit(dir);
  return found;
}
function verifyFiles(paths) {
  const expected = [...archiveMembers.keys()].filter(relevant).sort();
  const actual = paths.filter(relevant).sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    const missing = expected.filter(p => !actual.includes(p));
    const extra = actual.filter(p => !expected.includes(p));
    throw new Error(`Package/archive relevant file set differs (missing: ${missing.join(', ') || 'none'}; extra: ${extra.join(', ') || 'none'})`);
  }
  for (const relative of expected) {
    const archived = execFileSync('tar', ['-xOf', archive, archiveMembers.get(relative)]);
    const local = fs.readFileSync(path.join(root, relative));
    if (!crypto.timingSafeEqual(crypto.createHash('sha256').update(local).digest(), crypto.createHash('sha256').update(archived).digest()))
      throw new Error(`Package file differs from pinned archive: ${relative}`);
  }
}
const packageFiles = listRelative(root);
verifyFiles(packageFiles);
const pkg = JSON.parse(read(path.join(root, 'package.json')));
const original = fs.readFileSync(path.join(root, 'dist/katex.js'), 'utf8');
const actualHash = sha256(original);
if (pkg.name !== 'katex' || pkg.version !== expectedVersion)
  throw new Error(`Expected katex ${expectedVersion}, got ${pkg.name} ${pkg.version}`);
if (actualHash !== expectedDistHash) throw new Error(`Unexpected dist/katex.js SHA-256 ${actualHash}`);

// Exact, unique 0.16.22 anchors fail closed if bundle internals change.
const anchors = [
  'const SETTINGS_SCHEMA = {', 'const symbols = {', 'const _functions = {};',
  'const _environments = {};', 'const _macros = {};', 'const implicitCommands = {',
  'const scriptData = [{', 'const uSubsAndSups = Object.freeze({', 'const unicodeAccents = {',
  'const unicodeSymbols = {', 'class Settings {',
  'const unicodeSubRegEx = /^[₊₋₌₍₎₀₁₂₃₄₅₆₇₈₉ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓᵦᵧᵨᵩᵪ]/;',
  'const __domTree = {', '__webpack_exports__ = __webpack_exports__["default"];',
];
for (const anchor of anchors) {
  if (original.indexOf(anchor) < 0 || original.indexOf(anchor) !== original.lastIndexOf(anchor))
    throw new Error(`Expected unique instrumentation anchor missing/changed: ${anchor}`);
}
const marker = anchors[anchors.length - 1];
const snapshot = `globalThis.__katexInventory = {version:"${expectedVersion}",settings:SETTINGS_SCHEMA,effectiveSettings:new Settings({}),Settings,implicitCommands,scriptData,uSubsAndSups,unicodeAccents,unicodeSymbols,unicodeSubRegEx,tokenRegexString,combiningDiacriticalMarkString,controlSpaceRegexString,controlWordWhitespaceRegexString,controlSymbolRegexString,symbols,functions:_functions,environments:_environments,macros:_macros};\n${marker}`;
const instrumented = original.replace(marker, snapshot);
const sandbox = {module: {exports: {}}, exports: {}, console};
sandbox.exports = sandbox.module.exports;
vm.runInNewContext(instrumented, sandbox, {filename: 'dist/katex.js (in-memory inventory instrumentation)', timeout: 30000});
const live = sandbox.__katexInventory;
if (!live || Object.keys(live.functions).length === 0 || Object.keys(live.environments).length === 0 || Object.keys(live.macros).length === 0)
  throw new Error('Instrumentation produced incomplete registry snapshot');
function clean(value) {
  if (typeof value === 'number' && !Number.isFinite(value)) return {$number: Number.isNaN(value) ? 'NaN' : value > 0 ? 'Infinity' : '-Infinity'};
  if (typeof value === 'string') return value.replace(/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/g, char => `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`);
  if (value === null || ['number', 'boolean'].includes(typeof value)) return value;
  if (Array.isArray(value)) return value.map(clean);
  if (typeof value === 'function') return '[function]';
  if (typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, clean(value[k])]));
  return String(value);
}
const assert = (condition, message) => { if (!condition) throw new Error(message); };
assert(JSON.stringify(clean([Infinity, -Infinity, NaN])) === JSON.stringify([{$number:'Infinity'}, {$number:'-Infinity'}, {$number:'NaN'}]), 'Nonfinite-number serialization self-test failed');
function sortedObject(obj) { return Object.fromEntries(Object.keys(obj).sort().map(k => [k, clean(obj[k])])); }
function listFiles(dir, predicate = () => true) {
  return listRelative(dir).filter(p => p.startsWith(path.relative(root, dir).split(path.sep).join('/') + '/') && predicate(path.basename(p))).sort();
}
const sourceFiles = listFiles(path.join(root, 'src'), name => name.endsWith('.js'));
const contrib = listFiles(path.join(root, 'contrib'), name => name.endsWith('.js')).map(p => p.slice('contrib/'.length));
const fontFiles = listFiles(path.join(root, 'dist/fonts'), name => /\.(ttf|woff2?|otf)$/i.test(name));
const sourceModules = Object.fromEntries(sourceFiles.map(p => [p, sha256(fs.readFileSync(path.join(root, p)))]));
const packageAndFontHashes = Object.fromEntries(['package.json', ...fontFiles].map(p => [p, sha256(fs.readFileSync(path.join(root, p)))]));
const fontFaces = [...new Set(fontFiles.map(p => path.basename(p).replace(/\.(ttf|woff2?|otf)$/i, '')))].sort();
const familyCounts = {};
for (const face of fontFaces) { const family = face.replace(/-(Regular|Bold|Italic|BoldItalic)$/, ''); familyCounts[family] = (familyCounts[family] || 0) + 1; }
const symbols = {};
for (const mode of Object.keys(live.symbols).sort()) symbols[mode] = sortedObject(live.symbols[mode]);
const settingsSchema = {};
for (const [name, spec] of Object.entries(live.settings).sort(([a],[b]) => a.localeCompare(b))) settingsSchema[name] = clean(spec);
const effectiveSettings = clean(live.effectiveSettings);
const counts = {functions: Object.keys(live.functions).length, environments: Object.keys(live.environments).length,
  symbols: Object.values(symbols).reduce((n, table) => n + Object.keys(table).length, 0), mathSymbols: Object.keys(symbols.math || {}).length,
  textSymbols: Object.keys(symbols.text || {}).length, settings: Object.keys(settingsSchema).length, builtinMacros: Object.keys(live.macros).length};
const expectedCounts = {functions:309, environments:33, symbols:2236, mathSymbols:1487, textSymbols:749, settings:14, builtinMacros:338};
for (const [name, expected] of Object.entries(expectedCounts)) assert(counts[name] === expected, `Unexpected ${name} count: ${counts[name]} (expected ${expected})`);
const inventory = {
  schema: 'coyote.native-math.katex-inventory.v2',
  provenance: {name: pkg.name, version: pkg.version, npmArchiveSha256: actualArchiveHash, distPath: 'dist/katex.js', distSha256: actualHash, reference: 'share/coyote/math/PROVENANCE.md', instrumentation: 'In-memory VM injection at guarded final-export anchor; archive SHA-256 verified and every inventoried source, contrib, package metadata, bundle, and font file byte-verified against the archive.'},
  registries: {functions: sortedObject(live.functions), environments: sortedObject(live.environments), symbolsByMode: symbols, settingsSchema, effectiveSettings, builtinMacros: sortedObject(live.macros),
    runtimeTables: {implicitCommands: sortedObject(live.implicitCommands), unicodeSymbols: sortedObject(live.unicodeSymbols), unicodeAccents: sortedObject(live.unicodeAccents), uSubsAndSups: sortedObject(live.uSubsAndSups), scriptData: clean(live.scriptData)},
    lexerRegexSources: {tokenRegexString: clean(live.tokenRegexString), unicodeSubRegEx: clean(live.unicodeSubRegEx.source), combiningDiacriticalMarkString: clean(live.combiningDiacriticalMarkString), controlSpaceRegexString: clean(live.controlSpaceRegexString), controlWordWhitespaceRegexString: clean(live.controlWordWhitespaceRegexString), controlSymbolRegexString: clean(live.controlSymbolRegexString)}},
  counts,
  supportingInventory: {srcFunctionFiles: sourceFiles.filter(p => p.startsWith('src/functions/')).map(p => p.slice('src/functions/'.length)), srcEnvironmentFiles: sourceFiles.filter(p => p.startsWith('src/environments/')).map(p => p.slice('src/environments/'.length)), contribJavaScriptFiles: contrib, fontFaceFiles: fontFaces, fontFileCount: fontFiles.length, fontFacesGroupedByFamily: familyCounts, packageAndFontSha256: packageAndFontHashes, sourceModuleSha256: sourceModules},
  nativeCoverage: {status: 'unassessed', note: 'No per-entry correspondence has been verified against approved requirements; the native name-family evidence is incomplete and counts are not a coverage denominator or percentage.'},
  limitations: ['Registries capture KaTeX runtime registrations, not arbitrary user macro definitions or all possible inputs.', 'Function-valued built-in macro bodies are represented by markers; exact implementation semantics are protected by the pinned distribution and hashed source inventory, not serialized function bodies.', 'Source and contrib listings are package inventories; contrib extensions are not implied core commands.', 'Font faces are grouped by face stem across TTF/WOFF/WOFF2 files; format variants are not counted as separate faces.', 'Native feature-family mapping and requirement-level classification remain pending review.'],
};
fs.mkdirSync(path.dirname(jsonOut), {recursive: true});
fs.mkdirSync(path.dirname(mdOut), {recursive: true});
fs.writeFileSync(jsonOut, JSON.stringify(inventory, null, 2) + '\n');
const md = `# KaTeX 0.16.22 native-math inventory\n\n` +
`Generated from the pinned npm distribution listed in [PROVENANCE.md](../share/coyote/math/PROVENANCE.md). Archive SHA-256: \`${actualArchiveHash}\` (verified); \`dist/katex.js\` SHA-256: \`${actualHash}\` (verified). Package name/version and every listed package.json, dist bundle, src JavaScript, contrib JavaScript, and font-file byte sequence are checked against archive entries; missing or extra relevant files are rejected.\n\n` +
`Full regeneration command (from the repository root; package root must be an extraction of the same archive): \`node tools/inventory_katex.cjs /tmp/coyote-katex-support-check/package /tmp/coyote-katex-support-check/katex.tgz plan/native-math-katex-0.16.22-inventory.json plan/native-math-katex-0.16.22-inventory.md\`. The archive is checked before use; tar is invoked without a shell. The bundle registries are instrumented in a Node VM with exact guarded anchors; reference files are not modified.\n\n` +
`## Registry counts\n\n| Registry | Entries |\n|---|---:|\n| Functions | ${counts.functions} |\n| Environments | ${counts.environments} |\n| Mode-specific symbol keys | ${counts.symbols} (${counts.mathSymbols} math, ${counts.textSymbols} text) |\n| Settings schema / effective default object | ${counts.settings} / ${Object.keys(effectiveSettings).length} |\n| Built-in macros | ${counts.builtinMacros} |\n| Source JavaScript modules (all src) | ${sourceFiles.length} |\n| Contrib JavaScript files | ${contrib.length} |\n| Font files / distinct face stems | ${fontFiles.length} / ${fontFaces.length} |\n\n` +
`The inventory records schema metadata and the actual \`new Settings({})\` effective defaults. Function-valued options and callable registry metadata are markers. Function-valued macro bodies are not retained as JSON; their exact semantics are evidenced by the pinned dist hash and hashes for every source JavaScript module. Runtime tables include implicit commands, Unicode symbols/accents/subscripts and superscripts, and script data. Lexer regex source strings are recorded from guarded runtime bindings.\n\n` +
`## Source and resource evidence\n\nThe JSON includes SHA-256 for every \`src/**/*.js\` module, \`package.json\`, and every bundled font asset; all listed bytes and the relevant-file path sets were verified against the pinned archive. Paths and hashes are inventory evidence, not a native-compatibility mapping.\n\n` +
`## Native feature-family evidence (incomplete; not a compatibility claim)\n\nExisting native parser/layout code has some evidence for groups, arrays, scripts/limits, and selected command families. This name-family evidence is incomplete: the KaTeX registries and resource listings have not been systematically mapped to native names or requirements. Native coverage remains **unassessed**; no missing-feature determination or coverage percentage is asserted.\n\n## Limitations\n\n` + inventory.limitations.map(x => `- ${x}`).join('\n') + '\n';
fs.writeFileSync(mdOut, md);
console.log(JSON.stringify({jsonOut, mdOut, counts, sourceModules: sourceFiles.length, fontAssets: fontFiles.length}));
