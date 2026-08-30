--  Coyote_App.Plain body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON; use GNATCOLL.JSON;
with LLM.Agent;
with LLM.Compaction;
with LLM.Events;
with LLM.Session_Store;
with LLM.Settings;
with LLM.Types;
with Coyote_App.Dispatch; use Coyote_App.Dispatch;
with Coyote_App.Frontend.Plain;
with Coyote_App.History; use Coyote_App.History;
with Coyote_App.Utils; use Coyote_App.Utils;
with Coyote_Process_Control;

package body Coyote_App.Plain is

   use type LLM.Events.Message_Update_Kind;

   procedure Run (Opts : Coyote_App.Options) is
      State            : Coyote_App.App_State;
      Agent_Session    : aliased LLM.Agent.Session;
      Frontend         : Coyote_App.Frontend.Plain.Instance;
      Settings         : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;
      Current_Thinking : Unbounded_String := Settings.Default_Thinking;
      Current_Text     : Unbounded_String;
      Final_Text       : Unbounded_String;
      Final_Error      : Unbounded_String;
      Was_Aborted      : Boolean := False;
      Agent_Ready      : Boolean := False;
      Section          : Coyote_App.Section_Kind := Coyote_App.No_Section;

      task Shutdown_Monitor;

      procedure Stop_Monitor is
      begin
         Coyote_Process_Control.Stop_Monitor;
      end Stop_Monitor;

      procedure Signal_Shutdown is
      begin
         State.Signal_Shutdown;
      end Signal_Shutdown;

      procedure Store_One_Shot_Result is
         Result : constant JSON_Value := Create_Object;
      begin
         if Was_Aborted then
            Result.Set_Field ("error", Create ("aborted"));
         elsif Length (Final_Text) > 0 then
            Result.Set_Field ("output", Create (To_String (Final_Text)));
         elsif Length (Final_Error) > 0 then
            Result.Set_Field ("error", Create (To_String (Final_Error)));
         else
            Result.Set_Field ("error", Create ("No response from agent"));
         end if;
         if Agent_Ready then
            Result.Set_Field
              ("session_id", Create (LLM.Agent.Session_Id (Agent_Session)));
         end if;
         State.Set_One_Shot_Result (Write (Result));
      end Store_One_Shot_Result;

      procedure Emit_One_Shot_Result is
      begin
         if Opts.One_Shot then
            Ada.Text_IO.Put_Line (State.One_Shot_Result);
         end if;
      end Emit_One_Shot_Result;

      procedure Track_Event (Event : LLM.Events.Agent_Event'Class) is
      begin
         if Event in LLM.Events.Message_Update_Event then
            declare
               Update : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (Event);
            begin
               if Update.Kind = LLM.Events.Text_Delta then
                  Append (Current_Text, To_String (Update.Delta_Text));
               end if;
            end;
         elsif Event in LLM.Events.Message_End_Event then
            declare
               Message_End : constant LLM.Events.Message_End_Event :=
                 LLM.Events.Message_End_Event (Event);
            begin
               if Message_End.Stop in LLM.Types.Stop | LLM.Types.Length then
                  Final_Text := Current_Text;
               end if;
               if Length (Message_End.Err_Msg) > 0 then
                  Final_Error := Message_End.Err_Msg;
               end if;
               Current_Text := Null_Unbounded_String;
            end;
         elsif Event in LLM.Events.Agent_End_Event then
            declare
               Agent_End : constant LLM.Events.Agent_End_Event :=
                 LLM.Events.Agent_End_Event (Event);
            begin
               Was_Aborted := Agent_End.Was_Aborted;
               if Length (Agent_End.Error_Msg) > 0 then
                  Final_Error := Agent_End.Error_Msg;
               end if;
            end;
         end if;
      end Track_Event;

      procedure Dispatch_Agent_Event
        (Event : LLM.Events.Agent_Event'Class)
      is
      begin
         Track_Event (Event);
         Coyote_App.Dispatch.Dispatch_Event
           (Event    => Event,
            Frontend => Frontend,
            State    => State,
            Section  => Section);
      end Dispatch_Agent_Event;

      procedure Emit_Model_Select is
         Model_Spec : constant String :=
           LLM.Agent.Current_Model_Spec (Agent_Session);
         Slash      : Natural := 0;
      begin
         if Model_Spec'Length = 0 then
            return;
         end if;
         for I in Model_Spec'Range loop
            if Model_Spec (I) = '/' then
               Slash := I;
               exit;
            end if;
         end loop;
         if Slash = 0 or else Slash = Model_Spec'First
           or else Slash = Model_Spec'Last
         then
            return;
         end if;
         declare
            Event : constant LLM.Events.Model_Select_Event :=
              (LLM.Events.Agent_Event with
               Provider       => To_Unbounded_String
                 (Model_Spec (Model_Spec'First .. Slash - 1)),
               Model_Id       => To_Unbounded_String
                 (Model_Spec (Slash + 1 .. Model_Spec'Last)),
               Context_Window => LLM.Agent.Context_Window (Agent_Session));
         begin
            Dispatch_Agent_Event (Event);
         end;
      end Emit_Model_Select;

      procedure Emit_Session_Info is
         Session_Id : constant String :=
           LLM.Agent.Session_Id (Agent_Session);
         Event : constant LLM.Events.Session_Info_Event :=
           (LLM.Events.Agent_Event with
            Session_Id       => To_Unbounded_String (Session_Id),
            Thinking_Level   => Current_Thinking,
            Sandbox_Profile  => To_Unbounded_String
              (LLM.Agent.Current_Sandbox (Agent_Session)),
            Model            => To_Unbounded_String
              (LLM.Agent.Current_Model_Spec (Agent_Session)),
            Source_Directory => To_Unbounded_String
              (LLM.Session_Store.Session_Work_Dir (Session_Id)),
            Session_Start    => To_Unbounded_String
              (LLM.Session_Store.Session_Created_At (Session_Id)));
      begin
         Dispatch_Agent_Event (Event);
      end Emit_Session_Info;

      procedure Configure_Environment is
      begin
         if Length (Opts.Prompt_Filter) > 0 then
            State.Set_Prompt_Filter (To_String (Opts.Prompt_Filter));
         else
            State.Set_Prompt_Filter (To_String (Settings.Prompt_Filter));
         end if;
         declare
            Inherited_Thinking : constant String :=
              Ada.Environment_Variables.Value
                ("COYOTE_THINKING_LEVEL", "");
            Inherited_Session : constant String :=
              Ada.Environment_Variables.Value ("COYOTE_SESSION_ID", "");
            Parent_Session : constant String :=
              Ada.Environment_Variables.Value
                ("COYOTE_PARENT_SESSION", "");
         begin
            if Inherited_Thinking'Length > 0 then
               Current_Thinking := To_Unbounded_String (Inherited_Thinking);
            end if;
            if Parent_Session'Length = 0
              and then Inherited_Session'Length > 0
            then
               Ada.Environment_Variables.Set
                 ("COYOTE_PARENT_SESSION", Inherited_Session);
            end if;
         end;
      end Configure_Environment;

      procedure Publish_Environment is
         Session_Id : constant String :=
           LLM.Agent.Session_Id (Agent_Session);
         Sandbox : constant String :=
           LLM.Agent.Current_Sandbox (Agent_Session);
      begin
         if Session_Id'Length > 0 then
            Ada.Environment_Variables.Set ("COYOTE_SESSION_ID", Session_Id);
         end if;
         Ada.Environment_Variables.Set
           ("COYOTE_OPENROUTER_SESSION_ID",
            LLM.Agent.OpenRouter_Session_Id (Agent_Session));
         Ada.Environment_Variables.Set
           ("COYOTE_THINKING_LEVEL", To_String (Current_Thinking));
         Ada.Environment_Variables.Set ("COYOTE_SANDBOX_PROFILE", Sandbox);
      end Publish_Environment;

      procedure Reset_Prompt_Tracking is
      begin
         Current_Text := Null_Unbounded_String;
         Final_Text := Null_Unbounded_String;
         Final_Error := Null_Unbounded_String;
         Was_Aborted := False;
      end Reset_Prompt_Tracking;

      procedure Run_Prompt (Prompt : String) is
      begin
         Reset_Prompt_Tracking;
         declare
            Warning : Unbounded_String;
            Filtered : constant String := Apply_Prompt_Filter
              (Raw      => Prompt,
               Filter   => State.Prompt_Filter,
               Warn_Buf => Warning);
         begin
            if Length (Warning) > 0 then
               Frontend.Append_Notice
                 (Coyote_App.Frontend.Warning, To_String (Warning));
            end if;
            Frontend.Begin_Request (Filtered);
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => Filtered,
               On_Event => Dispatch_Agent_Event'Access);
         end;
         if Opts.One_Shot then
            Store_One_Shot_Result;
         end if;
      exception
         when Ex : others =>
            declare
               Error_Text : constant String :=
                 (if Length (Final_Error) > 0
                  then To_String (Final_Error)
                  else Ada.Exceptions.Exception_Message (Ex));
            begin
               Frontend.Append_Notice
                 (Coyote_App.Frontend.Error,
                  "prompt failed: " & Error_Text);
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "[!] prompt failed: " & Error_Text);
               if Opts.One_Shot then
                  Final_Error := To_Unbounded_String
                    ("prompt failed: " & Error_Text);
                  Store_One_Shot_Result;
               end if;
            end;
      end Run_Prompt;

      task body Shutdown_Monitor is
         Signal : Natural;
         First  : Boolean;
      begin
         loop
            exit when Coyote_Process_Control.Monitor_Should_Stop;
            Signal := Coyote_Process_Control.Read_Signal;
            if Signal = 0 then
               delay 0.05;
            else
               Coyote_Process_Control.Begin_Shutdown (First);
               if First and then Agent_Ready then
                  Coyote_Process_Control.Freeze_Persistence;
                  LLM.Agent.Request_Abort (Agent_Session);
                  Coyote_Process_Control.Complete_Shutdown
                    (Immediate => Signal >= 2);
               end if;
               Signal_Shutdown;
               exit;
            end if;
         end loop;
      exception
         when others =>
            Signal_Shutdown;
      end Shutdown_Monitor;

   begin
      Coyote_Process_Control.Set_Grace_Seconds
        (Settings.Shell_Termination_Grace_Seconds);
      Configure_Environment;
      Frontend.Create (Opts.One_Shot);
      Frontend.Set_Status ("Initializing" & UC_ELLIP);

      LLM.Agent.Create
        (S          => Agent_Session,
         Model_Spec => To_String (Opts.Model),
         Agent      => To_String (Opts.Agent),
         No_Tools   => Opts.No_Tools,
         Session_Id => To_String (Opts.Session_Id),
         Subagent   => Opts.Subagent);
      Agent_Ready := True;
      State.Set_Agent_Ready (True);
      State.Set_Sandbox (LLM.Agent.Current_Sandbox (Agent_Session));
      Publish_Environment;
      if Opts.No_Compact then
         LLM.Agent.Set_Compact_Settings
           (Agent_Session,
            (Enabled              => False,
             Reserve_Tokens       =>
               LLM.Compaction.Default_Compact_Settings.Reserve_Tokens,
             Keep_Recent_Tokens   =>
               LLM.Compaction.Default_Compact_Settings.Keep_Recent_Tokens,
             Consecutive_Failures => 0,
             Tripped              => False));
      end if;

      if Length (Opts.Session_Id) > 0 then
         Frontend.Append_Notice
           (Coyote_App.Frontend.Info,
            "Loading session " & To_String (Opts.Session_Id));
         Render_Session_History
           (UUID     => To_String (Opts.Session_Id),
            Frontend => Frontend,
            State    => State);
      end if;
      if Length (Opts.Work_Dir_Warning) > 0 then
         Frontend.Append_Notice
           (Coyote_App.Frontend.Warning,
            To_String (Opts.Work_Dir_Warning));
      end if;
      Emit_Model_Select;
      Emit_Session_Info;

      if Length (Opts.Initial_Prompt) > 0 then
         Run_Prompt (To_String (Opts.Initial_Prompt));
      elsif Opts.One_Shot then
         Frontend.Append_Notice
           (Coyote_App.Frontend.Error,
            "one-shot requires --prompt (use --prompt - to read from stdin)");
         declare
            Result : constant JSON_Value := Create_Object;
         begin
            Result.Set_Field
              ("error",
               Create
                 ("one-shot requires --prompt (use --prompt - to read from stdin)"));
            State.Set_One_Shot_Result (Write (Result));
         end;
      end if;

      if not Opts.One_Shot then
         Prompt_Loop : loop
            declare
               Prompt : constant String := Frontend.Read_Prompt;
            begin
               exit Prompt_Loop when Prompt'Length = 0;
               Run_Prompt (Prompt);
            end;
         end loop Prompt_Loop;
      end if;

      Stop_Monitor;
      Frontend.Shutdown;
      Signal_Shutdown;
      if not Opts.No_Session
        and then Length (Opts.Session_Id) = 0
        and then not LLM.Agent.Has_Submitted_Prompts (Agent_Session)
      then
         declare
            Session_Id : constant String :=
              LLM.Agent.Session_Id (Agent_Session);
         begin
            if Session_Id'Length > 0 then
               LLM.Session_Store.Delete_Session (Session_Id);
            end if;
         exception
            when others =>
               null;
         end;
      end if;
      Emit_One_Shot_Result;
   exception
      when Ex : others =>
         Stop_Monitor;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] headless runner: " & Ada.Exceptions.Exception_Message (Ex));
         if Opts.One_Shot then
            declare
               Result : constant JSON_Value := Create_Object;
            begin
               Result.Set_Field
                 ("error", "headless runner: "
                  & Ada.Exceptions.Exception_Message (Ex));
               if Agent_Ready then
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
               end if;
               State.Set_One_Shot_Result (Write (Result));
            end;
         end if;
         Frontend.Shutdown;
         Signal_Shutdown;
         Emit_One_Shot_Result;
   end Run;

end Coyote_App.Plain;
