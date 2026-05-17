--  coyote — Acme window frontend for the native LLM agent.
--
--  Usage: coyote [--session UUID] [--model PROVIDER/ID]
--                 [--agent TEXT|@PATH]
--                 [--no-tools] [--no-session]
--                 [--prompt TEXT|-] [--one-shot] [--subagent] [--name LABEL]
--                 [--prompt-filter CMD]
--
--  --agent TEXT|@PATH
--                 Append extra instructions to the system prompt.
--                 Prefix with '@' to load from a file.
--  --prompt TEXT|-
--                 Send TEXT as the first prompt immediately after startup.
--  --one-shot     Exit automatically after the first complete agent turn,
--                 printing a JSON result line to stdout.  Always selects
--                 the Plain (non-windowed) frontend.
--  --subagent     Like --one-shot but does NOT force Plain: the child
--                 inherits COYOTE_FRONTEND=gui / $winid and opens its own
--                 window.  Use for spawning headful subagents.
--  --name LABEL   Short label appended to the window name as ":LABEL" so
--                 the acme tagline reads "CWD/+coyote:LABEL | …".
--  --prompt-filter CMD
--                 Shell command through which interactive prompts are
--                 filtered before being sent to the agent.  The raw prompt
--                 is written to stdin; stdout is used as the filtered
--                 prompt.  Runs via "$SHELL -c CMD" ($SHELL defaults to
--                 "sh").  Overrides the "promptFilter" settings.json field.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App;
with Coyote_Utils;
with LLM.Session_Store;

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
            declare
               Arg_Val : constant String := Ada.Command_Line.Argument (I);
            begin
               if Arg_Val = "-" then
                  --  Read the prompt from stdin; each Get_Line call
                  --  raises End_Error at EOF, so the End_Of_File guard
                  --  is the safe termination condition.
                  declare
                     Content : Unbounded_String;
                  begin
                     while not Ada.Text_IO.End_Of_File loop
                        Append (Content, Ada.Text_IO.Get_Line);
                        Append (Content, "" & ASCII.LF);
                     end loop;
                     Opts.Initial_Prompt := Content;
                  end;
               else
                  Opts.Initial_Prompt := To_Unbounded_String (Arg_Val);
               end if;
            end;
         elsif Arg = "--one-shot" then
            Opts.One_Shot   := True;
            Opts.No_Compact := True;
         elsif Arg = "--subagent" then
            Opts.One_Shot   := True;
            Opts.Subagent   := True;
            Opts.No_Compact := True;
         elsif Arg = "--name"
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Name :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         elsif Arg = "--prompt-filter"
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Prompt_Filter :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Unknown argument: " & Arg);
         end if;
      end;
      I := I + 1;
   end loop;
   --  Inherit No_Session from the parent process when spawned as a
   --  subagent.  The parent sets COYOTE_NO_SESSION=1 before spawning
   --  so that --no-session propagates to all descendants automatically.
   if Ada.Environment_Variables.Exists ("COYOTE_NO_SESSION") then
      Opts.No_Session := True;
   end if;

   --  Propagate No_Session to child processes for this invocation.
   if Opts.No_Session then
      Ada.Environment_Variables.Set ("COYOTE_NO_SESSION", "1");
   end if;

   --  When resuming a session, change to the working directory that was
   --  current when the session was created so all relative paths resolve
   --  consistently.  If the stored directory no longer exists, record a
   --  warning for display in the acme window after it opens.
   if Length (Opts.Session_Id) > 0 then
      declare
         Wd : constant String :=
           LLM.Session_Store.Session_Work_Dir
             (To_String (Opts.Session_Id));
      begin
         if Wd /= "" then
            if Ada.Directories.Exists (Wd) then
               Ada.Directories.Set_Directory (Wd);
            else
               declare
                  Msg : constant String :=
                    "Session work dir no longer exists: " & Wd;
               begin
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error, "[!] " & Msg);
                  Opts.Work_Dir_Warning := To_Unbounded_String (Msg);
               end;
            end if;
         end if;
      end;
   end if;

   --  ── Frontend detection ────────────────────────────────────────────────
   --  Priority:
   --    1. --one-shot (non-subagent)          → Plain
   --    2. $winid non-zero (set by acme per exec.c:1584) → Acme
   --    3. $DISPLAY or $WAYLAND_DISPLAY set   → GUI
   --    4. COYOTE_FRONTEND=gui                → GUI
   --    5. otherwise                          → Plain
   if Opts.One_Shot and then not Opts.Subagent then
      Opts.Frontend := Coyote_App.Plain_Frontend;
   elsif Ada.Environment_Variables.Value ("winid", "0") /= "0"
   then
      Opts.Frontend := Coyote_App.Acme_Frontend;
   elsif (Ada.Environment_Variables.Exists ("DISPLAY")
            and then
              Ada.Environment_Variables.Value ("DISPLAY", "")'Length > 0)
     or else (Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY")
                and then
                  Ada.Environment_Variables.Value
                    ("WAYLAND_DISPLAY", "")'Length > 0)
     or else Ada.Environment_Variables.Value ("COYOTE_FRONTEND", "") = "gui"
   then
      Opts.Frontend := Coyote_App.GUI_Frontend;
   else
      Opts.Frontend := Coyote_App.Plain_Frontend;
   end if;

   --  Propagate GUI context to child processes (subagents inherit this
   --  and open their own GTK windows automatically).
   case Opts.Frontend is
      when Coyote_App.GUI_Frontend =>
         Ada.Environment_Variables.Set ("COYOTE_FRONTEND", "gui");
      when others => null;
   end case;

   case Opts.Frontend is
      when Coyote_App.Acme_Frontend | Coyote_App.Plain_Frontend =>
         Coyote_App.Run (Opts);
      when Coyote_App.GUI_Frontend =>
         Coyote_App.Run_GUI (Opts);
   end case;
exception
   when E : Coyote_Utils.Bad_Arg_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Coyote;
