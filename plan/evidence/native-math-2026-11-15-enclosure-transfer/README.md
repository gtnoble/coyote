# Enclosure command ownership transfer — developer evidence

Checkpoint2026-11-15,parent5c74453. Host timestamps differ from the project date
and are preserved verbatim. PCR-125;REQ-MATH-010/014 scoped maintenance.
Requirements,public APIs,limits,work checks and budget guards are unchanged.

## Implementation and rationale

Color/framed-color and phase enclosures previously cloned Result.Commands into
a local snapshot before clearing and rebuilding it. They now Move children
into an initially empty local vector after existing geometry validation (and
phase transform). GNAT15.2 vector Adjust allocates/copies live elements;its Move
transfers backing storage to the empty target. This removes these two explicit
whole-vector copies,including nested controlled path/text payloads. Existing
per-child shifted copies and append operations remain;other copies are not
removed or newly accounted for. No blanket claim about iteration copies.

Local vectors own children through successful reconstruction or unwinding.
There is no borrowed lifetime escape or parsed-AST mutation. Move/Reserve are
native runtime operations,not preemptible by Work polls. Existing poll locations
and order remain unchanged. This is not a pool,retained-account or refcount
migration and introduces no fine-grained accounting.

Transfer-only rebuilding lost the old cleared-vector capacity. It increased
allocation counts on all three corpora and total bytes on two. Final rebuilding
reserves child count plus1 background,5 framed decorations or1 phase path,
clamped to the existing131072-command ceiling. Append_Command still enforces
that ceiling. Bounded child length plus these small constants fits Count_Type.
No cap or numerical safety criterion was raised or relaxed.

## Controlled prior/final characterization

Three fixed corpora are run using frozen HEAD and final exporters built with
the same GNAT15.2/exporter source;only math_layout.adb differs among49 math files.
Input JSONL,normal outputs,Valgrind logs,source manifests and measurement scripts
are retained in characterization/. Normal and Valgrind outputs are byte-identical
for each variant;duplicate Valgrind JSONL and large xtree files are omitted from
this archive. Existing host-path hashes preserve their identities. Frozen layout
sources plus manifests support reconstruction;not all49 source files are copied.

| Corpus | Requests / commands / path segments | Baseline allocations / bytes | Final allocations / bytes |
|---|---|---|---|
| Regression |52 /352 /888 |132954 /21925408 |132749 /21696752 |
| Nested-heavy |72 /1848 /8125 |782748 /164304506 |779587 /160279682 |
| Repeated |10 /200 /600 |79139 /15082312 |78879 /14704792 |

All134 requests return ok;full exported records for all2400 commands match
baseline byte-for-byte. Cases cover color/framed/phase,nesting1..16,path-bearing
children,display/text and fleqn variants. This is comparison to prior behavior,
not independent browser/image parity. Allocated bytes fall228656 (1.04%),
4024824 (2.45%) and377520 (2.50%);allocation counts also fall on all three.
These are fixed-workload,whole-process cumulative Valgrind allocation totals,
not peak live memory,RSS,per-job caps,wall-clock speedups or universal savings.

Transfer-only intermediate allocations/bytes:133054/21966280,
783630/164244626,79299/15180392. Its mixed result and earlier full validation
remain separately retained,not substituted for final transfer-plus-reservation
results. Valgrind reports zero errors and zero definite,indirect or possible
lost bytes in each final exporter corpus. Reachable native/font allocations
remain;the previously failing strict raster losses are NOT waived.

## Direct-layout and recovery coverage

Final engine3497/3497 twice. The byte-identical probe also passes twice against
isolated HEAD runtime:an equivalence-preserving ownership optimization,not an
asserted earlier functional defect. Five fixtures cover color,framed,nested,
phase,nested-phase with populated path payloads. They compare complete Box values
with and without Work,inject cancel/deadline at one-third,two-thirds and last
poll (30 injections),check exact exception identity and rebuild recovery,then
mutate a returned path and verify fresh geometry/other output remains independent.
A successful result is rebuilt before comparing after exceptions. Before/after
poll totals match:80,88,116,87,107. Checkpoints span whole layout;not every stop
is proven inside reconstruction. Last poll is in final command validation.

