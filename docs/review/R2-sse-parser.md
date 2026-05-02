# R2: SSE Parser Correctness

## Verdict
FAIL

## Summary
`LLM.SSE` is correct for the main LF-delimited happy path: it buffers partial chunks, waits for a blank-line terminator before returning an event, joins multiple `data:` lines with embedded newlines, skips `ping`, passes `[DONE]` through unchanged, ignores comment/`id:`/`retry:` lines, and `Reset` clears the buffered partial record. However, it does not handle CRLF-delimited SSE streams correctly. `Next_Event` looks only for `"\n\n"`, so a valid `"\r\n\r\n"` record separator is never recognized and the parser can stall forever on such servers. The current tests exercise only LF fixtures, so this failure mode is not covered.

## Issues

### [HIGH] CRLF-terminated SSE records are never recognized
**Files:** src/llm/llm-sse.adb:29-35, src/llm/llm-sse.adb:102-115
**Description:** The parser strips a trailing carriage return from individual lines, but it detects record boundaries using only `LF & LF`. A valid SSE stream using `\r\n` line endings produces `\r\n\r\n`, which contains no consecutive `\n` bytes. In that case `Next_Event` never finds a delimiter, returns `False`, and leaves the complete event buffered indefinitely. This violates the R2 CRLF requirement and can break streaming completely against servers that emit CRLF.
**Evidence:**
```ada
function Strip_Trailing_CR (Text : String) return String is
begin
   if Text'Length > 0 and then Text (Text'Last) = ASCII.CR then
      return Text (Text'First .. Text'Last - 1);
   else
      return Text;
   end if;
end Strip_Trailing_CR;
...
function Next_Event
  (P          : in out Parser;
   Event_Name :    out Unbounded_String;
   Data       :    out Unbounded_String)
   return Boolean
is
   Delimiter : constant String := ASCII.LF & ASCII.LF;
begin
   ...
   Block_End : constant Natural :=
     Ada.Strings.Fixed.Index (Buffer_String, Delimiter);
   if Block_End = 0 then
      return False;
   end if;
```
For input `"data: hello" & CR & LF & CR & LF`, `Index (..., LF & LF)` returns 0, so the record is never emitted.
**Fix:** Accept both `LF LF` and `CRLF CRLF` as record terminators, or normalize CRLF to LF before delimiter scanning. The simplest robust approach is to scan line-by-line and treat a blank line as a terminator after stripping an optional trailing `CR`. Add unit tests for CRLF-delimited `data:`, `event:`, and `[DONE]` records.

## Confirmed Correct
- For LF-delimited input, `Next_Event` does not return an event until a full blank-line terminator (`\n\n`) is present.
- `Feed` correctly accumulates partial chunks across multiple calls; a split record such as `"data: hel"` then `"lo\n\n"` is reconstructed as one event.
- `data:` field parsing correctly accepts both `data: {...}` and `data:{...}` because `Strip_Optional_Space` removes at most one leading space after the colon.
- Multiple `data:` lines in one record are concatenated with a single embedded newline, matching SSE semantics.
- `event:` lines set the returned event name, and records with only `data:` return an empty event name.
- `event: ping` records are consumed silently and do not leak through to callers.
- `data: [DONE]` is returned unchanged to the caller.
- Comment lines beginning with `:` are ignored because `Parse_Block` only handles `event:` and `data:` fields.
- `id:` and `retry:` lines are silently ignored, which is acceptable for this parser.
- `Reset` clears the parser's only internal state (`Buffer`), so buffered partial data is discarded completely.
