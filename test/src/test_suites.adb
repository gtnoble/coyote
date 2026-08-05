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
with Collapse_Utils_Tests;
with Coyote_Utils_Tests;
with Coyote_Cmark_Tests;
with Coyote_GUI_Conversation_Tests;
with Coyote_GUI_Updates_Tests;
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
with Coyote_SQC_Statistics_Tests;
with Coyote_SQC_Parser_Tests;
with Coyote_SQC_Workspace_Tests;
with Coyote_SQC_Histogram_Tests;
with Coyote_SQC_JSD_Tests;
with Coyote_SQC_MI_Tests;
with Coyote_SQC_Integrity_Tests;
with Coyote_SQC_Quantile_CC_Tests;
with LLM_SSE_Tests;
with LLM_Tools_Tests;
with LLM_OpenAI_Completions_Tests;
with LLM_Auth_Tests;
with LLM_Catalogue_Tests;
with LLM_OpenRouter_Tests;
with LLM_OpenRouter_Catalogue_Tests;
with LLM_Anthropic_Messages_Tests;
with LLM_GitHub_Copilot_Tests;
with LLM_Model_Registry_Tests;
with LLM_OpenCode_Go_Catalogue_Tests;
with LLM_Session_Store_Tests;
with LLM_Agent_Tests;
with LLM_Parallel_Tools_Tests;
with Sandbox_Tests;

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
   package Collapse_Utils_Caller is
     new AUnit.Test_Caller (Collapse_Utils_Tests.Test);
   package Coyote_Cmark_Caller is
     new AUnit.Test_Caller (Coyote_Cmark_Tests.Test);
   package Coyote_GUI_Conversation_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Conversation_Tests.Test);
   package Coyote_GUI_Updates_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Updates_Tests.Test);
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
   package LLM_OpenCode_Go_Catalogue_Caller is
     new AUnit.Test_Caller (LLM_OpenCode_Go_Catalogue_Tests.Test);
   package LLM_Session_Store_Caller is
     new AUnit.Test_Caller (LLM_Session_Store_Tests.Test);
   package LLM_Agent_Caller is
     new AUnit.Test_Caller (LLM_Agent_Tests.Test);
   package LLM_Parallel_Caller is
     new AUnit.Test_Caller (LLM_Parallel_Tools_Tests.Test);
   package Sandbox_Caller is
     new AUnit.Test_Caller (Sandbox_Tests.Test);
   package SQC_Statistics_Caller is
     new AUnit.Test_Caller (Coyote_SQC_Statistics_Tests.Test);
   package SQC_Parser_Caller is
     new AUnit.Test_Caller (Coyote_SQC_Parser_Tests.Test);
   package SQC_Workspace_Caller is
     new AUnit.Test_Caller (Coyote_SQC_Workspace_Tests.Test);
   package SQC_Histogram_Caller is
     new AUnit.Test_Caller (Coyote_SQC_Histogram_Tests.Test);
   package SQC_JSD_Caller is
     new AUnit.Test_Caller (Coyote_SQC_JSD_Tests.Test);
   package SQC_Integrity_Caller is
     new AUnit.Test_Caller (Coyote_SQC_Integrity_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   package SQC_Quantile_CC_Caller is
     new AUnit.Test_Caller (Coyote_SQC_Quantile_CC_Tests.Test);
   package SQC_MI_Caller is
     new AUnit.Test_Caller (Coyote_SQC_MI_Tests.Test);
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
        ("[integration] Dispatch tool_execution_end cancelled closes block",
         Dispatch_Tests.Test_Dispatch_Tool_End_Cancelled'Access));
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
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch Agent_Paused_Event sets Is_Paused",
         Dispatch_Tests.Test_Dispatch_Agent_Paused_Event'Access));
      Result.Add_Test (Dispatch_Caller.Create
        ("[integration] Dispatch Agent_Resumed_Event clears Is_Paused",
         Dispatch_Tests.Test_Dispatch_Agent_Resumed_Event'Access));

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
        ("Parse_Session_File extracts Parent_Id from header",
         Session_Lister_Tests.Test_Parse_Session_Parent_Id'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Parse_Session_File leaves Parent_Id empty when absent",
         Session_Lister_Tests.Test_Parse_Session_No_Parent_Id'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Parse_Session_File: Is_Fork True when relation is fork",
         Session_Lister_Tests.Test_Parse_Session_Is_Fork_True'Access));
      Result.Add_Test (Session_Lister_Caller.Create
        ("Parse_Session_File: Is_Fork False when relation is subagent",
         Session_Lister_Tests.Test_Parse_Session_Is_Fork_False'Access));
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
        ("Parse_Fork_Token: with step suffix",
         Coyote_App_Tests.Test_Parse_Fork_Token_With_Step'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Turn_Footer: step-level separator",
         Coyote_App_Tests.Test_Format_Turn_Footer_Display_Step'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Step increment",
         Coyote_App_Tests.Test_State_Turn_Step_Increment'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Step set",
         Coyote_App_Tests.Test_State_Turn_Step_Set'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Turn_Step reset",
         Coyote_App_Tests.Test_State_Turn_Step_Reset'Access));
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
      Result.Add_Test (App_State_Caller.Create
        ("Tool_Segment line count: LF-count + 1 = display lines",
         Coyote_App_Tests.Test_Tool_Segment_Line_Count'Access));

      --  Format_SI_Count
      Result.Add_Test (App_State_Caller.Create
        ("Format_SI_Count: values below 1000 returned as decimal",
         Coyote_App_Tests.Test_Format_SI_Count_Below_Threshold'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_SI_Count: exact multiples of 1000 use ""k"" suffix",
         Coyote_App_Tests.Test_Format_SI_Count_Round_Numbers'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_SI_Count: non-zero hundredths produce ""N.FFk"" form",
         Coyote_App_Tests.Test_Format_SI_Count_Fractional'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_SI_Count: values >= 1 000 000 use ""M"" suffix",
         Coyote_App_Tests.Test_Format_SI_Count_M_Range'Access));

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

      --  Format_Model_Price
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: all zeros returns empty string",
         Coyote_App_Tests.Test_Format_Model_Price_All_Zeros'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: in/out only produces two SI Âµ segments",
         Coyote_App_Tests.Test_Format_Model_Price_In_Out_Only'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: all four fields, four SI-prefixed segments",
         Coyote_App_Tests.Test_Format_Model_Price_All_Four'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: zero cache fields are silently omitted",
         Coyote_App_Tests.Test_Format_Model_Price_Omits_Zeros'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Model_Price: cache-read-only produces nano cr segment",
         Coyote_App_Tests.Test_Format_Model_Price_Cache_Only'Access));

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

      --  Apply_Prompt_Filter
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: empty filter returns raw unchanged",
         Coyote_App_Tests.Test_Apply_Filter_Empty_Filter'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: cat filter echoes prompt back",
         Coyote_App_Tests.Test_Apply_Filter_Echo'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: tr filter transforms prompt to uppercase",
         Coyote_App_Tests.Test_Apply_Filter_Transform'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: non-zero exit falls back to raw with warning",
         Coyote_App_Tests.Test_Apply_Filter_Non_Zero_Exit'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: empty stdout falls back to raw with warning",
         Coyote_App_Tests.Test_Apply_Filter_Empty_Output'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Apply_Prompt_Filter: output is trimmed of surrounding whitespace",
         Coyote_App_Tests.Test_Apply_Filter_Trims_Whitespace'Access));

      --  App_State Prompt_Filter
      Result.Add_Test (App_State_Caller.Create
        ("App_State Prompt_Filter initial value is empty",
         Coyote_App_Tests.Test_State_Prompt_Filter_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Prompt_Filter round-trip via Set_Prompt_Filter",
         Coyote_App_Tests.Test_State_Prompt_Filter_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Paused initial value is False",
         Coyote_App_Tests.Test_State_Is_Paused_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Paused toggles via Set_Paused",
         Coyote_App_Tests.Test_State_Is_Paused_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Pause_Armed initial value is False",
         Coyote_App_Tests.Test_State_Is_Pause_Armed_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Is_Pause_Armed toggles via Set_Pause_Armed",
         Coyote_App_Tests.Test_State_Is_Pause_Armed_Set_And_Clear'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Session_List: flat list has no tree connectors",
         Coyote_App_Tests.Test_Format_Session_List_Flat'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Session_List: child indented under parent",
         Coyote_App_Tests.Test_Format_Session_List_Parent_Child'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Session_List: grandchild indented two levels",
         Coyote_App_Tests.Test_Format_Session_List_Deep'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Session_List: orphaned subagent rendered as root",
         Coyote_App_Tests.Test_Format_Session_List_Orphan'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Session_List: multiple children ordered after parent",
         Coyote_App_Tests.Test_Format_Session_List_Multi_Child'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Session_List: subagent child uses hook connector",
         Coyote_App_Tests.Test_Format_Session_List_Subagent_Uses_Hook'Access));
      Result.Add_Test (App_State_Caller.Create
        ("Format_Session_List: fork child uses branch connector",
         Coyote_App_Tests.Test_Format_Session_List_Fork_Uses_Branch'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Tag_Suffix initial value is empty",
         Coyote_App_Tests.Test_State_Tag_Suffix_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Tag_Suffix round-trip via Set_Tag_Suffix",
         Coyote_App_Tests.Test_State_Tag_Suffix_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Current_Sandbox initial value is empty",
         Coyote_App_Tests.Test_State_Sandbox_Initial'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Current_Sandbox round-trip via Set_Sandbox",
         Coyote_App_Tests.Test_State_Sandbox_Round_Trip'Access));
      Result.Add_Test (App_State_Caller.Create
        ("App_State Set_Sandbox to empty clears the profile",
         Coyote_App_Tests.Test_State_Sandbox_Clear'Access));
      --  GFM (libcmark-gfm) table parsing
      Result.Add_Test (App_State_Caller.Create
        ("GFM cmark: table input produces node with type_string 'table'",
         Coyote_App_Tests.Test_Cmark_GFM_Table_Parsed'Access));
      Result.Add_Test (App_State_Caller.Create
        ("GFM cmark: paragraph still has type_string 'paragraph'",
         Coyote_App_Tests.Test_Cmark_Paragraph_Type_String'Access));

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
      Result.Add_Test (Subagent_Int_Caller.Create
        ("[subagent] Prompt-failure one-shot still returns session_id",
         Subagent_Integration_Tests
           .Test_One_Shot_Prompt_Failure_Has_Session_Id'Access));

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
        ("LLM.System_Prompt agent appended to prompt",
         LLM_System_Prompt_Tests
           .Test_Agent_Appended'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt agent prompt appears in built prompt",
         LLM_System_Prompt_Tests
           .Test_Agent_Prompt_Appears'Access));
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
        ("LLM.System_Prompt default prompt contains current shell",
         LLM_System_Prompt_Tests.Test_Default_Prompt_Contains_Shell'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt preserves section order",
         LLM_System_Prompt_Tests.Test_Section_Order'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt memory block injected when provided",
         LLM_System_Prompt_Tests.Test_Memory_Block_Injected'Access));
      Result.Add_Test (LLM_Sys_Prompt_Caller.Create
        ("LLM.System_Prompt empty memory block absent from prompt",
         LLM_System_Prompt_Tests.Test_Memory_Block_Absent_When_Empty'Access));

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
        ("LLM.System_Prompt Load_Context_Sections: global before project",
         LLM_Context_Tests.Test_Global_Before_Project'Access));
      Result.Add_Test (LLM_Context_Caller.Create
        ("LLM.System_Prompt Load_Context_Sections: project before AGENTS",
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
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Install_Base derives prefix from bin/coyote",
         LLM_Skills_Tests.Test_Install_Base_Bin_Coyote'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Install_Base returns empty for non-bin path",
         LLM_Skills_Tests.Test_Install_Base_Non_Standard'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Install_Base uses explicit Executable arg",
         LLM_Skills_Tests.Test_Install_Base_Explicit_Arg'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Installation_Skills_Base appends path",
         LLM_Skills_Tests.Test_Installation_Skills_Base_Path'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills Installation_Skills_Base returns empty for non-bin",
         LLM_Skills_Tests.Test_Installation_Skills_Base_Empty'Access));
      Result.Add_Test (LLM_Skills_Caller.Create
        ("LLM.Skills install-root skills not loaded when bin/ absent",
         LLM_Skills_Tests.Test_Install_Root_Skills_Loaded'Access));

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
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Sanitize_UTF8 passes through pure ASCII unchanged",
         Coyote_Utils_Tests.Test_Sanitize_UTF8_Passthrough_Pure_ASCII'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Sanitize_UTF8 passes through valid multi-byte UTF-8",
         Coyote_Utils_Tests.Test_Sanitize_UTF8_Passthrough_Valid_UTF8'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Sanitize_UTF8 replaces Latin-1 text with U+FFFD",
         Coyote_Utils_Tests.Test_Sanitize_UTF8_Replaces_Latin1_Mojibake'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Sanitize_UTF8 replaces isolated continuation bytes",
         Coyote_Utils_Tests.Test_Sanitize_UTF8_Replaces_Isolated_Cont'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Sanitize_UTF8 replaces truncated multi-byte sequences",
         Coyote_Utils_Tests.Test_Sanitize_UTF8_Replaces_Truncated_Seq'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Sanitize_UTF8 replaces overlong encoding with U+FFFD",
         Coyote_Utils_Tests.Test_Sanitize_UTF8_Handles_Overlong_Seq'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("Sanitize_UTF8 returns empty string unchanged",
         Coyote_Utils_Tests.Test_Sanitize_UTF8_Handles_Empty_String'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("UTF8_Stream reassembles two-byte sequences",
         Coyote_Utils_Tests.Test_UTF8_Stream_Reassembles_Two_Byte'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("UTF8_Stream reassembles three-byte sequences",
         Coyote_Utils_Tests.Test_UTF8_Stream_Reassembles_Three_Byte'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("UTF8_Stream reassembles four-byte sequences",
         Coyote_Utils_Tests.Test_UTF8_Stream_Reassembles_Four_Byte'Access));
      Result.Add_Test (Coyote_Utils_Caller.Create
        ("UTF8_Stream flushes incomplete sequences",
         Coyote_Utils_Tests.Test_UTF8_Stream_Flushes_Incomplete'Access));

      --  Collapse_Utils tests
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: single-LF collapse to spaces",
         Collapse_Utils_Tests.Test_Collapse_Basic'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: paragraph breaks (LF LF) preserved",
         Collapse_Utils_Tests.Test_Collapse_Paragraph'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: empty input returns empty string",
         Collapse_Utils_Tests.Test_Collapse_Empty'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: no-LF input returned verbatim",
         Collapse_Utils_Tests.Test_Collapse_NoLF'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: leading/trailing whitespace stripped",
         Collapse_Utils_Tests.Test_Collapse_Leading_Trailing_WS'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: spaces preserved as word boundaries",
         Collapse_Utils_Tests.Test_Collapse_Preserves_Spaces'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: OpenAI-style trailing LF stripped",
         Collapse_Utils_Tests.Test_Collapse_OpenAI_Style'Access));
      Result.Add_Test (Collapse_Utils_Caller.Create
        ("Collapse_Thinking_Delta: OpenAI mid-stream LFs become spaces",
         Collapse_Utils_Tests.Test_Collapse_OpenAI_Mid_Stream'Access));


      --  Coyote_Cmark binding tests
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark enum constants are non-negative after elaboration",
         Coyote_Cmark_Tests.Test_Constants_Are_Non_Negative'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark Parse_Document returns non-null root node",
         Coyote_Cmark_Tests.Test_Parse_Returns_Non_Null'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark root node type equals NODE_DOCUMENT",
         Coyote_Cmark_Tests.Test_Root_Type_Is_Document'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark iterator yields TEXT event for plain paragraph",
         Coyote_Cmark_Tests.Test_Iterator_Yields_Text_Event'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark TEXT node literal matches the input word",
         Coyote_Cmark_Tests.Test_Literal_Matches_Input'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark Node_Free and Iter_Free do not raise",
         Coyote_Cmark_Tests.Test_Free_Does_Not_Raise'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark Node_Get_Heading_Level returns correct level",
         Coyote_Cmark_Tests.Test_Heading_Level'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark Node_Get_List_Type returns LIST_BULLET",
         Coyote_Cmark_Tests.Test_List_Type_Is_Bullet'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark Node_Get_List_Type returns LIST_ORDERED",
         Coyote_Cmark_Tests.Test_List_Type_Is_Ordered'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark Node_Get_List_Start returns declared ordinal",
         Coyote_Cmark_Tests.Test_List_Start_Ordinal'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark Node_Get_Literal on code block returns content",
         Coyote_Cmark_Tests.Test_Code_Block_Literal'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark shim returns empty string for null literal",
         Coyote_Cmark_Tests.Test_Get_Literal_Null_Safety'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark event constants are mutually distinct",
         Coyote_Cmark_Tests.Test_Event_Constants_Are_Distinct'Access));
      Result.Add_Test (Coyote_Cmark_Caller.Create
        ("Coyote_Cmark Render_Markdown node-type constants are distinct",
         Coyote_Cmark_Tests.Test_Node_Constants_Are_Distinct'Access));

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
        ("LLM.Settings Agent parameter appears in built prompt",
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
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings loads promptFilter from settings.json",
         LLM_Settings_Tests.Test_Prompt_Filter_Loaded'Access));
      Result.Add_Test (LLM_Settings_Caller.Create
        ("LLM.Settings Prompt_Filter defaults to empty when absent",
         LLM_Settings_Tests.Test_Prompt_Filter_Missing'Access));

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
        ("LLM.Types tool-result block stores Media_Type field",
         LLM_Types_Tests.Test_Tool_Result_Block_Media_Type'Access));
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
        ("LLM.Compaction builds a realistic compaction candidate",
         LLM_Compaction_Tests.Test_Full_Compaction_Candidate'Access));

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
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store.Session_Work_Dir returns stored Cwd and empty "
         & "string for missing session or missing field",
         LLM_Session_Store_Tests.Test_Session_Work_Dir'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store.Append_Message handles large tool result without "
         & "secondary-stack overflow",
         LLM_Session_Store_Tests
           .Test_Large_Tool_Result_Round_Trip'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store tool call with invalid args round-trips",
         LLM_Session_Store_Tests
           .Test_Assistant_Tool_Call_Invalid_Args'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store sandboxProfile written to header when set",
         LLM_Session_Store_Tests
           .Test_Sandbox_Profile_Written_To_Header'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store sandboxProfile absent when env var unset",
         LLM_Session_Store_Tests
           .Test_Sandbox_No_Profile_No_Header_Field'Access));
      Result.Add_Test (LLM_Session_Store_Caller.Create
        ("LLM.Session_Store reads sandboxProfile from session header",
         LLM_Session_Store_Tests
           .Test_Sandbox_Profile_Read_From_Header'Access));

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
        ("LLM.Tools.Shell executes a successful command",
         LLM_Tools_Tests.Test_Shell_Success'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell reports a non-zero exit status",
         LLM_Tools_Tests.Test_Shell_Failure'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell pipes stdin text into the command",
         LLM_Tools_Tests.Test_Shell_Stdin_Piped'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell treats empty stdin field as absent",
         LLM_Tools_Tests.Test_Shell_Stdin_Empty_Ignored'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell succeeds without a stdin field",
         LLM_Tools_Tests.Test_Shell_Stdin_Absent_Dev_Null'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold zero returns MAX",
         LLM_Tools_Tests.Test_Result_Threshold_Zero_Returns_Max'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold small clamped to MIN",
         LLM_Tools_Tests.Test_Result_Threshold_Small_Clamped_To_Min'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold 128k yields 64 KB",
         LLM_Tools_Tests.Test_Result_Threshold_Typical_128k'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold 200k yields 100 KB",
         LLM_Tools_Tests.Test_Result_Threshold_Typical_200k'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Result_Threshold large clamped to MAX",
         LLM_Tools_Tests.Test_Result_Threshold_Large_Clamped_To_Max'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Validate_Arguments accepts valid JSON object",
         LLM_Tools_Tests.Test_Validate_Arguments_Valid_Object'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Validate_Arguments rejects invalid JSON",
         LLM_Tools_Tests.Test_Validate_Arguments_Invalid_Json'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Validate_Arguments rejects non-object JSON",
         LLM_Tools_Tests.Test_Validate_Arguments_Non_Object'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Validate_Arguments rejects empty string",
         LLM_Tools_Tests.Test_Validate_Arguments_Empty_String'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag initial state is not armed and not paused",
         LLM_Tools_Tests.Test_Pause_Flag_Initial_State'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Arm sets Is_Armed",
         LLM_Tools_Tests.Test_Pause_Flag_Arm_Sets_Armed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Unarm cancels a pending Arm",
         LLM_Tools_Tests.Test_Pause_Flag_Unarm_Cancels_Arm'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Fire transitions Armed to Paused",
         LLM_Tools_Tests.Test_Pause_Flag_Fire_Transitions'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Fire without Arm is a no-op",
         LLM_Tools_Tests.Test_Pause_Flag_Fire_No_Op_When_Not_Armed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Release clears Paused",
         LLM_Tools_Tests.Test_Pause_Flag_Release_Clears_Paused'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Pause_Flag Release also clears Armed",
         LLM_Tools_Tests.Test_Pause_Flag_Release_Clears_Armed'Access));

      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell media_type base64-encodes stdout",
         LLM_Tools_Tests.Test_Shell_Media_Type_Sets_Base64_Result'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell media_type on error returns empty Media_Type",
         LLM_Tools_Tests.Test_Shell_Media_Type_Error_Clears_Type'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell absent media_type is plain text",
         LLM_Tools_Tests.Test_Shell_Media_Type_Absent_Is_Plain_Text'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Execute image results bypass truncation cap",
         LLM_Tools_Tests.Test_Execute_Image_Not_Truncated'Access));

      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout finishes before deadline",
         LLM_Tools_Tests.Test_Shell_Timeout_Under'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout kills an over-running command",
         LLM_Tools_Tests.Test_Shell_Timeout_Triggers'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout=0 disables the timer",
         LLM_Tools_Tests.Test_Shell_Timeout_Zero'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell negative timeout is ignored",
         LLM_Tools_Tests.Test_Shell_Timeout_Negative'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout under: elapsed time verifies fast finish",
         LLM_Tools_Tests.Test_Shell_Timeout_Under_Elapsed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout triggers: elapsed time verifies tight window",
         LLM_Tools_Tests.Test_Shell_Timeout_Triggers_Elapsed'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell timeout preserves stdout emitted before kill",
         LLM_Tools_Tests.Test_Shell_Timeout_Preserves_Stdout'Access));
      Result.Add_Test (LLM_Tools_Caller.Create
        ("LLM.Tools.Shell abort preserves stdout emitted before kill",
         LLM_Tools_Tests.Test_Shell_Abort_Preserves_Stdout'Access));
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
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions system message has cache_control",
         LLM_OpenAI_Completions_Tests
           .Test_OpenAI_System_Cache_Control'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions last tool has cache_control breakpoint",
         LLM_OpenAI_Completions_Tests
           .Test_OpenAI_Last_Tool_Cache_Control'Access));
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("LLM.OpenAI_Completions cached_tokens parsed in usage",
         LLM_OpenAI_Completions_Tests
           .Test_OpenAI_Cached_Tokens_In_Usage'Access));

      --  LLM.Auth tests
      Result.Add_Test (LLM_OpenAI_Completions_Caller.Create
        ("OpenAI tool_result image uses image_url data URI format",
         LLM_OpenAI_Completions_Tests
           .Test_Tool_Result_Image_Serialised'Access));
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

      --  Coyote_SQC statistics tests
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: c4(n) matches ASTM E2587 Table 1 reference values",
         Coyote_SQC_Statistics_Tests.Test_C4_Known_Values'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: c4(101) approximation within 0.1% of exact value",
         Coyote_SQC_Statistics_Tests.Test_C4_Approximation'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: c4(1) raises Constraint_Error",
         Coyote_SQC_Statistics_Tests.Test_C4_N1_Raises'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Xbar limits well-formed for n > 1",
         Coyote_SQC_Statistics_Tests.Test_Xbar_Limits_Basic'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Xbar n=1 returns Undefined",
         Coyote_SQC_Statistics_Tests.Test_Xbar_N1_Undefined'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Xbar Pooled_S=0 returns Undefined ; Has_UCL and Has_LCL both False",
         Coyote_SQC_Statistics_Tests.Test_Xbar_Pooled_S_Zero'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: s chart limits well-formed for n > 1",
         Coyote_SQC_Statistics_Tests.Test_S_Chart_Limits_Basic'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: s chart n=1 returns Undefined",
         Coyote_SQC_Statistics_Tests.Test_S_Chart_N1_Undefined'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: S_Chart Pooled_S=0 returns Undefined",
         Coyote_SQC_Statistics_Tests.Test_S_Chart_Pooled_S_Zero'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: s chart LCL clamped to 0 for n=2",
         Coyote_SQC_Statistics_Tests.Test_S_Chart_LCL_Clamped'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: p chart limits well-formed for N > 0",
         Coyote_SQC_Statistics_Tests.Test_P_Chart_Limits_Basic'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: p chart N=0 returns Undefined",
         Coyote_SQC_Statistics_Tests.Test_P_Chart_N0_Undefined'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: p chart LCL clamped to 0 when formula yields negative",
         Coyote_SQC_Statistics_Tests.Test_P_Chart_LCL_Clamped'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Estimate_Parameters grand mean and pooled s (Xbar/s)",
         Coyote_SQC_Statistics_Tests.Test_Estimate_Xbar_S'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Â§14.1: 5-session varying-n dataset UCL/CL/LCL to 4 dp",
         Coyote_SQC_Statistics_Tests.Test_Xbar_Known_Dataset'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Â§14.1: 4-session p-chart dataset UCL/CL/LCL to 4 dp",
         Coyote_SQC_Statistics_Tests.Test_P_Chart_Known_Dataset'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Estimate_Parameters grand p (p chart)",
         Coyote_SQC_Statistics_Tests.Test_Estimate_P_Chart'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Estimate_Parameters all n=1 sessions -> Pooled_S = 0",
         Coyote_SQC_Statistics_Tests.Test_Estimate_N1_Only'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Â§14.1 special: n=1 contributes to grand mean, not pooled s",
         Coyote_SQC_Statistics_Tests.Test_N1_Excluded_From_Pooled_S'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Estimate_Parameters excludes zero-thinking sessions",
         Coyote_SQC_Statistics_Tests.Test_Estimate_Zero_Thinking'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Â§14.3: Estimate_Parameters excludes zero-tool-call sessions",
         Coyote_SQC_Statistics_Tests.Test_Estimate_Zero_Tool_Calls'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Â§14.4: Per_Turn_Tool_Tokens records output tokens for tool-call turns",
         Coyote_SQC_Statistics_Tests.Test_Tool_Call_Token_Values'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: I chart limits well-formed for Mean_MR > 0",
         Coyote_SQC_Statistics_Tests.Test_I_Chart_Limits_Basic'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: I chart LCL positive when grand mean sufficiently large",
         Coyote_SQC_Statistics_Tests.Test_I_Chart_LCL_Positive'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: I chart Mean_MR=0 returns Undefined",
         Coyote_SQC_Statistics_Tests.Test_I_Chart_Mean_MR_Zero'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: I chart LCL clamped to 0 when formula yields negative",
         Coyote_SQC_Statistics_Tests.Test_I_Chart_LCL_Clamped'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: MR chart limits well-formed for Mean_MR > 0",
         Coyote_SQC_Statistics_Tests.Test_MR_Chart_Limits_Basic'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: MR chart Mean_MR=0 returns Undefined",
         Coyote_SQC_Statistics_Tests.Test_MR_Chart_Mean_MR_Zero'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Estimate_Parameters grand mean and Mean_MR (I chart, input tokens)",
         Coyote_SQC_Statistics_Tests.Test_Estimate_I_Chart_Input'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Estimate_Parameters single-session setup -> Mean_MR = 0",
         Coyote_SQC_Statistics_Tests.Test_Estimate_I_Chart_Single'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Box_Cox ln identity",
         Coyote_SQC_Statistics_Tests.Test_Box_Cox_Ln_Identity'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Box_Cox lambda=1 identity",
         Coyote_SQC_Statistics_Tests.Test_Box_Cox_Lambda_One'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Box_Cox round-trip",
         Coyote_SQC_Statistics_Tests.Test_Box_Cox_Round_Trip'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Box_Cox zero raises Constraint_Error",
         Coyote_SQC_Statistics_Tests.Test_Box_Cox_Zero_Raises'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Estimate_Lambda with few observations returns 0",
         Coyote_SQC_Statistics_Tests.Test_Estimate_Lambda_Few_Obs'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("I chart Box-Cox ln: back-transformed limits",
         Coyote_SQC_Statistics_Tests.Test_I_Limits_Box_Cox_Ln'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Box-Cox MR: differences of transformed values",
         Coyote_SQC_Statistics_Tests.Test_Box_Cox_MR_Transformed'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Qn_Scale: N=3 known value",
         Coyote_SQC_Statistics_Tests.Test_Qn_Scale_N3_Known'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Qn_Scale: N=4 known value",
         Coyote_SQC_Statistics_Tests.Test_Qn_Scale_N4_Known'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Qn_Scale: N<2 raises Constraint_Error",
         Coyote_SQC_Statistics_Tests.Test_Qn_Scale_N_Less_2_Raises'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Qn_Scale: zero value raises Constraint_Error",
         Coyote_SQC_Statistics_Tests.Test_Qn_Scale_Zero_Raises'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Qn_Scale: N=20 (even asymptotic) is positive",
         Coyote_SQC_Statistics_Tests.Test_Qn_Scale_Asymptotic_Even'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Qn_Scale: N=11 (odd asymptotic) is positive",
         Coyote_SQC_Statistics_Tests.Test_Qn_Scale_Asymptotic_Odd'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust Estimate_Lambda: fewer than 3 obs returns 0.0",
         Coyote_SQC_Statistics_Tests.
           Test_Estimate_Lambda_Robust_Few_Obs'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust Estimate_Lambda: result in [-2.0, 2.0] on skewed data",
         Coyote_SQC_Statistics_Tests.
           Test_Estimate_Lambda_Robust_Basic'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Estimate_Lambda: all-identical data returns 0.0 with fallback",
         Coyote_SQC_Statistics_Tests.
           Test_Estimate_Lambda_Degenerate'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("EWMA: Compute_Z single step",
         Coyote_SQC_Statistics_Tests.Test_EWMA_Compute_Z_Single_Step'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("EWMA: Compute_Z multi step",
         Coyote_SQC_Statistics_Tests.Test_EWMA_Compute_Z_Multi_Step'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("EWMA: time-varying limits at T=1",
         Coyote_SQC_Statistics_Tests.Test_EWMA_Limits_T1'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("EWMA: limits converge toward steady state",
         Coyote_SQC_Statistics_Tests.Test_EWMA_Limits_Steady_State'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("EWMA: zero sigma gives no limits",
         Coyote_SQC_Statistics_Tests.Test_EWMA_Limits_Zero_Sigma'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("EWMA: LCL clamped to 0 when formula yields negative",
         Coyote_SQC_Statistics_Tests.Test_EWMA_Limits_LCL_Clamped'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: Median_Of basic (odd size)",
         Coyote_SQC_Statistics_Tests.Test_Median_Of_Basic'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: Median_Of even size",
         Coyote_SQC_Statistics_Tests.Test_Median_Of_Even'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: Median_Of single element",
         Coyote_SQC_Statistics_Tests.Test_Median_Of_Single'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: Median_Of empty array returns 0",
         Coyote_SQC_Statistics_Tests.Test_Median_Of_Empty'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: Median_Of unsorted input",
         Coyote_SQC_Statistics_Tests.Test_Median_Of_Unsorted'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: I chart Grand_Mean = median when outlier present",
         Coyote_SQC_Statistics_Tests.Test_Robust_I_Chart_Grand_Mean'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: I chart Mean_MR = median of MRs, I_Sigma = Qn/2.2219",
         Coyote_SQC_Statistics_Tests.Test_Robust_I_Chart_Mean_MR'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: Compute_I_Limits uses Sigma parameter directly (no internal divisor)",
         Coyote_SQC_Statistics_Tests.Test_Robust_I_Limits_Divisor'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: MR chart UCL = D4 * median(MR_i)",
         Coyote_SQC_Statistics_Tests.Test_Robust_MR_UCL'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: Xbar Grand_Mean = unweighted median of session means",
         Coyote_SQC_Statistics_Tests.Test_Robust_Xbar_Grand_Mean'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: Xbar Pooled_S = Qn of pooled residuals (> 0)",
         Coyote_SQC_Statistics_Tests.Test_Robust_Xbar_Pooled_S'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("Robust: p-chart Grand_P unchanged by estimation method",
         Coyote_SQC_Statistics_Tests.Test_Robust_P_Chart_Unchanged'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Fraction_Thinking_Tokens Grand_Mean estimated correctly",
         Coyote_SQC_Statistics_Tests.Test_Fraction_Thinking_Tokens_Grand_Mean'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Fraction_Tool_Call_Tokens Grand_Mean estimated correctly",
         Coyote_SQC_Statistics_Tests.Test_Fraction_Tool_Call_Tokens_Grand_Mean'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: token fraction charts exclude zero-output sessions",
         Coyote_SQC_Statistics_Tests.Test_Fraction_Token_Charts_Zero_Output'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Fraction_Thinking_Per_Tool_Call Grand_Mean estimated correctly",
         Coyote_SQC_Statistics_Tests.Test_Fraction_Thinking_Per_Tool_Call_Grand_Mean'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: Fraction_Uncached_Input Grand_Mean estimated correctly",
         Coyote_SQC_Statistics_Tests.Test_Fraction_Uncached_Input_Grand_Mean'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: new rate charts exclude zero-denominator sessions",
         Coyote_SQC_Statistics_Tests.Test_Fraction_New_Charts_Zero_Denominator'Access));
      --  Coyote_SQC parser tests
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v3 session ID parsed correctly",
         Coyote_SQC_Parser_Tests.Test_V3_Session_Id'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v3 turn count correct",
         Coyote_SQC_Parser_Tests.Test_V3_Turn_Count'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v3 model is last model_change",
         Coyote_SQC_Parser_Tests.Test_V3_Model'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v3 first user message extracted",
         Coyote_SQC_Parser_Tests.Test_V3_First_User_Message'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v3 tool failure flags set correctly",
         Coyote_SQC_Parser_Tests.Test_V3_Tool_Failure_Flags'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC Â§14.2: multi-tool turn N_Tool_Calls=2, N_Failed_Tool_Calls=1",
         Coyote_SQC_Parser_Tests.Test_Multi_Tool_Metrics'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v3 source directory parsed from cwd",
         Coyote_SQC_Parser_Tests.Test_V3_Source_Directory'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v1 legacy session ID parsed correctly",
         Coyote_SQC_Parser_Tests.Test_V1_Session_Id'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v1 source directory parsed from workDir",
         Coyote_SQC_Parser_Tests.Test_V1_Source_Directory'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v1 [Model -> ...] prefix stripped from first user message",
         Coyote_SQC_Parser_Tests.Test_V1_Prompt_Prefix_Strip'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v1 session turn count is 1",
         Coyote_SQC_Parser_Tests.Test_V1_Turn_Count'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v1 start time year is 2025 (createdAt ms -> UTC conversion)",
         Coyote_SQC_Parser_Tests.Test_V1_Start_Time'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v1 session model is empty when no model_change present",
         Coyote_SQC_Parser_Tests.Test_V1_Model'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v1 session has no tool calls (failure flags empty)",
         Coyote_SQC_Parser_Tests.Test_V1_Tool_Call_Flags'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: v3 start time year parsed correctly (UTC conversion)",
         Coyote_SQC_Parser_Tests.Test_V3_Start_Time'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: thinking_tokens field parsed correctly",
         Coyote_SQC_Parser_Tests.Test_Thinking_Tokens'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: Thinking_Enabled set for thinking block",
         Coyote_SQC_Parser_Tests.Test_Thinking_Enabled'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: Thinking_Tokens=0 when field absent (backward compat)",
         Coyote_SQC_Parser_Tests.Test_Thinking_Absent'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: Thinking_Tokens estimated from text length when usage field absent",
         Coyote_SQC_Parser_Tests.Test_Thinking_Text_Estimate'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: tool-call Input_Tokens and Output_Tokens estimated from args and result text",
         Coyote_SQC_Parser_Tests.Test_Tool_Call_Token_Estimates'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: both pre- and post-compaction turns counted",
         Coyote_SQC_Parser_Tests.Test_Compaction_All_Turns'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: Encode_Cwd absolute path",
         Coyote_SQC_Parser_Tests.Test_Encode_Cwd_Absolute'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC: Encode_Cwd relative path",
         Coyote_SQC_Parser_Tests.Test_Encode_Cwd_Relative'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC Â§5.9: interior whitespace collapsed to single space",
         Coyote_SQC_Parser_Tests.Test_Whitespace_Collapse'Access));
      --  Coyote_SQC workspace tests
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: workspace round-trip serialisation",
         Coyote_SQC_Workspace_Tests.Test_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: workspace version > 2 raises Workspace_Error",
         Coyote_SQC_Workspace_Tests.Test_Version_Too_High'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: workspace missing version loads without error",
         Coyote_SQC_Workspace_Tests.Test_Missing_Version'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: duplicate setup session IDs are deduplicated on load",
         Coyote_SQC_Workspace_Tests.Test_UUID_Deduplication'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: New_UUID returns valid RFC 4122 v4 format",
         Coyote_SQC_Workspace_Tests.Test_New_UUID_Format'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC: New_UUID returns unique values",
         Coyote_SQC_Workspace_Tests.Test_New_UUID_Unique'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Box-Cox config round-trip",
         Coyote_SQC_Workspace_Tests.Test_Box_Cox_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Robust_Auto lambda source round-trip",
         Coyote_SQC_Workspace_Tests.Test_Robust_Auto_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("v1 workspace loads with Box-Cox disabled",
         Coyote_SQC_Workspace_Tests.Test_V1_Loads_Box_Cox_Disabled'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("EWMA: weight and L round-trip through workspace",
         Coyote_SQC_Workspace_Tests.Test_EWMA_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("EWMA: v3 workspace loads default weight=0.2, L=3.0",
         Coyote_SQC_Workspace_Tests.Test_V3_Loads_EWMA_Defaults'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Turn Count Box-Cox: config round-trips through workspace",
         Coyote_SQC_Workspace_Tests.Test_Turn_Count_Box_Cox_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Turn Count Box-Cox: v4 workspace loads default (disabled)",
         Coyote_SQC_Workspace_Tests.Test_V4_Loads_Turn_Count_Defaults'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Robust estimation: Robust_Median survives workspace round-trip",
         Coyote_SQC_Workspace_Tests.Test_Estimation_Method_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Robust estimation: v5 workspace loads Classical default",
         Coyote_SQC_Workspace_Tests.Test_V5_Loads_Classical_Default'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC workspace: Anscombe transform round-trips through save/load",
         Coyote_SQC_Workspace_Tests
           .Test_Anscombe_Transform_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC workspace: logYMode round-trips through workspace save/load",
         Coyote_SQC_Workspace_Tests
           .Test_Log_Y_Mode_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("SQC workspace: Analyze_All_Directories round-trips through save/load",
         Coyote_SQC_Workspace_Tests
           .Test_Analyze_All_Directories_Round_Trip'Access));

      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Quantile_Bonferroni round-trip",
         Coyote_SQC_Workspace_Tests
           .Test_Quantile_Bonferroni_Round_Trip'Access));
      Result.Add_Test (SQC_Workspace_Caller.Create
        ("Quantile_Bonferroni defaults to True when absent",
         Coyote_SQC_Workspace_Tests
           .Test_Quantile_Bonferroni_Default'Access));
      --  Coyote_SQC histogram bin computation tests
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: n=2 uniform: FD gives 2 bins",
         Coyote_SQC_Histogram_Tests.Test_Bins_N2'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: n=8 uniform: FD gives 2 bins",
         Coyote_SQC_Histogram_Tests.Test_Bins_N8'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: n=100 uniform: FD gives 5 bins",
         Coyote_SQC_Histogram_Tests.Test_Bins_N100'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: IQR=0 falls back to single bin",
         Coyote_SQC_Histogram_Tests.Test_FD_IQR_Zero'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: bin totals equal input length",
         Coyote_SQC_Histogram_Tests.Test_Bins_Uniform'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: minimum value in bin 1",
         Coyote_SQC_Histogram_Tests.Test_Bins_All_In_First'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: maximum value clamped to last bin",
         Coyote_SQC_Histogram_Tests.Test_Bins_All_In_Last'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: all-equal values -> N_Bins=1, Bin_Width=1.0",
         Coyote_SQC_Histogram_Tests.Test_Bins_All_Equal'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: n=1 -> N_Bins=1, Bin_Min=value",
         Coyote_SQC_Histogram_Tests.Test_Bins_N1'Access));
      Result.Add_Test (SQC_Histogram_Caller.Create
        ("SQC histogram: bimodal FD bin count capped at 32",
         Coyote_SQC_Histogram_Tests.Test_Bins_Cap_At_32'Access));

      --  Coyote_SQC statistics: EWMA + Box-Cox and Robust+EWMA tests
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: EWMA + ln Box-Cox back-transforms to asymmetric limits",
         Coyote_SQC_Statistics_Tests
           .Test_EWMA_Box_Cox_Asymmetric_Limits'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Robust Grand_Mean gives different EWMA Z0 than Classical",
         Coyote_SQC_Statistics_Tests
           .Test_Robust_EWMA_Outlier_Grand_Mean'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust Xbar plot uses median",
         Coyote_SQC_Statistics_Tests.Test_Robust_Xbar_Plot_Median'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust s chart plot uses Qn",
         Coyote_SQC_Statistics_Tests.Test_Robust_S_Plot_Qn'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust plot produces distinct values",
         Coyote_SQC_Statistics_Tests.Test_Robust_Plot_Round_Trip'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust plot I chart unaffected",
         Coyote_SQC_Statistics_Tests
           .Test_Robust_Plot_I_Chart_Unaffected'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust plot p chart unaffected",
         Coyote_SQC_Statistics_Tests
           .Test_Robust_Plot_P_Chart_Unaffected'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust plot quantile CC unaffected",
         Coyote_SQC_Statistics_Tests
           .Test_Robust_Plot_Quantile_Unaffected'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust plot single-turn Xbar identical",
         Coyote_SQC_Statistics_Tests
           .Test_Robust_Plot_Single_Turn_Xbar'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust plot single-turn s excluded",
         Coyote_SQC_Statistics_Tests
           .Test_Robust_Plot_Single_Turn_S'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC: robust plot Box-Cox interaction",
         Coyote_SQC_Statistics_Tests
           .Test_Robust_Plot_Box_Cox_Interaction'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Sqrt_VS forward/inverse round-trip",
         Coyote_SQC_Statistics_Tests
           .Test_Sqrt_VS_Round_Trip'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Anscombe forward/inverse round-trip",
         Coyote_SQC_Statistics_Tests
           .Test_Anscombe_Round_Trip'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Arcsinh_VS forward/inverse round-trip (incl. negatives)",
         Coyote_SQC_Statistics_Tests
           .Test_Arcsinh_VS_Round_Trip'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Freeman-Tukey forward/inverse round-trip",
         Coyote_SQC_Statistics_Tests
           .Test_Freeman_Tukey_Round_Trip'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Apply_Transform / Invert_Transform dispatch for all kinds",
         Coyote_SQC_Statistics_Tests
           .Test_Apply_Invert_Dispatch'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Dip_Test_P_Value returns N/A for N < 4",
         Coyote_SQC_Statistics_Tests
           .Test_Dip_NA_Too_Small'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Dip test flags strongly bimodal data (p < 0.05)",
         Coyote_SQC_Statistics_Tests
           .Test_Dip_Bimodal_Significant'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC stats: Dip test does not flag tightly unimodal data (p > 0.10)",
         Coyote_SQC_Statistics_Tests
           .Test_Dip_Unimodal_Not_Sig'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Bootstrap: point estimates for Set A={1..5} and Set B={3..7}",
         Coyote_SQC_Statistics_Tests
           .Test_Bootstrap_Point_Estimates'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Bootstrap: 95% CI with seed 12345 contains true parameter",
         Coyote_SQC_Statistics_Tests
           .Test_Bootstrap_CI_Coverage'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Bootstrap: all stats N/A when Set A has fewer than 2 values",
         Coyote_SQC_Statistics_Tests
           .Test_Bootstrap_NA_Insufficient'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Bootstrap: SD_Ratio N/A when SD(A) = 0",
         Coyote_SQC_Statistics_Tests
           .Test_Bootstrap_NA_SD_Zero'Access));
      Result.Add_Test (SQC_Statistics_Caller.Create
        ("SQC Bootstrap: same seed produces identical CI bounds",
         Coyote_SQC_Statistics_Tests
           .Test_Bootstrap_Reproducibility'Access));

      --  Coyote_SQC parser: Anthropic token normalization
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC parser: Anthropic input_tokens normalized to total context window",
         Coyote_SQC_Parser_Tests
           .Test_Anthropic_Input_Token_Normalization'Access));
      --  Incremental-reload: Parse_File must set File_Path and File_Mtime.
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC parser: Parse_File sets File_Path on success",
         Coyote_SQC_Parser_Tests
           .Test_Parse_File_Sets_File_Path'Access));
      Result.Add_Test (SQC_Parser_Caller.Create
        ("SQC parser: Parse_File sets File_Mtime to non-epoch on success",
         Coyote_SQC_Parser_Tests
           .Test_Parse_File_Sets_File_Mtime'Access));

      --  Coyote_SQC JSD statistics tests
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Token_Count single tool name only",
         Coyote_SQC_JSD_Tests.Test_Token_Count_Tool_Name_Only'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Token_Count multi-word tool name",
         Coyote_SQC_JSD_Tests
           .Test_Token_Count_Multi_Word_Tool_Name'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Token_Count empty tool name and args yields 0",
         Coyote_SQC_JSD_Tests.Test_Token_Count_Empty'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Compute_S_Values identical calls pair-level sum non-zero",
         Coyote_SQC_JSD_Tests
           .Test_S_Values_Identical_Calls_Non_Zero'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Compute_S_Values identical calls sum = 4.0",
         Coyote_SQC_JSD_Tests
           .Test_S_Values_Identical_Calls_Sum'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Compute_S_Values one-side absent key pair-level sum equals tool_name-only S_k",
         Coyote_SQC_JSD_Tests
           .Test_S_Values_One_Side_Absent'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Compute_S_Values integer-valued key skipped (N_k = 0)",
         Coyote_SQC_JSD_Tests
           .Test_S_Values_Integer_Key_Skipped'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Compute_S_Values different tool names give lower pair-level sum",
         Coyote_SQC_JSD_Tests
           .Test_S_Values_Different_Tool_Names'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Metrics.Compute N_Consecutive_Tool_Pairs=1 for two calls",
         Coyote_SQC_JSD_Tests
           .Test_Metrics_JSD_Two_Identical_Calls'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Metrics.Compute N_Consecutive_Tool_Pairs=0 for one call",
         Coyote_SQC_JSD_Tests
           .Test_Metrics_JSD_Single_Tool_Call'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Metrics.Compute N_Consecutive_Tool_Pairs=0 with no tools",
         Coyote_SQC_JSD_Tests.Test_Metrics_JSD_No_Tool_Calls'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Total_Tool_Call_JSD_S equals sum of Per_Consecutive_Tool_S",
         Coyote_SQC_JSD_Tests.Test_Metrics_JSD_Total_S_Sum'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Tool calls across turns form consecutive pairs",
         Coyote_SQC_JSD_Tests.Test_Metrics_JSD_Cross_Turn_Pairs'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Estimate_Parameters JSD Sum I Grand_Mean",
         Coyote_SQC_JSD_Tests
           .Test_Estimate_JSD_Sum_I_Grand_Mean'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Estimate_Parameters JSD Sum I Mean_MR",
         Coyote_SQC_JSD_Tests
           .Test_Estimate_JSD_Sum_I_Mean_MR'Access));
      Result.Add_Test (SQC_JSD_Caller.Create
        ("SQC JSD: Estimate_Parameters JSD Sum excludes sessions with 0 pairs",
         Coyote_SQC_JSD_Tests
           .Test_Estimate_JSD_Sum_Excludes_No_Pairs'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: identical calls",
         Coyote_SQC_MI_Tests.Test_MI_Identical_Calls'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: different tool names",
         Coyote_SQC_MI_Tests.Test_MI_Different_Tool_Names'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: one side absent",
         Coyote_SQC_MI_Tests.Test_MI_One_Side_Absent'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: integer key skipped",
         Coyote_SQC_MI_Tests.Test_MI_Integer_Key_Skipped'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: both sides empty",
         Coyote_SQC_MI_Tests.Test_MI_Both_Sides_Empty'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: metrics two identical calls",
         Coyote_SQC_MI_Tests.Test_Metrics_MI_Two_Identical_Calls'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: metrics single tool call",
         Coyote_SQC_MI_Tests.Test_Metrics_MI_Single_Tool_Call'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: metrics no tool calls",
         Coyote_SQC_MI_Tests.Test_Metrics_MI_No_Tool_Calls'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: metrics total sum",
         Coyote_SQC_MI_Tests.Test_Metrics_MI_Total_Sum'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: metrics cross-turn pairs",
         Coyote_SQC_MI_Tests.Test_Metrics_MI_Cross_Turn_Pairs'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: estimate Grand_Mean",
         Coyote_SQC_MI_Tests.Test_Estimate_MI_Sum_I_Grand_Mean'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: estimate Mean_MR",
         Coyote_SQC_MI_Tests.Test_Estimate_MI_Sum_I_Mean_MR'Access));
      Result.Add_Test (SQC_MI_Caller.Create
        ("SQC MI: estimate excludes no-pairs",
         Coyote_SQC_MI_Tests.Test_Estimate_MI_Sum_Excludes_No_Pairs'Access));

      --  Coyote_SQC workspace integrity tests
      Result.Add_Test (SQC_Integrity_Caller.Create
        ("SQC integrity: Check all present returns Missing_Count = 0",
         Coyote_SQC_Integrity_Tests.Test_Check_All_Present'Access));
      Result.Add_Test (SQC_Integrity_Caller.Create
        ("SQC integrity: Check one missing returns Missing_Count = 1",
         Coyote_SQC_Integrity_Tests.Test_Check_Some_Missing'Access));
      Result.Add_Test (SQC_Integrity_Caller.Create
        ("SQC integrity: Check all missing returns Missing_Count = N",
         Coyote_SQC_Integrity_Tests.Test_Check_All_Missing'Access));
      Result.Add_Test (SQC_Integrity_Caller.Create
        ("SQC integrity: Check empty setup interval returns Missing_Count = 0",
         Coyote_SQC_Integrity_Tests.Test_Check_Empty_Setup'Access));
      Result.Add_Test (SQC_Integrity_Caller.Create
        ("SQC integrity: Remove_Missing removes absent, retains present",
         Coyote_SQC_Integrity_Tests.Test_Remove_Missing_Partial'Access));
      Result.Add_Test (SQC_Integrity_Caller.Create
        ("SQC integrity: Remove_Missing clears all when all absent",
         Coyote_SQC_Integrity_Tests.Test_Remove_Missing_All'Access));
      Result.Add_Test (SQC_Integrity_Caller.Create
        ("SQC integrity: Remove_Missing no-op when all present",
         Coyote_SQC_Integrity_Tests.Test_Remove_Missing_None'Access));

      --  Coyote_SQC Quantile CC tests
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Compute_Quantiles basic 10-element array",
         Coyote_SQC_Quantile_CC_Tests.Test_Compute_Quantiles_Basic'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Compute_Quantiles n=1 returns all equal",
         Coyote_SQC_Quantile_CC_Tests.Test_Compute_Quantiles_N1'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Build_Distribution with 3-session pool",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Build_Distribution_Limits'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Build_Distribution single-session pool",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Build_Distribution_Single'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Build_Distribution seed reproducibility",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Build_Distribution_Seeding'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Extract_Limits with known distribution",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Extract_Limits_Known'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Is_OOC detects value above UCL",
         Coyote_SQC_Quantile_CC_Tests.Test_Is_OOC_Above'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Is_OOC with Has_UCL=False",
         Coyote_SQC_Quantile_CC_Tests.Test_Is_OOC_No_UCL'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Session_Is_OOC all in-control",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Session_Is_OOC_All_In'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: Session_Is_OOC one component out",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Session_Is_OOC_One_Out'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: OOC_Components returns correct set",
         Coyote_SQC_Quantile_CC_Tests.Test_OOC_Components'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: cache hit returns same distribution",
         Coyote_SQC_Quantile_CC_Tests.Test_Cache_Hit'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: cache invalidation clears entries",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Cache_Invalidation'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: sort through quantiles -- reverse input",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Sort_Through_Quantiles_Reverse'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: sort through quantiles -- all equal values",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Sort_Through_Quantiles_All_Equal'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: sort through quantiles -- two descending",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Sort_Through_Quantiles_Two_Desc'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Quantile CC: sort through quantiles -- 50 random-ish",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Sort_Through_Quantiles_Larger'Access));

      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Interpolate_Limits at anchor matches exact",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Interpolate_Limits_Anchor'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Interpolate_Limits between anchors shrinks HW",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Interpolate_Limits_Between'Access));
      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Interpolate_Limits n=1 falls back to exact",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Interpolate_Limits_N1'Access));

      Result.Add_Test (SQC_Quantile_CC_Caller.Create
        ("Extract_Limits with Bonferroni disabled uses unadjusted ranks",
         Coyote_SQC_Quantile_CC_Tests
           .Test_Extract_Limits_Bonferroni_Disabled'Access));
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
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages captures signature from signature_delta",
         LLM_Anthropic_Messages_Tests
           .Test_Signature_Parsed_From_SSE'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("LLM.Anthropic_Messages echoes thinking block with signature "
         & "in subsequent request",
         LLM_Anthropic_Messages_Tests
           .Test_Thinking_Block_Serialised_In_Request'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("Anthropic system prompt is content-block array with cache_control",
         LLM_Anthropic_Messages_Tests
           .Test_System_Prompt_Is_Content_Block_Array'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("Anthropic last tool has cache_control breakpoint",
         LLM_Anthropic_Messages_Tests
           .Test_Cache_Control_On_Last_Tool'Access));
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("Anthropic last user message has cache_control breakpoint",
         LLM_Anthropic_Messages_Tests
           .Test_Cache_Control_On_Last_User_Message'Access));

      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("Anthropic tool_result with Is_Error includes is_error field",
         LLM_Anthropic_Messages_Tests
           .Test_Tool_Result_Is_Error_Serialised'Access));

      --  LLM.Providers.GitHub_Copilot tests
      Result.Add_Test (LLM_Anthropic_Messages_Caller.Create
        ("Anthropic tool_result image block uses base64 source format",
         LLM_Anthropic_Messages_Tests
           .Test_Tool_Result_Image_Serialised'Access));
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
        ("LLM.Model_Registry returns a default for unknown Copilot ids",
         LLM_Model_Registry_Tests.Test_GitHub_Copilot_Default_Fallback'Access));
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
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry MiniMax M2.7 uses Anthropic wire format",
         LLM_Model_Registry_Tests
           .Test_OpenCode_Go_Wire_Format_Anthropic'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry DeepSeek V4 Pro uses OpenAI wire format",
         LLM_Model_Registry_Tests
           .Test_OpenCode_Go_Wire_Format_OpenAI'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry defaults unknown opencode-go ids",
         LLM_Model_Registry_Tests
           .Test_OpenCode_Go_Default_Fallback'Access));
      Result.Add_Test (LLM_Model_Registry_Caller.Create
        ("LLM.Model_Registry OpenCode Go models available with key",
         LLM_Model_Registry_Tests
           .Test_OpenCode_Go_Available_With_Key'Access));

      --  LLM.Providers.OpenCode_Go.Catalogue tests
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue MiniMax uses Anthropic wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_MiniMax_Anthropic'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue DeepSeek uses OpenAI wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_DeepSeek_OpenAI'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue unknown models default to OpenAI wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_Unknown_Defaults_OpenAI'Access));

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
        ("LLM.Agent aborts shell tool with timeout promptly",
         LLM_Agent_Tests.Test_Abort_During_Shell_With_Timeout'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent flushes tool batch to session file as soon as it"
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
        ("LLM.Agent memory enabled by COYOTE_ENABLE_MEMORY=1",
         LLM_Agent_Tests.Test_Memory_Enabled_By_Env_Var'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent memory disabled by default (env var unset)",
         LLM_Agent_Tests.Test_Memory_Disabled_By_Default'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent reuses history across multiple turns in one session",
         LLM_Agent_Tests
           .Test_Multi_Turn_Same_Session_Carries_History'Access));
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
        ("LLM.Agent Set_Compact_Settings Enabled=False prevents compaction",
         LLM_Agent_Tests
           .Test_Set_Compact_Settings_Disabled'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Compact survives a session reload round-trip",
         LLM_Agent_Tests
           .Test_Compact_Then_Resume'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("[live] LLM.Agent Compact summarises a GitHub Copilot conversation",
         LLM_Agent_Tests
           .Test_Compact_Live_Summarises_Conversation'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("Tool result contains [coyote: turn=...] stats footer",
         LLM_Agent_Tests
           .Test_Tool_Result_Has_Stats_Footer'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("Stats footer appears only on last tool in a batch",
         LLM_Agent_Tests
           .Test_Stats_Footer_Only_On_Last_Tool_In_Batch'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("Image tool results have no stats footer appended",
         LLM_Agent_Tests
           .Test_Image_Tool_Result_No_Footer'Access));
      Result.Add_Test (LLM_Parallel_Caller.Create
        ("Parallel batch: two 0.4 s tools complete in < 0.75 s",
         LLM_Parallel_Tools_Tests
           .Test_Parallel_Tools_Run_Concurrently'Access));
      Result.Add_Test (LLM_Parallel_Caller.Create
        ("Parallel batch: abort during batch sets Was_Aborted",
         LLM_Parallel_Tools_Tests
           .Test_Parallel_Abort_During_Batch'Access));
      Result.Add_Test (LLM_Parallel_Caller.Create
        ("Sequential default: tools without run_group run sequentially",
         LLM_Parallel_Tools_Tests
           .Test_Tools_Run_Sequentially_By_Default'Access));
      Result.Add_Test (LLM_Parallel_Caller.Create
        ("Group order: group 1 runs before group 2",
         LLM_Parallel_Tools_Tests
           .Test_Tools_Run_In_Group_Order'Access));
      --  Sandbox tests
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Profiles_Dir returns path",
         Sandbox_Tests.Test_Profiles_Dir_Returns_Path'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Available_Profiles empty when none exist",
         Sandbox_Tests.Test_Available_Profiles_Empty'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Available_Profiles finds profile",
         Sandbox_Tests.Test_Available_Profiles_Found'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Load_Profile returns object for valid profile",
         Sandbox_Tests.Test_Load_Profile_Found'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Load_Profile returns JSON_Null for missing profile",
         Sandbox_Tests.Test_Load_Profile_Not_Found'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Load_Profile returns JSON_Null for bad JSON",
         Sandbox_Tests.Test_Load_Profile_Bad_Json'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args returns empty for empty profile",
         Sandbox_Tests.Test_Bbuild_Empty_Profile'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args returns empty for non-existent profile",
         Sandbox_Tests.Test_Bbuild_Non_Existent_Profile'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args allowWrite uses --bind",
         Sandbox_Tests.Test_Bbuild_Allow_Write'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args denyWrite uses --ro-bind",
         Sandbox_Tests.Test_Bbuild_Deny_Write'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args allowRead uses --ro-bind",
         Sandbox_Tests.Test_Bbuild_Allow_Read'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args denyRead uses --tmpfs",
         Sandbox_Tests.Test_Bbuild_Deny_Read'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args skips missing paths",
         Sandbox_Tests.Test_Bbuild_Missing_Path_Skipped'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args handles multiple rule types",
         Sandbox_Tests.Test_Bbuild_Multiple_Rule_Types'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox Build_Bwrap_Args sorts by path depth",
         Sandbox_Tests.Test_Bbuild_Depth_Sorted'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox resolves '.' to Cwd",
         Sandbox_Tests.Test_Resolve_Dot_To_Cwd'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox resolves './...' relative to Cwd",
         Sandbox_Tests.Test_Resolve_Dot_Slash'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox resolves '~/' prefix to $HOME",
         Sandbox_Tests.Test_Resolve_Home_Prefix'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox passes absolute paths through unchanged",
         Sandbox_Tests.Test_Resolve_Absolute_Untouched'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox shell allowWrite succeeds",
         Sandbox_Tests.Test_Shell_Sandbox_Allow_Write'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox shell denyRead blocks access",
         Sandbox_Tests.Test_Shell_Sandbox_Deny_Read'Access));
      Result.Add_Test (Sandbox_Caller.Create
        ("Sandbox shell empty profile runs unsandboxed",
         Sandbox_Tests.Test_Shell_Sandbox_Empty_Profile'Access));

      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent pause fires at turn boundary and resumes normally",
         LLM_Agent_Tests.Test_Pause_Fires_At_Turn_Boundary'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Request_Abort while paused exits with Was_Aborted",
         LLM_Agent_Tests.Test_Stop_While_Paused'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent Set_Sandbox_Profile and Current_Sandbox round-trip",
         LLM_Agent_Tests.Test_Sandbox_Set_And_Get'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent COYOTE_SANDBOX_PROFILE inherited by Create",
         LLM_Agent_Tests.Test_Sandbox_Env_Var_Inherited'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent sandbox defaults to empty without env var",
         LLM_Agent_Tests.Test_Sandbox_Default_Empty'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent restores sandbox profile on session resume",
         LLM_Agent_Tests.Test_Sandbox_Profile_Restored_On_Resume'Access));
      Result.Add_Test (LLM_Agent_Caller.Create
        ("LLM.Agent restores and clears sandbox profile on session switch",
         LLM_Agent_Tests
           .Test_Sandbox_Profile_Restored_And_Cleared_On_Switch'Access));

      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates first enqueue wakes exactly once",
         Coyote_GUI_Updates_Tests.Test_First_Enqueue_Wakes_Exactly_Once'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates pending enqueue does not duplicate wakeup",
         Coyote_GUI_Updates_Tests.Test_Pending_Enqueue_Does_Not_Duplicate_Wakeup'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates idle completion keeps source for pending work",
         Coyote_GUI_Updates_Tests.Test_Idle_Done_Keeps_Source_For_Pending_Work'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates idle completion clears source when empty",
         Coyote_GUI_Updates_Tests.Test_Idle_Done_Clears_Source_When_Empty'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates enqueue rearms after idle completion",
         Coyote_GUI_Updates_Tests.Test_Enqueue_Rearms_After_Idle_Done'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates stopped queue does not wake",
         Coyote_GUI_Updates_Tests.Test_Stopped_Queue_Does_Not_Wake'Access));

      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Append_Notice adds logical lines",
         Coyote_GUI_Conversation_Tests.Test_Append_Notice_Increments_Count'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Append_Text enters text block",
         Coyote_GUI_Conversation_Tests.Test_Append_Text_Enters_Text_Block'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Append_Text accumulates buffer",
         Coyote_GUI_Conversation_Tests.Test_Append_Text_Accumulates_Buffer'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation reassembles split UTF-8 text",
         Coyote_GUI_Conversation_Tests.Test_Split_UTF8_Text_Is_Reassembled'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation reassembles split UTF-8 thinking",
         Coyote_GUI_Conversation_Tests.Test_Split_UTF8_Thinking_Is_Reassembled'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation streaming append invalidates visual cache",
         Coyote_GUI_Conversation_Tests
           .Test_Streaming_Append_Invalidates_Vis_Cache'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation End_Text_Block exits block",
         Coyote_GUI_Conversation_Tests.Test_End_Text_Block_Exits_Block'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Begin_Thinking sets flag",
         Coyote_GUI_Conversation_Tests.Test_Begin_Thinking_Sets_Flag'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation End_Thinking clears flag",
         Coyote_GUI_Conversation_Tests.Test_End_Thinking_Clears_Flag'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation tool detail preserves arguments",
         Coyote_GUI_Conversation_Tests
           .Test_Tool_Detail_Preserves_Arguments'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation selects interleaved second tool",
         Coyote_GUI_Conversation_Tests
           .Test_Tool_Detail_Selects_Second_Interleaved'Access));

      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation notices do not enter text block",
         Coyote_GUI_Conversation_Tests.Test_Notice_Does_Not_Enter_Text_Block'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation footer leaves 3 lines",
         Coyote_GUI_Conversation_Tests.Test_Footer_Leaves_Blank_Lines'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation single short line Vis_Count = 1",
         Coyote_GUI_Conversation_Tests.Test_Single_Short_Line_Vis_Count_One'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Total_Vis_Lines after Append_Text",
         Coyote_GUI_Conversation_Tests.Test_Total_Vis_Lines_After_Append_Text'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Total_Vis_Lines zero when empty",
         Coyote_GUI_Conversation_Tests.Test_Total_Vis_Lines_Zero_When_Empty'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation cache width non-zero after recompute",
         Coyote_GUI_Conversation_Tests.Test_Cache_Width_Non_Zero_After_Recompute'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Invalidate_Layout recomputes cache",
         Coyote_GUI_Conversation_Tests.Test_Invalidate_Layout_Zeroes_Cache_Width'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Recompute_Vis_Lines updates total",
         Coyote_GUI_Conversation_Tests.Test_Recompute_Vis_Lines_Updates_Total'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation multiple short lines each Vis_Count=1",
         Coyote_GUI_Conversation_Tests.Test_Multiple_Short_Lines_Each_Vis_Count_One'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation long line produces many visual lines",
         Coyote_GUI_Conversation_Tests.Test_Long_Line_Produces_Many_Visual_Lines'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation deep indent consumes width and wraps",
         Coyote_GUI_Conversation_Tests.Test_Deep_Indent_Consumes_Width_And_Wraps'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation visual lines exceed viewport height",
         Coyote_GUI_Conversation_Tests.Test_Visual_Lines_Exceed_Viewport_Height'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation Vis_Count consistent on recompute",
         Coyote_GUI_Conversation_Tests.Test_Long_Line_Vis_Count_Consistent_On_Recompute'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation long word forces character break",
         Coyote_GUI_Conversation_Tests.Test_Long_Word_Forces_Character_Break'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation select-all extracts expected text",
         Coyote_GUI_Conversation_Tests.Test_Viewport_Select_All_Extracts_Expected_Text'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation markdown paragraph has markup flag",
         Coyote_GUI_Conversation_Tests.Test_Markdown_Paragraph_Has_Markup_Flag'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation markdown multi-paragraph line count",
         Coyote_GUI_Conversation_Tests.Test_Markdown_Multi_Paragraph_Line_Count'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation markdown select-all strips markup",
         Coyote_GUI_Conversation_Tests.Test_Markdown_Select_All_Strips_Markup'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation markdown heading styles",
         Coyote_GUI_Conversation_Tests.Test_Markdown_Heading_Styles'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Caller.Create
        ("Coyote.GUI.Conversation markdown bold/italic rendered to plain text",
         Coyote_GUI_Conversation_Tests.Test_Markdown_Bold_Italic_Preserved_In_Text'Access));

      return Result;
   end Suite;

end Test_Suites;
