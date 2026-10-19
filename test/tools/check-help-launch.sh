#!/bin/sh
# Exercise the real launcher from an isolated installation prefix.
set -eu
worker=$1
mode=$2
root=$(mktemp -d "${TMPDIR:-/tmp}/coyote-help.XXXXXX")
trap 'rm -rf "$root"' EXIT HUP INT TERM
prefix="$root/prefix with spaces"
mkdir -p "$prefix/bin" "$root/viewer" "$root/empty"
cp "$worker" "$prefix/bin/help_test_worker"
worker="$prefix/bin/help_test_worker"
if [ "$mode" != no-data ]; then
    mkdir -p "$prefix/share/help/C/coyote"
    printf '%s\n' '<page xmlns="http://projectmallard.org/1.0/" id="overview"><title>Help probe</title></page>' > "$prefix/share/help/C/coyote/overview.page"
fi
cat_source='#!/bin/sh
set -eu
# Only shell builtins: the PATH intentionally excludes all real programs.
printf "%s\n" "$#" "$1" "${XDG_DATA_DIRS-unset}" > "$HELP_CAPTURE.tmp"
if [ -f "$HELP_EXPECT_PAGE" ]; then
    printf "page-present\n" >> "$HELP_CAPTURE.tmp"
else
    printf "page-absent\n" >> "$HELP_CAPTURE.tmp"
fi
# Completion is published only after the capture has been closed.
: > "$HELP_CAPTURE.done"
'
printf '%s' "$cat_source" > "$root/viewer/yelp"
chmod +x "$root/viewer/yelp"
export HELP_CAPTURE="$root/capture"
export HELP_EXPECT_PAGE="$prefix/share/help/C/coyote/overview.page"
topic=overview
expected="help:coyote/overview"
case "$mode" in
    existing) export XDG_DATA_DIRS=/original/share:/second/share ;;
    empty) export XDG_DATA_DIRS= ;;
    unset) unset XDG_DATA_DIRS ;;
    root) export XDG_DATA_DIRS=/original/share; topic=; expected=help:coyote ;;
    no-data) export XDG_DATA_DIRS=/original/share ;;
    missing) export XDG_DATA_DIRS=/original/share ;;
    *) echo "unknown launcher probe: $mode" >&2; exit 1 ;;
esac
if [ "$mode" = missing ]; then
    PATH="$root/empty" "$worker" "$topic" false
    test ! -e "$HELP_CAPTURE.done"
    exit 0
fi
PATH="$root/viewer" "$worker" "$topic" true
attempt=0
while [ ! -e "$HELP_CAPTURE.done" ] && [ "$attempt" -lt 200 ]; do
    sleep 0.01
    attempt=$((attempt + 1))
done
if [ ! -e "$HELP_CAPTURE.done" ]; then
    echo 'detached fake Yelp did not publish completion' >&2
    exit 1
fi
{
    printf '1\n%s\n' "$expected"
    case "$mode" in
        existing) printf '%s:/original/share:/second/share\n' "$prefix/share" ;;
        root) printf '%s:/original/share\n' "$prefix/share" ;;
        empty|unset) printf '%s\n' "$prefix/share" ;;
        no-data) printf '/original/share\n' ;;
    esac
    if [ "$mode" = no-data ]; then
        printf 'page-absent\n'
    else
        printf 'page-present\n'
    fi
} > "$root/expected"
diff -u "$root/expected" "$HELP_CAPTURE.tmp"
