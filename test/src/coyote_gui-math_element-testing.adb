--  Coyote_GUI.Math_Element.Testing body.
--
--  Project: coyote

with Gtk.Style_Context;

package body Coyote_GUI.Math_Element.Testing is

   function Area_Visible
     (Element : Coyote_GUI.Math_Element.Instance) return Boolean
   is
   begin
      return Element.Area.Get_Visible;
   end Area_Visible;

   function Fallback_Visible
     (Element : Coyote_GUI.Math_Element.Instance) return Boolean
   is
   begin
      return Element.Fallback.Get_Visible;
   end Fallback_Visible;

   function Has_Response_Style
     (Element : Coyote_GUI.Math_Element.Instance) return Boolean
   is
   begin
      return Gtk.Style_Context.Get_Style_Context (Element.Area).Has_Class
        ("coyote-response-content");
   end Has_Response_Style;

end Coyote_GUI.Math_Element.Testing;
