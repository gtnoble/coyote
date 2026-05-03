--  coyote — Acme window frontend for the native LLM agent.
--
--  Usage: coyote [--session UUID] [--model PROVIDER/ID]
--                 [--agent NAME] [--no-tools] [--no-session]
--                 [--prompt TEXT] [--one-shot] [--name LABEL]
--
--  --prompt TEXT  Send TEXT as the first prompt immediately after startup.
--  --one-shot     Exit automatically after the first complete agent turn,
--                 printing a JSON result line to stdout.  Intended for use
--                 by the native spawn_subagent tool.
--  --name LABEL   Short label appended to the window name as ":LABEL" so
--                 the acme tagline reads "CWD/+coyote:LABEL | …".
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App;
with Coyote_Utils;

procedure Coyote is
   Opts : Coyote_App.Options;
   I    : Positive := 1;
begin
   while I <= Ada.Command_Line.Argument_Count loop
      declare
         Arg : constant String := Ada.Command_Line.Argument (I);
      begin
         if Arg = "--session"
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Session_Id :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         elsif Arg = "--model"
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Model :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         elsif Arg = "--agent"
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            declare
               Raw   : constant String := Ada.Command_Line.Argument (I);
               Fread : constant String :=
                 Coyote_Utils.Read_File_If_Exists (Raw);
            begin
               Opts.Agent :=
                 To_Unbounded_String (if Fread'Length > 0 then Fread else Raw);
            end;
         elsif Arg = "--no-tools" then
            Opts.No_Tools := True;
         elsif Arg = "--no-session" then
            Opts.No_Session := True;
         elsif Arg = "--prompt"
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Initial_Prompt :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         elsif Arg = "--one-shot" then
            Opts.One_Shot   := True;
            Opts.No_Session := True;
         elsif Arg = "--name"
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Name :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Unknown argument: " & Arg);
         end if;
      end;
      I := I + 1;
   end loop;

   Coyote_App.Run (Opts);
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
end Coyote;
