#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/coyote-image-loader.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

: "${CC:=cc}"
: "${TIMEOUT:=timeout}"
: "${IMAGE_LOADER_TEST_TIMEOUT:=60}"

set -- -std=c11 -Wall -Wextra -Werror -g
if [ "${IMAGE_LOADER_ASAN:-0}" = 1 ]; then
   set -- "$@" -fsanitize=address,undefined -fno-omit-frame-pointer
fi
# pkg-config supplies the GTK-independent GLib/GdkPixbuf dependencies.
# shellcheck disable=SC2046
"$CC" "$@" -I"$repo/src/coyote_gui" \
   "$repo/test/native/image_loader_test.c" \
   "$repo/src/coyote_gui/coyote_image_loader.c" \
   $(pkg-config --cflags --libs gdk-pixbuf-2.0 glib-2.0) \
   -pthread -o "$tmp/image_loader_test"

if command -v "$TIMEOUT" >/dev/null 2>&1; then
   "$TIMEOUT" "${IMAGE_LOADER_TEST_TIMEOUT}s" "$tmp/image_loader_test"
else
   echo "timeout utility unavailable; running without wall-clock bound" >&2
   "$tmp/image_loader_test"
fi
