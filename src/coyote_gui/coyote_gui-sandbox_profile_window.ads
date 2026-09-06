--  Coyote_GUI.Sandbox_Profile_Window — reusable sandbox profile manager.
--
--  The support window is modeless and owns no agent task.  It keeps typed
--  profile drafts in memory and persists dirty drafts through Save.
--
--  Project: coyote

with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Coyote_GUI.Prompt_Queue;
with Gtk.Box;
with Gtk.Button;
with Gtk.GEntry;
with Gtk.Label;
with Gtk.List_Box;
with Gtk.List_Store;
with Gtk.Tree_View;
with Gtk.Window;
with LLM.Tools.Sandbox;

package Coyote_GUI.Sandbox_Profile_Window is

   type Use_Profile_Handler is access procedure
     (Profile_Name : String);

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

   --  Update the live agent that receives Use Profile.
   procedure Set_Target_Agent
     (S               : in out Instance;
      Target_Agent_Id : String);

   --  Route Use Profile through the owning frontend when supplied.
   procedure Set_Use_Profile_Handler
     (S       : in out Instance;
      Handler : Use_Profile_Handler);

   --  Refresh persisted profiles without discarding dirty in-memory drafts.
   procedure Refresh (S : in out Instance);

private

   type Profile_Draft is record
      Name          : Ada.Strings.Unbounded.Unbounded_String;
      Baseline_Name : Ada.Strings.Unbounded.Unbounded_String;
      Profile       : LLM.Tools.Sandbox.Profile;
      Baseline      : LLM.Tools.Sandbox.Profile;
      Is_New        : Boolean := False;
      Dirty         : Boolean := False;
   end record;

   package Draft_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => Profile_Draft);

   type Instance is record
      Window          : Gtk.Window.Gtk_Window := null;
      Main_Window     : access Gtk.Window.Gtk_Window_Record'Class := null;
      Queue           : access Coyote_GUI.Prompt_Queue.Queue := null;
      Target_Agent_Id : Ada.Strings.Unbounded.Unbounded_String;
      Use_Handler     : Use_Profile_Handler := null;
      Drafts          : Draft_Vectors.Vector;
      Selected_Draft  : Natural := 0;
      Profile_List    : Gtk.List_Box.Gtk_List_Box := null;
      Name_Entry      : Gtk.GEntry.Gtk_Entry := null;
      Path_View          : Gtk.Tree_View.Gtk_Tree_View := null;
      Path_Store         : Gtk.List_Store.Gtk_List_Store := null;
      Add_Path_Button    : Gtk.Button.Gtk_Button := null;
      Edit_Path_Button   : Gtk.Button.Gtk_Button := null;
      Remove_Path_Button : Gtk.Button.Gtk_Button := null;
      Status             : Gtk.Label.Gtk_Label := null;
      Editor             : Gtk.Box.Gtk_Box := null;
      Save_Button        : Gtk.Button.Gtk_Button := null;
      Cancel_Button      : Gtk.Button.Gtk_Button := null;
      Refreshing         : Boolean := False;
      Updating_Editor    : Boolean := False;
      Created            : Boolean := False;
   end record;

end Coyote_GUI.Sandbox_Profile_Window;
