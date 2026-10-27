with Gtk.Tree_View;
with Math_Semantics;

--  GTK tree view exposing projected math semantics as navigable text.
package Coyote_GUI.Math_Accessibility is
   function Create
     (Meaning : Math_Semantics.Document)
      return Gtk.Tree_View.Gtk_Tree_View;
end Coyote_GUI.Math_Accessibility;
