--  LLM.Auth.GitHub_Copilot -- GitHub Copilot credential refresh.
--
--  Handles Copilot access-token expiry, refresh, and dynamic API base-URL
--  extraction from the short-lived access token.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

package LLM.Auth.GitHub_Copilot is

   --  Return True when the current access token has expired or is within
   --  five minutes of expiry.
   function Token_Expired (Creds : Provider_Credentials) return Boolean;

   --  Extract the API base URL from Token's `proxy-ep=` field.
   --
   --  For example:
   --    tid=...;proxy-ep=proxy.individual.githubcopilot.com;...
   --  becomes:
   --    https://api.individual.githubcopilot.com
   --
   --  Returns the standard individual-plan endpoint when the token does not
   --  contain a proxy-ep component.
   function Get_Base_Url (Token : String) return String;

   --  Refresh the short-lived Copilot API token using Creds.Refresh_Token.
   --
   --  On success, updates Creds.Access_Token and Creds.Expires_Ms in place and
   --  persists the refreshed record back to ~/.pi/agent/auth.json.
   --  Raises Auth_Error on any HTTP, parse, or persistence failure.
   procedure Refresh_Token (Creds : in out Provider_Credentials);

   --  Ensure that Creds contains a valid, non-expired access token.
   --
   --  Concurrent callers are serialized so only one refresh happens at a time.
   procedure Ensure_Valid (Creds : in out Provider_Credentials);

   Auth_Error : exception;

   --  Static headers required on GitHub Copilot API requests.
   User_Agent_Header     : constant String :=
     "User-Agent: GitHubCopilotChat/0.35.0";
   Editor_Version_Header : constant String :=
     "Editor-Version: vscode/1.107.0";
   Editor_Plugin_Header  : constant String :=
     "Editor-Plugin-Version: copilot-chat/0.35.0";
   Integration_Id_Header : constant String :=
     "Copilot-Integration-Id: vscode-chat";
   Intent_Header         : constant String :=
     "Openai-Intent: conversation-edits";

end LLM.Auth.GitHub_Copilot;
