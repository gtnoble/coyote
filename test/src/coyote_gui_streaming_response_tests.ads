--  Coyote_GUI_Streaming_Response_Tests — response-owner qualification.
--
--  Tests require a display and skip when GTK cannot be initialised.
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Coyote_GUI.Streaming_Response;
with Gtk.Box;
with Gtk.Window;

package Coyote_GUI_Streaming_Response_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Display_Available : Boolean := False;
      Parent            : Gtk.Window.Gtk_Window;
      Host              : Gtk.Box.Gtk_Box;
      Response          : Coyote_GUI.Streaming_Response.Handle;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   procedure Test_Empty_Lifecycle_Operations_Are_No_Ops (T : in out Test);
   procedure Test_Begin_Append_Finish_Is_Idempotent (T : in out Test);
   procedure Test_Empty_Finish_Closes_Owner (T : in out Test);
   procedure Test_Begin_After_Finish_Reuses_Owner (T : in out Test);
   procedure Test_Discard_Releases_Transaction (T : in out Test);
   procedure Test_Clear_While_Focused_Is_Safe (T : in out Test);
   procedure Test_Font_Applies_Before_During_And_After (T : in out Test);
   procedure Test_Malformed_Source_Remains_Visible (T : in out Test);
   procedure Test_Split_Table_Promotes_Only_At_Close (T : in out Test);
   procedure Test_Split_Math_Promotes_Only_At_Close (T : in out Test);
   procedure Test_Native_Payload_Identity_Survives_Later_Mutation
     (T : in out Test);
   procedure Test_Handle_Copy_And_Assignment (T : in out Test);
   procedure Test_Handle_Vector_Delete_And_Clear (T : in out Test);
   procedure Test_Handle_Reset_Is_Idempotent (T : in out Test);
   procedure Test_Handle_Finalizes_During_Exception_Unwinding
     (T : in out Test);
   procedure Test_Chunking_Preserves_Root_And_Widget_Identity
     (T : in out Test);
   procedure Test_Long_Stream_Widget_Scaling
     (T : in out Test);
   procedure Test_Repeated_Response_Reset_Has_No_Stale_Roots
     (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Coyote_GUI_Streaming_Response_Tests;
