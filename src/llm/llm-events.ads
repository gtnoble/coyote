--  LLM.Events — event hierarchy emitted by native provider adapters.
--
--  These tagged event types are emitted by native provider adapters and
--  consumed by the display layer (Coyote_App.Dispatch).
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with LLM.Types;

package LLM.Events is

   --  Root of all agent-to-UI events.
   type Agent_Event is abstract tagged null record;

   type Agent_Start_Event is new Agent_Event with null record;

   type Agent_End_Event is new Agent_Event with record
      Was_Aborted : Boolean := False;
   end record;

   type Message_Start_Event is new Agent_Event with null record;

   type Message_End_Event is new Agent_Event with record
      Stop      : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Err_Msg   : Ada.Strings.Unbounded.Unbounded_String;
      Tok_Usage : LLM.Types.Usage;
      Cost_Dmil : Natural := 0;
   end record;

   type Message_Update_Kind is
     (Thinking_Start,
      Thinking_Delta,
      Thinking_End,
      Text_Start,
      Text_Delta,
      Text_End,
      Tool_Call_Start,
      Tool_Call_Delta,
      Tool_Call_End);

   type Message_Update_Event is new Agent_Event with record
      Kind          : Message_Update_Kind := Text_Delta;
      Delta_Text    : Ada.Strings.Unbounded.Unbounded_String;
      Content_Index : Natural := 0;
      Tool_Call_Id  : Ada.Strings.Unbounded.Unbounded_String;
      Tool_Name     : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Tool_Execution_Start_Event is new Agent_Event with record
      Tool_Call_Id : Ada.Strings.Unbounded.Unbounded_String;
      Tool_Name    : Ada.Strings.Unbounded.Unbounded_String;
      Args_Json    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Tool_Execution_End_Event is new Agent_Event with record
      Tool_Call_Id : Ada.Strings.Unbounded.Unbounded_String;
      Tool_Name    : Ada.Strings.Unbounded.Unbounded_String;
      Result_Text  : Ada.Strings.Unbounded.Unbounded_String;
      Is_Error     : Boolean := False;
   end record;

   type Model_Select_Event is new Agent_Event with record
      Provider       : Ada.Strings.Unbounded.Unbounded_String;
      Model_Id       : Ada.Strings.Unbounded.Unbounded_String;
      Context_Window : Natural := 0;
   end record;

   type Auto_Retry_Start_Event is new Agent_Event with record
      Attempt      : Positive := 1;
      Max_Attempts : Positive := 3;
      Delay_Ms     : Natural := 0;
      Error_Msg    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Auto_Retry_End_Event is new Agent_Event with record
      Success     : Boolean := True;
      Attempt     : Positive := 1;
      Final_Error : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Auto_Compaction_Start_Event is new Agent_Event with record
      Reason : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Auto_Compaction_End_Event is new Agent_Event with record
      Summary    : Ada.Strings.Unbounded.Unbounded_String;
      Aborted    : Boolean := False;
      Will_Retry : Boolean := False;
      Err_Msg    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Session_Info_Event is new Agent_Event with record
      Session_Id     : Ada.Strings.Unbounded.Unbounded_String;
      Thinking_Level : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Session_Stats_Event is new Agent_Event with record
      Cost_Dmil   : Natural := 0;
      Input       : Natural := 0;
      Output      : Natural := 0;
      Cache_Read  : Natural := 0;
      Cache_Write : Natural := 0;
      Total       : Natural := 0;
   end record;

end LLM.Events;
