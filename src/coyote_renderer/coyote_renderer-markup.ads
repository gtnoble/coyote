--  Coyote_Renderer.Markup — Markdown semantic adapter and Pango serializer.
--
--  Shared by the native Coyote GUI and coyote_sqc.
--
--  Project: coyote

with Coyote_Renderer.Semantics;

package Coyote_Renderer.Markup is

   --  Parse GFM Markdown into the renderer-neutral semantic document.  The
   --  cmark tree is private to this call and is never retained by Target.
   --  When Include_Display_Math is true, the existing standalone $$ extractor
   --  contributes Display_Math blocks; code blocks remain protected.
   function Parse_Markdown
     (Markdown             : String;
      Target               : in out Coyote_Renderer.Semantics.Document;
      Include_Display_Math : Boolean := True) return Boolean;

   --  Convert a Markdown string (GFM extensions: table, strikethrough,
   --  autolink) to a Pango markup string suitable for
   --  Gtk.Text_Buffer.Insert_Markup.  The result is produced from the shared
   --  semantic document.  Returns the input XML-escaped if parsing fails.
   function To_Pango_Markup (MD_Text : String) return String;

   --  Escape XML special characters (&, <, >) for embedding in Pango markup.
   function Xml_Escape (S : String) return String;

end Coyote_Renderer.Markup;
