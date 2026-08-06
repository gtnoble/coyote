with AUnit.Assertions;
with Ada.Calendar;
with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with Test_HTTP_Server;
with LLM.Compaction;
with LLM.Agent;
with LLM.Agent.Testing;
with LLM.Events;
with LLM.Session_Store;
with LLM.Types;
with Test_HTTP_Server;

package body LLM_Agent_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;
   use type LLM.Types.Stop_Reason;

   type Recorded_Event_Kind is
     (Other_Event_Kind,
      Model_Select_Kind,
      Agent_Start_Kind,
      Message_Start_Kind,
      Message_Update_Kind,
      Message_End_Kind,
      Tool_Execution_Start_Kind,
      Tool_Execution_End_Kind,
      Agent_End_Kind,
      Session_Stats_Kind,
      Auto_Retry_Start_Kind,
      Auto_Retry_End_Kind,
      Auto_Compaction_Start_Kind,
      Auto_Compaction_End_Kind);

   package Recorded_Event_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Recorded_Event_Kind);

   No_Event_Index : constant Natural := Natural'Last;

   function To_Recorded_Event_Kind
     (E : LLM.Events.Agent_Event'Class) return Recorded_Event_Kind
   is
   begin
      if E in LLM.Events.Model_Select_Event then
         return Model_Select_Kind;
      elsif E in LLM.Events.Agent_Start_Event then
         return Agent_Start_Kind;
      elsif E in LLM.Events.Message_Start_Event then
         return Message_Start_Kind;
      elsif E in LLM.Events.Message_Update_Event then
         return Message_Update_Kind;
      elsif E in LLM.Events.Message_End_Event then
         return Message_End_Kind;
      elsif E in LLM.Events.Tool_Execution_Start_Event then
         return Tool_Execution_Start_Kind;
      elsif E in LLM.Events.Tool_Execution_End_Event then
         return Tool_Execution_End_Kind;
      elsif E in LLM.Events.Agent_End_Event then
         return Agent_End_Kind;
      elsif E in LLM.Events.Session_Stats_Event then
         return Session_Stats_Kind;
      elsif E in LLM.Events.Auto_Retry_Start_Event then
         return Auto_Retry_Start_Kind;
      elsif E in LLM.Events.Auto_Retry_End_Event then
         return Auto_Retry_End_Kind;
      elsif E in LLM.Events.Auto_Compaction_Start_Event then
         return Auto_Compaction_Start_Kind;
      elsif E in LLM.Events.Auto_Compaction_End_Event then
         return Auto_Compaction_End_Kind;
      else
         return Other_Event_Kind;
      end if;
   end To_Recorded_Event_Kind;

   function First_Event_Index
     (Events : Recorded_Event_Vectors.Vector;
      Kind   : Recorded_Event_Kind;
      Start  : Natural := 0) return Natural
   is
   begin
      if Events.Is_Empty then
         return No_Event_Index;
      end if;

      for Index in Events.First_Index .. Events.Last_Index loop
         if Index >= Start
           and then Events.Element (Index) = Kind
         then
            return Index;
         end if;
      end loop;

      return No_Event_Index;
   end First_Event_Index;

   function Current_Unix_S return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of (Year => 1970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Long_Integer (Clock - Epoch);
   end Current_Unix_S;

   function Long_Long_Image (Value : Long_Long_Integer) return String is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Long_Long_Image;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Prepare_Test_Home (Home : String) is
   begin
      if Ada.Directories.Exists (Home) then
         Ada.Directories.Delete_Tree (Home);
      end if;

      Ada.Directories.Create_Path (Home & "/.coyote");
   end Prepare_Test_Home;

   procedure Cleanup_Test_Home (Home : String) is
   begin
      if Ada.Directories.Exists (Home) then
         Ada.Directories.Delete_Tree (Home);
      end if;
   exception
      when others =>
         null;
   end Cleanup_Test_Home;

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Append (Content, Line);
            Append (Content, ASCII.LF);
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Read_File;

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Write_File;

   function Fixture_Data_Array return String is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read
          (Read_File
             (Ada.Directories.Current_Directory
              & "/fixtures/openrouter_models.json"));
   begin
      if not Parsed.Success then
         raise Constraint_Error with
           "Failed to parse OpenRouter fixture";
      end if;

      if Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
        or else not Parsed.Value.Has_Field ("data")
      then
         raise Constraint_Error with
           "OpenRouter fixture is missing the data field";
      end if;

      return GNATCOLL.JSON.Write (Parsed.Value.Get ("data"));
   end Fixture_Data_Array;

   procedure Write_OpenRouter_Cache (Home : String) is
   begin
      Write_File
        (Home & "/.coyote/openrouter_models_cache.json",
         "{""fetched_at"":" & Long_Long_Image (Current_Unix_S)
         & ",""data"":" & Fixture_Data_Array & "}");
   end Write_OpenRouter_Cache;

   procedure Write_Settings_File
     (Home             : String;
      Default_Provider : String := "";
      Default_Model    : String := "";
      Default_Thinking : String := "")
   is
   begin
      Write_File
        (Home & "/.coyote/settings.json",
         "{""defaultProvider"":""" & Default_Provider
         & """,""defaultModel"":""" & Default_Model
         & """,""defaultThinkingLevel"":"""
         & Default_Thinking & """}");
   end Write_Settings_File;

   procedure Write_OpenRouter_Models_File
     (Home    : String;
      Api_Key : String)
   is
   begin
      Write_File
        (Home & "/.coyote/models.json",
         "{""providers"":{""openrouter"":{""apiKey"":"""
         & Api_Key & """}}}");
   end Write_OpenRouter_Models_File;

   procedure Write_Minimal_OpenRouter_Cache
     (Home     : String;
      Model_Id : String)
   is
   begin
      Write_File
        (Home & "/.coyote/openrouter_models_cache.json",
         "{""fetched_at"":9999999999,""data"":[{""id"":"""
         & Model_Id
         & """,""name"":"""
         & Model_Id
         & """,""context_length"":128000,"
         & """architecture"":{""input_modalities"":[""text""],"
         & """output_modalities"":[""text""]},"
         & """pricing"":{""prompt"":""0.000001"","
         & """completion"":""0.000002"","
         & """input_cache_read"":""0.0000005""},"
         & """top_provider"":{""context_length"":128000,"
         & """max_completion_tokens"":4096},"
         & """supported_parameters"":[""max_tokens"",""tools""]}]}"
        );
   end Write_Minimal_OpenRouter_Cache;

   --  Build a two-event SSE payload that streams Text then closes with stop.
   --  The payload matches the OpenAI chat-completions streaming format:
   --    data: <delta-content event>\n\n
   --    data: <finish event with usage>\n\n
   --    data: [DONE]\n\n
   function Text_SSE_Payload
     (Text              : String;
      Prompt_Tokens     : Natural := 8;
      Completion_Tokens : Natural := 3) return String
   is
   begin
      return
        "data: {""choices"":[{""delta"":{""content"":"
        & GNATCOLL.JSON.Write (GNATCOLL.JSON.Create (Text))
        & "},""finish_reason"":null}]}"
        & ASCII.LF & ASCII.LF
        & "data: {""choices"":[{""delta"":{},""finish_reason"":""stop""}],"
        & """usage"":{""prompt_tokens"":"
        & Natural_Image (Prompt_Tokens)
        & ",""completion_tokens"":"
        & Natural_Image (Completion_Tokens)
        & "}}"
        & ASCII.LF & ASCII.LF
        & "data: [DONE]"
        & ASCII.LF & ASCII.LF;
   end Text_SSE_Payload;

   --  Append a Content-Type: text/event-stream header to a response.
   procedure Add_SSE_Header (Res : in out Test_HTTP_Server.Response) is
   begin
      Res.Headers.Append
        ((Name  => To_Unbounded_String ("Content-Type"),
          Value => To_Unbounded_String ("text/event-stream")));
   end Add_SSE_Header;

   type Tool_Call_Definition is record
      Tool_Call_Id   : Unbounded_String;
      Tool_Name      : Unbounded_String;
      Arguments_Json : Unbounded_String;
   end record;

   type Tool_Call_Definition_Array is
     array (Positive range <>) of Tool_Call_Definition;

   function Tool_Call_Def
     (Tool_Call_Id   : String;
      Tool_Name      : String;
      Arguments_Json : String) return Tool_Call_Definition
   is
   begin
      return
        (Tool_Call_Id   => To_Unbounded_String (Tool_Call_Id),
         Tool_Name      => To_Unbounded_String (Tool_Name),
         Arguments_Json => To_Unbounded_String (Arguments_Json));
   end Tool_Call_Def;

   function Tool_Call_SSE_Payload
     (Calls             : Tool_Call_Definition_Array;
      Prompt_Tokens     : Natural := 12;
      Completion_Tokens : Natural := 6) return String
   is
      use GNATCOLL.JSON;

      Start_Event  : constant JSON_Value := Create_Object;
      Start_Choice : constant JSON_Value := Create_Object;
      Start_Delta  : constant JSON_Value := Create_Object;
      Start_Calls  : JSON_Array          := Empty_Array;
      End_Event    : constant JSON_Value := Create_Object;
      End_Choice   : constant JSON_Value := Create_Object;
      End_Delta    : constant JSON_Value := Create_Object;
      End_Usage    : constant JSON_Value := Create_Object;
      Choices      : JSON_Array          := Empty_Array;
   begin
      for I in Calls'Range loop
         declare
            Tool_Call      : constant JSON_Value := Create_Object;
            Function_Value : constant JSON_Value := Create_Object;
         begin
            Tool_Call.Set_Field ("index", Integer (I - Calls'First));
            Tool_Call.Set_Field
              ("id", To_String (Calls (I).Tool_Call_Id));
            Tool_Call.Set_Field ("type", "function");
            Function_Value.Set_Field
              ("name", To_String (Calls (I).Tool_Name));
            Function_Value.Set_Field
              ("arguments", To_String (Calls (I).Arguments_Json));
            Tool_Call.Set_Field ("function", Function_Value);
            Append (Start_Calls, Tool_Call);
         end;
      end loop;

      Start_Delta.Set_Field ("tool_calls", Start_Calls);
      Start_Choice.Set_Field ("delta", Start_Delta);
      Start_Choice.Set_Field ("finish_reason", JSON_Null);
      Append (Choices, Start_Choice);
      Start_Event.Set_Field ("choices", Choices);

      Choices := Empty_Array;
      End_Choice.Set_Field ("delta", End_Delta);
      End_Choice.Set_Field ("finish_reason", "tool_calls");
      Append (Choices, End_Choice);
      End_Event.Set_Field ("choices", Choices);
      End_Usage.Set_Field ("prompt_tokens", Integer (Prompt_Tokens));
      End_Usage.Set_Field
        ("completion_tokens", Integer (Completion_Tokens));
      End_Event.Set_Field ("usage", End_Usage);

      return
        "data: " & Write (Start_Event)
        & ASCII.LF & ASCII.LF
        & "data: " & Write (End_Event)
        & ASCII.LF & ASCII.LF
        & "data: [DONE]"
        & ASCII.LF & ASCII.LF;
   end Tool_Call_SSE_Payload;

   function Assistant_Text (Msg : LLM.Types.Message) return String is
      Result : Unbounded_String;
   begin
      for Block of Msg.Content loop
         if Block.Kind = LLM.Types.Text_Block then
            Append (Result, To_String (Block.Text));
         end if;
      end loop;

      return To_String (Result);
   end Assistant_Text;

   procedure Append_Text_Message
     (Session_Id : String;
      Role       : LLM.Types.Role;
      Text       : String) is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Text)));

      LLM.Session_Store.Append_Message
        (Session_Id,
         (Role      => Role,
          Content   => Content,
          Tok_Usage => (others => 0),
          Stop      =>
            (if Role = LLM.Types.Assistant
             then LLM.Types.Stop
             else LLM.Types.Unknown_Stop),
          Timestamp => Null_Unbounded_String));
   end Append_Text_Message;

   procedure Seed_Compaction_History
     (S : in out LLM.Agent.Session)
   is
      Session_UUID : constant String := LLM.Agent.Session_Id (S);
      Large_User_1 : constant String := (1 .. 50_000 => 'u');
      Large_Asst_1 : constant String := (1 .. 50_000 => 'a');
      Large_User_2 : constant String := (1 .. 50_000 => 'v');
      Large_Asst_2 : constant String := (1 .. 50_000 => 'b');
   begin
      Append_Text_Message (Session_UUID, LLM.Types.User, Large_User_1);
      Append_Text_Message (Session_UUID, LLM.Types.Assistant, Large_Asst_1);
      Append_Text_Message (Session_UUID, LLM.Types.User, Large_User_2);
      Append_Text_Message (Session_UUID, LLM.Types.Assistant, Large_Asst_2);
      LLM.Agent.Switch_Session (S, Session_UUID);
   end Seed_Compaction_History;




   procedure Test_Single_Turn_Prompt (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_1";
      Port           : constant Positive := 18_781;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Hello", 10, 5));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Say hello",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert (Messages.Length = 2, "Expected user + assistant messages");
      Assert
        (Messages.Element (0).Role = LLM.Types.User,
         "First message should be the user prompt");
      Assert
        (Messages.Element (1).Role = LLM.Types.Assistant,
         "Second message should be the assistant reply");
      Assert
        (Assistant_Text (Messages.Element (1)) = "Hello",
         "Assistant text should round-trip through session storage");
      Assert
        (Ada.Directories.Exists
           (LLM.Session_Store.Session_File_Path
              (LLM.Agent.Session_Id (Agent_Session))),
         "Session file should exist on disk after Run_Prompt");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Single_Turn_Prompt;

   procedure Test_Tool_Call_Loop (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_2";
      Port          : constant Positive := 18_782;
      Agent_Session : LLM.Agent.Session;
      Messages      : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      Request_Count : aliased Natural := 0;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         use GNATCOLL.JSON;
         Parsed : constant Read_Result :=
           Read (To_String (Req.Body_Data));
         Req_Body : constant JSON_Value := Parsed.Value;
         All_Msgs : constant JSON_Array := Req_Body.Get ("messages").Get;

         function Is_System (M : JSON_Value) return Boolean is
         begin
            return String'(M.Get ("role").Get) = "system";
         end Is_System;

         Msgs : JSON_Array;
      begin
         for I in 1 .. Length (All_Msgs) loop
            if not Is_System (Get (All_Msgs, I)) then
               Append (Msgs, Get (All_Msgs, I));
            end if;
         end loop;

         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);

         if Request_Count = 1 then
            Assert (Length (Msgs) = 1, "Tool call req 1: expected 1 msg");
            Assert
              (Ada.Strings.Fixed.Index
                 (String'(Get (Msgs, 1).Get ("content").Get),
                  "Use a tool") = 1,
               "Tool call req 1: wrong prompt");
            declare
               Tool_Call_SSE : constant String :=
                 Tool_Call_SSE_Payload
                   ((1 => Tool_Call_Def
                      (Tool_Call_Id   => "call_1",
                       Tool_Name      => "shell",
                       Arguments_Json =>
                         "{""command"":""echo tool-ok""}")),
                    Prompt_Tokens     => 12,
                    Completion_Tokens => 6);
            begin
               Append (Res.Body_Data, Tool_Call_SSE);
            end;
         else
            Assert (Length (Msgs) = 3, "Tool call req 2: expected 3 msgs");
            Assert
              (String'(Get
                 (Get (Msgs, 2).Get ("tool_calls").Get, 1).Get ("id").Get)
               = "call_1",
               "Tool call req 2: wrong tool call id");
            Assert
              (String'(Get (Msgs, 3).Get ("role").Get) = "tool",
               "Tool call req 2: expected tool result");
            Assert
              (Ada.Strings.Fixed.Index
                 (Get (Msgs, 3).Get ("content").Get, "tool-ok") > 0,
               "Tool call req 2: tool output not present");
            Append (Res.Body_Data, Text_SSE_Payload ("Done", 20, 4));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use a tool",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (Messages.Length = 4,
         "Expected user, tool call, tool result, reply");
      Assert
        (Messages.Element (1).Role = LLM.Types.Assistant,
         "Second message should be the assistant tool-call message");
      Assert
        (Messages.Element (1).Content.Element (0).Kind
           = LLM.Types.Tool_Call_Block,
         "Assistant tool-call message should contain a tool call block");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third message should be the tool result");
      Assert
        (Messages.Element (3).Role = LLM.Types.Assistant,
         "Fourth message should be the final assistant reply");
      Assert
        (Assistant_Text (Messages.Element (3)) = "Done",
         "Final assistant text should round-trip through session storage");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Tool_Call_Loop;

   procedure Test_Two_Tool_Call_Loop (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_7";
      Port          : constant Positive := 18_789;
      Agent_Session : LLM.Agent.Session;
      Messages      : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      Two_Tool_SSE : constant String :=
        Tool_Call_SSE_Payload
          ((1 => Tool_Call_Def
             (Tool_Call_Id   => "call_1",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""printf first-ok""}"),
            2 => Tool_Call_Def
             (Tool_Call_Id   => "call_2",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""printf second-ok""}")),
           Prompt_Tokens     => 14,
           Completion_Tokens => 7);

      Request_Count : aliased Natural := 0;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         use GNATCOLL.JSON;
         Parsed   : constant Read_Result :=
           Read (To_String (Req.Body_Data));
         Req_Body : constant JSON_Value := Parsed.Value;
         All_Msgs : constant JSON_Array := Req_Body.Get ("messages").Get;

         function Is_System (M : JSON_Value) return Boolean is
         begin
            return String'(M.Get ("role").Get) = "system";
         end Is_System;

         Msgs : JSON_Array;
      begin
         for I in 1 .. Length (All_Msgs) loop
            if not Is_System (Get (All_Msgs, I)) then
               Append (Msgs, Get (All_Msgs, I));
            end if;
         end loop;

         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);

         if Request_Count = 1 then
            Assert (Length (Msgs) = 1, "Two-tool req 1: expected 1 msg");
            Assert
              (Ada.Strings.Fixed.Index
                 (String'(Get (Msgs, 1).Get ("content").Get),
                  "Use two tools") = 1,
               "Two-tool req 1: wrong prompt");
            Append (Res.Body_Data, Two_Tool_SSE);
         else
            Assert (Length (Msgs) = 4, "Two-tool req 2: expected 4 msgs");
            Assert
              (String'(Get (Msgs, 2).Get ("role").Get) = "assistant",
               "Two-tool req 2: second msg should be assistant");
            Assert
              (GNATCOLL.JSON.Length (Get (Msgs, 2).Get ("tool_calls").Get) = 2,
               "Two-tool req 2: expected 2 tool calls");
            Assert
              (String'(Get (Msgs, 3).Get ("role").Get) = "tool",
               "Two-tool req 2: third msg should be tool");
            Assert
              (String'(Get (Msgs, 3).Get ("tool_call_id").Get) = "call_1",
               "Two-tool req 2: first tool result id wrong");
            Assert
              (Ada.Strings.Fixed.Index
                 (Get (Msgs, 3).Get ("content").Get, "first-ok") > 0,
               "Two-tool req 2: first-ok not in tool result");
            Assert
              (String'(Get (Msgs, 4).Get ("role").Get) = "tool",
               "Two-tool req 2: fourth msg should be tool");
            Assert
              (String'(Get (Msgs, 4).Get ("tool_call_id").Get) = "call_2",
               "Two-tool req 2: second tool result id wrong");
            Assert
              (Ada.Strings.Fixed.Index
                 (Get (Msgs, 4).Get ("content").Get, "second-ok") > 0,
               "Two-tool req 2: second-ok not in tool result");
            Append (Res.Body_Data, Text_SSE_Payload ("All done", 24, 5));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use two tools",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (Messages.Length = 5,
         "Expected user, assistant tool batch, two results, and reply");
      Assert
        (Messages.Element (1).Role = LLM.Types.Assistant,
         "Second message should be the assistant tool-call batch");
      Assert
        (Messages.Element (1).Content.Length = 2,
         "Assistant tool-call batch should contain two tool-call blocks");
      Assert
        (Messages.Element (1).Content.Element (0).Kind
           = LLM.Types.Tool_Call_Block,
         "First assistant block should be a tool call");
      Assert
        (Messages.Element (1).Content.Element (1).Kind
           = LLM.Types.Tool_Call_Block,
         "Second assistant block should be a tool call");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third message should be the first tool result");
      Assert
        (Messages.Element (3).Role = LLM.Types.Tool_Result,
         "Fourth message should be the second tool result");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Messages.Element (2).Content.Element (0).Result_Text),
            "first-ok") > 0,
         "First tool result should contain first-ok");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Messages.Element (3).Content.Element (0).Result_Text),
            "second-ok") > 0,
         "Second tool result should contain second-ok");
      Assert
        (Messages.Element (4).Role = LLM.Types.Assistant,
         "Fifth message should be the final assistant reply");
      Assert
        (Assistant_Text (Messages.Element (4)) = "All done",
         "Final assistant reply should round-trip through session storage");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Two_Tool_Call_Loop;

   procedure Test_Tool_Execution_Failure (T : in out Test) is
      pragma Unreferenced (T);

      Home               : constant String := "/tmp/coyote_llm_agent_test_8";
      Port               : constant Positive := 18_793;
      Agent_Session      : LLM.Agent.Session;
      Messages           : LLM.Types.Message_Vectors.Vector;
      Saw_Tool_End       : Boolean := False;
      Tool_End_Is_Error  : Boolean := False;
      Tool_End_Result    : Unbounded_String := Null_Unbounded_String;
      Server_Stopped     : Boolean := False;
      Home_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home           : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set        : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key            : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set        : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url            : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Tool_Execution_End_Event then
            declare
               Event : constant LLM.Events.Tool_Execution_End_Event :=
                 LLM.Events.Tool_Execution_End_Event (E);
            begin
               Saw_Tool_End := True;
               Tool_End_Is_Error := Event.Is_Error;
               Tool_End_Result := Event.Result_Text;
            end;
         end if;
      end On_Event;

      Missing_Path : constant String :=
        "/tmp/coyote_missing_tool_input_"
        & Natural_Image (Port) & ".txt";

      Request_Count : aliased Natural := 0;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         use GNATCOLL.JSON;
         Parsed   : constant Read_Result :=
           Read (To_String (Req.Body_Data));
         Req_Body : constant JSON_Value := Parsed.Value;
         All_Msgs : constant JSON_Array := Req_Body.Get ("messages").Get;

         function Is_System (M : JSON_Value) return Boolean is
         begin
            return String'(M.Get ("role").Get) = "system";
         end Is_System;

         Msgs : JSON_Array;
      begin
         for I in 1 .. Length (All_Msgs) loop
            if not Is_System (Get (All_Msgs, I)) then
               Append (Msgs, Get (All_Msgs, I));
            end if;
         end loop;

         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);

         if Request_Count = 1 then
            Assert (Length (Msgs) = 1, "Tool-fail req 1: expected 1 msg");
            Assert
              (Ada.Strings.Fixed.Index
                 (String'(Get (Msgs, 1).Get ("content").Get),
                  "Use failing tool") = 1,
               "Tool-fail req 1: wrong prompt");
            declare
               Args : constant JSON_Value := Create_Object;
            begin
               Args.Set_Field ("path", Missing_Path);

               declare
                  Read_SSE : constant String :=
                    Tool_Call_SSE_Payload
                      ((1 => Tool_Call_Def
                          ("call_1", "read", Write (Args))),
                       Prompt_Tokens     => 12,
                       Completion_Tokens => 6);
               begin
                  Append (Res.Body_Data, Read_SSE);
               end;
            end;
         else
            Assert (Length (Msgs) = 3, "Tool-fail req 2: expected 3 msgs");
            Assert
              (String'(Get (Msgs, 3).Get ("role").Get) = "tool",
               "Tool-fail req 2: third msg should be tool result");
            Assert
              (String'(Get (Msgs, 3).Get ("tool_call_id").Get) = "call_1",
               "Tool-fail req 2: wrong tool call id");
            Assert
              (Ada.Strings.Fixed.Index
                 (Get (Msgs, 3).Get ("content").Get, "unknown tool") > 0,
               "Tool-fail req 2: error text not present");
            Append
              (Res.Body_Data,
               Text_SSE_Payload ("Handled failure", 18, 4));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use failing tool",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert (Saw_Tool_End, "Tool_Execution_End_Event should be emitted");
      Assert
        (Tool_End_Is_Error,
         "Tool_Execution_End_Event.Is_Error should be True");
      Assert
        (Ada.Strings.Fixed.Index (To_String (Tool_End_Result),
           "unknown tool") > 0,
         "Tool failure result text should describe the unknown tool");
      Assert
        (Messages.Length = 4,
         "Failed tool turn should persist user, tool call, result, and reply");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third message should be the persisted tool result");
      Assert
        (Messages.Element (2).Content.Element (0).Is_Error,
         "Persisted tool result block should preserve Is_Error=True");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Messages.Element (2).Content.Element (0).Result_Text),
            "unknown tool") > 0,
         "Persisted tool result text should describe the unknown tool");
      Assert
        (Assistant_Text (Messages.Element (3)) = "Handled failure",
         "Final assistant reply should still complete after tool failure");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Tool_Execution_Failure;

   procedure Test_Switch_Session_Loads_History (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_9";
      Agent_Session : LLM.Agent.Session;
      Existing_Id   : Unbounded_String;
      User_Content  : LLM.Types.Content_Block_Vectors.Vector;
      Reply_Content : LLM.Types.Content_Block_Vectors.Vector;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");

      Existing_Id := To_Unbounded_String
        (LLM.Session_Store.Create_Session (Ada.Directories.Current_Directory));

      User_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Earlier question")));
      LLM.Session_Store.Append_Message
        (To_String (Existing_Id),
         (Role      => LLM.Types.User,
          Content   => User_Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));

      Reply_Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Earlier answer")));
      LLM.Session_Store.Append_Message
        (To_String (Existing_Id),
         (Role      => LLM.Types.Assistant,
          Content   => Reply_Content,
          Tok_Usage => (Input => 3, Output => 2, Cache_Read => 0,
                        Cache_Write => 0,
                        Thinking    => 0),
          Stop      => LLM.Types.Stop,
          Timestamp => Null_Unbounded_String));

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      LLM.Agent.Switch_Session (Agent_Session, To_String (Existing_Id));

      Assert
        (LLM.Agent.Session_Id (Agent_Session) = To_String (Existing_Id),
         "Switch_Session should update the active session id");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 2,
         "Switch_Session should pre-load the persisted history");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.User,
         "First pre-loaded message should be the stored user message");
      Assert
        (To_String
           (LLM.Agent.Testing.History_Element
              (Agent_Session, 0).Content.Element (0).Text)
         = "Earlier question",
         "Stored user text should be pre-loaded into S.History");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 1).Role
           = LLM.Types.Assistant,
         "Second pre-loaded message should be the stored assistant reply");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 1))
         = "Earlier answer",
         "Stored assistant text should be pre-loaded into S.History");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Switch_Session_Loads_History;

   procedure Test_Abort_Request (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_3";
      Port          : constant Positive := 18_783;
      Agent_Session : LLM.Agent.Session;
      Messages      : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_End (Was_Aborted : Boolean);
         procedure Note_Error;
         function Saw_Aborted_End return Boolean;
         function Had_Error return Boolean;
      private
         Aborted_End : Boolean := False;
         Task_Error  : Boolean := False;
      end State;

      protected body State is
         procedure Note_End (Was_Aborted : Boolean) is
         begin
            Aborted_End := Was_Aborted;
         end Note_End;

         procedure Note_Error is
         begin
            Task_Error := True;
         end Note_Error;

         function Saw_Aborted_End return Boolean is
         begin
            return Aborted_End;
         end Saw_Aborted_End;

         function Had_Error return Boolean is
         begin
            return Task_Error;
         end Had_Error;
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Agent_End_Event then
            State.Note_End (LLM.Events.Agent_End_Event (E).Was_Aborted);
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         delay 1.0;
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Too late", 1, 1));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Abort this prompt",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         delay 0.10;
         LLM.Agent.Request_Abort (Agent_Session);

         for I in 1 .. 200 loop
            exit when Runner'Terminated;
            delay 0.05;
         end loop;

         Assert (Runner'Terminated,
                 "Abort request must terminate within 10 s");
      end;

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (not State.Had_Error,
         "Run_Prompt task should not raise");
      Assert
        (State.Saw_Aborted_End,
         "Agent_End_Event should report Was_Aborted=True");
      Assert
        (Messages.Length = 0,
         "Abort should not persist any messages");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Abort_Request;

   procedure Test_Abort_Batched_Tools_Keep_History_Valid
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_5";
      Capture_Path   : constant String := Home & "/resume_request.json";
      Abort_Port     : constant Positive := 18_786;
      Resume_Port    : constant Positive := 18_787;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Abort_Stopped  : Boolean := False;
      Resume_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_First_Tool_End;
         procedure Note_End (Was_Aborted : Boolean);
         procedure Note_Error;
         function Saw_First_Tool_End return Boolean;
         function Saw_Aborted_End return Boolean;
         function Had_Error return Boolean;
      private
         First_Tool_Ended : Boolean := False;
         Aborted_End      : Boolean := False;
         Task_Error       : Boolean := False;
      end State;

      protected body State is
         procedure Note_First_Tool_End is
         begin
            First_Tool_Ended := True;
         end Note_First_Tool_End;

         procedure Note_End (Was_Aborted : Boolean) is
         begin
            Aborted_End := Was_Aborted;
         end Note_End;

         procedure Note_Error is
         begin
            Task_Error := True;
         end Note_Error;

         function Saw_First_Tool_End return Boolean is
         begin
            return First_Tool_Ended;
         end Saw_First_Tool_End;

         function Saw_Aborted_End return Boolean is
         begin
            return Aborted_End;
         end Saw_Aborted_End;

         function Had_Error return Boolean is
         begin
            return Task_Error;
         end Had_Error;
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Tool_Execution_End_Event then
            declare
               Tool_End : constant LLM.Events.Tool_Execution_End_Event :=
                 LLM.Events.Tool_Execution_End_Event (E);
            begin
               if To_String (Tool_End.Tool_Call_Id) = "call_1" then
                  State.Note_First_Tool_End;
                  LLM.Agent.Request_Abort (Agent_Session);
               end if;
            end;
         elsif E in LLM.Events.Agent_End_Event then
            State.Note_End (LLM.Events.Agent_End_Event (E).Was_Aborted);
         end if;
      end On_Event;

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      Two_Tool_SSE : constant String :=
        Tool_Call_SSE_Payload
          ((1 => Tool_Call_Def
             (Tool_Call_Id   => "call_1",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""printf first-ok""}"),
            2 => Tool_Call_Def
             (Tool_Call_Id   => "call_2",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""printf second-ok""}")),
           Prompt_Tokens     => 14,
           Completion_Tokens => 7);

      procedure Handle_Abort
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Two_Tool_SSE);
      end Handle_Abort;

      Srv_Abort : Test_HTTP_Server.Server
        (Handle_Abort'Unrestricted_Access);

      procedure Handle_Resume
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Capture_Path);
         Ada.Text_IO.Put (File, To_String (Req.Body_Data));
         Ada.Text_IO.Close (File);

         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Recovered", 16, 3));
      end Handle_Resume;

      Srv_Resume : Test_HTTP_Server.Server
        (Handle_Resume'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Abort_Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv_Abort.Bind (Abort_Port);

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Use two tools",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         for I in 1 .. 100 loop
            exit when State.Saw_First_Tool_End;
            delay 0.05;
         end loop;

         Assert
           (State.Saw_First_Tool_End,
            "First tool should complete before the abort callback fires");

         for I in 1 .. 100 loop
            exit when Runner'Terminated;
            delay 0.05;
         end loop;

         Assert (Runner'Terminated, "Aborted Run_Prompt should terminate");
      end;

      Srv_Abort.Stop;
      Abort_Stopped := True;

      Assert (not State.Had_Error, "Aborted Run_Prompt should not raise");
      Assert
        (State.Saw_Aborted_End,
         "Agent_End_Event should report Was_Aborted=True");

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));
      Assert
        (Messages.Length = 4,
         "Aborted turn should persist tool results for recoverability");

      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Resume_Port) & "/api/v1");
      Srv_Resume.Bind (Resume_Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "After abort",
         On_Event => Ignore_Event'Access);

      Srv_Resume.Stop;
      Resume_Stopped := True;

      declare
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Read_File (Capture_Path));
      begin
         Assert (Parsed.Success, "Captured resume request should parse");

         declare
            function Json_String
              (Value : GNATCOLL.JSON.JSON_Value;
               Field : String) return String
            is
            begin
               return Value.Get (Field).Get;
            end Json_String;

            Request    : constant GNATCOLL.JSON.JSON_Value := Parsed.Value;
            Msgs       : constant GNATCOLL.JSON.JSON_Array :=
              Request.Get ("messages").Get;
            Sys_Offset : constant Natural :=
              (if GNATCOLL.JSON.Length (Msgs) > 0
                 and then Json_String
                   (GNATCOLL.JSON.Get (Msgs, 1), "role") = "system"
               then 1 else 0);
            Calls      : constant GNATCOLL.JSON.JSON_Array :=
              GNATCOLL.JSON.Get
                (Msgs, 2 + Sys_Offset).Get ("tool_calls").Get;
         begin
            Assert
              (GNATCOLL.JSON.Length (Msgs) = 5 + Sys_Offset,
               "Resume request should include the aborted tool batch"
               & " in memory");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 1 + Sys_Offset), "role")
                 = "user",
               "First request message should be the original user prompt");
            Assert
              (Ada.Strings.Fixed.Index
                 (Json_String
                    (GNATCOLL.JSON.Get (Msgs, 1 + Sys_Offset), "content"),
                  "Use two tools") = 1,
               "Original user prompt should remain in history");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 2 + Sys_Offset), "role")
                 = "assistant",
               "Assistant tool-call message should precede tool results");
            Assert
              (GNATCOLL.JSON.Length (Calls) = 2,
               "Assistant history message should include both tool calls");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Calls, 1), "id") = "call_1",
               "First tool call id should be preserved");
            Assert
              (Json_String (GNATCOLL.JSON.Get (Calls, 2), "id") = "call_2",
               "Second tool call id should be preserved");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 3 + Sys_Offset), "role")
                 = "tool",
               "First tool result should follow the assistant tool call");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 3 + Sys_Offset), "tool_call_id")
                 = "call_1",
               "First tool result should match call_1");
            Assert
              (Ada.Strings.Fixed.Index
                 (Json_String
                    (GNATCOLL.JSON.Get (Msgs, 3 + Sys_Offset), "content"),
                  "first-ok") > 0,
               "First tool result should contain the real command output");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 4 + Sys_Offset), "role")
                 = "tool",
               "Second tool result should be present after abort");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get
                    (Msgs, 4 + Sys_Offset), "tool_call_id")
                 = "call_2",
               "Second tool result should match call_2");
            Assert
              (Json_String
                 (GNATCOLL.JSON.Get (Msgs, 5 + Sys_Offset), "role")
                 = "user",
               "Final message should be the after-abort user prompt");
            Assert
              (Ada.Strings.Fixed.Index
                 (Json_String
                    (GNATCOLL.JSON.Get (Msgs, 5 + Sys_Offset), "content"),
                  "After abort") = 1,
               "After-abort user prompt should be preserved in history");
         end;
      end;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));
      Assert
        (Messages.Length = 6,
         "Session file should contain aborted tool results plus completed turn");
      Assert
        (Assistant_Text (Messages.Element (5)) = "Recovered",
         "Second prompt should still complete after the aborted turn");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Abort_Stopped then
            begin
               Srv_Abort.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         if not Resume_Stopped then
            begin
               Srv_Resume.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Abort_Batched_Tools_Keep_History_Valid;

   procedure Test_Abort_During_Shell_With_Timeout
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String :=
        "/tmp/coyote_llm_agent_test_timeout_abort";
      Port           : constant Positive := 18_790;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_End (Was_Aborted : Boolean);
         procedure Note_Error;
         function Saw_Aborted_End return Boolean;
         function Had_Error return Boolean;
      private
         Aborted_End : Boolean := False;
         Task_Error  : Boolean := False;
      end State;

      protected body State is
         procedure Note_End (Was_Aborted : Boolean) is
         begin
            Aborted_End := Was_Aborted;
         end Note_End;

         procedure Note_Error is
         begin
            Task_Error := True;
         end Note_Error;

         function Saw_Aborted_End return Boolean is
         begin
            return Aborted_End;
         end Saw_Aborted_End;

         function Had_Error return Boolean is
         begin
            return Task_Error;
         end Had_Error;
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Agent_End_Event then
            State.Note_End (LLM.Events.Agent_End_Event (E).Was_Aborted);
         end if;
      end On_Event;

      --  SSE payload for a single shell tool call that sleeps 100 s
      --  with a 60 s timeout.  Without the abort fix, the Timer task
      --  would wait the full 60 s before killing the child; with it the
      --  abort flag should win the select-or-delay race immediately.
      Timeout_Tool_SSE : constant String :=
        Tool_Call_SSE_Payload
          ((1 => Tool_Call_Def
             (Tool_Call_Id   => "call_timeout",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""sleep 100"",""timeout"":60}")),
           Prompt_Tokens     => 14,
           Completion_Tokens => 7);

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Timeout_Tool_SSE);
      end Handle_Request;

      Srv : Test_HTTP_Server.Server
        (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Run a command with a timeout",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         --  Let the shell tool start executing (the child process
         --  starts sleep 100).
         delay 0.20;
         LLM.Agent.Request_Abort (Agent_Session);

         --  The abort must terminate quickly: the child should be
         --  killed via the Timer task's select-or-delay, not by the
         --  60 s timeout.  200 * 0.05 = 10 s maximum wait.
         for I in 1 .. 200 loop
            exit when Runner'Terminated;
            delay 0.05;
         end loop;

         Assert (Runner'Terminated,
                 "Aborted timeout tool call must terminate within 10 s");
      end;

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (not State.Had_Error,
         "Run_Prompt task should not raise");
      Assert
        (State.Saw_Aborted_End,
         "Agent_End_Event should report Was_Aborted=True");

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      --  Aborted turn should persist: user, assistant tool call,
      --  and tool result with the abort marker.
      Assert
        (Messages.Length = 3,
         "Aborted timeout turn should persist user, assistant,"
         & " and tool result");
      Assert
        (Messages.Element (1).Role = LLM.Types.Assistant,
         "Second message should be the assistant tool-call");
      Assert
        (Messages.Element (1).Content.Length = 1,
         "Assistant tool-call batch should contain 1 tool-call block");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third message should be the tool result");

      --  The tool result should show it was aborted (not timed out).
      Assert
        (Messages.Element (2).Content.Length = 1,
         "Tool result should have one content block");
      Assert
        (Ada.Strings.Unbounded.Length
           (Messages.Element (2).Content.Element (0).Result_Text) > 0,
         "Tool result should have non-empty text");
      Assert
        (Ada.Strings.Fixed.Index
           (Ada.Strings.Unbounded.To_String
              (Messages.Element (2).Content.Element (0).Result_Text),
            "aborted") > 0,
         "Tool result text should contain ""aborted""");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Abort_During_Shell_With_Timeout;

   procedure Test_Session_File_Written_Only_After_Turn_End
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home          : constant String := "/tmp/coyote_llm_agent_test_6";
      Port          : constant Positive := 18_788;
      Agent_Session : LLM.Agent.Session;
      Mid_Messages  : LLM.Types.Message_Vectors.Vector;
      End_Messages  : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key       : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_Tool_End;
         procedure Note_Error;
         function Saw_Tool_End return Boolean;
         function Had_Error return Boolean;
      private
         Tool_Ended : Boolean := False;
         Task_Error : Boolean := False;
      end State;

      protected body State is
         procedure Note_Tool_End is
         begin
            Tool_Ended := True;
         end Note_Tool_End;

         procedure Note_Error is
         begin
            Task_Error := True;
         end Note_Error;

         function Saw_Tool_End return Boolean is
         begin
            return Tool_Ended;
         end Saw_Tool_End;

         function Had_Error return Boolean is
         begin
            return Task_Error;
         end Had_Error;
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Tool_Execution_End_Event then
            State.Note_Tool_End;
         end if;
      end On_Event;

      Request_Count : aliased Natural := 0;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         use GNATCOLL.JSON;
         Parsed   : constant Read_Result :=
           Read (To_String (Req.Body_Data));
         Req_Body : constant JSON_Value := Parsed.Value;
         All_Msgs : constant JSON_Array := Req_Body.Get ("messages").Get;

         function Is_System (M : JSON_Value) return Boolean is
         begin
            return String'(M.Get ("role").Get) = "system";
         end Is_System;

         Msgs : JSON_Array;
      begin
         for I in 1 .. Length (All_Msgs) loop
            if not Is_System (Get (All_Msgs, I)) then
               Append (Msgs, Get (All_Msgs, I));
            end if;
         end loop;

         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);

         if Request_Count = 1 then
            Assert
              (Ada.Strings.Fixed.Index
                 (String'(Get (Msgs, 1).Get ("content").Get),
                  "Use delayed tool") = 1,
               "Delayed-tool req 1: wrong prompt");
            Assert
              (GNATCOLL.JSON.Length (Req_Body.Get ("tools").Get) > 0,
               "Delayed-tool req 1: tools should be present");
            declare
               Args : constant JSON_Value := Create_Object;
            begin
               Args.Set_Field ("command", "printf slow-ok");

               declare
                  Tool_SSE : constant String :=
                    Tool_Call_SSE_Payload
                      ((1 => Tool_Call_Def
                          ("call_1", "shell", Write (Args))),
                       Prompt_Tokens     => 12,
                       Completion_Tokens => 6);
               begin
                  Append (Res.Body_Data, Tool_SSE);
               end;
            end;
         else
            Assert
              (String'(Get (Msgs, 2).Get ("role").Get) = "assistant",
               "Delayed-tool req 2: second msg should be assistant");
            Assert
              (String'(Get
                 (Get (Msgs, 2).Get ("tool_calls").Get, 1).Get ("id").Get)
               = "call_1",
               "Delayed-tool req 2: wrong tool call id");
            Assert
              (String'(Get (Msgs, 3).Get ("role").Get) = "tool",
               "Delayed-tool req 2: third msg should be tool result");
            Assert
              (Ada.Strings.Fixed.Index
                 (Get (Msgs, 3).Get ("content").Get, "slow-ok") > 0,
               "Delayed-tool req 2: slow-ok not in result");
            delay 1.0;
            Append (Res.Body_Data, Text_SSE_Payload ("Done", 20, 4));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Use delayed tool",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         for I in 1 .. 100 loop
            exit when State.Saw_Tool_End;
            delay 0.05;
         end loop;

         Assert
           (State.Saw_Tool_End,
            "Tool execution should finish before checking mid-turn storage");

         delay 0.20;
         Mid_Messages := LLM.Session_Store.Load_Messages
           (LLM.Agent.Session_Id (Agent_Session));

         Assert
           (Mid_Messages.Length = 3,
            "Session file should contain user, tool call, and tool result"
            & " as soon as the tool batch completes");
         Assert
           (Mid_Messages.Element (0).Role = LLM.Types.User,
            "First mid-turn message should be the user prompt");
         Assert
           (Mid_Messages.Element (1).Role = LLM.Types.Assistant,
            "Second mid-turn message should be the assistant tool-call");
         Assert
           (Mid_Messages.Element (2).Role = LLM.Types.Tool_Result,
            "Third mid-turn message should be the tool result");

         for I in 1 .. 100 loop
            exit when Runner'Terminated;
            delay 0.05;
         end loop;

         Assert
           (Runner'Terminated,
            "Run_Prompt should finish after the delayed final response");
      end;

      Srv.Stop;
      Server_Stopped := True;

      Assert (not State.Had_Error, "Delayed Run_Prompt should not raise");

      End_Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (End_Messages.Length = 4,
         "Completed turn should persist user, tool call, tool result, reply");
      Assert
        (End_Messages.Element (1).Role = LLM.Types.Assistant,
         "Second persisted message should be the assistant tool call");
      Assert
        (End_Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third persisted message should be the tool result");
      Assert
        (Assistant_Text (End_Messages.Element (3)) = "Done",
         "Final assistant reply should persist after the turn ends");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Session_File_Written_Only_After_Turn_End;

   procedure Test_Session_Resume (T : in out Test) is
      pragma Unreferenced (T);

      Home                 : constant String :=
        "/tmp/coyote_llm_agent_test_4";
      First_Port           : constant Positive := 18_784;
      Second_Port          : constant Positive := 18_785;
      First_Session        : LLM.Agent.Session;
      Resume_Session       : LLM.Agent.Session;
      Session_UUID         : Unbounded_String;
      Messages             : LLM.Types.Message_Vectors.Vector;
      First_Server_Stopped  : Boolean := False;
      Second_Server_Stopped : Boolean := False;
      Home_Was_Set         : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home             : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key              : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url              : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_First_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Hello", 10, 5));
      end Handle_First_Request;

      Srv_First : Test_HTTP_Server.Server
        (Handle_First_Request'Unrestricted_Access);

      procedure Handle_Second_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         use GNATCOLL.JSON;
         Parsed   : constant Read_Result :=
           Read (To_String (Req.Body_Data));
         Req_Body : constant JSON_Value := Parsed.Value;
         All_Msgs : constant JSON_Array := Req_Body.Get ("messages").Get;

         function Is_System (M : JSON_Value) return Boolean is
         begin
            return String'(M.Get ("role").Get) = "system";
         end Is_System;

         Msgs : JSON_Array;
      begin
         for I in 1 .. Length (All_Msgs) loop
            if not Is_System (Get (All_Msgs, I)) then
               Append (Msgs, Get (All_Msgs, I));
            end if;
         end loop;

         Assert (Length (Msgs) = 3, "Resume req: expected 3 non-sys msgs");
         Assert
           (String'(Get (Msgs, 1).Get ("role").Get) = "user",
            "Resume req: first msg should be user");
         Assert
           (Ada.Strings.Fixed.Index
              (String'(Get (Msgs, 1).Get ("content").Get),
               "Say hello") = 1,
            "Resume req: wrong original user prompt");
         Assert
           (String'(Get (Msgs, 2).Get ("role").Get) = "assistant",
            "Resume req: second msg should be assistant");
         Assert
           (String'(Get (Msgs, 2).Get ("content").Get) = "Hello",
            "Resume req: wrong original assistant response");
         Assert
           (String'(Get (Msgs, 3).Get ("role").Get) = "user",
            "Resume req: third msg should be user");
         Assert
           (Ada.Strings.Fixed.Index
              (String'(Get (Msgs, 3).Get ("content").Get),
               "Second prompt") = 1,
            "Resume req: wrong second user prompt");

         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Resumed", 9, 3));
      end Handle_Second_Request;

      Srv_Second : Test_HTTP_Server.Server
        (Handle_Second_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (First_Port) & "/api/v1");

      LLM.Agent.Create
        (S          => First_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv_First.Bind (First_Port);
      LLM.Agent.Run_Prompt
        (S        => First_Session,
         Prompt   => "Say hello",
         On_Event => Ignore_Event'Access);
      Srv_First.Stop;
      First_Server_Stopped := True;

      Session_UUID :=
        To_Unbounded_String (LLM.Agent.Session_Id (First_Session));

      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Second_Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Resume_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True,
         Session_Id => To_String (Session_UUID));

      Srv_Second.Bind (Second_Port);

      LLM.Agent.Run_Prompt
        (S        => Resume_Session,
         Prompt   => "Second prompt",
         On_Event => Ignore_Event'Access);
      Srv_Second.Stop;
      Second_Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages (To_String (Session_UUID));

      Assert
        (Messages.Length = 4,
         "Resumed session should contain four messages");
      Assert
        (Assistant_Text (Messages.Element (1)) = "Hello",
         "Resumed session should preserve the original assistant reply");
      Assert
        (Assistant_Text (Messages.Element (3)) = "Resumed",
         "Second Run_Prompt should append the resumed reply");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not First_Server_Stopped then
            begin
               Srv_First.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         if not Second_Server_Stopped then
            begin
               Srv_Second.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Session_Resume;

   procedure Test_Create_Without_Model_Spec_Uses_Settings_Default
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_10";
      Port           : constant Positive := 18_794;
      Agent_Session  : LLM.Agent.Session;
      Saw_Model      : Boolean := False;
      Selected_Prov  : Unbounded_String := Null_Unbounded_String;
      Selected_Model : Unbounded_String := Null_Unbounded_String;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Model_Select_Event then
            declare
               Event : constant LLM.Events.Model_Select_Event :=
                 LLM.Events.Model_Select_Event (E);
            begin
               Saw_Model := True;
               Selected_Prov := Event.Provider;
               Selected_Model := Event.Model_Id;
            end;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("default reply", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("OPENROUTER_API_KEY");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "",
         No_Tools   => True);

      Assert
        (LLM.Agent.Current_Model_Spec (Agent_Session)
           = "openrouter/test/default-model",
         "Create should use the settings.json default model");

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use the default model",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert (Saw_Model, "Model_Select_Event should be emitted");
      Assert
        (To_String (Selected_Prov) = "openrouter",
         "Default provider should resolve to openrouter");
      Assert
        (To_String (Selected_Model) = "test/default-model",
         "Default model id should come from settings.json");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Create_Without_Model_Spec_Uses_Settings_Default;

   procedure Test_Memory_Enabled_By_Env_Var (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_10b";
      Agent_Session  : LLM.Agent.Session;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Mem_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_ENABLE_MEMORY");
      Old_Mem        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_ENABLE_MEMORY", "");
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("COYOTE_ENABLE_MEMORY", "1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "",
         No_Tools   => True);

      Assert
        (Ada.Strings.Fixed.Index
           (LLM.Agent.Testing.System_Prompt (Agent_Session),
            "# Memory System") > 0,
         "COYOTE_ENABLE_MEMORY=1 should inject memory taxonomy");

      Restore_Env ("COYOTE_ENABLE_MEMORY", Mem_Was_Set, Old_Mem);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_ENABLE_MEMORY", Mem_Was_Set, Old_Mem);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Memory_Enabled_By_Env_Var;

   procedure Test_Memory_Disabled_By_Default (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_10c";
      Agent_Session  : LLM.Agent.Session;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Mem_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_ENABLE_MEMORY");
      Old_Mem        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_ENABLE_MEMORY", "");
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("COYOTE_ENABLE_MEMORY");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "",
         No_Tools   => True);

      Assert
        (Ada.Strings.Fixed.Index
           (LLM.Agent.Testing.System_Prompt (Agent_Session),
            "# Memory System") = 0,
         "memory taxonomy should be absent when COYOTE_ENABLE_MEMORY is unset");

      Restore_Env ("COYOTE_ENABLE_MEMORY", Mem_Was_Set, Old_Mem);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_ENABLE_MEMORY", Mem_Was_Set, Old_Mem);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Memory_Disabled_By_Default;

   procedure Test_Multi_Turn_Same_Session_Carries_History
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_11";
      Port           : constant Positive := 18_795;
      Agent_Session  : LLM.Agent.Session;
      Server_Stopped : Boolean := False;
      Request_Count  : Natural := 0;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);
         if Request_Count = 1 then
            Append (Res.Body_Data,
                    Text_SSE_Payload ("turn one reply", 8, 3));
         else
            Append (Res.Body_Data,
                    Text_SSE_Payload ("turn two reply", 8, 3));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "first question",
         On_Event => Ignore_Event'Access);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "second question",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) >= 4,
         "Same session should retain both user and assistant turns");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 1))
         = "turn one reply",
         "First assistant reply should remain in the in-memory history");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 3))
         = "turn two reply",
         "Second assistant reply should be appended to the same session");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Multi_Turn_Same_Session_Carries_History;

   procedure Test_Event_Sequence_Agent_Start_Through_Session_Stats
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home               : constant String :=
        "/tmp/coyote_llm_agent_test_13";
      Port               : constant Positive := 18_798;
      Agent_Session      : LLM.Agent.Session;
      Events             : Recorded_Event_Vectors.Vector;
      Model_Select_Pos   : Natural;
      Agent_Start_Pos    : Natural;
      Message_Update_Pos : Natural;
      Message_End_Pos    : Natural;
      Agent_End_Pos      : Natural;
      Session_Stats_Pos  : Natural;
      Server_Stopped     : Boolean := False;
      Home_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home           : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set        : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key            : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set        : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url            : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         Events.Append (To_Recorded_Event_Kind (E));
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("event reply", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Show the event sequence",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Model_Select_Pos := First_Event_Index (Events, Model_Select_Kind);
      Assert
        (Model_Select_Pos /= No_Event_Index,
         "Model_Select_Event should be present");

      Agent_Start_Pos :=
        First_Event_Index (Events, Agent_Start_Kind, Model_Select_Pos + 1);
      Assert
        (Agent_Start_Pos /= No_Event_Index,
         "Agent_Start_Event should occur after model selection");

      Message_Update_Pos :=
        First_Event_Index (Events, Message_Update_Kind, Agent_Start_Pos + 1);
      Assert
        (Message_Update_Pos /= No_Event_Index,
         "At least one Message_Update_Event should be emitted");

      Message_End_Pos :=
        First_Event_Index (Events, Message_End_Kind, Message_Update_Pos + 1);
      Assert
        (Message_End_Pos /= No_Event_Index,
         "Message_End_Event should follow the message updates");

      Agent_End_Pos :=
        First_Event_Index (Events, Agent_End_Kind, Message_End_Pos + 1);
      Assert
        (Agent_End_Pos /= No_Event_Index,
         "Agent_End_Event should be emitted after Message_End_Event");

      Session_Stats_Pos :=
        First_Event_Index (Events, Session_Stats_Kind, Agent_End_Pos + 1);
      Assert
        (Session_Stats_Pos /= No_Event_Index,
         "Session_Stats_Event should follow Agent_End_Event");

      Assert
        (Agent_Start_Pos < Agent_End_Pos,
         "Agent_Start_Event should precede Agent_End_Event");
      Assert
        (Message_End_Pos < Agent_End_Pos,
         "Message_End_Event should precede Agent_End_Event");
      Assert
        (Agent_End_Pos < Session_Stats_Pos,
         "Session_Stats_Event should follow Agent_End_Event");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Event_Sequence_Agent_Start_Through_Session_Stats;

   procedure Test_Unknown_Tool_Becomes_Error_And_Agent_Continues
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home              : constant String := "/tmp/coyote_llm_agent_test_14";
      Port              : constant Positive := 18_799;
      Agent_Session     : LLM.Agent.Session;
      Saw_Tool_Start    : Boolean := False;
      Saw_Tool_End      : Boolean := False;
      Saw_Agent_End     : Boolean := False;
      Tool_End_Error    : Boolean := False;
      End_Was_Aborted   : Boolean := True;
      Tool_Name         : Unbounded_String := Null_Unbounded_String;
      Session_Text      : Unbounded_String := Null_Unbounded_String;
      Server_Stopped    : Boolean := False;
      Request_Count     : Natural := 0;
      Home_Was_Set      : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home          : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key           : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url           : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Tool_Execution_Start_Event then
            declare
               Event : constant LLM.Events.Tool_Execution_Start_Event :=
                 LLM.Events.Tool_Execution_Start_Event (E);
            begin
               Saw_Tool_Start := True;
               Tool_Name := Event.Tool_Name;
            end;
         elsif E in LLM.Events.Tool_Execution_End_Event then
            declare
               Event : constant LLM.Events.Tool_Execution_End_Event :=
                 LLM.Events.Tool_Execution_End_Event (E);
            begin
               Saw_Tool_End := True;
               Tool_End_Error := Event.Is_Error;
            end;
         elsif E in LLM.Events.Agent_End_Event then
            Saw_Agent_End := True;
            End_Was_Aborted := LLM.Events.Agent_End_Event (E).Was_Aborted;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
         Tool_SSE : constant String :=
           "data: {""choices"":[{""delta"":{""tool_calls"":[{""index"":0,"
           & """id"":""call_1"",""type"":""function"","
           & """function"":{""name"":""nonexistent_tool_xyz"","
           & """arguments"":""{}""}}"
           & "]},"
           & """finish_reason"":null}]}"
           & ASCII.LF & ASCII.LF
           & "data: {""choices"":[{""delta"":{},"
           & """finish_reason"":""tool_calls""}],"
           & """usage"":{""prompt_tokens"":11,""completion_tokens"":5}}"
           & ASCII.LF & ASCII.LF
           & "data: [DONE]"
           & ASCII.LF & ASCII.LF;
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);
         if Request_Count = 1 then
            Append (Res.Body_Data, Tool_SSE);
         else
            Append (Res.Body_Data, Text_SSE_Payload ("done", 15, 3));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Call the unknown tool",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Session_Text := To_Unbounded_String
        (Read_File
           (LLM.Session_Store.Session_File_Path
              (LLM.Agent.Session_Id (Agent_Session))));

      Assert
        (Saw_Tool_Start,
         "Tool_Execution_Start_Event should be emitted for the unknown tool");
      Assert
        (To_String (Tool_Name) = "nonexistent_tool_xyz",
         "Tool start event should preserve the requested tool name");
      Assert
        (Saw_Tool_End,
         "Tool_Execution_End_Event should be emitted for the unknown tool");
      Assert
        (Tool_End_Error,
         "Unknown tools should become tool errors rather than hard failures");
      Assert
        (Saw_Agent_End and then not End_Was_Aborted,
         "Agent should continue after an unknown tool and end normally");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Session_Text), """role"":""toolResult""") > 0,
         "Session file should contain a persisted tool-result record");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Session_Text), """isError"":true") > 0,
         "Persisted tool-result record should preserve Is_Error=True");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Unknown_Tool_Becomes_Error_And_Agent_Continues;

   procedure Test_Auto_Retry_On_HTTP_500_Then_Success
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home            : constant String := "/tmp/coyote_llm_agent_test_15";
      Port            : constant Positive := 18_800;
      Agent_Session   : LLM.Agent.Session;
      Saw_Retry       : Boolean := False;
      Saw_Text_Delta  : Boolean := False;
      End_Was_Aborted : Boolean := True;
      Text_Result     : Unbounded_String := Null_Unbounded_String;
      Server_Stopped  : Boolean := False;
      Request_Count   : Natural := 0;
      Home_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home        : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set     : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key         : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set     : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url         : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Retry_Start_Event then
            Saw_Retry := True;
         elsif E in LLM.Events.Message_Update_Event then
            declare
               Event : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (E);
            begin
               if Event.Kind = LLM.Events.Text_Delta then
                  Saw_Text_Delta := True;
                  Append (Text_Result, To_String (Event.Delta_Text));
               end if;
            end;
         elsif E in LLM.Events.Agent_End_Event then
            End_Was_Aborted := LLM.Events.Agent_End_Event (E).Was_Aborted;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         if Request_Count = 1 then
            Res.Status := 500;
            Res.Headers.Append
              ((Name  => To_Unbounded_String ("Content-Type"),
                Value => To_Unbounded_String ("application/json")));
            Append (Res.Body_Data, "{""error"":""server error""}");
         else
            Res.Status := 200;
            Add_SSE_Header (Res);
            Append (Res.Body_Data,
                    Text_SSE_Payload ("retried reply", 8, 3));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      --  The current implementation uses a fixed two-second first retry.
      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Retry this prompt",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert (Saw_Retry, "HTTP 500 should trigger Auto_Retry_Start_Event");
      Assert
        (not End_Was_Aborted,
         "Successful retry should still end the turn normally");
      Assert
        (Saw_Text_Delta and then To_String (Text_Result) = "retried reply",
         "Retry success should still stream the final assistant text");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Auto_Retry_On_HTTP_500_Then_Success;

   procedure Test_Is_Context_Overflow_Error_Detects_Known_Phrases
     (T : in out Test)
   is
      pragma Unreferenced (T);

      type Phrase_Array is array (Positive range <>) of Unbounded_String;

      Home         : constant String := "/tmp/coyote_llm_agent_test_24";
      Summary_Text : constant String :=
        "## Goal" & ASCII.LF & "overflow detection";
      Reply_Text   : constant String := "overflow detection reply";
      Exact_Phrases : constant Phrase_Array :=
        (To_Unbounded_String ("prompt is too long"),
         To_Unbounded_String ("context_length_exceeded"),
         To_Unbounded_String ("maximum context length"),
         To_Unbounded_String ("too many tokens"),
         To_Unbounded_String ("reduce the length of the messages"));
      Mixed_Phrases : constant Phrase_Array :=
        (To_Unbounded_String ("Prompt Is Too Long"),
         To_Unbounded_String ("Context_Length_Exceeded"),
         To_Unbounded_String ("Maximum Context Length"),
         To_Unbounded_String ("Too Many Tokens"),
         To_Unbounded_String ("Reduce The Length Of The Messages"));
      Next_Port    : Positive := 18_810;
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key      : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url      : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Run_Case
        (Port            : Positive;
         Error_Text      : String;
         Expect_Overflow : Boolean)
      is
         Agent_Session        : LLM.Agent.Session;
         Saw_Compaction_Start : Boolean := False;
         Text_Result          : Unbounded_String := Null_Unbounded_String;
         Raised               : Boolean := False;
         Server_Stopped       : Boolean := False;
         Request_Count        : Natural := 0;

         procedure On_Event (E : LLM.Events.Agent_Event'Class) is
         begin
            if E in LLM.Events.Auto_Compaction_Start_Event then
               Saw_Compaction_Start := True;
            elsif E in LLM.Events.Message_Update_Event then
               declare
                  Event : constant LLM.Events.Message_Update_Event :=
                    LLM.Events.Message_Update_Event (E);
               begin
                  if Event.Kind = LLM.Events.Text_Delta then
                     Append (Text_Result, To_String (Event.Delta_Text));
                  end if;
               end;
            end if;
         end On_Event;

         procedure Handle_Request
           (Req :     Test_HTTP_Server.Request;
            Res : out Test_HTTP_Server.Response)
         is
            pragma Unreferenced (Req);
         begin
            Request_Count := Request_Count + 1;
            if Expect_Overflow then
               case Request_Count is
                  when 1 =>
                     Res.Status := 400;
                     Append (Res.Body_Data, Error_Text);
                  when 2 =>
                     Res.Status := 200;
                     Add_SSE_Header (Res);
                     Append (Res.Body_Data,
                             Text_SSE_Payload (Summary_Text, 8, 3));
                  when others =>
                     Res.Status := 200;
                     Add_SSE_Header (Res);
                     Append (Res.Body_Data,
                             Text_SSE_Payload (Reply_Text, 8, 3));
               end case;
            else
               Res.Status := 400;
               Append (Res.Body_Data, Error_Text);
            end if;
         end Handle_Request;

         Srv : Test_HTTP_Server.Server
           (Handle_Request'Unrestricted_Access);
      begin
         Ada.Environment_Variables.Set
           ("COYOTE_OPENROUTER_BASE_URL",
            "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

         LLM.Agent.Create
           (S          => Agent_Session,
            Model_Spec => "openrouter/openai/gpt-4o-mini",
            No_Tools   => True);
         Seed_Compaction_History (Agent_Session);

         Srv.Bind (Port);

         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Detect overflow text",
               On_Event => On_Event'Access);
         exception
            when others =>
               Raised := True;
         end;

         Srv.Stop;
         Server_Stopped := True;

         if Expect_Overflow then
            Assert (not Raised, "Overflow case should recover and return");
            Assert
              (Saw_Compaction_Start,
               "Known overflow phrase should trigger compaction");
            Assert
              (To_String (Text_Result) = Reply_Text,
               "Recovered overflow case should still return the reply");
         else
            Assert (Raised, "Non-overflow error should still raise");
            Assert
              (not Saw_Compaction_Start,
               "Non-overflow error should not trigger compaction");
         end if;
      exception
         when others =>
            if not Server_Stopped then
               begin
                  Srv.Stop;
               exception
                  when Tasking_Error => null;
               end;
            end if;
            raise;
      end Run_Case;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");

      for Phrase of Exact_Phrases loop
         Run_Case
           (Port            => Next_Port,
            Error_Text      => To_String (Phrase),
            Expect_Overflow => True);
         Next_Port := Next_Port + 1;
      end loop;

      for Phrase of Mixed_Phrases loop
         Run_Case
           (Port            => Next_Port,
            Error_Text      => To_String (Phrase),
            Expect_Overflow => True);
         Next_Port := Next_Port + 1;
      end loop;

      Run_Case
        (Port            => Next_Port,
         Error_Text      => "validation failed",
         Expect_Overflow => False);

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Is_Context_Overflow_Error_Detects_Known_Phrases;

   procedure Test_Overflow_Triggers_Compact_And_Retry
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                  : constant String :=
        "/tmp/coyote_llm_agent_test_25";
      Port                  : constant Positive := 18_821;
      Agent_Session         : LLM.Agent.Session;
      Saw_Compaction_Start  : Boolean := False;
      Compaction_Reason     : Unbounded_String := Null_Unbounded_String;
      Final_Text            : Unbounded_String := Null_Unbounded_String;
      Final_Stop            : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      End_Was_Aborted       : Boolean := True;
      Summary_Text          : constant String :=
        "## Goal" & ASCII.LF & "overflow retry";
      Reply_Text            : constant String := "overflow recovered";
      Server_Stopped        : Boolean := False;
      Request_Count         : Natural := 0;
      Home_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home              : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key               : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url               : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_Start_Event then
            Saw_Compaction_Start := True;
            Compaction_Reason :=
              LLM.Events.Auto_Compaction_Start_Event (E).Reason;
         elsif E in LLM.Events.Message_Update_Event then
            declare
               Event : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (E);
            begin
               if Event.Kind = LLM.Events.Text_Delta then
                  Append (Final_Text, To_String (Event.Delta_Text));
               end if;
            end;
         elsif E in LLM.Events.Message_End_Event then
            Final_Stop := LLM.Events.Message_End_Event (E).Stop;
         elsif E in LLM.Events.Agent_End_Event then
            End_Was_Aborted := LLM.Events.Agent_End_Event (E).Was_Aborted;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         case Request_Count is
            when 1 =>
               Res.Status := 400;
               Append (Res.Body_Data, "prompt is too long");
            when 2 =>
               Res.Status := 200;
               Add_SSE_Header (Res);
               Append (Res.Body_Data,
                       Text_SSE_Payload (Summary_Text, 8, 3));
            when others =>
               Res.Status := 200;
               Add_SSE_Header (Res);
               Append (Res.Body_Data,
                       Text_SSE_Payload (Reply_Text, 8, 3));
         end case;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Recover from overflow",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Saw_Compaction_Start,
         "Overflow should emit Auto_Compaction_Start_Event");
      Assert
        (To_String (Compaction_Reason) = "overflow",
         "Overflow compaction should record the overflow reason");
      Assert
        (not End_Was_Aborted,
         "Recovered overflow turn should end normally");
      Assert
        (Final_Stop = LLM.Types.Stop,
         "Recovered overflow turn should finish with Stop");
      Assert
        (To_String (Final_Text) = Reply_Text,
         "Recovered overflow turn should stream the retried reply");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "Overflow recovery should compact the in-memory history");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Overflow_Triggers_Compact_And_Retry;

   procedure Test_Overflow_Recovery_Not_Attempted_Twice
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                 : constant String :=
        "/tmp/coyote_llm_agent_test_26";
      Port                 : constant Positive := 18_822;
      Agent_Session        : LLM.Agent.Session;
      Saw_Aborted_End      : Boolean := False;
      Aborted_Error_Text   : Unbounded_String := Null_Unbounded_String;
      Saw_Agent_End        : Boolean := False;
      Summary_Text         : constant String :=
        "## Goal" & ASCII.LF & "overflow retry failure";
      Server_Stopped       : Boolean := False;
      Request_Count        : Natural := 0;
      Home_Was_Set         : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home             : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key              : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url              : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_End_Event then
            declare
               Event : constant LLM.Events.Auto_Compaction_End_Event :=
                 LLM.Events.Auto_Compaction_End_Event (E);
            begin
               if Event.Aborted then
                  Saw_Aborted_End := True;
                  Aborted_Error_Text := Event.Err_Msg;
               end if;
            end;
         elsif E in LLM.Events.Agent_End_Event then
            Saw_Agent_End := True;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         if Request_Count = 2 then
            Res.Status := 200;
            Add_SSE_Header (Res);
            Append (Res.Body_Data,
                    Text_SSE_Payload (Summary_Text, 8, 3));
         else
            Res.Status := 400;
            Append (Res.Body_Data, "prompt is too long");
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Overflow twice",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Saw_Aborted_End,
         "Second overflow should emit an aborted compaction end event");
      Assert
        (Ada.Strings.Fixed.Index
           (To_String (Aborted_Error_Text),
            "Context overflow recovery failed after one attempt.") > 0,
         "Second overflow should report the one-attempt failure message");
      Assert
        (Saw_Agent_End,
         "Run_Prompt should still emit Agent_End and return");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Overflow_Recovery_Not_Attempted_Twice;

   procedure Test_Overflow_Will_Retry_Event_Emitted
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home              : constant String :=
        "/tmp/coyote_llm_agent_test_27";
      Port              : constant Positive := 18_823;
      Agent_Session     : LLM.Agent.Session;
      Event_Count       : Natural := 0;
      Will_Retry_Pos    : Natural := No_Event_Index;
      Final_Text_Pos    : Natural := No_Event_Index;
      Summary_Text      : constant String :=
        "## Goal" & ASCII.LF & "overflow retry event";
      Server_Stopped    : Boolean := False;
      Request_Count     : Natural := 0;
      Home_Was_Set      : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home          : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key           : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url           : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         Event_Count := Event_Count + 1;

         if E in LLM.Events.Auto_Compaction_End_Event then
            declare
               Event : constant LLM.Events.Auto_Compaction_End_Event :=
                 LLM.Events.Auto_Compaction_End_Event (E);
            begin
               if Event.Will_Retry and then Will_Retry_Pos = No_Event_Index
               then
                  Will_Retry_Pos := Event_Count;
               end if;
            end;
         elsif E in LLM.Events.Message_Update_Event then
            declare
               Event : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (E);
            begin
               if Event.Kind = LLM.Events.Text_Delta
                 and then Final_Text_Pos = No_Event_Index
               then
                  Final_Text_Pos := Event_Count;
               end if;
            end;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         case Request_Count is
            when 1 =>
               Res.Status := 400;
               Append (Res.Body_Data, "prompt is too long");
            when 2 =>
               Res.Status := 200;
               Add_SSE_Header (Res);
               Append (Res.Body_Data,
                       Text_SSE_Payload (Summary_Text, 8, 3));
            when others =>
               Res.Status := 200;
               Add_SSE_Header (Res);
               Append (Res.Body_Data,
                       Text_SSE_Payload ("retry reply", 8, 3));
         end case;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Emit retry event",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Will_Retry_Pos /= No_Event_Index,
         "Overflow recovery should emit an Auto_Compaction_End"
         & " will-retry event");
      Assert
        (Final_Text_Pos /= No_Event_Index,
         "Successful retry should eventually emit streamed text");
      Assert
        (Will_Retry_Pos < Final_Text_Pos,
         "Will_Retry event should be emitted before the retried text"
         & " arrives");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Overflow_Will_Retry_Event_Emitted;

   procedure Test_Compact_Produces_Summary_Message
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_16";
      Port           : constant Positive := 18_801;
      Agent_Session  : LLM.Agent.Session;
      Summary_Text   : constant String :=
        "## Goal" & ASCII.LF
        & "Verify compact creates a summary." & ASCII.LF & ASCII.LF
        & "## Constraints & Preferences" & ASCII.LF
        & "- (none)";
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload (Summary_Text, 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
      Compact_OK : Boolean;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => Ignore_Event'Access,
         Succeeded => Compact_OK);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 3,
         "Compact should replace old history with summary plus kept tail");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "First history message should be the synthetic summary");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 0))
         = Summary_Text,
         "Summary text should be stored in the first history message");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Produces_Summary_Message;

   procedure Test_Compact_Emits_Start_And_End_Events
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_17";
      Port           : constant Positive := 18_802;
      Agent_Session  : LLM.Agent.Session;
      Events         : Recorded_Event_Vectors.Vector;
      End_Aborted    : Boolean := True;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         Events.Append (To_Recorded_Event_Kind (E));
         if E in LLM.Events.Auto_Compaction_End_Event then
            End_Aborted := LLM.Events.Auto_Compaction_End_Event (E).Aborted;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data,
                 Text_SSE_Payload
                   ("## Goal" & ASCII.LF & "event test", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
      Compact_OK : Boolean;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => On_Event'Access,
         Succeeded => Compact_OK);

      Srv.Stop;
      Server_Stopped := True;

      declare
         Start_Pos : constant Natural :=
           First_Event_Index (Events, Auto_Compaction_Start_Kind);
         End_Pos   : constant Natural :=
           First_Event_Index (Events, Auto_Compaction_End_Kind);
      begin
         Assert
           (Start_Pos /= No_Event_Index,
            "Compact should emit Auto_Compaction_Start_Event");
         Assert
           (End_Pos /= No_Event_Index,
            "Compact should emit Auto_Compaction_End_Event");
         Assert
           (Start_Pos < End_Pos,
            "Auto_Compaction_Start_Event should precede end event");
         Assert (not End_Aborted, "Successful compaction should not abort");
      end;

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Emits_Start_And_End_Events;

   procedure Test_Compact_Short_History_Aborts
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home              : constant String := "/tmp/coyote_llm_agent_test_18";
      Agent_Session     : LLM.Agent.Session;
      Saw_End           : Boolean := False;
      End_Aborted       : Boolean := False;
      Original_Length   : Ada.Containers.Count_Type;
      Original_Text     : Unbounded_String := Null_Unbounded_String;
      Home_Was_Set      : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home          : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set       : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key           : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_End_Event then
            Saw_End := True;
            End_Aborted := LLM.Events.Auto_Compaction_End_Event (E).Aborted;
         end if;
      end On_Event;
      Compact_OK : Boolean;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Append_Text_Message
        (LLM.Agent.Session_Id (Agent_Session),
         LLM.Types.User,
         "Only one message");
      LLM.Agent.Switch_Session
        (Agent_Session, LLM.Agent.Session_Id (Agent_Session));

      Original_Length := LLM.Agent.Testing.History_Length (Agent_Session);
      Original_Text := To_Unbounded_String
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 0)));

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => On_Event'Access,
         Succeeded => Compact_OK);

      Assert (Saw_End, "Short-history compaction should emit an end event");
      Assert (End_Aborted, "Short histories should abort compaction");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = Original_Length,
         "Short-history abort should leave history unchanged");
      Assert
        (Assistant_Text (LLM.Agent.Testing.History_Element (Agent_Session, 0))
           = To_String (Original_Text),
         "Short-history abort should preserve the original message text");

      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Short_History_Aborts;

   procedure Test_Compact_Persists_Entry
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_19";
      Port           : constant Positive := 18_803;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data,
                 Text_SSE_Payload
                   ("## Goal" & ASCII.LF & "persist", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
      Compact_OK : Boolean;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);

      Srv.Bind (Port);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => Ignore_Event'Access,
         Succeeded => Compact_OK);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));
      Assert
        (not Messages.Is_Empty,
         "Compacted session should reload from disk with synthetic history");
      Assert
        (Messages.First_Element.Role = LLM.Types.Compaction_Summary,
         "Reloaded session should begin with Compaction_Summary");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Persists_Entry;

   procedure Test_Auto_Compact_Fires_At_Threshold
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                  : constant String :=
        "/tmp/coyote_llm_agent_test_21";
      Port                  : constant Positive := 18_805;
      Agent_Session         : LLM.Agent.Session;
      Saw_Compaction_Start  : Boolean := False;
      Compaction_Reason     : Unbounded_String := Null_Unbounded_String;
      Summary_Text          : constant String :=
        "## Goal" & ASCII.LF & "threshold compaction";
      Server_Stopped        : Boolean := False;
      Home_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home              : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key               : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url               : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_Start_Event then
            Saw_Compaction_Start := True;
            Compaction_Reason :=
              LLM.Events.Auto_Compaction_Start_Event (E).Reason;
         end if;
      end On_Event;

      Request_Count : aliased Natural := 0;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);
         if Request_Count = 1 then
            Append (Res.Body_Data,
                    Text_SSE_Payload ("threshold reply", 120_000, 616));
         else
            Append (Res.Body_Data, Text_SSE_Payload (Summary_Text, 8, 3));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Trigger threshold compaction",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Saw_Compaction_Start,
         "Threshold usage should emit Auto_Compaction_Start_Event");
      Assert
        (To_String (Compaction_Reason) = "threshold",
         "Auto-compaction reason should be threshold");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) >= 1,
         "Auto-compaction should leave a non-empty in-memory history");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "Auto-compaction should prepend a Compaction_Summary message");
      Assert
        (Assistant_Text
           (LLM.Agent.Testing.History_Element (Agent_Session, 0))
         = Summary_Text,
         "Threshold compaction should store the returned summary text");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Auto_Compact_Fires_At_Threshold;

   procedure Test_Auto_Compact_Does_Not_Fire_Below_Threshold
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                  : constant String :=
        "/tmp/coyote_llm_agent_test_22";
      Capture_Path          : constant String :=
        Home & "/threshold_request.json";
      Port                  : constant Positive := 18_806;
      Agent_Session         : LLM.Agent.Session;
      Saw_Compaction_Start  : Boolean := False;
      Server_Stopped        : Boolean := False;
      Home_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home              : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key               : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url               : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_Start_Event then
            Saw_Compaction_Start := True;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Capture_Path);
         Ada.Text_IO.Put (File, To_String (Req.Body_Data));
         Ada.Text_IO.Close (File);
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("small reply", 16, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Stay below the threshold",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (not Saw_Compaction_Start,
         "Below-threshold usage should not emit auto-compaction events");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 2,
         "Below-threshold prompt should leave just user and assistant turns");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.User,
         "Below-threshold history should remain un-compacted");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Auto_Compact_Does_Not_Fire_Below_Threshold;

   procedure Test_Auto_Compact_Session_Persisted_After_Threshold
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_23";
      Port           : constant Positive := 18_807;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Summary_Text   : constant String :=
        "## Goal" & ASCII.LF & "persisted threshold";
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end On_Event;

      Request_Count : aliased Natural := 0;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);
         if Request_Count = 1 then
            Append (Res.Body_Data,
                    Text_SSE_Payload ("persisted reply", 120_000, 616));
         else
            Append (Res.Body_Data, Text_SSE_Payload (Summary_Text, 8, 3));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Persist threshold compaction",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));
      Assert
        (not Messages.Is_Empty,
         "Threshold compaction should leave a reloadable session history");
      Assert
        (Messages.First_Element.Role = LLM.Types.Compaction_Summary,
         "Reloaded threshold-compacted session should start with summary");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Auto_Compact_Session_Persisted_After_Threshold;

   procedure Test_Set_Compact_Settings_Disabled
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home                  : constant String :=
        "/tmp/coyote_llm_agent_test_24";
      Port                  : constant Positive := 18_808;
      Agent_Session         : LLM.Agent.Session;
      Saw_Compaction_Start  : Boolean := False;
      Server_Stopped        : Boolean := False;
      Home_Was_Set          : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home              : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key               : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set           : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url               : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Auto_Compaction_Start_Event then
            Saw_Compaction_Start := True;
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data,
                 Text_SSE_Payload ("disabled compact reply", 120_000, 616));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      LLM.Agent.Set_Compact_Settings
        (Agent_Session,
         (Enabled              => False,
          Reserve_Tokens       =>
            LLM.Compaction.Default_Compact_Settings.Reserve_Tokens,
          Keep_Recent_Tokens   =>
            LLM.Compaction.Default_Compact_Settings.Keep_Recent_Tokens,
          Consecutive_Failures => 0,
          Tripped              => False));

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Trigger threshold but compaction is disabled",
         On_Event => On_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Assert
        (not Saw_Compaction_Start,
         "Compaction should not fire when disabled via Set_Compact_Settings");
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) = 2,
         "History should contain only user and assistant turns");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           /= LLM.Types.Compaction_Summary,
         "Disabled compaction should not prepend a Compaction_Summary message");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Set_Compact_Settings_Disabled;

      procedure Test_Compact_Then_Resume
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_llm_agent_test_20";
      Port           : constant Positive := 18_804;
      Agent_Session  : LLM.Agent.Session;
      Session_UUID   : Unbounded_String := Null_Unbounded_String;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data,
                 Text_SSE_Payload
                   ("## Goal" & ASCII.LF & "resume", 8, 3));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
      Compact_OK : Boolean;
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);
      Seed_Compaction_History (Agent_Session);
      Session_UUID :=
        To_Unbounded_String (LLM.Agent.Session_Id (Agent_Session));

      Srv.Bind (Port);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => Ignore_Event'Access,
         Succeeded => Compact_OK);

      Srv.Stop;
      Server_Stopped := True;

      LLM.Agent.Switch_Session (Agent_Session, To_String (Session_UUID));
      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) >= 1,
         "Switch_Session should reload compacted history");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "Reloaded in-memory history should start with Compaction_Summary");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Compact_Then_Resume;

   procedure Test_Compact_Live_Summarises_Conversation
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Guard_Name : constant String := "COYOTE_TEST_LIVE";
      Auth_Path  : constant String :=
        Ada.Environment_Variables.Value ("HOME", "") & "/.coyote/auth.json";
      Agent_Session : LLM.Agent.Session;

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;
      Compact_OK : Boolean;
   begin
      if Ada.Environment_Variables.Value (Guard_Name, "") /= "1" then
         return;
      end if;

      if not Ada.Directories.Exists (Auth_Path) then
         Ada.Text_IO.Put_Line
           ("[SKIP] GitHub Copilot live compaction test requires "
            & Auth_Path);
         return;
      end if;

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "github-copilot/claude-sonnet-4.6",
         No_Tools   => True);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   =>
           "We are testing live context compaction. Please note that the"
           & " goal is to verify the summary format.",
         On_Event => Ignore_Event'Access);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   =>
           "Constraint: keep the summary concise and preserve exact phrases"
           & " when possible.",
         On_Event => Ignore_Event'Access);

      LLM.Agent.Compact
        (S        => Agent_Session,
         On_Event => Ignore_Event'Access,
         Succeeded => Compact_OK);

      Assert
        (LLM.Agent.Testing.History_Length (Agent_Session) >= 1,
         "Live compaction should leave a non-empty history");
      Assert
        (LLM.Agent.Testing.History_Element (Agent_Session, 0).Role
           = LLM.Types.Compaction_Summary,
         "Live compaction should prepend a Compaction_Summary message");
      declare
         Summary : constant String :=
           Assistant_Text
             (LLM.Agent.Testing.History_Element (Agent_Session, 0));
      begin
         Assert
           (Summary'Length > 0,
            "Live compaction summary text should not be empty");
         Assert
           (Ada.Strings.Fixed.Index (Summary, "## Goal") > 0,
            "Live compaction summary should contain the required heading");
      end;
   end Test_Compact_Live_Summarises_Conversation;

   --  ── Test_Tool_Result_Has_Stats_Footer ────────────────────────────────
   --
   --  After a single tool call the persisted tool result text should end
   --  with a [coyote: turn=...in/...out session=...in/...out...] footer.

   procedure Test_Tool_Result_Has_Stats_Footer (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String :=
        "/tmp/coyote_llm_agent_footer_1";
      Port           : constant Positive := 18_860;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      Request_Count : aliased Natural := 0;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);

         if Request_Count = 1 then
            Append
              (Res.Body_Data,
               Tool_Call_SSE_Payload
                 ((1 => Tool_Call_Def
                    (Tool_Call_Id   => "call_footer_1",
                     Tool_Name      => "shell",
                     Arguments_Json => "{""command"":""echo footer-ok""}")),
                  Prompt_Tokens     => 50,
                  Completion_Tokens => 20));
         else
            Append (Res.Body_Data, Text_SSE_Payload ("Done", 10, 5));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Minimal_OpenRouter_Cache (Home, "openai/gpt-4o-mini");
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use a tool",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      --  Messages: user, assistant tool call, tool result, assistant reply.
      Assert
        (Messages.Length = 4,
         "Footer test: expected 4 messages");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Footer test: third message should be the tool result");

      declare
         Result_Text : constant String :=
           To_String
             (Messages.Element (2).Content.Element (0).Result_Text);
      begin
         Assert
           (Ada.Strings.Fixed.Index (Result_Text, "footer-ok") > 0,
            "Footer test: tool output should be present in result text");
         Assert
           (Ada.Strings.Fixed.Index (Result_Text, "[coyote: turn=") > 0,
            "Footer test: stats footer should be present in result text");
         Assert
           (Ada.Strings.Fixed.Index (Result_Text, "in/") > 0,
            "Footer test: in/ token separator should be in footer");
         Assert
           (Ada.Strings.Fixed.Index (Result_Text, "out") > 0,
            "Footer test: out token label should be in footer");
         Assert
           (Ada.Strings.Fixed.Index (Result_Text, "session=") > 0,
            "Footer test: session= field should be in footer");
         Assert
           (Ada.Strings.Fixed.Index (Result_Text, "50in/20out") > 0
            or else Ada.Strings.Fixed.Index (Result_Text, "turn=50in") > 0,
            "Footer test: turn token counts should reflect SSE payload");
      end;

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Tool_Result_Has_Stats_Footer;

   --  ── Test_Stats_Footer_Only_On_Last_Tool_In_Batch ─────────────────────
   --
   --  In a two-tool batch only the last tool result should carry the stats
   --  footer; the first should contain only its raw tool output.

   procedure Test_Stats_Footer_Only_On_Last_Tool_In_Batch
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home           : constant String :=
        "/tmp/coyote_llm_agent_footer_2";
      Port           : constant Positive := 18_861;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      Request_Count : aliased Natural := 0;

      Two_Tool_SSE : constant String :=
        Tool_Call_SSE_Payload
          ((1 => Tool_Call_Def
             (Tool_Call_Id   => "call_f1",
              Tool_Name      => "shell",
              Arguments_Json => "{""command"":""printf first-ok""}"),
            2 => Tool_Call_Def
             (Tool_Call_Id   => "call_f2",
              Tool_Name      => "shell",
              Arguments_Json => "{""command"":""printf second-ok""}")),
           Prompt_Tokens     => 30,
           Completion_Tokens => 10);

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);

         if Request_Count = 1 then
            Append (Res.Body_Data, Two_Tool_SSE);
         else
            Append (Res.Body_Data, Text_SSE_Payload ("All done", 12, 4));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Minimal_OpenRouter_Cache (Home, "openai/gpt-4o-mini");
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use two tools",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      --  Messages: user, assistant tool batch, first result,
      --  second result, assistant reply.
      Assert
        (Messages.Length = 5,
         "Two-tool footer test: expected 5 messages");

      declare
         First_Result  : constant String :=
           To_String
             (Messages.Element (2).Content.Element (0).Result_Text);
         Second_Result : constant String :=
           To_String
             (Messages.Element (3).Content.Element (0).Result_Text);
      begin
         Assert
           (Ada.Strings.Fixed.Index (First_Result, "first-ok") > 0,
            "Two-tool footer: first tool output should be present");
         Assert
           (Ada.Strings.Fixed.Index (First_Result, "[coyote:") = 0,
            "Two-tool footer: first tool result should NOT have the footer");
         Assert
           (Ada.Strings.Fixed.Index (Second_Result, "second-ok") > 0,
            "Two-tool footer: second tool output should be present");
         Assert
           (Ada.Strings.Fixed.Index (Second_Result, "[coyote: turn=") > 0,
            "Two-tool footer: second (last) result should have the footer");
      end;

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Stats_Footer_Only_On_Last_Tool_In_Batch;


   --  ── Test_Image_Tool_Result_No_Footer ──────────────────────────────
   --
   --  Image tool results are base64 blobs and must NOT have the stats
   --  footer appended; the footer would corrupt the base64 and break image
   --  decoding.

   procedure Test_Image_Tool_Result_No_Footer (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String :=
        "/tmp/coyote_llm_agent_footer_3";
      Port           : constant Positive := 18_862;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      Request_Count : aliased Natural := 0;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Request_Count := Request_Count + 1;
         Res.Status := 200;
         Add_SSE_Header (Res);

         if Request_Count = 1 then
            Append
              (Res.Body_Data,
               Tool_Call_SSE_Payload
                 ((1 => Tool_Call_Def
                    (Tool_Call_Id   => "call_footer_3",
                     Tool_Name      => "shell",
                     Arguments_Json =>
                       "{""command"":""printf test"",""media_type"":""image/png""}")),
                  Prompt_Tokens     => 50,
                  Completion_Tokens => 20));
         else
            Append (Res.Body_Data, Text_SSE_Payload ("Done", 10, 5));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Minimal_OpenRouter_Cache (Home, "openai/gpt-4o-mini");
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => False);

      Srv.Bind (Port);

      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Use a tool",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      --  Messages: user, assistant tool call, tool result, assistant reply.
      Assert
        (Messages.Length = 4,
         "Footer test: expected 4 messages");
      Assert
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Footer test: third message should be the tool result");

      declare
         Block : LLM.Types.Content_Block :=
           Messages.Element (2).Content.Element (0);
      begin
         Assert
           (Ada.Strings.Unbounded.Length (Block.Media_Type) > 0,
            "Image tool result should have non-empty Media_Type");
         Assert
           (Ada.Strings.Fixed.Index (Ada.Strings.Unbounded.To_String
            (Block.Result_Text), "[coyote: turn=") = 0,
            "Stats footer must not be appended to base64 image data");
      end;

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Image_Tool_Result_No_Footer;

   --  ── Pause_Flag agent integration tests ───────────────────────────────

   procedure Test_Pause_Fires_At_Turn_Boundary (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String  := "/tmp/coyote_llm_agent_pause_1";
      Port           : constant Positive := 18_870;
      Agent_Session  : LLM.Agent.Session;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_Paused;
         procedure Note_Resumed;
         procedure Note_End (Was_Aborted : Boolean);
         procedure Note_Error;
         function Saw_Paused  return Boolean;
         function Saw_Resumed return Boolean;
         function Saw_End     return Boolean;
         function Was_Aborted return Boolean;
         function Had_Error   return Boolean;
      private
         P_Paused    : Boolean := False;
         P_Resumed   : Boolean := False;
         P_End       : Boolean := False;
         P_Aborted   : Boolean := False;
         P_Error     : Boolean := False;
      end State;

      protected body State is
         procedure Note_Paused  is begin P_Paused  := True; end Note_Paused;
         procedure Note_Resumed is begin P_Resumed := True; end Note_Resumed;
         procedure Note_End (Was_Aborted : Boolean) is
         begin
            P_End     := True;
            P_Aborted := Was_Aborted;
         end Note_End;
         procedure Note_Error   is begin P_Error   := True; end Note_Error;
         function Saw_Paused  return Boolean is (P_Paused);
         function Saw_Resumed return Boolean is (P_Resumed);
         function Saw_End     return Boolean is (P_End);
         function Was_Aborted return Boolean is (P_Aborted);
         function Had_Error   return Boolean is (P_Error);
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Agent_Paused_Event then
            State.Note_Paused;
         elsif E in LLM.Events.Agent_Resumed_Event then
            State.Note_Resumed;
         elsif E in LLM.Events.Agent_End_Event then
            State.Note_End (LLM.Events.Agent_End_Event (E).Was_Aborted);
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Resumed and done", 10, 5));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      --  Arm the pause before the loop starts: it will fire at the first
      --  iteration boundary, before any LLM call is made.
      LLM.Agent.Request_Pause (Agent_Session);

      Srv.Bind (Port);

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Pause then continue",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         --  Wait up to 5 s for the loop to pause.
         for I in 1 .. 100 loop
            exit when State.Saw_Paused;
            delay 0.05;
         end loop;

         Assert (State.Saw_Paused,
                 "Agent_Paused_Event should be received within 5 s");
         Assert (not State.Saw_Resumed,
                 "Agent_Resumed_Event should not fire before Resume");

         LLM.Agent.Resume (Agent_Session);

         --  Wait for the runner to finish.
         for I in 1 .. 200 loop
            exit when Runner'Terminated;
            delay 0.05;
         end loop;

         Assert (Runner'Terminated,
                 "Runner must finish after Resume within 10 s");
      end;

      Srv.Stop;
      Server_Stopped := True;

      Assert (not State.Had_Error, "Run_Prompt task should not raise");
      Assert (State.Saw_Resumed,
              "Agent_Resumed_Event should be received after Resume");
      Assert (State.Saw_End,
              "Agent_End_Event should be received");
      Assert (not State.Was_Aborted,
              "Run should complete normally (not aborted)");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Pause_Fires_At_Turn_Boundary;

   procedure Test_Stop_While_Paused (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String  := "/tmp/coyote_llm_agent_pause_2";
      Port           : constant Positive := 18_871;
      Agent_Session  : LLM.Agent.Session;
      Server_Stopped : Boolean := False;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Key_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY");
      Old_Key        : constant String :=
        Ada.Environment_Variables.Value ("OPENROUTER_API_KEY", "");
      Url_Was_Set    : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL");
      Old_Url        : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL", "");

      protected State is
         procedure Note_Paused;
         procedure Note_End (Was_Aborted : Boolean);
         procedure Note_Error;
         function Saw_Paused  return Boolean;
         function Saw_End     return Boolean;
         function Was_Aborted return Boolean;
         function Had_Error   return Boolean;
      private
         P_Paused  : Boolean := False;
         P_End     : Boolean := False;
         P_Aborted : Boolean := False;
         P_Error   : Boolean := False;
      end State;

      protected body State is
         procedure Note_Paused is begin P_Paused := True; end Note_Paused;
         procedure Note_End (Was_Aborted : Boolean) is
         begin
            P_End     := True;
            P_Aborted := Was_Aborted;
         end Note_End;
         procedure Note_Error   is begin P_Error := True; end Note_Error;
         function Saw_Paused  return Boolean is (P_Paused);
         function Saw_End     return Boolean is (P_End);
         function Was_Aborted return Boolean is (P_Aborted);
         function Had_Error   return Boolean is (P_Error);
      end State;

      procedure On_Event (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Agent_Paused_Event then
            State.Note_Paused;
         elsif E in LLM.Events.Agent_End_Event then
            State.Note_End (LLM.Events.Agent_End_Event (E).Was_Aborted);
         end if;
      end On_Event;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         --  Should never be reached: the loop aborts before calling the
         --  provider.  Return a valid response anyway for robustness.
         Res.Status := 200;
         Add_SSE_Header (Res);
         Append (Res.Body_Data, Text_SSE_Payload ("Unexpected", 1, 1));
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_OpenRouter_Cache (Home);
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set ("OPENROUTER_API_KEY", "test-key");
      Ada.Environment_Variables.Set
        ("COYOTE_OPENROUTER_BASE_URL",
         "http://127.0.0.1:" & Natural_Image (Port) & "/api/v1");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/openai/gpt-4o-mini",
         No_Tools   => True);

      LLM.Agent.Request_Pause (Agent_Session);

      Srv.Bind (Port);

      declare
         task Runner;

         task body Runner is
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Stop while paused",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
         end Runner;
      begin
         --  Wait for the pause to fire.
         for I in 1 .. 100 loop
            exit when State.Saw_Paused;
            delay 0.05;
         end loop;

         Assert (State.Saw_Paused,
                 "Agent_Paused_Event should be received within 5 s");

         --  Abort while paused: should unblock the loop and exit.
         LLM.Agent.Request_Abort (Agent_Session);

         for I in 1 .. 200 loop
            exit when Runner'Terminated;
            delay 0.05;
         end loop;

         Assert (Runner'Terminated,
                 "Runner must terminate after Abort while paused within 10 s");
      end;

      Srv.Stop;
      Server_Stopped := True;

      Assert (not State.Had_Error, "Run_Prompt task should not raise");
      Assert (State.Saw_End, "Agent_End_Event should be received");
      Assert (State.Was_Aborted,
              "Agent_End_Event should report Was_Aborted=True");

      Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
      Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         if not Server_Stopped then
            begin
               Srv.Stop;
            exception
               when Tasking_Error => null;
            end;
         end if;
         Restore_Env ("COYOTE_OPENROUTER_BASE_URL", Url_Was_Set, Old_Url);
         Restore_Env ("OPENROUTER_API_KEY", Key_Was_Set, Old_Key);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Stop_While_Paused;

   --  ── Sandbox ──────────────────────────────────────────────────────────

   procedure Test_Sandbox_Set_And_Get (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String :=
        "/tmp/coyote_llm_agent_sandbox_1";
      Agent_Session : LLM.Agent.Session;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Sbx_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists
          ("COYOTE_SANDBOX_PROFILE");
      Old_Sbx       : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_SANDBOX_PROFILE", "");
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("COYOTE_SANDBOX_PROFILE");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "",
         No_Tools   => True);

      --  Initially empty.
      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "",
         "sandbox should be empty initially");

      --  Set a profile and verify round-trip.
      LLM.Agent.Set_Sandbox_Profile
        (Agent_Session, "restricted");
      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "restricted",
         "sandbox should return ""restricted"" after set, got: "
         & LLM.Agent.Current_Sandbox (Agent_Session));

      --  Change to a different profile.
      LLM.Agent.Set_Sandbox_Profile
        (Agent_Session, "full-access");
      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "full-access",
         "sandbox should return ""full-access"" after second set, got: "
         & LLM.Agent.Current_Sandbox (Agent_Session));

      --  Clear the profile.
      LLM.Agent.Set_Sandbox_Profile
        (Agent_Session, "");
      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "",
         "sandbox should return """" after clearing, got: "
         & LLM.Agent.Current_Sandbox (Agent_Session));

      Restore_Env
        ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env
           ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Sandbox_Set_And_Get;

   procedure Test_Sandbox_Env_Var_Inherited (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String :=
        "/tmp/coyote_llm_agent_sandbox_2";
      Agent_Session : LLM.Agent.Session;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Sbx_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists
          ("COYOTE_SANDBOX_PROFILE");
      Old_Sbx       : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_SANDBOX_PROFILE", "");
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_SANDBOX_PROFILE", "child-profile");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "",
         No_Tools   => True);

      --  The COYOTE_SANDBOX_PROFILE env var should be inherited.
      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session)
         = "child-profile",
         "sandbox should inherit from COYOTE_SANDBOX_PROFILE, got: "
         & LLM.Agent.Current_Sandbox (Agent_Session));

      Restore_Env
        ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env
           ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Sandbox_Env_Var_Inherited;

   procedure Test_Sandbox_Default_From_Settings (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String :=
        "/tmp/coyote_llm_agent_sandbox_3b";
      Agent_Session : LLM.Agent.Session;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Sbx_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_SANDBOX_PROFILE");
      Old_Sbx       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_SANDBOX_PROFILE", "");
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_File
        (Home & "/.coyote/settings.json",
         "{""defaultProvider"":""openrouter""," &
         """defaultModel"":""test/default-model""," &
         """defaultThinkingLevel"":""""," &
         """defaultSandboxProfile"":""settings-profile""}");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("COYOTE_SANDBOX_PROFILE");
      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/test/default-model",
         No_Tools   => True);
      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "settings-profile",
         "sandbox should use defaultSandboxProfile from settings.json");

      Restore_Env ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Sandbox_Default_From_Settings;

   procedure Test_Sandbox_Default_Empty (T : in out Test) is
      pragma Unreferenced (T);

      Home          : constant String :=
        "/tmp/coyote_llm_agent_sandbox_3";
      Agent_Session : LLM.Agent.Session;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Sbx_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists
          ("COYOTE_SANDBOX_PROFILE");
      Old_Sbx       : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_SANDBOX_PROFILE", "");
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Clear ("COYOTE_SANDBOX_PROFILE");

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "",
         No_Tools   => True);

      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "",
         "sandbox should be empty when COYOTE_SANDBOX_PROFILE"
         & " is absent, got: "
         & LLM.Agent.Current_Sandbox (Agent_Session));

      Restore_Env
        ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env
           ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Sandbox_Default_Empty;

   procedure Test_Sandbox_Profile_Restored_On_Resume
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home          : constant String :=
        "/tmp/coyote_llm_agent_sandbox_resume";
      Agent_Session : LLM.Agent.Session;
      Session_Id    : Unbounded_String;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Sbx_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_SANDBOX_PROFILE");
      Old_Sbx       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_SANDBOX_PROFILE", "");
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_SANDBOX_PROFILE", "restricted");
      Session_Id := To_Unbounded_String
        (LLM.Session_Store.Create_Session
           (Ada.Directories.Current_Directory));

      Ada.Environment_Variables.Clear ("COYOTE_SANDBOX_PROFILE");
      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/test/default-model",
         No_Tools   => True,
         Session_Id => To_String (Session_Id));

      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "restricted",
         "resuming a session should restore its persisted sandbox profile");

      Restore_Env ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Sandbox_Profile_Restored_On_Resume;

   procedure Test_Sandbox_Profile_Restored_And_Cleared_On_Switch
     (T : in out Test)
   is
      pragma Unreferenced (T);

      Home          : constant String :=
        "/tmp/coyote_llm_agent_sandbox_switch";
      Agent_Session : LLM.Agent.Session;
      Profiled_Id   : Unbounded_String;
      Unprofiled_Id : Unbounded_String;
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Sbx_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_SANDBOX_PROFILE");
      Old_Sbx       : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_SANDBOX_PROFILE", "");
   begin
      Prepare_Test_Home (Home);
      Write_Settings_File
        (Home             => Home,
         Default_Provider => "openrouter",
         Default_Model    => "test/default-model");
      Write_OpenRouter_Models_File (Home, "settings-key");
      Write_Minimal_OpenRouter_Cache
        (Home     => Home,
         Model_Id => "test/default-model");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_SANDBOX_PROFILE", "restricted");
      Profiled_Id := To_Unbounded_String
        (LLM.Session_Store.Create_Session
           (Ada.Directories.Current_Directory));

      Ada.Environment_Variables.Clear ("COYOTE_SANDBOX_PROFILE");
      Unprofiled_Id := To_Unbounded_String
        (LLM.Session_Store.Create_Session
           (Ada.Directories.Current_Directory));

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => "openrouter/test/default-model",
         No_Tools   => True);
      LLM.Agent.Set_Sandbox_Profile (Agent_Session, "stale-profile");

      LLM.Agent.Switch_Session
        (S    => Agent_Session,
         UUID => To_String (Profiled_Id));
      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "restricted",
         "switching should restore the target session sandbox profile");

      LLM.Agent.Switch_Session
        (S    => Agent_Session,
         UUID => To_String (Unprofiled_Id));
      Assert
        (LLM.Agent.Current_Sandbox (Agent_Session) = "",
         "switching to an unprofiled session should clear the old profile");

      Restore_Env ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("COYOTE_SANDBOX_PROFILE", Sbx_Was_Set, Old_Sbx);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Sandbox_Profile_Restored_And_Cleared_On_Switch;

end LLM_Agent_Tests;
