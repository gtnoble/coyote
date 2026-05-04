--  Session_Fixture — helpers for writing native test session files.
--
--  This support package creates and appends JSONL records compatible with
--  the native session format used by LLM.Session_Store.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Session_Fixture is

   --  Write a temporary native-format session file under Home.
   --
   --  Creates:
   --    <home>/.coyote/sessions/<cwd-slug>/<uuid>.jsonl
   --
   --  The file always contains the native header line.  When Name is
   --  non-empty, a native session_info record is appended as the second
   --  line so directory-listing tests can observe the session name.
   function Create_Native_Session
     (Home     : String;
      Cwd_Slug : String;
      Name     : String) return String;

   --  Append one native user text message line.
   procedure Append_User_Message
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Text     : String);

   --  Append one native assistant text message line.
   procedure Append_Assistant_Text
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Text     : String);

   --  Append one native assistant tool-call message line.
   procedure Append_Assistant_Tool_Call
     (Home      : String;
      Cwd_Slug  : String;
      UUID      : String;
      Tool_Id   : String;
      Tool_Name : String;
      Args_JSON : String);

   --  Append one native tool-result message line.
   procedure Append_Tool_Result
     (Home      : String;
      Cwd_Slug  : String;
      UUID      : String;
      Tool_Id   : String;
      Result    : String;
      Is_Error  : Boolean := False);

   --  Append one legacy envelope line containing a user message.
   procedure Append_Legacy_User_Message
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Text     : String);

   --  Append one model_change sentinel line.
   procedure Append_Model_Change
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Provider : String;
      Model_Id : String);

   --  Append an end-of-turn separator line.
   --
   --  The native store currently writes no explicit turn-separator records,
   --  so this helper is a no-op.
   procedure Append_Turn_End
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String);

   --  Return the full path to the session JSONL file.
   function Session_File_Path
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String) return String;

end Session_Fixture;
