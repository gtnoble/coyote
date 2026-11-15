#!/bin/sh
set -u
repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
out=${MATH_SHAPING_LIFECYCLE_ROOT:-${TMPDIR:-/tmp}/coyote-math-shaping-lifecycle}
build_root=${MATH_SHAPING_LIFECYCLE_BUILD_ROOT:-$out/build}
mkdir -p "$out" "$build_root"
cd "$repo"
if ! MATH_SHAPING_LIFECYCLE_ROOT="$build_root" alr exec -- gprbuild -p \
   -P test/native/math_shaping_lifecycle.gpr > "$out/build.log" 2>&1; then
   cat "$out/build.log" >&2
   exit 1
fi
probe="$build_root/bin/math_shaping_lifecycle_probe"
summary="$out/summary.csv"
printf 'count,mode,teardown,exit_status,definitely_lost,indirectly_lost,possibly_lost,error_summary\n' > "$summary"
failed=0
for mode in baseline measure draw; do
   for teardown in none teardown; do
      for count in 1 10 100; do
         log="$out/valgrind-$mode-$count-$teardown.log"
         printf 'Valgrind mode=%s count=%s teardown=%s\n' \
            "$mode" "$count" "$teardown"
         if [ "$teardown" = teardown ]; then
            valgrind --leak-check=full --show-leak-kinds=all \
               --num-callers=40 --error-exitcode=1 \
               "$probe" "$count" "$mode" teardown > "$log" 2>&1
         else
            valgrind --leak-check=full --show-leak-kinds=all \
               --num-callers=40 --error-exitcode=1 \
               "$probe" "$count" "$mode" > "$log" 2>&1
         fi
         status=$?
         record=$(grep '^LIFECYCLE_SUMMARY,' "$log" | tail -1)
         if [ -z "$record" ]; then
            printf 'missing probe summary: %s\n' "$log" >&2
            failed=1
         else
            printf '%s\n' "$record"
         fi
         lost=$(sed -n '/LEAK SUMMARY:/,/ERROR SUMMARY:/p' "$log" |
            grep -E 'definitely lost:|indirectly lost:|possibly lost:' |
            sed 's/^==[^=]*== //' | tr '\n' ';')
         errors=$(grep 'ERROR SUMMARY:' "$log" | tail -1 | sed 's/^==[^=]*== //')
         printf '%s,%s,%s,%s,"%s","%s","%s","%s"\n' \
            "$count" "$mode" "$teardown" "$status" \
            "$(printf '%s' "$lost" | sed -n 's/.*\(definitely lost:[^;]*\).*/\1/p')" \
            "$(printf '%s' "$lost" | sed -n 's/.*\(indirectly lost:[^;]*\).*/\1/p')" \
            "$(printf '%s' "$lost" | sed -n 's/.*\(possibly lost:[^;]*\).*/\1/p')" "$errors" >> "$summary"
         [ "$status" -eq 0 ] || failed=1
         grep 'ERROR SUMMARY:' "$log" | tail -1
         printf 'Full log: %s\n' "$log"
      done
   done
done
printf 'Machine-readable summary: %s\n' "$summary"
printf 'Build log: %s/build.log\nBuild root: %s\n' "$out" "$build_root"
exit "$failed"
