--  coyote — native LLM coding agent with GUI and plain frontends.
--
--  Usage: coyote [--session UUID] [--model PROVIDER/ID]
--                 [--agent TEXT|@PATH]
--                 [--no-tools] [--no-session]
--                 [--prompt TEXT|-] [--one-shot] [--subagent] [--name LABEL]
--                 [--prompt-filter CMD]
--                 [--frontend gui|plain|rpc] [-h|--help]
--
--  --agent TEXT|@PATH
--                 Append extra instructions to the system prompt.
--                 Prefix with '@' to load from a file.
--  --prompt TEXT|-
--                 Send TEXT as the first prompt immediately after startup.
--  --one-shot     Exit automatically after the first complete agent turn,
--                 printing a JSON result line to stdout.  Always selects
--                 the Plain (non-windowed) frontend.
--  --subagent     Like --one-shot but preserves inherited GUI context when
--                 one is available.  Use for spawning GUI subagents.
--  --name LABEL   Optional label appended to the GUI window title.
--  --prompt-filter CMD
--                 Shell command through which interactive prompts are
--                 filtered before being sent to the agent.  The raw prompt
--                 is written to stdin; stdout is used as the filtered
--                 prompt.  Runs via "$SHELL -c CMD" ($SHELL defaults to
--                 "sh").  Overrides the "promptFilter" settings.json field.

--  --frontend gui|plain|rpc
--                 Override automatic frontend detection.
--  --debug-logging        Enable conversation debug logging to stderr
--                         (disabled by default).
--
--  -h, --help     Print this help message and exit.
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Command_Line;

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App;
with Coyote_App.Plain;
with Coyote_App.RPC;
with Coyote_Process_Control;
with GNAT.OS_Lib;
with Coyote_Utils;
with LLM.Session_Store;
with LLM.Settings;

