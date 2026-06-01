# Component Development Log — coyote_sqc

**Components:** All `Coyote_SQC.*` packages, `Coyote_Renderer.*`

**Source files:** `src/coyote_sqc/*.ads/.adb`, `src/coyote_sqc_main.adb`,
`src/coyote_renderer/*.ads/.adb`

---

## Design Rationale

### Why coyote_sqc is a separate executable

coyote_sqc reads coyote session JSONL files but does not interact with the
LLM agent runtime at all. Separating it as a standalone executable means:
- It can be run without plan9port or an acme instance.
- It cannot accidentally write to session files (the session store is not
  linked into the sqc binary).
- The GTK event loop in coyote_sqc is simpler than in the main coyote GUI:
  it has no agent task, no streaming callbacks, and no prompt queue.

### Workspace file (.sqcw) as the source of chart configuration

All user-defined configuration (date range, chart visibility, per-chart
settings, setup interval, comments) is stored in a `.sqcw` JSON file separate
from the session data. Session JSONL files are treated as read-only input.
This separation means:
- Multiple `.sqcw` files can reference the same session directory with
  different chart configurations.
- Upgrading the session format does not invalidate existing workspace files
  (the parser handles both v1 and v3).
- The user can share or version-control their `.sqcw` file independently
  of their session data.

### Control chart parameter estimation from the setup interval

All control limits (UCL, LCL, center line) are estimated from the *setup
interval* — a user-defined contiguous range of sessions. This matches
standard SPC practice: the process is assumed to be in statistical control
during the setup interval; limits computed from it are used to judge
subsequent observations. Points within the setup interval are always plotted;
only points outside it are judged against the limits.

### Box-Cox transform for I/MR charts

I charts (Individual Value charts) assume approximate normality. Many LLM
session metrics (token counts, cost) are right-skewed. The per-chart settings
dialog allows the user to select a variance-stabilising transform (log, sqrt,
Anscombe, arcsinh, Freeman-Tukey, Box-Cox). Box-Cox λ can be estimated via
MLE from the setup interval data or fixed manually. The transform is applied
to the data before computing control limits; the chart Y-axis shows
back-transformed values so the scale is interpretable.

### Shared `Coyote_Renderer` library

`Coyote_Renderer.Markup` (Pango markup generation) and
`Coyote_Renderer.Session_View` (session replay rendering) are shared between
the main coyote GUI frontend and coyote_sqc's detail panel. This avoids
duplicating the libcmark-gfm integration and the session JSONL replay logic.

---

## Key Constraints

- `Coyote_SQC.Session_Parser` must never write to session JSONL files.
  It is strictly read-only.
- All GTK operations in coyote_sqc execute on the main Ada task (the GTK main
  loop). The application is single-threaded; there is no agent task.
- The workspace file is written atomically: the new content is written to a
  `.sqcw.tmp` file and then renamed to the final `.sqcw` path. This prevents
  a partial write from corrupting the workspace.

---

## Unit Test Coverage Notes

- `Coyote_SQC.Session_Parser`: covered by AUnit tests using JSONL fixtures
  in `test/fixtures/sqc/` — v1 format, v3 format, thinking sessions,
  compaction sessions.
- `Coyote_SQC.Statistics.*`: covered by AUnit tests — c4(n) table values,
  Xbar/s/p/I/MR limit calculations.
- `Coyote_SQC.Workspace`: covered by AUnit tests — load/save round-trip,
  version migration.

---

## Open Questions / Future Work

- The Hartigan dip test implementation uses a direct O(n²) algorithm.
  For session counts > 1000 this may be slow. Consider an approximate
  version or an O(n log n) algorithm.
- Workspace version 10 (`analyzeAllDirectories`) is the current version.
  Future schema changes should increment the version and add migration logic
  in `Coyote_SQC.Workspace.Load`.
