--  Coyote_Renderer.Math — Markdown-aware LaTeX math extraction.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Coyote_Renderer.Math is

   type Display_Math_Block is record
      Source      : Ada.Strings.Unbounded.Unbounded_String;
      LaTeX       : Ada.Strings.Unbounded.Unbounded_String;
      Placeholder : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Display_Math_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Display_Math_Block);

   type Extraction_Result is record
      Masked_Text : Ada.Strings.Unbounded.Unbounded_String;
      Blocks      : Display_Math_Vectors.Vector;
   end record;

   --  Extract complete $$...$$ and \[...\] blocks outside Markdown code.
   --  Unmatched delimiters remain unchanged in Masked_Text.
   function Extract_Display_Math (Markdown : String) return Extraction_Result;

end Coyote_Renderer.Math;
