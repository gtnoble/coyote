--  Coyote_GUI.Markdown_Links — clickable links in GTK text views.
--
--  Project: coyote

with Coyote_Renderer.Markup;
with Gtk.Text_Buffer;
with Gtk.Text_View;

package Coyote_GUI.Markdown_Links is

   --  Connect activation, hand-cursor hover, and plain destination tooltips.
   --  Call on the GTK main task for each text view that may contain link tags.
   procedure Connect
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class);

   --  Insert rendered markup and tag each link's visible text range.
   procedure Insert
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Result : Coyote_Renderer.Markup.Render_Result;
      Clear  : Boolean := False);

   --  Resolve whether a link destination is safe for xdg-open.
   function Is_Safe_Destination (Destination : String) return Boolean;

end Coyote_GUI.Markdown_Links;
