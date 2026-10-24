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
with Session_Fixture;

package body Coyote_App_History_Tests is

   use AUnit.Assertions;
   use type Coyote_App.Frontend.Tool_Status;

   type Text_Block_Array is
     array (Positive range 1 .. 8) of Unbounded_String;

   type Tool_Event_Array is array (Positive range 1 .. 8) of Unbounded_String;

   type Tool_Status_Array is
     array (Positive range 1 .. 8) of Coyote_App.Frontend.Tool_Status;

   type Tool_End_Status_Array is
     array (Positive range 1 .. 8) of Coyote_App.Frontend.Tool_End_Status;

   type Recorder is new Coyote_App.Frontend.Instance with record
      Source_Directory       : Unbounded_String;
      Tool_Source_Directory  : Unbounded_String;
      Source_Set_Before_Text : Boolean := False;
      Text_Block_Count       : Natural := 0;
      Text_Block_Texts       : Text_Block_Array :=
        (others => Null_Unbounded_String);
      Begin_Tool_Count       : Natural := 0;
      Begin_Tool_Ids         : Tool_Event_Array :=
        (others => Null_Unbounded_String);
      Begin_Tool_Statuses    : Tool_Status_Array :=
        (others => Coyote_App.Frontend.Running);
      End_Tool_Count         : Natural := 0;
      End_Tool_Ids           : Tool_Event_Array :=
        (others => Null_Unbounded_String);
      End_Tool_Statuses      : Tool_End_Status_Array :=
        (others => Coyote_App.Frontend.Success);
      End_Tool_Results       : Tool_Event_Array :=
        (others => Null_Unbounded_String);
   end record;

   overriding procedure Set_Source_Directory
     (F : in out Recorder; Directory : String);
   overriding procedure Set_Status
     (F : in out Recorder; Text : String);
   overriding procedure Set_Mode
     (F : in out Recorder; Mode : Coyote_App.Frontend.Run_Mode);
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
   procedure Set_Source_Directory
     (F : in out Recorder; Directory : String) is
   begin
      F.Source_Directory := To_Unbounded_String (Directory);
   end Set_Source_Directory;

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
   procedure Append_Text
     (F : in out Recorder; Text : String) is
   begin
      F.Source_Set_Before_Text := Length (F.Source_Directory) > 0;
      F.Text_Block_Count := F.Text_Block_Count + 1;
      if F.Text_Block_Count <= F.Text_Block_Texts'Last then
         F.Text_Block_Texts (F.Text_Block_Count) :=
           To_Unbounded_String (Text);
      end if;
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
      F.Tool_Source_Directory := To_Unbounded_String (Source_Directory);
      F.Begin_Tool_Count := F.Begin_Tool_Count + 1;
      if F.Begin_Tool_Count <= F.Begin_Tool_Ids'Last then
         F.Begin_Tool_Ids (F.Begin_Tool_Count) :=
           To_Unbounded_String (Tool_Id);
         F.Begin_Tool_Statuses (F.Begin_Tool_Count) := Initial_Status;
      end if;
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
      F.End_Tool_Count := F.End_Tool_Count + 1;
      if F.End_Tool_Count <= F.End_Tool_Ids'Last then
         F.End_Tool_Ids (F.End_Tool_Count) :=
           To_Unbounded_String (Tool_Id);
         F.End_Tool_Statuses (F.End_Tool_Count) := Status;
         F.End_Tool_Results (F.End_Tool_Count) :=
           To_Unbounded_String (Result_Text);
      end if;
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

   function Assistant_JSON (Text : String) return String is
   begin
      return "{""role"":""assistant"",""content"":[{""type"":""text"""
        & ",""text"":"""
        & Text
        & """}],""usage"":{},""stopReason"":""stop"""
        & "}";
   end Assistant_JSON;

   procedure Append_Result_Status
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Tool_Id  : String;
      Result   : String;
      Status   : String);

   procedure Test_Legacy_Format_Metadata_Ignored
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Root         : constant String := "/tmp/coyote_history_format_test";
      Session_Id   : Unbounded_String;
      Path         : Unbounded_String;
      File         : Ada.Text_IO.File_Type;
      Frontend     : Recorder;
      State        : Coyote_App.App_State;
   begin
      if Ada.Directories.Exists (Root) then
         Ada.Directories.Delete_Tree (Root);
      end if;
      Ada.Directories.Create_Path (Root & "/.coyote");
      Ada.Environment_Variables.Set ("HOME", Root);

      Session_Id := To_Unbounded_String
        (LLM.Session_Store.Create_Session ("/tmp"));
      Path := To_Unbounded_String
        (LLM.Session_Store.Session_File_Path (To_String (Session_Id)));
      Ada.Text_IO.Open
        (File, Ada.Text_IO.Append_File, To_String (Path));
      Ada.Text_IO.Put_Line
        (File, "{""role"":""user"",""content"":[]}");
      Ada.Text_IO.Put_Line
        (File,
         "{""role"":""assistant"",""format"":""coyote-stream"""
         & ",""formatVersion"":2,""content"":[{""type"":""text"""
         & ",""text"":""<p>legacy response</p>""}]"
         & ",""usage"":{},""stopReason"":""stop""}");
      Ada.Text_IO.Put_Line
        (File, "{""role"":""user"",""content"":[]}");
      Ada.Text_IO.Put_Line (File, Assistant_JSON ("legacy"));
      Ada.Text_IO.Put_Line
        (File,
         "{""role"":""assistant"",""format"":""future"",""content"""
         & ":[{""type"":""text"",""text"":""future-format""}]"
         & ",""usage"":{},""stopReason"":""stop""}");
      Ada.Text_IO.Close (File);

      Coyote_App.History.Render_Session_History
        (UUID     => To_String (Session_Id),
         Frontend => Frontend,
         State    => State);

      Assert (Frontend.Text_Block_Count = 3,
              "replay should render all three assistant text blocks");
      Assert
        (To_String (Frontend.Source_Directory) = "/tmp",
         "replay should set the session source directory");
      Assert
        (Frontend.Source_Set_Before_Text,
         "replay should set the source directory before rendering text");
      Assert
        (To_String (Frontend.Text_Block_Texts (1)) =
           "<p>legacy response</p>",
         "legacy XML-shaped response is delivered as source content");
      Assert
        (To_String (Frontend.Text_Block_Texts (2)) = "legacy",
         "ordinary legacy text remains visible during replay");
      Assert
        (To_String (Frontend.Text_Block_Texts (3)) = "future-format",
         "unknown format metadata does not suppress replay content");

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
         raise;
   end Test_Legacy_Format_Metadata_Ignored;

   procedure Test_Tool_Replay_Status_And_Result (T : in out Test) is
      pragma Unreferenced (T);
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Root : constant String := "/tmp/coyote_history_tool_test";
      Cwd_Slug : constant String := "--tmp--";
      Session_Id : Unbounded_String;
      Frontend : Recorder;
      State : Coyote_App.App_State;
   begin
      if Ada.Directories.Exists (Root) then
         Ada.Directories.Delete_Tree (Root);
      end if;
      Ada.Directories.Create_Path (Root);
      Ada.Environment_Variables.Set ("HOME", Root);

      Session_Id := To_Unbounded_String
        (Session_Fixture.Create_Native_Session
           (Home => Root, Cwd_Slug => Cwd_Slug, Name => "tool replay"));
      Session_Fixture.Append_Assistant_Tool_Call
        (Home => Root, Cwd_Slug => Cwd_Slug,
         UUID => To_String (Session_Id), Tool_Id => "success-id",
         Tool_Name => "shell", Args_JSON => "{""command"":""true""}");
      Session_Fixture.Append_Tool_Result
        (Home => Root, Cwd_Slug => Cwd_Slug,
         UUID => To_String (Session_Id), Tool_Id => "success-id",
         Result => "success payload");
      Session_Fixture.Append_Assistant_Tool_Call
        (Home => Root, Cwd_Slug => Cwd_Slug,
         UUID => To_String (Session_Id), Tool_Id => "timeout-id",
         Tool_Name => "shell", Args_JSON => "{}");
      Append_Result_Status (Root, Cwd_Slug, To_String (Session_Id),
                           "timeout-id", "timeout payload", "timed_out");
      Session_Fixture.Append_Assistant_Tool_Call
        (Home => Root, Cwd_Slug => Cwd_Slug,
         UUID => To_String (Session_Id), Tool_Id => "cancel-id",
         Tool_Name => "shell", Args_JSON => "{}");
      Append_Result_Status (Root, Cwd_Slug, To_String (Session_Id),
                           "cancel-id", "cancel payload", "cancelled");
      Session_Fixture.Append_Assistant_Tool_Call
        (Home => Root, Cwd_Slug => Cwd_Slug,
         UUID => To_String (Session_Id), Tool_Id => "error-id",
         Tool_Name => "shell", Args_JSON => "{}");
      Session_Fixture.Append_Tool_Result
        (Home => Root, Cwd_Slug => Cwd_Slug,
         UUID => To_String (Session_Id), Tool_Id => "error-id",
         Result => "error payload", Is_Error => True);
      Session_Fixture.Append_Assistant_Tool_Call
        (Home => Root, Cwd_Slug => Cwd_Slug,
         UUID => To_String (Session_Id), Tool_Id => "unmatched-id",
         Tool_Name => "shell", Args_JSON => "{}");

      Coyote_App.History.Render_Session_History
        (UUID => To_String (Session_Id), Frontend => Frontend,
         State => State);

      Assert (Frontend.Begin_Tool_Count = 5,
              "replay begins each recorded tool call");
      Assert (Frontend.End_Tool_Count = 5,
              "replay ends each recorded tool call");
      Assert
        (To_String (Frontend.Begin_Tool_Ids (1)) = "success-id"
         and then Frontend.Begin_Tool_Statuses (1) =
           Coyote_App.Frontend.Success,
         "successful history begins in terminal Success state");
      Assert
        (To_String (Frontend.End_Tool_Ids (1)) = "success-id"
         and then Frontend.End_Tool_Statuses (1) =
           Coyote_App.Frontend.Success
         and then To_String (Frontend.End_Tool_Results (1)) =
           "success payload",
         "successful history retains result payload and matching ID");
      Assert
        (Frontend.Begin_Tool_Statuses (2) = Coyote_App.Frontend.Timed_Out
         and then Frontend.End_Tool_Statuses (2) =
           Coyote_App.Frontend.Timed_Out,
         "timed-out history begins and ends with Timed_Out");
      Assert
        (To_String (Frontend.End_Tool_Ids (2)) = "timeout-id"
         and then To_String (Frontend.End_Tool_Results (2)) =
           "timeout payload",
         "timed-out history retains result ID and payload");
      Assert
        (Frontend.Begin_Tool_Statuses (3) = Coyote_App.Frontend.Cancelled
         and then Frontend.End_Tool_Statuses (3) =
           Coyote_App.Frontend.Cancelled,
         "cancelled history begins and ends with Cancelled");
      Assert
        (Frontend.Begin_Tool_Statuses (4) = Coyote_App.Frontend.Error
         and then Frontend.End_Tool_Statuses (4) =
           Coyote_App.Frontend.Error,
         "error history begins and ends with Error");
      Assert
        (Frontend.Begin_Tool_Statuses (5) = Coyote_App.Frontend.Cancelled
         and then Frontend.End_Tool_Statuses (5) =
           Coyote_App.Frontend.Cancelled,
         "unmatched tool call begins and ends as Cancelled");

      if Ada.Directories.Exists (Root) then
         Ada.Directories.Delete_Tree (Root);
      end if;
      if Home_Was_Set then
         Ada.Environment_Variables.Set ("HOME", Old_Home);
      else
         Ada.Environment_Variables.Clear ("HOME");
      end if;
   exception
      when others =>
         if Ada.Directories.Exists (Root) then
            Ada.Directories.Delete_Tree (Root);
         end if;
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         else
            Ada.Environment_Variables.Clear ("HOME");
         end if;
         raise;
   end Test_Tool_Replay_Status_And_Result;

   procedure Append_Result_Status
     (Home     : String;
      Cwd_Slug : String;
      UUID     : String;
      Tool_Id  : String;
      Result   : String;
      Status   : String)
   is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open
        (File, Ada.Text_IO.Append_File,
         Session_Fixture.Session_File_Path (Home, Cwd_Slug, UUID));
      Ada.Text_IO.Put_Line
        (File, "{""role"":""toolResult"",""toolCallId"":"""
         & Tool_Id & """,""content"":[{""type"":""text"",""text"":"""
         & Result & """}],""isError"":false,""status"":"""
         & Status & """}");
      Ada.Text_IO.Close (File);
   end Append_Result_Status;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("Coyote_App.History ignores legacy format metadata",
            Test_Legacy_Format_Metadata_Ignored'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote_App.History replays terminal tool results",
            Test_Tool_Replay_Status_And_Result'Access));
      return Result;
   end Suite;

end Coyote_App_History_Tests;
