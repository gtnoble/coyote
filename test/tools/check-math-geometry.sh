#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_GEOMETRY_ROOT:-${TMPDIR:-/tmp}/coyote-math-geometry}
katex=${KATEX_PACKAGE:-/tmp/coyote-katex-support-check/package}
mkdir -p "$out"
cd "$repo"
[ -f "$katex/dist/katex.js" ] || {
    echo "KaTeX package not found: $katex" >&2
    exit 2
}
MATH_GEOMETRY_ROOT="$out" alr exec -- gprbuild -p \
    -P test/native/math_geometry.gpr > "$out/build.log" 2>&1 || {
    cat "$out/build.log" >&2
    exit 1
}
"$out/bin/math_geometry_probe" > "$out/native.txt"
KATEX_PACKAGE="$katex" node - "$out/native.txt" <<'NODE'
const fs = require('node:fs');
const katex = require(process.env.KATEX_PACKAGE + '/dist/katex.js');
const native = new Map(fs.readFileSync(process.argv[2], 'utf8').trim().split('\n')
  .map(line => { const [id, ascent, descent, width] = line.split(/\s+/); return [id, [+ascent, +descent, +width]]; }));
const legacyCases = [
  ['dot-x', '\\dot{x}', false],
  ['ddot-T-sub-a', '\\ddot{T}_a', false],
  ['heatbalance-first-term', '\\dot{Q}_{\\mathrm{in}}', false],
  ['hat-x', '\\hat{x}', false],
  ['T-sub-a', 'T_a', false],
  ['x-sub-a', 'x_a', false],
  ['dot-T-sub-a', '\\dot T_a', false],
  ['dot-group-T-sub-a', '\\dot{T_a}', false],
  ['hat-x-sup-2', '\\hat{x}^2', false],
  ['frac-sub-script', '\\frac{a}{b}_c', false],
  ['sqrt-nested-fraction', '\\sqrt{\\frac{x}{y}}', false],
  ['sqrt-abcdef', '\\sqrt{abcdef}', false],
  ['sqrt-x-plus-one', '\\sqrt{x+1}', false],
  ['widehat-abcdef', '\\widehat{abcdef}', false],
  ['overrightarrow-xy', '\\overrightarrow{xy}', false],
  ['wideaccent-pilot', '\\widehat{abcdef}+\\overrightarrow{xy}+\\sqrt{abcdef}', false],
  ['sqrt-x-squared-text', '\\sqrt{x^2}', false],
  ['frac-x-squared-text', '\\frac{x^2}{y^2}', false],
  ['sqrt-frac-squared-text', '\\sqrt{\\frac{1}{x^2}}', false],
  ['sqrt-x-squared-display', '\\sqrt{x^2}', true],
  ['frac-x-squared-display', '\\frac{x^2}{y^2}', true],
  ['sqrt-frac-squared-display', '\\sqrt{\\frac{1}{x^2}}', true],
  ['script-cascade', '\\scriptstyle{\\sqrt{\\frac{1}{x^2}}^2}', false],
  ['display-script-cascade', '\\displaystyle\\sqrt{\\frac{1}{x^2}}^2', false],
  ['fraction-xy', '\\frac{x}{y}', false],
  ['frac-default', '\\frac{a}{b}', false],
  ['tfrac-default', '\\tfrac{a}{b}', false],
  ['dfrac-text', '\\dfrac{a}{b}', false],
  ['frac-nested', '\\frac{1+\\frac{x}{y}}{z}', false],
  ['tfrac-nested', '\\tfrac{1+\\tfrac{x}{y}}{z}', false],
  ['dfrac-script', '\\scriptstyle{\\dfrac{x^2}{\\frac{1}{y}}}', false],
  ['sqrt-index', '\\sqrt[3]{x^2+1}', false],
  ['sqrt-index-fraction', '\\sqrt[\\frac{1}{2}]{\\dfrac{x}{y}}', false],
  ['display-tfrac', '\\tfrac{a+b}{c+d}', true],
  ['display-nested-dfrac', '\\dfrac{1+\\dfrac{x}{y}}{z}', true],
  ['smallmatrix-fraction', '\\begin{smallmatrix}1 & \\frac{x}{y} \\\\ a^2 & \\sqrt{b}\\end{smallmatrix}', false],
  ['dcases-radical', '\\begin{dcases} \\sqrt{x} & x \\ge 0 \\\\ \\frac{1}{x} & x < 0 \\end{dcases}', false],
];

