#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/coyote-canvas-tiles.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: "${CC:=cc}"
: "${TIMEOUT:=timeout}"
: "${CANVAS_TILES_TEST_TIMEOUT:=120}"
large=0
if [ "${1:-}" = --large ]; then
   large=1
elif [ "$#" -ne 0 ]; then
   echo "usage: $0 [--large]" >&2
   exit 2
fi
set -- -std=c11 -Wall -Wextra -Wpedantic -Werror -g
if [ "${CANVAS_TILES_ASAN:-0}" = 1 ]; then
   set -- "$@" -fsanitize=address,undefined -fno-omit-frame-pointer
fi
# pkg-config provides libpng and libjpeg headers and link flags.
# shellcheck disable=SC2046
"$CC" "$@" \
   -I"$repo/src" \
   "$repo/test/native/canvas_tiles_test.c" \
   "$repo/src/coyote_canvas_tiles.c" \
   "$repo/src/coyote_canvas_tile_decode.c" \
   $(pkg-config --cflags --libs libpng libjpeg) \
   -o "$tmp/canvas_tiles_test"
if ! command -v "$TIMEOUT" >/dev/null 2>&1; then
   echo "timeout utility unavailable; refusing unbounded test run" >&2
   exit 1
fi
if [ "$large" -eq 1 ]; then
   TMPDIR="$tmp" "$TIMEOUT" "${CANVAS_TILES_TEST_TIMEOUT}s" "$tmp/canvas_tiles_test" --large
else
   TMPDIR="$tmp" "$TIMEOUT" "${CANVAS_TILES_TEST_TIMEOUT}s" "$tmp/canvas_tiles_test"
fi
