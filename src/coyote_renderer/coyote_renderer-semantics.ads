--  Coyote_Renderer.Semantics — renderer-neutral document semantics.
--
--  The package stores ordered block and inline content without dependencies on
--  Markdown, CSM, GTK, cmark, Lasem, or persistence formats.
--
--  Blocks and inline nodes are allocated by a Document and identified by
--  private handles.  A handle is valid only with the Document that created it;
--  Clear invalidates all existing handles.  New nodes are first constructed
--  with New_Block, New_Inline, New_Table_Row, or New_Table_Cell and then
--  attached with the corresponding Append operation.  The Document owns all
--  nodes and Ada containers reclaim their storage when the Document goes out
--  of scope.
--
--  Source fields preserve source/provenance separately from decoded values.
--  Values are intentionally opaque strings; interpretation and rendering are
--  responsibilities of later packages.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Coyote_Renderer.Semantics is

   type Document is tagged limited private;
   type Block_Id is private;
   type Inline_Id is private;
   type Table_Row_Id is private;
   type Table_Cell_Id is private;

   type Block_Kind is
     (Paragraph,
      Heading,
      Blockquote,
      List,
      List_Item,
      Code_Block,
      Table,
      Display_Math,
      Horizontal_Rule,
      Invalid_Source);

   type Inline_Kind is
     (Text,
      Strong,
      Emphasis,
      Deletion,
      Link,
      Inline_Code,
      Raw_Markup,
      Soft_Line_Break,
      Hard_Line_Break);

   type List_Kind is
     (Unordered_List,
      Ordered_List);

   type Table_Alignment is
     (Unspecified,
      Left,
      Center,
      Right);

   subtype Heading_Level is Positive range 1 .. 6;

   No_Block     : constant Block_Id;
   No_Inline    : constant Inline_Id;
   No_Table_Row : constant Table_Row_Id;
   No_Table_Cell : constant Table_Cell_Id;

   function Is_Valid (D : Document; Id : Block_Id) return Boolean;
   function Is_Valid (D : Document; Id : Inline_Id) return Boolean;
   function Is_Valid (D : Document; Id : Table_Row_Id) return Boolean;
   function Is_Valid (D : Document; Id : Table_Cell_Id) return Boolean;

   procedure Clear (D : in out Document);

   function New_Block
     (D      : in out Document;
      Kind   : Block_Kind;
      Source : String := "") return Block_Id;

   function New_Inline
     (D      : in out Document;
      Kind   : Inline_Kind;
      Value  : String := "";
      Source : String := "") return Inline_Id;

   function Set_Block_Source
     (D : in out Document; Block : Block_Id; Source : String)
     return Boolean;

   function Set_Block_Kind
     (D : in out Document; Block : Block_Id; Kind : Block_Kind)
     return Boolean;

   --  Replace a block with one atomic invalid-source node.  Attached
   --  children, inlines, rows, and presentation data are discarded.
   function Set_Block_Invalid_Source
     (D : in out Document; Block : Block_Id; Source : String)
     return Boolean;

   --  Stable identity for a parser root.  This value is preserved by Copy
   --  and is independent of document-local semantic handles.
   function Set_Block_Semantic_Root_Id
     (D : in out Document; Block : Block_Id; Root_Id : Natural)
     return Boolean;

   function Block_Semantic_Root_Id
     (D : Document; Block : Block_Id) return Natural;

   function Set_Inline_Source
     (D : in out Document; Inline : Inline_Id; Source : String)
     return Boolean;

   function Set_Inline_Value
     (D : in out Document; Inline : Inline_Id; Value : String)
     return Boolean;

   function Set_Table_Cell_Source
     (D : in out Document; Cell : Table_Cell_Id; Source : String)
     return Boolean;

   procedure Copy
     (Source : Document; Target : in out Document);

   function Append_Block
     (D : in out Document; Child : Block_Id) return Boolean;

   function Append_Block
     (D      : in out Document;
      Parent : Block_Id;
      Child  : Block_Id) return Boolean;

   function Append_Inline
     (D      : in out Document;
      Parent : Block_Id;
      Child  : Inline_Id) return Boolean;

   function Append_Inline
     (D      : in out Document;
      Parent : Inline_Id;
      Child  : Inline_Id) return Boolean;

   function Append_Inline
     (D      : in out Document;
      Parent : Table_Cell_Id;
      Child  : Inline_Id) return Boolean;

   --  Append decoded plain text to a parent, coalescing only with its
   --  immediately preceding Text inline.  Source and value remain exact.
   function Append_Text
     (D      : in out Document;
      Parent : Block_Id;
      Value  : String;
      Source : String) return Boolean;

   function Append_Text
     (D      : in out Document;
      Parent : Inline_Id;
      Value  : String;
      Source : String) return Boolean;

   function Append_Text
     (D      : in out Document;
      Parent : Table_Cell_Id;
      Value  : String;
      Source : String) return Boolean;

   function Set_Heading_Level
     (D     : in out Document;
      Block : Block_Id;
      Level : Heading_Level) return Boolean;

   function Set_List_Attributes
     (D       : in out Document;
      Block   : Block_Id;
      Kind    : List_Kind;
      Start   : Positive := 1) return Boolean;

   function Set_Code_Block_Data
     (D        : in out Document;
      Block    : Block_Id;
      Literal  : String;
      Language : String := "") return Boolean;

   function Set_Display_Math_Data
     (D      : in out Document;
      Block  : Block_Id;
      MathML : String) return Boolean;

   function Set_Link_URL
     (D     : in out Document;
      Link  : Inline_Id;
      URL   : String) return Boolean;

   function New_Table_Row
     (D        : in out Document;
      Table    : Block_Id;
      Is_Header : Boolean := False) return Table_Row_Id;

   function New_Table_Cell
     (D      : in out Document;
      Row    : Table_Row_Id;
      Value  : String := "";
      Source : String := "") return Table_Cell_Id;

   function Set_Table_Cell_Value
     (D     : in out Document;
      Cell  : Table_Cell_Id;
      Value : String) return Boolean;

   function Set_Table_Alignment
     (D         : in out Document;
      Table     : Block_Id;
      Column    : Positive;
      Alignment : Table_Alignment) return Boolean;

   function Block_Count (D : Document) return Natural;
   function Block_At (D : Document; Position : Positive) return Block_Id;
   function Block_Kind_Of (D : Document; Block : Block_Id) return Block_Kind;
   function Block_Source
     (D : Document; Block : Block_Id) return String;
   function Block_Child_Count (D : Document; Block : Block_Id) return Natural;
   function Block_Child_At
     (D : Document; Block : Block_Id; Position : Positive) return Block_Id;
   function Block_Inline_Count (D : Document; Block : Block_Id) return Natural;
   function Block_Inline_At
     (D : Document; Block : Block_Id; Position : Positive) return Inline_Id;
   function Heading_Level_Of (D : Document; Block : Block_Id) return Natural;
   function List_Kind_Of (D : Document; Block : Block_Id) return List_Kind;
   function List_Start (D : Document; Block : Block_Id) return Positive;
   function Code_Literal (D : Document; Block : Block_Id) return String;
   function Code_Language (D : Document; Block : Block_Id) return String;
   function MathML_Source (D : Document; Block : Block_Id) return String;
   function MathML_Value (D : Document; Block : Block_Id) return String;
   function Table_Alignment_At
     (D : Document; Block : Block_Id; Column : Positive)
      return Table_Alignment;
   function Table_Column_Count
     (D : Document; Block : Block_Id) return Natural;
   function Table_Row_Count (D : Document; Table : Block_Id) return Natural;
   function Table_Row_At
     (D : Document; Table : Block_Id; Position : Positive) return Table_Row_Id;
   function Table_Row_Is_Header (D : Document; Row : Table_Row_Id) return Boolean;
   function Set_Table_Row_Source
     (D : in out Document; Row : Table_Row_Id; Source : String)
     return Boolean;
   function Table_Row_Source (D : Document; Row : Table_Row_Id) return String;
   function Table_Cell_Count (D : Document; Row : Table_Row_Id) return Natural;
   function Table_Cell_At
     (D : Document; Row : Table_Row_Id; Position : Positive)
      return Table_Cell_Id;
   function Table_Cell_Source
     (D : Document; Cell : Table_Cell_Id) return String;
   function Table_Cell_Value
     (D : Document; Cell : Table_Cell_Id) return String;
   function Table_Cell_Inline_Count
     (D : Document; Cell : Table_Cell_Id) return Natural;
   function Table_Cell_Inline_At
     (D : Document; Cell : Table_Cell_Id; Position : Positive)
      return Inline_Id;

   function Inline_Kind_Of (D : Document; Inline : Inline_Id) return Inline_Kind;
   function Inline_Source (D : Document; Inline : Inline_Id) return String;
   function Inline_Value (D : Document; Inline : Inline_Id) return String;
   function Inline_URL (D : Document; Link : Inline_Id) return String;
   function Inline_Child_Count (D : Document; Inline : Inline_Id) return Natural;
   function Inline_Child_At
     (D : Document; Inline : Inline_Id; Position : Positive) return Inline_Id;

