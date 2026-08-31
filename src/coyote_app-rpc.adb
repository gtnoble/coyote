--  Coyote_App.RPC body.
--
--  RPC mode is opt-in through an explicit endpoint and runtime identity.  This
--  prevents display inheritance from turning an ordinary subagent into a GUI.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Text_IO;
with Coyote_Utils;
with Coyote_App.Frontend.RPC;
with Coyote_App.Headless;

package body Coyote_App.RPC is

   procedure Run (Opts : Coyote_App.Options) is
      Endpoint : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_RPC_ENDPOINT", "");
      Agent_Id : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_RUNTIME_AGENT_ID", "");
      Parent_Id : constant String :=
        Ada.Environment_Variables.Value
          ("COYOTE_PARENT_RUNTIME_AGENT_ID", "");
      Label : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_AGENT_LABEL", "subagent");
      Frontend : Coyote_App.Frontend.RPC.Instance;
   begin
      if Endpoint'Length = 0 or else Agent_Id'Length = 0 then
         raise Coyote_Utils.Bad_Arg_Error with
           "RPC frontend requires COYOTE_RPC_ENDPOINT and "
           & "COYOTE_RUNTIME_AGENT_ID";
      end if;
      Frontend.Create
        (Endpoint        => Endpoint,
         Agent_Id        => Agent_Id,
         Parent_Agent_Id => Parent_Id,
         Label           => Label);
      Coyote_App.Headless.Run (Opts, Frontend);
   exception
      when E : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] RPC runner: " & Ada.Exceptions.Exception_Message (E));
   end Run;

end Coyote_App.RPC;
