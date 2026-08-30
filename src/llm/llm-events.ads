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
      Error_Msg   : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   end record;

   --  Error_Msg carries the complete diagnostic when a run terminates
   --  exceptionally; it is kept outside Ada exception-message storage.
   --  The value is empty for successful and aborted runs without an error.

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
      Signature     : Ada.Strings.Unbounded.Unbounded_String;
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
      Media_Type   : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Is_Error     : Boolean := False;
      Is_Cancelled : Boolean := False;
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
      Session_Id       : Ada.Strings.Unbounded.Unbounded_String;
      Thinking_Level   : Ada.Strings.Unbounded.Unbounded_String;
      Sandbox_Profile  : Ada.Strings.Unbounded.Unbounded_String;
      Model            : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Source_Directory : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Session_Start    : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
   end record;
   type Session_Stats_Event is new Agent_Event with record
      Cost_Dmil   : Natural := 0;
      Input       : Natural := 0;
      Output      : Natural := 0;
      Cache_Read  : Natural := 0;
      Cache_Write : Natural := 0;
      Total       : Natural := 0;
   end record;

   --  Emitted by Run_Prompt when a pending pause fires at a turn boundary.
   --  The loop is now blocked waiting for Resume to be called.
   type Agent_Paused_Event is new Agent_Event with null record;

   --  Emitted by Run_Prompt immediately after the loop unblocks following
   --  a Resume call.
   type Agent_Resumed_Event is new Agent_Event with null record;

end LLM.Events;
