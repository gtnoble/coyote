--  LLM.Tools body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with LLM.Tools.Shell;
with LLM.Tools.Spawn_Subagent;
with LLM.Tools.Temp_File;

with GNATCOLL.JSON;
package body LLM.Tools is

   use type GNATCOLL.JSON.JSON_Value_Type;

   protected body Abort_Flag is

      procedure Set is
      begin
         Value := True;
      end Set;

      procedure Clear is
      begin
         Value := False;
      end Clear;

      function Requested return Boolean is
      begin
         return Value;
      end Requested;

      entry Wait_Requested when Value is
      begin
         null;
      end Wait_Requested;

   end Abort_Flag;

   protected body Pause_Flag is

      procedure Arm is
      begin
         Armed := True;
      end Arm;

      procedure Unarm is
      begin
         Armed := False;
      end Unarm;

      procedure Fire is
      begin
         if Armed then
            Armed  := False;
            Paused := True;
         end if;
      end Fire;

      procedure Release is
      begin
         Armed  := False;
         Paused := False;
      end Release;

      function Is_Armed return Boolean is
      begin
         return Armed;
      end Is_Armed;

      function Is_Paused return Boolean is
      begin
         return Paused;
      end Is_Paused;

      entry Wait_If_Paused when not Paused is
      begin
         null;
      end Wait_If_Paused;

   end Pause_Flag;

   function Built_In_Tools return Tool_Descriptor_Vectors.Vector is
      Result : Tool_Descriptor_Vectors.Vector;
   begin
      Result.Append (LLM.Tools.Shell.Descriptor);
      Result.Append (LLM.Tools.Spawn_Subagent.Descriptor);
      return Result;
   end Built_In_Tools;

   function Validate_Arguments (Args_Json : String) return String is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args_Json);
   begin
      if not Parsed.Success then
         return "tool arguments are not valid JSON; "
                & "the LLM response may have been truncated "
                & "due to output token limits";
      elsif Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         return "tool arguments must be a JSON object";
      else
         return "";
      end if;
   end Validate_Arguments;

   function Result_Threshold (Context_Window : Natural) return Positive is
      Raw : Natural;
   begin
      if Context_Window = 0 then
         return MAX_RESULT_THRESHOLD;
      end if;

      Raw := Context_Window * BYTES_PER_TOKEN / CONTEXT_SHARE;

      if Raw < MIN_RESULT_THRESHOLD then
         return MIN_RESULT_THRESHOLD;
      elsif Raw > MAX_RESULT_THRESHOLD then
         return MAX_RESULT_THRESHOLD;
      else
         return Raw;
      end if;
   end Result_Threshold;

   procedure Execute
     (Name           :     String;
      Args_Json      :     String;
      Result         : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error       : out Boolean;
      Abort_Flg      : access Abort_Flag := null;
      Context_Window :     Natural       := 0)
   is
      use Ada.Strings.Unbounded;
      Validation : constant String := Validate_Arguments (Args_Json);
   begin
      if Validation'Length > 0 then
         Result   := To_Unbounded_String (Validation);
         Is_Error := True;
         return;
      end if;

      if Name = "shell" then
         LLM.Tools.Shell.Execute (Args_Json, Result, Is_Error, Abort_Flg);
      elsif Name = "spawn_subagent" then
         LLM.Tools.Spawn_Subagent.Execute
           (Args_Json, Result, Is_Error, Abort_Flg);
      else
         raise Unknown_Tool with "unknown tool: " & Name;
      end if;

      --  Enforce the result size cap.  Any tool whose output exceeds the
      --  threshold has the full content spilled to a temp file; the caller
      --  receives an excerpt followed by a path to the complete file.
      Result := To_Unbounded_String
        (LLM.Tools.Temp_File.Truncated
           (To_String (Result),
            Threshold => Result_Threshold (Context_Window),
            Tool_Name => Name));
   end Execute;

end LLM.Tools;
