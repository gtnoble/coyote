--  Coyote_App.Dispatch body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Types;
with Coyote_App.Frontend;
with Coyote_App.Utils;       use Coyote_App.Utils;

package body Coyote_App.Dispatch is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;
   use type LLM.Types.Stop_Reason;

   function Stop_Reason_Image
     (Reason : LLM.Types.Stop_Reason) return String
   is
   begin
      case Reason is
         when LLM.Types.Stop       => return "stop";
         when LLM.Types.Length     => return "length";
         when LLM.Types.Tool_Use   => return "toolUse";
         when LLM.Types.Aborted    => return "aborted";
         when LLM.Types.Error_Stop => return "error";
         when others               => return "unknown";
      end case;
   end Stop_Reason_Image;

   --  Build the one-line status string.
   function Format_Status
     (State : App_State;
      Extra : String := "ready") return String
   is
      Model_Text   : constant String  := State.Current_Model;
      Session_Text : constant String  := State.Session_Id;
      Think_Text   : constant String  := State.Current_Thinking;
      Sandbox_Text : constant String  := State.Current_Sandbox;
      Input_Tokens : constant Natural := State.Turn_Input_Tokens;
      Ctx_Window   : constant Natural := State.Context_Window;
      Tools_Running_N : constant Natural := State.Tools_Running;
      Tools_Done_N    : constant Natural := State.Tools_Done;

      Model_Part   : constant String :=
        (if Model_Text'Length > 0
         then " [" & Model_Text & "]"
         else "");
      Think_Part   : constant String :=
        (if Think_Text'Length > 0 then " ~" & Think_Text else "");
      Sandbox_Part : constant String :=
        (if Sandbox_Text'Length > 0
         then " [" & Sandbox_Text & "]"
         else "");
      Session_Part : constant String :=
        (if Session_Text'Length >= 8
         then " session:"
              & Session_Text (Session_Text'First
                               .. Session_Text'First + 7)
         else "");
      Context_Part : constant String :=
        (if Input_Tokens > 0 and then Ctx_Window > 0
         then " " & Format_SI_Count (Input_Tokens)
              & "/" & Format_SI_Count (Ctx_Window)
              & " (" & Natural_Image (Input_Tokens * 100 / Ctx_Window)
              & "%)"
         else "");
      Tool_Part    : constant String :=
        (if Tools_Running_N > 0
         then " " & Natural_Image (Tools_Done_N)
              & "+" & Natural_Image (Tools_Running_N)
              & " tools"
         elsif Tools_Done_N > 0
         then " " & Natural_Image (Tools_Done_N) & " tools done"
         else "");
   begin
      return UC_BULLET & " " & Extra
             & Model_Part & Think_Part & Sandbox_Part
             & Context_Part & Tool_Part & Session_Part;
   end Format_Status;

   --  Append a live turn footer and advance the turn counter.
   procedure Append_Live_Turn_Footer
     (Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State)
   is
      Input_Tokens      : constant Natural := State.Turn_Input_Tokens;
      Output_Tokens     : constant Natural := State.Turn_Output_Tokens;
      Ctx_Window        : constant Natural := State.Context_Window;
      Model_Text        : constant String  := State.Current_Model;
      Turn_Cost_Dmil    : constant Natural := State.Turn_Cost_Dmil;
      Session_Cost_Dmil : constant Natural := State.Session_Cost_Dmil;
      Stop_Reason_Text  : constant String  := State.Last_Stop_Reason;
      Footer_Summary    : constant String :=
        Format_Turn_Summary
          (Input_Tokens      => Input_Tokens,
           Output_Tokens     => Output_Tokens,
           Ctx_Window        => Ctx_Window,
           Model_Text        => Model_Text,
           Turn_Cost_Dmil    => Turn_Cost_Dmil,
           Session_Cost_Dmil => Session_Cost_Dmil,
           Stop_Reason_Text  => Stop_Reason_Text);
   begin
      State.Increment_Turn_Count;
      Frontend.Append_Turn_Footer
        (Format_Turn_Footer_Display
           (Input_Tokens      => Input_Tokens,
            Output_Tokens     => Output_Tokens,
            Ctx_Window        => Ctx_Window,
            Model_Text        => Model_Text,
            Turn_Cost_Dmil    => Turn_Cost_Dmil,
            Session_Cost_Dmil => Session_Cost_Dmil,
            Stop_Reason_Text => Stop_Reason_Text),
         Summary => Footer_Summary);
      Frontend.Append_Fork_Action
        (UUID   => State.Session_Id,
         Turn_N => State.Turn_Count,
         Step_N => 0);
   end Append_Live_Turn_Footer;

   --  Append a step-level turn footer for an intermediate assistant message
   --  (stop = toolUse) within a turn.  Does not increment Turn_Count.
   procedure Append_Step_Footer
     (Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State)
   is
      Input_Tokens      : constant Natural := State.Turn_Input_Tokens;
      Output_Tokens     : constant Natural := State.Turn_Output_Tokens;
      Ctx_Window        : constant Natural := State.Context_Window;
      Model_Text        : constant String  := State.Current_Model;
      Turn_Cost_Dmil    : constant Natural := State.Turn_Cost_Dmil;
      Stop_Reason_Text  : constant String  := State.Last_Stop_Reason;
      Footer_Summary    : constant String :=
        Format_Turn_Summary
          (Input_Tokens      => Input_Tokens,
           Output_Tokens     => Output_Tokens,
           Ctx_Window        => Ctx_Window,
           Model_Text        => Model_Text,
           Turn_Cost_Dmil    => Turn_Cost_Dmil,
           Stop_Reason_Text  => Stop_Reason_Text);
   begin
      Frontend.Append_Turn_Footer
        (Format_Turn_Footer_Display
           (Input_Tokens      => Input_Tokens,
            Output_Tokens     => Output_Tokens,
            Ctx_Window        => Ctx_Window,
            Model_Text        => Model_Text,
            Turn_Cost_Dmil    => Turn_Cost_Dmil,
            Session_Cost_Dmil => 0,  --  session cost unavailable at step level
            Stop_Reason_Text => Stop_Reason_Text,
            Is_Step          => True),
         Kind    => Coyote_App.Frontend.Step_Footer,
         Summary => Footer_Summary);
      Frontend.Append_Fork_Action
        (UUID   => State.Session_Id,
         Turn_N => State.Turn_Count + 1,
         Step_N => State.Turn_Step);
   end Append_Step_Footer;

   procedure Dispatch_Event
     (Event    : LLM.Events.Agent_Event'Class;
      Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State;
      Section  : in out Section_Kind)
   is
   begin

      --  ── agent_start ───────────────────────────────────────────────────
      if Event in LLM.Events.Agent_Start_Event then
         State.Set_Streaming (True);
         State.Set_Text_Emitted (False);
         State.Set_Has_Text_Delta (False);
         State.Set_Has_Tool_In_Turn (False);
         State.Reset_Tool_Counts;
         State.Reset_Turn_Step;
         State.Set_Tool_Cancelled (False);
         State.Set_Last_Stop_Reason ("");
         State.Set_Last_Error_Message ("");
         Section := No_Section;
         Frontend.Set_Status (Format_Status (State, "running"));
         Frontend.Set_Mode (Coyote_App.Frontend.Running);

      --  ── agent_end ─────────────────────────────────────────────────────
      elsif Event in LLM.Events.Agent_End_Event then
         State.Set_Streaming (False);
         State.Set_Paused (False);
         State.Set_Pause_Armed (False);
         State.Set_Is_Retrying (False);
         Section := No_Section;
         declare
            Ev : constant LLM.Events.Agent_End_Event :=
              LLM.Events.Agent_End_Event (Event);
         begin
            if Ev.Was_Aborted then
               State.Set_Aborted (True);
            end if;
         end;
         if State.Was_Aborted then
            Frontend.Append_Notice
              (Coyote_App.Frontend.Info,
               ASCII.LF & "[STOP] Aborted." & ASCII.LF);
            Frontend.Complete_Request
              (Coyote_App.Frontend.Aborted);
            State.Set_Pending_Stats (False);
            State.Set_Aborted (False);
         else
            declare
               Stop    : constant String := State.Last_Stop_Reason;
               Err_Msg : constant String := State.Last_Error_Message;
            begin
               if Stop = "error" then
                  Frontend.Append_Notice
                    (Coyote_App.Frontend.Warning,
                     "Agent stopped with an error"
                     & (if Err_Msg'Length > 0
                        then ": " & Err_Msg
                        else ""));
                  Frontend.Complete_Request
                    (Coyote_App.Frontend.Failed);
                  State.Set_Pending_Stats (False);
               elsif not State.Text_Emitted
                 and then not State.Is_Retrying
               then
                  Frontend.Append_Notice
                    (Coyote_App.Frontend.Warning,
                     "No response from the agent"
                     & (if Err_Msg'Length > 0
                        then ": " & Err_Msg
                        else " -- context may be too long, or a temporary"
                             & " error occurred. Try New."));
                  Frontend.Complete_Request
                    (Coyote_App.Frontend.Failed);
               end if;
            end;
         end if;
         if State.Last_Stop_Reason = "stop"
           or else State.Last_Stop_Reason = "length"
         then
            State.Set_Pending_Stats (True);
         end if;
         Frontend.Set_Status (Format_Status (State, "ready"));
         Frontend.Set_Mode (Coyote_App.Frontend.Idle);

      elsif Event in LLM.Events.Message_Update_Event then
         declare
            Ev : constant LLM.Events.Message_Update_Event :=
              LLM.Events.Message_Update_Event (Event);
         begin
            if Ev.Kind = LLM.Events.Thinking_Delta then
               if Section /= Thinking_Section then
                  Frontend.Begin_Thinking;
                  Section := Thinking_Section;
               end if;
               Frontend.Append_Thinking (To_String (Ev.Delta_Text));
               State.Set_Text_Emitted (True);

            elsif Ev.Kind = LLM.Events.Thinking_End then
               Frontend.End_Thinking;
               Section := No_Section;

            elsif Ev.Kind = LLM.Events.Text_Delta then
               if Section /= Text_Section then
                  if Section /= No_Section then
                     Frontend.Append_Text ("" & ASCII.LF);
                  end if;
                  Section := Text_Section;
               end if;
               State.Set_Text_Emitted (True);
               State.Set_Has_Text_Delta (True);
               Frontend.Append_Text (To_String (Ev.Delta_Text));

            elsif Ev.Kind = LLM.Events.Text_End then
               Frontend.End_Text_Block;
               Section := No_Section;
            end if;
         end;

      --  ── tool_execution_start ──────────────────────────────────────────
      elsif Event in LLM.Events.Tool_Execution_Start_Event then
         State.Set_Text_Emitted (True);
         State.Set_Has_Tool_In_Turn (True);
         State.Increment_Tool_Call;
         State.Increment_Tools_Running;
         Frontend.Set_Status (Format_Status (State, "running"));
         declare
            Ev      : constant LLM.Events.Tool_Execution_Start_Event :=
              LLM.Events.Tool_Execution_Start_Event (Event);
            Tool    : constant String := To_String (Ev.Tool_Name);
            Tool_Id : constant String := To_String (Ev.Tool_Call_Id);
            Sess    : constant String := State.Session_Id;
         begin
            Frontend.Begin_Tool
              (Name             => Tool,
               Args_Json        => To_String (Ev.Args_Json),
               Session_Id       => Sess,
               Tool_Id           => Tool_Id,
               Model            => State.Current_Model,
               Source_Directory => State.Source_Directory,
               Session_Start    => State.Session_Start,
               Turn_Index       => State.Turn_Count + 1,
               Call_In_Turn     => State.Current_Tool_Call);
            Section := Tool_Section;
         end;

      --  ── tool_execution_end ────────────────────────────────────────────
      elsif Event in LLM.Events.Tool_Execution_End_Event then
         declare
            Ev      : constant LLM.Events.Tool_Execution_End_Event :=
              LLM.Events.Tool_Execution_End_Event (Event);
            Tool_Id : constant String := To_String (Ev.Tool_Call_Id);
            Status  : Coyote_App.Frontend.Tool_End_Status;
         begin
            if Ev.Is_Cancelled then
               Status := Coyote_App.Frontend.Cancelled;
               State.Set_Tool_Cancelled (True);
            elsif Ev.Is_Error then
               Status := Coyote_App.Frontend.Error;
            else
               Status := Coyote_App.Frontend.Success;
            end if;
            Frontend.End_Tool
              (Tool_Id     => Tool_Id,
               Status      => Status,
               Result_Text => To_String (Ev.Result_Text),
               Media_Type  => To_String (Ev.Media_Type));
            Section := No_Section;
         end;

      --  ── tool_execution_end continued: tool-done counting ──────────────
            State.Increment_Tools_Done;

            --  When the last tool in a batch completes and the assistant
            --  is continuing the turn (stop = toolUse), emit a step-level
            --  fork footer so the user can branch the session at this
            --  intermediate decision point.
            if State.Tools_Running = 0
              and then State.Has_Tool_In_Turn
              and then not State.Tool_Cancelled
              and then State.Last_Stop_Reason = "toolUse"
            then
               State.Increment_Turn_Step;
               Append_Step_Footer
                 (Frontend => Frontend,
                  State    => State);
            end if;

            Frontend.Set_Status (Format_Status (State, "running"));
      elsif Event in LLM.Events.Message_End_Event then
         declare
            Ev           : constant LLM.Events.Message_End_Event :=
              LLM.Events.Message_End_Event (Event);
            Input_Count  : constant Natural :=
              Ev.Tok_Usage.Input
              + Ev.Tok_Usage.Cache_Read
              + Ev.Tok_Usage.Cache_Write;
            Output_Count : constant Natural := Ev.Tok_Usage.Output;
         begin
            State.Set_Last_Stop_Reason (Stop_Reason_Image (Ev.Stop));
            if Ev.Stop = LLM.Types.Error_Stop then
               State.Set_Last_Error_Message (To_String (Ev.Err_Msg));
            else
               State.Set_Last_Error_Message ("");
            end if;
            if Input_Count > 0 or else Output_Count > 0 then
               State.Set_Turn_Tokens (Input_Count, Output_Count);
            end if;
            if Ev.Cost_Dmil > 0 then
               State.Set_Turn_Cost (Ev.Cost_Dmil);
            end if;
         end;

      --  ── auto_retry_start ──────────────────────────────────────────────
      elsif Event in LLM.Events.Auto_Retry_Start_Event then
         State.Set_Is_Retrying (True);
         declare
            Ev          : constant LLM.Events.Auto_Retry_Start_Event :=
              LLM.Events.Auto_Retry_Start_Event (Event);
            Attempt     : constant Natural := Ev.Attempt;
            Max_Att     : constant Natural := Ev.Max_Attempts;
            Delay_Ms    : constant Natural := Ev.Delay_Ms;
            Err_Msg     : constant String  := To_String (Ev.Error_Msg);
            Delay_S_Str : constant String  :=
              (if Delay_Ms >= 1000
               then Natural_Image (Delay_Ms / 1000) & "s"
               else Natural_Image (Delay_Ms) & "ms");
         begin
            Frontend.Append_Notice
              (Coyote_App.Frontend.Info,
               ASCII.LF
               & UC_RETRY & " Retry "
               & Natural_Image (Attempt)
               & "/" & Natural_Image (Max_Att)
               & " in " & Delay_S_Str
               & ": " & Err_Msg
               & ASCII.LF);
            Frontend.Set_Status (Format_Status (State, "retrying"));
         end;

      --  ── auto_retry_end ────────────────────────────────────────────────
      elsif Event in LLM.Events.Auto_Retry_End_Event then
         State.Set_Is_Retrying (False);
         declare
            Ev : constant LLM.Events.Auto_Retry_End_Event :=
              LLM.Events.Auto_Retry_End_Event (Event);
         begin
            if not Ev.Success then
               declare
                  Final_Err : constant String := To_String (Ev.Final_Error);
                  Attempts  : constant Natural := Ev.Attempt;
               begin
                  Frontend.Append_Notice
                    (Coyote_App.Frontend.Info,
                     ASCII.LF
                     & UC_CROSS & " Retry failed after "
                     & Natural_Image (Attempts)
                     & (if Attempts = 1 then " attempt" else " attempts")
                     & (if Final_Err'Length > 0
                        then ": " & Final_Err
                        else "")
                     & ASCII.LF);
               end;
            end if;
         end;

      --  ── auto_compaction_start ─────────────────────────────────────────
      elsif Event in LLM.Events.Auto_Compaction_Start_Event then
         State.Set_Compacting (True);
         declare
            Ev     : constant LLM.Events.Auto_Compaction_Start_Event :=
              LLM.Events.Auto_Compaction_Start_Event (Event);
            Reason : constant String := To_String (Ev.Reason);
            Label  : constant String :=
              (if Reason = "overflow"
               then "Overflow: compacting context" & UC_ELLIP
               else "Compacting context" & UC_ELLIP);
         begin
            Frontend.Append_Notice
              (Coyote_App.Frontend.Info,
               ASCII.LF & UC_GEAR & " " & Label & ASCII.LF);
         end;
         Frontend.Set_Status (Format_Status (State, "compacting"));

      --  ── auto_compaction_end ───────────────────────────────────────────
      elsif Event in LLM.Events.Auto_Compaction_End_Event then
         State.Set_Compacting (False);
         declare
            Ev         : constant LLM.Events.Auto_Compaction_End_Event :=
              LLM.Events.Auto_Compaction_End_Event (Event);
            Err_Msg    : constant String  := To_String (Ev.Err_Msg);
            Is_Aborted : constant Boolean := Ev.Aborted;
            Will_Retry : constant Boolean := Ev.Will_Retry;
         begin
            if Err_Msg'Length > 0 then
               Frontend.Append_Notice
                 (Coyote_App.Frontend.Warning,
                  "Compaction failed: " & Err_Msg);
            elsif Is_Aborted then
               Frontend.Append_Notice
                 (Coyote_App.Frontend.Info,
                  ASCII.LF & UC_CROSS & " Compaction aborted." & ASCII.LF);
            elsif Will_Retry then
               Frontend.Append_Notice
                 (Coyote_App.Frontend.Info,
                  ASCII.LF & UC_CHECK
                  & " Context compacted, retrying" & UC_ELLIP
                  & ASCII.LF);
            else
               Frontend.Append_Notice
                 (Coyote_App.Frontend.Info,
                  ASCII.LF & UC_CHECK & " Context compacted." & ASCII.LF);
            end if;
         end;
         Frontend.Set_Status
           (Format_Status
              (State,
               (if State.Is_Streaming then "running" else "ready")));

      --  ── model_select ──────────────────────────────────────────────────
      elsif Event in LLM.Events.Model_Select_Event then
         declare
            Ev         : constant LLM.Events.Model_Select_Event :=
              LLM.Events.Model_Select_Event (Event);
            Provider   : constant String  := To_String (Ev.Provider);
            Model_Id   : constant String  := To_String (Ev.Model_Id);
            Ctx_Window : constant Natural := Ev.Context_Window;
         begin
            if Provider'Length > 0 and then Model_Id'Length > 0 then
               State.Set_Model (Provider & "/" & Model_Id);
            end if;
            if Ctx_Window > 0 then
               State.Set_Context_Window (Ctx_Window);
            end if;
         end;
         Frontend.Set_Status
           (Format_Status
              (State,
               (if State.Is_Streaming then "running" else "ready")));

      --  ── session_info ──────────────────────────────────────────────────
      elsif Event in LLM.Events.Session_Info_Event then
         declare
            Ev           : constant LLM.Events.Session_Info_Event :=
              LLM.Events.Session_Info_Event (Event);
            Session_Id_V : constant String := To_String (Ev.Session_Id);
            Think_Level  : constant String := To_String (Ev.Thinking_Level);
         begin
            if Session_Id_V'Length > 0 then
               State.Set_Session_Id (Session_Id_V);
            end if;
            if Think_Level'Length > 0 then
               State.Set_Thinking (Think_Level);
            end if;
            State.Set_Model (To_String (Ev.Model));
            State.Set_Source_Directory (To_String (Ev.Source_Directory));
            State.Set_Session_Start (To_String (Ev.Session_Start));
            declare
               Sandbox : constant String := To_String (Ev.Sandbox_Profile);
            begin
               State.Set_Sandbox (Sandbox);
            end;
         end;
         Frontend.Set_Status (Format_Status (State, "ready"));

      --  ── session_stats ─────────────────────────────────────────────────
      elsif Event in LLM.Events.Session_Stats_Event then
         declare
            Ev : constant LLM.Events.Session_Stats_Event :=
              LLM.Events.Session_Stats_Event (Event);
         begin
            State.Set_Session_Stats
              (Cost_Dmil   => Ev.Cost_Dmil,
               Input       => Ev.Input,
               Output      => Ev.Output,
               Cache_Read  => Ev.Cache_Read,
               Cache_Write => Ev.Cache_Write,
               Total       => Ev.Total);
         end;
         if State.Pending_Stats then
            State.Set_Pending_Stats (False);
            Append_Live_Turn_Footer
              (Frontend => Frontend,
               State    => State);
            Frontend.Complete_Request
              (Coyote_App.Frontend.Completed);
         end if;
         Frontend.Set_Status (Format_Status (State, "ready"));

      --  ── agent_paused ──────────────────────────────────────────────────
      elsif Event in LLM.Events.Agent_Paused_Event then
         State.Set_Paused (True);
         State.Set_Pause_Armed (False);
         Frontend.Set_Status (Format_Status (State, "paused"));
         Frontend.Set_Mode (Coyote_App.Frontend.Paused);

      --  ── agent_resumed ─────────────────────────────────────────────────
      elsif Event in LLM.Events.Agent_Resumed_Event then
         State.Set_Paused (False);
         Frontend.Set_Status (Format_Status (State, "running"));
         Frontend.Set_Mode (Coyote_App.Frontend.Running);

      end if;
   end Dispatch_Event;

end Coyote_App.Dispatch;