procedure Coyote is
   use type Coyote_App.Frontend_Kind;

   Opts : Coyote_App.Options;
   I    : Positive := 1;

   function Parse_Natural (Text : String) return Natural is
      Value : Long_Long_Integer := 0;
   begin
      if Text'Length = 0 then
         raise Constraint_Error with "empty recursion depth";
      end if;

      for Character_Value of Text loop
         declare
            Digit : Long_Long_Integer;
         begin
            if Character_Value not in '0' .. '9' then
               raise Constraint_Error with
                 "recursion depth is not a nonnegative integer";
            end if;
            Digit := Long_Long_Integer
              (Character'Pos (Character_Value) - Character'Pos ('0'));
            if Value >
              (Long_Long_Integer (Natural'Last) - Digit) / 10
            then
               raise Constraint_Error with
                 "recursion depth is too large";
            end if;
            Value := Value * 10 + Digit;
         end;
      end loop;

      return Natural (Value);
   end Parse_Natural;

   procedure Initialize_Recursion_Depth is
      Depth_Is_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("COYOTE_RECURSION_DEPTH");
      Current_Text : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_RECURSION_DEPTH", "");
      Current_Depth  : Natural := 0;
      Next_Depth     : Natural := 0;
      Settings_Value : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;
   begin
      if Depth_Is_Set then
         begin
            Current_Depth := Parse_Natural (Current_Text);
         exception
            when E : Constraint_Error =>
               raise Coyote_Utils.Bad_Arg_Error with
                 "invalid COYOTE_RECURSION_DEPTH: "
                 & Current_Text
                 & " ("
                 & Ada.Exceptions.Exception_Message (E)
                 & ")";
         end;
      end if;

      if Opts.Subagent then
         if Current_Depth = Natural'Last then
            raise Coyote_Utils.Bad_Arg_Error with
              "COYOTE_RECURSION_DEPTH cannot be incremented";
         end if;
         Next_Depth := Current_Depth + 1;
         if Next_Depth > Settings_Value.Max_Recursion_Depth then
            raise Coyote_Utils.Bad_Arg_Error with
              "maximum subagent recursion depth exceeded (depth "
              & Ada.Strings.Fixed.Trim
                  (Natural'Image (Next_Depth), Ada.Strings.Both)
              & ", maximum "
              & Ada.Strings.Fixed.Trim
                  (Natural'Image (Settings_Value.Max_Recursion_Depth),
                   Ada.Strings.Both)
              & ")";
         end if;
      else
         Next_Depth := Current_Depth;
      end if;

      Ada.Environment_Variables.Set
        ("COYOTE_RECURSION_DEPTH",
         Ada.Strings.Fixed.Trim
           (Natural'Image (Next_Depth), Ada.Strings.Both));
   end Initialize_Recursion_Depth;

   procedure Print_Usage is
   begin
      Ada.Text_IO.Put_Line
        ("coyote -- Native Ada LLM coding agent harness");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line
        ("Usage: coyote [-s|--session UUID] [-m|--model PROVIDER/ID]");
      Ada.Text_IO.Put_Line
        ("               [-a|--agent TEXT|@PATH]");
      Ada.Text_IO.Put_Line
        ("               [-T|--no-tools] [-S|--no-session]");
      Ada.Text_IO.Put_Line
        ("               [-p|--prompt TEXT|-] [-1|--one-shot]"
         & " [-A|--subagent] [-n|--name LABEL]");
      Ada.Text_IO.Put_Line
        ("               [-f|--prompt-filter CMD]");
      Ada.Text_IO.Put_Line
        ("               [-F|--frontend gui|plain|rpc]");
      Ada.Text_IO.Put_Line
        ("               [-d|--debug-logging]");
      Ada.Text_IO.Put_Line
        ("               [-h|--help]");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line
        ("  -s, --session UUID        Resume the given session");
      Ada.Text_IO.Put_Line
        ("  -m, --model ID             Select the LLM model");
      Ada.Text_IO.Put_Line
        ("  -a, --agent TEXT|@PATH     Append to system prompt");
      Ada.Text_IO.Put_Line
        ("  -T, --no-tools             Disable tool execution");
      Ada.Text_IO.Put_Line
        ("  -S, --no-session           Do not persist this session");
      Ada.Text_IO.Put_Line
        ("  -p, --prompt TEXT|-        Send initial prompt");
      Ada.Text_IO.Put_Line
        ("  -1, --one-shot             Exit after one turn");
      Ada.Text_IO.Put_Line
        ("  -A, --subagent             Like --one-shot, keeps frontend");
      Ada.Text_IO.Put_Line
        ("  -n, --name LABEL            Set window name label");
      Ada.Text_IO.Put_Line
        ("  -f, --prompt-filter CMD    Filter prompts through shell");
      Ada.Text_IO.Put_Line
        ("  -F, --frontend gui|plain|rpc"
         & "   Override frontend selection (gui, plain, or rpc)");
      Ada.Text_IO.Put_Line
        ("  -d, --debug-logging         Enable conv debug output to stderr");
      Ada.Text_IO.Put_Line
        ("  -h, --help              Print this help and exit");
   end Print_Usage;
begin
   if not Coyote_Process_Control.Install then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "warning: SIGTERM handler could not be installed");
   end if;

   while I <= Ada.Command_Line.Argument_Count loop
      declare
         Arg : constant String := Ada.Command_Line.Argument (I);
      begin
         if (Arg = "-s" or else Arg = "--session")
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Session_Id :=
              To_Unbounded_String
                (Coyote_Utils.Strip_Session_Prefix
                   (Ada.Command_Line.Argument (I)));
         elsif (Arg = "-m" or else Arg = "--model")
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Model :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         elsif (Arg = "-a" or else Arg = "--agent")
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Agent :=
              To_Unbounded_String
                (Coyote_Utils.Resolve_Text_Arg
                   (Ada.Command_Line.Argument (I)));
         elsif Arg = "-T" or else Arg = "--no-tools" then
            Opts.No_Tools := True;
         elsif Arg = "-S" or else Arg = "--no-session" then
            Opts.No_Session := True;
         elsif (Arg = "-p" or else Arg = "--prompt")
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
         elsif Arg = "-1" or else Arg = "--one-shot" then
            Opts.One_Shot   := True;
            Opts.No_Compact := True;
         elsif Arg = "-A" or else Arg = "--subagent" then
            Opts.One_Shot   := True;
            Opts.Subagent   := True;
            Opts.No_Compact := True;
         elsif (Arg = "-n" or else Arg = "--name")
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Name :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         elsif (Arg = "-f" or else Arg = "--prompt-filter")
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            Opts.Prompt_Filter :=
              To_Unbounded_String (Ada.Command_Line.Argument (I));
         elsif (Arg = "-F" or else Arg = "--frontend")
           and then I < Ada.Command_Line.Argument_Count
         then
            I := I + 1;
            declare
               Val : constant String := Ada.Command_Line.Argument (I);
            begin
               if Val = "gui" then
                  Opts.Frontend := Coyote_App.GUI_Frontend;
               elsif Val = "plain" then
                  Opts.Frontend := Coyote_App.Plain_Frontend;
               elsif Val = "rpc" then
                  Opts.Frontend := Coyote_App.RPC_Frontend;
               else
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "Unknown frontend: " & Val);
               end if;
               Opts.Frontend_Explicit := True;
            end;

         elsif Arg = "-d" or else Arg = "--debug-logging" then
            Opts.Debug_Logging := True;

         elsif Arg = "-h" or else Arg = "--help" then
            Print_Usage;
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
            return;
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Unknown argument: " & Arg);
         end if;
      end;
      I := I + 1;
   end loop;

   --  Establish the inherited process depth before any frontend, session,
   --  or provider initialization.  A rejected subagent must not open a
   --  window or create a session.
   Initialize_Recursion_Depth;

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

   --  Inherit thinking level from the parent process when spawned as a
   --  subagent.  The parent sets COYOTE_THINKING_LEVEL before spawning
   --  so that the thinking level propagates to all descendants.
   if Ada.Environment_Variables.Exists ("COYOTE_THINKING_LEVEL") then
      null;  --  Used only for propagation; consumed in Coyote_App.Run
   end if;

   --  When resuming a session, change to the working directory that was
   --  current when the session was created so all relative paths resolve
   --  consistently.  If the stored directory no longer exists, record a
   --  warning for display after the selected frontend starts.
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

   --  Endpoint-backed subagents receive their own runtime identity while
   --  retaining the inherited coordinator identity as their parent.
   if Opts.Subagent
     and then Ada.Environment_Variables.Value
       ("COYOTE_RPC_ENDPOINT", "")'Length > 0
   then
      declare
         Parent_Id : constant String :=
           Ada.Environment_Variables.Value
             ("COYOTE_RUNTIME_AGENT_ID", "root");
         Pid_Text : constant String :=
           Ada.Strings.Fixed.Trim
             (GNAT.OS_Lib.Pid_To_Integer
                (GNAT.OS_Lib.Current_Process_Id)'Image,
              Ada.Strings.Both);
      begin
         Ada.Environment_Variables.Set
           ("COYOTE_PARENT_RUNTIME_AGENT_ID", Parent_Id);
         Ada.Environment_Variables.Set
           ("COYOTE_RUNTIME_AGENT_ID", "subagent-" & Pid_Text);
         Ada.Environment_Variables.Set
           ("COYOTE_AGENT_LABEL",
            (if Length (Opts.Name) > 0 then To_String (Opts.Name)
             else "subagent"));
      end;
   end if;

   --  ── Frontend detection ────────────────────────────────────────────────
   --  Priority:
   --    0. --frontend flag explicitly set → that frontend
   --    1. --one-shot (non-subagent)     → Plain
   --    2. $DISPLAY or $WAYLAND_DISPLAY  → GUI
   --    3. COYOTE_FRONTEND=gui           → GUI
   --    4. otherwise                      → Plain
   if Opts.Frontend_Explicit then
      null;
   elsif Opts.One_Shot and then not Opts.Subagent then
      Opts.Frontend := Coyote_App.Plain_Frontend;
   elsif Opts.Subagent
     and then Ada.Environment_Variables.Value
       ("COYOTE_RPC_ENDPOINT", "")'Length > 0
   then
      Opts.Frontend := Coyote_App.RPC_Frontend;
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

   --  Propagate GUI context to child processes.
   if Opts.Frontend = Coyote_App.GUI_Frontend then
      Ada.Environment_Variables.Set ("COYOTE_FRONTEND", "gui");
   end if;

   case Opts.Frontend is
      when Coyote_App.Plain_Frontend =>
         Coyote_App.Plain.Run (Opts);
      when Coyote_App.GUI_Frontend =>
         Coyote_App.Run_GUI (Opts);
      when Coyote_App.RPC_Frontend =>
         Coyote_App.RPC.Run (Opts);
   end case;
exception
   when E : Coyote_Utils.Bad_Arg_Error =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Coyote;
