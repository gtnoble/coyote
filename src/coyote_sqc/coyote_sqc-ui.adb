with Gdk.Types;              use Gdk.Types;
with Gdk.Types.Keysyms;
with Gtk.Accel_Group;
with Ada.Exceptions;
with Gdk.Event;
with Gtk.Dialog;
with Gtk.Drawing_Area;
with Gtk.File_Filter;
with Gtk.Scrolled_Window;
--  Coyote_SQC.UI body — main window builder.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.App;
with Coyote_SQC.Config;
with Coyote_SQC.UI.Chart_Canvas;
with Coyote_SQC.UI.Detail_Panel;
with Coyote_SQC.UI.Dialogs;
with Coyote_SQC.UI.Left_Panel;
with Coyote_SQC.UI.Toolbar;
with Coyote_SQC.UI.Workspace_Settings;
with Coyote_SQC.Workspace;
with Glib;                   use Glib;
with Gtk.Box;
with Gtk.Enums;
with Gtk.File_Chooser;
with Gtk.File_Chooser_Dialog;
with Gtk.File_Filter;
with Gtk.Main;
with Gtk.Menu;
with Gtk.Menu_Bar;
with Gtk.Menu_Item;
with Gtk.Check_Menu_Item;
with Gtk.Paned;
with Gtk.Separator_Menu_Item;
with Gtk.GEntry;
with Gtk.Label;
with Gtk.Widget;
with Gtk.Window;

