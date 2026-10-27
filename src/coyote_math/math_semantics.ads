with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Math_Model;
with Math_Syntax;

--  Immutable semantic view of a parsed math document. Projection retains
--  source, AST identity, positions, and operation payloads for later clients.
package Math_Semantics is
   use Math_Model;

   Max_Semantic_Nodes : constant := 131_072;

   type Child_Role is
     (Root_Role, Sequence_Item, Numerator, Denominator, Radicand,
      Radical_Index, Script_Base, Superscript, Subscript, Array_Row,
      Array_Cell, Delimited_Content, Accent_Base, Overlay_Base,
      Overlay_Mark, Annotation_Base, Annotation_Above, Annotation_Below,
      Boxed_Content, Phantom_Content, Color_Content, Styled_Content,
      Sized_Content, Raised_Content, Enclosed_Content,
      Display_Choice_Text, Text_Choice_Text, Script_Choice_Text,
      Scriptscript_Choice_Text);

   type Semantic_Node is record
      Kind            : Node_Kind := Row_Node;
      Role            : Child_Role := Root_Role;
      AST_Id          : Node_Id := No_Node;
      Parent          : Natural := 0;
      First_Child     : Natural := 0;
      Next_Sibling    : Natural := 0;
      Child_Count     : Natural := 0;
      Position        : Positive := 1;
      Class           : Atom_Class := Ordinary;
      Font            : Font_Kind := Main_Regular;
      Code_Point      : Natural := 0;
      Amount          : Long_Float := 0.0;
      Width           : Long_Float := 0.0;
      Height          : Long_Float := 0.0;
      Depth           : Long_Float := 0.0;
      Scale           : Long_Float := 1.0;
      Enclosure       : Enclosure_Kind := Cancel_Enclosure;
      Fraction_Type   : Fraction_Style := Default_Fraction;
      Fraction_Bar    : Fraction_Bar_Mode := Default_Rule;
      Fraction_Alignment_Mode : Fraction_Alignment := Center_Fraction;
      Fraction_Rule_Thickness : Long_Float := -1.0;
      Fraction_Continued : Boolean := False;
      Fraction_Style_Mode : Math_Style_Kind := Natural_Style;
      Script_Type     : Script_Layout := Side_Scripts;
      Array_Type      : Array_Kind := Matrix_Array;
      Column_Spec     : Ada.Strings.Unbounded.Unbounded_String;
      Row_Spacing     : Long_Float := 0.0;
      Math_Style      : Math_Style_Kind := Natural_Style;
      Annotation_Type : Annotation_Kind := Over_Annotation;
      Color           : Color_Value := (others => <>);
      --  Mirrors Math_Syntax.Stretchy_Name and its Code_Point mode.
      Stretchy_Name   : Ada.Strings.Unbounded.Unbounded_String;
      Left_Delimiter  : Math_Syntax.Delimiter_Kind :=
        Math_Syntax.No_Delimiter;
      Right_Delimiter : Math_Syntax.Delimiter_Kind :=
        Math_Syntax.No_Delimiter;
   end record;

   type Document is private;

   function Project (Source : String) return Document;
   function Project (AST : Math_Syntax.Document) return Document;
   function Is_Valid (Item : Document) return Boolean;
   function Source (Item : Document) return String;
   function Error (Item : Document) return String;
   function Count (Item : Document) return Natural;
   function Root (Item : Document) return Natural;
   function Element
     (Item : Document; Index : Positive) return Semantic_Node;
   function Accent_Command (Item : Document; Index : Positive) return String;

private
   package Node_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Semantic_Node);
   type Document is record
      Text       : Ada.Strings.Unbounded.Unbounded_String;
      Message    : Ada.Strings.Unbounded.Unbounded_String;
      Root_Index : Natural := 0;
      Nodes      : Node_Vectors.Vector;
   end record;
end Math_Semantics;
