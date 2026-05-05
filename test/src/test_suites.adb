with AUnit.Test_Caller;
with Nine_P_Proto_Tests;
with Nine_P_Client_Tests;
with Nine_P_Mock_Server_Tests;
with Nine_P_Integration_Tests;
with Acme_Event_Parser_Tests;
with Acme_Raw_Events_Tests;
with Acme_Window_Tests;
with Acme_Integration_Tests;
with Dispatch_Tests;
with Session_Lister_Tests;
with Coyote_App_Tests;
with Coyote_Utils_Tests;
with Session_History_Tests;
with Tool_URI_Tests;
with Subagent_Integration_Tests;
with LLM_System_Prompt_Tests;
with LLM_Context_Tests;
with LLM_Skills_Tests;
with LLM_HTTP_Tests;
with LLM_Settings_Tests;
with LLM_Types_Tests;
with LLM_Compaction_Tests;
with LLM_SSE_Tests;
with LLM_Tools_Tests;
with LLM_Spawn_Subagent_Tests;
with LLM_OpenAI_Completions_Tests;
with LLM_Auth_Tests;
with LLM_Catalogue_Tests;
with LLM_OpenRouter_Tests;
with LLM_OpenRouter_Catalogue_Tests;
with LLM_Anthropic_Messages_Tests;
with LLM_GitHub_Copilot_Tests;
with LLM_Model_Registry_Tests;
with LLM_Session_Store_Tests;
with LLM_Agent_Tests;
with LLM_Parallel_Tools_Tests;

