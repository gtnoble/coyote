with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Math_Model;
with Math_Macros;

--  Parse bounded TeX-like input. Error positions are one-based UTF-8 byte
--  offsets. Raw Unicode is accepted only for registered math symbols.
package Math_Syntax is
   use Math_Model;

   Max_Source_Bytes  : constant := 65_536;
   Max_Nodes         : constant := 32_768;
   Max_Depth         : constant := 128;
   Max_Array_Rows    : constant := 64;
   Max_Array_Columns : constant := 64;

   type Strict_Policy is (Strict_Warn, Strict_Ignore, Strict_Error);
   subtype Expansion_Limit is Positive range 1 .. 10_000;
   subtype Size_Limit is Positive range 1 .. 100;
   type Options is record
      Strict : Strict_Policy := Strict_Warn;
      Max_Expand : Expansion_Limit := 1_000;
      Max_Size : Size_Limit := 100;
      Display_Mode : Boolean := False;
      Left_Tags : Boolean := False;
      Color_Is_Text_Color : Boolean := False;
   end record;

   type Diagnostic_Kind is (Warning, Refusal, Parse_Error);
   type Diagnostic is record
      Kind : Diagnostic_Kind := Parse_Error;
      Message : Ada.Strings.Unbounded.Unbounded_String;
      Position : Natural := 0;
   end record;

   type Delimiter_Kind is
     (No_Delimiter, Parenthesis_Delimiter, Bracket_Delimiter, Brace_Delimiter,
      Bar_Delimiter, Double_Bar_Delimiter);

   type Node is record
      Kind            : Node_Kind      := Row_Node;
      Class           : Atom_Class     := Ordinary;
      Font            : Font_Kind      := Main_Regular;
      Code_Point      : Natural        := 0;
      First           : Node_Id       := No_Node;
      Second          : Node_Id       := No_Node;
      Third           : Node_Id       := No_Node;
      Fourth          : Node_Id       := No_Node;
      Next            : Node_Id       := No_Node;
      Amount          : Long_Float    := 0.0;
      Width           : Long_Float    := 0.0;
      Height          : Long_Float    := 0.0;
      Depth           : Long_Float    := 0.0;
      Scale           : Long_Float    := 1.0;
      Enclosure       : Enclosure_Kind := Cancel_Enclosure;
      Fraction_Type   : Fraction_Style := Default_Fraction;
      Fraction_Bar    : Fraction_Bar_Mode := Default_Rule;
      Fraction_Alignment_Mode : Fraction_Alignment := Center_Fraction;
      Fraction_Rule_Thickness : Long_Float := -1.0;
      Fraction_Continued : Boolean := False;
      Fraction_Style_Mode : Math_Style_Kind := Natural_Style;
      Script_Type     : Script_Layout := Side_Scripts;
      Array_Type      : Array_Kind    := Matrix_Array;
      Column_Spec     : Ada.Strings.Unbounded.Unbounded_String;
      Row_Spacing     : Long_Float := 0.0;
      Math_Style      : Math_Style_Kind := Natural_Style;
      Annotation_Type : Annotation_Kind := Over_Annotation;
      Dual_Type       : Dual_Projection := Visual_First;
      Overlap_Mode    : Overlap_Alignment := Right_Overlap;
      Color           : Color_Value := (others => <>);
      Tag_Text        : Ada.Strings.Unbounded.Unbounded_String;
      --  Stretchy_Node: First is content/above label, Second is below label;
      --  Code_Point is 0 for accent content and 1 for labelled arrows.
      --  Stretchy_Name is an allowlisted Math_Stretchy table key.
      Stretchy_Name   : Ada.Strings.Unbounded.Unbounded_String;
      Tag_Is_Left     : Boolean := False;
      Left_Delimiter  : Delimiter_Kind := No_Delimiter;
      Right_Delimiter : Delimiter_Kind := No_Delimiter;
      Position        : Positive      := 1;
   end record;
   --  Row.First starts a Next-linked sequence. Array.First links rows;
   --  each row's First links cell-expression rows. Other child fields retain
   --  their fraction/radical/script meanings. Dual nodes keep both branches.
   --  MathChoice nodes use First, Second, Third, Fourth for display, text,
   --  script, and scriptscript branches, respectively.
   --  A Delimited_Node with First = No_Node and Amount > 0 represents one
   --  explicitly sized delimiter. Amount is the target height in em;
   --  Left_Delimiter stores its shape. Code_Point is the sizing-command role:
   --  1 plain, 2 left, 3 right, 4 middle. Class is the delimiter's atom role.

   type Document is private;
   function Parse (Source : String) return Document;
   function Parse (Source : String; Settings : Options) return Document;
   function Parse
     (Source : String; Shared : not null access Math_Macros.Context;
      Global_Group : Boolean := False) return Document;
   function Parse
     (Source : String; Shared : not null access Math_Macros.Context;
      Settings : Options; Global_Group : Boolean := False) return Document;
   --  Explicit shared state follows local/global namespace semantics, even
   --  when parsing fails. Ordinary parsing starts a fresh context.
   function Is_Valid (Item : Document) return Boolean;
   function Source (Item : Document) return String;
   function Error (Item : Document) return String;
   function Error_Position (Item : Document) return Natural;
   function Root (Item : Document) return Node_Id;
   function Count (Item : Document) return Natural;
   function Element (Item : Document; Id : Positive) return Node;
   function Diagnostic_Count (Item : Document) return Natural;
   function Diagnostic_At
     (Item : Document; Index : Positive) return Diagnostic;

private
   package Node_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Node);
   package Diagnostic_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Diagnostic);
   type Document is record
      Text    : Ada.Strings.Unbounded.Unbounded_String;
      Message : Ada.Strings.Unbounded.Unbounded_String;
      Failure : Natural := 0;
      Root_Id : Node_Id := No_Node;
      Nodes   : Node_Vectors.Vector;
      Diagnostics : Diagnostic_Vectors.Vector;
   end record;
end Math_Syntax;
