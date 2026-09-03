--  Coyote_Renderer.Tables — structured GFM table extraction.
--
--  The package copies table content out of libcmark-gfm while the parse tree
--  is alive, then returns an ordered masked source for native realization.
--  No GTK types or cmark pointers cross this interface.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Coyote_Renderer.Tables is

   type Table_Alignment is (Unspecified, Left, Center, Right);

   package Table_Alignment_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Table_Alignment);

   type Table_Cell is record
      Text : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Table_Cell_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Table_Cell);

   type Table_Row is record
      Is_Header : Boolean := False;
      Cells     : Table_Cell_Vectors.Vector;
   end record;

   package Table_Row_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Table_Row);

   type Table_Block is record
      Start_Line  : Positive := 1;
      End_Line    : Positive := 1;
      Column_Count : Natural := 0;
      Alignments  : Table_Alignment_Vectors.Vector;
      Rows        : Table_Row_Vectors.Vector;
      Placeholder : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Table_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Table_Block);

   type Extraction_Result is record
      Masked_Text : Ada.Strings.Unbounded.Unbounded_String;
      Blocks      : Table_Vectors.Vector;
   end record;

   --  Parse GFM tables, copy their values and metadata, and replace each
   --  table's source lines with an ordered placeholder.
   function Extract_Tables (Markdown : String) return Extraction_Result;

end Coyote_Renderer.Tables;
