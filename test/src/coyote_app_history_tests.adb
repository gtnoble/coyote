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

package body Coyote_App_History_Tests is

   use AUnit.Assertions;

   type Text_Block_Array is
     array (Positive range 1 .. 8) of Unbounded_String;

   type Recorder is new Coyote_App.Frontend.Instance with record
      Text_Block_Count : Natural := 0;
      Text_Block_Texts : Text_Block_Array := (others => Null_Unbounded_String);
   end record;

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

   function Assistant_JSON (Text : String) return String is
   begin
      return "{""role"":""assistant"",""content"":[{""type"":""text"""
        & ",""text"":"""
        & Text
        & """}],""usage"":{},""stopReason"":""stop"""
        & "}";
   end Assistant_JSON;

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

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("Coyote_App.History ignores legacy format metadata",
            Test_Legacy_Format_Metadata_Ignored'Access));
      return Result;
   end Suite;

end Coyote_App_History_Tests;
