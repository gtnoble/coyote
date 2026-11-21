# Math enclosure allocation characterization — baseline

This is a `/tmp`-only characterization, not product timing, qualification, or an allocation-improvement claim.

## Baseline identity

- Repository `HEAD`: `5c74453b047b44e7522569eeef6ad8071f006a42`
- Worktree was clean before capture. No repository files were changed.
- Frozen `src/coyote_math` contains all 49 files from `HEAD`; `math_layout.adb` was byte-compared to `git show HEAD:src/coyote_math/math_layout.adb`.
- Frozen math tree SHA-256 aggregate: `6fb7856a9247b3d297f6644de4829d7bd02f496c1ba40a418f41ad9b35e2db93`
- Frozen `math_layout.adb` SHA-256: `cc65c6e2b4202f32a74837c905dd74ee94bdf1727871d9611357f74abf98d841`
- Toolchain: `alr exec` / GNAT and binder 15.2, GPRbuild 25.0.0; Valgrind 3.22.0.
- Exporter and project are frozen under `baseline-src/test`; project source directories point only to `baseline-src/coyote_math` and `baseline-src/test/tools`.
- Baseline exporter binary SHA-256 is in `manifest.sha256`.

## Corpora and captured results

`corpus/` contains fixed UTF-8 JSONL requests. Requests use `displayMode` false/true, selected `options.fleqn`, and repeated `sequence` values on heavy corpus inputs. `baseline-regression` has 52 short mixed cases; `allocation-heavy` has 72 nested cases at enclosure depths 1, 2, 4, 8, 12, and 16 around nontrivial fraction/root/stretchy/cancellation payloads; `repeat-10` repeats an identical nested request ten times. Maximum source length is 330 bytes, below the 65,536-byte request bound. All requests returned `status=ok`.

| Corpus | Records | Commands | Path commands | Path segments | Valgrind heap allocs | Heap bytes allocated |
|---|---:|---:|---:|---:|---:|---:|
| baseline-regression | 52 | 352 | 52 | 888 | 132,954 | 21,925,408 |
| allocation-heavy | 72 | 1,848 | 538 | 8,125 | 782,748 | 164,304,506 |
| repeat-10 | 10 | 200 | 40 | 600 | 79,139 | 15,082,312 |

For each corpus, normal and Valgrind JSONL outputs are byte-identical; exporter return code is zero and stderr is empty. Valgrind reported zero errors and zero definite/indirect/possible losses for these exporter runs; reachable-at-exit GNAT/runtime allocations are present (123,707 / 232,107 / 148,187 bytes respectively). These isolated exporter results do not override other known native lifecycle results.

## Repeatable final comparison

After coordinator source changes are complete, build the exporter with the same GNAT 15.2 setup and final source directories. Then run:

```sh
/tmp/coyote-enclosure-characterization/compare-allocation.py final /absolute/path/to/final/math_export
```

The script runs all fixed corpora normally and under Valgrind, requires `status=ok`, verifies output equivalence under instrumentation, and prints allocation counts/bytes and command/path workload counts. Baseline logs and JSON outputs are retained at the workspace root and in `logs/`. Compare the matching corpus rows. Repeat-10 intentionally measures **ten requests in one process**, not isolated launches.

Valgrind allocation counts/bytes are instrumented characterization, not runtime timing or exact process memory. No performance conclusion should be drawn until final-source results are measured on these same inputs/toolchain/options.
