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

   --  Character positions count rendered Unicode code points; End_Char is
   --  exclusive. Source remains visible in Markup for non-GUI consumers.
   type Math_Span is record
      Source     : Ada.Strings.Unbounded.Unbounded_String;
      LaTeX      : Ada.Strings.Unbounded.Unbounded_String;
      Start_Char : Natural;
      End_Char   : Natural;
   end record;

   package Math_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Math_Span);

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
      Maths  : Math_Vectors.Vector;
   end record;

   --  Convert Markdown and retain visible labels and destinations for links,
   --  plus source-positioned inline LaTeX spans.
   function Render (MD_Text : String) return Render_Result;

   --  Convert Markdown (GFM tables, strikethrough and autolinks) to Pango.
   function To_Pango_Markup (MD_Text : String) return String;

   --  Escape XML special characters for embedding in Pango markup.
   function Xml_Escape (S : String) return String;

end Coyote_Renderer.Markup;
