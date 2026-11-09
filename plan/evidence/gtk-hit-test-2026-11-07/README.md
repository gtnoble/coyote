# PCR-127 — hidden inline-math line-boundary hit testing

Evidence keyed to the 2026-11-07 crash report. Raw logs retain their original
host timestamps. GTK version tested: 3.24.41. Development profiles only.

## Cause and workaround

The user backtrace reaches `gtk_text_view_event`,
`gtk_text_layout_get_iter_at_position`, `line_display_index_to_iter`,
`gtk_text_iter_set_visible_line_index`, and `iter_set_from_byte_offset`.
The reported raw byte offset was 228 (earlier occurrence 220).

Upstream GTK 3.24.41 `gtk/gtktextlayout.c:2798–2808` uses the raw line byte
count in the below-layout branch, then calls a visible-byte converter.
`gtk/gtktextiter.c:3987–4004` skips invisible segments and can advance into the
following line while retaining an accumulated byte offset. Hidden math source
and a sufficiently short following line reproduce the fatal B-tree assertion.
Our native and application reproductions abort with byte index 23 instead of
228; the same failed invariant and conversion path are reproduced, not the
original complete desktop state.

Coyote now uses zero below-line pixels, retaining two above-line pixels.
This avoids that GTK branch for conversation line-padding hits. It does not
patch GTK or claim correctness for every GTK hidden-text configuration.
Inline source hiding, pixbufs, margins, copy/search and reflow are unchanged.

## Native reproducer

From the repository root:

```sh
cc -g -O0 -Wall -Wextra \
  plan/evidence/gtk-hit-test-2026-11-07/native-reproducer.c \
  -o /tmp/coyote-gtk-hidden-repro $(pkg-config --cflags --libs gtk+-3.0)
xvfb-run -a /tmp/coyote-gtk-hidden-repro 2 2
xvfb-run -a /tmp/coyote-gtk-hidden-repro 2 0
```

Arguments are above-line and below-line pixels. Expected on affected GTK:
(0,0) and (2,0) exit 0; (0,2) and (2,2) SIGTRAP/exit 133. The four
`gtk-hidden-*-*.log` files retain the measured matrix. The failing runs are
intentional reproductions. Native reproducer code is evidence, not a runtime
dependency or a new production C unit.

## Application regression and builds

```sh
alr build --development
cd test
alr build --development --profiles=coyote=development
xvfb-run -a ./bin/coyote_test \
  'Coyote.GUI.Conversation_Stack hit-tests inline math line boundaries'
xvfb-run -a ./bin/coyote_test 'Coyote.GUI.Conversation_Stack'
/usr/bin/time -f 'wall=%e user=%U sys=%S exit=%x' \
  xvfb-run -a ./bin/coyote_test
```

- Baseline with new test but old 2-pixel below padding: SIGTRAP, exit 133;
  `coyote-gtk-baseline-test.log`. Baseline build log is retained separately.
- Root and final test development builds pass, with existing warnings.
- Exact new test passes before strengthened line-center checks; final full
  suite includes those checks and the final focused repeat passes 1/1,
  8.840067 seconds cumulative, 8.92 seconds wall.
- Conversation-stack focused run passes 50/50, 24.172117 seconds cumulative.
  That run preceded the final line-center assertions; the final full suite
  exercises all 50 with those assertions included.
- Final full suite from `test/`: 1069/1069, zero failures/errors,
  142.032699 seconds cumulative, 142.11 seconds wall, exit 0.
- Earlier full run from repository root: 948 successful, 28 failed assertions,
  95 unexpected errors across 1069 cases, exit 1. Fixture-relative paths require
  the `test/` cwd; that run is retained as `coyote-gtk-full-suite.log`, not counted
  as passing evidence. The corrected run is `coyote-gtk-full-suite-correct-cwd.log`.

The new case waits for a real committed inline pixbuf and hidden source,
realizes the conversation widget, checks logical line-center hits, sweeps every
allocated y coordinate at four x positions, and repeats after reflow. Its
baseline crash demonstrates sensitivity to the original setting; it is not an
exhaustive pointer-event, font, theme, accessibility or native-math qualification.

Existing CSS theme warnings remain. No live-provider tests, installed-binary
update, release, or independent desktop acceptance was performed. Developer
self-evaluation/read-only agent review is not independent user acceptance.
`implementation.patch` identifies the production/test changes; `SHA256SUMS`
covers retained files other than itself. No saved conversations are archived.
