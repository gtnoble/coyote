with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions;
with Acme.Window;
with LLM.Events;
with LLM.Types;
with Nine_P.Client;
with Coyote_App;          use Coyote_App;
with Coyote_App.Dispatch; use Coyote_App.Dispatch;

package body Dispatch_Tests is

   use AUnit.Assertions;

   PID : constant String := "12345";

   UC_Box_V : constant String :=
     Character'Val (16#E2#)
     & Character'Val (16#94#)
     & Character'Val (16#82#);

   UC_Check : constant String :=
     Character'Val (16#E2#)
     & Character'Val (16#9C#)
     & Character'Val (16#93#);

   UC_Cross : constant String :=
     Character'Val (16#E2#)
     & Character'Val (16#9C#)
     & Character'Val (16#97#);

   UC_Dbl_H : constant String :=
     Character'Val (16#E2#)
     & Character'Val (16#95#)
     & Character'Val (16#90#);

   procedure Assert_Contains
     (Haystack : String;
      Needle   : String;
      Message  : String)
   is
   begin
      Assert
        (Ada.Strings.Fixed.Index (Haystack, Needle) > 0,
         Message);
   end Assert_Contains;

   procedure Assert_Not_Contains
     (Haystack : String;
      Needle   : String;
      Message  : String)
   is
   begin
      Assert
        (Ada.Strings.Fixed.Index (Haystack, Needle) = 0,
         Message);
   end Assert_Not_Contains;

   procedure Test_Dispatch_Agent_Start (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Agent_Start_Event'
              (LLM.Events.Agent_Event with null record),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (S.Is_Streaming,
                    "agent_start should set Is_Streaming");
            Assert_Contains
              (Body_Text, "running",
               "agent_start should replace line 1 with running status");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Agent_Start;

   procedure Test_Dispatch_Agent_End_Normal (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         S.Set_Streaming (True);
         S.Set_Text_Emitted (True);
         S.Set_Last_Stop_Reason ("toolUse");
         Acme.Window.Append
           (Win, FS'Access, Format_Status (S, "running") & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Agent_End_Event'
              (LLM.Events.Agent_Event with
               Was_Aborted => False),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (not S.Is_Streaming,
                    "agent_end should clear Is_Streaming");
            Assert_Contains
              (Body_Text, "ready",
               "agent_end should restore the ready status line");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Agent_End_Normal;

   procedure Test_Dispatch_Text_Delta (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Message_Update_Event'
              (LLM.Events.Agent_Event with
               Kind          => LLM.Events.Text_Delta,
               Delta_Text    => To_Unbounded_String ("hello world"),
               Content_Index => 0,
               Tool_Call_Id  => Null_Unbounded_String,
               Tool_Name     => Null_Unbounded_String),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert_Contains
              (Body_Text, "hello world",
               "text_delta should append the streamed text");
            Assert (S.Text_Emitted,
                    "text_delta should set Text_Emitted");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Text_Delta;

   procedure Test_Dispatch_Thinking_Delta (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Message_Update_Event'
              (LLM.Events.Agent_Event with
               Kind          => LLM.Events.Thinking_Delta,
               Delta_Text    => To_Unbounded_String ("a thought"),
               Content_Index => 0,
               Tool_Call_Id  => Null_Unbounded_String,
               Tool_Name     => Null_Unbounded_String),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert_Contains
              (Body_Text, UC_Box_V,
               "thinking_delta should prefix output with the box border");
            Assert_Contains
              (Body_Text, "a thought",
               "thinking_delta should append the thought text");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Thinking_Delta;

   procedure Test_Dispatch_Tool_Start (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Tool_Execution_Start_Event'
              (LLM.Events.Agent_Event with
               Tool_Call_Id => To_Unbounded_String ("tc-1"),
               Tool_Name    => To_Unbounded_String ("read"),
               Args_Json    => To_Unbounded_String
                 ("{""path"":""x.adb""}")),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert_Contains
              (Body_Text, "read",
               "tool_execution_start should write the tool name");
            Assert (S.Has_Tool_In_Turn,
                    "tool_execution_start should set Has_Tool_In_Turn");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Tool_Start;

   procedure Test_Dispatch_Tool_End_Success (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Tool_Execution_Start_Event'
              (LLM.Events.Agent_Event with
               Tool_Call_Id => To_Unbounded_String ("tc-ok"),
               Tool_Name    => To_Unbounded_String ("read"),
               Args_Json    => To_Unbounded_String
                 ("{""path"":""x.adb""}")),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Tool_Execution_End_Event'
              (LLM.Events.Agent_Event with
               Tool_Call_Id => To_Unbounded_String ("tc-ok"),
               Tool_Name    => To_Unbounded_String ("read"),
               Result_Text  => To_Unbounded_String ("done"),
               Is_Error     => False),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert_Contains
              (Body_Text, UC_Check,
               "tool_execution_end success should replace the placeholder"
               & " with a check mark");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Tool_End_Success;

   procedure Test_Dispatch_Tool_End_Error (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Tool_Execution_Start_Event'
              (LLM.Events.Agent_Event with
               Tool_Call_Id => To_Unbounded_String ("tc-err"),
               Tool_Name    => To_Unbounded_String ("read"),
               Args_Json    => To_Unbounded_String
                 ("{""path"":""x.adb""}")),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Tool_Execution_End_Event'
              (LLM.Events.Agent_Event with
               Tool_Call_Id => To_Unbounded_String ("tc-err"),
               Tool_Name    => To_Unbounded_String ("read"),
               Result_Text  => To_Unbounded_String ("boom"),
               Is_Error     => True),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert_Contains
              (Body_Text, UC_Cross,
               "tool_execution_end error should replace the placeholder"
               & " with a cross mark");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Tool_End_Error;

   procedure Test_Dispatch_Message_End_Tokens (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Message_End_Event'
              (LLM.Events.Agent_Event with
               Stop      => LLM.Types.Stop,
               Err_Msg   => Null_Unbounded_String,
               Tok_Usage =>
                 (Input       => 100,
                  Output      => 50,
                  Cache_Read  => 10,
                  Cache_Write => 5),
               Cost_Dmil => 0),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Assert (S.Turn_Input_Tokens = 115,
                 "message_end should sum input, cache_read, and cache_write"
                 & " into Turn_Input_Tokens");
         Assert (S.Turn_Output_Tokens = 50,
                 "message_end should store output tokens");
         Assert (S.Last_Stop_Reason = "stop",
                 "message_end should map Stop to ""stop""");

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Message_End_Tokens;

   procedure Test_Dispatch_Session_Stats_Footer (T : in out Test) is
      pragma Unreferenced (T);
      Session_Id : constant String := "test-session-1234";
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         S.Set_Session_Id (Session_Id);
         S.Set_Model ("anthropic/claude-3-5");
         S.Set_Context_Window (200_000);
         S.Set_Pending_Stats (True);
         S.Set_Turn_Tokens (100, 50);
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Session_Stats_Event'
              (LLM.Events.Agent_Event with
               Cost_Dmil   => 10,
               Input       => 200,
               Output      => 80,
               Cache_Read  => 0,
               Cache_Write => 0,
               Total       => 280),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (not S.Pending_Stats,
                    "session_stats should consume Pending_Stats");
            Assert (S.Session_Cost_Dmil = 10,
                    "session_stats should store Session_Cost_Dmil");
            Assert (S.Turn_Count = 1,
                    "session_stats should append the live turn footer");
            Assert_Contains
              (Body_Text, "coyote-fork+" & PID & "/" & Session_Id & "/1",
               "session_stats should append the live turn footer");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Session_Stats_Footer;

   procedure Test_Dispatch_Model_Select (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Model_Select_Event'
              (LLM.Events.Agent_Event with
               Provider       => To_Unbounded_String ("anthropic"),
               Model_Id       => To_Unbounded_String ("claude-3-5"),
               Context_Window => 200_000),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (S.Current_Model = "anthropic/claude-3-5",
                    "model_select should update Current_Model");
            Assert (S.Context_Window = 200_000,
                    "model_select should update Context_Window");
            Assert_Contains
              (Body_Text, "anthropic/claude-3-5",
               "model_select should refresh the status line");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Model_Select;

   procedure Test_Dispatch_Session_Info (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Session_Info_Event'
              (LLM.Events.Agent_Event with
               Session_Id     => To_Unbounded_String ("test-uuid-1234"),
               Thinking_Level => To_Unbounded_String ("medium")),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (S.Session_Id = "test-uuid-1234",
                    "session_info should update Session_Id");
            Assert (S.Current_Thinking = "medium",
                    "session_info should update Current_Thinking");
            Assert_Contains
              (Body_Text, "medium",
               "session_info should refresh the status line");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Session_Info;

   procedure Test_Dispatch_Auto_Retry_Start (T : in out Test) is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Auto_Retry_Start_Event'
              (LLM.Events.Agent_Event with
               Attempt      => 1,
               Max_Attempts => 3,
               Delay_Ms     => 2_000,
               Error_Msg    => To_Unbounded_String ("rate limit")),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (S.Is_Retrying,
                    "auto_retry_start should set Is_Retrying");
            Assert_Contains
              (Body_Text, "Retry",
               "auto_retry_start should append a retry notice");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Auto_Retry_Start;

   procedure Test_Dispatch_Full_Turn_Footer_Only_After_Session_Stats
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Session_Id : constant String := "dispatch-full-turn-1234";
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         S.Set_Session_Id (Session_Id);
         S.Set_Model ("anthropic/claude-3-5");
         S.Set_Context_Window (200_000);
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Agent_Start_Event'
              (LLM.Events.Agent_Event with null record),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Message_Update_Event'
              (LLM.Events.Agent_Event with
               Kind          => LLM.Events.Text_Delta,
               Delta_Text    => To_Unbounded_String ("hello"),
               Content_Index => 0,
               Tool_Call_Id  => Null_Unbounded_String,
               Tool_Name     => Null_Unbounded_String),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Message_End_Event'
              (LLM.Events.Agent_Event with
               Stop      => LLM.Types.Stop,
               Err_Msg   => Null_Unbounded_String,
               Tok_Usage =>
                 (Input       => 10,
                  Output      => 5,
                  Cache_Read  => 0,
                  Cache_Write => 0),
               Cost_Dmil => 1),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Agent_End_Event'
              (LLM.Events.Agent_Event with
               Was_Aborted => False),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (S.Pending_Stats,
                    "agent_end should defer the footer until session_stats");
            Assert_Not_Contains
              (Body_Text, UC_Dbl_H,
               "footer separator must not appear before session_stats");
         end;

         Dispatch_Event
           (Event   => LLM.Events.Session_Stats_Event'
              (LLM.Events.Agent_Event with
               Cost_Dmil   => 2,
               Input       => 10,
               Output      => 5,
               Cache_Read  => 1,
               Cache_Write => 1,
               Total       => 17),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert_Contains
              (Body_Text, UC_Dbl_H,
               "footer separator must appear after session_stats");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Full_Turn_Footer_Only_After_Session_Stats;

   procedure Test_Dispatch_Aborted_Turn_No_Footer
     (T : in out Test)
   is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Agent_Start_Event'
              (LLM.Events.Agent_Event with null record),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Message_Update_Event'
              (LLM.Events.Agent_Event with
               Kind          => LLM.Events.Text_Delta,
               Delta_Text    => To_Unbounded_String ("partial"),
               Content_Index => 0,
               Tool_Call_Id  => Null_Unbounded_String,
               Tool_Name     => Null_Unbounded_String),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         S.Set_Aborted (True);
         Dispatch_Event
           (Event   => LLM.Events.Agent_End_Event'
              (LLM.Events.Agent_Event with
               Was_Aborted => True),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert_Not_Contains
              (Body_Text, UC_Dbl_H,
               "aborted turn must not append the footer separator");
            Assert (not S.Is_Streaming,
                    "aborted agent_end should clear Is_Streaming");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Aborted_Turn_No_Footer;

   procedure Test_Dispatch_Auto_Retry_End_Then_Normal_Turn
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Session_Id : constant String := "dispatch-retry-end-1234";
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         S.Set_Session_Id (Session_Id);
         S.Set_Model ("anthropic/claude-3-5");
         S.Set_Context_Window (200_000);
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Auto_Retry_Start_Event'
              (LLM.Events.Agent_Event with
               Attempt      => 1,
               Max_Attempts => 3,
               Delay_Ms     => 250,
               Error_Msg    => To_Unbounded_String ("temporary error")),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Assert (S.Is_Retrying,
                 "auto_retry_start should set Is_Retrying");

         Dispatch_Event
           (Event   => LLM.Events.Auto_Retry_End_Event'
              (LLM.Events.Agent_Event with
               Success     => True,
               Attempt     => 1,
               Final_Error => Null_Unbounded_String),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Agent_Start_Event'
              (LLM.Events.Agent_Event with null record),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Message_Update_Event'
              (LLM.Events.Agent_Event with
               Kind          => LLM.Events.Text_Delta,
               Delta_Text    => To_Unbounded_String ("ok"),
               Content_Index => 0,
               Tool_Call_Id  => Null_Unbounded_String,
               Tool_Name     => Null_Unbounded_String),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Message_End_Event'
              (LLM.Events.Agent_Event with
               Stop      => LLM.Types.Stop,
               Err_Msg   => Null_Unbounded_String,
               Tok_Usage =>
                 (Input       => 4,
                  Output      => 2,
                  Cache_Read  => 0,
                  Cache_Write => 0),
               Cost_Dmil => 1),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Agent_End_Event'
              (LLM.Events.Agent_Event with
               Was_Aborted => False),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Session_Stats_Event'
              (LLM.Events.Agent_Event with
               Cost_Dmil   => 3,
               Input       => 4,
               Output      => 2,
               Cache_Read  => 1,
               Cache_Write => 0,
               Total       => 7),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (not S.Is_Retrying,
                    "auto_retry_end should clear Is_Retrying");
            Assert_Contains
              (Body_Text, UC_Dbl_H,
               "normal turn after retry should append the footer");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Auto_Retry_End_Then_Normal_Turn;

   procedure Test_Dispatch_Auto_Compaction_Start_And_End
     (T : in out Test)
   is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Auto_Compaction_Start_Event'
              (LLM.Events.Agent_Event with
               Reason => To_Unbounded_String ("threshold")),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Auto_Compaction_End_Event'
              (LLM.Events.Agent_Event with
               Summary    => To_Unbounded_String ("compacted"),
               Aborted    => False,
               Will_Retry => False,
               Err_Msg    => Null_Unbounded_String),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert (not S.Is_Streaming,
                    "compaction events should leave Is_Streaming False");
            Assert (not S.Is_Compacting,
                    "auto_compaction_end should clear Is_Compacting");
            Assert_Contains
              (Body_Text, "Compacting context",
               "auto_compaction_start should append a visible notice");
            Assert_Contains
              (Body_Text, "Context compacted.",
               "auto_compaction_end should append a completion notice");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Auto_Compaction_Start_And_End;

   procedure Test_Dispatch_Agent_End_No_Response_Shows_Error
     (T : in out Test)
   is
      pragma Unreferenced (T);
   begin
      begin
         declare
            Guard_FS : aliased Nine_P.Client.Fs :=
              Nine_P.Client.Ns_Mount ("acme");
            pragma Unreferenced (Guard_FS);
         begin
            null;
         end;
      exception
         when others =>
            AUnit.Assertions.Assert (True, "");
            return;
      end;

      declare
         FS   : aliased Nine_P.Client.Fs := Nine_P.Client.Ns_Mount ("acme");
         Win  : Acme.Window.Win          :=
           Acme.Window.New_Win (FS'Access);
         S    : App_State;
         Sect : Section_Kind             := No_Section;
      begin
         Acme.Window.Append (Win, FS'Access, Format_Status (S) & ASCII.LF);

         Dispatch_Event
           (Event   => LLM.Events.Agent_Start_Event'
              (LLM.Events.Agent_Event with null record),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         Dispatch_Event
           (Event   => LLM.Events.Agent_End_Event'
              (LLM.Events.Agent_Event with
               Was_Aborted => False),
            Win     => Win,
            FS      => FS'Access,
            State   => S,
            Section => Sect,
            PID     => PID);

         declare
            Body_Text : constant String :=
              Acme.Window.Read_Body (Win, FS'Access);
         begin
            Assert_Contains
              (Body_Text, "No response from the agent",
               "agent_end without text or tool output should warn");
            Assert_Contains
              (Body_Text, "context may be too long",
               "no-response warning should include the context hint");
         end;

         begin
            Acme.Window.Delete (Win, FS'Access);
         exception
            when others => null;
         end;
      exception
         when others =>
            begin
               Acme.Window.Delete (Win, FS'Access);
            exception
               when others => null;
            end;
            raise;
      end;
   end Test_Dispatch_Agent_End_No_Response_Shows_Error;

end Dispatch_Tests;
