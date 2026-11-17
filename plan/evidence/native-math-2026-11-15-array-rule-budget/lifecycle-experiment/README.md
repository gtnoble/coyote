# PangoFC per-map shutdown lifecycle diagnostic

Date: 2026-11-16. Diagnostic only; no product source or repository test was
changed. The working tree already had unrelated modifications in
`src/coyote_math/math_syntax.adb`, `src/coyote_math/math_syntax.ads`, and
`test/tools/math_parser_memory_probe.adb`; they were left untouched.

## Question and result

Does an explicit `pango_fc_font_map_shutdown(map)` after unref of the layout
and context, immediately before unref of the map, remove the fixed Fontconfig
Memcheck losses?

**No.** The experiment source and unmodified-source control each execute the
same lifecycle probe against Pango 1.52.1 and Fontconfig 2.15.0. For all tested
counts (1, 10, 100), both report 6,656 bytes definitely lost in 26 blocks and
2,183 bytes indirectly lost in 102 blocks. Hashes/checksums match exactly for
corresponding workload cases. The shutdown variant therefore does not resolve
the fixed losses. Possibly-lost bytes and context counts vary between runs;
these are recorded, not normalized away. One original 10-measure run emitted
extra variable allocation losses; repeated runs exhibited the same run-to-run
variation. The fixed definite/indirect figures are stable.

No safe product fix is established. Pango's shutdown is a map-object cleanup
operation, not a process-global Fontconfig finalizer: it did not remove the
fixed losses in the isolated A/B. Calling global `FcFini` from each shaping
operation would be incorrect lifecycle ownership: it would tear down shared
process-wide Fontconfig state while the GUI, inline worker pipeline, other
Pango maps, and unrelated GTK clients may still use it. Correct global
finalization requires coordinated process shutdown after all users have
stopped, not a per-call `With_Layout` cleanup. This experiment does not justify
claiming the residual losses harmless.

## Experiment design

- Probe: exact byte copy of `test/tools/math_shaping_lifecycle_probe.adb`.
- All Ada dependencies: copied exactly from `src/coyote_math/` into `source/`.
- Control `math_text_shaping.adb`: exact copy of product source at experiment
  time, SHA-256 `a6d40f7d275fe747c163a2b27cd1777ed47ccfd5c1601d24cca080aa716f5e3a`.
- Variant: that same source with only the import for
  `pango_fc_font_map_shutdown` and a call immediately after layout/context
  unrefs and before map unref. Variant SHA-256
  `ae5f249d7c28e4a9a2d0f797a5d93fe78447d71dd1e9af73fd3bc728308aa60e`.
  Variant retained as `source/math_text_shaping_fc_shutdown.adb`; the runnable
  variant copy in `/tmp/math-shaping-fc-shutdown/source/math_text_shaping.adb`.
- Probe SHA-256 (repository and copy):
  `d57e1e03f73042fec776980623e2443e9152f66ae739878f535bf1489a971d19`.
- Variant GPR in this evidence folder. Its copy in `/tmp` points to the copied
  source and uses a separate object/executable root. The experiment-only
  linker addition is `-lpangoft2-1.0`, required because the imported shutdown
  symbol is defined by `libpangoft2` and otherwise fails to link (DSO missing
  from command line). No repository GPR was edited.
- Workload: the probe's same `measure` and `draw` modes at 1, 10, and 100
  iterations. Each mode/count is a separate process. No global teardown and
  no leak suppressions. This isolates the per-map shutdown question; it is not
  a product test or suite run.

## Commands

Run from the repository root. Alire supplies GtkAda/GNAT project paths and the
Alire GNAT toolchain. The variant build was:

```sh
MATH_SHAPING_LIFECYCLE_ROOT=/tmp/math-shaping-fc-shutdown/build \
  alr exec -- gprbuild -p \
  -P /tmp/math-shaping-fc-shutdown/math_shaping_lifecycle.gpr
```

