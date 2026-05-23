--  Coyote_SQC_Parser_Tests body.
--
--  Project: coyote

with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Containers;
with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_SQC.Session_Parser;
with Coyote_SQC.Metrics;
with Coyote_SQC.Data_Model;

package body Coyote_SQC_Parser_Tests is

   use AUnit.Assertions;
   use Coyote_SQC.Data_Model;
   use type Ada.Containers.Count_Type;

   function Fixture (Name : String) return String is
   begin
      return Ada.Directories.Current_Directory & "/fixtures/sqc/" & Name;
   end Fixture;

   --  ── v3 session tests ─────────────────────────────────────────────────

   procedure Test_V3_Session_Id (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v3_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must return Ok = True for v3 fixture");
      Assert
        (To_String (Session.Session_Id) =
           "00000000-0000-4000-8000-000000000001",
         "Session_Id mismatch: " & To_String (Session.Session_Id));
   end Test_V3_Session_Id;

   procedure Test_V3_Turn_Count (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v3_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Session.Turns.Length = 3,
         "Expected 3 turns; got "
         & Ada.Containers.Count_Type'Image (Session.Turns.Length));
   end Test_V3_Turn_Count;

   procedure Test_V3_Model (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v3_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      --  Two model_change records; last one is anthropic/claude-sonnet-4-5.
      Assert
        (To_String (Session.Model) = "anthropic/claude-sonnet-4-5",
         "Model should be last model_change value; got "
         & To_String (Session.Model));
   end Test_V3_Model;

   procedure Test_V3_First_User_Message (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
      Msg     : constant String := "Hello, help me write a test.";
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v3_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (To_String (Session.First_User_Message) = Msg,
         "First_User_Message mismatch: '"
         & To_String (Session.First_User_Message) & "'");
   end Test_V3_First_User_Message;

   procedure Test_V3_Tool_Failure_Flags (T : in out Test) is
      pragma Unreferenced (T);
      Session  : Session_Record;
      Ok       : Boolean;
      Turn_2   : Turn_Record;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v3_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      --  Turn 2 (index 2) has 2 tool calls: tc-001 (ok) and tc-002 (failed).
      Assert
        (Session.Turns.Length >= 2, "Expected at least 2 turns");
      Turn_2 := Session.Turns.Element (2);
      Assert
        (Turn_2.Tool_Calls.Length = 2,
         "Turn 2 should have 2 tool calls; got "
         & Ada.Containers.Count_Type'Image (Turn_2.Tool_Calls.Length));
      Assert
        (not Turn_2.Tool_Calls.Element (1).Failed,
         "tc-001 should not be Failed");
      Assert
        (Turn_2.Tool_Calls.Element (2).Failed,
         "tc-002 should be Failed (isError: true)");
   end Test_V3_Tool_Failure_Flags;

   --  §14.2 Multi-tool turn via Metrics: N_Tool_Calls=2, N_Failed_Tool_Calls=1.
   procedure Test_Multi_Tool_Metrics (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
      M       : Coyote_SQC.Data_Model.Session_Metrics_Record;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v3_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      M := Coyote_SQC.Metrics.Compute (Session);
      Assert
        (M.N_Tool_Calls = 2,
         "N_Tool_Calls should be 2; got "
         & Natural'Image (M.N_Tool_Calls));
      Assert
        (M.N_Failed_Tool_Calls = 1,
         "N_Failed_Tool_Calls should be 1; got "
         & Natural'Image (M.N_Failed_Tool_Calls));
   end Test_Multi_Tool_Metrics;

   procedure Test_V3_Source_Directory (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v3_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (To_String (Session.Source_Directory) = "/home/user/testproject",
         "Source_Directory mismatch: "
         & To_String (Session.Source_Directory));
   end Test_V3_Source_Directory;

   --  ── v1 (legacy) session tests ─────────────────────────────────────────

   procedure Test_V1_Session_Id (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v1_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed for v1 fixture");
      Assert
        (To_String (Session.Session_Id) =
           "00000000-0000-4000-8000-000000000002",
         "v1 Session_Id mismatch: " & To_String (Session.Session_Id));
   end Test_V1_Session_Id;

   procedure Test_V1_Source_Directory (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v1_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (To_String (Session.Source_Directory) = "/home/user/legacyproject",
         "v1 Source_Directory (workDir) mismatch: "
         & To_String (Session.Source_Directory));
   end Test_V1_Source_Directory;

   procedure Test_V1_Prompt_Prefix_Strip (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
      Msg     : constant String := "Fix the bug in main.adb";
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v1_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (To_String (Session.First_User_Message) = Msg,
         "Prefix [Model -> ...] should be stripped; got '"
         & To_String (Session.First_User_Message) & "'");
   end Test_V1_Prompt_Prefix_Strip;

   --  V1 turn count — exactly 1 assistant message in the fixture.
   procedure Test_V1_Turn_Count (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v1_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Session.Turns.Length = 1,
         "V1 session must have 1 turn; got "
         & Ada.Containers.Count_Type'Image (Session.Turns.Length));
   end Test_V1_Turn_Count;

   --  §14.2: V1 start time — createdAt = 1744469520000 ms → year 2025.
   procedure Test_V1_Start_Time (T : in out Test) is
      pragma Unreferenced (T);
      use Ada.Calendar;
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v1_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Year (Session.Start_Time) = 2025,
         "V1 start time year must be 2025 (createdAt=1744469520000); got "
         & Year_Number'Image (Year (Session.Start_Time)));
   end Test_V1_Start_Time;

   --  §14.2: V1 model — no model_change record; Model must be empty string.
   procedure Test_V1_Model (T : in out Test) is
      pragma Unreferenced (T);
      use Ada.Strings.Unbounded;
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v1_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Session.Model = Null_Unbounded_String,
         "V1 session with no model_change must have empty Model; got '"
         & To_String (Session.Model) & "'");
   end Test_V1_Model;

   --  §14.2: V1 tool call flags -- V1 fixture has no tool calls; N_Tool_Calls=0.
   procedure Test_V1_Tool_Call_Flags (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v1_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Session.Turns.Length = 1, "Expected 1 turn");
      Assert
        (Session.Turns.Element (1).Tool_Calls.Is_Empty,
         "V1 session fixture has no tool calls; Tool_Calls must be empty");
   end Test_V1_Tool_Call_Flags;

   --  V3 start time — parse "2025-04-12T14:32:00.000Z".
   --  Verify that the year is 2025 (UTC conversion produces correct year).
   procedure Test_V3_Start_Time (T : in out Test) is
      pragma Unreferenced (T);
      use Ada.Calendar;
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("v3_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Year (Session.Start_Time) = 2025,
         "V3 start time year must be 2025; got "
         & Year_Number'Image (Year (Session.Start_Time)));
   end Test_V3_Start_Time;

   --  ── thinking session tests ────────────────────────────────────────────

   procedure Test_Thinking_Tokens (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("thinking_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Session.Turns.Length = 1, "Expected 1 turn");
      Assert
        (Session.Turns.Element (1).Thinking_Tokens = 42,
         "Thinking_Tokens should be 42; got "
         & Natural'Image (Session.Turns.Element (1).Thinking_Tokens));
   end Test_Thinking_Tokens;

   procedure Test_Thinking_Enabled (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("thinking_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Session.Turns.Element (1).Thinking_Enabled,
         "Thinking_Enabled should be True for a thinking block");
   end Test_Thinking_Enabled;

   --  §14.2: Thinking estimation absent — no "thinking" field in usage;
   --  backward compat: Thinking_Tokens must default to 0.
   procedure Test_Thinking_Absent (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("no_thinking_field_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (Session.Turns.Length = 1, "Expected 1 turn");
      Assert
        (Session.Turns.Element (1).Thinking_Tokens = 0,
         "Thinking_Tokens must default to 0 when field absent; got "
         & Natural'Image (Session.Turns.Element (1).Thinking_Tokens));
      Assert
        (not Session.Turns.Element (1).Thinking_Enabled,
         "Thinking_Enabled must be False when no thinking block present");
   end Test_Thinking_Absent;

   --  ── compaction session tests ──────────────────────────────────────────

   procedure Test_Compaction_All_Turns (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("compaction_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      --  Both pre- and post-compaction turns must be counted (total = 2).
      Assert
        (Session.Turns.Length = 2,
         "Expected 2 turns across compaction; got "
         & Ada.Containers.Count_Type'Image (Session.Turns.Length));
   end Test_Compaction_All_Turns;

   --  ── Encode_Cwd pure tests ─────────────────────────────────────────────

   procedure Test_Encode_Cwd_Absolute (T : in out Test) is
      pragma Unreferenced (T);
      Slug : constant String :=
        Coyote_SQC.Session_Parser.Encode_Cwd ("/home/user/Projects/foo");
   begin
      Assert
        (Slug = "--home-user-Projects-foo--",
         "Encode_Cwd absolute path mismatch: '" & Slug & "'");
   end Test_Encode_Cwd_Absolute;

   procedure Test_Encode_Cwd_Relative (T : in out Test) is
      pragma Unreferenced (T);
      Slug : constant String :=
        Coyote_SQC.Session_Parser.Encode_Cwd ("myproject");
   begin
      Assert
        (Slug = "--myproject--",
         "Encode_Cwd relative path mismatch: '" & Slug & "'");
   end Test_Encode_Cwd_Relative;

   --  §5.9: interior whitespace collapsed to single space.
   procedure Test_Whitespace_Collapse (T : in out Test) is
      pragma Unreferenced (T);
      Session : Session_Record;
      Ok      : Boolean;
   begin
      Coyote_SQC.Session_Parser.Parse_File
        (Fixture ("whitespace_session.jsonl"), Session, Ok);
      Assert (Ok, "Parse_File must succeed");
      Assert
        (To_String (Session.First_User_Message) = "Fix the bug in main.adb",
         "Interior whitespace should be collapsed; got '"
         & To_String (Session.First_User_Message) & "'");
   end Test_Whitespace_Collapse;

end Coyote_SQC_Parser_Tests;
