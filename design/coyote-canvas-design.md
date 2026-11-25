# Coyote Canvas Detailed Design (SDD-CANVAS)

- **Version:** 1.8
- **Date:** 2026-11-22
- **Status:** PCR-133 direct revision editing implemented and developer-tested; PCR-134 finger editing implemented and developer-tested; PCR-135 live Eraser implemented and developer-tested; formal qualification remains pending. Prior baseline acceptance remains dated 2026-11-21.
- **Parent:** [SDD-CORE §5.51](coyote-design.md#551-drawing-canvas-and-additive-cli-planned)
- **Requirements:** [SRS-CORE v1.42](../requirements/coyote-requirements.md), REQ-CORE-026–028 and 260–271.
- **Qualification:** [STP §4.6](../plan/test-plan.md#46-planned-qualification--drawing-canvas-and-subcommands-pcr-130), PCR-130–135.

## 1. Scope and decisions

The Canvas is an editable, session-scoped workspace for the root agent in a GTK conversation. The model still has one tool, `shell`. This design adds desktop image paste, Wacom Intuos and mouse drawing, a version tree, explicit crop, and ordered user-image prompts. It does not extend the Plain frontend or virtual-agent RPC to submit images. It does not change Markdown image rendering or image tool results. See SRS-CORE §2 for the applicable IRIX Interactive Desktop guidelines (SGI 007-2167-005).

The normal Canvas composite and the attached PNG have one authoritative pixel source. Zoom and pan affect display only. A deliberate crop changes drawing bounds before attachment; Attach and Send never crop, resize, recompress lossily, make a contact sheet, or omit an image to meet a limit. No separate outgoing preview is used. The guarantee ends at the provider request boundary.

## 2. Units and execution

Names for new units are allocation names, not claims that packages already exist.

| Unit | Interface and ownership |
|---|---|
| `Coyote_CLI` | First-argument dispatch; no frontend initialization. Shares the legacy listing formatter with the standalone executable. |
| `Coyote_Canvas.Import_Service` | Session-bound local import server and client protocol. Accepts bounded byte streams, not server-side paths. Owns validation jobs, request deadlines and result delivery. |
| `Coyote_Canvas.Document` | Widget-independent drawing, revision, draft, pixel rectangle and edit-command operations. Applies validated transactions to the session's drawing tree. |
| `Coyote_Canvas.Images` | Bounded native-resolution PNG/JPEG decoding, static SVG rendering, canonical composition and lossless PNG encoding. Returns immutable owned results, with no GTK widget dependencies. |
| `Coyote_Canvas.Store` | Session-local revision assets and manifests; ordered recovery writes, validated load, delete and fork support. |
| `Coyote_GUI.Canvas` | Co-primary window, Drawings tree, clipboard callbacks, stroke and crop interaction, and attachment commands. GTK main task owns this state and adopts worker results there. |
| Existing app, agent and provider units | `Prompt_Queue`, `Updates`, `Coyote_App`, `LLM.Agent`, `LLM.Types`, adapters, `Session_Store`, `History` and `Session_Lister` carry, serialize, restore and present typed user images. |

The GTK task alone publishes changes to the live document and composer. Bounded workers perform decode, SVG rasterization, PNG encoding and disk I/O using immutable inputs or owned buffers; the completion path returns typed results to the main task. The Canvas service does not use the agent prompt queue: a shell import can complete while the agent task is waiting for that shell call. The session writer is serialized per session and never runs in a draw or input callback. New Session, Switch Session, and application shutdown invalidate the session binding before new input is accepted; callbacks from the prior binding free their resources without adopting data. A Canvas close also invalidates widget-bound requests, but keeps the session document and permitted shell import target alive. An import while the window is closed is visible on next open and never opens it automatically.

## 3. CLI and local import protocol

`Coyote` dispatches `session` and `canvas` when either is the first argument, before ordinary launcher initialization. Absent a subcommand, the existing launch syntax and internal child-process flags retain their meanings. Group and leaf `-h`/`--help` return usage on stdout and exit zero. Missing/unknown subcommands, invalid flags and missing file operands produce stderr and a nonzero exit, with no launcher fallback. The optional `--` ends option parsing; arguments are passed as filenames, not evaluated as shell expressions by the CLI.

- `coyote session list` and `coyote_list_sessions` call the same listing and formatter. For the current CWD, output remains newest-first `UUID<TAB>name<TAB>date<TAB>snippet`, zero rows and status zero for an empty result. `coyote_sqc` stays separate.
- `coyote canvas add [--] FILE...` reads permitted regular files in the calling shell's context (relative names resolve against that invocation's CWD), checks size while reading, and uploads the bytes with a sanitized basename label. The GUI never opens a path from the client. Accept PNG, JPEG and self-contained SVG. Validate the whole batch before publication. Each file adds a new root with an Original in argument order, regardless of repeated names. A successful response lists name and stable drawing and Original revision IDs for each file. No attach, Send, selection change or focus change occurs.

Use a dedicated local Unix-domain socket in a private user runtime directory, not the virtual-agent RPC socket. Require both same-user peer credentials and a high-entropy, unlogged capability bound to this live root session binding. Supply the endpoint and capability only to eligible root `shell` invocations via their launch environment, not through process-global discovery, provider messages, the prompt-filter environment or virtual-agent/physical-window startup. The provider request adds the shell-quoted startup executable path and import syntax only when the root session has Canvas import, the model has tools, and the path still names an executable regular file. A separate note describes Attach → Send for GUI root sessions with image-capable models, even if tools are disabled. The import note grants no editing or sending capability. Do not make a sandbox-blocked endpoint available by widening its profile; fail with an unavailable-target diagnostic. Invalidate the capability on session replacement or exit; never infer a target from CWD, newest session, a requested UUID or presently selected agent.

The v1 request has one `add` operation, a request ID and an ordered file count. Each file has a bounded UTF-8 label, declared byte length and binary bytes. The header has a version and capability; length fields are unsigned, checked before allocation and encoded in network byte order. The result is a bounded response with status and ordered IDs or an error identifying the failing file. Authenticate before accepting image data; reject invalid headers, counts, truncated streams and unexpected trailing data. Use finite read/write deadlines, bounded concurrent requests, per-file and aggregate byte reservations, and one batch commit on GTK adoption after rechecking the binding. For a persisted session, acknowledge success only after its batch manifest is committed. Validation failure leaves no published roots. Cache terminal dispositions by binding and request ID for the service retry window, so retrying a lost acknowledgement with the same ID does not add duplicates; if no disposition can be confirmed, report the outcome as unknown rather than silently retrying as a new command. Protocol widths, timeouts and retry-window values are implementation constants to confirm before protocol freeze.

## 4. Canvas window and interactions

### 4.1 Window, selection and edit routing

**View → Canvas** shows one resizable, modeless `coyote : Canvas` co-primary. It has standard desktop decorations and placement, a labeled Drawings tree to the left, drawing area and scrollbars, a contextual control strip and a bottom status area. Keep tree selection, displayed revision, active working copy, and composer attachments distinct. Single-row selection and **Show in Canvas** display the exact saved revision without replacing or discarding any working draft; replay follows the same rule. Multi-selection remains standard discontiguous tree selection. There is no **Edit Revision** action. When the displayed revision is writable and **Show Markup** is on, Pencil, Eraser, and Crop are enabled. The first completed pointer/finger stroke or **Apply Crop** creates or activates a working copy based on that displayed revision. Applying an identity crop does not switch the working copy. Before switching from a different dirty working copy, checkpoint it as a child revision of its own base; if checkpointing fails, leave the display/edit state unchanged and do not apply the requested edit. Unfinished or canceled gestures/crops, browsing, pan, zoom, and Fit do not switch or mutate drafts. Keep text state indicators distinct for selection, displayed revision/draft, and editability.

| Menu | Initial commands and focus rules |
|---|---|
| File | **New** (`Ctrl+N`), **Import…** (modeless File Selection), **Save** (`Ctrl+S`) creates an immutable child revision for changed content and is a no-op for unchanged content; **Close** (`Ctrl+W`; hides the Canvas without discarding drawings or recoverable drafts). |
| Selected | **Attach** for selected revisions in visible tree order or the active working copy when acting in the drawing area. A bottom-right **Attach** button in the status area runs the same command without changing the attachment target when it takes focus. Dim unavailable actions, do not remove them. |
| Edit | Mutually exclusive **Pencil**, **Eraser**, and **Crop** radio choices, synchronized with the icon buttons below the menu bar; **Pencil** is the default. The editing icons and matching menu items are enabled when the displayed drawing is writable and **Show Markup** is on, including saved revisions and while a crop is pending; otherwise they are disabled. **Apply Crop** alone commits the pending crop; switching to a drawing tool discards it. **Apply Crop**, **Cancel**, and `Escape` return to the drawing tool selected before Crop. Also **Undo** (`Ctrl+Z`), **Redo** (`Shift+Ctrl+Z`), and **Paste** (`Ctrl+V`) in drawing context. Focused editable text fields retain ordinary text editing and paste. |
| View | **Fit**, **Zoom In/Out**, **Actual Size**, and a stable checkbox **Show Markup**; all display-only. **Fit** selects a uniform zoom for the current viewport and displayed draft or revision, up to 400%. It clears panning, preserves a pending crop, and is disabled without a drawing or during an active gesture. |
| Options | **Edit with Finger** toggles touchscreen Pencil/Eraser input for the current session; off by default. |
| Help | Canvas Overview, tasks, Index, Keys & Shortcuts, Product Information and Click for Help using the existing desktop Help path. |

The **Zoom In** and **Zoom Out** magnifier icons select display-only modes.
A primary mouse click or pen tap on the drawing changes scale by one step
and keeps that point under the pointer where the scroll bounds permit. The
**View** menu retains immediate zoom steps about the viewport center as a
keyboard-accessible alternative. A magnifier suspends the editing tool and
any pending crop; `Escape` resumes it without reverting the zoom. The zoom
controls also work on saved previews and with **Show Markup** off, but are
unavailable during a live ink stroke or crop drag. Over the drawing, pen
side buttons reported by GTK as buttons 2 and 3 take one anchored zoom-in
or zoom-out step on press. This always-available shortcut does not select
a magnifier, take focus, or change a pending crop. It has no effect while
Click for Help is armed and does not consume mouse buttons.

Give entries mnemonics, preserve native Tab/tree traversal, use the primary action button or pen tip for drawing/crop, and keep the right button for a shortcut menu that duplicates menu actions. Do not change pointer mapping or force focus across windows. Indicate editable/draft/read-only/sent state in text, not color alone. Scope text paste and standard accelerators to the focused context. Use the status area for successful background work, an explanatory dialog for empty or invalid clipboard paste, and a cancellable Warning before discarding draft edits; switching from a pending crop to a drawing tool discards that pending crop without applying it. Agent additions use only the status area and never change focus or selection. No tool keyboard shortcuts are assigned; native Tab and arrow navigation operate the toolbar, and Edit mnemonics remain in effect.

### 4.2 Input and clipboard

For a Wacom Intuos Small Bluetooth (CTL-4100WL) on X11 with its
standard button mapping, the fourth (far-right) ExpressKey reports
button 8. Recognize it only from a tablet pad with the matching Wacom
vendor and model IDs, never from an ordinary mouse. Holding `F8` in the
Canvas window is the fallback for other driver mappings. Canvas does not
change the tablet's desktop settings.

When either control is held **before** pen tip-down, capture the gesture
as viewport pan before routing to ink, crop, or the magnifier. The pen
moves the two scroll adjustments using root-coordinate deltas, clamped
by the viewport. Do not edit pixels, pressure samples, zoom, history,
selection, or a pending crop. Read-only views and hidden markup can pan.
If the modifier is released first, stop panning but consume that pen
contact through tip-up; if the tip comes up first, the held modifier may
pan again. Escape stops the pan without discarding a crop. Focus loss,
a broken grab, tablet removal, and window/session transitions clear
pan state. Ignore a pan modifier pressed after a stroke has begun.

Use `Gtk.Drawing_Area`, Cairo and GDK events through GtkAda. Distinguish pen
and mouse; test pressure-axis availability at runtime. Keep separate
session-local Pencil and Eraser sizes, each 1–64 source pixels, defaulting to
3 and 16 at session start. Capture the active size at mouse, pen, or eligible
finger gesture begin and keep it fixed through the gesture. Pen pressure, if
available, changes only alpha deposited by Pencil marks, never width. Mouse,
finger, and pen without usable pressure deposit opaque Pencil marks. Eraser
removes ink only, independent of pressure. A recognized GDK eraser tip
overrides the selected tool for the gesture, using captured Eraser size
without changing selection; Crop takes precedence. Place Pencil marks at
fixed distance intervals along the path and interpolate opacity. Retracing
within a gesture deposits ink again; one complete gesture is one ordered
undoable edit. Use the same stroke rasterizer for preview, committed
rendering, and replay. Lost capture, device removal, or window/session change cancels an
unfinished pointer gesture. Suppress duplicate emulated mouse delivery.
Physical-device and performance qualification remain pending.

**Edit with Finger** is session-local and off by default. Use the drawing
area's GTK `touch-event` with `Touch_Mask` and existing first-contact sequence
handling. Eligibility is determined at touch begin: option on, contact begins
in the drawing area, displayed drawing writable, Show Markup on, and selected
tool Pencil or Eraser. Capture the operation and corresponding session size at
begin, retain through end/cancel, ignore additional contacts, and do not
transfer the sequence. Finger Pencil uses the captured size and opaque alpha;
Finger Eraser uses the captured Eraser size, removes ink only, preserves the
background, and ignores pressure/contact size. Ineligible contacts cannot
become later drawing gestures. Disable GTK kinetic scrolling while finger
Pencil/Eraser input is available; otherwise leave ordinary touch panning
available. Consume touch events to prevent emulated pointer input. Do not
change mouse/pen handling or scroller behavior for mouse, pen, Crop, or Zoom.
Lift commits one undoable edit. Cancellation, lost capture, option disable,
window close, or session change discards the unfinished operation through
shared gesture cancellation. Add no persisted preference, raw-device access,
permissions, input model, or device dependency.

**Eraser preview and composition.** For mouse, pen (including recognized
eraser override), and eligible finger erasing, show immediate ink-only
removal in a transient preview with the captured round brush and matching
cursor guide. Use the same round eraser segments and pixel rules for
preview, committed composition, and replay. Cache a premultiplied ARGB32
ink layer, keep the background separate, and never erase it. A separate
transient surface represents the displayed extent; update dirty rectangles on
subsequent redraws. Canonical output, saved revisions, staged attachments and
authoritative PNG remain unchanged until release commits one ordered,
undoable edit. Cancel or lost eligibility discards preview and restores ink
without an edit or revision switch; if preview is unavailable, show the
canonical surface and guide rather than partial output. Legacy strokes replay
exactly as encoded in Canvas manifest versions v2–v4; v5 stroke markers
identify color and rendering mode, and samples are `[X,Y,Width,Alpha]`.
The toolbar Pencil swatch sets RGB for future strokes; changing it is not
an edit. See SDD-CORE §5.51 for
manifest serialization.

On an explicit Canvas image Paste, asynchronously request desktop `CLIPBOARD` targets, taking PNG when offered, otherwise JPEG. Do not fall back to text, paths, URLs or `PRIMARY`, and do not change either selection. Use GtkAda `Request_Contents`, not `Wait_For_Image` or GTK's already-decoded image callback. Validate status, MIME/signature and encoded length before copying callback-owned bytes; preflight decoded dimensions before full worker decode. This bounds application-owned buffers and decode work; it does not claim to cap buffering already performed by GTK's clipboard transport. On success, create exactly one new **Clipboard Image** root with its own Original and owned pixels. On failure, leave the document and composer unchanged and report the reason. Bind the request to a Canvas-window generation, session generation and request serial; replacement by a newer paste, Canvas close, or session switch invalidates the request even if the same session reopens. Do not read the clipboard on focus, polling, or agent request. Never include clipboard bytes in diagnostics or debug logs. The ordinary local drawing store is distinct from diagnostics; the model receives no pasted data unless the user separately attaches and sends it.

### 4.3 Crop operation

**Crop** in the synchronized toolbar or Edit radio group starts a pending crop bound to the displayed revision or active working-copy ID and content generation in the normal editing view. On Apply from a saved revision, begin a working copy from that exact revision; checkpoint any different dirty working copy as a child of its own base first, and do not apply if that checkpoint fails. Draw a rectangle with pen tip or mouse, move it from the interior, and resize with edge/corner handles. Ignore pressure; use crosshair, move and resize pointers as appropriate. Draw the border and excluded-area dimmer as overlays and show resulting pixel dimensions. Labeled `X`, `Y`, `Width` and `Height` integer fields permit exact keyboard input, with separate **Apply Crop** and **Cancel** buttons. Keyboard entry and pointer changes share the same validation; invalid or empty bounds disable Apply.

Use the menu or toolbar to switch away from a pending crop; selecting Pencil or Eraser discards the pending rectangle without applying it. Only **Apply Crop** commits the crop. **Apply Crop**, **Cancel**, and `Escape` return to the drawing tool selected before Crop. The editing icons and Edit radio group remain enabled when the displayed drawing is writable and **Show Markup** is on, including a saved revision and during a pending crop; otherwise the editing choices are disabled. There are no Crop/tool shortcuts. Native Tab and arrow keys navigate the toolbar; Edit menu mnemonics are retained.

Represent the rectangle by half-open pixel edges `[left, right) × [top, bottom)` in the pre-crop draft. Invert the display transform exactly once, including pan and zoom (convert device pixels to widget coordinates first only when applicable). Round pointer edges to the nearest pixel edge, ties toward the larger coordinate, then normalize reverse drags and clamp to the current image. Moving preserves size and clamps the origin; exact numeric entries outside the image are rejected rather than rounded. Zero-area and identity crops do not create edits. On Apply, recheck the bound draft and generation, clip the background and ink together and translate the retained region to origin without resampling. Implement clipping as a stored source-coordinate extent, not a destructive rewrite of background or strokes; rasterize with the original pixel-grid phase so the retained composite equals the source subrectangle. Undo restores the prior extent and Redo reapplies the same rectangle. Escape, Cancel, lost capture during an unfinished drag, selection that changes the displayed drawing, and closing or switching the session cannot apply a crop. Save or Attach never applies a pending crop; block those actions during the crop transaction. An applied crop is one working-copy edit, not its own revision until checkpointed.

## 5. Drawing data, composition and storage

### 5.1 Data and edit model

`Drawing_Id` and `Revision_Id` are stable opaque UUIDs within a session. Each drawing owns a root and immutable revisions with one optional parent (none for Original), display label, dimensions/time/provenance, a background asset, editable ink operations, and an integer pixel extent. A working copy has the same content shape, an exact base revision ID, generation and its own Undo/Redo stacks. A completed edit on a displayed saved revision creates/activates its working copy from that revision only then; merely displaying or selecting it never changes another working copy. A new edit clears that working copy's redo path, not saved branches. File → Save creates an immutable child revision under the working copy's exact base when content changed; unchanged content creates no duplicate. On successful save the working copy's base advances to the new child. Before an edit switches from a different dirty working copy, checkpoint it as a child of its own base; on failure do not perform the switch/edit. Recovery writes retain the latest draft without visible revision nodes; recovery need not reconstruct in-memory Undo/Redo. A sent marker can be derived from recorded revision references; it does not revise the drawing.

The flat PNG/JPEG decoder has a geometry ceiling of 8,192 pixels on either side and 33,554,432 pixels per image. Durable direct file imports can fall back to the tiled decoder when geometry exceeds the flat ceiling. Preflight both dimensions and checked pixel area before full decode. A direct regular PNG/JPEG file is streamed in bounded chunks and has no encoded-byte ceiling; clipboard and agent encoded-input byte ceilings remain unchanged. SVG retains its separate 8 MiB input and 16,777,216-pixel render-area limits. Keep alpha where present and decode at source dimensions; never automatically resize an accepted import. Close or session change cancels direct reads at chunk boundaries and prevents publication of a partial or stale batch. This bounds the application input buffer, not native decoder allocations. For SVG, render once with librsvg using bounded in-memory input and its existing input/render ceilings, without a base URI or unlimited parser flags. Permit only self-contained static SVG; reject unsupported external references, scripting and unsafe or indeterminate dimensions. Use explicit positive intrinsic pixel dimensions when resolvable at a fixed 96 DPI; otherwise require a finite positive `viewBox` and use its width and height rounded up to pixels, or reject if neither is usable. Store the imported raster as the authoritative background; retain SVG source as a separate local asset if needed for provenance, never as a live path. Do not rerasterize SVG for display at zoom or for replay. Use the existing bounded decoder/worker pattern without the Markdown thumbnail scaling policy.

For recovery and decoded residency, allow a 128 MiB raw-raster ceiling per image, a 128 MiB aggregate decoded-import-batch ceiling, and a 128 MiB live-workspace decoded-raster ceiling. These are separate checks; the per-image allowance does not expand the batch or workspace allowance. Native decoder, composition, display-cache, encoding, and concurrent-job allocations can make process peak memory larger than 128 MiB; no whole-process peak-memory bound is claimed.

Render editable ink with Cairo onto a transparent layer in the original pixel-grid phase. Blend the covered pixels over the straight-alpha background with deterministic source-over rounding; copy the background RGBA unchanged wherever the ink has zero coverage. This avoids losing low-alpha or transparent pixel values in a Cairo premultiply/unpremultiply round trip. The resulting straight-alpha RGBA is the canonical buffer. GTK displays it with view transforms; PNG encoding uses that same buffer. Markup-hidden and pending crop overlays are not part of it. Equality means decoded canonical RGBA, not window screenshots, screen scaling, or source encoding metadata. Verify an applied crop against the exact subrectangle of the pre-crop composite, including edges and partially transparent ink. Keep a bounded cache of needed composites and release worker/Canvas references when no longer in use.

**Disk-backed raster implementation (PCR-137).** The first increment adds
`Coyote_Canvas.Tiles`: read a regular PNG or JPEG descriptor into a private,
empty staging descriptor without changing either offset. The v1 format stores
straight RGBA in packed 256 × 256 tiles with unpadded edges. A 16-byte header
contains the format version and source dimensions. The caller's disk budget
includes that header. The backend's 32,768-pixel side guard keeps a complete
tile band at or below 32 MiB, separate from codec and runtime allocations.

Decode PNG, including Adam7, and single-scan grayscale/RGB JPEG. Restore
previous tile rows from disk for subsequent Adam7 passes. Progressive,
multiscan, and CMYK/YCCK JPEG are not supported by the tiled backend;
those encodings must fit the flat decoder. Import checks cancellation between
reads, rows, and tile-band writes; never use failed staging. Inspect checks
layout and size, not the pixel digest. The decoder stages assets without
publishing them; the session store handles publication and sync.

The workspace store publishes immutable `<sha256>.tile` files before the
manifest. Its `assets` array uses `{ "tileV1": "<sha256>" }` for a tiled
Original and retains digest strings for legacy flat RGBA. Load checks the
file layout, dimensions and full digest using bounded I/O before adopting
the workspace. Fork holds the source session guard until selected tiles
are copied. Reclaim protects both kinds by their exact filenames. The
legacy raster-only reader refuses tiled manifests rather than substituting
blank pixels.

The GTK file picker stages tiled assets on the import worker for durable
sessions, with up to 2 GiB of tiled staging per batch and a 32,768-pixel
side ceiling. The recovery worker publishes assets and the manifest before
adopting a mixed batch. A failed batch may leave unreferenced files for
explicit reclaim but adds no visible Originals. Clipboard, agent transport,
and `--no-session` retain their separate flat limits.

Fit selects a scale, not a rendering mode. Manual Zoom Out can return to
Fit when Fit is below the ordinary 25% floor. For tiled Originals, choose
the coarsest power-of-two level that supplies at least one sample per
physical display pixel. Read and compose only a viewport window plus a
small margin, with a 4 Mi-pixel and 4,096-pixel-per-side cap; exceptionally
large viewport windows can use a coarser level to meet these bounds.

A worker generates reduced background levels on first use with an
alpha-weighted 2× box filter and bounded tile scratch buffers. Completed
levels for one Original per Canvas occupy private unlinked temporary files.
They use roughly one third of the Original's tile bytes for a square image,
subject to rounding on odd edges. The first reduced request streams the
Original once; later zoom and pan requests reuse the generated levels.
A stale frame may remain visible only over its existing coverage while a
current request runs. Discard stale results; do not restart same-Original
level generation on every zoom step. Close or session reset releases the
cache. No derived pixels are published to the session store.

Reduced ink is replayed in source coordinates at the level's scale, clipped
to the revision bounds. For level cells split by a crop edge, substitute a
native sample from inside the crop, so discarded pixels do not bleed into
an edge. At level zero use the canonical compositor. Tiled Eraser shows a
guide during a gesture and renders the result on commit.
A crop that fits the unchanged attachment budget reads only intersecting
tiles and encodes its native extent. Attachment encoding still runs on GTK.

The native check is `sh test/tools/check-canvas-tiles.sh`. Its `--large`
case imports a 20,000 × 20,000 PNG and reads the resulting tiles under a
128 MiB process address-space limit. This tests the backend, not whole-Canvas
memory or interactive performance.

### 5.2 Persistence and recovery

Use a session-private sibling directory derived from the resolved session file, keyed by session UUID, not user paths or labels. A versioned `canvas.json` manifest records ordered roots, revision records, immutable asset IDs and the latest recovery drafts. Assets are immutable, addressed by a digest of their bytes; validate names, format/dimensions, digests and bounded ancestry on read. Use private file/directory permissions. Publish referenced assets first, then replace a flushed manifest atomically and synchronize directory metadata; commit multi-file imports in one manifest update. Use one exclusive writer lock per durable session for both manifest commits and JSONL writes, including conversion, fork publication on the destination, and deletion. Separate windows reopening the same UUID cannot clobber each other; another opener may read, but cannot append while the lock is held. On lock failure keep existing data intact and reject writes with an explanation. Do not publish a saved revision or acknowledge a persisted import before its commit. Recovery ignores temporary files or unreferenced assets left by interrupted writes; only reclaim assets after verifying they cannot be needed by a valid manifest. A failed load never silently substitutes the latest revision. With `--no-session`, use memory only for the Canvas store and attachments, including recovery drafts.

For image-bearing turns, use the SRS v3 message envelope with ordered `image` content blocks on `role: user`. Unlike an image tool result, these are typed user content. In persistence each block contains `type: "image"`, `media_type: "image/png"`, `data` (base64 of the submitted PNG), `width`, `height`, `drawingId`, `revisionId` and a label snapshot. Position in the image sequence defines its ordinal. The manifest and assets hold the editable drawing; inline PNG keeps replay independent of the Canvas cache or editable assets. A changed working copy must be saved as an immutable child revision, and the Canvas manifest commit must complete before that revision is staged; unchanged content creates no revision node. The user record must be durably written before the provider call starts. An interrupted record must not appear as a successful replay or become a partial provider request. If the editable asset cannot be loaded but the PNG is valid, show it and explain why Show in Canvas is unavailable. If an image block itself is missing or corrupt, surface the record error; do not send a reduced turn.

The writer now creates v3 headers and envelopes. The first image append to
an existing v1 log performs validated conversion and includes the new record
in the same guarded atomic replacement. The writer preserves existing header
metadata, IDs, message order, and non-message records; refusals retain the
composer draft. See [JSONL session format](../docs/session-format.md) for the
implemented schema and compatibility boundaries.

Fork keeps the existing conversation cut semantics. If it copies image-bearing turns, it also copies each referenced editable revision, its ancestors and needed assets into the destination store before publishing the fork. IDs are interpreted in the destination session; subsequent edits do not change the source. Do not copy unsent drafts or unrelated drawings into the fork. Fail the fork before publication if required assets are unavailable, rather than leaving broken links. Deleting a session removes its private Canvas sidecar as well as its session file under the same writer ownership; it cannot remove a different session's fork assets. Closing Canvas or compaction is not deletion.

Explicit maintenance can inspect or reclaim unreferenced raster files in a
validated Canvas store, or remove a logless sidecar in a separate mode. It
serializes with workspace recovery, publication and fork/deletion and never
runs on ordinary Open or Save. See [SDD-CORE §5.51](coyote-design.md#551-drawing-canvas-and-additive-cli)
for the validation and durability boundary.

## 6. Attach, queue, provider and replay

1. **Attach:** Resolve selected revision IDs in visible tree order, or checkpoint the changed active working copy as an immutable child revision before staging it. A displayed saved revision shown for browsing is attached as that exact revision; display alone does not create a working copy or revision. Validate that the pane is in the normal view (no pending crop, comparison or markup hiding). Preflight the output extent before rendering: attachments retain an independent ceiling of 8,192 pixels per side and 16,777,216 pixels per image. Reject a larger extent and suggest cropping; do not automatically resize. Encode the canonical composite losslessly to PNG with original resulting dimensions under the existing encoded-byte limits and stage each batch atomically. Staging copies or retains immutable bytes, label, dimensions and exact IDs. The composer presents numbered names and IDs with keyboard-accessible Move Up, Move Down, Remove and Show in Canvas; numbers reflect the current order. It states provider upload and applicable retention on Send. Later edits, Undo, or model selection cannot mutate staged bytes.
2. **Send:** Build a typed prompt from the text and an ordered vector of snapshot references. Use a session/target generation, request ID and bounded aggregate byte accounting in addition to the existing item-count cap. Check the current target, adapter and known limits before enqueue; an unsupported target or full queue leaves the draft intact. Apply any prompt filter to the text only; image-only is valid. A local busy item queues for the next turn. Associate the pending composer contents with the command until final preflight and handoff, using the request ID to avoid clearing newer text or attachments. On agent dequeue, recheck the target and the actual adapter/limits for the entire request, including retained images. Reject stale bindings and newly incompatible targets; retain the original combined draft intact for its owning session, not a different session. On a known provider rejection of the submitted images, expose the complete rejected draft for correction without overwriting newer composer content. If a user record is already committed, keep it as recorded, report the failed request and do not automatically retry or mark it delivered. Revalidate against provider selection on subsequent requests as needed. Do not drop images from old retained turns to send text to an incompatible target; show the conflict and allow a compatible model or a fresh session.
3. **Wire:** Keep bytes immutable and encode at the adapter boundary. Put the optional typed text and image parts in one user message in composer order; include short ordered `Image N` text markers adjacent to image parts as the stable user/model reference, separate from the text filter and never substitute labels for pixels. `LLM.Agent`, `LLM.Types`, and adapters do not depend on GTK. Router adapters use the actual wire delegate and only advertise support when the selected model and that delegate allow user images. Preflight uses the encoded request/parts as applicable, not only raw PNG size. Local and known provider limits are reject-only, and a provider request rejected for its image contents must not trigger a text-only fallback.

| Wire | User text and ordered image representation |
|---|---|
| OpenAI Responses | One `role: user` item with `input_text` and `input_image`; the latter has `image_url` as a PNG data URL. |
| OpenAI Chat Completions | One `role: user` message with content-array `text` and `image_url` parts; `image_url.url` is a PNG data URL. |
| Anthropic Messages | One `role: user` message with `text` and `image` blocks; each image source has `type: "base64"`, `media_type: "image/png"`, and PNG base64 `data`. |

Replay reads the exact stored PNGs, showing the same image order and numbering and resolving **Show in Canvas** against the recorded revision IDs. Full conversation replay is independent of the in-memory compaction tail. Compaction places bounded numbered attachment markers in summarization text for images outside the retained tail (no base64 transcript dump) and preserves full user-image blocks in the retained tail. Serialization never projects an image-bearing message onto text before capability checks. Plain/SQC may show a descriptive image marker in history but do not expose Canvas attachment submission.

## 7. Operating limits and qualification

Use separate explicit budget checks for encoded import bytes, dimensions/pixels, decoder/render work, live Canvas buffers, staged/queued PNG bytes, stored sizes and serialized request size. Check multiplication/addition before allocation. Preflight headers before full decode and cap worker count and outstanding jobs. Discard late results; do not claim cooperative cancellation can preempt a native decoder. Reuse the existing resource/job ownership patterns, not their thumbnail dimensions. Set quantitative Canvas budgets and error messages before implementation qualification using representative full-resolution screenshots and SVGs; an oversized but otherwise valid input is rejected rather than shrunk. Confirm backend-specific clipboard behavior with both actual desktop producers and synthetic fixtures. The existing Xvfb clipboard and composition probes are feasibility evidence only, not acceptance.

| Requirements | Design allocation | Planned verification |
|---|---|---|
| REQ-CORE-026–028, 267 | §3 local CLI/import; §2 ownership; §5 decode and persistence | CAN-CLI-01, CAN-IMPORT-01; wrong credential, denied read, generation change, mixed batch, lost acknowledgement. |
| REQ-CORE-260–262 | §4 window and input; §5 revisions | CAN-GUI-01, CAN-DATA-01; actual Intuos, focus, older base/branch, recovery without source. |
| REQ-CORE-261 (live Eraser) | §4.2 input and preview; §5.1 data/composition | CAN-GUI-01, CAN-TOUCH-01; transient-to-canonical comparison, exact committed pixels, crop and alpha preservation, cancellation and performance; physical-device/performance qualification pending. |
| REQ-CORE-263–266 | §5 persistence, §6 send/replay | CAN-DATA-01, CAN-LIMIT-01; native pixel comparison for three wires, model switch, compaction, corrupt records, fork and no-session. |
| REQ-CORE-270 | §4.2 clipboard, §5 bounds/recovery | CAN-CLIP-01; real and synthetic owners, malformed offers, delayed results, and exact alpha/dimensions. |
| REQ-CORE-271 | §4.3 crop; §5.1 composition; §6 freeze | CAN-CROP-01, CAN-CROP-02; pressure-independent drag, zoom/scale invariance, keyboard, cancellation, edge pixels and saved crop replay. |
| REQ-CORE-268–269 | §8 follow-on | CAN-FOLLOW-01; compare and explicit parent linkage. |

Stage implementation as: (1) compatibility CLI and deterministic document/pixel primitives, (2) local workspace, import/clipboard and crop with recovery, (3) typed prompt and provider/persistence/replay round trip. Qualification includes the physical Intuos demonstration and offline capture of ordered, pixel-exact provider requests. No runtime pass or independent acceptance is established by this design.

## 8. Follow-on design

**Selected → Compare** opens a read-only split inside the same Canvas for exactly two revision IDs, with linked zoom and pan and independent image extents. It cannot change drafts or staged data. Disable attachment while comparison is displayed. A later explicitly authorized `canvas add --from-revision ID -- FILE` operation uses one file and resolves the base only in the bound session; it records agent provenance and adds a child without changing the user draft. Default `canvas add` still creates roots. Both follow-ons reuse existing revision IDs and remain outside the initial qualification gate.
