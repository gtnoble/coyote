// Development-only oracle. Coyote and math_probe do not execute JavaScript.
// Supply an extracted KaTeX 0.16.22 dist/katex.js; no npm install is required.
const assert = require('node:assert/strict');
const path = require('node:path');
const katex = require(path.resolve(process.argv[2]));
assert.equal(katex.version, '0.16.22');
const valid = [
  'x+y=2', '  x\t+\r\ny  ', '(x+[y])', 'x^2_3', 'x_3^2',
  String.raw`\frac{a+b}{c}`, String.raw`\frac{1}{\sqrt{x+1}}`,
  String.raw`\sqrt{\frac{x}{y}}`, String.raw`\alpha+\Gamma`,
  String.raw`\infty+1`, String.raw`\times \cdot \pm \le \ge`,
  String.raw`\sum_{i=1}^n i`, String.raw`\sin(x)+\log(y)`,
  String.raw`\frac{}{}`, String.raw`\sqrt{}`, '{}', 'x^{y^z}',
  String.raw`\alpha x`, String.raw`x\,+y`,
];
const invalid = ['x+{y', 'x^a^b', 'x_a_b', String.raw`\bogus`,
  String.raw`\frac`, 'x^', 'x_}', 'x}'];
for (const source of valid) {
  assert.doesNotThrow(() => katex.renderToString(source, {throwOnError: true}));
}
for (const source of invalid) {
  assert.throws(() => katex.renderToString(source, {throwOnError: true}));
}
// Compare the font-metric and basic fraction core used by the Ada tests.
console.log(`KaTeX ${katex.version}: ${valid.length} valid and ${invalid.length} invalid reference cases passed`);
if (!process.argv[3]) {
  console.log('Reference sanity check only; supply Ada probe log for metric comparison.');
} else {
  const fs = require('node:fs');
  const records = fs.readFileSync(process.argv[3], 'utf8').split('\n')
    .filter(line => line.startsWith('REFERENCE|'));
  assert.equal(records.length, 3, 'expected three Ada layout exports');
  for (const record of records) {
    const [, source, style, ascent, descent] = record.split('|');
    const ref = katex.__renderToHTMLTree(source, {displayMode: style === 'display'});
    assert(Math.abs(Number(ascent) - ref.height) < 0.000001, `${source} ascent`);
    assert(Math.abs(Number(descent) - ref.depth) < 0.000001, `${source} descent`);
  }
  console.log('Ada/KaTeX: 3 layout cases, 6 ascent/descent comparisons passed.');
  console.log('No whole-layout, pixel, or full-dialect equivalence claimed.');
}
