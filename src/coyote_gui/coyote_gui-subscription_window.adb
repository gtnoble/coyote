--  Coyote_GUI.Subscription_Window body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Glib;
with Glib.Main;
with Gtk.Box;
with Gtk.Cell_Renderer_Text;
with Coyote_GUI.Mnemonics;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Scrolled_Window;
with Gtk.Tree_Model;
with Gtk.Tree_Selection;
with Gtk.Tree_View_Column;
with Gtk.Widget;
with LLM.Auth;
with LLM.Auth.Codex;
with LLM.Auth.Codex.Login;

package body Coyote_GUI.Subscription_Window is

   use type Gtk.Label.Gtk_Label;
   use type Gtk.Button.Gtk_Button;
   use type Gtk.Window.Gtk_Window;
   use type Gdk.Types.Gdk_Modifier_Type;
   use type Glib.Gint;
   use Gtk.List_Store;
   use Gtk.Tree_Model;
   use Gtk.Tree_View;

   Current_Instance : access Instance := null;

   --  ── Provider rows ────────────────────────────────────────────────────

   --  One row per managed subscription provider; the list order is fixed
   --  so row index maps to the enum value.
   type Provider_State is
     (Codex_Subscription,
      GitHub_Copilot_Subscription);

   subtype Provider_Index is Natural range 0 .. 1;

   type Credential_Info is record
      Logged_In  : Boolean := False;
      Account    : Unbounded_String := Null_Unbounded_String;
      Expires_Ms : Long_Long_Integer := 0;
   end record;

   function Codex_Info return Credential_Info is
      Creds : constant LLM.Auth.Provider_Credentials :=
        LLM.Auth.Load_Credentials ("codex");
      Result : Credential_Info;
   begin
      Result.Logged_In :=
        Length (Creds.Refresh_Token) > 0
        or else Length (Creds.Access_Token) > 0;
      Result.Account := Creds.Account_Id;
      Result.Expires_Ms := Creds.Expires_Ms;
      return Result;
   end Codex_Info;

   function Copilot_Info return Credential_Info is
      Creds : constant LLM.Auth.Provider_Credentials :=
        LLM.Auth.Load_Credentials ("github-copilot");
      Result : Credential_Info;
   begin
      Result.Logged_In :=
        Length (Creds.Refresh_Token) > 0
        or else Length (Creds.Access_Token) > 0;
      Result.Expires_Ms := Creds.Expires_Ms;
      return Result;
   end Copilot_Info;

   function Info_For (State : Provider_State) return Credential_Info is
   begin
      case State is
         when Codex_Subscription =>
            return Codex_Info;
         when GitHub_Copilot_Subscription =>
            return Copilot_Info;
      end case;
   end Info_For;

   function Provider_Name (State : Provider_State) return String is
   begin
      case State is
         when Codex_Subscription =>
            return "OpenAI Codex (ChatGPT Plus/Pro)";
         when GitHub_Copilot_Subscription =>
            return "GitHub Copilot";
      end case;
   end Provider_Name;

   --  Row index (1-based) of the currently selected provider.
   Selected_Row : Provider_Index := Provider_Index'First;

   --  ── Login outcome exchange between the login task and GTK idle ───────

   protected type Login_Outcome is
      procedure Record_Success;
      procedure Record_Failure (Message : String);
      function Finished return Boolean;
      function Succeeded return Boolean;
      function Error_Text return String;
   private
      Done    : Boolean := False;
      OK      : Boolean := False;
      Err_Msg : Unbounded_String := Null_Unbounded_String;
   end Login_Outcome;

   protected body Login_Outcome is
      procedure Record_Success is
      begin
         Done := True;
         OK := True;
      end Record_Success;

      procedure Record_Failure (Message : String) is
      begin
         Done := True;
         OK := False;
         Err_Msg := To_Unbounded_String (Message);
      end Record_Failure;

      function Finished return Boolean is
      begin
         return Done;
      end Finished;

      function Succeeded return Boolean is
      begin
         return OK;
      end Succeeded;

      function Error_Text return String is
      begin
         return To_String (Err_Msg);
      end Error_Text;
   end Login_Outcome;

   Outcome : Login_Outcome;

   task type Login_Task_Type;

   Login_Handle : access Login_Task_Type := null;
   pragma Unreferenced (Login_Handle);
   --  Retained so the task object outlives the click handler; the task
   --  terminates when the browser flow completes and records the outcome.

   task body Login_Task_Type is
      Creds : LLM.Auth.Provider_Credentials;
   begin
      LLM.Auth.Codex.Login.Browser_Login
        (Open_Authorize_Url => null,
         On_Progress        => null,
         Creds              => Creds);
      Outcome.Record_Success;
   exception
      when E : LLM.Auth.Codex.Login.Login_Error =>
         Outcome.Record_Failure
           (Ada.Exceptions.Exception_Message (E));
      when E : others =>
         Outcome.Record_Failure
           (Ada.Exceptions.Exception_Message (E));
   end Login_Task_Type;

   --  ── Widget construction and callbacks ────────────────────────────────

   procedure Update_Detail_Fields;

   procedure Update_Button_Sensitivity is
      State : constant Provider_State :=
        Provider_State'Val (Selected_Row);
      Info  : constant Credential_Info := Info_For (State);
   begin
      if Current_Instance = null then
         return;
      end if;

      if Current_Instance.Login_Active then
         Current_Instance.Login_Button.Set_Sensitive (False);
         Current_Instance.Refresh_Button.Set_Sensitive (False);
         Current_Instance.Logout_Button.Set_Sensitive (False);
         return;
      end if;

      case State is
         when Codex_Subscription =>
            Current_Instance.Login_Button.Set_Sensitive
              (not Info.Logged_In);
            Current_Instance.Refresh_Button.Set_Sensitive
              (Info.Logged_In);
            Current_Instance.Logout_Button.Set_Sensitive
              (Info.Logged_In);
         when GitHub_Copilot_Subscription =>
            --  Copilot credential management stays in the CLI; the window
            --  only reports state for it.
            Current_Instance.Login_Button.Set_Sensitive (False);
            Current_Instance.Refresh_Button.Set_Sensitive
              (Info.Logged_In);
            Current_Instance.Logout_Button.Set_Sensitive (False);
      end case;
   end Update_Button_Sensitivity;

   procedure Update_Detail_Fields is
      State : constant Provider_State :=
        Provider_State'Val (Selected_Row);
      Info  : constant Credential_Info := Info_For (State);
   begin
      if Current_Instance = null then
         return;
      end if;

      if Info.Logged_In then
         Current_Instance.Status_Field.Set_Text ("Logged in");
         if Length (Info.Account) > 0 then
            Current_Instance.Account_Field.Set_Text
              (To_String (Info.Account));
         else
            Current_Instance.Account_Field.Set_Text ("(not reported)");
         end if;
      else
         Current_Instance.Status_Field.Set_Text ("Not configured");
         Current_Instance.Account_Field.Set_Text ("");
      end if;

      Update_Button_Sensitivity;
   end Update_Detail_Fields;

   procedure Rebuild_Provider_List is
      Iter : Gtk_Tree_Iter;
   begin
      if Current_Instance = null
        or else Current_Instance.Provider_Store = null
      then
         return;
      end if;

      Current_Instance.Provider_Store.Clear;
      for P in Provider_State'Range loop
         declare
            Info : constant Credential_Info := Info_For (P);
            State_Text : constant String :=
              (if Info.Logged_In then "Logged in" else "Not configured");
         begin
            Current_Instance.Provider_Store.Append (Iter);
            Current_Instance.Provider_Store.Set
              (Iter, 0, Provider_Name (P));
            Current_Instance.Provider_Store.Set
              (Iter, 1, State_Text);
         end;
      end loop;

      --  Keep the previous selection visible after refresh.  Clamp the
      --  walk target so a stale Selected_Row cannot run the iterator past
      --  the end of the (rebuilt) model.
      declare
         Selection : constant Gtk.Tree_Selection.Gtk_Tree_Selection :=
           Current_Instance.Provider_View.Get_Selection;
         Target    : Gtk.Tree_Model.Gtk_Tree_Iter;
         Walk_To   : constant Provider_Index :=
           (if Selected_Row > Provider_Index'Last
              then Provider_Index'Last
              else Selected_Row);
         Position  : Provider_Index := Provider_Index'First;
      begin
         Selection.Unselect_All;
         Target := Current_Instance.Provider_Store.Get_Iter_First;
         while Position < Walk_To loop
            Current_Instance.Provider_Store.Next (Target);
            Position := Provider_Index'Succ (Position);
         end loop;
         Selection.Select_Iter (Target);
      end;
   end Rebuild_Provider_List;

   --  ── Login poll idle ──────────────────────────────────────────────────

   function Login_Poll_Idle return Boolean;
   --  Runs on the GTK main loop while a login is active.  On completion
   --  refreshes credential state and resets the buttons.

   Poll_Source_Id : Glib.Main.G_Source_Id := 0;
   Poll_Active    : Boolean := False;

   procedure Start_Poll is
   begin
      if Poll_Active then
         return;
      end if;
      Poll_Active := True;
      Poll_Source_Id := Glib.Main.Timeout_Add (250, Login_Poll_Idle'Access);
   end Start_Poll;

   procedure Stop_Poll is
   begin
      if Poll_Active then
         Glib.Main.Remove (Poll_Source_Id);
         Poll_Active := False;
      end if;
   end Stop_Poll;
   pragma Unreferenced (Stop_Poll);

   function Login_Poll_Idle return Boolean is
   begin
      if Current_Instance = null then
         Poll_Active := False;
         return False;
      end if;

      if not Outcome.Finished then
         return True;
      end if;

      Poll_Active := False;
      Current_Instance.Login_Active := False;
      Login_Handle := null;

      if Outcome.Succeeded then
         Current_Instance.Status.Set_Text
           ("OpenAI Codex login complete");
      else
         Current_Instance.Status.Set_Text
           ("Login failed: " & Outcome.Error_Text);
      end if;

      Rebuild_Provider_List;
      Update_Detail_Fields;
      return False;
   end Login_Poll_Idle;

   --  ── Button handlers ──────────────────────────────────────────────────

   procedure On_Login_Clicked
     (Self : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Instance = null
        or else Current_Instance.Login_Active
      then
         return;
      end if;

      Outcome.Record_Failure ("");
      --  Reset the outcome record through its own operations; the
      --  protected type is limited so assignment is not available.
      Current_Instance.Login_Active := True;
      Current_Instance.Status.Set_Text
        ("Waiting for browser authorization...");
      Update_Button_Sensitivity;

      Login_Handle := new Login_Task_Type;
      Start_Poll;
   end On_Login_Clicked;

   procedure On_Refresh_Clicked
     (Self : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Self);
      State : Provider_State;
      Info  : Credential_Info;
   begin
      if Current_Instance = null then
         return;
      end if;

      State := Provider_State'Val (Selected_Row);
      Info := Info_For (State);

      case State is
         when Codex_Subscription =>
            if Info.Logged_In then
               Current_Instance.Status.Set_Text ("Refreshing token...");
               begin
                  declare
                     Creds : LLM.Auth.Provider_Credentials :=
                       LLM.Auth.Load_Credentials ("codex");
                  begin
                     LLM.Auth.Codex.Ensure_Valid (Creds);
                     Current_Instance.Status.Set_Text
                       ("Token refreshed");
                  end;
               exception
                  when E : LLM.Auth.Codex.Auth_Error =>
                     Current_Instance.Status.Set_Text
                       ("Refresh failed: "
                        & Ada.Exceptions.Exception_Message (E));
               end;
               Rebuild_Provider_List;
               Update_Detail_Fields;
            end if;
         when GitHub_Copilot_Subscription =>
            Current_Instance.Status.Set_Text
              ("Copilot tokens refresh automatically on use");
      end case;
   end On_Refresh_Clicked;

   procedure On_Logout_Clicked
     (Self : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      if Current_Instance = null then
         return;
      end if;

      case Provider_State'Val (Selected_Row) is
         when Codex_Subscription =>
            LLM.Auth.Save_Credentials
              ("codex",
               (others => <>));
            Current_Instance.Status.Set_Text
              ("OpenAI Codex subscription removed");
         when GitHub_Copilot_Subscription =>
            null;
      end case;

      Rebuild_Provider_List;
      Update_Detail_Fields;
   end On_Logout_Clicked;

   procedure On_Selection_Changed
     (Self : access Gtk.Tree_Selection.Gtk_Tree_Selection_Record'Class)
   is
      Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter  : Gtk.Tree_Model.Gtk_Tree_Iter;
   begin
      if Current_Instance = null then
         return;
      end if;
      Self.Get_Selected (Model, Iter);
      if Iter = Gtk.Tree_Model.Null_Iter then
         return;
      end if;
      declare
         use Gtk.Tree_Model;
         Path : constant Gtk_Tree_Path := Get_Path (Model, Iter);
         Indices : constant Glib.Gint_Array := Get_Indices (Path);
      begin
         if Indices'Length > 0 then
            Selected_Row := Provider_Index (Indices (Indices'First));
         end if;
         Gtk.Tree_Model.Path_Free (Path);
      end;
      Update_Detail_Fields;
   exception
      when others =>
         null;
   end On_Selection_Changed;

   function On_Window_Delete
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event) return Boolean
   is
      pragma Unreferenced (Self, Event);
   begin
      --  A running login keeps going; the outcome lands when the window
      --  is reopened.  Hide rather than destroy so the instance stays
      --  reusable, matching the Sandbox Profiles manager.
      if Current_Instance /= null
        and then Current_Instance.Window /= null
      then
         Current_Instance.Window.Hide;
      end if;
      return True;
   end On_Window_Delete;

   function On_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
      use type Gdk.Types.Gdk_Key_Type;
   begin
      if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_w
        and then (Event.State and Gdk.Types.Control_Mask) /= 0
      then
         if Current_Instance /= null
           and then Current_Instance.Window /= null
         then
            Current_Instance.Window.Hide;
         end if;
         return True;
      end if;
      return False;
   end On_Key_Press;

   --  ── Public operations ────────────────────────────────────────────────

   procedure Create
     (S            : aliased in out Instance;
      Main_Window  : not null access Gtk.Window.Gtk_Window_Record'Class;
      Prompt_Queue : not null access Coyote_GUI.Prompt_Queue.Queue)
   is
      pragma Unreferenced (Prompt_Queue);
      Content   : Gtk.Box.Gtk_Box;
      Detail    : Gtk.Frame.Gtk_Frame;
      Detail_Box : Gtk.Box.Gtk_Box;
      Grid      : Gtk.Box.Gtk_Box;
      Row_Box   : Gtk.Box.Gtk_Box;
      Label     : Gtk.Label.Gtk_Label;
      Scroll    : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Actions   : Gtk.Box.Gtk_Box;
      Mnemonics : Coyote_GUI.Mnemonics.Registry;
      pragma Unreferenced (Mnemonics);
      Renderer  : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      Column    : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
   begin
      if S.Created then
         return;
      end if;

      S.Main_Window := Main_Window;
      Gtk.Window.Gtk_New (S.Window, Gtk.Enums.Window_Toplevel);
      Current_Instance := S'Unchecked_Access;
      S.Window.Set_Title ("coyote : Subscriptions");
      S.Window.Set_Transient_For (Main_Window);
      S.Window.Set_Default_Size (520, 380);
      S.Window.Set_Size_Request (440, 300);
      S.Window.On_Delete_Event (On_Window_Delete'Access);
      S.Window.On_Key_Press_Event (On_Key_Press'Access);

      Gtk.Box.Gtk_New_Vbox (Content, False, 4);
      Content.Set_Border_Width (8);
      S.Window.Add (Content);

      Gtk.Label.Gtk_New (Label, "Provider:");
      Label.Set_Halign (Gtk.Widget.Align_Start);
      Content.Pack_Start (Label, False, False, 0);

      Gtk.List_Store.Gtk_New
        (S.Provider_Store,
         (1 => Glib.GType_String, 2 => Glib.GType_String));
      Gtk.Tree_View.Gtk_New (S.Provider_View, S.Provider_Store);
      Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
      Gtk.Tree_View_Column.Gtk_New (Column);
      Column.Set_Title ("Provider");
      Column.Pack_Start (Renderer, True);
      Column.Add_Attribute (Renderer, "text", 0);
      declare
         Dummy : Glib.Gint;
         pragma Unreferenced (Dummy);
      begin
         Dummy := S.Provider_View.Append_Column (Column);
      end;
      Gtk.Tree_View_Column.Gtk_New (Column);
      Column.Set_Title ("State");
      Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
      Column.Pack_Start (Renderer, True);
      Column.Add_Attribute (Renderer, "text", 1);
      declare
         Dummy : Glib.Gint;
         pragma Unreferenced (Dummy);
      begin
         Dummy := S.Provider_View.Append_Column (Column);
      end;
      S.Provider_View.Set_Headers_Visible (True);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Scroll.Add (S.Provider_View);
      Scroll.Set_Size_Request (-1, 90);
      Content.Pack_Start (Scroll, False, False, 0);

      S.Provider_View.Get_Selection.On_Changed
        (On_Selection_Changed'Access);

      Gtk.Frame.Gtk_New (Detail);
      Detail.Set_Label ("Selected subscription");
      Gtk.Box.Gtk_New_Vbox (Detail_Box, False, 3);
      Detail.Add (Detail_Box);
      Content.Pack_Start (Detail, False, False, 4);

      Gtk.Box.Gtk_New_Hbox (Grid, False, 8);
      Gtk.Label.Gtk_New (Label, "Status:");
      Grid.Pack_Start (Label, False, False, 0);
      Gtk.Label.Gtk_New (S.Status_Field, "Not configured");
      S.Status_Field.Set_Halign (Gtk.Widget.Align_Start);
      Grid.Pack_Start (S.Status_Field, False, False, 0);
      Detail_Box.Pack_Start (Grid, False, False, 0);

      Gtk.Box.Gtk_New_Hbox (Row_Box, False, 8);
      Gtk.Label.Gtk_New (Label, "Account:");
      Row_Box.Pack_Start (Label, False, False, 0);
      Gtk.Label.Gtk_New (S.Account_Field, "");
      S.Account_Field.Set_Halign (Gtk.Widget.Align_Start);
      Row_Box.Pack_Start (S.Account_Field, False, False, 0);
      Detail_Box.Pack_Start (Row_Box, False, False, 0);

      Gtk.Box.Gtk_New_Hbox (Actions, False, 4);
      Gtk.Button.Gtk_New_With_Mnemonic (S.Login_Button, "_Login...");
      Gtk.Button.Gtk_New_With_Mnemonic (S.Refresh_Button, "_Refresh");
      Gtk.Button.Gtk_New_With_Mnemonic (S.Logout_Button, "_Logout");
      S.Login_Button.On_Clicked (On_Login_Clicked'Access);
      S.Refresh_Button.On_Clicked (On_Refresh_Clicked'Access);
      S.Logout_Button.On_Clicked (On_Logout_Clicked'Access);
      Actions.Pack_Start (S.Login_Button, False, False, 0);
      Actions.Pack_Start (S.Refresh_Button, False, False, 0);
      Actions.Pack_Start (S.Logout_Button, False, False, 0);
      Content.Pack_Start (Actions, False, False, 4);

      Gtk.Label.Gtk_New (S.Status, "Subscription state loaded");
      S.Status.Set_Halign (Gtk.Widget.Align_Start);
      S.Status.Set_Line_Wrap (True);
      Content.Pack_End (S.Status, False, False, 0);

      S.Created := True;
      Rebuild_Provider_List;
      Update_Detail_Fields;
   end Create;

   function Is_Created (S : Instance) return Boolean is
   begin
      return S.Created;
   end Is_Created;

   function Window_Title (S : Instance) return String is
   begin
      if not S.Created then
         return "";
      end if;
      return S.Window.Get_Title;
   end Window_Title;

   procedure Show (S : in out Instance) is
   begin
      if S.Created then
         Refresh (S);
         S.Window.Show_All;
         S.Window.Present;
         S.Provider_View.Grab_Focus;
      end if;
   end Show;

   procedure Refresh (S : in out Instance) is
   begin
      if not S.Created then
         return;
      end if;
      Rebuild_Provider_List;
      Update_Detail_Fields;
   end Refresh;

   function Login_Running (S : Instance) return Boolean is
   begin
      return S.Login_Active;
   end Login_Running;

end Coyote_GUI.Subscription_Window;
