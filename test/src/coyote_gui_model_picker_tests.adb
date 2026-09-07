with AUnit.Test_Caller;
--  Coyote_GUI_Model_Picker_Tests body.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_GUI.Model_Picker;

package body Coyote_GUI_Model_Picker_Tests is

   use AUnit.Assertions;
   use Coyote_GUI.Model_Picker;

   procedure Test_Cancelled_Result (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant Selection_Result := (Status => Cancelled);
   begin
      case Result.Status is
         when Cancelled =>
            null;
         when Selected | Use_Default =>
            Assert (False,
                    "default picker result must represent cancellation");
      end case;
   end Test_Cancelled_Result;

   procedure Test_Selected_Result (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant Selection_Result :=
        (Status     => Selected,
         Model_Spec => To_Unbounded_String ("openai/test-model"));
   begin
      case Result.Status is
         when Selected =>
            Assert (To_String (Result.Model_Spec) = "openai/test-model",
                    "selected result must preserve its model specification");
         when Cancelled | Use_Default =>
            Assert (False, "selected result must preserve its status");
      end case;
   end Test_Selected_Result;

   procedure Test_Default_Result (T : in out Test) is
      pragma Unreferenced (T);
      Result : constant Selection_Result := (Status => Use_Default);
   begin
      case Result.Status is
         when Use_Default =>
            null;
         when Cancelled | Selected =>
            Assert (False,
                    "default result must represent the fallback choice");
      end case;
   end Test_Default_Result;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("Coyote.GUI.Model_Picker cancelled result",
         Test_Cancelled_Result'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.GUI.Model_Picker selected result",
         Test_Selected_Result'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.GUI.Model_Picker default result",
         Test_Default_Result'Access));
      return Result;
   end Suite;

end Coyote_GUI_Model_Picker_Tests;
