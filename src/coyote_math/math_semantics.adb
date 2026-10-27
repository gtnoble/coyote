with Ada.Strings.Unbounded;
with Math_Macros;

package body Math_Semantics is
   use Ada.Strings.Unbounded;

   function Accent_Command (Item : Document; Index : Positive) return String is
      N : constant Semantic_Node := Element (Item, Index);
      Text : constant String := Source (Item);
      First : Natural := N.Position;
      Last : Natural;
   begin
      if N.Kind = Stretchy_Node then
         return "\" & To_String (N.Stretchy_Name);
      elsif N.Kind /= Accent_Node then
         return "";
      end if;
      case N.Code_Point is
         when Wide_Hat_Code_Point =>
            return "\widehat";
         when Wide_Tilde_Code_Point =>
            return "\widetilde";
         when Over_Right_Arrow_Code_Point =>
            return "\overrightarrow";
         when Over_Left_Arrow_Code_Point =>
            return "\overleftarrow";
         when Over_Brace_Code_Point =>
            return "\overbrace";
         when Under_Brace_Code_Point =>
            return "\underbrace";
         when others =>
            if N.Code_Point >= Wide_Hat_Code_Point then
               return "";
            end if;
      end case;
      if First > Text'Last then
         return "";
      end if;
      if Text (First) = '\' then
         First := First + 1;
      end if;
      Last := First;
      while Last <= Text'Last and then Text (Last) in 'a' .. 'z' loop
         Last := Last + 1;
      end loop;
      if Last > First then
         return Text (First - (if Text (First - 1) = '\' then 1 else 0)
           .. Last - 1);
      end if;
      return "";
   end Accent_Command;
   function Project (Source : String) return Document is
   begin
      return Project (Math_Syntax.Parse (Source));
   end Project;

   function Project (AST : Math_Syntax.Document) return Document is
      Result : Document;
      Tail_Array : array (1 .. Max_Semantic_Nodes) of Natural :=
        (others => 0);
      type Frame is record
         AST_Id : Node_Id;
         Sem_Id : Natural;
      end record;
      type Frame_Array is array (Positive range <>) of Frame;
      Stack : Frame_Array (1 .. Math_Syntax.Max_Nodes * 8);
      Stack_Last : Natural := 0;
      procedure Push (Id : Node_Id; Sem_Id : Natural) is
      begin
         if Id = No_Node then
            return;
         elsif Id > Math_Syntax.Count (AST) or else
           Stack_Last = Stack'Last
         then
            Result.Message := To_Unbounded_String
              ("invalid AST link or projection depth limit");
            return;
         end if;
         Stack_Last := Stack_Last + 1;
         Stack (Stack_Last) := (Id, Sem_Id);
      end Push;
      function Make_Node
        (Id : Node_Id; Parent : Natural; Role : Child_Role)
         return Semantic_Node is
         A : constant Math_Syntax.Node := Math_Syntax.Element
           (AST, Positive (Id));
      begin
         return
           (Kind            => A.Kind,
            Role            => Role,
            AST_Id          => Id,
            Parent          => Parent,
            First_Child     => 0,
            Next_Sibling    => 0,
            Child_Count     => 0,
            Position        => A.Position,
            Class           => A.Class,
            Font            => A.Font,
            Code_Point      => A.Code_Point,
            Stretchy_Name   => A.Stretchy_Name,
            Amount          => A.Amount,
            Width           => A.Width,
            Height          => A.Height,
            Depth           => A.Depth,
            Scale           => A.Scale,
            Enclosure       => A.Enclosure,
            Fraction_Type   => A.Fraction_Type,
            Fraction_Bar    => A.Fraction_Bar,
            Fraction_Alignment_Mode => A.Fraction_Alignment_Mode,
            Fraction_Rule_Thickness => A.Fraction_Rule_Thickness,
            Fraction_Continued => A.Fraction_Continued,
            Fraction_Style_Mode => A.Fraction_Style_Mode,
            Script_Type     => A.Script_Type,
            Array_Type      => A.Array_Type,
            Column_Spec     => A.Column_Spec,
            Row_Spacing     => A.Row_Spacing,
            Math_Style      => A.Math_Style,
            Annotation_Type => A.Annotation_Type,
            Color           => A.Color,
            Left_Delimiter  => A.Left_Delimiter,
            Right_Delimiter => A.Right_Delimiter);
      end Make_Node;
      procedure Add_Child
        (Parent : Natural; Id : Node_Id; Role : Child_Role) is
         Index : Natural;
         Parent_Node : Semantic_Node;
         Previous : Semantic_Node;
      begin
         if Id = No_Node or else Length (Result.Message) > 0 then
            return;
         end if;
         if Id > Math_Syntax.Count (AST) or else
           Natural (Result.Nodes.Length) >= Max_Semantic_Nodes or else
           Natural (Result.Nodes.Length) >=
             2 * Math_Syntax.Count (AST)
         then
            Result.Message := To_Unbounded_String
              ("invalid AST link or semantic node budget exceeded");
            return;
         end if;
         Result.Nodes.Append (Make_Node (Id, Parent, Role));
         Index := Natural (Result.Nodes.Last_Index);
         Parent_Node := Result.Nodes (Positive (Parent));
         if Parent_Node.First_Child = 0 then
            Parent_Node.First_Child := Index;
         else
            Previous := Result.Nodes (Positive (Tail_Array (Parent)));
            Previous.Next_Sibling := Index;
            Result.Nodes.Replace_Element
              (Positive (Tail_Array (Parent)), Previous);
         end if;
         Parent_Node.Child_Count := Parent_Node.Child_Count + 1;
         Result.Nodes.Replace_Element (Positive (Parent), Parent_Node);
         Tail_Array (Parent) := Index;
         Push (Id, Index);
      end Add_Child;
      procedure Add_Chain
        (Parent : Natural; Id : Node_Id; Role : Child_Role) is
         Current : Node_Id := Id;
         Seen : Natural := 0;
      begin
         while Current /= No_Node and then Length (Result.Message) = 0 loop
            if Current > Math_Syntax.Count (AST) or else
              Seen >= Math_Syntax.Count (AST)
            then
               Result.Message := To_Unbounded_String
                 ("invalid or cyclic AST sibling chain");
               exit;
            end if;
            Add_Child (Parent, Current, Role);
            Current := Math_Syntax.Element (AST, Positive (Current)).Next;
            Seen := Seen + 1;
         end loop;
      end Add_Chain;
      procedure Expand (Sem_Id : Natural; Id : Node_Id) is
         A : constant Math_Syntax.Node := Math_Syntax.Element
           (AST, Positive (Id));
         Semantic : constant Semantic_Node :=
           Result.Nodes (Positive (Sem_Id));
         Current_Row : Node_Id;
         Row_Count : Natural := 0;
      begin
         if Semantic.Role = Array_Row then
            Add_Chain (Sem_Id, A.First, Array_Cell);
            return;
         end if;
         case A.Kind is
            when Row_Node =>
               Add_Chain (Sem_Id, A.First, Sequence_Item);
            when Fraction_Node =>
               Add_Child (Sem_Id, A.First, Numerator);
               Add_Child (Sem_Id, A.Second, Denominator);
            when Radical_Node =>
               Add_Child (Sem_Id, A.First, Radicand);
               Add_Child (Sem_Id, A.Second, Radical_Index);
            when Scripts_Node =>
               Add_Child (Sem_Id, A.First, Script_Base);
               Add_Child (Sem_Id, A.Second, Superscript);
               Add_Child (Sem_Id, A.Third, Subscript);
            when Array_Node =>
               Current_Row := A.First;
               while Current_Row /= No_Node and then
                 Length (Result.Message) = 0
               loop
                  if Current_Row > Math_Syntax.Count (AST) or else
                    Row_Count >= Math_Syntax.Count (AST)
                  then
                     Result.Message := To_Unbounded_String
                       ("invalid or cyclic array row chain");
                     exit;
                  end if;
                  Add_Child (Sem_Id, Current_Row, Array_Row);
                  Current_Row := Math_Syntax.Element
                    (AST, Positive (Current_Row)).Next;
                  Row_Count := Row_Count + 1;
               end loop;
            when Delimited_Node =>
               Add_Child (Sem_Id, A.First, Delimited_Content);
            when Accent_Node =>
               Add_Child (Sem_Id, A.First, Accent_Base);
            when Stretchy_Node =>
               if A.Code_Point = 0 then
                  Add_Child (Sem_Id, A.First, Accent_Base);
               else
                  Add_Child (Sem_Id, A.First, Annotation_Above);
                  Add_Child (Sem_Id, A.Second, Annotation_Below);
               end if;
            when Overlay_Node =>
               Add_Child (Sem_Id, A.First, Overlay_Base);
               Add_Child (Sem_Id, A.Second, Overlay_Mark);
            when Dual_Node =>
               Add_Child (Sem_Id, A.Second, Delimited_Content);
            when MathChoice_Node =>
               Add_Child (Sem_Id, A.First, Display_Choice_Text);
               Add_Child (Sem_Id, A.Second, Text_Choice_Text);
               Add_Child (Sem_Id, A.Third, Script_Choice_Text);
               Add_Child (Sem_Id, A.Fourth, Scriptscript_Choice_Text);
            when Binomial_Node =>
               Add_Child (Sem_Id, A.First, Numerator);
               Add_Child (Sem_Id, A.Second, Denominator);
            when Annotation_Node =>
               Add_Child (Sem_Id, A.First, Annotation_Base);
               if A.Annotation_Type = Over_Annotation then
                  Add_Child (Sem_Id, A.Second, Annotation_Above);
               else
                  Add_Child (Sem_Id, A.Second, Annotation_Below);
               end if;
            when Boxed_Node =>
               Add_Child (Sem_Id, A.First, Boxed_Content);
            when Phantom_Node =>
               Add_Child (Sem_Id, A.First, Phantom_Content);
            when Color_Node =>
               Add_Child (Sem_Id, A.First, Color_Content);
            when Tagged_Node =>
               Add_Child (Sem_Id, A.First, Sequence_Item);
               Add_Child (Sem_Id, A.Second, Annotation_Below);
            when Overlap_Node =>
               Add_Child (Sem_Id, A.First, Delimited_Content);
            when Style_Node =>
               Add_Child (Sem_Id, A.First, Styled_Content);
            when Sized_Node =>
               Add_Child (Sem_Id, A.First, Sized_Content);
            when Raised_Node =>
               Add_Child (Sem_Id, A.First, Raised_Content);
            when Enclosed_Node =>
               Add_Child (Sem_Id, A.First, Enclosed_Content);
            when Rule_Node | Glyph_Node | Space_Node =>
               null;
         end case;
      end Expand;
   begin
      Result.Text := To_Unbounded_String (Math_Syntax.Source (AST));
      if not Math_Syntax.Is_Valid (AST) then
         Result.Message := To_Unbounded_String (Math_Syntax.Error (AST));
         return Result;
      end if;
      if Math_Syntax.Count (AST) = 0 or else
        Math_Syntax.Count (AST) > Max_Semantic_Nodes / 2
      then
         Result.Message := To_Unbounded_String
           ("AST outside semantic projection budget");
         return Result;
      end if;
      Result.Nodes.Append
        (Make_Node (Math_Syntax.Root (AST), 0, Root_Role));
      Result.Root_Index := 1;
      Push (Math_Syntax.Root (AST), 1);
      while Stack_Last > 0 and then Length (Result.Message) = 0 loop
         declare
            Work : constant Frame := Stack (Stack_Last);
         begin
            Stack_Last := Stack_Last - 1;
            Expand (Work.Sem_Id, Work.AST_Id);
         end;
      end loop;
      return Result;
   exception
      when others =>
         Result.Message := To_Unbounded_String
           ("semantic projection failed safely");
         return Result;
   end Project;

   function Is_Valid (Item : Document) return Boolean is
     (Length (Item.Message) = 0 and then Item.Root_Index /= 0);

   function Source (Item : Document) return String is
     (To_String (Item.Text));

   function Error (Item : Document) return String is
     (To_String (Item.Message));

   function Count (Item : Document) return Natural is
     (Natural (Item.Nodes.Length));

   function Root (Item : Document) return Natural is (Item.Root_Index);

   function Element
     (Item : Document; Index : Positive) return Semantic_Node is
     (Item.Nodes (Index));
end Math_Semantics;