Color-box invalid geometry is rejected before transfer with exact diagnostic,
empty commands and ordinary recovery. Phase rejection and active-worker phase
interruption are not separately injected. Engine Valgrind3497 assertions reports
zero errors/lost bytes,216713 reachable,using the existing4MiB semantic-frame
classification threshold,no suppressions or relaxed leak criteria.

## Final broader regression

Root/test development builds pass (7.24s/4.67s),existing warnings/style diagnostics
remain. Full Xvfb1076/1076,zero failures/errors,144.475244s cumulative/144.51s wall.
All293 src hashes match before/after. New standalone checks do not add AUnit
registrations. GTK9/9,runner containment and offline HTTP pass. Expected Unicode
kill/bidi timeout yield7/9 synthetic child criteria;the containment harness passes.
Worker346/346 and pinned geometry235/235 pass. Stratified fuzz10000 primaries,
eight strata,5007 distinct sources,full two-pass replay passes unchanged digest
083e07d5fd4873f8bbec5405fb63f0a4ca65820ed66da7b5f0572a5da4480caa;
per pass5742 ok,3893 parse-error,156 layout-error,209 policy-visible. Elapsed41702ms
is harness time,not product latency qualification.

## Development provenance and reproduction

The initial reserve edit used Max_Commands rather than local Max_Draw_Commands
and failed compilation. The retained worker gate records the reported blockage;
corrected final builds/probes supersede it. First aged correction was rejected
as nonunique and made no change;scoped exact replacements fixed both sites.
Initial tests omitted phase;phase/nested-phase fixtures were added before final
3497 runs. Earlier3458/transfer-only results are not exact-final evidence.
Archive assembly initially assumed an incorrect snapshot nesting path;collection
was corrected and coordinator verifies exact retained source/output identities.
No product source was altered by that archive error.

Commands from repository root unless noted:

- `alr build --development`;from test,`alr build --development --profiles=coyote=development`.
- From test,`timeout 300 xvfb-run -a ./bin/coyote_test`.
- `MATH_ENGINE_ROOT=/tmp/coyote-enclosure-engine-final3 sh test/tools/check-math-engine.sh`.
- `MATH_JOBS_ROOT=/tmp/coyote-enclosure-jobs sh test/tools/check-math-jobs.sh`.
- `MATH_GEOMETRY_ROOT=/tmp/coyote-enclosure-geometry sh test/tools/check-math-geometry.sh`.
- `valgrind --max-stackframe=4194304 --error-exitcode=1 --leak-check=full /tmp/coyote-enclosure-engine-final3/bin/math_engine_probe`.
- `node test/tools/check-math-fuzz.cjs /tmp/coyote-enclosure-characterization/reserved-build/bin/math_export /tmp/coyote-enclosure-fuzz.json`.
- Original characterization:`python3 compare-allocation.py reserved /tmp/coyote-enclosure-characterization/reserved-build/bin/math_export`.
  Script uses its own directory for corpus/logs;copied scripts/manifests carry
  original host paths. Inputs and normal outputs are retained for reconstruction.
- Required GTK/runner/HTTP commands,toolchain,profile evidence and timings are in
  validation/final/. Transfer-only validation is explicitly intermediate.

Read-only review finds no correctness blocker;it did not independently verify
all output records. Coordinator checks verify those records and hashes.
Developer/agent self-review is NOT independent acceptance. Source fingerprint
updated,coverage counts unchanged. No browser images/raster or whole-macro
Valgrind rerun;prior raster losses and broader resource,GTK/cache,timing,font,
lifecycle,parity and human gates remain OPEN. No release/install/commit.
