--  Coyote_GUI.Model_Picker — reusable GTK model selection dialog.
--
--  The picker is modal and must be called on the GTK main-loop thread.  It
--  returns the user's choice without changing agent state or persisting data.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with Gtk.Window;
with LLM.Model_Registry;
with LLM.Settings;

package Coyote_GUI.Model_Picker is

   type Selection_Status is
     (Cancelled,
      Selected,
      Use_Default);

   type Selection_Result (Status : Selection_Status := Cancelled) is record
      case Status is
         when Selected =>
            Model_Spec : Ada.Strings.Unbounded.Unbounded_String;
         when Cancelled
            | Use_Default =>
            null;
      end case;
   end record;

   --  Show the common searchable model picker and return its choice.  When
   --  Allow_Default is true, the picker includes an explicit fallback row.
   --  Initial_Spec selects a matching provider/model row when available.
   function Choose
     (Parent        : not null access Gtk.Window.Gtk_Window_Record'Class;
      Models        : LLM.Model_Registry.Model_Info_Vectors.Vector;
      Price_Display : LLM.Settings.Price_Display_Mode;
      Initial_Spec  : String  := "";
      Allow_Default : Boolean := False)
      return Selection_Result;

end Coyote_GUI.Model_Picker;
