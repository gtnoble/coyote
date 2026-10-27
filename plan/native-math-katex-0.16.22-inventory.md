# KaTeX 0.16.22 native-math inventory

Generated from the pinned npm distribution listed in [PROVENANCE.md](../share/coyote/math/PROVENANCE.md). Archive SHA-256: `e9e0d167db3175481cbadaff38e8d90b130f6a3ddb451a47e43c577fd511f365` (verified); `dist/katex.js` SHA-256: `8f1f4fb1080439c012bb8fddf424fa253e9144ab4cdd7dc0eae0e92cd04a5e33` (verified). Package name/version and every listed package.json, dist bundle, src JavaScript, contrib JavaScript, and font-file byte sequence are checked against archive entries; missing or extra relevant files are rejected.

Full regeneration command (from the repository root; package root must be an extraction of the same archive): `node tools/inventory_katex.cjs /tmp/coyote-katex-support-check/package /tmp/coyote-katex-support-check/katex.tgz plan/native-math-katex-0.16.22-inventory.json plan/native-math-katex-0.16.22-inventory.md`. The archive is checked before use; tar is invoked without a shell. The bundle registries are instrumented in a Node VM with exact guarded anchors; reference files are not modified.

## Registry counts

| Registry | Entries |
|---|---:|
| Functions | 309 |
| Environments | 33 |
| Mode-specific symbol keys | 2236 (1487 math, 749 text) |
| Settings schema / effective default object | 14 / 14 |
| Built-in macros | 338 |
| Source JavaScript modules (all src) | 88 |
| Contrib JavaScript files | 9 |
| Font files / distinct face stems | 60 / 20 |

The inventory records schema metadata and the actual `new Settings({})` effective defaults. Function-valued options and callable registry metadata are markers. Function-valued macro bodies are not retained as JSON; their exact semantics are evidenced by the pinned dist hash and hashes for every source JavaScript module. Runtime tables include implicit commands, Unicode symbols/accents/subscripts and superscripts, and script data. Lexer regex source strings are recorded from guarded runtime bindings.

## Source and resource evidence

The JSON includes SHA-256 for every `src/**/*.js` module, `package.json`, and every bundled font asset; all listed bytes and the relevant-file path sets were verified against the pinned archive. Paths and hashes are inventory evidence, not a native-compatibility mapping.

## Native feature-family evidence (incomplete; not a compatibility claim)

Existing native parser/layout code has some evidence for groups, arrays, scripts/limits, and selected command families. This name-family evidence is incomplete: the KaTeX registries and resource listings have not been systematically mapped to native names or requirements. Native coverage remains **unassessed**; no missing-feature determination or coverage percentage is asserted.

## Limitations

- Registries capture KaTeX runtime registrations, not arbitrary user macro definitions or all possible inputs.
- Function-valued built-in macro bodies are represented by markers; exact implementation semantics are protected by the pinned distribution and hashed source inventory, not serialized function bodies.
- Source and contrib listings are package inventories; contrib extensions are not implied core commands.
- Font faces are grouped by face stem across TTF/WOFF/WOFF2 files; format variants are not counted as separate faces.
- Native feature-family mapping and requirement-level classification remain pending review.
