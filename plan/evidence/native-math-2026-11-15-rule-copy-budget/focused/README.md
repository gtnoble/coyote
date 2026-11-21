# Focused validation — 2026-11-18

Validation-only run in `/home/gtnoble/Projects/coyote/coyote-latex-math`. No production files were edited by this run. No root build or full suite was run. Each test has an independent absolute `MATH_*_ROOT` under this directory; artifacts are not shared across runs. Full console/build/probe/Valgrind logs are retained as listed below.

## Results

| Check | Status | Result |
|---|---:|---|
| Parser probe run 1 | PASS (0) | 719 checks, 0 failures; measured peak 2,443,968 bytes |
| Parser probe run 2 | PASS (0) | 719 checks, 0 failures; measured peak 2,443,968 bytes |
| Parser probe strict Valgrind | PASS (0) | 719 checks, 0 failures; 0 definitely/indirectly/possibly lost bytes; 0 Valgrind errors; 113,248 bytes still reachable |
| Worker `check-math-jobs.sh` | PASS (0) | 223 assertions, 0 failures; warm 200 cases × 10 iterations; saturation accepted 8, busy 2, requested 10, workers 2 |
| Memory ledger `check-math-memory-budget.sh` | PASS (0) | 38 checks passed |
| KaTeX geometry | PASS (0) | 235/235 across all groups: legacy 37, features 17, contours 8, added 52, arrows 24, spacing 4, mathchoice 8, fractions 28, vcenter-pmb 18, arrays 5, CD 12, delimiters 14, callables 8 |
| Raster normal checks | PASS portion | 1116 assertions, 0 functional failures |
| Strict raster Valgrind | FAIL (1), retained as failure | 2 error contexts; 6,656 bytes/26 blocks definitely lost, 2,183 bytes/102 blocks indirectly lost, 26 bytes/1 block possibly lost; 3,732,722 bytes still reachable; 0 suppressed |

Raster Valgrind reports a Pango language allocation context (26 possibly lost bytes) and a Fontconfig/Expat allocation context (8,839 bytes total: 6,656 direct + 2,183 indirect). No suppression was used. This is the expected known native dependency leak failure, not a passing strict raster result.

## Commands

All scripts were invoked from the repository root with the following absolute roots:

```sh
MATH_PARSER_MEMORY_ROOT="$PWD/plan/evidence/native-math-2026-11-15-rule-copy-budget/focused/parser-run-1/out" sh test/tools/check-math-parser-memory.sh
MATH_PARSER_MEMORY_ROOT="$PWD/plan/evidence/native-math-2026-11-15-rule-copy-budget/focused/parser-run-2/out" sh test/tools/check-math-parser-memory.sh
MATH_JOBS_ROOT="$PWD/plan/evidence/native-math-2026-11-15-rule-copy-budget/focused/jobs/out" sh test/tools/check-math-jobs.sh
MATH_MEMORY_BUDGET_ROOT="$PWD/plan/evidence/native-math-2026-11-15-rule-copy-budget/focused/ledger/out" sh test/tools/check-math-memory-budget.sh
MATH_GEOMETRY_ROOT="$PWD/plan/evidence/native-math-2026-11-15-rule-copy-budget/focused/geometry/out" sh test/tools/check-math-geometry.sh
MATH_RASTER_ROOT="$PWD/plan/evidence/native-math-2026-11-15-rule-copy-budget/focused/raster/out" sh test/tools/check-math-raster.sh

MATH_PARSER_MEMORY_ROOT="$PWD/plan/evidence/native-math-2026-11-15-rule-copy-budget/focused/parser-valgrind/out" alr exec -- gprbuild -p -P test/native/math_parser_memory.gpr
valgrind --error-exitcode=1 --leak-check=full --show-leak-kinds=all "$PWD/plan/evidence/native-math-2026-11-15-rule-copy-budget/focused/parser-valgrind/out/bin/math_parser_memory_probe"
```

The parser Valgrind build exited 0 and Valgrind exited 0. In the raster script, the build and normal probe passed; strict Valgrind exited 1 as recorded in `raster/console.log`.

## Retained evidence

- Each `*/console.log` records command and final status.
- Each `*/out/build.log` records its isolated build; parser, worker and ledger probes also retain `*/out/probe.log`.
- Geometry retains `geometry/out/native.txt` and complete reference comparisons in `geometry/console.log`.
- Parser Valgrind retains the full `parser-valgrind/valgrind.log`.
- Raster retains full normal + strict Valgrind output, including all leak records and stack traces, in `raster/console.log`.
- `provenance/mutant-source-project/` is a byte-preserving copy of `/tmp/coyote-parser-probe-mutant` (project and source files); the accompanying build and probe logs are copied separately. It is explicitly a negative control: 719 checks, 5 failures.
- `provenance/final-20261118-build/` is a byte-preserving copy of `/tmp/coyote-parser-probe-final-20261118`, with its probe/build logs and the separate console log also retained. The source tree/project was not present in that final directory; no source was inferred or substituted. Its existing console log reports 719 checks, 0 failures.

No existing historical evidence was overwritten. No binaries were removed. No commit was made.
