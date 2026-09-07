--  LLM.Auth.Codex -- OpenAI Codex subscription OAuth credentials.
--
--  Implements the ChatGPT Plus/Pro subscription OAuth flow used by the
--  Codex backend: PKCE browser login with a local callback server, token
--  exchange and refresh against auth.openai.com, and extraction of the
--  ChatGPT account id from the access-token JWT.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with LLM.Auth;

package LLM.Auth.Codex is

   Auth_Error : exception;

   --  Constants describing the OAuth endpoint set.  Exposed for tests.
   Client_Id        : constant String := "app_EMoamEEZ73f0CkXaXp7hrann";
   User_Agent_Value : constant String := "coyote/0.1.0-dev";
   Auth_Base_Url    : constant String := "https://auth.openai.com";
   Authorize_Url    : constant String :=
     Auth_Base_Url & "/oauth/authorize";
   Token_Url        : constant String :=
     Auth_Base_Url & "/oauth/token";
   --  Local callback listener port for the browser flow.  The redirect
   --  URI stays http://localhost:1455/auth/callback as registered with
   --  the OpenAI OAuth client.
   Redirect_Port    : constant Positive := 1455;
   Redirect_Host    : constant String := "127.0.0.1";
   Redirect_Path    : constant String := "/auth/callback";
   Redirect_Uri     : constant String :=
     "http://localhost:1455/auth/callback";
   Scope            : constant String :=
     "openid profile email offline_access";
   Jwt_Claim_Path   : constant String := "https://api.openai.com/auth";

   --  Build the PKCE code verifier (43 unreserved characters) and its
   --  S256 challenge (base64url of the SHA-256 digest).
   procedure Make_Pkce
     (Verifier  :    out Ada.Strings.Unbounded.Unbounded_String;
      Challenge :    out Ada.Strings.Unbounded.Unbounded_String);

   --  Return a random 16-byte hex state value.
   function New_State return String;

   --  Return the authorize URL to open in a browser.  State is a random
   --  16-byte hex value; the caller must retain it for callback
   --  validation.
   function Build_Authorize_Url
     (Code_Challenge : String;
      State          : String) return String;

   --  Extract the ChatGPT account id from a JWT access token by
   --  decoding the payload claim "https://api.openai.com/auth" ->
   --  "chatgpt_account_id".  Returns "" when the claim is absent.
   function Account_Id_From_Jwt (Access_Token : String) return String;

   --  Exchange an authorization code for tokens.  Redirect_Uri_Override
   --  replaces the default redirect URI.  On success the credential
   --  record carries the access/refresh tokens, the expiry in epoch
   --  milliseconds, and the account id extracted from the new access
   --  token.  Raises Auth_Error on failure.  The credential is NOT
   --  persisted here; the caller owns persistence.
   procedure Exchange_Code
     (Code                  :     String;
      Code_Verifier         :     String;
      Redirect_Uri_Override :     String := "";
      Creds                 : out LLM.Auth.Provider_Credentials);

   --  Refresh an existing credential.  Updates Creds in place and
   --  persists the result to ~/.coyote/auth.json.  Raises Auth_Error on
   --  transport, parse, or missing-field failures.
   procedure Refresh_Token (Creds : in out LLM.Auth.Provider_Credentials);

   --  Return True when the access token is missing or expires within
   --  five minutes.
   function Token_Expired (Creds : LLM.Auth.Provider_Credentials)
      return Boolean;

   --  Ensure the credential carries a non-expired access token,
   --  refreshing (and re-extracting the account id) when needed.
   --  Serialised across tasks.
   procedure Ensure_Valid (Creds : in out LLM.Auth.Provider_Credentials);

end LLM.Auth.Codex;
