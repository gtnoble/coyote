# Native math retained-budget ownership — design proposal

**Date:** 2026-11-15. **Status:** OPTIONAL DESIGN EXPLORATION — NOT APPROVED / NOT IMPLEMENTED.

**Supersession:** SRS-MATH v1.1 replaces exhaustive whole-job memory accounting
with practical resource-abuse protection. The proposal below is preserved as
historical design analysis, not a required next increment or acceptance gate.
Retained-account leases, storage pools and Document API migration are optional
and require concrete justification before further work. Existing call-only
budget borrows must still not escape; ordinary lifetime safety remains required.
References below to the old 256 MiB whole-job requirement and approval gate
describe the superseded v1.0 rationale, not current mandatory work.
**Authority:** PCR-125 continuation, REQ-MATH-010 / MATH-LIMIT-002.
**Current verified implementation:** report §11.16; no requirements/deviations
changed. This proposal is not qualification or acceptance.

## Decision requested

Approve a bounded design increment for stable per-job accounts and explicit
retained-result leases before extending any borrowed Parse reservation beyond
its call. Prefer preserving Math_Syntax.Document's existing value API for now;
place initial retained ownership at job/result boundaries, then explicitly
cover clones and GUI adoption. This is a recommendation, not an approved design.

## Problem and verified constraints

Parse receives Memory as a call-only borrow. Its controlled reservations end
at return. Worker Memory is local to the job block, but Job_Result and GUI
copies survive that block. Retaining that access value in Document would permit
later finalization through a destroyed Budget. Making the worker field stable
is insufficient when earlier results remain live during later jobs.

Document is nonlimited and copyable; its vectors and strings deep-copy.
Parse_Document returns a value; GUI stores it independently. Semantics, layout
Box/commands, painting temporaries and raster adoption create additional owned
payloads and overlaps. Current logical capacity charges omit several of them.
The 256 MiB requirement is per job, not an already-approved process-wide256MiB
cap. The separate64MiB retained raster ledger is process-shared. Any new
process-wide concurrency cap would need its own requirements decision.

Exact paths/callers and alternatives are recorded in
`plan/evidence/native-math-2026-11-15-array-rule-budget/ownership-assessment.md`.

## Recommended design direction

1. Use a stable reference-counted job-account owner whose storage outlives all
   leases. A worker/result/explicit clone holds an owning handle, not an
   unchecked borrow to stack storage. Define protected lifetime synchronization
   and final-release behavior before coding. Distinct jobs retain distinct
   256MiB accounts; process cache admission remains separate.
2. Keep Parse construction reservations call-local. Account the resulting AST
   through a job-owned retained lease before moving to later phases, without an
   uncharged transfer interval. Measure nested vector/string capacity honestly;
   logical payload accounting is not allocator overhead or RSS accounting.
3. Introduce explicit retained clone/transfer/borrow operations at job-to-GUI
   boundaries. A clone must admit source+destination overlap before allocation;
   failed cloning must leave the original result usable and release partial
   output before charge release. Ordinary value accessors must not silently
   bypass retained accounting on the qualified path.
4. Specify when job products become cache products: while both copies coexist,
   charge both to the job and admit retained raster against64MiB; after job
   completion transition only actual cache-owned data. Source/session retention
   and shared font baseline remain separately reported per the SRS.
5. Extend the same ownership discipline to semantic/layout/painter/native
   intermediates in subsequent reviewed increments. Do not label the AST-only
   migration whole-job enforcement.

## Alternatives and trade-offs

- Limited Document with explicit move/clone: strongest prevention of accidental
  copies, but migrates Parse returns/assignments, tests, engine/GUI fields and
  public accessors. Prefer only if boundary leases prove insufficient.
- Immutable shared Document backing: copies become handles charged once; larger
  representation/refcount/thread-safety change with failure and immutability
  obligations. Not selected for this first proposal.
- Fully scoped callback pipeline: avoids escaping products but substantially
  changes display reflow and retained GUI behavior. Not selected.
- Extending borrowed reservation directly: rejected due to dangling ledger
  lifetime and uncontrolled deep-copy paths.

## Required verification before any completion claim

- Exact/short boundaries, clone overlap rejection, account lifetime beyond
  worker scope, repeated replacement and independent concurrent jobs.
- Fault-injected clone/allocation failure; cancellation/deadline/error cleanup;
  source ownership preserved after failed transfer.
- Result publication/discard/clear/reflow/GTK adoption/destruction coverage;
  no GTK calls from workers and no escaped uncharged qualified-path copies.
- Separate logical-accounted payload and isolated warmed-baseline RSS reporting.
- Full development suite and mandatory GTK/containment/offline HTTP checks;
  strict native lifecycle failures remain failures until actually resolved.

## Gate and limits

User design review is required before implementing this ownership/API change.
Current §11.16 source remains intact and verified. Scoped parser improvements
and other project tasks are not technically blocked by this decision; no claim
is made that all possible work is exhausted. Whole-job accounting cannot be
asserted from present call-scoped reservations. Dependency-global lifecycle,
hard timing, font behavior, full parity and independent desktop/AT/user
acceptance remain open. Developer/agent self-review is not independent approval.
No release, installation or commit is authorized by this proposal.
