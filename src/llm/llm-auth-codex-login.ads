--  LLM.Auth.Codex.Login -- browser OAuth login flow for OpenAI Codex.
--
--  Runs the PKCE authorization-code login: starts a local HTTP callback
--  listener, builds the authorize URL for the user to open in a browser,
--  waits for the redirected authorization code (or an acceptor-supplied
--  manual code), exchanges it for tokens, and persists the credential.
--
--  The caller supplies an Open_Authorize_Url callback so the login can
--  be driven from a GUI or a console prompt; On_Progress reports each
--  phase transition.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with LLM.Auth;

package LLM.Auth.Codex.Login is

   --  Phase labels reported through On_Progress.
   type Progress_Kind is
     (Listening,
      Waiting_For_Browser,
      Callback_Received,
      Exchanging_Token,
      Done);

   Login_Error : exception;

   --  Deliver a manual authorization code.  Called from any task; the
   --  login loop consumes whichever arrives first, the browser callback
   --  or a manual code.
   procedure Provide_Manual_Code (Code : String);

   --  Cancel a running login.  Safe to call from any task.
   procedure Cancel;

   --  Run one browser login to completion and persist the resulting
   --  credential under the "codex" key of ~/.coyote/auth.json.
   --
   --  Open_Authorize_Url is called once with the URL the user should
   --  visit; a GUI caller launches a browser, a console caller prints
   --  it.  On_Progress reports phase transitions; both may be null.
   --  Raises Login_Error on transport failure, state mismatch, cancel,
   --  or timeout.
   procedure Browser_Login
     (Open_Authorize_Url :     access procedure (Url : String);
      On_Progress        :     access procedure
        (Phase : Progress_Kind; Detail : String) :=
        null;
      Creds              : out LLM.Auth.Provider_Credentials);

end LLM.Auth.Codex.Login;
