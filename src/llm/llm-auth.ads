--  LLM.Auth -- provider credential storage helpers.
--
--  Reads and writes `~/.pi/agent/auth.json` for providers that store
--  refreshable credentials, including GitHub Copilot.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.Auth is

   type Provider_Credentials is record
      Credential_Type : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Refresh_Token   : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Access_Token    : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Expires_Ms      : Long_Long_Integer := 0;
   end record;

   --  Read credentials for Provider from ~/.pi/agent/auth.json.
   --
   --  Returns an all-empty record when the auth file is missing, the file
   --  cannot be parsed, or the named provider entry is absent.
   function Load_Credentials (Provider : String) return Provider_Credentials;

   --  Write credentials for Provider to ~/.pi/agent/auth.json.
   --
   --  The file is updated atomically by writing a temporary file in the same
   --  directory and renaming it over the original path.
   procedure Save_Credentials
     (Provider : String;
      Creds    : Provider_Credentials);

end LLM.Auth;
