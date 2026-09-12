with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App;
with Coyote_App.Frontend;
with Coyote_App.History;
with LLM.Session_Store;
with LLM.Types;

package body Coyote_App_History_Tests is

   use AUnit.Assertions;

   use type LLM.Types.Message_Format;

   type Format_Array is array (Positive range 1 .. 6)
     of LLM.Types.Message_Format;

   type Recorder is new Coyote_App.Frontend.Instance with record
      Formats      : Format_Array := (others => LLM.Types.Format_Unspecified);
      Format_Count : Natural := 0;
   end record;

   overriding procedure Set_Status
     (F : in out Recorder; Text : String);
   overriding procedure Set_Mode
     (F : in out Recorder; Mode : Coyote_App.Frontend.Run_Mode);
   overriding procedure Set_Response_Format
     (F      : in out Recorder;
      Format : LLM.Types.Message_Format);
   overriding procedure Append_Text
     (F : in out Recorder; Text : String);
   overriding procedure End_Text_Block (F : in out Recorder);
   overriding procedure Begin_Thinking (F : in out Recorder);
   overriding procedure Append_Thinking
     (F : in out Recorder; Text : String);
   overriding procedure End_Thinking (F : in out Recorder);
   overriding procedure Begin_Tool
     (F               : in out Recorder;
      Name            : String;
      Args_Json       : String;
      Session_Id      : String;
      Tool_Id         : String;
      Model           : String := "";
      Source_Directory : String := "";
      Session_Start   : String := "";
      Turn_Index      : Positive := 1;
      Call_In_Turn    : Positive := 1;
      Initial_Status  : Coyote_App.Frontend.Tool_Status :=
        Coyote_App.Frontend.Running);
   overriding procedure Set_Tool_Status
     (F       : in out Recorder;
      Tool_Id : String;
      Status  : Coyote_App.Frontend.Tool_Status);
   overriding procedure End_Tool
     (F           : in out Recorder;
      Tool_Id     : String;
      Status      : Coyote_App.Frontend.Tool_End_Status;
      Result_Text : String := "";
      Media_Type  : String := "");
   overriding procedure Append_Turn_Footer
     (F       : in out Recorder;
      Text    : String;
      Kind    : Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary : String := "");
   overriding procedure Append_Fork_Action
     (F      : in out Recorder;
      UUID   : String;
      Turn_N : Positive;
      Step_N : Natural := 0);
   overriding procedure Append_Notice
     (F    : in out Recorder;
      Kind : Coyote_App.Frontend.Notice_Kind;
      Text : String);
   overriding procedure Show_Detail
     (F       : in out Recorder;
      Title   : String;
      Content : String);
   overriding function Read_Prompt (F : in out Recorder) return String;
   overriding procedure Shutdown (F : in out Recorder);

   overriding
   procedure Set_Status
     (F : in out Recorder; Text : String) is
   begin
      null;
   end Set_Status;

   overriding
   procedure Set_Mode
     (F : in out Recorder; Mode : Coyote_App.Frontend.Run_Mode) is
   begin
      null;
   end Set_Mode;

   overriding
   procedure Set_Response_Format
     (F      : in out Recorder;
      Format : LLM.Types.Message_Format)
   is
   begin
      F.Format_Count := F.Format_Count + 1;
      if F.Format_Count <= F.Formats'Last then
         F.Formats (F.Format_Count) := Format;
      end if;
   end Set_Response_Format;

   overriding
   procedure Append_Text
     (F : in out Recorder; Text : String) is
   begin
      null;
   end Append_Text;

   overriding
   procedure End_Text_Block (F : in out Recorder) is
   begin
      null;
   end End_Text_Block;

   overriding
   procedure Begin_Thinking (F : in out Recorder) is
   begin
      null;
   end Begin_Thinking;

   overriding
   procedure Append_Thinking
     (F : in out Recorder; Text : String) is
   begin
      null;
   end Append_Thinking;

   overriding
   procedure End_Thinking (F : in out Recorder) is
   begin
      null;
   end End_Thinking;

   overriding
   procedure Begin_Tool
     (F               : in out Recorder;
      Name            : String;
      Args_Json       : String;
      Session_Id      : String;
      Tool_Id         : String;
      Model           : String := "";
      Source_Directory : String := "";
      Session_Start   : String := "";
      Turn_Index      : Positive := 1;
      Call_In_Turn    : Positive := 1;
      Initial_Status  : Coyote_App.Frontend.Tool_Status :=
        Coyote_App.Frontend.Running) is
   begin
      null;
   end Begin_Tool;

   overriding
   procedure Set_Tool_Status
     (F       : in out Recorder;
      Tool_Id : String;
      Status  : Coyote_App.Frontend.Tool_Status) is
   begin
      null;
   end Set_Tool_Status;

   overriding
   procedure End_Tool
     (F           : in out Recorder;
      Tool_Id     : String;
      Status      : Coyote_App.Frontend.Tool_End_Status;
      Result_Text : String := "";
      Media_Type  : String := "") is
   begin
      null;
   end End_Tool;

   overriding
   procedure Append_Turn_Footer
     (F       : in out Recorder;
      Text    : String;
      Kind    : Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary : String := "") is
   begin
      null;
   end Append_Turn_Footer;

   overriding
   procedure Append_Fork_Action
     (F      : in out Recorder;
      UUID   : String;
      Turn_N : Positive;
      Step_N : Natural := 0) is
   begin
      null;
   end Append_Fork_Action;

   overriding
   procedure Append_Notice
     (F    : in out Recorder;
      Kind : Coyote_App.Frontend.Notice_Kind;
      Text : String) is
   begin
      null;
   end Append_Notice;

   overriding
   procedure Show_Detail
     (F       : in out Recorder;
      Title   : String;
      Content : String) is
   begin
      null;
   end Show_Detail;

   overriding
   function Read_Prompt (F : in out Recorder) return String is
   begin
      return "";
   end Read_Prompt;

   overriding
   procedure Shutdown (F : in out Recorder) is
   begin
      null;
   end Shutdown;

   function Assistant_JSON
     (Text   : String;
      Format : String := "";
      Version : String := "") return String
   is
   begin
      return "{""role"":""assistant"",""content"":[{""type"":""text"",""text"":"""
        & Text
        & """}],""usage"":{},""stopReason"":""stop"""
        & (if Format'Length > 0
           then ",""format"":""" & Format & """"
           else "")
        & (if Version'Length > 0
           then ",""formatVersion"":" & Version
           else "")
        & "}";
   end Assistant_JSON;

   procedure Test_Replay_Uses_Persisted_Assistant_Formats
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Old_Markup : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_INCREMENTAL_MARKUP", "");
      Old_Markup_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_INCREMENTAL_MARKUP");
      Root : constant String := "/tmp/coyote_history_format_test";
      Session_Id : Unbounded_String;
      Path       : Unbounded_String;
      File       : Ada.Text_IO.File_Type;
      Frontend : Recorder;
      State : Coyote_App.App_State;
   begin
      if Ada.Directories.Exists (Root) then
         Ada.Directories.Delete_Tree (Root);
      end if;
      Ada.Directories.Create_Path (Root & "/.coyote");
      Ada.Environment_Variables.Set ("HOME", Root);
      Ada.Environment_Variables.Set ("COYOTE_INCREMENTAL_MARKUP", "1");

      Session_Id := To_Unbounded_String
        (LLM.Session_Store.Create_Session ("/tmp"));
      Path := To_Unbounded_String
        (LLM.Session_Store.Session_File_Path (To_String (Session_Id)));
      Ada.Text_IO.Open
        (File, Ada.Text_IO.Append_File, To_String (Path));
      Ada.Text_IO.Put_Line
        (File, "{""role"":""user"",""content"":[]}");
      Ada.Text_IO.Put_Line
        (File, Assistant_JSON ("CSM-1", "coyote-stream"));
      Ada.Text_IO.Put_Line
        (File, Assistant_JSON ("CSM-2", "coyote-stream", "2"));
      Ada.Text_IO.Put_Line
        (File, "{""role"":""user"",""content"":[]}");
      Ada.Text_IO.Put_Line (File, Assistant_JSON ("legacy"));
      Ada.Text_IO.Put_Line
        (File, Assistant_JSON ("unknown-format", "future"));
      Ada.Text_IO.Put_Line
        (File, Assistant_JSON ("unknown-version", "coyote-stream", "99"));
      Ada.Text_IO.Close (File);

      Coyote_App.History.Render_Session_History
        (UUID     => To_String (Session_Id),
         Frontend => Frontend,
         State    => State);

      Assert (Frontend.Format_Count = 6,
              "replay should select mixed formats and restore live mode");
      Assert (Frontend.Formats (1) = LLM.Types.Format_Coyote_Stream,
              "old coyote-stream should remain CSM-1");
      Assert (Frontend.Formats (2) = LLM.Types.Format_Coyote_Stream_2,
              "versioned coyote-stream should select CSM-2");
      Assert (Frontend.Formats (3) = LLM.Types.Format_Markdown,
              "missing persisted format should select Markdown");
      Assert (Frontend.Formats (4) = LLM.Types.Format_Markdown,
              "unknown format should fall back to Markdown");
      Assert (Frontend.Formats (5) = LLM.Types.Format_Markdown,
              "unknown version should fall back to Markdown");
      Assert (Frontend.Formats (6) = LLM.Types.Format_Coyote_Stream_2,
              "configured CSM-2 mode should be restored after replay");

      if Ada.Text_IO.Is_Open (File) then
         Ada.Text_IO.Close (File);
      end if;
      if Ada.Directories.Exists (Root) then
         Ada.Directories.Delete_Tree (Root);
      end if;
      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      else
         Ada.Environment_Variables.Clear ("HOME");
      end if;
      if Old_Markup_Set then
         Ada.Environment_Variables.Set
           ("COYOTE_INCREMENTAL_MARKUP", Old_Markup);
      else
         Ada.Environment_Variables.Clear ("COYOTE_INCREMENTAL_MARKUP");
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         if Ada.Directories.Exists (Root) then
            Ada.Directories.Delete_Tree (Root);
         end if;
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         if Old_Markup_Set then
            Ada.Environment_Variables.Set
              ("COYOTE_INCREMENTAL_MARKUP", Old_Markup);
         else
            Ada.Environment_Variables.Clear ("COYOTE_INCREMENTAL_MARKUP");
         end if;
         raise;
   end Test_Replay_Uses_Persisted_Assistant_Formats;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("Coyote_App.History replays persisted assistant formats",
            Test_Replay_Uses_Persisted_Assistant_Formats'Access));
      return Result;
   end Suite;

end Coyote_App_History_Tests;
