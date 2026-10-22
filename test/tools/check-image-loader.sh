#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/coyote-image-io.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

: "${CC:=cc}"
: "${TIMEOUT:=timeout}"
: "${IMAGE_LOADER_TEST_TIMEOUT:=60}"

set -- -std=c11 -Wall -Wextra -Wpedantic -Werror -g
if [ "${IMAGE_LOADER_ASAN:-0}" = 1 ]; then
   set -- "$@" -fsanitize=address,undefined -fno-omit-frame-pointer
fi
# pkg-config supplies GdkPixbuf, GLib, and GObject headers and libraries.
# shellcheck disable=SC2046
"$CC" "$@" \
   "$repo/test/native/image_io_test.c" \
   "$repo/src/coyote_image_io_c.c" \
   $(pkg-config --cflags --libs gdk-pixbuf-2.0 glib-2.0 gobject-2.0) \
   -o "$tmp/image_io_test"

if command -v "$TIMEOUT" >/dev/null 2>&1; then
   "$TIMEOUT" "${IMAGE_LOADER_TEST_TIMEOUT}s" "$tmp/image_io_test"
else
   echo "timeout utility unavailable; running without wall-clock bound" >&2
   "$tmp/image_io_test"
fi
