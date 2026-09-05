with AUnit.Assertions;
with Ada.Real_Time;
with Ada.Strings.Fixed;
with AUnit.Test_Caller;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Tools;
with LLM.Tools.Temp_File;
with LLM.Tools.Shell;
with Coyote_Process_Control;

package body LLM_Tools_Tests is

   use AUnit.Assertions;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   function Image_Arguments
     (Command : String; Media_Type : String := "image/png") return String is
   begin
      return "{""command"":""" & Command
        & """,""media_type"":""" & Media_Type & """}";
   end Image_Arguments;

   --  Minimal 1x1 PNG used by image-result tests.
   PNG_Base64 : constant String :=
     "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";
   PNG_Command : constant String :=
     "printf '" & PNG_Base64 & "' | base64 -d";

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

      --  A real minimal PNG is emitted and must round-trip unchanged.
      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  => Image_Arguments (PNG_Command),
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
        (To_String (Result) = PNG_Base64,
         "PNG stdout should be returned unchanged after base64 encoding");
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

   procedure Test_Shell_Image_Separates_Stderr (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  => Image_Arguments
           ("printf warning >&2; " & PNG_Command),
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (not Is_Error,
              "valid image stdout with stderr diagnostics should succeed");
      Assert (To_String (Media_Type) = "image/png",
              "image MIME type should be preserved");
      Assert (To_String (Result) = PNG_Base64,
              "stderr must not be included in image base64 data");
   end Test_Shell_Image_Separates_Stderr;

   procedure Test_Shell_Image_Rejects_Invalid_Data (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  => Image_Arguments ("printf not-an-image"),
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (Is_Error, "non-image bytes should be rejected");
      Assert (To_String (Media_Type) = "",
              "invalid image output must not retain a media type");
      Assert (Contains (To_String (Result), "not a valid image/png"),
              "invalid image result should explain the validation failure");
   end Test_Shell_Image_Rejects_Invalid_Data;

   procedure Test_Shell_Image_Rejects_Unsupported_Mime (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json => Image_Arguments
           ("printf should-not-run", "image/bmp"),
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (Is_Error, "unsupported image MIME should be rejected");
      Assert (To_String (Media_Type) = "",
              "unsupported image MIME must not be returned");
      Assert (Contains (To_String (Result), "unsupported image media type"),
              "MIME failure should identify the rejected media type");
   end Test_Shell_Image_Rejects_Unsupported_Mime;

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
           Image_Arguments (PNG_Command & "; printf '%5000d' 0 >&2"),
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


   --  ── Shell timeout tests ───────────────────────────────────────────────

   procedure Test_Shell_Timeout_Under (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""sleep 0.5 && echo ok"","
           & """timeout"":5}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (not Is_Error,
              "command that finishes under the timeout should succeed");
      Assert
        (Contains (To_String (Result), "ok"),
         "output should contain the expected text");
      Assert
        (not Contains (To_String (Result), "timed out"),
         "output must not contain a timeout notice");
   end Test_Shell_Timeout_Under;

   procedure Test_Shell_Timeout_Triggers (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""sleep 10"","
           & """timeout"":2}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (Is_Error,
              "command exceeding the timeout should set Is_Error");
      Assert
        (Contains (To_String (Result), "timed out after 2 seconds"),
         "output should contain ""timed out after 2 seconds"", got: "
         & To_String (Result));
   end Test_Shell_Timeout_Triggers;

   procedure Test_Shell_Timeout_Zero (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""echo ok"","
           & """timeout"":0}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (not Is_Error,
              "timeout=0 should be treated as no time limit");
      Assert
        (Contains (To_String (Result), "ok"),
         "output should contain the expected text");
   end Test_Shell_Timeout_Zero;

   procedure Test_Shell_Timeout_Negative (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""echo ok"","
           & """timeout"":-5}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Assert (not Is_Error,
              "negative timeout should be treated as no time limit");
      Assert
        (Contains (To_String (Result), "ok"),
         "output should contain the expected text");
   end Test_Shell_Timeout_Negative;

   --  ── Independent elapsed-time timeout tests ─────────────────────────

   procedure Test_Shell_Timeout_Under_Elapsed (T : in out Test) is
      pragma Unreferenced (T);

      use Ada.Real_Time;

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
      Start      : constant Time := Clock;
      Elapsed    : Time_Span;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""sleep 0.5 && echo ok"","
           & """timeout"":5}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Elapsed := Clock - Start;

      Assert (not Is_Error,
              "command that finishes under the timeout should succeed");
      Assert
        (Contains (To_String (Result), "ok"),
         "output should contain the expected text");
      Assert
        (not Contains (To_String (Result), "timed out"),
         "output must not contain a timeout notice");
      Assert
        (To_Duration (Elapsed) < 2.0,
         "elapsed time should be well within the 5 s timeout, got: "
         & Duration'Image (To_Duration (Elapsed)));
   end Test_Shell_Timeout_Under_Elapsed;


   procedure Test_Shell_Timeout_Triggers_Elapsed (T : in out Test) is
      pragma Unreferenced (T);

      use Ada.Real_Time;

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
      Start      : constant Time := Clock;
      Elapsed    : Time_Span;
   begin
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""sleep 10"","
           & """timeout"":2}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      Elapsed := Clock - Start;

      Assert (Is_Error,
              "command exceeding the timeout should set Is_Error");
      Assert
        (Contains (To_String (Result), "timed out after 2 seconds"),
         "output should contain ""timed out after 2 seconds"", got: "
         & To_String (Result));
      Assert
        (To_Duration (Elapsed) >= 1.5,
         "elapsed time should be at least 1.5 s, got: "
         & Duration'Image (To_Duration (Elapsed)));
      Assert
        (To_Duration (Elapsed) <= 3.0,
         "elapsed time should be no more than 3.0 s, got: "
         & Duration'Image (To_Duration (Elapsed)));
   end Test_Shell_Timeout_Triggers_Elapsed;

   --  ── Timeout / abort partial-stdout flushing tests ──────────────────

   procedure Test_Shell_Timeout_Preserves_Stdout (T : in out Test) is
      pragma Unreferenced (T);

      Result     : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      --  A command that writes stdout then sleeps past the timeout:
      --  the output written before the kill should be preserved.
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""echo hello && sleep 10"","
           & """timeout"":1}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);

      declare
         Result_Text : constant String := To_String (Result);
      begin
         Assert (Is_Error,
                 "command exceeding the timeout should set Is_Error");
         Assert
           (Contains (Result_Text, "hello"),
            "stdout emitted before the timeout should be preserved, got: "
            & Result_Text);
         Assert
           (Contains (Result_Text, "timed out after 1 seconds"),
            "timeout notice must be present");
         Assert
           (Ada.Strings.Fixed.Index (Result_Text, "hello")
              < Ada.Strings.Fixed.Index (Result_Text, "timed out"),
            "stdout must appear before the timeout notice, got: "
            & Result_Text);
      end;
   end Test_Shell_Timeout_Preserves_Stdout;

   procedure Test_Shell_Abort_Preserves_Stdout (T : in out Test) is
      pragma Unreferenced (T);

      Flag    : aliased LLM.Tools.Abort_Flag;
      Result  : Unbounded_String;
      Media_Type : Unbounded_String;
      Is_Error   : Boolean;
   begin
      --  Execute the shell in a task so the main test can trigger the
      --  abort while the command is still running.
      declare
         task Executor;

         task body Executor is
         begin
            LLM.Tools.Shell.Execute
              (Args_Json  =>
                 "{""command"":""echo hello && sleep 10"","
                 & """timeout"":30}",
               Result     => Result,
               Media_Type => Media_Type,
               Is_Error   => Is_Error,
               Abort_Flg  => Flag'Access);
         end Executor;
      begin
         --  Let echo complete before we kill.
         delay 0.50;
         Flag.Set;

         --  Wait for the executor to finish (killed immediately after
         --  the abort is issued).
         declare
            use Ada.Real_Time;
            Deadline : constant Time := Clock + Milliseconds (2_000);
         begin
            loop
               exit when Executor'Terminated;
               exit when Clock >= Deadline;
               delay 0.01;
            end loop;
         end;

         Assert (Executor'Terminated,
                 "aborted shell must terminate within 2 s");
      end;

      declare
         Result_Text : constant String := To_String (Result);
         Hello_Pos   : constant Natural :=
           Ada.Strings.Fixed.Index (Result_Text, "hello");
         Abort_Pos   : constant Natural :=
           Ada.Strings.Fixed.Index (Result_Text, "was aborted");
      begin
         Assert (Is_Error,
                 "aborted command should set Is_Error");
         Assert
           (Hello_Pos > 0,
            "stdout emitted before the abort should be preserved, got: "
            & Result_Text);
         Assert
           (Abort_Pos > 0,
            "abort notice must be present");
         Assert
           (Hello_Pos < Abort_Pos,
            "stdout must appear before the abort notice, got: "
            & Result_Text);
      end;
   end Test_Shell_Abort_Preserves_Stdout;

   procedure Test_Shell_Timeout_Allows_Term_Exit (T : in out Test) is
      pragma Unreferenced (T);

      Result      : Unbounded_String;
      Media_Type  : Unbounded_String;
      Is_Error    : Boolean;
      Saved_Grace : constant Natural :=
        Coyote_Process_Control.Grace_Seconds;
   begin
      Coyote_Process_Control.Set_Grace_Seconds (1);
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""trap 'echo term && exit 0' TERM; sleep 10"",""timeout"":1}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);
      Coyote_Process_Control.Set_Grace_Seconds (Saved_Grace);

      Assert (Is_Error, "timed-out TERM-aware command should report an error");
      Assert
        (Contains (To_String (Result), "term"),
         "timeout should send SIGTERM before forced termination");
      Assert
        (Contains (To_String (Result), "timed out after 1 seconds"),
         "timeout result should retain its timeout notice");
   exception
      when others =>
         Coyote_Process_Control.Set_Grace_Seconds (Saved_Grace);
         raise;
   end Test_Shell_Timeout_Allows_Term_Exit;

   procedure Test_Shell_Timeout_Escalates_After_Grace (T : in out Test) is
      pragma Unreferenced (T);

      use Ada.Real_Time;

      Result      : Unbounded_String;
      Media_Type  : Unbounded_String;
      Is_Error    : Boolean;
      Start       : constant Time := Clock;
      Elapsed     : Time_Span;
      Saved_Grace : constant Natural :=
        Coyote_Process_Control.Grace_Seconds;
   begin
      Coyote_Process_Control.Set_Grace_Seconds (1);
      LLM.Tools.Shell.Execute
        (Args_Json  =>
           "{""command"":""trap '' TERM; sleep 10"",""timeout"":1}",
         Result     => Result,
         Media_Type => Media_Type,
         Is_Error   => Is_Error);
      Elapsed := Clock - Start;
      Coyote_Process_Control.Set_Grace_Seconds (Saved_Grace);

      Assert (Is_Error, "TERM-ignoring timeout command should report an error");
      Assert
        (Contains (To_String (Result), "timed out after 1 seconds"),
         "forced timeout result should contain its timeout notice");
      Assert
        (To_Duration (Elapsed) >= 1.8,
         "timeout should allow the configured grace period");
      Assert
        (To_Duration (Elapsed) < 3.5,
         "timeout escalation should complete after timeout plus grace");
   exception
      when others =>
         Coyote_Process_Control.Set_Grace_Seconds (Saved_Grace);
         raise;
   end Test_Shell_Timeout_Escalates_After_Grace;


   package LLM_Tools_Caller is
     new AUnit.Test_Caller (LLM_Tools_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell executes a successful command",
         LLM_Tools_Tests.Test_Shell_Success'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell reports a non-zero exit status",
         LLM_Tools_Tests.Test_Shell_Failure'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell pipes stdin text into the command",
         LLM_Tools_Tests.Test_Shell_Stdin_Piped'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell treats empty stdin field as absent",
         LLM_Tools_Tests.Test_Shell_Stdin_Empty_Ignored'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell succeeds without a stdin field",
         LLM_Tools_Tests.Test_Shell_Stdin_Absent_Dev_Null'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold zero returns MAX",
         LLM_Tools_Tests.Test_Result_Threshold_Zero_Returns_Max'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold small clamped to MIN",
         LLM_Tools_Tests.Test_Result_Threshold_Small_Clamped_To_Min'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold 128k yields 64 KB",
         LLM_Tools_Tests.Test_Result_Threshold_Typical_128k'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold 200k yields 100 KB",
         LLM_Tools_Tests.Test_Result_Threshold_Typical_200k'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold large clamped to MAX",
         LLM_Tools_Tests.Test_Result_Threshold_Large_Clamped_To_Max'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Validate_Arguments accepts valid JSON object",
         LLM_Tools_Tests.Test_Validate_Arguments_Valid_Object'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Validate_Arguments rejects invalid JSON",
         LLM_Tools_Tests.Test_Validate_Arguments_Invalid_Json'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Validate_Arguments rejects non-object JSON",
         LLM_Tools_Tests.Test_Validate_Arguments_Non_Object'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Validate_Arguments rejects empty string",
         LLM_Tools_Tests.Test_Validate_Arguments_Empty_String'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag initial state is not armed and not paused",
         LLM_Tools_Tests.Test_Pause_Flag_Initial_State'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Arm sets Is_Armed",
         LLM_Tools_Tests.Test_Pause_Flag_Arm_Sets_Armed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Unarm cancels a pending Arm",
         LLM_Tools_Tests.Test_Pause_Flag_Unarm_Cancels_Arm'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Fire transitions Armed to Paused",
         LLM_Tools_Tests.Test_Pause_Flag_Fire_Transitions'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Fire without Arm is a no-op",
         LLM_Tools_Tests.Test_Pause_Flag_Fire_No_Op_When_Not_Armed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Release clears Paused",
         LLM_Tools_Tests.Test_Pause_Flag_Release_Clears_Paused'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Release also clears Armed",
         LLM_Tools_Tests.Test_Pause_Flag_Release_Clears_Armed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell media_type base64-encodes stdout",
         LLM_Tools_Tests.Test_Shell_Media_Type_Sets_Base64_Result'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell media_type on error returns empty Media_Type",
         LLM_Tools_Tests.Test_Shell_Media_Type_Error_Clears_Type'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell absent media_type is plain text",
         LLM_Tools_Tests.Test_Shell_Media_Type_Absent_Is_Plain_Text'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell image keeps stderr out of payload",
         LLM_Tools_Tests.Test_Shell_Image_Separates_Stderr'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell image rejects invalid data",
         LLM_Tools_Tests.Test_Shell_Image_Rejects_Invalid_Data'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell image rejects unsupported MIME",
         LLM_Tools_Tests.Test_Shell_Image_Rejects_Unsupported_Mime'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Execute image results bypass truncation cap",
         LLM_Tools_Tests.Test_Execute_Image_Not_Truncated'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout finishes before deadline",
         LLM_Tools_Tests.Test_Shell_Timeout_Under'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout kills an over-running command",
         LLM_Tools_Tests.Test_Shell_Timeout_Triggers'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout=0 disables the timer",
         LLM_Tools_Tests.Test_Shell_Timeout_Zero'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell negative timeout is ignored",
         LLM_Tools_Tests.Test_Shell_Timeout_Negative'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout under: elapsed time verifies fast finish",
         LLM_Tools_Tests.Test_Shell_Timeout_Under_Elapsed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout triggers: elapsed time verifies tight window",
         LLM_Tools_Tests.Test_Shell_Timeout_Triggers_Elapsed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout preserves stdout emitted before kill",
         LLM_Tools_Tests.Test_Shell_Timeout_Preserves_Stdout'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout allows TERM-aware exit during grace",
         LLM_Tools_Tests.Test_Shell_Timeout_Allows_Term_Exit'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout escalates after grace",
         LLM_Tools_Tests.Test_Shell_Timeout_Escalates_After_Grace'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell abort preserves stdout emitted before kill",
         LLM_Tools_Tests.Test_Shell_Abort_Preserves_Stdout'Access));

      return Result;
   end Suite;

end LLM_Tools_Tests;
