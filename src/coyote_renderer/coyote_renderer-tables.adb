--  Coyote_Renderer.Tables body.
--
--  Table nodes are copied into Ada containers before the cmark document is
--  released.  The masked source keeps the original block order available to
--  the GTK response builder without exposing cmark pointers.
--
--  Project: coyote

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_Cmark;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Coyote_Renderer.Tables is

   use type Interfaces.C.int;
   use type System.Address;

   function Parse_Source (Markdown : String) return Coyote_Cmark.Node_Ptr is
      C_Text : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (Markdown, Append_Nul => True);
   begin
      return Coyote_Cmark.Parse_Document
        (C_Text, Interfaces.C.size_t (Markdown'Length),
         Coyote_Cmark.OPT_DEFAULT);
   end Parse_Source;

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

   procedure Append_Inline_Text
     (Node   : Coyote_Cmark.Node_Ptr;
      Result : in out Unbounded_String)
   is
      Child : Coyote_Cmark.Node_Ptr;
      Name  : constant String := Type_Name (Node);
   begin
      if Name = "text" or else Name = "code" or else Name = "html_inline" then
         Append (Result, Literal (Node));
      elsif Name = "softbreak" or else Name = "linebreak" then
         Append (Result, " ");
      end if;

      Child := Coyote_Cmark.Node_First_Child (Node);
      while Child /= System.Null_Address loop
         Append_Inline_Text (Child, Result);
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
   end Append_Inline_Text;

   function Read_Cell (Node : Coyote_Cmark.Node_Ptr) return Table_Cell is
      Result : Table_Cell;
      Child  : Coyote_Cmark.Node_Ptr;
   begin
      Child := Coyote_Cmark.Node_First_Child (Node);
      while Child /= System.Null_Address loop
         Append_Inline_Text (Child, Result.Text);
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
      return Result;
   end Read_Cell;

   function Read_Row (Node : Coyote_Cmark.Node_Ptr) return Table_Row is
      Result : Table_Row;
      Child  : Coyote_Cmark.Node_Ptr;
   begin
      Result.Is_Header := Type_Name (Node) = "table_header"
        or else Coyote_Cmark.Table_Row_Is_Header (Node) /= 0;
      Child := Coyote_Cmark.Node_First_Child (Node);
      while Child /= System.Null_Address loop
         if Type_Name (Child) = "table_cell" then
            Result.Cells.Append (Read_Cell (Child));
         end if;
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
      return Result;
   end Read_Row;

   function Read_Alignment
     (Node   : Coyote_Cmark.Node_Ptr;
      Column : Natural) return Table_Alignment
   is
      Value : constant Interfaces.C.int :=
        Coyote_Cmark.Table_Column_Alignment
          (Node, Interfaces.C.int (Column));
   begin
      case Integer (Value) is
         when Character'Pos ('l') => return Left;
         when Character'Pos ('c') => return Center;
         when Character'Pos ('r') => return Right;
         when others              => return Unspecified;
      end case;
   end Read_Alignment;

   function Read_Table
     (Node        : Coyote_Cmark.Node_Ptr;
      Block_Index : Positive) return Table_Block
   is
      Result       : Table_Block;
      Child        : Coyote_Cmark.Node_Ptr;
      Column_Count : constant Interfaces.C.int :=
        Coyote_Cmark.Table_Column_Count (Node);
   begin
      Result.Start_Line := Positive'Max
        (1, Integer (Coyote_Cmark.Node_Get_Start_Line (Node)));
      Result.End_Line := Positive'Max
        (Result.Start_Line,
         Integer (Coyote_Cmark.Node_Get_End_Line (Node)));
      if Column_Count > 0 then
         Result.Column_Count := Natural (Column_Count);
         for Column in 0 .. Result.Column_Count - 1 loop
            Result.Alignments.Append (Read_Alignment (Node, Column));
         end loop;
      end if;
      Result.Placeholder := To_Unbounded_String
        ("COYOTE_TABLE_BLOCK_"
         & Ada.Strings.Fixed.Trim
             (Positive'Image (Block_Index), Ada.Strings.Both)
         & "__");

      Child := Coyote_Cmark.Node_First_Child (Node);
      while Child /= System.Null_Address loop
         declare
            Name : constant String := Type_Name (Child);
         begin
            if Name = "table_header" or else Name = "table_row" then
               Result.Rows.Append (Read_Row (Child));
            end if;
         end;
         Child := Coyote_Cmark.Node_Next (Child);
      end loop;
      return Result;
   end Read_Table;

   procedure Append_Line
     (Result : in out Unbounded_String;
      Line   : String)
   is
   begin
      Append (Result, Line);
      Append (Result, ASCII.LF);
   end Append_Line;

   function Mask_Source
     (Markdown : String;
      Blocks   : Table_Vectors.Vector) return Unbounded_String
   is
      Result       : Unbounded_String;
      Start        : Natural := Markdown'First;
      Line_Number  : Positive := 1;
      Skip_Until   : Natural := 0;
      Block_Index  : Table_Vectors.Extended_Index :=
        Blocks.First_Index;
   begin
      if Markdown'Length = 0 then
         return Result;
      end if;

      for I in Markdown'Range loop
         if Markdown (I) = ASCII.LF
           or else I = Markdown'Last
         then
            declare
               Last : constant Natural :=
                 (if Markdown (I) = ASCII.LF then I - 1 else I);
               Line : constant String :=
                 (if Last >= Start then Markdown (Start .. Last) else "");
            begin
               if Line_Number <= Skip_Until then
                  Append_Line (Result, "");
               elsif Block_Index /= Table_Vectors.No_Index
                 and then Line_Number = Blocks (Block_Index).Start_Line
               then
                  Append_Line
                    (Result, To_String (Blocks (Block_Index).Placeholder));
                  Skip_Until := Blocks (Block_Index).End_Line;
                  if Block_Index = Blocks.Last_Index then
                     Block_Index := Table_Vectors.No_Index;
                  else
                     Block_Index := Table_Vectors.Extended_Index'Succ
                       (Block_Index);
                  end if;
               else
                  Append_Line (Result, Line);
               end if;
            end;
            Start       := I + 1;
            Line_Number := Line_Number + 1;
         end if;
      end loop;
      return Result;
   end Mask_Source;

   function Extract_Tables (Markdown : String) return Extraction_Result is
      Result : Extraction_Result;
      Doc    : constant Coyote_Cmark.Node_Ptr := Parse_Source (Markdown);
      It     : Coyote_Cmark.Iter_Ptr;
      Event  : Coyote_Cmark.Event_Type_Int;
      Node   : Coyote_Cmark.Node_Ptr;
   begin
      if Markdown'Length = 0 then
         return Result;
      end if;
      if Doc = System.Null_Address then
         Result.Masked_Text := To_Unbounded_String (Markdown);
         return Result;
      end if;

      It := Coyote_Cmark.Iter_New (Doc);
      loop
         Event := Coyote_Cmark.Iter_Next (It);
         exit when Event = Coyote_Cmark.EVENT_DONE;
         if Event = Coyote_Cmark.EVENT_ENTER then
            Node := Coyote_Cmark.Iter_Get_Node (It);
            if Type_Name (Node) = "table" then
               Result.Blocks.Append
                 (Read_Table
                    (Node, Positive (Natural (Result.Blocks.Length) + 1)));
            end if;
         end if;
      end loop;
      Coyote_Cmark.Iter_Free (It);
      Coyote_Cmark.Node_Free (Doc);

      Result.Masked_Text := Mask_Source (Markdown, Result.Blocks);
      return Result;
   end Extract_Tables;

end Coyote_Renderer.Tables;
