with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Containers;
with Cairo;
with Gdk.Device_Tool;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Gtk.Accel_Group;
with Gtk.Check_Menu_Item;
with Gdk.Event;
with Glib;
with Gtk.Cell_Renderer_Text;
with Gtk.Enums;
with Gtk.Handlers;
with Gtk.Menu;
with Gtk.Menu_Bar;
with Gtk.Scrolled_Window;
with Gtk.Tree_Selection;
with Gtk.Tree_View_Column;
with Gtk.Widget;

package body Coyote_GUI.Canvas is
   use type Ada.Containers.Count_Type;
   package Doc renames Coyote_Canvas.Document;
   package Rev renames Coyote_Canvas.Revisions;
   package TM renames Gtk.Tree_Model;
   use type Gdk.Event.Gdk_Event_Mask;
   use type Gdk.Event.Gdk_Event_Type;
   use type Gdk.Device_Tool.Gdk_Device_Tool;
   use type Gdk.Types.Gdk_Key_Type;
   use type Gdk.Types.Gdk_Modifier_Type;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Drawing_Area.Gtk_Drawing_Area;
   use type Gtk.Tree_Model.Gtk_Tree_Path;
   use type Gtk.Tree_Model.Gtk_Tree_Path_List.Glist;
   use type Gtk.Accel_Group.Gtk_Accel_Group;
   use type Gtk.Tree_Model.Gtk_Tree_Iter;
   use type Gtk.Window.Gtk_Window;
   use type Glib.Gint;
   use type Glib.Gdouble;
   use type Glib.Guint;

   type Instance_Access is access all Instance;

   package Draw_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Drawing_Area.Gtk_Drawing_Area_Record, Boolean, Instance_Access);
   package Draw_Context_Marshaller is new Draw_Callback.Marshallers
     .Generic_Marshaller
     (Cairo.Cairo_Context, Cairo.Get_Context);
   package Event_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Widget.Gtk_Widget_Record, Boolean, Instance_Access);
   package Event_Marshaller is new Event_Callback.Marshallers
     .Generic_Marshaller
     (Gdk.Event.Gdk_Event, Gdk.Event.Get_Event);
   package Selection_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Tree_Selection.Gtk_Tree_Selection_Record, Instance_Access);
   package Button_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Button.Gtk_Button_Record, Instance_Access);
   package Entry_Callback is new Gtk.Handlers.User_Callback
     (Gtk.GEntry.Gtk_Entry_Record, Instance_Access);
   package Check_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record, Instance_Access);
   package Menu_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Menu_Item.Gtk_Menu_Item_Record, Instance_Access);

   function On_Draw
     (Area    : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context : Cairo.Cairo_Context; S : Instance_Access) return Boolean;
   function On_Press
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean;
   function On_Release
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean;
   function On_Motion
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean;
   function On_Delete
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean;
   function On_Cancel_Event
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean;
   procedure On_Selection
     (Selection : access Gtk.Tree_Selection.Gtk_Tree_Selection_Record'Class;
      S         : Instance_Access);
   procedure On_New
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Save
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Edit
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Undo
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Redo
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Crop
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Cancel_Crop
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Apply_Crop
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Close
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class;
      S    : Instance_Access);

   procedure Set_Status (S : in out Instance; Text : String) is
   begin
      if S.Status /= null then
         S.Status.Set_Text (Text);
      end if;
   end Set_Status;

   function Display_Extent (S : Instance) return Doc.Rectangle is
     (Rev.Extent
        (S.Document,
         (if S.Editing_Draft then Rev.NO_REVISION else S.Preview_Revision)));

   function Pending (S : Instance) return Doc.Rectangle is
      E : constant Doc.Rectangle := Rev.Extent (S.Document);
   begin
      if not S.Crop_Mode or else not Doc.Is_Nonempty (E) then
         return Doc.EMPTY_RECTANGLE;
      end if;
      return
        Doc.From_Fields
          (Integer'Value (S.X_Field.Get_Text),
           Integer'Value (S.Y_Field.Get_Text),
           Integer'Value (S.Width_Field.Get_Text),
           Integer'Value (S.Height_Field.Get_Text), E.Right - E.Left,
           E.Bottom - E.Top);
   exception
      when Constraint_Error =>
         return Doc.EMPTY_RECTANGLE;
   end Pending;

   procedure Refresh (S : in out Instance) is
      E          : constant Doc.Rectangle := Display_Extent (S);
      Editing    : constant Boolean       :=
        S.Has_Drawing and S.Editing_Draft and not S.Crop_Mode and
        not S.Drawing;
      Valid_Crop : constant Boolean       :=
        not S.Crop_Drag and then Doc.Is_Nonempty (Pending (S));
   begin
      if S.Drawing_Area = null then
         return;
      end if;
      S.Save_Item.Set_Sensitive (Editing and then Rev.Changed (S.Document));
      S.Edit_Item.Set_Sensitive (S.Preview_Revision /= 0);
      S.Draft_Item.Set_Sensitive (S.Has_Drawing and not S.Editing_Draft);
      S.Crop_Item.Set_Sensitive (Editing and S.Show_Ink);
      S.Undo_Item.Set_Sensitive (Editing and then Rev.Can_Undo (S.Document));
      S.Redo_Item.Set_Sensitive (Editing and then Rev.Can_Redo (S.Document));
      S.Apply_Crop.Set_Sensitive (Valid_Crop);
      S.Apply_Item.Set_Sensitive (Valid_Crop);
      S.Cancel_Item.Set_Sensitive (S.Crop_Mode);
      S.Drawing_Area.Set_Size_Request
        (Glib.Gint (Long_Float (E.Right - E.Left) * S.Zoom),
         Glib.Gint (Long_Float (E.Bottom - E.Top) * S.Zoom));
      S.Drawing_Area.Queue_Draw;
   end Refresh;

   procedure Cancel_Gesture (S : in out Instance) is
   begin
      S.Drawing := False;
      S.Stroke_Points.Clear;
      S.Crop_Drag := False;
      S.Crop_Mode := False;
      S.Crop_Grid.Hide;
   end Cancel_Gesture;

   procedure Extend_Tree (S : in out Instance) is
   begin
      for Id in S.Listed + 1 .. Rev.Count (S.Document) loop
         Add_Row :
         declare
            Ancestor : constant Rev.Revision_Id := Rev.Parent (S.Document, Id);
            Path     : TM.Gtk_Tree_Path;
         begin
            S.Store.Append
              (S.Rows (Id),
               (if Ancestor = 0 then TM.Null_Iter else S.Rows (Ancestor)));
            S.Store.Set
              (S.Rows (Id), 0,
               (if Ancestor = 0 then "Original (drawing" else "Revision") &
               Natural'Image (Id) & (if Ancestor = 0 then ")" else ""));
            S.Store.Set (S.Rows (Id), 1, Glib.Gint (Id));
            Path := S.Store.Get_Path (S.Rows (Id));
            S.Drawing_Tree.Expand_To_Path (Path);
            TM.Path_Free (Path);
            S.Listed := Id;
         end Add_Row;
      end loop;
   end Extend_Tree;

   procedure On_Field
     (Field : access Gtk.GEntry.Gtk_Entry_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Field);
   begin
      Refresh (S.all);
   end On_Field;

   procedure On_Markup
     (Item : access Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record'Class;
      S    : Instance_Access)
   is
   begin
      Cancel_Gesture (S.all);
      S.Show_Ink := Item.Get_Active;
      Refresh (S.all);
   end On_Markup;

   procedure On_Action
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class;
      S    : Instance_Access);

   procedure Build_Window
     (S      : aliased in out Instance;
      Parent :            not null access Gtk.Window.Gtk_Window_Record'Class)
   is
      Outer, Body_Box, Side : Gtk.Box.Gtk_Box;
      Bar                   : Gtk.Menu_Bar.Gtk_Menu_Bar;
      Menu                  : Gtk.Menu.Gtk_Menu;
      Scroll                : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Column                : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Renderer              : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      Label, Crop_Label     : Gtk.Label.Gtk_Label;
      Markup                : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
      Item                  : Gtk.Menu_Item.Gtk_Menu_Item;
      pragma Unreferenced (Item);
      Accels : Gtk.Accel_Group.Gtk_Accel_Group;
      State  : constant Instance_Access := S'Unchecked_Access;

      procedure Group (Title : String) is
         Top : Gtk.Menu_Item.Gtk_Menu_Item;
      begin
         Gtk.Menu.Gtk_New (Menu);
         Gtk.Menu_Item.Gtk_New_With_Mnemonic (Top, Title);
         Top.Set_Submenu (Menu);
         Bar.Append (Top);
      end Group;

      function Action
        (Title, Name : String; Key : Gdk.Types.Gdk_Key_Type := 0;
         Mods        : Gdk.Types.Gdk_Modifier_Type := Gdk.Types.Control_Mask)
         return Gtk.Menu_Item.Gtk_Menu_Item
      is
         Entry_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      begin
         Gtk.Menu_Item.Gtk_New_With_Mnemonic (Entry_Item, Title);
         Entry_Item.Set_Name ("canvas-" & Name);
         Menu.Append (Entry_Item);
         Menu_Callback.Connect
           (Entry_Item, "activate", On_Action'Access, State);
         if Key /= 0 then
            Entry_Item.Add_Accelerator
              ("activate", Accels, Key, Mods, Gtk.Accel_Group.Accel_Visible);
         end if;
         return Entry_Item;
      end Action;

      procedure Field
        (Control : out Gtk.GEntry.Gtk_Entry; Title, Name : String;
         Col     :     Glib.Gint)
      is
      begin
         Gtk.Label.Gtk_New_With_Mnemonic (Crop_Label, Title);
         Gtk.GEntry.Gtk_New (Control);
         Control.Set_Max_Length (11);
         Control.Set_Name ("coyote-canvas-crop-" & Name);
         Control.Set_Width_Chars (5);
         Crop_Label.Set_Mnemonic_Widget (Control);
         S.Crop_Grid.Attach (Crop_Label, Col, 0, 1, 1);
         S.Crop_Grid.Attach (Control, Col + 1, 0, 1, 1);
         Entry_Callback.Connect (Control, "changed", On_Field'Access, State);
      end Field;
   begin
      Gtk.Window.Gtk_New (S.Canvas_Window, Gtk.Enums.Window_Toplevel);
      S.Canvas_Window.Set_Title ("coyote : Canvas");
      S.Canvas_Window.Set_Name ("coyote-canvas-window");
      S.Canvas_Window.Set_Transient_For (Parent);
      S.Canvas_Window.Set_Default_Size (960, 680);
      Event_Callback.Connect
        (S.Canvas_Window, "delete-event",
         Event_Marshaller.To_Marshaller (On_Delete'Access),
         S'Unchecked_Access);
      Event_Callback.Connect
        (S.Canvas_Window, "key-press-event",
         Event_Marshaller.To_Marshaller (On_Cancel_Event'Access), State);
      Event_Callback.Connect
        (S.Canvas_Window, "focus-out-event",
         Event_Marshaller.To_Marshaller (On_Cancel_Event'Access), State);
      Gtk.Box.Gtk_New_Vbox (Outer, False, 0);
      S.Canvas_Window.Add (Outer);
      Gtk.Menu_Bar.Gtk_New (Bar);
      Gtk.Accel_Group.Gtk_New (Accels);
      S.Canvas_Window.Add_Accel_Group (Accels);
      Group ("_File");
      Item        := Action ("_New", "new", Gdk.Types.Keysyms.GDK_LC_n);
      S.Save_Item := Action ("_Save", "save", Gdk.Types.Keysyms.GDK_LC_s);
      Item        := Action ("_Close", "close", Gdk.Types.Keysyms.GDK_LC_w);
      Group ("_Selected");
      S.Edit_Item := Action ("_Edit Revision", "edit");
      Group ("_Edit");
      S.Undo_Item   := Action ("_Undo", "undo", Gdk.Types.Keysyms.GDK_LC_z);
      S.Redo_Item   :=
        Action
          ("_Redo", "redo", Gdk.Types.Keysyms.GDK_LC_z,
           Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask);
      S.Crop_Item   := Action ("_Crop...", "crop");
      S.Apply_Item  := Action ("_Apply Crop", "apply");
      S.Cancel_Item := Action ("Ca_ncel Crop", "cancel");
      Group ("_View");
      S.Draft_Item := Action ("Show _Working Copy", "draft");
      Item         := Action ("Zoom _In", "zoom-in");
      Item         := Action ("Zoom _Out", "zoom-out");
      Item         := Action ("_Actual Size", "actual");
      Gtk.Check_Menu_Item.Gtk_New_With_Mnemonic (Markup, "Show _Markup");
      Markup.Set_Active (True);
      Markup.Set_Name ("canvas-markup");
      Menu.Append (Markup);
      Check_Callback.Connect (Markup, "toggled", On_Markup'Access, State);
      Group ("_Help");
      Item := Action ("_Overview", "help", Gdk.Types.Keysyms.GDK_F1, 0);
      Outer.Pack_Start (Bar, False, False, 0);
      Accels.Unref;
      Gtk.Box.Gtk_New_Hbox (Body_Box, False, 4);
      Outer.Pack_Start (Body_Box, True, True, 0);
      Gtk.Box.Gtk_New_Vbox (Side, False, 3);
      Side.Set_Size_Request (210, -1);
      Body_Box.Pack_Start (Side, False, False, 2);
      Gtk.Label.Gtk_New (Label, "Drawings and revisions");
      Label.Set_Halign (Gtk.Widget.Align_Start);
      Side.Pack_Start (Label, False, False, 2);
      Gtk.Tree_Store.Gtk_New
        (S.Store, (0 => Glib.GType_String, 1 => Glib.GType_Int));
      Gtk.Tree_View.Gtk_New (S.Drawing_Tree, Gtk.Tree_Store."+" (S.Store));
      S.Store.Unref;
      S.Drawing_Tree.Set_Name ("coyote-canvas-drawings");
      Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
      Gtk.Tree_View_Column.Gtk_New (Column);
      Column.Set_Title ("Drawing / revision");
      Column.Pack_Start (Renderer, True);
      Column.Add_Attribute (Renderer, "text", 0);
      declare
         Ignored : constant Glib.Gint := S.Drawing_Tree.Append_Column (Column);
         pragma Unreferenced (Ignored);
      begin
         null;
      end;
      S.Drawing_Tree.Get_Selection.Set_Mode (Gtk.Enums.Selection_Multiple);
      Selection_Callback.Connect
        (S.Drawing_Tree.Get_Selection, "changed", On_Selection'Access, State);
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Add (S.Drawing_Tree);
      Side.Pack_Start (Scroll, True, True, 0);
      Gtk.Box.Gtk_New_Vbox (S.Root, False, 0);
      Body_Box.Pack_Start (S.Root, True, True, 0);
      Gtk.Drawing_Area.Gtk_New (S.Drawing_Area);
      S.Drawing_Area.Set_Name ("coyote-canvas-drawing-area");
      S.Drawing_Area.Set_Can_Focus (True);
      S.Drawing_Area.Add_Events
        (Gdk.Event.Button_Press_Mask or Gdk.Event.Button_Release_Mask or
         Gdk.Event.Pointer_Motion_Mask or Gdk.Event.Button_Motion_Mask);
      Draw_Callback.Connect
        (S.Drawing_Area, "draw",
         Draw_Context_Marshaller.To_Marshaller (On_Draw'Access), State);
      Event_Callback.Connect
        (S.Drawing_Area, "button-press-event",
         Event_Marshaller.To_Marshaller (On_Press'Access), S'Unchecked_Access);
      Event_Callback.Connect
        (S.Drawing_Area, "button-release-event",
         Event_Marshaller.To_Marshaller (On_Release'Access),
         S'Unchecked_Access);
      Event_Callback.Connect
        (S.Drawing_Area, "motion-notify-event",
         Event_Marshaller.To_Marshaller (On_Motion'Access),
         S'Unchecked_Access);
      Event_Callback.Connect
        (S.Drawing_Area, "grab-broken-event",
         Event_Marshaller.To_Marshaller (On_Cancel_Event'Access), State);
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      S.Drawing_Area.Set_Halign (Gtk.Widget.Align_Start);
      S.Drawing_Area.Set_Valign (Gtk.Widget.Align_Start);
      Scroll.Add (S.Drawing_Area);
      S.Root.Pack_Start (Scroll, True, True, 0);
      Gtk.Grid.Gtk_New (S.Crop_Grid);
      S.Crop_Grid.Set_Column_Spacing (4);
      Field (S.X_Field, "_X:", "x", 0);
      Field (S.Y_Field, "_Y:", "y", 2);
      Field (S.Width_Field, "_Width:", "width", 4);
      Field (S.Height_Field, "_Height:", "height", 6);
      Gtk.Button.Gtk_New (S.Apply_Crop, "Apply Crop");
      Gtk.Button.Gtk_New (S.Cancel_Crop, "Cancel");
      S.Apply_Crop.Set_Name ("canvas-apply-button");
      Button_Callback.Connect
        (S.Apply_Crop, "clicked", On_Apply_Crop'Access, State);
      Button_Callback.Connect
        (S.Cancel_Crop, "clicked", On_Cancel_Crop'Access, State);
      S.Crop_Grid.Attach (S.Apply_Crop, 8, 0, 1, 1);
      S.Crop_Grid.Attach (S.Cancel_Crop, 9, 0, 1, 1);
      Outer.Pack_Start (S.Crop_Grid, False, False, 2);
      Gtk.Label.Gtk_New (S.Status, "Blank drawing workspace");
      S.Status.Set_Name ("coyote-canvas-status");
      S.Status.Set_Halign (Gtk.Widget.Align_Start);
      Outer.Pack_Start (S.Status, False, False, 4);
      Outer.Show_All;
      S.Crop_Grid.Hide;
   end Build_Window;

   procedure Show
     (S      : aliased in out Instance;
      Parent :            not null access Gtk.Window.Gtk_Window_Record'Class)
   is
   begin
      if S.Canvas_Window = null then
         Build_Window (S, Parent);
      end if;
      S.Canvas_Window.Show;
      S.Canvas_Window.Present;
      Refresh (S);
   end Show;

   procedure Reset (S : in out Instance) is
   begin
      S.Resetting := True;
      S.Drawing := False;
      S.Stroke_Points.Clear;
      S.Crop_Drag   := False;
      S.Crop_Mode   := False;
      S.Has_Drawing := False;
      Coyote_Canvas.Revisions.Clear (S.Document);
      S.Preview_Revision := Coyote_Canvas.Revisions.NO_REVISION;
      if S.Canvas_Window /= null then
         S.Canvas_Window.Hide;
      end if;
      S.Listed := 0;
      if S.Canvas_Window /= null then
         S.Store.Clear;
         Cancel_Gesture (S);
      end if;
      S.Editing_Draft := True;
      S.Resetting := False;
      Refresh (S);
      Set_Status (S, "Canvas cleared");
   end Reset;

   procedure Destroy (S : in out Instance) is
   begin
      Reset (S);
      if S.Canvas_Window /= null then
         S.Canvas_Window.Destroy;
         S.Canvas_Window := null;
      end if;
      S.Root         := null;
      S.Drawing_Area := null;
      S.Store        := null;
      S.Drawing_Tree := null;
      S.Status       := null;
      S.Crop_Grid    := null;
      S.X_Field      := null;
      S.Y_Field      := null;
      S.Width_Field  := null;
      S.Height_Field := null;
      S.Apply_Crop   := null;
      S.Cancel_Crop  := null;
      S.Zoom         := 1.0;
      S.Show_Ink     := True;
   end Destroy;

   function Window (S : Instance) return Gtk.Window.Gtk_Window is
   begin
      return S.Canvas_Window;
   end Window;

   function Revision_Count (S : Instance) return Natural is
     (Rev.Count (S.Document));

   procedure On_New
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
   begin
      if S = null then
         return;
      end if;
      Cancel_Gesture (S.all);
      Rev.New_Drawing (S.Document, 800, 600);
      S.Has_Drawing := True;
      S.Drawing_Tree.Get_Selection.Unselect_All;
      S.Preview_Revision := Rev.NO_REVISION;
      S.Editing_Draft    := True;
      Extend_Tree (S.all);
      Refresh (S.all);
      Set_Status (S.all, "New blank drawing");
   exception
      when Coyote_Canvas.Revisions.Capacity_Error =>
         Set_Status (S.all, "Canvas capacity reached");
   end On_New;

   procedure On_Save
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
   begin
      if S /= null and then S.Editing_Draft and then not S.Crop_Mode then
         Coyote_Canvas.Revisions.Save (S.Document);
         Extend_Tree (S.all);
         Set_Status (S.all, "Working copy checkpointed in memory");
         Refresh (S.all);
      end if;
   exception
      when Coyote_Canvas.Revisions.Capacity_Error =>
         Set_Status (S.all, "Revision capacity reached; draft retained");
   end On_Save;

   procedure On_Edit
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
   begin
      if S /= null and then S.Preview_Revision /= 0 then
         Cancel_Gesture (S.all);
         Rev.Edit (S.Document, S.Preview_Revision);
         Extend_Tree (S.all);
         S.Editing_Draft := True;
         Set_Status (S.all, "Editing selected revision draft");
         Refresh (S.all);
      end if;
   exception
      when Coyote_Canvas.Revisions.Capacity_Error =>
         Set_Status (S.all, "Cannot checkpoint current draft");
      when Constraint_Error                       =>
         Set_Status (S.all, "Selected revision is unavailable");
   end On_Edit;

   procedure On_Undo
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
   begin
      if S /= null and then S.Editing_Draft and then not S.Crop_Mode then
         Coyote_Canvas.Revisions.Undo (S.Document);
         Refresh (S.all);
      end if;
   exception
      when others =>
         Set_Status (S.all, "Undo could not be applied");
   end On_Undo;

   procedure On_Redo
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
   begin
      if S /= null and then S.Editing_Draft and then not S.Crop_Mode then
         Coyote_Canvas.Revisions.Redo (S.Document);
         Refresh (S.all);
      end if;
   exception
      when others =>
         Set_Status (S.all, "Redo could not be applied");
   end On_Redo;

   function Pixel_Text (N : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left));

   procedure Set_Crop_Fields (S : in out Instance; R : Doc.Rectangle) is
   begin
      S.X_Field.Set_Text (Pixel_Text (R.Left));
      S.Y_Field.Set_Text (Pixel_Text (R.Top));
      S.Width_Field.Set_Text (Pixel_Text (R.Right - R.Left));
      S.Height_Field.Set_Text (Pixel_Text (R.Bottom - R.Top));
   end Set_Crop_Fields;

   procedure On_Crop
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
      Current : Coyote_Canvas.Document.Rectangle;
   begin
      if S = null then
         return;
      end if;
      Current := Coyote_Canvas.Revisions.Extent (S.Document);
      if not Coyote_Canvas.Document.Is_Nonempty (Current) then
         Set_Status (S.all, "Create a drawing before cropping");
         return;
      end if;
      if not S.Editing_Draft then
         Set_Status (S.all, "Edit a revision before cropping");
         return;
      end if;
      Cancel_Gesture (S.all);
      S.Crop_Mode := True;
      Set_Crop_Fields (S.all, Doc.EMPTY_RECTANGLE);
      S.Crop_Grid.Show;
      S.X_Field.Grab_Focus;
      Refresh (S.all);
      Set_Status (S.all, "Drag a crop region or enter exact pixel bounds");
   end On_Crop;

   procedure On_Cancel_Crop
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
   begin
      if S /= null then
         Cancel_Gesture (S.all);
         Refresh (S.all);
      end if;
   end On_Cancel_Crop;

   procedure On_Apply_Crop
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
   begin
      if S = null or else not S.Crop_Mode or else S.Crop_Drag then
         return;
      end if;
      Rev.Crop (S.Document, Pending (S.all));
      On_Cancel_Crop (Button, S);
      Set_Status (S.all, "Crop applied to draft");
   exception
      when Constraint_Error                       =>
         Set_Status (S.all, "Crop must be non-empty and within the drawing");
      when Coyote_Canvas.Revisions.Capacity_Error =>
         Set_Status (S.all, "Crop capacity reached; draft retained");
   end On_Apply_Crop;

   procedure On_Close
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class;
      S    : Instance_Access)
   is
      pragma Unreferenced (Item);
   begin
      if S /= null and then S.Canvas_Window /= null then
         Cancel_Gesture (S.all);
         Refresh (S.all);
         S.Canvas_Window.Hide;
      end if;
   end On_Close;

   procedure On_Selection
     (Selection : access Gtk.Tree_Selection.Gtk_Tree_Selection_Record'Class;
      S         : Instance_Access)
   is
      Model : TM.Gtk_Tree_Model;
      Paths : TM.Gtk_Tree_Path_List.Glist;
      Iter  : TM.Gtk_Tree_Iter;
      use TM.Gtk_Tree_Path_List;
   begin
      if S.Resetting then
         return;
      end if;
      S.Preview_Revision := 0;
      if Selection.Count_Selected_Rows = 1 then
         Selection.Get_Selected_Rows (Model, Paths);
         if Paths /= Null_List then
            Iter := TM.Get_Iter (Model, Get_Data (Paths));
            TM.Path_Free (Get_Data (Paths));
            Free (Paths);
            if Iter /= TM.Null_Iter then
               S.Preview_Revision :=
                 Rev.Revision_Id (TM.Get_Int (Model, Iter, 1));
               Cancel_Gesture (S.all);
               S.Editing_Draft := False;
               Set_Status
                 (S.all,
                  "Read-only revision" &
                  Rev.Revision_Id'Image (S.Preview_Revision));
            end if;
         end if;
      elsif not S.Editing_Draft then
         S.Editing_Draft := True;
         Set_Status (S.all, "Working copy (in memory)");
      end if;
      Refresh (S.all);
   end On_Selection;

   procedure On_Action
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class;
      S    : Instance_Access)
   is
      Name : constant String := Item.Get_Name;
   begin
      if Name = "canvas-new" then
         On_New (null, S);
      elsif Name = "canvas-save" then
         On_Save (null, S);
      elsif Name = "canvas-edit" then
         On_Edit (null, S);
      elsif Name = "canvas-undo" then
         On_Undo (null, S);
      elsif Name = "canvas-redo" then
         On_Redo (null, S);
      elsif Name = "canvas-crop" then
         On_Crop (null, S);
      elsif Name = "canvas-cancel" then
         On_Cancel_Crop (null, S);
      elsif Name = "canvas-apply" then
         On_Apply_Crop (null, S);
      elsif Name = "canvas-close" then
         On_Close (Item, S);
      elsif Name = "canvas-help" then
         Set_Status
           (S.all, "Use File > New to draw; Save checkpoints in memory.");
      else
         Cancel_Gesture (S.all);
         if Name = "canvas-draft" then
            S.Editing_Draft := True;
            Set_Status (S.all, "Working copy (in memory)");
         elsif Name = "canvas-zoom-in" then
            S.Zoom := Long_Float'Min (4.0, S.Zoom * 1.25);
         elsif Name = "canvas-zoom-out" then
            S.Zoom := Long_Float'Max (0.25, S.Zoom / 1.25);
         elsif Name = "canvas-actual" then
            S.Zoom := 1.0;
         end if;
         Refresh (S.all);
      end if;
   end On_Action;

   procedure Draw_Stroke
     (Points : Rev.Samples.Vector; Context : Cairo.Cairo_Context)
   is
      Prev  : Rev.Sample := (0.0, 0.0, 1.0);
      First : Boolean    := True;
   begin
      Cairo.Set_Source_Rgb (Context, 0.05, 0.05, 0.05);
      Cairo.Set_Line_Cap (Context, Cairo.Cairo_Line_Cap_Round);
      for Point of Points loop
         if not First then
            Cairo.Set_Line_Width
              (Context, Glib.Gdouble ((Prev.Width + Point.Width) / 2.0));
            Cairo.Move_To
              (Context, Glib.Gdouble (Prev.X), Glib.Gdouble (Prev.Y));
            Cairo.Line_To
              (Context, Glib.Gdouble (Point.X), Glib.Gdouble (Point.Y));
            Cairo.Stroke (Context);
         else
            Cairo.Arc
              (Context, Glib.Gdouble (Point.X), Glib.Gdouble (Point.Y),
               Glib.Gdouble (Point.Width / 2.0), 0.0, 6.283_185_307_179_586);
            Cairo.Fill (Context);
         end if;
         Prev  := Point;
         First := False;
      end loop;
   end Draw_Stroke;

   procedure Outline (Context : Cairo.Cairo_Context; R : Doc.Rectangle) is
   begin
      Cairo.Rectangle
        (Context, Glib.Gdouble (R.Left), Glib.Gdouble (R.Top),
         Glib.Gdouble (R.Right - R.Left), Glib.Gdouble (R.Bottom - R.Top));
   end Outline;

   function On_Draw
     (Area    : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context : Cairo.Cairo_Context; S : Instance_Access) return Boolean
   is
      pragma Unreferenced (Area);
      E        : constant Doc.Rectangle   := Display_Extent (S.all);
      Region   : constant Doc.Rectangle   := Pending (S.all);
      Revision : constant Rev.Revision_Id :=
        (if S.Editing_Draft then Rev.NO_REVISION else S.Preview_Revision);
      procedure Draw_Points (Points : Rev.Samples.Vector) is
      begin
         Draw_Stroke (Points, Context);
      end Draw_Points;
   begin
      if not Doc.Is_Nonempty (E) then
         return False;
      end if;
      Cairo.Save (Context);
      Cairo.Scale (Context, Glib.Gdouble (S.Zoom), Glib.Gdouble (S.Zoom));
      Outline (Context, Doc.Full_Extent (E.Right - E.Left, E.Bottom - E.Top));
      Cairo.Clip (Context);
      Cairo.Set_Source_Rgb (Context, 1.0, 1.0, 1.0);
      Cairo.Paint (Context);
      if S.Show_Ink then
         Cairo.Save (Context);
         Cairo.Translate
           (Context, -Glib.Gdouble (E.Left), -Glib.Gdouble (E.Top));
         Rev.Visit_Source (S.Document, Revision, Draw_Points'Access);
         Cairo.Restore (Context);
         if S.Drawing then
            Draw_Stroke (S.Stroke_Points, Context);
         end if;
      end if;
      if Doc.Is_Nonempty (Region) then
         Outline
           (Context, Doc.Full_Extent (E.Right - E.Left, E.Bottom - E.Top));
         Outline (Context, Region);
         Cairo.Set_Fill_Rule (Context, Cairo.Cairo_Fill_Rule_Even_Odd);
         Cairo.Set_Source_Rgba (Context, 0.1, 0.1, 0.1, 0.42);
         Cairo.Fill (Context);
         Outline (Context, Region);
         Cairo.Set_Line_Width (Context, Glib.Gdouble (1.0 / S.Zoom));
         Cairo.Set_Source_Rgb (Context, 0.15, 0.32, 0.70);
         Cairo.Stroke (Context);
      end if;
      Cairo.Restore (Context);
      return True;
   end On_Draw;

   --  The generated GtkAda declaration drops these GDK boolean results.
   function Read_Axis
     (Event :     Gdk.Event.Gdk_Event; Axis : Gdk.Types.Gdk_Axis_Use;
      Value : out Glib.Gdouble) return Glib.Gboolean with
     Import, Convention => C, External_Name => "gdk_event_get_axis";
   function Read_Coords
     (Event : Gdk.Event.Gdk_Event; X, Y : out Glib.Gdouble)
      return Glib.Gboolean with
     Import, Convention => C, External_Name => "gdk_event_get_coords";
   use type Glib.Gboolean;

   procedure Add_Point
     (S : in out Instance; Event : Gdk.Event.Gdk_Event; X, Y : Long_Float)
   is
      E        : constant Doc.Rectangle := Rev.Extent (S.Document);
      Pressure : Glib.Gdouble;
      Width    : Long_Float             := 3.0;
   begin
      if S.Stroke_Points.Length >= 4_096 then
         raise Rev.Capacity_Error with "Canvas gesture sample limit reached";
      end if;
      if Gdk.Event.Get_Device_Tool (Event) /= null
        and then Read_Axis (Event, Gdk.Types.Axis_Pressure, Pressure) /= 0
        and then Pressure >= 0.0 and then Pressure <= 1.0
      then
         Width := 1.0 + 7.0 * Long_Float (Pressure);
      end if;
      S.Stroke_Points.Append
        (Rev.Sample'
           (X     =>
              Long_Float'Max
                (0.0, Long_Float'Min (X, Long_Float (E.Right - E.Left))),
            Y     =>
              Long_Float'Max
                (0.0, Long_Float'Min (Y, Long_Float (E.Bottom - E.Top))),
            Width => Width));
   end Add_Point;

   procedure Drag_Crop (S : in out Instance; X, Y : Long_Float) is
      E    : constant Doc.Rectangle := Rev.Extent (S.Document);
      W    : constant Positive      := E.Right - E.Left;
      H    : constant Positive      := E.Bottom - E.Top;
      R    : constant Doc.Rectangle := S.Crop_Start;
      Next : Doc.Rectangle;
   begin
      if S.Move_Crop then
         Next :=
           Doc.Move
             (R, R.Left + Integer (X - S.Crop_X1),
              R.Top + Integer (Y - S.Crop_Y1), W, H);
      elsif S.Drag_Left or S.Drag_Right or S.Drag_Top or S.Drag_Bottom then
         Next :=
           Doc.From_Drag
             ((if S.Drag_Left then X else Long_Float (R.Left)),
              (if S.Drag_Top then Y else Long_Float (R.Top)),
              (if S.Drag_Right then X else Long_Float (R.Right)),
              (if S.Drag_Bottom then Y else Long_Float (R.Bottom)), W, H);
      else
         Next := Doc.From_Drag (S.Crop_X1, S.Crop_Y1, X, Y, W, H);
      end if;
      Set_Crop_Fields (S, Next);
   end Drag_Crop;

   function On_Press
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean
   is
      X, Y : Glib.Gdouble;
   begin
      if not S.Has_Drawing or else not S.Editing_Draft or else not S.Show_Ink
        or else S.Drawing or else S.Crop_Drag
        or else Gdk.Event.Get_Pointer_Emulated (Event)
        or else Gdk.Event.Get_Event_Type (Event) /= Gdk.Event.Button_Press
        or else Gdk.Event.Get_Button (Event) /= 1
        or else Read_Coords (Event, X, Y) = 0
      then
         return False;
      end if;
      Widget.Grab_Focus;
      if S.Crop_Mode then
         Begin_Crop_Drag :
         declare
            PX       : constant Long_Float    := Long_Float (X) / S.Zoom;
            PY       : constant Long_Float    := Long_Float (Y) / S.Zoom;
            R        : constant Doc.Rectangle := Pending (S.all);
            Hit      : constant Long_Float    := 5.0 / S.Zoom;
            Near_X   : constant Boolean       :=
              PX >= Long_Float (R.Left) - Hit and
              PX <= Long_Float (R.Right) + Hit;
            Near_Y   : constant Boolean       :=
              PY >= Long_Float (R.Top) - Hit and
              PY <= Long_Float (R.Bottom) + Hit;
            Existing : constant Boolean       := Doc.Is_Nonempty (R);
         begin
            S.Crop_Drag   := True;
            S.Crop_X1     := PX;
            S.Crop_Y1     := PY;
            S.Crop_Start  := R;
            S.Drag_Left   :=
              Existing and Near_Y and abs (PX - Long_Float (R.Left)) <= Hit;
            S.Drag_Right  :=
              Existing and Near_Y and not S.Drag_Left and
              abs (PX - Long_Float (R.Right)) <= Hit;
            S.Drag_Top    :=
              Existing and Near_X and abs (PY - Long_Float (R.Top)) <= Hit;
            S.Drag_Bottom :=
              Existing and Near_X and not S.Drag_Top and
              abs (PY - Long_Float (R.Bottom)) <= Hit;
            S.Move_Crop   :=
              Existing and Near_X and Near_Y and
              not (S.Drag_Left or S.Drag_Right or S.Drag_Top or S.Drag_Bottom);
         end Begin_Crop_Drag;
      else
         Add_Point
           (S.all, Event, Long_Float (X) / S.Zoom, Long_Float (Y) / S.Zoom);
         S.Drawing := True;
      end if;
      Refresh (S.all);
      return True;
   end On_Press;

   function On_Motion
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean
   is
      pragma Unreferenced (Widget);
      X, Y : Glib.Gdouble;
   begin
      if not (S.Crop_Drag or else S.Drawing)
        or else Gdk.Event.Get_Pointer_Emulated (Event)
        or else Read_Coords (Event, X, Y) = 0
      then
         return False;
      end if;
      if S.Crop_Drag then
         Drag_Crop (S.all, Long_Float (X) / S.Zoom, Long_Float (Y) / S.Zoom);
      else
         Add_Point
           (S.all, Event, Long_Float (X) / S.Zoom, Long_Float (Y) / S.Zoom);
      end if;
      Refresh (S.all);
      return True;
   exception
      when Rev.Capacity_Error =>
         Cancel_Gesture (S.all);
         Set_Status (S.all, "Canvas sample limit reached; stroke discarded");
         Refresh (S.all);
         return True;
   end On_Motion;

   function On_Release
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean
   is
      pragma Unreferenced (Widget);
      X, Y : Glib.Gdouble;
   begin
      if Gdk.Event.Get_Button (Event) /= 1
        or else Gdk.Event.Get_Pointer_Emulated (Event)
        or else not (S.Drawing or else S.Crop_Drag)
      then
         return False;
      end if;
      if S.Drawing then
         Rev.Add_Stroke (S.Document, S.Stroke_Points);
      elsif Read_Coords (Event, X, Y) /= 0 then
         Drag_Crop (S.all, Long_Float (X) / S.Zoom, Long_Float (Y) / S.Zoom);
      end if;
      S.Drawing := False;
      S.Stroke_Points.Clear;
      S.Crop_Drag := False;
      Refresh (S.all);
      return True;
   exception
      when Rev.Capacity_Error =>
         Cancel_Gesture (S.all);
         Set_Status (S.all, "Canvas capacity reached; stroke discarded");
         Refresh (S.all);
         return True;
   end On_Release;

   function On_Cancel_Event
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean
   is
      pragma Unreferenced (Widget);
      Is_Key : constant Boolean :=
        Gdk.Event.Get_Event_Type (Event) = Gdk.Event.Key_Press;
   begin
      if (S.Crop_Drag or else S.Drawing or else (Is_Key and then S.Crop_Mode))
        and then
        (not Is_Key
         or else Gdk.Event.Get_Key_Val (Event) = Gdk.Types.Keysyms.GDK_Escape)
      then
         Cancel_Gesture (S.all);
         Refresh (S.all);
         return Is_Key;
      end if;
      return False;
   end On_Cancel_Event;

   function On_Delete
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean
   is
      pragma Unreferenced (Widget, Event);
   begin
      On_Close (null, S);
      return True;
   end On_Delete;
end Coyote_GUI.Canvas;
