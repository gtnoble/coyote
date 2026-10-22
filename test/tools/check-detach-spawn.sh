#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/coyote-detach-spawn.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: "${CC:=cc}"
: "${TIMEOUT:=timeout}"
: "${DETACH_SPAWN_TEST_TIMEOUT:=15}"
set -- -std=c11 -Wall -Wextra -Wpedantic -Werror -g
if [ "${DETACH_SPAWN_ASAN:-0}" = 1 ]; then
    set -- "$@" -fsanitize=address,undefined -fno-omit-frame-pointer
fi
wraps=
for name in pipe2 fcntl fork setsid chdir open dup2 execvp read write waitpid; do
    wraps="$wraps -Wl,--wrap=$name"
done
# Intentional word splitting of linker-wrapper arguments.
# shellcheck disable=SC2086
"$CC" "$@" $wraps "$repo/test/native/detach_spawn_test.c" \
    "$repo/src/coyote_detach_spawn.c" -o "$tmp/detach_spawn_test"
if command -v "$TIMEOUT" >/dev/null 2>&1; then
    "$TIMEOUT" "${DETACH_SPAWN_TEST_TIMEOUT}s" "$tmp/detach_spawn_test"
else
    echo "timeout utility unavailable; running without wall-clock bound" >&2
    "$tmp/detach_spawn_test"
fi
