--  Coyote_GUI.Model_Picker body.
--
--  The picker keeps callback state private to this package because GtkAda
--  signal callbacks cannot capture the caller's nested local variables.
--
--  Project: coyote

with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_App.Utils;
with Glib;
with Glib.Values;
with Gtk.Box;
with Gtk.Cell_Renderer_Text;
with Gtk.Dialog;
with Gtk.Enums;
with Gtk.Label;
with Gtk.List_Store;
with Gtk.Scrolled_Window;
with Gtk.Search_Entry;
with Gtk.Tree_Model;
with Gtk.Tree_Model_Filter;
with Gtk.Tree_Model_Sort;
with Gtk.Tree_Selection;
with Gtk.Tree_View;
with Gtk.Tree_View_Column;
with Gtk.Widget;

package body Coyote_GUI.Model_Picker is

   use Coyote_App.Utils;
   use type Glib.Gint;
   use type Glib.Guint16;
   use type Gtk.Dialog.Gtk_Dialog;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Dialog.Gtk_Response_Type;
   use type LLM.Settings.Price_Display_Mode;
   use type Gtk.Tree_Model.Gtk_Tree_Iter;
   use type Gtk.Tree_Model_Filter.Gtk_Tree_Model_Filter;
   use type Gtk.Tree_Model_Sort.Gtk_Tree_Model_Sort;
   use type Gtk.Tree_View.Gtk_Tree_View;

   Default_Spec : constant String := "__coyote_use_default__";

   type Picker_State is record
      Filter : Gtk.Tree_Model_Filter.Gtk_Tree_Model_Filter := null;
      Sort   : Gtk.Tree_Model_Sort.Gtk_Tree_Model_Sort     := null;
      View   : Gtk.Tree_View.Gtk_Tree_View                 := null;
      Search : Gtk.Search_Entry.Gtk_Search_Entry           := null;
      Count  : Gtk.Label.Gtk_Label                         := null;
      Dialog : Gtk.Dialog.Gtk_Dialog                       := null;
      Query  : Unbounded_String := Null_Unbounded_String;
   end record;

   State : Picker_State;

   procedure Clear_State is
   begin
      State := (others => <>);
   end Clear_State;

   function Row_Visible
     (Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter  : Gtk.Tree_Model.Gtk_Tree_Iter)
      return Boolean
   is
      use Gtk.Tree_Model;
   begin
      if Iter = Null_Iter then
         return False;
      end if;
      return
        Model_Row_Matches
          (Provider => Get_String (Model, Iter, 0),
           Name     => Get_String (Model, Iter, 1),
           Spec     => Get_String (Model, Iter, 7),
           Query    => To_String (State.Query));
   end Row_Visible;

   procedure Update_Count is
      use Gtk.Tree_Model;
      use Gtk.Tree_Model_Filter;
      Needle  : constant String :=
        Ada.Strings.Fixed.Trim (To_String (State.Query), Ada.Strings.Both);
      Visible : Natural         := 0;
   begin
      if State.Filter = null or else State.Count = null then
         return;
      end if;
      Visible := Natural (N_Children (+State.Filter));
      State.Count.Set_Text
        (Format_Model_Picker_Count
           (Visible => Visible, Filtered => Needle'Length > 0));
   end Update_Count;

   procedure Ensure_Selection is
      use Gtk.Tree_Model;
      use Gtk.Tree_Model_Sort;
      Selection : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Model     : Gtk_Tree_Model;
      Iter      : Gtk_Tree_Iter;
      Path      : Gtk_Tree_Path;
   begin
      if State.View = null then
         return;
      end if;
      Selection := State.View.Get_Selection;
      Selection.Get_Selected (Model, Iter);
      if Iter /= Null_Iter then
         return;
      end if;
      Iter := Get_Iter_First (+State.Sort);
      if Iter = Null_Iter then
         return;
      end if;
      Selection.Select_Iter (Iter);
      Path := Get_Path (+State.Sort, Iter);
      State.View.Scroll_To_Cell (Path, null, False, 0.0, 0.0);
      Path_Free (Path);
   end Ensure_Selection;

   procedure Apply_Filter is
   begin
      if State.Filter = null then
         return;
      end if;
      State.Filter.Refilter;
      Update_Count;
      Ensure_Selection;
   end Apply_Filter;

   procedure On_Search_Changed
     (Self : access Gtk.Search_Entry.Gtk_Search_Entry_Record'Class)
   is
   begin
      State.Query := To_Unbounded_String (Self.Get_Text);
      Apply_Filter;
   end On_Search_Changed;

   procedure On_Search_Stop
     (Self : access Gtk.Search_Entry.Gtk_Search_Entry_Record'Class)
   is
   begin
      if Self.Get_Text_Length > 0 then
         Self.Set_Text ("");
         State.Query := Null_Unbounded_String;
         Apply_Filter;
      elsif State.Dialog /= null then
         State.Dialog.Response (Gtk.Dialog.Gtk_Response_Cancel);
      end if;
   end On_Search_Stop;

   procedure On_Row_Activated
     (Self   : access Gtk.Tree_View.Gtk_Tree_View_Record'Class;
      Path   : Gtk.Tree_Model.Gtk_Tree_Path;
      Column : not null access Gtk.Tree_View_Column
        .Gtk_Tree_View_Column_Record'
        Class)
   is
      pragma Unreferenced (Self, Path, Column);
   begin
      if State.Dialog /= null then
         State.Dialog.Response (Gtk.Dialog.Gtk_Response_OK);
      end if;
   end On_Row_Activated;

   procedure Add_Text_Column
     (View     : not null access Gtk.Tree_View.Gtk_Tree_View_Record'Class;
      Title    : String;
      Col_Num  : Glib.Gint;
      Sort_Col : Glib.Gint := -1)
   is
      Column   : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Renderer : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      Dummy    : Glib.Gint;
      pragma Unreferenced (Dummy);
   begin
      Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
      Gtk.Tree_View_Column.Gtk_New (Column);
      Column.Set_Title (Title);
      Column.Pack_Start (Renderer, Expand => True);
      Column.Add_Attribute (Renderer, "text", Col_Num);
      Column.Set_Resizable (True);
      if Sort_Col >= 0 then
         Column.Set_Sort_Column_Id (Sort_Col);
      end if;
      Dummy := View.Append_Column (Column);
   end Add_Text_Column;

   function Price_Sort (Price : Long_Float) return Glib.Gint is
      Scale : constant Long_Float := 1.0E6;
      Limit : constant Long_Float := Long_Float (Glib.Gint'Last);
   begin
      if Price <= 0.0 then
         return 0;
      elsif Price * Scale >= Limit then
         return Glib.Gint'Last;
      else
         return Glib.Gint (Price * Scale);
      end if;
   end Price_Sort;

   function Price_Text
     (Price         : Long_Float;
      Price_Display : LLM.Settings.Price_Display_Mode)
      return String
   is
   begin
      if Price = 0.0 then
         return "free";
      elsif Price < 0.0 then
         return "";
      elsif Price_Display = LLM.Settings.Decibels then
         return Format_DB_Price (Price);
      else
         return Format_SI_Price (Price);
      end if;
   end Price_Text;

   function Initial_Iter
     (Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Spec  : String)
      return Gtk.Tree_Model.Gtk_Tree_Iter
   is
      use Gtk.Tree_Model;
      Iter : Gtk_Tree_Iter := Get_Iter_First (Model);
   begin
      while Iter /= Null_Iter loop
         if Get_String (Model, Iter, 7) = Spec then
            return Iter;
         end if;
         Next (Model, Iter);
      end loop;
      return Null_Iter;
   end Initial_Iter;

   function Choose
     (Parent        : not null access Gtk.Window.Gtk_Window_Record'Class;
      Models        : LLM.Model_Registry.Model_Info_Vectors.Vector;
      Price_Display : LLM.Settings.Price_Display_Mode;
      Initial_Spec  : String  := "";
      Allow_Default : Boolean := False)
      return Selection_Result
   is
      use Gtk.Dialog;
      use Gtk.List_Store;
      use Gtk.Tree_Model;
      use Gtk.Tree_Model_Filter;
      use Gtk.Tree_Model_Sort;
      use Gtk.Tree_View;
      Store      : Gtk_List_Store;
      View       : Gtk_Tree_View;
      Scroll     : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Search_Row : Gtk.Box.Gtk_Box;
      Content    : Gtk.Box.Gtk_Box;
      Dialog     : Gtk_Dialog;
      Response   : Gtk_Response_Type;
      Selection  : Gtk.Tree_Selection.Gtk_Tree_Selection;
      Model      : Gtk_Tree_Model;
      Iter       : Gtk_Tree_Iter;
      Value      : Glib.Values.GValue;
      --  Unconstrained holder: a constrained String initialized from an
      --  empty Initial_Spec has null bounds (1..0) and cannot later hold
      --  Default_Spec, which raised Constraint_Error on the length check.
      Initial    : Unbounded_String := To_Unbounded_String (Initial_Spec);
   begin
      Gtk.List_Store.Gtk_New
        (Store,
         (0  => Glib.GType_String,
          1  => Glib.GType_String,
          2  => Glib.GType_String,
          3  => Glib.GType_String,
          4  => Glib.GType_String,
          5  => Glib.GType_String,
          6  => Glib.GType_String,
          7  => Glib.GType_String,
          8  => Glib.GType_Int,
          9  => Glib.GType_Int,
          10 => Glib.GType_Int,
          11 => Glib.GType_Int,
          12 => Glib.GType_Int));

      if Allow_Default then
         Store.Append (Iter);
         Store.Set (Iter, 0, "(default)");
         Store.Set (Iter, 1, "Use default model");
         Store.Set (Iter, 7, Default_Spec);
      end if;

      for Model_Info of Models loop
         declare
            Provider : constant String := To_String (Model_Info.Provider);
            Name     : constant String :=
              (if Length (Model_Info.Name) > 0 then To_String (Model_Info.Name)
               else To_String (Model_Info.Model_Id));
            Context  : constant String :=
              Format_SI_Count (Model_Info.Context_Window) & " ctx";
            Input_P  : constant String :=
              Price_Text (Model_Info.Cost.Input, Price_Display);
            Output_P : constant String :=
              Price_Text (Model_Info.Cost.Output, Price_Display);
            Read_P   : constant String :=
              Price_Text (Model_Info.Cost.Cache_Read, Price_Display);
            Write_P  : constant String :=
              Price_Text (Model_Info.Cost.Cache_Write, Price_Display);
            Spec     : constant String :=
              Provider & "/" & To_String (Model_Info.Model_Id);
            Row      : Gtk_Tree_Iter;
         begin
            Store.Append (Row);
            Store.Set (Row, 0, Provider);
            Store.Set (Row, 1, Name);
            Store.Set (Row, 2, Context);
            Store.Set (Row, 3, Input_P);
            Store.Set (Row, 4, Output_P);
            Store.Set (Row, 5, Read_P);
            Store.Set (Row, 6, Write_P);
            Store.Set (Row, 7, Spec);
            Store.Set (Row, 8, Glib.Gint (Model_Info.Context_Window));
            Store.Set (Row, 9, Price_Sort (Model_Info.Cost.Input));
            Store.Set (Row, 10, Price_Sort (Model_Info.Cost.Output));
            Store.Set (Row, 11, Price_Sort (Model_Info.Cost.Cache_Read));
            Store.Set (Row, 12, Price_Sort (Model_Info.Cost.Cache_Write));
         end;
      end loop;

      Clear_State;
      Gtk.Tree_Model_Filter.Gtk_New (State.Filter, +Store);
      State.Filter.Set_Visible_Func (Row_Visible'Access);
      Gtk.Tree_Model_Sort.Gtk_New_With_Model (State.Sort, +State.Filter);
      Gtk.Tree_View.Gtk_New (View, +State.Sort);
      View.On_Row_Activated (On_Row_Activated'Access);
      View.Set_Enable_Search (False);
      Add_Text_Column (View, "Provider", 0, 0);
      Add_Text_Column (View, "Name", 1, 1);
      Add_Text_Column (View, "Context", 2, 8);
      Add_Text_Column
        (View,
         (if Price_Display = LLM.Settings.Decibels then "In dB ($/tok)"
          else "In $/MTok"),
         3,
         9);
      Add_Text_Column
        (View,
         (if Price_Display = LLM.Settings.Decibels then "Out dB ($/tok)"
          else "Out $/MTok"),
         4,
         10);
      Add_Text_Column
        (View,
         (if Price_Display = LLM.Settings.Decibels then "CR dB ($/tok)"
          else "CR $/MTok"),
         5,
         11);
      Add_Text_Column
        (View,
         (if Price_Display = LLM.Settings.Decibels then "CW dB ($/tok)"
          else "CW $/MTok"),
         6,
         12);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      Scroll.Add (View);
      Gtk.Dialog.Gtk_New (Dialog);
      Dialog.Set_Title ("coyote : Select Model");
      Dialog.Set_Default_Size (1_000, 520);
      Dialog.Set_Transient_For (Parent);
      declare
         Button : Gtk.Widget.Gtk_Widget;
         pragma Warnings (Off, Button);
      begin
         Button := Dialog.Add_Button ("_Select", Gtk_Response_OK);
         Button := Dialog.Add_Button ("_Cancel", Gtk_Response_Cancel);
      end;
      Dialog.Set_Default_Response (Gtk_Response_OK);

      Gtk.Search_Entry.Gtk_New (State.Search);
      State.Search.Set_Placeholder_Text ("Filter models");
      State.Search.On_Search_Changed (On_Search_Changed'Access);
      State.Search.On_Stop_Search (On_Search_Stop'Access);
      Gtk.Label.Gtk_New (State.Count, "");
      State.Count.Set_Xalign (1.0);
      State.Count.Set_Width_Chars (12);
      Gtk.Box.Gtk_New_Hbox (Search_Row, Homogeneous => False, Spacing => 8);
      Search_Row.Set_Border_Width (4);
      Search_Row.Pack_Start (State.Search, True, True, 0);
      Search_Row.Pack_Start (State.Count, False, False, 0);

      State.View   := View;
      State.Dialog := Dialog;
      State.Query  := Null_Unbounded_String;
      if Allow_Default and then Length (Initial) = 0 then
         Initial := To_Unbounded_String (Default_Spec);
      end if;
      Update_Count;
      if Length (Initial) > 0 then
         Selection := View.Get_Selection;
         Iter      := Initial_Iter (+State.Sort, To_String (Initial));
         if Iter /= Null_Iter then
            Selection.Select_Iter (Iter);
         else
            Ensure_Selection;
         end if;
      else
         Ensure_Selection;
      end if;

      Content := Dialog.Get_Content_Area;
      Content.Pack_Start (Search_Row, False, True, 0);
      Content.Pack_Start (Scroll, True, True, 4);
      Dialog.Show_All;
      State.Search.Grab_Focus;
      Response := Dialog.Run;
      if Response = Gtk_Response_OK then
         Selection := View.Get_Selection;
         Selection.Get_Selected (Model, Iter);
         if Iter /= Null_Iter then
            Gtk.Tree_Model.Get_Value (Model, Iter, 7, Value);
            declare
               Spec : constant String := Glib.Values.Get_String (Value);
            begin
               Glib.Values.Unset (Value);
               Dialog.Destroy;
               Clear_State;
               if Spec = Default_Spec then
                  return (Status => Use_Default);
               elsif Spec'Length > 0 then
                  return
                    (Status     => Selected,
                     Model_Spec => To_Unbounded_String (Spec));
               end if;
            end;
         end if;
      end if;
      Dialog.Destroy;
      Clear_State;
      return (Status => Cancelled);
   exception
      when others =>
         if Dialog /= null then
            Dialog.Destroy;
         end if;
         Clear_State;
         raise;
   end Choose;

end Coyote_GUI.Model_Picker;