The control build used the same command with `/tmp/math-shaping-fc-original`
in both root and GPR paths. For each `mode` in `measure draw` and each
`count` in `1 10 100`, the command was:

```sh
valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all \
  --track-origins=yes --num-callers=40 --error-exitcode=99 \
  /tmp/math-shaping-fc-shutdown/build/bin/math_shaping_lifecycle_probe \
  "$count" "$mode"
```

The matched control substituted
`/tmp/math-shaping-fc-original/build/bin/math_shaping_lifecycle_probe`.
Exit 99 means strict Memcheck detected errors; each probe itself completed and
printed its lifecycle summary. Full outputs are `fcshutdown-<mode>-<count>.log`
and `original-<mode>-<count>.log`; condensed rows are in the two CSV files.
Repeated count-10 measure checks are in `recheck-*.log`.

## Results

| mode | count | control definite/indirect | shutdown definite/indirect | control contexts | shutdown contexts | metric hash |
|---|---:|---|---|---:|---:|---|
| measure | 1 | 6656/2183 bytes | 6656/2183 bytes | 2 | 3 | 4953163356658974821 |
| measure | 10 | 8448/20202 bytes* | 6656/2183 bytes | 114* | 3 | 8251416062157915787 |
| measure | 100 | 6656/2183 bytes | 6656/2183 bytes | 3 | 3 | 18238019086283923219 |
| draw | 1 | 6656/2183 bytes | 6656/2183 bytes | 2 | 3 | 4953163356658974821 |
| draw | 10 | 6656/2183 bytes | 6656/2183 bytes | 2 | 3 | 8251416062157915787 |
| draw | 100 | 6656/2183 bytes | 6656/2183 bytes | 3 | 3 | 18238019086283923219 |

* One control count-10 measurement had a transient extra loss set. Separate
  repetitions reported the persistent 6656/2183 fixed losses and varying
  possibly-lost amounts; see original count-10 logs and rechecks. Do not
  interpret row-level possibly-lost values or context counts as stable.

Shutdown-variant possibly-lost bytes: measure 378, 1082, 378; draw 378, 378,
378 for counts 1/10/100. Control values from the six initial runs are in
`original-summary.csv`. Every strict run exits 99 due to Memcheck findings;
all workload summary records are present and metric hashes match.

## Installed API / ownership evidence

Installed versions from `dpkg-query`: Pango/PangoFT2 1.52.1+ds-1build1 and
Fontconfig 2.15.0-1.1ubuntu2. The installed
`/usr/include/pango-1.0/pango/pangofc-fontmap.h` declares
`pango_fc_font_map_shutdown(PangoFcFontMap *)` as available since Pango 1.4;
there is no additional ownership or timing contract in that header. The symbol
is exported by `libpangoft2-1.0.so.0` (`nm -D` confirmed). Installed Pango
GTK-doc HTML was not present in the searched system documentation paths, so
no stronger semantic claim is inferred from prose docs.

`/usr/include/fontconfig/fontconfig.h` declares `FcConfigGetCurrent`,
`FcConfigReference`, and `FcConfigDestroy` separately; callers can take an
explicit config reference and release it. It also declares `FcInit`,
`FcInitLoadConfigAndFonts`, and `FcFini` as library-level initialization and
finalization APIs. The shaping code does not acquire a `FcConfig` reference
or own Fontconfig initialization; Pango/GTK do. Hence a per-call shaping
routine cannot safely assume authority to run process-global `FcFini`.

## Retained files

- `source/`: exact copied dependencies/probe, plus shutdown variant source.
- `math_shaping_lifecycle.gpr`: isolated variant build project.
- `build.log`, `build-original.log`: build records.
- `fcshutdown-*.log`, `original-*.log`, `recheck-*.log`: strict full-stack
  Memcheck output.
- `valgrind-summary.csv`, `original-summary.csv`: concise summaries.
