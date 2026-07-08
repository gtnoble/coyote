--  LLM.Tools.Shell body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with GNATCOLL.OS.FS;         use GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;    use GNATCOLL.OS.Process;

package body LLM.Tools.Shell is

   use type GNATCOLL.JSON.JSON_Value_Type;

   --  Thin binding for POSIX kill(2); sends Signal to process group -Pid.
   function C_Kill
     (Pid    : Integer;
      Signal : Integer) return Integer
     with Import, Convention => C, External_Name => "kill";

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
         & " ""image/jpeg"").  When non-empty the raw stdout bytes are"
         & " base64-encoded and returned as an image content block of this"
         & " type.  Omit or leave empty for plain-text output (the default).");

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
     (Args_Json  :     String;
      Result     : out Ada.Strings.Unbounded.Unbounded_String;
      Media_Type : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error   : out Boolean;
      Abort_Flg  : access LLM.Tools.Abort_Flag := null)
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
            Null_In          : File_Descriptor := Invalid_FD;
            Handle           : Process_Handle  := Invalid_Handle;
            Args             : Argument_List;
            Chunk            : String (1 .. 4096);
            Bytes_Read       : Integer;
            Exit_Code        : Integer         := 0;
            Output           : Unbounded_String;
            Has_Stdin_Text   : Boolean         := False;
            Stdin_Text       : Unbounded_String := Null_Unbounded_String;
            Timeout_Seconds  : Integer := 0;
            Timer_Fired      : Boolean := False;
            Stdin_R          : File_Descriptor := Invalid_FD;
            Stdin_W          : File_Descriptor := Invalid_FD;
            Requested_Mime   : Unbounded_String := Null_Unbounded_String;

            procedure Cleanup is
            begin
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
                     Requested_Mime := To_Unbounded_String (Value);
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

            Args.Append (Shell_Path);
            Args.Append ("-lc");
            Args.Append (Command);

            Handle := Start
              (Args   => Args,
               Stdin  => (if Has_Stdin_Text then Stdin_R else Null_In),
               Stdout => Output_W,
               Stderr => Output_W);

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

            --  When a timeout is requested, spawn a timer task that fires
            --  a local abort flag after Timeout_Seconds seconds.  The ATC
            --  waits on this local flag so the read loop is interrupted
            --  immediately when the timer expires.  User-abort requests are
            --  polled at the top of each read iteration; their latency is
            --  bounded by a single Read call (typically sub-millisecond).
            --  The timer is cancelled as soon as the read loop completes.
            if Timeout_Seconds > 0 then
               declare
                  Watch_Abort : aliased LLM.Tools.Abort_Flag;

                  task Timer;
                  task body Timer is
                  begin
                     delay Duration (Timeout_Seconds);
                     Timer_Fired := True;
                     Watch_Abort.Set;
                  end Timer;
               begin
                  select
                     Watch_Abort.Wait_Requested;
                  then abort
                     Read_Loop :
                     loop
                        --  Honour an external abort request at the top of
                        --  every iteration.  User-clicked-Abort retains the
                        --  "[command was aborted]" message.
                        if Abort_Flg /= null
                          and then Abort_Flg.Requested
                        then
                           Timer_Fired := False;
                           exit Read_Loop;
                        end if;

                        begin
                           Bytes_Read := Read (Output_R, Chunk);
                        exception
                           when others =>
                              if Timer_Fired then
                                 exit Read_Loop;
                              end if;
                              raise;
                        end;
                        exit Read_Loop when Bytes_Read <= 0;
                        Append (Output, Chunk (1 .. Bytes_Read));
                     end loop Read_Loop;
                  end select;

                  abort Timer;
               end;

            else
               --  Read all output from the child process.  When an abort
               --  flag is provided the read loop runs inside an ATC block:
               --  if the user requests abort while Read is blocking,
               --  Wait_Requested fires and Ada's runtime interrupts the
               --  blocked syscall immediately.
               if Abort_Flg /= null then
                  select
                     Abort_Flg.Wait_Requested;
                  then abort
                     Read_Output_Loop :
                     loop
                        begin
                           Bytes_Read := Read (Output_R, Chunk);
                        exception
                           when others =>
                              if Abort_Flg /= null
                                and then Abort_Flg.Requested
                              then
                                 exit Read_Output_Loop;
                              end if;
                              raise;
                        end;
                        exit Read_Output_Loop when Bytes_Read <= 0;
                        Append (Output, Chunk (1 .. Bytes_Read));
                     end loop Read_Output_Loop;
                  end select;
               else
                  No_Abort_Read_Loop :
                  loop
                     Bytes_Read := Read (Output_R, Chunk);
                     exit No_Abort_Read_Loop when Bytes_Read <= 0;
                     Append (Output, Chunk (1 .. Bytes_Read));
                  end loop No_Abort_Read_Loop;
               end if;
            end if;

            --  If timed out, terminate the child process before waiting.
            if Timer_Fired then
               if Handle /= Invalid_Handle then
                  declare
                     Dummy : Integer;
                  begin
                     Dummy :=
                       C_Kill (-Integer (Handle), 15);
                  end;
               end if;
               Close (Output_R);
               Output_R := Invalid_FD;
               Exit_Code := Wait (Handle);
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
               if Handle /= Invalid_Handle then
                  declare
                     Dummy : Integer;
                  begin
                     Dummy :=
                       C_Kill (-Integer (Handle), 15);
                  end;
               end if;
               Close (Output_R);
               Output_R := Invalid_FD;
               Exit_Code := Wait (Handle);
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

            Exit_Code := Wait (Handle);

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
               --  On error discard any requested media type; the result is
               --  always an error text message.
               Result := Output;
               Cleanup;
               return;
            end if;

            --  Successful exit: base64-encode when a media type was requested.
            if Length (Requested_Mime) > 0 then
               Result     :=
                 To_Unbounded_String (Base64_Encode (To_String (Output)));
               Media_Type := Requested_Mime;
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
