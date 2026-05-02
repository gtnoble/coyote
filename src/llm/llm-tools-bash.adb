--  LLM.Tools.Bash body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with GNATCOLL.OS.FS;         use GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;    use GNATCOLL.OS.Process;

package body LLM.Tools.Bash is

   use type GNATCOLL.JSON.JSON_Value_Type;

   Max_Output_Bytes : constant Natural := 200 * 1024;

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
        "/tmp/pi_acme_bash_tool_"
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
      Is_Error  : out Boolean)
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Json);
      Root   : constant GNATCOLL.JSON.JSON_Value  := Parsed.Value;
   begin
      Result   := Null_Unbounded_String;
      Is_Error := False;

      if not Parsed.Success or else Root.Kind /= GNATCOLL.JSON.JSON_Object_Type
      then
         Set_Error ("invalid JSON arguments for bash tool", Result, Is_Error);
         return;
      end if;

      if not Root.Has_Field ("command")
        or else Root.Get ("command").Kind /= GNATCOLL.JSON.JSON_String_Type
      then
         Set_Error
           ("bash tool requires a string field 'command'",
            Result,
            Is_Error);
         return;
      end if;

      declare
         Command        : constant String := Root.Get ("command").Get;
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
         Open_Pipe (Output_R, Output_W);
         Null_In := Open (Null_File, Read_Mode);

         Args.Append ("bash");
         Args.Append ("-lc");
         Args.Append (Command);

         Handle := Start
           (Args   => Args,
            Stdin  => Null_In,
            Stdout => Output_W,
            Stderr => Output_W);

         Close (Null_In);
         Null_In := Invalid_FD;
         Close (Output_W);
         Output_W := Invalid_FD;

         Read_Output_Loop :
         loop
            Bytes_Read := Read (Output_R, Chunk);
            exit Read_Output_Loop when Bytes_Read <= 0;
            Capture (Chunk (1 .. Bytes_Read));
         end loop Read_Output_Loop;

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
              ("bash tool failed: " & Ada.Exceptions.Exception_Message (Ex),
               Result,
               Is_Error);
      end;
   end Execute;

end LLM.Tools.Bash;
