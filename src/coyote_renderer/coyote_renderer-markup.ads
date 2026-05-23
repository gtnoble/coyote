--  Coyote_Renderer.Markup — Markdown → Pango markup conversion.
--
--  Extracted from Coyote_GUI.Buffer so that both the Coyote GUI and
--  coyote_sqc can share the same rendering implementation.
--
--  Dependencies: Coyote_Cmark, standard Ada. No GTK widget types.
--
--  Project: coyote

package Coyote_Renderer.Markup is

   --  Convert a Markdown string (GFM extensions: table, strikethrough,
   --  autolink) to a Pango markup string suitable for
   --  Gtk.Text_Buffer.Insert_Markup.  Returns the input XML-escaped if
   --  libcmark-gfm is unavailable or MD_Text is empty.
   function To_Pango_Markup (MD_Text : String) return String;

   --  Escape XML special characters (&, <, >) for embedding in Pango markup.
   function Xml_Escape (S : String) return String;

end Coyote_Renderer.Markup;
