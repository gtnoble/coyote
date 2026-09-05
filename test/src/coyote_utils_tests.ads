with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_Utils_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Reads_File_When_Path_Exists  (T : in out Test);
   procedure Test_Returns_Arg_When_Not_A_File  (T : in out Test);
   procedure Test_Returns_Empty_For_Empty_Path (T : in out Test);
   procedure Test_Reads_Multiline_File         (T : in out Test);

   procedure Test_Strip_Session_Prefix_With_Prefix    (T : in out Test);
   procedure Test_Strip_Session_Prefix_Without_Prefix (T : in out Test);
   procedure Test_Strip_Session_Prefix_Empty           (T : in out Test);
   procedure Test_Active_Executable_Path_Is_Absolute   (T : in out Test);
   procedure Test_Spawn_Detached_Rejects_Empty_Args    (T : in out Test);
   procedure Test_Shell_Quote_Preserves_Spaces         (T : in out Test);
   procedure Test_Shell_Quote_Escapes_Apostrophes      (T : in out Test);
   procedure Test_Hidden_Tool_Arguments                (T : in out Test);

   procedure Test_Sanitize_UTF8_Passthrough_Pure_ASCII (T : in out Test);
   procedure Test_Sanitize_UTF8_Passthrough_Valid_UTF8  (T : in out Test);
   procedure Test_Sanitize_UTF8_Replaces_Latin1_Mojibake (T : in out Test);
   procedure Test_Sanitize_UTF8_Replaces_Isolated_Cont   (T : in out Test);
   procedure Test_Sanitize_UTF8_Replaces_Truncated_Seq   (T : in out Test);
   procedure Test_Sanitize_UTF8_Handles_Overlong_Seq     (T : in out Test);
   procedure Test_Sanitize_UTF8_Handles_Empty_String     (T : in out Test);
   procedure Test_UTF8_Stream_Reassembles_Two_Byte (T : in out Test);
   procedure Test_UTF8_Stream_Reassembles_Three_Byte (T : in out Test);
   procedure Test_UTF8_Stream_Reassembles_Four_Byte (T : in out Test);
   procedure Test_UTF8_Stream_Flushes_Incomplete (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_Utils_Tests;
