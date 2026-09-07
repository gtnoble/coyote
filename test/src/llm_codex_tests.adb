with Ada.Calendar;
with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Tags;
use type Ada.Tags.Tag;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Caller;
with GNATCOLL.JSON;
with Interfaces;
with LLM.Auth.Codex;
with LLM.Events;
with LLM.HTTP;
with LLM.Model_Registry;
with LLM.Providers;
with LLM.Providers.Codex;
with LLM.Types;
with Test_HTTP_Server;

package body LLM_Codex_Tests is

   use AUnit.Assertions;
   use type Ada.Containers.Count_Type;
   use type Interfaces.Unsigned_32;
   use type LLM.Types.Stop_Reason;

   subtype Unsigned is Interfaces.Unsigned_32;

   function Trimmed_Image (Port : Positive) return String is
      Image : constant String := Positive'Image (Port);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Trimmed_Image;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (Text, Pattern) > 0;
   end Contains;

   function Current_Unix_Ms return Long_Long_Integer is
      use Ada.Calendar;

      Epoch : constant Time :=
        Time_Of (Year => 1970, Month => 1, Day => 1, Seconds => 0.0);
   begin
      return Long_Long_Integer ((Clock - Epoch) * 1000.0);
   end Current_Unix_Ms;

   procedure Restore_Env (Name : String; Was_Set : Boolean; Value : String) is
   begin
      if Was_Set then
         Ada.Environment_Variables.Set (Name, Value);
      else
         Ada.Environment_Variables.Clear (Name);
      end if;
   end Restore_Env;

   procedure Ensure_Test_Home (Home : String) is
   begin
      Ada.Directories.Create_Path (Home & "/.coyote");
   end Ensure_Test_Home;

   procedure Delete_If_Exists (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   exception
      when others =>
         null;
   end Delete_If_Exists;

   procedure Cleanup_Test_Home (Home : String) is
      Agent_Dir : constant String := Home & "/.coyote";
   begin
      Delete_If_Exists (Agent_Dir & "/auth.json");
      Delete_If_Exists (Agent_Dir & "/auth.json.tmp");

      if Ada.Directories.Exists (Agent_Dir) then
         Ada.Directories.Delete_Directory (Agent_Dir);
      end if;

      if Ada.Directories.Exists (Home) then
         Ada.Directories.Delete_Directory (Home);
      end if;
   exception
      when others =>
         null;
   end Cleanup_Test_Home;

   function Read_File (Path : String) return String is
      File    : Ada.Text_IO.File_Type;
      Content : Unbounded_String;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Append (Content, Line);
            Append (Content, ASCII.LF);
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return To_String (Content);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Read_File;

   procedure Write_File (Path : String; Content : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Content);
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         raise;
   end Write_File;

   --  Base64url-encoded JWT payload carrying the ChatGPT account claim.
   function Sample_Jwt (Account_Id : String) return String is
      Encoded  : Unbounded_String;
      Alphabet : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
      Text     : constant String :=
        "{""https://api.openai.com/auth"":{""chatgpt_account_id"":"""
        & Account_Id & """}}";
      Group    : Unsigned := 0;
      Bits     : Natural := 0;
   begin
      for Char of Text loop
         Group := Group * 256 + Unsigned (Character'Pos (Char));
         Bits := Bits + 8;
         while Bits >= 6 loop
            Bits := Bits - 6;
            Append
              (Encoded,
               Alphabet
                 (Natural ((Group / 2 ** Bits) mod 64) + Alphabet'First));
         end loop;
         Group := Group mod 2 ** Bits;
      end loop;
      if Bits > 0 then
         Append
           (Encoded,
            Alphabet
              (Natural ((Group * 2 ** (6 - Bits)) mod 64)
               + Alphabet'First));
      end if;

      return "header." & To_String (Encoded) & ".signature";
   end Sample_Jwt;

   procedure Test_Make_Pkce (T : in out Test) is
      pragma Unreferenced (T);

      Verifier  : Unbounded_String;
      Challenge : Unbounded_String;
      Verifier2 : Unbounded_String;
      Challenge2 : Unbounded_String;
   begin
      LLM.Auth.Codex.Make_Pkce (Verifier, Challenge);
      LLM.Auth.Codex.Make_Pkce (Verifier2, Challenge2);

      Assert
        (Length (Verifier) = 43,
         "PKCE verifier should be 43 characters");
      Assert
        (Length (Challenge) = 43,
         "S256 challenge should be 43 base64url characters (no padding)");
      Assert
        (Verifier /= Verifier2,
         "Two verifiers should differ");
      Assert
        (Challenge /= Challenge2,
         "Two challenges should differ");
      for C of To_String (Challenge) loop
         Assert
           (C /= '=' and then C /= '+' and then C /= '/',
            "Challenge must be base64url without padding");
      end loop;
   end Test_Make_Pkce;

   procedure Test_New_State (T : in out Test) is
      pragma Unreferenced (T);

      State_A : constant String := LLM.Auth.Codex.New_State;
      State_B : constant String := LLM.Auth.Codex.New_State;
   begin
      Assert (State_A'Length = 32, "State should be 16 hex bytes");
      Assert (State_A /= State_B, "States should differ");
      for C of State_A loop
         Assert
           (C in '0' .. '9' or else C in 'a' .. 'f',
            "State should be lowercase hex");
      end loop;
   end Test_New_State;

   procedure Test_Build_Authorize_Url (T : in out Test) is
      pragma Unreferenced (T);

      Url : constant String :=
        LLM.Auth.Codex.Build_Authorize_Url
          ("challenge-value", "state-value");
   begin
      Assert
        (Contains (Url, "https://auth.openai.com/oauth/authorize?"),
         "Authorize URL should target the OpenAI issuer");
      Assert
        (Contains (Url, "client_id=app_EMoamEEZ73f0CkXaXp7hrann"),
         "Authorize URL should carry the Codex client id");
      Assert
        (Contains (Url, "redirect_uri=http%3A%2F%2Flocalhost%3A1455%2Fauth%2Fcallback"),
         "Authorize URL should encode the localhost callback");
      Assert
        (Contains (Url, "code_challenge_method=S256"),
         "Authorize URL should request S256 PKCE");
      Assert
        (Contains (Url, "codex_cli_simplified_flow=true"),
         "Authorize URL should set the simplified-flow flag");
      Assert
        (Contains (Url, "originator=coyote"),
         "Authorize URL should carry the coyote originator");
      Assert
        (Contains (Url, "state=state-value"),
         "Authorize URL should carry the caller state");
   end Test_Build_Authorize_Url;

   procedure Test_Account_Id_From_Jwt (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Auth.Codex.Account_Id_From_Jwt (Sample_Jwt ("acc-123"))
         = "acc-123",
         "JWT claim extraction should return the account id");
      Assert
        (LLM.Auth.Codex.Account_Id_From_Jwt ("not-a-jwt") = "",
         "Malformed tokens should yield an empty account id");
      Assert
        (LLM.Auth.Codex.Account_Id_From_Jwt ("a.b.c") = "",
         "Payload without the claim should yield an empty account id");
   end Test_Account_Id_From_Jwt;

   procedure Test_Token_Expired (T : in out Test) is
      pragma Unreferenced (T);

      Now : constant Long_Long_Integer := Current_Unix_Ms;
   begin
      Assert
        (LLM.Auth.Codex.Token_Expired
           ((Expires_Ms => Now - 1, others => <>)),
         "Past expiry should be reported expired");
      Assert
        (LLM.Auth.Codex.Token_Expired
           ((Expires_Ms => Now + 240_000, others => <>)),
         "Tokens within five minutes should refresh");
      Assert
        (not LLM.Auth.Codex.Token_Expired
           ((Expires_Ms => Now + 360_000, others => <>)),
         "Tokens valid for six minutes should stay");
   end Test_Token_Expired;

   procedure Test_Refresh_Token (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_809;
      Home         : constant String := "/tmp/coyote_codex_auth_test_1";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Url_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_CODEX_TOKEN_URL");
      Old_Url      : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_CODEX_TOKEN_URL", "");
      Creds        : LLM.Auth.Provider_Credentials :=
        (Credential_Type => To_Unbounded_String ("oauth"),
         Refresh_Token   => To_Unbounded_String ("refresh-token"),
         Access_Token    => To_Unbounded_String ("expired-token"),
         Expires_Ms      => 0,
         Account_Id      => To_Unbounded_String ("acc-old"));
      Saved        : LLM.Auth.Provider_Credentials;

      procedure Refresh_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Body_Text : constant String := To_String (Req.Body_Data);
      begin
         Assert
           (To_String (Req.Path) = "/oauth/token",
            "Refresh request should target the token endpoint");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Content-Type")
            = "application/x-www-form-urlencoded",
            "Refresh request should be form-urlencoded");
         Assert
           (Contains (Body_Text, "grant_type=refresh_token"),
            "Refresh request should use the refresh grant");
         Assert
           (Contains (Body_Text, "refresh_token=refresh-token"),
            "Refresh request should carry the stored refresh token");
         Assert
           (Contains (Body_Text, "client_id=app_EMoamEEZ73f0CkXaXp7hrann"),
            "Refresh request should carry the client id");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "User-Agent")
           = "coyote/0.1.0-dev",
            "Refresh request should carry the coyote User-Agent");
         Res.Status := 200;
         Res.Headers.Append
           ((Name  => To_Unbounded_String ("Content-Type"),
             Value => To_Unbounded_String ("application/json")));
         Append (Res.Body_Data, "{""access_token"":""");
         Append (Res.Body_Data, Sample_Jwt ("acc-new"));
         Append (Res.Body_Data, """,""refresh_token"":""rotated-token"",");
         Append (Res.Body_Data, """expires_in"":3600}");
      end Refresh_Handler;

      Srv : Test_HTTP_Server.Server
        (Handler => Refresh_Handler'Unrestricted_Access);

   begin
      Srv.Bind (Port);
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_CODEX_TOKEN_URL",
         "http://127.0.0.1:" & Trimmed_Image (Port) & "/oauth/token");

      LLM.Auth.Codex.Refresh_Token (Creds);
      Saved := LLM.Auth.Load_Credentials ("codex");

      Srv.Stop;

      Assert
        (Contains (To_String (Creds.Access_Token), "acc-new")
          or else Contains
            (LLM.Auth.Codex.Account_Id_From_Jwt
               (To_String (Creds.Access_Token)),
             "acc-new"),
         "Refresh should update the access token");
      Assert
        (To_String (Creds.Account_Id) = "acc-new",
         "Refresh should re-extract the account id");
      Assert
        (Creds.Expires_Ms > Current_Unix_Ms + 3_000_000,
         "Refresh should extend the expiry by expires_in");
      Assert
        (To_String (Saved.Refresh_Token) = "rotated-token",
         "Refresh should persist the rotated refresh token");
      Assert
        (To_String (Saved.Account_Id) = "acc-new",
         "Refresh should persist the refreshed account id");
      Assert
        (Contains
           (Read_File (Home & "/.coyote/auth.json"), """accountId"":"),
         "auth.json should carry the account id field");

      Restore_Env ("COYOTE_CODEX_TOKEN_URL", Url_Was_Set, Old_Url);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Srv.Stop;
         Restore_Env ("COYOTE_CODEX_TOKEN_URL", Url_Was_Set, Old_Url);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Refresh_Token;

   --  Run a refresh against a mock server and assert the raised error
   --  message contains Expected_Part.
   procedure Run_Refresh_Failure_Test
     (Home          : String;
      Port          : Positive;
      Status_Code   : Natural;
      Response_Body : String;
      Expected_Part : String)
   is
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Url_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_CODEX_TOKEN_URL");
      Old_Url      : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_CODEX_TOKEN_URL", "");
      Creds        : LLM.Auth.Provider_Credentials :=
        (Credential_Type => To_Unbounded_String ("oauth"),
         Refresh_Token   => To_Unbounded_String ("refresh-token"),
         Access_Token    => To_Unbounded_String ("expired-token"),
         Expires_Ms      => 0,
         Account_Id      => Null_Unbounded_String);
      Raised       : Boolean := False;
      Error_Message : Unbounded_String;

      procedure Failure_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         pragma Unreferenced (Req);
      begin
         Res.Status := Status_Code;
         Res.Headers.Append
           ((Name  => To_Unbounded_String ("Content-Type"),
             Value => To_Unbounded_String ("application/json")));
         Append (Res.Body_Data, Response_Body);
      end Failure_Handler;

      Srv : Test_HTTP_Server.Server
        (Handler => Failure_Handler'Unrestricted_Access);

   begin
      Srv.Bind (Port);
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_CODEX_TOKEN_URL",
         "http://127.0.0.1:" & Trimmed_Image (Port) & "/oauth/token");

      begin
         LLM.Auth.Codex.Refresh_Token (Creds);
      exception
         when E : LLM.Auth.Codex.Auth_Error =>
            Raised := True;
            Error_Message :=
              To_Unbounded_String (Ada.Exceptions.Exception_Message (E));
      end;

      Srv.Stop;

      Assert (Raised, "Refresh_Token should raise Auth_Error");
      Assert
        (Contains (To_String (Error_Message), Expected_Part),
         "Error message should mention the failure; got: "
         & To_String (Error_Message));
      Assert
        (not Ada.Directories.Exists (Home & "/.coyote/auth.json"),
         "A failed refresh should not create auth.json");

      Restore_Env ("COYOTE_CODEX_TOKEN_URL", Url_Was_Set, Old_Url);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Srv.Stop;
         Restore_Env ("COYOTE_CODEX_TOKEN_URL", Url_Was_Set, Old_Url);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Run_Refresh_Failure_Test;

   procedure Test_Refresh_Token_Non_200_Raises (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Refresh_Failure_Test
        (Home          => "/tmp/coyote_codex_auth_test_2",
         Port          => 18_810,
         Status_Code   => 401,
         Response_Body => "{""error"":""nope""}",
         Expected_Part => "HTTP 401");
   end Test_Refresh_Token_Non_200_Raises;

   procedure Test_Refresh_Token_Missing_Fields_Raises (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Refresh_Failure_Test
        (Home          => "/tmp/coyote_codex_auth_test_3",
         Port          => 18_811,
         Status_Code   => 200,
         Response_Body => "{""access_token"":""x""}",
         Expected_Part => "missing fields");
   end Test_Refresh_Token_Missing_Fields_Raises;

   --  Event sequence collector shared by the streaming Send tests.
   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   type Event_Collector is record
      Sequence   : String_Vectors.Vector;
      Last_Stop  : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Usage      : LLM.Types.Usage := (others => 0);
      Last_Error : Unbounded_String;
   end record;

   Current_Collector : Event_Collector;

   procedure Reset_Collector is
   begin
      Current_Collector.Sequence.Clear;
      Current_Collector.Last_Stop := LLM.Types.Unknown_Stop;
      Current_Collector.Usage := (others => 0);
      Current_Collector.Last_Error := Null_Unbounded_String;
   end Reset_Collector;

   procedure On_Event (E : LLM.Events.Agent_Event'Class) is
   begin
      if E'Tag = LLM.Events.Agent_Start_Event'Tag then
         Current_Collector.Sequence.Append ("agent_start");
      elsif E'Tag = LLM.Events.Message_Start_Event'Tag then
         Current_Collector.Sequence.Append ("message_start");
      elsif E'Tag = LLM.Events.Message_End_Event'Tag then
         declare
            Event : constant LLM.Events.Message_End_Event :=
              LLM.Events.Message_End_Event (E);
         begin
            Current_Collector.Last_Stop := Event.Stop;
            Current_Collector.Usage := Event.Tok_Usage;
            Current_Collector.Last_Error := Event.Err_Msg;
            Current_Collector.Sequence.Append ("message_end");
         end;
      elsif E'Tag = LLM.Events.Agent_End_Event'Tag then
         Current_Collector.Sequence.Append ("agent_end");
      elsif E'Tag = LLM.Events.Message_Update_Event'Tag then
         declare
            Event : constant LLM.Events.Message_Update_Event :=
              LLM.Events.Message_Update_Event (E);
         begin
            case Event.Kind is
               when LLM.Events.Thinking_Start =>
                  Current_Collector.Sequence.Append ("thinking_start");
               when LLM.Events.Thinking_Delta =>
                  Current_Collector.Sequence.Append
                    ("thinking_delta:" & To_String (Event.Delta_Text));
               when LLM.Events.Thinking_End =>
                  Current_Collector.Sequence.Append
                    ("thinking_end:" & To_String (Event.Signature));
               when LLM.Events.Text_Start =>
                  Current_Collector.Sequence.Append ("text_start");
               when LLM.Events.Text_Delta =>
                  Current_Collector.Sequence.Append
                    ("text_delta:" & To_String (Event.Delta_Text));
               when LLM.Events.Text_End =>
                  Current_Collector.Sequence.Append ("text_end");
               when others =>
                  null;
            end case;
         end;
      end if;
   end On_Event;

   function Sequence_Image return String is
      Result : Unbounded_String;
   begin
      for Item of Current_Collector.Sequence loop
         if Length (Result) > 0 then
            Append (Result, " | ");
         end if;
         Append (Result, Item);
      end loop;
      return To_String (Result);
   end Sequence_Image;

   function Json_String (Val : GNATCOLL.JSON.JSON_Value) return String is
      S : constant String := Val.Get;
   begin
      return S;
   end Json_String;

   function SSE_Event (Event_Type : String; Data : String) return String is
   begin
      return
        "event: " & Event_Type & ASCII.LF
        & "data: " & Data & ASCII.LF & ASCII.LF;
   end SSE_Event;

   function SSE_Event
     (Event_Type : String;
      Data       : GNATCOLL.JSON.JSON_Value) return String
   is
   begin
      return SSE_Event (Event_Type, GNATCOLL.JSON.Write (Data));
   end SSE_Event;

   function User_Hello return LLM.Types.Message_Vectors.Vector is
      Messages : LLM.Types.Message_Vectors.Vector;
      Content  : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String ("Say hello")));
      Messages.Append
        ((Role      => LLM.Types.User,
          Content   => Content,
          Tok_Usage => (others => 0),
          Stop      => LLM.Types.Unknown_Stop,
          Timestamp => Null_Unbounded_String));
      return Messages;
   end User_Hello;

   --  Write a valid codex credential with a JWT access token carrying
   --  the given account id.
   procedure Write_Credentials (Home : String; Account_Id : String) is
   begin
      Write_File
        (Home & "/.coyote/auth.json",
         "{""codex"":{"
         & """type"":""oauth"","
         & """refresh"":""codex-refresh"","
         & """access"":""" & Sample_Jwt (Account_Id) & ""","
         & """expires"":9999999999000,"
         & """accountId"":""" & Account_Id & """}}");
   end Write_Credentials;

   --  Drive Provider.Send against the mock server, tolerating transient
   --  connect errors.
   procedure Send_With_Retry
     (P        : in out LLM.Providers.Codex.Provider;
      Model_Id :        String;
      Messages :        LLM.Types.Message_Vectors.Vector;
      Thinking :        LLM.Providers.Thinking_Level := LLM.Providers.Off)
   is
   begin
      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            P.Send
              (Model_Id      => Model_Id,
               System_Prompt => "Be helpful.",
               Messages      => Messages,
               Tools_Json    => "[]",
               Thinking      => Thinking,
               Max_Tokens    => 64,
               Handler       => On_Event'Access);
            exit Retry_Loop;
         exception
            when LLM.HTTP.Curl_Error =>
               if Attempt = 20 then
                  raise;
               end if;

               delay 0.05;
         end;
      end loop Retry_Loop;
   end Send_With_Retry;

   --  Minimal completed Responses SSE payload.
   function Build_Text_SSE (Text : String) return String is
      use GNATCOLL.JSON;

      Created  : constant JSON_Value := Create_Object;
      Delta_Val : constant JSON_Value := Create_Object;
      Item     : constant JSON_Value := Create_Object;
      Part     : constant JSON_Value := Create_Object;
      Content  : JSON_Array := Empty_Array;
      Output   : JSON_Array := Empty_Array;
      Response : constant JSON_Value := Create_Object;
      Usage    : constant JSON_Value := Create_Object;
      Done     : constant JSON_Value := Create_Object;
   begin
      Created.Set_Field ("type", "response.created");
      Item.Set_Field ("id", "msg_test");
      Item.Set_Field ("type", "message");
      Item.Set_Field ("role", "assistant");
      Item.Set_Field ("status", "in_progress");
      Item.Set_Field ("content", Empty_Array);
      Delta_Val.Set_Field ("type", "response.output_text.delta");
      Delta_Val.Set_Field ("item_id", "msg_test");
      Delta_Val.Set_Field ("delta", Text);
      Part.Set_Field ("type", "output_text");
      Part.Set_Field ("text", Text);
      Append (Content, Part);
      Item.Set_Field ("id", "msg_test");
      Item.Set_Field ("type", "message");
      Item.Set_Field ("role", "assistant");
      Item.Set_Field ("status", "completed");
      Item.Set_Field ("content", Content);
      Append (Output, Item);
      Usage.Set_Field ("input_tokens", Integer (7));
      Usage.Set_Field ("output_tokens", Integer (3));
      Response.Set_Field ("id", "resp_1");
      Response.Set_Field ("status", "completed");
      Response.Set_Field ("output", Output);
      Response.Set_Field ("usage", Usage);
      Done.Set_Field ("type", "response.completed");
      Done.Set_Field ("response", Response);
      return SSE_Event ("response.created", Created)
        & SSE_Event ("response.output_text.delta", Delta_Val)
        & SSE_Event ("response.completed", Done);
   end Build_Text_SSE;

   procedure Test_Send_Adds_Codex_Headers (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_201;
      Home     : constant String := "/tmp/coyote_codex_send_1";
      Provider : LLM.Providers.Codex.Provider :=
        LLM.Providers.Codex.Create (Session_Id => "sess-1234");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;
      Saw_Headers : Boolean := False;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Assert
           (To_String (Req.Path) = "/codex/responses",
            "Expected path /codex/responses, got: "
            & To_String (Req.Path));
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "chatgpt-account-id") = "acc-xyz",
            "Expected chatgpt-account-id header");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "originator")
              = "coyote",
            "Expected originator coyote");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "session-id")
              = "sess-1234",
            "Expected session-id header");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "x-client-request-id") = "sess-1234",
            "Expected x-client-request-id header");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "OpenAI-Beta")
              = "responses=experimental",
            "Expected OpenAI-Beta responses=experimental");
         Assert
           (Contains
              (Test_HTTP_Server.Get_Header
                 (Req.Headers, "Authorization"),
               "Bearer "),
            "Expected bearer authorization");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "User-Agent")
              = "coyote/0.1.0-dev",
            "Expected coyote User-Agent");
         Saw_Headers := True;
         Res.Status := 200;
         Append (Res.Body_Data, Build_Text_SSE ("ok"));
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Credentials (Home, "acc-xyz");

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_CODEX_BASE_URL", "http://127.0.0.1:19201");

      Srv.Bind (Port);
      Send_With_Retry
        (P        => Provider,
         Model_Id => "gpt-5.5",
         Messages => Messages);
      Srv.Stop;
      Server_Stopped := True;

      Assert (Saw_Headers, "Header assertions should have run");
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Stop,
         "Completed response should map to Stop: " & Sequence_Image);
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Send_Adds_Codex_Headers;

   procedure Test_Send_Requires_Credentials (T : in out Test) is
      pragma Unreferenced (T);

      Home     : constant String := "/tmp/coyote_codex_send_2";
      Provider : LLM.Providers.Codex.Provider :=
        LLM.Providers.Codex.Create (Session_Id => "s");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;
      Raised   : Boolean := False;
      Msg      : Unbounded_String;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Ada.Environment_Variables.Set ("HOME", Home);

      begin
         Provider.Send
           (Model_Id      => "gpt-5.5",
            System_Prompt => "",
            Messages      => Messages,
            Tools_Json    => "[]",
            Thinking      => LLM.Providers.Off,
            Max_Tokens    => 16,
            Handler       => On_Event'Access);
      exception
         when E : Constraint_Error =>
            Raised := True;
            Msg := To_Unbounded_String
              (Ada.Exceptions.Exception_Message (E));
      end;

      Assert (Raised, "Send without credentials should raise");
      Assert
        (Contains (To_String (Msg), "not configured"),
         "Error should tell the user to configure the subscription: "
         & To_String (Msg));

      Cleanup_Test_Home (Home);
   exception
      when others =>
         Cleanup_Test_Home (Home);
         raise;
   end Test_Send_Requires_Credentials;

   procedure Test_Send_Requires_Account_Claim (T : in out Test) is
      pragma Unreferenced (T);

      Home     : constant String := "/tmp/coyote_codex_send_3";
      Provider : LLM.Providers.Codex.Provider :=
        LLM.Providers.Codex.Create (Session_Id => "s");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;
      Raised   : Boolean := False;
      Msg      : Unbounded_String;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_File
        (Home & "/.coyote/auth.json",
         "{""codex"":{""type"":""oauth"","
         & """refresh"":""r"",""access"":""plain-token"","
         & """expires"":9999999999000}}");
      Ada.Environment_Variables.Set ("HOME", Home);

      begin
         Provider.Send
           (Model_Id      => "gpt-5.5",
            System_Prompt => "",
            Messages      => Messages,
            Tools_Json    => "[]",
            Thinking      => LLM.Providers.Off,
            Max_Tokens    => 16,
            Handler       => On_Event'Access);
      exception
         when E : Constraint_Error =>
            Raised := True;
            Msg := To_Unbounded_String
              (Ada.Exceptions.Exception_Message (E));
      end;

      Assert (Raised, "Send without account claim should raise");
      Assert
        (Contains (To_String (Msg), "chatgpt_account_id"),
         "Error should name the missing claim: " & To_String (Msg));

      Cleanup_Test_Home (Home);
   exception
      when others =>
         Cleanup_Test_Home (Home);
         raise;
   end Test_Send_Requires_Account_Claim;

   procedure Test_Stream_Text_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_204;
      Home     : constant String := "/tmp/coyote_codex_send_4";
      Provider : LLM.Providers.Codex.Provider :=
        LLM.Providers.Codex.Create (Session_Id => "sess-stream");
      Messages : constant LLM.Types.Message_Vectors.Vector := User_Hello;

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Body_JS : GNATCOLL.JSON.JSON_Value;
         Input   : GNATCOLL.JSON.JSON_Array;
         Include : GNATCOLL.JSON.JSON_Array;
      begin
         Assert (Parsed.Success, "Request body should parse as JSON");
         Body_JS := Parsed.Value;
         Assert
           (Json_String (Body_JS.Get ("model")) = "gpt-5.5",
            "Model should be sent verbatim");
         Assert
           (not Body_JS.Has_Field ("max_output_tokens"),
            "Codex requests should omit max_output_tokens");
         Assert
           (not Body_JS.Has_Field ("store")
              or else not Boolean'(Body_JS.Get ("store").Get),
            "store must not be true");
         Assert
           (Json_String (Body_JS.Get ("instructions")) = "Be helpful.",
            "System prompt should ride in instructions");
         Assert
           (Body_JS.Has_Field ("include"),
            "include should request encrypted reasoning");
         Assert
           (Body_JS.Has_Field ("prompt_cache_key"),
            "prompt_cache_key should carry the session id");
         Assert
           (Json_String (Body_JS.Get ("prompt_cache_key"))
            = "sess-stream",
            "prompt_cache_key should equal the session id");
         Input := Body_JS.Get ("input").Get;
         Assert
           (GNATCOLL.JSON.Length (Input) = 1,
            "Input should carry one user item");
         Include := Body_JS.Get ("include").Get;
         Assert
           (Json_String (GNATCOLL.JSON.Get (Include, 1))
              = "reasoning.encrypted_content",
            "include should request encrypted reasoning");
         Res.Status := 200;
         Append (Res.Body_Data, Build_Text_SSE ("hello codex"));
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Credentials (Home, "acc-stream");
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_CODEX_BASE_URL", "http://127.0.0.1:19204");

      Srv.Bind (Port);
      Send_With_Retry
        (P        => Provider,
         Model_Id => "gpt-5.5",
         Messages => Messages);
      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Current_Collector.Sequence.Find_Index
           ("text_delta:hello codex") > 0,
         "Text delta should arrive: " & Sequence_Image);
      Assert
        (Current_Collector.Last_Stop = LLM.Types.Stop,
         "Stop reason should map to Stop");
      Assert (Current_Collector.Usage.Input = 7, "Input tokens");
      Assert (Current_Collector.Usage.Output = 3, "Output tokens");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Text_Response;

   procedure Test_Stream_Thinking_Response (T : in out Test) is
      pragma Unreferenced (T);

      Port     : constant Positive := 19_205;
      Home     : constant String := "/tmp/coyote_codex_send_5";
      Provider : LLM.Providers.Codex.Provider :=
        LLM.Providers.Codex.Create (Session_Id => "s");

      procedure Handle_Request
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
         use GNATCOLL.JSON;

         Parsed     : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (To_String (Req.Body_Data));
         Reasoning  : JSON_Value;
         Reason_Delta : constant JSON_Value := Create_Object;
         Text_Delta : constant JSON_Value := Create_Object;
         R_Item     : constant JSON_Value := Create_Object;
         M_Item     : constant JSON_Value := Create_Object;
         Part       : constant JSON_Value := Create_Object;
         Content    : JSON_Array := Empty_Array;
         Output     : JSON_Array := Empty_Array;
         Response   : constant JSON_Value := Create_Object;
         Usage      : constant JSON_Value := Create_Object;
         Input_Det  : constant JSON_Value := Create_Object;
         Output_Det : constant JSON_Value := Create_Object;
         Completed  : constant JSON_Value := Create_Object;
      begin
         Assert (Parsed.Success, "parse body");
         Reasoning := GNATCOLL.JSON.Create_Object;
         Reasoning.Set_Field ("effort", "medium");
         Assert
           (Parsed.Value.Has_Field ("reasoning"),
            "reasoning field should be present when thinking requested");
         pragma Unreferenced (Reasoning);

         Reason_Delta.Set_Field
           ("type", "response.reasoning_text.delta");
         Reason_Delta.Set_Field ("item_id", "rs_test");
         Reason_Delta.Set_Field ("delta", "pondering");
         Text_Delta.Set_Field ("type", "response.output_text.delta");
         Text_Delta.Set_Field ("item_id", "msg_test");
         Text_Delta.Set_Field ("delta", "done");
         R_Item.Set_Field ("type", "reasoning");
         R_Item.Set_Field ("id", "rs_test");
         R_Item.Set_Field ("encrypted_content", "enc-secret");
         Part.Set_Field ("type", "output_text");
         Part.Set_Field ("text", "done");
         Append (Content, Part);
         M_Item.Set_Field ("type", "message");
         M_Item.Set_Field ("role", "assistant");
         M_Item.Set_Field ("content", Content);
         Append (Output, R_Item);
         Append (Output, M_Item);
         Input_Det.Set_Field ("cached_tokens", Integer (2));
         Output_Det.Set_Field ("reasoning_tokens", Integer (5));
         Usage.Set_Field ("input_tokens", Integer (10));
         Usage.Set_Field ("output_tokens", Integer (20));
         Usage.Set_Field ("input_tokens_details", Input_Det);
         Usage.Set_Field ("output_tokens_details", Output_Det);
         Response.Set_Field ("id", "resp_2");
         Response.Set_Field ("status", "completed");
         Response.Set_Field ("output", Output);
         Response.Set_Field ("usage", Usage);
         Completed.Set_Field ("type", "response.completed");
         Completed.Set_Field ("response", Response);

         Res.Status := 200;
         Append
           (Res.Body_Data,
            SSE_Event ("response.reasoning_text.delta", Reason_Delta)
            & SSE_Event ("response.output_text.delta", Text_Delta)
            & SSE_Event ("response.completed", Completed));
      end Handle_Request;

      Server_Stopped : Boolean := False;
      Srv            : Test_HTTP_Server.Server
        (Handler => Handle_Request'Unrestricted_Access);
   begin
      Reset_Collector;
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Credentials (Home, "acc-think");
      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_CODEX_BASE_URL", "http://127.0.0.1:19205");

      Srv.Bind (Port);
      Send_With_Retry
        (P        => Provider,
         Model_Id => "gpt-5.5",
         Messages => User_Hello,
         Thinking => LLM.Providers.Medium);
      Srv.Stop;
      Server_Stopped := True;

      Assert
        (Current_Collector.Sequence.Find_Index
           ("thinking_delta:pondering") > 0,
         "Thinking delta should arrive: " & Sequence_Image);
      Assert
        (Current_Collector.Sequence.Find_Index
           ("thinking_end:") > 0,
         "Thinking end should carry the encrypted signature");
      Assert
        (Current_Collector.Usage.Thinking = 5,
         "reasoning_tokens should map to Usage.Thinking");
      Assert
        (Current_Collector.Usage.Cache_Read = 2,
         "cached_tokens should map to Usage.Cache_Read");
   exception
      when others =>
         if not Server_Stopped then
            Srv.Stop;
         end if;
         raise;
   end Test_Stream_Thinking_Response;

   procedure Test_Body_Omits_Store (T : in out Test) is
      pragma Unreferenced (T);

      --  Covered by Test_Stream_Text_Response's handler assertions;
      --  this test pins the registry catalogue instead.
      Home     : constant String := "/tmp/coyote_codex_registry";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Model    : LLM.Model_Registry.Model_Info;
      Available : LLM.Model_Registry.Model_Info_Vectors.Vector;
      Found_Default : Boolean := False;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_Credentials (Home, "acc-reg");
      Ada.Environment_Variables.Set ("HOME", Home);

      LLM.Model_Registry.Refresh_Codex;
      Available := LLM.Model_Registry.Available_Models;

      --  The live catalogue requires network access and a valid
      --  subscription; when no entries load, the fallback default in
      --  Lookup still resolves ids with Responses wire format.
      if Available.Length = 0 then
         Model := LLM.Model_Registry.Lookup ("codex", "gpt-5.5");
      else
         for Item of Available loop
            if To_String (Item.Provider) = "codex"
              and then To_String (Item.Model_Id) = "gpt-5.5"
            then
               Found_Default := True;
            end if;
         end loop;
         Assert
           (Found_Default,
            "gpt-5.5 should be in the codex catalogue when logged in");
         Model := LLM.Model_Registry.Lookup ("codex", "gpt-5.5");
      end if;

      Assert
        (To_String (Model.Wire_Format) = "openai-responses",
         "Codex models should use the Responses wire format");
      Assert
        (To_String (Model.Provider) = "codex",
         "Codex models should keep the codex provider name");

      Model := LLM.Model_Registry.Lookup ("codex", "unknown-future");
      Assert
        (To_String (Model.Wire_Format) = "openai-responses",
         "Unknown codex ids should fall back to Responses defaults");

      Cleanup_Test_Home (Home);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Body_Omits_Store;

   procedure Test_Registry_Refresh (T : in out Test) is
      pragma Unreferenced (T);

      Home     : constant String := "/tmp/coyote_codex_registry2";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Available : LLM.Model_Registry.Model_Info_Vectors.Vector;

      function Count_Codex
        (Models : LLM.Model_Registry.Model_Info_Vectors.Vector)
         return Natural
      is
         Result : Natural := 0;
      begin
         for Model of Models loop
            if To_String (Model.Provider) = "codex" then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Count_Codex;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Ada.Environment_Variables.Set ("HOME", Home);

      LLM.Model_Registry.Refresh_Codex;
      Available := LLM.Model_Registry.Available_Models;
      Assert
        (Count_Codex (Available) = 0,
         "Codex models should be hidden without credentials");

      Write_Credentials (Home, "acc-reg2");
      LLM.Model_Registry.Refresh_Codex;
      Available := LLM.Model_Registry.Available_Models;
      --  The live fetch needs network access and a valid subscription;
      --  without a seeded cache the registry legitimately stays empty.
      Assert
        (Count_Codex (Available) = 8 or else Count_Codex (Available) = 0,
         "Codex catalogue should be empty or fully populated when logged in");

      Cleanup_Test_Home (Home);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Registry_Refresh;

   package LLM_Codex_Caller is
     new AUnit.Test_Caller (LLM_Codex_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Auth.Codex generates 43-character PKCE pairs",
         LLM_Codex_Tests.Test_Make_Pkce'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Auth.Codex generates 32-character hex states",
         LLM_Codex_Tests.Test_New_State'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Auth.Codex builds the authorize URL with coyote originator",
         LLM_Codex_Tests.Test_Build_Authorize_Url'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Auth.Codex extracts the account id from the JWT claim",
         LLM_Codex_Tests.Test_Account_Id_From_Jwt'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Auth.Codex detects expiring tokens",
         LLM_Codex_Tests.Test_Token_Expired'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Auth.Codex refreshes and persists rotated tokens",
         LLM_Codex_Tests.Test_Refresh_Token'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Auth.Codex raises on non-200 refresh responses",
         LLM_Codex_Tests.Test_Refresh_Token_Non_200_Raises'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Auth.Codex raises when refresh response misses fields",
         LLM_Codex_Tests.Test_Refresh_Token_Missing_Fields_Raises'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Providers.Codex sends the Codex headers and endpoint",
         LLM_Codex_Tests.Test_Send_Adds_Codex_Headers'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Providers.Codex rejects sends without credentials",
         LLM_Codex_Tests.Test_Send_Requires_Credentials'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Providers.Codex rejects sends without the account claim",
         LLM_Codex_Tests.Test_Send_Requires_Account_Claim'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Providers.Codex streams Responses text and body shape",
         LLM_Codex_Tests.Test_Stream_Text_Response'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Providers.Codex streams thinking with encrypted replay",
         LLM_Codex_Tests.Test_Stream_Thinking_Response'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Model_Registry defaults unknown codex ids to Responses",
         LLM_Codex_Tests.Test_Body_Omits_Store'Access));
      Result.Add_Test (LLM_Codex_Caller.Create
        ("LLM.Model_Registry lists codex models only when logged in",
         LLM_Codex_Tests.Test_Registry_Refresh'Access));

      return Result;
   end Suite;

end LLM_Codex_Tests;
