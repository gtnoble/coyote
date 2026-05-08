--  LLM.Tools.Spawn_Subagent body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Command_Line;
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

   function Descriptor return Tool_Descriptor is
      Schema   : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Props    : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Required : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;

      function Str_Prop (Desc : String) return GNATCOLL.JSON.JSON_Value is
         Prop : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
      begin
         Prop.Set_Field ("type", "string");
         Prop.Set_Field ("description", Desc);
         return Prop;
      end Str_Prop;

   begin
      Props.Set_Field
        ("prompt", Str_Prop ("Task or question for the subagent."));
      Props.Set_Field
        ("model",
         Str_Prop ("Model to use in provider/model-id form."
                   & " Defaults to the current model."));
      Props.Set_Field
        ("agent",
         Str_Prop ("Name of an agent definition to use for the subagent."
                   & " Must match the name field of a discovered AGENT.md"
                   & " file."));
      Props.Set_Field
        ("custom_prompt",
         Str_Prop ("Additional instructions appended to the agent"
                   & " definition system prompt.  Use @path to load from"
                   & " a file."));
      Props.Set_Field
        ("name",
         Str_Prop ("Short label for the subagent window tagline."));

      GNATCOLL.JSON.Append (Required, GNATCOLL.JSON.Create ("prompt"));

      Schema.Set_Field ("type", "object");
      Schema.Set_Field ("properties", Props);
      Schema.Set_Field ("required", GNATCOLL.JSON.Create (Required));

      return
        (Name        => To_Unbounded_String ("spawn_subagent"),
         Description => To_Unbounded_String
           ("Spawn a subagent in a new coyote window and return its"
            & " response. The window closes automatically when the turn"
            & " completes. Subagents are ephemeral and do not persist"
            & " sessions."),
         Schema_Json => Schema);
   end Descriptor;

   function Find_Coyote return String is
      Env_Bin : constant String :=
        Ada.Environment_Variables.Value ("COYOTE_BIN", "");
   begin
      if Env_Bin'Length > 0 then
         return Env_Bin;
      end if;

      return Ada.Command_Line.Command_Name;
   end Find_Coyote;

   procedure Set_Error
     (Message  :     String;
      Result   : out Unbounded_String;
      Is_Error : out Boolean) is
   begin
      Result   := To_Unbounded_String (Message);
      Is_Error := True;
   end Set_Error;

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
                 and then Parsed.Value.Kind = GNATCOLL.JSON.JSON_Object_Type
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

         if not Root.Has_Field ("prompt")
           or else Root.Get ("prompt").Kind /= GNATCOLL.JSON.JSON_String_Type
         then
            Set_Error
              ("spawn_subagent tool requires a non-empty string field"
               & " 'prompt'",
               Result,
               Is_Error);
            return;
         end if;

         declare
            Prompt : constant String := Root.Get ("prompt").Get;
         begin
            if Prompt'Length = 0 then
               Set_Error
                 ("spawn_subagent tool requires a non-empty string field"
                  & " 'prompt'",
                  Result,
                  Is_Error);
               return;
            end if;
         end;

         if Root.Has_Field ("model")
           and then Root.Get ("model").Kind /=
             GNATCOLL.JSON.JSON_String_Type
         then
            Set_Error
              ("spawn_subagent tool field 'model' must be a string",
               Result,
               Is_Error);
            return;
         end if;

         if Root.Has_Field ("agent")
           and then Root.Get ("agent").Kind /=
             GNATCOLL.JSON.JSON_String_Type
         then
            Set_Error
              ("spawn_subagent tool field 'agent' must be a string",
               Result,
               Is_Error);
            return;
         end if;

         if Root.Has_Field ("custom_prompt")
           and then Root.Get ("custom_prompt").Kind /=
             GNATCOLL.JSON.JSON_String_Type
         then
            Set_Error
              ("spawn_subagent tool field 'custom_prompt' must be a string",
               Result,
               Is_Error);
            return;
         end if;

         if Root.Has_Field ("name")
           and then Root.Get ("name").Kind /=
             GNATCOLL.JSON.JSON_String_Type
         then
            Set_Error
              ("spawn_subagent tool field 'name' must be a string",
               Result,
               Is_Error);
            return;
         end if;

         declare
            Prompt        : constant String := Root.Get ("prompt").Get;
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
            Output_R      : File_Descriptor := Invalid_FD;
            Output_W      : File_Descriptor := Invalid_FD;
            Null_In       : File_Descriptor := Invalid_FD;
            Null_Err      : File_Descriptor := Invalid_FD;
            Handle        : Process_Handle  := Invalid_Handle;
            Args          : Argument_List;
            Chunk         : String (1 .. 4096);
            Bytes_Read    : Integer;
            Exit_Code     : Integer := 0;
            pragma Unreferenced (Exit_Code);
            Output        : Unbounded_String;
            Json_Result   : GNATCOLL.JSON.JSON_Value;

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

               if Null_Err /= Invalid_FD then
                  Close (Null_Err);
                  Null_Err := Invalid_FD;
               end if;
            end Cleanup;

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
            Null_In := Invalid_FD;
            Close (Null_Err);
            Null_Err := Invalid_FD;
            Close (Output_W);
            Output_W := Invalid_FD;

            Read_Output_Loop : loop
               exit Read_Output_Loop when
                 Abort_Flg /= null and then Abort_Flg.Requested;
               Bytes_Read := Read (Output_R, Chunk);
               exit Read_Output_Loop when Bytes_Read <= 0;
               Append (Output, Chunk (1 .. Bytes_Read));
            end loop Read_Output_Loop;

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

            declare
               Raw_Output : constant String := To_String (Output);
            begin
               if not Find_Last_Json_Object (Raw_Output, Json_Result) then
                  Set_Error
                    ("subagent produced no output",
                     Result,
                     Is_Error);
                  Cleanup;
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
                     Result   := To_Unbounded_String (Output_Text);
                     Is_Error := False;
                  end;
               elsif Json_Result.Has_Field ("error")
                 and then Json_Result.Get ("error").Kind =
                   GNATCOLL.JSON.JSON_String_Type
               then
                  declare
                     Error_Text : constant String :=
                       Json_Result.Get ("error").Get;
                  begin
                     Set_Error (Error_Text, Result, Is_Error);
                  end;
               else
                  Set_Error
                    ("subagent produced no output",
                     Result,
                     Is_Error);
               end if;
            end;

            Cleanup;
         exception
            when Ex : others =>
               Cleanup;
               Set_Error
                 ("spawn_subagent tool failed: "
                  & Ada.Exceptions.Exception_Message (Ex),
                  Result,
                  Is_Error);
         end;
      end;
   end Execute;

end LLM.Tools.Spawn_Subagent;
