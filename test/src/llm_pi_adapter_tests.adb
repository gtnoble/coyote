with AUnit.Assertions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Agent.Pi_Adapter;
with LLM.Events;
with LLM.Types;

package body LLM_Pi_Adapter_Tests is

   use AUnit.Assertions;

   procedure Test_Agent_Start_Json (T : in out Test) is
      pragma Unreferenced (T);

      Event : constant LLM.Events.Agent_Start_Event :=
        (LLM.Events.Agent_Event with null record);
   begin
      Assert
        (LLM.Agent.Pi_Adapter.To_Pi_Json (Event)
           = "{""type"":""agent_start""}",
         "Agent_Start_Event should map to pi agent_start JSON");
   end Test_Agent_Start_Json;

   procedure Test_Text_Delta_Json (T : in out Test) is
      pragma Unreferenced (T);

      Event  : constant LLM.Events.Message_Update_Event :=
        (LLM.Events.Agent_Event with
         Kind          => LLM.Events.Text_Delta,
         Delta_Text    => To_Unbounded_String ("hello"),
         Content_Index => 0,
         Tool_Call_Id  => Null_Unbounded_String,
         Tool_Name     => Null_Unbounded_String);
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (LLM.Agent.Pi_Adapter.To_Pi_Json (Event));
      Sub    : GNATCOLL.JSON.JSON_Value;
   begin
      Assert (Parsed.Success, "Text delta JSON should parse successfully");
      declare
         Root_Type : constant String := Parsed.Value.Get ("type").Get;
      begin
         Assert
           (Root_Type = "message_update",
            "Top-level event type should be message_update");
      end;
      Sub := Parsed.Value.Get ("assistantMessageEvent");
      declare
         Sub_Type  : constant String := Sub.Get ("type").Get;
         Sub_Delta : constant String := Sub.Get ("delta").Get;
      begin
         Assert
           (Sub_Type = "text_delta",
            "Nested event type should be text_delta");
         Assert
           (Sub_Delta = "hello",
            "Nested delta should preserve the streamed text");
      end;
   end Test_Text_Delta_Json;

   procedure Test_Message_End_Json_Cost (T : in out Test) is
      pragma Unreferenced (T);

      Event   : constant LLM.Events.Message_End_Event :=
        (LLM.Events.Agent_Event with
         Stop      => LLM.Types.Stop,
         Err_Msg   => Null_Unbounded_String,
         Tok_Usage =>
           (Input       => 12,
            Output      => 7,
            Cache_Read  => 3,
            Cache_Write => 1),
         Cost_Dmil => 45);
      Parsed  : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (LLM.Agent.Pi_Adapter.To_Pi_Json (Event));
      Message : GNATCOLL.JSON.JSON_Value;
      Usage   : GNATCOLL.JSON.JSON_Value;
      Cost    : GNATCOLL.JSON.JSON_Value;
   begin
      Assert (Parsed.Success, "Message end JSON should parse successfully");
      declare
         Root_Type : constant String := Parsed.Value.Get ("type").Get;
      begin
         Assert
           (Root_Type = "message_end",
            "Top-level event type should be message_end");
      end;

      Message := Parsed.Value.Get ("message");
      Usage := Message.Get ("usage");
      Cost := Usage.Get ("cost");

      declare
         Total_Cost : constant Long_Float :=
           GNATCOLL.JSON.Get_Long_Float (Cost.Get ("total"));
      begin
         Assert
           (abs (Total_Cost - 0.0045) < 1.0E-9,
            "message.usage.cost.total should round-trip Cost_Dmil");
      end;
   end Test_Message_End_Json_Cost;

   procedure Test_Tool_Execution_Start_Json (T : in out Test) is
      pragma Unreferenced (T);

      Event  : constant LLM.Events.Tool_Execution_Start_Event :=
        (LLM.Events.Agent_Event with
         Tool_Call_Id => To_Unbounded_String ("call-1"),
         Tool_Name    => To_Unbounded_String ("read"),
         Args_Json    => To_Unbounded_String
           ("{""path"":""demo.adb""}"));
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (LLM.Agent.Pi_Adapter.To_Pi_Json (Event));
      Args   : GNATCOLL.JSON.JSON_Value;
   begin
      Assert
        (Parsed.Success,
         "Tool execution start JSON should parse successfully");
      declare
         Root_Type    : constant String := Parsed.Value.Get ("type").Get;
         Tool_Name    : constant String := Parsed.Value.Get ("toolName").Get;
         Tool_Call_Id : constant String :=
           Parsed.Value.Get ("toolCallId").Get;
      begin
         Assert
           (Root_Type = "tool_execution_start",
            "Top-level event type should be tool_execution_start");
         Assert
           (Tool_Name = "read",
            "Tool name should be preserved");
         Assert
           (Tool_Call_Id = "call-1",
            "Tool call id should be preserved");
      end;
      Args := Parsed.Value.Get ("args");
      declare
         Path_Value : constant String := Args.Get ("path").Get;
      begin
         Assert
           (Path_Value = "demo.adb",
            "Args JSON should be parsed as an object");
      end;
   end Test_Tool_Execution_Start_Json;

end LLM_Pi_Adapter_Tests;
