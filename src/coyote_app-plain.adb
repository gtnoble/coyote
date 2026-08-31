--  Coyote_App.Plain body.
--
--  Project: coyote

with Coyote_App.Frontend.Plain;
with Coyote_App.Headless;

package body Coyote_App.Plain is

   procedure Run (Opts : Coyote_App.Options) is
      Frontend : Coyote_App.Frontend.Plain.Instance;
   begin
      Frontend.Create (Opts.One_Shot);
      Coyote_App.Headless.Run (Opts, Frontend);
   end Run;

end Coyote_App.Plain;
