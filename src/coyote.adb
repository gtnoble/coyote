--  coyote — Acme window frontend for the native LLM agent.
--
--  Usage: coyote [--session UUID] [--model PROVIDER/ID]
--                 [--agent NAME] [--custom-prompt TEXT|@PATH]
--                 [--no-tools] [--no-session]
--                 [--prompt TEXT] [--one-shot] [--name LABEL]
--
--  --agent NAME   Use the named agent definition (looked up from the
--                 discovered AGENT.md catalogue).
--  --custom-prompt TEXT|@PATH
--                 Append extra instructions to the system prompt.
--                 Prefix with '@' to load from a file.
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
with Ada.Exceptions;
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
              To_Unbounded_String
                (Coyote_Utils.Strip_Session_Prefix
                   (Ada.Command_Line.Argument (I)));
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
            Opts.Agent :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         elsif Arg = "--custom-prompt"
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Custom_Prompt :=
              To_Unbounded_String
                (Coyote_Utils.Resolve_Text_Arg
                   (Ada.Command_Line.Argument (I)));
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
exception
   when E : Coyote_Utils.Bad_Arg_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Coyote;
