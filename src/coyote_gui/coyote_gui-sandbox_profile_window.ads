--  Coyote_GUI.Sandbox_Profile_Window — reusable sandbox profile manager.
--
--  The support window is modeless and owns no agent task.  It persists named
--  profiles through LLM.Tools.Sandbox and queues a named profile on request.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with Coyote_GUI.Prompt_Queue;
with Gtk.Box;
with Gtk.Button;
with Gtk.GEntry;
with Gtk.Label;
with Gtk.List_Box;
with Gtk.Window;
with LLM.Tools.Sandbox;

package Coyote_GUI.Sandbox_Profile_Window is

   type Instance is private;

   --  Construct the reusable manager, transient for Main_Window.
   procedure Create
     (S               : aliased in out Instance;
      Main_Window     : not null access Gtk.Window.Gtk_Window_Record'Class;
      Prompt_Queue    : not null access Coyote_GUI.Prompt_Queue.Queue;
      Target_Agent_Id : String := "");

   function Is_Created (S : Instance) return Boolean;

   function Window_Title (S : Instance) return String;

   procedure Show (S : in out Instance);

   --  Reload the available profile names and preserve the selection where
   --  possible.  An active editor is left unchanged.
   procedure Refresh (S : in out Instance);

private

   type Instance is record
      Window          : Gtk.Window.Gtk_Window := null;
      Main_Window     : access Gtk.Window.Gtk_Window_Record'Class := null;
      Queue           : access Coyote_GUI.Prompt_Queue.Queue := null;
      Target_Agent_Id : Ada.Strings.Unbounded.Unbounded_String;
      Names           : LLM.Tools.Sandbox.String_Vectors.Vector;
      Selected_Name   : Ada.Strings.Unbounded.Unbounded_String;
      Original_Name   : Ada.Strings.Unbounded.Unbounded_String;
      Profile         : LLM.Tools.Sandbox.Profile;
      Profile_List    : Gtk.List_Box.Gtk_List_Box := null;
      Name_Entry      : Gtk.GEntry.Gtk_Entry := null;
      Allow_Write     : Gtk.List_Box.Gtk_List_Box := null;
      Deny_Write      : Gtk.List_Box.Gtk_List_Box := null;
      Deny_Read       : Gtk.List_Box.Gtk_List_Box := null;
      Allow_Read      : Gtk.List_Box.Gtk_List_Box := null;
      Details         : Gtk.Label.Gtk_Label := null;
      Status          : Gtk.Label.Gtk_Label := null;
      Editor          : Gtk.Box.Gtk_Box := null;
      Detail_Box      : Gtk.Box.Gtk_Box := null;
      Save_Button     : Gtk.Button.Gtk_Button := null;
      Cancel_Button   : Gtk.Button.Gtk_Button := null;
      Edit_Mode       : Boolean := False;
      New_Profile     : Boolean := False;
      Refreshing      : Boolean := False;
      Created         : Boolean := False;
   end record;

end Coyote_GUI.Sandbox_Profile_Window;
