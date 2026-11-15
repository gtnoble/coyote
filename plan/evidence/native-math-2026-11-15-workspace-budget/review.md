# Scoped developer/agent review

Read-only worker reviewed the workspace ledger, raster Paint/Render_Into,
worker integration and post-allocation cancellation controls. No scoped
blocker found. Coordinator read the result and final code. This is not
independent human acceptance or qualification.

Review verified account lifetime exceeds scoped reservation lifetime,
cleanup clears output and releases after native object destruction, and
worker direct rendering avoids its function-result assignment copy.
GNAT14/15 a-convec runtime inspection found empty-vector Reserve_Capacity
allocates requested capacity. This implementation dependence is documented:
actual capacity reconciliation after allocation is not portable preadmission
of a runtime that over-allocates. Allocation metadata remains excluded.

The empty-box cancellation/deadline control reaches poll10 after output-vector
allocation (nine polls precede it). It does not preempt native allocation.
Ledgers are independent per invocation/job, not a concurrent-worker process
cap. Charges end at render completion; parser/layout/native/font internals,
retained/caller copies and full-cache policy are outside this increment.
