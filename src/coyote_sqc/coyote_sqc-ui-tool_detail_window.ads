--  Coyote_SQC.UI.Tool_Detail_Window — non-modal tool call detail window.
--
--  Opens a new independent GtkWindow for a single tool call, displaying
--  the tool arguments and result.  Multiple windows may be open
--  simultaneously; each closes only when the user clicks its close button.
--
--  Project: coyote

with Coyote_Renderer.Session_View;
with Coyote_SQC.Data_Model;
with Gtk.Window;

package Coyote_SQC.UI.Tool_Detail_Window is

   --  Open a new non-modal tool call detail window transient for Main_Window.
   --  All closure data is passed directly; no session file is re-parsed.
   procedure Show
     (Tool_Name    : in String;
      Arguments    : in String;
      Result_Text  : in String;
      Is_Image     : in Boolean;
      Status       : in Coyote_Renderer.Session_View.Tool_End_Status;
      Turn_Index   : in Positive;
      Call_In_Turn : in Positive;
      Session      : in Coyote_SQC.Data_Model.Session_Record;
      Main_Window  : not null access Gtk.Window.Gtk_Window_Record'Class);

end Coyote_SQC.UI.Tool_Detail_Window;
