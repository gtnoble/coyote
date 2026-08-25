--  Coyote_GUI.Conversation_Stack.Testing — test accessors.
--
--  Project: coyote

with Coyote_GUI;
with Coyote_GUI.Conversation;
with Coyote_GUI.Conversation_Stack;
with Gtk.Button;
with Gtk.Frame;
with Gtk.Scrolled_Window;
with Gtk.Separator;
with Gtk.Text_View;

package Coyote_GUI.Conversation_Stack.Testing is

   function Has_Exchange
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean;

   function Is_Completed
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean;

   function Last_Status
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Coyote_GUI.Completion_Status;

   function Tool_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural;

   function Host_Widget
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Scrolled_Window.Gtk_Scrolled_Window;

   function Active_Text_View
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Text_View.Gtk_Text_View;

   function Step_Frame_Count
     (C : Coyote_GUI.Conversation_Stack.Instance) return Natural;

   function Active_Step_Frame
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Frame.Gtk_Frame;

   function Tool_Summary
     (C       : Coyote_GUI.Conversation_Stack.Instance;
      Tool_Id : String) return String;

   function Tool_Detail
     (C       : Coyote_GUI.Conversation_Stack.Instance;
      Tool_Id : String) return Coyote_GUI.Conversation.Tool_Info;

   function Details_Label
     (C       : Coyote_GUI.Conversation_Stack.Instance;
      Tool_Id : String) return String;

   function Details_Enabled
     (C       : Coyote_GUI.Conversation_Stack.Instance;
      Tool_Id : String) return Boolean;

   function Footer_Separator
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Separator.Gtk_Separator;

   function Footer_Summary
     (C : Coyote_GUI.Conversation_Stack.Instance) return String;

   function Footer_Summary_Selectable
     (C : Coyote_GUI.Conversation_Stack.Instance) return Boolean;

   function Fork_Button
     (C : Coyote_GUI.Conversation_Stack.Instance)
      return Gtk.Button.Gtk_Button;

end Coyote_GUI.Conversation_Stack.Testing;
