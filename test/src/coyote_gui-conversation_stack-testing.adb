--  Coyote_GUI.Conversation_Stack.Testing body.
--
--  Project: coyote

with Gtk.Text_Buffer;
with Gtk.Text_Iter;

package body Coyote_GUI.Conversation_Stack.Testing is

   use type Gtk.Label.Gtk_Label;
   use type Gtk.Text_Buffer.Gtk_Text_Buffer;

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

   function Math_Element_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      return Natural (C.Math_Elements.Length);
   end Math_Element_Count;

   function Math_Source
     (C     : Coyote_GUI.Conversation_Stack.Instance;
      Index : Positive) return String
   is
   begin
      if Index <= Natural (C.Math_Elements.Length) then
         return Coyote_GUI.Math_Element.Source
           (C.Math_Elements (Index).all);
      end if;
      return "";
   end Math_Source;

   function Math_Is_Valid
     (C     : Coyote_GUI.Conversation_Stack.Instance;
      Index : Positive) return Boolean
   is
   begin
      return Index <= Natural (C.Math_Elements.Length)
        and then Coyote_GUI.Math_Element.Is_Valid
          (C.Math_Elements (Index).all);
   end Math_Is_Valid;

   function Math_Width
     (C     : Coyote_GUI.Conversation_Stack.Instance;
      Index : Positive) return Natural
   is
   begin
      if Index <= Natural (C.Math_Elements.Length) then
         return Coyote_GUI.Math_Element.Width
           (C.Math_Elements (Index).all);
      end if;
      return 0;
   end Math_Width;

   function Math_Height
     (C     : Coyote_GUI.Conversation_Stack.Instance;
      Index : Positive) return Natural
   is
   begin
      if Index <= Natural (C.Math_Elements.Length) then
         return Coyote_GUI.Math_Element.Height
           (C.Math_Elements (Index).all);
      end if;
      return 0;
   end Math_Height;

   function Math_Scale
     (C     : Coyote_GUI.Conversation_Stack.Instance;
      Index : Positive) return Long_Float
   is
   begin
      if Index <= Natural (C.Math_Elements.Length) then
         return Coyote_GUI.Math_Element.Scale
           (C.Math_Elements (Index).all);
      end if;
      return 0.0;
   end Math_Scale;

   function Step_Frame_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural
   is
   begin
      return Natural (C.Step_Frames.Length);
   end Step_Frame_Count;

   function Active_Step_Frame
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Frame.Gtk_Frame
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
     (C       : Coyote_GUI.Conversation_Stack.Instance;
      Tool_Id : String) return String
   is
   begin
      return C.Tool_Summary (Tool_Id);
   end Tool_Summary;

   function Tool_Detail
     (C       : Coyote_GUI.Conversation_Stack.Instance;
      Tool_Id : String) return Coyote_GUI.Conversation.Tool_Info
   is
   begin
      return C.Tool_Detail (Tool_Id);
   end Tool_Detail;

   function Details_Label
     (C       : Coyote_GUI.Conversation_Stack.Instance;
      Tool_Id : String) return String
   is
   begin
      if C.Tools.Contains (Tool_Id) then
         return C.Tools.Element (Tool_Id).Details.Get_Label;
      end if;
      return "";
   end Details_Label;

   function Details_Enabled
     (C       : Coyote_GUI.Conversation_Stack.Instance;
      Tool_Id : String) return Boolean
   is
   begin
      if C.Tools.Contains (Tool_Id) then
         return C.Tools.Element (Tool_Id).Details.Get_Sensitive;
      end if;
      return False;
   end Details_Enabled;

   function Footer_Separator
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Separator.Gtk_Separator
   is
   begin
      return C.Footer_Separator;
   end Footer_Separator;

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
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Button.Gtk_Button
   is
   begin
      return C.Fork_Button;
   end Fork_Button;

end Coyote_GUI.Conversation_Stack.Testing;
