--  Coyote_GUI.Markdown_Links — clickable links in GTK text views.
--
--  Project: coyote

with Coyote_Renderer.Markup;
with Gtk.Text_Buffer;
with Gtk.Text_View;

package Coyote_GUI.Markdown_Links is

   --  Insert rendered markup, tag link text ranges, and enable click opening.
   procedure Insert
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      View   : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      Result : Coyote_Renderer.Markup.Render_Result;
      Clear  : Boolean := False;
      Connect_Events : Boolean := True);

   --  Resolve whether a link destination is safe for xdg-open.
   function Is_Safe_Destination (Destination : String) return Boolean;

end Coyote_GUI.Markdown_Links;
