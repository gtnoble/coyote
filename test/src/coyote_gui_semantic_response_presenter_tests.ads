--  Coyote_GUI_Semantic_Response_Presenter_Tests — persistent presenter tests.
--
--  Display-gated tests prove snapshot reconciliation and widget identity.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Gtk.Box;
with Gtk.Window;

package Coyote_GUI_Semantic_Response_Presenter_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
      Parent            : Gtk.Window.Gtk_Window;
      Host              : Gtk.Box.Gtk_Box;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Text_Identity_Persists (T : in out Test);
   procedure Test_Native_Commit_Preserves_Neighbors (T : in out Test);
   procedure Test_Localized_Invalid_Preserves_Roots (T : in out Test);
   procedure Test_Semantic_Styles_And_Order (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Semantic_Response_Presenter_Tests;
