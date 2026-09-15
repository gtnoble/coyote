--  Coyote_GUI.Response_Renderer body.
--
--  Project: coyote

with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_App.Utils;      use Coyote_App.Utils;
with Coyote_GUI.Math_Element;
with Coyote_Renderer.Markup;
with Coyote_Renderer.MathML;
with Coyote_Renderer.Incremental;
with Coyote_Renderer.Semantics;
with Glib;                  use Glib;
with Glib.Error;
with Gtk.Box;
with Gtk.Container;
with Gtk.Css_Provider;
with Gtk.Enums;
with Gtk.Grid;
with Gtk.Label;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;
with Pango.Font;

package body Coyote_GUI.Response_Renderer is

   use type Gtk.Box.Gtk_Box;
   use type Gtk.Grid.Gtk_Grid;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Widget.Gtk_Widget;
   use type Gtk.Widget.Widget_List.Glist;
   use type Coyote_GUI.Math_Element.Instance_Access;
   use type Coyote_Renderer.Semantics.Block_Id;
   use type Coyote_Renderer.Semantics.Inline_Id;
   use type Coyote_Renderer.Semantics.Block_Kind;
   use type Coyote_Renderer.Semantics.List_Kind;
   use type Coyote_Renderer.Semantics.Table_Alignment;

   Response_Box_Spacing   : constant Gint  := 2;
   Response_Block_Padding : constant Guint := 4;

   type Counter_Array is array (Natural range <>) of Integer;
   type Bullet_Array is array (Natural range <>) of Boolean;

   function Ends_With_Line_Feed (Output : Unbounded_String) return Boolean is
   begin
      return Length (Output) > 0
        and then Element (Output, Length (Output)) =
          Ada.Characters.Latin_1.LF;
   end Ends_With_Line_Feed;

   function Needs_Leading_Line_Feed
     (Kind : Coyote_Renderer.Semantics.Block_Kind) return Boolean
   is
      package S renames Coyote_Renderer.Semantics;
   begin
      return Kind in S.Paragraph | S.List | S.Table
        | S.Horizontal_Rule | S.Invalid_Source;
   end Needs_Leading_Line_Feed;

   procedure Render_Inline
     (D      :        Coyote_Renderer.Semantics.Document;
      Item   :        Coyote_Renderer.Semantics.Inline_Id;
      Output : in out Unbounded_String);

   procedure Render_Inline_Children
     (D      :        Coyote_Renderer.Semantics.Document;
      Item   :        Coyote_Renderer.Semantics.Inline_Id;
      Output : in out Unbounded_String)
   is
   begin
      for Position in
        1 .. Coyote_Renderer.Semantics.Inline_Child_Count (D, Item)
      loop
         Render_Inline
           (D, Coyote_Renderer.Semantics.Inline_Child_At (D, Item, Position),
            Output);
      end loop;
   end Render_Inline_Children;

   procedure Render_Inline
     (D      :        Coyote_Renderer.Semantics.Document;
      Item   :        Coyote_Renderer.Semantics.Inline_Id;
      Output : in out Unbounded_String)
   is
      package S renames Coyote_Renderer.Semantics;
      Kind  : constant S.Inline_Kind := S.Inline_Kind_Of (D, Item);
      Value : constant String        := S.Inline_Value (D, Item);
   begin
      case Kind is
         when S.Text =>
            Append (Output, Coyote_Renderer.Markup.Xml_Escape (Value));
         when S.Strong =>
            Append (Output, "<b>");
            Render_Inline_Children (D, Item, Output);
            Append (Output, "</b>");
         when S.Emphasis =>
            Append (Output, "<i>");
            Render_Inline_Children (D, Item, Output);
            Append (Output, "</i>");
         when S.Deletion =>
            Append (Output, "<s>");
            Render_Inline_Children (D, Item, Output);
            Append (Output, "</s>");
         when S.Link =>
            Append (Output, "<u>");
            Render_Inline_Children (D, Item, Output);
            Append (Output, "</u>");
         when S.Inline_Code =>
            Append
              (Output,
               "<tt>" & Coyote_Renderer.Markup.Xml_Escape (Value) & "</tt>");
         when S.Raw_Markup =>
            Append (Output, Coyote_Renderer.Markup.Xml_Escape (Value));
         when S.Soft_Line_Break =>
            Append (Output, " ");
         when S.Hard_Line_Break =>
            Append (Output, Ada.Characters.Latin_1.LF);
      end case;
   end Render_Inline;

   procedure Render_Block
     (D        :        Coyote_Renderer.Semantics.Document;
      Block    :        Coyote_Renderer.Semantics.Block_Id;
      Output   : in out Unbounded_String; Depth : in out Natural;
      Counters : in out Counter_Array; Bullets : in out Bullet_Array);

   procedure Render_Inline_Block
     (D      :        Coyote_Renderer.Semantics.Document;
      Block  :        Coyote_Renderer.Semantics.Block_Id;
      Output : in out Unbounded_String)
   is
   begin
      for Position in
        1 .. Coyote_Renderer.Semantics.Block_Inline_Count (D, Block)
      loop
         Render_Inline
           (D, Coyote_Renderer.Semantics.Block_Inline_At (D, Block, Position),
            Output);
      end loop;
   end Render_Inline_Block;

   procedure Render_Table_Text
     (D      :        Coyote_Renderer.Semantics.Document;
      Block  :        Coyote_Renderer.Semantics.Block_Id;
      Output : in out Unbounded_String)
   is
      package S renames Coyote_Renderer.Semantics;
      Columns : constant Natural           :=
        Natural'Min (16, S.Table_Column_Count (D, Block));
      Rows    : constant Natural           :=
        Natural'Min (256, S.Table_Row_Count (D, Block));
      Widths  : array (0 .. 15) of Natural := (others => 0);
      function Pad (Value : String; Width : Natural) return String is
         Count  : constant Natural    := Natural'Min (Value'Length, Width);
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
               Row  : constant S.Table_Row_Id  :=
                 S.Table_Row_At (D, Block, Row_Number);
               Cell : constant S.Table_Cell_Id :=
                 S.Table_Cell_At (D, Row, Column + 1);
            begin
               Widths (Column) :=
                 Natural'Max
                   (Widths (Column),
                    Natural'Min (35, S.Table_Cell_Value (D, Cell)'Length));
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
                  Append
                    (Output,
                     " " &
                     Coyote_Renderer.Markup.Xml_Escape
                       (Pad (S.Table_Cell_Value (D, Cell), Widths (Column))) &
                     " " & UC_BOX_V);
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
   end Render_Table_Text;

   procedure Render_Block
     (D        :        Coyote_Renderer.Semantics.Document;
      Block    :        Coyote_Renderer.Semantics.Block_Id;
      Output   : in out Unbounded_String; Depth : in out Natural;
      Counters : in out Counter_Array; Bullets : in out Bullet_Array)
   is
      package S renames Coyote_Renderer.Semantics;
      Kind  : constant S.Block_Kind := S.Block_Kind_Of (D, Block);
      Index : constant Natural      := Natural'Min (Depth, Counters'Last);
   begin
      case Kind is
         when S.Table =>
            Render_Table_Text (D, Block, Output);
         when S.Paragraph =>
            Render_Inline_Block (D, Block, Output);
            Append
              (Output, Ada.Characters.Latin_1.LF & Ada.Characters.Latin_1.LF);
         when S.Heading =>
            declare
               Level : constant Natural := S.Heading_Level_Of (D, Block);
            begin
               Append (Output, Ada.Characters.Latin_1.LF);
               if Level <= 2 then
                  Append (Output, "<span weight=""bold"" size=""larger"">");
               elsif Level <= 4 then
                  Append (Output, "<span weight=""bold"" size=""medium"">");
               else
                  Append (Output, "<span weight=""bold"">");
               end if;
               Render_Inline_Block (D, Block, Output);
               Append
                 (Output,
                  "</span>" & Ada.Characters.Latin_1.LF &
                  Ada.Characters.Latin_1.LF);
            end;
         when S.Blockquote =>
            Append
              (Output,
               Ada.Characters.Latin_1.LF &
               "<span alpha=""50%%"" font_style=""italic"">" & UC_BOX_V & " ");
            for Position in 1 .. S.Block_Child_Count (D, Block) loop
               Render_Block
                 (D, S.Block_Child_At (D, Block, Position), Output, Depth,
                  Counters, Bullets);
            end loop;
            Append
              (Output,
               "</span>" & Ada.Characters.Latin_1.LF &
               Ada.Characters.Latin_1.LF);
         when S.List =>
            if Depth < Counters'Last then
               Depth                                         := Depth + 1;
               Counters (Natural'Min (Depth, Counters'Last)) :=
                 Integer (S.List_Start (D, Block)) - 1;
               Bullets (Natural'Min (Depth, Bullets'Last))   :=
                 S.List_Kind_Of (D, Block) = S.Unordered_List;
            end if;
            for Position in 1 .. S.Block_Child_Count (D, Block) loop
               Render_Block
                 (D, S.Block_Child_At (D, Block, Position), Output, Depth,
                  Counters, Bullets);
            end loop;
            if Depth > 0 then
               Depth := Depth - 1;
            end if;
            if not Ends_With_Line_Feed (Output) then
               Append (Output, Ada.Characters.Latin_1.LF);
            end if;
         when S.List_Item =>
            if Depth > 0 then
               if Depth > 1 then
                  Append (Output, Str_Repeat ("  ", Depth - 1));
               end if;
               if Bullets (Index) then
                  Append (Output, UC_BULLET & " ");
               else
                  Counters (Index) := Counters (Index) + 1;
                  Append
                    (Output,
                     Ada.Strings.Fixed.Trim
                       (Integer'Image (Counters (Index)), Ada.Strings.Left) &
                     ". ");
               end if;
            end if;
            Render_Inline_Block (D, Block, Output);
            for Position in 1 .. S.Block_Child_Count (D, Block) loop
               declare
                  Child : constant S.Block_Id :=
                    S.Block_Child_At (D, Block, Position);
               begin
                  if Needs_Leading_Line_Feed
                    (S.Block_Kind_Of (D, Child))
                    and then not Ends_With_Line_Feed (Output)
                  then
                     Append (Output, Ada.Characters.Latin_1.LF);
                  end if;
                  Render_Block
                    (D, Child, Output, Depth, Counters, Bullets);
               end;
            end loop;
            if not Ends_With_Line_Feed (Output) then
               Append (Output, Ada.Characters.Latin_1.LF);
            end if;
         when S.Code_Block =>
            Append
              (Output,
               Ada.Characters.Latin_1.LF &
               "<span background=""#f4f4f4""><tt>" &
               Coyote_Renderer.Markup.Xml_Escape (S.Code_Literal (D, Block)) &
               "</tt></span>" & Ada.Characters.Latin_1.LF);
         when S.Horizontal_Rule =>
            Append
              (Output,
               "<span alpha=""50%%"">" & UC_HORIZ & UC_HORIZ & UC_HORIZ &
               UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ &
               UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ & "</span>" &
               Ada.Characters.Latin_1.LF);
         when S.Display_Math =>
            null;
         when S.Invalid_Source =>
            Append (Output, Coyote_Renderer.Markup.Xml_Escape
              (S.Block_Source (D, Block)) & Ada.Characters.Latin_1.LF);
      end case;
   end Render_Block;

   procedure Add_Markup_Block
     (R      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class; Markup : String)
   is
      Section : Gtk.Box.Gtk_Box;
      Label   : Gtk.Label.Gtk_Label;
      Buffer  : Gtk.Text_Buffer.Gtk_Text_Buffer;
      View    : Gtk.Text_View.Gtk_Text_View;
      Iter    : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Markup'Length = 0 then
         return;
      end if;
      Gtk.Box.Gtk_New_Vbox (Section, Homogeneous => False, Spacing => 2);
      Gtk.Label.Gtk_New (Label, "");
      Label.Set_Xalign (0.0);
      Label.Set_Selectable (True);
      Section.Pack_Start (Label, Expand => False, Fill => False, Padding => 2);
      Gtk.Text_Buffer.Gtk_New (Buffer);
      Gtk.Text_View.Gtk_New (View, Buffer);
      Configure_Text_View (View);
      Apply_Response_Style (View);
      Buffer.Get_End_Iter (Iter);
      Buffer.Insert_Markup (Iter, Markup, -1);
      Section.Pack_Start (View, Expand => False, Fill => True, Padding => 2);
      Pack_Response_Block (Parent, Section);
      R.Text_Views.Append (View);
   end Add_Markup_Block;

   procedure Add_Table
     (R      : in out Instance;
      Parent :        not null access Gtk.Box.Gtk_Box_Record'Class;
      D      :        Coyote_Renderer.Semantics.Document;
      Block  :        Coyote_Renderer.Semantics.Block_Id)
   is
      package S renames Coyote_Renderer.Semantics;
      Grid : Gtk.Grid.Gtk_Grid;
   begin
      Gtk.Grid.Gtk_New (Grid);
      Grid.Set_Column_Spacing (12);
      Grid.Set_Row_Spacing (3);
      Grid.Set_Hexpand (True);
      Apply_Response_Style (Grid);
      for Row_Index in 1 .. S.Table_Row_Count (D, Block) loop
         declare
            Row : constant S.Table_Row_Id :=
              S.Table_Row_At (D, Block, Row_Index);
         begin
            for Column_Index in 1 .. S.Table_Cell_Count (D, Row) loop
               declare
                  Cell      : Gtk.Label.Gtk_Label;
                  Value     : constant String            :=
                    S.Table_Cell_Value
                      (D, S.Table_Cell_At (D, Row, Column_Index));
                  Alignment : constant S.Table_Alignment :=
                    S.Table_Alignment_At (D, Block, Column_Index);
               begin
                  Gtk.Label.Gtk_New (Cell);
                  if S.Table_Row_Is_Header (D, Row) then
                     Cell.Set_Markup
                       ("<b>" & Coyote_Renderer.Markup.Xml_Escape (Value) &
                        "</b>");
                  else
                     Cell.Set_Text (Value);
                  end if;
                  Cell.Set_Line_Wrap (True);
                  Cell.Set_Max_Width_Chars (35);
                  Cell.Set_Selectable (True);
                  Cell.Set_Halign (Gtk.Widget.Align_Fill);
                  case Alignment is
                     when S.Left | S.Unspecified =>
                        Cell.Set_Xalign (0.0);
                     when S.Center =>
                        Cell.Set_Xalign (0.5);
                     when S.Right =>
                        Cell.Set_Xalign (1.0);
                  end case;
                  Grid.Attach
                    (Cell, Gint (Column_Index - 1), Gint (Row_Index - 1));
                  R.Table_Cells.Append (Cell);
               end;
            end loop;
         end;
      end loop;
      Pack_Response_Block (Parent, Grid);
      R.Table_Grids.Append (Grid);
   end Add_Table;

   function Terminal_MathML (Source : String) return String is
   begin
      return Coyote_Renderer.Incremental.Normalize_Math_Source (Source);
   end Terminal_MathML;

   procedure Add_Math
     (R                       : in out Instance;
      Parent                  :        not null access Gtk.Box.Gtk_Box_Record'Class;
      D                       :        Coyote_Renderer.Semantics.Document;
      Block                   :        Coyote_Renderer.Semantics.Block_Id;
      Normalize_Terminal_Math :        Boolean := False)
   is
      package S renames Coyote_Renderer.Semantics;
      Source : constant String := S.MathML_Source (D, Block);
      MathML : constant String :=
        (if Normalize_Terminal_Math then Terminal_MathML (Source)
         else S.MathML_Value (D, Block));
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Coyote_GUI.Math_Element.New_Element
          (MathML, Source, R.Math_Scale);
   begin
      if Element = null then
         Add_Markup_Block (R, Parent, Coyote_Renderer.Markup.Xml_Escape (Source));
      else
         Pack_Response_Block
           (Parent, Coyote_GUI.Math_Element.Widget (Element.all));
         R.Math_Elements.Append (Element);
      end if;
   end Add_Math;

   procedure Add_Math_Source
     (R      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class; MathML : String;
      Source :        String)
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Coyote_GUI.Math_Element.New_Element (MathML, Source, R.Math_Scale);
   begin
      if Element = null then
         Add_Markup_Block
           (R, Parent, Coyote_Renderer.Markup.Xml_Escape (Source));
      else
         Pack_Response_Block
           (Parent, Coyote_GUI.Math_Element.Widget (Element.all));
         R.Math_Elements.Append (Element);
      end if;
   end Add_Math_Source;

   function Block_Markup
     (Document : Coyote_Renderer.Semantics.Document;
      Block    : Coyote_Renderer.Semantics.Block_Id) return String
   is
      Depth    : Natural := 0;
      Counters : Counter_Array (0 .. 7) := (others => 0);
      Bullets  : Bullet_Array (0 .. 7) := (others => True);
      Output   : Unbounded_String;
   begin
      Render_Block (Document, Block, Output, Depth, Counters, Bullets);
      return To_String (Output);
   end Block_Markup;

   procedure Render_Native_Block
     (R                       : in out Instance;
      Parent                  :        not null access Gtk.Box.Gtk_Box_Record'Class;
      Document                :        Coyote_Renderer.Semantics.Document;
      Block                   :        Coyote_Renderer.Semantics.Block_Id;
      Normalize_Terminal_Math :        Boolean := False;
      Math_Scale              :        Long_Float := 1.0)
   is
      package S renames Coyote_Renderer.Semantics;
   begin
      R.Math_Scale := Long_Float'Max (Math_Scale, 0.01);
      case S.Block_Kind_Of (Document, Block) is
         when S.Table =>
            Add_Table (R, Parent, Document, Block);
         when S.Display_Math =>
            Add_Math
              (R, Parent, Document, Block, Normalize_Terminal_Math);
         when others =>
            null;
      end case;
   end Render_Native_Block;

   procedure Apply_Response_Style     (Widget : not null access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      use Gtk.Css_Provider;
      use Gtk.Style_Context;
      use Gtk.Style_Provider;
      CSS       : constant String :=
        ".coyote-response-content { background-color: @theme_base_color; " &
        "color: @theme_text_color; }";
      Provider  : Gtk_Css_Provider;
      CSS_Error : aliased Glib.Error.GError;
      Ignored   : Boolean;
      pragma Unreferenced (Ignored);
   begin
      Gtk_New (Provider);
      Ignored := Provider.Load_From_Data (CSS, CSS_Error'Access);
      Get_Style_Context (Widget).Add_Class ("coyote-response-content");
      Get_Style_Context (Widget).Add_Provider
        (Implements_Gtk_Style_Provider.To_Interface (Provider),
         Guint (Priority_Application));
   end Apply_Response_Style;

   procedure Configure_Text_View
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
   begin
      View.Set_Editable (False);
      View.Set_Cursor_Visible (False);
      View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
      View.Set_Accepts_Tab (False);
      View.Set_Left_Margin (8);
      View.Set_Right_Margin (8);
      View.Set_Pixels_Above_Lines (2);
      View.Set_Pixels_Below_Lines (2);
   end Configure_Text_View;

   procedure Pack_Response_Block
     (Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Child  : not null access Gtk.Widget.Gtk_Widget_Record'Class)
   is
   begin
      Parent.Pack_Start
        (Child, Expand => False, Fill => True,
         Padding       => Response_Block_Padding);
   end Pack_Response_Block;

   procedure Render_Math_Fallback
     (R           : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class; Source : String;
      Active_Text :    out Gtk.Text_Buffer.Gtk_Text_Buffer;
      Active_View :    out Gtk.Text_View.Gtk_Text_View);

   procedure Render_Math_Fallback
     (R           : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class; Source : String;
      Active_Text :    out Gtk.Text_Buffer.Gtk_Text_Buffer;
      Active_View :    out Gtk.Text_View.Gtk_Text_View)
   is
      Extraction : constant Coyote_Renderer.MathML.Extraction_Result :=
        Coyote_Renderer.MathML.Extract_Display_Math (Source);
      Masked     : constant String := To_String (Extraction.Masked_Text);
      Cursor     : Positive := Masked'First;
      Start      : Positive := Masked'First;
   begin
      Active_Text := null;
      Active_View := null;
      for Index in 1 .. Natural (Extraction.Blocks.Length) loop
         declare
            Token    : constant String  :=
              "COYOTE_MATH_BLOCK_" &
              Ada.Strings.Fixed.Trim
                (Natural'Image (Index), Ada.Strings.Both) &
              "__";
            Position : constant Natural :=
              Ada.Strings.Fixed.Index (Masked, Token, Cursor);
         begin
            if Position = 0 then
               exit;
            end if;
            if Position > Start then
               Add_Markup_Block
                 (R, Parent,
                  Coyote_Renderer.Markup.To_Pango_Markup
                    (Masked (Start .. Position - 1)));
            end if;
            Add_Math_Source
              (R, Parent, To_String (Extraction.Blocks (Index).MathML),
               To_String (Extraction.Blocks (Index).Source));
            Cursor := Position + Token'Length;
            Start  := Cursor;
         end;
      end loop;
      if Masked'Length > 0 and then Start <= Masked'Last then
         Add_Markup_Block
           (R, Parent,
            Coyote_Renderer.Markup.To_Pango_Markup
              (Masked (Start .. Masked'Last)));
      end if;
      if not R.Text_Views.Is_Empty then
         Active_View := R.Text_Views (R.Text_Views.Last_Index);
         Active_Text := Active_View.Get_Buffer;
      end if;
   end Render_Math_Fallback;

   procedure Render
     (R                       : in out Instance;
      Parent                  :        not null access Gtk.Box.Gtk_Box_Record'Class;
      Document                :        Coyote_Renderer.Semantics.Document;
      Source                  :        String;
      Active_Text             :    out Gtk.Text_Buffer.Gtk_Text_Buffer;
      Active_View             :    out Gtk.Text_View.Gtk_Text_View;
      Math_Scale              :        Long_Float := 1.0;
      Use_Math_Fallback       :        Boolean := True;
      Normalize_Terminal_Math :        Boolean := False)
   is
      package S renames Coyote_Renderer.Semantics;
      Depth            : Natural := 0;
      Counters         : Counter_Array (0 .. 7) := (others => 0);
      Bullets          : Bullet_Array (0 .. 7) := (others => True);
      Markup           : Unbounded_String;
      Pending          : Unbounded_String;
      Has_Display_Math : Boolean := False;
      Extraction       : Coyote_Renderer.MathML.Extraction_Result;
   begin
      Active_Text  := null;
      Active_View  := null;
      if R.Response /= null then
         Clear (R);
      end if;
      if Use_Math_Fallback then
         Extraction := Coyote_Renderer.MathML.Extract_Display_Math (Source);
      end if;
      R.Math_Scale := Long_Float'Max (Math_Scale, 0.01);
      Gtk.Box.Gtk_New_Vbox
        (R.Response, Homogeneous => False, Spacing => Response_Box_Spacing);
      R.Response.Set_Name ("coyote-response-rendered");
      Parent.Pack_Start
        (R.Response, Expand => False, Fill => True, Padding => 2);
      for Position in 1 .. S.Block_Count (Document) loop
         Has_Display_Math :=
           Has_Display_Math
           or else
             S.Block_Kind_Of (Document, S.Block_At (Document, Position)) =
             S.Display_Math;
      end loop;
      if Use_Math_Fallback
        and then not Has_Display_Math and then not Extraction.Blocks.Is_Empty
      then
         Render_Math_Fallback
           (R, R.Response, Source, Active_Text, Active_View);
         R.Response.Show_All;
         return;
      end if;
      for Position in 1 .. S.Block_Count (Document) loop
         declare
            Block : constant S.Block_Id   := S.Block_At (Document, Position);
            Kind  : constant S.Block_Kind := S.Block_Kind_Of (Document, Block);
         begin
            case Kind is
               when S.Table =>
                  Add_Markup_Block (R, R.Response, To_String (Pending));
                  Pending := Null_Unbounded_String;
                  Add_Table (R, R.Response, Document, Block);
               when S.Display_Math =>
                  Add_Markup_Block (R, R.Response, To_String (Pending));
                  Pending := Null_Unbounded_String;
                  Add_Math
                    (R, R.Response, Document, Block,
                     Normalize_Terminal_Math);
               when others =>
                  Markup := Null_Unbounded_String;
                  Render_Block
                    (Document, Block, Markup, Depth, Counters, Bullets);
                  Append (Pending, To_String (Markup));
            end case;
         end;
      end loop;
      Add_Markup_Block (R, R.Response, To_String (Pending));
      if not R.Text_Views.Is_Empty then
         Active_View := R.Text_Views (R.Text_Views.Last_Index);
         Active_Text := Active_View.Get_Buffer;
      end if;
      R.Response.Show_All;
   end Render;

   procedure Replace
     (R                       : in out Instance;
      Parent                  :        not null access Gtk.Box.Gtk_Box_Record'Class;
      Document                :        Coyote_Renderer.Semantics.Document;
      Source                  :        String;
      Active_Text             :    out Gtk.Text_Buffer.Gtk_Text_Buffer;
      Active_View             :    out Gtk.Text_View.Gtk_Text_View;
      Math_Scale              :        Long_Float := 1.0;
      Use_Math_Fallback       :        Boolean := True;
      Normalize_Terminal_Math :        Boolean := False)
   is
   begin
      if R.Response /= null
        and then R.Response.Get_Parent = Gtk.Widget.Gtk_Widget (Parent)
      then
         Parent.Remove (R.Response);
      end if;
      Clear (R);
      Render
        (R                       => R,
         Parent                  => Parent,
         Document                => Document,
         Source                  => Source,
         Active_Text             => Active_Text,
         Active_View             => Active_View,
         Math_Scale              => Math_Scale,
         Use_Math_Fallback       => Use_Math_Fallback,
         Normalize_Terminal_Math => Normalize_Terminal_Math);
   end Replace;

   procedure Release_Math_Element
     (R       : in out Instance;
      Element : in out Coyote_GUI.Math_Element.Instance_Access)
   is
      Position : Math_Element_Vectors.Extended_Index;
      Widget   : Gtk.Box.Gtk_Box;
      Parent   : Gtk.Widget.Gtk_Widget;
   begin
      if Element = null then
         return;
      end if;
      Position := R.Math_Elements.Find_Index (Element);
      if Position /= Math_Element_Vectors.No_Index then
         R.Math_Elements.Delete (Position);
      end if;
      Widget := Coyote_GUI.Math_Element.Widget (Element.all);
      if Widget /= null then
         Parent := Widget.Get_Parent;
         if Parent /= null then
            Gtk.Container.Gtk_Container (Parent).Remove (Widget);
         end if;
      end if;
      Coyote_GUI.Math_Element.Detach (Element.all);
      Coyote_GUI.Math_Element.Free (Element);
   end Release_Math_Element;

   function Response_Box (R : Instance) return Gtk.Box.Gtk_Box is
   begin
      return R.Response;
   end Response_Box;

   function Text_View_Count (R : Instance) return Natural is
   begin
      return Natural (R.Text_Views.Length);
   end Text_View_Count;

   function Text_View_At
     (R : Instance; Index : Positive) return Gtk.Text_View.Gtk_Text_View
   is
   begin
      if Index <= Natural (R.Text_Views.Length) then
         return R.Text_Views (Index);
      end if;
      return null;
   end Text_View_At;

   function Table_Count (R : Instance) return Natural is
   begin
      return Natural (R.Table_Grids.Length);
   end Table_Count;

   function Table_Grid_At
     (R : Instance; Index : Positive) return Gtk.Grid.Gtk_Grid
   is
   begin
      if Index <= Natural (R.Table_Grids.Length) then
         return R.Table_Grids (Index);
      end if;
      return null;
   end Table_Grid_At;

   function Math_Element_Count (R : Instance) return Natural is
   begin
      return Natural (R.Math_Elements.Length);
   end Math_Element_Count;

   function Math_Element_At
     (R : Instance; Index : Positive)
      return Coyote_GUI.Math_Element.Instance_Access
   is
   begin
      if Index <= Natural (R.Math_Elements.Length) then
         return R.Math_Elements (Index);
      end if;
      return null;
   end Math_Element_At;

   procedure Set_Font
     (R          : in out Instance; Desc : Pango.Font.Pango_Font_Description;
      Math_Scale :        Long_Float := 1.0)
   is
   begin
      for View of R.Text_Views loop
         View.Modify_Font (Desc);
      end loop;
      for Cell of R.Table_Cells loop
         Cell.Modify_Font (Desc);
      end loop;
      R.Math_Scale := Long_Float'Max (Math_Scale, 0.01);
      for Element of R.Math_Elements loop
         Coyote_GUI.Math_Element.Set_Scale (Element.all, R.Math_Scale);
         Coyote_GUI.Math_Element.Set_Font (Element.all, Desc);
      end loop;
   end Set_Font;

   function Math_Scale (R : Instance) return Long_Float is
   begin
      return R.Math_Scale;
   end Math_Scale;

   procedure Clear (R : in out Instance) is
      Child : Gtk.Widget.Gtk_Widget;
   begin
      if R.Response /= null then
         loop
            declare
               Children : constant Gtk.Widget.Widget_List.Glist :=
                 Gtk.Widget.Widget_List.First
                   (Gtk.Container.Get_Children
                      (Gtk.Container.Gtk_Container (R.Response)));
            begin
               exit when Children = Gtk.Widget.Widget_List.Null_List;
               Child := Gtk.Widget.Widget_List.Get_Data (Children);
            end;
            exit when Child = null;
            R.Response.Remove (Child);
         end loop;
      end if;
      for Element of R.Math_Elements loop
         Coyote_GUI.Math_Element.Detach (Element.all);
      end loop;
      for Element of R.Math_Elements loop
         Coyote_GUI.Math_Element.Free (Element);
      end loop;
      R.Math_Elements.Clear;
      R.Table_Grids.Clear;
      R.Table_Cells.Clear;
      R.Text_Views.Clear;
      R.Response   := null;
      R.Math_Scale := 1.0;
   end Clear;

end Coyote_GUI.Response_Renderer;
