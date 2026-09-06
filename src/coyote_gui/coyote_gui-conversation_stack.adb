--  Coyote_GUI.Conversation_Stack body.
--
--  Project: coyote

with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Coyote_GUI;
with Coyote_GUI.Tool_Detail_Window;
with Coyote_GUI.Math_Element;
with Coyote_GUI.Navigation;
with Coyote_Renderer.MathML;
with Coyote_Renderer.Markup;
with Coyote_Renderer.Tables;
with Glib;                   use Glib;
with Glib.Error;
with Gtk.Adjustment;
with Gtk.Handlers;
with GNATCOLL.JSON;
with Gtk.Box;
with Gtk.Button;
with Gtk.Clipboard;
with Gtk.Enums;
with Gtk.Flow_Box;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Label;
with Gtk.Scrolled_Window;
with Gtk.Separator;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;
with Gtk.Css_Provider;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Pango.Font;

package body Coyote_GUI.Conversation_Stack is

   use type Gtk.Adjustment.Gtk_Adjustment;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Flow_Box.Gtk_Flow_Box;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Text_Mark.Gtk_Text_Mark;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Widget.Gtk_Widget;
   use type Coyote_GUI.Math_Element.Instance_Access;
   use type Gtk.Window.Gtk_Window;

   type Instance_Access is access all Instance;

   Response_Box_Spacing   : constant Gint  := 2;
   Response_Block_Padding : constant Guint := 4;

   procedure Pack_Response_Block
     (Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Child  : not null access Gtk.Widget.Gtk_Widget_Record'Class)
   is
   begin
      Parent.Pack_Start
        (Child, Expand => False, Fill => True,
         Padding => Response_Block_Padding);
   end Pack_Response_Block;

   function Has_Non_Whitespace (Text : String) return Boolean is
   begin
      for Character_Value of Text loop
         case Character_Value is
            when ' ' | ASCII.HT | ASCII.LF | ASCII.CR | ASCII.FF => null;
            when others => return True;
         end case;
      end loop;
      return False;
   end Has_Non_Whitespace;

   type Detail_Context is record
      Stack   : Instance_Access;
      Tool_Id : Unbounded_String;
   end record;

   package Detail_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Button.Gtk_Button_Record, Detail_Context);

   type Fork_Context is record
      Handler : Coyote_GUI.Conversation_Stack.Fork_Handler;
      UUID    : Unbounded_String;
      Turn_N  : Positive;
      Step_N  : Natural;
   end record;

   package Fork_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Button.Gtk_Button_Record, Fork_Context);

   procedure On_Detail_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class;
      Data   : Detail_Context);

   procedure On_Fork_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class;
      Data   : Fork_Context);

   procedure On_Fork_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class;
      Data   : Fork_Context)
   is
      pragma Unreferenced (Button);
   begin
      if Data.Handler /= null then
         Data.Handler.all
           (To_String (Data.UUID), Data.Turn_N, Data.Step_N);
      end if;
   end On_Fork_Clicked;

   procedure Log (C : Instance; Text : String) is
   begin
      if C.Debug_Logging then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "[conversation-stack] " & Text);
      end if;
   end Log;

   procedure Append_Buffer
     (Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      Text   : String)
   is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Buffer.Get_End_Iter (Iter);
      Buffer.Insert (Iter, Text);
   end Append_Buffer;

   procedure Add_Text_Element
     (C              : in out Instance;
      Parent         : not null access Gtk.Box.Gtk_Box_Record'Class;
      Caption        : String;
      Text           : String;
      Buffer         : out Gtk.Text_Buffer.Gtk_Text_Buffer;
      View           : out Gtk.Text_View.Gtk_Text_View;
      Response_Block : Boolean := False);

   procedure Add_Response_Table
     (C      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Table  : Coyote_Renderer.Tables.Table_Block);

   procedure Apply_Response_Style
     (Widget : not null access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      use Gtk.Css_Provider;
      use Gtk.Style_Context;
      use Gtk.Style_Provider;
      CSS : constant String :=
        ".coyote-response-content { background-color: @theme_base_color; "
        & "color: @theme_text_color; }";
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

   procedure Add_Response_Text
     (C      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Text   : String)
   is
      Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;
      View   : Gtk.Text_View.Gtk_Text_View;
      Markup : constant String :=
        Coyote_Renderer.Markup.To_Pango_Markup (Text);
      Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Text'Length = 0 then
         return;
      end if;
      Add_Text_Element
        (C, Parent, "", Text, Buffer, View, Response_Block => True);
      Apply_Response_Style (View);
      if C.Render_Markdown then
         Buffer.Set_Text ("");
         Buffer.Get_End_Iter (Iter);
         Buffer.Insert_Markup (Iter, Markup, -1);
      end if;
      C.Text_Views.Append (View);
      C.Active_Text := Buffer;
      C.Active_View := View;
   end Add_Response_Text;

   procedure Add_Response_Table
     (C      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Table  : Coyote_Renderer.Tables.Table_Block)
   is
      Grid : Gtk.Grid.Gtk_Grid;
   begin
      Gtk.Grid.Gtk_New (Grid);
      Grid.Set_Column_Spacing (12);
      Grid.Set_Row_Spacing (3);
      Grid.Set_Hexpand (True);
      Apply_Response_Style (Grid);

      if not Table.Rows.Is_Empty then
         for Row_Index in Table.Rows.First_Index .. Table.Rows.Last_Index loop
            declare
               Row : constant Coyote_Renderer.Tables.Table_Row :=
                 Table.Rows (Row_Index);
            begin
               if not Row.Cells.Is_Empty then
                  for Column_Index in Row.Cells.First_Index
                    .. Row.Cells.Last_Index
                  loop
                     declare
                        Cell : Gtk.Label.Gtk_Label;
                        Text : constant String := To_String
                          (Row.Cells (Column_Index).Text);
                        Alignment : constant
                          Coyote_Renderer.Tables.Table_Alignment :=
                          (if Column_Index <= Natural
                             (Table.Alignments.Length)
                           then Table.Alignments (Column_Index)
                           else Coyote_Renderer.Tables.Unspecified);
                     begin
                        Gtk.Label.Gtk_New (Cell);
                        if Row.Is_Header then
                           Cell.Set_Markup
                             ("<b>"
                              & Coyote_Renderer.Markup.Xml_Escape (Text)
                              & "</b>");
                        else
                           Cell.Set_Text (Text);
                        end if;
                        Cell.Set_Line_Wrap (True);
                        Cell.Set_Max_Width_Chars (35);
                        Cell.Set_Selectable (True);
                        Cell.Set_Halign (Gtk.Widget.Align_Fill);
                        case Alignment is
                           when Coyote_Renderer.Tables.Left |
                                Coyote_Renderer.Tables.Unspecified =>
                              Cell.Set_Xalign (0.0);
                           when Coyote_Renderer.Tables.Center =>
                              Cell.Set_Xalign (0.5);
                           when Coyote_Renderer.Tables.Right =>
                              Cell.Set_Xalign (1.0);
                        end case;
                        Grid.Attach
                          (Cell,
                           Glib.Gint (Column_Index - 1),
                           Glib.Gint (Row_Index - 1));
                        C.Table_Cells.Append (Cell);
                     end;
                  end loop;
               end if;
            end;
         end loop;
      end if;
      Pack_Response_Block (Parent, Grid);
      C.Table_Grids.Append (Grid);
   end Add_Response_Table;

   procedure Add_Response_Math
     (C      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Block  : Coyote_Renderer.MathML.Display_Math_Block)
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Coyote_GUI.Math_Element.New_Element
          (To_String (Block.MathML),
           To_String (Block.Source),
           C.Math_Scale);
   begin
      if Element = null then
         Add_Response_Text (C, Parent, To_String (Block.Source));
         return;
      end if;
      Pack_Response_Block
        (Parent, Coyote_GUI.Math_Element.Widget (Element.all));
      C.Math_Elements.Append (Element);
   end Add_Response_Math;
   procedure Build_Response_Elements
     (C        : in out Instance;
      Full_Text : String)
   is
      Table_Extraction : constant Coyote_Renderer.Tables.Extraction_Result :=
        Coyote_Renderer.Tables.Extract_Tables (Full_Text);
      Math_Extraction : constant Coyote_Renderer.MathML.Extraction_Result :=
        Coyote_Renderer.MathML.Extract_Display_Math
          (To_String (Table_Extraction.Masked_Text));
      Masked     : constant String :=
        To_String (Math_Extraction.Masked_Text);
      Cursor     : Positive := (if Masked'Length > 0 then Masked'First else 1);
      Table_Index : Natural := 1;
      Math_Index  : Natural := 1;
      Table_Token : Unbounded_String;
      Math_Token  : Unbounded_String;
      Table_Position : Natural := 0;
      Math_Position  : Natural := 0;

      procedure Add_Response_Text_If_Content (Text : String) is
      begin
         if Has_Non_Whitespace (Text) then
            Add_Response_Text (C, C.Response_Box, Text);
         end if;
      end Add_Response_Text_If_Content;
   begin
      if (Table_Extraction.Blocks.Is_Empty
          and then Math_Extraction.Blocks.Is_Empty)
        or else C.Response_Section = null
      then
         return;
      end if;

      Gtk.Box.Gtk_New_Vbox
        (C.Response_Box, Homogeneous => False,
         Spacing => Response_Box_Spacing);
      C.Response_Box.Set_Name ("coyote-response-rendered");
      C.Response_Section.Pack_Start
        (C.Response_Box, Expand => False, Fill => True, Padding => 2);

      while Table_Index <= Natural (Table_Extraction.Blocks.Length)
        or else Math_Index <= Natural (Math_Extraction.Blocks.Length)
      loop
         Table_Token := Null_Unbounded_String;
         Math_Token := Null_Unbounded_String;
         if Table_Index <= Natural (Table_Extraction.Blocks.Length) then
            Table_Token := Table_Extraction.Blocks (Table_Index).Placeholder;
            Table_Position := Ada.Strings.Fixed.Index
              (Masked, To_String (Table_Token), Cursor);
         else
            Table_Position := 0;
         end if;
         if Math_Index <= Natural (Math_Extraction.Blocks.Length) then
            Math_Token := To_Unbounded_String
              ("COYOTE_MATH_BLOCK_"
               & Ada.Strings.Fixed.Trim
                   (Natural'Image (Math_Index), Ada.Strings.Both)
               & "__");
            Math_Position := Ada.Strings.Fixed.Index
              (Masked, To_String (Math_Token), Cursor);
         else
            Math_Position := 0;
         end if;

         exit when Table_Position = 0 and then Math_Position = 0;
         if Math_Position = 0
           or else (Table_Position > 0 and then Table_Position < Math_Position)
         then
            if Table_Position > Cursor then
               Add_Response_Text_If_Content
                 (Masked (Cursor .. Table_Position - 1));
            end if;
            Add_Response_Table
              (C, C.Response_Box,
               Table_Extraction.Blocks (Table_Index));
            Cursor := Table_Position + Length (Table_Token);
            Table_Index := Table_Index + 1;
         else
            if Math_Position > Cursor then
               Add_Response_Text_If_Content
                 (Masked (Cursor .. Math_Position - 1));
            end if;
            Add_Response_Math
              (C, C.Response_Box, Math_Extraction.Blocks (Math_Index));
            Cursor := Math_Position + Length (Math_Token);
            Math_Index := Math_Index + 1;
         end if;
      end loop;

      if Masked'Length > 0 and then Cursor <= Masked'Last then
         Add_Response_Text_If_Content (Masked (Cursor .. Masked'Last));
      end if;
      C.Response_Box.Show_All;
   end Build_Response_Elements;

   procedure Replace_Streamed_Text
     (C                : in out Instance;
      Full_Text        : String;
      Has_Display_Math : out Boolean)
   is
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      Markup     : Unbounded_String;
   begin
      Has_Display_Math := False;
      if C.Active_Text = null or else C.Stream_Mark = null then
         return;
      end if;
      declare
         Table_Extraction : constant
           Coyote_Renderer.Tables.Extraction_Result :=
           Coyote_Renderer.Tables.Extract_Tables (Full_Text);
      begin
         if not Table_Extraction.Blocks.Is_Empty then
            return;
         end if;
      end;
      declare
         Extraction : constant Coyote_Renderer.MathML.Extraction_Result :=
           Coyote_Renderer.MathML.Extract_Display_Math (Full_Text);
      begin
         if not Extraction.Blocks.Is_Empty then
            Has_Display_Math := True;
            return;
         end if;
      end;
      Markup := To_Unbounded_String
        (Coyote_Renderer.Markup.To_Pango_Markup (Full_Text));
      C.Active_Text.Get_Iter_At_Mark (Start_Iter, C.Stream_Mark);
      C.Active_Text.Get_End_Iter (End_Iter);
      C.Active_Text.Delete (Start_Iter, End_Iter);
      C.Active_Text.Get_Iter_At_Mark (Start_Iter, C.Stream_Mark);
      if Length (Markup) > 0 then
         C.Active_Text.Insert_Markup
           (Start_Iter, To_String (Markup), -1);
      else
         C.Active_Text.Insert (Start_Iter, Full_Text);
      end if;
   end Replace_Streamed_Text;

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

   procedure Show_Contents (C : Instance) is
   begin
      if C.Scroll /= null then
         C.Scroll.Show_All;
      end if;
   end Show_Contents;

   function Tool_Status_Text
     (Status  : Coyote_GUI.Tool_End_Status;
      Result  : String;
      Running : Boolean) return String
   is
      Detail : constant String :=
        Sanitize_UTF8
          ((if Result'Length > 80
            then Result (Result'First .. Result'First + 79)
            else Result));
      Text : Unbounded_String;
   begin
      if Running then
         return "Running";
      end if;
      case Status is
         when Coyote_GUI.Success =>
            return "Completed";
         when Coyote_GUI.Error =>
            Text := To_Unbounded_String ("Error");
            if Detail'Length > 0 then
               Append (Text, " - " & Detail);
            end if;
            return To_String (Text);
         when Coyote_GUI.Cancelled =>
            return "Cancelled";
      end case;
   end Tool_Status_Text;

   function Compact_Tool_Value (Value : String) return String is
   begin
      if Value'Length > 80 then
         return Sanitize_UTF8
           (Value (Value'First .. Value'First + 76) & UC_ELLIP);
      end if;
      return Sanitize_UTF8 (Value);
   end Compact_Tool_Value;

   function Format_Tool_Summary
     (Name    : String;
      Args    : String;
      Status  : Coyote_GUI.Tool_End_Status;
      Result  : String;
      Running : Boolean) return String
   is
      use type GNATCOLL.JSON.JSON_Value_Type;
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Args);
      Args_Val : constant GNATCOLL.JSON.JSON_Value :=
        (if Parsed.Success
         then Parsed.Value
         else GNATCOLL.JSON.JSON_Null);
      Summary : Unbounded_String;
   begin
      Append (Summary, Name);
      if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
         declare
            procedure Add_Argument
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
            begin
               if not Is_Hidden_Tool_Argument (Field_Name, Field_Value) then
                  Append
                    (Summary,
                     ASCII.LF & String (Field_Name) & ": "
                     & Compact_Tool_Value
                         (JSON_Scalar_Image (Field_Value)));
               end if;
            end Add_Argument;
         begin
            Args_Val.Map_JSON_Object (Add_Argument'Access);
         end;
      end if;
      Append
        (Summary,
         ASCII.LF & "Status: "
         & Tool_Status_Text (Status, Result, Running));
      return To_String (Summary);
   end Format_Tool_Summary;

   procedure Finalize_Active_Step (C : in out Instance) is
   begin
      C.Step_Frame     := null;
      C.Step_Box       := null;
      C.Tool_Flow      := null;
      C.Step_Open      := False;
      C.Footer_Pending := False;
      C.Text_Open      := False;
      C.Thinking_Open  := False;
   end Finalize_Active_Step;

   procedure Ensure_Active_Step (C : in out Instance) is
   begin
      if C.Footer_Pending then
         Finalize_Active_Step (C);
      end if;
      if not C.Step_Open then
         C.Step_Number := C.Step_Number + 1;
         Gtk.Frame.Gtk_New
           (C.Step_Frame, "Step " & Natural_Image (C.Step_Number));
         C.Step_Frame.Set_Shadow_Type (Gtk.Enums.Shadow_In);
         Gtk.Box.Gtk_New_Vbox
           (C.Step_Box, Homogeneous => False, Spacing => 3);
         C.Step_Box.Set_Border_Width (6);
         C.Step_Frame.Add (C.Step_Box);
         C.Exchange.Pack_Start
           (C.Step_Frame, Expand => False, Fill => True, Padding => 4);
         C.Step_Frames.Append (C.Step_Frame);
         C.Step_Open := True;
         Show_Contents (C);
         Log (C, "began step frame");
      end if;
   end Ensure_Active_Step;

   procedure Add_Text_Element
     (C              : in out Instance;
      Parent         : not null access Gtk.Box.Gtk_Box_Record'Class;
      Caption        : String;
      Text           : String;
      Buffer         : out Gtk.Text_Buffer.Gtk_Text_Buffer;
      View           : out Gtk.Text_View.Gtk_Text_View;
      Response_Block : Boolean := False)
   is
      Section : Gtk.Box.Gtk_Box;
      Label   : Gtk.Label.Gtk_Label;
   begin
      Gtk.Box.Gtk_New_Vbox (Section, Homogeneous => False, Spacing => 2);
      Gtk.Label.Gtk_New (Label, Caption);
      Label.Set_Xalign (0.0);
      Label.Set_Selectable (True);
      Section.Pack_Start (Label, Expand => False, Fill => False, Padding => 2);
      Gtk.Text_Buffer.Gtk_New (Buffer);
      Gtk.Text_View.Gtk_New (View, Buffer);
      Configure_Text_View (View);
      if Caption = "Response" then
         View.Set_Name ("coyote-response-stream");
      end if;
      if Text'Length > 0 then
         Buffer.Set_Text (Text);
      end if;
      Section.Pack_Start (View, Expand => False, Fill => True, Padding => 2);
      if Response_Block then
         Pack_Response_Block (Parent, Section);
      else
         Parent.Pack_Start
           (Section, Expand => False, Fill => True, Padding => 4);
      end if;
      if Caption = "Response" then
         C.Response_Section := Section;
         Apply_Response_Style (View);
      end if;
      Show_Contents (C);
   end Add_Text_Element;

   procedure Create
     (C           : in out Instance;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class)
   is
   begin
      if C.Scroll /= null then
         return;
      end if;
      C.Main_Window := Gtk.Window.Gtk_Window (Main_Window);
      Gtk.Scrolled_Window.Gtk_New (C.Scroll);
      C.Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Gtk.Box.Gtk_New_Vbox (C.Host, Homogeneous => False, Spacing => 6);
      C.Scroll.Add (C.Host);
      Log (C, "created outer scroll host");
   end Create;

   procedure On_Detail_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class;
      Data   : Detail_Context)
   is
      pragma Unreferenced (Button);
   begin
      if Data.Stack /= null
        and then Data.Stack.Main_Window /= null
      then
         Coyote_GUI.Tool_Detail_Window.Show
           (Tool_Detail (Data.Stack.all, To_String (Data.Tool_Id)),
            Data.Stack.Main_Window.all'Access);
      end if;
   end On_Detail_Clicked;

   function Widget (C : Instance)
     return Gtk.Scrolled_Window.Gtk_Scrolled_Window
   is
   begin
      return C.Scroll;
   end Widget;

   procedure Set_Fork_Handler
     (C       : in out Instance;
      Handler : Fork_Handler)
   is
   begin
      C.Fork_Callback := Handler;
   end Set_Fork_Handler;

   procedure Clear (C : in out Instance) is
   begin
      if not C.Math_Elements.Is_Empty then
         for Math_Index in C.Math_Elements.First_Index
           .. C.Math_Elements.Last_Index
         loop
            Coyote_GUI.Math_Element.Detach
              (C.Math_Elements (Math_Index).all);
         end loop;
      end if;
      if not C.Exchanges.Is_Empty then
         for Exchange_Index in reverse C.Exchanges.First_Index
           .. C.Exchanges.Last_Index
         loop
            C.Host.Remove (C.Exchanges (Exchange_Index));
         end loop;
      end if;
      C.Exchanges.Clear;
      C.Step_Frames.Clear;
      C.Tools.Clear;
      if not C.Math_Elements.Is_Empty then
         for Math_Index in C.Math_Elements.First_Index
           .. C.Math_Elements.Last_Index
         loop
            Coyote_GUI.Math_Element.Free
              (C.Math_Elements (Math_Index));
         end loop;
      end if;
      C.Math_Elements.Clear;
      C.Table_Grids.Clear;
      C.Table_Cells.Clear;
      C.Text_Views.Clear;
      C.Exchange       := null;
      C.Step_Frame     := null;
      C.Step_Box       := null;
      C.Tool_Flow      := null;
      C.Active_Text    := null;
      C.Active_View    := null;
      C.Response_Section := null;
      C.Response_Box  := null;
      C.Math_Scale    := 1.0;
      C.Stream_Mark  := null;
      C.Stream_Buf   := Null_Unbounded_String;
      C.Thinking       := null;
      C.Thinking_View  := null;
      C.Has_Exchange   := False;
      C.Step_Open      := False;
      C.Footer_Pending := False;
      C.Step_Number    := 0;
      C.Text_Open      := False;
      C.Thinking_Open  := False;
      C.Completed      := False;
      C.Last_Status      := Coyote_GUI.Completed;
      C.Footer_Separator := null;
      C.Footer_Heading   := null;
      C.Footer_Label     := null;
      C.Fork_Button      := null;
      Log (C, "cleared stack and invalidated callbacks");
   end Clear;

   procedure Begin_Request
     (C    : in out Instance;
      Text : String;
      Kind : Coyote_GUI.Request_Kind)
   is
      Caption : constant String :=
        (if Kind = Coyote_GUI.Steer then "Steer" else "Request");
   begin
      Create (C, C.Main_Window.all'Access);
      Gtk.Box.Gtk_New_Vbox (C.Exchange, Homogeneous => False, Spacing => 3);
      C.Host.Pack_Start
        (C.Exchange, Expand => False, Fill => True, Padding => 4);
      C.Exchanges.Append (C.Exchange);
      C.Step_Frames.Clear;
      C.Tools.Clear;
      Add_Text_Element
        (C, C.Exchange, Caption, Text, C.Active_Text, C.Active_View);
      C.Has_Exchange   := True;
      C.Step_Open      := False;
      C.Footer_Pending := False;
      C.Step_Number    := 0;
      C.Text_Open      := False;
      C.Thinking_Open  := False;
      C.Completed      := False;
      C.Last_Status    := Coyote_GUI.Completed;
      Log (C, "began exchange");
   end Begin_Request;

   procedure Append_Text (C : in out Instance; Text : String) is
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      Ensure_Active_Step (C);
      if not C.Text_Open then
         Add_Text_Element
           (C, C.Step_Box, "Response", "", C.Active_Text, C.Active_View);
         C.Text_Open := True;
         C.Stream_Buf := Null_Unbounded_String;
         declare
            Iter : Gtk.Text_Iter.Gtk_Text_Iter;
         begin
            C.Active_Text.Get_End_Iter (Iter);
            C.Stream_Mark := C.Active_Text.Create_Mark
              ("", Iter, Left_Gravity => True);
         end;
      end if;
      Append (C.Stream_Buf, Text);
      Append_Buffer (C.Active_Text, Text);
   end Append_Text;

   procedure End_Text_Block (C : in out Instance) is
      Full_Text        : constant String :=
        Sanitize_UTF8 (To_String (C.Stream_Buf));
      Has_Display_Math : Boolean := False;
      Has_Native_Blocks : Boolean := False;
   begin
      if C.Text_Open then
         if C.Render_Markdown then
            Replace_Streamed_Text (C, Full_Text, Has_Display_Math);
            Has_Native_Blocks := Has_Display_Math
              or else not Coyote_Renderer.Tables.Extract_Tables
                (Full_Text).Blocks.Is_Empty;
         end if;
         Append_Buffer (C.Active_Text, ASCII.LF & ASCII.LF);
         if C.Stream_Mark /= null then
            C.Active_Text.Delete_Mark (C.Stream_Mark);
         end if;
         C.Stream_Mark := null;
         C.Stream_Buf  := Null_Unbounded_String;
         C.Text_Open   := False;
         if Has_Native_Blocks and then C.Response_Section /= null then
            declare
               Old_View  : constant Gtk.Text_View.Gtk_Text_View :=
                 C.Active_View;
               Old_Index : Text_View_Vectors.Extended_Index :=
                 Text_View_Vectors.No_Index;
            begin
               if Old_View /= null then
                  Old_Index := C.Text_Views.Find_Index (Old_View);
                  if Old_Index /= Text_View_Vectors.No_Index then
                     C.Text_Views.Delete (Old_Index);
                  end if;
                  C.Response_Section.Remove (Old_View);
               end if;
               C.Active_Text := null;
               C.Active_View := null;
               Build_Response_Elements (C, Full_Text);
            end;
         end if;
      end if;
   end End_Text_Block;

   procedure Begin_Thinking (C : in out Instance) is
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      Ensure_Active_Step (C);
      if not C.Thinking_Open then
         Add_Text_Element
           (C, C.Step_Box, "Thinking", "", C.Thinking, C.Thinking_View);
         C.Thinking_Open := True;
      end if;
   end Begin_Thinking;

   procedure Append_Thinking (C : in out Instance; Text : String) is
   begin
      if not C.Thinking_Open then
         Begin_Thinking (C);
      end if;
      Append_Buffer (C.Thinking, Text);
   end Append_Thinking;

   procedure End_Thinking (C : in out Instance) is
   begin
      if C.Thinking_Open then
         Append_Buffer (C.Thinking, ASCII.LF & ASCII.LF);
         C.Thinking_Open := False;
      end if;
   end End_Thinking;

   procedure Add_Tool_Argument
     (Grid        : not null access Gtk.Grid.Gtk_Grid_Record'Class;
      Row         : Glib.Gint;
      Field_Name  : String;
      Field_Value : String)
   is
      Key   : Gtk.Label.Gtk_Label;
      Value : Gtk.Label.Gtk_Label;
   begin
      Gtk.Label.Gtk_New (Key, Field_Name);
      Key.Set_Xalign (0.0);
      Grid.Attach (Key, 0, Row);

      Gtk.Label.Gtk_New (Value, Field_Value);
      Value.Set_Xalign (0.0);
      Value.Set_Line_Wrap (True);
      Value.Set_Max_Width_Chars (80);
      Value.Set_Selectable (True);
      Grid.Attach (Value, 1, Row);
   end Add_Tool_Argument;

   procedure Ensure_Tool_Flow (C : in out Instance) is
   begin
      if C.Tool_Flow = null then
         Gtk.Flow_Box.Gtk_New (C.Tool_Flow);
         C.Tool_Flow.Set_Homogeneous (False);
         C.Tool_Flow.Set_Row_Spacing (4);
         C.Tool_Flow.Set_Column_Spacing (4);
         C.Tool_Flow.Set_Selection_Mode (Gtk.Enums.Selection_None);
         C.Tool_Flow.Set_Orientation
           (Gtk.Enums.Orientation_Horizontal);
         C.Tool_Flow.Set_Hexpand (True);
         C.Tool_Flow.Set_Halign (Gtk.Widget.Align_Fill);
         C.Step_Box.Pack_Start
           (C.Tool_Flow, Expand => False, Fill => True, Padding => 0);
      end if;
   end Ensure_Tool_Flow;

   procedure Begin_Tool
     (C               : in out Instance;
      Name            : String;
      Args            : String;
      Session_Id      : String;
      Tool_Id         : String;
      Model           : String := "";
      Source_Directory : String := "";
      Session_Start   : String := "";
      Turn_Index      : Positive := 1;
      Call_In_Turn    : Positive := 1)
   is
      Frame        : Gtk.Frame.Gtk_Frame;
      Box          : Gtk.Box.Gtk_Box;
      Header       : Gtk.Label.Gtk_Label;
      Status       : Gtk.Label.Gtk_Label;
      Arguments    : Gtk.Grid.Gtk_Grid;
      Details      : Gtk.Button.Gtk_Button;
      Info         : Coyote_GUI.Tool_Info;
      Summary_Text : constant String :=
        Format_Tool_Summary
          (Name, Args, Coyote_GUI.Success, "", Running => True);
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      Ensure_Active_Step (C);
      Ensure_Tool_Flow (C);
      if C.Tools.Contains (Tool_Id) then
         return;
      end if;

      Info.Tool_Id          := To_Unbounded_String (Tool_Id);
      Info.Session_Id       := To_Unbounded_String (Session_Id);
      Info.Name             := To_Unbounded_String (Name);
      Info.Args             := To_Unbounded_String (Args);
      Info.Model            := To_Unbounded_String (Model);
      Info.Source_Directory := To_Unbounded_String (Source_Directory);
      Info.Session_Start    := To_Unbounded_String (Session_Start);
      Info.Turn_Index       := Turn_Index;
      Info.Call_In_Turn     := Call_In_Turn;
      Info.Completed        := False;

      Gtk.Frame.Gtk_New (Frame, "Tool call");
      Gtk.Box.Gtk_New_Vbox (Box, Homogeneous => False, Spacing => 4);
      Box.Set_Border_Width (6);
      Frame.Add (Box);

      Gtk.Label.Gtk_New (Header, Name);
      Header.Set_Xalign (0.0);
      Box.Pack_Start (Header, Expand => False, Fill => False, Padding => 0);

      Gtk.Label.Gtk_New
        (Status, "Status: "
         & Tool_Status_Text
             (Coyote_GUI.Success, "", Running => True));
      Status.Set_Xalign (0.0);
      Box.Pack_Start (Status, Expand => False, Fill => False, Padding => 0);

      Gtk.Grid.Gtk_New (Arguments);
      Arguments.Set_Column_Spacing (12);
      Arguments.Set_Row_Spacing (3);
      declare
         use type GNATCOLL.JSON.JSON_Value_Type;
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Args);
         Args_Val : constant GNATCOLL.JSON.JSON_Value :=
           (if Parsed.Success
            then Parsed.Value
            else GNATCOLL.JSON.JSON_Null);
         Row : Glib.Gint := 0;
      begin
         if Args_Val.Kind = GNATCOLL.JSON.JSON_Object_Type then
            declare
               procedure Add_Argument
                 (Field_Name  : GNATCOLL.JSON.UTF8_String;
                  Field_Value : GNATCOLL.JSON.JSON_Value)
               is
               begin
                  if not Is_Hidden_Tool_Argument
                    (Field_Name, Field_Value)
                  then
                     Add_Tool_Argument
                       (Arguments.all'Access,
                        Row,
                        String (Field_Name),
                        Compact_Tool_Value
                          (JSON_Scalar_Image (Field_Value)));
                     Row := Row + 1;
                  end if;
               end Add_Argument;
            begin
               Args_Val.Map_JSON_Object (Add_Argument'Access);
            end;
         end if;
         if Row > 0 then
            Box.Pack_Start
              (Arguments, Expand => False, Fill => True, Padding => 0);
         end if;
      end;

      Gtk.Button.Gtk_New (Details, "View Details");
      Details.Set_Can_Focus (True);
      Details.Set_Sensitive (True);
      Details.Set_Tooltip_Text
        ("View captured tool call details and current status");
      Detail_Callback.Connect
        (Details,
         Gtk.Button.Signal_Clicked,
         On_Detail_Clicked'Access,
         (Stack   => C'Unchecked_Access,
          Tool_Id => To_Unbounded_String (Tool_Id)));
      Box.Pack_Start (Details, Expand => False, Fill => False, Padding => 0);
      C.Tool_Flow.Insert (Frame, -1);
      Show_Contents (C);
      C.Tools.Insert
        (Tool_Id,
         (Summary_Text => To_Unbounded_String (Summary_Text),
          Status       => Status,
          Details      => Details,
          Info         => Info));
   end Begin_Tool;

   procedure End_Tool
     (C          : in out Instance;
      Tool_Id    : String;
      Status     : Coyote_GUI.Tool_End_Status;
      Result     : String;
      Media_Type : String := "")
   is
      Tool_Value : Tool_Entry;
   begin
      if not C.Tools.Contains (Tool_Id) then
         return;
      end if;
      Tool_Value := C.Tools.Element (Tool_Id);
      Tool_Value.Info.Result_Text   := To_Unbounded_String (Result);
      Tool_Value.Info.Media_Type    := To_Unbounded_String (Media_Type);
      Tool_Value.Info.Result_Status :=
        Coyote_GUI.Tool_End_Status'Val
          (Coyote_GUI.Tool_End_Status'Pos (Status));
      Tool_Value.Info.Completed := True;
      Tool_Value.Summary_Text :=
        To_Unbounded_String
          (Format_Tool_Summary
             (To_String (Tool_Value.Info.Name),
              To_String (Tool_Value.Info.Args),
              Status,
              Result,
              Running => False));
      Tool_Value.Status.Set_Text
        ("Status: "
         & Tool_Status_Text (Status, Result, Running => False));
      Tool_Value.Details.Set_Sensitive (True);
      C.Tools.Replace (Tool_Id, Tool_Value);
   end End_Tool;

   procedure Append_Notice
     (C    : in out Instance;
      Kind : Coyote_GUI.Notice_Kind;
      Text : String)
   is
      Label : Gtk.Label.Gtk_Label;
      Prefix : constant String :=
        (case Kind is
            when Coyote_GUI.Info    => "Info: ",
            when Coyote_GUI.Warning => "Warning: ",
            when Coyote_GUI.Error   => "Error: ");
   begin
      if not C.Has_Exchange then
         Begin_Request (C, "", Coyote_GUI.Prompt);
      end if;
      Gtk.Label.Gtk_New (Label, Prefix & Text);
      Label.Set_Xalign (0.0);
      Label.Set_Line_Wrap (True);
      Label.Set_Selectable (True);
      C.Exchange.Pack_Start
        (Label, Expand => False, Fill => True, Padding => 2);
      Show_Contents (C);
   end Append_Notice;

   procedure Append_Turn_Footer
     (C       : in out Instance;
      Text    : String;
      Kind    : Coyote_GUI.Footer_Kind;
      Summary : String := "")
   is
      Footer_Box : Gtk.Box.Gtk_Box;
      Heading    : constant String :=
        (if Kind = Coyote_GUI.Step_Footer
         then "Step " & Natural_Image (C.Step_Number) & " summary"
         else "Turn summary");
   begin
      if not C.Has_Exchange then
         return;
      end if;
      Ensure_Active_Step (C);

      Gtk.Box.Gtk_New_Vbox (Footer_Box, Homogeneous => False, Spacing => 2);
      Gtk.Separator.Gtk_New_Hseparator (C.Footer_Separator);
      Footer_Box.Pack_Start
        (C.Footer_Separator, Expand => False, Fill => True, Padding => 0);

      Gtk.Label.Gtk_New (C.Footer_Heading, Heading);
      C.Footer_Heading.Set_Xalign (0.0);
      C.Footer_Heading.Set_Selectable (False);
      Footer_Box.Pack_Start
        (C.Footer_Heading, Expand => False, Fill => True, Padding => 0);

      if Summary'Length > 0 then
         Gtk.Label.Gtk_New (C.Footer_Label, Summary);
         C.Footer_Label.Set_Xalign (0.0);
         C.Footer_Label.Set_Line_Wrap (True);
         C.Footer_Label.Set_Selectable (False);
         C.Footer_Label.Set_Tooltip_Text
           ("Token, context, cost, and completion information for "
            & Heading);
         Footer_Box.Pack_Start
           (C.Footer_Label, Expand => False, Fill => True, Padding => 0);
      end if;
      C.Step_Box.Pack_Start
        (Footer_Box, Expand => False, Fill => True, Padding => 1);
      Show_Contents (C);
      C.Footer_Pending := True;
   end Append_Turn_Footer;

   procedure Append_Fork_Action
     (C       : in out Instance;
      Label   : String;
      UUID    : String;
      Turn_N  : Positive;
      Step_N  : Natural)
   is
      pragma Unreferenced (Label);
      Action_Box : Gtk.Box.Gtk_Box;
      Point      : Gtk.Label.Gtk_Label;
   begin
      if not C.Has_Exchange or else not C.Step_Open then
         return;
      end if;
      Gtk.Box.Gtk_New_Hbox (Action_Box, Homogeneous => False, Spacing => 6);
      Gtk.Label.Gtk_New
        (Point, "Fork point: turn " & Natural_Image (Turn_N)
         & (if Step_N > 0
            then ", step " & Natural_Image (Step_N)
            else ""));
      Point.Set_Xalign (0.0);
      Action_Box.Pack_Start
        (Point, Expand => True, Fill => True, Padding => 0);
      Gtk.Button.Gtk_New (C.Fork_Button, "Fork");
      C.Fork_Button.Set_Can_Focus (True);
      C.Fork_Button.Set_Tooltip_Text
        ("Create a new session from turn " & Natural_Image (Turn_N)
         & (if Step_N > 0 then ", step " & Natural_Image (Step_N) else ""));
      Fork_Callback.Connect
        (C.Fork_Button,
         Gtk.Button.Signal_Clicked,
         On_Fork_Clicked'Access,
         (Handler => C.Fork_Callback,
          UUID    => To_Unbounded_String (UUID),
          Turn_N  => Turn_N,
          Step_N  => Step_N));
      Action_Box.Pack_End
        (C.Fork_Button, Expand => False, Fill => False, Padding => 0);
      C.Step_Box.Pack_Start
        (Action_Box, Expand => False, Fill => True, Padding => 0);
      Show_Contents (C);
      if C.Footer_Pending then
         Finalize_Active_Step (C);
      end if;
   end Append_Fork_Action;

   procedure Complete_Request
     (C      : in out Instance;
      Status : Coyote_GUI.Completion_Status)
   is
   begin
      if not C.Has_Exchange or else C.Completed then
         return;
      end if;
      C.Last_Status := Status;
      C.Completed := True;
      Finalize_Active_Step (C);
   end Complete_Request;

   function Tool_Summary
     (C       : Instance;
      Tool_Id : String) return String
   is
      Tool_Value : Tool_Entry;
   begin
      if not C.Tools.Contains (Tool_Id) then
         return "";
      end if;
      Tool_Value := C.Tools.Element (Tool_Id);
      return To_String (Tool_Value.Summary_Text);
   end Tool_Summary;

   function Tool_Detail
     (C       : Instance;
      Tool_Id : String) return Coyote_GUI.Tool_Info
   is
      Tool_Value : Tool_Entry;
   begin
      if C.Tools.Contains (Tool_Id) then
         Tool_Value := C.Tools.Element (Tool_Id);
         return Tool_Value.Info;
      end if;
      return (others => <>);
   end Tool_Detail;

   function Selection_View (C : Instance)
     return Gtk.Text_View.Gtk_Text_View
   is
      Focus : Gtk.Widget.Gtk_Widget;
   begin
      if C.Main_Window /= null then
         Focus := C.Main_Window.Get_Focus;
         if Focus /= null then
            for View of C.Text_Views loop
               if Focus = Gtk.Widget.Gtk_Widget (View) then
                  return View;
               end if;
            end loop;
         end if;
      end if;
      for View of C.Text_Views loop
         if View.Get_Buffer.Get_Has_Selection then
            return View;
         end if;
      end loop;
      return C.Active_View;
   end Selection_View;

   procedure Scroll_To_End (C : in out Instance) is
   begin
      if C.Scroll = null then
         return;
      end if;
      declare
         Adjustment : constant Gtk.Adjustment.Gtk_Adjustment :=
           C.Scroll.Get_Vadjustment;
      begin
         Adjustment.Set_Value
           (Gdouble'Max
              (Adjustment.Get_Upper - Adjustment.Get_Page_Size, 0.0));
      end;
   end Scroll_To_End;

   procedure Move_Viewport
     (C    : in out Instance;
      Move : Coyote_GUI.Navigation.Movement)
   is
      Adjustment : constant Gtk.Adjustment.Gtk_Adjustment :=
        (if C.Scroll = null then null else C.Scroll.Get_Vadjustment);
      Line_Size  : constant Gdouble := 18.0;
   begin
      if Adjustment = null then
         return;
      end if;
      Adjustment.Set_Value
        (Coyote_GUI.Navigation.Target_Value
           (Current   => Adjustment.Get_Value,
            Lower     => Adjustment.Get_Lower,
            Upper     => Adjustment.Get_Upper,
            Page_Size => Adjustment.Get_Page_Size,
            Line_Size => Line_Size,
            Move      => Move));
   end Move_Viewport;

   function Has_Focus (C : Instance) return Boolean is
      Focus : Gtk.Widget.Gtk_Widget;
   begin
      if C.Main_Window = null then
         return False;
      end if;
      Focus := C.Main_Window.Get_Focus;
      if Focus = null then
         return False;
      end if;
      for View of C.Text_Views loop
         if Focus = Gtk.Widget.Gtk_Widget (View) then
            return True;
         end if;
      end loop;
      return False;
   end Has_Focus;

   function Has_Selection (C : Instance) return Boolean is
      View : constant Gtk.Text_View.Gtk_Text_View := Selection_View (C);
   begin
      return View /= null and then View.Get_Buffer.Get_Has_Selection;
   end Has_Selection;

   procedure Copy_Selection (C : in out Instance) is
      View : constant Gtk.Text_View.Gtk_Text_View := Selection_View (C);
   begin
      if View /= null and then View.Get_Buffer.Get_Has_Selection then
         View.Get_Buffer.Copy_Clipboard (Gtk.Clipboard.Get);
      end if;
   end Copy_Selection;

   procedure Select_All (C : in out Instance) is
      View       : constant Gtk.Text_View.Gtk_Text_View := Selection_View (C);
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if View = null then
         return;
      end if;
      View.Get_Buffer.Get_Start_Iter (Start_Iter);
      View.Get_Buffer.Get_End_Iter (End_Iter);
      View.Get_Buffer.Select_Range (Start_Iter, End_Iter);
   end Select_All;

   procedure Clear_Selection (C : in out Instance) is
      View        : constant Gtk.Text_View.Gtk_Text_View := Selection_View (C);
      Insert_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if View = null then
         return;
      end if;
      View.Get_Buffer.Get_Iter_At_Mark
        (Insert_Iter, View.Get_Buffer.Get_Insert);
      View.Get_Buffer.Place_Cursor (Insert_Iter);
   end Clear_Selection;

   procedure Set_Render_Markdown (C : in out Instance; Enabled : Boolean) is
   begin
      C.Render_Markdown := Enabled;
   end Set_Render_Markdown;

   function Get_Render_Markdown (C : Instance) return Boolean is
   begin
      return C.Render_Markdown;
   end Get_Render_Markdown;

   procedure Set_Font
     (C          : in out Instance;
      Desc       : Pango.Font.Pango_Font_Description;
      Math_Scale : Long_Float := 1.0)
   is
   begin
      if C.Active_View /= null then
         C.Active_View.Modify_Font (Desc);
      end if;
      if not C.Text_Views.Is_Empty then
         for Text_Index in C.Text_Views.First_Index
           .. C.Text_Views.Last_Index
         loop
            C.Text_Views (Text_Index).Modify_Font (Desc);
         end loop;
      end if;
      if C.Thinking_View /= null then
         C.Thinking_View.Modify_Font (Desc);
      end if;
      if not C.Table_Cells.Is_Empty then
         for Cell_Index in C.Table_Cells.First_Index
           .. C.Table_Cells.Last_Index
         loop
            C.Table_Cells (Cell_Index).Modify_Font (Desc);
         end loop;
      end if;
      C.Math_Scale := Long_Float'Max (Math_Scale, 0.01);
      if not C.Math_Elements.Is_Empty then
         for Math_Index in C.Math_Elements.First_Index
           .. C.Math_Elements.Last_Index
         loop
            Coyote_GUI.Math_Element.Set_Scale
              (C.Math_Elements (Math_Index).all, C.Math_Scale);
         end loop;
      end if;
   end Set_Font;

   procedure Set_Debug_Logging (C : in out Instance; Enabled : Boolean) is
   begin
      C.Debug_Logging := Enabled;
   end Set_Debug_Logging;

end Coyote_GUI.Conversation_Stack;
