with AUnit;
with AUnit.Test_Fixtures;

package LLM_Tools_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Shell_Success (T : in out Test);
   procedure Test_Shell_Failure (T : in out Test);
   procedure Test_Shell_Stdin_Piped           (T : in out Test);
   procedure Test_Shell_Stdin_Empty_Ignored   (T : in out Test);
   procedure Test_Shell_Stdin_Absent_Dev_Null (T : in out Test);

   --  ── Validate_Arguments unit tests ─────────────────────────────────────

   --  Valid JSON object returns empty string.
   procedure Test_Validate_Arguments_Valid_Object  (T : in out Test);

   --  Invalid JSON returns a diagnostic mentioning truncation.
   procedure Test_Validate_Arguments_Invalid_Json   (T : in out Test);

   --  Valid JSON but non-object (e.g. an array) returns a diagnostic.
   procedure Test_Validate_Arguments_Non_Object     (T : in out Test);

   --  Empty string returns a diagnostic (not valid JSON).
   procedure Test_Validate_Arguments_Empty_String    (T : in out Test);

   --  ── Result_Threshold unit tests ───────────────────────────────────────

   --  Context_Window = 0 yields the maximum threshold.
   procedure Test_Result_Threshold_Zero_Returns_Max      (T : in out Test);

   --  A very small context window is clamped to the floor.
   procedure Test_Result_Threshold_Small_Clamped_To_Min  (T : in out Test);

   --  A typical 128 k-token window produces the expected mid-range value.
   procedure Test_Result_Threshold_Typical_128k           (T : in out Test);

   --  A 200 k-token window is still within the ceiling.
   procedure Test_Result_Threshold_Typical_200k           (T : in out Test);

   --  A very large context window is clamped to the ceiling.
   procedure Test_Result_Threshold_Large_Clamped_To_Max  (T : in out Test);

   --  ── Pause_Flag unit tests ─────────────────────────────────────────────

   --  Both Is_Armed and Is_Paused start False.
   procedure Test_Pause_Flag_Initial_State         (T : in out Test);

   --  Arm sets Is_Armed; Is_Paused stays False.
   procedure Test_Pause_Flag_Arm_Sets_Armed         (T : in out Test);

   --  Arm then Unarm: both flags remain/return to False.
   procedure Test_Pause_Flag_Unarm_Cancels_Arm      (T : in out Test);

   --  Arm then Fire: Armed clears, Paused becomes True.
   procedure Test_Pause_Flag_Fire_Transitions        (T : in out Test);

   --  Fire without prior Arm is a no-op.
   procedure Test_Pause_Flag_Fire_No_Op_When_Not_Armed
     (T : in out Test);

   --  After Arm+Fire, Release clears Paused.
   procedure Test_Pause_Flag_Release_Clears_Paused  (T : in out Test);

   --  Release also clears Armed (e.g. when Stop is clicked while armed).
   procedure Test_Pause_Flag_Release_Clears_Armed   (T : in out Test);


   --  ── Shell media_type tests ────────────────────────────────────────────

   --  When media_type is set, stdout is base64-encoded and Media_Type is
   --  populated with the requested MIME string.
   procedure Test_Shell_Media_Type_Sets_Base64_Result  (T : in out Test);

   --  When media_type is set and the command fails, Is_Error is True and
   --  Media_Type is empty (no image data on error).
   procedure Test_Shell_Media_Type_Error_Clears_Type   (T : in out Test);

   --  When media_type is absent the tool behaves as plain text.
   procedure Test_Shell_Media_Type_Absent_Is_Plain_Text (T : in out Test);

   --  LLM.Tools.Execute skips Temp_File truncation for image results.
   procedure Test_Execute_Image_Not_Truncated           (T : in out Test);

end LLM_Tools_Tests;
