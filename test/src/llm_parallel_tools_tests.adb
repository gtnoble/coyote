with AUnit.Assertions;
with Ada.Calendar;
with Ada.Containers;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;
with Test_HTTP_Server;
with LLM.Agent;
with LLM.Events;
with LLM.Session_Store;
with LLM.Types;

package body LLM_Parallel_Tools_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type LLM.Types.Role;

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

   procedure Test_Parallel_Tools_Run_Concurrently (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_parallel_test_1";
      Port           : constant Positive := 18_801;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Before         : Ada.Calendar.Time;
      After          : Ada.Calendar.Time;
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
                "{""command"":""sleep 0.4"",""run_group"":1}"),
            2 => Tool_Call_Def
             (Tool_Call_Id   => "call_2",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""sleep 0.4"",""run_group"":1}")));

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
            Assert (Length (Msgs) = 1, "Parallel req 1: expected 1 msg");
            Assert
              (String'(Get (Msgs, 1).Get ("content").Get)
                 = "Run two sleeps in parallel",
               "Parallel req 1: wrong prompt");
            Append (Res.Body_Data, Two_Tool_SSE);
         else
            Assert (Length (Msgs) = 4, "Parallel req 2: expected 4 msgs");
            Assert
              (String'(Get (Msgs, 2).Get ("role").Get) = "assistant",
               "Parallel req 2: second msg should be assistant");
            Assert
              (GNATCOLL.JSON.Length (Get (Msgs, 2).Get ("tool_calls").Get)
                 = 2,
               "Parallel req 2: expected 2 tool calls");
            Assert
              (String'(Get (Msgs, 3).Get ("role").Get) = "tool",
               "Parallel req 2: third msg should be tool");
            Assert
              (String'(Get (Msgs, 3).Get ("tool_call_id").Get) = "call_1",
               "Parallel req 2: first tool result id wrong");
            Assert
              (String'(Get (Msgs, 4).Get ("role").Get) = "tool",
               "Parallel req 2: fourth msg should be tool");
            Assert
              (String'(Get (Msgs, 4).Get ("tool_call_id").Get) = "call_2",
               "Parallel req 2: second tool result id wrong");
            Append (Res.Body_Data, Text_SSE_Payload ("Parallel done", 20, 5));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Minimal_OpenRouter_Cache (Home, "openai/gpt-4o-mini");
      Write_Settings_File (Home);
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

      Before := Ada.Calendar.Clock;
      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Run two sleeps in parallel",
         On_Event => Ignore_Event'Access);
      After := Ada.Calendar.Clock;

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (Ada.Calendar."-" (After, Before) < 0.75,
         "Two 0.4 s tools should run concurrently (expected < 0.75 s)");
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
        (Messages.Element (2).Role = LLM.Types.Tool_Result,
         "Third message should be the first tool result");
      Assert
        (Messages.Element (3).Role = LLM.Types.Tool_Result,
         "Fourth message should be the second tool result");
      Assert
        (To_String (Messages.Element (2).Content.Element (0).Result_Id)
           = "call_1",
         "First tool result should keep call_1");
      Assert
        (To_String (Messages.Element (3).Content.Element (0).Result_Id)
           = "call_2",
         "Second tool result should keep call_2");
      Assert
        (Messages.Element (4).Role = LLM.Types.Assistant,
         "Fifth message should be the final assistant reply");

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
   end Test_Parallel_Tools_Run_Concurrently;

   procedure Test_Parallel_Abort_During_Batch (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_parallel_test_2";
      Port           : constant Positive := 18_802;
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

      Two_Tool_SSE : constant String :=
        Tool_Call_SSE_Payload
          ((1 => Tool_Call_Def
             (Tool_Call_Id   => "call_1",
              Tool_Name      => "shell",
              Arguments_Json => "{""command"":""sleep 2""}"),
            2 => Tool_Call_Def
             (Tool_Call_Id   => "call_2",
              Tool_Name      => "shell",
              Arguments_Json => "{""command"":""echo done""}")));

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
            Assert (Length (Msgs) = 1, "Parallel abort req 1: expected 1 msg");
            Append (Res.Body_Data, Two_Tool_SSE);
         else
            Append
              (Res.Body_Data,
               Text_SSE_Payload ("Unexpected continuation", 2, 1));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Minimal_OpenRouter_Cache (Home, "openai/gpt-4o-mini");
      Write_Settings_File (Home);
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
         task Aborter;

         task body Aborter is
         begin
            delay 0.15;
            LLM.Agent.Request_Abort (Agent_Session);
         exception
            when others =>
               State.Note_Error;
         end Aborter;
      begin
         begin
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => "Abort parallel tool batch",
               On_Event => On_Event'Access);
         exception
            when others =>
               State.Note_Error;
               raise;
         end;
      end;

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (not State.Had_Error,
         "Parallel abort test should not raise in helper tasks");
      Assert
        (State.Saw_Aborted_End,
         "Agent_End_Event should report Was_Aborted=True");
      Assert
        (Messages.Length = 4,
         "Aborted turn should persist user, assistant, and tool results");

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
   end Test_Parallel_Abort_During_Batch;

   procedure Test_Tools_Run_Sequentially_By_Default (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_parallel_test_3";
      Port           : constant Positive := 18_803;
      Agent_Session  : LLM.Agent.Session;
      Messages       : LLM.Types.Message_Vectors.Vector;
      Before         : Ada.Calendar.Time;
      After          : Ada.Calendar.Time;
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

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      --  Two tools without run_group — must execute sequentially (default).
      Two_Tool_SSE : constant String :=
        Tool_Call_SSE_Payload
          ((1 => Tool_Call_Def
             (Tool_Call_Id   => "call_s1",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""sleep 0.3""}"),
            2 => Tool_Call_Def
             (Tool_Call_Id   => "call_s2",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""sleep 0.3""}")));

      Request_Count : aliased Natural := 0;
      Saw_Req_2     : aliased Boolean := False;

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
            Append (Res.Body_Data, Two_Tool_SSE);
         else
            Saw_Req_2 := True;
            Append
              (Res.Body_Data,
               Text_SSE_Payload ("Sequential done", 18, 5));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Minimal_OpenRouter_Cache (Home, "openai/gpt-4o-mini");
      Write_Settings_File (Home);
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

      Before := Ada.Calendar.Clock;
      LLM.Agent.Run_Prompt
        (S        => Agent_Session,
         Prompt   => "Run two sleeps sequentially",
         On_Event => Ignore_Event'Access);
      After := Ada.Calendar.Clock;

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      --  Two 0.3 s sleeps sequentially should take > 0.5 s total.
      --  If they ran in parallel it would be ~0.31 s.
      Assert
        (Ada.Calendar."-" (After, Before) > 0.5,
         "Two 0.3 s tools without run_group should run sequentially"
         & " (expected > 0.5 s)");
      Assert
        (Messages.Length = 5,
         "Expected user, assistant tool batch, two results, and reply");
      Assert
        (Saw_Req_2,
         "Final assistant turn should be requested after sequential tools");

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
   end Test_Tools_Run_Sequentially_By_Default;

   procedure Test_Tools_Run_In_Group_Order (T : in out Test) is
      pragma Unreferenced (T);

      Home           : constant String := "/tmp/coyote_parallel_test_4";
      Port           : constant Positive := 18_804;
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

      procedure Ignore_Event (E : LLM.Events.Agent_Event'Class) is
         pragma Unreferenced (E);
      begin
         null;
      end Ignore_Event;

      --  Three tools: first two in group 1, third in group 2.
      --  Group 1 must execute first (in parallel), then group 2.
      Three_Tool_SSE : constant String :=
        Tool_Call_SSE_Payload
          ((1 => Tool_Call_Def
             (Tool_Call_Id   => "call_g1a",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""printf group1-a"",""run_group"":1}"),
            2 => Tool_Call_Def
             (Tool_Call_Id   => "call_g1b",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""printf group1-b"",""run_group"":1}"),
            3 => Tool_Call_Def
             (Tool_Call_Id   => "call_g2",
              Tool_Name      => "shell",
              Arguments_Json =>
                "{""command"":""printf group2"",""run_group"":2}")));

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
            Append (Res.Body_Data, Three_Tool_SSE);
         else
            --  Second request: verify all three results are present
            --  and in the correct call order.
            Assert
              (Length (Msgs) = 5,
               "Group-order req 2: expected 5 msgs (assistant + 3 results)");
            Append
              (Res.Body_Data,
               Text_SSE_Payload ("Group order done", 22, 5));
         end if;
      end Handle_Request;

      Srv : Test_HTTP_Server.Server (Handle_Request'Unrestricted_Access);
   begin
      Prepare_Test_Home (Home);
      Write_Minimal_OpenRouter_Cache (Home, "openai/gpt-4o-mini");
      Write_Settings_File (Home);
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
         Prompt   => "Run two groups of tools",
         On_Event => Ignore_Event'Access);

      Srv.Stop;
      Server_Stopped := True;

      Messages := LLM.Session_Store.Load_Messages
        (LLM.Agent.Session_Id (Agent_Session));

      Assert
        (Messages.Length = 6,
         "Expected user, assistant tool batch, 3 results, and reply");
      Assert
        (Messages.Element (1).Role = LLM.Types.Assistant,
         "Second message should be the assistant tool-call batch");
      Assert
        (Messages.Element (1).Content.Length = 3,
         "Assistant tool-call batch should contain 3 tool-call blocks");

      --  All three tool results must appear, in call order.
      for I in 2 .. 4 loop
         Assert
           (Messages.Element (I).Role = LLM.Types.Tool_Result,
            "Message " & Natural_Image (I)
            & " should be a tool result");
         Assert
           (Messages.Element (I).Content.Length = 1,
            "Tool result " & Natural_Image (I - 1)
            & " should have one content block");
         Assert
           (Ada.Strings.Unbounded.Length
              (Messages.Element (I).Content.Element (0).Result_Text) > 0,
            "Tool result " & Natural_Image (I - 1)
            & " should have non-empty result text");
      end loop;

      Assert
        (Messages.Element (5).Role = LLM.Types.Assistant,
         "Sixth message should be the final assistant reply");

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
   end Test_Tools_Run_In_Group_Order;

end LLM_Parallel_Tools_Tests;
