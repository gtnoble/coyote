--  Coyote_App.Utils — pure utility functions shared by Coyote_App.
--
--  All subprograms in this package take only plain parameters and have no
--  dependency on App_State or Acme.Window.  They may be tested in
--  isolation without a live acme session.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with Session_Lister;
with GNATCOLL.JSON;
with Nine_P;

package Coyote_App.Utils is

   --  ── UTF-8 pseudographic constants ────────────────────────────────────
   --  Each constant holds the UTF-8 byte sequence for one Unicode character.

   UC_BULLET : constant String :=  --  ●  U+25CF
     Character'Val (16#E2#) & Character'Val (16#97#) & Character'Val (16#8F#);
   UC_DBL_H  : constant String :=  --  ═  U+2550
     Character'Val (16#E2#) & Character'Val (16#95#) & Character'Val (16#90#);
   UC_BOX_V  : constant String :=  --  │  U+2502
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#82#);
   UC_BOX_TL : constant String :=  --  ┌  U+250C
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#8C#);
   UC_BOX_BL : constant String :=  --  └  U+2514
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#94#);
   UC_BOX_TR : constant String :=  --  ┐  U+2510
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#90#);
   UC_BOX_BR : constant String :=  --  ┘  U+2518
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#98#);
   UC_BOX_T  : constant String :=  --  ┬  U+252C  (top T-junction)
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#AC#);
   UC_BOX_B  : constant String :=  --  ┴  U+2534  (bottom T-junction)
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#B4#);
   UC_BOX_L  : constant String :=  --  ├  U+251C  (left T-junction)
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#9C#);
   UC_BOX_R  : constant String :=  --  ┤  U+2524  (right T-junction)
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#A4#);
   UC_BOX_X  : constant String :=  --  ┼  U+253C  (cross junction)
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#BC#);
   UC_GEAR   : constant String :=  --  ⚙  U+2699
     Character'Val (16#E2#) & Character'Val (16#9A#) & Character'Val (16#99#);
   UC_CHECK  : constant String :=  --  ✓  U+2713
     Character'Val (16#E2#) & Character'Val (16#9C#) & Character'Val (16#93#);
   UC_CROSS  : constant String :=  --  ✗  U+2717
     Character'Val (16#E2#) & Character'Val (16#9C#) & Character'Val (16#97#);
   UC_TRI_R  : constant String :=  --  ▶  U+25B6
     Character'Val (16#E2#) & Character'Val (16#96#) & Character'Val (16#B6#);
   UC_WARN   : constant String :=  --  ⚠  U+26A0
     Character'Val (16#E2#) & Character'Val (16#9A#) & Character'Val (16#A0#);
   UC_ELLIP  : constant String :=  --  …  U+2026
     Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#A6#);
   UC_HORIZ  : constant String :=  --  ─  U+2500
     Character'Val (16#E2#) & Character'Val (16#94#) & Character'Val (16#80#);
   UC_RETRY  : constant String :=  --  ↻  U+21BB
     Character'Val (16#E2#) & Character'Val (16#86#) & Character'Val (16#BB#);
   UC_HOOK_L : constant String :=  --  ↩  U+21A9
     Character'Val (16#E2#) & Character'Val (16#86#) & Character'Val (16#A9#);
   UC_MICRO  : constant String :=  --  µ  U+00B5
     Character'Val (16#C2#) & Character'Val (16#B5#);
   UC_ARROW_D : constant String :=  --  ↓  U+2193
     Character'Val (16#E2#) & Character'Val (16#86#) & Character'Val (16#93#);

   --  ── String utilities ─────────────────────────────────────────────────

   --  Repeat string Text exactly N times.
   function Str_Repeat (Text : String; N : Positive) return String;

   --  Natural'Image without the leading space.
   function Natural_Image (N : Natural) return String;

   --  Format a token count with an appropriate SI prefix.
   --
   --  Returns the raw decimal integer for N < 1 000; appends "k" for
   --  the kilo range, "M" for the mega range, and "G" for the giga
   --  range.  Precision is at most two decimal places with trailing
   --  zeros stripped.
   --
   --  Examples: 999 → "999", 1500 → "1.5k", 200000 → "200k",
   --            1000000 → "1M", 1500000 → "1.5M".
   function Format_SI_Count (N : Natural) return String;

   --  Format a single per-token rate (given in $/MTok) as a compact
   --  SI-prefixed price string.
   --
   --  $/MTok equals µ$/tok exactly, so the prefix thresholds are:
   --    ≥ 1.0   →  µ (micro)  e.g. 3.0 → "$3µ"
   --    ≥ 0.001 →  n (nano)   e.g. 0.3 → "$300n"
   --    < 0.001 →  p (pico)   (very cheap / free-tier models)
   --
   --  Precision is at most two decimal places with trailing zeros
   --  stripped.  Returns "" for non-positive values.
   --
   --  Examples: 3.0 → "$3µ", 1.25 → "$1.25µ", 0.3 → "$300n",
   --            0.075 → "$75n".
   function Format_SI_Price (Per_MTok : Long_Float) return String;

   --  Format a compact per-million-token price string for model display.
   --
   --  Each non-zero field produces one labelled segment:
   --    in  — prompt / input tokens
   --    out — completion / output tokens
   --    cr  — cache read tokens
   --    cw  — cache write tokens
   --
   --  Segments are separated by spaces and the whole result ends with
   --  "/tok" using SI-prefixed prices from Format_SI_Price.  Returns ""
   --  when all four values are zero (e.g. for GitHub Copilot and
   --  Anthropic models where no pricing is available).
   --
   --  Example: "in $3µ out $15µ cr $300n /tok"
   function Format_Model_Price
     (Input_Per_MTok       : Long_Float;
      Output_Per_MTok      : Long_Float;
      Cache_Read_Per_MTok  : Long_Float;
      Cache_Write_Per_MTok : Long_Float) return String;

   --  Examples: 0 -> "$0.0000", 234 -> "$0.0234", 12345 -> "$1.2345".
   function Format_Cost (Dmil : Natural) return String;

   --  Return the N-th (1-based) whitespace-separated token from Text,
   --  or "" if Text has fewer than N tokens.  Whitespace is space or HT.
   function Nth_Field (Text : String; N : Positive) return String;

   --  Parse a coyote-fork+PID/UUID/N token received from the coyote-fork
   --  plumb port.
   --
   --  Data       : the data field of the plumb message (already extracted).
   --  Pid_Prefix : the expected prefix string,
   --               e.g. "coyote-fork+" & My_PID & "/".
   --
   --  On success (token begins with Pid_Prefix and has the form
   --  "coyote-fork+PID/UUID/N") sets UUID and Turn_N and returns True.
   --  On any mismatch or malformed input returns False and leaves
   --  UUID / Turn_N unchanged.
   function Parse_Fork_Token
     (Data       : String;
      Pid_Prefix : String;
      UUID       : out Ada.Strings.Unbounded.Unbounded_String;
      Turn_N     : out Positive) return Boolean;

   --  Return the first 16 hex characters of the SHA-256 digest of Tool_Id,
   --  matching the token computed by the Python reference implementation:
   --    hashlib.sha256(tool_id.encode()).hexdigest()[:16]
   function Hash_Tool_Id (Tool_Id : String) return String;

   --  Extract the data payload from a raw plumb message byte array.
   --  A plumb message is 7 newline-separated fields; the last field is
   --  the data payload.  Returns "" if the message is malformed.
   function Extract_Plumb_Data (Raw : Nine_P.Byte_Array) return String;

   --  Run the raw prompt text through a shell filter command and return
   --  the filtered result.
   --
   --  Filter is passed to "$SHELL -c <Filter>" (falling back to "sh" when
   --  $SHELL is unset); the raw prompt is written to the command's stdin
   --  and stdout is read as the filtered prompt.
   --
   --  Returns Raw unchanged when:
   --    * Filter is empty (no filtering configured);
   --    * the subprocess cannot be started;
   --    * the command exits with a non-zero status; or
   --    * stdout is empty after trimming leading/trailing whitespace.
   --
   --  In the latter three cases a "[!] prompt filter …" warning is appended
   --  to Warn_Buf so the caller can display it to the user.
   function Apply_Prompt_Filter
     (Raw      : String;
      Filter   : String;
      Warn_Buf : out Ada.Strings.Unbounded.Unbounded_String) return String;

   --  Collapse thinking-text deltas to flowing prose.
   --
   --  Thinking SSE chunks often contain leading/trailing newlines and
   --  internal line breaks that should be displayed as flowing text rather
   --  than as one fragment per line.  This function:
   --    * Preserves single \n and \r characters as line breaks
   --    * Preserves \n\n (paragraph breaks) as blank lines
   --    * Trims leading and trailing whitespace from the result
   --
   --  Example: " The\n user\n wants " → "The\nuser\nwants"
   --           "Para 1\n\nPara 2" → "Para 1\n\nPara 2" (unchanged)
   function Collapse_Thinking_Delta (Text : String) return String;

   --  ── Turn footer builders ─────────────────────────────────────────────

   --  Build the bracketed per-turn summary placed before the fork token.
   --  Returns "" when no summary parts are available.
   function Format_Turn_Summary
     (Input_Tokens      : Natural;
      Output_Tokens     : Natural;
      Ctx_Window        : Natural;
      Model_Text        : String;
      Turn_Cost_Dmil    : Natural := 0;
      Session_Cost_Dmil : Natural := 0;
      Stop_Reason_Text : String  := "") return String;

   --  Turn footer between completed turns.  Carries a clickable fork token
   --  so button-3 opens a forked session.
   --  Format: [summary ]coyote-fork+PID/UUID/N\n════...════\n\n
   function Format_Turn_Footer
     (Turn_N            : Positive;
      UUID              : String;
      PID               : String;
      Input_Tokens      : Natural := 0;
      Output_Tokens     : Natural := 0;
      Ctx_Window        : Natural := 0;
      Model_Text        : String  := "";
      Turn_Cost_Dmil    : Natural := 0;
      Session_Cost_Dmil : Natural := 0;
      Stop_Reason_Text : String  := "") return String;

   --  ── JSON field helpers ────────────────────────────────────────────────

   --  Return the string value of Field from Val, or "" if absent or not
   --  a JSON string.
   function Get_String
     (Val   : GNATCOLL.JSON.JSON_Value;
      Field : GNATCOLL.JSON.UTF8_String) return String;

   --  Return the integer value of Field from Val as Natural, or 0 if
   --  absent or not a JSON integer.
   function Get_Integer
     (Val   : GNATCOLL.JSON.JSON_Value;
      Field : GNATCOLL.JSON.UTF8_String) return Natural;

   --  Read a JSON cost field (float or integer) and return the value in
   --  units of $0.0001 ("dmil").  Handles JSON_Float_Type (the normal case
   --  from the cost.total computation) and JSON_Int_Type (zero when no
   --  pricing is configured).  Returns 0 when the field is absent, zero,
   --  or negative.
   function Get_Cost_Dmil
     (Val   : GNATCOLL.JSON.JSON_Value;
      Field : GNATCOLL.JSON.UTF8_String) return Natural;

   --  Return the boolean value of Field from Val, or False if absent or
   --  not a JSON boolean.
   function Get_Boolean
     (Val   : GNATCOLL.JSON.JSON_Value;
      Field : GNATCOLL.JSON.UTF8_String) return Boolean;

   --  Return the object value of Field from Val, or JSON_Null if absent
   --  or not a JSON object.
   function Get_Object
     (Val   : GNATCOLL.JSON.JSON_Value;
      Field : GNATCOLL.JSON.UTF8_String) return GNATCOLL.JSON.JSON_Value;

   --  Return a human-readable string for a scalar JSON value suitable for
   --  display in tool-call argument summaries.
   --
   --  Strings are returned as-is (no quotation marks).  Integers, booleans,
   --  and floats are serialised by GNATCOLL.JSON.Write (e.g. 42, true,
   --  3.14).  Null, object, and array values return "...".
   function JSON_Scalar_Image
     (Val : GNATCOLL.JSON.JSON_Value) return String;

   --  Format a single tool-argument field for display in the acme window.
   --
   --  The first line of the result is "│ Name: <first line of Value>".
   --  Each subsequent line (delimited by ASCII.LF in Value) is prefixed
   --  with "│ " so that the box border is continuous for multi-line
   --  values such as bash commands.
   --
   --  Value is truncated to Max_Len bytes (keeping the first Max_Len - 3
   --  bytes and appending "…") when Value'Length > Max_Len.
   --
   --  The returned string contains no leading LF; the caller should
   --  prepend ASCII.LF before appending to the acme window body.
   function Format_Tool_Field
     (Name    : String;
      Value   : String;
      Max_Len : Positive := 200) return String;

   --  Format a vector of session records as a tree for the Sessions window.
   --
   --  Sessions whose Parent_Id is empty, or whose parent UUID is not present
   --  in the vector, are rendered as roots.  Children are rendered
   --  immediately after their parent, indented by 2*Depth spaces followed
   --  by a "↳ " connector.  Each level of nesting adds one depth unit.
   --  Within each group (roots and children of the same parent) sessions
   --  are presented in the order they appear in the input vector; the caller
   --  is responsible for sorting before passing.
   --
   --  Each line has the form:
   --    [indent]coyote-session+UUID<TAB>name<TAB>date<TAB>snippet
   --
   --  The introductory comment line and trailing newline are included in the
   --  returned string.  Returns just the comment line when Sessions is empty.
   function Format_Session_List
     (Sessions : Session_Lister.Session_Vectors.Vector) return String;


end Coyote_App.Utils;
