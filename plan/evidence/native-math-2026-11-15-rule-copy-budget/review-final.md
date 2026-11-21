# Final read-only review — parser array-rule copy budget

**Disposition:** The revised source addresses the specific nested `Array_Rules` copy that occurs during outer node-vector growth for the current GNAT implementation. The explicit indexed `Constant_Reference` scans and the revised fixture/mutation evidence are materially stronger than the state recorded in `review.md`. This is a scoped implementation-specific accounting change, not independent allocator measurement, portable memory accounting, whole-job accounting, or qualification.

## Scope and review method

Reviewed the current source diff in `src/coyote_math/math_syntax.adb`, `src/coyote_math/math_syntax.ads`, and `test/tools/math_parser_memory_probe.adb`; the `Add` call paths and array parsing/linking paths; Alire's active GNAT via `alr exec -- gnatls -v`; GNAT 15.2.0's `a-convec.ads`/`a-convec.adb`; and the focused probe and mutation logs under `/tmp`. No source, test, or other project documentation was changed. No full suite was run. Only this review record was written.

## Findings

### 1. Both accounting scans now inspect nodes by reference

The two scans in `Add` (`math_syntax.adb`, outer growth block) use `Node_Vectors.Constant_Reference (Index)` and read the node fields through the returned `Constant_Reference_Type`. Each reference is declared in a loop-body-local `declare` block; that block ends before the next iteration. The first scan and its references end before the following outer-node `Reserve_Capacity`; the second scan starts after `Reserve_Capacity` has returned. There is no reference retained across the outer-vector mutation or across another mutation of `State.Item.Nodes`.

The explicit approach is defensible regardless of any language/compiler optimization to container iteration. I did **not** treat ordinary `for ... of` iteration as proof of a per-element copy. The active GNAT 15.2 vector spec says `Iterator_Element => Element_Type`, and its implementation has a by-value `Element` function; but the vector also declares `Constant_Indexing`. Those facts alone do not prove which mechanism a particular Ada iteration uses. No claim that the old iteration necessarily copied each node is needed for this review.

### 2. Active GNAT 15.2 implementation supports charging active nested rule elements

The actual compiler selected by Alire is GNAT 15.2.0 at the Alire toolchain path, not system GNAT 13. The active runtime source confirms:

- `Ada.Containers.Vectors.Adjust` allocates replacement storage over `Index_Type'First .. Last`, so its copied range is the active length, not spare capacity (`a-convec.adb`, `Adjust`).
- `Reserve_Capacity` constructs a replacement array from the active `Src` range and only frees the old array after allocating/copying the replacement (`a-convec.adb`, `Reserve_Capacity`).

Consequently, for this runtime, outer node-vector growth can create transient nested rule-vector copies totaling the sum of active `Array_Rules.Length * Rule_Width`. The first pre-admission adds this active-length amount to the already-owned rule-capacity reservation, and leaves that overlap charged through `Nodes.Reserve_Capacity`. After growth, the second reference scan reconciles to the aggregate live nested-vector capacities. The node-array old/new overlap is charged separately. This reasoning is specific to the inspected GNAT implementation. It does not establish allocated bytes, allocator metadata, or a guarantee for another runtime implementation.

The post-growth reconciliation is necessarily after the allocation. Its safety argument depends on the requested capacity and inspected GNAT behavior; it should not be described as portable strict admission for a runtime that might provide capacity beyond the request.

### 3. Current `Add` callers do not provide populated array-rule vectors

`Add` initializes `Fresh : Node := Item`, which is a potential nested-vector copy if a caller passes a node with populated `Array_Rules`. The inspected call sites do not do that:

- Array nodes are passed to `Add` with default-empty `Array_Rules`; `Parse_Array` and CD parsing append rules only after the array node is in `State.Item.Nodes`.
- Other `Add` inputs are default-initialized nodes, record aggregates with `others => <>`, or copies/updates of ordinary nodes such as rows, fractions, glyphs, and wrappers. I found no path that populates an `Array_Rules` vector in a local `Node` and then passes that node to `Add`.

