--  Coyote_App body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;          use GNATCOLL.JSON;
with GNATCOLL.OS.Process;
with LLM.Compaction;
with LLM.Agent;
with LLM.Events;
with LLM.Providers;
with LLM.Session_Store;
with LLM.Settings;
with LLM.Types;
with Coyote_App.Frontend.GUI;
with Coyote_Process_Control;
with Coyote_GUI.Prompt_Queue;
with Coyote_GUI;
with Coyote_Notify;
with Coyote_Spawn;
with Gtk.Main;
with Coyote_App.History;    use Coyote_App.History;
with Coyote_App.Dispatch;   use Coyote_App.Dispatch;
with Coyote_App.Utils;      use Coyote_App.Utils;

package body Coyote_App is

   use type LLM.Events.Message_Update_Kind;


   --  ── App_State body ────────────────────────────────────────────────────

   protected body App_State is

      function Session_Id         return String  is
        (To_String (P_Session_Id));
      function Current_Model      return String  is
        (To_String (P_Model));
      function Current_Thinking   return String  is
        (To_String (P_Thinking));
      function Current_Sandbox    return String  is
        (To_String (P_Sandbox));
      function Source_Directory   return String is
        (To_String (P_Source_Directory));
      function Session_Start      return String is
        (To_String (P_Session_Start));
      function Current_Tool_Call  return Natural is
        (P_Tool_Call);
      function Is_Streaming       return Boolean is (P_Streaming);
      function Is_Compacting      return Boolean is (P_Compacting);
      function Was_Aborted        return Boolean is (P_Aborted);
      function Is_Paused          return Boolean is (P_Paused);
      function Is_Pause_Armed     return Boolean is (P_Pause_Armed);
      function Is_Retrying        return Boolean is (P_Is_Retrying);
      function Text_Emitted       return Boolean is (P_Text_Emitted);
      function Has_Tool_In_Turn return Boolean is (P_Has_Tool_In_Turn);
      function Tools_Running return Natural is (P_Tools_Running);
      function Tools_Done    return Natural is (P_Tools_Done);
      function Pending_Stats      return Boolean is (P_Pending_Stats);
      function Context_Window     return Natural is (P_Ctx_Win);
      function Turn_Input_Tokens  return Natural is (P_Turn_In);
      function Turn_Output_Tokens return Natural is (P_Turn_Out);
      function Turn_Count         return Natural is (P_Turn_Count);
      function Turn_Cost_Dmil     return Natural is (P_Turn_Cost);
      function Session_Cost_Dmil  return Natural is (P_Sess_Cost);
      function Session_Input_Tokens  return Natural is (P_Sess_In);
      function Session_Output_Tokens return Natural is (P_Sess_Out);
      function Session_Cache_Read    return Natural is (P_Sess_Cache_R);
      function Session_Cache_Write   return Natural is (P_Sess_Cache_W);
      function Session_Total_Tokens  return Natural is (P_Sess_Total);
      function Prompt_Filter      return String  is
        (To_String (P_Prompt_Filter));
      function Agent_Ready return Boolean is (P_Agent_Ready);

      procedure Set_Agent_Ready (Value : Boolean) is
      begin
         P_Agent_Ready := Value;
      end Set_Agent_Ready;

      procedure Set_Agent_Stopped (Value : Boolean) is
      begin
         P_Agent_Stopped := Value;
      end Set_Agent_Stopped;

      entry Wait_Agent_Ready when P_Agent_Ready or else P_Shutdown is
      begin
         null;
      end Wait_Agent_Ready;

      function Agent_Stopped return Boolean is (P_Agent_Stopped);

      entry Wait_Agent_Stopped when P_Agent_Stopped is
      begin
         null;
      end Wait_Agent_Stopped;

      function Frontend_Ready return Boolean is (P_Frontend_Ready);
      function Shutdown_Requested return Boolean is (P_Shutdown);

      procedure Set_Frontend_Ready (Value : Boolean) is
      begin
         P_Frontend_Ready := Value;
      end Set_Frontend_Ready;

      procedure Set_Session_Id (Id : String) is
      begin
         P_Session_Id := To_Unbounded_String (Id);
      end Set_Session_Id;

      procedure Set_Model (Model : String) is
      begin
         P_Model := To_Unbounded_String (Model);
      end Set_Model;

      procedure Set_Thinking (Level : String) is
      begin
         P_Thinking := To_Unbounded_String (Level);
      end Set_Thinking;

      procedure Set_Sandbox (Profile : String) is
      begin
         P_Sandbox := To_Unbounded_String (Profile);
      end Set_Sandbox;

      procedure Set_Source_Directory (Directory : String) is
      begin
         P_Source_Directory := To_Unbounded_String (Directory);
      end Set_Source_Directory;

      procedure Set_Session_Start (Start : String) is
      begin
         P_Session_Start := To_Unbounded_String (Start);
      end Set_Session_Start;

      procedure Set_Streaming (Value : Boolean) is
      begin
         P_Streaming := Value;
      end Set_Streaming;

      procedure Set_Compacting (Value : Boolean) is
      begin
         P_Compacting := Value;
      end Set_Compacting;

      procedure Set_Aborted (Value : Boolean) is
      begin
         P_Aborted := Value;
      end Set_Aborted;

      procedure Set_Paused (Value : Boolean) is
      begin
         P_Paused := Value;
      end Set_Paused;

      procedure Set_Pause_Armed (Value : Boolean) is
      begin
         P_Pause_Armed := Value;
      end Set_Pause_Armed;

      procedure Set_Is_Retrying (Value : Boolean) is
      begin
         P_Is_Retrying := Value;
      end Set_Is_Retrying;

      procedure Set_Text_Emitted (Value : Boolean) is
      begin
         P_Text_Emitted := Value;
      end Set_Text_Emitted;

      function Has_Text_Delta return Boolean is (P_Has_Text_Delta);

      procedure Set_Has_Text_Delta (Value : Boolean) is
      begin
         P_Has_Text_Delta := Value;
      end Set_Has_Text_Delta;

      procedure Set_Has_Tool_In_Turn (Value : Boolean) is
      begin
         P_Has_Tool_In_Turn := Value;
      end Set_Has_Tool_In_Turn;

      procedure Increment_Tools_Running is
      begin
         P_Tools_Running := P_Tools_Running + 1;
      end Increment_Tools_Running;

      procedure Increment_Tools_Done is
      begin
         P_Tools_Done    := P_Tools_Done + 1;
         if P_Tools_Running > 0 then
            P_Tools_Running := P_Tools_Running - 1;
         end if;
      end Increment_Tools_Done;

      procedure Increment_Tool_Call is
      begin
         P_Tool_Call := P_Tool_Call + 1;
      end Increment_Tool_Call;

      procedure Reset_Tool_Counts is
      begin
         P_Tools_Running := 0;
         P_Tools_Done    := 0;
         P_Tool_Call     := 0;
      end Reset_Tool_Counts;

      function Last_Stop_Reason return String is
        (To_String (P_Last_Stop_Reason));

      procedure Set_Last_Stop_Reason (Value : String) is
      begin
         P_Last_Stop_Reason := To_Unbounded_String (Value);
      end Set_Last_Stop_Reason;

      function Last_Error_Message return String is
        (To_String (P_Last_Error_Message));

      procedure Set_Last_Error_Message (Value : String) is
      begin
         P_Last_Error_Message := To_Unbounded_String (Value);
      end Set_Last_Error_Message;

      procedure Set_Pending_Stats (Value : Boolean) is
      begin
         P_Pending_Stats := Value;
      end Set_Pending_Stats;


      procedure Set_Context_Window (N : Natural) is
      begin
         P_Ctx_Win := N;
      end Set_Context_Window;

      procedure Set_Turn_Tokens (Input, Output : Natural) is
      begin
         P_Turn_In  := Input;
         P_Turn_Out := Output;
      end Set_Turn_Tokens;

      procedure Set_Turn_Cost (Dmil : Natural) is
      begin
         P_Turn_Cost := Dmil;
      end Set_Turn_Cost;

      procedure Set_Session_Stats
        (Cost_Dmil   : Natural;
         Input       : Natural;
         Output      : Natural;
         Cache_Read  : Natural;
         Cache_Write : Natural;
         Total       : Natural)
      is
      begin
         P_Sess_Cost    := Cost_Dmil;
         P_Sess_In      := Input;
         P_Sess_Out     := Output;
         P_Sess_Cache_R := Cache_Read;
         P_Sess_Cache_W := Cache_Write;
         P_Sess_Total   := Total;
      end Set_Session_Stats;


      procedure Set_Prompt_Filter (Cmd : String) is
      begin
         P_Prompt_Filter := To_Unbounded_String (Cmd);
      end Set_Prompt_Filter;


      procedure Increment_Turn_Count is
      begin
         P_Turn_Count := P_Turn_Count + 1;
      end Increment_Turn_Count;

      procedure Set_Turn_Count (N : Natural) is
      begin
         P_Turn_Count := N;
      end Set_Turn_Count;

      procedure Reset_Turn_Count is
      begin
         P_Turn_Count := 0;
      end Reset_Turn_Count;

      function Turn_Step          return Natural is (P_Turn_Step);
      procedure Increment_Turn_Step is
      begin
         P_Turn_Step := P_Turn_Step + 1;
      end Increment_Turn_Step;
      procedure Reset_Turn_Step is
      begin
         P_Turn_Step := 0;
      end Reset_Turn_Step;
      procedure Set_Turn_Step (N : Natural) is
      begin
         P_Turn_Step := N;
      end Set_Turn_Step;

      function Tool_Cancelled     return Boolean is (P_Tool_Cancelled);
      procedure Set_Tool_Cancelled (Value : Boolean) is
      begin
         P_Tool_Cancelled := Value;
      end Set_Tool_Cancelled;

      procedure Set_One_Shot_Result (Json : String) is
      begin
         --  First write wins; ignore subsequent calls so that the exception
         --  handler cannot clobber an already-captured success result.
         if Length (P_One_Shot_Result) = 0 then
            P_One_Shot_Result := To_Unbounded_String (Json);
         end if;
      end Set_One_Shot_Result;

      function One_Shot_Result return String is
      begin
         return To_String (P_One_Shot_Result);
      end One_Shot_Result;

      procedure Signal_Shutdown is
      begin
         P_Shutdown := True;
      end Signal_Shutdown;

      entry Wait_Shutdown when P_Shutdown is
      begin
         null;
      end Wait_Shutdown;

   end App_State;

   procedure Split_Model_Spec
     (Spec     :     String;
      Provider : out Unbounded_String;
      Model_Id : out Unbounded_String)
   is
      Slash : constant Natural := Ada.Strings.Fixed.Index (Spec, "/");
   begin
      if Slash = 0
        or else Slash = Spec'First
        or else Slash = Spec'Last
      then
         raise Constraint_Error with
           "Model spec must be provider/model-id: " & Spec;
      end if;

      Provider := To_Unbounded_String (Spec (Spec'First .. Slash - 1));
      Model_Id := To_Unbounded_String (Spec (Slash + 1 .. Spec'Last));
   end Split_Model_Spec;

   --  ── Run_GUI ───────────────────────────────────────────────────────────
   --
   --  The GTK main loop runs on the main Ada task.  Agent_Task runs
   --  concurrently and communicates with GTK through the frontend's
   --  protected update queue.

   procedure Run_GUI (Opts : Options) is
      use type LLM.Events.Message_Update_Kind;

      Win_Name : constant String :=
        "coyote"
        & (if Length (Opts.Name) > 0
           then " : " & To_String (Opts.Name)
           else "");

      --  Shared objects closed over by Agent_Task:
      State            : App_State;
      Agent_Session    : aliased LLM.Agent.Session;
      My_Frontend      : Coyote_App.Frontend.GUI.Instance;
      Startup_Settings : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;

      function Status_Label return String is
      begin
         if State.Is_Compacting then
            return "compacting";
         elsif State.Is_Retrying then
            return "retrying";
         elsif State.Is_Paused then
            return "paused";
         elsif State.Is_Streaming then
            return "running";
         else
            return "ready";
         end if;
      end Status_Label;

      procedure Initiate_Shutdown is
      begin
         Coyote_Process_Control.Stop_Monitor;
         LLM.Agent.Request_Abort (Agent_Session);
         My_Frontend.Shutdown;
         State.Signal_Shutdown;
      exception
         when others =>
            My_Frontend.Shutdown;
            State.Signal_Shutdown;
      end Initiate_Shutdown;

      task Agent_Task;
      task Shutdown_Monitor;

      task body Shutdown_Monitor is
         First  : Boolean;
         Signal : Natural;
      begin
         loop
            exit when Coyote_Process_Control.Monitor_Should_Stop;
            Signal := Coyote_Process_Control.Read_Signal;
            if Signal = 0 then
               delay 0.05;
            else
               Coyote_Process_Control.Begin_Shutdown (First);
               if First then
                  if State.Agent_Ready then
                     Coyote_Process_Control.Freeze_Persistence;
                     if State.Frontend_Ready then
                        My_Frontend.Shutdown;
                     end if;
                     LLM.Agent.Request_Abort (Agent_Session);
                  else
                     if State.Frontend_Ready then
                        My_Frontend.Shutdown;
                     end if;
                  end if;
                  Coyote_Process_Control.Complete_Shutdown
                    (Immediate => Signal >= 2);
                  if State.Agent_Ready then
                     State.Wait_Agent_Stopped;
                  end if;
                  My_Frontend.Shutdown;
                  State.Signal_Shutdown;
               else
                  Coyote_Process_Control.Signal_All
                    (Coyote_Process_Control.SIGKILL_Signal);
               end if;
               exit;
            end if;
         end loop;
      exception
         when others =>
            My_Frontend.Shutdown;
            State.Signal_Shutdown;
      end Shutdown_Monitor;

      task body Agent_Task is
         Section          : Section_Kind    := No_Section;
         Current_Thinking : Unbounded_String := Null_Unbounded_String;
         Current_Sandbox  : Unbounded_String := Null_Unbounded_String;
         Current_Text     : Unbounded_String := Null_Unbounded_String;
         Final_Text         : Unbounded_String := Null_Unbounded_String;
         Final_Error        : Unbounded_String := Null_Unbounded_String;
         Completion_Pending : Boolean := False;
      begin
         declare

            procedure Track_Event
              (E : LLM.Events.Agent_Event'Class)
            is
            begin
               if E in LLM.Events.Message_Update_Event then
                  declare
                     Event : constant LLM.Events.Message_Update_Event :=
                       LLM.Events.Message_Update_Event (E);
                  begin
                     if Event.Kind = LLM.Events.Text_Delta then
                        Append (Current_Text, To_String (Event.Delta_Text));
                     end if;
                  end;
               elsif E in LLM.Events.Message_End_Event then
                  declare
                     Event : constant LLM.Events.Message_End_Event :=
                       LLM.Events.Message_End_Event (E);
                  begin
                     if Event.Stop in LLM.Types.Stop | LLM.Types.Length then
                        Final_Text := Current_Text;
                     end if;
                     if Length (Event.Err_Msg) > 0 then
                        Final_Error := Event.Err_Msg;
                     end if;
                     Current_Text := Null_Unbounded_String;
                  end;
               elsif E in LLM.Events.Agent_End_Event then
                  declare
                     Agent_End : constant LLM.Events.Agent_End_Event :=
                       LLM.Events.Agent_End_Event (E);
                  begin
                     if Length (Agent_End.Error_Msg) > 0 then
                        Final_Error := Agent_End.Error_Msg;
                     end if;
                     Completion_Pending :=
                       not Agent_End.Was_Aborted
                       and then not Opts.One_Shot
                       and then not Opts.Subagent;
                  end;
               elsif E in LLM.Events.Session_Stats_Event then
                  declare
                     Ev : constant LLM.Events.Session_Stats_Event :=
                       LLM.Events.Session_Stats_Event (E);
                  begin
                     My_Frontend.Set_Stats_Summary
                       ((Model          =>
                           To_Unbounded_String (State.Current_Model),
                         Session_Id     =>
                           To_Unbounded_String (State.Session_Id),
                         Turn_Count     => State.Turn_Count,
                         Last_Input     => State.Turn_Input_Tokens,
                         Last_Output    => State.Turn_Output_Tokens,
                         Last_Cost_Dmil => State.Turn_Cost_Dmil,
                         Input          => Ev.Input,
                         Cache_Read     => Ev.Cache_Read,
                         Cache_Write    => Ev.Cache_Write,
                         Output         => Ev.Output,
                         Cost_Dmil      => Ev.Cost_Dmil));
                  end;
               end if;
            end Track_Event;

            procedure Dispatch_Event
              (E : LLM.Events.Agent_Event'Class)
            is
            begin
               Track_Event (E);
               Coyote_App.Dispatch.Dispatch_Event
                 (Event    => E,
                  Frontend => My_Frontend,
                  State    => State,
                  Section  => Section);
               if E in LLM.Events.Session_Stats_Event
                 and then Completion_Pending
               then
                  My_Frontend.Notify_Completion;
                  Completion_Pending := False;
               end if;
            end Dispatch_Event;

            procedure Dispatch_Agent_Event
              (E : LLM.Events.Agent_Event'Class)
              renames Dispatch_Event;

            procedure Emit_Model_Select is
               Model_Spec : constant String :=
                 LLM.Agent.Current_Model_Spec (Agent_Session);
               Provider   : Unbounded_String;
               Model_Id   : Unbounded_String;
            begin
               if Model_Spec'Length = 0 then
                  return;
               end if;
               Split_Model_Spec (Model_Spec, Provider, Model_Id);
               declare
                  Event : constant LLM.Events.Model_Select_Event :=
                    (LLM.Events.Agent_Event with
                     Provider       => Provider,
                     Model_Id       => Model_Id,
                     Context_Window =>
                       LLM.Agent.Context_Window (Agent_Session));
               begin
                  Dispatch_Event (Event);
               end;
            end Emit_Model_Select;

            procedure Emit_Session_Info is
               Session_Id : constant String :=
                 LLM.Agent.Session_Id (Agent_Session);
               Event : constant LLM.Events.Session_Info_Event :=
                 (LLM.Events.Agent_Event with
                  Session_Id       => To_Unbounded_String (Session_Id),
                  Thinking_Level   => Current_Thinking,
                  Sandbox_Profile  =>
                    To_Unbounded_String
                      (LLM.Agent.Current_Sandbox (Agent_Session)),
                  Model            => To_Unbounded_String
                    (LLM.Agent.Current_Model_Spec (Agent_Session)),
                  Source_Directory => To_Unbounded_String
                    (LLM.Session_Store.Session_Work_Dir (Session_Id)),
                  Session_Start    => To_Unbounded_String
                    (LLM.Session_Store.Session_Created_At (Session_Id)));
            begin
               if Session_Id'Length > 0 then
                  My_Frontend.Set_Session_Identity (Session_Id);
               end if;
               Dispatch_Event (Event);
            end Emit_Session_Info;

            procedure Emit_Bootstrap is
            begin
               Emit_Model_Select;
               Emit_Session_Info;
            end Emit_Bootstrap;

            procedure Append_Task_Warning (Message : String) is
            begin
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error, "[!] " & Message);
               My_Frontend.Append_Notice
                 (Coyote_App.Frontend.Error, Message);
            end Append_Task_Warning;

            procedure Reset_Session_State is
            begin
               State.Set_Streaming (False);
               State.Set_Compacting (False);
               State.Set_Aborted (False);
               State.Set_Is_Retrying (False);
               State.Set_Text_Emitted (False);
               State.Set_Has_Text_Delta (False);
               State.Set_Has_Tool_In_Turn (False);
               State.Set_Last_Stop_Reason ("");
               State.Set_Last_Error_Message ("");
               State.Set_Pending_Stats (False);
               State.Set_Turn_Tokens (0, 0);
               State.Set_Turn_Cost (0);
               State.Set_Session_Stats (0, 0, 0, 0, 0, 0);
               State.Reset_Turn_Count;
            end Reset_Session_State;

            procedure Render_Loaded_Session (UUID : String) is
               Short_Id : constant String :=
                 (if UUID'Length >= 8
                  then UUID (UUID'First .. UUID'First + 7)
                  else UUID);
            begin
               My_Frontend.Append_Notice
                 (Coyote_App.Frontend.Info,
                  "Loading session " & Short_Id & UC_ELLIP);
               Render_Session_History
                 (UUID     => UUID,
                  Frontend => My_Frontend,
                  State    => State);
            end Render_Loaded_Session;

            procedure Synchronize_Sandbox is
               Profile : constant String :=
                 LLM.Agent.Current_Sandbox (Agent_Session);
            begin
               Current_Sandbox := To_Unbounded_String (Profile);
               State.Set_Sandbox (Profile);
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE", Profile);
            end Synchronize_Sandbox;

            procedure Store_One_Shot_Result is
               Result : constant JSON_Value := Create_Object;
            begin
               if State.Was_Aborted then
                  Result.Set_Field ("error", Create ("aborted"));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
               elsif Length (Final_Text) > 0 then
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  Result.Set_Field
                    ("output", Create (To_String (Final_Text)));
                  State.Set_One_Shot_Result (Write (Result));
               elsif Length (Final_Error) > 0 then
                  Result.Set_Field
                    ("error", Create (To_String (Final_Error)));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
               else
                  Result.Set_Field
                    ("error", Create ("No response from agent"));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
               end if;
            end Store_One_Shot_Result;

            procedure Run_Queued_Prompt
              (Prompt   : String;
               Is_Steer : Boolean)
            is
               pragma Unreferenced (Is_Steer);
            begin
               LLM.Agent.Run_Prompt
                 (S        => Agent_Session,
                  Prompt   => Prompt,
                  On_Event => Dispatch_Event'Access);
               if Opts.One_Shot then
                  Store_One_Shot_Result;
                  Initiate_Shutdown;
               end if;
            exception
               when Ex : others =>
                  declare
                     Error_Text : constant String :=
                       (if Length (Final_Error) > 0
                        then To_String (Final_Error)
                        else Ada.Exceptions.Exception_Message (Ex));
                  begin
                     Append_Task_Warning
                       ("prompt failed: " & Error_Text);
                     if Opts.One_Shot then
                        declare
                           Err : constant JSON_Value := Create_Object;
                        begin
                           Err.Set_Field
                             ("error", "prompt failed: " & Error_Text);
                           Err.Set_Field
                             ("session_id",
                              Create (LLM.Agent.Session_Id (Agent_Session)));
                           State.Set_One_Shot_Result (Write (Err));
                        end;
                     end if;
                     Initiate_Shutdown;
                  end;
            end Run_Queued_Prompt;

         begin
            --  Load settings.
            declare
               Settings_Value : constant LLM.Settings.Settings :=
                 Startup_Settings;
            begin
               Coyote_Process_Control.Set_Grace_Seconds
                 (Settings_Value.Shell_Termination_Grace_Seconds);
               Current_Thinking := Settings_Value.Default_Thinking;
               if Length (Opts.Prompt_Filter) > 0 then
                  State.Set_Prompt_Filter
                    (To_String (Opts.Prompt_Filter));
               else
                  State.Set_Prompt_Filter
                    (To_String (Settings_Value.Prompt_Filter));
               end if;
               --  Inherit thinking level from parent subagent process.
               declare
                  Think_Level : constant String :=
                    Ada.Environment_Variables.Value
                      ("COYOTE_THINKING_LEVEL", "");
               begin
                  if Think_Level'Length > 0 then
                     Current_Thinking :=
                       Ada.Strings.Unbounded.To_Unbounded_String (Think_Level);
                  end if;
               end;
            end;

            My_Frontend.Set_Status ("Initializing" & UC_ELLIP);

            --  Promote inherited session ID for subagent lineage.
            declare
               Inherited_Sid : constant String :=
                 Ada.Environment_Variables.Value
                   ("COYOTE_SESSION_ID", "");
               Parent_Sid    : constant String :=
                 Ada.Environment_Variables.Value
                   ("COYOTE_PARENT_SESSION", "");
            begin
               if Parent_Sid'Length = 0
                 and then Inherited_Sid'Length > 0
               then
                  Ada.Environment_Variables.Set
                    ("COYOTE_PARENT_SESSION", Inherited_Sid);
               end if;
            end;

            LLM.Agent.Create
              (S          => Agent_Session,
               Model_Spec => To_String (Opts.Model),
               Agent      => To_String (Opts.Agent),
               No_Tools   => Opts.No_Tools,
               Session_Id => To_String (Opts.Session_Id),
               Subagent   => Opts.Subagent);
            State.Set_Agent_Ready (True);
            Synchronize_Sandbox;
            My_Frontend.Register_Session (Agent_Session'Unchecked_Access);
            if Opts.No_Compact then
               LLM.Agent.Set_Compact_Settings
                 (Agent_Session,
                  (Enabled              => False,
                   Reserve_Tokens       =>
                     LLM.Compaction.Default_Compact_Settings
                       .Reserve_Tokens,
                   Keep_Recent_Tokens   =>
                     LLM.Compaction.Default_Compact_Settings
                       .Keep_Recent_Tokens,
                   Consecutive_Failures => 0,
                   Tripped              => False));
            end if;

            --  Publish session ID for child processes.
            declare
               Sess : constant String :=
                 LLM.Agent.Session_Id (Agent_Session);
            begin
               if Sess'Length > 0 then
                  Ada.Environment_Variables.Set
                    ("COYOTE_SESSION_ID", Sess);
               end if;
            end;
            --  Publish the stable OpenRouter Broadcast identity for child
            --  subagent processes.  Durable coyote lineage continues to use
            --  COYOTE_SESSION_ID independently.
            Ada.Environment_Variables.Set
              ("COYOTE_OPENROUTER_SESSION_ID",
               LLM.Agent.OpenRouter_Session_Id (Agent_Session));
            --  Publish the thinking level for child subagent processes.
            if Ada.Strings.Unbounded.Length (Current_Thinking) > 0 then
               Ada.Environment_Variables.Set
                 ("COYOTE_THINKING_LEVEL",
                  Ada.Strings.Unbounded.To_String (Current_Thinking));
            else
               Ada.Environment_Variables.Set
                 ("COYOTE_THINKING_LEVEL", "");
            end if;

            --  Publish the sandbox profile for child subagent processes.
            if Ada.Strings.Unbounded.Length (Current_Sandbox) > 0 then
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE",
                  Ada.Strings.Unbounded.To_String (Current_Sandbox));
            else
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE", "");
            end if;


            if Length (Opts.Session_Id) > 0 then
               Render_Loaded_Session (To_String (Opts.Session_Id));
            end if;
            if Length (Opts.Work_Dir_Warning) > 0 then
               Append_Task_Warning (To_String (Opts.Work_Dir_Warning));
            end if;
            Emit_Bootstrap;

            --  If an initial prompt was supplied via --prompt, run it now.
            --  For --subagent / one-shot mode Run_Queued_Prompt calls
            --  Initiate_Shutdown after the turn, which marks the prompt
            --  queue for shutdown so Prompt_Loop exits immediately.
            if Length (Opts.Initial_Prompt) > 0 then
               My_Frontend.Begin_Request
                 (Text => To_String (Opts.Initial_Prompt),
                  Kind => Coyote_App.Frontend.Prompt);
               Run_Queued_Prompt
                 (Prompt   => To_String (Opts.Initial_Prompt),
                  Is_Steer => False);
            end if;

            --  Main input loop.
            Prompt_Loop : loop
               declare
                  It       : constant Coyote_GUI.Prompt_Queue.Item :=
                    My_Frontend.Read_Item;
                  Is_Steer : constant Boolean :=
                    State.Is_Streaming or else State.Is_Retrying;
               begin
                  case It.Kind is

                     when Coyote_GUI.Prompt_Queue.Shutdown_Item =>
                        exit Prompt_Loop;

                     when Coyote_GUI.Prompt_Queue.User_Prompt =>
                        declare
                           Prompt : constant String :=
                             Ada.Strings.Unbounded.To_String (It.Text);
                        begin
                           My_Frontend.Begin_Request
                             (Text => Prompt,
                              Kind =>
                                (if Is_Steer
                                 then Coyote_App.Frontend.Steer
                                 else Coyote_App.Frontend.Prompt));
                           Run_Queued_Prompt (Prompt, Is_Steer);
                        end;

                     when Coyote_GUI.Prompt_Queue.Stop =>
                        State.Set_Aborted (True);
                        LLM.Agent.Request_Abort (Agent_Session);

                     when Coyote_GUI.Prompt_Queue.Pause =>
                        if State.Is_Streaming
                          and then not State.Is_Paused
                          and then not State.Is_Pause_Armed
                        then
                           State.Set_Pause_Armed (True);
                           LLM.Agent.Request_Pause (Agent_Session);
                        end if;

                     when Coyote_GUI.Prompt_Queue.Resume =>
                        if State.Is_Paused then
                           State.Set_Paused (False);
                           LLM.Agent.Resume (Agent_Session);
                        end if;

                     when Coyote_GUI.Prompt_Queue.Compact =>
                        if not State.Is_Streaming
                          and then not State.Is_Compacting
                        then
                           declare
                              Compact_OK : Boolean;
                           begin
                              LLM.Agent.Compact
                                (Agent_Session,
                                 Dispatch_Agent_Event'Unrestricted_Access,
                                 "manual",
                                 Compact_OK);
                           end;
                        end if;

                     when Coyote_GUI.Prompt_Queue.Clear =>
                        My_Frontend.Clear_Conversation;

                     when Coyote_GUI.Prompt_Queue.New_Window =>
                        declare
                           use GNATCOLL.OS.Process;
                           Model   : constant String :=
                             LLM.Agent.Current_Model_Spec (Agent_Session);
                           Args    : Argument_List;
                        begin
                           Args.Append (Ada.Command_Line.Command_Name);
                           if Model'Length > 0 then
                              Args.Append ("--model");
                              Args.Append (Model);
                           end if;
                           Coyote_Spawn.Spawn_Detached
                             (Args,
                              Cwd => Ada.Directories.Current_Directory);
                        end;

                     when Coyote_GUI.Prompt_Queue.New_Session =>
                        begin
                           if State.Is_Streaming then
                              LLM.Agent.Request_Abort (Agent_Session);
                           end if;
                           declare
                              Settings_Value : constant LLM.Settings.Settings :=
                                LLM.Settings.Load_Settings;
                           begin
                              Ada.Environment_Variables.Set
                                ("COYOTE_THINKING_LEVEL",
                                 To_String (Settings_Value.Default_Thinking));
                              Ada.Environment_Variables.Set
                                ("COYOTE_SANDBOX_PROFILE",
                                 To_String (Settings_Value.Default_Sandbox));
                              LLM.Agent.Create
                                (S        => Agent_Session,
                                 Agent    => To_String (Opts.Agent),
                                 No_Tools => Opts.No_Tools);
                              Current_Thinking := Settings_Value.Default_Thinking;
                           end;
                           Synchronize_Sandbox;
                           My_Frontend.Register_Session
                             (Agent_Session'Unchecked_Access);
                           if Opts.No_Compact then
                              LLM.Agent.Set_Compact_Settings
                                (Agent_Session,
                                 (Enabled              => False,
                                  Reserve_Tokens       =>
                                    LLM.Compaction.Default_Compact_Settings
                                      .Reserve_Tokens,
                                  Keep_Recent_Tokens   =>
                                    LLM.Compaction.Default_Compact_Settings
                                      .Keep_Recent_Tokens,
                                  Consecutive_Failures => 0,
                                  Tripped              => False));
                           end if;
                           declare
                              Sess : constant String :=
                                LLM.Agent.Session_Id (Agent_Session);
                           begin
                              if Sess'Length > 0 then
                                 Ada.Environment_Variables.Set
                                   ("COYOTE_SESSION_ID", Sess);
                              end if;
                           end;
                           Ada.Environment_Variables.Set
                             ("COYOTE_OPENROUTER_SESSION_ID",
                              LLM.Agent.OpenRouter_Session_Id
                                (Agent_Session));
                           Reset_Session_State;
                           My_Frontend.Clear_Stats;
                           My_Frontend.Clear_Conversation;
                           Emit_Bootstrap;
                           My_Frontend.Append_Notice
                             (Coyote_App.Frontend.Info,
                              "New session" & UC_ELLIP);
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("new session failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Model =>
                        begin
                           LLM.Agent.Set_Model
                             (S    => Agent_Session,
                              Spec => Ada.Strings.Unbounded.To_String
                                        (It.Model_Spec));
                           Emit_Model_Select;
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("model change failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Thinking =>
                        begin
                           Current_Thinking :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Ada.Characters.Handling.To_Lower
                                  (LLM.Providers.Thinking_Level'Image
                                     (It.Level)));
                           LLM.Agent.Set_Thinking
                             (S     => Agent_Session,
                              Level => It.Level);
                           State.Set_Thinking (To_String (Current_Thinking));
                           Ada.Environment_Variables.Set
                             ("COYOTE_THINKING_LEVEL",
                              To_String (Current_Thinking));
                           My_Frontend.Set_Status
                             (Format_Status (State, Status_Label));
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("thinking change failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Sandbox =>
                        begin
                           Current_Sandbox := It.Profile_Name;
                           LLM.Agent.Set_Sandbox_Profile
                             (S       => Agent_Session,
                              Profile => To_String (Current_Sandbox));
                           State.Set_Sandbox
                             (To_String (Current_Sandbox));
                           Ada.Environment_Variables.Set
                             ("COYOTE_SANDBOX_PROFILE",
                              To_String (Current_Sandbox));
                           My_Frontend.Set_Status
                             (Format_Status (State, Status_Label));
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("sandbox profile change failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Switch_Session =>
                        begin
                           LLM.Agent.Switch_Session
                             (S    => Agent_Session,
                              UUID => Ada.Strings.Unbounded.To_String
                                        (It.Session_UUID));
                           Ada.Environment_Variables.Set
                             ("COYOTE_OPENROUTER_SESSION_ID",
                              LLM.Agent.OpenRouter_Session_Id
                                (Agent_Session));
                           Synchronize_Sandbox;
                           Reset_Session_State;
                           My_Frontend.Clear_Stats;
                           My_Frontend.Clear_Conversation;
                           Render_Loaded_Session
                             (Ada.Strings.Unbounded.To_String
                                (It.Session_UUID));
                           Emit_Bootstrap;
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("session switch failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Default =>
                        declare
                           Model_Spec : constant String :=
                             LLM.Agent.Current_Model_Spec (Agent_Session);
                           Provider : Unbounded_String;
                           Model_Id : Unbounded_String;
                        begin
                           if Model_Spec'Length > 0 then
                              Split_Model_Spec
                                (Model_Spec, Provider, Model_Id);
                           end if;
                           LLM.Settings.Save_Defaults
                             (Provider    => To_String (Provider),
                              Model_Id    => To_String (Model_Id),
                              Think_Level => State.Current_Thinking);
                           My_Frontend.Append_Notice
                             (Coyote_App.Frontend.Info,
                              "Defaults saved: " & Model_Spec
                              & (if
                                State.Current_Thinking'Length > 0
                                then " ~" & State.Current_Thinking
                                else ""));
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("saving defaults failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Preferences =>
                        begin
                           LLM.Settings.Save_Preferences
                             (Provider    => To_String
                                (It.Preferences.Provider),
                              Model_Id    => To_String
                                (It.Preferences.Model_Id),
                              Think_Level => Ada.Characters.Handling.To_Lower
                                (LLM.Providers.Thinking_Level'Image
                                   (It.Preferences.Thinking)),
                              Sandbox     => To_String
                                (It.Preferences.Sandbox),
                              Subagent_Provider        => To_String
                                (It.Preferences.Subagent_Provider),
                              Subagent_Model           => To_String
                                (It.Preferences.Subagent_Model),
                              Max_Recursion_Depth      =>
                                It.Preferences.Max_Recursion_Depth,
                              Completion_Notifications =>
                                It.Preferences.Completion_Notifications,
                              Price_Display => It.Preferences.Price_Display,
                              Skill_Paths => It.Preferences.Skill_Paths,
                              Termination_Grace_Seconds =>
                                It.Preferences.Termination_Grace_Seconds);
                           Coyote_Process_Control.Set_Grace_Seconds
                             (It.Preferences.Termination_Grace_Seconds);
                           My_Frontend.Set_Completion_Notifications
                             (It.Preferences.Completion_Notifications);
                           My_Frontend.Append_Notice
                             (Coyote_App.Frontend.Info,
                              "Preferences saved for new sessions");
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("saving preferences failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;
                  end case;
               end;
            end loop Prompt_Loop;
            My_Frontend.Shutdown;

            State.Signal_Shutdown;

         exception
            when Ex : others =>
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "[!] Agent task: "
                  & Ada.Exceptions.Exception_Message (Ex));
               My_Frontend.Append_Notice
                 (Coyote_App.Frontend.Error,
                  "Agent task: "
                  & Ada.Exceptions.Exception_Message (Ex));
               Initiate_Shutdown;
         end;
         State.Set_Agent_Stopped (True);
      end Agent_Task;

   begin
      --  Initialise GTK on the main task and create the window.
      --  The idle callback registered inside Create will drain the
      --  Updates queue once Gtk.Main.Main is running.
      Gtk.Main.Init;
      Coyote_App.Frontend.GUI.Create
        (F                          => My_Frontend,
         Win_Name                   => Win_Name,
         Pop_Under                  => Opts.Subagent,
         Notifications_Allowed      =>
           not Opts.One_Shot and then not Opts.Subagent,
         Notifications_Enabled     =>
           Startup_Settings.Completion_Notifications);
      State.Set_Frontend_Ready (True);
      if Coyote_Process_Control.Shutdown_Requested then
         My_Frontend.Shutdown;
         State.Signal_Shutdown;
         return;
      end if;

      if Opts.Debug_Logging then
         My_Frontend.Set_Debug_Logging (True);
      end if;

      --  Enter the GTK event loop; returns when Main_Quit is called
      --  (either from the window close handler or the Shutdown update).
      Gtk.Main.Main;
      Coyote_Notify.Finalize;

      --  For one-shot mode, wait for Agent_Task to store the result
      --  before we return (Agent_Task calls State.Signal_Shutdown just
      --  before enqueueing the Shutdown update).
      if Opts.One_Shot then
         State.Wait_Shutdown;
         declare
            Json : constant String := State.One_Shot_Result;
         begin
            if Json'Length > 0 then
               Ada.Text_IO.Put_Line (Json);
            else
               declare
                  Err : constant JSON_Value := Create_Object;
               begin
                  Err.Set_Field
                    ("error",
                     "subagent closed before producing output");
                  Ada.Text_IO.Put_Line (Write (Err));
               end;
            end if;
         end;
      end if;

      --  Delete empty sessions (not resumed, no prompts submitted).
      if not Opts.No_Session
        and then Length (Opts.Session_Id) = 0
        and then not LLM.Agent.Has_Submitted_Prompts (Agent_Session)
      then
         declare
            S_Id : constant String :=
              LLM.Agent.Session_Id (Agent_Session);
         begin
            if S_Id'Length > 0 then
               LLM.Session_Store.Delete_Session (S_Id);
            end if;
         exception
            when others =>
               null;
         end;
      end if;
   end Run_GUI;

end Coyote_App;
