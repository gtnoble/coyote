--  Coyote_Renderer.Markup body.
--  Project: coyote

with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_App.Utils; use Coyote_App.Utils;
with Coyote_Cmark;
with Coyote_Renderer.MathML;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Coyote_Renderer.Markup is

   package S renames Coyote_Renderer.Semantics;

   use type System.Address;
   use type Interfaces.C.int;
   use type S.Block_Id;
   use type S.Table_Cell_Id;
   use type S.List_Kind;
   procedure Ignore (Value : Boolean) is
      pragma Unreferenced (Value);
   begin
      null;
   end Ignore;

   procedure Ignore_Block (Value : S.Block_Id) is
      pragma Unreferenced (Value);
   begin
      null;
   end Ignore_Block;

   function Xml_Escape (S : String) return String is
      Result : Unbounded_String;
   begin
      for Character_Value of S loop
         case Character_Value is
            when '&' =>
               Append (Result, "&amp;");
            when '<' =>
               Append (Result, "&lt;");
            when '>' =>
               Append (Result, "&gt;");
            when others =>
               Append (Result, Character_Value);
         end case;
      end loop;
      return To_String (Result);
   end Xml_Escape;

   function Type_Name (Node : Coyote_Cmark.Node_Ptr) return String is
   begin
      return Interfaces.C.Strings.Value
        (Coyote_Cmark.Node_Get_Type_String (Node));
   end Type_Name;

   function Literal (Node : Coyote_Cmark.Node_Ptr) return String is
   begin
      return Interfaces.C.Strings.Value
        (Coyote_Cmark.Node_Get_Literal (Node));
   end Literal;

   function URL (Node : Coyote_Cmark.Node_Ptr) return String is
   begin
      return Interfaces.C.Strings.Value
        (Coyote_Cmark.Node_Get_URL (Node));
   end URL;

   function Fence_Info (Node : Coyote_Cmark.Node_Ptr) return String is
   begin
      return Interfaces.C.Strings.Value
        (Coyote_Cmark.Node_Get_Fence_Info (Node));
   end Fence_Info;

   function Parse_Source (Markdown : String) return Coyote_Cmark.Node_Ptr is
      C_Text : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Markdown, Append_Nul => True);
   begin
      return Coyote_Cmark.Parse_Document
        (C_Text, Interfaces.C.size_t (Markdown'Length),
         Coyote_Cmark.OPT_DEFAULT);
   end Parse_Source;

   function Lines
     (Markdown : String; First_Line, Last_Line : Positive) return String
   is
      Line_Number : Positive := 1;
      Start       : Natural := Markdown'First;
      Result      : Unbounded_String;
   begin
      if Markdown'Length = 0 or else Last_Line < First_Line then
         return "";
      end if;
      for Position in Markdown'Range loop
         if Markdown (Position) = Ada.Characters.Latin_1.LF
           or else Position = Markdown'Last
         then
            declare
               Line_Last : constant Natural :=
                 (if Markdown (Position) = Ada.Characters.Latin_1.LF
                  then Position - 1
                  else Position);
            begin
               if Line_Number in First_Line .. Last_Line
                 and then Line_Last >= Start
               then
                  Append (Result, Markdown (Start .. Line_Last));
                  if Line_Number < Last_Line then
                     Append (Result, Ada.Characters.Latin_1.LF);
                  end if;
               end if;
            end;
            exit when Line_Number = Last_Line;
            Line_Number := Line_Number + 1;
            Start := Position + 1;
         end if;
      end loop;
      return To_String (Result);
   end Lines;

   function Node_Source
     (Markdown : String; Node : Coyote_Cmark.Node_Ptr) return String
   is
      First_Line : constant Interfaces.C.int :=
        Coyote_Cmark.Node_Get_Start_Line (Node);
      Last_Line : constant Interfaces.C.int :=
        Coyote_Cmark.Node_Get_End_Line (Node);
   begin
      if First_Line > 0 and then Last_Line >= First_Line then
         return Lines (Markdown, Positive (First_Line), Positive (Last_Line));
      end if;
      return "";
   end Node_Source;

   function Plain_Text (Node : Coyote_Cmark.Node_Ptr) return String is
      Name : constant String := Type_Name (Node);
      Child : Coyote_Cmark.Node_Ptr :=
        Coyote_Cmark.Node_First_Child (Node);
      Result : Unbounded_String;
   begin
      if Name = "text" or else Name = "code" then
         Append (Result, Literal (Node));
      elsif Name = "softbreak" or else Name = "linebreak" then
         Append (Result, " ");
      end if;
      while Child /= System.Null_Address loop
         Append (Result, Plain_Text (Child));
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
      return To_String (Result);
   end Plain_Text;

   function Add_Nested_Inline_Children
     (D : in out S.Document; Parent : S.Inline_Id;
      Node : Coyote_Cmark.Node_Ptr) return Boolean;

   function Add_Inline
     (D : in out S.Document; Block : S.Block_Id; Cell : S.Table_Cell_Id;
      Node : Coyote_Cmark.Node_Ptr) return Boolean
   is
      Name : constant String := Type_Name (Node);
      Kind : S.Inline_Kind;
      Item : S.Inline_Id;
      Value : constant String := Literal (Node);
      Result : Boolean;
   begin
      if Name = "html_inline" or else Name = "image" then
         return True;
      elsif Name = "text" then
         Kind := S.Text;
      elsif Name = "strong" then
         Kind := S.Strong;
      elsif Name = "emph" then
         Kind := S.Emphasis;
      elsif Name = "strikethrough" then
         Kind := S.Deletion;
      elsif Name = "link" then
         Kind := S.Link;
      elsif Name = "code" then
         Kind := S.Inline_Code;
      elsif Name = "softbreak" then
         Kind := S.Soft_Line_Break;
      elsif Name = "linebreak" then
         Kind := S.Hard_Line_Break;
      else
         return True;
      end if;

      Item := S.New_Inline
        (D, Kind,
         (if Name in "strong" | "emph" | "strikethrough" | "link"
          then ""
          else Value),
         Value);
      if Cell /= S.No_Table_Cell then
         Result := S.Append_Inline (D, Cell, Item);
      else
         Result := S.Append_Inline (D, Block, Item);
      end if;
      if Name = "link" then
         Ignore (S.Set_Link_URL (D, Item, URL (Node)));
      end if;
      if Name in "strong" | "emph" | "strikethrough" | "link" then
         return Add_Nested_Inline_Children (D, Item, Node) and then Result;
      end if;
      return Result;
   end Add_Inline;

   function Add_Inline_Children
     (D : in out S.Document; Block : S.Block_Id; Cell : S.Table_Cell_Id;
      Node : Coyote_Cmark.Node_Ptr) return Boolean
   is
      Child : Coyote_Cmark.Node_Ptr :=
        Coyote_Cmark.Node_First_Child (Node);
      Result : Boolean := True;
   begin
      while Child /= System.Null_Address loop
         Result := Add_Inline (D, Block, Cell, Child) and then Result;
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
      return Result;
   end Add_Inline_Children;

   function Add_Nested_Inline_Children
     (D : in out S.Document; Parent : S.Inline_Id;
      Node : Coyote_Cmark.Node_Ptr) return Boolean
   is
      Child : Coyote_Cmark.Node_Ptr :=
        Coyote_Cmark.Node_First_Child (Node);
      Result : Boolean := True;
   begin
      while Child /= System.Null_Address loop
         declare
            Name : constant String := Type_Name (Child);
            Kind : S.Inline_Kind;
            Item : S.Inline_Id;
         begin
            if Name = "text" then
               Kind := S.Text;
            elsif Name = "strong" then
               Kind := S.Strong;
            elsif Name = "emph" then
               Kind := S.Emphasis;
            elsif Name = "strikethrough" then
               Kind := S.Deletion;
            elsif Name = "link" then
               Kind := S.Link;
            elsif Name = "code" then
               Kind := S.Inline_Code;
            elsif Name = "softbreak" then
               Kind := S.Soft_Line_Break;
            elsif Name = "linebreak" then
               Kind := S.Hard_Line_Break;
            else
               Kind := S.Text;
            end if;
            if Name /= "html_inline" and then Name /= "image" then
               Item := S.New_Inline
                 (D, Kind,
                  (if Name in "strong" | "emph" | "strikethrough" | "link"
                   then ""
                   else Literal (Child)),
                  Literal (Child));
               Result := S.Append_Inline (D, Parent, Item) and then Result;
               if Name = "link" then
                  Ignore (S.Set_Link_URL (D, Item, URL (Child)));
               end if;
               if Name in "strong" | "emph" | "strikethrough" | "link" then
                  Result := Add_Nested_Inline_Children (D, Item, Child)
                    and then Result;
               end if;
            end if;
         end;
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
      return Result;
   end Add_Nested_Inline_Children;

   function Table_Alignment
     (Node : Coyote_Cmark.Node_Ptr; Column : Natural)
      return S.Table_Alignment
   is
      Value : constant Interfaces.C.int :=
        Coyote_Cmark.Table_Column_Alignment
          (Node, Interfaces.C.int (Column));
   begin
      case Integer (Value) is
         when Character'Pos ('l') =>
            return S.Left;
         when Character'Pos ('c') =>
            return S.Center;
         when Character'Pos ('r') =>
            return S.Right;
         when others =>
            return S.Unspecified;
      end case;
   end Table_Alignment;

   function Build_Block
     (D : in out S.Document; Markdown : String;
      Node : Coyote_Cmark.Node_Ptr; Parent : S.Block_Id := S.No_Block)
      return S.Block_Id;

   function Build_Table
     (D : in out S.Document; Markdown : String;
      Node : Coyote_Cmark.Node_Ptr; Parent : S.Block_Id) return S.Block_Id
   is
      Table : constant S.Block_Id := S.New_Block
        (D, S.Table, Node_Source (Markdown, Node));
      Row_Node : Coyote_Cmark.Node_Ptr :=
        Coyote_Cmark.Node_First_Child (Node);
      Column_Count : constant Interfaces.C.int :=
        Coyote_Cmark.Table_Column_Count (Node);
   begin
      if Parent = S.No_Block then
         Ignore (S.Append_Block (D, Table));
      else
         Ignore (S.Append_Block (D, Parent, Table));
      end if;
      if Column_Count > 0 then
         for Column in 0 .. Natural (Column_Count) - 1 loop
            Ignore (S.Set_Table_Alignment
              (D, Table, Column + 1, Table_Alignment (Node, Column)));
         end loop;
      end if;
      while Row_Node /= System.Null_Address loop
         if Type_Name (Row_Node) = "table_header"
           or else Type_Name (Row_Node) = "table_row"
         then
            declare
               Row : constant S.Table_Row_Id := S.New_Table_Row
                 (D, Table,
                  Type_Name (Row_Node) = "table_header"
                  or else Coyote_Cmark.Table_Row_Is_Header (Row_Node) /= 0);
               Cell_Node : Coyote_Cmark.Node_Ptr :=
                 Coyote_Cmark.Node_First_Child (Row_Node);
            begin
               Ignore (S.Set_Table_Row_Source
                 (D, Row, Node_Source (Markdown, Row_Node)));
               while Cell_Node /= System.Null_Address loop
                  if Type_Name (Cell_Node) = "table_cell" then
                     declare
                        Cell : constant S.Table_Cell_Id := S.New_Table_Cell
                          (D, Row, Plain_Text (Cell_Node),
                           Node_Source (Markdown, Cell_Node));
                     begin
                        Ignore (Add_Inline_Children
                          (D, S.No_Block, Cell, Cell_Node));
                     end;
                  end if;
                  Cell_Node := Coyote_Cmark.Node_Next (Cell_Node);
               end loop;
            end;
         end if;
         Row_Node := Coyote_Cmark.Node_Next (Row_Node);
      end loop;
      return Table;
   end Build_Table;

   function Build_Block
     (D : in out S.Document; Markdown : String;
      Node : Coyote_Cmark.Node_Ptr; Parent : S.Block_Id := S.No_Block)
      return S.Block_Id
   is
      Name : constant String := Type_Name (Node);
      Kind : S.Block_Kind;
      Block : S.Block_Id;
      Child : Coyote_Cmark.Node_Ptr;
   begin
      if Name = "table" then
         return Build_Table (D, Markdown, Node, Parent);
      elsif Name = "paragraph" then
         Kind := S.Paragraph;
      elsif Name = "heading" then
         Kind := S.Heading;
      elsif Name = "block_quote" then
         Kind := S.Blockquote;
      elsif Name = "list" then
         Kind := S.List;
      elsif Name = "item" then
         Kind := S.List_Item;
      elsif Name = "code_block" then
         Kind := S.Code_Block;
      elsif Name = "thematic_break" then
         Kind := S.Horizontal_Rule;
      else
         return S.No_Block;
      end if;

      Block := S.New_Block (D, Kind, Node_Source (Markdown, Node));
      if Parent = S.No_Block then
         Ignore (S.Append_Block (D, Block));
      else
         Ignore (S.Append_Block (D, Parent, Block));
      end if;
      if Name = "heading" then
         Ignore (S.Set_Heading_Level
           (D, Block,
            Positive (Coyote_Cmark.Node_Get_Heading_Level (Node))));
      elsif Name = "list" then
         Ignore (S.Set_List_Attributes
           (D, Block,
            (if Coyote_Cmark.Node_Get_List_Type (Node)
                 = Coyote_Cmark.LIST_ORDERED
             then S.Ordered_List
             else S.Unordered_List),
            Positive'Max
              (1, Integer (Coyote_Cmark.Node_Get_List_Start (Node)))));
      elsif Name = "code_block" then
         Ignore (S.Set_Code_Block_Data
           (D, Block, Literal (Node), Fence_Info (Node)));
      end if;
      if Name = "paragraph" or else Name = "heading" then
         Ignore (Add_Inline_Children
           (D, Block, S.No_Table_Cell, Node));
      end if;
      Child := Coyote_Cmark.Node_First_Child (Node);
      while Child /= System.Null_Address loop
         if Name = "block_quote" or else Name = "list"
           or else Name = "item"
         then
            if Type_Name (Child) in "paragraph" | "heading" | "block_quote"
              | "list" | "item" | "code_block" | "table"
              | "thematic_break"
            then
               if Name = "item"
                 and then Type_Name (Child) = "paragraph"
                 and then S.Block_Inline_Count (D, Block) = 0
               then
                  Ignore (Add_Inline_Children
                    (D, Block, S.No_Table_Cell, Child));
               else
                  Ignore_Block (Build_Block (D, Markdown, Child, Block));
               end if;
            end if;
         end if;
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
      return Block;
   end Build_Block;

   function Math_Token (Index : Positive) return String is
   begin
      return "COYOTE_MATH_BLOCK_"
        & Ada.Strings.Fixed.Trim
          (Positive'Image (Index), Ada.Strings.Both)
        & "__";
   end Math_Token;

   function Parse_Markdown
     (Markdown : String; Target : in out S.Document;
      Include_Display_Math : Boolean := True) return Boolean
   is
      Extraction : Coyote_Renderer.MathML.Extraction_Result;
      Source : Unbounded_String;
      Doc : Coyote_Cmark.Node_Ptr;
      Child : Coyote_Cmark.Node_Ptr;
      Math_Index : Positive := 1;
   begin
      S.Clear (Target);
      if Markdown'Length = 0 then
         return True;
      end if;
      if Include_Display_Math then
         Extraction := Coyote_Renderer.MathML.Extract_Display_Math (Markdown);
         Source := Extraction.Masked_Text;
      else
         Source := To_Unbounded_String (Markdown);
      end if;
      Doc := Parse_Source (To_String (Source));
      if Doc = System.Null_Address then
         return False;
      end if;
      Child := Coyote_Cmark.Node_First_Child (Doc);
      while Child /= System.Null_Address loop
         if Include_Display_Math
           and then not Extraction.Blocks.Is_Empty
           and then Math_Index <= Positive (Extraction.Blocks.Length)
         then
            declare
               First : constant Coyote_Cmark.Node_Ptr :=
                 Coyote_Cmark.Node_First_Child (Child);
            begin
               if Type_Name (Child) = "paragraph"
                 and then First /= System.Null_Address
                 and then Type_Name (First) = "text"
                 and then Literal (First) = Math_Token (Math_Index)
               then
                  declare
                     Math : constant S.Block_Id := S.New_Block
                       (Target, S.Display_Math,
                        To_String (Extraction.Blocks (Math_Index).Source));
                  begin
                     Ignore (S.Set_Display_Math_Data
                       (Target, Math,
                        To_String (Extraction.Blocks (Math_Index).MathML)));
                     Ignore (S.Append_Block (Target, Math));
                  end;
                  Math_Index := Math_Index + 1;
               else
                  Ignore_Block
                    (Build_Block (Target, Markdown, Child));
               end if;
            end;
         else
            Ignore_Block (Build_Block (Target, Markdown, Child));
         end if;
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
      Coyote_Cmark.Node_Free (Doc);
      return True;
   end Parse_Markdown;

   procedure Render_Inline
     (D : S.Document; Item : S.Inline_Id;
      Output : in out Unbounded_String; In_Cell : Boolean := False);

   procedure Render_Inline_Children
     (D : S.Document; Item : S.Inline_Id;
      Output : in out Unbounded_String) is
   begin
      for Position in 1 .. S.Inline_Child_Count (D, Item) loop
         Render_Inline
           (D, S.Inline_Child_At (D, Item, Position), Output);
      end loop;
   end Render_Inline_Children;

   procedure Render_Inline
     (D : S.Document; Item : S.Inline_Id;
      Output : in out Unbounded_String; In_Cell : Boolean := False)
   is
      Kind : constant S.Inline_Kind := S.Inline_Kind_Of (D, Item);
      Value : constant String := S.Inline_Value (D, Item);
   begin
      case Kind is
         when S.Text =>
            Append (Output, Xml_Escape (Value));
         when S.Strong =>
            if not In_Cell then
               Append (Output, "<b>");
               Render_Inline_Children (D, Item, Output);
               Append (Output, "</b>");
            end if;
         when S.Emphasis =>
            if not In_Cell then
               Append (Output, "<i>");
               Render_Inline_Children (D, Item, Output);
               Append (Output, "</i>");
            end if;
         when S.Deletion =>
            if not In_Cell then
               Append (Output, "<s>");
               Render_Inline_Children (D, Item, Output);
               Append (Output, "</s>");
            end if;
         when S.Link =>
            if not In_Cell then
               Append (Output, "<u>");
               Render_Inline_Children (D, Item, Output);
               Append (Output, "</u>");
            end if;
         when S.Inline_Code =>
            if In_Cell then
               Append (Output, Xml_Escape (Value));
            else
               Append (Output, "<tt>" & Xml_Escape (Value) & "</tt>");
            end if;
         when S.Raw_Markup =>
            Append (Output, Xml_Escape (Value));
         when S.Soft_Line_Break =>
            Append (Output, " ");
         when S.Hard_Line_Break =>
            Append (Output, Ada.Characters.Latin_1.LF);
      end case;
   end Render_Inline;

   function To_Pango_Markup (MD_Text : String) return String is
      D : S.Document;
      Output : Unbounded_String;
      Depth : Natural := 0;
      Counters : array (0 .. 7) of Integer := (others => 0);
      Bullets : array (0 .. 7) of Boolean := (others => True);
      function Stack_Index return Natural is
      begin
         return Natural'Min (Depth, 7);
      end Stack_Index;
      procedure Render_Block (Block : S.Block_Id);

      procedure Render_Table (Block : S.Block_Id) is
         Columns : constant Natural := Natural'Min
           (16, S.Table_Column_Count (D, Block));
         Rows : constant Natural := Natural'Min
           (256, S.Table_Row_Count (D, Block));
         Widths : array (0 .. 15) of Natural := (others => 0);
         function Pad (Value : String; Width : Natural) return String is
            Count : constant Natural := Natural'Min (Value'Length, Width);
            Result : String (1 .. Width) := (others => ' ');
         begin
            if Count > 0 then
               Result (1 .. Count) :=
                 Value (Value'First .. Value'First + Count - 1);
            end if;
            return Result;
         end Pad;
         procedure Rule (Left, Join, Right : String) is
         begin
            Append (Output, Left);
            for Column in 0 .. Columns - 1 loop
               for Count in 1 .. Widths (Column) + 2 loop
                  Append (Output, UC_HORIZ);
               end loop;
               if Column < Columns - 1 then
                  Append (Output, Join);
               end if;
            end loop;
            Append (Output, Right & Ada.Characters.Latin_1.LF);
         end Rule;
      begin
         if Columns = 0 or else Rows = 0 then
            return;
         end if;
         for Column in 0 .. Columns - 1 loop
            for Row_Number in 1 .. Rows loop
               declare
                  Row : constant S.Table_Row_Id :=
                    S.Table_Row_At (D, Block, Row_Number);
                  Cell : constant S.Table_Cell_Id :=
                    S.Table_Cell_At (D, Row, Column + 1);
               begin
                  Widths (Column) := Natural'Max
                    (Widths (Column), Natural'Min
                      (35, S.Table_Cell_Value (D, Cell)'Length));
               end;
            end loop;
         end loop;
         Append (Output, "<tt>");
         Rule (UC_BOX_TL, UC_BOX_T, UC_BOX_TR);
         for Row_Number in 1 .. Rows loop
            declare
               Row : constant S.Table_Row_Id :=
                 S.Table_Row_At (D, Block, Row_Number);
            begin
               Append (Output, UC_BOX_V);
               for Column in 0 .. Columns - 1 loop
                  declare
                     Cell : constant S.Table_Cell_Id :=
                       S.Table_Cell_At (D, Row, Column + 1);
                  begin
                     Append (Output, " " & Xml_Escape
                       (Pad (S.Table_Cell_Value (D, Cell), Widths (Column)))
                       & " " & UC_BOX_V);
                  end;
               end loop;
               Append (Output, Ada.Characters.Latin_1.LF);
               if Row_Number = 1 and then Rows > 1 then
                  Rule (UC_BOX_L, UC_BOX_X, UC_BOX_R);
               end if;
            end;
         end loop;
         Rule (UC_BOX_BL, UC_BOX_B, UC_BOX_BR);
         Append (Output, "</tt>" & Ada.Characters.Latin_1.LF);
      end Render_Table;

      procedure Render_Inlines (Block : S.Block_Id) is
      begin
         for Position in 1 .. S.Block_Inline_Count (D, Block) loop
            Render_Inline
              (D, S.Block_Inline_At (D, Block, Position), Output);
         end loop;
      end Render_Inlines;

      procedure Render_Block (Block : S.Block_Id) is
         Kind : constant S.Block_Kind := S.Block_Kind_Of (D, Block);
      begin
         case Kind is
            when S.Table =>
               Render_Table (Block);
            when S.Paragraph =>
               Render_Inlines (Block);
               Append (Output, Ada.Characters.Latin_1.LF
                 & Ada.Characters.Latin_1.LF);
            when S.Heading =>
               declare
                  H : constant Natural := S.Heading_Level_Of (D, Block);
               begin
                  if H <= 2 then
                     Append (Output, Ada.Characters.Latin_1.LF
                       & "<span weight=""bold"" size=""larger"">");
                  elsif H <= 4 then
                     Append (Output, Ada.Characters.Latin_1.LF
                       & "<span weight=""bold"" size=""medium"">");
                  else
                     Append (Output, Ada.Characters.Latin_1.LF
                       & "<span weight=""bold"">");
                  end if;
                  Render_Inlines (Block);
                  Append (Output, "</span>" & Ada.Characters.Latin_1.LF
                    & Ada.Characters.Latin_1.LF);
               end;
            when S.Blockquote =>
               Append (Output, Ada.Characters.Latin_1.LF
                 & "<span alpha=""50%%"" font_style=""italic"">"
                 & UC_BOX_V & " ");
               for Position in 1 .. S.Block_Child_Count (D, Block) loop
                  Render_Block (S.Block_Child_At (D, Block, Position));
               end loop;
               Append (Output, "</span>" & Ada.Characters.Latin_1.LF
                 & Ada.Characters.Latin_1.LF);
            when S.List =>
               if Depth < 7 then
                  Depth := Depth + 1;
                  Counters (Stack_Index) :=
                    Integer (S.List_Start (D, Block)) - 1;
                  Bullets (Stack_Index) :=
                    S.List_Kind_Of (D, Block) = S.Unordered_List;
               end if;
               for Position in 1 .. S.Block_Child_Count (D, Block) loop
                  Render_Block (S.Block_Child_At (D, Block, Position));
               end loop;
               if Depth > 0 then
                  Depth := Depth - 1;
               end if;
               Append (Output, Ada.Characters.Latin_1.LF);
            when S.List_Item =>
               if Depth > 0 then
                  declare
                     Indent : constant Positive :=
                       Positive'Max (1, Depth);
                  begin
                     if Indent > 1 then
                        Append (Output, Str_Repeat ("  ", Indent - 1));
                     end if;
                  end;
                  if Bullets (Stack_Index) then
                     Append (Output, UC_BULLET & " ");
                  else
                     Counters (Stack_Index) := Counters (Stack_Index) + 1;
                     Append
                       (Output,
                        Ada.Strings.Fixed.Trim
                          (Integer'Image (Counters (Stack_Index)),
                           Ada.Strings.Left)
                        & ". ");
                  end if;
               end if;
               Render_Inlines (Block);
               for Position in 1 .. S.Block_Child_Count (D, Block) loop
                  Render_Block (S.Block_Child_At (D, Block, Position));
               end loop;
            when S.Code_Block =>
               Append (Output, Ada.Characters.Latin_1.LF
                 & "<span background=""#f4f4f4""><tt>"
                 & Xml_Escape (S.Code_Literal (D, Block))
                 & "</tt></span>" & Ada.Characters.Latin_1.LF);
            when S.Horizontal_Rule =>
               Append (Output, "<span alpha=""50%%"">"
                 & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
                 & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
                 & UC_HORIZ & UC_HORIZ & "</span>"
                 & Ada.Characters.Latin_1.LF);
            when S.Display_Math | S.Invalid_Source =>
               null;
         end case;
      end Render_Block;
   begin
      if MD_Text'Length = 0 then
         return "";
      end if;
      if not Parse_Markdown
        (MD_Text, D, Include_Display_Math => False)
      then
         return Xml_Escape (MD_Text);
      end if;
      for Position in 1 .. S.Block_Count (D) loop
         Render_Block (S.Block_At (D, Position));
      end loop;
      return To_String (Output);
   end To_Pango_Markup;

end Coyote_Renderer.Markup;