const additions = [
  ['rule-default', '\\rule{1em}{0.1em}', false],
  ['rule-raised-positive', '\\rule[0.2em]{1em}{0.1em}', false],
  ['rule-raised-negative', '\\rule[-0.2em]{1em}{0.1em}', false],
  ['raisebox-positive', '\\raisebox{0.2em}{x}', false],
  ['raisebox-negative', '\\raisebox{-0.2em}{x}', false],
  ['hbox-inline-multatom', 'x+y', false],
  ['hbox-display-multatom', 'x+y', true],
  ['sized-tiny-half', '\\tiny{x}', false],
  ['sized-sixpt-six-tenths', '\\sixptsize{x}', false],
  ['sized-huge', '\\Huge{x}', false],
  ['sized-huge-multatom', '\\Huge x+y', false],
  ['sized-tiny-huge-nested', '\\tiny{\\Huge{x}}', false],
  ['sized-huge-tiny-nested', '\\Huge{\\tiny{x}}', false],
  ['style-textstyle-scope', '\\textstyle{\\sqrt{x^2}}', false],
  ['style-displaystyle-scope', '\\displaystyle{\\sqrt{x^2}}', false],
  ['style-scriptstyle-scope', '\\scriptstyle{\\sqrt{x^2}}', false],
  ['style-scriptscriptstyle-scope', '\\scriptscriptstyle{\\sqrt{x^2}}', false],
  ['cancel-x', '\\cancel{x}', false],
  ['bcancel-x', '\\bcancel{x}', false],
  ['xcancel-x', '\\xcancel{x}', false],
  ['sout-x', '\\sout{x}', false],
  ['smash-x', '\\smash{x}', false],
  ['smash-x-squared', '\\smash{x^2}', false],
  ['style-textstyle-multatom', '\\textstyle{x+y}', false],
  ['overbrace-x', '\\overbrace{x}', false],
  ['underbrace-x', '\\underbrace{x}', false],
  ['overbrace-x-plus-y', '\\overbrace{x+y}', false],
  ['underbrace-x-plus-y', '\\underbrace{x+y}', false],
  ['overbrace-script', '\\overbrace{x+y}^{n}', false],
  ['underbrace-script', '\\underbrace{x+y}_{n}', false],
  ['overbrace-opposite-script', '\\overbrace{x+y}_{n}', false],
  ['underbrace-opposite-script', '\\underbrace{x+y}^{n}', false],
  ['sized-big-left-paren', '\\bigl(', false],
  ['sized-big-right-paren', '\\bigr)', false],
  ['sized-big-right-bracket', '\\bigr]', false],
  ['sized-big-right-brace', '\\bigr\\}', false],
  ['sized-big-bar', '\\big|', false],
  ['sized-Big-left-paren', '\\Bigl(', false],
  ['sized-Big-right-paren', '\\Bigr)', false],
  ['sized-Big-right-bracket', '\\Bigr]', false],
  ['sized-Big-right-brace', '\\Bigr\\}', false],
  ['sized-Big-bar', '\\Big|', false],
  ['sized-bigg-left-paren', '\\biggl(', false],
  ['sized-bigg-right-paren', '\\biggr)', false],
  ['sized-bigg-right-bracket', '\\biggr]', false],
  ['sized-bigg-right-brace', '\\biggr\\}', false],
  ['sized-bigg-bar', '\\bigg|', false],
  ['sized-Bigg-left-paren', '\\Biggl(', false],
  ['sized-Bigg-right-paren', '\\Biggr)', false],
  ['sized-Bigg-right-bracket', '\\Biggr]', false],
  ['sized-Bigg-right-brace', '\\Biggr\\}', false],
  ['sized-Bigg-bar', '\\Bigg|', false],
];
const arrowCases = [
  ['label-xrightarrow-text', '\\xrightarrow[b]{a}', false],
  ['label-xleftarrow-display', '\\xleftarrow[b]{a}', true],
  ['label-Overrightarrow-text', '\\Overrightarrow[b]{a}', false],
  ['label-xRightarrow-display', '\\xRightarrow[b]{a}', true],
  ['label-xLeftarrow-text', '\\xLeftarrow[b]{a}', false],
  ['label-overleftharpoon-display', '\\overleftharpoon[b]{a}', true],
  ['label-xleftharpoonup-text', '\\xleftharpoonup[b]{a}', false],
  ['label-xleftharpoondown-display', '\\xleftharpoondown[b]{a}', true],
  ['label-overrightharpoon-text', '\\overrightharpoon[b]{a}', false],
  ['label-xrightharpoonup-display', '\\xrightharpoonup[b]{a}', true],
  ['label-xrightharpoondown-text', '\\xrightharpoondown[b]{a}', false],
  ['label-xlongequal-display', '\\xlongequal[b]{a}', true],
  ['label-xtwoheadleftarrow-text', '\\xtwoheadleftarrow[b]{a}', false],
  ['label-xtwoheadrightarrow-display', '\\xtwoheadrightarrow[b]{a}', true],
  ['label-xleftrightarrow-text', '\\xleftrightarrow[b]{a}', false],
  ['label-xLeftrightarrow-display', '\\xLeftrightarrow[b]{a}', true],
  ['label-xrightleftharpoons-text', '\\xrightleftharpoons[b]{a}', false],
  ['label-xleftrightharpoons-display', '\\xleftrightharpoons[b]{a}', true],
  ['label-xhookleftarrow-text', '\\xhookleftarrow[b]{a}', false],
  ['label-xhookrightarrow-display', '\\xhookrightarrow[b]{a}', true],
  ['label-xmapsto-text', '\\xmapsto[b]{a}', false],
  ['label-xtofrom-display', '\\xtofrom[b]{a}', true],
  ['accent-overrightarrow-text', '\\overrightarrow{abcdef}', false],
  ['accent-underleftarrow-display', '\\underleftarrow{abcdef}', true],
];
const featureCases = [
  ['widecheck-one', '\\widecheck{x}', false],
  ['widecheck-two', '\\widecheck{xy}', false],
  ['widecheck-three', '\\widecheck{xyz}', false],
  ['widecheck-four', '\\widecheck{wxyz}', false],
  ['widecheck-five', '\\widecheck{vwxyz}', false],
  ['widecheck-six', '\\widecheck{uvwxyz}', false],
  ['widecheck-long', '\\widecheck{abcdefg}', false],
  ['utilde-one', '\\utilde{x}', false],
  ['utilde-two', '\\utilde{xy}', false],
  ['utilde-three', '\\utilde{xyz}', false],
  ['utilde-four', '\\utilde{wxyz}', false],
  ['utilde-five', '\\utilde{vwxyz}', false],
  ['utilde-six', '\\utilde{uvwxyz}', false],
  ['phase-one', '\\phase{x}', false],
  ['phase-fraction', '\\phase{\\frac{x}{y}}', false],
  ['angl-one', '\\angl{x}', false],
  ['angl-group', '\\angl{xy}', false],
];
const contourCases = [
  ['contour-oiint-text', '\\oiint', false],
  ['contour-oiint-display', '\\oiint', true],
  ['contour-oiiint-text', '\\oiiint', false],
  ['contour-oiiint-display', '\\oiiint', true],
  ['contour-raw-oiint-text', '∯', false],
  ['contour-raw-oiint-display', '∯', true],
  ['contour-raw-oiiint-text', '∰', false],
  ['contour-raw-oiiint-display', '∰', true],
];
const spacingCases = [
  ['spacing-medspace-colon', 'a\\:b', false],
  ['spacing-medspace-greater', 'a\\>b', false],
  ['break-allow', 'a\\allowbreak b', false],
  ['break-forbid', 'a\\nobreak b', false],
];
const mathChoiceCases = [
  ['mathchoice-text', '\\mathchoice{a}{\\sqrt{x}}{x^2}{\\sum}', false],
  ['mathchoice-display', '\\mathchoice{a}{\\sqrt{x}}{x^2}{\\sum}', true],
  ['mathchoice-script', '\\scriptstyle{\\mathchoice{a}{\\sqrt{x}}{x^2}{\\sum}}', false],
  ['mathchoice-scriptscript', '\\scriptscriptstyle{\\mathchoice{a}{\\sqrt{x}}{x^2}{\\sum}}', false],
  ['mathchoice-text-cramped', '\\sqrt{\\mathchoice{a}{\\sqrt{x}}{x^2}{\\sum}}', false],
  ['mathchoice-display-cramped', '\\sqrt{\\mathchoice{a}{\\sqrt{x}}{x^2}{\\sum}}', true],
  ['mathchoice-script-cramped', '\\scriptstyle{\\sqrt{\\mathchoice{a}{\\sqrt{x}}{x^2}{\\sum}}}', false],
  ['mathchoice-scriptscript-cramped', '\\scriptscriptstyle{\\sqrt{\\mathchoice{a}{\\sqrt{x}}{x^2}{\\sum}}}', false],
];
const fractionCases = [
  ['fraction-genfrac-default', '\\genfrac{}{}{}{}{a}{b}', false],
  ['fraction-genfrac-nobar-zero', '\\genfrac{}{}{0pt}{}{a}{b}', false],
  ['fraction-genfrac-custom-02', '\\genfrac{}{}{0.2pt}{}{a}{b}', false],
  ['fraction-genfrac-custom-05', '\\genfrac{}{}{0.5pt}{}{x+y}{z}', false],
  ['fraction-genfrac-delimited', '\\genfrac{(}{)}{0.2pt}{}{a}{b}', false],
  ['fraction-genfrac-left-only', '\\genfrac{[}{}{0pt}{}{a}{b}', false],
  ['fraction-genfrac-style-display', '\\genfrac{}{}{0pt}{0}{a}{b}', false],
  ['fraction-genfrac-style-text', '\\genfrac{}{}{0pt}{1}{a}{b}', false],
  ['fraction-genfrac-style-script', '\\genfrac{}{}{0pt}{2}{a}{b}', false],
  ['fraction-genfrac-style-scriptscript', '\\genfrac{}{}{0pt}{3}{a}{b}', false],
  ['fraction-genfrac-display-bar', '\\genfrac{}{}{0.2pt}{0}{x+y}{z}', false],
  ['fraction-genfrac-text-bar', '\\genfrac{}{}{0.2pt}{1}{x+y}{z}', false],
  ['fraction-genfrac-script-bar', '\\genfrac{}{}{0.2pt}{2}{x+y}{z}', false],
  ['fraction-genfrac-sscript-bar', '\\genfrac{}{}{0.2pt}{3}{x+y}{z}', false],
  ['fraction-cfrac-default', '\\cfrac{a}{b}', false],
  ['fraction-cfrac-left', '\\cfrac[l]{x+y}{z}', false],
  ['fraction-cfrac-right', '\\cfrac[r]{x+y}{z}', false],
  ['fraction-cfrac-display', '\\cfrac{\\frac{a}{b}}{c}', true],
  ['fraction-infix-over', 'a\\over b', false],
  ['fraction-infix-choose', 'a\\choose b', false],
  ['fraction-infix-atop', 'a\\atop b', false],
  ['fraction-infix-brace', 'a\\brace b', false],
  ['fraction-infix-above-zero', 'a\\above{0pt}b', false],
  ['fraction-infix-above-custom', 'a\\above{0.2pt}b', false],
  ['fraction-stack-above', '\\stackrel{n}{=}', false],
  ['fraction-stack-binary', 'a+\\stackrel{n}{=}b', false],
  ['fraction-overset-relation', 'a\\overset{n}{=}b', false],
  ['fraction-overset-binary', 'a\\overset{n}{+}b', false],
];
const delimiterCases = [
  ['delimiter-angle', '\\left\\langle x \\right\\rangle', false],
  ['delimiter-angle-raw', '\\left< x \\right>', false],
  ['delimiter-floor', '\\left\\lfloor x \\right\\rfloor', false],
  ['delimiter-ceiling', '\\left\\lceil x \\right\\rceil', false],
  ['delimiter-floor-large', '\\left\\lfloor \\frac{x}{y} \\right\\rfloor', false],
  ['delimiter-ceiling-large', '\\left\\lceil \\frac{x}{y} \\right\\rceil', false],
  ['delimiter-angle-sized', '\\bigl\\langle', false],
  ['delimiter-floor-sized', '\\bigl\\lfloor', false],
  ['delimiter-ceiling-sized', '\\bigl\\lceil', false],
  ['delimiter-doublebar', '\\left\\Vert x \\right\\Vert', false],
  ['delimiter-doublebar-sized', '\\Big\\Vert', false],
  ['delimiter-braket-macro', '\\Braket{a}{b}', false],
  ['delimiter-braket-middle', '\\left\\langle a \\middle| b \\right\\rangle', false],
  ['raw-vertical-bar', 'a|b', false],
];
const arrayRuleCases = [
  ['array-hline-top', '\\begin{array}{c}\\hline a\\end{array}', false],
  ['array-hline-interior', '\\begin{array}{c}a\\\\\\hline b\\end{array}', false],
  ['array-hdashline', '\\begin{array}{c}a\\\\\\hdashline b\\end{array}', false],
  ['array-hline-repeated-top', '\\begin{array}{c}\\hline\\hline a\\end{array}', false],
  ['array-hline-repeated-interior', '\\begin{array}{c}a\\\\\\hline\\hline b\\end{array}', false],
];
const cdCases = [
  ['cd-empty', '\\begin{CD}\\end{CD}', true],
  ['cd-empty-horizontal-label', '\\begin{CD}A@>x>>B\\end{CD}', true],
  ['cd-empty-vertical-label', '\\begin{CD}A@VVV\\\\B\\end{CD}', true],
  ['cd-two-by-two', '\\begin{CD} A @>f>> B \\\\ @VgVV @AAhA \\\\ C @>>k> D \\end{CD}', true],
  ['cd-grouped-label', '\\begin{CD}A@>{x>y}>z>B\\end{CD}', true],
  ['cd-horizontal-right', '\\begin{CD}A@>f>>B\\end{CD}', true],
  ['cd-horizontal-left', '\\begin{CD}X@<g<<Y\\end{CD}', true],
  ['cd-long-equal', '\\begin{CD}C@=D\\end{CD}', true],
  ['cd-vertical-up', '\\begin{CD}A@AfAAB\\\\C\\end{CD}', true],
  ['cd-vertical-down', '\\begin{CD}X@VgVV\\\\Y\\end{CD}', true],
  ['cd-markers', '\\begin{CD}A@|B@.C\\\\D@|E@.F\\end{CD}', true],
  ['cd-mixed', '\\begin{CD}P@>f>>Q&R@VgVV\\\\S@<h<<T&U\\end{CD}', true],
];
const callableCases = [
  ['callable-newline', '\\newline', false],
  ['callable-notag', '\\notag', false],
  ['callable-nonumber', '\\nonumber', false],
  ['callable-tag-literal', '\\tag{A}x', true],
  ['callable-approx-equal', '≘', false],
  ['callable-approx-equal-composed', 'a≘b', false],
  ['callable-not-equal', '\\ne', false],
  ['callable-not-equal-alias', '\\neq', false],
];
const supportCases = [
  ['support-vcenter-frac', '\\vcenter{\\hbox{$\\frac{a+b}{\\dfrac{c}{d}}$}}', false],
  ['support-vcenter-x', '\\vcenter{\\hbox{$x$}}', false],
  ['support-vcenter-atom', '\\vcenter{x}', false],
  ['support-pmb-x', '\\pmb{x}', false],
  ['support-pmb-relation', 'a\\pmb{\\leq}b', false],
  ['support-pmb-display', '\\pmb{x+y}', true],
  ['verb-plain', '\\verb|a b~|', false],
  ['verb-starred', '\\verb*|a b~|', false],
  ['verb-subscript', 'x_{\\verb*|a b|}', false],
  ['verb-superscript', 'x^{\\verb|a b|}', false],
  ['verb-display-style', '\\verb*|a b|', true],
  ['verb-star-space-only', '\\verb*| |', false],
  ['text-cedilla-below', '\\text{\\c{c}}', false],
  ['text-circled-full', '\\text{\\textcircled{R}}', false],
  ['colorbox-red-x', '\\colorbox{red}{x}', false],
  ['colorbox-text-space', '\\colorbox{red}{a b}', false],
  ['fcolorbox-white-a', '\\fcolorbox{blue}{#ffffff}{A}', false],
  ['fcolorbox-math-dollar', '\\fcolorbox{blue}{#ffffff}{$x^2$}', false],
];
const cases = [...legacyCases, ...featureCases, ...contourCases, ...additions, ...arrowCases, ...spacingCases, ...mathChoiceCases, ...fractionCases, ...supportCases, ...arrayRuleCases, ...cdCases, ...delimiterCases, ...callableCases];
const expectedIds = new Set(cases.map(([id]) => id));
const duplicates = cases.map(([id]) => id).filter((id, i, all) => all.indexOf(id) !== i);
const unexpected = [...native.keys()].filter(id => !expectedIds.has(id));
const missing = [...expectedIds].filter(id => !native.has(id));
let failures = 0;
if (legacyCases.length !== 37 || featureCases.length !== 17 || contourCases.length !== 8 || additions.length !== 52 || arrowCases.length !== 24 || spacingCases.length !== 4 ||
    mathChoiceCases.length !== 8 || fractionCases.length !== 28 || arrayRuleCases.length !== 5 || cdCases.length !== 12 || delimiterCases.length !== 14 || duplicates.length || native.size !== expectedIds.size ||
    unexpected.length || missing.length) {
  console.error(`ID/count mismatch: arrays=${arrayRuleCases.length}/5 legacy=${legacyCases.length}/37 additions=${additions.length}/52 arrows=${arrowCases.length}/24 mathchoice=${mathChoiceCases.length}/8 fractions=${fractionCases.length}/28 CD=${cdCases.length}/12 delimiters=${delimiterCases.length}/14 native=${native.size}/${expectedIds.size}; duplicates=${duplicates.join(',')} missing=${missing.join(',')} unexpected=${unexpected.join(',')}`);
  failures++;
}
function compare(group, rows) {
  let groupFailures = 0;
  for (const [id, source, displayMode] of rows) {
    try {
      const ref = katex.__renderToDomTree(source, {displayMode});
      const [ascent, descent] = native.get(id) || [];
      const da = ascent - ref.height, dd = descent - ref.depth;
      console.log(`${group} ${id}: KaTeX=${ref.height.toFixed(6)}/${ref.depth.toFixed(6)} native=${ascent.toFixed(6)}/${descent.toFixed(6)} delta=${da.toFixed(6)}/${dd.toFixed(6)}`);
      const [, , width] = native.get(id) || [];
      if (!Number.isFinite(da) || !Number.isFinite(dd) ||
          !Number.isFinite(width) || Math.abs(da) > 0.01 ||
          Math.abs(dd) > 0.01) groupFailures++;
    } catch (error) {
      console.log(`${group} ${id}: REFERENCE_ERROR ${error.message}`);
      groupFailures++;
    }
  }
  console.log(`${group} result: ${rows.length - groupFailures}/${rows.length} pass; ${groupFailures} fail`);
  failures += groupFailures;
}
compare('legacy', legacyCases);
compare('features', featureCases);
compare('contours', contourCases);
compare('added', additions);
compare('arrows', arrowCases);
compare('spacing', spacingCases);
compare('mathchoice', mathChoiceCases);
compare('fractions', fractionCases);
compare('vcenter-pmb', supportCases);
compare('arrays', arrayRuleCases);
compare('cd', cdCases.map(([id, source]) => [id, source, true]));
compare('delimiters', delimiterCases);
compare('callables', callableCases);
if (failures) process.exitCode = 1;
NODE
printf 'Build log: %s/build.log\nNative geometry: %s/native.txt\n' "$out" "$out"
