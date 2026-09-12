--  Coyote_GUI_CSM2_Qualification_Tests — display-backed CSM-2 qualification.
--
--  Tests are explicitly display-gated; pure parser/model qualification is
--  provided by Coyote_CSM2_Qualification_Tests and always runs headlessly.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Coyote_GUI.Conversation_Stack;
with Gtk.Window;

package Coyote_GUI_CSM2_Qualification_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
      Parent            : Gtk.Window.Gtk_Window;
      Stack             : Coyote_GUI.Conversation_Stack.Instance;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Paired_CSM2_And_Markdown_Parity (T : in out Test);
   procedure Test_Response_Children_Selection_And_Reconciliation
     (T : in out Test);
   procedure Test_Malformed_CSM2_Has_No_Stale_Native_Widgets
     (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_CSM2_Qualification_Tests;
