with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Math_Model;

--  Parse bounded TeX-like input. Input is at most 4 KiB; rejected oversized
--  input retains only the bounded prefix. Error positions are one-based
--  byte offsets. No user macros or recovery-as-success.
package Math_Syntax is
   use Math_Model;

   Max_Source_Bytes  : constant := 4_096;
   Max_Nodes         : constant := 2_048;
   Max_Depth         : constant := 32;
   Max_Array_Rows    : constant := 32;
   Max_Array_Columns : constant := 32;

   type Delimiter_Kind is
     (No_Delimiter, Parenthesis_Delimiter, Bracket_Delimiter, Brace_Delimiter,
      Bar_Delimiter, Double_Bar_Delimiter);

   type Node is record
      Kind            : Node_Kind      := Row_Node;
      Class           : Atom_Class     := Ordinary;
      Font            : Font_Kind      := Main_Regular;
      Code_Point      : Natural        := 0;
      First           : Node_Id        := No_Node;
      Second          : Node_Id        := No_Node;
      Third           : Node_Id        := No_Node;
      Next            : Node_Id        := No_Node;
      Amount          : Long_Float     := 0.0;
      Fraction_Type   : Fraction_Style := Default_Fraction;
      Script_Type     : Script_Layout  := Side_Scripts;
      Array_Type      : Array_Kind     := Matrix_Array;
      Left_Delimiter  : Delimiter_Kind := No_Delimiter;
      Right_Delimiter : Delimiter_Kind := No_Delimiter;
      Position        : Positive       := 1;
   end record;
   --  Row.First starts a Next-linked sequence. Array.First links rows;
   --  each row's First links cell-expression rows. Other child fields retain
   --  their fraction/radical/script meanings. Array metadata is per node.

   type Document is private;
   function Parse (Source : String) return Document;
   function Is_Valid (Item : Document) return Boolean;
   function Source (Item : Document) return String;
   function Error (Item : Document) return String;
   function Error_Position (Item : Document) return Natural;
   function Root (Item : Document) return Node_Id;
   function Count (Item : Document) return Natural;
   function Element (Item : Document; Id : Positive) return Node;

private
   package Node_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Node);
   type Document is record
      Text    : Ada.Strings.Unbounded.Unbounded_String;
      Message : Ada.Strings.Unbounded.Unbounded_String;
      Failure : Natural := 0;
      Root_Id : Node_Id := No_Node;
      Nodes   : Node_Vectors.Vector;
   end record;
end Math_Syntax;
