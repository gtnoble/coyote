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
      Endpoint        :        String;
      Agent_Id        :        String;
      Parent_Agent_Id :        String := "";
      Label           :        String := "subagent");

   overriding procedure Set_Status (F : in out Instance; Text : String);
   overriding procedure Set_Context_Progress
     (F              : in out Instance;
      Context_Tokens :        Natural;
      Context_Window :        Natural);
   overriding procedure Set_Mode
     (F : in out Instance; Mode : Coyote_App.Frontend.Run_Mode);
   overriding procedure Begin_Request
     (F    : in out Instance;
      Text :        String;
      Kind : Coyote_App.Frontend.Request_Kind := Coyote_App.Frontend.Prompt);
   overriding procedure Append_Text (F : in out Instance; Text : String);
   overriding procedure End_Text_Block (F : in out Instance);
   overriding procedure Begin_Thinking (F : in out Instance);
   overriding procedure Append_Thinking (F : in out Instance; Text : String);
   overriding procedure End_Thinking (F : in out Instance);
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
        Coyote_App.Frontend.Running);
   overriding procedure Set_Tool_Status
     (F       : in out Instance;
      Tool_Id :        String;
      Status  :        Coyote_App.Frontend.Tool_Status);
   overriding procedure End_Tool
     (F           : in out Instance;
      Tool_Id     :        String;
      Status      :        Coyote_App.Frontend.Tool_End_Status;
      Result_Text :        String := "";
      Media_Type  :        String := "");
   overriding procedure Append_Turn_Footer
     (F       : in out Instance;
      Text    :        String;
      Kind    :        Coyote_App.Frontend.Footer_Kind :=
        Coyote_App.Frontend.Final_Footer;
      Summary :        String                          := "");
   overriding procedure Complete_Request
     (F : in out Instance; Status : Coyote_App.Frontend.Completion_Status);
   overriding procedure Append_Fork_Action
     (F      : in out Instance;
      UUID   :        String;
      Turn_N :        Positive;
      Step_N :        Natural := 0);
   overriding procedure Append_Notice
     (F    : in out Instance;
      Kind :        Coyote_App.Frontend.Notice_Kind;
      Text :        String);
   overriding procedure Show_Detail
     (F : in out Instance; Title : String; Content : String);
   overriding function Read_Prompt (F : in out Instance) return String;
   overriding function Has_Control_Channel (F : Instance) return Boolean;
   overriding function Read_Control
     (F       : in out Instance;
      Command :    out Coyote_App.Frontend.Control_Command)
      return Boolean;
   overriding procedure Shutdown (F : in out Instance);

private

   Max_Inbound_Depth : constant Positive := 64;

   protected type Channel_Lock is
      entry Acquire;
      procedure Release;
   private
      Busy : Boolean := False;
   end Channel_Lock;

   type Prompt_Array is
     array (Positive range 1 .. Max_Inbound_Depth)
     of Ada.Strings.Unbounded.Unbounded_String;

   protected type Prompt_Mailbox is
      procedure Put (Text : String);
      procedure Try_Get
        (Text : out Ada.Strings.Unbounded.Unbounded_String;
         Got  : out Boolean);
      entry Get (Text : out Ada.Strings.Unbounded.Unbounded_String);
      procedure Close;
      function Is_Open return Boolean;
   private
      Items  : Prompt_Array;
      Head   : Natural := 1;
      Count  : Natural := 0;
      Closed : Boolean := False;
   end Prompt_Mailbox;

   type Control_Array is
     array (Positive range 1 .. Max_Inbound_Depth)
     of Coyote_App.Frontend.Control_Command;

   protected type Control_Mailbox is
      procedure Put (Command : Coyote_App.Frontend.Control_Command);
      procedure Try_Get
        (Command : out Coyote_App.Frontend.Control_Command;
         Got     : out Boolean);
      procedure Close;
      function Is_Open return Boolean;
   private
      Items  : Control_Array;
      Head   : Natural := 1;
      Count  : Natural := 0;
      Closed : Boolean := False;
   end Control_Mailbox;

   type Reader_State;
   type Reader_State_Access is access all Reader_State;

   task type Reader_Task (State : not null Reader_State_Access) is
      entry Start;
      entry Stop;
   end Reader_Task;

   type Reader_Task_Access is access Reader_Task;

   type Reader_State is limited record
      Channel       : Coyote_App.Agent_RPC.Transport.Channel;
      Channel_Guard : Channel_Lock;
      Prompts       : Prompt_Mailbox;
      Controls      : Control_Mailbox;
   end record;

   type Instance is new Coyote_App.Frontend.Instance with record
      State          : Reader_State_Access := null;
      Reader         : Reader_Task_Access := null;
      Agent_Id       : Ada.Strings.Unbounded.Unbounded_String;
      Next_Sequence  : Natural                              := 1;
      Is_Terminated  : Boolean                              := False;
      Terminal_State : Coyote_App.Agent_RPC.Terminal_Status :=
        Coyote_App.Agent_RPC.Completed;
   end record;

end Coyote_App.Frontend.RPC;
