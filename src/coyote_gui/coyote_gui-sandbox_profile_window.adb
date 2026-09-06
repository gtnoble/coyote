--  Coyote_GUI.Sandbox_Profile_Window body.
--
--  The four path collections are represented directly by list-box rows whose
--  children are entries.  This deliberately keeps path spelling untouched;
--  validation only rejects empty path entries.
--
--  Project: coyote

with Ada.Containers;
with Ada.Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_GUI.Prompt_Queue;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Glib;
with Gtk.Bin;
with Gtk.Box;
with Gtk.Button;
with Gtk.Dialog;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.GEntry;
with Gtk.Handlers;
with Gtk.Label;
with Gtk.List_Box;
with Gtk.List_Box_Row;
with Gtk.Menu;
with Gtk.Menu_Bar;
with Gtk.Menu_Item;
with Gtk.Menu_Shell;
with Gtk.Message_Dialog;
with Gtk.Paned;
with Gtk.Scrolled_Window;
with Gtk.Widget;
with Gtk.Window;
with LLM.Settings;
with LLM.Tools.Sandbox;
package body Coyote_GUI.Sandbox_Profile_Window is

   use type Ada.Containers.Count_Type;
   use type Gdk.Types.Gdk_Key_Type;
   use type Gdk.Types.Gdk_Modifier_Type;
   use type Glib.Gint;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Dialog.Gtk_Dialog_Flags;
   use type Gtk.Dialog.Gtk_Response_Type;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.List_Box_Row.Gtk_List_Box_Row;
   use type Gtk.Widget.Gtk_Widget;
   use type Gtk.Window.Gtk_Window;

   Current_Instance : access Instance := null;

   type Group_Name_Array is array (Positive range <>) of Unbounded_String;
   Group_Names : constant Group_Name_Array :=
     (To_Unbounded_String ("allow-write"),
      To_Unbounded_String ("deny-write"),
      To_Unbounded_String ("deny-read"),
      To_Unbounded_String ("allow-read"));

   function On_Window_Delete
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event) return Boolean
   is
      pragma Unreferenced (Event);
   begin
      Self.Hide;
      return True;
   end On_Window_Delete;

   function On_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
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

   function Vector_Text
     (Values : LLM.Tools.Sandbox.String_Vectors.Vector) return String
   is
      Result : Unbounded_String;
   begin
      if Values.Is_Empty then
         return "(none)";
      end if;
      for Value of Values loop
         if Length (Result) > 0 then
            Append (Result, ASCII.LF);
         end if;
         Append (Result, "  " & Value);
      end loop;
      return To_String (Result);
   end Vector_Text;

   function Profile_Text
     (Name : String;
      Value : LLM.Tools.Sandbox.Profile) return String
   is
      Result : Unbounded_String;
      Dir    : constant String := LLM.Tools.Sandbox.Profiles_Dir;
   begin
      Append (Result, "Profile: " & Name & ASCII.LF);
      Append (Result, "Path: " & Dir & "/" & Name & ".json" & ASCII.LF);
      Append (Result, ASCII.LF & "Allow write:" & ASCII.LF);
      Append (Result, Vector_Text (Value.Allow_Write));
      Append (Result, ASCII.LF & ASCII.LF & "Deny write:" & ASCII.LF);
      Append (Result, Vector_Text (Value.Deny_Write));
      Append (Result, ASCII.LF & ASCII.LF & "Deny read:" & ASCII.LF);
      Append (Result, Vector_Text (Value.Deny_Read));
      Append (Result, ASCII.LF & ASCII.LF & "Allow read:" & ASCII.LF);
      Append (Result, Vector_Text (Value.Allow_Read));
      return To_String (Result);
   end Profile_Text;

   procedure Show_Message
     (S         :  Instance;
      The_Type  :  Gtk.Message_Dialog.Gtk_Message_Type;
      Message   :  String)
   is
      Dialog   : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Response : Gtk.Dialog.Gtk_Response_Type;
   begin
      Gtk.Message_Dialog.Gtk_New
        (Dialog,
         (if S.Window = null then null else S.Window),
         Gtk.Dialog.Modal or Gtk.Dialog.Destroy_With_Parent,
         The_Type,
         Gtk.Message_Dialog.Buttons_Ok,
         Message);
      Response := Gtk.Dialog.Gtk_Dialog (Dialog).Run;
      pragma Unreferenced (Response);
      Dialog.Destroy;
   end Show_Message;

   procedure Show_Error (S :  Instance; Message :  String) is
   begin
      Show_Message (S, Gtk.Message_Dialog.Message_Error, Message);
   end Show_Error;

   function Selected_Name_From_Row
     (Row : not null access Gtk.List_Box_Row.Gtk_List_Box_Row_Record'Class)
      return String
   is
      Child : constant Gtk.Widget.Gtk_Widget :=
        Gtk.Bin.Get_Child (Gtk.Bin.Gtk_Bin (Row));
   begin
      if Child = null then
         return "";
      end if;
      return Gtk.Label.Gtk_Label (Child).Get_Text;
   end Selected_Name_From_Row;

   procedure Clear_List
     (List : not null access Gtk.List_Box.Gtk_List_Box_Record'Class)
   is
      Row : Gtk.List_Box_Row.Gtk_List_Box_Row;
   begin
      Clear_Loop:
      loop
         Row := List.Get_Row_At_Index (0);
         exit Clear_Loop when Row = null;
         List.Remove (Row);
      end loop Clear_Loop;
   end Clear_List;

   procedure Fill_Path_List
     (List   : not null access Gtk.List_Box.Gtk_List_Box_Record'Class;
      Values : LLM.Tools.Sandbox.String_Vectors.Vector)
   is
   begin
      Clear_List (List);
      for Value of Values loop
         declare
            Row   : Gtk.List_Box_Row.Gtk_List_Box_Row;
            Path_Entry : Gtk.GEntry.Gtk_Entry;
         begin
            Gtk.List_Box_Row.Gtk_New (Row);
            Gtk.GEntry.Gtk_New (Path_Entry);
            Path_Entry.Set_Text (Value);
            Path_Entry.Set_Width_Chars (30);
            Row.Add (Path_Entry);
            List.Add (Row);
            Row.Show_All;
         end;
      end loop;
   end Fill_Path_List;

   function Read_Path_List
     (List : not null access Gtk.List_Box.Gtk_List_Box_Record'Class)
      return LLM.Tools.Sandbox.String_Vectors.Vector
   is
      Result : LLM.Tools.Sandbox.String_Vectors.Vector;
      Index  : Glib.Gint := 0;
      Row    : Gtk.List_Box_Row.Gtk_List_Box_Row;
   begin
      Read_Loop:
      loop
         Row := List.Get_Row_At_Index (Index);
         exit Read_Loop when Row = null;
         declare
            Child : constant Gtk.Widget.Gtk_Widget :=
              Gtk.Bin.Get_Child (Gtk.Bin.Gtk_Bin (Row));
         begin
            if Child /= null then
               Result.Append (Gtk.GEntry.Gtk_Entry (Child).Get_Text);
            end if;
         end;
         Index := Index + Glib.Gint (1);
      end loop Read_Loop;
      return Result;
   end Read_Path_List;

   function List_For_Name
     (S :  Instance; Name : String)
      return Gtk.List_Box.Gtk_List_Box
   is
   begin
      if Name = "allow-write" then
         return S.Allow_Write;
      elsif Name = "deny-write" then
         return S.Deny_Write;
      elsif Name = "deny-read" then
         return S.Deny_Read;
      else
         return S.Allow_Read;
      end if;
   end List_For_Name;

   procedure Add_Empty_Path
     (List : not null access Gtk.List_Box.Gtk_List_Box_Record'Class)
   is
      Row        : Gtk.List_Box_Row.Gtk_List_Box_Row;
      Path_Entry : Gtk.GEntry.Gtk_Entry;
   begin
      Gtk.List_Box_Row.Gtk_New (Row);
      Gtk.GEntry.Gtk_New (Path_Entry);
      Path_Entry.Set_Width_Chars (30);
      Row.Add (Path_Entry);
      List.Add (Row);
      Row.Show_All;
      List.Select_Row (Row);
      Path_Entry.Grab_Focus;
   end Add_Empty_Path;

   procedure On_Add_Path
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
   begin
      if Current_Instance /= null then
         Add_Empty_Path
           (List_For_Name (Current_Instance.all, Button.Get_Name));
      end if;
   end On_Add_Path;

   procedure On_Remove_Path
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      Name : constant String := Button.Get_Name;
      List : Gtk.List_Box.Gtk_List_Box;
      Row  : Gtk.List_Box_Row.Gtk_List_Box_Row;
   begin
      if Current_Instance = null then
         return;
      end if;
      List := List_For_Name (Current_Instance.all, Name);
      Row := List.Get_Selected_Row;
      if Row /= null then
         List.Remove (Row);
      end if;
   end On_Remove_Path;

   procedure Create_Path_Group
     (Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Title  : String;
      Name   : String;
      List   : out Gtk.List_Box.Gtk_List_Box)
   is
      Frame   : Gtk.Frame.Gtk_Frame;
      Inner   : Gtk.Box.Gtk_Box;
      Scroll  : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Actions : Gtk.Box.Gtk_Box;
      Add_B   : Gtk.Button.Gtk_Button;
      Remove_B : Gtk.Button.Gtk_Button;
   begin
      Gtk.Frame.Gtk_New (Frame, Title);
      Gtk.Box.Gtk_New_Vbox (Inner, Homogeneous => False, Spacing => 4);
      Gtk.List_Box.Gtk_New (List);
      List.Set_Selection_Mode (Gtk.Enums.Selection_Single);
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Scroll.Set_Size_Request (-1, 72);
      Scroll.Add (List);
      Inner.Pack_Start (Scroll, True, True, 0);
      Gtk.Box.Gtk_New_Hbox (Actions, Homogeneous => False, Spacing => 4);
      Gtk.Button.Gtk_New_With_Mnemonic (Add_B, "_Add Path");
      Gtk.Button.Gtk_New_With_Mnemonic (Remove_B, "_Remove Selected");
      Add_B.Set_Name (Name);
      Remove_B.Set_Name (Name);
      Add_B.On_Clicked (On_Add_Path'Access);
      Remove_B.On_Clicked (On_Remove_Path'Access);
      Actions.Pack_Start (Add_B, False, False, 0);
      Actions.Pack_Start (Remove_B, False, False, 0);
      Inner.Pack_Start (Actions, False, False, 0);
      Frame.Add (Inner);
      Frame.Set_Border_Width (6);
      Parent.Pack_Start (Frame, True, True, 0);
   end Create_Path_Group;

   procedure Update_Details (S : in out Instance) is
      Name : constant String := To_String (S.Selected_Name);
   begin
      if Name'Length = 0 then
         S.Details.Set_Text
           ("No sandbox profile is available. Use File / New to create one.");
      else
         S.Details.Set_Text (Profile_Text (Name, S.Profile));
      end if;
   end Update_Details;

   procedure Set_Browse (S : in out Instance) is
   begin
      S.Edit_Mode := False;
      if S.Editor /= null then
         S.Editor.Hide;
      end if;
      if S.Details /= null then
         S.Details.Show;
      end if;
      if S.Status /= null then
         S.Status.Set_Text ("Browse mode");
      end if;
   end Set_Browse;

   procedure Begin_Edit
     (S          : in out Instance;
      Name       : String;
      Value      : LLM.Tools.Sandbox.Profile;
      Is_New     : Boolean)
   is
   begin
      S.Profile := Value;
      S.Original_Name := To_Unbounded_String (Name);
      S.Selected_Name := To_Unbounded_String (Name);
      S.New_Profile := Is_New;
      S.Edit_Mode := True;
      S.Name_Entry.Set_Text (Name);
      S.Name_Entry.Set_Editable (Is_New);
      Fill_Path_List (S.Allow_Write, Value.Allow_Write);
      Fill_Path_List (S.Deny_Write, Value.Deny_Write);
      Fill_Path_List (S.Deny_Read, Value.Deny_Read);
      Fill_Path_List (S.Allow_Read, Value.Allow_Read);
      S.Details.Hide;
      S.Editor.Show_All;
      if S.Status /= null then
         S.Status.Set_Text
           (if Is_New then "New profile - unsaved" else "Editing profile");
      end if;
      S.Name_Entry.Grab_Focus;
      S.Name_Entry.Select_Region (0, -1);
   end Begin_Edit;

   function Selected_Name (S :  Instance) return String is
   begin
      return To_String (S.Selected_Name);
   end Selected_Name;

   function Load_Selected_Profile (Name : String) return Boolean
   is
   begin
      if Current_Instance = null
        or else Current_Instance.Refreshing
        or else Current_Instance.Edit_Mode
      then
         return False;
      end if;
      Current_Instance.Selected_Name := To_Unbounded_String (Name);
      begin
         Current_Instance.Profile :=
           LLM.Tools.Sandbox.Load_Profile_Typed (Name);
         Update_Details (Current_Instance.all);
         Current_Instance.Status.Set_Text ("Loaded " & Name);
         return True;
      exception
         when E : LLM.Tools.Sandbox.Sandbox_Error =>
            Show_Error
              (Current_Instance.all,
               "Unable to load profile '" & Name & "': "
               & Ada.Exceptions.Exception_Message (E));
            return False;
      end;
   end Load_Selected_Profile;

   procedure On_Profile_Selected
     (List : access Gtk.List_Box.Gtk_List_Box_Record'Class;
      Row  : not null access Gtk.List_Box_Row.Gtk_List_Box_Row_Record'Class)
   is
      pragma Unreferenced (List);
   begin
      if Current_Instance /= null
        and then not Current_Instance.Refreshing
        and then not Current_Instance.Edit_Mode
      then
         declare
            Loaded : constant Boolean :=
              Load_Selected_Profile (Selected_Name_From_Row (Row));
         begin
            pragma Unreferenced (Loaded);
         end;
      end if;
   end On_Profile_Selected;

   procedure On_Profile_Activated
     (List : access Gtk.List_Box.Gtk_List_Box_Record'Class;
      Row  : not null access Gtk.List_Box_Row.Gtk_List_Box_Row_Record'Class)
   is
      pragma Unreferenced (List);
      Name : constant String := Selected_Name_From_Row (Row);
   begin
      if Current_Instance = null
        or else Current_Instance.Refreshing
        or else Current_Instance.Edit_Mode
      then
         return;
      end if;
      if Load_Selected_Profile (Name)
        and then Current_Instance /= null
      then
         Begin_Edit
           (Current_Instance.all,
            Name,
            Current_Instance.Profile,
            False);
      end if;
   end On_Profile_Activated;

   procedure Rebuild_Profile_List (S : in out Instance) is
      Wanted : constant String := To_String (S.Selected_Name);
      Index  : Glib.Gint := -1;
   begin
      S.Refreshing := True;
      Gtk.Handlers.Handlers_Destroy
        (Gtk.Widget.Gtk_Widget (S.Profile_List));
      S.Profile_List.Set_Selection_Mode (Gtk.Enums.Selection_None);
      S.Names := LLM.Tools.Sandbox.Available_Profiles;
      Clear_List (S.Profile_List);
      for Name of S.Names loop
         declare
            Row   : Gtk.List_Box_Row.Gtk_List_Box_Row;
            Label : Gtk.Label.Gtk_Label;
         begin
            Gtk.List_Box_Row.Gtk_New (Row);
            Gtk.Label.Gtk_New (Label, Name);
            Label.Set_Halign (Gtk.Widget.Align_Start);
            Row.Add (Label);
            S.Profile_List.Add (Row);
            Row.Show_All;
            if Name = Wanted then
               Index := Row.Get_Index;
            end if;
         end;
      end loop;
      S.Refreshing := False;
      declare
         Selected_Row : Gtk.List_Box_Row.Gtk_List_Box_Row;
         Detail_Name  : Unbounded_String := To_Unbounded_String (Wanted);
      begin
         if Index >= 0 then
            Selected_Row := S.Profile_List.Get_Row_At_Index (Index);
         elsif not S.Names.Is_Empty then
            Selected_Row := S.Profile_List.Get_Row_At_Index (0);
            Detail_Name :=
              To_Unbounded_String (S.Names.First_Element);
         end if;

         S.Profile_List.Set_Selection_Mode (Gtk.Enums.Selection_Single);
         S.Profile_List.On_Row_Selected (On_Profile_Selected'Access);
         S.Profile_List.On_Row_Activated (On_Profile_Activated'Access);

         if Length (Detail_Name) > 0
           and then (Index >= 0 or else not S.Names.Is_Empty)
         then
            declare
               Loaded : constant Boolean :=
                 Load_Selected_Profile (To_String (Detail_Name));
            begin
               pragma Unreferenced (Loaded);
            end;
         elsif S.Names.Is_Empty then
            S.Selected_Name := Null_Unbounded_String;
            S.Details.Set_Text
              ("No sandbox profile is available. Use File / New to create one.");
         end if;
      end;
   exception
      when others =>
         S.Refreshing := False;
         raise;
   end Rebuild_Profile_List;

   procedure On_New
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      Empty : LLM.Tools.Sandbox.Profile;
   begin
      if Current_Instance /= null then
         Begin_Edit (Current_Instance.all, "new-profile", Empty, True);
      end if;
   end On_New;

   procedure On_Edit
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Current_Instance /= null
        and then Length (Current_Instance.Selected_Name) > 0
      then
         Begin_Edit
           (Current_Instance.all,
            Selected_Name (Current_Instance.all),
            Current_Instance.Profile,
            False);
      end if;
   end On_Edit;

   procedure On_Duplicate
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      Name : Unbounded_String;
   begin
      if Current_Instance = null
        or else Length (Current_Instance.Selected_Name) = 0
      then
         return;
      end if;
      Name := To_Unbounded_String
        (Selected_Name (Current_Instance.all) & "-copy");
      Begin_Edit (Current_Instance.all, To_String (Name),
                  Current_Instance.Profile, True);
   end On_Duplicate;

   procedure On_Rename
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      Dialog     : Gtk.Dialog.Gtk_Dialog;
      Name_Field : Gtk.GEntry.Gtk_Entry;
      Dummy      : Gtk.Widget.Gtk_Widget;
      Response : Gtk.Dialog.Gtk_Response_Type;
      Old_Name : String := "";
   begin
      if Current_Instance = null
        or else Length (Current_Instance.Selected_Name) = 0
      then
         return;
      end if;
      Old_Name := Selected_Name (Current_Instance.all);
      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("Rename Sandbox Profile");
      Dialog.Set_Transient_For (Current_Instance.Window);
      Dialog.Set_Modal (True);
      Gtk.GEntry.Gtk_New (Name_Field);
      Name_Field.Set_Text (Old_Name);
      Dialog.Get_Content_Area.Pack_Start (Name_Field, False, False, 8);
      Dummy := Dialog.Add_Button ("_Rename", Gtk.Dialog.Gtk_Response_OK);
      Dummy := Dialog.Add_Button ("_Cancel", Gtk.Dialog.Gtk_Response_Cancel);
      Dialog.Show_All;
      Response := Dialog.Run;
      if Response = Gtk.Dialog.Gtk_Response_OK then
         declare
            New_Name : constant String := Name_Field.Get_Text;
         begin
            if not LLM.Tools.Sandbox.Is_Valid_Profile_Name (New_Name) then
               Show_Error
                 (Current_Instance.all,
                  "Invalid profile name: '" & New_Name & "'.");
            else
               begin
                  LLM.Tools.Sandbox.Rename_Profile (Old_Name, New_Name);
                  begin
                     LLM.Settings.Rename_Default_Sandbox
                       (Old_Name => Old_Name,
                        New_Name => New_Name);
                  exception
                     when E : others =>
                        Show_Error
                          (Current_Instance.all,
                           "Profile renamed, but the persistent default "
                           & "could not be updated: "
                           & Ada.Exceptions.Exception_Message (E));
                  end;
                  Current_Instance.Selected_Name :=
                    To_Unbounded_String (New_Name);
                  Rebuild_Profile_List (Current_Instance.all);
                  Current_Instance.Status.Set_Text
                    ("Renamed " & Old_Name & " to " & New_Name);
               exception
                  when E : LLM.Tools.Sandbox.Sandbox_Error =>
                     Show_Error
                       (Current_Instance.all,
                        "Unable to rename profile '" & Old_Name & "': "
                        & Ada.Exceptions.Exception_Message (E));
               end;
            end if;
         end;
      end if;
      Dialog.Destroy;
   end On_Rename;

   procedure On_Refresh
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Current_Instance /= null and then not Current_Instance.Edit_Mode then
         Refresh (Current_Instance.all);
      end if;
   end On_Refresh;

   procedure On_Use
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      Accepted : Boolean;
   begin
      if Current_Instance = null
        or else Length (Current_Instance.Selected_Name) = 0
      then
         return;
      end if;
      if Current_Instance.Use_Handler /= null then
         Current_Instance.Use_Handler.all
           (Selected_Name (Current_Instance.all));
         Current_Instance.Status.Set_Text
           ("Queued sandbox profile " & Selected_Name (Current_Instance.all));
         return;
      end if;
      if Current_Instance.Queue = null then
         return;
      end if;
      Current_Instance.Queue.Enqueue
        ((Kind           => Coyote_GUI.Prompt_Queue.Set_Sandbox,
          Target_Agent_Id => Current_Instance.Target_Agent_Id,
          Profile_Name   => Current_Instance.Selected_Name), Accepted);
      if Accepted then
         Current_Instance.Status.Set_Text
           ("Queued sandbox profile " & Selected_Name (Current_Instance.all));
      else
         Show_Error (Current_Instance.all, "The agent command queue is full.");
      end if;
   end On_Use;

   procedure On_Close
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Current_Instance /= null and then Current_Instance.Window /= null then
         Current_Instance.Window.Hide;
      end if;
   end On_Close;

   procedure On_Save_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
      S : access Instance := Current_Instance;
   begin
      if S /= null then
         declare
            Name : constant String := S.Name_Entry.Get_Text;
            Value : LLM.Tools.Sandbox.Profile;
         begin
            if not LLM.Tools.Sandbox.Is_Valid_Profile_Name (Name) then
               Show_Error (S.all, "Invalid profile name: '" & Name & "'.");
               return;
            end if;
            Value.Allow_Write := Read_Path_List (S.Allow_Write);
            Value.Deny_Write := Read_Path_List (S.Deny_Write);
            Value.Deny_Read := Read_Path_List (S.Deny_Read);
            Value.Allow_Read := Read_Path_List (S.Allow_Read);
            for Group_Name of Group_Names loop
               declare
                  Name : constant String := To_String (Group_Name);
                  Paths : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
                    Read_Path_List (List_For_Name (S.all, Name));
               begin
                  for Path of Paths loop
                     if Path'Length = 0 then
                        Show_Error
                          (S.all,
                           "Empty path in " & Name & " rules.");
                        return;
                     end if;
                  end loop;
               end;
            end loop;
            begin
               if S.New_Profile then
                  LLM.Tools.Sandbox.Create_Profile (Name, Value);
               else
                  LLM.Tools.Sandbox.Edit_Profile (Name, Value);
               end if;
               S.Profile := Value;
               S.Selected_Name := To_Unbounded_String (Name);
               S.New_Profile := False;
               Rebuild_Profile_List (S.all);
               Update_Details (S.all);
               Set_Browse (S.all);
               S.Status.Set_Text ("Saved " & Name);
            exception
               when E : LLM.Tools.Sandbox.Sandbox_Error =>
                  Show_Error
                    (S.all,
                     "Unable to save profile '" & Name & "': "
                     & Ada.Exceptions.Exception_Message (E));
            end;
         end;
      end if;
   end On_Save_Clicked;

   procedure On_Cancel_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      if Current_Instance /= null then
         Set_Browse (Current_Instance.all);
      end if;
   end On_Cancel_Clicked;

   procedure On_New_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_New (null);
   end On_New_Button;

   procedure On_Edit_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_Edit (null);
   end On_Edit_Button;

   procedure On_Duplicate_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_Duplicate (null);
   end On_Duplicate_Button;

   procedure On_Rename_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_Rename (null);
   end On_Rename_Button;

   procedure On_Use_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_Use (null);
   end On_Use_Button;

   procedure On_Save_Menu
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Current_Instance /= null then
         On_Save_Clicked (Current_Instance.Save_Button);
      end if;
   end On_Save_Menu;

   procedure On_Help
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Current_Instance /= null then
         Show_Message
           (Current_Instance.all,
            Gtk.Message_Dialog.Message_Info,
            "Use named profiles to describe filesystem access. "
            & "New and Duplicate create unsaved edits; Save validates "
            & "profile names and nonempty path rules.");
      end if;
   end On_Help;

   function Make_Menu_Item
     (Menu  : not null access Gtk.Menu.Gtk_Menu_Record'Class;
      Label : String;
      Call  : Gtk.Menu_Item.Cb_Gtk_Menu_Item_Void)
      return Gtk.Menu_Item.Gtk_Menu_Item
   is
      Item : Gtk.Menu_Item.Gtk_Menu_Item;
   begin
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Item, Label);
      Item.On_Activate (Call);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Menu), Item);
      return Item;
   end Make_Menu_Item;

   procedure Create_Menus
     (Window : not null access Gtk.Window.Gtk_Window_Record'Class;
      Outer  : not null access Gtk.Box.Gtk_Box_Record'Class)
   is
      pragma Unreferenced (Window);
      Bar : Gtk.Menu_Bar.Gtk_Menu_Bar;
      File_Menu, Selected_Menu, Edit_Menu, View_Menu, Help_Menu :
        Gtk.Menu.Gtk_Menu;
      File_Item, Selected_Item, Edit_Item, View_Item, Help_Item :
        Gtk.Menu_Item.Gtk_Menu_Item;
      Item : Gtk.Menu_Item.Gtk_Menu_Item;
   begin
      Gtk.Menu_Bar.Gtk_New (Bar);
      Gtk.Menu.Gtk_New (File_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (File_Item, "_File");
      File_Item.Set_Submenu (File_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Bar), File_Item);
      Item := Make_Menu_Item (File_Menu, "_New", On_New'Access);
      Item := Make_Menu_Item (File_Menu, "_Save", On_Save_Menu'Access);
      Item := Make_Menu_Item (File_Menu, "_Close", On_Close'Access);

      Gtk.Menu.Gtk_New (Selected_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Selected_Item, "_Selected");
      Selected_Item.Set_Submenu (Selected_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Bar), Selected_Item);
      Item := Make_Menu_Item (Selected_Menu, "_Use Profile", On_Use'Access);
      Item := Make_Menu_Item (Selected_Menu, "_Edit", On_Edit'Access);
      Item := Make_Menu_Item
        (Selected_Menu, "_Duplicate Profile", On_Duplicate'Access);
      Item := Make_Menu_Item
        (Selected_Menu, "_Rename Profile", On_Rename'Access);

      Gtk.Menu.Gtk_New (Edit_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Edit_Item, "_Edit");
      Edit_Item.Set_Submenu (Edit_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Bar), Edit_Item);

      Gtk.Menu.Gtk_New (View_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (View_Item, "_View");
      View_Item.Set_Submenu (View_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Bar), View_Item);
      Item := Make_Menu_Item (View_Menu, "_Refresh", On_Refresh'Access);

      Gtk.Menu.Gtk_New (Help_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Help_Item, "_Help");
      Help_Item.Set_Submenu (Help_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Bar), Help_Item);
      Item := Make_Menu_Item
        (Help_Menu, "About Sandbox Profiles", On_Help'Access);
      Outer.Pack_Start (Bar, False, False, 0);
   end Create_Menus;

   procedure Create
     (S               : aliased in out Instance;
      Main_Window     : not null access Gtk.Window.Gtk_Window_Record'Class;
      Prompt_Queue    : not null access Coyote_GUI.Prompt_Queue.Queue;
      Target_Agent_Id : String := "")
   is
      Outer       : Gtk.Box.Gtk_Box;
      Content     : Gtk.Box.Gtk_Box;
      Main_Pane   : Gtk.Paned.Gtk_Hpaned;
      Left_Box    : Gtk.Box.Gtk_Box;
      Right_Box   : Gtk.Box.Gtk_Box;
      Scroll      : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Label       : Gtk.Label.Gtk_Label;
      Actions     : Gtk.Box.Gtk_Box;
      Edit_B      : Gtk.Button.Gtk_Button;
      Duplicate_B : Gtk.Button.Gtk_Button;
      Rename_B    : Gtk.Button.Gtk_Button;
      Use_B       : Gtk.Button.Gtk_Button;
   begin
      if S.Created then
         return;
      end if;
      S.Main_Window := Main_Window;
      S.Queue := Prompt_Queue.all'Unchecked_Access;
      S.Target_Agent_Id := To_Unbounded_String (Target_Agent_Id);
      Gtk.Window.Gtk_New (S.Window, Gtk.Enums.Window_Toplevel);
      Current_Instance := S'Unchecked_Access;
      S.Window.Set_Title ("coyote : Sandbox Profiles");
      S.Window.Set_Transient_For (Main_Window);
      S.Window.Set_Default_Size (760, 520);
      S.Window.Set_Size_Request (620, 420);
      S.Window.On_Delete_Event (On_Window_Delete'Access);
      S.Window.On_Key_Press_Event (On_Key_Press'Access);
      Gtk.Box.Gtk_New_Vbox (Outer, False, 0);
      S.Window.Add (Outer);
      Create_Menus (S.Window, Outer);
      Gtk.Box.Gtk_New_Vbox (Content, False, 4);
      Content.Set_Border_Width (8);
      Outer.Pack_Start (Content, True, True, 0);
      Gtk.Paned.Gtk_New_Hpaned (Main_Pane);
      Gtk.Box.Gtk_New_Vbox (Left_Box, False, 4);
      Gtk.Label.Gtk_New (Label, "Sandbox profiles");
      Label.Set_Halign (Gtk.Widget.Align_Start);
      Left_Box.Pack_Start (Label, False, False, 0);
      Gtk.List_Box.Gtk_New (S.Profile_List);
      S.Profile_List.Set_Selection_Mode (Gtk.Enums.Selection_Single);
      S.Profile_List.On_Row_Activated (On_Profile_Activated'Access);
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Scroll.Add (S.Profile_List);
      Left_Box.Pack_Start (Scroll, True, True, 0);
      Main_Pane.Pack1 (Left_Box, True, False);
      Gtk.Box.Gtk_New_Vbox (Right_Box, False, 4);
      S.Detail_Box := Right_Box;
      Gtk.Label.Gtk_New (S.Details, "No sandbox profile is available.");
      S.Details.Set_Halign (Gtk.Widget.Align_Start);
      S.Details.Set_Line_Wrap (True);
      Right_Box.Pack_Start (S.Details, True, True, 0);
      Gtk.Box.Gtk_New_Vbox (S.Editor, False, 3);
      Gtk.Label.Gtk_New (Label, "Profile name:");
      S.Editor.Pack_Start (Label, False, False, 0);
      Gtk.GEntry.Gtk_New (S.Name_Entry);
      S.Editor.Pack_Start (S.Name_Entry, False, False, 0);
      Create_Path_Group
        (S.Editor, "Allow write", "allow-write", S.Allow_Write);
      Create_Path_Group
        (S.Editor, "Deny write", "deny-write", S.Deny_Write);
      Create_Path_Group
        (S.Editor, "Deny read", "deny-read", S.Deny_Read);
      Create_Path_Group
        (S.Editor, "Allow read", "allow-read", S.Allow_Read);
      Gtk.Box.Gtk_New_Hbox (Actions, False, 4);
      Gtk.Button.Gtk_New_With_Mnemonic (S.Save_Button, "_Save");
      Gtk.Button.Gtk_New_With_Mnemonic (S.Cancel_Button, "_Cancel");
      S.Save_Button.On_Clicked (On_Save_Clicked'Access);
      S.Cancel_Button.On_Clicked (On_Cancel_Clicked'Access);
      Actions.Pack_Start (S.Save_Button, False, False, 0);
      Actions.Pack_Start (S.Cancel_Button, False, False, 0);
      S.Editor.Pack_Start (Actions, False, False, 0);
      Right_Box.Pack_Start (S.Editor, True, True, 0);
      Gtk.Box.Gtk_New_Hbox (Actions, False, 4);
      Gtk.Button.Gtk_New_With_Mnemonic (Edit_B, "_Edit");
      Gtk.Button.Gtk_New_With_Mnemonic (Duplicate_B, "_Duplicate Profile");
      Gtk.Button.Gtk_New_With_Mnemonic (Rename_B, "_Rename Profile");
      Gtk.Button.Gtk_New_With_Mnemonic (Use_B, "_Use Profile");
      Edit_B.On_Clicked (On_Edit_Button'Access);
      Duplicate_B.On_Clicked (On_Duplicate_Button'Access);
      Rename_B.On_Clicked (On_Rename_Button'Access);
      Use_B.On_Clicked (On_Use_Button'Access);
      Actions.Pack_Start (Edit_B, False, False, 0);
      Actions.Pack_Start (Duplicate_B, False, False, 0);
      Actions.Pack_Start (Rename_B, False, False, 0);
      Actions.Pack_Start (Use_B, False, False, 0);
      Right_Box.Pack_Start (Actions, False, False, 0);
      Main_Pane.Pack2 (Right_Box, True, False);
      Main_Pane.Set_Position (270);
      Content.Pack_Start (Main_Pane, True, True, 0);
      Gtk.Label.Gtk_New (S.Status, "Browse mode");
      S.Status.Set_Halign (Gtk.Widget.Align_Start);
      Content.Pack_End (S.Status, False, False, 0);
      S.Created := True;
      Refresh (S);
      Set_Browse (S);
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
         S.Window.Show_All;
         S.Window.Present;
         S.Profile_List.Grab_Focus;
      end if;
   end Show;

   procedure Set_Target_Agent
     (S             : in out Instance;
      Target_Agent_Id : String)
   is
   begin
      S.Target_Agent_Id := To_Unbounded_String (Target_Agent_Id);
   end Set_Target_Agent;

   procedure Set_Use_Profile_Handler
     (S       : in out Instance;
      Handler : Use_Profile_Handler)
   is
   begin
      S.Use_Handler := Handler;
   end Set_Use_Profile_Handler;

   procedure Refresh (S : in out Instance) is
      Name : constant String := To_String (S.Selected_Name);
   begin
      if not S.Created or else S.Edit_Mode then
         return;
      end if;
      S.Selected_Name := To_Unbounded_String (Name);
      Rebuild_Profile_List (S);
      if Length (S.Selected_Name) = 0 then
         S.Status.Set_Text ("No profiles found");
      end if;
   end Refresh;

end Coyote_GUI.Sandbox_Profile_Window;
