with AUnit.Test_Caller;
--  Coyote_GUI_Navigation_Tests body.
--
--  Project: coyote

with AUnit.Assertions;
with Coyote_GUI.Navigation;
with Glib;

package body Coyote_GUI_Navigation_Tests is

   use AUnit.Assertions;
   use Coyote_GUI.Navigation;
   use type Glib.Gdouble;

   procedure Test_Line_Movement (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Target_Value (10.0, 0.0, 1000.0, 100.0, 18.0, Line_Down) = 28.0,
              "line down should advance by line size");
      Assert (Target_Value (10.0, 0.0, 1000.0, 100.0, 18.0, Line_Up) = 0.0,
              "line up should clamp at lower bound");
   end Test_Line_Movement;

   procedure Test_Page_Movement (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Target_Value (300.0, 0.0, 1000.0, 100.0, 18.0, Page_Down) = 400.0,
              "page down should advance by page size");
      Assert (Target_Value (300.0, 0.0, 1000.0, 100.0, 18.0, Page_Up) = 200.0,
              "page up should retreat by page size");
   end Test_Page_Movement;

   procedure Test_Top_Bottom_And_Clamp (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Target_Value (300.0, 0.0, 1000.0, 100.0, 18.0, To_Top) = 0.0,
              "top should select lower bound");
      Assert (Target_Value (0.0, 0.0, 1000.0, 100.0, 18.0, To_Bottom) = 900.0,
              "bottom should account for page size");
      Assert (Target_Value (1000.0, 0.0, 1000.0, 100.0, 18.0, Line_Down) = 900.0,
              "down should clamp at effective upper bound");
   end Test_Top_Bottom_And_Clamp;

   package Coyote_GUI_Navigation_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Navigation_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Navigation_Caller.Create
        ("Coyote.GUI.Navigation line movement",
         Coyote_GUI_Navigation_Tests.Test_Line_Movement'Access));
      Result.Add_Test (Coyote_GUI_Navigation_Caller.Create
        ("Coyote.GUI.Navigation page movement",
         Coyote_GUI_Navigation_Tests.Test_Page_Movement'Access));
      Result.Add_Test (Coyote_GUI_Navigation_Caller.Create
        ("Coyote.GUI.Navigation top bottom clamp",
         Coyote_GUI_Navigation_Tests.Test_Top_Bottom_And_Clamp'Access));

      return Result;
   end Suite;

end Coyote_GUI_Navigation_Tests;
