#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/coyote-cmark-ownership.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: "${ALR:=alr}"
cd "$repo"
CMARK_TEST_ROOT="$tmp" "$ALR" exec -- gprbuild -p \
  -P test/native/cmark_ownership.gpr
timeout 15 "$tmp/bin/cmark_ownership_worker"
