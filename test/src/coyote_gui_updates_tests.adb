with AUnit.Assertions;
with Ada.Strings.Unbounded;
with Coyote_GUI;
with Coyote_GUI.Updates;
with AUnit.Test_Caller;
with AUnit.Test_Suites;

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

   procedure Test_Runtime_Agent_Id_Round_Trips (T : in out Test) is
      pragma Unreferenced (T);
      Queue  : Coyote_GUI.Updates.Queue;
      Input  : Coyote_GUI.Update;
      Output : Coyote_GUI.Update;
      Got    : Boolean;
      Wake   : Boolean;
   begin
      Input.Kind := Coyote_GUI.Append_Text;
      Input.Runtime_Agent_Id := To_Unbounded_String ("agent-7");
      Input.Text := To_Unbounded_String ("child output");
      Queue.Enqueue (Input, Wake);
      Queue.Dequeue (Output, Got);
      Assert (Got, "identity update must be dequeued");
      Assert (To_String (Output.Runtime_Agent_Id) = "agent-7",
              "runtime agent identity must survive update transport");
      Assert (To_String (Output.Text) = "child output",
              "update payload must survive identity transport");
   end Test_Runtime_Agent_Id_Round_Trips;

   procedure Test_Footer_Summary_Round_Trips (T : in out Test) is
      pragma Unreferenced (T);
      Queue : Coyote_GUI.Updates.Queue;
      Input : Coyote_GUI.Update;
      Output : Coyote_GUI.Update;
      Got : Boolean;
      Wake : Boolean;
   begin
      Input.Kind := Coyote_GUI.Append_Turn_Footer;
      Input.Text := To_Unbounded_String ("formatted footer");
      Input.Text2 := To_Unbounded_String ("[ctx 24k/400k (6%)]");
      Queue.Enqueue (Input, Wake);
      Queue.Dequeue (Output, Got);
      Assert (Got, "footer update must be dequeued");
      Assert (To_String (Output.Text2) = To_String (Input.Text2),
              "footer summary must survive the update queue");
   end Test_Footer_Summary_Round_Trips;


   package Coyote_GUI_Updates_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Updates_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates first enqueue wakes exactly once",
         Coyote_GUI_Updates_Tests.Test_First_Enqueue_Wakes_Exactly_Once'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates pending enqueue does not duplicate wakeup",
         Coyote_GUI_Updates_Tests.Test_Pending_Enqueue_Does_Not_Duplicate_Wakeup'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates idle completion keeps source for pending work",
         Coyote_GUI_Updates_Tests.Test_Idle_Done_Keeps_Source_For_Pending_Work'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates idle completion clears source when empty",
         Coyote_GUI_Updates_Tests.Test_Idle_Done_Clears_Source_When_Empty'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates enqueue rearms after idle completion",
         Coyote_GUI_Updates_Tests.Test_Enqueue_Rearms_After_Idle_Done'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates stopped queue does not wake",
         Coyote_GUI_Updates_Tests.Test_Stopped_Queue_Does_Not_Wake'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates preserves runtime agent identity",
         Coyote_GUI_Updates_Tests.Test_Runtime_Agent_Id_Round_Trips'Access));
      Result.Add_Test (Coyote_GUI_Updates_Caller.Create
        ("Coyote.GUI.Updates preserves footer summary",
         Coyote_GUI_Updates_Tests.Test_Footer_Summary_Round_Trips'Access));

      return Result;
   end Suite;

end Coyote_GUI_Updates_Tests;
