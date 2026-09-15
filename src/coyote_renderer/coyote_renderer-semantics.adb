--  Coyote_Renderer.Semantics body.
--
--  The implementation uses document-local vector indexes instead of recursive
--  access values.  This keeps ownership deterministic and makes inspection
--  independent of any parser or renderer lifetime.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Coyote_Renderer.Semantics is

   protected type Document_Identity_Allocator is
      procedure Allocate (Result : out Natural);
   private
      Next : Natural := 0;
   end Document_Identity_Allocator;

   protected body Document_Identity_Allocator is
      procedure Allocate (Result : out Natural) is
      begin
         if Next = Natural'Last then
            raise Storage_Error;
         end if;
         Next := Next + 1;
         Result := Next;
      end Allocate;
   end Document_Identity_Allocator;

   Identity_Allocator : Document_Identity_Allocator;

   function New_Document_Identity return Natural is
      Result : Natural;
   begin
      Identity_Allocator.Allocate (Result);
      return Result;
   end New_Document_Identity;

   procedure Ensure_Identity (D : in out Document) is
   begin
      if D.Identity = 0 then
         D.Identity := New_Document_Identity;
      end if;
   end Ensure_Identity;

   function Is_Valid
     (D : Document; Id : Block_Id) return Boolean is
   begin
      return Id.Document_Identity = D.Identity
        and then Id.Generation = D.Generation
        and then Id.Index > 0
        and then Id.Index <= Natural (D.Blocks.Length);
   end Is_Valid;

   function Is_Valid
     (D : Document; Id : Inline_Id) return Boolean is
   begin
      return Id.Document_Identity = D.Identity
        and then Id.Generation = D.Generation
        and then Id.Index > 0
        and then Id.Index <= Natural (D.Inlines.Length);
   end Is_Valid;

   function Is_Valid
     (D : Document; Id : Table_Row_Id) return Boolean is
   begin
      return Id.Document_Identity = D.Identity
        and then Id.Generation = D.Generation
        and then Id.Index > 0
        and then Id.Index <= Natural (D.Rows.Length);
   end Is_Valid;

   function Is_Valid
     (D : Document; Id : Table_Cell_Id) return Boolean is
   begin
      return Id.Document_Identity = D.Identity
        and then Id.Generation = D.Generation
        and then Id.Index > 0
        and then Id.Index <= Natural (D.Cells.Length);
   end Is_Valid;

   procedure Clear (D : in out Document) is
   begin
      D.Blocks.Clear;
      D.Root_Blocks.Clear;
      D.Inlines.Clear;
      D.Rows.Clear;
      D.Cells.Clear;
      if D.Generation = Natural'Last then
         D.Generation := 1;
      else
         D.Generation := D.Generation + 1;
      end if;
   end Clear;

   function New_Block
     (D      : in out Document;
      Kind   : Block_Kind;
      Source : String := "") return Block_Id
   is
      Result : Block_Id;
   begin
      Ensure_Identity (D);
      D.Blocks.Append
        ((Kind             => Kind,
          Source           => To_Unbounded_String (Source),
          Semantic_Root_Id => 0,
          Heading_Level    => 0,
          List_Kind     => Unordered_List,
          List_Start     => 1,
          Code_Literal  => Null_Unbounded_String,
          Code_Language => Null_Unbounded_String,
          MathML        => Null_Unbounded_String,
          Children      => Block_Id_Vectors.Empty_Vector,
          Inlines       => Inline_Id_Vectors.Empty_Vector,
          Rows          => Table_Row_Id_Vectors.Empty_Vector,
          Alignments    => Alignment_Vectors.Empty_Vector,
          Column_Count  => 0));
      Result.Index := Positive (D.Blocks.Length);
      Result.Generation := D.Generation;
      Result.Document_Identity := D.Identity;
      return Result;
   end New_Block;

   function New_Inline
     (D      : in out Document;
      Kind   : Inline_Kind;
      Value  : String := "";
      Source : String := "") return Inline_Id
   is
      Result : Inline_Id;
   begin
      Ensure_Identity (D);
      D.Inlines.Append
        ((Kind     => Kind,
          Value    => To_Unbounded_String (Value),
          Source   => To_Unbounded_String (Source),
          URL      => Null_Unbounded_String,
          Children => Inline_Id_Vectors.Empty_Vector));
      Result.Index := Positive (D.Inlines.Length);
      Result.Generation := D.Generation;
      Result.Document_Identity := D.Identity;
      return Result;
   end New_Inline;

   function Set_Block_Source
     (D : in out Document; Block : Block_Id; Source : String)
     return Boolean is
   begin
      if not Is_Valid (D, Block) then
         return False;
      end if;
      D.Blocks.Reference (Block.Index).Source :=
        To_Unbounded_String (Source);
      return True;
   end Set_Block_Source;

   function Set_Block_Kind
     (D : in out Document; Block : Block_Id; Kind : Block_Kind)
     return Boolean is
   begin
      if not Is_Valid (D, Block) then
         return False;
      end if;
      D.Blocks.Reference (Block.Index).Kind := Kind;
      return True;
   end Set_Block_Kind;

   function Set_Block_Invalid_Source
     (D : in out Document; Block : Block_Id; Source : String)
     return Boolean is
   begin
      if not Is_Valid (D, Block) then
         return False;
      end if;
      declare
         Item : Block_Record renames D.Blocks.Reference (Block.Index);
      begin
         Item.Kind := Invalid_Source;
         Item.Source := To_Unbounded_String (Source);
         Item.Heading_Level := 0;
         Item.List_Kind := Unordered_List;
         Item.List_Start := 1;
         Item.Code_Literal := Null_Unbounded_String;
         Item.Code_Language := Null_Unbounded_String;
         Item.MathML := Null_Unbounded_String;
         Item.Children.Clear;
         Item.Inlines.Clear;
         Item.Rows.Clear;
         Item.Alignments.Clear;
         Item.Column_Count := 0;
      end;
      return True;
   end Set_Block_Invalid_Source;

   function Set_Block_Semantic_Root_Id
     (D : in out Document; Block : Block_Id; Root_Id : Natural)
     return Boolean is
   begin
      if not Is_Valid (D, Block) then
         return False;
      end if;
      D.Blocks.Reference (Block.Index).Semantic_Root_Id := Root_Id;
      return True;
   end Set_Block_Semantic_Root_Id;

   function Block_Semantic_Root_Id
     (D : Document; Block : Block_Id) return Natural is
   begin
      if Is_Valid (D, Block) then
         return D.Blocks.Element (Block.Index).Semantic_Root_Id;
      end if;
      return 0;
   end Block_Semantic_Root_Id;

   function Set_Inline_Source
     (D : in out Document; Inline : Inline_Id; Source : String)
     return Boolean is
   begin
      if not Is_Valid (D, Inline) then
         return False;
      end if;
      D.Inlines.Reference (Inline.Index).Source :=
        To_Unbounded_String (Source);
      return True;
   end Set_Inline_Source;

   function Set_Inline_Value
     (D : in out Document; Inline : Inline_Id; Value : String)
     return Boolean is
   begin
      if not Is_Valid (D, Inline) then
         return False;
      end if;
      D.Inlines.Reference (Inline.Index).Value :=
        To_Unbounded_String (Value);
      return True;
   end Set_Inline_Value;

   function Set_Table_Cell_Source
     (D : in out Document; Cell : Table_Cell_Id; Source : String)
     return Boolean is
   begin
      if not Is_Valid (D, Cell) then
         return False;
      end if;
      D.Cells.Reference (Cell.Index).Source :=
        To_Unbounded_String (Source);
      return True;
   end Set_Table_Cell_Source;

   procedure Copy
     (Source : Document; Target : in out Document) is
   begin
      Ensure_Identity (Target);
      Clear (Target);
      Target.Blocks := Source.Blocks;
      Target.Root_Blocks := Source.Root_Blocks;
      Target.Inlines := Source.Inlines;
      Target.Rows := Source.Rows;
      Target.Cells := Source.Cells;

      if not Target.Root_Blocks.Is_Empty then
         for I in Target.Root_Blocks.First_Index ..
           Target.Root_Blocks.Last_Index loop
            Target.Root_Blocks.Reference (I).Generation := Target.Generation;
            Target.Root_Blocks.Reference (I).Document_Identity :=
              Target.Identity;
         end loop;
      end if;
      if not Target.Blocks.Is_Empty then
         for I in Target.Blocks.First_Index .. Target.Blocks.Last_Index loop
            declare
               B : Block_Record renames Target.Blocks.Reference (I);
            begin
               if not B.Children.Is_Empty then
                  for J in B.Children.First_Index .. B.Children.Last_Index loop
                     B.Children.Reference (J).Generation := Target.Generation;
                     B.Children.Reference (J).Document_Identity :=
                       Target.Identity;
                  end loop;
               end if;
               if not B.Inlines.Is_Empty then
                  for J in B.Inlines.First_Index .. B.Inlines.Last_Index loop
                     B.Inlines.Reference (J).Generation := Target.Generation;
                     B.Inlines.Reference (J).Document_Identity :=
                       Target.Identity;
                  end loop;
               end if;
               if not B.Rows.Is_Empty then
                  for J in B.Rows.First_Index .. B.Rows.Last_Index loop
                     B.Rows.Reference (J).Generation := Target.Generation;
                     B.Rows.Reference (J).Document_Identity :=
                       Target.Identity;
                  end loop;
               end if;
            end;
         end loop;
      end if;
      if not Target.Inlines.Is_Empty then
         for I in Target.Inlines.First_Index .. Target.Inlines.Last_Index loop
            if not Target.Inlines.Reference (I).Children.Is_Empty then
               for J in Target.Inlines.Reference (I).Children.First_Index ..
                 Target.Inlines.Reference (I).Children.Last_Index loop
                  Target.Inlines.Reference (I).Children.Reference (J).Generation :=
                    Target.Generation;
                  Target.Inlines.Reference (I).Children.Reference (J)
                    .Document_Identity := Target.Identity;
               end loop;
            end if;
         end loop;
      end if;
      if not Target.Rows.Is_Empty then
         for I in Target.Rows.First_Index .. Target.Rows.Last_Index loop
            Target.Rows.Reference (I).Table.Generation := Target.Generation;
            Target.Rows.Reference (I).Table.Document_Identity :=
              Target.Identity;
            if not Target.Rows.Reference (I).Cells.Is_Empty then
               for J in Target.Rows.Reference (I).Cells.First_Index ..
                 Target.Rows.Reference (I).Cells.Last_Index loop
                  Target.Rows.Reference (I).Cells.Reference (J).Generation :=
                    Target.Generation;
                  Target.Rows.Reference (I).Cells.Reference (J).Document_Identity :=
                    Target.Identity;
               end loop;
            end if;
         end loop;
      end if;
      if not Target.Cells.Is_Empty then
         for I in Target.Cells.First_Index .. Target.Cells.Last_Index loop
            if not Target.Cells.Reference (I).Inlines.Is_Empty then
               for J in Target.Cells.Reference (I).Inlines.First_Index ..
                 Target.Cells.Reference (I).Inlines.Last_Index loop
                  Target.Cells.Reference (I).Inlines.Reference (J).Generation :=
                    Target.Generation;
                  Target.Cells.Reference (I).Inlines.Reference (J)
                    .Document_Identity := Target.Identity;
               end loop;
            end if;
         end loop;
      end if;

   end Copy;

   function Append_Block
     (D : in out Document; Child : Block_Id) return Boolean is
   begin
      if not Is_Valid (D, Child) then
         return False;
      end if;
      D.Root_Blocks.Append (Child);
      return True;
   end Append_Block;

   function Append_Block
     (D      : in out Document;
      Parent : Block_Id;
      Child  : Block_Id) return Boolean is
   begin
      if not Is_Valid (D, Parent) or else not Is_Valid (D, Child) then
         return False;
      end if;
      D.Blocks.Reference (Parent.Index).Children.Append (Child);
      return True;
   end Append_Block;

   function Append_Inline
     (D      : in out Document;
      Parent : Block_Id;
      Child  : Inline_Id) return Boolean is
   begin
      if not Is_Valid (D, Parent) or else not Is_Valid (D, Child) then
         return False;
      end if;
      D.Blocks.Reference (Parent.Index).Inlines.Append (Child);
      return True;
   end Append_Inline;

   function Append_Inline
     (D      : in out Document;
      Parent : Inline_Id;
      Child  : Inline_Id) return Boolean is
   begin
      if not Is_Valid (D, Parent) or else not Is_Valid (D, Child) then
         return False;
      end if;
      D.Inlines.Reference (Parent.Index).Children.Append (Child);
      return True;
   end Append_Inline;

   function Append_Inline
     (D      : in out Document;
      Parent : Table_Cell_Id;
      Child  : Inline_Id) return Boolean is
   begin
      if not Is_Valid (D, Parent) or else not Is_Valid (D, Child) then
         return False;
      end if;
      D.Cells.Reference (Parent.Index).Inlines.Append (Child);
      return True;
   end Append_Inline;

   function Append_Text
     (D      : in out Document;
      Parent : Block_Id;
      Value  : String;
      Source : String) return Boolean is
      Item : Inline_Id;
   begin
      if not Is_Valid (D, Parent) then
         return False;
      end if;
      if not D.Blocks.Element (Parent.Index).Inlines.Is_Empty then
         Item := D.Blocks.Element (Parent.Index).Inlines.Last_Element;
         if Inline_Kind_Of (D, Item) = Text then
            D.Inlines.Reference (Item.Index).Value :=
              D.Inlines.Element (Item.Index).Value & Value;
            D.Inlines.Reference (Item.Index).Source :=
              D.Inlines.Element (Item.Index).Source & Source;
            return True;
         end if;
      end if;
      Item := New_Inline (D, Text, Value, Source);
      return Append_Inline (D, Parent, Item);
   end Append_Text;

   function Append_Text
     (D      : in out Document;
      Parent : Inline_Id;
      Value  : String;
      Source : String) return Boolean is
      Item : Inline_Id;
   begin
      if not Is_Valid (D, Parent) then
         return False;
      end if;
      if not D.Inlines.Element (Parent.Index).Children.Is_Empty then
         Item := D.Inlines.Element (Parent.Index).Children.Last_Element;
         if Inline_Kind_Of (D, Item) = Text then
            D.Inlines.Reference (Item.Index).Value :=
              D.Inlines.Element (Item.Index).Value & Value;
            D.Inlines.Reference (Item.Index).Source :=
              D.Inlines.Element (Item.Index).Source & Source;
            return True;
         end if;
      end if;
      Item := New_Inline (D, Text, Value, Source);
      return Append_Inline (D, Parent, Item);
   end Append_Text;

   function Append_Text
     (D      : in out Document;
      Parent : Table_Cell_Id;
      Value  : String;
      Source : String) return Boolean is
      Item : Inline_Id;
   begin
      if not Is_Valid (D, Parent) then
         return False;
      end if;
      if not D.Cells.Element (Parent.Index).Inlines.Is_Empty then
         Item := D.Cells.Element (Parent.Index).Inlines.Last_Element;
         if Inline_Kind_Of (D, Item) = Text then
            D.Inlines.Reference (Item.Index).Value :=
              D.Inlines.Element (Item.Index).Value & Value;
            D.Inlines.Reference (Item.Index).Source :=
              D.Inlines.Element (Item.Index).Source & Source;
            return True;
         end if;
      end if;
      Item := New_Inline (D, Text, Value, Source);
      return Append_Inline (D, Parent, Item);
   end Append_Text;

   function Set_Heading_Level
     (D     : in out Document;
      Block : Block_Id;
      Level : Heading_Level) return Boolean is
   begin
      if not Is_Valid (D, Block) then
         return False;
      end if;
      D.Blocks.Reference (Block.Index).Heading_Level := Level;
      return True;
   end Set_Heading_Level;

   function Set_List_Attributes
     (D       : in out Document;
      Block   : Block_Id;
      Kind    : List_Kind;
      Start   : Positive := 1) return Boolean is
   begin
      if not Is_Valid (D, Block) then
         return False;
      end if;
      D.Blocks.Reference (Block.Index).List_Kind := Kind;
      D.Blocks.Reference (Block.Index).List_Start := Start;
      return True;
   end Set_List_Attributes;

   function Set_Code_Block_Data
     (D        : in out Document;
      Block    : Block_Id;
      Literal  : String;
      Language : String := "") return Boolean is
   begin
      if not Is_Valid (D, Block) then
         return False;
      end if;
      D.Blocks.Reference (Block.Index).Code_Literal :=
        To_Unbounded_String (Literal);
      D.Blocks.Reference (Block.Index).Code_Language :=
        To_Unbounded_String (Language);
      return True;
   end Set_Code_Block_Data;

   function Set_Display_Math_Data
     (D      : in out Document;
      Block  : Block_Id;
      MathML : String) return Boolean is
   begin
      if not Is_Valid (D, Block) then
         return False;
      end if;
      D.Blocks.Reference (Block.Index).MathML :=
        To_Unbounded_String (MathML);
      return True;
   end Set_Display_Math_Data;

   function Set_Link_URL
     (D     : in out Document;
      Link  : Inline_Id;
      URL   : String) return Boolean is
   begin
      if not Is_Valid (D, Link) then
         return False;
      end if;
      D.Inlines.Reference (Link.Index).URL := To_Unbounded_String (URL);
      return True;
   end Set_Link_URL;

   function New_Table_Row
     (D         : in out Document;
      Table     : Block_Id;
      Is_Header : Boolean := False) return Table_Row_Id is
      Result : Table_Row_Id := No_Table_Row;
   begin
      Ensure_Identity (D);
      if not Is_Valid (D, Table)
        or else D.Blocks.Element (Table.Index).Kind /=
          Coyote_Renderer.Semantics.Table
      then
         return Result;
      end if;
      D.Rows.Append
        ((Table     => Table,
          Is_Header => Is_Header,
          Source    => Null_Unbounded_String,
          Cells     => Table_Cell_Id_Vectors.Empty_Vector));
      Result.Index := Positive (D.Rows.Length);
      Result.Generation := D.Generation;
      Result.Document_Identity := D.Identity;
      D.Blocks.Reference (Table.Index).Rows.Append (Result);
      return Result;
   end New_Table_Row;

   function New_Table_Cell
     (D      : in out Document;
      Row    : Table_Row_Id;
      Value  : String := "";
      Source : String := "") return Table_Cell_Id is
      Result : Table_Cell_Id := No_Table_Cell;
   begin
      Ensure_Identity (D);
      if not Is_Valid (D, Row)
        or else not Is_Valid (D, D.Rows.Element (Row.Index).Table)
        or else D.Blocks.Element (D.Rows.Element (Row.Index).Table.Index).Kind /= Table
      then
         return Result;
      end if;
      D.Cells.Append
        ((Value   => To_Unbounded_String (Value),
          Source  => To_Unbounded_String (Source),
          Inlines => Inline_Id_Vectors.Empty_Vector));
      Result.Index := Positive (D.Cells.Length);
      Result.Generation := D.Generation;
      Result.Document_Identity := D.Identity;
      D.Rows.Reference (Row.Index).Cells.Append (Result);
      declare
         Table : constant Block_Id := D.Rows.Element (Row.Index).Table;
         Count : constant Natural :=
           Natural (D.Rows.Element (Row.Index).Cells.Length);
      begin
         if Count > D.Blocks.Element (Table.Index).Column_Count then
            D.Blocks.Reference (Table.Index).Column_Count := Count;
         end if;
      end;
      return Result;
   end New_Table_Cell;

   function Set_Table_Cell_Value
     (D     : in out Document;
      Cell  : Table_Cell_Id;
      Value : String) return Boolean is
   begin
      if not Is_Valid (D, Cell) then
         return False;
      end if;
      D.Cells.Reference (Cell.Index).Value := To_Unbounded_String (Value);
      return True;
   end Set_Table_Cell_Value;

   function Set_Table_Alignment
     (D         : in out Document;
      Table     : Block_Id;
      Column    : Positive;
      Alignment : Table_Alignment) return Boolean is
   begin
      if not Is_Valid (D, Table) then
         return False;
      end if;
      declare
         Alignments : Alignment_Vectors.Vector renames
           D.Blocks.Reference (Table.Index).Alignments;
      begin
         while Natural (Alignments.Length) < Column loop
            Alignments.Append (Unspecified);
         end loop;
         Alignments.Replace_Element (Column, Alignment);
      end;
      return True;
   end Set_Table_Alignment;

   function Block_Count (D : Document) return Natural is
   begin
      return Natural (D.Root_Blocks.Length);
   end Block_Count;

   function Block_At (D : Document; Position : Positive) return Block_Id is
   begin
      if Position <= Natural (D.Root_Blocks.Length) then
         return D.Root_Blocks.Element (Position);
      end if;
      return No_Block;
   end Block_At;

   function Block_Kind_Of
     (D : Document; Block : Block_Id) return Block_Kind is
   begin
      if Is_Valid (D, Block) then
         return D.Blocks.Element (Block.Index).Kind;
      end if;
      return Invalid_Source;
   end Block_Kind_Of;

   function Block_Source
     (D : Document; Block : Block_Id) return String is
   begin
      if Is_Valid (D, Block) then
         return To_String (D.Blocks.Element (Block.Index).Source);
      end if;
      return "";
   end Block_Source;

   function Block_Child_Count (D : Document; Block : Block_Id) return Natural is
   begin
      if Is_Valid (D, Block) then
         return Natural (D.Blocks.Element (Block.Index).Children.Length);
      end if;
      return 0;
   end Block_Child_Count;

   function Block_Child_At
     (D : Document; Block : Block_Id; Position : Positive) return Block_Id is
   begin
      if Is_Valid (D, Block)
        and then Position <= Natural (D.Blocks.Element (Block.Index).Children.Length)
      then
         return D.Blocks.Element (Block.Index).Children.Element (Position);
      end if;
      return No_Block;
   end Block_Child_At;

   function Block_Inline_Count
     (D : Document; Block : Block_Id) return Natural is
   begin
      if Is_Valid (D, Block) then
         return Natural (D.Blocks.Element (Block.Index).Inlines.Length);
      end if;
      return 0;
   end Block_Inline_Count;

   function Block_Inline_At
     (D : Document; Block : Block_Id; Position : Positive) return Inline_Id is
   begin
      if Is_Valid (D, Block)
        and then Position <= Natural (D.Blocks.Element (Block.Index).Inlines.Length)
      then
         return D.Blocks.Element (Block.Index).Inlines.Element (Position);
      end if;
      return No_Inline;
   end Block_Inline_At;

   function Heading_Level_Of
     (D : Document; Block : Block_Id) return Natural is
   begin
      if Is_Valid (D, Block) then
         return D.Blocks.Element (Block.Index).Heading_Level;
      end if;
      return 0;
   end Heading_Level_Of;

   function List_Kind_Of
     (D : Document; Block : Block_Id) return List_Kind is
   begin
      if Is_Valid (D, Block) then
         return D.Blocks.Element (Block.Index).List_Kind;
      end if;
      return Unordered_List;
   end List_Kind_Of;

   function List_Start (D : Document; Block : Block_Id) return Positive is
   begin
      if Is_Valid (D, Block) then
         return D.Blocks.Element (Block.Index).List_Start;
      end if;
      return 1;
   end List_Start;

   function Code_Literal (D : Document; Block : Block_Id) return String is
   begin
      if Is_Valid (D, Block) then
         return To_String (D.Blocks.Element (Block.Index).Code_Literal);
      end if;
      return "";
   end Code_Literal;

   function Code_Language (D : Document; Block : Block_Id) return String is
   begin
      if Is_Valid (D, Block) then
         return To_String (D.Blocks.Element (Block.Index).Code_Language);
      end if;
      return "";
   end Code_Language;

   function MathML_Source (D : Document; Block : Block_Id) return String is
   begin
      return Block_Source (D, Block);
   end MathML_Source;

   function MathML_Value (D : Document; Block : Block_Id) return String is
   begin
      if Is_Valid (D, Block) then
         return To_String (D.Blocks.Element (Block.Index).MathML);
      end if;
      return "";
   end MathML_Value;

   function Table_Alignment_At
     (D : Document; Block : Block_Id; Column : Positive)
      return Table_Alignment is
   begin
      if Is_Valid (D, Block)
        and then Column <= Natural (D.Blocks.Element (Block.Index).Alignments.Length)
      then
         return D.Blocks.Element (Block.Index).Alignments.Element (Column);
      end if;
      return Unspecified;
   end Table_Alignment_At;

   function Table_Column_Count
     (D : Document; Block : Block_Id) return Natural is
   begin
      if Is_Valid (D, Block)
        and then D.Blocks.Element (Block.Index).Kind = Table
      then
         return D.Blocks.Element (Block.Index).Column_Count;
      end if;
      return 0;
   end Table_Column_Count;

   function Table_Row_Count (D : Document; Table : Block_Id) return Natural is
   begin
      if Is_Valid (D, Table) then
         return Natural (D.Blocks.Element (Table.Index).Rows.Length);
      end if;
      return 0;
   end Table_Row_Count;

   function Table_Row_At
     (D : Document; Table : Block_Id; Position : Positive) return Table_Row_Id is
   begin
      if Is_Valid (D, Table)
        and then Position <= Natural (D.Blocks.Element (Table.Index).Rows.Length)
      then
         return D.Blocks.Element (Table.Index).Rows.Element (Position);
      end if;
      return No_Table_Row;
   end Table_Row_At;

   function Table_Row_Is_Header
     (D : Document; Row : Table_Row_Id) return Boolean is
   begin
      if Is_Valid (D, Row) then
         return D.Rows.Element (Row.Index).Is_Header;
      end if;
      return False;
   end Table_Row_Is_Header;

   function Set_Table_Row_Source
     (D : in out Document; Row : Table_Row_Id; Source : String)
     return Boolean is
   begin
      if not Is_Valid (D, Row) then
         return False;
      end if;
      D.Rows.Reference (Row.Index).Source := To_Unbounded_String (Source);
      return True;
   end Set_Table_Row_Source;

   function Table_Row_Source
     (D : Document; Row : Table_Row_Id) return String is
   begin
      if Is_Valid (D, Row) then
         return To_String (D.Rows.Element (Row.Index).Source);
      end if;
      return "";
   end Table_Row_Source;

   function Table_Cell_Count (D : Document; Row : Table_Row_Id) return Natural is
   begin
      if Is_Valid (D, Row) then
         return Natural (D.Rows.Element (Row.Index).Cells.Length);
      end if;
      return 0;
   end Table_Cell_Count;

   function Table_Cell_At
     (D : Document; Row : Table_Row_Id; Position : Positive)
      return Table_Cell_Id is
   begin
      if Is_Valid (D, Row)
        and then Position <= Natural (D.Rows.Element (Row.Index).Cells.Length)
      then
         return D.Rows.Element (Row.Index).Cells.Element (Position);
      end if;
      return No_Table_Cell;
   end Table_Cell_At;

   function Table_Cell_Source
     (D : Document; Cell : Table_Cell_Id) return String is
   begin
      if Is_Valid (D, Cell) then
         return To_String (D.Cells.Element (Cell.Index).Source);
      end if;
      return "";
   end Table_Cell_Source;

   function Table_Cell_Value
     (D : Document; Cell : Table_Cell_Id) return String is
   begin
      if Is_Valid (D, Cell) then
         return To_String (D.Cells.Element (Cell.Index).Value);
      end if;
      return "";
   end Table_Cell_Value;

   function Table_Cell_Inline_Count
     (D : Document; Cell : Table_Cell_Id) return Natural is
   begin
      if Is_Valid (D, Cell) then
         return Natural (D.Cells.Element (Cell.Index).Inlines.Length);
      end if;
      return 0;
   end Table_Cell_Inline_Count;

   function Table_Cell_Inline_At
     (D : Document; Cell : Table_Cell_Id; Position : Positive)
      return Inline_Id is
   begin
      if Is_Valid (D, Cell)
        and then Position <= Natural (D.Cells.Element (Cell.Index).Inlines.Length)
      then
         return D.Cells.Element (Cell.Index).Inlines.Element (Position);
      end if;
      return No_Inline;
   end Table_Cell_Inline_At;

   function Inline_Kind_Of
     (D : Document; Inline : Inline_Id) return Inline_Kind is
   begin
      if Is_Valid (D, Inline) then
         return D.Inlines.Element (Inline.Index).Kind;
      end if;
      return Text;
   end Inline_Kind_Of;

   function Inline_Source
     (D : Document; Inline : Inline_Id) return String is
   begin
      if Is_Valid (D, Inline) then
         return To_String (D.Inlines.Element (Inline.Index).Source);
      end if;
      return "";
   end Inline_Source;

   function Inline_Value
     (D : Document; Inline : Inline_Id) return String is
   begin
      if Is_Valid (D, Inline) then
         return To_String (D.Inlines.Element (Inline.Index).Value);
      end if;
      return "";
   end Inline_Value;

   function Inline_URL
     (D : Document; Link : Inline_Id) return String is
   begin
      if Is_Valid (D, Link) then
         return To_String (D.Inlines.Element (Link.Index).URL);
      end if;
      return "";
   end Inline_URL;

   function Inline_Child_Count
     (D : Document; Inline : Inline_Id) return Natural is
   begin
      if Is_Valid (D, Inline) then
         return Natural (D.Inlines.Element (Inline.Index).Children.Length);
      end if;
      return 0;
   end Inline_Child_Count;

   function Inline_Child_At
     (D : Document; Inline : Inline_Id; Position : Positive) return Inline_Id is
   begin
      if Is_Valid (D, Inline)
        and then Position <= Natural (D.Inlines.Element (Inline.Index).Children.Length)
      then
         return D.Inlines.Element (Inline.Index).Children.Element (Position);
      end if;
      return No_Inline;
   end Inline_Child_At;

end Coyote_Renderer.Semantics;
