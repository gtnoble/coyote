--  Coyote_GUI.Live_Response_Renderer body.
--
--  The renderer appends source-order event fragments to one selectable text
--  buffer.  Open structural contexts are represented by counters, so every
--  prefix and style remains valid while a response is incomplete.
--
--  Project: coyote

with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_App.Utils;      use Coyote_App.Utils;
with Glib;                  use Glib;
with Gtk.Text_Buffer;
with Gtk.Text_Mark;
with Gtk.Widget;
with Gtk.Container;
with Glib.Object;
with Glib.Properties;       use Glib.Properties;
with Gtk.Enums;
with Gtk.Text_Iter;
with Gtk.Text_Tag;
with Pango.Enums;

package body Coyote_GUI.Live_Response_Renderer is

   use type Glib.Gint;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Widget.Gtk_Widget;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Text_Mark.Gtk_Text_Mark;
   use type Coyote_Renderer.Incremental.Live_Event_Kind;

   Indent_Pixels : constant Glib.Gint := 20;
   Heading_Size  : constant Glib.Gint := 14;

   function Tag_For
     (R : Instance; Style : Style_Kind) return Gtk.Text_Tag.Gtk_Text_Tag is
   begin
      case Style is
         when Strong_Style       => return R.Tags.Strong;
         when Em_Style           => return R.Tags.Em;
         when Del_Style          => return R.Tags.Del;
         when Link_Style         => return R.Tags.Link;
         when Inline_Code_Style  => return R.Tags.Inline_Code;
         when Code_Block_Style   => return R.Tags.Code_Block;
         when Blockquote_Style   => return R.Tags.Blockquote;
         when List_Style         => return R.Tags.List;
         when Heading_Style      => return R.Tags.Heading;
      end case;
   end Tag_For;

   procedure Configure_Tags
     (R : in out Instance)
   is
      use Gtk.Text_Tag;
      Buffer : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class :=
        R.Text_Buffer;
   begin
      R.Tags.Strong := Buffer.Create_Tag ("live-strong");
      Set_Property (R.Tags.Strong, Font_Property, "Bold");
      R.Tags.Em := Buffer.Create_Tag ("live-em");
      Set_Property (R.Tags.Em, Font_Property, "Italic");
      R.Tags.Del := Buffer.Create_Tag ("live-del");
      Set_Property (R.Tags.Del, Strikethrough_Property, True);
      R.Tags.Link := Buffer.Create_Tag ("live-link");
      Pango.Enums.Underline_Properties.Set_Property
        (R.Tags.Link,
         Pango.Enums.Underline_Properties.Property (Underline_Property),
         Pango.Enums.Pango_Underline_Single);
      Set_Property (R.Tags.Link, Foreground_Property, "#204080");
      R.Tags.Inline_Code := Buffer.Create_Tag ("live-inline-code");
      Set_Property (R.Tags.Inline_Code, Family_Property, "Monospace");
      Set_Property (R.Tags.Inline_Code, Background_Property, "#f4f4f4");
      R.Tags.Code_Block := Buffer.Create_Tag ("live-code-block");
      Set_Property (R.Tags.Code_Block, Family_Property, "Monospace");
      Set_Property (R.Tags.Code_Block, Background_Property, "#f4f4f4");
      Set_Property (R.Tags.Code_Block, Left_Margin_Property, Indent_Pixels);
      R.Tags.Blockquote := Buffer.Create_Tag ("live-blockquote");
      Set_Property (R.Tags.Blockquote, Left_Margin_Property, Indent_Pixels);
      Set_Property (R.Tags.Blockquote, Foreground_Property, "#505050");
      R.Tags.List := Buffer.Create_Tag ("live-list");
      Set_Property (R.Tags.List, Left_Margin_Property, Indent_Pixels);
      R.Tags.Heading := Buffer.Create_Tag ("live-heading");
      Set_Property (R.Tags.Heading, Font_Property, "Bold 14");
      Set_Property (R.Tags.Heading, Size_Property, Heading_Size);
   end Configure_Tags;

   procedure Append_Plain
     (R : in out Instance; Value : String) is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Value'Length /= 0 then
         R.Text_Buffer.Get_End_Iter (Iter);
         R.Text_Buffer.Insert (Iter, Value);
      end if;
   end Append_Plain;

   procedure Apply_Active_Tags
     (R : in out Instance;
      Start_Offset : Glib.Gint;
      End_Offset   : Glib.Gint)
   is
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      procedure Apply (Tag : Gtk.Text_Tag.Gtk_Text_Tag) is
      begin
         R.Text_Buffer.Apply_Tag (Tag, Start_Iter, End_Iter);
      end Apply;
   begin
      R.Text_Buffer.Get_Iter_At_Offset (Start_Iter, Start_Offset);
      R.Text_Buffer.Get_Iter_At_Offset (End_Iter, End_Offset);
      if R.Strong_Depth > 0 then
         Apply (R.Tags.Strong);
      end if;
      if R.Em_Depth > 0 then
         Apply (R.Tags.Em);
      end if;
      if R.Del_Depth > 0 then
         Apply (R.Tags.Del);
      end if;
      if R.Link_Depth > 0 then
         Apply (R.Tags.Link);
      end if;
      if R.Inline_Code_Depth > 0 then
         Apply (R.Tags.Inline_Code);
      end if;
      if R.Code_Block_Depth > 0 then
         Apply (R.Tags.Code_Block);
      end if;
      if R.Blockquote_Depth > 0 then
         Apply (R.Tags.Blockquote);
      end if;
      if R.List_Depth > 0 then
         Apply (R.Tags.List);
      end if;
      if R.Heading_Depth > 0 then
         Apply (R.Tags.Heading);
      end if;
   end Apply_Active_Tags;

   procedure Append_With_State
     (R : in out Instance; Value : String) is
      Start_Offset : constant Glib.Gint := R.Text_Buffer.Get_Char_Count;
      Iter         : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if Value'Length = 0 then
         return;
      end if;
      R.Text_Buffer.Get_End_Iter (Iter);
      R.Text_Buffer.Insert (Iter, Value);
      Apply_Active_Tags (R, Start_Offset, R.Text_Buffer.Get_Char_Count);
   end Append_With_State;

   procedure Append_Indent (R : in out Instance; Amount : Natural) is
   begin
      if Amount > 0 then
         Append_Plain (R, Str_Repeat ("  ", Amount));
      end if;
   end Append_Indent;

   function Detail_Value
     (Detail : String; Prefix : String) return String is
      Position : constant Natural :=
        Ada.Strings.Fixed.Index (Detail, Prefix);
   begin
      if Position = 1 then
         return Detail (Prefix'Length + 1 .. Detail'Last);
      end if;
      return "";
   end Detail_Value;

   function Positive_Number (Value : String) return Positive is
      Number : Natural := 0;
   begin
      for Character_Value of Value loop
         if Character_Value in '0' .. '9' then
            Number := Natural'Min
              (Positive'Last, Number * 10
               + Character'Pos (Character_Value) - Character'Pos ('0'));
         end if;
      end loop;
      return Positive'Max (1, Number);
   end Positive_Number;

   procedure Add_List_Prefix
     (R : in out Instance;
      Value : Coyote_Renderer.Incremental.Live_Event) is
      Detail : constant String := To_String (Value.Detail);
      Start  : constant String := Detail_Value (Detail, "ordered:");
   begin
      Append_Indent (R, R.List_Depth - 1);
      if Start'Length > 0 then
         Append_Plain (R, "");
      elsif R.List_Depth > 0
        and then R.List_Frames (R.List_Depth).Kind = Ordered
      then
         Append_Plain
           (R, Ada.Strings.Fixed.Trim
              (Positive'Image
                 (R.List_Frames (R.List_Depth).Next_Value),
               Ada.Strings.Left) & ". ");
         R.List_Frames (R.List_Depth).Next_Value :=
           R.List_Frames (R.List_Depth).Next_Value + 1;
      else
         Append_Plain (R, UC_BULLET & " ");
      end if;
      if Start'Length > 0 and then R.List_Depth > 0 then
         Append_Plain
           (R, Ada.Strings.Fixed.Trim
              (Positive'Image (Positive_Number (Start)), Ada.Strings.Left)
            & ". ");
         R.List_Frames (R.List_Depth).Next_Value :=
           Positive_Number (Start) + 1;
      end if;
   end Add_List_Prefix;

   procedure Set_Counter
     (Value : in out Natural; Increase : Boolean) is
   begin
      if Increase then
         Value := Value + 1;
      elsif Value > 0 then
         Value := Value - 1;
      end if;
   end Set_Counter;

   procedure Capture_Checkpoint
     (R : in out Instance; Root_Id : Natural) is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if R.Text_Buffer = null or else R.Checkpoint_Active then
         return;
      end if;
      R.Text_Buffer.Get_End_Iter (Iter);
      R.Checkpoint.Mark := R.Text_Buffer.Create_Mark
        ("live-root", Iter, Left_Gravity => True);
      R.Checkpoint.Root_Id := Root_Id;
      R.Checkpoint.List_Frames := R.List_Frames;
      R.Checkpoint.List_Depth := R.List_Depth;
      R.Checkpoint.Strong_Depth := R.Strong_Depth;
      R.Checkpoint.Em_Depth := R.Em_Depth;
      R.Checkpoint.Del_Depth := R.Del_Depth;
      R.Checkpoint.Link_Depth := R.Link_Depth;
      R.Checkpoint.Inline_Code_Depth := R.Inline_Code_Depth;
      R.Checkpoint.Code_Block_Depth := R.Code_Block_Depth;
      R.Checkpoint.Blockquote_Depth := R.Blockquote_Depth;
      R.Checkpoint.Heading_Depth := R.Heading_Depth;
      R.Checkpoint.Deferred_Depth := R.Deferred_Depth;
      R.Checkpoint.Deferred_Count := R.Deferred_Count;
      R.Checkpoint.Deferred_Blocks := R.Deferred_Blocks;
      R.Checkpoint.Active_Deferred_Kind := R.Active_Deferred_Kind;
      R.Checkpoint.Deferred_Payload := R.Deferred_Payload;
      R.Checkpoint_Active := True;
   end Capture_Checkpoint;

   procedure Restore_Checkpoint
     (R : in out Instance) is
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if not R.Checkpoint_Active then
         return;
      end if;
      R.Text_Buffer.Get_Iter_At_Mark (Start_Iter, R.Checkpoint.Mark);
      R.Text_Buffer.Get_End_Iter (End_Iter);
      R.Text_Buffer.Delete (Start_Iter, End_Iter);
      R.List_Frames := R.Checkpoint.List_Frames;
      R.List_Depth := R.Checkpoint.List_Depth;
      R.Strong_Depth := R.Checkpoint.Strong_Depth;
      R.Em_Depth := R.Checkpoint.Em_Depth;
      R.Del_Depth := R.Checkpoint.Del_Depth;
      R.Link_Depth := R.Checkpoint.Link_Depth;
      R.Inline_Code_Depth := R.Checkpoint.Inline_Code_Depth;
      R.Code_Block_Depth := R.Checkpoint.Code_Block_Depth;
      R.Blockquote_Depth := R.Checkpoint.Blockquote_Depth;
      R.Heading_Depth := R.Checkpoint.Heading_Depth;
      R.Deferred_Depth := R.Checkpoint.Deferred_Depth;
      R.Deferred_Count := R.Checkpoint.Deferred_Count;
      R.Deferred_Blocks := R.Checkpoint.Deferred_Blocks;
      R.Active_Deferred_Kind := R.Checkpoint.Active_Deferred_Kind;
      R.Deferred_Payload := R.Checkpoint.Deferred_Payload;
   end Restore_Checkpoint;

   procedure Drop_Checkpoint (R : in out Instance) is
   begin
      if R.Checkpoint_Active and then R.Text_Buffer /= null
        and then R.Checkpoint.Mark /= null
      then
         R.Text_Buffer.Delete_Mark (R.Checkpoint.Mark);
      end if;
      R.Checkpoint.Mark := null;
      R.Checkpoint_Active := False;
   end Drop_Checkpoint;

   procedure Apply_Invalid
     (R : in out Instance; Text_Value : String) is
   begin
      R.Invalid_Count := R.Invalid_Count + 1;
      Restore_Checkpoint (R);
      Drop_Checkpoint (R);
      --  Invalid source is deliberately appended without active tags.
      Append_Plain (R, Text_Value);
      R.Invalid_State := False;
   end Apply_Invalid;

   procedure Apply
     (R     : in out Instance;
      Value :        Coyote_Renderer.Incremental.Live_Event)
   is
      package I renames Coyote_Renderer.Incremental;
      Kind : constant I.Live_Event_Kind := Value.Kind;
      Text_Value : constant String := To_String (Value.Text);
   begin
      if not R.Started or else R.Finalized
        or else Value.Sequence <= R.Last_Sequence
      then
         return;
      end if;
      R.Last_Sequence := Value.Sequence;
      if Value.Root_Begin then
         if Kind = I.Live_Invalid_Event
           and then R.Checkpoint_Active
           and then R.Checkpoint.Root_Id = Value.Root_Id
         then
            --  A localized invalid event starts at the current output end;
            --  replace the enclosing root checkpoint so its valid prefix is
            --  retained while only the affected suffix is rolled back.
            Drop_Checkpoint (R);
         end if;
         Capture_Checkpoint (R, Value.Root_Id);
      end if;
      if Kind = I.Live_Invalid_Event then
         if R.Checkpoint_Active
           and then (Value.Root_Id = 0
                    or else R.Checkpoint.Root_Id = Value.Root_Id)
         then
            Apply_Invalid (R, Text_Value);
         else
            R.Invalid_Count := R.Invalid_Count + 1;
            Append_Plain (R, Text_Value);
         end if;
         return;
      end if;
      case Kind is
         when I.Live_Text_Event | I.Live_Literal_Event =>
            if Kind = I.Live_Literal_Event then
               Append_With_State (R, Text_Value);
            else
               Append_With_State (R, Text_Value);
            end if;
         when I.Live_Strong_Begin_Event => Set_Counter (R.Strong_Depth, True);
         when I.Live_Strong_End_Event   => Set_Counter (R.Strong_Depth, False);
         when I.Live_Em_Begin_Event => Set_Counter (R.Em_Depth, True);
         when I.Live_Em_End_Event   => Set_Counter (R.Em_Depth, False);
         when I.Live_Del_Begin_Event => Set_Counter (R.Del_Depth, True);
         when I.Live_Del_End_Event   => Set_Counter (R.Del_Depth, False);
         when I.Live_Link_Begin_Event => Set_Counter (R.Link_Depth, True);
         when I.Live_Link_End_Event   => Set_Counter (R.Link_Depth, False);
         when I.Live_Code_Inline_Begin_Event =>
            Set_Counter (R.Inline_Code_Depth, True);
         when I.Live_Code_Inline_End_Event =>
            Set_Counter (R.Inline_Code_Depth, False);
         when I.Live_Hard_Break_Event =>
            Append_Plain
              (R, String'(1 => Ada.Characters.Latin_1.LF));
         when I.Live_Horizontal_Rule_Event =>
            Append_Plain (R, UC_HORIZ & UC_HORIZ & UC_HORIZ
              & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ & UC_HORIZ
              & Ada.Characters.Latin_1.LF);
         when I.Live_Paragraph_Begin_Event => null;
         when I.Live_Paragraph_End_Event =>
            Append_Plain
              (R, String'(1 => Ada.Characters.Latin_1.LF)
               & String'(1 => Ada.Characters.Latin_1.LF));
         when I.Live_Heading_Begin_Event =>
            R.Heading_Depth := R.Heading_Depth + 1;
         when I.Live_Heading_End_Event =>
            Set_Counter (R.Heading_Depth, False);
            Append_Plain
              (R, String'(1 => Ada.Characters.Latin_1.LF)
               & String'(1 => Ada.Characters.Latin_1.LF));
         when I.Live_Blockquote_Begin_Event =>
            R.Blockquote_Depth := R.Blockquote_Depth + 1;
            Append_Plain (R, UC_BOX_V & " ");
         when I.Live_Blockquote_End_Event =>
            Set_Counter (R.Blockquote_Depth, False);
            Append_Plain
              (R, String'(1 => Ada.Characters.Latin_1.LF));
         when I.Live_List_Begin_Event =>
            if R.List_Depth < Max_List_Depth then
               R.List_Depth := R.List_Depth + 1;
               if Detail_Value (To_String (Value.Detail), "ordered:")'Length
                 > 0
               then
                  R.List_Frames (R.List_Depth) :=
                    (Kind => Ordered,
                     Next_Value => Positive_Number
                       (Detail_Value (To_String (Value.Detail), "ordered:")));
               else
                  R.List_Frames (R.List_Depth) :=
                    (Kind => Unordered, Next_Value => 1);
               end if;
            end if;
         when I.Live_List_End_Event =>
            if R.List_Depth > 0 then
               R.List_Depth := R.List_Depth - 1;
            end if;
            Append_Plain
              (R, String'(1 => Ada.Characters.Latin_1.LF));
         when I.Live_Item_Begin_Event =>
            Add_List_Prefix (R, Value);
         when I.Live_Item_End_Event =>
            Append_Plain
              (R, String'(1 => Ada.Characters.Latin_1.LF));
         when I.Live_Code_Begin_Event =>
            R.Code_Block_Depth := R.Code_Block_Depth + 1;
         when I.Live_Code_End_Event =>
            Set_Counter (R.Code_Block_Depth, False);
            Append_Plain
              (R, String'(1 => Ada.Characters.Latin_1.LF));
         when I.Live_Table_Begin_Event | I.Live_Math_Begin_Event =>
            R.Active_Deferred_Kind :=
              (if Kind = I.Live_Table_Begin_Event then
                  Deferred_Table else Deferred_Math);
            R.Deferred_Depth := R.Deferred_Depth + 1;
         when I.Live_Table_End_Event | I.Live_Math_End_Event =>
            if R.Deferred_Count < Max_Deferred_Blocks then
               R.Deferred_Count := R.Deferred_Count + 1;
               R.Deferred_Blocks (R.Deferred_Count) :=
                 (Kind => R.Active_Deferred_Kind,
                  Source => To_Unbounded_String (Text_Value));
            end if;
            Append (R.Deferred_Payload, Text_Value);
            Set_Counter (R.Deferred_Depth, False);
         when I.Live_Invalid_Event =>
            null;
      end case;
      if Value.Root_End and then R.Checkpoint_Active
        and then R.Checkpoint.Root_Id = Value.Root_Id
      then
         Drop_Checkpoint (R);
      end if;
   end Apply;

   procedure Create
     (R      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class)
   is
   begin
      if R.Root = null then
         Gtk.Box.Gtk_New_Vbox (R.Root, Homogeneous => False, Spacing => 0);
         R.Root.Set_Name ("coyote-live-response");
         Gtk.Text_Buffer.Gtk_New (R.Text_Buffer);
         Gtk.Text_View.Gtk_New (R.Text_View, R.Text_Buffer);
         R.Text_View.Set_Editable (False);
         R.Text_View.Set_Cursor_Visible (False);
         R.Text_View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
         R.Text_View.Set_Accepts_Tab (False);
         R.Text_View.Set_Left_Margin (8);
         R.Text_View.Set_Right_Margin (8);
         Configure_Tags (R);
         R.Root.Pack_Start
           (R.Text_View, Expand => False, Fill => True, Padding => 2);
         Parent.Pack_Start (R.Root, Expand => False, Fill => True, Padding => 2);
         R.Attached := True;
         R.Root.Show_All;
      else
         Clear (R);
         if not R.Attached then
            Parent.Pack_Start (R.Root, Expand => False, Fill => True, Padding => 2);
            R.Attached := True;
            if R.Detached_Reference then
               Glib.Object.Unref (Glib.Object.GObject (R.Root));
               R.Detached_Reference := False;
            end if;
            R.Root.Show_All;
         end if;
      end if;
   end Create;

   procedure Begin_Response (R : in out Instance) is
   begin
      Clear (R);
      R.Started := True;
   end Begin_Response;

   procedure Detach
     (R      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class)
   is
   begin
      pragma Unreferenced (Parent);
      if R.Root /= null and then R.Attached then
         declare
            Actual_Parent : constant Gtk.Widget.Gtk_Widget := R.Root.Get_Parent;
         begin
            if Actual_Parent /= null then
               Glib.Object.Ref (Glib.Object.GObject (R.Root));
               Gtk.Container.Remove
                 (Gtk.Container.Gtk_Container (Actual_Parent), R.Root);
               R.Detached_Reference := True;
            end if;
         end;
         R.Attached := False;
      end if;
   exception
      when others =>
         R.Attached := False;
   end Detach;

   procedure Release (R : in out Instance) is
   begin
      Clear (R);
      if R.Detached_Reference and then R.Root /= null then
         Glib.Object.Unref (Glib.Object.GObject (R.Root));
      end if;
      R.Root        := null;
      R.Text_Buffer := null;
      R.Text_View   := null;
      R.Attached    := False;
      R.Detached_Reference := False;
      R.Started     := False;
      R.Finalized   := False;
   exception
      when others =>
         R.Root        := null;
         R.Text_Buffer := null;
         R.Text_View   := null;
         R.Attached    := False;
         R.Detached_Reference := False;
         R.Started     := False;
         R.Finalized   := False;
   end Release;

   procedure Clear (R : in out Instance) is
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Drop_Checkpoint (R);
      if R.Text_Buffer /= null then
         R.Text_Buffer.Get_Start_Iter (Start_Iter);
         R.Text_Buffer.Get_End_Iter (End_Iter);
         R.Text_Buffer.Delete (Start_Iter, End_Iter);
      end if;
      R.List_Depth        := 0;
      R.Strong_Depth      := 0;
      R.Em_Depth          := 0;
      R.Del_Depth         := 0;
      R.Link_Depth        := 0;
      R.Inline_Code_Depth := 0;
      R.Code_Block_Depth  := 0;
      R.Blockquote_Depth  := 0;
      R.Heading_Depth     := 0;
      R.Deferred_Depth    := 0;
      R.Deferred_Count    := 0;
      R.Active_Deferred_Kind := Deferred_Table;
      R.Invalid_Count         := 0;
      R.Invalid_State         := False;
      R.Last_Sequence         := 0;
      R.Finalized         := False;
      R.Started           := False;
      R.Deferred_Payload  := Null_Unbounded_String;
   end Clear;

   procedure Finalize (R : in out Instance) is
   begin
      if R.Started then
         R.Finalized := True;
      end if;
   end Finalize;

   function Is_Finalized (R : Instance) return Boolean is
   begin
      return R.Finalized;
   end Is_Finalized;

   function Widget (R : Instance) return Gtk.Box.Gtk_Box is
   begin
      return R.Root;
   end Widget;

   function Buffer (R : Instance) return Gtk.Text_Buffer.Gtk_Text_Buffer is
   begin
      return R.Text_Buffer;
   end Buffer;

   function View (R : Instance) return Gtk.Text_View.Gtk_Text_View is
   begin
      return R.Text_View;
   end View;

   function Text (R : Instance) return String is
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if R.Text_Buffer = null then
         return "";
      end if;
      R.Text_Buffer.Get_Start_Iter (Start_Iter);
      R.Text_Buffer.Get_End_Iter (End_Iter);
      return R.Text_Buffer.Get_Text (Start_Iter, End_Iter);
   end Text;

   function Has_Style
     (R      : Instance;
      Style  : Style_Kind;
      Offset : Natural) return Boolean
   is
      Iter : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if R.Text_Buffer = null or else Offset >=
        Natural (R.Text_Buffer.Get_Char_Count)
      then
         return False;
      end if;
      R.Text_Buffer.Get_Iter_At_Offset (Iter, Glib.Gint (Offset));
      return Gtk.Text_Iter.Has_Tag (Iter, Tag_For (R, Style));
   end Has_Style;

   function Deferred_Block_Count (R : Instance) return Natural is
   begin
      return R.Deferred_Count;
   end Deferred_Block_Count;

   function Deferred_Block_Kind_At
     (R : Instance; Index : Positive) return Deferred_Kind is
   begin
      if Index <= R.Deferred_Count then
         return R.Deferred_Blocks (Index).Kind;
      end if;
      return Deferred_Table;
   end Deferred_Block_Kind_At;

   function Deferred_Block_Source_At
     (R : Instance; Index : Positive) return String is
   begin
      if Index <= R.Deferred_Count then
         return To_String (R.Deferred_Blocks (Index).Source);
      end if;
      return "";
   end Deferred_Block_Source_At;

   function Deferred_Text (R : Instance) return String is
   begin
      return To_String (R.Deferred_Payload);
   end Deferred_Text;

   function Invalid_Event_Count (R : Instance) return Natural is
   begin
      return R.Invalid_Count;
   end Invalid_Event_Count;

end Coyote_GUI.Live_Response_Renderer;