Thus the `Fresh := Item` copy is not currently an uncharged populated-rule copy at a call site. This is a call-site fact, not an invariant enforced by `Add`: if a future caller passes a populated array-rule vector, that copy would need review/accounting. The same limitation applies to other nested payloads, which the current scope explicitly excludes.

### 4. Bounds and mutation ordering

The new active-rule sum checks that each `Length` fits the remaining `Natural` range after dividing by `Rule_Width`, then multiplies and adds. The post-growth capacity sum has the analogous check. The existing node old/new-capacity sum is guarded before multiplication. The new rule overlap reservation occurs before the node overlap reservation, poll, and outer `Reserve_Capacity`, so the intended nested-copy charge is visible before the allocation point. A poll can raise after both reservations and before growth; the reservation owners are Parse locals and release on unwinding.

The current loop ranges are evaluated while the vector is stable; references are short-lived and gone before the mutating operation. The `Add` growth block is entered at full capacity, and the parser's node storage is initialized before it can append, so the scans operate on the existing node range. No reference-lifetime or mutation-order defect was found in the revised code.

### 5. Fixture and focused evidence

The updated `Rule_Growth_Node_Source` begins its array with `\hline` (solid boundary 0), has a row break, then `\hdashline` (dashed boundary 1), followed by enough top-level terms to force outer node-vector growth. The final focused log records 56 AST nodes and verifies the returned array has two ordered rules: `(Boundary => 0, Kind => Solid_Array_Rule)` and `(Boundary => 1, Kind => Dashed_Array_Rule)`.

The current final console record `/tmp/coyote-parser-probe-final-20261118-console.log` reports:

- 719 checks, 0 failures;
- observed outer-growth ledger delta `24,586` bytes;
- rule-free node-only overlap `24,576` bytes;
- 10-byte difference, equal to the two active rule elements at the fixture's `Rule_Width`;
- expected node/rule overlap and cancellation/deadline cleanup checks passing.

`/tmp/coyote-parser-probe-mutant-build.log` and `/tmp/coyote-parser-probe-mutant-probe.log` record the mutation that removes only the rule-copy reservation while preserving the newly added `Math_Work_Control.Poll`. That run reports exactly five failures: the overlap observation, cancellation and deadline cleanup at that observation, and the two shared-macro-scope restore checks. This is useful evidence that those live-charge/poll-dependent assertions detect removal of the rule charge without relying on removal of the poll. It is not a separate allocator observation.

The checks observe the production `Math_Memory_Budget` ledger at a test-controlled poll and compare two instrumented parse runs. Therefore characterize them as a **live-charge detector with a poll-preserving mutation control**, not as an independent allocator/RSS oracle or proof of actual allocator bytes. Exact-fit and one-byte-short cases validate behavior relative to that same accounting model, not an independent measurement of physical memory.

### 6. Remaining scope limits

The declaration documentation correctly limits this addition to transient active nested array-rule copies during GNAT outer-vector growth and rule-vector capacity during parsing, with reservation charges ending at `Parse` return. Still unaccounted include other nested node payload copies, strings, diagnostics and other parser/expander/layout/native/font work, allocator overhead, process memory, and returned-document/cache lifetimes. The known retained-ownership proposal remains a separate design gate; this review neither approves nor resolves it.

The existing duplicate cancellation/deadline cases share the same injected stop point and cleanup path. They check propagation of two exception identities and reservation/scope cleanup, not independent phases or timing behavior.

## Final assessment

No blocking defect was found in the revised explicit-reference scans, their bounds, or their lifetime relative to outer-vector mutation for the reviewed source and active GNAT 15.2 runtime. The narrow accounting model is plausible and supported by its inspected runtime implementation; current `Add` callers do not pass populated array-rule vectors. The focused final probe and poll-preserving mutation provide meaningful behavioral evidence for live ledger charging and cleanup. They do not independently establish real allocation size, portable container semantics, whole-job memory bounds, timing, complete parity, lifecycle qualification, or user acceptance. No full-suite result is asserted by this review.
