with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Math_Model;
with Math_Semantics;
with Math_Syntax;
with Math_Macros;

procedure Math_Semantics_Probe is
   use Math_Model;
   use Math_Semantics;
   use type Math_Syntax.Delimiter_Kind;
   Checks : Natural := 0;
   Failures : Natural := 0;
   Item : Document;
   Shared : aliased Math_Macros.Context;
   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;
   function Child (Parent : Positive; Role : Child_Role) return Natural is
      Index : Natural := Element (Item, Parent).First_Child;
   begin
      while Index /= 0 loop
         if Element (Item, Positive (Index)).Role = Role then
            return Index;
         end if;
         Index := Element (Item, Positive (Index)).Next_Sibling;
      end loop;
      return 0;
   end Child;
   procedure Check_Common (Source_Text : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        (Source_Text);
   begin
      Item := Project (Source_Text);
      Check (Is_Valid (Item), "valid parse projects: " & Source_Text);
      Check (Source (Item) = Source_Text, "exact source retained");
      Check (Root (Item) = 1, "root index is one");
      Check (Count (Item) >= Math_Syntax.Count (Parsed),
        "semantic nodes cover AST");
      Check (Count (Item) <= 2 * Math_Syntax.Count (Parsed),
        "semantic expansion bounded");
      Check (Element (Item, 1).Role = Root_Role, "root role");
      Check (Element (Item, 1).Parent = 0, "root parent");
   end Check_Common;
   procedure Run is
      A, B, C, D : Natural;
      Current : Natural;
      N : Semantic_Node;
      Invalid : constant Document := Project ("\unknown");
   begin
      Check_Common ("\frac{a}{b}");
      A := Child (1, Sequence_Item);
      Check (A /= 0 and then Element (Item, A).Kind = Fraction_Node,
        "fraction represented as operation");
      B := Child (A, Numerator);
      C := Child (A, Denominator);
      Check (B /= 0 and then C /= 0, "fraction operand roles");
      Check (Element (Item, B).Position = 7 and
        Element (Item, C).Position = 10, "fraction operand source bytes");
      Check (Element (Item, A).Fraction_Type = Default_Fraction,
        "fraction style payload");
      Check (Element (Item, Element (Item, B).First_Child).Code_Point = 97
        and Element (Item, Element (Item, C).First_Child).Code_Point = 98,
        "fraction operand expression data");
      Check (Element (Item, Element (Item, B).First_Child).Font =
        Math_Italic and Element (Item,
        Element (Item, B).First_Child).Class = Ordinary,
        "glyph font and atom class retained");
      Check (Element (Item, Element (Item, C).First_Child).AST_Id > 0,
        "source AST identity retained");

      Check_Common ("x_i^2");
      A := Child (1, Sequence_Item);
      Check (Element (Item, A).Kind = Scripts_Node,
        "scripts remain semantic operation");
      Check (Child (A, Script_Base) /= 0 and
        Child (A, Superscript) /= 0 and Child (A, Subscript) /= 0,
        "scripts base superscript subscript");
      Check (Element (Item, A).Script_Type = Side_Scripts,
        "side script layout data");
      Check (Element (Item, Child (A, Superscript)).Position = 5 and
        Element (Item, Child (A, Subscript)).Position = 3,
        "script source positions preserved");

      Check_Common ("\sqrt[3]{x}");
      A := Child (1, Sequence_Item);
      Check (Element (Item, A).Kind = Radical_Node and
        Child (A, Radicand) /= 0 and Child (A, Radical_Index) /= 0,
        "radical with index roles");
      Check (Element (Item, Child (A, Radical_Index)).Position = 7,
        "radical index position");

      Check_Common ("\begin{matrix}a&b\\c&d\end{matrix}");
      A := Child (1, Sequence_Item);
      B := Element (Item, A).First_Child;
      C := Element (Item, B).Next_Sibling;
      Check (Element (Item, A).Kind = Array_Node and B /= 0 and C /= 0,
        "array has rows as children");
      Check (Element (Item, B).Role = Array_Row and
        Element (Item, C).Role = Array_Row,
        "array row roles retain reading order");
      D := Element (Item, B).First_Child;
      Check (D /= 0 and Element (Item, D).Role = Array_Cell and
        Element (Item, D).Next_Sibling /= 0 and
        Element (Item, C).First_Child /= 0,
        "array cells nested under their rows");
      Check (Element (Item, Element (Item, C).First_Child).Position <
        Element (Item, Element (Item,
          Element (Item, C).First_Child).Next_Sibling).Position,
        "array cells follow source reading order");
      Check (Element (Item, A).Array_Type = Matrix_Array,
        "array kind payload");

      Check_Common ("\begin{array}{lr}a&b\\c&d\end{array}");
      A := Child (1, Sequence_Item);
      Check (Ada.Strings.Unbounded.To_String
        (Element (Item, A).Column_Spec) = "lr" and
        Element (Item, A).Row_Spacing > 0.0,
        "array column and spacing metadata retained");

      Check_Common ("\binom{a}{b}");
      A := Child (1, Sequence_Item);
      Check (Element (Item, A).Kind = Binomial_Node and
        Child (A, Numerator) /= 0 and Child (A, Denominator) /= 0,
        "binomial children retain numerator and denominator roles");
      Check (Element (Item, A).Left_Delimiter =
        Math_Syntax.Parenthesis_Delimiter,
        "binomial delimiter metadata retained");

      Check_Common ("\overset{a}{x}");
      A := Child (1, Sequence_Item);
      B := Child (A, Annotation_Base);
      C := Child (A, Annotation_Above);
      Check (Element (Item, A).Kind = Annotation_Node and
        B /= 0 and C /= 0 and
        Element (Item, B).Position > Element (Item, C).Position,
        "overset retains base and above-label roles in source order");
      Check (Element (Item, A).Annotation_Type = Over_Annotation,
        "overset annotation type retained");

      Check_Common ("\underset{a}{x}");
      A := Child (1, Sequence_Item);
      B := Child (A, Annotation_Base);
      C := Child (A, Annotation_Below);
      Check (B /= 0 and C /= 0 and
        Element (Item, C).Position < Element (Item, B).Position and
        Element (Item, A).Annotation_Type = Under_Annotation,
        "underset retains below label and base roles");

      Check_Common ("\color{blue}{\phantom{x}}");
      A := Child (1, Sequence_Item);
      B := Child (A, Color_Content);
      C := Child (B, Sequence_Item);
      D := Child (C, Phantom_Content);
      Check (B /= 0 and C /= 0 and D /= 0,
        "color and phantom content roles are projected");
      if B /= 0 and then C /= 0 and then D /= 0 then
         Check (Element (Item, A).Color.Blue = 1.0 and
           Element (Item, C).Kind = Phantom_Node and
           Element (Item, C).Code_Point = 0 and
           Element (Item, D).Kind in Row_Node | Glyph_Node,
           "nested blue color and phantom geometry content retained");
         Check (Element (Item, A).Child_Count = 1 and
           Element (Item, C).Child_Count = 1,
           "phantom projection retains semantic children");
      end if;

      Check_Common ("\displaystyle{x}");
      A := Child (1, Sequence_Item);
      Check (Element (Item, A).Math_Style = Display_Style and
        Child (A, Styled_Content) /= 0,
        "style metadata and content role retained");

      Check_Common ("\hat{x}+\dot{y}");
      A := Child (1, Sequence_Item);
      Check (Element (Item, A).Kind = Accent_Node and
        Accent_Command (Item, Positive (A)) = "\hat",
        "hat operation exact source label");
      Check (Element (Item, A).Code_Point = 16#02C6# and
        Child (A, Accent_Base) /= 0, "accent mark and base payload");
      B := Element (Item, A).Next_Sibling;
      C := Element (Item, B).Next_Sibling;
      Check (Element (Item, C).Kind = Accent_Node and
        Accent_Command (Item, Positive (C)) = "\dot",
        "dot source command retained");
      Check_Common ("\bar x");
      A := Child (1, Sequence_Item);
      Check (Accent_Command (Item, Positive (A)) = "\bar",
        "unbraced accent command source label");

      Check_Common ("\widehat{xy}");
      A := Child (1, Sequence_Item);
      Check (Element (Item, A).Kind = Accent_Node and
        Element (Item, A).Code_Point = Wide_Hat_Code_Point and
        Child (A, Accent_Base) /= 0,
        "widehat path accent retains semantic node and base");

      Check_Common ("\left(x+1\right)");
      A := Child (1, Sequence_Item);
      Check (Element (Item, A).Kind = Delimited_Node and
        Child (A, Delimited_Content) /= 0 and
        Element (Item, A).Left_Delimiter = Math_Syntax.Parenthesis_Delimiter
        and Element (Item, A).Right_Delimiter =
          Math_Syntax.Parenthesis_Delimiter,
        "delimited expression and delimiter operations");

      Check_Common ("x+y");
      A := Child (1, Sequence_Item);
      Check (A /= 0 and then Element (Item, A).Kind = Glyph_Node,
        "ordinary glyph projects with semantic content");

      Check_Common ("a+b");
      A := Child (1, Sequence_Item);
      B := Element (Item, A).Next_Sibling;
      Check (B /= 0 and then Element (Item, B).Kind = Glyph_Node,
        "semantic sequence retains sibling order");

      Check (not Is_Valid (Invalid) and Error (Invalid)'Length > 0,
        "unsupported syntax not accepted");

      declare
         Definition_AST : constant Math_Syntax.Document :=
           Math_Syntax.Parse
             ("\gdef\foo{A}", Shared'Access, Global_Group => True);
         Use_AST : constant Math_Syntax.Document :=
           Math_Syntax.Parse ("\foo", Shared'Access);
         Definition_Count : constant Natural :=
           Math_Macros.Definition_Count (Shared);
         Projected : constant Document := Project (Use_AST);
         Projected_Node : constant Semantic_Node := Element (Projected, 1);
         Projected_Glyph : constant Semantic_Node :=
           Element (Projected, Positive (Projected_Node.First_Child));
      begin
         Check (not Math_Syntax.Is_Valid (Definition_AST) and
           Math_Syntax.Is_Valid (Use_AST), "shared macro ASTs valid");
         Check (Is_Valid (Projected), "shared macro AST projects");
         Check (Source (Projected) = "\foo",
           "AST projection preserves exact unexpanded source");
         Check (Projected_Node.Kind = Row_Node and
           Projected_Glyph.Kind = Glyph_Node and
           Projected_Glyph.Code_Point = Character'Pos ('A'),
           "AST projection uses already-expanded shared AST");
         Check (Math_Macros.Definition_Count (Shared) = Definition_Count and
           Math_Macros.Is_Defined (Shared, "\foo"),
           "AST projection has no macro context side effect");
      end;
      Current := 1;
      while Current <= Count (Item) loop
         N := Element (Item, Positive (Current));
         if N.First_Child /= 0 then
            Check (Element (Item, N.First_Child).Parent = Current,
              "first-child parent link");
         end if;
         if N.Next_Sibling /= 0 then
            Check (Element (Item, N.Next_Sibling).Parent = N.Parent,
              "next-sibling parent consistency");
         end if;
         Current := Current + 1;
      end loop;
   end Run;
begin
   Run;
   Ada.Text_IO.Put_Line ("ASSERTIONS" & Natural'Image (Checks) &
     " failures=" & Natural'Image (Failures));
   if Checks <= 25 or else Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Semantics_Probe;
