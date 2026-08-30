--  Coyote_App.Plain — headless application runner.
--
--  Provides non-GTK execution for one-shot, piped, and no-display modes.
--  The runner owns no windowing or desktop integration resources.
--
--  Project: coyote

package Coyote_App.Plain is

   --  Run the agent without GTK or another windowing frontend.
   --  One-shot and subagent invocations emit one JSON result record on
   --  standard output.  Presentation output is sent to standard error.
   procedure Run (Opts : Coyote_App.Options);

end Coyote_App.Plain;
