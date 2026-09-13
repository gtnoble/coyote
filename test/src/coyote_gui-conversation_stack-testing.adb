--  Coyote_GUI.Conversation_Stack.Testing body.
--
--  Project: coyote

with Coyote_GUI.Math_Element.Testing;
with Coyote_GUI.Response_Renderer;
with Glib;
with Gtk.Container;
with Gtk.Style_Context;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Widget;

package body Coyote_GUI.Conversation_Stack.Testing is

   use type Gtk.Label.Gtk_Label;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;
   use type Gtk.Widget.Gtk_Widget;
   use type Coyote_GUI.Math_Element.Instance_Access;
   use type Gtk.Widget.Widget_List.Glist;

   function Uses_Shared_Renderer
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean
   is
   begin
      return C.Response_Format = Coyote_GUI.Coyote_Stream_2_Response;
   end Uses_Shared_Renderer;

   function Math_Element_At
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Coyote_GUI.Math_Element.Instance_Access
   is
   begin
      if Uses_Shared_Renderer (C) then
         return Coyote_GUI.Response_Renderer.Math_Element_At
           (C.Response_Renderer, Index);
      elsif Index <= Natural (C.Math_Elements.Length) then
         return C.Math_Elements (Index);
      end if;
      return null;
   end Math_Element_At;

   function Has_Exchange
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean
   is
   begin
      return C.Has_Exchange;
   end Has_Exchange;

   function Is_Completed
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean
   is
   begin
      return C.Completed;
   end Is_Completed;

   function Last_Status
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Coyote_GUI.Completion_Status
   is
   begin
      return C.Last_Status;
   end Last_Status;

   function Tool_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      return Natural (C.Tools.Length);
   end Tool_Count;

   function Host_Widget
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Scrolled_Window.Gtk_Scrolled_Window
   is
   begin
      return C.Scroll;
   end Host_Widget;

   function Active_Text_View
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Text_View.Gtk_Text_View
   is
   begin
      return C.Active_View;
   end Active_Text_View;

   function Active_Text
     (C : Coyote_GUI.Conversation_Stack.Instance) return String
   is
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      if C.Active_Text = null then
         return "";
      end if;
      C.Active_Text.Get_Start_Iter (Start_Iter);
      C.Active_Text.Get_End_Iter (End_Iter);
      return C.Active_Text.Get_Text (Start_Iter, End_Iter);
   end Active_Text;

   function Response_Box
     (C : Coyote_GUI.Conversation_Stack.Instance) return Gtk.Box.Gtk_Box
   is
   begin
      return C.Response_Box;
   end Response_Box;

   function Response_Stream_Present
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean
   is
      Children : Gtk.Widget.Widget_List.Glist;
      Child    : Gtk.Widget.Gtk_Widget;
   begin
      if C.Response_Section = null then
         return False;
      end if;
      Children :=
        Gtk.Container.Get_Children
          (Gtk.Container.Gtk_Container (C.Response_Section));
      Children := Gtk.Widget.Widget_List.First (Children);
      while Children /= Gtk.Widget.Widget_List.Null_List loop
         Child := Gtk.Widget.Widget_List.Get_Data (Children);
         if Child /= null and then Child.Get_Name = "coyote-response-stream"
         then
            return True;
         end if;
         Children := Gtk.Widget.Widget_List.Next (Children);
      end loop;
      return False;
   end Response_Stream_Present;

   function Live_Response_Present
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean
   is
   begin
      return Coyote_GUI.Live_Response_Renderer.Widget (C.Live_Renderer) /= null
        and then not Coyote_GUI.Live_Response_Renderer.Is_Finalized
          (C.Live_Renderer);
   end Live_Response_Present;

   function Live_Response_Text
     (C : Coyote_GUI.Conversation_Stack.Instance) return String
   is
   begin
      return Coyote_GUI.Live_Response_Renderer.Text (C.Live_Renderer);
   end Live_Response_Text;

   function Live_Response_Invalid_Event_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      return Coyote_GUI.Live_Response_Renderer.Invalid_Event_Count
        (C.Live_Renderer);
   end Live_Response_Invalid_Event_Count;

   function Live_Response_Text_Has_Style
     (C      : Coyote_GUI.Conversation_Stack.Instance;
      Style  : Coyote_GUI.Live_Response_Renderer.Style_Kind;
      Offset : Natural) return Boolean
   is
   begin
      return Coyote_GUI.Live_Response_Renderer.Has_Style
        (C.Live_Renderer, Style, Offset);
   end Live_Response_Text_Has_Style;

   function Response_Text_Has_Style
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean
   is
   begin
      return
        C.Active_View /= null
        and then Gtk.Style_Context.Get_Style_Context (C.Active_View).Has_Class
          ("coyote-response-content");
   end Response_Text_Has_Style;

   function Active_Step_Child_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      if C.Step_Box = null then
         return 0;
      end if;
      return
        Natural
          (Gtk.Widget.Widget_List.Length
             (Gtk.Container.Get_Children
                (Gtk.Container.Gtk_Container (C.Step_Box))));
   end Active_Step_Child_Count;

   function Active_Step_Child_Name
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return String
   is
      Children : Gtk.Widget.Widget_List.Glist;
      Child    : Gtk.Widget.Gtk_Widget;
   begin
      if C.Step_Box = null then
         return "";
      end if;
      Children :=
        Gtk.Container.Get_Children (Gtk.Container.Gtk_Container (C.Step_Box));
      Children := Gtk.Widget.Widget_List.First (Children);
      for Position in 1 .. Index loop
         exit when Children = Gtk.Widget.Widget_List.Null_List;
         Child := Gtk.Widget.Widget_List.Get_Data (Children);
         if Position = Index and then Child /= null then
            return Child.Get_Name;
         end if;
         Children := Gtk.Widget.Widget_List.Next (Children);
      end loop;
      return "";
   end Active_Step_Child_Name;

   function Active_Step_Child_Text
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return String
   is
      Children : Gtk.Widget.Widget_List.Glist;
      Child    : Gtk.Widget.Gtk_Widget;
   begin
      if C.Step_Box = null then
         return "";
      end if;
      Children :=
        Gtk.Widget.Widget_List.First
          (Gtk.Container.Get_Children
             (Gtk.Container.Gtk_Container (C.Step_Box)));
      for Position in 1 .. Index loop
         exit when Children = Gtk.Widget.Widget_List.Null_List;
         Child := Gtk.Widget.Widget_List.Get_Data (Children);
         if Position = Index and then Child /= null then
            if Child.Get_Name = "GtkLabel" then
               return Gtk.Label.Gtk_Label (Child).Get_Text;
            end if;
            return "";
         end if;
         Children := Gtk.Widget.Widget_List.Next (Children);
      end loop;
      return "";
   end Active_Step_Child_Text;

   function Text_View_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      if Uses_Shared_Renderer (C) then
         return Coyote_GUI.Response_Renderer.Text_View_Count
           (C.Response_Renderer);
      end if;
      return Natural (C.Text_Views.Length);
   end Text_View_Count;

   function Text_View_Text
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return String
   is
      Start_Iter : Gtk.Text_Iter.Gtk_Text_Iter;
      End_Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      View       : Gtk.Text_View.Gtk_Text_View;
      Buffer     : Gtk.Text_Buffer.Gtk_Text_Buffer;
   begin
      if Index <= Natural (C.Text_Views.Length) then
         View := C.Text_Views (Index);
      else
         View :=
           Coyote_GUI.Response_Renderer.Text_View_At
             (C.Response_Renderer, Index - Natural (C.Text_Views.Length));
      end if;
      if View = null then
         return "";
      end if;
      Buffer := View.Get_Buffer;
      if Buffer = null then
         return "";
      end if;
      Buffer.Get_Start_Iter (Start_Iter);
      Buffer.Get_End_Iter (End_Iter);
      return Buffer.Get_Text (Start_Iter, End_Iter);
   end Text_View_Text;

   function Table_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      if Uses_Shared_Renderer (C) then
         return Coyote_GUI.Response_Renderer.Table_Count (C.Response_Renderer);
      end if;
      return Natural (C.Table_Grids.Length);
   end Table_Count;

   function Table_Grid
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Gtk.Grid.Gtk_Grid
   is
   begin
      if Uses_Shared_Renderer (C) then
         return Coyote_GUI.Response_Renderer.Table_Grid_At
           (C.Response_Renderer, Index);
      elsif Index <= Natural (C.Table_Grids.Length) then
         return C.Table_Grids (Index);
      end if;
      return null;
   end Table_Grid;

   function Table_Cell
     (C   : Coyote_GUI.Conversation_Stack.Instance; Table : Positive;
      Row : Positive; Column : Positive) return Gtk.Label.Gtk_Label
   is
      Grid  : constant Gtk.Grid.Gtk_Grid := Table_Grid (C, Table);
      Child : Gtk.Widget.Gtk_Widget;
   begin
      if Grid = null then
         return null;
      end if;
      Child := Grid.Get_Child_At (Glib.Gint (Column - 1), Glib.Gint (Row - 1));
      if Child = null then
         return null;
      end if;
      return Gtk.Label.Gtk_Label (Child);
   end Table_Cell;

   function Math_Area_Visible
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Boolean
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Math_Element_At (C, Index);
   begin
      return
        Element /= null
        and then Coyote_GUI.Math_Element.Testing.Area_Visible (Element.all);
   end Math_Area_Visible;

   function Math_Fallback_Visible
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Boolean
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Math_Element_At (C, Index);
   begin
      return
        Element /= null
        and then Coyote_GUI.Math_Element.Testing.Fallback_Visible
          (Element.all);
   end Math_Fallback_Visible;

   function Math_Has_Response_Style
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Boolean
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Math_Element_At (C, Index);
   begin
      return
        Element /= null
        and then Coyote_GUI.Math_Element.Testing.Has_Response_Style
          (Element.all);
   end Math_Has_Response_Style;

   function Math_Element_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      if Uses_Shared_Renderer (C) then
         return Coyote_GUI.Response_Renderer.Math_Element_Count
           (C.Response_Renderer);
      end if;
      return Natural (C.Math_Elements.Length);
   end Math_Element_Count;

   function Math_Source
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return String
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Math_Element_At (C, Index);
   begin
      if Element = null then
         return "";
      end if;
      return Coyote_GUI.Math_Element.Source (Element.all);
   end Math_Source;

   function Math_Is_Valid
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Boolean
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Math_Element_At (C, Index);
   begin
      return
        Element /= null
        and then Coyote_GUI.Math_Element.Is_Valid (Element.all);
   end Math_Is_Valid;

   function Math_Width
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Natural
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Math_Element_At (C, Index);
   begin
      if Element = null then
         return 0;
      end if;
      return Coyote_GUI.Math_Element.Width (Element.all);
   end Math_Width;

   function Math_Height
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Natural
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Math_Element_At (C, Index);
   begin
      if Element = null then
         return 0;
      end if;
      return Coyote_GUI.Math_Element.Height (Element.all);
   end Math_Height;

   function Math_Scale
     (C : Coyote_GUI.Conversation_Stack.Instance; Index : Positive)
      return Long_Float
   is
      Element : constant Coyote_GUI.Math_Element.Instance_Access :=
        Math_Element_At (C, Index);
   begin
      if Element = null then
         return 0.0;
      end if;
      return Coyote_GUI.Math_Element.Scale (Element.all);
   end Math_Scale;

   function Step_Frame_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      return Natural (C.Step_Frames.Length);
   end Step_Frame_Count;

   function Active_Step_Frame
     (C : Coyote_GUI.Conversation_Stack.Instance) return Gtk.Frame.Gtk_Frame
   is
   begin
      return C.Step_Frame;
   end Active_Step_Frame;

   function Tool_Flow
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Flow_Box.Gtk_Flow_Box
   is
   begin
      return C.Tool_Flow;
   end Tool_Flow;

   function Tool_Summary
     (C : Coyote_GUI.Conversation_Stack.Instance; Tool_Id : String)
      return String
   is
   begin
      return C.Tool_Summary (Tool_Id);
   end Tool_Summary;

   function Tool_Detail
     (C : Coyote_GUI.Conversation_Stack.Instance; Tool_Id : String)
      return Coyote_GUI.Tool_Info
   is
   begin
      return C.Tool_Detail (Tool_Id);
   end Tool_Detail;

   function Details_Label
     (C : Coyote_GUI.Conversation_Stack.Instance; Tool_Id : String)
      return String
   is
   begin
      if C.Tools.Contains (Tool_Id) then
         return C.Tools.Element (Tool_Id).Details.Get_Label;
      end if;
      return "";
   end Details_Label;

   function Details_Enabled
     (C : Coyote_GUI.Conversation_Stack.Instance; Tool_Id : String)
      return Boolean
   is
   begin
      if C.Tools.Contains (Tool_Id) then
         return C.Tools.Element (Tool_Id).Details.Get_Sensitive;
      end if;
      return False;
   end Details_Enabled;

   function Abort_Enabled
     (C : Coyote_GUI.Conversation_Stack.Instance; Tool_Id : String)
      return Boolean
   is
   begin
      if C.Tools.Contains (Tool_Id) then
         return C.Tools.Element (Tool_Id).Abort_Button.Get_Sensitive;
      end if;
      return False;
   end Abort_Enabled;

   function Abort_Message_Enabled
     (C : Coyote_GUI.Conversation_Stack.Instance; Tool_Id : String)
      return Boolean
   is
   begin
      if C.Tools.Contains (Tool_Id) then
         return C.Tools.Element (Tool_Id).Abort_Message_Button.Get_Sensitive;
      end if;
      return False;
   end Abort_Message_Enabled;

   function Tool_Action_Box
     (C : Coyote_GUI.Conversation_Stack.Instance; Tool_Id : String)
      return Gtk.Box.Gtk_Box
   is
   begin
      if C.Tools.Contains (Tool_Id) then
         return C.Tools.Element (Tool_Id).Action_Box;
      end if;
      return null;
   end Tool_Action_Box;

   function Footer_Separator
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Separator.Gtk_Separator
   is
   begin
      return C.Footer_Separator;
   end Footer_Separator;

   function Footer_Heading
     (C : Coyote_GUI.Conversation_Stack.Instance) return String
   is
   begin
      if C.Footer_Heading = null then
         return "";
      end if;
      return C.Footer_Heading.Get_Text;
   end Footer_Heading;

   function Footer_Summary
     (C : Coyote_GUI.Conversation_Stack.Instance) return String
   is
   begin
      if C.Footer_Label = null then
         return "";
      end if;
      return C.Footer_Label.Get_Text;
   end Footer_Summary;

   function Footer_Summary_Selectable
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean
   is
   begin
      if C.Footer_Label = null then
         return False;
      end if;
      return C.Footer_Label.Get_Selectable;
   end Footer_Summary_Selectable;

   function Fork_Button
     (C : Coyote_GUI.Conversation_Stack.Instance) return Gtk.Button.Gtk_Button
   is
   begin
      return C.Fork_Button;
   end Fork_Button;

end Coyote_GUI.Conversation_Stack.Testing;
