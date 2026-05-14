--  LLM.Tools.Spawn_Subagent body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Command_Line;
with Ada.Containers.Vectors;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with GNATCOLL.OS.FS;       use GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;  use GNATCOLL.OS.Process;
with LLM.Tools.Internal;

package body LLM.Tools.Spawn_Subagent is

   use type GNATCOLL.JSON.JSON_Value_Type;

   --  Agent_Job tracks state for one spawned subagent process during
   --  the two-phase spawn/collect cycle.
   type Agent_Job is record
      Name             : Unbounded_String;
      Effective_Prompt : Unbounded_String;
      Output_R         : File_Descriptor  := Invalid_FD;
      Handle           : Process_Handle   := Invalid_Handle;
   end record;

   package Job_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Agent_Job);

   --  ── Descriptor ───────────────────────────────────────────────────────

   function Descriptor return Tool_Descriptor is
      Schema   : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Props    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;

      function Str_Prop (Desc : String)
        return GNATCOLL.JSON.JSON_Value
      is
         Prop : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
      begin
         Prop.Set_Field ("type", "string");
         Prop.Set_Field ("description", Desc);
         return Prop;
      end Str_Prop;

      function Str_Array_Prop (Desc : String)
        return GNATCOLL.JSON.JSON_Value
      is
         Prop  : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
         Items : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
      begin
         Items.Set_Field ("type", "string");
         Prop.Set_Field ("type", "array");
         Prop.Set_Field ("items", Items);
         Prop.Set_Field ("description", Desc);
         return Prop;
      end Str_Array_Prop;

   begin
      Props.Set_Field
        ("prompt", Str_Prop ("Task or question for the subagent."));
      Props.Set_Field
        ("model",
         Str_Prop ("Model to use in provider/model-id form."
                   & " Defaults to the current model."));
      Props.Set_Field
        ("agent",
         Str_Prop ("Name of an agent definition to use for the"
                   & " subagent.  Must match the name field of a"
                   & " discovered AGENT.md file."));
      Props.Set_Field
        ("custom_prompt",
         Str_Prop ("Additional instructions appended to the agent"
                   & " definition system prompt.  Use @path to load"
                   & " from a file."));
      Props.Set_Field
        ("name",
         Str_Prop ("Short label for the subagent window tagline."
                   & "  Mutually exclusive with ""names""."));
      Props.Set_Field
        ("names",
         Str_Array_Prop
           ("Spawn one subagent per entry in parallel.  Each name"
            & " is passed as the window tagline and as the"
            & " COYOTE_SUBAGENT_NAME environment variable to"
            & " prompt_filter.  Mutually exclusive with ""name""."));
      Props.Set_Field
        ("prompt_filter",
         Str_Prop ("Shell command run once per subagent before"
                   & " spawning.  The raw prompt is written to stdin."
                   & "  COYOTE_SUBAGENT_NAME is set to the current"
                   & " agent name.  Stdout becomes the effective"
                   & " prompt.  Useful for m4 macro expansion:"
                   & " e.g. ""m4 -DAGENT=$COYOTE_SUBAGENT_NAME""."
                   & "  Falls back to the raw prompt on any error."));

      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("prompt"));

      Schema.Set_Field ("type", "object");
      Schema.Set_Field ("properties", Props);
      Schema.Set_Field ("required", GNATCOLL.JSON.Create (Required));

      return
        (Name        => To_Unbounded_String ("spawn_subagent"),
         Description => To_Unbounded_String
           ("Spawn a subagent in a new coyote window and return its"
            & " response. The window closes automatically when the"
            & " turn completes. Subagents are ephemeral and do not"
            & " persist sessions. Use ""names"" to spawn multiple"
            & " subagents in parallel with per-agent prompt"
            & " transformation via prompt_filter."),
         Schema_Json => Schema);
   end Descriptor;

   --  ── Find_Coyote ──────────────────────────────────────────────────────

   function Find_Coyote return String is
      Env_Bin : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_BIN", "");
   begin
      if Env_Bin'Length > 0 then
         return Env_Bin;
      end if;

      return Ada.Command_Line.Command_Name;
   end Find_Coyote;

   --  ── Set_Error ────────────────────────────────────────────────────────

   procedure Set_Error
     (Message  :     String;
      Result   : out Unbounded_String;
      Is_Error : out Boolean) is
   begin
      Result   := To_Unbounded_String (Message);
      Is_Error := True;
   end Set_Error;

   --  ── Find_Last_Json_Object ────────────────────────────────────────────

   function Find_Last_Json_Object
     (Text  :     String;
      Value : out GNATCOLL.JSON.JSON_Value) return Boolean
   is
      Line_End : Integer := Text'Last;
   begin
      Scan_Lines_Loop : loop
         exit Scan_Lines_Loop when Line_End < Text'First;

         while Line_End >= Text'First
           and then Text (Line_End) in ASCII.LF | ASCII.CR
         loop
            Line_End := Line_End - 1;
         end loop;

         exit Scan_Lines_Loop when Line_End < Text'First;

         declare
            Line_Start : Integer := Line_End;
         begin
            while Line_Start > Text'First
              and then Text (Line_Start - 1) not in ASCII.LF | ASCII.CR
            loop
               Line_Start := Line_Start - 1;
            end loop;

            declare
               Candidate : constant String := Ada.Strings.Fixed.Trim
                 (Text (Line_Start .. Line_End), Ada.Strings.Both);
               Parsed    : constant GNATCOLL.JSON.Read_Result :=
                 GNATCOLL.JSON.Read (Candidate);
            begin
               if Candidate'Length > 0
                 and then Parsed.Success
                 and then Parsed.Value.Kind =
                   GNATCOLL.JSON.JSON_Object_Type
               then
                  Value := Parsed.Value;
                  return True;
               end if;
            end;

            Line_End := Line_Start - 1;
         end;
      end loop Scan_Lines_Loop;

      return False;
   end Find_Last_Json_Object;

   --  ── Run_Prompt_Filter ────────────────────────────────────────────────
   --
   --  Run Filter as a shell command, writing Prompt to its stdin, with
   --  COYOTE_SUBAGENT_NAME set to Name.  Return trimmed stdout on
   --  success, or Prompt itself on any error (non-zero exit, empty
   --  output, or spawn failure).

   function Run_Prompt_Filter
     (Prompt : String;
      Filter : String;
      Name   : String) return String
   is
   begin
      if Filter'Length = 0 then
         return Prompt;
      end if;

      declare
         Stdin_R    : File_Descriptor := Invalid_FD;
         Stdin_W    : File_Descriptor := Invalid_FD;
         Stdout_R   : File_Descriptor := Invalid_FD;
         Stdout_W   : File_Descriptor := Invalid_FD;
         Null_Err   : File_Descriptor := Invalid_FD;
         Args       : Argument_List;
         Env        : Environment_Dict;
         Handle     : Process_Handle  := Invalid_Handle;
         Exit_Code  : Integer;
         Output_Buf : Unbounded_String;
         Chunk      : String (1 .. 4_096);
         N          : Integer;
         Dummy      : Integer;
         pragma Unreferenced (Dummy);
      begin
         Open_Pipe (Stdin_R,  Stdin_W);
         Open_Pipe (Stdout_R, Stdout_W);
         Null_Err := Open (Null_File, Write_Mode);

         Env.Include ("COYOTE_SUBAGENT_NAME", Name);

         declare
            Shell : constant String :=
              Ada.Environment_Variables.Value ("SHELL", "sh");
         begin
            Args.Append (Shell);
         end;
         Args.Append ("-c");
         Args.Append (Filter);

         Handle := Start
           (Args        => Args,
            Env         => Env,
            Stdin       => Stdin_R,
            Stdout      => Stdout_W,
            Stderr      => Null_Err,
            Inherit_Env => True);

         Close (Stdin_R);
         Close (Stdout_W);
         Close (Null_Err);

         Dummy := Write (Stdin_W, Prompt);
         Close (Stdin_W);

         Read_Filter_Loop : loop
            N := Read (Stdout_R, Chunk);
            exit Read_Filter_Loop when N <= 0;
            Append (Output_Buf, Chunk (1 .. N));
         end loop Read_Filter_Loop;
         Close (Stdout_R);

         Exit_Code := Wait (Handle);

         if Exit_Code /= 0 then
            return Prompt;
         end if;

         declare
            Output : constant String := To_String (Output_Buf);
            First  : Natural         := Output'First;
            Last   : Natural         := Output'Last;
         begin
            while First <= Last
              and then Output (First) in
                ' ' | ASCII.HT | ASCII.LF | ASCII.CR
            loop
               First := First + 1;
            end loop;
            while Last >= First
              and then Output (Last) in
                ' ' | ASCII.HT | ASCII.LF | ASCII.CR
            loop
               Last := Last - 1;
            end loop;

            if First > Last then
               return Prompt;
            end if;

            return Output (First .. Last);
         end;
      exception
         when others =>
            return Prompt;
      end;
   end Run_Prompt_Filter;

   --  ── Spawn_One ────────────────────────────────────────────────────────
   --
   --  Start a single coyote --one-shot subprocess and return its process
   --  handle together with the read end of its stdout pipe.  The caller
   --  is responsible for reading Output_R and calling Wait (Handle).
   --  Output_W is consumed (closed) before returning.

   procedure Spawn_One
     (Prompt        : String;
      Model         : String;
      Agent         : String;
      Custom_Prompt : String;
      Name          : String;
      Output_R      : out File_Descriptor;
      Handle        : out Process_Handle)
   is
      Output_W : File_Descriptor;
      Null_In  : File_Descriptor;
      Null_Err : File_Descriptor;
      Args     : Argument_List;
   begin
      Open_Pipe (Output_R, Output_W);
      Null_In  := Open (Null_File, Read_Mode);
      Null_Err := Open (Null_File, Write_Mode);

      Args.Append (Find_Coyote);
      Args.Append ("--prompt");
      Args.Append (Prompt);
      Args.Append ("--one-shot");
      Args.Append ("--no-session");
      if Model'Length > 0 then
         Args.Append ("--model");
         Args.Append (Model);
      end if;
      if Agent'Length > 0 then
         Args.Append ("--agent");
         Args.Append (Agent);
      end if;
      if Custom_Prompt'Length > 0 then
         Args.Append ("--custom-prompt");
         Args.Append (Custom_Prompt);
      end if;
      if Name'Length > 0 then
         Args.Append ("--name");
         Args.Append (Name);
      end if;

      Handle := Start
        (Args   => Args,
         Stdin  => Null_In,
         Stdout => Output_W,
         Stderr => Null_Err);

      Close (Null_In);
      Close (Null_Err);
      Close (Output_W);
   end Spawn_One;

   --  ── Parse_Job_Output ─────────────────────────────────────────────────
   --
   --  Extract the "output" or "error" string from the raw one-shot
   --  subprocess stdout.  Returns (True, text) on success or (False,
   --  message) when no valid JSON result line is found.

   procedure Parse_Job_Output
     (Raw      :     String;
      Success  : out Boolean;
      Text     : out Unbounded_String)
   is
      Json_Result : GNATCOLL.JSON.JSON_Value;
   begin
      if not Find_Last_Json_Object (Raw, Json_Result) then
         Success := False;
         Text    := To_Unbounded_String ("subagent produced no output");
         return;
      end if;

      if Json_Result.Has_Field ("output")
        and then Json_Result.Get ("output").Kind =
          GNATCOLL.JSON.JSON_String_Type
      then
         declare
            Output_Text : constant String :=
              Json_Result.Get ("output").Get;
         begin
            Success := True;
            Text    := To_Unbounded_String (Output_Text);
         end;
      elsif Json_Result.Has_Field ("error")
        and then Json_Result.Get ("error").Kind =
          GNATCOLL.JSON.JSON_String_Type
      then
         declare
            Error_Text : constant String :=
              Json_Result.Get ("error").Get;
         begin
            Success := False;
            Text    := To_Unbounded_String (Error_Text);
         end;
      else
         Success := False;
         Text    := To_Unbounded_String ("subagent produced no output");
      end if;
   end Parse_Job_Output;

   --  ── Execute ──────────────────────────────────────────────────────────

   procedure Execute
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null)
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Json);
   begin
      Result   := Null_Unbounded_String;
      Is_Error := False;

      if not Parsed.Success then
         Set_Error
           ("invalid JSON arguments for spawn_subagent tool",
            Result,
            Is_Error);
         return;
      end if;

      declare
         Root : constant GNATCOLL.JSON.JSON_Value := Parsed.Value;
      begin
         if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type then
            Set_Error
              ("invalid JSON arguments for spawn_subagent tool",
               Result,
               Is_Error);
            return;
         end if;

         --  "prompt" is required.
         if not Root.Has_Field ("prompt")
           or else Root.Get ("prompt").Kind /=
             GNATCOLL.JSON.JSON_String_Type
         then
            Set_Error
              ("spawn_subagent tool requires a non-empty string"
               & " field 'prompt'",
               Result,
               Is_Error);
            return;
         end if;

         if String'(Root.Get ("prompt").Get)'Length = 0 then
            Set_Error
              ("spawn_subagent tool requires a non-empty string"
               & " field 'prompt'",
               Result,
               Is_Error);
            return;
         end if;

         --  "name" and "names" are mutually exclusive.
         if Root.Has_Field ("name") and then Root.Has_Field ("names")
         then
            Set_Error
              ("spawn_subagent tool: 'name' and 'names' must not"
               & " both be present",
               Result,
               Is_Error);
            return;
         end if;

         --  Validate optional string fields.
         begin
            if Root.Has_Field ("model")
              and then Root.Get ("model").Kind /=
                GNATCOLL.JSON.JSON_String_Type
            then
               Set_Error
                 ("spawn_subagent tool field 'model' must be a"
                  & " string",
                  Result,
                  Is_Error);
               return;
            end if;

            if Root.Has_Field ("agent")
              and then Root.Get ("agent").Kind /=
                GNATCOLL.JSON.JSON_String_Type
            then
               Set_Error
                 ("spawn_subagent tool field 'agent' must be a"
                  & " string",
                  Result,
                  Is_Error);
               return;
            end if;

            if Root.Has_Field ("custom_prompt")
              and then Root.Get ("custom_prompt").Kind /=
                GNATCOLL.JSON.JSON_String_Type
            then
               Set_Error
                 ("spawn_subagent tool field 'custom_prompt' must"
                  & " be a string",
                  Result,
                  Is_Error);
               return;
            end if;

            if Root.Has_Field ("name")
              and then Root.Get ("name").Kind /=
                GNATCOLL.JSON.JSON_String_Type
            then
               Set_Error
                 ("spawn_subagent tool field 'name' must be a"
                  & " string",
                  Result,
                  Is_Error);
               return;
            end if;

            if Root.Has_Field ("prompt_filter")
              and then Root.Get ("prompt_filter").Kind /=
                GNATCOLL.JSON.JSON_String_Type
            then
               Set_Error
                 ("spawn_subagent tool field 'prompt_filter' must"
                  & " be a string",
                  Result,
                  Is_Error);
               return;
            end if;

            --  Validate "names" when present: must be a non-empty
            --  array of non-empty strings.
            if Root.Has_Field ("names") then
               if Root.Get ("names").Kind /=
                 GNATCOLL.JSON.JSON_Array_Type
               then
                  Set_Error
                    ("spawn_subagent tool field 'names' must be an"
                     & " array of strings",
                     Result,
                     Is_Error);
                  return;
               end if;

               declare
                  Names_Arr : constant GNATCOLL.JSON.JSON_Array :=
                    Root.Get ("names").Get;
                  Arr_Len   : constant Natural :=
                    GNATCOLL.JSON.Length (Names_Arr);
               begin
                  if Arr_Len = 0 then
                     Set_Error
                       ("spawn_subagent tool field 'names' must not"
                        & " be an empty array",
                        Result,
                        Is_Error);
                     return;
                  end if;

                  Validate_Names_Loop :
                  for I in 1 .. Arr_Len loop
                     declare
                        Elem : constant GNATCOLL.JSON.JSON_Value :=
                          GNATCOLL.JSON.Get (Names_Arr, I);
                     begin
                        if Elem.Kind /=
                          GNATCOLL.JSON.JSON_String_Type
                        then
                           Set_Error
                             ("spawn_subagent tool field 'names'"
                              & " must contain only strings",
                              Result,
                              Is_Error);
                           return;
                        end if;

                        if String'(Elem.Get)'Length = 0 then
                           Set_Error
                             ("spawn_subagent tool field 'names'"
                              & " must not contain empty strings",
                              Result,
                              Is_Error);
                           return;
                        end if;
                     end;
                  end loop Validate_Names_Loop;
               end;
            end if;
         end;

         --  All validation done.  Extract values and proceed.
         declare
            Prompt        : constant String :=
              Root.Get ("prompt").Get;
            Model         : constant String :=
              (if Root.Has_Field ("model")
               then Root.Get ("model").Get else "");
            Agent         : constant String :=
              (if Root.Has_Field ("agent")
               then Root.Get ("agent").Get else "");
            Custom_Prompt : constant String :=
              (if Root.Has_Field ("custom_prompt")
               then Root.Get ("custom_prompt").Get else "");
            Name          : constant String :=
              (if Root.Has_Field ("name")
               then Root.Get ("name").Get else "");
            Filter        : constant String :=
              (if Root.Has_Field ("prompt_filter")
               then Root.Get ("prompt_filter").Get else "");
            Multi_Mode    : constant Boolean :=
              Root.Has_Field ("names");

            Jobs           : Job_Vectors.Vector;
            Last_Collected : Natural := 0;

            --  Release any resources for jobs that have not yet
            --  been collected (i.e. jobs beyond Last_Collected).
            procedure Cleanup_Remaining is
               Dummy : Integer;
               pragma Unreferenced (Dummy);
            begin
               Cleanup_Loop :
               for I in Last_Collected + 1 .. Natural (Jobs.Length)
               loop
                  declare
                     Job : constant Agent_Job := Jobs.Element (I);
                  begin
                     if Job.Output_R /= Invalid_FD then
                        begin
                           Close (Job.Output_R);
                        exception
                           when others => null;
                        end;
                     end if;

                     if Job.Handle /= Invalid_Handle then
                        begin
                           Dummy :=
                             LLM.Tools.Internal.C_Kill
                               (Integer (Job.Handle), 15);
                        exception
                           when others => null;
                        end;
                        begin
                           Dummy := Wait (Job.Handle);
                        exception
                           when others => null;
                        end;
                     end if;
                  end;
               end loop Cleanup_Loop;
            end Cleanup_Remaining;

         begin
            --  ── Build jobs list ───────────────────────────────────────

            if Multi_Mode then
               declare
                  Names_Arr : constant GNATCOLL.JSON.JSON_Array :=
                    Root.Get ("names").Get;
                  Arr_Len   : constant Natural :=
                    GNATCOLL.JSON.Length (Names_Arr);
               begin
                  Build_Multi_Jobs_Loop :
                  for I in 1 .. Arr_Len loop
                     declare
                        N_Val : constant String :=
                          GNATCOLL.JSON.Get (Names_Arr, I).Get;
                        Eff   : constant String :=
                          Run_Prompt_Filter (Prompt, Filter, N_Val);
                        Job   : Agent_Job;
                     begin
                        Job.Name             :=
                          To_Unbounded_String (N_Val);
                        Job.Effective_Prompt :=
                          To_Unbounded_String (Eff);
                        Jobs.Append (Job);
                     end;
                  end loop Build_Multi_Jobs_Loop;
               end;
            else
               declare
                  Eff : constant String :=
                    Run_Prompt_Filter (Prompt, Filter, Name);
                  Job : Agent_Job;
               begin
                  Job.Name             := To_Unbounded_String (Name);
                  Job.Effective_Prompt := To_Unbounded_String (Eff);
                  Jobs.Append (Job);
               end;
            end if;

            --  Abort check before any spawn.
            if Abort_Flg /= null and then Abort_Flg.Requested then
               Set_Error ("aborted", Result, Is_Error);
               return;
            end if;

            --  ── Phase 1: spawn all subagents ──────────────────────────

            begin
               Spawn_Phase_Loop :
               for I in 1 .. Natural (Jobs.Length) loop
                  declare
                     Job      : Agent_Job := Jobs.Element (I);
                     Out_R    : File_Descriptor;
                     Hnd      : Process_Handle;
                  begin
                     Spawn_One
                       (Prompt        => To_String (Job.Effective_Prompt),
                        Model         => Model,
                        Agent         => Agent,
                        Custom_Prompt => Custom_Prompt,
                        Name          => To_String (Job.Name),
                        Output_R      => Out_R,
                        Handle        => Hnd);
                     Job.Output_R := Out_R;
                     Job.Handle   := Hnd;
                     Jobs.Replace_Element (I, Job);
                  end;
               end loop Spawn_Phase_Loop;
            exception
               when Ex : others =>
                  Cleanup_Remaining;
                  Set_Error
                    ("spawn_subagent tool failed: "
                     & Ada.Exceptions.Exception_Message (Ex),
                     Result,
                     Is_Error);
                  return;
            end;

            --  ── Phase 2: collect all outputs ──────────────────────────

            declare
               type Success_Array is
                 array (Positive range <>) of Boolean;
               type Text_Array is
                 array (Positive range <>) of Unbounded_String;

               N_Jobs   : constant Positive :=
                 Natural (Jobs.Length);
               Successes : Success_Array (1 .. N_Jobs) :=
                 (others => False);
               Texts     : Text_Array (1 .. N_Jobs) :=
                 (others => Null_Unbounded_String);

               procedure Collect_All is
               begin
                  Collect_Loop :
                  for I in 1 .. N_Jobs loop
                     declare
                        Job        : constant Agent_Job :=
                          Jobs.Element (I);
                        Output_Buf : Unbounded_String;
                        Chunk      : String (1 .. 4_096);
                        Bytes      : Integer;
                        Exit_Code  : Integer;
                        pragma Unreferenced (Exit_Code);
                     begin
                        Read_Loop :
                        loop
                           Bytes := Read (Job.Output_R, Chunk);
                           exit Read_Loop when Bytes <= 0;
                           Append (Output_Buf, Chunk (1 .. Bytes));
                        end loop Read_Loop;

                        Close (Job.Output_R);
                        Exit_Code := Wait (Job.Handle);
                        Last_Collected := I;

                        Parse_Job_Output
                          (Raw     => To_String (Output_Buf),
                           Success => Successes (I),
                           Text    => Texts (I));
                     end;
                  end loop Collect_Loop;
               end Collect_All;

            begin
               if Abort_Flg /= null then
                  select
                     Abort_Flg.Wait_Requested;
                  then abort
                     Collect_All;
                  end select;
               else
                  Collect_All;
               end if;

               if Abort_Flg /= null and then Abort_Flg.Requested then
                  Cleanup_Remaining;
                  Set_Error ("aborted", Result, Is_Error);
                  return;
               end if;

               --  ── Format results ────────────────────────────────────

               if not Multi_Mode then
                  --  Single-agent: return output directly (same
                  --  behaviour as before the multi-agent extension).
                  if Successes (1) then
                     Result   := Texts (1);
                     Is_Error := False;
                  else
                     Set_Error
                       (To_String (Texts (1)), Result, Is_Error);
                  end if;
               else
                  --  Multi-agent: combine results with name labels.
                  --  Is_Error is False as long as at least one
                  --  subagent succeeded.
                  declare
                     Any_Success : Boolean          := False;
                     Combined    : Unbounded_String :=
                       Null_Unbounded_String;
                  begin
                     Format_Loop :
                     for I in 1 .. N_Jobs loop
                        declare
                           Label : constant String :=
                             "[" & To_String (Jobs.Element (I).Name)
                             & "]" & ASCII.LF;
                        begin
                           Append (Combined, Label);
                           if Successes (I) then
                              Any_Success := True;
                              Append (Combined, Texts (I));
                           else
                              Append
                                (Combined,
                                 "[error: "
                                 & To_String (Texts (I))
                                 & "]");
                           end if;
                           Append (Combined, "" & ASCII.LF & ASCII.LF);
                        end;
                     end loop Format_Loop;

                     --  Trim the trailing blank line.
                     declare
                        S     : constant String := To_String (Combined);
                        Last  : Natural := S'Last;
                     begin
                        while Last >= S'First
                          and then S (Last) in ASCII.LF | ASCII.CR
                        loop
                           Last := Last - 1;
                        end loop;
                        Result := To_Unbounded_String
                          (S (S'First .. Last));
                     end;

                     Is_Error := not Any_Success;
                     if Is_Error then
                        --  All failed: prepend a summary error so
                        --  the caller knows this is an error result.
                        Result :=
                          To_Unbounded_String
                            ("all subagents failed:" & ASCII.LF)
                          & Result;
                     end if;
                  end;
               end if;
            exception
               when Ex : others =>
                  Cleanup_Remaining;
                  Set_Error
                    ("spawn_subagent tool failed: "
                     & Ada.Exceptions.Exception_Message (Ex),
                     Result,
                     Is_Error);
            end;
         end;
      end;
   end Execute;

end LLM.Tools.Spawn_Subagent;
