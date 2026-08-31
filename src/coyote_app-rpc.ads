--  Coyote_App.RPC — headless coordinator-channel runner.
--
--  Creates the RPC frontend from explicit process environment context and
--  delegates agent/session lifecycle to Coyote_App.Headless.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_App.RPC is

   procedure Run (Opts : Coyote_App.Options);

end Coyote_App.RPC;
