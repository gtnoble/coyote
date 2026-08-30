--  LLM.Tools.Shell body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Characters.Handling;
with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Strings;
with GNATCOLL.JSON;
with GNATCOLL.OS.FS;         use GNATCOLL.OS.FS;
with LLM.Tools.Sandbox;
with Coyote_Process_Control;
with GNATCOLL.OS.Process;    use GNATCOLL.OS.Process;
package body LLM.Tools.Shell is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type Ada.Real_Time.Time;

   --  Local process-group signalling is provided by Coyote_Process_Control.
   Default_Shell : constant String := "/bin/sh";

   --  Standard base64 alphabet (RFC 4648, Table 1).
   Base64_Alphabet : constant String :=
     "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

   --  Encode the bytes of Data as standard base64 with '=' padding.
   function Base64_Encode (Data : String) return String is
      Len    : constant Natural := Data'Length;
      --  Output length: ceil(Len / 3) * 4
      Out_Len : constant Natural := ((Len + 2) / 3) * 4;
      Result  : String (1 .. Out_Len);
      Out_Pos : Positive := 1;
      B0, B1, B2 : Natural;
   begin
      if Len = 0 then
         return "";
      end if;

      declare
         In_Pos : Positive := Data'First;
      begin
         while In_Pos <= Data'Last loop
            B0 := Character'Pos (Data (In_Pos));
            In_Pos := In_Pos + 1;

            if In_Pos <= Data'Last then
               B1 := Character'Pos (Data (In_Pos));
               In_Pos := In_Pos + 1;
            else
               B1 := 0;
            end if;

            if In_Pos <= Data'Last then
               B2 := Character'Pos (Data (In_Pos));
               In_Pos := In_Pos + 1;
            else
               B2 := 0;
            end if;

            Result (Out_Pos)     :=
              Base64_Alphabet (1 + B0 / 4);
            Result (Out_Pos + 1) :=
              Base64_Alphabet (1 + (B0 mod 4) * 16 + B1 / 16);
            Result (Out_Pos + 2) :=
              Base64_Alphabet (1 + (B1 mod 16) * 4 + B2 / 64);
            Result (Out_Pos + 3) :=
              Base64_Alphabet (1 + B2 mod 64);
            Out_Pos := Out_Pos + 4;
         end loop;
      end;

      --  Apply '=' padding for incomplete final groups.
      declare
         Remainder : constant Natural := Len mod 3;
      begin
         if Remainder = 1 then
            Result (Out_Len - 1) := '=';
            Result (Out_Len)     := '=';
         elsif Remainder = 2 then
            Result (Out_Len) := '=';
         end if;
      end;

      return Result;
   end Base64_Encode;

   function Canonical_Image_Mime (Value : String) return String is
      Normalized : constant String :=
        Ada.Characters.Handling.To_Lower
          (Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both));
   begin
      if Normalized = "image/png"
        or else Normalized = "image/jpeg"
        or else Normalized = "image/gif"
        or else Normalized = "image/webp"
      then
         return Normalized;
      end if;
      return "";
   end Canonical_Image_Mime;

   function Image_Signature_Matches
     (Media_Type : String;
      Data       : String) return Boolean
   is
      First : constant Positive := Data'First;
   begin
      if Media_Type = "image/png" then
         return Data'Length >= 8
           and then Data (First) = Character'Val (16#89#)
           and then Data (First + 1 .. First + 3) = "PNG"
           and then Data (First + 4) = Character'Val (16#0D#)
           and then Data (First + 5) = Character'Val (16#0A#)
           and then Data (First + 6) = Character'Val (16#1A#)
           and then Data (First + 7) = Character'Val (16#0A#);
      elsif Media_Type = "image/jpeg" then
         return Data'Length >= 2
           and then Data (First) = Character'Val (16#FF#)
           and then Data (First + 1) = Character'Val (16#D8#);
      elsif Media_Type = "image/gif" then
         return Data'Length >= 6
           and then (Data (First .. First + 5) = "GIF87a"
                     or else Data (First .. First + 5) = "GIF89a");
      elsif Media_Type = "image/webp" then
         return Data'Length >= 12
           and then Data (First .. First + 3) = "RIFF"
           and then Data (First + 8 .. First + 11) = "WEBP";
      end if;
      return False;
   end Image_Signature_Matches;

   function New_Temporary_Path return String is
      FD   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Name : GNAT.Strings.String_Access := null;
      use type GNAT.OS_Lib.File_Descriptor;
      use type GNAT.Strings.String_Access;
   begin
      GNAT.OS_Lib.Create_Temp_File (FD, Name);
      if FD = GNAT.OS_Lib.Invalid_FD or else Name = null then
         raise Program_Error with "unable to create image diagnostic file";
      end if;
      GNAT.OS_Lib.Close (FD);
      declare
         Path : constant String := Name.all;
      begin
         GNAT.OS_Lib.Free (Name);
         return Path;
      end;
   exception
      when others =>
         if Name /= null then
            GNAT.OS_Lib.Free (Name);
         end if;
         raise;
   end New_Temporary_Path;

   function Read_File_Prefix
     (Path : String) return String
   is
      FD       : File_Descriptor := Invalid_FD;
      Buffer   : String (1 .. 4096);
      Read_N   : Integer;
      Result   : Unbounded_String;
      Remaining : Natural := 8 * 1024;
   begin
      if Path'Length = 0 then
         return "";
      end if;
      FD := Open (Path, Read_Mode);
      if FD = Invalid_FD then
         return "";
      end if;
      loop
         Read_N := Read (FD, Buffer);
         exit when Read_N <= 0;
         if Remaining > 0 then
            declare
               Keep : constant Natural :=
                 Natural'Min (Remaining, Read_N);
            begin
               Append (Result, Buffer (1 .. Keep));
               Remaining := Remaining - Keep;
            end;
         end if;
      end loop;
      Close (FD);
      return To_String (Result);
   exception
      when others =>
         if FD /= Invalid_FD then
            Close (FD);
         end if;
         return To_String (Result);
   end Read_File_Prefix;

   function Resolve_Shell return String is
   begin
      if Ada.Environment_Variables.Exists ("SHELL") then
         declare
            Value : constant String :=
              Ada.Environment_Variables.Value ("SHELL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return Default_Shell;
   end Resolve_Shell;

   function Descriptor return Tool_Descriptor is
      Schema     : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Props      : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Command    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Desc_P     : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Stdin_P    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Media_P    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Run_Grp_P  : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Timeout_P  : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required   : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Command.Set_Field ("type", "string");
      Command.Set_Field ("description", "The shell command to execute");

      Desc_P.Set_Field ("type", "string");
      Desc_P.Set_Field
        ("description", "Optional description of what the command does");

      Stdin_P.Set_Field ("type", "string");
      Stdin_P.Set_Field
        ("description",
         "Text to pipe into the command's standard input."
         & " Use this instead of heredocs (<<EOF) or interpreter"
         & " inline-code flags (-e, -E) whenever passing multi-line"
         & " content to a command.");

      Media_P.Set_Field ("type", "string");
      Media_P.Set_Field
        ("description",
         "Optional MIME type of the command's stdout (e.g. ""image/png"","
         & " ""image/jpeg"").  Only supported image types are accepted."
         & " The stdout bytes must match the declared image type; stderr is"
         & " kept separate.  Omit or leave empty for plain-text output.");

      Run_Grp_P.Set_Field ("type", "integer");
      Run_Grp_P.Set_Field
        ("description",
         "Optional execution group number. Tools in the same group run"
         & " in parallel. Lower group numbers execute first. Only applies"
         & " when all tool calls in a turn carry a run_group.");

      Timeout_P.Set_Field ("type", "integer");
      Timeout_P.Set_Field
        ("description",
         "Optional wall-clock timeout in seconds. When positive the"
         & " command is automatically terminated after that many seconds."
         & " The output collected up to that point is returned with a"
         & " timeout notice appended. Omit, or use 0, for no time limit.");
      Props.Set_Field ("command", Command);
      Props.Set_Field ("description", Desc_P);
      Props.Set_Field ("stdin", Stdin_P);
      Props.Set_Field ("media_type", Media_P);
      Props.Set_Field ("run_group", Run_Grp_P);
      Props.Set_Field ("timeout", Timeout_P);

      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("command"));

      Schema.Set_Field ("type", "object");
      Schema.Set_Field ("properties", Props);
      Schema.Set_Field ("required", GNATCOLL.JSON.Create (Required));

      return
        (Name        => To_Unbounded_String ("shell"),
         Description => To_Unbounded_String
           ("Execute a shell command and return its combined output."
            & " Optionally pipe text into the command via the `stdin` field."
            & " Never use heredocs or interpreter inline-code flags"
            & " (-e, -E) to pass multi-line content; always use `stdin`"
            & " instead. Set `media_type` to a MIME type string (e.g."
            & " ""image/png"") when the command produces binary image output;"
            & " the bytes will be base64-encoded and returned as an image"
            & " content block."),
         Schema_Json => Schema);
   end Descriptor;

   function Image_Of (Value : Integer) return String is
   begin
      return Ada.Strings.Fixed.Trim
        (Integer'Image (Value), Ada.Strings.Both);
   end Image_Of;

   procedure Set_Error
     (Message    :     String;
      Result     : out Unbounded_String;
      Media_Type : out Unbounded_String;
      Is_Error   : out Boolean) is
   begin
      Result     := To_Unbounded_String (Message);
      Media_Type := Null_Unbounded_String;
      Is_Error   := True;
   end Set_Error;

   procedure Execute
     (Args_Json       :     String;
      Result          : out Ada.Strings.Unbounded.Unbounded_String;
      Media_Type      : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error        : out Boolean;
      Abort_Flg       : access LLM.Tools.Abort_Flag := null;
      Sandbox_Profile :     String := "")
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Json);
   begin
      Result     := Null_Unbounded_String;
      Media_Type := Null_Unbounded_String;
      Is_Error   := False;

      if not Parsed.Success then
         Set_Error
           ("invalid JSON arguments for shell tool",
            Result, Media_Type, Is_Error);
         return;
      end if;

      declare
         Root : constant GNATCOLL.JSON.JSON_Value := Parsed.Value;
      begin
         if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type then
            Set_Error
              ("invalid JSON arguments for shell tool",
               Result, Media_Type, Is_Error);
            return;
         end if;

         if not Root.Has_Field ("command")
           or else Root.Get ("command").Kind /= GNATCOLL.JSON.JSON_String_Type
         then
            Set_Error
              ("shell tool requires a string field 'command'",
               Result, Media_Type, Is_Error);
            return;
         end if;

         declare
            Command          : constant String := Root.Get ("command").Get;
            Shell_Path       : constant String := Resolve_Shell;
            Output_R         : File_Descriptor := Invalid_FD;
            Output_W         : File_Descriptor := Invalid_FD;
            Diagnostic_W     : File_Descriptor := Invalid_FD;
            Null_In          : File_Descriptor := Invalid_FD;
            Handle           : Process_Handle  := Invalid_Handle;
            Args             : Argument_List;
            Chunk            : String (1 .. 4096);
            Bytes_Read       : Integer;
            Exit_Code        : Integer         := 0;
            Output           : Unbounded_String;
            Diagnostic       : Unbounded_String;
            Diagnostic_Path  : Unbounded_String;
            Has_Stdin_Text   : Boolean         := False;
            Stdin_Text       : Unbounded_String := Null_Unbounded_String;
            Timeout_Seconds  : Integer := 0;
            Stdin_R          : File_Descriptor := Invalid_FD;
            Stdin_W          : File_Descriptor := Invalid_FD;
            Requested_Mime   : Unbounded_String := Null_Unbounded_String;
            Started          : Boolean := False;
            Waited           : Boolean := False;
            Registered       : Boolean := False;

            protected type Termination_State is
               procedure Mark_Timeout;
               procedure Mark_Aborted;
               procedure Mark_Killed;
               function Timed_Out return Boolean;
               function Aborted return Boolean;
               function Killed return Boolean;
            private
               Timeout_Fired : Boolean := False;
               Abort_Fired   : Boolean := False;
               Kill_Fired    : Boolean := False;
            end Termination_State;

            protected body Termination_State is
               procedure Mark_Timeout is
               begin
                  Timeout_Fired := True;
               end Mark_Timeout;

               procedure Mark_Aborted is
               begin
                  Abort_Fired := True;
               end Mark_Aborted;

               procedure Mark_Killed is
               begin
                  Kill_Fired := True;
               end Mark_Killed;

               function Timed_Out return Boolean is
               begin
                  return Timeout_Fired;
               end Timed_Out;

               function Aborted return Boolean is
               begin
                  return Abort_Fired;
               end Aborted;

               function Killed return Boolean is
               begin
                  return Kill_Fired;
               end Killed;
            end Termination_State;

            Termination : Termination_State;

            procedure Reap_Child is
            begin
               if Started and then not Waited then
                  Exit_Code := Wait (Handle);
                  Waited := True;
               end if;
            end Reap_Child;

            procedure Cleanup is
            begin
               if Started and then not Waited then
                  begin
                     Coyote_Process_Control.Signal_Group
                       (Integer (Handle),
                        Coyote_Process_Control.SIGKILL_Signal);
                  exception
                     when others =>
                        null;
                  end;
                  begin
                     Reap_Child;
                  exception
                     when others =>
                        null;
                  end;
               end if;

               if Registered then
                  Coyote_Process_Control.Unregister (Integer (Handle));
                  Registered := False;
               end if;

               if Output_R /= Invalid_FD then
                  Close (Output_R);
                  Output_R := Invalid_FD;
               end if;

               if Output_W /= Invalid_FD then
                  Close (Output_W);
                  Output_W := Invalid_FD;
               end if;

               if Null_In /= Invalid_FD then
                  Close (Null_In);
                  Null_In := Invalid_FD;
               end if;

               if Stdin_R /= Invalid_FD then
                  Close (Stdin_R);
                  Stdin_R := Invalid_FD;
               end if;

               if Stdin_W /= Invalid_FD then
                  Close (Stdin_W);
                  Stdin_W := Invalid_FD;
               end if;
            end Cleanup;

         begin
            --  Parse the optional "stdin" field before spawning the child.
            if Root.Has_Field ("stdin")
              and then
                Root.Get ("stdin").Kind = GNATCOLL.JSON.JSON_String_Type
            then
               declare
                  Value : constant String := Root.Get ("stdin").Get;
               begin
                  if Value'Length > 0 then
                     Has_Stdin_Text := True;
                     Stdin_Text     := To_Unbounded_String (Value);
                  end if;
               end;
            end if;

            --  Parse the optional "media_type" field.
            if Root.Has_Field ("media_type")
              and then Root.Get ("media_type").Kind =
                GNATCOLL.JSON.JSON_String_Type
            then
               declare
                  Value : constant String := Root.Get ("media_type").Get;
               begin
                  if Value'Length > 0 then
                     declare
                        Canonical : constant String :=
                          Canonical_Image_Mime (Value);
                     begin
                        if Canonical'Length = 0 then
                           Set_Error
                             ("shell tool rejected unsupported image media "
                              & "type: " & Value,
                              Result, Media_Type, Is_Error);
                           return;
                        end if;
                        Requested_Mime := To_Unbounded_String (Canonical);
                     end;
                  end if;
               end;
            end if;

            --  Parse the optional "timeout" field.
            if Root.Has_Field ("timeout")
              and then Root.Get ("timeout").Kind =
                GNATCOLL.JSON.JSON_Int_Type
            then
               declare
                  Raw : constant Long_Integer := Root.Get ("timeout").Get;
               begin
                  if Raw > 0 and then Raw <=
                    Long_Integer (Integer'Last)
                  then
                     Timeout_Seconds := Integer (Raw);
                  end if;
               end;
            end if;

            if Length (Requested_Mime) > 0 then
               Diagnostic_Path :=
                 To_Unbounded_String (New_Temporary_Path);
               Diagnostic_W := Open
                 (To_String (Diagnostic_Path), Write_Mode);
               if Diagnostic_W = Invalid_FD then
                  raise Program_Error with
                    "unable to open image diagnostic file";
               end if;
               Set_Close_On_Exec (Diagnostic_W, False);
            end if;

            Open_Pipe (Output_R, Output_W);

            if Has_Stdin_Text then
               --  Open a pipe whose write end the parent fills after Start.
               --  Note: this pattern is safe for stdin content that fits in
               --  the OS pipe buffer (typically 64 KB on Linux).  Larger
               --  payloads are handled correctly because the child begins
               --  consuming stdin as soon as it starts, and the parent
               --  drains stdout immediately afterward.
               Open_Pipe (Stdin_R, Stdin_W);
            else
               Null_In := Open (Null_File, Read_Mode);
            end if;

            --  Place setsid outside the optional bwrap wrapper.  The PID
            --  returned by Start is then the process-group leader in both
            --  sandboxed and unsandboxed executions.
            Args.Append ("/usr/bin/setsid");
            Args.Append ("/bin/sh");
            Args.Append ("-c");
            Args.Append ("trap - TERM; exec ""$0"" ""$@""");

            if Sandbox_Profile'Length > 0 then
               declare
                  Bwrap_Args : constant
                    LLM.Tools.Sandbox.String_Vectors.Vector :=
                      LLM.Tools.Sandbox.Build_Bwrap_Args
                        (Sandbox_Profile,
                         Ada.Directories.Current_Directory);
               begin
                  Args.Append ("bwrap");
                  Args.Append ("--ro-bind");
                  Args.Append ("/");
                  Args.Append ("/");
                  Args.Append ("--dev");
                  Args.Append ("/dev");
                  Args.Append ("--proc");
                  Args.Append ("/proc");
                  for Arg of Bwrap_Args loop
                     Args.Append (Arg);
                  end loop;
                  Args.Append ("--");
               end;
            else
               Args.Append (Shell_Path);
            end if;

            if Sandbox_Profile'Length = 0 then
               Args.Append ("-lc");
               Args.Append (Command);
            else
               Args.Append (Shell_Path);
               Args.Append ("-lc");
               Args.Append (Command);
            end if;

            --  The setsid process is the direct child started by Start and
            --  is replaced by the reset wrapper.  Its PID is therefore the
            --  process-group leader used by the registry.
            declare
               Launch_Accepted : Boolean;
               Needs_Signal    : Boolean;
            begin
               Coyote_Process_Control.Begin_Launch (Launch_Accepted);
               if not Launch_Accepted then
                  Set_Error
                    ("shell tool rejected during process shutdown",
                     Result, Media_Type, Is_Error);
                  Cleanup;
                  return;
               end if;
               begin
                  Handle := Start
                    (Args   => Args,
                     Stdin  => (if Has_Stdin_Text then Stdin_R else Null_In),
                     Stdout => Output_W,
                     Stderr => (if Length (Requested_Mime) > 0
                                then Diagnostic_W
                                else Output_W));
                  Started := True;
                  Coyote_Process_Control.Complete_Launch
                    (Integer (Handle), Needs_Signal);
                  Registered := True;
                  if Needs_Signal then
                     Coyote_Process_Control.Signal_Group
                       (Integer (Handle),
                        Coyote_Process_Control.SIGTERM_Signal);
                  end if;
               exception
                  when others =>
                     Coyote_Process_Control.Cancel_Launch;
                     raise;
               end;
            end;

            --  The child has inherited the read end of the stdin pipe; the
            --  parent no longer needs it.  Write the stdin content and close
            --  the write end so the child receives EOF when done reading.
            if Has_Stdin_Text then
               Close (Stdin_R);
               Stdin_R := Invalid_FD;
               Write (Stdin_W, To_String (Stdin_Text));
               Close (Stdin_W);
               Stdin_W := Invalid_FD;
            else
               Close (Null_In);
               Null_In := Invalid_FD;
            end if;

            Close (Output_W);
            Output_W := Invalid_FD;
            if Diagnostic_W /= Invalid_FD then
               Close (Diagnostic_W);
               Diagnostic_W := Invalid_FD;
            end if;

            --  When a timeout is requested, the supervisor sends SIGTERM
            --  at expiry, waits the configured grace period, and sends
            --  SIGKILL to the process group if it is still running.  Manual
            --  abort retains immediate SIGKILL.  The child runs under
            --  setsid(1), so Signal_Group also covers nested descendants.
            --  The supervisor is cancelled as soon as the read loop
            --  completes.
            if Timeout_Seconds > 0 then
               declare
                  task Timer;
                  task body Timer is
                     Deadline  : Ada.Real_Time.Time;
                     Timed_Out : Boolean := False;
                  begin
                     --  Manual abort retains its immediate KILL policy.
                     if Abort_Flg /= null then
                        select
                           Abort_Flg.Wait_Requested;
                           Termination.Mark_Aborted;
                           if not Coyote_Process_Control
                             .Shutdown_Requested
                           then
                              Coyote_Process_Control.Signal_Group
                                (Integer (Handle),
                                 Coyote_Process_Control.SIGKILL_Signal);
                              Termination.Mark_Killed;
                           end if;
                        or
                           delay Duration (Timeout_Seconds);
                           Timed_Out := True;
                        end select;
                     else
                        delay Duration (Timeout_Seconds);
                        Timed_Out := True;
                     end if;

                     if Timed_Out then
                        Termination.Mark_Timeout;
                        if not Coyote_Process_Control.Shutdown_Requested then
                           --  Allow a TERM-aware command to exit cleanly.
                           Coyote_Process_Control.Signal_Group
                             (Integer (Handle),
                              Coyote_Process_Control.SIGTERM_Signal);
                           Deadline :=
                             Ada.Real_Time.Clock
                             + Ada.Real_Time.Seconds
                               (Integer
                                  (Coyote_Process_Control.Grace_Seconds));
                           if Abort_Flg /= null then
                              select
                                 Abort_Flg.Wait_Requested;
                                 Termination.Mark_Aborted;
                                 if not Coyote_Process_Control
                                   .Shutdown_Requested
                                 then
                                    Coyote_Process_Control.Signal_Group
                                      (Integer (Handle),
                                       Coyote_Process_Control.SIGKILL_Signal);
                                    Termination.Mark_Killed;
                                 end if;
                              or
                                 delay until Deadline;
                              end select;
                           else
                              delay until Deadline;
                           end if;
                           if not Coyote_Process_Control.Shutdown_Requested
                             and then not Termination.Aborted
                           then
                              Coyote_Process_Control.Signal_Group
                                (Integer (Handle),
                                 Coyote_Process_Control.SIGKILL_Signal);
                              Termination.Mark_Killed;
                           end if;
                        end if;
                     end if;
                  exception
                     when others =>
                        null;
                  end Timer;
               begin
                  Read_Loop :
                  loop
                     begin
                        Bytes_Read := Read (Output_R, Chunk);
                     exception
                        when others =>
                           if Termination.Killed
                             or else Termination.Timed_Out
                             or else Termination.Aborted
                           then
                              --  Termination released the output pipe;
                              --  read() returning 0 is handled below.
                              exit Read_Loop;
                           end if;
                           raise;
                     end;
                     exit Read_Loop when Bytes_Read <= 0;
                     Append (Output, Chunk (1 .. Bytes_Read));
                  end loop Read_Loop;

                  abort Timer;
               end;

            else
               --  When an abort flag is provided, spawn an Abort_Watcher
               --  task that sends SIGKILL to the child's process group
               --  as soon as the flag is set.  The child runs under
               --  setsid(1), so kill(-Handle, SIGKILL) kills the shell
               --  and all descendants, unblocking any blocked read().
               if Abort_Flg /= null then
                  declare
                     Aborted : Boolean := False;

                     task Abort_Watcher;
                     task body Abort_Watcher is
                     begin
                        Abort_Flg.Wait_Requested;
                        Aborted := True;
                        --  kill(-Handle, SIGKILL) kills the setsid child's
                        --  process group (shell + descendants).  The kernel
                        --  closes the pipe's write-end → blocked read()
                        --  returns EOF immediately.
                        if not Coyote_Process_Control.Shutdown_Requested then
                           Coyote_Process_Control.Signal_Group
                             (Integer (Handle),
                              Coyote_Process_Control.SIGKILL_Signal);
                           Termination.Mark_Killed;
                        end if;
                     end Abort_Watcher;
                  begin
                     Read_Output_Loop :
                     loop
                        begin
                           Bytes_Read := Read (Output_R, Chunk);
                        exception
                           when others =>
                              if Aborted then
                                 --  Child killed by Abort_Watcher →
                                 --  expected error; read() returning 0
                                 --  is handled by the Bytes_Read exit.
                                 exit Read_Output_Loop;
                              end if;
                              raise;
                        end;
                        exit Read_Output_Loop when Bytes_Read <= 0;
                        Append (Output, Chunk (1 .. Bytes_Read));
                     end loop Read_Output_Loop;

                     abort Abort_Watcher;
                  end;
               else
                  No_Abort_Read_Loop :
                  loop
                     Bytes_Read := Read (Output_R, Chunk);
                     exit No_Abort_Read_Loop when Bytes_Read <= 0;
                     Append (Output, Chunk (1 .. Bytes_Read));
                  end loop No_Abort_Read_Loop;
               end if;
            end if;

            --  If timed out, return the result after graceful termination.
            if Termination.Timed_Out and then not Termination.Aborted then
               Close (Output_R);
               Output_R := Invalid_FD;
               Reap_Child;
               --  Preserve partial stdout/stderr as the result so the
               --  model sees how much work the command completed before
               --  the timeout expired.
               Is_Error   := True;
               Media_Type := Null_Unbounded_String;
               if Length (Output) > 0 then
                  Append (Output, ASCII.LF);
                  Append
                    (Output,
                     "[command timed out after"
                     & Integer'Image (Timeout_Seconds)
                     & " seconds]");
                  Result := Output;
               else
                  Result := To_Unbounded_String
                    ("[command timed out after"
                     & Integer'Image (Timeout_Seconds)
                     & " seconds -- no output]");
               end if;
               Cleanup;
               return;
            end if;

            --  If aborted, terminate the child process before waiting.
            if Abort_Flg /= null and then Abort_Flg.Requested then
               Close (Output_R);
               Output_R := Invalid_FD;
               Reap_Child;
               --  Preserve partial stdout/stderr as the result so the
               --  model sees how much work the command completed before
               --  the abort signal arrived.
               Is_Error   := True;
               Media_Type := Null_Unbounded_String;
               if Length (Output) > 0 then
                  Append (Output, ASCII.LF);
                  Append (Output, "[command was aborted]");
                  Result := Output;
               else
                  Result := To_Unbounded_String
                    ("[command was aborted -- no output]");
               end if;
               Cleanup;
               return;
            end if;

            Close (Output_R);
            Output_R := Invalid_FD;

            Reap_Child;

            if Length (Diagnostic_Path) > 0 then
               Diagnostic := To_Unbounded_String
                 (Read_File_Prefix (To_String (Diagnostic_Path)));
            end if;

            if Exit_Code /= 0 then
               Is_Error := True;
               if Length (Output) > 0 then
                  Append (Output, ASCII.LF);
                  Append
                    (Output,
                     "[command exited with status "
                     & Image_Of (Exit_Code)
                     & "]");
               else
                  Output := To_Unbounded_String
                    ("command exited with status " & Image_Of (Exit_Code));
               end if;
               if Length (Diagnostic) > 0 then
                  Append (Output, ASCII.LF);
                  Append (Output, "[command diagnostics: ");
                  Append (Output, To_String (Diagnostic));
                  Append (Output, "]");
               end if;
               --  On error discard any requested media type; the result is
               --  always an error text message.
               Result := Output;
               Cleanup;
               return;
            end if;

            --  Successful exit: validate and base64-encode image stdout.
            if Length (Requested_Mime) > 0 then
               if Length (Output) = 0 then
                  Set_Error
                    ("shell tool produced empty output for "
                     & To_String (Requested_Mime),
                     Result, Media_Type, Is_Error);
               elsif not Image_Signature_Matches
                 (To_String (Requested_Mime), To_String (Output))
               then
                  Set_Error
                    ("shell tool stdout is not a valid "
                     & To_String (Requested_Mime) & " image",
                     Result, Media_Type, Is_Error);
               else
                  Result     := To_Unbounded_String
                    (Base64_Encode (To_String (Output)));
                  Media_Type := Requested_Mime;
               end if;
            else
               Result := Output;
            end if;

            Cleanup;
         exception
            when Ex : others =>
               Cleanup;
               Set_Error
                 ("shell tool failed: "
                  & Ada.Exceptions.Exception_Message (Ex),
                  Result, Media_Type, Is_Error);
         end;
      end;
   end Execute;

end LLM.Tools.Shell;
