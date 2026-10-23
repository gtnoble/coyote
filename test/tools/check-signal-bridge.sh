#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/coyote-signal-bridge.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: "${CC:=cc}"
: "${TIMEOUT:=timeout}"
for sanitizer in normal sanitize; do
    set -- -std=c11 -Wall -Wextra -Wpedantic -Werror -g
    if [ "$sanitizer" = sanitize ]; then
        set -- "$@" -fsanitize=address,undefined -fno-omit-frame-pointer
    fi
    "$CC" "$@" \
        -Wl,--wrap=pipe -Wl,--wrap=fcntl -Wl,--wrap=sigaction \
        -Wl,--wrap=read "$repo/test/native/signal_bridge_test.c" \
        "$repo/src/coyote_signal_bridge.c" -o "$tmp/signal_bridge_$sanitizer"
    if command -v "$TIMEOUT" >/dev/null 2>&1; then
        ASAN_OPTIONS=detect_leaks=0 "$TIMEOUT" 30s "$tmp/signal_bridge_$sanitizer"
    else
        echo "timeout utility unavailable; refusing unbounded test run" >&2
        exit 1
    fi
done