package body Test_Suites is

   package Proto_Caller is
     new AUnit.Test_Caller (Nine_P_Proto_Tests.Test);
   package Client_Caller is
     new AUnit.Test_Caller (Nine_P_Client_Tests.Test);
   package Mock_Caller is
     new AUnit.Test_Caller (Nine_P_Mock_Server_Tests.Test);
   package Nine_P_Int_Caller is
     new AUnit.Test_Caller (Nine_P_Integration_Tests.Test);
   package Event_Parser_Caller is
     new AUnit.Test_Caller (Acme_Event_Parser_Tests.Test);
   package Raw_Events_Caller is
     new AUnit.Test_Caller (Acme_Raw_Events_Tests.Test);
   package Window_Caller is
     new AUnit.Test_Caller (Acme_Window_Tests.Test);
   package Acme_Int_Caller is
     new AUnit.Test_Caller (Acme_Integration_Tests.Test);
   package Dispatch_Caller is
     new AUnit.Test_Caller (Dispatch_Tests.Test);
   package Session_Lister_Caller is
     new AUnit.Test_Caller (Session_Lister_Tests.Test);
   package App_State_Caller is
     new AUnit.Test_Caller (Coyote_App_Tests.Test);
   package Session_History_Caller is
     new AUnit.Test_Caller (Session_History_Tests.Test);
   package Tool_URI_Caller is
     new AUnit.Test_Caller (Tool_URI_Tests.Test);
   package Subagent_Int_Caller is
     new AUnit.Test_Caller (Subagent_Integration_Tests.Test);
   package LLM_Sys_Prompt_Caller is
     new AUnit.Test_Caller (LLM_System_Prompt_Tests.Test);
   package LLM_Context_Caller is
     new AUnit.Test_Caller (LLM_Context_Tests.Test);
   package LLM_Skills_Caller is
     new AUnit.Test_Caller (LLM_Skills_Tests.Test);
   package Coyote_Utils_Caller is
     new AUnit.Test_Caller (Coyote_Utils_Tests.Test);
   package LLM_HTTP_Caller is
     new AUnit.Test_Caller (LLM_HTTP_Tests.Test);
   package LLM_Settings_Caller is
     new AUnit.Test_Caller (LLM_Settings_Tests.Test);
   package LLM_Types_Caller is
     new AUnit.Test_Caller (LLM_Types_Tests.Test);
   package LLM_Compaction_Caller is
     new AUnit.Test_Caller (LLM_Compaction_Tests.Test);
   package LLM_SSE_Caller is
     new AUnit.Test_Caller (LLM_SSE_Tests.Test);
   package LLM_Tools_Caller is
     new AUnit.Test_Caller (LLM_Tools_Tests.Test);
   package LLM_Spawn_Subagent_Caller is
     new AUnit.Test_Caller (LLM_Spawn_Subagent_Tests.Test);
   package LLM_OpenAI_Completions_Caller is
     new AUnit.Test_Caller (LLM_OpenAI_Completions_Tests.Test);
   package LLM_Auth_Caller is
     new AUnit.Test_Caller (LLM_Auth_Tests.Test);
   package LLM_Catalogue_Caller is
     new AUnit.Test_Caller (LLM_Catalogue_Tests.Test);
   package LLM_OpenRouter_Caller is
     new AUnit.Test_Caller (LLM_OpenRouter_Tests.Test);
   package LLM_OpenRouter_Catalogue_Caller is
     new AUnit.Test_Caller (LLM_OpenRouter_Catalogue_Tests.Test);
   package LLM_Anthropic_Messages_Caller is
     new AUnit.Test_Caller (LLM_Anthropic_Messages_Tests.Test);
   package LLM_GitHub_Copilot_Caller is
     new AUnit.Test_Caller (LLM_GitHub_Copilot_Tests.Test);
   package LLM_Model_Registry_Caller is
     new AUnit.Test_Caller (LLM_Model_Registry_Tests.Test);
   package LLM_Session_Store_Caller is
     new AUnit.Test_Caller (LLM_Session_Store_Tests.Test);
   package LLM_Agent_Caller is
     new AUnit.Test_Caller (LLM_Agent_Tests.Test);
   package LLM_Parallel_Caller is
     new AUnit.Test_Caller (LLM_Parallel_Tools_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      --  Nine_P.Proto tests
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Qid round-trip",
         Nine_P_Proto_Tests.Test_Qid_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Stat round-trip",
         Nine_P_Proto_Tests.Test_Stat_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Tversion",
         Nine_P_Proto_Tests.Test_Tversion_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Rversion",
         Nine_P_Proto_Tests.Test_Rversion_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Tattach",
         Nine_P_Proto_Tests.Test_Tattach_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Rattach",
         Nine_P_Proto_Tests.Test_Rattach_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Rerror",
         Nine_P_Proto_Tests.Test_Rerror_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Twalk",
         Nine_P_Proto_Tests.Test_Twalk_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Rwalk",
         Nine_P_Proto_Tests.Test_Rwalk_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Topen",
         Nine_P_Proto_Tests.Test_Topen_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Ropen",
         Nine_P_Proto_Tests.Test_Ropen_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Tread",
         Nine_P_Proto_Tests.Test_Tread_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Rread",
         Nine_P_Proto_Tests.Test_Rread_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Twrite",
         Nine_P_Proto_Tests.Test_Twrite_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Twrite with empty data (count=0)",
         Nine_P_Proto_Tests.Test_Twrite_Empty_Data'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Rwrite",
         Nine_P_Proto_Tests.Test_Rwrite_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Tclunk",
         Nine_P_Proto_Tests.Test_Tclunk_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Pack/Unpack Tstat/Rstat",
         Nine_P_Proto_Tests.Test_Stat_Message_Round_Trip'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Message size field is correct",
         Nine_P_Proto_Tests.Test_Message_Size'Access));
      Result.Add_Test (Proto_Caller.Create
        ("Little-endian byte order",
         Nine_P_Proto_Tests.Test_Little_Endian'Access));
      Result.Add_Test (Proto_Caller.Create
        ("UTF-8 string encoding",
         Nine_P_Proto_Tests.Test_String_Encoding'Access));

      --  Nine_P.Client tests
      Result.Add_Test (Client_Caller.Create
        ("Namespace uses $NAMESPACE env var",
         Nine_P_Client_Tests.Test_Namespace_Uses_Env'Access));
      Result.Add_Test (Client_Caller.Create
        ("Namespace fallback to /tmp/ns.<user>.<display>",
         Nine_P_Client_Tests.Test_Namespace_Fallback'Access));
      Result.Add_Test (Client_Caller.Create
        ("Connect mutates an existing Fs in place",
         Nine_P_Client_Tests.Test_Connect'Access));
      Result.Add_Test (Client_Caller.Create
        ("Open procedure mutates an existing File in place",
         Nine_P_Client_Tests.Test_Open_Procedure'Access));
      Result.Add_Test (Client_Caller.Create
        ("Connect closes old socket and reconnects cleanly",
         Nine_P_Client_Tests.Test_Connect_Reconnect'Access));
      Result.Add_Test (Client_Caller.Create
        ("Connect raises when service is absent from namespace",
         Nine_P_Client_Tests.Test_Connect_Failure'Access));
      Result.Add_Test (Client_Caller.Create
        ("Read_Message / Write_Message round-trip",
         Nine_P_Client_Tests.Test_Read_Write_Message'Access));
      Result.Add_Test (Client_Caller.Create
        ("Read_Message respects size framing",
         Nine_P_Client_Tests.Test_Read_Message_Framing'Access));
      Result.Add_Test (Client_Caller.Create
        ("Connect_With_Retry succeeds on first attempt",
         Nine_P_Client_Tests
           .Test_Connect_With_Retry_Happy_Path'Access));
      Result.Add_Test (Client_Caller.Create
        ("Connect_With_Retry succeeds on second attempt after one failure",
         Nine_P_Client_Tests
           .Test_Connect_With_Retry_Succeeds_On_Second_Attempt'Access));
      Result.Add_Test (Client_Caller.Create
        ("Connect_With_Retry raises after all retries exhausted",
         Nine_P_Client_Tests
           .Test_Connect_With_Retry_Exhausted'Access));

      --  Nine_P.Client protocol tests via TCP mock server
      Result.Add_Test (Mock_Caller.Create
        ("Nine_P.Client Read_Once issues a single Tread",
         Nine_P_Mock_Server_Tests
           .Test_Read_Once_Returns_Single_Tread'Access));
      Result.Add_Test (Mock_Caller.Create
        ("Nine_P.Client Read aggregates Rread chunks until EOF",
         Nine_P_Mock_Server_Tests
           .Test_Read_Aggregates_Chunks_Until_EOF'Access));
      Result.Add_Test (Mock_Caller.Create
        ("Nine_P.Client Write splits payloads by IOunit",
         Nine_P_Mock_Server_Tests.Test_Write_Splits_By_IOunit'Access));
      Result.Add_Test (Mock_Caller.Create
        ("Nine_P.Client Twalk Rerror raises P9_Error",
         Nine_P_Mock_Server_Tests
           .Test_Walk_Failure_Raises_P9_Error'Access));
      Result.Add_Test (Mock_Caller.Create
        ("Nine_P.Client Tread Rerror raises P9_Error",
         Nine_P_Mock_Server_Tests
           .Test_Rerror_On_Read_Raises_P9_Error'Access));
      Result.Add_Test (Mock_Caller.Create
        ("Nine_P.Client unsupported Rversion raises P9_Error",
         Nine_P_Mock_Server_Tests
           .Test_Rversion_Failure_Raises_P9_Error'Access));
      Result.Add_Test (Mock_Caller.Create
        ("Nine_P.Client finalization sends Tclunk",
         Nine_P_Mock_Server_Tests.Test_Finalize_Sends_Tclunk'Access));

      --  Nine_P integration tests (skipped if acme not running)
      Result.Add_Test (Nine_P_Int_Caller.Create
        ("[integration] Ns_Mount acme",
         Nine_P_Integration_Tests.Test_Ns_Mount_Acme'Access));
      Result.Add_Test (Nine_P_Int_Caller.Create
        ("[integration] Read /index matches 9p",
         Nine_P_Integration_Tests.Test_Read_Acme_Index'Access));
      Result.Add_Test (Nine_P_Int_Caller.Create
        ("[integration] Open /new/ctl returns window ID",
         Nine_P_Integration_Tests.Test_Open_New_Ctl'Access));
      Result.Add_Test (Nine_P_Int_Caller.Create
        ("[integration] Client write visible via 9p",
         Nine_P_Integration_Tests.Test_Client_Matches_9p'Access));

      --  Acme.Event_Parser tests
      Result.Add_Test (Event_Parser_Caller.Create
        ("Unquoted rc token",
         Acme_Event_Parser_Tests.Test_Unquoted_Token'Access));
      Result.Add_Test (Event_Parser_Caller.Create
        ("Quoted rc token with spaces",
         Acme_Event_Parser_Tests.Test_Quoted_Token'Access));
      Result.Add_Test (Event_Parser_Caller.Create
        ("Escaped single quote in rc token",
         Acme_Event_Parser_Tests.Test_Escaped_Quote'Access));
      Result.Add_Test (Event_Parser_Caller.Create
        ("Parse button-2 execute event",
         Acme_Event_Parser_Tests.Test_Parse_Execute'Access));
      Result.Add_Test (Event_Parser_Caller.Create
        ("Parse button-3 look event",
         Acme_Event_Parser_Tests.Test_Parse_Look'Access));
      Result.Add_Test (Event_Parser_Caller.Create
        ("Parse event with quoted text",
         Acme_Event_Parser_Tests.Test_Parse_Quoted_Text'Access));
      Result.Add_Test (Event_Parser_Caller.Create
        ("Invalid lines return False",
         Acme_Event_Parser_Tests.Test_Parse_Invalid'Access));
      Result.Add_Test (Event_Parser_Caller.Create
        ("Empty/whitespace lines return False",
         Acme_Event_Parser_Tests.Test_Parse_Empty'Access));

      --  Acme.Raw_Events tests
      Result.Add_Test (Raw_Events_Caller.Create
        ("Simple execute event",
         Acme_Raw_Events_Tests.Test_Simple_Execute'Access));
      Result.Add_Test (Raw_Events_Caller.Create
        ("Simple look event",
         Acme_Raw_Events_Tests.Test_Simple_Look'Access));
      Result.Add_Test (Raw_Events_Caller.Create
        ("Keyboard insert event",
         Acme_Raw_Events_Tests.Test_Keyboard_Insert'Access));
      Result.Add_Test (Raw_Events_Caller.Create
        ("Multi-digit positions",
         Acme_Raw_Events_Tests.Test_Multi_Digit_Pos'Access));
      Result.Add_Test (Raw_Events_Caller.Create
        ("Flag 2 expansion event",
         Acme_Raw_Events_Tests.Test_Flag2_Expansion'Access));
      Result.Add_Test (Raw_Events_Caller.Create
        ("Flag 8 chorded arg/origin",
         Acme_Raw_Events_Tests.Test_Flag8_Chorded'Access));
      Result.Add_Test (Raw_Events_Caller.Create
        ("Incremental feed",
         Acme_Raw_Events_Tests.Test_Incremental_Feed'Access));
      Result.Add_Test (Raw_Events_Caller.Create
        ("Two events in one feed",
         Acme_Raw_Events_Tests.Test_Two_Events_One_Feed'Access));
      Result.Add_Test (Raw_Events_Caller.Create
        ("Incomplete buffer returns False",
         Acme_Raw_Events_Tests.Test_Incomplete_Returns_False'Access));

      --  Acme.Window pure tests (no live acme)
      Result.Add_Test (Window_Caller.Create
        ("Win_File_Path generates correct paths",
         Acme_Window_Tests.Test_Win_File_Path'Access));
      Result.Add_Test (Window_Caller.Create
        ("Event_Path generates correct path",
         Acme_Window_Tests.Test_Event_Path'Access));
      Result.Add_Test (Window_Caller.Create
        ("Win_File_Path id=1 has no leading space",
         Acme_Window_Tests.Test_Win_File_Path_Id1'Access));

      --  Acme.Window integration tests (skipped if acme not running)
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] New_Win has valid ID",
         Acme_Integration_Tests.Test_New_Win_Has_Valid_Id'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Append visible via 9p",
         Acme_Integration_Tests.Test_Append_Visible_Via_9p'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Append_Tag visible via 9p",
         Acme_Integration_Tests.Test_Append_Tag_Visible_Via_9p'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Set_Name reflected in ctl",
         Acme_Integration_Tests.Test_Set_Name'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Replace_Line1 rewrites only the first line",
         Acme_Integration_Tests
           .Test_Replace_Line1_Only_Rewrites_First_Line'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Delete removes window from /index",
         Acme_Integration_Tests
           .Test_Delete_Removes_Window_From_Index'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Read_Body returns the full body",
         Acme_Integration_Tests
           .Test_Read_Body_Returns_Full_Content'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Read_Chars returns the requested subrange",
         Acme_Integration_Tests.Test_Read_Chars_Returns_Subrange'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Selection empty on fresh window",
         Acme_Integration_Tests.Test_Selection_Empty'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Selection_Text after dot=addr",
         Acme_Integration_Tests
           .Test_Selection_Text_After_Set_Dot'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Raw event parser with live window",
         Acme_Integration_Tests.Test_Raw_Event_From_Live'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Replace_Match substitutes matched text",
         Acme_Integration_Tests.Test_Replace_Match_Simple'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Replace_Match is silent when pattern absent",
         Acme_Integration_Tests.Test_Replace_Match_No_Match'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Replace_Match closes parallel blocks independently",
         Acme_Integration_Tests.Test_Replace_Match_Parallel_Blocks'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Clear: Replace_Match ""1,$"" erases body content",
         Acme_Integration_Tests.Test_Clear_Body_Erases_Content'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Clear: full sequence leaves only the status line",
         Acme_Integration_Tests.Test_Clear_Body_Restores_Status'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Clear: safe on an already-empty body",
         Acme_Integration_Tests.Test_Clear_Body_On_Empty_Body'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Live footer: summary and fork share one line",
         Acme_Integration_Tests.Test_Append_Live_Turn_Footer'Access));
      Result.Add_Test (Acme_Int_Caller.Create
        ("[integration] Live footer: cost segments appear when non-zero",
         Acme_Integration_Tests.Test_Append_Live_Turn_Footer_With_Cost
           'Access));

      --  Dispatch integration tests (skipped if acme not running)
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch agent_start sets streaming",
         Dispatch_Tests.Test_Dispatch_Agent_Start'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch agent_end clears streaming",
         Dispatch_Tests.Test_Dispatch_Agent_End_Normal'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch text_delta appends text",
         Dispatch_Tests.Test_Dispatch_Text_Delta'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch thinking_delta prefixes with border",
         Dispatch_Tests.Test_Dispatch_Thinking_Delta'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch tool_execution_start renders header",
         Dispatch_Tests.Test_Dispatch_Tool_Start'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch tool_execution_end success closes block",
         Dispatch_Tests.Test_Dispatch_Tool_End_Success'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch tool_execution_end error closes block",
         Dispatch_Tests.Test_Dispatch_Tool_End_Error'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch message_end updates token counts",
         Dispatch_Tests.Test_Dispatch_Message_End_Tokens'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch session_stats appends live footer",
         Dispatch_Tests.Test_Dispatch_Session_Stats_Footer'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch model_select updates model state",
         Dispatch_Tests.Test_Dispatch_Model_Select'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch session_info updates session state",
         Dispatch_Tests.Test_Dispatch_Session_Info'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch auto_retry_start writes retry notice",
         Dispatch_Tests.Test_Dispatch_Auto_Retry_Start'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch full turn footer waits for session_stats",
         Dispatch_Tests
           .Test_Dispatch_Full_Turn_Footer_Only_After_Session_Stats'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch aborted turn does not append footer",
         Dispatch_Tests.Test_Dispatch_Aborted_Turn_No_Footer'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch auto_retry_end allows later footer",
         Dispatch_Tests.Test_Dispatch_Auto_Retry_End_Then_Normal_Turn'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch auto_compaction start/end keep state clean",
         Dispatch_Tests.Test_Dispatch_Auto_Compaction_Start_And_End'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch agent_end with no response shows warning",
         Dispatch_Tests.Test_Dispatch_Agent_End_No_Response_Shows_Error
           'Access));

      --  Session_Lister tests
      Result.Add_Test (Session_Lister_Caller.Create
        ("Encode_Cwd absolute path",
         Session_Lister_Tests.Test_Encode_Cwd_Absolute'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Encode_Cwd relative path",
         Session_Lister_Tests.Test_Encode_Cwd_Relative'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Encode_Cwd empty/root path",
         Session_Lister_Tests.Test_Encode_Cwd_Empty'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Format_Timestamp ISO with Z",
         Session_Lister_Tests.Test_Format_Timestamp'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Format_Timestamp short string verbatim",
         Session_Lister_Tests.Test_Format_Timestamp_Short'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Parse full session JSONL",
         Session_Lister_Tests.Test_Parse_Session_Full'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Parse session JSONL without name",
         Session_Lister_Tests.Test_Parse_Session_No_Name'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Parse session JSONL with bad JSON",
         Session_Lister_Tests.Test_Parse_Session_Bad_Json'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Parse session JSONL with a very long line (no stack overflow)",
         Session_Lister_Tests.Test_Parse_Session_Long_Line'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Find_Session_File found in test dir",
         Session_Lister_Tests.Test_Find_Session_File_Found'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Find_Session_File returns empty when UUID absent",
         Session_Lister_Tests.Test_Find_Session_File_Not_Found'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Find_Session_File searches all session subdirectories",
         Session_Lister_Tests.Test_Find_Session_File_Any_Dir'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Fork_Session forks after first turn",
         Session_Lister_Tests.Test_Fork_Session_One_Turn'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Fork_Session forks after second turn",
         Session_Lister_Tests.Test_Fork_Session_Second_Turn'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Fork_Session returns empty beyond last turn",
         Session_Lister_Tests.Test_Fork_Session_Beyond_End'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Fork_Session returns empty for missing source",
         Session_Lister_Tests.Test_Fork_Session_Missing_Src'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("List_Sessions sorts native sessions newest first",
         Session_Lister_Tests.Test_List_Sessions_Newest_First'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("List_Sessions ignores invalid non-session files",
         Session_Lister_Tests.Test_List_Sessions_Skips_Invalid_Files'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Fork_Session preserves native turn boundaries",
         Session_Lister_Tests
           .Test_Fork_Native_Format_Preserves_Turn_Boundary'Access));

      --  Coyote_App (App_State) tests
      Result.Add_Test (App_State_Caller.Create
        ("App_State model round-trip",
         Coyote_App_Tests.Test_State_Model'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State streaming flag",
         Coyote_App_Tests.Test_State_Streaming'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State token counts",
         Coyote_App_Tests.Test_State_Tokens'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State shutdown barrier",
         Coyote_App_Tests.Test_State_Shutdown'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State session ID",
         Coyote_App_Tests.Test_State_Session_Id'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Nth_Field basic space-separated",
         Coyote_App_Tests.Test_Nth_Field_Basic'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Nth_Field tab-separated input",
         Coyote_App_Tests.Test_Nth_Field_Tabs'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Nth_Field edge cases",
         Coyote_App_Tests.Test_Nth_Field_Edges'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Parse_Fork_Token: matching PID extracts UUID and turn",
         Coyote_App_Tests.Test_Parse_Fork_Token_Match'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Parse_Fork_Token: mismatched PID returns False",
         Coyote_App_Tests.Test_Parse_Fork_Token_Pid_Mismatch'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Parse_Fork_Token: missing trailing slash returns False",
         Coyote_App_Tests.Test_Parse_Fork_Token_No_Slash'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Parse_Fork_Token: non-numeric turn returns False",
         Coyote_App_Tests.Test_Parse_Fork_Token_Bad_Turn'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Parse_Fork_Token: empty UUID returns False",
         Coyote_App_Tests.Test_Parse_Fork_Token_Empty_Uuid'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Parse_Fork_Token: empty input returns False",
         Coyote_App_Tests.Test_Parse_Fork_Token_Empty'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Count increment",
         Coyote_App_Tests.Test_State_Turn_Count_Increment'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Count set",
         Coyote_App_Tests.Test_State_Turn_Count_Set'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Count reset",
         Coyote_App_Tests.Test_State_Turn_Count_Reset'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Retrying initial value is False",
         Coyote_App_Tests.Test_State_Is_Retrying_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Retrying set and clear",
         Coyote_App_Tests.Test_State_Is_Retrying_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Retrying independent of text flags",
         Coyote_App_Tests.Test_State_Is_Retrying_Independent'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Has_Text_Delta initial value is False",
         Coyote_App_Tests.Test_State_Has_Text_Delta_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Has_Text_Delta set and clear",
         Coyote_App_Tests.Test_State_Has_Text_Delta_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Has_Text_Delta independent of Text_Emitted",
         Coyote_App_Tests.Test_State_Has_Text_Delta_Independent'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Stop_Reason initial value is empty",
         Coyote_App_Tests.Test_State_Last_Stop_Reason_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Stop_Reason round-trip for all stop-reason values",
         Coyote_App_Tests.Test_State_Last_Stop_Reason_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Stop_Reason independent of all other flags",
         Coyote_App_Tests.Test_State_Last_Stop_Reason_Independent'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Error_Message initial value is empty",
         Coyote_App_Tests.Test_State_Last_Error_Message_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Last_Error_Message round-trip and independence",
         Coyote_App_Tests
           .Test_State_Last_Error_Message_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Pending_Stats gated by Last_Stop_Reason "
         & "(stop/length only)",
         Coyote_App_Tests
           .Test_State_Pending_Stats_Gated_By_Stop_Reason'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Models_Pending defaults to False",
         Coyote_App_Tests.Test_State_Models_Pending_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Models_Pending Set_Models_Pending toggles flag",
         Coyote_App_Tests
           .Test_State_Models_Pending_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Models_Pending independent of Pending_Stats",
         Coyote_App_Tests
           .Test_State_Models_Pending_Independent'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: identical texts return (no changes)",
         Coyote_App_Tests.Test_Edit_Diff_No_Change'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: changed line shows - and + lines",
         Coyote_App_Tests.Test_Edit_Diff_Single_Substitution'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: added lines appear as + lines",
         Coyote_App_Tests.Test_Edit_Diff_Added_Lines'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: removed lines appear as - lines",
         Coyote_App_Tests.Test_Edit_Diff_Removed_Lines'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: output contains no ---/+++/@@ headers",
         Coyote_App_Tests.Test_Edit_Diff_No_Headers'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: diff > Max_L lines is truncated with trailer",
         Coyote_App_Tests.Test_Edit_Diff_Truncation'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: UTF-8 bytes in context lines preserved",
         Coyote_App_Tests.Test_Edit_Diff_Utf8_Context_Line'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: UTF-8 bytes in removed lines preserved",
         Coyote_App_Tests.Test_Edit_Diff_Utf8_Removed_Line'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: UTF-8 bytes in added lines preserved",
         Coyote_App_Tests.Test_Edit_Diff_Utf8_Added_Line'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Edit_Diff_Lines: no double-encoding under -gnatW8 (regression)",
         Coyote_App_Tests.Test_Edit_Diff_No_Double_Encoding'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Stats model part: non-empty when model is set",
         Coyote_App_Tests.Test_Stats_Model_Part_When_Set'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Stats model part: empty guard when no model set",
         Coyote_App_Tests.Test_Stats_Model_Part_When_Empty'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Cost_Dmil initial value is 0",
         Coyote_App_Tests.Test_State_Turn_Cost_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Cost_Dmil round-trip via Set_Turn_Cost",
         Coyote_App_Tests.Test_State_Turn_Cost_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State session stats fields all start at 0",
         Coyote_App_Tests.Test_State_Session_Stats_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Set_Session_Stats stores all six fields atomically",
         Coyote_App_Tests.Test_State_Session_Stats_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Set_Session_Stats with zeros resets all fields",
         Coyote_App_Tests.Test_State_Session_Stats_Reset'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State cost fields are independent of per-turn token counts",
         Coyote_App_Tests.Test_State_Cost_Independent_Of_Tokens'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: string value returned without quotes",
         Coyote_App_Tests.Test_JSON_Scalar_String'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: integer value serialised as numeric string",
         Coyote_App_Tests.Test_JSON_Scalar_Integer'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: negative integer serialised correctly",
         Coyote_App_Tests.Test_JSON_Scalar_Negative_Integer'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: boolean true serialises to ""true""",
         Coyote_App_Tests.Test_JSON_Scalar_Boolean_True'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: boolean false serialises to ""false""",
         Coyote_App_Tests.Test_JSON_Scalar_Boolean_False'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: float value serialises to non-empty string",
         Coyote_App_Tests.Test_JSON_Scalar_Float'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: null value returns ""...""",
         Coyote_App_Tests.Test_JSON_Scalar_Null'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: object value returns ""...""",
         Coyote_App_Tests.Test_JSON_Scalar_Object'Access));
      Result.Add_Test (App_State_Caller.Create
        ("JSON_Scalar_Image: array value returns ""...""",
         Coyote_App_Tests.Test_JSON_Scalar_Array'Access));

      Result.Add_Test (App_State_Caller.Create
        ("App_State One_Shot_Result initial value is empty",
         Coyote_App_Tests.Test_One_Shot_Result_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State One_Shot_Result first-write-wins",
         Coyote_App_Tests.Test_One_Shot_Result_First_Write_Wins'Access));

      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: single-line value returns border + label + value",
         Coyote_App_Tests.Test_Format_Tool_Field_Single_Line'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: two-line value carries border on both lines",
         Coyote_App_Tests.Test_Format_Tool_Field_Two_Lines'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: three-line value carries border on every line",
         Coyote_App_Tests.Test_Format_Tool_Field_Three_Lines'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: trailing LF produces empty continuation line",
         Coyote_App_Tests.Test_Format_Tool_Field_Trailing_LF'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: empty value returns border + label only",
         Coyote_App_Tests.Test_Format_Tool_Field_Empty_Value'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Tool_Field: value over Max_Len is truncated with ellipsis",
         Coyote_App_Tests.Test_Format_Tool_Field_Truncation'Access));

      --  Format_Kilo
      Result.Add_Test (App_State_Caller.Create
        ("Format_Kilo: values below 1000 returned as decimal",
         Coyote_App_Tests.Test_Format_Kilo_Below_Threshold'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Kilo: exact multiples of 1000 use ""k"" suffix",
         Coyote_App_Tests.Test_Format_Kilo_Round_Numbers'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Kilo: non-zero tenth produces ""N.Mk"" form",
         Coyote_App_Tests.Test_Format_Kilo_Fractional'Access));

      --  Format_Cost
      Result.Add_Test (App_State_Caller.Create
        ("Format_Cost: 0 dmil -> ""$0.0000""",
         Coyote_App_Tests.Test_Format_Cost_Zero'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Cost: sub-dollar values zero-pad fractional digits",
         Coyote_App_Tests.Test_Format_Cost_Fractional'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Cost: values >= 10000 dmil have non-zero dollar part",
         Coyote_App_Tests.Test_Format_Cost_Dollars'Access));

      --  Agent_Stem
      Result.Add_Test (App_State_Caller.Create
        ("Agent_Stem: .agent.md suffix stripped from basename",
         Coyote_App_Tests.Test_Agent_Stem_With_Extension'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Agent_Stem: no .agent.md suffix -- whole basename returned",
         Coyote_App_Tests.Test_Agent_Stem_No_Extension'Access));

      --  Extract_Plumb_Data
      Result.Add_Test (App_State_Caller.Create
        ("Extract_Plumb_Data: data field returned from valid message",
         Coyote_App_Tests.Test_Extract_Plumb_Data_Basic'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Extract_Plumb_Data: trailing LF stripped via ndata",
         Coyote_App_Tests.Test_Extract_Plumb_Data_Strips_Trailing_LF'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Extract_Plumb_Data: fewer than 6 newlines returns empty string",
         Coyote_App_Tests.Test_Extract_Plumb_Data_Too_Few_Fields'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Extract_Plumb_Data: empty byte array returns empty string",
         Coyote_App_Tests.Test_Extract_Plumb_Data_Empty'Access));

      --  Get_Cost_Dmil
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: JSON float converted to dmil units",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Float_Value'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: JSON float 0.0 returns 0",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Zero_Float'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: JSON integer 0 returns 0",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Integer_Zero'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: absent field returns 0",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Absent_Field'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Get_Cost_Dmil: negative float returns 0",
         Coyote_App_Tests.Test_Get_Cost_Dmil_Negative_Float'Access));

      --  Format_Status
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: empty state produces ""* ready""",
         Coyote_App_Tests.Test_Format_Status_Default'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: Extra argument reflected verbatim",
         Coyote_App_Tests.Test_Format_Status_Custom_Extra'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: model shown as ""[provider/model]""",
         Coyote_App_Tests.Test_Format_Status_With_Model'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: session ID shows first 8 chars",
         Coyote_App_Tests.Test_Format_Status_With_Session'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: token/context window shown as ""Nk/Mk""",
         Coyote_App_Tests.Test_Format_Status_With_Context'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Status: thinking level shown as "" ~level""",
         Coyote_App_Tests.Test_Format_Status_With_Thinking'Access));

      --  Session_History integration tests (require live acme)
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: file not found writes error",
         Session_History_Tests.Test_Render_File_Not_Found'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: user message rendered as triangle text",
         Session_History_Tests.Test_Render_User_Message'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: assistant text rendered verbatim",
         Session_History_Tests.Test_Render_Assistant_Text'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: successful tool call shows check mark",
         Session_History_Tests.Test_Render_Tool_Call_Success'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: failed tool call shows cross mark",
         Session_History_Tests.Test_Render_Tool_Call_Error'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: thinking block prefixed with bar",
         Session_History_Tests.Test_Render_Thinking_Block'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: model_change writes [Model ...] line",
         Session_History_Tests.Test_Render_Model_Change'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: token usage updates State.Turn_Tokens",
         Session_History_Tests.Test_Render_Token_Stats'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: separator appended after history",
         Session_History_Tests.Test_Render_Separator'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: tool call header contains coyote-session+ URI",
         Session_History_Tests.Test_Render_Tool_Call_URI'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: tool call header has no URI when id absent",
         Session_History_Tests.Test_Render_Tool_Call_No_URI'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: native user and assistant text",
         Session_History_Tests
           .Test_History_Renders_Native_User_And_Assistant'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: native tool call shows success",
         Session_History_Tests
           .Test_History_Renders_Native_Tool_Call'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: native model_change writes [Model ...]",
         Session_History_Tests
           .Test_History_Renders_Native_Model_Change'Access));
      Result.Add_Test (Session_History_Caller.Create
        ("[integration] Render: native two-turn history restores count",
         Session_History_Tests
           .Test_History_Renders_Two_Turn_Session'Access));

      --  Tool_URI unit tests (pure, no acme required)
      Result.Add_Test (Tool_URI_Caller.Create
        ("Hash_Tool_Id: SHA-256 of empty string",
         Tool_URI_Tests.Test_Hash_Empty'Access));
      Result.Add_Test (Tool_URI_Caller.Create
        ("Hash_Tool_Id: known values match Python reference",
         Tool_URI_Tests.Test_Hash_Known_Values'Access));
      Result.Add_Test (Tool_URI_Caller.Create
        ("Hash_Tool_Id: result is always 16 characters",
         Tool_URI_Tests.Test_Hash_Length'Access));
      Result.Add_Test (Tool_URI_Caller.Create
        ("Hash_Tool_Id: distinct inputs produce distinct hashes",
         Tool_URI_Tests.Test_Hash_Distinct'Access));
      Result.Add_Test (Tool_URI_Caller.Create
        ("Hash_Tool_Id: result contains only lowercase hex",
         Tool_URI_Tests.Test_Hash_Lowercase_Hex'Access));

      --  Subagent (--one-shot) integration tests (require live acme)
      Result.Add_Test (Subagent_Int_Caller.Create
        ("[subagent] One-shot returns JSON with output and session_id",
         Subagent_Integration_Tests.Test_One_Shot_Returns_Json'Access));
      Result.Add_Test (Subagent_Int_Caller.Create
        ("[subagent] Two --one-shot runs use distinct sessions",
         Subagent_Integration_Tests
           .Test_One_Shot_Fresh_Session_Each_Run'Access));

      --  LLM.System_Prompt tests
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains preamble",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Preamble'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt lists built-in tools",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Lists_Tools'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains guidelines",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Guidelines'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains cwd",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Cwd'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt default prompt contains date",
         LLM_System_Prompt_Tests
           .Test_Default_Prompt_Contains_Date'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt custom prompt replaces preamble",
         LLM_System_Prompt_Tests
           .Test_Custom_Prompt_Replaces_Preamble'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt custom prompt keeps cwd",
         LLM_System_Prompt_Tests
           .Test_Custom_Prompt_Keeps_Cwd'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt append prompt appears",
         LLM_System_Prompt_Tests
           .Test_Append_Prompt_Appears'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt no-tools suppresses tool list",
         LLM_System_Prompt_Tests
           .Test_No_Tools_Suppresses_Tool_List'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt injects context sections",
         LLM_System_Prompt_Tests
           .Test_Context_Sections_Injected'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt injects skills section",
         LLM_System_Prompt_Tests
           .Test_Skills_Section_Injected'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt empty context section is silent",
         LLM_System_Prompt_Tests
           .Test_Empty_Context_Sections_Silent'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt preserves section order",
         LLM_System_Prompt_Tests.Test_Section_Order'Access));

      --  LLM.System_Prompt context-loading tests
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections returns empty with no files",
         LLM_Context_Tests.Test_No_Files_Returns_Empty'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections loads AGENTS.md from cwd",
         LLM_Context_Tests.Test_Agents_Md_In_Cwd'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections loads global context dir",
         LLM_Context_Tests.Test_Global_Context_Dir'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections loads project context dir",
         LLM_Context_Tests.Test_Project_Context_Dir'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections orders global before project",
         LLM_Context_Tests.Test_Global_Before_Project'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections orders project before AGENTS",
         LLM_Context_Tests.Test_Project_Before_Agents_Md'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections sorts files alphabetically",
         LLM_Context_Tests.Test_Context_Files_Alpha_Order'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections adds outer header",
         LLM_Context_Tests.Test_Outer_Header_Present'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections omits header when empty",
         LLM_Context_Tests.Test_No_Header_When_Empty'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Build_System_Prompt injects loaded context",
         LLM_Context_Tests.Test_Injected_Into_Built_Prompt'Access));

      --  LLM.Skills tests
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills returns empty string when no skills exist",
         LLM_Skills_Tests.Test_No_Skills_Returns_Empty_String'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills parses name and description from frontmatter",
         LLM_Skills_Tests.Test_Parses_Name_And_Description'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills records absolute skill file locations",
         LLM_Skills_Tests.Test_Location_Is_Absolute_Path'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills skips files missing name",
         LLM_Skills_Tests.Test_Missing_Name_Skipped'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills skips files missing description",
         LLM_Skills_Tests.Test_Missing_Description_Skipped'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads global skills",
         LLM_Skills_Tests.Test_Global_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads project skills",
         LLM_Skills_Tests.Test_Project_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads global ~/.agents/skills",
         LLM_Skills_Tests.Test_Global_Agents_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills loads project .agents/skills",
         LLM_Skills_Tests.Test_Project_Agents_Skills_Loaded'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains skill name",
         LLM_Skills_Tests.Test_Format_Contains_Skill_Name'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains description",
         LLM_Skills_Tests.Test_Format_Contains_Description'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains location",
         LLM_Skills_Tests.Test_Format_Contains_Location'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains outer tags",
         LLM_Skills_Tests.Test_Format_Contains_Outer_Tags'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills format contains preamble",
         LLM_Skills_Tests.Test_Format_Contains_Preamble'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills formats two skills",
         LLM_Skills_Tests.Test_Format_Two_Skills'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills auto-injects into Build_System_Prompt",
         LLM_Skills_Tests.Test_Injected_Into_Built_Prompt'Access));

      --  Coyote_Utils tests
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Coyote_Utils reads file when path exists",
         Coyote_Utils_Tests.Test_Reads_File_When_Path_Exists'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Coyote_Utils returns empty when arg is not a file",
         Coyote_Utils_Tests.Test_Returns_Arg_When_Not_A_File'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Coyote_Utils returns empty for empty path",
         Coyote_Utils_Tests.Test_Returns_Empty_For_Empty_Path'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Coyote_Utils reads multiline file",
         Coyote_Utils_Tests.Test_Reads_Multiline_File'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Coyote_Utils Strip_Session_Prefix removes coyote-session+ prefix",
         Coyote_Utils_Tests
           .Test_Strip_Session_Prefix_With_Prefix'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Coyote_Utils Strip_Session_Prefix returns input unchanged "
         & "when prefix absent",
         Coyote_Utils_Tests
           .Test_Strip_Session_Prefix_Without_Prefix'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Coyote_Utils Strip_Session_Prefix returns empty for empty input",
         Coyote_Utils_Tests.Test_Strip_Session_Prefix_Empty'Access));

      --  LLM.HTTP tests
      Result.Add_Test (LLM_HTTP_Caller.Create
        ("LLM.HTTP POST returns status and callback chunk",
         LLM_HTTP_Tests.Test_Post_Status_And_Chunk'Access));
      Result.Add_Test (LLM_HTTP_Caller.Create
        ("LLM.HTTP GET returns status and callback chunk",
         LLM_HTTP_Tests.Test_Get_Status_And_Chunk'Access));
      Result.Add_Test (LLM_HTTP_Caller.Create
        ("LLM.HTTP POST non-200 returns status and body",
         LLM_HTTP_Tests.Test_HTTP_Non_200_Returns_Status_And_Body'Access));

      --  LLM.Settings tests
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings loads defaults from settings.json",
         LLM_Settings_Tests.Test_Load_Settings'Access));
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings loads appendSystemPrompt from settings.json",
         LLM_Settings_Tests.Test_Append_System_Prompt_Loaded'Access));
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings Append_System_Prompt defaults to empty",
         LLM_Settings_Tests.Test_Append_System_Prompt_Missing'Access));
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings Append_Prompt parameter appears in built prompt",
         LLM_Settings_Tests.Test_Append_Prompt_In_Built_Prompt'Access));
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings Resolve_Api_Key prefers models.json literal value",
         LLM_Settings_Tests.Test_Resolve_Api_Key_Literal'Access));
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings Resolve_Api_Key supports ${ENV_VAR} interpolation",
         LLM_Settings_Tests.Test_Resolve_Api_Key_Interpolated_Env'Access));
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings Resolve_Api_Key falls back to standard env map",
         LLM_Settings_Tests.Test_Resolve_Api_Key_Default_Env'Access));

      --  LLM.Types tests
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types text block stores text content",
         LLM_Types_Tests.Test_Text_Block'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types thinking block stores thinking content",
         LLM_Types_Tests.Test_Thinking_Block'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types tool-call block stores id/name/arguments",
         LLM_Types_Tests.Test_Tool_Call_Block'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types tool-result block stores result and error flag",
         LLM_Types_Tests.Test_Tool_Result_Block'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types compaction summary messages preserve role and text",
         LLM_Types_Tests.Test_Compaction_Summary_Role'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types usage values add field-by-field",
         LLM_Types_Tests.Test_Usage_Addition'Access));
      Result.Add_Test (LLM_Types_Caller.Create
        ("LLM.Types message vectors append and preserve values",
         LLM_Types_Tests.Test_Message_Vectors'Access));

      --  LLM.Compaction tests
      Result.Add_Test (LLM_Compaction_Caller.Create
        ("LLM.Compaction estimates message tokens conservatively",
         LLM_Compaction_Tests.Test_Estimate_Tokens'Access));
      Result.Add_Test (LLM_Compaction_Caller.Create
        ("LLM.Compaction estimates context tokens from usage or heuristics",
         LLM_Compaction_Tests.Test_Estimate_Context_Tokens'Access));
      Result.Add_Test (LLM_Compaction_Caller.Create
        ("LLM.Compaction decides when to compact",
         LLM_Compaction_Tests.Test_Should_Compact'Access));
      Result.Add_Test (LLM_Compaction_Caller.Create
        ("LLM.Compaction finds safe user-turn cut points",
         LLM_Compaction_Tests.Test_Find_Cut_Point'Access));
      Result.Add_Test (LLM_Compaction_Caller.Create
        ("LLM.Compaction serialises conversations for summarisation",
         LLM_Compaction_Tests.Test_Serialize_Conversation'Access));
      Result.Add_Test (LLM_Compaction_Caller.Create
        ("LLM.Compaction tracks read and modified files",
         LLM_Compaction_Tests.Test_Track_File_Ops'Access));
      Result.Add_Test (LLM_Compaction_Caller.Create
        ("LLM.Compaction builds a realistic compaction candidate",
         LLM_Compaction_Tests.Test_Full_Compaction_Candidate'Access));
      Result.Add_Test (LLM_Compaction_Caller.Create
        ("LLM.Compaction tracks file ops across multiple turns",
         LLM_Compaction_Tests.Test_Track_File_Ops_Multi_Turn'Access));

      --  LLM.Session_Store tests
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store New_UUID returns RFC 4122 v4 text",
         LLM_Session_Store_Tests.Test_New_UUID_Format'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store New_UUID returns unique values",
         LLM_Session_Store_Tests.Test_New_UUID_Unique'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store Create_Session writes a parseable header",
         LLM_Session_Store_Tests.Test_Create_Session_Header'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store user messages round-trip through disk",
         LLM_Session_Store_Tests.Test_User_Round_Trip'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store assistant tool calls round-trip through disk",
         LLM_Session_Store_Tests.Test_Assistant_Tool_Call'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store assistant thinking+text round-trips",
         LLM_Session_Store_Tests
           .Test_Assistant_Thinking_Text_Round_Trip'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store tool results round-trip through disk",
         LLM_Session_Store_Tests.Test_Tool_Result_Round_Trip'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store native sessions can be forked",
         LLM_Session_Store_Tests.Test_Fork_Session_Native_Source'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store loads legacy envelope lines",
         LLM_Session_Store_Tests.Test_Load_Legacy_Pi_Envelope_Lines'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store skips malformed JSONL lines",
         LLM_Session_Store_Tests.Test_Load_Skips_Malformed_Lines'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store persists assistant usage and stop reason",
         LLM_Session_Store_Tests
           .Test_Assistant_Usage_And_Stop_Reason_Persist'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store appends compaction records to JSONL",
         LLM_Session_Store_Tests
           .Test_Append_Compaction_Writes_Entry'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store rejects persisted compaction summary messages",
         LLM_Session_Store_Tests
           .Test_Compaction_Summary_Not_Persisted'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store loads synthetic history around compaction",
         LLM_Session_Store_Tests
           .Test_Load_With_Compaction_Entry'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store keeps legacy load behaviour without compaction",
         LLM_Session_Store_Tests
           .Test_Load_Without_Compaction_Unchanged'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store append/load compaction round-trips",
         LLM_Session_Store_Tests
           .Test_Append_Then_Load_Round_Trip'Access));

      --  LLM.SSE tests
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

      --  LLM.Tools tests
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Bash executes a successful command",
         LLM_Tools_Tests.Test_Bash_Success'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Bash reports a non-zero exit status",
         LLM_Tools_Tests.Test_Bash_Failure'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.File_Ops read returns file contents",
         LLM_Tools_Tests.Test_Read'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.File_Ops write creates files and directories",
         LLM_Tools_Tests.Test_Write'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.File_Ops edit replaces a unique match",
         LLM_Tools_Tests.Test_Edit_Unique'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.File_Ops edit rejects non-unique matches",
         LLM_Tools_Tests.Test_Edit_Non_Unique'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.File_Ops edit rejects missing matches",
         LLM_Tools_Tests.Test_Edit_Missing'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.File_Ops find walks fixture directories",
         LLM_Tools_Tests.Test_Find'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Built_In_Tools includes spawn_subagent",
         LLM_Tools_Tests
           .Test_Built_In_Tools_Include_Spawn_Subagent'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools dispatches spawn_subagent and returns output",
         LLM_Tools_Tests.Test_Spawn_Subagent_Success'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools spawn_subagent rejects missing prompt",
         LLM_Tools_Tests.Test_Spawn_Subagent_Requires_Prompt'Access));

      --  LLM.Tools.Spawn_Subagent tests
      Result.Add_Test (LLM_Spawn_Subagent_Caller.Create
        ("LLM.Tools.Spawn_Subagent rejects malformed JSON",
         LLM_Spawn_Subagent_Tests.Test_Bad_Json'Access));
      Result.Add_Test (LLM_Spawn_Subagent_Caller.Create
        ("LLM.Tools.Spawn_Subagent rejects an empty prompt",
         LLM_Spawn_Subagent_Tests.Test_Empty_Prompt'Access));
      Result.Add_Test (LLM_Spawn_Subagent_Caller.Create
        ("LLM.Tools.Spawn_Subagent reports missing coyote binary",
         LLM_Spawn_Subagent_Tests.Test_Binary_Not_Found'Access));
      Result.Add_Test (LLM_Spawn_Subagent_Caller.Create
        ("LLM.Tools.Spawn_Subagent returns an error when aborted",
         LLM_Spawn_Subagent_Tests.Test_Abort_Before_Spawn'Access));

      --  LLM.Providers.OpenAI_Completions tests
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions streams text SSE responses",
         LLM_OpenAI_Completions_Tests.Test_Stream_Text_Response'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions streams and assembles tool calls",
         LLM_OpenAI_Completions_Tests
           .Test_Stream_Tool_Call_Response'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions assembles multiple indexed tool calls",
         LLM_OpenAI_Completions_Tests
           .Test_Stream_Multi_Tool_Response'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions emits thinking deltas from reasoning",
         LLM_OpenAI_Completions_Tests
           .Test_Stream_Thinking_Response'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions encodes compaction summaries as user",
         LLM_OpenAI_Completions_Tests
           .Test_Compaction_Summary_Encodes_As_User_OpenAI'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions parses non-streaming JSON responses",
         LLM_OpenAI_Completions_Tests
           .Test_Non_Streaming_Response'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions parses non-streaming tool calls",
         LLM_OpenAI_Completions_Tests
           .Test_OpenAI_Non_Streaming_Tool_Calls'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions propagates HTTP errors",
         LLM_OpenAI_Completions_Tests
           .Test_OpenAI_HTTP_Error_Propagates'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions finalizes early-terminated streams",
         LLM_OpenAI_Completions_Tests
           .Test_OpenAI_Stream_Terminates_Early'Access));

      --  LLM.Auth tests
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth loads GitHub Copilot credentials from auth.json",
         LLM_Auth_Tests.Test_Load_Credentials'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth saves credentials atomically and preserves other providers",
         LLM_Auth_Tests.Test_Save_Credentials'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth.GitHub_Copilot detects expired and valid tokens",
         LLM_Auth_Tests.Test_Token_Expired'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth.GitHub_Copilot parses proxy-ep into the API base URL",
         LLM_Auth_Tests.Test_Get_Base_Url'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth.GitHub_Copilot falls back to the default base URL",
         LLM_Auth_Tests.Test_Get_Base_Url_Fallback'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth.GitHub_Copilot refreshes and persists the API token",
         LLM_Auth_Tests.Test_Refresh_Token'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth.GitHub_Copilot raises on non-200 refresh responses",
         LLM_Auth_Tests.Test_Refresh_Token_Non_200_Raises'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth.GitHub_Copilot raises on invalid JSON refresh responses",
         LLM_Auth_Tests.Test_Refresh_Token_Invalid_JSON_Raises'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth.GitHub_Copilot raises when token is missing",
         LLM_Auth_Tests.Test_Refresh_Token_Missing_Token_Field_Raises
           'Access));
      Result.Add_Test (LLM_Auth_Caller.Create
        ("LLM.Auth.GitHub_Copilot raises when expires_at is missing",
         LLM_Auth_Tests
           .Test_Refresh_Token_Missing_Expires_At_Field_Raises'Access));

      --  LLM.Providers.GitHub_Copilot.Catalogue tests
      Result.Add_Test (LLM_Catalogue_Caller.Create
        ("LLM.Catalogue loads and parses a fresh cached Copilot model list",
         LLM_Catalogue_Tests.Test_Load_From_Fresh_Cache'Access));
      Result.Add_Test (LLM_Catalogue_Caller.Create
        ("LLM.Catalogue uses live fetch when the Copilot cache is stale",
         LLM_Catalogue_Tests.Test_Stale_Cache_Triggers_Live_Fetch'Access));
      Result.Add_Test (LLM_Catalogue_Caller.Create
        ("LLM.Catalogue falls back to a stale cache on fetch failure",
         LLM_Catalogue_Tests.Test_Stale_Cache_Fallback'Access));

      --  LLM.Providers.OpenRouter tests
      Result.Add_Test (LLM_OpenRouter_Caller.Create
        ("LLM.OpenRouter sends the OpenRouter auth and metadata headers",
         LLM_OpenRouter_Tests.Test_Send_Adds_OpenRouter_Headers'Access));
      Result.Add_Test (LLM_OpenRouter_Caller.Create
        ("LLM.OpenRouter adds reasoning.effort for reasoning models",
         LLM_OpenRouter_Tests.Test_Send_Includes_Reasoning_Effort'Access));
      Result.Add_Test (LLM_OpenRouter_Caller.Create
        ("LLM.OpenRouter refreshes a stale cache before sending",
         LLM_OpenRouter_Tests
           .Test_OpenRouter_Stale_Cache_Fetches_Live_Then_Sends'Access));
      Result.Add_Test (LLM_OpenRouter_Caller.Create
        ("LLM.OpenRouter falls back to models.json for the API key",
         LLM_OpenRouter_Tests
           .Test_OpenRouter_Settings_Api_Key_Fallback'Access));

      --  LLM.Providers.OpenRouter.Catalogue tests
      Result.Add_Test (LLM_OpenRouter_Catalogue_Caller.Create
        ("LLM.OpenRouter.Catalogue loads and parses a fresh cached model list",
         LLM_OpenRouter_Catalogue_Tests.Test_Load_From_Fresh_Cache'Access));
      Result.Add_Test (LLM_OpenRouter_Catalogue_Caller.Create
        ("LLM.OpenRouter.Catalogue uses live fetch when the cache is stale",
         LLM_OpenRouter_Catalogue_Tests
           .Test_Stale_Cache_Triggers_Live_Fetch'Access));
      Result.Add_Test (LLM_OpenRouter_Catalogue_Caller.Create
        ("LLM.OpenRouter.Catalogue falls back to stale cache on fetch failure",
         LLM_OpenRouter_Catalogue_Tests.Test_Stale_Cache_Fallback'Access));

      --  LLM.Providers.Anthropic_Messages tests
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages streams thinking and text SSE responses",
         LLM_Anthropic_Messages_Tests
           .Test_Stream_Thinking_And_Text_Response'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages sends required Anthropic headers",
         LLM_Anthropic_Messages_Tests.Test_Request_Headers'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages injects the correct thinking budget",
         LLM_Anthropic_Messages_Tests
           .Test_Thinking_Budget_Injection'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages encodes compaction summaries as user",
         LLM_Anthropic_Messages_Tests
           .Test_Compaction_Summary_Encodes_As_User_Anthropic'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages streams tool_use blocks",
         LLM_Anthropic_Messages_Tests
           .Test_Stream_Tool_Use_Response'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages maps alternate stop reasons",
         LLM_Anthropic_Messages_Tests
           .Test_Stop_Reason_Mappings'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages uses x-api-key for Anthropic-style URLs",
         LLM_Anthropic_Messages_Tests
           .Test_Anthropic_Uses_X_Api_Key_Header'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages propagates HTTP errors",
         LLM_Anthropic_Messages_Tests
           .Test_Anthropic_HTTP_Error_Propagates'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages finalizes early-terminated streams",
         LLM_Anthropic_Messages_Tests
           .Test_Anthropic_Stream_Terminates_Early'Access));

      --  LLM.Providers.GitHub_Copilot tests
      Result.Add_Test (LLM_GitHub_Copilot_Caller.Create
        ("LLM.GitHub_Copilot adds the static Copilot headers",
         LLM_GitHub_Copilot_Tests.Test_Send_Adds_Static_Headers'Access));
      Result.Add_Test (LLM_GitHub_Copilot_Caller.Create
        ("LLM.GitHub_Copilot sets X-Initiator=user for user prompts",
         LLM_GitHub_Copilot_Tests.Test_Send_Sets_X_Initiator_User'Access));
      Result.Add_Test (LLM_GitHub_Copilot_Caller.Create
        ("LLM.GitHub_Copilot sets X-Initiator=agent for agent prompts",
         LLM_GitHub_Copilot_Tests.Test_Send_Sets_X_Initiator_Agent'Access));
      Result.Add_Test (LLM_GitHub_Copilot_Caller.Create
        ("LLM.GitHub_Copilot selects Anthropic Messages for Claude models",
         LLM_GitHub_Copilot_Tests.Test_Send_Selects_Anthropic_Path'Access));
      Result.Add_Test (LLM_GitHub_Copilot_Caller.Create
        ("LLM.GitHub_Copilot selects OpenAI completions for GPT models",
         LLM_GitHub_Copilot_Tests.Test_Send_Selects_OpenAI_Path'Access));
      Result.Add_Test (LLM_GitHub_Copilot_Caller.Create
        ("LLM.GitHub_Copilot refreshes expired tokens before sending",
         LLM_GitHub_Copilot_Tests
           .Test_Copilot_Refreshes_Expired_Token_Then_Sends'Access));

      --  LLM.Model_Registry tests
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry marks Claude Copilot models as Anthropic",
         LLM_Model_Registry_Tests
           .Test_GitHub_Copilot_Anthropic_Wire_Format'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry marks GPT Copilot models as OpenAI",
         LLM_Model_Registry_Tests
           .Test_GitHub_Copilot_OpenAI_Wire_Format'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry raises Not_Found for unknown Copilot ids",
         LLM_Model_Registry_Tests.Test_GitHub_Copilot_Not_Found'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry preserves OpenRouter model pricing",
         LLM_Model_Registry_Tests.Test_OpenRouter_Cost_Loaded'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry defaults unknown OpenRouter ids",
         LLM_Model_Registry_Tests.Test_OpenRouter_Default_Fallback'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry raises Not_Found for unknown providers",
         LLM_Model_Registry_Tests.Test_Unknown_Provider_Not_Found'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry filters Available_Models by credentials",
         LLM_Model_Registry_Tests.Test_Available_Models_Filtering'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry adds Anthropic models only with credentials",
         LLM_Model_Registry_Tests.Test_Anthropic_Available_Models'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry Available_Models returns sorted order",
         LLM_Model_Registry_Tests.Test_Available_Models_Sorted'Access));

      --  LLM.Agent tests
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent runs a single-turn prompt and persists it",
         LLM_Agent_Tests.Test_Single_Turn_Prompt'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent executes a tool call and loops for the final reply",
         LLM_Agent_Tests.Test_Tool_Call_Loop'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent executes two tool calls in one turn",
         LLM_Agent_Tests.Test_Two_Tool_Call_Loop'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent preserves tool execution failures",
         LLM_Agent_Tests.Test_Tool_Execution_Failure'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Switch_Session pre-loads existing history",
         LLM_Agent_Tests.Test_Switch_Session_Loads_History'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent honours cross-task abort requests",
         LLM_Agent_Tests.Test_Abort_Request'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent keeps aborted multi-tool history structurally valid",
         LLM_Agent_Tests.Test_Abort_Batched_Tools_Keep_History_Valid'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent writes assistant turns only after the turn"
         & " completes",
         LLM_Agent_Tests.
           Test_Session_File_Written_Only_After_Turn_End'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent resumes persisted session history",
         LLM_Agent_Tests.Test_Session_Resume'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent uses settings defaults when Model_Spec is empty",
         LLM_Agent_Tests
           .Test_Create_Without_Model_Spec_Uses_Settings_Default'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent reuses history across multiple turns in one session",
         LLM_Agent_Tests
           .Test_Multi_Turn_Same_Session_Carries_History'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent New_Session clears history and creates a fresh file",
         LLM_Agent_Tests
           .Test_New_Session_Clears_History_And_Uses_Fresh_File'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent emits model/start/update/end/stats in order",
         LLM_Agent_Tests
           .Test_Event_Sequence_Agent_Start_Through_Session_Stats'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent turns unknown tool calls into tool errors",
         LLM_Agent_Tests
           .Test_Unknown_Tool_Becomes_Error_And_Agent_Continues'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent retries HTTP 500 errors and succeeds on retry",
         LLM_Agent_Tests
           .Test_Auto_Retry_On_HTTP_500_Then_Success'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent detects known context-overflow error phrases",
         LLM_Agent_Tests
           .Test_Is_Context_Overflow_Error_Detects_Known_Phrases'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent compacts and retries after a context overflow",
         LLM_Agent_Tests
           .Test_Overflow_Triggers_Compact_And_Retry'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent gives up after one overflow recovery attempt",
         LLM_Agent_Tests
           .Test_Overflow_Recovery_Not_Attempted_Twice'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent emits a compaction will-retry event on overflow",
         LLM_Agent_Tests
           .Test_Overflow_Will_Retry_Event_Emitted'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Compact replaces old history with a summary message",
         LLM_Agent_Tests
           .Test_Compact_Produces_Summary_Message'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Compact emits compaction start and end events",
         LLM_Agent_Tests
           .Test_Compact_Emits_Start_And_End_Events'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Compact aborts cleanly on very short history",
         LLM_Agent_Tests
           .Test_Compact_Short_History_Aborts'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Compact persists a resumable compaction entry",
         LLM_Agent_Tests
           .Test_Compact_Persists_Entry'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent auto-compacts when the context threshold is reached",
         LLM_Agent_Tests
           .Test_Auto_Compact_Fires_At_Threshold'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent skips auto-compaction below the context threshold",
         LLM_Agent_Tests
           .Test_Auto_Compact_Does_Not_Fire_Below_Threshold'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent persists threshold-triggered compaction entries",
         LLM_Agent_Tests
           .Test_Auto_Compact_Session_Persisted_After_Threshold'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Compact survives a session reload round-trip",
         LLM_Agent_Tests
           .Test_Compact_Then_Resume'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("[live] LLM.Agent Compact summarises a GitHub Copilot conversation",
         LLM_Agent_Tests
           .Test_Compact_Live_Summarises_Conversation'Access));
      Result.Add_Test (LLM_Parallel_Caller.Create
        ("Parallel batch: two 0.4 s tools complete in < 0.75 s",
         LLM_Parallel_Tools_Tests
           .Test_Parallel_Tools_Run_Concurrently'Access));
      Result.Add_Test (LLM_Parallel_Caller.Create
        ("Parallel batch: abort during batch sets Was_Aborted",
         LLM_Parallel_Tools_Tests
           .Test_Parallel_Abort_During_Batch'Access));

      return Result;
   end Suite;

end Test_Suites;
