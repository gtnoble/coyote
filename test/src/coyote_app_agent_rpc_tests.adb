with AUnit.Test_Caller;
--  Coyote_App_Agent_RPC_Tests — versioned RPC frame codec tests.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_App.Agent_RPC;

package body Coyote_App_Agent_RPC_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_RPC;

   procedure Expect_RPC_Error
     (Text : String;
      Message : String) is
      Ignored : Frame;
   begin
      Ignored := Decode (Text);
      Assert (False, Message);
   exception
      when RPC_Error =>
         null;
   end Expect_RPC_Error;

   procedure Test_Handshake_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant Frame :=
        Make_Handshake
          (Agent_Id        => "worker-7",
           Parent_Agent_Id => "root",
           Session_Id      => "session-7",
           Label           => "search worker");
      Output : constant Frame := Decode (Encode (Input));
   begin
      Assert (Output.Kind = Handshake, "handshake kind must round-trip");
      Assert (To_String (Output.Agent_Id) = "worker-7",
              "handshake agent identity must round-trip");
      Assert (To_String (Output.Parent_Agent_Id) = "root",
              "handshake parent identity must round-trip");
      Assert (To_String (Output.Session_Id) = "session-7",
              "handshake session identity must round-trip");
      Assert (To_String (Output.Label) = "search worker",
              "handshake label must round-trip");
   end Test_Handshake_Round_Trip;

   procedure Test_Event_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant Frame :=
        Make_Event
          (Agent_Id     => "worker-7",
           Sequence     => 12,
           Event_Name   => Text_Delta,
           Payload_Json => "{""text"":""fragment""}");
      Output : constant Frame := Decode (Encode (Input));
   begin
      Assert (Output.Kind = Event, "event kind must round-trip");
      Assert (Output.Sequence = 12, "event sequence must round-trip");
      Assert (Output.Event_Name = Text_Delta,
              "event name must round-trip");
      Assert (To_String (Output.Payload_Json) = "{""text"":""fragment""}",
              "event payload must round-trip");
   end Test_Event_Round_Trip;

   procedure Test_Command_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant Frame :=
        Make_Command
          (Agent_Id     => "worker-7",
           Request_Id   => "cmd-19",
           Command_Name => Steer,
           Payload_Json => "{""text"":""change direction""}");
      Output : constant Frame := Decode (Encode (Input));
   begin
      Assert (Output.Kind = Command, "command kind must round-trip");
      Assert (To_String (Output.Request_Id) = "cmd-19",
              "command request identity must round-trip");
      Assert (Output.Command_Name = Steer,
              "command name must round-trip");
      Assert (To_String (Output.Payload_Json) =
                "{""text"":""change direction""}",
              "command payload must round-trip");
   end Test_Command_Round_Trip;

   procedure Test_Stop_Command_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant Frame :=
        Make_Command
          (Agent_Id     => "worker-7",
           Request_Id   => "stop-19",
           Command_Name => Stop);
      Output : constant Frame := Decode (Encode (Input));
   begin
      Assert (Output.Kind = Command,
              "Stop command kind must round-trip");
      Assert (Output.Command_Name = Stop,
              "Stop command name must round-trip");
      Assert (To_String (Output.Request_Id) = "stop-19",
              "Stop command request identity must round-trip");
   end Test_Stop_Command_Round_Trip;

   procedure Test_Set_Sandbox_Command_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant Frame :=
        Make_Command
          (Agent_Id      => "worker-7",
           Request_Id    => "sandbox-19",
           Command_Name  => Set_Sandbox,
           Payload_Json  => "{""profile"":""project-write""}");
      Output : constant Frame := Decode (Encode (Input));
   begin
      Assert (Output.Command_Name = Set_Sandbox,
              "Set_Sandbox command name must round-trip");
      Assert
        (To_String (Output.Payload_Json) =
           "{""profile"":""project-write""}",
         "Set_Sandbox payload must round-trip");
   end Test_Set_Sandbox_Command_Round_Trip;

   procedure Test_Terminal_Round_Trip (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant Frame :=
        Make_Terminal
          (Agent_Id      => "worker-7",
           Status        => Failed,
           Error_Text    => "provider failed",
           Last_Sequence => 27);
      Output : constant Frame := Decode (Encode (Input));
   begin
      Assert (Output.Kind = Terminal, "terminal kind must round-trip");
      Assert (Output.Status = Failed, "terminal status must round-trip");
      Assert (To_String (Output.Error_Text) = "provider failed",
              "terminal error must round-trip");
      Assert (Output.Last_Sequence = 27,
              "terminal sequence must round-trip");
   end Test_Terminal_Round_Trip;

   procedure Test_JSON_Escaping (T : in out Test) is
      pragma Unreferenced (T);
      Input : constant Frame :=
        Make_Command
          (Agent_Id     => "worker-7",
           Request_Id   => "cmd-escape",
           Command_Name => Prompt,
           Payload_Json => "{""text"":""line\n""}");
      Output : constant Frame := Decode (Encode (Input));
   begin
      Assert (To_String (Output.Payload_Json) =
                "{""text"":""line\n""}",
              "escaped payload text must round-trip");
   end Test_JSON_Escaping;

   procedure Test_Encode_Has_No_Trailing_Newline (T : in out Test) is
      pragma Unreferenced (T);
      Text : constant String :=
        Encode (Make_Handshake (Agent_Id => "worker-7"));
   begin
      Assert (Text'Length > 0, "encoded frame must not be empty");
      Assert (Text (Text'Last) /= ASCII.LF,
              "encoded frame must not contain transport newline");
   end Test_Encode_Has_No_Trailing_Newline;

   procedure Test_Malformed_JSON (T : in out Test) is
      pragma Unreferenced (T);
      Value : Frame;
      Status : Decode_Status;
      Error : Unbounded_String;
   begin
      Assert (not Try_Decode ("{bad", Value, Status, Error),
              "malformed JSON must be rejected");
      Assert (Status = Malformed_JSON,
              "malformed JSON must have its own decode status");
   end Test_Malformed_JSON;

   procedure Test_Non_Object_Frame (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Expect_RPC_Error ("[]", "array RPC frame must be rejected");
   end Test_Non_Object_Frame;

   procedure Test_Wrong_Protocol (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Expect_RPC_Error
        ("{""protocol"":""other"",""version"":1,""type"":""handshake"",""agentId"":""worker"",""label"":""w""}",
         "wrong RPC protocol must be rejected");
   end Test_Wrong_Protocol;

   procedure Test_Unsupported_Version (T : in out Test) is
      pragma Unreferenced (T);
      Value : Frame;
      Status : Decode_Status;
      Error : Unbounded_String;
   begin
      Assert
        (not Try_Decode
           ("{""protocol"":""coyote-agent-rpc"",""version"":2,""type"":""handshake"",""agentId"":""worker"",""label"":""w""}",
            Value, Status, Error),
         "unsupported RPC version must be rejected");
      Assert (Status = Unsupported_Version,
              "unsupported version must have its own decode status");
   end Test_Unsupported_Version;

   procedure Test_Missing_Required_Field (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Expect_RPC_Error
        ("{""protocol"":""coyote-agent-rpc"",""version"":1,""type"":""handshake"",""label"":""w""}",
         "missing agent identity must be rejected");
   end Test_Missing_Required_Field;

   procedure Test_Invalid_Payload (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Expect_RPC_Error
        ("{""protocol"":""coyote-agent-rpc"",""version"":1,""type"":""event"",""agentId"":""worker"",""sequence"":1,""event"":""textDelta"",""payload"":[]}",
         "non-object event payload must be rejected");
   end Test_Invalid_Payload;

   package Agent_RPC_Caller is
     new AUnit.Test_Caller (Coyote_App_Agent_RPC_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC Stop command round-trips",
         Coyote_App_Agent_RPC_Tests
           .Test_Stop_Command_Round_Trip'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC Set_Sandbox command round-trips",
         Coyote_App_Agent_RPC_Tests
           .Test_Set_Sandbox_Command_Round_Trip'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC handshake round-trips",
         Coyote_App_Agent_RPC_Tests.Test_Handshake_Round_Trip'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC event round-trips",
         Coyote_App_Agent_RPC_Tests.Test_Event_Round_Trip'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC command round-trips",
         Coyote_App_Agent_RPC_Tests.Test_Command_Round_Trip'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC terminal round-trips",
         Coyote_App_Agent_RPC_Tests.Test_Terminal_Round_Trip'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC preserves JSON escaping",
         Coyote_App_Agent_RPC_Tests.Test_JSON_Escaping'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC encoding has no trailing newline",
         Coyote_App_Agent_RPC_Tests.Test_Encode_Has_No_Trailing_Newline'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC rejects malformed JSON",
         Coyote_App_Agent_RPC_Tests.Test_Malformed_JSON'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC rejects non-object frames",
         Coyote_App_Agent_RPC_Tests.Test_Non_Object_Frame'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC rejects wrong protocol markers",
         Coyote_App_Agent_RPC_Tests.Test_Wrong_Protocol'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC rejects unsupported versions",
         Coyote_App_Agent_RPC_Tests.Test_Unsupported_Version'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC rejects missing required fields",
         Coyote_App_Agent_RPC_Tests.Test_Missing_Required_Field'Access));
      Result.Add_Test (Agent_RPC_Caller.Create
        ("Agent RPC rejects invalid payloads",
         Coyote_App_Agent_RPC_Tests.Test_Invalid_Payload'Access));

      return Result;
   end Suite;

end Coyote_App_Agent_RPC_Tests;
