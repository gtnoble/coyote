# Faithful repeated-rescan mutation (isolated /tmp evidence)

Mutation 5 replaces the entire optimized `Next_Rule` lookup with an original-order `for Rule of Value.Array_Rules` scan for each generated stroke. It increments `Seen` only when `Rule.Boundary = Boundary` and selects the `Rule_Index`-th matching rule. `Poll (Thickness)` remains at each visited entry; metadata validation, `Rules_At` and all other polls are unchanged.

The exact-final probe source is unchanged (SHA-256 is in `summary.json`). Under GNAT 15.2, build succeeded and the unchanged 3404-assertion probe completed with three expected poll-envelope failures: 16 rules/471 polls, 256/37,799, and 1,024/544,319. The 64 seeded stop cases / 128 injections passed. This is mutation evidence only, not a production change or timing benchmark.

Prior `mutant4-reset-next-rule` must not be described as a quadratic repeated-rescan mutation. It only resets `Next_Rule` to 1 before a scan and selects the first matching boundary rule; it observed 18,479 polls at 1,024 compared with 20,543 for the intended original lookup. Preserve that historical artifact and its label, but make no quadratic-traversal claim for it. The new mutation 5 and its logs/patch/hashes are retained alongside it.
