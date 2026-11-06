#!/bin/sh
set -u
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_SHAPING_LIFECYCLE_ROOT:-${TMPDIR:-/tmp}/coyote-math-shaping-lifecycle}
mkdir -p "$out"
cd "$repo"
if ! MATH_SHAPING_LIFECYCLE_ROOT="$out/build" alr exec -- gprbuild -p \
   -P test/native/math_shaping_lifecycle.gpr > "$out/build.log" 2>&1; then
   cat "$out/build.log" >&2
   exit 1
fi
probe="$out/build/bin/math_shaping_lifecycle_probe"
failed=0
baseline=
for mode in measure draw; do
   for count in 1 10 100; do
      log="$out/valgrind-$mode-$count.log"
      printf 'Valgrind %s count=%s\n' "$mode" "$count"
      if [ "$mode" = draw ]; then
         valgrind --leak-check=full --show-leak-kinds=all \
            --num-callers=30 --error-exitcode=1 \
            "$probe" "$count" draw > "$log" 2>&1
         status=$?
      else
         valgrind --leak-check=full --show-leak-kinds=all \
            --num-callers=30 --error-exitcode=1 \
            "$probe" "$count" > "$log" 2>&1
         status=$?
      fi
      grep '^iterations=' "$log" || failed=1
      summary=$(sed -n '/LEAK SUMMARY:/,/ERROR SUMMARY:/p' "$log" |
         grep -E 'definitely lost:|indirectly lost:|possibly lost:' |
         sed 's/^==[^=]*== //')
      printf '%s\n' "$summary"
      definite=$(printf '%s\n' "$summary" | grep 'definitely lost:' || :)
      indirect=$(printf '%s\n' "$summary" | grep 'indirectly lost:' || :)
      current="$definite|$indirect"
      if [ -z "$baseline" ]; then
         baseline=$current
      elif [ "$current" != "$baseline" ]; then
         printf 'definite/indirect leak counts changed: %s\n' "$log" >&2
         failed=1
      fi
      grep 'ERROR SUMMARY:' "$log" | tail -1
      if [ "$status" -ne 0 ]; then
         printf 'Strict Valgrind errors: %s\n' "$log" >&2
         failed=1
      fi
   done
done
printf 'Fixed definite/indirect baseline: %s\n' "$baseline"
printf 'Build log: %s/build.log\nValgrind logs: %s/valgrind-*.log\n' \
   "$out" "$out"
exit "$failed"
