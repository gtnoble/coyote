--  Coyote_App.Frontend.RPC body.
--
--  The reader task owns inbound socket access.  Prompt and control frames are
--  separated before either consumer can observe them.
--
--  Project: coyote

with GNATCOLL.JSON;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;
with Coyote_App.Utils;

package body Coyote_App.Frontend.RPC is

   use Ada.Strings.Unbounded;
   use GNATCOLL.JSON;
   use Coyote_App.Agent_RPC;
   use Coyote_App.Agent_RPC.Transport;

   protected body Channel_Lock is
      entry Acquire when not Busy is
      begin
         Busy := True;
      end Acquire;

      procedure Release is
      begin
         Busy := False;
      end Release;
   end Channel_Lock;

   protected body Prompt_Mailbox is
      procedure Put (Text : String) is
         Tail : Natural;
      begin
         if not Closed and then Count < Max_Inbound_Depth then
            Tail := (Head - 1 + Count) mod Max_Inbound_Depth + 1;
            Items (Tail) := To_Unbounded_String (Text);
            Count := Count + 1;
         end if;
      end Put;

      procedure Try_Get
        (Text : out Unbounded_String;
         Got  : out Boolean)
      is
      begin
         Got := Count > 0;
         if Got then
            Text := Items (Head);
            Head := Head mod Max_Inbound_Depth + 1;
            Count := Count - 1;
         else
            Text := Null_Unbounded_String;
         end if;
      end Try_Get;

      entry Get (Text : out Unbounded_String)
        when Count > 0 or else Closed
      is
         Got : Boolean;
      begin
         Try_Get (Text, Got);
         if not Got then
            Text := Null_Unbounded_String;
         end if;
      end Get;

      procedure Close is
      begin
         Closed := True;
      end Close;

      function Is_Open return Boolean is (not Closed);
   end Prompt_Mailbox;

   protected body Control_Mailbox is
      procedure Put (Command : Coyote_App.Frontend.Control_Command) is
         Tail : Natural;
      begin
         if not Closed and then Count < Max_Inbound_Depth then
            Tail := (Head - 1 + Count) mod Max_Inbound_Depth + 1;
            Items (Tail) := Command;
            Count := Count + 1;
         end if;
      end Put;

      procedure Try_Get
        (Command : out Coyote_App.Frontend.Control_Command;
         Got     : out Boolean)
      is
      begin
         Got := Count > 0;
         if Got then
            Command := Items (Head);
            Head := Head mod Max_Inbound_Depth + 1;
            Count := Count - 1;
         else
            Command := (others => <>);
         end if;
      end Try_Get;

      procedure Close is
      begin
         Closed := True;
      end Close;

      function Is_Open return Boolean is (not Closed);
   end Control_Mailbox;

   function Parse_Control
     (Value : Frame; Command : out Coyote_App.Frontend.Control_Command)
     return Boolean
   is
      Parsed : Read_Result;
   begin
      Command := (others => <>);
      case Value.Command_Name is
         when Stop =>
            Command.Kind := Coyote_App.Frontend.Control_Stop;
         when Pause =>
            Command.Kind := Coyote_App.Frontend.Control_Pause;
         when Resume =>
            Command.Kind := Coyote_App.Frontend.Control_Resume;
         when Abort_Tool =>
            Parsed := Read (To_String (Value.Payload_Json));
            if not Parsed.Success
              or else not Parsed.Value.Has_Field ("toolId")
              or else Parsed.Value.Get ("toolId").Kind /= JSON_String_Type
            then
               return False;
            end if;
            Command.Kind := Coyote_App.Frontend.Control_Abort_Tool;
            Command.Tool_Id :=
              To_Unbounded_String
                (Coyote_App.Utils.Get_String (Parsed.Value, "toolId"));
            if Parsed.Value.Has_Field ("message")
              and then Parsed.Value.Get ("message").Kind = JSON_String_Type
            then
               Command.Abort_Message :=
                 To_Unbounded_String
                   (Coyote_App.Utils.Get_String (Parsed.Value, "message"));
            end if;
         when Set_Sandbox =>
            Parsed := Read (To_String (Value.Payload_Json));
            if not Parsed.Success
              or else not Parsed.Value.Has_Field ("profile")
              or else Parsed.Value.Get ("profile").Kind /= JSON_String_Type
            then
               return False;
            end if;
            Command.Kind := Coyote_App.Frontend.Control_Set_Sandbox;
            Command.Sandbox_Profile :=
              To_Unbounded_String
                (Coyote_App.Utils.Get_String (Parsed.Value, "profile"));
         when Shutdown =>
            Command.Kind := Coyote_App.Frontend.Control_Shutdown;
         when Prompt | Steer =>
            return False;
      end case;
      return True;
   end Parse_Control;

   procedure Parse_Prompt (Value : Frame; State : Reader_State_Access) is
      Parsed : constant Read_Result := Read (To_String (Value.Payload_Json));
   begin
      if Parsed.Success and then Parsed.Value.Has_Field ("text")
        and then Parsed.Value.Get ("text").Kind = JSON_String_Type
      then
         State.all.Prompts.Put
           (Coyote_App.Utils.Get_String (Parsed.Value, "text"));
      end if;
   end Parse_Prompt;

   task body Reader_Task is
      Value  : Frame;
      Status : Receive_Status;
      Error  : Unbounded_String;
      Ready  : Boolean;
      Stop_Now : Boolean := False;
   begin
      accept Start;
      Reader_Loop :
      loop
         select
            accept Stop do
               Stop_Now := True;
            end Stop;
         or
            delay 0.01;
            exit Reader_Loop when Stop_Now;
            State.all.Channel_Guard.Acquire;
            begin
               if not Receive_Frame
                   (State.all.Channel, Value, Status, Error,
                    Timeout => 0.01, Ready => Ready)
               then
                  State.all.Channel_Guard.Release;
                  exit Reader_Loop when Ready;
               end if;
               State.all.Channel_Guard.Release;
            exception
               when others =>
                  State.all.Channel_Guard.Release;
                  exit Reader_Loop;
            end;
            if Value.Kind = Command then
               if Value.Command_Name = Prompt
                 or else Value.Command_Name = Steer
               then
                  Parse_Prompt (Value, State);
               else
                  declare
                     Command : Coyote_App.Frontend.Control_Command;
                  begin
                     if Parse_Control (Value, Command) then
                        if Command.Kind =
                          Coyote_App.Frontend.Control_Shutdown
                        then
                           State.all.Prompts.Close;
                        end if;
                        State.all.Controls.Put (Command);
                     end if;
                  end;
               end if;
            end if;
         end select;
      end loop Reader_Loop;
      State.all.Prompts.Close;
      State.all.Controls.Close;
   exception
      when others =>
         State.all.Prompts.Close;
         State.all.Controls.Close;
   end Reader_Task;

   procedure Emit (F : in out Instance; Name : Event_Kind; Data : JSON_Value)
   is
      Value : constant Frame :=
        Make_Event
          (Agent_Id     => To_String (F.Agent_Id),
           Sequence     => F.Next_Sequence,
           Event_Name   => Name,
           Payload_Json => Write (Data));
   begin
      if F.State = null then
         return;
      end if;
      F.State.all.Channel_Guard.Acquire;
      begin
         Send_Frame (F.State.all.Channel, Value);
         F.Next_Sequence := F.Next_Sequence + 1;
         F.State.all.Channel_Guard.Release;
      exception
         when others =>
            F.State.all.Channel_Guard.Release;
            raise;
      end;
   end Emit;

   function Object return JSON_Value is
   begin
      return Create_Object;
   end Object;

   procedure Create
     (F               : in out Instance;
      Endpoint        :        String;
      Agent_Id        :        String;
      Parent_Agent_Id :        String := "";
      Label           :        String := "subagent")
   is
   begin
      F.State := new Reader_State;
      Connect (F.State.all.Channel, Endpoint);
      F.Agent_Id := To_Unbounded_String (Agent_Id);
      F.Next_Sequence := 1;
      F.Is_Terminated := False;
      F.Terminal_State := Completed;
      F.State.all.Channel_Guard.Acquire;
      begin
         Send_Frame
           (F.State.all.Channel,
            Make_Handshake
              (Agent_Id => Agent_Id,
               Parent_Agent_Id => Parent_Agent_Id,
               Label => Label));
         F.State.all.Channel_Guard.Release;
      exception
         when others =>
            F.State.all.Channel_Guard.Release;
            raise;
      end;
      F.Reader := new Reader_Task (F.State);
      F.Reader.Start;
   end Create;

   overriding procedure Set_Status (F : in out Instance; Text : String) is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Emit (F, Status, Data);
   end Set_Status;

   overriding procedure Set_Context_Progress
     (F              : in out Instance;
      Context_Tokens :        Natural;
      Context_Window :        Natural)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("contextTokens", Integer (Context_Tokens));
      Data.Set_Field ("contextWindow", Integer (Context_Window));
      Emit (F, Context_Update, Data);
   end Set_Context_Progress;

   overriding procedure Set_Mode
     (F : in out Instance; Mode : Coyote_App.Frontend.Run_Mode)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("mode",
         (case Mode is
            when Coyote_App.Frontend.Idle => "idle",
            when Coyote_App.Frontend.Running => "running",
            when Coyote_App.Frontend.Armed => "armed",
            when Coyote_App.Frontend.Paused => "paused"));
      Emit (F, Coyote_App.Agent_RPC.Mode, Data);
   end Set_Mode;

   overriding procedure Begin_Request
     (F    : in out Instance;
      Text :        String;
      Kind :    Coyote_App.Frontend.Request_Kind := Coyote_App.Frontend.Prompt)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Data.Set_Field
        ("kind",
         (if Kind = Coyote_App.Frontend.Steer then "steer" else "prompt"));
      Emit (F, Request_Start, Data);
   end Begin_Request;

   overriding procedure Append_Text (F : in out Instance; Text : String) is
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

   overriding procedure Append_Thinking (F : in out Instance; Text : String) is
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
     (F                : in out Instance;
      Name             :        String;
      Args_Json        :        String;
      Session_Id       :        String;
      Tool_Id          :        String;
      Model            :        String                          := "";
      Source_Directory :        String                          := "";
      Session_Start    :        String                          := "";
      Turn_Index       :        Positive                        := 1;
      Call_In_Turn     :        Positive                        := 1;
      Initial_Status   :        Coyote_App.Frontend.Tool_Status :=
        Coyote_App.Frontend.Running)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("name", Name);
      declare
         Parsed : constant Read_Result := Read (Args_Json);
      begin
         if not Parsed.Success or else Parsed.Value.Kind /= JSON_Object_Type
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
      Data.Set_Field ("status",
         (case Initial_Status is
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
      Tool_Id :        String;
      Status  :        Coyote_App.Frontend.Tool_Status)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("toolId", Tool_Id);
      Data.Set_Field ("status",
         (case Status is
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
      Tool_Id     :        String;
      Status      :        Coyote_App.Frontend.Tool_End_Status;
      Result_Text :        String := "";
      Media_Type  :        String := "")
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("toolId", Tool_Id);
      Data.Set_Field ("result", Result_Text);
      Data.Set_Field ("mediaType", Media_Type);
      Data.Set_Field ("status",
         (case Status is
            when Coyote_App.Frontend.Success => "success",
            when Coyote_App.Frontend.Error => "error",
            when Coyote_App.Frontend.Timed_Out => "timed_out",
            when Coyote_App.Frontend.Cancelled => "cancelled"));
      Emit (F, Tool_End, Data);
   end End_Tool;

   overriding procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    :        String;
      Kind    :        Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary :        String                          := "")
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Data.Set_Field ("summary", Summary);
      Data.Set_Field
        ("kind",
         (if Kind = Coyote_App.Frontend.Step_Footer then "step" else "final"));
      Emit (F, Footer, Data);
   end Append_Turn_Footer;

   overriding procedure Complete_Request
     (F : in out Instance; Status : Coyote_App.Frontend.Completion_Status)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("status",
         (case Status is
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
     (F      : in out Instance;
      UUID   :        String;
      Turn_N :        Positive;
      Step_N :        Natural := 0)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("uuid", UUID);
      Data.Set_Field ("turn", Integer (Turn_N));
      Data.Set_Field ("step", Integer (Step_N));
      Emit (F, Fork_Action, Data);
   end Append_Fork_Action;

   overriding procedure Append_Notice
     (F    : in out Instance;
      Kind :        Coyote_App.Frontend.Notice_Kind;
      Text :        String)
   is
      Data : constant JSON_Value := Object;
   begin
      Data.Set_Field ("text", Text);
      Data.Set_Field ("severity",
         (case Kind is
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
      return F.State /= null and then F.State.Controls.Is_Open;
   end Has_Control_Channel;

   overriding function Read_Control
     (F : in out Instance;
      Command : out Coyote_App.Frontend.Control_Command)
      return Boolean
   is
      Got : Boolean;
   begin
      Command := (others => <>);
      if F.State = null then
         return False;
      end if;
      F.State.Controls.Try_Get (Command, Got);
      return Got;
   end Read_Control;

   overriding function Read_Prompt (F : in out Instance) return String is
      Text : Unbounded_String;
   begin
      if F.State = null then
         return "";
      end if;
      F.State.Prompts.Get (Text);
      return To_String (Text);
   end Read_Prompt;

   overriding procedure Shutdown (F : in out Instance) is
   begin
      if F.Reader /= null then
         F.Reader.Stop;
      end if;
      if F.State /= null then
         F.State.all.Prompts.Close;
         F.State.all.Controls.Close;
         F.State.all.Channel_Guard.Acquire;
         begin
            if not F.Is_Terminated then
               Send_Frame
                 (F.State.all.Channel,
                  Make_Terminal
                    (Agent_Id => To_String (F.Agent_Id),
                     Status => F.Terminal_State,
                     Last_Sequence => F.Next_Sequence - 1));
               F.Is_Terminated := True;
            end if;
            Close (F.State.all.Channel);
            F.State.all.Channel_Guard.Release;
         exception
            when others =>
               Close (F.State.all.Channel);
               F.State.all.Channel_Guard.Release;
         end;
      end if;
   end Shutdown;

end Coyote_App.Frontend.RPC;
