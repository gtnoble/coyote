# R8: Session Store JSONL Format Compatibility

## Verdict
PASS_WITH_NOTES

## Summary
`LLM.Session_Store`'s native JSONL write path is compatible with the two in-tree readers reviewed here. `Create_Session` writes the native header shape that `Session_Lister.Parse_Session_File` explicitly accepts (`id`/`version`/`createdAt`/`workDir`), and `Append_Message` writes the exact role strings and content-block type strings that both `Session_Lister` and `Coyote_App.History` recognise (`user`, `assistant`, `toolResult`, and `toolCall`). Usage field names also match exactly (`input`, `output`, `cacheRead`, `cacheWrite`), and the native Unix-millisecond timestamps are accepted by the relevant reader paths. Two compatibility gaps remain: `Fork_Session` generates non-RFC-4122 fork UUIDs because it never forces the variant nibble into the `8`-`b` range, and the written `toolResult.toolName` field is always empty because the native message model does not preserve that value.

## Issues

### [MEDIUM] Forked native sessions do not generate RFC 4122 variant-correct UUIDv4 IDs
**Files:** `src/session_lister.adb:473-476`, `src/session_lister.adb:487-495`, `test/src/llm_session_store_tests.adb:448-473`

**Description:** `LLM.Session_Store.New_UUID` correctly masks both the version and variant bits, but `Session_Lister.Fork_Session` creates its replacement UUID by slicing a SHA-256 digest and only forces the version nibble to `4`. The first nibble of the fourth UUID group is copied through unchanged, so forked session IDs can have a variant nibble outside `8`-`b`. That violates the R8 UUIDv4 requirement for generated session IDs. Current in-tree readers treat UUIDs as opaque strings, so this does not break listing or rendering today, but it is still a real format-compatibility defect for any consumer that validates UUIDv4 shape.

**Evidence:**
```ada
      --  Derive a UUID from the SHA-256 of (source UUID / turn / clock).
      --  The first 32 hex characters are formatted as an 8-4-4-4-12 UUID
      --  with the version nibble forced to '4'.  Pi treats session UUIDs
      --  as opaque filename stems, so RFC 4122 variant bits are not set.
```
```ada
         return H (H'First      .. H'First +  7)
                & "-"
                & H (H'First +  8 .. H'First + 11)
                & "-4"
                & H (H'First + 13 .. H'First + 15)
                & "-"
                & H (H'First + 16 .. H'First + 19)
                & "-"
                & H (H'First + 20 .. H'First + 31);
```
```ada
            Assert (Fork_Id'Length > 0, "Fork_Session should succeed");
```

**Fix:** Force the UUID variant nibble in `Fork_UUID` exactly as `New_UUID` does, so the first hex digit of the fourth group is always `8`, `9`, `a`, or `b`. Then extend the fork-session test to assert length, hyphen positions, version nibble, and variant nibble on the returned `Fork_Id`.

### [LOW] `toolResult.toolName` is written as an empty string and is not preserved on reload
**Files:** `src/llm/llm-session_store.adb:387-438`, `src/llm/llm-session_store.adb:569-605`, `src/coyote_app-history.adb:187-193`, `test/src/llm_session_store_tests.adb:393-414`

**Description:** The native writer emits a `toolName` field on `toolResult` messages, but `Tool_Result_Object` never assigns `Tool_Name`, so every written line contains `"toolName":""`. The reload path also drops the field entirely because `LLM.Types.Tool_Result_Block` has no place to store it, and `Render_Session_History` keys tool results only by `toolCallId`. This does not break current rendering because the UI gets the visible tool name from the assistant-side `toolCall` block, but it means the native JSONL is not fully field-for-field compatible with the planned/pi `toolResult` shape.

**Evidence:**
```ada
   function Tool_Result_Object
     (Msg : LLM.Types.Message) return GNATCOLL.JSON.JSON_Value
   is
      Result       : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Content      : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Tool_Call_Id : Unbounded_String;
      Tool_Name    : Unbounded_String;
      Result_Text  : Unbounded_String;
      Is_Error     : Boolean := False;
```
```ada
         Result.Set_Field ("role", "toolResult");
         Result.Set_Field ("toolCallId", To_String (Tool_Call_Id));
         Result.Set_Field ("toolName", To_String (Tool_Name));
         Result.Set_Field ("content", Content);
         Result.Set_Field ("isError", Is_Error);
```
```ada
      Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String
            (Get_String_Field (Msg, "toolCallId")),
          Result_Text => Text,
          Is_Error    => Get_Boolean_Field (Msg, "isError")));
```
```ada
                           Tid    : constant String  :=
                             Get_String (Msg, "toolCallId");
                           Is_Err : constant Boolean :=
                             Get_Boolean (Msg, "isError");
```

**Fix:** Preserve the tool name in the native message model and populate it when the agent records tool results, then write that real value into `toolResult.toolName`. If the field is intentionally unused, document that the native format omits meaningful `toolName` data and adjust the compatibility claim accordingly. Add a regression test that inspects the raw JSONL line for a non-empty `toolName`.

## Confirmed Correct
- `Create_Session` writes the native header fields `version`, `id`, `createdAt`, and `workDir`, and `Session_Lister.Parse_Session_File` explicitly recognises that native shape via the `createdAt` path.
- The exact message role strings written by `Append_Message` match both readers: `user`, `assistant`, and `toolResult`.
- Assistant tool-call content blocks are written with type `toolCall` and an object-valued `arguments` field; `Coyote_App.History` reads exactly `toolCall` and `Get_Object (Block, "arguments")`.
- Assistant `usage` is written with the exact field names `input`, `output`, `cacheRead`, and `cacheWrite`; `Render_Session_History` restores token counts from those same names.
- Native header timestamps are written as Unix-millisecond integers in `createdAt`; `Session_Lister` reads them with `Get_Integer (Obj, "createdAt")` and formats them through `Format_Unix_Milliseconds`.
- Per-message timestamps are also written as Unix-millisecond integers. `Coyote_App.History` does not depend on them, and `LLM.Session_Store.Load_Messages` accepts either integer or string timestamps when reloading.
- `LLM.Session_Store.New_UUID` itself is RFC-4122-conformant: it masks the version nibble to `4` and the variant nibble to the `8`-`b` range before formatting.
- `Fork_Session`'s turn-counting logic recognises native direct-message lines via the same role strings (`user`, `assistant`, `toolResult`) that `Append_Message` writes, so native sessions can be forked without envelope conversion.
