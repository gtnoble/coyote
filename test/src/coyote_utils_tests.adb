with AUnit.Assertions;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App.Utils;
with Coyote_Utils;

package body Coyote_Utils_Tests is

   use AUnit.Assertions;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_If_Exists;

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   end Write_File;

   procedure Write_Multiline_File
     (Path : String; Line_1 : String; Line_2 : String)
   is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (File, Line_1);
      Ada.Text_IO.Put_Line (File, Line_2);
      Ada.Text_IO.Close (File);
   end Write_Multiline_File;

   procedure Test_Reads_File_When_Path_Exists (T : in out Test) is
      pragma Unreferenced (T);

      Path     : constant String := "/tmp/coyote_utils_test_a.txt";
      Expected : constant String := "you are helpful";
   begin
      Delete_If_Exists (Path);
      Write_File (Path, Expected);

      declare
         Read_Result : constant String :=
           Coyote_Utils.Read_File_If_Exists (Path);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Read_Result, Expected) > 0,
            "existing file contents should be returned");
      end;

      Delete_If_Exists (Path);
   exception
      when others =>
         Delete_If_Exists (Path);
         raise;
   end Test_Reads_File_When_Path_Exists;

   procedure Test_Returns_Arg_When_Not_A_File (T : in out Test) is
      pragma Unreferenced (T);

      Result : constant String :=
        Coyote_Utils.Read_File_If_Exists ("you are helpful");
   begin
      Assert
        (Result = "",
         "non-file path should return an empty string");
   end Test_Returns_Arg_When_Not_A_File;

   procedure Test_Returns_Empty_For_Empty_Path (T : in out Test) is
      pragma Unreferenced (T);

      Result : constant String := Coyote_Utils.Read_File_If_Exists ("");
   begin
      Assert
        (Result = "",
         "empty path should return an empty string");
   end Test_Returns_Empty_For_Empty_Path;

   procedure Test_Reads_Multiline_File (T : in out Test) is
      pragma Unreferenced (T);

      Path   : constant String := "/tmp/coyote_utils_test_b.txt";
      Line_1 : constant String := "first line";
      Line_2 : constant String := "second line";
   begin
      Delete_If_Exists (Path);
      Write_Multiline_File (Path, Line_1, Line_2);

      declare
         Result : constant String := Coyote_Utils.Read_File_If_Exists (Path);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result, Line_1) > 0,
            "first line should appear in multiline result");
         Assert
           (Ada.Strings.Fixed.Index (Result, Line_2) > 0,
            "second line should appear in multiline result");
      end;

      Delete_If_Exists (Path);
   exception
      when others =>
         Delete_If_Exists (Path);
         raise;
   end Test_Reads_Multiline_File;

   procedure Test_Strip_Session_Prefix_With_Prefix (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Utils.Strip_Session_Prefix ("coyote-session+abc-123-def")
           = "abc-123-def",
         "Strip_Session_Prefix should remove the coyote-session+ prefix");
   end Test_Strip_Session_Prefix_With_Prefix;

   procedure Test_Strip_Session_Prefix_Without_Prefix (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Utils.Strip_Session_Prefix ("abc-123-def") = "abc-123-def",
         "Strip_Session_Prefix should return the string unchanged "
         & "when the prefix is absent");
   end Test_Strip_Session_Prefix_Without_Prefix;

   procedure Test_Strip_Session_Prefix_Empty (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (Coyote_Utils.Strip_Session_Prefix ("") = "",
         "Strip_Session_Prefix should return empty string for empty input");
   end Test_Strip_Session_Prefix_Empty;

   --  ── Sanitize_UTF8 tests ────────────────────────────────────────────────

   U_FFFD : constant String := Character'Val (16#EF#)
                               & Character'Val (16#BF#)
                               & Character'Val (16#BD#);

   procedure Test_Sanitize_UTF8_Passthrough_Pure_ASCII (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant String := "Hello, world! 123.";
      Output : constant String := Coyote_App.Utils.Sanitize_UTF8 (Input);
   begin
      Assert (Output = Input,
              "pure ASCII should pass through unchanged, got: " & Output);
   end Test_Sanitize_UTF8_Passthrough_Pure_ASCII;

   procedure Test_Sanitize_UTF8_Passthrough_Valid_UTF8 (T : in out Test) is
      pragma Unreferenced (T);
      --  "café" with U+00E9 (C3 A9) plus euro sign U+20AC (E2 82 AC)
      Input  : constant String :=
        "caf"
        & Character'Val (16#C3#) & Character'Val (16#A9#)
        & " 10"
        & Character'Val (16#E2#) & Character'Val (16#82#)
                                 & Character'Val (16#AC#);
      Output : constant String :=
        Coyote_App.Utils.Sanitize_UTF8 (Input);
   begin
      Assert (Output = Input,
              "valid multi-byte UTF-8 should pass through unchanged");
   end Test_Sanitize_UTF8_Passthrough_Valid_UTF8;

   procedure Test_Sanitize_UTF8_Replaces_Latin1_Mojibake (T : in out Test) is
      pragma Unreferenced (T);
      --  Common Latin-1 mojibake: "résumé" in Latin-1 (F1 is ñ in Latin-1!)
      --  Better example: "café" Latin-1 -> e-acute = 0xE9 solo byte
      Input  : constant String :=
        "caf" & Character'Val (16#E9#);  --  0xE9 alone = invalid
      Expected : constant String := "caf" & U_FFFD;
      Output  : constant String := Coyote_App.Utils.Sanitize_UTF8 (Input);
   begin
      Assert (Output = Expected,
              "Latin-1 0xE9 should be replaced with U+FFFD");
   end Test_Sanitize_UTF8_Replaces_Latin1_Mojibake;

   procedure Test_Sanitize_UTF8_Replaces_Isolated_Cont (T : in out Test) is
      pragma Unreferenced (T);
      --  Isolated continuation byte 0xBF by itself
      Input  : constant String := "abc"
                                 & Character'Val (16#BF#)
                                 & "def";
      Expected : constant String := "abc" & U_FFFD & "def";
      Output  : constant String := Coyote_App.Utils.Sanitize_UTF8 (Input);
   begin
      Assert (Output = Expected,
              "isolated continuation byte should be replaced with U+FFFD");
   end Test_Sanitize_UTF8_Replaces_Isolated_Cont;

   procedure Test_Sanitize_UTF8_Replaces_Truncated_Seq (T : in out Test) is
      pragma Unreferenced (T);
      --  3-byte leader 0xE2 followed by only one continuation byte (truncated)
      Input  : constant String := "x"
                                 & Character'Val (16#E2#)
                                 & Character'Val (16#82#);
      Expected : constant String := "x" & U_FFFD & U_FFFD;
      Output  : constant String := Coyote_App.Utils.Sanitize_UTF8 (Input);
   begin
      Assert (Output = Expected,
              "truncated 3-byte sequence should be replaced with U+FFFD");
   end Test_Sanitize_UTF8_Replaces_Truncated_Seq;

   procedure Test_Sanitize_UTF8_Handles_Overlong_Seq (T : in out Test) is
      pragma Unreferenced (T);
      --  Overlong 2-byte encoding of ASCII '/': 0xC0 0xAF
      Input  : constant String := Character'Val (16#C0#)
                                 & Character'Val (16#AF#);
      Expected : constant String := U_FFFD & U_FFFD;
      Output  : constant String := Coyote_App.Utils.Sanitize_UTF8 (Input);
   begin
      Assert (Output = Expected,
              "overlong 2-byte encoding should be replaced with U+FFFD");
   end Test_Sanitize_UTF8_Handles_Overlong_Seq;

   procedure Test_Sanitize_UTF8_Handles_Empty_String (T : in out Test) is
      pragma Unreferenced (T);
      Output : constant String := Coyote_App.Utils.Sanitize_UTF8 ("");
   begin
      Assert (Output = "",
              "empty string should return empty string");
   end Test_Sanitize_UTF8_Handles_Empty_String;

   procedure Test_UTF8_Stream_Reassembles_Two_Byte (T : in out Test) is
      pragma Unreferenced (T);
      S       : Coyote_App.Utils.UTF8_Stream.Instance;
      Output  : Ada.Strings.Unbounded.Unbounded_String;
      Accent  : constant String := Character'Val (16#C3#)
                                   & Character'Val (16#A9#);
   begin
      S.Feed (Accent (Accent'First .. Accent'First), Output);
      Assert (Ada.Strings.Unbounded.Length (Output) = 0,
              "incomplete two-byte sequence should be held");
      S.Feed (Accent (Accent'First + 1 .. Accent'Last), Output);
      Assert (Ada.Strings.Unbounded.To_String (Output) = Accent,
              "two-byte sequence should be reassembled");
   end Test_UTF8_Stream_Reassembles_Two_Byte;

   procedure Test_UTF8_Stream_Reassembles_Three_Byte (T : in out Test) is
      pragma Unreferenced (T);
      S       : Coyote_App.Utils.UTF8_Stream.Instance;
      Output  : Ada.Strings.Unbounded.Unbounded_String;
      Euro    : constant String := Character'Val (16#E2#)
                                   & Character'Val (16#82#)
                                   & Character'Val (16#AC#);
   begin
      S.Feed (Euro (Euro'First .. Euro'First + 1), Output);
      Assert (Ada.Strings.Unbounded.Length (Output) = 0,
              "incomplete three-byte sequence should be held");
      S.Feed (Euro (Euro'First + 2 .. Euro'Last), Output);
      Assert (Ada.Strings.Unbounded.To_String (Output) = Euro,
              "three-byte sequence should be reassembled");
   end Test_UTF8_Stream_Reassembles_Three_Byte;

   procedure Test_UTF8_Stream_Reassembles_Four_Byte (T : in out Test) is
      pragma Unreferenced (T);
      S       : Coyote_App.Utils.UTF8_Stream.Instance;
      Output  : Ada.Strings.Unbounded.Unbounded_String;
      Smile   : constant String := Character'Val (16#F0#)
                                   & Character'Val (16#9F#)
                                   & Character'Val (16#98#)
                                   & Character'Val (16#80#);
   begin
      S.Feed (Smile (Smile'First .. Smile'First + 2), Output);
      Assert (Ada.Strings.Unbounded.Length (Output) = 0,
              "incomplete four-byte sequence should be held");
      S.Feed (Smile (Smile'First + 3 .. Smile'Last), Output);
      Assert (Ada.Strings.Unbounded.To_String (Output) = Smile,
              "four-byte sequence should be reassembled");
   end Test_UTF8_Stream_Reassembles_Four_Byte;

   procedure Test_UTF8_Stream_Flushes_Incomplete (T : in out Test) is
      pragma Unreferenced (T);
      S       : Coyote_App.Utils.UTF8_Stream.Instance;
      Output  : Ada.Strings.Unbounded.Unbounded_String;
      Expected : constant String := Character'Val (16#EF#)
                                    & Character'Val (16#BF#)
                                    & Character'Val (16#BD#);
   begin
      S.Feed ("" & Character'Val (16#E2#), Output);
      S.Flush (Output);
      Assert (Ada.Strings.Unbounded.To_String (Output) = Expected,
              "flush should replace an incomplete sequence");
   end Test_UTF8_Stream_Flushes_Incomplete;

end Coyote_Utils_Tests;
