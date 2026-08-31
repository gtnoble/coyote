--  Coyote_App.Headless — common non-GTK agent lifecycle runner.
--
--  Runs one agent session through any abstract frontend.  Concrete frontends
--  are initialized by their wrappers before calling Run; this unit preserves
--  one-shot result handling, session replay, process monitoring, and shutdown.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_App.Frontend;

package Coyote_App.Headless is

   procedure Run
     (Opts     : Coyote_App.Options;
      Frontend : in out Coyote_App.Frontend.Instance'Class);

end Coyote_App.Headless;
