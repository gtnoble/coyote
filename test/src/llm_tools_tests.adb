with AUnit.Assertions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Tools;
with LLM.Tools.Temp_File;
with LLM.Tools.Shell;

package body LLM_Tools_Tests is

   use AUnit.Assertions;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   procedure Test_Shell_Success (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
      Media_Type : Unbounded_String;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json => "{""command"":""echo hello""}",
         Result    => Result,
         Media_Type => Media_Type,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "echo hello should succeed");
      Assert
        (Contains (To_String (Result), "hello"),
         "shell result should contain command output");
   end Test_Shell_Success;

   procedure Test_Shell_Failure (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
      Media_Type : Unbounded_String;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json => "{""command"":""exit 1""}",
         Result    => Result,
         Media_Type => Media_Type,
         Is_Error  => Is_Error);

      Assert (Is_Error, "exit 1 should report a tool error");
      Assert
        (Contains (To_String (Result), "status 1"),
         "non-zero exit should mention the failing status");
   end Test_Shell_Failure;

   procedure Test_Shell_Stdin_Piped (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
      Media_Type : Unbounded_String;
   begin
      --  "cat" reads its stdin and writes it to stdout.  The output should
      --  exactly reproduce the text supplied via the "stdin" field.
      LLM.Tools.Shell.Execute
        (Args_Json =>
           "{""command"":""cat"",""stdin"":""hello from stdin\n""}",
         Result    => Result,
         Media_Type => Media_Type,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "cat with stdin should succeed");
      Assert
        (Contains (To_String (Result), "hello from stdin"),
         "output should contain the text piped through stdin");
   end Test_Shell_Stdin_Piped;

   procedure Test_Shell_Stdin_Empty_Ignored (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
      Media_Type : Unbounded_String;
   begin
      --  An empty "stdin" field should be treated as absent: the command
      --  reads from /dev/null so it receives EOF immediately and succeeds.
      LLM.Tools.Shell.Execute
        (Args_Json => "{""command"":""cat"",""stdin"":""""}",
         Result    => Result,
         Media_Type => Media_Type,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "cat with empty stdin should succeed");
      Assert
        (To_String (Result) = "",
         "output should be empty when stdin field is an empty string");
   end Test_Shell_Stdin_Empty_Ignored;

   procedure Test_Shell_Stdin_Absent_Dev_Null (T : in out Test) is
      pragma Unreferenced (T);

      Result   : Unbounded_String;
      Is_Error : Boolean;
      Media_Type : Unbounded_String;
   begin
      --  When no "stdin" field is present the command should still run
      --  normally, receiving EOF from /dev/null.
      LLM.Tools.Shell.Execute
        (Args_Json => "{""command"":""echo no-stdin""}",
         Result    => Result,
         Media_Type => Media_Type,
         Is_Error  => Is_Error);

      Assert (not Is_Error, "echo without stdin should succeed");
      Assert
        (Contains (To_String (Result), "no-stdin"),
         "output should contain the echo'd text");
   end Test_Shell_Stdin_Absent_Dev_Null;

   --  ── Result_Threshold unit tests ───────────────────────────────────────

   procedure Test_Result_Threshold_Zero_Returns_Max (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Tools.Temp_File.Result_Threshold (0) =
            LLM.Tools.Temp_File.MAX_RESULT_THRESHOLD,
         "Context_Window = 0 should return MAX_RESULT_THRESHOLD");
   end Test_Result_Threshold_Zero_Returns_Max;

   procedure Test_Result_Threshold_Small_Clamped_To_Min (T : in out Test) is
      pragma Unreferenced (T);
   begin
      --  8 k tokens → 8_000 × 4 ÷ 8 = 4_000 bytes < MIN (4_096)
      Assert
        (LLM.Tools.Temp_File.Result_Threshold (8_000) =
            LLM.Tools.Temp_File.MIN_RESULT_THRESHOLD,
         "8k context should clamp to MIN_RESULT_THRESHOLD");
   end Test_Result_Threshold_Small_Clamped_To_Min;

   procedure Test_Result_Threshold_Typical_128k (T : in out Test) is
      pragma Unreferenced (T);
   begin
      --  128_000 × 4 ÷ 8 = 64_000 (64 KB) — within bounds
      Assert
        (LLM.Tools.Temp_File.Result_Threshold (128_000) = 64_000,
         "128k context should yield 64 KB threshold");
   end Test_Result_Threshold_Typical_128k;

   procedure Test_Result_Threshold_Typical_200k (T : in out Test) is
      pragma Unreferenced (T);
   begin
      --  200_000 × 4 ÷ 8 = 100_000 (100 KB) — within bounds
      Assert
        (LLM.Tools.Temp_File.Result_Threshold (200_000) = 100_000,
         "200k context should yield 100 KB threshold");
   end Test_Result_Threshold_Typical_200k;

   procedure Test_Result_Threshold_Large_Clamped_To_Max (T : in out Test) is
      pragma Unreferenced (T);
   begin
      --  1_000_000 × 4 ÷ 8 = 500_000 > MAX (204_800)
      Assert
        (LLM.Tools.Temp_File.Result_Threshold (1_000_000) =
            LLM.Tools.Temp_File.MAX_RESULT_THRESHOLD,
         "1M context should clamp to MAX_RESULT_THRESHOLD");
   end Test_Result_Threshold_Large_Clamped_To_Max;

   --  ── Pause_Flag unit tests ─────────────────────────────────────────────

   procedure Test_Pause_Flag_Initial_State (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Assert (not Flag.Is_Armed,  "initial Is_Armed must be False");
      Assert (not Flag.Is_Paused, "initial Is_Paused must be False");
   end Test_Pause_Flag_Initial_State;

   procedure Test_Pause_Flag_Arm_Sets_Armed (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Assert (Flag.Is_Armed,      "Arm must set Is_Armed");
      Assert (not Flag.Is_Paused, "Arm must not set Is_Paused");
   end Test_Pause_Flag_Arm_Sets_Armed;

   procedure Test_Pause_Flag_Unarm_Cancels_Arm (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Flag.Unarm;
      Assert (not Flag.Is_Armed,  "Unarm must clear Is_Armed");
      Assert (not Flag.Is_Paused, "Unarm must not set Is_Paused");
   end Test_Pause_Flag_Unarm_Cancels_Arm;

   procedure Test_Pause_Flag_Fire_Transitions (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Flag.Fire;
      Assert (not Flag.Is_Armed,  "Fire must clear Armed");
      Assert (Flag.Is_Paused,     "Fire must set Paused when Armed was True");
   end Test_Pause_Flag_Fire_Transitions;

   procedure Test_Pause_Flag_Fire_No_Op_When_Not_Armed (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Fire;
      Assert (not Flag.Is_Armed,  "Fire without Arm must leave Is_Armed False");
      Assert (not Flag.Is_Paused, "Fire without Arm must leave Is_Paused False");
   end Test_Pause_Flag_Fire_No_Op_When_Not_Armed;

   procedure Test_Pause_Flag_Release_Clears_Paused (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Flag.Fire;
      Assert (Flag.Is_Paused, "precondition: Is_Paused must be True after Fire");
      Flag.Release;
      Assert (not Flag.Is_Paused, "Release must clear Is_Paused");
   end Test_Pause_Flag_Release_Clears_Paused;

   procedure Test_Pause_Flag_Release_Clears_Armed (T : in out Test) is
      pragma Unreferenced (T);
      Flag : LLM.Tools.Pause_Flag;
   begin
      Flag.Arm;
      Assert (Flag.Is_Armed, "precondition: Is_Armed must be True after Arm");
      Flag.Release;
      Assert (not Flag.Is_Armed, "Release must also clear Is_Armed");
   end Test_Pause_Flag_Release_Clears_Armed;


   --  Validate_Arguments unit tests

   --  The Validate_Arguments tests exercise Shell.Execute's built-in
   --  argument validation.  Valid JSON objects succeed; everything else
   --  causes Is_Error to be set to True.

   procedure Test_Validate_Arguments_Valid_Object (T : in out Test) is
      pragma Unreferenced (T);
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  => "{""command"":""echo hi""}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);
      Assert
        (not Is_Error,
         "Valid JSON object with command should not produce an error");
   end Test_Validate_Arguments_Valid_Object;

   procedure Test_Validate_Arguments_Invalid_Json (T : in out Test) is
      pragma Unreferenced (T);
      --  Simulates a truncated tool-call argument where the LLM hit
      --  max_tokens mid-JSON.
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  => """command"":""echo hi""",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);
      Assert (Is_Error,
              "Broken JSON arguments should produce an error");
   end Test_Validate_Arguments_Invalid_Json;

   procedure Test_Validate_Arguments_Non_Object (T : in out Test) is
      pragma Unreferenced (T);
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  => "[1, 2, 3]",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);
      Assert (Is_Error,
              "JSON array instead of object should produce an error");
   end Test_Validate_Arguments_Non_Object;

   procedure Test_Validate_Arguments_Empty_String (T : in out Test) is
      pragma Unreferenced (T);
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  => "",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);
      Assert (Is_Error,
              "Empty string arguments should produce an error");
   end Test_Validate_Arguments_Empty_String;


   --  ── Shell media_type tests ────────────────────────────────────────────

   procedure Test_Shell_Media_Type_Sets_Base64_Result (T : in out Test) is
      pragma Unreferenced (T);

      --  "Hello" in standard base64 is "SGVsbG8="
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""printf Hello"","
           & """media_type"":""image/png""}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (not Is_Error,
              "command with media_type should succeed");
      Assert
        (To_String (Media_Type) = "image/png",
         "Media_Type out param should be ""image/png"", got: "
         & To_String (Media_Type));
      Assert
        (To_String (Result) = "SGVsbG8=",
         "Base64 of ""Hello"" should be ""SGVsbG8="", got: "
         & To_String (Result));
   end Test_Shell_Media_Type_Sets_Base64_Result;

   procedure Test_Shell_Media_Type_Error_Clears_Type (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""exit 1"","
           & """media_type"":""image/jpeg""}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (Is_Error,
              "failed command should set Is_Error");
      Assert
        (To_String (Media_Type) = "",
         "Media_Type should be empty on command error, got: "
         & To_String (Media_Type));
   end Test_Shell_Media_Type_Error_Clears_Type;

   procedure Test_Shell_Media_Type_Absent_Is_Plain_Text (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  => "{""command"":""echo plain""}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (not Is_Error,
              "echo without media_type should succeed");
      Assert
        (To_String (Media_Type) = "",
         "Media_Type should be empty when field is absent, got: "
         & To_String (Media_Type));
      Assert
        (Contains (To_String (Result), "plain"),
         "Result should contain the plain-text output");
   end Test_Shell_Media_Type_Absent_Is_Plain_Text;

   procedure Test_Execute_Image_Not_Truncated (T : in out Test) is
      pragma Unreferenced (T);

      --  printf '%5000d' 0 produces a 5000-character output (4999 spaces +
      --  the digit 0), which exceeds the 4 096-byte Temp_File threshold for
      --  context_window=8_000.  A plain-text result at this size would be
      --  truncated; an image result must bypass the cap entirely.
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""printf '%5000d' 0"","
           & """media_type"":""image/png""}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      --  Apply the result-size cap: image results must bypass it entirely.
      if Ada.Strings.Unbounded.Length (Media_Type) = 0 then
         Result := Ada.Strings.Unbounded.To_Unbounded_String
           (LLM.Tools.Temp_File.Truncated
              (Ada.Strings.Unbounded.To_String (Result),
               Threshold => LLM.Tools.Temp_File.Result_Threshold (8_000),
               Tool_Name => "shell"));
      end if;

      Assert (not Is_Error,
              "large image command should succeed");
      Assert
        (To_String (Media_Type) = "image/png",
         "Media_Type should be image/png");
      Assert
        (not Contains (To_String (Result), "truncated"),
         "Image result must not contain a truncation trailer");
      Assert
        (not Contains (To_String (Result), "["),
         "Base64 output must not contain '[' (truncation marker)");
   end Test_Execute_Image_Not_Truncated;


end LLM_Tools_Tests;
