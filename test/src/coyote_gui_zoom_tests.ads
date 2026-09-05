--  Coyote_GUI_Zoom_Tests — unit tests for Coyote_GUI.Zoom arithmetic.
--
--  Pure logic tests: no GTK widgets, no display required.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Coyote_GUI_Zoom_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Effective_Size_At_Zero_Level        (T : in out Test);
   procedure Test_Effective_Size_Positive_Level       (T : in out Test);
   procedure Test_Effective_Size_Clamps_At_Max        (T : in out Test);
   procedure Test_Effective_Size_Clamps_At_Min        (T : in out Test);
   procedure Test_Step_Zoom_In_Changes_Level          (T : in out Test);
   procedure Test_Step_Zoom_Out_Changes_Level         (T : in out Test);
   procedure Test_Step_Zoom_At_Max_Reports_No_Change  (T : in out Test);
   procedure Test_Step_Zoom_At_Min_Reports_No_Change  (T : in out Test);
   procedure Test_Step_Zoom_Multi_Step                (T : in out Test);
   procedure Test_Step_Zoom_Multi_Step_Stops_At_Clamp (T : in out Test);
   procedure Test_Step_Zoom_Zero_Steps_No_Change      (T : in out Test);
   procedure Test_Clamped_Base_Pt                     (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Zoom_Tests;
