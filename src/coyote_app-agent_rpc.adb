--  Coyote_App.Agent_RPC — versioned virtual-agent RPC frames.
--
--  Frames are compact JSON objects.  The codec owns validation and wire-name
--  mapping; socket framing, ordering, and process lifetime belong elsewhere.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with GNATCOLL.JSON;

package body Coyote_App.Agent_RPC is

   use Ada.Strings.Unbounded;
   use GNATCOLL.JSON;

   Empty_Frame : constant Frame :=
     (Kind          => Handshake,
      Version       => Current_Version,
      Agent_Id      => Null_Unbounded_String,
      Payload_Json  => Null_Unbounded_String,
      Parent_Agent_Id => Null_Unbounded_String,
      Session_Id    => Null_Unbounded_String,
      Label         => Null_Unbounded_String);

   function String_Value
     (Value : JSON_Value;
      Name  : String;
      Required : Boolean := True) return String
   is
      Field : JSON_Value;
   begin
      if Value.Kind /= JSON_Object_Type
        or else not Value.Has_Field (Name)
      then
         if Required then
            raise RPC_Error with "missing RPC field: " & Name;
         else
            return "";
         end if;
      end if;
      Field := Value.Get (Name);
      if Field.Kind /= JSON_String_Type then
         raise RPC_Error with "RPC field is not a string: " & Name;
      end if;
      return Field.Get;
   end String_Value;

   function Natural_Value
     (Value : JSON_Value;
      Name  : String) return Natural
   is
      Field : JSON_Value;
      Number : Long_Long_Integer;
   begin
      if Value.Kind /= JSON_Object_Type
        or else not Value.Has_Field (Name)
      then
         raise RPC_Error with "missing RPC field: " & Name;
      end if;
      Field := Value.Get (Name);
      if Field.Kind /= JSON_Int_Type then
         raise RPC_Error with "RPC field is not an integer: " & Name;
      end if;
      Number := Field.Get;
      if Number < 0
        or else Number > Long_Long_Integer (Natural'Last)
      then
         raise RPC_Error with "RPC field is outside Natural range: " & Name;
      end if;
      return Natural (Number);
   end Natural_Value;

   function Payload_Value (Text : String) return JSON_Value is
      Parsed : constant Read_Result := Read (Text);
   begin
      if not Parsed.Success then
         raise RPC_Error with
           "invalid RPC payload JSON: "
           & Format_Parsing_Error (Parsed.Error);
      end if;
      if Parsed.Value.Kind /= JSON_Object_Type then
         raise RPC_Error with "RPC payload must be a JSON object";
      end if;
      return Parsed.Value;
   end Payload_Value;

   function Frame_Type_Image (Value : Frame_Kind) return String is
   begin
      case Value is
         when Handshake => return "handshake";
         when Event     => return "event";
         when Command   => return "command";
         when Terminal  => return "terminal";
      end case;
   end Frame_Type_Image;

   function Event_Image (Value : Event_Kind) return String is
   begin
      case Value is
         when Request_Start  => return "requestStart";
         when Request_End    => return "requestEnd";
         when Agent_Start    => return "agentStart";
         when Thinking_Start => return "thinkingStart";
         when Thinking_Delta => return "thinkingDelta";
         when Thinking_End   => return "thinkingEnd";
         when Text_Delta     => return "textDelta";
         when Text_End       => return "textEnd";
         when Tool_Start     => return "toolStart";
         when Tool_Status    => return "toolStatus";
         when Tool_End       => return "toolEnd";
         when Notice         => return "notice";
         when Status         => return "status";
         when Mode           => return "mode";
         when Footer         => return "footer";
         when Fork_Action    => return "forkAction";
         when Statistics     => return "statistics";
         when Session_Info   => return "sessionInfo";
      end case;
   end Event_Image;

   function Command_Image (Value : Command_Kind) return String is
   begin
      case Value is
         when Prompt   => return "prompt";
         when Steer    => return "steer";
         when Stop     => return "stop";
         when Pause    => return "pause";
         when Resume   => return "resume";
         when Shutdown => return "shutdown";
      end case;
   end Command_Image;

   function Terminal_Image (Value : Terminal_Status) return String is
   begin
      case Value is
         when Completed    => return "completed";
         when Aborted      => return "aborted";
         when Failed       => return "failed";
         when Disconnected => return "disconnected";
      end case;
   end Terminal_Image;

   function Event_Value (Value : String) return Event_Kind is
   begin
      if Value = "requestStart" then return Request_Start;
      elsif Value = "requestEnd" then return Request_End;
      elsif Value = "agentStart" then return Agent_Start;
      elsif Value = "thinkingStart" then return Thinking_Start;
      elsif Value = "thinkingDelta" then return Thinking_Delta;
      elsif Value = "thinkingEnd" then return Thinking_End;
      elsif Value = "textDelta" then return Text_Delta;
      elsif Value = "textEnd" then return Text_End;
      elsif Value = "toolStart" then return Tool_Start;
      elsif Value = "toolStatus" then return Tool_Status;
      elsif Value = "toolEnd" then return Tool_End;
      elsif Value = "notice" then return Notice;
      elsif Value = "status" then return Status;
      elsif Value = "mode" then return Mode;
      elsif Value = "footer" then return Footer;
      elsif Value = "forkAction" then return Fork_Action;
      elsif Value = "statistics" then return Statistics;
      elsif Value = "sessionInfo" then return Session_Info;
      else
         raise RPC_Error with "unknown RPC event: " & Value;
      end if;
   end Event_Value;

   function Command_Value (Value : String) return Command_Kind is
   begin
      if Value = "prompt" then return Prompt;
      elsif Value = "steer" then return Steer;
      elsif Value = "stop" then return Stop;
      elsif Value = "pause" then return Pause;
      elsif Value = "resume" then return Resume;
      elsif Value = "shutdown" then return Shutdown;
      else
         raise RPC_Error with "unknown RPC command: " & Value;
      end if;
   end Command_Value;

   function Terminal_Value (Value : String) return Terminal_Status is
   begin
      if Value = "completed" then return Completed;
      elsif Value = "aborted" then return Aborted;
      elsif Value = "failed" then return Failed;
      elsif Value = "disconnected" then return Disconnected;
      else
         raise RPC_Error with "unknown RPC terminal status: " & Value;
      end if;
   end Terminal_Value;

   function Make_Handshake
     (Agent_Id        : String;
      Parent_Agent_Id : String := "";
      Session_Id      : String := "";
      Label           : String := "subagent") return Frame
   is
      Result : Frame (Handshake) :=
        (Kind             => Handshake,
         Version          => Current_Version,
         Agent_Id         => To_Unbounded_String (Agent_Id),
         Payload_Json     => Null_Unbounded_String,
         Parent_Agent_Id  => To_Unbounded_String (Parent_Agent_Id),
         Session_Id       => To_Unbounded_String (Session_Id),
         Label            => To_Unbounded_String (Label));
   begin
      Validate (Result);
      return Result;
   end Make_Handshake;

   function Make_Event
     (Agent_Id     : String;
      Sequence     : Natural;
      Event_Name   : Event_Kind;
      Payload_Json : String := "{}") return Frame
   is
      Result : Frame (Event) :=
        (Kind          => Event,
         Version       => Current_Version,
         Agent_Id      => To_Unbounded_String (Agent_Id),
         Payload_Json  => To_Unbounded_String (Payload_Json),
         Sequence      => Sequence,
         Event_Name    => Event_Name);
   begin
      Validate (Result);
      return Result;
   end Make_Event;

   function Make_Command
     (Agent_Id      : String;
      Request_Id    : String;
      Command_Name  : Command_Kind;
      Payload_Json  : String := "{}") return Frame
   is
      Result : Frame (Command) :=
        (Kind          => Command,
         Version       => Current_Version,
         Agent_Id      => To_Unbounded_String (Agent_Id),
         Payload_Json  => To_Unbounded_String (Payload_Json),
         Request_Id    => To_Unbounded_String (Request_Id),
         Command_Name  => Command_Name);
   begin
      Validate (Result);
      return Result;
   end Make_Command;

   function Make_Terminal
     (Agent_Id      : String;
      Status        : Terminal_Status;
      Error_Text    : String := "";
      Last_Sequence : Natural := 0) return Frame
   is
      Result : Frame (Terminal) :=
        (Kind          => Terminal,
         Version       => Current_Version,
         Agent_Id      => To_Unbounded_String (Agent_Id),
         Payload_Json  => Null_Unbounded_String,
         Status        => Status,
         Error_Text    => To_Unbounded_String (Error_Text),
         Last_Sequence => Last_Sequence);
   begin
      Validate (Result);
      return Result;
   end Make_Terminal;

   procedure Validate (Value : Frame) is
      Agent : constant String := To_String (Value.Agent_Id);
   begin
      if Value.Version /= Current_Version then
         raise RPC_Error with "unsupported RPC version";
      end if;
      if Agent'Length = 0 then
         raise RPC_Error with "RPC agent identity is empty";
      end if;

      case Value.Kind is
         when Handshake =>
            if Length (Value.Label) = 0 then
               raise RPC_Error with "RPC handshake label is empty";
            end if;
         when Event =>
            if Length (Value.Payload_Json) = 0 then
               raise RPC_Error with "RPC event payload is empty";
            end if;
            declare
               Payload : constant JSON_Value :=
                 Payload_Value (To_String (Value.Payload_Json));
            begin
               if (Value.Event_Name = Text_Delta
                   or else Value.Event_Name = Thinking_Delta)
                 and then (not Payload.Has_Field ("text")
                           or else Payload.Get ("text").Kind /= JSON_String_Type)
               then
                  raise RPC_Error with
                    "text RPC event payload requires string field: text";
               end if;
            end;
         when Command =>
            if Length (Value.Request_Id) = 0 then
               raise RPC_Error with "RPC command request identity is empty";
            end if;
            declare
               Payload : constant JSON_Value :=
                 Payload_Value (To_String (Value.Payload_Json));
            begin
               if (Value.Command_Name = Prompt
                   or else Value.Command_Name = Steer)
                 and then (not Payload.Has_Field ("text")
                           or else Payload.Get ("text").Kind /= JSON_String_Type)
               then
                  raise RPC_Error with
                    "prompt RPC command payload requires string field: text";
               end if;
            end;
         when Terminal =>
            null;
      end case;
   end Validate;

   function Encode (Value : Frame) return String is
      Root : constant JSON_Value := Create_Object;
   begin
      Validate (Value);
      Root.Set_Field ("protocol", Protocol_Name);
      Root.Set_Field ("version", Integer (Value.Version));
      Root.Set_Field ("type", Frame_Type_Image (Value.Kind));
      Root.Set_Field ("agentId", To_String (Value.Agent_Id));

      case Value.Kind is
         when Handshake =>
            Root.Set_Field
              ("parentAgentId", To_String (Value.Parent_Agent_Id));
            Root.Set_Field ("sessionId", To_String (Value.Session_Id));
            Root.Set_Field ("label", To_String (Value.Label));
         when Event =>
            Root.Set_Field ("sequence", Integer (Value.Sequence));
            Root.Set_Field ("event", Event_Image (Value.Event_Name));
            Root.Set_Field
              ("payload", Payload_Value (To_String (Value.Payload_Json)));
         when Command =>
            Root.Set_Field ("requestId", To_String (Value.Request_Id));
            Root.Set_Field ("command", Command_Image (Value.Command_Name));
            Root.Set_Field
              ("payload", Payload_Value (To_String (Value.Payload_Json)));
         when Terminal =>
            Root.Set_Field ("status", Terminal_Image (Value.Status));
            Root.Set_Field ("error", To_String (Value.Error_Text));
            Root.Set_Field
              ("lastSequence", Integer (Value.Last_Sequence));
      end case;
      return Write (Root);
   end Encode;

   function Decode (Text : String) return Frame is
      Parsed : constant Read_Result := Read (Text);
      Root   : JSON_Value;
      Version_Field : JSON_Value;
      Version_Value : Long_Long_Integer;
      Type_Name     : String := "";
      Agent         : String := "";
   begin
      if Text'Length = 0 then
         raise RPC_Error with "malformed JSON: empty RPC frame";
      end if;
      if not Parsed.Success then
         raise RPC_Error with
           "malformed JSON: " & Format_Parsing_Error (Parsed.Error);
      end if;
      Root := Parsed.Value;
      if Root.Kind /= JSON_Object_Type then
         raise RPC_Error with "RPC frame must be a JSON object";
      end if;
      if String_Value (Root, "protocol") /= Protocol_Name then
         raise RPC_Error with "invalid RPC protocol marker";
      end if;
      if not Root.Has_Field ("version") then
         raise RPC_Error with "missing RPC field: version";
      end if;
      Version_Field := Root.Get ("version");
      if Version_Field.Kind /= JSON_Int_Type then
         raise RPC_Error with "RPC field is not an integer: version";
      end if;
      Version_Value := Version_Field.Get;
      if Version_Value /= Long_Long_Integer (Current_Version) then
         raise RPC_Error with "unsupported RPC version";
      end if;

      declare
         Type_Name : constant String := String_Value (Root, "type");
         Agent     : constant String := String_Value (Root, "agentId");
      begin
         if Type_Name = "handshake" then
         declare
            Result : constant Frame :=
              (Kind             => Handshake,
               Version          => Current_Version,
               Agent_Id         => To_Unbounded_String (Agent),
               Payload_Json     => Null_Unbounded_String,
               Parent_Agent_Id  =>
                 To_Unbounded_String
                   (String_Value (Root, "parentAgentId", False)),
               Session_Id       =>
                 To_Unbounded_String (String_Value (Root, "sessionId", False)),
               Label            => To_Unbounded_String
                 (String_Value (Root, "label")));
         begin
            Validate (Result);
            return Result;
         end;
      elsif Type_Name = "event" then
         declare
            Payload : constant JSON_Value := Root.Get ("payload");
            Result : constant Frame :=
              (Kind          => Event,
               Version       => Current_Version,
               Agent_Id      => To_Unbounded_String (Agent),
               Payload_Json  => To_Unbounded_String (Write (Payload)),
               Sequence      => Natural_Value (Root, "sequence"),
               Event_Name    => Event_Value (String_Value (Root, "event")));
         begin
            Validate (Result);
            return Result;
         exception
            when Constraint_Error =>
               raise RPC_Error with "invalid event RPC frame";
         end;
      elsif Type_Name = "command" then
         declare
            Payload : constant JSON_Value := Root.Get ("payload");
            Result : constant Frame :=
              (Kind          => Command,
               Version       => Current_Version,
               Agent_Id      => To_Unbounded_String (Agent),
               Payload_Json  => To_Unbounded_String (Write (Payload)),
               Request_Id    => To_Unbounded_String
                 (String_Value (Root, "requestId")),
               Command_Name  =>
                 Command_Value (String_Value (Root, "command")));
         begin
            Validate (Result);
            return Result;
         exception
            when Constraint_Error =>
               raise RPC_Error with "invalid command RPC frame";
         end;
      elsif Type_Name = "terminal" then
         declare
            Result : constant Frame :=
              (Kind          => Terminal,
               Version       => Current_Version,
               Agent_Id      => To_Unbounded_String (Agent),
               Payload_Json  => Null_Unbounded_String,
               Status        =>
                 Terminal_Value (String_Value (Root, "status")),
               Error_Text    => To_Unbounded_String
                 (String_Value (Root, "error", False)),
               Last_Sequence => Natural_Value (Root, "lastSequence"));
         begin
            Validate (Result);
            return Result;
         exception
            when Constraint_Error =>
               raise RPC_Error with "invalid terminal RPC frame";
         end;
      else
         raise RPC_Error with "unknown RPC frame type: " & Type_Name;
      end if;
      end;
   exception
      when E : RPC_Error =>
         raise;
      when E : others =>
         raise RPC_Error with Ada.Exceptions.Exception_Message (E);
   end Decode;

   function Try_Decode
     (Text   : String;
      Value  : out Frame;
      Status : out Decode_Status;
      Error  : out Unbounded_String) return Boolean
   is
      Message : Unbounded_String;
   begin
      Value := Empty_Frame;
      Status := Invalid_Frame;
      Error := Null_Unbounded_String;
      begin
         Value := Decode (Text);
         Status := Valid;
         return True;
      exception
         when E : RPC_Error =>
            Message := To_Unbounded_String (Ada.Exceptions.Exception_Message (E));
            Error := Message;
            if Ada.Strings.Fixed.Index
              (To_String (Message), "malformed JSON") > 0
            then
               Status := Malformed_JSON;
            elsif Ada.Strings.Fixed.Index
              (To_String (Message), "unsupported RPC version") > 0
            then
               Status := Unsupported_Version;
            else
               Status := Invalid_Frame;
            end if;
            return False;
         when E : others =>
            Error := To_Unbounded_String (Ada.Exceptions.Exception_Message (E));
            Status := Invalid_Frame;
            return False;
      end;
   end Try_Decode;

end Coyote_App.Agent_RPC;
