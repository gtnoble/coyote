with AUnit.Test_Caller;
--  Coyote_GUI_Zoom_Tests body.
--
--  Project: coyote

with AUnit.Assertions;
with Coyote_GUI.Zoom;

package body Coyote_GUI_Zoom_Tests is

   use AUnit.Assertions;
   use Coyote_GUI.Zoom;

   Base : constant := 11;

   procedure Test_Effective_Size_At_Zero_Level (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Effective_Size_Pt (0, Base) = Base,
              "level 0 yields the baseline size");
   end Test_Effective_Size_At_Zero_Level;

   procedure Test_Effective_Size_Positive_Level (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Effective_Size_Pt (3, Base) = Base + 3 * Zoom_Step_Pt,
              "positive level scales by Zoom_Step_Pt");
   end Test_Effective_Size_Positive_Level;

   procedure Test_Effective_Size_Clamps_At_Max (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Effective_Size_Pt (1000, Base) = Max_Size_Pt,
              "very high level clamps at Max_Size_Pt");
   end Test_Effective_Size_Clamps_At_Max;

   procedure Test_Effective_Size_Clamps_At_Min (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Effective_Size_Pt (-1000, Base) = Min_Size_Pt,
              "very low level clamps at Min_Size_Pt");
   end Test_Effective_Size_Clamps_At_Min;

   procedure Test_Step_Zoom_In_Changes_Level (T : in out Test) is
      pragma Unreferenced (T);
      Level   : Integer := 0;
      Changed : Boolean;
   begin
      Step_Zoom (Level, 1, Base, Changed);
      Assert (Changed, "zoom in from level 0 reports a change");
      Assert (Level = 1, "zoom in from level 0 advances to level 1");
   end Test_Step_Zoom_In_Changes_Level;

   procedure Test_Step_Zoom_Out_Changes_Level (T : in out Test) is
      pragma Unreferenced (T);
      Level   : Integer := 0;
      Changed : Boolean;
   begin
      Step_Zoom (Level, -1, Base, Changed);
      Assert (Changed, "zoom out from level 0 reports a change");
      Assert (Level = -1, "zoom out from level 0 goes to level -1");
   end Test_Step_Zoom_Out_Changes_Level;

   procedure Test_Step_Zoom_At_Max_Reports_No_Change (T : in out Test) is
      pragma Unreferenced (T);
      Level   : Integer := (Max_Size_Pt - Base) / Zoom_Step_Pt;
      Changed : Boolean;
   begin
      Step_Zoom (Level, 1, Base, Changed);
      Assert (not Changed, "zoom in at max effective size reports no change");
      Assert (Effective_Size_Pt (Level, Base) = Max_Size_Pt,
              "level still maps to the max effective size");
   end Test_Step_Zoom_At_Max_Reports_No_Change;

   procedure Test_Step_Zoom_At_Min_Reports_No_Change (T : in out Test) is
      pragma Unreferenced (T);
      Level   : Integer := (Min_Size_Pt - Base) / Zoom_Step_Pt;
      Changed : Boolean;
   begin
      Step_Zoom (Level, -1, Base, Changed);
      Assert (not Changed, "zoom out at min effective size reports no change");
      Assert (Effective_Size_Pt (Level, Base) = Min_Size_Pt,
              "level still maps to the min effective size");
   end Test_Step_Zoom_At_Min_Reports_No_Change;

   procedure Test_Step_Zoom_Multi_Step (T : in out Test) is
      pragma Unreferenced (T);
      Level   : Integer := 0;
      Changed : Boolean;
   begin
      Step_Zoom (Level, 3, Base, Changed);
      Assert (Changed, "multi-step zoom in reports a change");
      Assert (Level = 3, "multi-step zoom in advances level by 3");
   end Test_Step_Zoom_Multi_Step;

   procedure Test_Step_Zoom_Multi_Step_Stops_At_Clamp (T : in out Test) is
      pragma Unreferenced (T);
      Level   : Integer := 0;
      Changed : Boolean;
   begin
      Step_Zoom (Level, 10_000, Base, Changed);
      Assert (Changed, "huge zoom-in request reports a change");
      Assert (Effective_Size_Pt (Level, Base) = Max_Size_Pt,
              "level stops at the first level mapping to max size");
      Assert (Level <= (Max_Size_Pt - Min_Size_Pt) / Zoom_Step_Pt + 1,
              "level does not run away far past the clamp");
   end Test_Step_Zoom_Multi_Step_Stops_At_Clamp;

   procedure Test_Step_Zoom_Zero_Steps_No_Change (T : in out Test) is
      pragma Unreferenced (T);
      Level   : Integer := 5;
      Changed : Boolean;
   begin
      Step_Zoom (Level, 0, Base, Changed);
      Assert (not Changed, "zero steps report no change");
      Assert (Level = 5, "zero steps leave the level untouched");
   end Test_Step_Zoom_Zero_Steps_No_Change;

   procedure Test_Clamped_Base_Pt (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Clamped_Base_Pt (11) = 11, "in-range baseline unchanged");
      Assert (Clamped_Base_Pt (2) = Min_Size_Pt,
              "tiny baseline clamps to Min_Size_Pt");
      Assert (Clamped_Base_Pt (100) = Max_Size_Pt,
              "huge baseline clamps to Max_Size_Pt");
   end Test_Clamped_Base_Pt;

   package Coyote_GUI_Zoom_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Zoom_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom effective size at level zero",
         Coyote_GUI_Zoom_Tests.Test_Effective_Size_At_Zero_Level'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom effective size at positive level",
         Coyote_GUI_Zoom_Tests.Test_Effective_Size_Positive_Level'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom effective size clamps at maximum",
         Coyote_GUI_Zoom_Tests.Test_Effective_Size_Clamps_At_Max'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom effective size clamps at minimum",
         Coyote_GUI_Zoom_Tests.Test_Effective_Size_Clamps_At_Min'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom step zoom in changes level",
         Coyote_GUI_Zoom_Tests.Test_Step_Zoom_In_Changes_Level'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom step zoom out changes level",
         Coyote_GUI_Zoom_Tests.Test_Step_Zoom_Out_Changes_Level'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom step zoom at max reports no change",
         Coyote_GUI_Zoom_Tests.Test_Step_Zoom_At_Max_Reports_No_Change'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom step zoom at min reports no change",
         Coyote_GUI_Zoom_Tests.Test_Step_Zoom_At_Min_Reports_No_Change'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom step zoom applies multiple steps",
         Coyote_GUI_Zoom_Tests.Test_Step_Zoom_Multi_Step'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom step zoom stops at the clamp",
         Coyote_GUI_Zoom_Tests.Test_Step_Zoom_Multi_Step_Stops_At_Clamp'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom zero steps report no change",
         Coyote_GUI_Zoom_Tests.Test_Step_Zoom_Zero_Steps_No_Change'Access));
      Result.Add_Test (Coyote_GUI_Zoom_Caller.Create
        ("Coyote.GUI.Zoom baseline clamps to valid range",
         Coyote_GUI_Zoom_Tests.Test_Clamped_Base_Pt'Access));

      return Result;
   end Suite;

end Coyote_GUI_Zoom_Tests;
