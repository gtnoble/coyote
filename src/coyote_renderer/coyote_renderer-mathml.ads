--  Coyote_Renderer.MathML — Markdown-aware display-math extraction.
--
--  Identifies standalone $$ blocks without interpreting text inside Markdown
--  code blocks.  The original source is retained separately from the inner
--  Presentation MathML passed to Lasem.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Coyote_Renderer.MathML is

   type Display_Math_Block is record
      Source : Ada.Strings.Unbounded.Unbounded_String;
      MathML : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Display_Math_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Display_Math_Block);

   type Extraction_Result is record
      Masked_Text : Ada.Strings.Unbounded.Unbounded_String;
      Blocks      : Display_Math_Vectors.Vector;
   end record;

   --  Parse Markdown with cmark-gfm, protect all code-block source ranges,
   --  and replace eligible display-math blocks with stable placeholders.
   function Extract_Display_Math
     (Markdown : String) return Extraction_Result;

end Coyote_Renderer.MathML;
