#!/bin/sh
set -eu
# Run from the repository root. Requires this project's Alire environment.
ROOT=/home/gtnoble/Projects/coyote/coyote-latex-math
EVIDENCE="$ROOT/plan/evidence/native-math-2026-11-15-array-rule-budget/lifecycle-experiment"
VARIANT=/tmp/math-shaping-fc-shutdown
CONTROL=/tmp/math-shaping-fc-original
cd "$ROOT"
mkdir -p "$VARIANT" "$CONTROL"
cp -a "$EVIDENCE/source/." "$VARIANT/source/"
cp -a "$EVIDENCE/source/." "$CONTROL/source/"
cp "$EVIDENCE/source/math_text_shaping_fc_shutdown.adb" "$VARIANT/source/math_text_shaping.adb"
cp "$EVIDENCE/math_shaping_lifecycle.gpr" "$VARIANT/math_shaping_lifecycle.gpr"
cp "$EVIDENCE/math_shaping_lifecycle.gpr" "$CONTROL/math_shaping_lifecycle.gpr"
# Ensure the GPRs use their own copied sources and separate build roots.
sed -i 's#External ("MATH_SHAPING_LIFECYCLE_ROOT")#External ("MATH_SHAPING_LIFECYCLE_ROOT")#g' "$VARIANT/math_shaping_lifecycle.gpr" "$CONTROL/math_shaping_lifecycle.gpr"
MATH_SHAPING_LIFECYCLE_ROOT="$VARIANT/build" alr exec -- gprbuild -p -P "$VARIANT/math_shaping_lifecycle.gpr"
MATH_SHAPING_LIFECYCLE_ROOT="$CONTROL/build" alr exec -- gprbuild -p -P "$CONTROL/math_shaping_lifecycle.gpr"
for name in shutdown original; do
   if [ "$name" = shutdown ]; then root=$VARIANT; else root=$CONTROL; fi
   for mode in measure draw; do
      for count in 1 10 100; do
         log="$EVIDENCE/$name-$mode-$count.log"
         rc=0
         valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all \
            --track-origins=yes --num-callers=40 --error-exitcode=99 \
            "$root/build/bin/math_shaping_lifecycle_probe" "$count" "$mode" \
            > "$log" 2>&1 || rc=$?
         if [ "$rc" -ne 99 ]; then
            echo "$name $mode $count: expected Memcheck exit 99, got $rc" >&2
            exit 1
         fi
      done
   done
done
