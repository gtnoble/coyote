#!/bin/sh
set -eu
printf 'display=%s\n' "$DISPLAY"
printf 'GDK_BACKEND=%s\n' "${GDK_BACKEND-}"
printf 'GTK_MODULES=%s\n' "${GTK_MODULES-}"
printf 'GTK_IM_MODULE=%s\n' "${GTK_IM_MODULE-}"
xprop -root _NET_SUPPORTING_WM_CHECK
prop=$(xprop -root _NET_SUPPORTING_WM_CHECK 2>&1)
case "$prop" in
  *"not found"*|*"no such atom"*) ;;
  *) printf 'WM_PROPERTY_PRESENT: %s\n' "$prop"; exit 92 ;;
esac
xdpyinfo | grep -E 'dimensions:|depth of root window'
export GDK_BACKEND=x11
unset WAYLAND_DISPLAY
cd /home/gtnoble/Projects/coyote/coyote-latex-math/test
exec ./bin/coyote_test
