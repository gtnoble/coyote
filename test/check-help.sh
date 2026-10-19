#!/bin/sh
# Run from any directory after development builds of the application and tests.
# GUI widget checks need DISPLAY (use xvfb-run -a sh test/check-help.sh).
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root/test"
for prerequisite in yelp-check timeout; do
    command -v "$prerequisite" >/dev/null || {
        echo "Missing Help check prerequisite: $prerequisite" >&2
        exit 1
    }
done
for program in "$root/bin/coyote" "$root/test/bin/coyote_test" "$root/test/bin/help_test_worker"; do
    test -x "$program" || { echo "Build development binaries first: $program" >&2; exit 1; }
done
if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    echo 'A display is required for the Help widget checks; use xvfb-run -a.' >&2
    exit 1
fi
timeout 60 "$root/test/bin/coyote_test" Coyote.Help
timeout 45 "$root/test/bin/coyote_test" 'Coyote.GUI Help'
yelp-check validate "$root"/share/help/C/coyote/*.page
yelp-check links "$root"/share/help/C/coyote/*.page
scratch=$(mktemp -d "${TMPDIR:-/tmp}/coyote-cli-help.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
for option in --help -h; do
    timeout 10 "$root/bin/coyote" "$option" > "$scratch/$option.out" 2> "$scratch/$option.err"
    test ! -s "$scratch/$option.err"
    grep -q '^Usage: coyote' "$scratch/$option.out"
    grep -q -- '--help' "$scratch/$option.out"
done
cmp "$scratch/--help.out" "$scratch/-h.out"
printf 'Help AUnit, Mallard validation/links, and CLI checks passed.\n'
