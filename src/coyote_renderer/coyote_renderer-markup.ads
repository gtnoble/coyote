--  Coyote_Renderer.Markup — Markdown → Pango markup conversion.
--
--  Shared by the native Coyote GUI and coyote_sqc.
--
--  Dependencies: Coyote_Cmark, standard Ada. No GTK widget types.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Coyote_Renderer.Markup is

   type Link_Info is record
      Label       : Ada.Strings.Unbounded.Unbounded_String;
      Destination : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Link_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Link_Info);

   --  Character positions count rendered Unicode code points, not bytes.
   type Image_Info is record
      Alt_Text         : Ada.Strings.Unbounded.Unbounded_String;
      Destination      : Ada.Strings.Unbounded.Unbounded_String;
      Title            : Ada.Strings.Unbounded.Unbounded_String;
      Link_Destination : Ada.Strings.Unbounded.Unbounded_String;
      Start_Char       : Natural;
      End_Char         : Natural;
   end record;

   package Image_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Image_Info);

   type Render_Result is record
      Markup : Ada.Strings.Unbounded.Unbounded_String;
      Links  : Link_Vectors.Vector;
      Images : Image_Vectors.Vector;
   end record;
   --  Convert Markdown and retain visible labels and destinations for links.
   function Render (MD_Text : String) return Render_Result;

   --  Convert a Markdown string (GFM extensions: table, strikethrough,
   --  autolink) to a Pango markup string suitable for
   --  Gtk.Text_Buffer.Insert_Markup.  Returns the input XML-escaped if
   --  libcmark-gfm is unavailable or MD_Text is empty.
   function To_Pango_Markup (MD_Text : String) return String;

   --  Escape XML special characters (&, <, >) for embedding in Pango markup.
   function Xml_Escape (S : String) return String;

end Coyote_Renderer.Markup;
