--  Coyote_GUI.Semantic_Response_Presenter body.
--
--  The presenter reconciles canonical semantic snapshots into stable
--  top-level response components.  All operations run on the GTK main task.
--
--  Project: coyote

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Coyote_GUI.Math_Element;
with Coyote_GUI.Response_Renderer;
with Coyote_Renderer.Markup;
with Coyote_Renderer.Semantics;
with Glib;
with Gtk.Box;
with Gtk.Container;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;

package body Coyote_GUI.Semantic_Response_Presenter is

   use type Gtk.Box.Gtk_Box;
   use type Gtk.Grid.Gtk_Grid;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Glib.Gint;
   use type Gtk.Widget.Widget_List.Glist;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Widget.Gtk_Widget;
   use type Coyote_Renderer.Semantics.Block_Id;
   use type Coyote_Renderer.Semantics.Block_Kind;
   use type Coyote_Renderer.Semantics.Inline_Kind;
   use type Coyote_GUI.Math_Element.Instance_Access;

   procedure Free is new Ada.Unchecked_Deallocation
     (Component, Component_Access);

   function Is_Native_Kind
     (Document : Coyote_Renderer.Semantics.Document;
      Block    : Coyote_Renderer.Semantics.Block_Id) return Boolean is
      package S renames Coyote_Renderer.Semantics;
   begin
      return S.Block_Kind_Of (Document, Block) in S.Table | S.Display_Math;
   end Is_Native_Kind;

   function Is_Committed
     (P : Instance; Root_Id : Natural) return Boolean is
   begin
      return Root_Id /= 0 and then P.Committed.Contains (Root_Id);
   end Is_Committed;

   function Text_Markup
     (Document    : Coyote_Renderer.Semantics.Document;
      Block       : Coyote_Renderer.Semantics.Block_Id;
      Provisional : Boolean) return String is
      package S renames Coyote_Renderer.Semantics;
   begin
      if Provisional and then Is_Native_Kind (Document, Block) then
         return Coyote_Renderer.Markup.Xml_Escape
           (S.Block_Source (Document, Block));
      end if;
      return Coyote_GUI.Response_Renderer.Block_Markup (Document, Block);
   end Text_Markup;

   procedure Remove_Payload (C : in out Component) is
      Child : Gtk.Widget.Gtk_Widget;
   begin
      if C.Payload = null then
         return;
      end if;
      loop
         declare
            Children : constant Gtk.Widget.Widget_List.Glist :=
              Gtk.Widget.Widget_List.First
                (Gtk.Container.Get_Children
                   (Gtk.Container.Gtk_Container (C.Payload)));
         begin
            exit when Children = Gtk.Widget.Widget_List.Null_List;
            Child := Gtk.Widget.Widget_List.Get_Data (Children);
         end;
         exit when Child = null;
         C.Payload.Remove (Child);
      end loop;
      C.View := null;
      C.Buffer := null;
   end Remove_Payload;

   procedure Clear_Component (C : in out Component) is
   begin
      --  Math_Element callbacks must run while their Ada owner is alive.
      Remove_Payload (C);
      Coyote_GUI.Response_Renderer.Clear (C.Renderer);
   end Clear_Component;

   procedure Apply_Text_Font
     (P : Instance; C : not null access Component) is
   begin
      if C.View /= null and then Length (P.Font_Name) > 0 then
         declare
            Description : Pango.Font.Pango_Font_Description :=
              Pango.Font.From_String (To_String (P.Font_Name));
         begin
            C.View.Modify_Font (Description);
            Pango.Font.Free (Description);
         end;
      end if;
   end Apply_Text_Font;

   procedure Set_Text
     (P : in out Instance; C : in out Component; Markup : String) is
      Iter          : Gtk.Text_Iter.Gtk_Text_Iter;
      Insert_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      Bound_Iter    : Gtk.Text_Iter.Gtk_Text_Iter;
      Had_Selection : Boolean := False;
      Restore_Marks : Boolean := False;
      Insert_Offset : Glib.Gint := 0;
      Bound_Offset  : Glib.Gint := 0;
   begin
      if C.Buffer = null then
         Gtk.Text_Buffer.Gtk_New (C.Buffer);
      else
         C.Buffer.Get_Iter_At_Mark (Insert_Iter, C.Buffer.Get_Insert);
         C.Buffer.Get_Iter_At_Mark
           (Bound_Iter, C.Buffer.Get_Selection_Bound);
         Insert_Offset := Gtk.Text_Iter.Get_Offset (Insert_Iter);
         Bound_Offset := Gtk.Text_Iter.Get_Offset (Bound_Iter);
         Had_Selection := C.Buffer.Get_Has_Selection;
         Restore_Marks := True;
      end if;
      if C.View = null then
         Gtk.Text_View.Gtk_New (C.View, C.Buffer);
         Coyote_GUI.Response_Renderer.Configure_Text_View (C.View);
         Coyote_GUI.Response_Renderer.Apply_Response_Style (C.View);
         C.Payload.Pack_Start
           (C.View, Expand => False, Fill => True, Padding => 2);
      else
         C.Buffer.Set_Text ("");
      end if;
      if Markup'Length > 0 then
         C.Buffer.Get_End_Iter (Iter);
         C.Buffer.Insert_Markup (Iter, Markup, -1);
      end if;
      if Restore_Marks then
         declare
            Last_Offset : constant Glib.Gint := C.Buffer.Get_Char_Count;
            New_Insert  : Gtk.Text_Iter.Gtk_Text_Iter;
            New_Bound   : Gtk.Text_Iter.Gtk_Text_Iter;
         begin
            Insert_Offset := Glib.Gint'Min
              (Glib.Gint'Max (Insert_Offset, 0), Last_Offset);
            Bound_Offset := Glib.Gint'Min
              (Glib.Gint'Max (Bound_Offset, 0), Last_Offset);
            C.Buffer.Get_Iter_At_Offset (New_Insert, Insert_Offset);
            C.Buffer.Get_Iter_At_Offset (New_Bound, Bound_Offset);
            if Had_Selection then
               C.Buffer.Select_Range (New_Insert, New_Bound);
            else
               C.Buffer.Place_Cursor (New_Insert);
            end if;
         end;
      end if;
      Apply_Text_Font (P, C'Access);
      P.Active := C.View;
   end Set_Text;

   procedure Apply_Component_Font
     (P : Instance; C : in out Component) is
   begin
      if Length (P.Font_Name) > 0 then
         declare
            Description : Pango.Font.Pango_Font_Description :=
              Pango.Font.From_String (To_String (P.Font_Name));
         begin
            if C.View /= null then
               C.View.Modify_Font (Description);
            end if;
            Coyote_GUI.Response_Renderer.Set_Font
              (C.Renderer, Description, P.Math_Scale);
            Pango.Font.Free (Description);
         end;
      end if;
   end Apply_Component_Font;

   function Inline_Has_Style
     (Document : Coyote_Renderer.Semantics.Document;
      Inline   : Coyote_Renderer.Semantics.Inline_Id;
      Style    : Style_Kind) return Boolean is
      package S renames Coyote_Renderer.Semantics;
      Kind : constant S.Inline_Kind := S.Inline_Kind_Of (Document, Inline);
   begin
      if (Style = Strong_Style and then Kind = S.Strong)
        or else (Style = Em_Style and then Kind = S.Emphasis)
        or else (Style = Del_Style and then Kind = S.Deletion)
        or else (Style = Link_Style and then Kind = S.Link)
        or else (Style = Inline_Code_Style and then Kind = S.Inline_Code)
      then
         return True;
      end if;
      for Position in 1 .. S.Inline_Child_Count (Document, Inline) loop
         if Inline_Has_Style
           (Document, S.Inline_Child_At (Document, Inline, Position), Style)
         then
            return True;
         end if;
      end loop;
      return False;
   end Inline_Has_Style;

   function Block_Has_Style
     (Document : Coyote_Renderer.Semantics.Document;
      Block    : Coyote_Renderer.Semantics.Block_Id;
      Style    : Style_Kind) return Boolean is
      package S renames Coyote_Renderer.Semantics;
      Kind : constant S.Block_Kind := S.Block_Kind_Of (Document, Block);
   begin
      if (Style = Code_Block_Style and then Kind = S.Code_Block)
        or else (Style = Blockquote_Style and then Kind = S.Blockquote)
        or else (Style = List_Style
                and then Kind in S.List | S.List_Item)
        or else (Style = Heading_Style and then Kind = S.Heading)
      then
         return True;
      end if;
      for Position in 1 .. S.Block_Inline_Count (Document, Block) loop
         if Inline_Has_Style
           (Document, S.Block_Inline_At (Document, Block, Position), Style)
         then
            return True;
         end if;
      end loop;
      for Position in 1 .. S.Block_Child_Count (Document, Block) loop
         if Block_Has_Style
           (Document, S.Block_Child_At (Document, Block, Position), Style)
         then
            return True;
         end if;
      end loop;
      return False;
   end Block_Has_Style;

   function Has_Style
     (Document : Coyote_Renderer.Semantics.Document;
      Style    : Style_Kind) return Boolean is
   begin
      for Position in 1 .. Coyote_Renderer.Semantics.Block_Count (Document) loop
         if Block_Has_Style
           (Document, Coyote_Renderer.Semantics.Block_At (Document, Position),
            Style)
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Style;

   procedure Create_Component
     (P                       : in out Instance;
      C                       : in out Component;
      Document                :        Coyote_Renderer.Semantics.Document;
      Block                   :        Coyote_Renderer.Semantics.Block_Id;
      Normalize_Terminal_Math :        Boolean) is
      package S renames Coyote_Renderer.Semantics;
      Root_Id : constant Natural := S.Block_Semantic_Root_Id
        (Document, Block);
      Want_Native : constant Boolean :=
        Is_Native_Kind (Document, Block) and then Is_Committed (P, Root_Id);
   begin
      C.Root_Id := Root_Id;
      C.Block := Block;
      C.Committed := Is_Committed (P, Root_Id);
      C.Kind := (if Want_Native then Native_Component else Text_Component);
      Gtk.Box.Gtk_New_Vbox (C.Outer, Homogeneous => False, Spacing => 0);
      Gtk.Box.Gtk_New_Vbox (C.Payload, Homogeneous => False, Spacing => 2);
      C.Outer.Pack_Start
        (C.Payload, Expand => False, Fill => True, Padding => 2);
      if Want_Native then
         Coyote_GUI.Response_Renderer.Render_Native_Block
           (C.Renderer, C.Payload, Document, Block,
            Normalize_Terminal_Math, P.Math_Scale);
      else
         Set_Text (P, C, Text_Markup (Document, Block, not C.Committed));
      end if;
      P.Response.Pack_Start
        (C.Outer, Expand => False, Fill => True, Padding => 2);
      Apply_Component_Font (P, C);
      C.Dirty := False;
   end Create_Component;

   procedure Update_Component
     (P                       : in out Instance;
      C                       : in out Component;
      Document                :        Coyote_Renderer.Semantics.Document;
      Block                   :        Coyote_Renderer.Semantics.Block_Id;
      Normalize_Terminal_Math :        Boolean) is
      package S renames Coyote_Renderer.Semantics;
      Root_Id     : constant Natural := S.Block_Semantic_Root_Id
        (Document, Block);
      Committed   : constant Boolean := Is_Committed (P, Root_Id);
      Want_Native : constant Boolean :=
        Is_Native_Kind (Document, Block) and then Committed;
      Changed     : constant Boolean := C.Dirty
        or else C.Committed /= Committed
        or else (Want_Native and then C.Kind /= Native_Component)
        or else (not Want_Native and then C.Kind /= Text_Component);
   begin
      if Changed then
         if C.Kind = Native_Component then
            Remove_Payload (C);
            Coyote_GUI.Response_Renderer.Clear (C.Renderer);
         end if;
         if Want_Native then
            if C.Kind /= Native_Component then
               Remove_Payload (C);
               Coyote_GUI.Response_Renderer.Clear (C.Renderer);
               C.Kind := Native_Component;
            end if;
            Coyote_GUI.Response_Renderer.Render_Native_Block
              (C.Renderer, C.Payload, Document, Block,
               Normalize_Terminal_Math, P.Math_Scale);
         else
            if C.Kind /= Text_Component then
               Remove_Payload (C);
               Coyote_GUI.Response_Renderer.Clear (C.Renderer);
               C.Kind := Text_Component;
            end if;
            Set_Text (P, C, Text_Markup (Document, Block, not Committed));
         end if;
      end if;
      C.Root_Id := Root_Id;
      C.Block := Block;
      C.Committed := Committed;
      C.Dirty := False;
      Apply_Component_Font (P, C);
   end Update_Component;

   procedure Remove_Component
     (P : in out Instance; Position : Component_Vectors.Extended_Index) is
      C : Component_Access := P.Components (Position);
   begin
      Clear_Component (C.all);
      if C.Outer /= null and then C.Outer.Get_Parent /= null then
         P.Response.Remove (C.Outer);
      end if;
      Free (C);
      P.Components.Delete (Position);
   end Remove_Component;

   function Find_Component
     (P : Instance; Root_Id : Natural)
      return Component_Vectors.Extended_Index is
   begin
      for Position in P.Components.First_Index .. P.Components.Last_Index loop
         if P.Components (Position).Root_Id = Root_Id then
            return Position;
         end if;
      end loop;
      return Component_Vectors.No_Index;
   end Find_Component;

   function Find_Block
     (Document : Coyote_Renderer.Semantics.Document;
      Root_Id  : Natural) return Coyote_Renderer.Semantics.Block_Id is
      package S renames Coyote_Renderer.Semantics;
   begin
      for Position in 1 .. S.Block_Count (Document) loop
         declare
            Block : constant S.Block_Id := S.Block_At (Document, Position);
         begin
            if S.Block_Semantic_Root_Id (Document, Block) = Root_Id then
               return Block;
            end if;
         end;
      end loop;
      return S.No_Block;
   end Find_Block;

   procedure Create
     (P      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class) is
   begin
      Clear (P);
      P.Parent := Gtk.Box.Gtk_Box (Parent);
      Gtk.Box.Gtk_New_Vbox (P.Response, Homogeneous => False, Spacing => 2);
      P.Response.Set_Name ("coyote-response-rendered");
      P.Placeholder := new Component;
      Gtk.Box.Gtk_New_Vbox
        (P.Placeholder.Outer, Homogeneous => False, Spacing => 0);
      Gtk.Box.Gtk_New_Vbox
        (P.Placeholder.Payload, Homogeneous => False, Spacing => 2);
      P.Placeholder.Kind := Text_Component;
      P.Placeholder.Root_Id := 0;
      P.Placeholder.Committed := True;
      P.Placeholder.Outer.Pack_Start
        (P.Placeholder.Payload, Expand => False, Fill => True, Padding => 2);
      P.Response.Pack_Start
        (P.Placeholder.Outer, Expand => False, Fill => True, Padding => 2);
      Set_Text (P, P.Placeholder.all, "");
      Parent.Pack_Start (P.Response, Expand => False, Fill => True, Padding => 2);
   end Create;

   procedure Mark_Dirty (P : in out Instance; Root_Id : Natural) is
   begin
      if Root_Id /= 0 then
         if not P.Dirty_Roots.Contains (Root_Id) then
            P.Dirty_Roots.Append (Root_Id);
         end if;
         for C of P.Components loop
            if C.Root_Id = Root_Id then
               C.Dirty := True;
            end if;
         end loop;
      end if;
   end Mark_Dirty;

   procedure Record_Invalid (P : in out Instance) is
   begin
      P.Invalid_Count := P.Invalid_Count + 1;
   end Record_Invalid;

   procedure Commit_Root (P : in out Instance; Root_Id : Natural) is
   begin
      if Root_Id /= 0 then
         if not P.Committed.Contains (Root_Id) then
            P.Committed.Append (Root_Id);
         end if;
         for C of P.Components loop
            if C.Root_Id = Root_Id then
               C.Dirty := True;
            end if;
         end loop;
      end if;
   end Commit_Root;

   procedure Reconcile
     (P                       : in out Instance;
      Document                :        Coyote_Renderer.Semantics.Document;
      Normalize_Terminal_Math :        Boolean := False) is
      package S renames Coyote_Renderer.Semantics;
      Count       : constant Natural := S.Block_Count (Document);
      Focused_Root : Natural := 0;
      Had_Focus    : Boolean := False;
      C            : Component_Access;
   begin
      if P.Response = null then
         return;
      end if;
      for Item of P.Components loop
         if Item.View /= null and then Item.View.Is_Focus then
            Focused_Root := Item.Root_Id;
            Had_Focus := True;
         end if;
      end loop;
      if Count = 0 then
         while not P.Components.Is_Empty loop
            Remove_Component (P, P.Components.Last_Index);
         end loop;
         if P.Placeholder = null then
            P.Placeholder := new Component;
            Gtk.Box.Gtk_New_Vbox
              (P.Placeholder.Outer, Homogeneous => False, Spacing => 0);
            Gtk.Box.Gtk_New_Vbox
              (P.Placeholder.Payload, Homogeneous => False, Spacing => 2);
            P.Placeholder.Kind := Text_Component;
            P.Placeholder.Root_Id := 0;
            P.Placeholder.Committed := True;
            P.Placeholder.Outer.Pack_Start
              (P.Placeholder.Payload, Expand => False, Fill => True, Padding => 2);
            P.Response.Pack_Start
              (P.Placeholder.Outer, Expand => False, Fill => True, Padding => 2);
            Set_Text (P, P.Placeholder.all, "");
         end if;
         P.Dirty_Roots.Clear;
         P.Active := P.Placeholder.View;
         P.Response.Show_All;
         return;
      end if;
      declare
         First_Block : constant S.Block_Id := S.Block_At (Document, 1);
         First_Root  : constant Natural := S.Block_Semantic_Root_Id
           (Document, First_Block);
         First_Native : constant Boolean :=
           Is_Native_Kind (Document, First_Block)
           and then Is_Committed (P, First_Root);
      begin
         if P.Placeholder /= null and then First_Native then
            Clear_Component (P.Placeholder.all);
            if P.Placeholder.Outer.Get_Parent /= null then
               P.Response.Remove (P.Placeholder.Outer);
            end if;
            Free (P.Placeholder);
            P.Placeholder := null;
         elsif P.Placeholder /= null then
            C := P.Placeholder;
            P.Placeholder := null;
            C.Root_Id := First_Root;
            C.Block := First_Block;
            C.Dirty := True;
            P.Components.Append (C);
         end if;
      end;
      declare
         Position : Component_Vectors.Extended_Index :=
           P.Components.First_Index;
      begin
         while Position <= P.Components.Last_Index loop
            if Find_Block
              (Document, P.Components (Position).Root_Id) = S.No_Block
            then
               Remove_Component (P, Position);
            else
               Position := Position + 1;
            end if;
         end loop;
      end;
      for Index in 1 .. Count loop
         declare
            Block  : constant S.Block_Id := S.Block_At (Document, Index);
            Root_Id : constant Natural := S.Block_Semantic_Root_Id
              (Document, Block);
            Existing : Component_Vectors.Extended_Index :=
              Find_Component (P, Root_Id);
            Desired : constant Positive := Positive (Index);
         begin
            if Existing = Component_Vectors.No_Index then
               C := new Component;
               Create_Component (P, C.all, Document, Block,
                                 Normalize_Terminal_Math);
               P.Components.Insert (Desired, C);
            else
               C := P.Components (Existing);
               Update_Component (P, C.all, Document, Block,
                                Normalize_Terminal_Math);
               if Existing /= Desired then
                  P.Components.Delete (Existing);
                  P.Components.Insert (Desired, C);
               end if;
            end if;
            P.Response.Reorder_Child
              (C.Outer, Glib.Gint (Desired - 1));
         end;
      end loop;
      P.Dirty_Roots.Clear;
      P.Active := null;
      for Item of P.Components loop
         if Item.View /= null then
            P.Active := Item.View;
         end if;
      end loop;
      if Had_Focus and then Focused_Root /= 0 then
         declare
            Position : constant Component_Vectors.Extended_Index :=
              Find_Component (P, Focused_Root);
         begin
            if Position /= Component_Vectors.No_Index
              and then P.Components (Position).View /= null
            then
               P.Components (Position).View.Grab_Focus;
            end if;
         end;
      end if;
      P.Response.Show_All;
   end Reconcile;

   procedure Set_Font
     (P          : in out Instance;
      Desc       :        Pango.Font.Pango_Font_Description;
      Math_Scale :        Long_Float := 1.0) is
   begin
      P.Font_Name := To_Unbounded_String (Pango.Font.To_String (Desc));
      P.Math_Scale := Long_Float'Max (Math_Scale, 0.01);
      if P.Placeholder /= null and then P.Placeholder.View /= null then
         P.Placeholder.View.Modify_Font (Desc);
      end if;
      for C of P.Components loop
         if C.View /= null then
            C.View.Modify_Font (Desc);
         end if;
         Coyote_GUI.Response_Renderer.Set_Font
           (C.Renderer, Desc, P.Math_Scale);
      end loop;
   end Set_Font;

   procedure Clear (P : in out Instance) is
   begin
      while not P.Components.Is_Empty loop
         Remove_Component (P, P.Components.Last_Index);
      end loop;
      if P.Placeholder /= null then
         Clear_Component (P.Placeholder.all);
         if P.Placeholder.Outer /= null
           and then P.Placeholder.Outer.Get_Parent /= null
         then
            P.Response.Remove (P.Placeholder.Outer);
         end if;
         Free (P.Placeholder);
         P.Placeholder := null;
      end if;
      P.Committed.Clear;
      P.Dirty_Roots.Clear;
      if P.Response /= null and then P.Response.Get_Parent /= null then
         P.Parent.Remove (P.Response);
      end if;
      P.Parent := null;
      P.Response := null;
      P.Active := null;
      P.Invalid_Count := 0;
   end Clear;

   function Root (P : Instance) return Gtk.Box.Gtk_Box is
   begin
      return P.Response;
   end Root;

   function Root_Outer
     (P : Instance; Root_Id : Natural) return Gtk.Box.Gtk_Box is
   begin
      for C of P.Components loop
         if C.Root_Id = Root_Id then
            return C.Outer;
         end if;
      end loop;
      return null;
   end Root_Outer;

   function Selection_View (P : Instance) return Gtk.Text_View.Gtk_Text_View is
   begin
      for C of P.Components loop
         if C.View /= null and then C.Buffer.Get_Has_Selection then
            return C.View;
         end if;
      end loop;
      return P.Active;
   end Selection_View;

   function Active_Buffer (P : Instance) return Gtk.Text_Buffer.Gtk_Text_Buffer is
   begin
      if P.Active = null then
         return null;
      end if;
      return P.Active.Get_Buffer;
   end Active_Buffer;

   function Active_View (P : Instance) return Gtk.Text_View.Gtk_Text_View is
   begin
      return P.Active;
   end Active_View;

   function Invalid_Event_Count (P : Instance) return Natural is
   begin
      return P.Invalid_Count;
   end Invalid_Event_Count;

   function Text_View_Count (P : Instance) return Natural is
      Result : Natural := 0;
   begin
      for C of P.Components loop
         if C.View /= null then
            Result := Result + 1;
         end if;
      end loop;
      return Result;
   end Text_View_Count;

   function Text_View_At
     (P : Instance; Index : Positive) return Gtk.Text_View.Gtk_Text_View is
      Remaining : Natural := Index;
   begin
      for C of P.Components loop
         if C.View /= null then
            if Remaining = 1 then
               return C.View;
            end if;
            Remaining := Remaining - 1;
         end if;
      end loop;
      return null;
   end Text_View_At;

   function Table_Count (P : Instance) return Natural is
      Result : Natural := 0;
   begin
      for C of P.Components loop
         Result := Result + Coyote_GUI.Response_Renderer.Table_Count (C.Renderer);
      end loop;
      return Result;
   end Table_Count;

   function Table_Grid_At
     (P : Instance; Index : Positive) return Gtk.Grid.Gtk_Grid is
      Remaining : Natural := Index;
   begin
      for C of P.Components loop
         for Item in 1 .. Coyote_GUI.Response_Renderer.Table_Count (C.Renderer) loop
            if Remaining = 1 then
               return Coyote_GUI.Response_Renderer.Table_Grid_At
                 (C.Renderer, Item);
            end if;
            Remaining := Remaining - 1;
         end loop;
      end loop;
      return null;
   end Table_Grid_At;

   function Math_Element_Count (P : Instance) return Natural is
      Result : Natural := 0;
   begin
      for C of P.Components loop
         Result := Result +
           Coyote_GUI.Response_Renderer.Math_Element_Count (C.Renderer);
      end loop;
      return Result;
   end Math_Element_Count;

   function Math_Element_At
     (P : Instance; Index : Positive)
      return Coyote_GUI.Math_Element.Instance_Access is
      Remaining : Natural := Index;
   begin
      for C of P.Components loop
         for Item in 1 .. Coyote_GUI.Response_Renderer.Math_Element_Count
           (C.Renderer)
         loop
            if Remaining = 1 then
               return Coyote_GUI.Response_Renderer.Math_Element_At
                 (C.Renderer, Item);
            end if;
            Remaining := Remaining - 1;
         end loop;
      end loop;
      return null;
   end Math_Element_At;

end Coyote_GUI.Semantic_Response_Presenter;
