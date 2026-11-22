# Macro definition snapshot characterization

Purpose: isolated characterization of replacing per-body-token
Math_Macros.Lookup + Token_At with Token_At(Definition_Value, Index).
No repository source was edited.

Repository baseline: 1a765ce880c4818646b1da8acbb0314ef379a441
Toolchain: Alire GNAT 15.2 via `alr exec -- gprbuild`; GPRBUILD 25.0.0.
Probe: `driver/math_snapshot_probe.adb`; input is generated as repeated
\snapshot invocations. Definition is installed directly from lexed tokens
using Math_Macros.Define_Tokens; there is no `\def` source parsing. Output
serializes all token fields plus diagnostics, scope depth, definition count,
and whether the target definition remains installed.

Snapshot: 49 math source files; baseline source manifest at
`source-hashes.txt`, per-tree manifests at `baseline-source-hashes.txt` and
`variant-source-hashes.txt`. Variant differs only at the `Definition_Token`
expression in `math_expander.adb`; see `variant.diff`. The Ada driver and
project files are outside those source snapshots.

Semantic audit: `Definition_Value` is assigned before prefix and argument
processing. Both macro branches use `Read_Raw` for arguments; they do not
expand tokens or mutate the shared macro context before replacement tokens
are traversed. The cached value therefore represents the invocation-time
macro definition, as does the captured definition already used for argument
count/default/prefix/delimiter processing. This audit does not cover
out-of-band concurrent mutation of a context during `Next`.

Results:
- Exact serialized output equality for baseline/variant at body sizes 128,
  512, 2048 and 4096. Full output fields include kind, code point, source
  byte/scalar/UTF-16 spans, text span, lexeme, verbatim-star flag, invocation
  flag and invocation byte span, including EOF; state record includes the
  expansion diagnostic, scope depth and definition table state.
- Baseline and variant Memcheck were error-free at 128/512/2048 with one
  invocation; total heap allocation counts and bytes were exactly equal at
  every size. 4096 body one-invocation and 64-decoy/four-invocation runs also
  had identical counts/bytes and zero errors. Detailed stdout, timing and
  Memcheck logs are under `logs/`.
- Uninstrumented timings are noisy and show no reliable improvement at zero
  through 1024 decoy definitions. At 4096 decoys the two implementations
  remain similar (e.g. body 2048 x4: 0.78 s each; 4096 x4: 1.38 s each).
  The table-scaling setup is an artificial stress corpus. These results do
  not demonstrate a performance win or acceptance threshold.
- A 4096-body/4096-decoy Memcheck run exceeded the 120-second outer limit;
  partial baseline output/profile exists, but the pair is incomplete and is
  excluded. No whole-macro-suite Valgrind run was attempted.

Interpretation: the proposed expression change is semantically consistent
with the captured invocation-time Definition_Value and does not alter token
allocation/copy volume in this direct workload. No measurable runtime benefit
was demonstrated here. The candidate's defensible value is fewer repeated
macro-table lookups and less dependence on table growth in the inner token
loop; the direct timing results do not establish that this is material in
ordinary use. No repository edit or production recommendation is made.
