--  Coyote_App_Agent_Registry_Tests — runtime-agent registry tests.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_App.Agent_Registry;

package body Coyote_App_Agent_Registry_Tests is

   use AUnit.Assertions;
   use Ada.Strings.Unbounded;
   use Coyote_App.Agent_Registry;

   Root_Id : constant Agent_Id := Create_Agent_Id ("root");
   Child_Id : constant Agent_Id := Create_Agent_Id ("child");
   Grandchild_Id : constant Agent_Id := Create_Agent_Id ("grandchild");

   procedure Test_Register_Main_Agent_As_Root (T : in out Test) is
      pragma Unreferenced (T);
      R      : Registry;
      Agent_Data : Agent_Record;
   begin
      Assert (Register_Root (R, Root_Id, "session-root", "main"),
              "root registration must succeed");
      Agent_Data := Agent_At (R, 1);
      Assert (Agent_Count (R) = 1, "root must be the first record");
      Assert (Agent_Data.Runtime_Id = Root_Id, "root identity must be retained");
      Assert (Is_Empty (Agent_Data.Parent_Runtime_Id),
              "root must not have a parent");
      Assert (To_String (Agent_Data.Durable_Session_Id) = "session-root",
              "durable session identity must be retained");
      Assert (To_String (Agent_Data.Label) = "main",
              "root label must be retained");
   end Test_Register_Main_Agent_As_Root;

   procedure Test_Register_Child_Under_Parent (T : in out Test) is
      pragma Unreferenced (T);
      R      : Registry;
      Agent_Data : Agent_Record;
   begin
      Assert (Register_Root (R, Root_Id), "root registration must succeed");
      Assert (Register_Child (R, Child_Id, Root_Id, "session-child", "worker"),
              "child registration must succeed");
      Agent_Data := Get_Agent (R, Child_Id);
      Assert (Agent_Data.Parent_Runtime_Id = Root_Id,
              "child parent identity must be retained");
      Assert (Agent_Data.Endpoint = RPC_Endpoint,
              "child endpoint should be RPC");
      Assert (Child_Count (R, Root_Id) = 1,
              "parent must report one child");
      Assert (Child_At (R, Root_Id, 1) = Child_Id,
              "child lookup must follow registration order");
   end Test_Register_Child_Under_Parent;

   procedure Test_Register_Agent_Endpoint_Kind (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
      Agent_Data : Agent_Record;
   begin
      Assert
        (Register_Agent
           (R                  => R,
            Runtime_Id         => Root_Id,
            Parent_Runtime_Id  => Create_Agent_Id (""),
            Endpoint           => Local_Endpoint,
            Label              => "main"),
         "generic root registration must succeed");
      Agent_Data := Get_Agent (R, Root_Id);
      Assert (Agent_Data.Endpoint = Local_Endpoint,
              "generic root endpoint should be local");
      Assert
        (Register_Agent
           (R                  => R,
            Runtime_Id         => Child_Id,
            Parent_Runtime_Id  => Root_Id,
            Endpoint           => RPC_Endpoint),
         "generic child registration must succeed");
      Agent_Data := Get_Agent (R, Child_Id);
      Assert (Agent_Data.Endpoint = RPC_Endpoint,
              "generic child endpoint should be RPC");
   end Test_Register_Agent_Endpoint_Kind;

   procedure Test_Register_Recursive_Descendants (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id), "root registration must succeed");
      Assert (Register_Child (R, Child_Id, Root_Id),
              "child registration must succeed");
      Assert (Register_Child (R, Grandchild_Id, Child_Id),
              "grandchild registration must succeed");
      Assert (Child_Count (R, Root_Id) = 1,
              "root must have only its direct child");
      Assert (Child_Count (R, Child_Id) = 1,
              "child must have its direct grandchild");
      Assert (Child_At (R, Child_Id, 1) = Grandchild_Id,
              "grandchild must be below its launching agent");
   end Test_Register_Recursive_Descendants;

   procedure Test_Runtime_Identity_Is_Separate (T : in out Test) is
      pragma Unreferenced (T);
      R      : Registry;
      Agent_Data : Agent_Record;
   begin
      Assert (Root_Id /= Create_Agent_Id ("session-root"),
              "runtime and durable identities must be distinct values");
      Assert (Register_Root (R, Root_Id, "session-root"),
              "root registration must succeed");
      Agent_Data := Get_Agent (R, Root_Id);
      Assert (To_String (Agent_Data.Durable_Session_Id) = "session-root",
              "durable identity must be stored separately");
   end Test_Runtime_Identity_Is_Separate;

   procedure Test_Select_Live_Agent (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id, Status => Running),
              "root registration must succeed");
      Assert (Register_Child (R, Child_Id, Root_Id, Status => Running),
              "child registration must succeed");
      Assert (Select_Agent (R, Child_Id),
              "live child selection must succeed");
      Assert (Selected_Agent (R) = Child_Id,
              "selected identity must be retained");
      Assert (Has_Selection (R), "registry must report a selection");
      Assert (Can_Control (R, Child_Id),
              "live selected agent must accept controls");
   end Test_Select_Live_Agent;

   procedure Test_Ready_Agent_Accepts_Control (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id, Status => Ready),
              "ready root registration must succeed");
      Assert (Can_Control (R, Root_Id),
              "ready agent must accept live controls");
   end Test_Ready_Agent_Accepts_Control;

   procedure Test_Starting_Agent_Accepts_Control (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id),
              "root registration must succeed");
      Assert (Register_Child (R, Child_Id, Root_Id),
              "child registration must succeed");
      Assert (Can_Control (R, Child_Id),
              "starting child must accept Stop control");
   end Test_Starting_Agent_Accepts_Control;

   procedure Test_Live_Status_Transitions (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id),
              "root registration must succeed");
      Assert (Register_Child (R, Child_Id, Root_Id),
              "child registration must succeed");
      Assert (Set_Status (R, Child_Id, Running),
              "running transition must succeed");
      Assert (Can_Control (R, Child_Id),
              "running child must accept control");
      Assert (Set_Status (R, Child_Id, Paused),
              "paused transition must succeed");
      Assert (Can_Control (R, Child_Id),
              "paused child must accept control");
      Assert (Set_Status (R, Child_Id, Ready),
              "ready transition must succeed");
      Assert (Can_Control (R, Child_Id),
              "ready child must accept Stop control");
      Assert (Set_Status (R, Child_Id, Aborted),
              "aborted transition must succeed");
      Assert (not Can_Control (R, Child_Id),
              "aborted child must reject control");
   end Test_Live_Status_Transitions;

   procedure Test_Durable_Session_Id_Update (T : in out Test) is
      pragma Unreferenced (T);
      R      : Registry;
      Agent_Data : Agent_Record;
   begin
      Assert (Register_Root (R, Root_Id), "root registration must succeed");
      Assert (Set_Durable_Session_Id (R, Root_Id, "session-42"),
              "durable session update must succeed");
      Agent_Data := Get_Agent (R, Root_Id);
      Assert (To_String (Agent_Data.Durable_Session_Id) = "session-42",
              "durable session update must be retained");
   end Test_Durable_Session_Id_Update;

   procedure Test_Terminal_Agent_Remains_Selectable (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id, Status => Completed),
              "terminal root registration must succeed");
      Assert (Select_Agent (R, Root_Id),
              "terminal agent must remain selectable for review");
      Assert (Selected_Agent (R) = Root_Id,
              "terminal selection must be retained");
      Assert (Agent_Count (R) = 1,
              "terminal record must remain in the registry");
   end Test_Terminal_Agent_Remains_Selectable;

   procedure Test_Terminal_Agent_Rejects_Control (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id, Status => Failed),
              "failed root registration must succeed");
      Assert (not Can_Control (R, Root_Id),
              "terminal agent must reject live controls");
      Assert (Set_Status (R, Root_Id, Running),
              "status transition must succeed");
      Assert (Can_Control (R, Root_Id),
              "running agent must accept live controls");
   end Test_Terminal_Agent_Rejects_Control;

   procedure Test_Unknown_Parent_Is_Rejected (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id), "root registration must succeed");
      Assert
        (not Register_Child (R, Child_Id, Create_Agent_Id ("unknown")),
         "unknown parent must reject child registration");
      Assert (Agent_Count (R) = 1,
              "rejected child must not alter the registry");
   end Test_Unknown_Parent_Is_Rejected;

   procedure Test_Duplicate_Runtime_Id_Is_Rejected (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id), "root registration must succeed");
      Assert (not Register_Root (R, Root_Id),
              "second root registration must be rejected");
      Assert (not Register_Child (R, Root_Id, Root_Id),
              "duplicate child identity must be rejected");
      Assert (Agent_Count (R) = 1,
              "duplicate registrations must not alter the registry");
   end Test_Duplicate_Runtime_Id_Is_Rejected;

   procedure Test_Clear_Removes_All_Records (T : in out Test) is
      pragma Unreferenced (T);
      R : Registry;
   begin
      Assert (Register_Root (R, Root_Id), "root registration must succeed");
      Assert (Select_Agent (R, Root_Id), "selection must succeed");
      Clear (R);
      Assert (Agent_Count (R) = 0, "clear must remove all records");
      Assert (not Has_Selection (R), "clear must remove selection");
      Assert (not Has_Agent (R, Root_Id),
              "cleared agent must no longer be found");
   end Test_Clear_Removes_All_Records;

end Coyote_App_Agent_Registry_Tests;
