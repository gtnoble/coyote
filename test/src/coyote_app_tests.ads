with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_App_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  App_State protected type
   procedure Test_State_Model         (T : in out Test);
   procedure Test_State_Streaming     (T : in out Test);
   procedure Test_State_Tokens        (T : in out Test);
   procedure Test_State_Shutdown      (T : in out Test);
   procedure Test_State_Session_Id    (T : in out Test);

   --  Nth_Field string utility
   procedure Test_Nth_Field_Basic     (T : in out Test);
   procedure Test_Nth_Field_Tabs      (T : in out Test);
   procedure Test_Nth_Field_Edges     (T : in out Test);

   --  Format_Turn_Footer with step-level separator.
   procedure Test_Format_Turn_Footer_Display_Step  (T : in out Test);

   --  App_State Turn_Step counter tests.
   procedure Test_State_Turn_Step_Increment      (T : in out Test);
   procedure Test_State_Turn_Step_Set            (T : in out Test);
   procedure Test_State_Turn_Step_Reset          (T : in out Test);

   --  App_State Turn_Count
   procedure Test_State_Turn_Count_Increment (T : in out Test);
   procedure Test_State_Turn_Count_Set       (T : in out Test);
   procedure Test_State_Turn_Count_Reset     (T : in out Test);

   --  App_State Is_Retrying — tracks whether an auto-retry sequence is in
   --  flight.  Set by auto_retry_start, cleared by auto_retry_end and
   --  explicit reset points (new_session, session reload).  Used in
   --  agent_end to suppress the repeated "No response" message.
   procedure Test_State_Is_Retrying_Initial     (T : in out Test);
   procedure Test_State_Is_Retrying_Set_And_Clear (T : in out Test);
   procedure Test_State_Is_Retrying_Independent (T : in out Test);

   --  App_State Has_Text_Delta — tracks whether a text_delta arrived in the
   --  current agent turn.
   procedure Test_State_Has_Text_Delta_Initial             (T : in out Test);
   procedure Test_State_Has_Text_Delta_Set_And_Clear       (T : in out Test);
   procedure Test_State_Has_Text_Delta_Independent         (T : in out Test);

   --  App_State Last_Stop_Reason — stopReason from the last assistant
   --  message_end in the current agent run.  "stop"/"length" means the
   --  agent's final LLM call produced a text response; "toolUse" means an
   --  intermediate tool-calling turn (should not occur at agent_end).
   --  Resets to "" at agent_start.  Used to gate the turn footer and stats
   --  request in the agent_end handler.
   procedure Test_State_Last_Stop_Reason_Initial           (T : in out Test);
   procedure Test_State_Last_Stop_Reason_Round_Trip        (T : in out Test);
   procedure Test_State_Last_Stop_Reason_Independent       (T : in out Test);

   --  App_State Last_Error_Message — errorMessage from the last assistant
   --  message_end with stopReason "error".  Empty when the last turn did not
   --  produce an error, or when no message was supplied.
   procedure Test_State_Last_Error_Message_Initial         (T : in out Test);
   procedure Test_State_Last_Error_Message_Round_Trip      (T : in out Test);

   --  Pending_Stats is gated by Last_Stop_Reason in Dispatch_Event.
   --  "stop" and "length" trigger the footer; other reasons do not.
   procedure Test_State_Pending_Stats_Gated_By_Stop_Reason (T : in out Test);

   --  Model in stats summary line
   --  Verify the App_State accessor that gates the model part in the
   --  get_session_stats summary appended at the end of each agentic turn.
   procedure Test_Stats_Model_Part_When_Set   (T : in out Test);
   procedure Test_Stats_Model_Part_When_Empty (T : in out Test);

   --  App_State cost fields
   procedure Test_State_Turn_Cost_Initial       (T : in out Test);
   procedure Test_State_Turn_Cost_Round_Trip    (T : in out Test);
   procedure Test_State_Session_Stats_Initial   (T : in out Test);
   procedure Test_State_Session_Stats_Round_Trip (T : in out Test);
   procedure Test_State_Session_Stats_Reset     (T : in out Test);
   procedure Test_State_Cost_Independent_Of_Tokens (T : in out Test);

   --  JSON_Scalar_Image
   procedure Test_JSON_Scalar_String           (T : in out Test);
   procedure Test_JSON_Scalar_Integer          (T : in out Test);
   procedure Test_JSON_Scalar_Negative_Integer (T : in out Test);
   procedure Test_JSON_Scalar_Boolean_True     (T : in out Test);
   procedure Test_JSON_Scalar_Boolean_False    (T : in out Test);
   procedure Test_JSON_Scalar_Float            (T : in out Test);
   procedure Test_JSON_Scalar_Null             (T : in out Test);
   procedure Test_JSON_Scalar_Object           (T : in out Test);
   procedure Test_JSON_Scalar_Array            (T : in out Test);

   procedure Test_One_Shot_Result_Initial          (T : in out Test);
   procedure Test_One_Shot_Result_First_Write_Wins (T : in out Test);

   --  ── Format_Tool_Field ─────────────────────────────────────────────────

   procedure Test_Format_Tool_Field_Single_Line   (T : in out Test);
   --  Single-line value: returns "│ name: value" with no embedded LF.

   procedure Test_Format_Tool_Field_Two_Lines     (T : in out Test);
   --  Value with one LF: first line has label; second line has │ only.

   procedure Test_Format_Tool_Field_Three_Lines   (T : in out Test);
   --  Value with two LFs: all three lines carry the │ border.

   procedure Test_Format_Tool_Field_Trailing_LF   (T : in out Test);
   --  Value ending with LF: produces a blank-body continuation line.

   procedure Test_Format_Tool_Field_Empty_Value   (T : in out Test);
   --  Empty value: returns "│ name: " (label with no value text).

   procedure Test_Format_Tool_Field_Truncation    (T : in out Test);
   --  Value longer than Max_Len is truncated and ends with "…".

   procedure Test_Tool_Segment_Line_Count (T : in out Test);
   --  LF-count + 1 in Format_Tool_Field output equals ncurses display lines.

   --  ── Format_SI_Count ───────────────────────────────────────────────────
   --  Format_SI_Count formats a Natural with an appropriate SI prefix:
   --  plain decimal for N < 1000; "Nk" for the kilo range; "NM" for
   --  the mega range.

   procedure Test_Format_SI_Count_Below_Threshold (T : in out Test);
   procedure Test_Format_SI_Count_Round_Numbers   (T : in out Test);
   procedure Test_Format_SI_Count_Fractional      (T : in out Test);
   procedure Test_Format_SI_Count_M_Range         (T : in out Test);

   --  ── Format_Cost ───────────────────────────────────────────────────────
   --  Format_Cost converts an integer in units of $0.0001 (dmil) to
   --  a "$D.FFFF" string.  0 → "$0.0000"; 12345 → "$1.2345".

   procedure Test_Format_Cost_Zero       (T : in out Test);
   procedure Test_Format_Cost_Fractional (T : in out Test);
   procedure Test_Format_Cost_Dollars    (T : in out Test);

   --  ── Format_Model_Price ────────────────────────────────────────────────
   --  Format_Model_Price formats a per-MTok rate string for the model
   --  selection window.  Each non-zero field emits one labelled segment
   --  ("in", "out", "cr", "cw"); all segments are absent (empty result)
   --  when every value is zero.

   --  All four values zero → returns "".
   procedure Test_Format_Model_Price_All_Zeros   (T : in out Test);

   --  Input and output non-zero, cache fields zero → "in … out … /MTok",
   --  no "cr" or "cw" labels.
   procedure Test_Format_Model_Price_In_Out_Only (T : in out Test);

   --  All four values non-zero → all four labels appear.
   procedure Test_Format_Model_Price_All_Four    (T : in out Test);

   --  Zero cache fields are silently omitted even when in/out are set.
   procedure Test_Format_Model_Price_Omits_Zeros (T : in out Test);

   --  Only cache_read non-zero → only "cr" label appears.
   procedure Test_Format_Model_Price_Cache_Only  (T : in out Test);

   --  Format_DB_Price converts $/MTok to dB $/tok using 10*log10.
   procedure Test_Format_DB_Price_Representative (T : in out Test);
   procedure Test_Format_DB_Price_Free_And_Negative (T : in out Test);

   --  ── Get_Cost_Dmil ────────────────────────────────────────────────────
   --  Get_Cost_Dmil reads a JSON float or integer cost field and converts
   --  it to integer dmil units ($0.0001) using round-half-up arithmetic.
   --  Returns 0 for absent, zero, or negative values.

   procedure Test_Get_Cost_Dmil_Float_Value    (T : in out Test);
   procedure Test_Get_Cost_Dmil_Zero_Float     (T : in out Test);
   procedure Test_Get_Cost_Dmil_Integer_Zero   (T : in out Test);
   procedure Test_Get_Cost_Dmil_Absent_Field   (T : in out Test);
   procedure Test_Get_Cost_Dmil_Negative_Float (T : in out Test);

   --  ── Format_Status ─────────────────────────────────────────────────────
   --  Format_Status builds the one-line status string placed in the first
   --  body line of the +coyote window.  Parts (model, thinking, sandbox,
   --  session) are included only when the corresponding App_State fields
   --  are populated.

   procedure Test_Format_Status_Default        (T : in out Test);
   procedure Test_Format_Status_Custom_Extra   (T : in out Test);
   procedure Test_Format_Status_With_Model     (T : in out Test);
   procedure Test_Format_Status_With_Session   (T : in out Test);
   procedure Test_Format_Status_With_Context   (T : in out Test);
   procedure Test_Format_Status_With_Thinking  (T : in out Test);
   procedure Test_Format_Status_With_Sandbox   (T : in out Test);

   --  ── Apply_Prompt_Filter ───────────────────────────────────────────────
   --  Apply_Prompt_Filter pipes the raw prompt through $SHELL -c <Filter>.
   --  When Filter is empty the raw prompt is returned unchanged (no Warn_Buf).
   --  On filter success the trimmed stdout is returned.
   --  On non-zero exit, empty stdout, or exception, Raw is returned and
   --  Warn_Buf carries a descriptive message.

   --  Empty filter returns raw prompt unchanged with empty Warn_Buf.
   procedure Test_Apply_Filter_Empty_Filter      (T : in out Test);

   --  Filter that echoes input produces trimmed output.
   procedure Test_Apply_Filter_Echo              (T : in out Test);

   --  Filter that transforms input (e.g. uppercase).
   procedure Test_Apply_Filter_Transform         (T : in out Test);

   --  Filter with non-zero exit falls back to raw with warning.
   procedure Test_Apply_Filter_Non_Zero_Exit     (T : in out Test);

   --  Filter that emits empty stdout falls back to raw with warning.
   procedure Test_Apply_Filter_Empty_Output      (T : in out Test);

   --  Filter output is trimmed of leading/trailing whitespace.
   procedure Test_Apply_Filter_Trims_Whitespace  (T : in out Test);

   --  ── App_State Prompt_Filter ───────────────────────────────────────────
   --  Prompt_Filter is stored in App_State for the active runner.

   procedure Test_State_Prompt_Filter_Initial    (T : in out Test);
   procedure Test_State_Prompt_Filter_Round_Trip (T : in out Test);

   --  ── Is_Paused ─────────────────────────────────────────────────────────

   --  Is_Paused is False by default.
   procedure Test_State_Is_Paused_Initial        (T : in out Test);

   --  Set_Paused toggles the Is_Paused flag.
   procedure Test_State_Is_Paused_Set_And_Clear  (T : in out Test);

   --  ── Is_Pause_Armed ────────────────────────────────────────────────────

   --  Is_Pause_Armed is False by default.
   procedure Test_State_Is_Pause_Armed_Initial       (T : in out Test);

   --  Set_Pause_Armed toggles the Is_Pause_Armed flag.
   procedure Test_State_Is_Pause_Armed_Set_And_Clear (T : in out Test);

   --  ── Sandbox ──────────────────────────────────────────────────────────

   --  Current_Sandbox is empty by default.
   procedure Test_State_Sandbox_Initial          (T : in out Test);

   --  Set_Sandbox stores the profile name and Current_Sandbox returns it.
   procedure Test_State_Sandbox_Round_Trip       (T : in out Test);

   --  Set_Sandbox ("") clears the profile back to empty.
   procedure Test_State_Sandbox_Clear            (T : in out Test);

   --  ── GFM (libcmark-gfm) table parsing ─────────────────────────────────

   --  GFM table input produces a node with type_string "table".
   procedure Test_Cmark_GFM_Table_Parsed       (T : in out Test);
   --  Standard CommonMark paragraph still has type_string "paragraph".
   procedure Test_Cmark_Paragraph_Type_String  (T : in out Test);
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_App_Tests;
