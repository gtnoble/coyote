--  LLM.Agent.Pi_Adapter body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Types;

package body LLM.Agent.Pi_Adapter is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;

   function Stop_Reason_Image
     (Reason : LLM.Types.Stop_Reason) return String
   is
   begin
      case Reason is
         when LLM.Types.Stop =>
            return "stop";
         when LLM.Types.Length =>
            return "length";
         when LLM.Types.Tool_Use =>
            return "toolUse";
         when LLM.Types.Aborted =>
            return "aborted";
         when LLM.Types.Error_Stop =>
            return "error";
         when others =>
            return "unknown";
      end case;
   end Stop_Reason_Image;

   function Args_Object (Args_Json : String) return GNATCOLL.JSON.JSON_Value is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Json);
   begin
      if Parsed.Success
        and then Parsed.Value.Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Parsed.Value;
      end if;

      return GNATCOLL.JSON.Create_Object;
   end Args_Object;

   function To_Pi_Json
     (E : LLM.Events.Agent_Event'Class) return String
   is
   begin
      if E in LLM.Events.Agent_Start_Event then
         return "{""type"":""agent_start""}";
      elsif E in LLM.Events.Agent_End_Event then
         return "{""type"":""agent_end"",""messages"":[]}";
      elsif E in LLM.Events.Message_Update_Event then
         declare
            Event : constant LLM.Events.Message_Update_Event :=
              LLM.Events.Message_Update_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Sub   : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            case Event.Kind is
               when LLM.Events.Text_Delta =>
                  Root.Set_Field ("type", "message_update");
                  Sub.Set_Field ("type", "text_delta");
                  Sub.Set_Field ("delta", To_String (Event.Delta_Text));
                  Root.Set_Field ("assistantMessageEvent", Sub);
                  return GNATCOLL.JSON.Write (Root);

               when LLM.Events.Thinking_Delta =>
                  Root.Set_Field ("type", "message_update");
                  Sub.Set_Field ("type", "thinking_delta");
                  Sub.Set_Field ("delta", To_String (Event.Delta_Text));
                  Root.Set_Field ("assistantMessageEvent", Sub);
                  return GNATCOLL.JSON.Write (Root);

               when LLM.Events.Text_End =>
                  Root.Set_Field ("type", "message_update");
                  Sub.Set_Field ("type", "text_end");
                  Root.Set_Field ("assistantMessageEvent", Sub);
                  return GNATCOLL.JSON.Write (Root);

               when LLM.Events.Thinking_End =>
                  Root.Set_Field ("type", "message_update");
                  Sub.Set_Field ("type", "thinking_end");
                  Root.Set_Field ("assistantMessageEvent", Sub);
                  return GNATCOLL.JSON.Write (Root);

               when others =>
                  return "";
            end case;
         end;
      elsif E in LLM.Events.Message_End_Event then
         declare
            Event      : constant LLM.Events.Message_End_Event :=
              LLM.Events.Message_End_Event (E);
            Root       : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Message    : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Usage      : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Cost_Obj   : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Cost_Value : constant Long_Float :=
              Long_Float (Event.Cost_Dmil) / 10_000.0;
         begin
            Root.Set_Field ("type", "message_end");
            Message.Set_Field ("role", "assistant");
            Message.Set_Field ("stopReason", Stop_Reason_Image (Event.Stop));
            if Length (Event.Err_Msg) > 0 then
               Message.Set_Field ("errorMessage", To_String (Event.Err_Msg));
            end if;
            Usage.Set_Field ("input", Integer (Event.Tok_Usage.Input));
            Usage.Set_Field ("output", Integer (Event.Tok_Usage.Output));
            Usage.Set_Field
              ("cacheRead", Integer (Event.Tok_Usage.Cache_Read));
            Usage.Set_Field
              ("cacheWrite", Integer (Event.Tok_Usage.Cache_Write));
            Cost_Obj.Set_Field ("total", GNATCOLL.JSON.Create (Cost_Value));
            Usage.Set_Field ("cost", Cost_Obj);
            Message.Set_Field ("usage", Usage);
            Root.Set_Field ("message", Message);
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Tool_Execution_Start_Event then
         declare
            Event : constant LLM.Events.Tool_Execution_Start_Event :=
              LLM.Events.Tool_Execution_Start_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Root.Set_Field ("type", "tool_execution_start");
            Root.Set_Field ("toolName", To_String (Event.Tool_Name));
            Root.Set_Field ("toolCallId", To_String (Event.Tool_Call_Id));
            Root.Set_Field ("args", Args_Object (To_String (Event.Args_Json)));
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Tool_Execution_End_Event then
         declare
            Event : constant LLM.Events.Tool_Execution_End_Event :=
              LLM.Events.Tool_Execution_End_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Root.Set_Field ("type", "tool_execution_end");
            Root.Set_Field ("toolCallId", To_String (Event.Tool_Call_Id));
            Root.Set_Field ("isError", Event.Is_Error);
            Root.Set_Field ("result", To_String (Event.Result_Text));
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Model_Select_Event then
         declare
            Event : constant LLM.Events.Model_Select_Event :=
              LLM.Events.Model_Select_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Model : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Root.Set_Field ("type", "model_select");
            Model.Set_Field ("provider", To_String (Event.Provider));
            Model.Set_Field ("id", To_String (Event.Model_Id));
            Model.Set_Field
              ("contextWindow", Integer (Event.Context_Window));
            Root.Set_Field ("model", Model);
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Session_Info_Event then
         declare
            Event : constant LLM.Events.Session_Info_Event :=
              LLM.Events.Session_Info_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Data  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Root.Set_Field ("type", "response");
            Root.Set_Field ("command", "get_state");
            Root.Set_Field ("success", True);
            Data.Set_Field ("sessionId", To_String (Event.Session_Id));
            Data.Set_Field
              ("thinkingLevel", To_String (Event.Thinking_Level));
            Data.Set_Field ("model", GNATCOLL.JSON.Create_Object);
            Root.Set_Field ("data", Data);
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Auto_Retry_Start_Event then
         declare
            Event : constant LLM.Events.Auto_Retry_Start_Event :=
              LLM.Events.Auto_Retry_Start_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Root.Set_Field ("type", "auto_retry_start");
            Root.Set_Field ("attempt", Integer (Event.Attempt));
            Root.Set_Field ("maxAttempts", Integer (Event.Max_Attempts));
            Root.Set_Field ("delayMs", Integer (Event.Delay_Ms));
            Root.Set_Field ("errorMessage", To_String (Event.Error_Msg));
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Auto_Retry_End_Event then
         declare
            Event : constant LLM.Events.Auto_Retry_End_Event :=
              LLM.Events.Auto_Retry_End_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Root.Set_Field ("type", "auto_retry_end");
            Root.Set_Field ("success", Event.Success);
            Root.Set_Field ("attempt", Integer (Event.Attempt));
            Root.Set_Field ("finalError", To_String (Event.Final_Error));
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Session_Stats_Event then
         declare
            Event : constant LLM.Events.Session_Stats_Event :=
              LLM.Events.Session_Stats_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Data  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Tokens : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Cost_Value : constant Long_Float :=
              Long_Float (Event.Cost_Dmil) / 10_000.0;
            Total_Value : constant Natural :=
              (if Event.Total > 0
               then Event.Total
               else Event.Input
                 + Event.Output
                 + Event.Cache_Read
                 + Event.Cache_Write);
         begin
            Root.Set_Field ("type", "response");
            Root.Set_Field ("command", "get_session_stats");
            Root.Set_Field ("success", True);
            Tokens.Set_Field ("input", Integer (Event.Input));
            Tokens.Set_Field ("output", Integer (Event.Output));
            Tokens.Set_Field ("cacheRead", Integer (Event.Cache_Read));
            Tokens.Set_Field ("cacheWrite", Integer (Event.Cache_Write));
            Tokens.Set_Field ("total", Integer (Total_Value));
            Data.Set_Field ("tokens", Tokens);
            Data.Set_Field
              ("cost", GNATCOLL.JSON.Create (Cost_Value));
            Root.Set_Field ("data", Data);
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Auto_Compaction_Start_Event then
         declare
            Event : constant LLM.Events.Auto_Compaction_Start_Event :=
              LLM.Events.Auto_Compaction_Start_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Root.Set_Field ("type", "auto_compaction_start");
            Root.Set_Field ("reason", To_String (Event.Reason));
            return GNATCOLL.JSON.Write (Root);
         end;
      elsif E in LLM.Events.Auto_Compaction_End_Event then
         declare
            Event : constant LLM.Events.Auto_Compaction_End_Event :=
              LLM.Events.Auto_Compaction_End_Event (E);
            Root  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Root.Set_Field ("type", "auto_compaction_end");
            Root.Set_Field ("summary", To_String (Event.Summary));
            Root.Set_Field ("aborted", Event.Aborted);
            Root.Set_Field ("willRetry", Event.Will_Retry);
            Root.Set_Field ("errorMessage", To_String (Event.Err_Msg));
            return GNATCOLL.JSON.Write (Root);
         end;
      else
         return "";
      end if;
   end To_Pi_Json;

end LLM.Agent.Pi_Adapter;
