--  Coyote_Process_Control body.
--  Project: coyote

with Ada.Real_Time;
with Interfaces.C;

package body Coyote_Process_Control is

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Interfaces.C.int;


   function C_Signal_Install return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "coyote_signal_install";

   function C_Signal_Read return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "coyote_signal_read";

   function C_Signal_Group_Tree
     (Pid    : Interfaces.C.int;
      Signal : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "coyote_signal_group_tree";

   MAX_GROUPS : constant Positive := 128;
   subtype Group_Index is Positive range 1 .. MAX_GROUPS;
   type Group_Array is array (Group_Index) of Integer;

   protected type Controller is
      function Signal_Count return Natural;
      procedure Set_Grace_Seconds (Value : Natural);
      function Grace_Seconds return Natural;
      procedure Begin_Launch (Accepted : out Boolean);
      procedure Complete_Launch
        (Pid : Integer; Needs_Signal : out Boolean);
      procedure Cancel_Launch;
      entry Wait_For_Launches;
      entry Wait_For_Groups;
      procedure Begin_Shutdown (First : out Boolean);
      function Shutdown_Requested return Boolean;
      procedure Stop_Monitor;
      function Monitor_Should_Stop return Boolean;

      procedure Get_Groups
        (Values : out Group_Array;
         Count  : out Natural);
      procedure Unregister (Pid : Integer);
      entry Freeze_Persistence;
      procedure Begin_Persistence_Write (Accepted : out Boolean);
      procedure End_Persistence_Write;
   private
      Launches_Active    : Natural := 0;
      Groups             : Group_Array := (others => 0);
      Group_Count        : Natural := 0;
      Shutdown           : Boolean := False;
      Monitor_Stop       : Boolean := False;
      Persistence_Frozen : Boolean := False;
      Freeze_Requested   : Boolean := False;
      Writes_Active      : Natural := 0;
      Grace              : Natural := 2;
   end Controller;

   protected body Controller is

      function Signal_Count return Natural is
         Value : constant Interfaces.C.int := C_Signal_Read;
      begin
         if Value >= 2 then
            return 2;
         elsif Value = 1 then
            return 1;
         else
            return 0;
         end if;
      end Signal_Count;

      procedure Set_Grace_Seconds (Value : Natural) is
      begin
         Grace := Natural'Min (30, Value);
      end Set_Grace_Seconds;

      function Grace_Seconds return Natural is
      begin
         return Grace;
      end Grace_Seconds;

      procedure Begin_Launch (Accepted : out Boolean) is
      begin
         Accepted :=
           not Shutdown
           and then Group_Count + Launches_Active < MAX_GROUPS;
         if Accepted then
            Launches_Active := Launches_Active + 1;
         end if;
      end Begin_Launch;

      procedure Complete_Launch
        (Pid : Integer; Needs_Signal : out Boolean)
      is
      begin
         if Launches_Active > 0 then
            Launches_Active := Launches_Active - 1;
         end if;
         Needs_Signal := Shutdown;
         if Pid > 0 and then Group_Count < MAX_GROUPS then
            Group_Count := Group_Count + 1;
            Groups (Group_Index (Group_Count)) := Pid;
         end if;
      end Complete_Launch;

      procedure Cancel_Launch is
      begin
         if Launches_Active > 0 then
            Launches_Active := Launches_Active - 1;
         end if;
      end Cancel_Launch;

      entry Wait_For_Launches when Launches_Active = 0 is
      begin
         null;
      end Wait_For_Launches;

      entry Wait_For_Groups when Group_Count = 0 is
      begin
         null;
      end Wait_For_Groups;

      procedure Begin_Shutdown (First : out Boolean) is
      begin
         First := not Shutdown;
         Shutdown := True;
         Freeze_Requested := True;
         if Writes_Active = 0 then
            Persistence_Frozen := True;
         end if;
      end Begin_Shutdown;

      function Shutdown_Requested return Boolean is
      begin
         return Shutdown;
      end Shutdown_Requested;

      procedure Stop_Monitor is
      begin
         Monitor_Stop := True;
      end Stop_Monitor;

      function Monitor_Should_Stop return Boolean is
      begin
         return Monitor_Stop;
      end Monitor_Should_Stop;

      procedure Get_Groups
        (Values : out Group_Array;
         Count  : out Natural)
      is
      begin
         Values := Groups;
         Count := Group_Count;
      end Get_Groups;

      procedure Unregister (Pid : Integer) is
      begin
         if Group_Count = 0 then
            return;
         end if;
         for I in Group_Index'First .. Group_Index (Group_Count) loop
            if Groups (I) = Pid then
               Groups (I) := Groups (Group_Count);
               Groups (Group_Count) := 0;
               Group_Count := Group_Count - 1;
               exit;
            end if;
         end loop;
      end Unregister;

      entry Freeze_Persistence when Writes_Active = 0 is
      begin
         Persistence_Frozen := True;
      end Freeze_Persistence;

      procedure Begin_Persistence_Write (Accepted : out Boolean) is
      begin
         Accepted := not Persistence_Frozen and then not Freeze_Requested;
         if Accepted then
            Writes_Active := Writes_Active + 1;
         end if;
      end Begin_Persistence_Write;

      procedure End_Persistence_Write is
      begin
         if Writes_Active > 0 then
            Writes_Active := Writes_Active - 1;
         end if;
         if Writes_Active = 0 and then Freeze_Requested then
            Persistence_Frozen := True;
         end if;
      end End_Persistence_Write;

   end Controller;

   State : Controller;

   function Install return Boolean is
   begin
      return C_Signal_Install = 0;
   end Install;

   function Read_Signal return Natural is
   begin
      return State.Signal_Count;
   end Read_Signal;

   procedure Set_Grace_Seconds (Value : Natural) is
   begin
      State.Set_Grace_Seconds (Value);
   end Set_Grace_Seconds;

   function Grace_Seconds return Natural is
   begin
      return State.Grace_Seconds;
   end Grace_Seconds;

   procedure Begin_Launch (Accepted : out Boolean) is
   begin
      State.Begin_Launch (Accepted);
   end Begin_Launch;

   procedure Complete_Launch
     (Pid : Integer; Needs_Signal : out Boolean)
   is
   begin
      State.Complete_Launch (Pid, Needs_Signal);
   end Complete_Launch;

   procedure Cancel_Launch is
   begin
      State.Cancel_Launch;
   end Cancel_Launch;

   procedure Wait_For_Launches is
   begin
      State.Wait_For_Launches;
   end Wait_For_Launches;

   procedure Wait_For_Groups is
   begin
      State.Wait_For_Groups;
   end Wait_For_Groups;

   procedure Begin_Shutdown (First : out Boolean) is
   begin
      State.Begin_Shutdown (First);
   end Begin_Shutdown;

   procedure Complete_Shutdown (Immediate : Boolean := False) is
      Deadline : Ada.Real_Time.Time;
      Signal   : Natural;
   begin
      Freeze_Persistence;
      Wait_For_Launches;
      Signal_All (SIGTERM_Signal);
      Deadline :=
        Ada.Real_Time.Clock
        + Ada.Real_Time.Seconds (Integer (Grace_Seconds));
      if not Immediate then
         loop
            Signal := Read_Signal;
            exit when Signal >= 2;
            exit when Ada.Real_Time.Clock >= Deadline;
            delay 0.05;
         end loop;
      end if;
      Signal_All (SIGKILL_Signal);
      Wait_For_Groups;
   end Complete_Shutdown;

   function Shutdown_Requested return Boolean is
   begin
      return State.Shutdown_Requested;
   end Shutdown_Requested;

   procedure Stop_Monitor is
   begin
      State.Stop_Monitor;
   end Stop_Monitor;

   function Monitor_Should_Stop return Boolean is
   begin
      return State.Monitor_Should_Stop;
   end Monitor_Should_Stop;

   procedure Signal_All (Signal : Integer) is
      Values : Group_Array;
      Count  : Natural;
   begin
      State.Get_Groups (Values, Count);
      if Count = 0 then
         return;
      end if;
      for I in Group_Index'First .. Group_Index (Count) loop
         if Values (I) > 0 then
            declare
               Ignored : Interfaces.C.int;
            begin
               Ignored :=
                 C_Signal_Group_Tree
                   (Interfaces.C.int (Values (I)),
                    Interfaces.C.int (Signal));
               pragma Unreferenced (Ignored);
            end;
         end if;
      end loop;
   end Signal_All;

   procedure Signal_Group (Pid : Integer; Signal : Integer) is
      Ignored : Interfaces.C.int;
   begin
      Ignored :=
        C_Signal_Group_Tree
          (Interfaces.C.int (Pid), Interfaces.C.int (Signal));
      pragma Unreferenced (Ignored);
   end Signal_Group;

   procedure Unregister (Pid : Integer) is
   begin
      State.Unregister (Pid);
   end Unregister;

   procedure Freeze_Persistence is
   begin
      State.Freeze_Persistence;
   end Freeze_Persistence;

   procedure Begin_Persistence_Write (Accepted : out Boolean) is
   begin
      State.Begin_Persistence_Write (Accepted);
   end Begin_Persistence_Write;

   procedure End_Persistence_Write is
   begin
      State.End_Persistence_Write;
   end End_Persistence_Write;

end Coyote_Process_Control;
