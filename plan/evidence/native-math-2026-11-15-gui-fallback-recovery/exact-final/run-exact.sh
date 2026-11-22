#!/usr/bin/env bash
set +e
ROOT=/home/gtnoble/Projects/coyote/coyote-latex-math
OUT=/tmp/coyote-gui-fallback-exact-validation
cd "$ROOT" || exit 2
printf 'HEAD=%s\n' "$(git rev-parse HEAD)" > "$OUT/provenance.txt"
printf 'WORKTREE_STATUS_BEGIN\n' >> "$OUT/provenance.txt"
git status --short >> "$OUT/provenance.txt"
printf 'WORKTREE_STATUS_END\n' >> "$OUT/provenance.txt"
printf 'TEST_SOURCE_SHA256=' >> "$OUT/provenance.txt"
sha256sum test/src/coyote_gui_conversation_stack_tests.adb >> "$OUT/provenance.txt"
find src tools requirements -type f -print0 | sort -z | xargs -0 sha256sum > "$OUT/source-fingerprints.sha256"
sha256sum test/bin/coyote_test >> "$OUT/provenance.txt"
(cd test && alr exec -- gprconfig --version) > "$OUT/toolchain.txt" 2>&1
(cd test && alr exec -- gprbuild --version) >> "$OUT/toolchain.txt" 2>&1
printf 'BUILD_LOG_SHA256=' >> "$OUT/provenance.txt"
sha256sum /tmp/coyote-gui-fallback-exact-build.log >> "$OUT/provenance.txt"
printf 'BASELINE_BUILD_END\n' >> "$OUT/provenance.txt"
run_test() {
  label=$1; filter=$2
  logfile="$OUT/$label.log"
  printf 'START %s %s\n' "$(date -Is)" "$label" | tee "$OUT/$label.meta"
  unset DISPLAY WAYLAND_DISPLAY
  timeout -k 10s 300s xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' sh -c '
    printf "DISPLAY=%s WAYLAND_DISPLAY=%s XAUTHORITY_PRESENT=%s\n" "$DISPLAY" "${WAYLAND_DISPLAY-unset}" "${XAUTHORITY:+yes}";
    xprop -root _NET_SUPPORTING_WM_CHECK _NET_WM_NAME 2>&1;
    xdpyinfo | grep -E "dimensions:|resolution:";
    cd "$1" || exit 126;
    if [ -n "$2" ]; then exec env G_DEBUG=fatal-criticals ./bin/coyote_test "$2"; else exec env G_DEBUG=fatal-criticals ./bin/coyote_test; fi
  ' sh "$ROOT/test" "$filter" > "$logfile" 2>&1
  rc=$?
  printf 'END %s rc=%d at=%s\n' "$label" "$rc" "$(date -Is)" | tee -a "$OUT/$label.meta"
  printf '%s\t%d\n' "$label" "$rc" >> "$OUT/status.tsv"
  return 0
}
: > "$OUT/status.tsv"
run_test full-1 ''
run_test full-2 ''
run_test focused-1 'Coyote.GUI.Conversation_Stack recovers'
run_test focused-2 'Coyote.GUI.Conversation_Stack recovers'
sha256sum test/bin/coyote_test >> "$OUT/provenance.txt"
find src tools requirements -type f -print0 | sort -z | xargs -0 sha256sum > "$OUT/source-fingerprints-after.sha256"
printf 'FINAL_HEAD=%s\n' "$(git rev-parse HEAD)" >> "$OUT/provenance.txt"
git status --short > "$OUT/worktree-status-after.txt"
exit 0
