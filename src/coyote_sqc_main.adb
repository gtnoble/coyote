--  coyote_sqc — Coyote Session Quality Control application.
--
--  Entry point.  Parses optional command-line workspace path and runs
--  the GTK main loop via Coyote_SQC.App.Run.
--
--  Project: coyote

with Ada.Command_Line;
with Coyote_SQC.App;

procedure Coyote_SQC_Main is
   Workspace_Path : constant String :=
     (if Ada.Command_Line.Argument_Count > 0
      then Ada.Command_Line.Argument (1)
      else "");
begin
   Coyote_SQC.App.Run (Workspace_Path);
end Coyote_SQC_Main;
