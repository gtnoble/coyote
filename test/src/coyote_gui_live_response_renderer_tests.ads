--  Coyote_GUI_Live_Response_Renderer_Tests — Phase 2 live GTK renderer tests.
--
--  Widget assertions are display-gated; parser events are delivered directly
--  to the standalone live renderer and never pass through Conversation_Stack.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Coyote_GUI.Live_Response_Renderer;
with Gtk.Box;
with Gtk.Window;

package Coyote_GUI_Live_Response_Renderer_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
      Parent            : Gtk.Window.Gtk_Window;
      Host              : Gtk.Box.Gtk_Box;
      Renderer          : Coyote_GUI.Live_Response_Renderer.Instance;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Live_Text_Styles_And_Order (T : in out Test);
   procedure Test_Live_Code_Quote_And_Lists (T : in out Test);
   procedure Test_Deferred_Blocks_And_Clear (T : in out Test);
   procedure Test_Invalid_Rolls_Back_Optimistic_Content (T : in out Test);
   procedure Test_Invalid_Preserves_Deferred_Roots (T : in out Test);
   procedure Test_Detach_And_Reattach (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Live_Response_Renderer_Tests;
