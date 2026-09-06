--  Coyote_App.Frontend.RPC body.
--
--  This first adapter publishes frontend-level events over the tested local
--  transport.  The runner remains short-lived; command execution is added by
--  the coordinator/control-task slice.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;

package body Coyote_App.Frontend.RPC is

   use Ada.Strings.Unbounded;
   use GNATCOLL.JSON;
   use Coyote_App.Agent_RPC;
   use Coyote_App.Agent_RPC.Transport;

   procedure Emit
     (F     : in out Instance;
      Name  : Event_Kind;
      Data  : JSON_Value)
   is
      Value : constant Frame :=
        Make_Event
          (Agent_Id     => To_String (F.Agent_Id),
           Sequence     => F.Next_Sequence,
           Event_Name   => Name,
           Payload_Json => Write (Data));
   begin
      Send_Frame (F.Channel, Value);
      F.Next_Sequence := F.Next_Sequence + 1;
   end Emit;

   function Object return JSON_Value is
   begin
      return Create_Object;
   end Object;

   procedure Create
     (F               : in out Instance;
      Endpoint        : String;
      Agent_Id        : String;
      Parent_Agent_Id : String := "";
      Label           : String := "subagent")
   is
   begin
      Connect (F.Channel, Endpoint);
      F.Agent_Id := To_Unbounded_String (Agent_Id);
      F.Next_Sequence := 1;
      F.Is_Connected := True;
      F.Is_Terminated := False;
      F.Terminal_State := Completed;
      F.Pending_Prompt := Null_Unbounded_String;
      F.Pending_Steer := False;
      F.Control_Closed := False;
      F.Shutdown_Requested := False;
      Send_Frame
        (F.Channel,
         Make_Handshake
           (Agent_Id        => Agent_Id,
            Parent_Agent_Id => Parent_Agent_Id,
            Label           => Label));
   end Create;

   overriding procedure Set_Status
     (F : in out Instance; Text : String)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Emit (F, Status, Data);
   end Set_Status;

   overriding procedure Set_Mode
     (F : in out Instance; Mode : Coyote_App.Frontend.Run_Mode)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field
        ("mode", (case Mode is
                    when Coyote_App.Frontend.Idle    => "idle",
                    when Coyote_App.Frontend.Running => "running",
                    when Coyote_App.Frontend.Armed  => "armed",
                    when Coyote_App.Frontend.Paused  => "paused"));
      Emit (F, Coyote_App.Agent_RPC.Mode, Data);
   end Set_Mode;

   overriding procedure Begin_Request
     (F : in out Instance;
      Text : String;
      Kind : Coyote_App.Frontend.Request_Kind :=
        Coyote_App.Frontend.Prompt)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Data.Set_Field
        ("kind", (if Kind = Coyote_App.Frontend.Steer
                  then "steer" else "prompt"));
      Emit (F, Request_Start, Data);
   end Begin_Request;

   overriding procedure Append_Text
     (F : in out Instance; Text : String)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Emit (F, Text_Delta, Data);
   end Append_Text;

   overriding procedure End_Text_Block (F : in out Instance) is
      Data : constant JSON_Value := Object;
   begin
      Emit (F, Text_End, Data);
   end End_Text_Block;

   overriding procedure Begin_Thinking (F : in out Instance) is
      Data : constant JSON_Value := Object;
   begin
      Emit (F, Thinking_Start, Data);
   end Begin_Thinking;

   overriding procedure Append_Thinking
     (F : in out Instance; Text : String)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Emit (F, Thinking_Delta, Data);
   end Append_Thinking;

   overriding procedure End_Thinking (F : in out Instance) is
      Data : constant JSON_Value := Object;
   begin
      Emit (F, Thinking_End, Data);
   end End_Thinking;

   overriding procedure Begin_Tool
     (F               : in out Instance;
      Name            : String;
      Args_Json       : String;
      Session_Id      : String;
      Tool_Id         : String;
      Model           : String := "";
      Source_Directory : String := "";
      Session_Start   : String := "";
      Turn_Index      : Positive := 1;
      Call_In_Turn    : Positive := 1;
      Initial_Status  : Coyote_App.Frontend.Tool_Status :=
        Coyote_App.Frontend.Running)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("name", Name);
      declare
         Parsed : constant Read_Result := Read (Args_Json);
      begin
         if not Parsed.Success
           or else Parsed.Value.Kind /= JSON_Object_Type
         then
            Data.Set_Field ("args", Args_Json);
         else
            Data.Set_Field ("args", Parsed.Value);
         end if;
      end;
      Data.Set_Field ("sessionId", Session_Id);
      Data.Set_Field ("toolId", Tool_Id);
      Data.Set_Field ("model", Model);
      Data.Set_Field ("sourceDirectory", Source_Directory);
      Data.Set_Field ("sessionStart", Session_Start);
      Data.Set_Field ("turn", Integer (Turn_Index));
      Data.Set_Field ("call", Integer (Call_In_Turn));
      Data.Set_Field
        ("status", (case Initial_Status is
                       when Coyote_App.Frontend.Queued => "queued",
                       when Coyote_App.Frontend.Running => "running",
                       when Coyote_App.Frontend.Success => "success",
                       when Coyote_App.Frontend.Error => "error",
                       when Coyote_App.Frontend.Timed_Out => "timed_out",
                       when Coyote_App.Frontend.Cancelled => "cancelled"));
      Emit (F, Tool_Start, Data);
   end Begin_Tool;

   overriding procedure Set_Tool_Status
     (F       : in out Instance;
      Tool_Id : String;
      Status  : Coyote_App.Frontend.Tool_Status)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("toolId", Tool_Id);
      Data.Set_Field
        ("status", (case Status is
                       when Coyote_App.Frontend.Queued => "queued",
                       when Coyote_App.Frontend.Running => "running",
                       when Coyote_App.Frontend.Success => "success",
                       when Coyote_App.Frontend.Error => "error",
                       when Coyote_App.Frontend.Timed_Out => "timed_out",
                       when Coyote_App.Frontend.Cancelled => "cancelled"));
      Emit (F, Coyote_App.Agent_RPC.Tool_Status, Data);
   end Set_Tool_Status;

   overriding procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : String;
      Status      : Coyote_App.Frontend.Tool_End_Status;
      Result_Text : String := "";
      Media_Type  : String := "")
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("toolId", Tool_Id);
      Data.Set_Field ("result", Result_Text);
      Data.Set_Field ("mediaType", Media_Type);
      Data.Set_Field
        ("status", (case Status is
                      when Coyote_App.Frontend.Success => "success",
                      when Coyote_App.Frontend.Error => "error",
                      when Coyote_App.Frontend.Timed_Out => "timed_out",
                      when Coyote_App.Frontend.Cancelled => "cancelled"));
      Emit (F, Tool_End, Data);
   end End_Tool;

   overriding procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    : String;
      Kind    : Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary : String := "")
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Data.Set_Field ("summary", Summary);
      Data.Set_Field
        ("kind", (if Kind = Coyote_App.Frontend.Step_Footer
                  then "step" else "final"));
      Emit (F, Footer, Data);
   end Append_Turn_Footer;

   overriding procedure Complete_Request
     (F : in out Instance; Status : Coyote_App.Frontend.Completion_Status)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field
        ("status", (case Status is
                      when Coyote_App.Frontend.Completed => "completed",
                      when Coyote_App.Frontend.Aborted => "aborted",
                      when Coyote_App.Frontend.Failed => "failed"));
      F.Terminal_State :=
        (case Status is
            when Coyote_App.Frontend.Completed => Completed,
            when Coyote_App.Frontend.Aborted => Aborted,
            when Coyote_App.Frontend.Failed => Failed);
      Emit (F, Request_End, Data);
   end Complete_Request;

   overriding procedure Append_Fork_Action
     (F : in out Instance; UUID : String; Turn_N : Positive;
      Step_N : Natural := 0)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("uuid", UUID);
      Data.Set_Field ("turn", Integer (Turn_N));
      Data.Set_Field ("step", Integer (Step_N));
      Emit (F, Fork_Action, Data);
   end Append_Fork_Action;

   overriding procedure Append_Notice
     (F : in out Instance;
      Kind : Coyote_App.Frontend.Notice_Kind;
      Text : String)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Data.Set_Field
        ("severity", (case Kind is
                        when Coyote_App.Frontend.Info => "info",
                        when Coyote_App.Frontend.Warning => "warning",
                        when Coyote_App.Frontend.Error => "error"));
      Emit (F, Notice, Data);
   end Append_Notice;

   overriding procedure Show_Detail
     (F : in out Instance; Title : String; Content : String)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("title", Title);
      Data.Set_Field ("content", Content);
      Emit (F, Session_Info, Data);
   end Show_Detail;

   overriding function Has_Control_Channel (F : Instance) return Boolean is
   begin
      return F.Is_Connected and then not F.Control_Closed;
   end Has_Control_Channel;

   overriding function Read_Control
     (F       : in out Instance;
      Command : out Coyote_App.Frontend.Control_Command) return Boolean
   is
      Value  : Frame;
      Status : Receive_Status;
      Error  : Unbounded_String;
      Ready  : Boolean;
   begin
      Command.Kind := Coyote_App.Frontend.Control_Stop;
      if not Has_Control_Channel (F) then
         return False;
      end if;
      if not Receive_Frame
        (F.Channel, Value, Status, Error, Timeout => 0.0, Ready => Ready)
        or else not Ready
      then
         if Status = Peer_Closed then
            F.Control_Closed := True;
         end if;
         return False;
      end if;
      if Value.Kind /= Coyote_App.Agent_RPC.Command then
         return False;
      end if;
      case Value.Command_Name is
         when Prompt | Steer =>
            declare
               Parsed : constant Read_Result :=
                 Read (To_String (Value.Payload_Json));
            begin
               if Parsed.Success
                 and then Parsed.Value.Has_Field ("text")
                 and then Parsed.Value.Get ("text").Kind = JSON_String_Type
               then
                  declare
                     Prompt_Text : constant String :=
                       String'(Parsed.Value.Get ("text").Get);
                  begin
                     F.Pending_Prompt := To_Unbounded_String (Prompt_Text);
                     F.Pending_Steer := Value.Command_Name = Steer;
                  end;
               end if;
            end;
            return False;
         when Stop =>
            Command.Kind := Coyote_App.Frontend.Control_Stop;
         when Pause =>
            Command.Kind := Coyote_App.Frontend.Control_Pause;
         when Resume =>
            Command.Kind := Coyote_App.Frontend.Control_Resume;
         when Shutdown =>
            Command.Kind := Coyote_App.Frontend.Control_Shutdown;
            F.Shutdown_Requested := True;
      end case;
      return True;
   end Read_Control;

   overriding function Read_Prompt (F : in out Instance) return String is
      Value  : Frame;
      Status : Receive_Status;
      Error  : Unbounded_String;
   begin
      if F.Shutdown_Requested then
         return "";
      end if;
      if Length (F.Pending_Prompt) > 0 then
         declare
            Prompt : constant String := To_String (F.Pending_Prompt);
         begin
            F.Pending_Prompt := Null_Unbounded_String;
            F.Pending_Steer := False;
            return Prompt;
         end;
      end if;
      loop
         if not Receive_Frame (F.Channel, Value, Status, Error) then
            return "";
         end if;
         if Value.Kind = Command
           and then (Value.Command_Name = Prompt
                     or else Value.Command_Name = Steer)
         then
            declare
               Parsed : constant Read_Result :=
                 Read (To_String (Value.Payload_Json));
            begin
               if Parsed.Success
                 and then Parsed.Value.Has_Field ("text")
                 and then Parsed.Value.Get ("text").Kind = JSON_String_Type
               then
                  return Parsed.Value.Get ("text").Get;
               end if;
            end;
         end if;
      end loop;
   end Read_Prompt;

   overriding procedure Shutdown (F : in out Instance) is
   begin
      if F.Is_Connected and then not F.Is_Terminated then
         Send_Frame
           (F.Channel,
            Make_Terminal
              (Agent_Id => To_String (F.Agent_Id),
               Status   => F.Terminal_State,
               Last_Sequence => F.Next_Sequence - 1));
         F.Is_Terminated := True;
      end if;
      Close (F.Channel);
      F.Is_Connected := False;
   end Shutdown;

end Coyote_App.Frontend.RPC;
