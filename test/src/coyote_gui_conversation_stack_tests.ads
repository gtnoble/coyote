--  Coyote_GUI_Conversation_Stack_Tests — native GTK stack tests.
--
--  Widget tests require a display and skip when GTK cannot be initialised.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with Coyote_GUI.Conversation_Stack;
with Gtk.Window;

package Coyote_GUI_Conversation_Stack_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
      Parent            : Gtk.Window.Gtk_Window;
      Stack             : Coyote_GUI.Conversation_Stack.Instance;
   end record;

   procedure Test_Native_Footer_Uses_Status_Row_And_Fork_Button
     (T : in out Test);

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Creates_Single_Outer_Host (T : in out Test);
   procedure Test_Request_And_Streaming_Are_Incremental (T : in out Test);
   procedure Test_Native_Markdown_Renders_After_Streaming (T : in out Test);
   procedure Test_Native_Markdown_Toggle_Disables_Rendering (T : in out Test);
   procedure Test_Assistant_Content_Uses_Visible_Step_Frame
     (T : in out Test);
   procedure Test_Footer_Closes_Step_Before_Next_Step
     (T : in out Test);
   procedure Test_New_Request_Resets_Step_Frames
     (T : in out Test);
   procedure Test_Tool_Updates_By_Stable_Id (T : in out Test);
   procedure Test_Tool_Card_Uses_Native_Labels (T : in out Test);
   procedure Test_Footer_Kind_And_Completion_Are_Explicit (T : in out Test);
   procedure Test_Clear_Removes_Exchange_State (T : in out Test);

end Coyote_GUI_Conversation_Stack_Tests;
