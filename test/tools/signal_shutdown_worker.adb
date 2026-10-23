--  Signal_Shutdown_Worker — isolated production signal lifecycle probe.
--  Project: coyote

with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Text_IO;
with Coyote_Process_Control;
with Interfaces.C;

procedure Signal_Shutdown_Worker is
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Interfaces.C.int;

   function C_Raise (Signal : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "raise";

   protected Outcome is
      procedure Record_Failure (Message : String);
      function Failed return Boolean;
      function Message return String;
   private
      Is_Failed : Boolean := False;
      Failure_Message : String (1 .. 256) := (others => ' ');
      Message_Length : Natural := 0;
   end Outcome;

   protected body Outcome is
      procedure Record_Failure (Message : String) is
      begin
         Is_Failed := True;
         Message_Length :=
           Natural'Min (Message'Length, Failure_Message'Length);
         if Message_Length > 0 then
            Failure_Message (1 .. Message_Length) :=
              Message (Message'First .. Message'First + Message_Length - 1);
         end if;
      end Record_Failure;

      function Failed return Boolean is
      begin
         return Is_Failed;
      end Failed;

      function Message return String is
      begin
         return Failure_Message (1 .. Message_Length);
      end Message;
   end Outcome;

   protected Gate is
      procedure Release (Send_Signal : Boolean);
      entry Wait (Send_Signal : out Boolean);
   private
      Is_Released : Boolean := False;
      Signal_Enabled : Boolean := False;
   end Gate;

   protected body Gate is
      procedure Release (Send_Signal : Boolean) is
      begin
         Signal_Enabled := Send_Signal;
         Is_Released := True;
      end Release;

      entry Wait (Send_Signal : out Boolean) when Is_Released is
      begin
         Send_Signal := Signal_Enabled;
      end Wait;
   end Gate;

   task type Escalator;

   task body Escalator is
      Send_Signal : Boolean;
   begin
      Gate.Wait (Send_Signal);
      if Send_Signal then
         delay 0.2;
         if C_Raise (15) /= 0 then
            Outcome.Record_Failure ("second SIGTERM raise failed");
         end if;
      end if;
   exception
      when others =>
         Outcome.Record_Failure ("escalator task raised an exception");
   end Escalator;

   function Seconds_Elapsed
     (Started : Ada.Real_Time.Time; Finished : Ada.Real_Time.Time)
      return Duration is
   begin
      return Ada.Real_Time.To_Duration (Finished - Started);
   end Seconds_Elapsed;

   Mode : constant String :=
     (if Ada.Command_Line.Argument_Count = 1
      then Ada.Command_Line.Argument (1) else "");
   Grace : Natural := 1;
   Started : Ada.Real_Time.Time;
   Finished : Ada.Real_Time.Time;
   First : Boolean;
   Accepted : Boolean;
   Second : Escalator;
begin
   if Mode /= "grace" and then Mode /= "escalate" then
      Gate.Release (False);
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "invalid mode");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   if not Coyote_Process_Control.Install then
      raise Program_Error with "signal bridge installation failed";
   end if;

   if Mode = "escalate" then
      Grace := 5;
   end if;
   Coyote_Process_Control.Set_Grace_Seconds (Grace);

   if C_Raise (15) /= 0 then
      raise Program_Error with "first SIGTERM raise failed";
   end if;
   if Coyote_Process_Control.Read_Signal /= 1 then
      raise Program_Error with "first SIGTERM was not observed";
   end if;
   if Coyote_Process_Control.Read_Signal /= 0 then
      raise Program_Error with "first SIGTERM pipe did not drain";
   end if;

   Coyote_Process_Control.Begin_Shutdown (First);
   if not First or else not Coyote_Process_Control.Shutdown_Requested then
      raise Program_Error with "shutdown did not begin exactly once";
   end if;
   Coyote_Process_Control.Begin_Launch (Accepted);
   if Accepted then
      raise Program_Error with "launch accepted after shutdown";
   end if;
   Coyote_Process_Control.Begin_Persistence_Write (Accepted);
   if Accepted then
      raise Program_Error with "persistence accepted after shutdown";
   end if;

   Started := Ada.Real_Time.Clock;
   Gate.Release (Mode = "escalate");
   Coyote_Process_Control.Complete_Shutdown;
   Finished := Ada.Real_Time.Clock;

   if Mode = "grace" then
      if Seconds_Elapsed (Started, Finished) < 0.9
        or else Seconds_Elapsed (Started, Finished) > 5.0
      then
         raise Program_Error with "one-second grace duration out of bounds";
      end if;
   else
      if Seconds_Elapsed (Started, Finished) < 0.1
        or else Seconds_Elapsed (Started, Finished) >= 2.0
      then
         raise Program_Error with "second signal did not promptly escalate";
      end if;
   end if;

   if Outcome.Failed then
      raise Program_Error with Outcome.Message;
   end if;
   if Mode = "grace"
     and then Coyote_Process_Control.Read_Signal /= 0
   then
      raise Program_Error with "signal pipe remained readable after grace";
   end if;
exception
   when E : others =>
      Gate.Release (False);
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         Ada.Exceptions.Exception_Information (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Signal_Shutdown_Worker;