private

   type Block_Id is record
      Index             : Natural := 0;
      Generation        : Natural := 0;
      Document_Identity : Natural := 0;
   end record;

   type Inline_Id is record
      Index             : Natural := 0;
      Generation        : Natural := 0;
      Document_Identity : Natural := 0;
   end record;

   type Table_Row_Id is record
      Index             : Natural := 0;
      Generation        : Natural := 0;
      Document_Identity : Natural := 0;
   end record;

   type Table_Cell_Id is record
      Index             : Natural := 0;
      Generation        : Natural := 0;
      Document_Identity : Natural := 0;
   end record;

   package Block_Id_Vectors is new Ada.Containers.Vectors
     (Positive, Block_Id);
   package Inline_Id_Vectors is new Ada.Containers.Vectors
     (Positive, Inline_Id);
   package Table_Row_Id_Vectors is new Ada.Containers.Vectors
     (Positive, Table_Row_Id);
   package Table_Cell_Id_Vectors is new Ada.Containers.Vectors
     (Positive, Table_Cell_Id);
   package Alignment_Vectors is new Ada.Containers.Vectors
     (Positive, Table_Alignment);

   type Block_Record is record
      Kind             : Block_Kind;
      Source           : Ada.Strings.Unbounded.Unbounded_String;
      Semantic_Root_Id : Natural := 0;
      Heading_Level    : Natural := 0;
      List_Kind     : Coyote_Renderer.Semantics.List_Kind := Unordered_List;
      List_Start    : Positive := 1;
      Code_Literal  : Ada.Strings.Unbounded.Unbounded_String;
      Code_Language : Ada.Strings.Unbounded.Unbounded_String;
      MathML        : Ada.Strings.Unbounded.Unbounded_String;
      Children      : Block_Id_Vectors.Vector;
      Inlines       : Inline_Id_Vectors.Vector;
      Rows          : Table_Row_Id_Vectors.Vector;
      Alignments    : Alignment_Vectors.Vector;
      Column_Count  : Natural := 0;
   end record;

   package Block_Vectors is new Ada.Containers.Vectors
     (Positive, Block_Record);

   type Inline_Record is record
      Kind     : Inline_Kind;
      Value    : Ada.Strings.Unbounded.Unbounded_String;
      Source   : Ada.Strings.Unbounded.Unbounded_String;
      URL      : Ada.Strings.Unbounded.Unbounded_String;
      Children : Inline_Id_Vectors.Vector;
   end record;

   package Inline_Vectors is new Ada.Containers.Vectors
     (Positive, Inline_Record);

   type Table_Row_Record is record
      Table     : Block_Id;
      Is_Header : Boolean := False;
      Source    : Ada.Strings.Unbounded.Unbounded_String;
      Cells     : Table_Cell_Id_Vectors.Vector;
   end record;
   package Table_Row_Vectors is new Ada.Containers.Vectors
     (Positive, Table_Row_Record);

   type Table_Cell_Record is record
      Value    : Ada.Strings.Unbounded.Unbounded_String;
      Source   : Ada.Strings.Unbounded.Unbounded_String;
      Inlines  : Inline_Id_Vectors.Vector;
   end record;

   package Table_Cell_Vectors is new Ada.Containers.Vectors
     (Positive, Table_Cell_Record);

   type Document is tagged limited record
      Identity    : Natural := 0;
      Generation  : Natural := 1;
      Blocks      : Block_Vectors.Vector;
      Root_Blocks : Block_Id_Vectors.Vector;
      Inlines     : Inline_Vectors.Vector;
      Rows        : Table_Row_Vectors.Vector;
      Cells       : Table_Cell_Vectors.Vector;
   end record;

   No_Block      : constant Block_Id :=
     (Index => 0, Generation => 0, Document_Identity => 0);
   No_Inline     : constant Inline_Id :=
     (Index => 0, Generation => 0, Document_Identity => 0);
   No_Table_Row  : constant Table_Row_Id :=
     (Index => 0, Generation => 0, Document_Identity => 0);
   No_Table_Cell : constant Table_Cell_Id :=
     (Index => 0, Generation => 0, Document_Identity => 0);

end Coyote_Renderer.Semantics;
