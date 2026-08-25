--  Coyote_GUI.Conversation_Stack.Testing body.
--
--  Project: coyote

package body Coyote_GUI.Conversation_Stack.Testing is

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

end Coyote_GUI.Conversation_Stack.Testing;
