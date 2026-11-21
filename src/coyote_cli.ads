--  Additive maintenance commands, independent of frontend startup.
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_CLI is

   --  Run a recognized first-argument group, including its error path, and
   --  set the process exit status. Return False only for launcher input.
   function Dispatch return Boolean;

   procedure Print_Subcommands;

end Coyote_CLI;
