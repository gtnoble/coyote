# Session JSONL: v1 compatibility and v3 Canvas images

Session files live under `~/.coyote/sessions/`. Readers support bare v1 messages and v3 message envelopes. A filename may be `<uuid>.jsonl` or have a timestamp prefix; Canvas identity is the UUID, not the timestamp or filename alone. The private editable workspace is `<uuid>.canvas` beside the resolved log.

A new v3 header is a `type: "session"` object with `version: 3`, `id`, ISO timestamp, and `cwd`. Coyote also preserves `createdAt` (Unix milliseconds) and `workDir` for compatibility. `parentSession`, `parentRelation`, `thinkingLevel`, and `sandboxProfile` are optional. Message lines have this shape (the PNG data is abbreviated):

```json
{"type":"message","message":{"role":"user","timestamp":1795262400000,"content":[{"type":"text","text":"Compare these drawings."},{"type":"image","media_type":"image/png","data":"…","width":800,"height":600,"drawingId":"55be8400-e29b-41d4-a716-446655440000","revisionId":"55be8400-e29b-41d4-a716-446655440001","label":"Drawing 1 / Revision 2"}]}}
```

`data` is canonical, padded base64 of the frozen PNG byte stream. The order of `image` blocks specifies the ordinals; the ordinals are not additional stored content. The paired drawing and revision IDs identify an editable revision in the current session (or in a fork that copied that revision). Inline PNGs allow replay without editable storage. A `toolResult` image remains a different kind of record and does not carry Canvas revision IDs.

Non-message records, including `model_change`, `session_info`, and `compaction`, remain separate. Compaction's `firstKeptMessageIndex` is a zero-based index into the history at that point, including any previous synthetic summary. Each replayed cut replaces the previous summary and retains the requested tail. Full graphical replay reads the original user records even when their PNGs are outside the model's retained tail.

Text-only legacy sessions are not rewritten merely to display them. The first image append takes the shared session writer guard, validates the legacy header and existing JSON record framing, stages the v3 log with the new record, and atomically replaces and syncs it. Compatible metadata and non-message records are preserved. Failed validation leaves the source log unchanged. A write with uncertain durability is not authorization to send. Image-bearing v3 turns are also synced before upload. A provider rejection after commit does not delete the user record.

New headers and forks sync their private staged file, publish it without
replacing an existing log, and sync its containing directory under the
session guard. A failure before rename leaves the target log unchanged. A
failure syncing the directory after rename reports a visible but unconfirmed
UUID; no fork Canvas is rolled back, and the current session is not switched
to that fork. Check the session list before retrying. This does not sync
ancestors of a newly created project session directory or make a blanket
power-loss guarantee for all session writes.

Canvas policy: up to eight images, 8 MiB per PNG, 16 MiB of PNGs per turn, and 32 MiB of serialized image-bearing provider request. Dimensions and encoded sizes are checked; there is no resized fallback. `--no-session` keeps new turns and drawings in memory. Do not include inline PNG data in log excerpts or diagnostic reports.
