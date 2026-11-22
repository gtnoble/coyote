#!/usr/bin/env bash
set -uo pipefail
root=/tmp/coyote-gtk-allocation-investigation/controlled
binary=/home/gtnoble/Projects/coyote/coyote-latex-math/test/bin/coyote_test
config=$root/i3.config
log=$root/run.log
: > "$log"
{
  printf 'started_utc='; date -u +%FT%TZ
  printf 'binary='; readlink -f "$binary"
  sha256sum "$binary"
  printf 'filter=Coyote.GUI tool detail stable layout and snapshots\n'
  printf 'timeout_seconds=30\n'
  printf 'existing_display_not_used='; printf '%s\n' "${DISPLAY:-<unset>}"
} >> "$log"
run_test() {
  local label=$1; shift
  printf '\n--- %s ---\n' "$label" | tee -a "$log"
  (cd /home/gtnoble/Projects/coyote/coyote-latex-math/test && timeout 30s "$binary" "Coyote.GUI tool detail stable layout and snapshots") >> "$log" 2>&1
  local rc=$?
  printf 'exit_status=%s\n' "$rc" | tee -a "$log"
  return 0
}
export GTK_A11Y=none
xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' bash -c '
set -uo pipefail
root=/tmp/coyote-gtk-allocation-investigation/controlled
log=$root/run.log
unset I3SOCK
/usr/bin/i3 -c "$root/i3.config" >>"$log" 2>&1 &
wm_pid=$!
cleanup() { kill "$wm_pid" 2>/dev/null || true; wait "$wm_pid" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
ready=0
for n in $(seq 1 100); do
  if xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q "window id #"; then
    name=$(xprop -id "$(xprop -root _NET_SUPPORTING_WM_CHECK | sed -n "s/.*# //p")" _NET_WM_NAME 2>/dev/null || true)
    if printf "%s" "$name" | grep -q i3; then ready=1; break; fi
  fi
  sleep 0.05
done
{
  echo "private_display=$DISPLAY"
  xdpyinfo | grep -E "dimensions:|depth of root window"
  xprop -root _NET_SUPPORTING_WM_CHECK
  xprop -id "$(xprop -root _NET_SUPPORTING_WM_CHECK | sed -n "s/.*# //p")" _NET_WM_NAME
  echo "private_i3_pid=$wm_pid ready=$ready"
} >> "$log"
if [ "$ready" -ne 1 ]; then echo "BLOCKED: private i3 did not become WM" >> "$log"; exit 70; fi
# i3-managed tiling: first focused reproduction
(cd /home/gtnoble/Projects/coyote/coyote-latex-math/test && timeout 30s /home/gtnoble/Projects/coyote/coyote-latex-math/test/bin/coyote_test "Coyote.GUI tool detail stable layout and snapshots") >> "$log" 2>&1; rc=$?
echo "managed_i3_exit_status=$rc" >> "$log"
# Terminate only the private WM, then rerun on the same X server without any WM.
kill "$wm_pid" 2>/dev/null || true
wait "$wm_pid" 2>/dev/null || true
wm_pid=
sleep 0.25
echo "same_display_no_wm=1" >> "$log"
(cd /home/gtnoble/Projects/coyote/coyote-latex-math/test && timeout 30s /home/gtnoble/Projects/coyote/coyote-latex-math/test/bin/coyote_test "Coyote.GUI tool detail stable layout and snapshots") >> "$log" 2>&1; rc=$?
echo "same_display_no_wm_exit_status=$rc" >> "$log"
' >> "$log" 2>&1
xrc=$?
printf 'xvfb_run_exit_status=%s\n' "$xrc" | tee -a "$log"
# independent fresh Xvfb displays, each with the same private WM/config
for n in 1 2 3; do
  xvfb-run -a -s '-screen 0 1280x1024x24 -nolisten tcp' bash -c '
    set -uo pipefail; root=/tmp/coyote-gtk-allocation-investigation/controlled; unset I3SOCK
    /usr/bin/i3 -c "$root/i3.config" >>"$root/run.log" 2>&1 & p=$!
    trap "kill $p 2>/dev/null || true; wait $p 2>/dev/null || true" EXIT INT TERM
    ready=0; for n in $(seq 1 100); do
      wid=$(xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | sed -n "s/.*# //p")
      if [ -n "$wid" ] && xprop -id "$wid" _NET_WM_NAME 2>/dev/null | grep -q i3; then ready=1; break; fi
      sleep 0.05
    done
    echo "fresh_display=$DISPLAY i3_ready=$ready" >>"$root/run.log"
    if [ "$ready" -ne 1 ]; then echo BLOCKED >>"$root/run.log"; exit 70; fi
    (cd /home/gtnoble/Projects/coyote/coyote-latex-math/test && timeout 30s "/home/gtnoble/Projects/coyote/coyote-latex-math/test/bin/coyote_test" "Coyote.GUI tool detail stable layout and snapshots") >>"$root/run.log" 2>&1; rc=$?
    echo "fresh_i3_repeat_exit_status=$rc" >>"$root/run.log"
  ' >> "$log" 2>&1
  printf 'fresh_repeat_%s_xvfb_exit=%s\n' "$n" "$?" | tee -a "$log"
done
cat "$log"
