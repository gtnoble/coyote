--  LLM.Tools body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

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

end LLM.Tools;
