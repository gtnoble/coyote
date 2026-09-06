--  Coyote_Renderer.Session_View — render a Coyote session into a GtkTextBuffer.
--
--  Populate a GtkTextBuffer with a rendered session: assistant text
--  (with Markdown), thinking blocks, tool call frames, and user messages.
--  The buffer is cleared before rendering.  All operations happen on the
--  caller's thread (must be the GTK main loop thread).
--
--  Project: coyote

with Coyote_SQC.Data_Model;
with Gtk.Text_Buffer;
with Gtk.Text_View;

package Coyote_Renderer.Session_View is

   --  Status of a completed tool call, used in the clickable frame label
   --  and in the detail window status banner.
   type Tool_End_Status is (Success, Error, Cancelled);

   --  Callback invoked when the user clicks a tool call widget in the session
   --  replay.  All parameters are captured in the widget closure at render
   --  time; no re-parsing of the session file occurs at click time.
   type Tool_Click_Callback is access procedure
     (Tool_Name    :  String;
      Arguments    :  String;
      Result_Text  :  String;
      Is_Image     :  Boolean;
      Status       :  Tool_End_Status;
      Turn_Index   :  Positive;
      Call_In_Turn :  Positive;
      Session      :  Coyote_SQC.Data_Model.Session_Record);

   --  Render a session identified by Session into Buffer.
   --
   --  The raw session JSONL is re-read to obtain full message content.
   --  If the file cannot be located or read, the buffer will contain
   --  a brief error message.
   --
   --  When On_Tool_Click is non-null, each tool call is rendered as a
   --  clickable GtkButton widget embedded via GtkTextChildAnchor; clicking
   --  it invokes the callback with closure data captured at render time.
   --  When On_Tool_Click is null, tool calls are rendered as plain tagged
   --  text (non-interactive).
   procedure Render_Session
     (Session       :      Coyote_SQC.Data_Model.Session_Record;
      Buffer        : not null access Gtk.Text_Buffer.Gtk_Text_Buffer_Record'Class;
      View          : not null access Gtk.Text_View.Gtk_Text_View_Record'Class;
      On_Tool_Click :      Tool_Click_Callback := null);

   --  Return the JSONL file path for the given session UUID and source
   --  directory, or empty string if not found.
   function Find_Session_File
     (Session_Id       :  String;
      Source_Directory :  String) return String;

end Coyote_Renderer.Session_View;
