--  Coyote_App.Agent_RPC — versioned virtual-agent RPC frames.
--
--  Defines the transport-independent wire contract used between a coordinator
--  and a short-lived headless subagent.  This unit performs no I/O.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package Coyote_App.Agent_RPC is

   Current_Version : constant Positive := 1;
   Protocol_Name   : constant String := "coyote-agent-rpc";

   type Frame_Kind is (Handshake, Event, Command, Terminal);

   type Event_Kind is
     (Request_Start,
      Request_End,
      Agent_Start,
      Thinking_Start,
      Thinking_Delta,
      Thinking_End,
      Text_Delta,
      Text_End,
      Tool_Start,
      Tool_Status,
      Tool_End,
      Notice,
      Status,
      Mode,
      Footer,
      Fork_Action,
      Statistics,
      Session_Info);

   type Command_Kind is
     (Prompt,
      Steer,
      Stop,
      Pause,
      Resume,
      Shutdown);

   type Terminal_Status is
     (Completed,
      Aborted,
      Failed,
      Disconnected);

   type Frame (Kind : Frame_Kind := Handshake) is record
      Version        : Positive := Current_Version;
      Agent_Id       : Ada.Strings.Unbounded.Unbounded_String;
      Payload_Json   : Ada.Strings.Unbounded.Unbounded_String;
      case Kind is
         when Handshake =>
            Parent_Agent_Id : Ada.Strings.Unbounded.Unbounded_String;
            Session_Id      : Ada.Strings.Unbounded.Unbounded_String;
            Label           : Ada.Strings.Unbounded.Unbounded_String;
         when Event =>
            Sequence   : Natural := 0;
            Event_Name : Event_Kind := Agent_Start;
         when Command =>
            Request_Id   : Ada.Strings.Unbounded.Unbounded_String;
            Command_Name : Command_Kind := Prompt;
         when Terminal =>
            Status        : Terminal_Status := Completed;
            Error_Text    : Ada.Strings.Unbounded.Unbounded_String;
            Last_Sequence : Natural := 0;
      end case;
   end record;

   function Make_Handshake
     (Agent_Id        : String;
      Parent_Agent_Id : String := "";
      Session_Id      : String := "";
      Label           : String := "subagent") return Frame;

   function Make_Event
     (Agent_Id     : String;
      Sequence     : Natural;
      Event_Name   : Event_Kind;
      Payload_Json : String := "{}") return Frame;

   function Make_Command
     (Agent_Id      : String;
      Request_Id    : String;
      Command_Name  : Command_Kind;
      Payload_Json  : String := "{}") return Frame;

   function Make_Terminal
     (Agent_Id      : String;
      Status        : Terminal_Status;
      Error_Text    : String := "";
      Last_Sequence : Natural := 0) return Frame;

   procedure Validate (Value : Frame);
   function Encode (Value : Frame) return String;
   function Decode (Text : String) return Frame;

   type Decode_Status is
     (Valid,
      Malformed_JSON,
      Unsupported_Version,
      Invalid_Frame);

   function Try_Decode
     (Text   : String;
      Value  : out Frame;
      Status : out Decode_Status;
      Error  : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;

   RPC_Error : exception;

end Coyote_App.Agent_RPC;
