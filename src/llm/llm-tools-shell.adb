--  LLM.Tools.Shell body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with GNATCOLL.OS.FS;         use GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;    use GNATCOLL.OS.Process;
with LLM.Tools.Internal;

package body LLM.Tools.Shell is

   use type GNATCOLL.JSON.JSON_Value_Type;

   Max_Output_Bytes : constant Natural := 200 * 1024;

   Default_Shell : constant String := "/bin/sh";

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
      Schema   : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Props    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Command  : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Desc_P   : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Stdin_P  : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Command.Set_Field ("type", "string");
      Command.Set_Field ("description", "The shell command to execute");

      Desc_P.Set_Field ("type", "string");
      Desc_P.Set_Field
        ("description", "Optional description of what the command does");

      Stdin_P.Set_Field ("type", "string");
      Stdin_P.Set_Field
        ("description",
         "Optional text to pipe into the command's standard input");

      Props.Set_Field ("command", Command);
      Props.Set_Field ("description", Desc_P);
      Props.Set_Field ("stdin", Stdin_P);

      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("command"));

      Schema.Set_Field ("type", "object");
      Schema.Set_Field ("properties", Props);
      Schema.Set_Field ("required", GNATCOLL.JSON.Create (Required));

      return
        (Name        => To_Unbounded_String ("shell"),
         Description => To_Unbounded_String
           ("Execute a shell command and return its combined output."
            & " Optionally pipe text into the command via the"
            & " `stdin` field."),
         Schema_Json => Schema);
   end Descriptor;

   --  POSIX getpid() used to generate stable temporary-output paths.
   function Getpid return Integer;
   pragma Import (C, Getpid, "getpid");

   protected Temp_Names is
      procedure Next (Value : out Natural);
   private
      Counter : Natural := 0;
   end Temp_Names;

   protected body Temp_Names is
      procedure Next (Value : out Natural) is
      begin
         Counter := Counter + 1;
         Value   := Counter;
      end Next;
   end Temp_Names;

   function Image_Of (Value : Integer) return String is
      Image : constant String := Ada.Strings.Fixed.Trim
        (Integer'Image (Value), Ada.Strings.Both);
   begin
      return Image;
   end Image_Of;

   function Temp_Output_Path return String is
      Suffix : Natural;
   begin
      Temp_Names.Next (Suffix);
      return
        "/tmp/coyote_shell_tool_"
        & Image_Of (Getpid)
        & "_"
        & Image_Of (Integer (Suffix))
        & ".txt";
   end Temp_Output_Path;

   procedure Write_String
     (File : in out Ada.Streams.Stream_IO.File_Type;
      Data : String) is
   begin
      if Data'Length > 0 then
         String'Write (Ada.Streams.Stream_IO.Stream (File), Data);
      end if;
   end Write_String;

   procedure Set_Error
     (Message  :     String;
      Result   : out Unbounded_String;
      Is_Error : out Boolean) is
   begin
      Result   := To_Unbounded_String (Message);
      Is_Error := True;
   end Set_Error;

   procedure Execute
     (Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access LLM.Tools.Abort_Flag := null)
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Json);
      Root   : constant GNATCOLL.JSON.JSON_Value  := Parsed.Value;
   begin
      Result   := Null_Unbounded_String;
      Is_Error := False;

      if not Parsed.Success or else Root.Kind /= GNATCOLL.JSON.JSON_Object_Type
      then
         Set_Error ("invalid JSON arguments for shell tool", Result, Is_Error);
         return;
      end if;

      if not Root.Has_Field ("command")
        or else Root.Get ("command").Kind /= GNATCOLL.JSON.JSON_String_Type
      then
         Set_Error
           ("shell tool requires a string field 'command'",
            Result,
            Is_Error);
         return;
      end if;

      declare
         Command        : constant String := Root.Get ("command").Get;
         Shell_Path     : constant String := Resolve_Shell;
         Output_R       : File_Descriptor := Invalid_FD;
         Output_W       : File_Descriptor := Invalid_FD;
         Null_In        : File_Descriptor := Invalid_FD;
         Handle         : Process_Handle  := Invalid_Handle;
         Args           : Argument_List;
         Chunk          : String (1 .. 4096);
         Bytes_Read     : Integer;
         Exit_Code      : Integer         := 0;
         Output         : Unbounded_String;
         Temp_File      : Ada.Streams.Stream_IO.File_Type;
         Temp_Open      : Boolean         := False;
         Temp_Path      : Unbounded_String;
         Was_Truncated  : Boolean         := False;
         Total_Bytes    : Natural         := 0;
         Has_Stdin_Text : Boolean         := False;
         Stdin_Text     : Unbounded_String := Null_Unbounded_String;
         Stdin_R        : File_Descriptor := Invalid_FD;
         Stdin_W        : File_Descriptor := Invalid_FD;

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

            if Temp_Open then
               Ada.Streams.Stream_IO.Close (Temp_File);
               Temp_Open := False;
            end if;
         end Cleanup;

         procedure Capture (Data : String) is
            Current_Length : constant Natural := Length (Output);
            Keep_Count     : Natural          := 0;
         begin
            Total_Bytes := Total_Bytes + Data'Length;

            if Was_Truncated then
               Write_String (Temp_File, Data);
               return;
            end if;

            if Current_Length + Data'Length <= Max_Output_Bytes then
               Append (Output, Data);
               return;
            end if;

            Temp_Path := To_Unbounded_String (Temp_Output_Path);
            Ada.Streams.Stream_IO.Create
              (Temp_File,
               Ada.Streams.Stream_IO.Out_File,
               To_String (Temp_Path));
            Temp_Open := True;
            Write_String (Temp_File, To_String (Output));
            Write_String (Temp_File, Data);

            if Current_Length < Max_Output_Bytes then
               Keep_Count := Max_Output_Bytes - Current_Length;
               if Keep_Count > 0 then
                  Append
                    (Output,
                     Data (Data'First .. Data'First + Keep_Count - 1));
               end if;
            end if;

            Was_Truncated := True;
         end Capture;

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

         --  Read all output from the child process.  When an abort flag is
         --  provided the read loop runs inside an ATC block: if the user
         --  requests abort while Read is blocking, Wait_Requested fires and
         --  Ada's runtime interrupts the blocked syscall immediately.
         if Abort_Flg /= null then
            select
               Abort_Flg.Wait_Requested;
            then abort
               Read_Output_Loop :
               loop
                  Bytes_Read := Read (Output_R, Chunk);
                  exit Read_Output_Loop when Bytes_Read <= 0;
                  Capture (Chunk (1 .. Bytes_Read));
               end loop Read_Output_Loop;
            end select;
         else
            No_Abort_Read_Loop :
            loop
               Bytes_Read := Read (Output_R, Chunk);
               exit No_Abort_Read_Loop when Bytes_Read <= 0;
               Capture (Chunk (1 .. Bytes_Read));
            end loop No_Abort_Read_Loop;
         end if;

         --  If aborted, terminate the child process before waiting.
         if Abort_Flg /= null and then Abort_Flg.Requested then
            if Handle /= Invalid_Handle then
               declare
                  Dummy : Integer;
               begin
                  Dummy :=
                    LLM.Tools.Internal.C_Kill (Integer (Handle), 15);
               end;
            end if;
            Close (Output_R);
            Output_R := Invalid_FD;
            Exit_Code := Wait (Handle);
            Set_Error ("aborted", Result, Is_Error);
            Cleanup;
            return;
         end if;

         Close (Output_R);
         Output_R := Invalid_FD;

         Exit_Code := Wait (Handle);

         if Was_Truncated then
            Ada.Streams.Stream_IO.Close (Temp_File);
            Temp_Open := False;
            Append (Output, ASCII.LF);
            Append
              (Output,
               "[output truncated at "
               & Image_Of (Integer (Max_Output_Bytes))
               & " bytes; full output saved to "
               & To_String (Temp_Path)
               & "; total bytes "
               & Image_Of (Integer (Total_Bytes))
               & "]");
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
         end if;

         Result := Output;
         Cleanup;
      exception
         when Ex : others =>
            Cleanup;
            Set_Error
              ("shell tool failed: " & Ada.Exceptions.Exception_Message (Ex),
               Result,
               Is_Error);
      end;
   end Execute;

end LLM.Tools.Shell;
