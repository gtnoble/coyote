#!/bin/sh
# Run the GUI normally, retaining a private native backtrace if it crashes.
set -eu
umask 077
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary="$root/bin/coyote"
if ! command -v gdb >/dev/null 2>&1; then
    echo 'capture-gtk-crash: gdb is required' >&2
    exit 127
fi
if [ ! -x "$binary" ]; then
    echo "capture-gtk-crash: executable not found: $binary" >&2
    exit 127
fi
log=$(mktemp "${TMPDIR:-/tmp}/coyote-gtk-crash.XXXXXX")
printf 'GDB transcript: %s\n' "$log" >&2
printf '%s\n' 'The transcript can contain conversation text and secrets; review before sharing.' >&2
status=0
gdb --quiet --batch --return-child-result \
    -ex 'set pagination off' \
    -ex 'set confirm off' \
    -ex 'set debuginfod enabled off' \
    -ex 'handle SIGPIPE nostop noprint pass' \
    -ex run \
    -ex 'thread apply all bt full' \
    -ex 'info sharedlibrary' \
    --args "$binary" --frontend gui "$@" >"$log" 2>&1 || status=$?
printf 'GDB finished (status %s). Transcript retained: %s\n' "$status" "$log" >&2
exit "$status"
