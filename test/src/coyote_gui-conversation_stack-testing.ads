--  Coyote_GUI.Conversation_Stack.Testing — test accessors.
--
--  Project: coyote

with Coyote_GUI;
with Coyote_GUI.Conversation_Stack;
with Gtk.Scrolled_Window;

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

end Coyote_GUI.Conversation_Stack.Testing;
