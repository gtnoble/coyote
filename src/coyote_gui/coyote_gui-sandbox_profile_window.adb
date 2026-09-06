--  Coyote_GUI.Sandbox_Profile_Window body.
--
--  The manager keeps typed profile drafts in memory.  Profile files are
--  changed only by Save, and Cancel discards all pending drafts.
--
--  Project: coyote

with Ada.Containers;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_GUI.Prompt_Queue;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Glib;
with Glib.Values;
with Gtk.Bin;
with Gtk.Box;
with Gtk.Button;
with Gtk.Cell_Renderer_Text;
with Gtk.Dialog;
with Gtk.Editable;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.GEntry;
with Gtk.Handlers;
with Gtk.Label;
with Gtk.List_Box;
with Gtk.List_Box_Row;
with Gtk.List_Store;
with Gtk.Menu;
with Gtk.Menu_Bar;
with Gtk.Menu_Item;
with Gtk.Menu_Shell;
with Gtk.Message_Dialog;
with Gtk.Paned;
with Gtk.Scrolled_Window;
with Gtk.Tree_Model;
with Gtk.Tree_Selection;
with Gtk.Tree_View;
with Gtk.Tree_View_Column;
with Gtk.Widget;
with Gtk.Window;
with LLM.Tools.Sandbox;
package body Coyote_GUI.Sandbox_Profile_Window is

   use type Ada.Containers.Count_Type;
   use type Gdk.Types.Gdk_Key_Type;
   use type Gdk.Types.Gdk_Modifier_Type;
   use type Glib.Gint;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Button.Gtk_Button;
   use type Gtk.Tree_Model.Gtk_Tree_Iter;
   use Gtk.List_Store;
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

   procedure On_Editor_Changed (Self : Gtk.Editable.Gtk_Editable);

   procedure On_Profile_Selected
     (List : access Gtk.List_Box.Gtk_List_Box_Record'Class;
      Row  : not null access Gtk.List_Box_Row.Gtk_List_Box_Row_Record'Class);

   procedure On_Help
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_Close_Manager
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_New_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class);

   procedure On_Duplicate_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class);

   procedure On_Use_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class);

   procedure On_Save_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class);

   procedure On_Cancel_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class);

   procedure On_New
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_Duplicate
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_Use
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_Save
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_Cancel
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   procedure On_Refresh
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class);

   function Draft_Index
     (S    : Instance;
      Name : String) return Natural
   is
   begin
      if not S.Drafts.Is_Empty then
         for Index in S.Drafts.First_Index .. S.Drafts.Last_Index loop
            if To_String (S.Drafts.Element (Index).Name) = Name then
               return Natural (Index);
            end if;
         end loop;
      end if;
      return 0;
   end Draft_Index;

   function Draft_Index
     (Drafts : Draft_Vectors.Vector;
      Name   : String) return Natural
   is
   begin
      if not Drafts.Is_Empty then
         for Index in Drafts.First_Index .. Drafts.Last_Index loop
            if To_String (Drafts.Element (Index).Name) = Name then
               return Natural (Index);
            end if;
         end loop;
      end if;
      return 0;
   end Draft_Index;

   function Profile_Equal
     (Left  : LLM.Tools.Sandbox.Profile;
      Right : LLM.Tools.Sandbox.Profile) return Boolean
   is
      function Vectors_Equal
        (A : LLM.Tools.Sandbox.String_Vectors.Vector;
         B : LLM.Tools.Sandbox.String_Vectors.Vector) return Boolean
      is
      begin
         if A.Length /= B.Length then
            return False;
         end if;
         if not A.Is_Empty then
            for Index in A.First_Index .. A.Last_Index loop
               if A.Element (Index) /= B.Element (Index) then
                  return False;
               end if;
            end loop;
         end if;
         return True;
      end Vectors_Equal;
   begin
      return Vectors_Equal (Left.Allow_Write, Right.Allow_Write)
        and then Vectors_Equal (Left.Deny_Write, Right.Deny_Write)
        and then Vectors_Equal (Left.Deny_Read, Right.Deny_Read)
        and then Vectors_Equal (Left.Allow_Read, Right.Allow_Read);
   end Profile_Equal;

   function Any_Dirty (S : Instance) return Boolean is
   begin
      if not S.Drafts.Is_Empty then
         for Draft of S.Drafts loop
            if Draft.Dirty then
               return True;
            end if;
         end loop;
      end if;
      return False;
   end Any_Dirty;

   procedure Show_Message
     (S         : Instance;
      The_Type  : Gtk.Message_Dialog.Gtk_Message_Type;
      Buttons   : Gtk.Message_Dialog.Gtk_Buttons_Type;
      Message   : String)
   is
      Dialog   : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Response : Gtk.Dialog.Gtk_Response_Type;
   begin
      Gtk.Message_Dialog.Gtk_New
        (Dialog,
         (if S.Window = null then null else S.Window),
         Gtk.Dialog.Modal or Gtk.Dialog.Destroy_With_Parent,
         The_Type,
         Buttons,
         Message);
      Response := Gtk.Dialog.Gtk_Dialog (Dialog).Run;
      pragma Unreferenced (Response);
      Dialog.Destroy;
   end Show_Message;

   procedure Show_Error (S : Instance; Message : String) is
   begin
      Show_Message
        (S, Gtk.Message_Dialog.Message_Error,
         Gtk.Message_Dialog.Buttons_Ok, Message);
   end Show_Error;

   function Confirm_Discard (S : Instance; Message : String) return Boolean is
      Dialog   : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Response : Gtk.Dialog.Gtk_Response_Type;
   begin
      Gtk.Message_Dialog.Gtk_New
        (Dialog,
         (if S.Window = null then null else S.Window),
         Gtk.Dialog.Modal or Gtk.Dialog.Destroy_With_Parent,
         Gtk.Message_Dialog.Message_Question,
         Gtk.Message_Dialog.Buttons_Yes_No,
         Message);
      Response := Gtk.Dialog.Gtk_Dialog (Dialog).Run;
      Dialog.Destroy;
      return Response = Gtk.Dialog.Gtk_Response_Yes;
   end Confirm_Discard;

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

   type Path_Group is (Allow_Write_Group, Deny_Write_Group,
                       Deny_Read_Group, Allow_Read_Group);

   function Group_For_Index (Index : Natural) return Path_Group is
   begin
      case Index is
         when 1 => return Allow_Write_Group;
         when 2 => return Deny_Write_Group;
         when 3 => return Deny_Read_Group;
         when others => return Allow_Read_Group;
      end case;
   end Group_For_Index;

   function View_For_Group
     (S : Instance; Group : Path_Group) return Gtk.Tree_View.Gtk_Tree_View
   is
   begin
      case Group is
         when Allow_Write_Group => return S.Allow_Write_View;
         when Deny_Write_Group  => return S.Deny_Write_View;
         when Deny_Read_Group   => return S.Deny_Read_View;
         when Allow_Read_Group  => return S.Allow_Read_View;
      end case;
   end View_For_Group;

   function Store_For_Group
     (S : Instance; Group : Path_Group) return Gtk.List_Store.Gtk_List_Store
   is
   begin
      case Group is
         when Allow_Write_Group => return S.Allow_Write_Store;
         when Deny_Write_Group  => return S.Deny_Write_Store;
         when Deny_Read_Group   => return S.Deny_Read_Store;
         when Allow_Read_Group  => return S.Allow_Read_Store;
      end case;
   end Store_For_Group;

   procedure Set_Active_Group (S : in out Instance; Name : String) is
   begin
      if Name = "allow-write-paths" then
         S.Active_Group := 1;
      elsif Name = "deny-write-paths" then
         S.Active_Group := 2;
      elsif Name = "deny-read-paths" then
         S.Active_Group := 3;
      elsif Name = "allow-read-paths" then
         S.Active_Group := 4;
      end if;
   end Set_Active_Group;

   procedure Get_Selected_Path
     (S     : Instance;
      Group : Path_Group;
      Model : out Gtk.Tree_Model.Gtk_Tree_Model;
      Iter  : out Gtk.Tree_Model.Gtk_Tree_Iter)
   is
   begin
      View_For_Group (S, Group).Get_Selection.Get_Selected (Model, Iter);
   end Get_Selected_Path;

   function Has_Path_Selection
     (S : Instance; Group : Path_Group) return Boolean
   is
      Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter  : Gtk.Tree_Model.Gtk_Tree_Iter;
   begin
      Get_Selected_Path (S, Group, Model, Iter);
      return Iter /= Gtk.Tree_Model.Null_Iter;
   end Has_Path_Selection;

   function Read_Path_List
     (View : Gtk.Tree_View.Gtk_Tree_View)
      return LLM.Tools.Sandbox.String_Vectors.Vector
   is
      Result : LLM.Tools.Sandbox.String_Vectors.Vector;
      Model  : constant Gtk.Tree_Model.Gtk_Tree_Model := View.Get_Model;
      Iter   : Gtk.Tree_Model.Gtk_Tree_Iter;
      Value  : Glib.Values.GValue;
      Count  : constant Glib.Gint := Gtk.Tree_Model.N_Children (Model);
   begin
      if Count > 0 then
         for Index in 0 .. Count - 1 loop
            Iter := Gtk.Tree_Model.Get_Iter_From_String
              (Model, Ada.Strings.Fixed.Trim
                 (Glib.Gint'Image (Index), Ada.Strings.Both));
            if Iter /= Gtk.Tree_Model.Null_Iter then
               Gtk.Tree_Model.Get_Value (Model, Iter, 0, Value);
               declare
                  Path : constant String :=
                    Glib.Values.Get_String (Value);
               begin
                  Result.Append (Path);
               end;
               Glib.Values.Unset (Value);
            end if;
         end loop;
      end if;
      return Result;
   end Read_Path_List;

   procedure Fill_Path_List
     (Store  : Gtk.List_Store.Gtk_List_Store;
      Values : LLM.Tools.Sandbox.String_Vectors.Vector)
   is
      Iter : Gtk.Tree_Model.Gtk_Tree_Iter;
   begin
      Store.Clear;
      for Value of Values loop
         Store.Append (Iter);
         Store.Set (Iter, 0, Value);
      end loop;
   end Fill_Path_List;

   procedure Update_Action_State (S : in out Instance) is
      Has_Selection : constant Boolean := S.Selected_Draft > 0;
      Can_Use       : Boolean := Has_Selection;
      Has_Path      : constant Boolean :=
        Has_Path_Selection (S, Group_For_Index (S.Active_Group));
   begin
      if Has_Selection then
         Can_Use := not S.Drafts.Element (S.Selected_Draft).Is_New;
      end if;
      if S.Save_Button /= null then
         S.Save_Button.Set_Sensitive (Any_Dirty (S));
      end if;
      if S.Cancel_Button /= null then
         S.Cancel_Button.Set_Sensitive (Any_Dirty (S));
      end if;
      if S.Edit_Path_Button /= null then
         S.Edit_Path_Button.Set_Sensitive (Has_Path);
      end if;
      if S.Remove_Path_Button /= null then
         S.Remove_Path_Button.Set_Sensitive (Has_Path);
      end if;
      pragma Unreferenced (Can_Use);
   end Update_Action_State;

   procedure Capture_Editor (S : in out Instance) is
      Draft : Profile_Draft;
   begin
      if S.Updating_Editor
        or else S.Selected_Draft = 0
        or else S.Drafts.Is_Empty
      then
         return;
      end if;
      Draft := S.Drafts.Element (S.Selected_Draft);
      Draft.Name := To_Unbounded_String (S.Name_Entry.Get_Text);
      Draft.Profile.Allow_Write := Read_Path_List (S.Allow_Write_View);
      Draft.Profile.Deny_Write := Read_Path_List (S.Deny_Write_View);
      Draft.Profile.Deny_Read := Read_Path_List (S.Deny_Read_View);
      Draft.Profile.Allow_Read := Read_Path_List (S.Allow_Read_View);
      Draft.Dirty := Draft.Is_New
        or else Draft.Name /= Draft.Baseline_Name
        or else not Profile_Equal (Draft.Profile, Draft.Baseline);
      S.Drafts.Replace_Element (S.Selected_Draft, Draft);
   end Capture_Editor;

   procedure Populate_Editor (S : in out Instance) is
      Draft : Profile_Draft;
   begin
      S.Updating_Editor := True;
      if S.Selected_Draft = 0 or else S.Drafts.Is_Empty then
         S.Name_Entry.Set_Text ("");
         S.Name_Entry.Set_Editable (False);
         Fill_Path_List
           (S.Allow_Write_Store,
            LLM.Tools.Sandbox.String_Vectors.Empty_Vector);
         Fill_Path_List
           (S.Deny_Write_Store,
            LLM.Tools.Sandbox.String_Vectors.Empty_Vector);
         Fill_Path_List
           (S.Deny_Read_Store,
            LLM.Tools.Sandbox.String_Vectors.Empty_Vector);
         Fill_Path_List
           (S.Allow_Read_Store,
            LLM.Tools.Sandbox.String_Vectors.Empty_Vector);
      else
         Draft := S.Drafts.Element (S.Selected_Draft);
         S.Name_Entry.Set_Text (To_String (Draft.Name));
         S.Name_Entry.Set_Editable (Draft.Is_New);
         Fill_Path_List (S.Allow_Write_Store, Draft.Profile.Allow_Write);
         Fill_Path_List (S.Deny_Write_Store, Draft.Profile.Deny_Write);
         Fill_Path_List (S.Deny_Read_Store, Draft.Profile.Deny_Read);
         Fill_Path_List (S.Allow_Read_Store, Draft.Profile.Allow_Read);
      end if;
      S.Updating_Editor := False;
      Update_Action_State (S);
   end Populate_Editor;

   procedure Update_Profile_List_Labels (S : in out Instance) is
      Row   : Gtk.List_Box_Row.Gtk_List_Box_Row;
      Child : Gtk.Widget.Gtk_Widget;
   begin
      if not S.Drafts.Is_Empty then
         for Index in S.Drafts.First_Index .. S.Drafts.Last_Index loop
            Row := S.Profile_List.Get_Row_At_Index (Glib.Gint (Index - 1));
            if Row /= null then
               Child := Gtk.Bin.Get_Child (Gtk.Bin.Gtk_Bin (Row));
               if Child /= null then
                  Gtk.Label.Gtk_Label (Child).Set_Text
                    ((if S.Drafts.Element (Index).Dirty then "* " else "")
                     & To_String (S.Drafts.Element (Index).Name));
               end if;
            end if;
         end loop;
      end if;
      Update_Action_State (S);
   end Update_Profile_List_Labels;

   procedure On_Editor_Changed (Self : Gtk.Editable.Gtk_Editable) is
      pragma Unreferenced (Self);
   begin
      if Current_Instance /= null
        and then not Current_Instance.Updating_Editor
      then
         Capture_Editor (Current_Instance.all);
         Update_Profile_List_Labels (Current_Instance.all);
      end if;
   end On_Editor_Changed;

   procedure On_Path_Selection_Changed
     (Self : access Gtk.Tree_Selection.Gtk_Tree_Selection_Record'Class)
   is
   begin
      if Current_Instance /= null then
         Set_Active_Group
           (Current_Instance.all, Self.Get_Tree_View.Get_Name);
         Update_Action_State (Current_Instance.all);
      end if;
   end On_Path_Selection_Changed;

   function On_Path_View_Button_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Button) return Boolean
   is
      pragma Unreferenced (Event);
   begin
      if Current_Instance /= null then
         Set_Active_Group (Current_Instance.all, Self.Get_Name);
         Update_Action_State (Current_Instance.all);
      end if;
      return False;
   end On_Path_View_Button_Press;

   function On_Path_View_Focus_In
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Focus) return Boolean
   is
      pragma Unreferenced (Event);
   begin
      if Current_Instance /= null then
         Set_Active_Group (Current_Instance.all, Self.Get_Name);
         Update_Action_State (Current_Instance.all);
      end if;
      return False;
   end On_Path_View_Focus_In;

   function Edit_Path
     (S        : Instance;
      Title    : String;
      Initial  : String;
      Accepted : out Boolean) return String
   is
      Dialog : Gtk.Dialog.Gtk_Dialog;
      Path_Field : Gtk.GEntry.Gtk_Entry;
      Dummy      : Gtk.Widget.Gtk_Widget;
      Result     : Gtk.Dialog.Gtk_Response_Type;
   begin
      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title (Title);
      Dialog.Set_Transient_For (S.Window);
      Dialog.Set_Modal (True);
      Gtk.GEntry.Gtk_New (Path_Field);
      Path_Field.Set_Text (Initial);
      Path_Field.Set_Width_Chars (48);
      Dialog.Get_Content_Area.Pack_Start
        (Path_Field, False, False, 8);
      Dummy := Dialog.Add_Button
        ("_Edit", Gtk.Dialog.Gtk_Response_OK);
      Dummy := Dialog.Add_Button
        ("_Cancel", Gtk.Dialog.Gtk_Response_Cancel);
      pragma Unreferenced (Dummy);
      Dialog.Set_Default_Response (Gtk.Dialog.Gtk_Response_OK);
      Dialog.Show_All;
      Path_Field.Grab_Focus;
      Path_Field.Select_Region (0, -1);
      Result := Dialog.Run;
      Accepted := Result = Gtk.Dialog.Gtk_Response_OK;
      declare
         Value : constant String := Path_Field.Get_Text;
      begin
         Dialog.Destroy;
         return Value;
      end;
   end Edit_Path;

   procedure On_Add_Path
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
      S        : access Instance := Current_Instance;
      Group    : Path_Group;
      Store    : Gtk.List_Store.Gtk_List_Store;
      View     : Gtk.Tree_View.Gtk_Tree_View;
      Iter     : Gtk.Tree_Model.Gtk_Tree_Iter;
      Accepted : Boolean;
   begin
      if S = null then
         return;
      end if;
      Group := Group_For_Index (S.Active_Group);
      Store := Store_For_Group (S.all, Group);
      View := View_For_Group (S.all, Group);
      declare
         Value : constant String :=
           Edit_Path (S.all, "Add Path", "", Accepted);
      begin
         if Accepted and then Value'Length > 0 then
            Store.Append (Iter);
            Store.Set (Iter, 0, Value);
            View.Get_Selection.Select_Iter (Iter);
            Capture_Editor (S.all);
            Update_Profile_List_Labels (S.all);
         end if;
      end;
   end On_Add_Path;

   procedure On_Edit_Path
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
      S        : access Instance := Current_Instance;
      Group    : Path_Group;
      Store    : Gtk.List_Store.Gtk_List_Store;
      Model    : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter     : Gtk.Tree_Model.Gtk_Tree_Iter;
      Value    : Glib.Values.GValue;
      Accepted : Boolean;
      Current  : Unbounded_String;
   begin
      if S = null then
         return;
      end if;
      Group := Group_For_Index (S.Active_Group);
      Store := Store_For_Group (S.all, Group);
      Get_Selected_Path (S.all, Group, Model, Iter);
      if Iter = Gtk.Tree_Model.Null_Iter then
         return;
      end if;
      Gtk.Tree_Model.Get_Value (Model, Iter, 0, Value);
      Current := To_Unbounded_String (Glib.Values.Get_String (Value));
      Glib.Values.Unset (Value);
      declare
         New_Value : constant String :=
           Edit_Path (S.all, "Edit Path", To_String (Current), Accepted);
      begin
         if Accepted and then New_Value'Length > 0 then
            Store.Set (Iter, 0, New_Value);
            Capture_Editor (S.all);
            Update_Profile_List_Labels (S.all);
         end if;
      end;
   end On_Edit_Path;

   procedure On_Remove_Path
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
      S     : access Instance := Current_Instance;
      Group : Path_Group;
      Store : Gtk.List_Store.Gtk_List_Store;
      Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter  : Gtk.Tree_Model.Gtk_Tree_Iter;
   begin
      if S = null then
         return;
      end if;
      Group := Group_For_Index (S.Active_Group);
      Store := Store_For_Group (S.all, Group);
      Get_Selected_Path (S.all, Group, Model, Iter);
      if Iter /= Gtk.Tree_Model.Null_Iter then
         Store.Remove (Iter);
         Capture_Editor (S.all);
         Update_Profile_List_Labels (S.all);
      end if;
   end On_Remove_Path;

   procedure Create_Path_Group
     (Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Title  : String;
      Name   : String;
      View   : out Gtk.Tree_View.Gtk_Tree_View;
      Store  : out Gtk.List_Store.Gtk_List_Store)
   is
      Frame     : Gtk.Frame.Gtk_Frame;
      Scroll    : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Column    : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Renderer  : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      Selection : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Dummy     : Glib.Gint;
   begin
      Gtk.Frame.Gtk_New (Frame, Title);
      Gtk.List_Store.Gtk_New (Store, (0 => Glib.GType_String));
      Gtk.Tree_View.Gtk_New (View, +Store);
      View.Set_Name (Name);
      View.Set_Headers_Visible (False);
      View.Set_Enable_Search (False);
      Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
      Gtk.Tree_View_Column.Gtk_New (Column);
      Column.Pack_Start (Renderer, Expand => True);
      Column.Add_Attribute (Renderer, "text", 0);
      Dummy := View.Append_Column (Column);
      Selection := View.Get_Selection;
      Selection.Set_Mode (Gtk.Enums.Selection_Single);
      Selection.On_Changed (On_Path_Selection_Changed'Access);
      View.On_Button_Press_Event (On_Path_View_Button_Press'Access);
      View.On_Focus_In_Event (On_Path_View_Focus_In'Access);
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      Scroll.Set_Size_Request (-1, 72);
      Scroll.Add (View);
      Frame.Add (Scroll);
      Frame.Set_Border_Width (6);
      Parent.Pack_Start (Frame, True, True, 0);
   end Create_Path_Group;

   procedure Rebuild_Profile_List (S : in out Instance) is
      Wanted : Unbounded_String;
      Index  : Natural := 0;
      Row    : Gtk.List_Box_Row.Gtk_List_Box_Row;
      Label  : Gtk.Label.Gtk_Label;
   begin
      if S.Selected_Draft > 0 and then not S.Drafts.Is_Empty then
         Wanted := S.Drafts.Element (S.Selected_Draft).Name;
      end if;
      S.Refreshing := True;
      Gtk.Handlers.Handlers_Destroy
        (Gtk.Widget.Gtk_Widget (S.Profile_List));
      S.Profile_List.Set_Selection_Mode (Gtk.Enums.Selection_None);
      Clear_List (S.Profile_List);
      if not S.Drafts.Is_Empty then
         for Draft_Index in S.Drafts.First_Index .. S.Drafts.Last_Index loop
            Gtk.List_Box_Row.Gtk_New (Row);
            Gtk.Label.Gtk_New
              (Label,
               (if S.Drafts.Element (Draft_Index).Dirty then "* " else "")
               & To_String (S.Drafts.Element (Draft_Index).Name));
            Label.Set_Halign (Gtk.Widget.Align_Start);
            Row.Add (Label);
            S.Profile_List.Add (Row);
            Row.Show_All;
            if S.Drafts.Element (Draft_Index).Name = Wanted then
               Index := Natural (Draft_Index);
            end if;
         end loop;
      end if;
      if Index = 0 and then not S.Drafts.Is_Empty then
         Index := Natural (S.Drafts.First_Index);
      end if;
      S.Selected_Draft := Index;
      S.Profile_List.Set_Selection_Mode (Gtk.Enums.Selection_Single);
      S.Profile_List.On_Row_Selected (On_Profile_Selected'Access);
      if Index > 0 then
         Row := S.Profile_List.Get_Row_At_Index (Glib.Gint (Index - 1));
         if Row /= null then
            S.Profile_List.Select_Row (Row);
         end if;
      end if;
      S.Refreshing := False;
      Populate_Editor (S);
      if S.Drafts.Is_Empty then
         S.Status.Set_Text ("No profiles found; use File / New.");
      elsif Any_Dirty (S) then
         S.Status.Set_Text ("Unsaved profile changes");
      else
         S.Status.Set_Text ("Profiles loaded");
      end if;
   exception
      when others =>
         S.Refreshing := False;
         raise;
   end Rebuild_Profile_List;

   procedure Load_Persisted_Drafts (S : in out Instance) is
      Names : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
        LLM.Tools.Sandbox.Available_Profiles;
      Draft : Profile_Draft;
   begin
      S.Drafts.Clear;
      for Name of Names loop
         begin
            Draft.Name := To_Unbounded_String (Name);
            Draft.Baseline_Name := Draft.Name;
            Draft.Profile := LLM.Tools.Sandbox.Load_Profile_Typed (Name);
            Draft.Baseline := Draft.Profile;
            Draft.Is_New := False;
            Draft.Dirty := False;
            S.Drafts.Append (Draft);
         exception
            when E : LLM.Tools.Sandbox.Sandbox_Error =>
               Show_Error
                 (S,
                  "Unable to load profile '" & Name & "': "
                  & Ada.Exceptions.Exception_Message (E));
         end;
      end loop;
   end Load_Persisted_Drafts;

   procedure Refresh_Persisted_Drafts (S : in out Instance) is
      Names          : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
        LLM.Tools.Sandbox.Available_Profiles;
      Old_Drafts     : constant Draft_Vectors.Vector := S.Drafts;
      New_Drafts     : Draft_Vectors.Vector;
      Draft          : Profile_Draft;
      Selected_Name  : Unbounded_String;
      Old_Index      : Natural;
   begin
      if S.Selected_Draft > 0 and then not Old_Drafts.Is_Empty then
         Selected_Name := Old_Drafts.Element (S.Selected_Draft).Name;
      end if;
      for Name of Names loop
         Old_Index := Draft_Index (Old_Drafts, Name);
         if Old_Index > 0 and then Old_Drafts.Element (Old_Index).Dirty then
            New_Drafts.Append (Old_Drafts.Element (Old_Index));
         else
            begin
               Draft.Name := To_Unbounded_String (Name);
               Draft.Baseline_Name := Draft.Name;
               Draft.Profile := LLM.Tools.Sandbox.Load_Profile_Typed (Name);
               Draft.Baseline := Draft.Profile;
               Draft.Is_New := False;
               Draft.Dirty := False;
               New_Drafts.Append (Draft);
            exception
               when E : LLM.Tools.Sandbox.Sandbox_Error =>
                  Show_Error
                    (S,
                     "Unable to load profile '" & Name & "': "
                     & Ada.Exceptions.Exception_Message (E));
            end;
         end if;
      end loop;
      if not Old_Drafts.Is_Empty then
         for Old_Index in Old_Drafts.First_Index .. Old_Drafts.Last_Index loop
            Draft := Old_Drafts.Element (Old_Index);
            if (Draft.Is_New or else Draft.Dirty)
              and then Draft_Index (New_Drafts, To_String (Draft.Name)) = 0
            then
               New_Drafts.Append (Draft);
            end if;
         end loop;
      end if;
      S.Drafts := New_Drafts;
      S.Selected_Draft := Draft_Index (S.Drafts, To_String (Selected_Name));
   end Refresh_Persisted_Drafts;

   procedure On_Profile_Selected
     (List : access Gtk.List_Box.Gtk_List_Box_Record'Class;
      Row  : not null access Gtk.List_Box_Row.Gtk_List_Box_Row_Record'Class)
   is
      pragma Unreferenced (List);
      S     : access Instance := Current_Instance;
      Index : Natural;
   begin
      if S = null or else S.Refreshing then
         return;
      end if;
      Capture_Editor (S.all);
      Index := Natural (Row.Get_Index) + 1;
      if Index <= Natural (S.Drafts.Length) then
         S.Selected_Draft := Index;
         Populate_Editor (S.all);
         S.Status.Set_Text
           ("Editing " & To_String (S.Drafts.Element (Index).Name));
      end if;
   end On_Profile_Selected;

   function Unique_Name
     (S : Instance; Base : String) return String
   is
      Candidate : Unbounded_String := To_Unbounded_String (Base);
      Suffix    : Natural := 2;
   begin
      while Draft_Index (S, To_String (Candidate)) > 0 loop
         Candidate := To_Unbounded_String
           (Base & "-"
            & Ada.Strings.Fixed.Trim
                (Natural'Image (Suffix), Ada.Strings.Both));
         Suffix := Suffix + 1;
      end loop;
      return To_String (Candidate);
   end Unique_Name;

   procedure On_New
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      Draft : Profile_Draft;
      S     : access Instance := Current_Instance;
   begin
      if S = null then
         return;
      end if;
      Capture_Editor (S.all);
      Draft.Name := To_Unbounded_String (Unique_Name (S.all, "new-profile"));
      Draft.Is_New := True;
      Draft.Dirty := True;
      S.Drafts.Append (Draft);
      S.Selected_Draft := Natural (S.Drafts.Last_Index);
      Rebuild_Profile_List (S.all);
      S.Name_Entry.Grab_Focus;
   end On_New;

   procedure On_Duplicate
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      Draft : Profile_Draft;
      S     : access Instance := Current_Instance;
      Base  : Unbounded_String;
   begin
      if S = null or else S.Selected_Draft = 0 then
         return;
      end if;
      Capture_Editor (S.all);
      Draft := S.Drafts.Element (S.Selected_Draft);
      Base := To_Unbounded_String (To_String (Draft.Name) & "-copy");
      Draft.Name := To_Unbounded_String (Unique_Name (S.all, To_String (Base)));
      Draft.Baseline_Name := Null_Unbounded_String;
      Draft.Baseline := LLM.Tools.Sandbox.Profile'(others => <>);
      Draft.Is_New := True;
      Draft.Dirty := True;
      S.Drafts.Append (Draft);
      S.Selected_Draft := Natural (S.Drafts.Last_Index);
      Rebuild_Profile_List (S.all);
   end On_Duplicate;

   procedure On_Refresh
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Current_Instance /= null then
         Refresh (Current_Instance.all);
      end if;
   end On_Refresh;

   function Drafts_Valid (S : Instance; Message : out Unbounded_String)
      return Boolean
   is
      Result : Boolean := True;
   begin
      if not S.Drafts.Is_Empty then
         for Left in S.Drafts.First_Index .. S.Drafts.Last_Index loop
            declare
               Name : constant String :=
                 To_String (S.Drafts.Element (Left).Name);
            begin
               if not LLM.Tools.Sandbox.Is_Valid_Profile_Name (Name) then
                  Message := To_Unbounded_String
                    ("Invalid profile name: '" & Name & "'.");
                  return False;
               end if;
               if S.Drafts.Element (Left).Dirty then
                  for Group_Name of Group_Names loop
                     declare
                        Paths : constant LLM.Tools.Sandbox.String_Vectors.Vector :=
                          (if Group_Name = To_Unbounded_String ("allow-write")
                           then S.Drafts.Element (Left).Profile.Allow_Write
                           elsif Group_Name = To_Unbounded_String ("deny-write")
                           then S.Drafts.Element (Left).Profile.Deny_Write
                           elsif Group_Name = To_Unbounded_String ("deny-read")
                           then S.Drafts.Element (Left).Profile.Deny_Read
                           else S.Drafts.Element (Left).Profile.Allow_Read);
                     begin
                        for Path of Paths loop
                           if Path'Length = 0 then
                              Message := To_Unbounded_String
                                ("Empty path in " & To_String (Group_Name)
                                 & " rules.");
                              return False;
                           end if;
                        end loop;
                     end;
                  end loop;
               end if;
               if Left < S.Drafts.Last_Index then
                  for Right in Left + 1 .. S.Drafts.Last_Index loop
                     if S.Drafts.Element (Right).Name =
                       S.Drafts.Element (Left).Name
                     then
                        Message := To_Unbounded_String
                          ("Duplicate profile name: '" & Name & "'.");
                        return False;
                     end if;
                  end loop;
               end if;
            end;
         end loop;
      end if;
      return Result;
   end Drafts_Valid;

   procedure On_Save
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      S       : access Instance := Current_Instance;
      Message : Unbounded_String;
      Saved   : Natural := 0;
      Failed  : Natural := 0;
      Errors  : Unbounded_String;
   begin
      if S = null then
         return;
      end if;
      Capture_Editor (S.all);
      if not Drafts_Valid (S.all, Message) then
         Show_Error (S.all, To_String (Message));
         return;
      end if;
      if not S.Drafts.Is_Empty then
         for Index in S.Drafts.First_Index .. S.Drafts.Last_Index loop
            if S.Drafts.Element (Index).Dirty then
               declare
                  Draft : Profile_Draft := S.Drafts.Element (Index);
               begin
                  begin
                     if Draft.Is_New then
                        LLM.Tools.Sandbox.Create_Profile
                          (To_String (Draft.Name), Draft.Profile);
                     else
                        LLM.Tools.Sandbox.Edit_Profile
                          (To_String (Draft.Name), Draft.Profile);
                     end if;
                     Draft.Baseline_Name := Draft.Name;
                     Draft.Baseline := Draft.Profile;
                     Draft.Is_New := False;
                     Draft.Dirty := False;
                     S.Drafts.Replace_Element (Index, Draft);
                     Saved := Saved + 1;
                  exception
                     when E : LLM.Tools.Sandbox.Sandbox_Error =>
                        Failed := Failed + 1;
                        if Length (Errors) > 0 then
                           Append (Errors, ASCII.LF);
                        end if;
                        Append
                          (Errors,
                           To_String (Draft.Name) & ": "
                           & Ada.Exceptions.Exception_Message (E));
                  end;
               end;
            end if;
         end loop;
      end if;
      Rebuild_Profile_List (S.all);
      if Failed > 0 then
         Show_Error
           (S.all,
            "Some profiles were not saved:" & ASCII.LF
            & To_String (Errors));
      elsif Saved > 0 then
         S.Status.Set_Text
           (Natural'Image (Saved) & " profile(s) saved");
      else
         S.Status.Set_Text ("No unsaved profile changes");
      end if;
   end On_Save;

   procedure On_Cancel
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      S            : access Instance := Current_Instance;
      Selected_Name : Unbounded_String;
      Index        : Natural;
   begin
      if S /= null then
         if S.Selected_Draft > 0 and then not S.Drafts.Is_Empty then
            Selected_Name := S.Drafts.Element (S.Selected_Draft).Name;
         end if;
         Load_Persisted_Drafts (S.all);
         Index := Draft_Index (S.Drafts, To_String (Selected_Name));
         S.Selected_Draft := Index;
         Rebuild_Profile_List (S.all);
         S.Status.Set_Text ("Unsaved changes discarded");
      end if;
   end On_Cancel;

   procedure On_Use
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
      S        : access Instance := Current_Instance;
      Accepted : Boolean;
      Name     : Unbounded_String;
   begin
      if S = null or else S.Selected_Draft = 0 then
         return;
      end if;
      Capture_Editor (S.all);
      if S.Drafts.Element (S.Selected_Draft).Is_New then
         Show_Error (S.all, "Save the new profile before using it.");
         return;
      end if;
      Name := S.Drafts.Element (S.Selected_Draft).Name;
      if S.Use_Handler /= null then
         S.Use_Handler.all (To_String (Name));
         S.Status.Set_Text ("Queued sandbox profile " & To_String (Name));
         return;
      end if;
      if S.Queue = null then
         return;
      end if;
      S.Queue.Enqueue
        ((Kind           => Coyote_GUI.Prompt_Queue.Set_Sandbox,
          Target_Agent_Id => S.Target_Agent_Id,
          Profile_Name   => Name), Accepted);
      if Accepted then
         S.Status.Set_Text ("Queued sandbox profile " & To_String (Name));
      else
         Show_Error (S.all, "The agent command queue is full.");
      end if;
   end On_Use;

   procedure Close_Window (S : in out Instance) is
   begin
      Capture_Editor (S);
      if Any_Dirty (S)
        and then not Confirm_Discard
          (S, "Discard all unsaved sandbox profile changes?")
      then
         return;
      end if;
      if Any_Dirty (S) then
         Load_Persisted_Drafts (S);
         Rebuild_Profile_List (S);
      end if;
      S.Window.Hide;
   end Close_Window;

   function On_Window_Delete
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event) return Boolean
   is
      pragma Unreferenced (Self, Event);
   begin
      if Current_Instance /= null then
         Close_Window (Current_Instance.all);
      end if;
      return True;
   end On_Window_Delete;

   function On_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      if Current_Instance = null then
         return False;
      end if;
      if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_w
        and then (Event.State and Gdk.Types.Control_Mask) /= 0
      then
         Close_Window (Current_Instance.all);
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_Escape then
         On_Cancel (null);
         return True;
      end if;
      return False;
   end On_Key_Press;

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
      File_Menu, Selected_Menu, View_Menu, Help_Menu :
        Gtk.Menu.Gtk_Menu;
      File_Item, Selected_Item, View_Item, Help_Item :
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
      Item := Make_Menu_Item (File_Menu, "_Save", On_Save'Access);
      Item := Make_Menu_Item (File_Menu, "_Cancel", On_Cancel'Access);
      Item := Make_Menu_Item
        (File_Menu, "_Close", On_Close_Manager'Access);

      Gtk.Menu.Gtk_New (Selected_Menu);
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Selected_Item, "_Selected");
      Selected_Item.Set_Submenu (Selected_Menu);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Bar), Selected_Item);
      Item := Make_Menu_Item (Selected_Menu, "_Duplicate Profile",
                              On_Duplicate'Access);
      Item := Make_Menu_Item (Selected_Menu, "_Use Profile", On_Use'Access);

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

   procedure On_Help
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Current_Instance /= null then
         Show_Message
           (Current_Instance.all,
            Gtk.Message_Dialog.Message_Info,
            Gtk.Message_Dialog.Buttons_Ok,
            "Edit several named profiles in one session. New and Duplicate "
            & "remain in memory until Save; Cancel discards all unsaved "
            & "profile changes. Delete and Rename are not provided.");
      end if;
   end On_Help;

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
      New_B       : Gtk.Button.Gtk_Button;
      Duplicate_B : Gtk.Button.Gtk_Button;
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
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Scroll.Add (S.Profile_List);
      Left_Box.Pack_Start (Scroll, True, True, 0);
      Main_Pane.Pack1 (Left_Box, True, False);
      Gtk.Box.Gtk_New_Vbox (Right_Box, False, 4);
      Gtk.Box.Gtk_New_Vbox (S.Editor, False, 3);
      Gtk.Label.Gtk_New (Label, "Profile name:");
      S.Editor.Pack_Start (Label, False, False, 0);
      Gtk.GEntry.Gtk_New (S.Name_Entry);
      Gtk.Editable.On_Changed
        (Gtk.GEntry.Implements_Gtk_Editable.To_Interface
           (S.Name_Entry),
         On_Editor_Changed'Access);
      S.Editor.Pack_Start (S.Name_Entry, False, False, 0);
      Create_Path_Group
        (S.Editor, "Allow write", "allow-write-paths",
         S.Allow_Write_View, S.Allow_Write_Store);
      Create_Path_Group
        (S.Editor, "Deny write", "deny-write-paths",
         S.Deny_Write_View, S.Deny_Write_Store);
      Create_Path_Group
        (S.Editor, "Deny read", "deny-read-paths",
         S.Deny_Read_View, S.Deny_Read_Store);
      Create_Path_Group
        (S.Editor, "Allow read", "allow-read-paths",
         S.Allow_Read_View, S.Allow_Read_Store);
      Gtk.Box.Gtk_New_Hbox (Actions, False, 4);
      Gtk.Button.Gtk_New_With_Mnemonic (S.Add_Path_Button, "_Add Path");
      Gtk.Button.Gtk_New_With_Mnemonic
        (S.Edit_Path_Button, "_Edit Selected");
      Gtk.Button.Gtk_New_With_Mnemonic
        (S.Remove_Path_Button, "_Remove Selected");
      S.Add_Path_Button.On_Clicked (On_Add_Path'Access);
      S.Edit_Path_Button.On_Clicked (On_Edit_Path'Access);
      S.Remove_Path_Button.On_Clicked (On_Remove_Path'Access);
      Actions.Pack_Start (S.Add_Path_Button, False, False, 0);
      Actions.Pack_Start (S.Edit_Path_Button, False, False, 0);
      Actions.Pack_Start (S.Remove_Path_Button, False, False, 0);
      S.Editor.Pack_Start (Actions, False, False, 0);
      Gtk.Box.Gtk_New_Hbox (Actions, False, 4);
      Gtk.Button.Gtk_New_With_Mnemonic (S.Save_Button, "_Save");
      Gtk.Button.Gtk_New_With_Mnemonic (S.Cancel_Button, "_Cancel");
      S.Save_Button.On_Clicked (On_Save_Button'Access);
      S.Cancel_Button.On_Clicked (On_Cancel_Button'Access);
      Actions.Pack_Start (S.Save_Button, False, False, 0);
      Actions.Pack_Start (S.Cancel_Button, False, False, 0);
      S.Editor.Pack_Start (Actions, False, False, 0);
      Right_Box.Pack_Start (S.Editor, True, True, 0);
      Gtk.Box.Gtk_New_Hbox (Actions, False, 4);
      Gtk.Button.Gtk_New_With_Mnemonic (New_B, "_New");
      Gtk.Button.Gtk_New_With_Mnemonic (Duplicate_B, "_Duplicate Profile");
      Gtk.Button.Gtk_New_With_Mnemonic (Use_B, "_Use Profile");
      New_B.On_Clicked (On_New_Button'Access);
      Duplicate_B.On_Clicked (On_Duplicate_Button'Access);
      Use_B.On_Clicked (On_Use_Button'Access);
      Actions.Pack_Start (New_B, False, False, 0);
      Actions.Pack_Start (Duplicate_B, False, False, 0);
      Actions.Pack_Start (Use_B, False, False, 0);
      Right_Box.Pack_Start (Actions, False, False, 0);
      Main_Pane.Pack2 (Right_Box, True, False);
      Main_Pane.Set_Position (270);
      Content.Pack_Start (Main_Pane, True, True, 0);
      Gtk.Label.Gtk_New (S.Status, "Profiles not loaded");
      S.Status.Set_Halign (Gtk.Widget.Align_Start);
      Content.Pack_End (S.Status, False, False, 0);
      S.Created := True;
      Load_Persisted_Drafts (S);
      Rebuild_Profile_List (S);
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
     (S               : in out Instance;
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
   begin
      if not S.Created then
         return;
      end if;
      Capture_Editor (S);
      Refresh_Persisted_Drafts (S);
      Rebuild_Profile_List (S);
   end Refresh;

   procedure On_New_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_New (null);
   end On_New_Button;

   procedure On_Duplicate_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_Duplicate (null);
   end On_Duplicate_Button;

   procedure On_Use_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_Use (null);
   end On_Use_Button;

   procedure On_Save_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_Save (null);
   end On_Save_Button;

   procedure On_Cancel_Button
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      On_Cancel (null);
   end On_Cancel_Button;

   procedure On_Close_Manager
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Item);
   begin
      if Current_Instance /= null then
         Close_Window (Current_Instance.all);
      end if;
   end On_Close_Manager;

end Coyote_GUI.Sandbox_Profile_Window;
