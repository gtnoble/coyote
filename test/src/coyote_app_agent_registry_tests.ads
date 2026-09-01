--  Coyote_App_Agent_Registry_Tests — runtime-agent registry tests.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;

package Coyote_App_Agent_Registry_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Register_Main_Agent_As_Root (T : in out Test);
   procedure Test_Register_Child_Under_Parent (T : in out Test);
   procedure Test_Register_Recursive_Descendants (T : in out Test);
   procedure Test_Runtime_Identity_Is_Separate (T : in out Test);
   procedure Test_Select_Live_Agent (T : in out Test);
   procedure Test_Ready_Agent_Accepts_Control (T : in out Test);
   procedure Test_Starting_Agent_Accepts_Control (T : in out Test);
   procedure Test_Live_Status_Transitions (T : in out Test);
   procedure Test_Durable_Session_Id_Update (T : in out Test);
   procedure Test_Terminal_Agent_Remains_Selectable (T : in out Test);
   procedure Test_Terminal_Agent_Rejects_Control (T : in out Test);
   procedure Test_Unknown_Parent_Is_Rejected (T : in out Test);
   procedure Test_Duplicate_Runtime_Id_Is_Rejected (T : in out Test);
   procedure Test_Clear_Removes_All_Records (T : in out Test);

end Coyote_App_Agent_Registry_Tests;
