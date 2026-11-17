# Read-only review: array-rule construction reservations

**Scope:** current diff in `src/coyote_math/math_syntax.adb/.ads` and `test/tools/math_parser_memory_probe.adb`. No source changes made.

## Blocker — reservation becomes stale after first-row linking

`Append_Rule` at `math_syntax.adb:2496-2535` accounts aggregate rule-vector capacity and correctly pre-admits old+new buffers before `Reserve_Capacity`. However, `Parse_Array.Append_Row` at `2458-2483` copies the array `Node` when linking its first completed row (`2470-2474`), then calls `Nodes.Replace_Element`.

This is a capacity-changing deep copy on the current GNAT runtime. `Ada.Containers.Vectors` `Adjust` allocates `Elements_Type'(L, EA)` (`/usr/lib/gcc/x86_64-linux-gnu/13/adainclude/a-convec.adb:134-160`), so a copied nested rule vector's capacity becomes its **length**, dropping spare capacity. `Replace_Element` assigns that value into the stored node (`:2518-2531`). The reservation still charges the old spare capacity.

Concrete shape: place five rule commands before the first cell, complete that row, then place another rule command at the next row boundary, e.g. `\begin{array}{c}\hline\hdashline\hline\hdashline\hline a\\\hline b\end{array}`. Five rules grow the vector to capacity 8, with reservation 8 rule slots. First-row linking copies/replaces the array node; the stored vector now has length/capacity 5 but reservation remains 8. The next append sees `Length = Capacity = 5` and requests capacity 10. Pre-admission raises aggregate from 8 to 18 slots (8 charged plus 10 proposed). After reserve, the adjustment computes `18 - (5 + 10) + 10 = 13` slots, although actual aggregate capacity is 10. Thus this is **not an underflow**: the stale three-slot excess persists and grows across subsequent resizes. With other arrays, the same per-copy excess contaminates the aggregate.

Consequences: measured/charged capacity is no longer the live capacity; peak telemetry is inflated, and exact-fit budgets can spuriously reject later. It does not undercharge actual rule capacity in this path because the copy's capacity shrinks to length, which cannot exceed the already-charged capacity. The error also makes the reservation's old-capacity term differ from actual capacity, invalidating its intended exact old/new overlap accounting.

**Fix:** avoid the array-node value copy in this branch: use a scoped `Nodes.Reference (Array_Id)` to set `First` in place, as `Append_Rule` does for `Array_Rules`. Keep the reference scope free of `Add`/outer-node-vector growth and Poll callbacks. Alternatively, if retaining value replacement, reconcile the aggregate reservation to the copied vector's actual capacity immediately after replacement and correctly account for any copy overlap; in-place mutation is simpler and eliminates the deep copy.

## Other copy and safety checks

- The other ordinary `Parse_Array` `Append_Row` branch copies a row node, not an array node, so it does not copy nested rule vectors. `Append_Cell` copies row/cell nodes. `Link` similarly copies nodes, but the parsed array node is not linked as its `Row` or `Part` in this parser. CD-array construction has no rule-vector append path. Outer `Nodes.Reserve_Capacity` does copy array nodes and nested rule vectors, but the spec explicitly excludes nested rule storage copied during outer node-vector growth; this remains an explicitly unaccounted case.
- The `Append_Rule` `Reference_Type` is scoped to the procedure and no mutation of the outer `Nodes` vector occurs there. Its `Poll` calls are not passed parser state; the callback interface only receives its own context, so it cannot invalidate this private reference through this call path. Avoid expanding reference scope around any callback or `Add` in a fix.
- `Append_Rule` checks capacity doubling, capacity-times-width and aggregate addition for overflow. In the reviewed stale-capacity scenario, the growth-time subtraction does not underflow because pre-admission has already added the new capacity; the issue is persistent overcharge, not an arithmetic exception. Keep defensive checks if the calculation is generalized.
- The diff does not remove or loosen an array semantic cap: `Max_Array_Rows` and `Max_Array_Columns` checks remain, and there is no separate rule-count cap in the reviewed preexisting path. Rule count is bounded indirectly by source/node constraints.
- Reservation lifetime is call-scoped. `Rule_Reservation` is declared before `State`, borrowed by state, and released after parser locals finalize; parse result nodes are moved to the returned document, but returned rule-vector storage is intentionally no longer charged. Syntax-failure cleanup clears partial nodes before return. Those lifetime semantics match the API comment's explicit limitation.

## Regression detectability / evidence

The recorded `parser-worker/probe.log` says **697 checks, 0 failures**, not 694 checks with 3 baseline failures. It tests aggregate charges through 4→8 growth and a second array, plus exact-fit/one-byte-short and cancellation/deadline cleanup. It does not include first-row copy followed by rule-vector regrowth, so it misses the stale-capacity and false-rejection path.

Add a focused regression using at least five pre-first-row rules, first-row linking, then a later rule growth. Assert successful parse, expected rule count/boundaries, and zero residual charge. Also test exact-fit and one-byte-short budgets for that shape; the current code may reject against its inflated measured peak, while an in-place-link fix should produce the actual-capacity result. Keep existing multi-array overlap tests.

`git diff --check` passes; the recorded full suite is 1076/1076. These passes do not qualify the uncovered copy/capacity path.

## Disposition

**Blocker for exact aggregate accounting:** remove or reconcile the first-row array-node copy, and add the copy-then-regrow regression before treating array-rule reservation telemetry and exact-fit behavior as consistent. This finding is an overcharge/false-rejection risk, not evidence of an undercharged allocation in the identified path.
