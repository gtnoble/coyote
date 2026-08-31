--  Coyote_App.Frontend.RPC — headless coordinator-channel frontend.
--
--  Publishes abstract frontend operations as versioned Agent_RPC frames over a
--  local channel.  It owns no GTK resources and is intended for short-lived
--  coordinator-launched subagents.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with Coyote_App.Agent_RPC.Transport;
with Coyote_App.Frontend;

package Coyote_App.Frontend.RPC is

   type Instance is new Coyote_App.Frontend.Instance with private;

   procedure Create
     (F               : in out Instance;
      Endpoint        : String;
      Agent_Id        : String;
      Parent_Agent_Id : String := "";
      Label           : String := "subagent");

   overriding procedure Set_Status
     (F : in out Instance; Text : String);
   overriding procedure Set_Mode
     (F : in out Instance; Mode : Coyote_App.Frontend.Run_Mode);
   overriding procedure Begin_Request
     (F : in out Instance;
      Text : String;
      Kind : Coyote_App.Frontend.Request_Kind :=
        Coyote_App.Frontend.Prompt);
   overriding procedure Append_Text
     (F : in out Instance; Text : String);
   overriding procedure End_Text_Block (F : in out Instance);
   overriding procedure Begin_Thinking (F : in out Instance);
   overriding procedure Append_Thinking
     (F : in out Instance; Text : String);
   overriding procedure End_Thinking (F : in out Instance);
   overriding procedure Begin_Tool
     (F               : in out Instance;
      Name            : String;
      Args_Json       : String;
      Session_Id      : String;
      Tool_Id          : String;
      Model           : String := "";
      Source_Directory : String := "";
      Session_Start   : String := "";
      Turn_Index      : Positive := 1;
      Call_In_Turn    : Positive := 1);
   overriding procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : String;
      Status      : Coyote_App.Frontend.Tool_End_Status;
      Result_Text : String := "";
      Media_Type  : String := "");
   overriding procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    : String;
      Kind    : Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary : String := "");
   overriding procedure Complete_Request
     (F : in out Instance; Status : Coyote_App.Frontend.Completion_Status);
   overriding procedure Append_Fork_Action
     (F : in out Instance; UUID : String; Turn_N : Positive;
      Step_N : Natural := 0);
   overriding procedure Append_Notice
     (F : in out Instance;
      Kind : Coyote_App.Frontend.Notice_Kind;
      Text : String);
   overriding procedure Show_Detail
     (F : in out Instance; Title : String; Content : String);
   overriding function Read_Prompt (F : in out Instance) return String;
   overriding function Has_Control_Channel (F : Instance) return Boolean;
   overriding function Read_Control
     (F       : in out Instance;
      Command : out Coyote_App.Frontend.Control_Command) return Boolean;
   overriding procedure Shutdown (F : in out Instance);

private

   type Instance is new Coyote_App.Frontend.Instance with record
      Channel       : Coyote_App.Agent_RPC.Transport.Channel;
      Agent_Id      : Ada.Strings.Unbounded.Unbounded_String;
      Next_Sequence : Natural := 1;
      Is_Connected  : Boolean := False;
      Is_Terminated : Boolean := False;
      Terminal_State : Coyote_App.Agent_RPC.Terminal_Status :=
        Coyote_App.Agent_RPC.Completed;
      Pending_Prompt : Ada.Strings.Unbounded.Unbounded_String;
      Pending_Steer  : Boolean := False;
      Control_Closed : Boolean := False;
      Shutdown_Requested : Boolean := False;
   end record;

end Coyote_App.Frontend.RPC;
