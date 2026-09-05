with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.SSE;

package body LLM_SSE_Tests is

   use AUnit.Assertions;

   Full_Event_Fixture : constant String :=
     "event: tool_call" & ASCII.LF
     & "data: {""name"":""read"","
     & ASCII.LF
     & "data: ""path"":""src/main.adb""}"
     & ASCII.LF
     & ASCII.LF;

   Anthropic_Fixture : constant String :=
     "event: message_start" & ASCII.LF
     & "data: {""type"":""message_start"",""message"":{""id"":""msg_1""}}"
     & ASCII.LF & ASCII.LF
     & "event: content_block_delta" & ASCII.LF
     & "data: {""type"":""content_block_delta"",""index"":0,"
     & """delta"":{""type"":""thinking_delta"",""thinking"":""plan""}}"
     & ASCII.LF & ASCII.LF;

   OpenAI_Fixture : constant String :=
     "data: {""choices"":[{""delta"":{""content"":""Hello""}}]}"
     & ASCII.LF & ASCII.LF
     & "data: {""choices"":[{""delta"":{""content"":"" world""}}]}"
     & ASCII.LF & ASCII.LF
     & "data: [DONE]" & ASCII.LF & ASCII.LF;

   Ping_Fixture : constant String :=
     "event: ping" & ASCII.LF
     & "data: {""type"":""ping""}" & ASCII.LF
     & ASCII.LF
     & "data: {""choices"":[{""delta"":{""content"":""ok""}}]}"
     & ASCII.LF & ASCII.LF;

   CRLF_Ping_Fixture : constant String :=
     "data: hello" & ASCII.CR & ASCII.LF
     & "event: ping" & ASCII.CR & ASCII.LF
     & ASCII.CR & ASCII.LF
     & "data: world" & ASCII.CR & ASCII.LF
     & ASCII.CR & ASCII.LF;

   procedure Assert_Event
     (P             : in out LLM.SSE.Parser;
      Expected_Name : String;
      Expected_Data : String)
   is
      Event_Name : Unbounded_String;
      Data       : Unbounded_String;
   begin
      Assert (LLM.SSE.Next_Event (P, Event_Name, Data), "Expected one event");
      Assert
        (To_String (Event_Name) = Expected_Name,
         "Unexpected SSE event name");
      Assert (To_String (Data) = Expected_Data, "Unexpected SSE data payload");
   end Assert_Event;

   procedure Test_Full_Event (T : in out Test) is
      pragma Unreferenced (T);

      P : LLM.SSE.Parser;
   begin
      LLM.SSE.Feed (P, Full_Event_Fixture);

      Assert_Event
        (P,
         Expected_Name => "tool_call",
         Expected_Data => "{""name"":""read"","
           & ASCII.LF
           & """path"":""src/main.adb""}");

      declare
         Event_Name : Unbounded_String;
         Data       : Unbounded_String;
      begin
         Assert
           (not LLM.SSE.Next_Event (P, Event_Name, Data),
            "Parser should be empty after one event");
      end;
   end Test_Full_Event;

   procedure Test_Multi_Chunk_Event (T : in out Test) is
      pragma Unreferenced (T);

      P          : LLM.SSE.Parser;
      Event_Name : Unbounded_String;
      Data       : Unbounded_String;
   begin
      LLM.SSE.Feed
        (P,
         "event: content_block_delta" & ASCII.LF & "data: {""");
      Assert
        (not LLM.SSE.Next_Event (P, Event_Name, Data),
         "Partial event should not be returned yet");

      LLM.SSE.Feed
        (P,
         "type"":""content_block_delta"",""delta"":{""text"":""hel");
      Assert
        (not LLM.SSE.Next_Event (P, Event_Name, Data),
         "Still incomplete without blank-line terminator");

      LLM.SSE.Feed (P, "lo""}}" & ASCII.LF & ASCII.LF);

      Assert_Event
        (P,
         Expected_Name => "content_block_delta",
         Expected_Data =>
           "{""type"":""content_block_delta"",""delta"":{""text"":""hello""}}"
        );
   end Test_Multi_Chunk_Event;

   procedure Test_Done_Event (T : in out Test) is
      pragma Unreferenced (T);

      P : LLM.SSE.Parser;
   begin
      LLM.SSE.Feed (P, "data: [DONE]" & ASCII.LF & ASCII.LF);
      Assert_Event (P, Expected_Name => "", Expected_Data => "[DONE]");
   end Test_Done_Event;

   procedure Test_Ping_Skipped (T : in out Test) is
      pragma Unreferenced (T);

      P : LLM.SSE.Parser;
   begin
      LLM.SSE.Feed (P, Ping_Fixture);

      Assert_Event
        (P,
         Expected_Name => "",
         Expected_Data =>
           "{""choices"":[{""delta"":{""content"":""ok""}}]}");

      declare
         Event_Name : Unbounded_String;
         Data       : Unbounded_String;
      begin
         Assert
           (not LLM.SSE.Next_Event (P, Event_Name, Data),
            "Ping should be consumed and no extra events should remain");
      end;
   end Test_Ping_Skipped;

   procedure Test_CRLF_Ping_Skipped (T : in out Test) is
      pragma Unreferenced (T);

      P : LLM.SSE.Parser;
   begin
      LLM.SSE.Feed (P, CRLF_Ping_Fixture);

      Assert_Event (P, Expected_Name => "", Expected_Data => "world");

      declare
         Event_Name : Unbounded_String;
         Data       : Unbounded_String;
      begin
         Assert
           (not LLM.SSE.Next_Event (P, Event_Name, Data),
            "CRLF-terminated ping fixture should leave no extra events");
      end;
   end Test_CRLF_Ping_Skipped;

   procedure Test_Anthropic_Fixture (T : in out Test) is
      pragma Unreferenced (T);

      P : LLM.SSE.Parser;
   begin
      LLM.SSE.Feed (P, Anthropic_Fixture);

      Assert_Event
        (P,
         Expected_Name => "message_start",
         Expected_Data =>
           "{""type"":""message_start"",""message"":{""id"":""msg_1""}}"
        );
      Assert_Event
        (P,
         Expected_Name => "content_block_delta",
         Expected_Data =>
           "{""type"":""content_block_delta"",""index"":0,"
           & """delta"":{""type"":""thinking_delta"",""thinking"":""plan""}}"
        );
   end Test_Anthropic_Fixture;

   procedure Test_OpenAI_Fixture (T : in out Test) is
      pragma Unreferenced (T);

      P : LLM.SSE.Parser;
   begin
      LLM.SSE.Feed (P, OpenAI_Fixture);

      Assert_Event
        (P,
         Expected_Name => "",
         Expected_Data =>
           "{""choices"":[{""delta"":{""content"":""Hello""}}]}"
        );
      Assert_Event
        (P,
         Expected_Name => "",
         Expected_Data =>
           "{""choices"":[{""delta"":{""content"":"" world""}}]}"
        );
      Assert_Event (P, Expected_Name => "", Expected_Data => "[DONE]");
   end Test_OpenAI_Fixture;

   procedure Test_Reset (T : in out Test) is
      pragma Unreferenced (T);

      P          : LLM.SSE.Parser;
      Event_Name : Unbounded_String;
      Data       : Unbounded_String;
   begin
      LLM.SSE.Feed (P, "data: partial");
      LLM.SSE.Reset (P);

      Assert
        (not LLM.SSE.Next_Event (P, Event_Name, Data),
         "Reset should discard buffered partial data");

      LLM.SSE.Feed (P, "data: complete" & ASCII.LF & ASCII.LF);
      Assert_Event (P, Expected_Name => "", Expected_Data => "complete");
   end Test_Reset;


   package LLM_SSE_Caller is
     new AUnit.Test_Caller (LLM_SSE_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_SSE_Caller.Create
        ("LLM.SSE parses a complete named event",
         LLM_SSE_Tests.Test_Full_Event'Access));
      Result.Add_Test (LLM_SSE_Caller.Create
        ("LLM.SSE parses an event split across Feed calls",
         LLM_SSE_Tests.Test_Multi_Chunk_Event'Access));
      Result.Add_Test (LLM_SSE_Caller.Create
        ("LLM.SSE returns the [DONE] sentinel unchanged",
         LLM_SSE_Tests.Test_Done_Event'Access));
      Result.Add_Test (LLM_SSE_Caller.Create
        ("LLM.SSE skips ping events transparently",
         LLM_SSE_Tests.Test_Ping_Skipped'Access));
      Result.Add_Test (LLM_SSE_Caller.Create
        ("LLM.SSE accepts CRLF-terminated records",
         LLM_SSE_Tests.Test_CRLF_Ping_Skipped'Access));
      Result.Add_Test (LLM_SSE_Caller.Create
        ("LLM.SSE parses a canned Anthropic SSE fixture",
         LLM_SSE_Tests.Test_Anthropic_Fixture'Access));
      Result.Add_Test (LLM_SSE_Caller.Create
        ("LLM.SSE parses a canned OpenAI SSE fixture",
         LLM_SSE_Tests.Test_OpenAI_Fixture'Access));
      Result.Add_Test (LLM_SSE_Caller.Create
        ("LLM.SSE Reset clears partial buffered data",
         LLM_SSE_Tests.Test_Reset'Access));

      return Result;
   end Suite;

end LLM_SSE_Tests;
