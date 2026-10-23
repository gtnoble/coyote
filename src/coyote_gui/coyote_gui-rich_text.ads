--  Coyote_GUI.Rich_Text — insert rendered rich text in a GTK text view.
--
--  Project: coyote

with Coyote_Renderer.Markup;
with Gtk.Text_View;

package Coyote_GUI.Rich_Text is

   --  Insert markup with link tags and local images. Image alt text remains
   --  in the text buffer for search and copy; image widgets are added before
   --  that caption. Local raster loads are asynchronous and bounded by the
   --  backend. Decode size uses the view width minus a small margin; widget
   --  size is natural and is not rescaled after window resizing. The caller
   --  shares Images_Remaining across all text segments of one response.
   --  Each local anchor consumes one slot, including failed image loads.
   --  Empty source directories and remote image URLs add no widgets.
   procedure Insert
     (View             : not null access
        Gtk.Text_View.Gtk_Text_View_Record'Class;
      Result           : Coyote_Renderer.Markup.Render_Result;
      Source_Directory : String;
      Images_Remaining : in out Natural;
      Clear            : Boolean := False;
      Math_Scale       : Long_Float := 1.0);

   --  Re-render valid inline formulas at the requested scale.
   procedure Reflow
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      Math_Scale : Long_Float);
   --  Copy selected text including source hidden by inline math tags.
   procedure Copy_Selection
     (View : not null access
        Gtk.Text_View.Gtk_Text_View_Record'Class);

end Coyote_GUI.Rich_Text;
