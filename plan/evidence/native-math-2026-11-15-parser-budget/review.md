# Scoped product evaluation — PCR-125 parser budget

Developer/agent evaluation, not independent human acceptance.

Read-only review checked reservation-before-allocation, local finalization order,
raw-vector alias lifetime, expanded-vector Move, Unicode transformation bounds,
GNAT requested capacities, overflow and worker peak-window exception paths.
Initial review found parser telemetry was overwritten after a later font-load
exception; a deterministic regression reproduced215 assertions/1 failure. All
three exception handlers now preserve the maximum saved/current parser peak.
Corrected worker215/215 passes three times plus repeat. Final read-only review
found no scoped blocker; it did not rerun tests. Coordinator reviewed results.

A second correction accounts for three overlapping lexer record arrays and
replaces raw/expanded copies with borrowing/Move. Initial maximum-capacity
preallocation caused unnecessary tiny-input allocation; final input-derived
bounds avoid it. Two-mark decomposition proof corrected from seven to eight
emitted tokens, and direct lexical count/capacity checks cover214 nonempty
entries through U+03FF plus targeted cases.674/674 twice. Passing full1076/1076,
ledger38/38, raster1116/1116 and required GTK/offline lifecycle checks support
this scoped implementation, not complete feature qualification.

Strict raster Valgrind and all12 shaped lifecycle experiments fail. Test-only
global teardown clears definite/indirect losses in isolation but not possible
losses. No production teardown/suppression/threshold relaxation is justified.

Evaluation limitations: vector payload accounting excludes strings/lexemes,
expander/AST/semantic/layout and native/font/allocator/copy/cache lifetime data;
GNAT capacity behavior does not qualify portable allocator/RSS bounds. Macro
budget rejection is before group mutation. Hard timing, all-cache behavior,
full corpus/font parity and independent desktop/AT/user acceptance remain open.
Requirements/approved bounds unchanged. No release/installation/commit.
