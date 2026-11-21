# Evolving harness evidence

The first generated-corpus attempt failed its setup snapshot assertion. The
retained failure JSON/input/output are the actual original batch artifacts;
they are not an exact-final baseline. That version mixed fuzzlocal uses with
sentinel definitions and exploratory script generation in a supposedly valid
stratum. It was corrected in the harness, not production. Later drafts were
reviewed and tightened:alphabetic macro names rather than control-word digits,
explicit macro/URL oracles, exact sentinel/local cleanup, calibrated positive
corpus. The two final invocations use the final sources in the manifest.

A coordinator experiment considered rejecting all exporter stderr, but source
inspection showed ordinary parse/layout rejections also write stderr, so it
was not run as a final corpus rule. Unexpected exporter exceptions take a path
without macroStateComplete, rejected by the required shared-context snapshot
check and an explicit self-test. No native fix or before/after product defect
result is claimed. Final runner negative controls are synthetic, not native
failures. Original host paths/timestamps are preserved.
