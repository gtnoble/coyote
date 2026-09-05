with AUnit.Assertions;
with Ada.Calendar;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Test_Caller;
with AUnit.Test_Suites;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Test_HTTP_Server;
with LLM.Auth;
with LLM.Auth.GitHub_Copilot;

package body LLM_Auth_Tests is

   use AUnit.Assertions;

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

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

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

   function Auth_Fixture_Path return String is
   begin
      return Ada.Directories.Current_Directory & "/fixtures/auth.json";
   end Auth_Fixture_Path;

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

   function Refresh_Test_Auth_Content return String is
   begin
      return
        "{" & ASCII.LF
        & "  ""github-copilot"": {" & ASCII.LF
        & "    ""type"": ""oauth""," & ASCII.LF
        & "    ""refresh"": ""refresh-token""," & ASCII.LF
        & "    ""access"": ""expired-token""," & ASCII.LF
        & "    ""expires"": 0" & ASCII.LF
        & "  }" & ASCII.LF
        & "}" & ASCII.LF;
   end Refresh_Test_Auth_Content;

   function Is_Transient_Connect_Error (Message : String) return Boolean is
   begin
      return Contains (Message, "Couldn't connect")
        or else Contains (Message, "Failed to connect")
        or else Contains (Message, "Connection refused");
   end Is_Transient_Connect_Error;

   procedure Run_Refresh_Failure_Test
     (Home                  : String;
      Port                  : Positive;
      Status_Code           : Positive;
      Response_Body         : String;
      Expected_Message_Part : String;
      Content_Type          : String := "application/json")
   is
      Home_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home      : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Url_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists
          ("COYOTE_GITHUB_COPILOT_TOKEN_URL");
      Old_Url       : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_GITHUB_COPILOT_TOKEN_URL", "");
      Original_Auth : constant String := Refresh_Test_Auth_Content;
      Creds         : LLM.Auth.Provider_Credentials;
      Saved         : LLM.Auth.Provider_Credentials;
      Raised        : Boolean := False;
      Error_Message : Unbounded_String;

      procedure Failure_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Assert
           (To_String (Req.Path) = "/copilot_internal/v2/token",
            "Refresh request should target the token endpoint");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "Authorization")
              = "Bearer refresh-token",
            "Refresh request should carry the stored refresh token");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "User-Agent")
              = "GitHubCopilotChat/0.35.0",
            "Refresh request should carry the Copilot User-Agent");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "Editor-Version")
              = "vscode/1.107.0",
            "Refresh request should carry the Editor-Version header");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Editor-Plugin-Version")
              = "copilot-chat/0.35.0",
            "Refresh request should carry the Editor-Plugin-Version header");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Copilot-Integration-Id")
              = "vscode-chat",
            "Refresh request should carry the Copilot-Integration-Id header");
         Res.Status := Status_Code;
         Res.Headers.Append
           ((Name  => To_Unbounded_String ("Content-Type"),
             Value => To_Unbounded_String (Content_Type)));
         Append (Res.Body_Data, Response_Body);
      end Failure_Handler;

      Srv : Test_HTTP_Server.Server
        (Handler => Failure_Handler'Unrestricted_Access);

   begin
      Srv.Bind (Port);
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_File (Home & "/.coyote/auth.json", Original_Auth);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_GITHUB_COPILOT_TOKEN_URL",
         "http://127.0.0.1:" & Natural_Image (Port)
         & "/copilot_internal/v2/token");

      Creds := LLM.Auth.Load_Credentials ("github-copilot");

      Retry_Loop :
      for Attempt in 1 .. 20 loop
         begin
            LLM.Auth.GitHub_Copilot.Refresh_Token (Creds);
            exit Retry_Loop;
         exception
            when E : LLM.Auth.GitHub_Copilot.Auth_Error =>
               Error_Message :=
                 To_Unbounded_String
                   (Ada.Exceptions.Exception_Message (E));

               if Is_Transient_Connect_Error (To_String (Error_Message))
                 and then Attempt < 20
               then
                  delay 0.05;
               else
                  Raised := True;
                  exit Retry_Loop;
               end if;
         end;
      end loop Retry_Loop;

      Srv.Stop;
      Saved := LLM.Auth.Load_Credentials ("github-copilot");

      Assert (Raised, "Refresh_Token should raise Auth_Error");
      Assert
        (Contains (To_String (Error_Message), Expected_Message_Part),
         "Refresh_Token should report the expected failure; got: "
         & To_String (Error_Message));
      Assert
        (Read_File (Home & "/.coyote/auth.json") = Original_Auth,
         "auth.json should remain unchanged after a failed refresh");
      Assert
        (To_String (Saved.Refresh_Token) = "refresh-token",
         "A failed refresh should preserve the stored refresh token");
      Assert
        (To_String (Saved.Access_Token) = "expired-token",
         "A failed refresh should preserve the stored access token");
      Assert
        (Saved.Expires_Ms = 0,
         "A failed refresh should preserve the stored expiration");

      Restore_Env
        ("COYOTE_GITHUB_COPILOT_TOKEN_URL", Url_Was_Set, Old_Url);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Srv.Stop;
         Restore_Env
           ("COYOTE_GITHUB_COPILOT_TOKEN_URL", Url_Was_Set, Old_Url);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Run_Refresh_Failure_Test;

   procedure Test_Load_Credentials (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_llm_auth_test_1";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Loaded       : LLM.Auth.Provider_Credentials;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_File
        (Home & "/.coyote/auth.json",
         Read_File (Auth_Fixture_Path));

      Ada.Environment_Variables.Set ("HOME", Home);
      Loaded := LLM.Auth.Load_Credentials ("github-copilot");

      Assert
        (To_String (Loaded.Credential_Type) = "oauth",
         "Credential type should be loaded from auth.json");
      Assert
        (To_String (Loaded.Refresh_Token) = "fixture-refresh-token",
         "Refresh token should be loaded from auth.json");
      Assert
        (Contains (To_String (Loaded.Access_Token), "proxy-ep="),
         "Access token should be loaded from auth.json");
      Assert
        (Loaded.Expires_Ms = 1_748_000_000_000,
         "Expires_Ms should be loaded from auth.json");
      Assert
        (LLM.Auth.Load_Credentials ("missing-provider").Expires_Ms = 0,
         "Missing providers should return an empty credential record");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Load_Credentials;

   procedure Test_Save_Credentials (T : in out Test) is
      pragma Unreferenced (T);

      Home         : constant String := "/tmp/coyote_llm_auth_test_2";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Saved        : constant LLM.Auth.Provider_Credentials :=
        (Credential_Type => To_Unbounded_String ("oauth"),
         Refresh_Token   => To_Unbounded_String ("saved-refresh"),
         Access_Token    => To_Unbounded_String
           ("tid=saved;proxy-ep=proxy.saved.example;exp=42"),
         Expires_Ms      => 1_748_123_456_789);
      Loaded       : LLM.Auth.Provider_Credentials;
      Raw_Auth     : Unbounded_String;
   begin
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);
      Write_File
        (Home & "/.coyote/auth.json",
         Read_File (Auth_Fixture_Path));

      Ada.Environment_Variables.Set ("HOME", Home);
      LLM.Auth.Save_Credentials ("github-copilot", Saved);
      Loaded := LLM.Auth.Load_Credentials ("github-copilot");
      Raw_Auth :=
        To_Unbounded_String (Read_File (Home & "/.coyote/auth.json"));

      Assert
        (To_String (Loaded.Refresh_Token) = "saved-refresh",
         "Save_Credentials should persist the new refresh token");
      Assert
        (To_String (Loaded.Access_Token)
           = "tid=saved;proxy-ep=proxy.saved.example;exp=42",
         "Save_Credentials should persist the new access token");
      Assert
        (Loaded.Expires_Ms = 1_748_123_456_789,
         "Save_Credentials should persist the expiration timestamp");
      Assert
        (Contains (To_String (Raw_Auth), """openrouter"""),
         "Save_Credentials should preserve unrelated provider entries");
      Assert
        (not Ada.Directories.Exists (Home & "/.coyote/auth.json.tmp"),
         "Temporary auth file should not remain after atomic save");

      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Save_Credentials;

   procedure Test_Token_Expired (T : in out Test) is
      pragma Unreferenced (T);

      Now                : constant Long_Long_Integer := Current_Unix_Ms;
      Expired_Creds      : constant LLM.Auth.Provider_Credentials :=
        (Expires_Ms => Now - 1, others => <>);
      Near_Expiry_Creds  : constant LLM.Auth.Provider_Credentials :=
        (Expires_Ms => Now + 240_000, others => <>);
      Valid_Future_Creds : constant LLM.Auth.Provider_Credentials :=
        (Expires_Ms => Now + 360_000, others => <>);
   begin
      Assert
        (LLM.Auth.GitHub_Copilot.Token_Expired (Expired_Creds),
         "Past expirations should be reported as expired");
      Assert
        (LLM.Auth.GitHub_Copilot.Token_Expired (Near_Expiry_Creds),
         "Tokens expiring within five minutes should be refreshed");
      Assert
        (not LLM.Auth.GitHub_Copilot.Token_Expired (Valid_Future_Creds),
         "Tokens expiring more than five minutes ahead should stay valid");
   end Test_Token_Expired;

   procedure Test_Get_Base_Url (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Auth.GitHub_Copilot.Get_Base_Url
           ("tid=abc;proxy-ep=proxy.foo.bar;exp=1")
           = "https://api.foo.bar",
         "proxy-ep should be mapped to the corresponding api host");
   end Test_Get_Base_Url;

   procedure Test_Get_Base_Url_Fallback (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Auth.GitHub_Copilot.Get_Base_Url ("tid=abc;exp=1")
           = "https://api.individual.githubcopilot.com",
         "Tokens without proxy-ep should use the default Copilot base URL");
   end Test_Get_Base_Url_Fallback;

   procedure Test_Refresh_Token (T : in out Test) is
      pragma Unreferenced (T);

      Port         : constant Positive := 18_769;
      Home         : constant String := "/tmp/coyote_llm_auth_test_3";
      Home_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home     : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Url_Was_Set  : constant Boolean :=
        Ada.Environment_Variables.Exists
          ("COYOTE_GITHUB_COPILOT_TOKEN_URL");
      Old_Url      : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_GITHUB_COPILOT_TOKEN_URL", "");
      Creds        : LLM.Auth.Provider_Credentials :=
        (Credential_Type => To_Unbounded_String ("oauth"),
         Refresh_Token   => To_Unbounded_String ("refresh-token"),
         Access_Token    => To_Unbounded_String ("expired-token"),
         Expires_Ms      => 0);
      Saved        : LLM.Auth.Provider_Credentials;

      procedure Refresh_Handler
        (Req :     Test_HTTP_Server.Request;
         Res : out Test_HTTP_Server.Response)
      is
      begin
         Assert
           (To_String (Req.Path) = "/copilot_internal/v2/token",
            "Refresh request should target the token endpoint");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "Authorization")
              = "Bearer refresh-token",
            "Refresh request should carry the stored refresh token");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "User-Agent")
              = "GitHubCopilotChat/0.35.0",
            "Refresh request should carry the Copilot User-Agent");
         Assert
           (Test_HTTP_Server.Get_Header (Req.Headers, "Editor-Version")
              = "vscode/1.107.0",
            "Refresh request should carry the Editor-Version header");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Editor-Plugin-Version")
              = "copilot-chat/0.35.0",
            "Refresh request should carry the Editor-Plugin-Version header");
         Assert
           (Test_HTTP_Server.Get_Header
              (Req.Headers, "Copilot-Integration-Id")
              = "vscode-chat",
            "Refresh request should carry the Copilot-Integration-Id header");
         Res.Status := 200;
         Res.Headers.Append
           ((Name  => To_Unbounded_String ("Content-Type"),
             Value => To_Unbounded_String ("application/json")));
         Append
           (Res.Body_Data,
            "{""token"":"
            & """tid=abc;proxy-ep=proxy.test.com;exp=9999999999"","
            & """expires_at"":9999999999}");
      end Refresh_Handler;

      Srv : Test_HTTP_Server.Server
        (Handler => Refresh_Handler'Unrestricted_Access);

   begin
      Srv.Bind (Port);
      Cleanup_Test_Home (Home);
      Ensure_Test_Home (Home);

      Ada.Environment_Variables.Set ("HOME", Home);
      Ada.Environment_Variables.Set
        ("COYOTE_GITHUB_COPILOT_TOKEN_URL",
         "http://127.0.0.1:18769/copilot_internal/v2/token");

      LLM.Auth.GitHub_Copilot.Refresh_Token (Creds);
      Saved := LLM.Auth.Load_Credentials ("github-copilot");

      Srv.Stop;

      Assert
        (To_String (Creds.Access_Token)
           = "tid=abc;proxy-ep=proxy.test.com;exp=9999999999",
         "Refresh_Token should update the in-memory access token");
      Assert
        (Creds.Expires_Ms = 9_999_999_999_000,
         "Refresh_Token should convert expires_at seconds to milliseconds");
      Assert
        (To_String (Saved.Access_Token) = To_String (Creds.Access_Token),
         "Refresh_Token should persist the refreshed token to auth.json");
      Assert
        (Saved.Expires_Ms = Creds.Expires_Ms,
         "Refresh_Token should persist the refreshed expiration timestamp");

      Restore_Env
        ("COYOTE_GITHUB_COPILOT_TOKEN_URL", Url_Was_Set, Old_Url);
      Restore_Env ("HOME", Home_Was_Set, Old_Home);
      Cleanup_Test_Home (Home);
   exception
      when others =>
         Srv.Stop;
         Restore_Env
           ("COYOTE_GITHUB_COPILOT_TOKEN_URL", Url_Was_Set, Old_Url);
         Restore_Env ("HOME", Home_Was_Set, Old_Home);
         Cleanup_Test_Home (Home);
         raise;
   end Test_Refresh_Token;

   procedure Test_Refresh_Token_Non_200_Raises (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Refresh_Failure_Test
        (Home                  => "/tmp/coyote_llm_auth_test_4",
         Port                  => 18_770,
         Status_Code           => 403,
         Response_Body         => "{""error"":""forbidden""}",
         Expected_Message_Part => "HTTP 403");
   end Test_Refresh_Token_Non_200_Raises;

   procedure Test_Refresh_Token_Invalid_JSON_Raises (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Run_Refresh_Failure_Test
        (Home                  => "/tmp/coyote_llm_auth_test_5",
         Port                  => 18_771,
         Status_Code           => 200,
         Response_Body         => "not valid json",
         Expected_Message_Part =>
           "Invalid GitHub Copilot token refresh response",
         Content_Type          => "text/plain");
   end Test_Refresh_Token_Invalid_JSON_Raises;

   procedure Test_Refresh_Token_Missing_Token_Field_Raises
     (T : in out Test)
   is
      pragma Unreferenced (T);
   begin
      Run_Refresh_Failure_Test
        (Home                  => "/tmp/coyote_llm_auth_test_6",
         Port                  => 18_772,
         Status_Code           => 200,
         Response_Body         => "{""expires_at"":9999999999}",
         Expected_Message_Part => "missing fields");
   end Test_Refresh_Token_Missing_Token_Field_Raises;

   procedure Test_Refresh_Token_Missing_Expires_At_Field_Raises
     (T : in out Test)
   is
      pragma Unreferenced (T);
   begin
      Run_Refresh_Failure_Test
        (Home                  => "/tmp/coyote_llm_auth_test_7",
         Port                  => 18_773,
         Status_Code           => 200,
         Response_Body         => "{""token"":""abc123""}",
         Expected_Message_Part => "missing fields");
   end Test_Refresh_Token_Missing_Expires_At_Field_Raises;


   package LLM_Auth_Caller is
     new AUnit.Test_Caller (LLM_Auth_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
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

      return Result;
   end Suite;

end LLM_Auth_Tests;
