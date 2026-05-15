--  LLM.Tools body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with LLM.Tools.Shell;
with LLM.Tools.Spawn_Subagent;

package body LLM.Tools is

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

   procedure Execute
     (Name      :     String;
      Args_Json :     String;
      Result    : out Ada.Strings.Unbounded.Unbounded_String;
      Is_Error  : out Boolean;
      Abort_Flg : access Abort_Flag := null)
   is
   begin
      if Name = "shell" then
         LLM.Tools.Shell.Execute (Args_Json, Result, Is_Error, Abort_Flg);
      elsif Name = "spawn_subagent" then
         LLM.Tools.Spawn_Subagent.Execute
           (Args_Json, Result, Is_Error, Abort_Flg);
      else
         raise Unknown_Tool with "unknown tool: " & Name;
      end if;
   end Execute;

end LLM.Tools;
