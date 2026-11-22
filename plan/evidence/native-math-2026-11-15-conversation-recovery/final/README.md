# Final validation — 2026-11-22

Validation only: no source/test edits, subagents, commits, release, or installation. Host date 2026-11-22; coordinator project record date 2026-11-15. HEAD: `8cb46948190ade6bfbc2c4c5a52a45c8a74f5d57`.

## Snapshot identity

Rich_Text spec SHA-256: `cf3363a7162fc5df910b2dfb91bfa717b6143c3f0aed72aedd3211a2cbb60762`; body: `7d28012a978b0963862e809b9e9498e93b23d5af1a5932a56646f0b0926734be`; test source: `23a0ffd86fb05c4a03444f604ffe075dcd215cd1ecece8eb3faf846a003cb8dd`. Pre/post hashes match. Test binary `e630e61bd0a45c49299c15185483bc0ef1a4eb77798c9ea4c65a524b772260bc`. Other conversation-stack and Math_Element source hashes are listed in `identity-after.txt`; no edits to those files.

## Builds and tests

Root and test development-profile builds passed (actual Alire toolchain GNAT 15.2.0, GPRbuild 25.0.0; see build logs). Focused mixed-stream/copy/clear/reconstruction test passed twice 1/1; retained-buffer GObject-ref teardown test passed twice 1/1; pre-existing component fallback prefix passed 2/2. Two sequential full runs passed 1080/1080 each, zero assertion failures/errors; wall 143.62 s and 143.40 s, AUnit cumulative 2m23.532677s and 2m23.308856s.

The retained-buffer case in both focused runs recorded baseline 0 and final 0, held the explicit buffer reference after view destruction, restored visible formula source, and observed zero Pixbufs. This does not establish that any previous suite-wide 1000-byte charge is globally legitimate/resolved.

## Display checks

Private Xvfb, X11 backend, 1280x1024x24, fresh WM-free display per process, `WAYLAND_DISPLAY` unset, preserved `XAUTHORITY`, G_DEBUG=fatal-criticals for AUnit. Current real display `:0.0` is Xorg/i3 and was not used. Tool-layout runner independently validates WM-property absence/dimensions and binary hash: three repeats pass; test binary hash matches above.

GTK interactions 9/9; interaction-runner synthetic containment summary 7/9 (expected); tool-layout 3/3; tool-layout runner 36 assertions; offline HTTP lifecycle passed (65 sec bound/check). See raw logs. Script child logs remain in paths printed in the raw logs, outside this archive; they were not copied.

## Files

All final archived raw logs and identities are in `/tmp/coyote-conversation-final-validation/`: `root-build.log`, `test-build.log`, `focused-*.log`, `full-1.log`, `full-2.log`, `.time` files, required-check logs, and `identity-before.txt`/`identity-after.txt`, source hashes.

Earlier `/tmp/coyote-conversation-math-validation/` records a weaker test snapshot (source hash `b124899c…`, two full 1079 runs); it is not evidence for this 1080 snapshot. `/tmp/coyote-conversation-negative/restored-build.log` confirms the restored build; negative-control hashes and artifacts remain in that directory. Earlier desktop full-run 109/1033 allocation failure is not classified or repeated here. No browser, Valgrind, hard native preemption, product parity, or human qualification is claimed.
