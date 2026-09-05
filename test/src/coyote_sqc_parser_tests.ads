--  Coyote_SQC.Session_Parser — AUnit test suite.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_SQC_Parser_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Fixture: test/fixtures/sqc/v3_session.jsonl
   procedure Test_V3_Session_Id          (T : in out Test);
   procedure Test_V3_Turn_Count          (T : in out Test);
   procedure Test_V3_Model               (T : in out Test);
   procedure Test_V3_First_User_Message  (T : in out Test);
   procedure Test_V3_Tool_Failure_Flags  (T : in out Test);
   procedure Test_Multi_Tool_Metrics     (T : in out Test);
   procedure Test_V3_Source_Directory    (T : in out Test);

   --  Fixture: test/fixtures/sqc/v1_session.jsonl
   procedure Test_V1_Session_Id          (T : in out Test);
   procedure Test_V1_Source_Directory    (T : in out Test);
   procedure Test_V1_Prompt_Prefix_Strip (T : in out Test);
   procedure Test_V1_Turn_Count          (T : in out Test);
   procedure Test_V1_Start_Time          (T : in out Test);
   procedure Test_V1_Model               (T : in out Test);
   procedure Test_V1_Tool_Call_Flags     (T : in out Test);
   procedure Test_V3_Start_Time          (T : in out Test);

   --  Fixture: test/fixtures/sqc/thinking_session.jsonl
   procedure Test_Thinking_Tokens        (T : in out Test);
   procedure Test_Thinking_Enabled       (T : in out Test);
   procedure Test_Thinking_Absent        (T : in out Test);
   procedure Test_Thinking_Text_Estimate (T : in out Test);
   procedure Test_Tool_Call_Token_Estimates (T : in out Test);

   --  Fixture: test/fixtures/sqc/compaction_session.jsonl
   procedure Test_Compaction_All_Turns   (T : in out Test);

   --  Encode_Cwd pure unit tests.
   procedure Test_Encode_Cwd_Absolute    (T : in out Test);
   procedure Test_Encode_Cwd_Relative    (T : in out Test);
   procedure Test_Whitespace_Collapse     (T : in out Test);

   --  Token accounting normalization tests.
   procedure Test_Anthropic_Input_Token_Normalization (T : in out Test);

   --  Incremental-reload tests: Parse_File must populate File_Path / File_Mtime.
   procedure Test_Parse_File_Sets_File_Path  (T : in out Test);
   procedure Test_Parse_File_Sets_File_Mtime (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_SQC_Parser_Tests;
