with AUnit.Assertions;
with Ada.Strings.Unbounded;
with Coyote_GUI;
with Coyote_GUI.Updates;

package body Coyote_GUI_Updates_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;

   function Sample_Update return Coyote_GUI.Update is
      U : Coyote_GUI.Update;
   begin
      U.Kind := Coyote_GUI.Set_Status;
      U.Text := To_Unbounded_String ("test");
      return U;
   end Sample_Update;

   procedure Test_First_Enqueue_Wakes_Exactly_Once (T : in out Test) is
      pragma Unreferenced (T);
      Queue : Coyote_GUI.Updates.Queue;
      Wake  : Boolean;
   begin
      Queue.Enqueue (Sample_Update, Wake);
      Assert (Wake, "first enqueue must request an idle source");
      Queue.Enqueue (Sample_Update, Wake);
      Assert (not Wake,
              "pending enqueue must not request a second idle source");
   end Test_First_Enqueue_Wakes_Exactly_Once;

   procedure Test_Pending_Enqueue_Does_Not_Duplicate_Wakeup
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Queue : Coyote_GUI.Updates.Queue;
      Wake  : Boolean;
   begin
      Queue.Enqueue (Sample_Update, Wake);
      Assert (Wake, "first enqueue must request an idle source");
      Queue.Enqueue (Sample_Update, Wake);
      Assert (not Wake, "second pending enqueue must not wake again");
   end Test_Pending_Enqueue_Does_Not_Duplicate_Wakeup;

   procedure Test_Idle_Done_Keeps_Source_For_Pending_Work
     (T : in out Test)
   is
      pragma Unreferenced (T);
      Queue       : Coyote_GUI.Updates.Queue;
      U           : Coyote_GUI.Update;
      Got         : Boolean;
      Wake        : Boolean;
      Keep_Active : Boolean;
   begin
      Queue.Enqueue (Sample_Update, Wake);
      Queue.Enqueue (Sample_Update, Wake);
      Queue.Dequeue (U, Got);
      Assert (Got, "queued update must be dequeued");
      Queue.Idle_Done (Keep_Active);
      Assert (Keep_Active,
              "idle source must remain active while work is pending");
      Queue.Enqueue (Sample_Update, Wake);
      Assert (not Wake,
              "pending work must not register a competing idle source");
   end Test_Idle_Done_Keeps_Source_For_Pending_Work;

   procedure Test_Idle_Done_Clears_Source_When_Empty (T : in out Test) is
      pragma Unreferenced (T);
      Queue       : Coyote_GUI.Updates.Queue;
      U           : Coyote_GUI.Update;
      Got         : Boolean;
      Wake        : Boolean;
      Keep_Active : Boolean;
   begin
      Queue.Enqueue (Sample_Update, Wake);
      Queue.Dequeue (U, Got);
      Assert (Got, "queued update must be dequeued");
      Queue.Idle_Done (Keep_Active);
      Assert (not Keep_Active,
              "idle source must stop when the queue becomes empty");
      Queue.Enqueue (Sample_Update, Wake);
      Assert (Wake, "enqueue after idle completion must rearm the source");
   end Test_Idle_Done_Clears_Source_When_Empty;

   procedure Test_Enqueue_Rearms_After_Idle_Done (T : in out Test) is
      pragma Unreferenced (T);
      Queue       : Coyote_GUI.Updates.Queue;
      U           : Coyote_GUI.Update;
      Got         : Boolean;
      Wake        : Boolean;
      Keep_Active : Boolean;
   begin
      Queue.Enqueue (Sample_Update, Wake);
      Assert (Wake, "first enqueue must request an idle source");
      Queue.Dequeue (U, Got);
      Queue.Idle_Done (Keep_Active);
      Assert (not Keep_Active, "idle source must stop with no pending work");
      Queue.Enqueue (Sample_Update, Wake);
      Assert (Wake, "new work must request a new idle source");
   end Test_Enqueue_Rearms_After_Idle_Done;

   procedure Test_Stopped_Queue_Does_Not_Wake (T : in out Test) is
      pragma Unreferenced (T);
      Queue : Coyote_GUI.Updates.Queue;
      U     : Coyote_GUI.Update;
      Got   : Boolean;
      Wake  : Boolean;
   begin
      Queue.Stop;
      Queue.Enqueue (Sample_Update, Wake);
      Assert (not Wake, "stopped queue must not request an idle source");
      Queue.Dequeue (U, Got);
      Assert (not Got, "stopped queue must not retain a new update");
   end Test_Stopped_Queue_Does_Not_Wake;

end Coyote_GUI_Updates_Tests;
