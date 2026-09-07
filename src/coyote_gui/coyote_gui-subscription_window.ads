--  Coyote_GUI.Subscription_Window -- reusable provider subscription manager.
--
--  The support window is modeless and owns no agent task.  It lists
--  configured LLM provider subscriptions with their credential state and
--  exposes Login / Refresh / Logout actions.  The browser OAuth login runs
--  in a background task owned by the window body; its completion is
--  delivered back to the GTK main loop through a poll idle that also
--  refreshes credential state once the task finishes.
--
--  Project: coyote

with Coyote_GUI.Prompt_Queue;
with Gtk.Button;
with Gtk.List_Store;
with Gtk.Label;
with Gtk.Tree_View;
with Gtk.Window;

package Coyote_GUI.Subscription_Window is

   type Instance is private;

   --  Construct the reusable manager, transient for Main_Window.
   procedure Create
     (S            : aliased in out Instance;
      Main_Window  : not null access Gtk.Window.Gtk_Window_Record'Class;
      Prompt_Queue : not null access Coyote_GUI.Prompt_Queue.Queue);

   function Is_Created (S : Instance) return Boolean;

   function Window_Title (S : Instance) return String;

   procedure Show (S : in out Instance);

   --  Re-read credential state from disk and rebuild the rows.  Call from
   --  the GTK main task.
   procedure Refresh (S : in out Instance);

   --  True while a browser login runs in the background.
   function Login_Running (S : Instance) return Boolean;

private

   type Instance is record
      Window         : Gtk.Window.Gtk_Window := null;
      Main_Window    : access Gtk.Window.Gtk_Window_Record'Class := null;
      Queue          : access Coyote_GUI.Prompt_Queue.Queue := null;
      Provider_View  : Gtk.Tree_View.Gtk_Tree_View := null;
      Provider_Store : Gtk.List_Store.Gtk_List_Store := null;
      Status_Field   : Gtk.Label.Gtk_Label := null;
      Account_Field  : Gtk.Label.Gtk_Label := null;
      Login_Button   : Gtk.Button.Gtk_Button := null;
      Refresh_Button : Gtk.Button.Gtk_Button := null;
      Logout_Button  : Gtk.Button.Gtk_Button := null;
      Status         : Gtk.Label.Gtk_Label := null;
      Login_Active   : Boolean := False;
      Created        : Boolean := False;
   end record;

end Coyote_GUI.Subscription_Window;
