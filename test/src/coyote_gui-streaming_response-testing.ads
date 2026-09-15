--  Coyote_GUI.Streaming_Response.Testing — test-only response inspection.
--
--  This child keeps qualification queries out of the production response API.
--
--  Project: coyote

with Coyote_GUI.Math_Element;
with Coyote_GUI.Streaming_Response;
with Gtk.Grid;
with Gtk.Text_View;

package Coyote_GUI.Streaming_Response.Testing is

   function Live_Owner_Count return Natural;
   function Is_Open (R : Handle) return Boolean;
   function Is_Finished (R : Handle) return Boolean;
   function Selection_View (R : Handle) return Gtk.Text_View.Gtk_Text_View;
   function Source (R : Handle) return String;
   function Presented_Response_Present (R : Handle) return Boolean;
   function Presented_Text (R : Handle) return String;
   function Presented_Invalid_Event_Count (R : Handle) return Natural;
   function Text_View_Count (R : Handle) return Natural;
   function Text_View_At
     (R : Handle; Index : Positive) return Gtk.Text_View.Gtk_Text_View;
   function Table_Count (R : Handle) return Natural;
   function Table_Grid_At
     (R : Handle; Index : Positive) return Gtk.Grid.Gtk_Grid;
   function Math_Element_Count (R : Handle) return Natural;
   function Math_Element_At
     (R : Handle; Index : Positive)
      return Coyote_GUI.Math_Element.Instance_Access;

end Coyote_GUI.Streaming_Response.Testing;