package body Coyote_SQC.UI is
   use type Coyote_SQC.App.App_State_Access;
   use Coyote_SQC.UI.Dialogs;
   use Gtk.Dialog;
   use Gtk.Widget;

   --  Recent workspace paths for menu callbacks (max 5).
   Recent_Paths : array (1 .. Coyote_SQC.Config.Max_Recent)
     of Ada.Strings.Unbounded.Unbounded_String;

   --  Reference to the Recent Workspaces submenu for dynamic update.
   Recent_Submenu : Gtk.Menu.Gtk_Menu := null;
   Recent_Items : array (1 .. Coyote_SQC.Config.Max_Recent)
     of Gtk.Menu_Item.Gtk_Menu_Item :=
       (others => null);
   use type Gtk.Menu_Item.Gtk_Menu_Item;
   use type Gtk.Menu.Gtk_Menu;

   procedure On_Recent_Item
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure Rebuild_Recent_Submenu;

   --  ── Forward-declared signal callbacks ─────────────────────────────────

   procedure On_Quit (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_New (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Open (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Save (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Save_As
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Workspace_Settings
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Reload
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Show_All
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Y_Fit
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Clear_Selection
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);
   procedure On_Clear_Setup
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   function On_Window_Delete
     (Win   : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event) return Boolean;

   --  ── Window delete ─────────────────────────────────────────────────────

   function On_Window_Delete
     (Win   : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event) return Boolean
   is
      pragma Unreferenced (Win, Event);
   begin
      if Coyote_SQC.App.State /= null
        and then Coyote_SQC.App.State.Modified
      then
         declare
            Res : constant Coyote_SQC.UI.Dialogs.Dialog_Response :=
              Coyote_SQC.UI.Dialogs.Unsaved_Changes
                (Coyote_SQC.App.State.Main_Window,
                 To_String (Coyote_SQC.App.State.Workspace.Name));
         begin
            case Res is
               when Coyote_SQC.UI.Dialogs.Response_OK =>
                  On_Save (null);
               when Coyote_SQC.UI.Dialogs.Response_Cancel =>
                  return True;  --  Block window close.
               when Coyote_SQC.UI.Dialogs.Response_Other =>
                  null;  --  Discard.
            end case;
         end;
      end if;
      Gtk.Main.Main_Quit;
      return False;
   end On_Window_Delete;

   --  ── File menu callbacks ───────────────────────────────────────────────

   procedure Do_Save (Path : String) is
   begin
      Coyote_SQC.Workspace.Save (Path, Coyote_SQC.App.State.Workspace);
      Coyote_SQC.App.State.Workspace_Path := To_Unbounded_String (Path);
      Coyote_SQC.App.State.Modified := False;
      Coyote_SQC.App.Update_Title;
      Coyote_SQC.Config.Record_Open
        (To_String (Coyote_SQC.App.State.Workspace.Name), Path);
      Rebuild_Recent_Submenu;
   exception
      when others =>
         Coyote_SQC.UI.Dialogs.Error
           (Coyote_SQC.App.State.Main_Window,
            "Save Failed",
            "Could not save workspace to '" & Path & "'.");
   end Do_Save;

   procedure On_New (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Item);
   begin
      if Coyote_SQC.App.State = null then return; end if;
      --  Check unsaved changes.
      if Coyote_SQC.App.State.Modified then
         declare
            Res : constant Coyote_SQC.UI.Dialogs.Dialog_Response :=
              Coyote_SQC.UI.Dialogs.Unsaved_Changes
                (Coyote_SQC.App.State.Main_Window,
                 To_String (Coyote_SQC.App.State.Workspace.Name));
         begin
            if Res = Coyote_SQC.UI.Dialogs.Response_Cancel then return; end if;
            if Res = Coyote_SQC.UI.Dialogs.Response_OK then
               On_Save (null);
            end if;
         end;
      end if;
      --  Ask user for the new workspace name.
      declare
         D     : Gtk.Dialog.Gtk_Dialog;
         VBox  : Gtk.Box.Gtk_Box;
         Lbl   : Gtk.Label.Gtk_Label;
         Name_E : Gtk.GEntry.Gtk_Entry;
         Res   : Gtk.Dialog.Gtk_Response_Type;
         Dummy : Gtk.Widget.Gtk_Widget;
         pragma Unreferenced (Dummy);
      begin
         Gtk.Dialog.Gtk_New
           (D, "New Workspace",
            Coyote_SQC.App.State.Main_Window,
            Gtk.Dialog.Modal);
         D.Set_Default_Size (350, 110);
         Gtk.Box.Gtk_New_Vbox (VBox);
         VBox.Set_Spacing (6);
         VBox.Set_Border_Width (8);
         Gtk.Label.Gtk_New (Lbl, "Workspace name:");
         Lbl.Set_Halign (Gtk.Widget.Align_Start);
         VBox.Pack_Start (Lbl, False, False, 0);
         Gtk.GEntry.Gtk_New (Name_E);
         Name_E.Set_Text ("New Workspace");
         Name_E.Set_Activates_Default (True);
         VBox.Pack_Start (Name_E, False, False, 0);
         D.Get_Content_Area.Pack_Start (VBox, True, True, 0);
         Dummy := D.Add_Button ("_Create", Gtk.Dialog.Gtk_Response_OK);
         Dummy := D.Add_Button ("_Cancel", Gtk.Dialog.Gtk_Response_Cancel);
         D.Set_Default_Response (Gtk.Dialog.Gtk_Response_OK);
         D.Show_All;
         Res := D.Run;
         if Res = Gtk.Dialog.Gtk_Response_OK then
            declare
               Name : constant String := Name_E.Get_Text;
            begin
               D.Destroy;
               Coyote_SQC.App.State.Workspace :=
                 (Workspace_Id => To_Unbounded_String
                                    (Coyote_SQC.Workspace.New_UUID),
                  Name         => To_Unbounded_String
                                    (if Name'Length > 0
                                     then Name
                                     else "New Workspace"),
                  others       => <>);
               Coyote_SQC.App.State.Workspace_Path := Null_Unbounded_String;
               Coyote_SQC.App.State.Modified       := False;
               Coyote_SQC.App.Reload_Sessions;
               Coyote_SQC.App.Update_Title;
               Rebuild_Recent_Submenu;
               Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
            end;
         else
            D.Destroy;
         end if;
      end;
   end On_New;

   procedure On_Open (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Item);
      use Gtk.File_Chooser_Dialog;
      use Gtk.File_Chooser;
      use Gtk.Enums;
      D    : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
      Filt : Gtk.File_Filter.Gtk_File_Filter;
      Res  : Gtk_Response_Type;
   begin
      if Coyote_SQC.App.State = null then return; end if;
      Gtk.File_Chooser_Dialog.Gtk_New
        (D,
         Title  => "Open Workspace",
         Parent => Coyote_SQC.App.State.Main_Window,
         Action => Gtk.File_Chooser.Action_Open);
      declare
         DLG : constant Gtk.Dialog.Gtk_Dialog := Gtk.Dialog.Gtk_Dialog (D);
         Dummy : Gtk.Widget.Gtk_Widget;
         pragma Unreferenced (Dummy);
      begin
         Dummy := DLG.Add_Button ("_Open",   Gtk_Response_OK);
         Dummy := DLG.Add_Button ("_Cancel", Gtk_Response_Cancel);
      end;
      Gtk.File_Filter.Gtk_New (Filt);
      Filt.Add_Pattern ("*.sqcw");
      Filt.Set_Name ("Workspace files (*.sqcw)");
      D.Add_Filter (Filt);
      D.Show_All;
      Res := Gtk.Dialog.Gtk_Dialog (D).Run;
      if Res = Gtk_Response_OK then
         declare
            Path : constant String := D.Get_Filename;
         begin
            D.Destroy;
            begin
               declare
                  VF : Natural;
               begin
                  Coyote_SQC.Workspace.Load
                    (Path, Coyote_SQC.App.State.Workspace, VF);
                  if VF = 0 then
                     Coyote_SQC.UI.Dialogs.Info
                       (Coyote_SQC.App.State.Main_Window,
                        "Missing Version",
                        "Workspace file has no version field; "
                        & "some data may be missing.");
                  end if;
               end;
               Coyote_SQC.App.State.Workspace_Path := To_Unbounded_String (Path);
               Coyote_SQC.App.State.Modified := False;
               Coyote_SQC.Config.Record_Open
                 (To_String (Coyote_SQC.App.State.Workspace.Name), Path);
               Coyote_SQC.App.Reload_Sessions;
               Coyote_SQC.App.Update_Title;
               Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
               Rebuild_Recent_Submenu;
            exception
               when E : others =>
                  Coyote_SQC.UI.Dialogs.Error
                    (Coyote_SQC.App.State.Main_Window,
                     "Open Failed",
                     "Could not open workspace: "
                     & Ada.Exceptions.Exception_Message (E));
            end;
            return;
         end;
      end if;
      D.Destroy;
   end On_Open;

   procedure On_Save (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Item);
   begin
      if Coyote_SQC.App.State = null then return; end if;
      if To_String (Coyote_SQC.App.State.Workspace_Path) = "" then
         On_Save_As (null);
      else
         Do_Save (To_String (Coyote_SQC.App.State.Workspace_Path));
      end if;
   end On_Save;

   procedure On_Save_As
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      use Gtk.File_Chooser_Dialog;
      use Gtk.File_Chooser;
      use Gtk.Enums;
      D    : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
      Filt : Gtk.File_Filter.Gtk_File_Filter;
      Res  : Gtk_Response_Type;
   begin
      if Coyote_SQC.App.State = null then return; end if;
      Gtk.File_Chooser_Dialog.Gtk_New
        (D,
         Title  => "Save Workspace As",
         Parent => Coyote_SQC.App.State.Main_Window,
         Action => Gtk.File_Chooser.Action_Save);
      D.Set_Do_Overwrite_Confirmation (True);
      declare
         DLG   : constant Gtk.Dialog.Gtk_Dialog := Gtk.Dialog.Gtk_Dialog (D);
         Dummy : Gtk.Widget.Gtk_Widget;
         pragma Unreferenced (Dummy);
      begin
         Dummy := DLG.Add_Button ("_Save",   Gtk_Response_OK);
         Dummy := DLG.Add_Button ("_Cancel", Gtk_Response_Cancel);
      end;
      Gtk.File_Filter.Gtk_New (Filt);
      Filt.Add_Pattern ("*.sqcw");
      Filt.Set_Name ("Workspace files (*.sqcw)");
      D.Add_Filter (Filt);
      D.Show_All;
      Res := Gtk.Dialog.Gtk_Dialog (D).Run;
      if Res = Gtk_Response_OK then
         declare
            Path : constant String := D.Get_Filename;
         begin
            D.Destroy;
            Do_Save (Path);
            return;
         end;
      end if;
      D.Destroy;
   end On_Save_As;

   procedure On_Quit (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class) is
      pragma Unreferenced (Item);
      Dummy_Ev : Gdk.Event.Gdk_Event;
   begin
      if On_Window_Delete (Coyote_SQC.App.State.Main_Window, Dummy_Ev) then
         null;
      end if;
   end On_Quit;

   --  ── Recent workspaces ─────────────────────────────────────────────────

   procedure On_Recent_Item
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      use type Gtk.Menu_Item.Gtk_Menu_Item;
      Found_Path : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if Coyote_SQC.App.State = null then return; end if;
      for I in Recent_Items'Range loop
         if Recent_Items (I) /= null
           and then Gtk.Menu_Item.Gtk_Menu_Item (Item) = Recent_Items (I)
         then
            Found_Path := Recent_Paths (I);
            exit;
         end if;
      end loop;
      if To_String (Found_Path) = "" then return; end if;
      if Coyote_SQC.App.State.Modified then
         declare
            Res : constant Dialog_Response :=
              Coyote_SQC.UI.Dialogs.Unsaved_Changes
                (Coyote_SQC.App.State.Main_Window,
                 To_String (Coyote_SQC.App.State.Workspace.Name));
         begin
            if Res = Response_Cancel then return; end if;
            if Res = Response_OK then On_Save (null); end if;
         end;
      end if;
      begin
         declare
            VF : Natural;
         begin
            Coyote_SQC.Workspace.Load
              (To_String (Found_Path), Coyote_SQC.App.State.Workspace, VF);
            if VF = 0 then
               Coyote_SQC.UI.Dialogs.Info
                 (Coyote_SQC.App.State.Main_Window,
                  "Missing Version",
                  "Workspace file has no version field; "
                  & "some data may be missing.");
            end if;
         end;
         Coyote_SQC.App.State.Workspace_Path := Found_Path;
         Coyote_SQC.App.State.Modified := False;
         Coyote_SQC.Config.Record_Open
           (To_String (Coyote_SQC.App.State.Workspace.Name),
            To_String (Found_Path));
         Coyote_SQC.App.Reload_Sessions;
         Coyote_SQC.App.Update_Title;
         Rebuild_Recent_Submenu;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      exception
         when E : others =>
            Coyote_SQC.UI.Dialogs.Error
              (Coyote_SQC.App.State.Main_Window,
               "Open Failed",
               "Could not open workspace: "
               & Ada.Exceptions.Exception_Message (E));
      end;
   end On_Recent_Item;

   procedure Rebuild_Recent_Submenu is
      use Coyote_SQC.Config;
      Recent  : constant Recent_List := Config.Load_Recent;
      New_Sub : Gtk.Menu.Gtk_Menu;
   begin
      if Coyote_SQC.App.State = null or else
         Coyote_SQC.App.State.Recent_Menu = null
      then return; end if;
      Gtk.Menu.Gtk_New (New_Sub);
      Recent_Submenu := New_Sub;
      for I in 1 .. Integer (Recent.Count) loop
         declare
            E    : constant Recent_Entry :=
              Recent.Entries (I);
            Lbl  : constant String :=
              To_String (E.Name) & "  ("
              & To_String (E.Path) & ")";
            Item : Gtk.Menu_Item.Gtk_Menu_Item;
         begin
            Recent_Paths (I) := E.Path;
            Gtk.Menu_Item.Gtk_New (Item, Lbl);
            Item.On_Activate (On_Recent_Item'Access);
            New_Sub.Append (Item);
            Recent_Items (I) := Item;
            Item.Show;
         end;
      end loop;
      for I in Integer (Recent.Count) + 1 .. Max_Recent loop
         Recent_Items (I) := null;
         Recent_Paths (I) := Ada.Strings.Unbounded.Null_Unbounded_String;
      end loop;
      if Integer (Recent.Count) = 0 then
         declare
            Item : Gtk.Menu_Item.Gtk_Menu_Item;
         begin
            Gtk.Menu_Item.Gtk_New (Item, "(no recent workspaces)");
            Item.Set_Sensitive (False);
            New_Sub.Append (Item);
            Item.Show;
         end;
      end if;
      Coyote_SQC.App.State.Recent_Menu.Set_Submenu (New_Sub);
   end Rebuild_Recent_Submenu;


   --  ── Workspace menu ────────────────────────────────────────────────────

   procedure On_Workspace_Settings
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      Coyote_SQC.UI.Workspace_Settings.Show_Dialog;
   end On_Workspace_Settings;

   procedure On_Reload
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Coyote_SQC.App.State /= null then
         Coyote_SQC.App.Reload_Sessions;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      end if;
   end On_Reload;

   --  ── View menu ─────────────────────────────────────────────────────────

   procedure On_Show_All
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Coyote_SQC.App.State = null
        or else Coyote_SQC.App.State.Sessions.Is_Empty
      then return; end if;
      Coyote_SQC.App.State.Date_From :=
        Coyote_SQC.App.State.Sessions.First_Element.Start_Time;
      Coyote_SQC.App.State.Date_To :=
        Coyote_SQC.App.State.Sessions.Last_Element.Start_Time;
      Coyote_SQC.UI.Chart_Canvas.Sync_X_From_Dates;
      Coyote_SQC.UI.Toolbar.Sync_Pickers;
      Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
   end On_Show_All;

   procedure On_Y_Fit
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Coyote_SQC.App.State /= null then
         Coyote_SQC.App.Y_Fit;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      end if;
   end On_Y_Fit;

   procedure On_Clear_Selection
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Coyote_SQC.App.State /= null then
         Coyote_SQC.App.State.Selection.Clear;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
      end if;
   end On_Clear_Selection;

   procedure On_Clear_Setup
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Coyote_SQC.App.State = null then return; end if;
      if not Coyote_SQC.UI.Dialogs.Confirm
        (Coyote_SQC.App.State.Main_Window,
         "Clear Setup Interval",
         "Clear the setup interval? Charts will revert to retrospective limits.")
      then
         return;
      end if;
      Coyote_SQC.App.State.Workspace.Setup_Session_Ids.Clear;
      Coyote_SQC.App.State.Modified := True;
      Coyote_SQC.App.Update_Title;
      Coyote_SQC.App.Recompute_Charts;
      Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
   end On_Clear_Setup;

   procedure On_Run_Sequence_Activated
     (Item : access Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record'Class)
   is
   begin
      if Coyote_SQC.App.State = null then return; end if;
      --  Delegate to the canvas which converts the viewport and redraws.
      Coyote_SQC.UI.Chart_Canvas.Switch_X_Scale_Mode (Item.Get_Active);
      --  Keep the toolbar checkbox in sync.
      Coyote_SQC.UI.Toolbar.Sync_Run_Sequence_Button;
   end On_Run_Sequence_Activated;


   --  ── Build menu bar ────────────────────────────────────────────────────

   function Build_Menu_Bar
     (AG : not null access Gtk.Accel_Group.Gtk_Accel_Group_Record'Class)
      return Gtk.Menu_Bar.Gtk_Menu_Bar
   is
      use Gtk.Menu_Bar;
      use Gtk.Menu;
      use Gtk.Menu_Item;
      use Gtk.Separator_Menu_Item;

      MB       : Gtk.Menu_Bar.Gtk_Menu_Bar;
      File_M   : Gtk.Menu.Gtk_Menu;
      WS_M     : Gtk.Menu.Gtk_Menu;
      View_M   : Gtk.Menu.Gtk_Menu;
      Item     : Gtk.Menu_Item.Gtk_Menu_Item;
      Save_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      Quit_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      Recent_MI : Gtk.Menu_Item.Gtk_Menu_Item;
      Sep      : Gtk.Separator_Menu_Item.Gtk_Separator_Menu_Item;

      procedure Add_Item
        (Menu  : Gtk.Menu.Gtk_Menu;
         Label : String;
         CB    : access procedure (I : access Gtk_Menu_Item_Record'Class))
      is
         I : Gtk.Menu_Item.Gtk_Menu_Item;
      begin
         Gtk.Menu_Item.Gtk_New (I, Label);
         I.On_Activate (CB);
         Menu.Append (I);
      end Add_Item;

      procedure Add_Sep (Menu : Gtk.Menu.Gtk_Menu) is
         S : Gtk.Separator_Menu_Item.Gtk_Separator_Menu_Item;
      begin
         Gtk.Separator_Menu_Item.Gtk_New (S);
         Menu.Append (S);
      end Add_Sep;

   begin
      Gtk.Menu_Bar.Gtk_New (MB);

      --  File menu.
      Gtk.Menu.Gtk_New (File_M);
      Add_Item (File_M, "New Workspace...",   On_New'Access);
      Add_Item (File_M, "Open Workspace...",  On_Open'Access);
      --  Recent Workspaces submenu.
      Gtk.Menu_Item.Gtk_New (Recent_MI, "Recent Workspaces");
      declare
         Recent_Sub : Gtk.Menu.Gtk_Menu;
      begin
         Gtk.Menu.Gtk_New (Recent_Sub);
         Recent_MI.Set_Submenu (Recent_Sub);
         File_M.Append (Recent_MI);
         Recent_Submenu := Recent_Sub;
         if Coyote_SQC.App.State /= null then
            Coyote_SQC.App.State.Recent_Menu := Recent_MI;
         end if;
      end;
      Add_Sep (File_M);
      --  Save (Ctrl+S).
      Gtk.Menu_Item.Gtk_New (Save_Item, "Save Workspace");
      Save_Item.On_Activate (On_Save'Access);
      Save_Item.Add_Accelerator
        ("activate", AG,
         Gdk.Types.Keysyms.GDK_LC_s,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      File_M.Append (Save_Item);
      Add_Item (File_M, "Save Workspace As...", On_Save_As'Access);
      Add_Sep (File_M);
      --  Quit (Ctrl+Q).
      Gtk.Menu_Item.Gtk_New (Quit_Item, "Quit");
      Quit_Item.On_Activate (On_Quit'Access);
      Quit_Item.Add_Accelerator
        ("activate", AG,
         Gdk.Types.Keysyms.GDK_LC_q,
         Gdk.Types.Control_Mask,
         Gtk.Accel_Group.Accel_Visible);
      File_M.Append (Quit_Item);
      Gtk.Menu_Item.Gtk_New (Item, "File");
      Item.Set_Submenu (File_M);
      MB.Append (Item);

      --  Workspace menu.
      Gtk.Menu.Gtk_New (WS_M);
      Add_Item (WS_M, "Workspace Settings...", On_Workspace_Settings'Access);
      Add_Item (WS_M, "Reload Sessions",      On_Reload'Access);
      Gtk.Menu_Item.Gtk_New (Item, "Workspace");
      Item.Set_Submenu (WS_M);
      MB.Append (Item);

      --  View menu.
      Gtk.Menu.Gtk_New (View_M);
      Add_Item (View_M, "Show All",         On_Show_All'Access);
      Add_Item (View_M, "Y-Fit",            On_Y_Fit'Access);
      Add_Sep (View_M);
      Add_Item (View_M, "Clear Selection",  On_Clear_Selection'Access);
      declare
         CSI : Gtk.Menu_Item.Gtk_Menu_Item;
      begin
         Gtk.Menu_Item.Gtk_New (CSI, "Clear Setup Interval");
         CSI.On_Activate (On_Clear_Setup'Access);
         View_M.Append (CSI);
         Coyote_SQC.App.State.Clear_Setup_Item := CSI;
         CSI.Set_Sensitive (not Coyote_SQC.App.State.Workspace
                                  .Setup_Session_Ids.Is_Empty);
      end;
      --  X-Axis: Run Sequence checkable item.
      Add_Sep (View_M);
      declare
         RSI : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
      begin
         Gtk.Check_Menu_Item.Gtk_New (RSI, "X-Axis: Run Sequence");
         RSI.On_Toggled (On_Run_Sequence_Activated'Access);
         View_M.Append (RSI);
         Coyote_SQC.App.State.Run_Sequence_Item := RSI;
      end;
      Gtk.Menu_Item.Gtk_New (Item, "View");
      Item.Set_Submenu (View_M);
      MB.Append (Item);

      return MB;
   end Build_Menu_Bar;

   --  ── Build_Main_Window ─────────────────────────────────────────────────

   procedure Build_Main_Window is
      use Coyote_SQC.App;
      use Gtk.Window;
      use Gtk.Box;
      use Gtk.Paned;
      use Gtk.Enums;

      Win          : Gtk.Window.Gtk_Window;
      VBox         : Gtk.Box.Gtk_Box;
      Menu_Bar_W   : Gtk.Menu_Bar.Gtk_Menu_Bar;
      H_Paned      : Gtk.Paned.Gtk_Paned;     --  left | (canvas | detail)
      R_Paned      : Gtk.Paned.Gtk_Paned;     --  canvas | detail
      Left_Scroll  : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Canvas_W     : Gtk.Drawing_Area.Gtk_Drawing_Area;
      Detail_W     : Gtk.Box.Gtk_Box;
      Detail_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Status_Bar_Lbl : Gtk.Label.Gtk_Label;

   begin
      --  Main window.
      Gtk.Window.Gtk_New (Win, Gtk.Enums.Window_Toplevel);
      Win.Set_Title ("coyote_sqc");
      Win.Set_Default_Size (1200, 700);
      State.Main_Window := Win;

      Win.On_Delete_Event (On_Window_Delete'Access);

      --  Top-level VBox.
      Gtk.Box.Gtk_New_Vbox (VBox);

      --  Menu bar.
      --  Create accelerator group and attach to window.
      declare
         AG : Gtk.Accel_Group.Gtk_Accel_Group;
      begin
         Gtk.Accel_Group.Gtk_New (AG);
         Win.Add_Accel_Group (AG);
         Menu_Bar_W := Build_Menu_Bar (AG);
      end;
      VBox.Pack_Start (Menu_Bar_W, False, False, 0);

      --  Toolbar.
      Coyote_SQC.UI.Toolbar.Build (VBox);

      --  Three-panel layout using nested GtkPaned.
      Gtk.Paned.Gtk_New_Hpaned (H_Paned);
      Gtk.Paned.Gtk_New_Hpaned (R_Paned);

      --  Left panel (chart selector).
      Left_Scroll := Coyote_SQC.UI.Left_Panel.Build;
      H_Paned.Pack1 (Left_Scroll, False, False);

      --  Chart canvas.
      Canvas_W := Coyote_SQC.UI.Chart_Canvas.Build;
      State.Canvas := Canvas_W;

      --  Detail panel (inside a scrolled window).
      Gtk.Scrolled_Window.Gtk_New (Detail_Scroll);
      Detail_Scroll.Set_Policy (Policy_Never, Policy_Automatic);
      Detail_W := Coyote_SQC.UI.Detail_Panel.Build;
      Detail_Scroll.Add (Detail_W);

      --  Right paned: canvas | detail.
      R_Paned.Pack1 (Canvas_W, True, True);
      R_Paned.Pack2 (Detail_Scroll, False, True);
      R_Paned.Set_Position (640);    --  canvas width; detail = 380 (§11.1)
      H_Paned.Set_Position (180);    --  left panel = 180 (§11.1)

      State.Detail_Pane    := R_Paned;
      State.Content_Paned  := H_Paned;
      State.Detail_Box     := Detail_W;

      H_Paned.Pack2 (R_Paned, True, True);

      VBox.Pack_Start (H_Paned, True, True, 0);
      --  Status bar.
      Gtk.Label.Gtk_New (Status_Bar_Lbl, "");
      Status_Bar_Lbl.Set_Xalign (0.0);
      Status_Bar_Lbl.Set_Margin_Start (4);
      Status_Bar_Lbl.Set_Margin_Bottom (2);
      VBox.Pack_Start (Status_Bar_Lbl, False, False, 0);
      State.Status_Bar := Status_Bar_Lbl;
      Win.Add (VBox);
      Win.Show_All;

      --  Highlight the first chart in the left panel.
      Coyote_SQC.UI.Left_Panel.Refresh_Selection;
      Rebuild_Recent_Submenu;
   end Build_Main_Window;

end Coyote_SQC.UI;
