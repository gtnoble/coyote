with Ada.Streams;
with Ada.Real_Time;
with Ada.Strings.Unbounded.Aux;
with Coyote_Canvas.Images;
with Coyote_Canvas.Ink;
with Interfaces.C;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Coyote_Canvas.Rasters;
with Coyote_GUI.Canvas_Import_Jobs;
with Gdk.Property;
with Gdk.Cursor;
with Gdk.Window;
with Coyote_Help;
with Glib.Object;
with Glib.Values;
with Gtk.Clipboard;
with Gtk.Dialog;
with Gtk.File_Chooser;
with Gtk.Selection_Data;
with System;
with Ada.Containers;
with Gdk.Device_Tool;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Gtk.Accel_Group;
with Gtk.Adjustment;
with Gtk.Check_Menu_Item;
with Gtk.Color_Button;
with Gdk.Event;
with Glib;
with Gtk.Cell_Renderer_Text;
with Gtk.Enums;
with Gtk.Handlers;
with Gtk.Menu;
with Gtk.Menu_Bar;
with Gtk.Scrolled_Window;
with Gtk.Style_Context;
with Gtk.Css_Provider;
with Gtk.Style_Provider;
with Gdk.RGBA;
with Gtk.Tree_Selection;
with Gtk.Tree_View_Column;
with Gtk.Widget;

with Coyote_Canvas.Revisions.Recovery;
with LLM.User_Images;

package body Coyote_GUI.Canvas is
   use type Ada.Containers.Count_Type;
   package Doc renames Coyote_Canvas.Document;
   package Rev renames Coyote_Canvas.Revisions;
   package TM renames Gtk.Tree_Model;
   package Raster renames Coyote_Canvas.Rasters;
   package Jobs renames Coyote_GUI.Canvas_Import_Jobs;
   package Recovery_Jobs renames Coyote_GUI.Canvas_Recovery_Jobs;
   package Persistence renames Recovery_Jobs.Store;
   package Service renames Coyote_Canvas.Import_Service;
   use type Service.Binding_Access;
   use Ada.Strings.Unbounded;
   use type Ada.Real_Time.Time;
   use type Recovery_Jobs.Job_Access;
   use type Glib.Main.G_Source_Id;
   use type Persistence.Result;
   use type Cairo.Cairo_Surface;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Gdk.Gdk_Cursor;
   use type Gdk.Gdk_Window;
   use type Gdk.Types.Gdk_Atom;
   use type Gtk.Dialog.Gtk_Response_Type;
   use type Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
   use type Gtk.Message_Dialog.Gtk_Message_Dialog;
   use type Gtk.Widget.Gtk_Widget;
   use type Raster.Format;
   use type System.Address;
   use type Gdk.Event.Gdk_Event_Mask;
   use type Gdk.Event.Gdk_Event_Type;
   use type Gdk.Event.Gdk_Event_Sequence;
   use type Gdk.Device_Tool.Gdk_Device_Tool;
   use type Gdk.Device_Tool.Gdk_Device_Tool_Type;
   use type Rev.Ink_Operation;
   use type Rev.Ink_Color;
   use type Gtk.Color_Button.Gtk_Color_Button;
   use type Gtk.Spin_Button.Gtk_Spin_Button;
   use type Gtk.Radio_Button.Gtk_Radio_Button;
   use type Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
   DEFAULT_BRUSH_SIZE : constant array (Ink_Tool) of Glib.Gdouble :=
     (Pencil => 3.0, Eraser => 16.0);
   use type Gdk.Types.Gdk_Key_Type;
   use type Gdk.Types.Gdk_Modifier_Type;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Drawing_Area.Gtk_Drawing_Area;
   use type Gtk.Tree_Model.Gtk_Tree_Path;
   use type Gtk.Tree_Model.Gtk_Tree_Path_List.Glist;
   use type Gtk.Accel_Group.Gtk_Accel_Group;
   use type Gtk.Tree_Model.Gtk_Tree_Iter;
   use type Gtk.Tree_Store.Gtk_Tree_Store;
   use type Gtk.Tree_View.Gtk_Tree_View;
   use type Gtk.Window.Gtk_Window;
   use type Glib.Gint;
   use type Glib.Gdouble;
   use type Glib.Guint;

   type Instance_Access is access all Instance;

   --  Each outstanding C callback owns a slot until its last notification.
   --  Invalidation detaches the owner, never reuses a still-borrowed slot.
   --  Bounds apply even if an external clipboard owner does not respond.
   type Import_Request is record
      Busy     : Boolean := False;
      Owner    : Instance_Access;
      Origin   : Image_Origin := Blank;
      Expected : Raster.Format := Raster.Unknown;
   end record;
   subtype Request_Index is Natural range 0 .. 4;
   Requests : array (Request_Index range 1 .. 4) of aliased Import_Request;
   MAX_IMAGE_BYTES : constant := 128 * 1_024 * 1_024;

   procedure Invalidate
     (S : Instance; Paste_Only : Boolean := False; Keep_Agent : Boolean := False) is
   begin
      for R of Requests loop
         if R.Owner /= null and then R.Owner.all'Address = S'Address
           and then (not Paste_Only or else R.Origin = Clipboard_Image)
           and then (not Keep_Agent or else R.Origin /= Agent_Image)
         then
            if R.Origin = File_Image then
               Jobs.Cancel_Files (R'Address);
            end if;
            R.Owner := null;
         end if;
      end loop;
   end Invalidate;

   function Acquire (S : Instance_Access; Origin : Image_Origin)
      return Request_Index is
   begin
      for I in Requests'Range loop
         if not Requests (I).Busy then
            Requests (I) := (Busy => True, Owner => S, Origin => Origin,
                             Expected => Raster.Unknown);
            return I;
         end if;
      end loop;
      return 0;
   end Acquire;

   function Find_Request (Token : System.Address) return Request_Index is
   begin
      for I in Requests'Range loop
         if Requests (I)'Address = Token and then Requests (I).Busy then
            return I;
         end if;
      end loop;
      return 0;
   end Find_Request;

   package Draw_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Drawing_Area.Gtk_Drawing_Area_Record, Boolean, Instance_Access);
   package Draw_Context_Marshaller is new Draw_Callback.Marshallers
     .Generic_Marshaller
     (Cairo.Cairo_Context, Cairo.Get_Context);
   package Icon_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Drawing_Area.Gtk_Drawing_Area_Record, Boolean, Tool_Kind);
   package Icon_Marshaller is new Icon_Callback.Marshallers.Generic_Marshaller
     (Cairo.Cairo_Context, Cairo.Get_Context);
   package Event_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Widget.Gtk_Widget_Record, Boolean, Instance_Access);
   package Event_Marshaller is new Event_Callback.Marshallers
     .Generic_Marshaller
     (Gdk.Event.Gdk_Event, Gdk.Event.Get_Event);
   package Toolbar_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Box.Gtk_Box_Record, Boolean, Instance_Access);
   package Selection_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Tree_Selection.Gtk_Tree_Selection_Record, Instance_Access);
   package Viewport_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record, Instance_Access);
   package Button_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Button.Gtk_Button_Record, Instance_Access);
   package Window_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Window.Gtk_Window_Record, Instance_Access);
   package Tool_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Radio_Button.Gtk_Radio_Button_Record, Instance_Access);
   package Entry_Callback is new Gtk.Handlers.User_Callback
     (Gtk.GEntry.Gtk_Entry_Record, Instance_Access);
   package Check_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record, Instance_Access);
   package Color_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Color_Button.Gtk_Color_Button_Record, Instance_Access);
   package Menu_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Menu_Item.Gtk_Menu_Item_Record, Instance_Access);

   function On_Draw
     (Area    : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context : Cairo.Cairo_Context; S : Instance_Access) return Boolean;
   function On_Touch
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean;
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
   procedure On_Undo
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Redo
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure Select_Tool
     (S : in out Instance; Tool : Tool_Kind; Focus_Fields : Boolean);
   procedure On_Cancel_Crop
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Apply_Crop
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access);
   procedure On_Close
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class;
      S    : Instance_Access);
   procedure On_Pencil_Color_Set
     (Button : access Gtk.Color_Button.Gtk_Color_Button_Record'Class;
      S      : Instance_Access);

   procedure Set_Status (S : in out Instance; Text : String) is
   begin
      if S.Status /= null then
         S.Status.Set_Text (Text);
      end if;
   end Set_Status;

   function Can_Edit (S : Instance) return Boolean is
     (not S.Suspended and then S.Import_Count = 0 and then
        (Length (S.Parent) = 0 or else S.Writable));

   function Cropping (S : Instance) return Boolean is (S.Tool = Crop);

   function Can_Draw (S : Instance) return Boolean is
     (Can_Edit (S) and then S.Show_Ink and then
        (if S.Editing_Draft then S.Has_Drawing
         else S.Preview_Revision /= Rev.NO_REVISION));

   function Can_Select_Tool (S : Instance) return Boolean is
     (Can_Draw (S) and then not (S.Drawing or else S.Crop_Drag));

   function Can_Edit_With_Finger (S : Instance) return Boolean is
     (S.Edit_With_Finger and then S.Tool in Ink_Tool
      and then S.Zoom_Tool = No_Zoom and then Can_Draw (S));

   procedure Storage_Status (S : Instance; Text : String) is
   begin
      if S.Storage_Label /= null then
         S.Storage_Label.Set_Text (Text);
      end if;
   end Storage_Status;

   function Display_Extent (S : Instance) return Doc.Rectangle is
     (Rev.Extent
        (S.Document,
         (if S.Editing_Draft then Rev.NO_REVISION else S.Preview_Revision)));

   function Can_Zoom (S : Instance; E : Doc.Rectangle) return Boolean is
     (Doc.Is_Nonempty (E) and then not (S.Drawing or else S.Crop_Drag));

   function Active_Tool (S : Instance) return Tool_Kind is
     (case S.Zoom_Tool is when No_Zoom => S.Tool,
                         when Magnify => Zoom_In, when Reduce => Zoom_Out);

   procedure Update_Zoom_Cursor (S : Instance) is
      Cursor : Gdk.Gdk_Cursor := null;
   begin
      if S.Drawing_Area = null or else S.Drawing_Area.Get_Window = null then
         return;
      end if;
      if S.Zoom_Tool /= No_Zoom and then not S.Help_Mode then
         Cursor := Gdk.Cursor.Gdk_Cursor_New_From_Name
           (S.Drawing_Area.Get_Display,
            (if S.Zoom_Tool = Magnify then "zoom-in" else "zoom-out"));
         if Cursor = null then
            Cursor := Gdk.Cursor.Gdk_Cursor_New_For_Display
              (S.Drawing_Area.Get_Display, Gdk.Cursor.Crosshair);
         end if;
      end if;
      Gdk.Window.Set_Cursor (S.Drawing_Area.Get_Window, Cursor);
      if Cursor /= null then
         Gdk.Cursor.Unref (Cursor);
      end if;
   end Update_Zoom_Cursor;

   procedure Leave_Zoom_Tool (S : in out Instance) is
   begin
      if S.Zoom_Tool /= No_Zoom then
         S.Zoom_Tool := No_Zoom;
         Update_Zoom_Cursor (S);
      end if;
   end Leave_Zoom_Tool;

   function Pending (S : Instance) return Doc.Rectangle is
      E : constant Doc.Rectangle := Display_Extent (S);
   begin
      if not Cropping (S) or else not Doc.Is_Nonempty (E) then
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

   function Has_Drawing_Focus (S : Instance) return Boolean is
      Focus : constant Gtk.Widget.Gtk_Widget := S.Canvas_Window.Get_Focus;
   begin
      return Focus = Gtk.Widget.Gtk_Widget (S.Drawing_Area)
        or else (Focus = Gtk.Widget.Gtk_Widget (S.Attach_Button)
                 and then S.Attach_From_Drawing);
   end Has_Drawing_Focus;

   function Can_Attach (S : Instance) return Boolean is
     (S.Drawing_Tree /= null and then Can_Edit (S) and then S.Show_Ink
      and then not (Cropping (S) or else S.Drawing)
      and then S.On_Attach /= null
      and then ((S.Editing_Draft and then S.Has_Drawing)
        or else S.Drawing_Tree.Get_Selection.Count_Selected_Rows > 0));

   procedure Refresh (S : in out Instance) is
      E          : constant Doc.Rectangle := Display_Extent (S);
      Editing    : constant Boolean       :=
        Can_Edit (S) and then S.Has_Drawing and then S.Editing_Draft
        and then not (Cropping (S) or else S.Drawing);
      Tools_Enabled : constant Boolean := Can_Select_Tool (S);
      Zoom_Enabled  : constant Boolean := Can_Zoom (S, E);
      Attach_Enabled : constant Boolean := Can_Attach (S);
      Valid_Crop : constant Boolean       :=
        Can_Draw (S) and then not S.Crop_Drag
        and then Doc.Is_Nonempty (Pending (S));
   begin
      if S.Drawing_Area = null then
         return;
      end if;
      S.Save_Item.Set_Sensitive
        (Can_Edit (S) and then not Cropping (S) and then not S.Drawing
         and then ((Editing and then Rev.Changed (S.Document))
                   or else S.Save_Failed));
      S.Attach_Item.Set_Sensitive (Attach_Enabled);
      S.Attach_Button.Set_Sensitive (Attach_Enabled);
      S.New_Item.Set_Sensitive (Can_Edit (S));
      S.Import_Item.Set_Sensitive (Can_Edit (S));
      S.Paste_Item.Set_Sensitive (Can_Edit (S));
      S.Draft_Item.Set_Sensitive (S.Has_Drawing and not S.Editing_Draft);
      --  GTK's scroller can capture a touch before it reaches the canvas.
      S.Viewport.Set_Kinetic_Scrolling (not Can_Edit_With_Finger (S));
      S.Fit_Item.Set_Sensitive (Zoom_Enabled);
      S.Zoom_In_Item.Set_Sensitive (Zoom_Enabled);
      S.Zoom_Out_Item.Set_Sensitive (Zoom_Enabled);
      S.Actual_Item.Set_Sensitive (Zoom_Enabled);
      --  Reflect state without re-entering a tool selection callback.
      S.Syncing_Tools := True;
      S.Buttons (Active_Tool (S)).Set_Active (True);
      S.Tool_Menu (S.Tool).Set_Active (True);
      S.Syncing_Tools := False;
      for Tool in Editing_Tool loop
         S.Buttons (Tool).Set_Sensitive (Tools_Enabled);
         S.Tool_Menu (Tool).Set_Sensitive (Tools_Enabled);
      end loop;
      S.Pencil_Color.Set_Sensitive
        (Tools_Enabled and then not Cropping (S));
      for Control of S.Brush_Size loop
         Control.Set_Sensitive (Tools_Enabled and then not Cropping (S));
      end loop;
      S.Buttons (Zoom_In).Set_Sensitive (Zoom_Enabled);
      S.Buttons (Zoom_Out).Set_Sensitive (Zoom_Enabled);
      S.Tool_Label.Set_Text
        (if S.Zoom_Tool = Magnify then "Tool: Zoom In"
         elsif S.Zoom_Tool = Reduce then "Tool: Zoom Out"
         elsif S.Drawing and then S.Gesture_Operation = Rev.Erase then
            "Tool: Eraser"
         elsif Cropping (S) then "Tool: Crop"
         elsif S.Tool = Eraser then "Tool: Eraser"
         else "Tool: Pencil");
      S.Undo_Item.Set_Sensitive (Editing and then Rev.Can_Undo (S.Document));
      S.Redo_Item.Set_Sensitive (Editing and then Rev.Can_Redo (S.Document));
      S.Apply_Crop.Set_Sensitive (Valid_Crop);
      S.Apply_Item.Set_Sensitive (Valid_Crop);
      S.Cancel_Item.Set_Sensitive (Cropping (S));
      S.Drawing_Area.Set_Size_Request
        (Glib.Gint (Long_Float'Ceiling
           (Long_Float (E.Right - E.Left) * S.Zoom)),
         Glib.Gint (Long_Float'Ceiling
           (Long_Float (E.Bottom - E.Top) * S.Zoom)));
      S.Drawing_Area.Queue_Draw;
   end Refresh;

   procedure Fit_View (S : in out Instance) is
      E : constant Doc.Rectangle := Display_Extent (S);
   begin
      if Can_Zoom (S, E) then
         S.Anchor_Pending := False;
         --  Fit to the unframed allocation, not the page size reduced by
         --  the scrollbars this change will remove.
         declare
            Width  : constant Long_Float :=
              Long_Float (S.Viewport.Get_Allocated_Width);
            Height : constant Long_Float :=
              Long_Float (S.Viewport.Get_Allocated_Height);
            Image_Width  : constant Long_Float :=
              Long_Float (E.Right - E.Left);
            Image_Height : constant Long_Float :=
              Long_Float (E.Bottom - E.Top);
            Fit_Scale : Long_Float := Long_Float'Min
              (4.0,
               Long_Float'Min (Width / Image_Width, Height / Image_Height));
         begin
            --  Avoid a spurious scrollbar if floating-point rounding would
            --  make the size request one pixel larger than the viewport.
            if Image_Width * Fit_Scale > Width or else
              Image_Height * Fit_Scale > Height
            then
               Fit_Scale := Long_Float'Adjacent (Fit_Scale, 0.0);
            end if;
            S.Zoom := Fit_Scale;
         end;
         Refresh (S);
      end if;
   end Fit_View;

   procedure Apply_Zoom_Anchor
     (Scroll : access Gtk.Scrolled_Window.Gtk_Scrolled_Window_Record'Class;
      Params : Glib.Values.GValues; S : Instance_Access)
   is
      pragma Unreferenced (Params);
   begin
      if S.Anchor_Pending then
         --  GtkViewport has now recalculated the two scroll ranges.
         S.Anchor_Pending := False;
         Scroll.Get_Hadjustment.Set_Value (S.Anchor_X);
         Scroll.Get_Vadjustment.Set_Value (S.Anchor_Y);
      end if;
   end Apply_Zoom_Anchor;

   function Step_Zoom (Scale : Long_Float; Increase : Boolean)
     return Long_Float is
     (if Increase then Long_Float'Min (4.0, Scale * 1.25)
      --  Fit can go below the manual floor; Zoom Out never enlarges.
      else Long_Float'Min (Scale, Long_Float'Max (0.25, Scale / 1.25)));

   procedure Zoom_At
     (S : in out Instance; X, Y : Glib.Gdouble; Increase : Boolean)
   is
      Target : constant Long_Float := Step_Zoom (S.Zoom, Increase);
   begin
      if Target /= S.Zoom then
         --  Events before the next allocation still use the old geometry.
         if not S.Anchor_Pending then
            S.Anchor_Scale := S.Zoom;
         end if;
         declare
            Step : constant Glib.Gdouble :=
              Glib.Gdouble (Target / S.Anchor_Scale - 1.0);
         begin
            S.Anchor_X := S.Viewport.Get_Hadjustment.Get_Value + X * Step;
            S.Anchor_Y := S.Viewport.Get_Vadjustment.Get_Value + Y * Step;
         end;
         S.Anchor_Pending := True;
         S.Zoom := Target;
         Refresh (S);
         S.Viewport.Queue_Allocate;
      end if;
   end Zoom_At;

   procedure Zoom_Over_Drawing
     (S : in out Instance; X, Y : Glib.Gdouble; Increase : Boolean)
   is
      E : constant Doc.Rectangle := Display_Extent (S);
      Input_Scale : constant Long_Float :=
        (if S.Anchor_Pending then S.Anchor_Scale else S.Zoom);
   begin
      if Can_Zoom (S, E) and then X >= 0.0 and then Y >= 0.0
        and then Long_Float (X) / Input_Scale < Long_Float (E.Right - E.Left)
        and then Long_Float (Y) / Input_Scale < Long_Float (E.Bottom - E.Top)
      then
         Zoom_At (S, X, Y, Increase);
      end if;
   end Zoom_Over_Drawing;

   procedure Cancel_Gesture
     (S : in out Instance; Keep_Zoom : Boolean := False)
   is
   begin
      if not Keep_Zoom then
         Leave_Zoom_Tool (S);
         S.Anchor_Pending := False;
      end if;
      S.Drawing := False;
      S.Finger_Sequence := null;
      S.Stroke_Points.Clear;
      Coyote_Canvas.Composite.Clear (S.Live_Erase);
      S.Erase_Preview_Failed := False;
      S.Crop_Drag := False;
      if Cropping (S) then
         S.Tool := S.Previous_Ink_Tool;
      end if;
      S.Crop_Grid.Hide;
   end Cancel_Gesture;

   procedure Extend_Tree (S : in out Instance) is
   begin
      if S.Store = null then
         return;
      end if;
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
               (if Ancestor /= 0 then "Revision" & Natural'Image (Id)
                elsif Rev.Original_Label (S.Document, Id) /= "" then
                  Rev.Original_Label (S.Document, Id) & " (Original)"
                else (case S.Images (Id).Origin is
                      when Clipboard_Image => "Clipboard Image",
                      when File_Image | Agent_Image => "Imported Image",
                      when Blank => "Blank Drawing") & Natural'Image (Id)
                  & " (Original)"));
            S.Store.Set (S.Rows (Id), 1, Glib.Gint (Id));
            Path := S.Store.Get_Path (S.Rows (Id));
            S.Drawing_Tree.Expand_To_Path (Path);
            TM.Path_Free (Path);
            S.Listed := Id;
         end Add_Row;
      end loop;
   end Extend_Tree;

   procedure Destroy_Import_Dialogs (S : in out Instance) is
   begin
      if S.File_Selection /= null then
         S.File_Selection.Destroy;
         S.File_Selection := null;
      end if;
      if S.Import_Error /= null then
         S.Import_Error.Destroy;
         S.Import_Error := null;
      end if;
   end Destroy_Import_Dialogs;

   package Dialog_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Dialog.Gtk_Dialog_Record, Instance_Access);

   procedure Dismiss_Error
     (Dialog : access Gtk.Dialog.Gtk_Dialog_Record'Class;
      Response : Glib.Gint; S : Instance_Access)
   is
      pragma Unreferenced (Response);
   begin
      S.Import_Error := null;
      Dialog.Destroy;
   end Dismiss_Error;

   procedure Report_Import_Error (S : Instance_Access; Text : String) is
   begin
      if S.Import_Error /= null then
         S.Import_Error.Destroy;
      end if;
      Gtk.Message_Dialog.Gtk_New
        (S.Import_Error, S.Canvas_Window, Gtk.Dialog.Destroy_With_Parent,
         Gtk.Message_Dialog.Message_Error, Gtk.Message_Dialog.Buttons_Close, Text);
      S.Import_Error.Set_Title ("coyote : Image Import");
      S.Import_Error.Set_Name ("coyote-canvas-import-error");
      Dialog_Callback.Connect
        (S.Import_Error, "response",
         Dialog_Callback.To_Marshaller (Dismiss_Error'Access), S);
      S.Import_Error.Show;
   end Report_Import_Error;

   function Read_Pixels (Pixbuf : System.Address) return System.Address
     with Import, Convention => C, External_Name => "gdk_pixbuf_get_pixels";

   procedure Pack
     (Src : System.Address; Stride : Interfaces.C.size_t;
      Channels : Interfaces.C.int; W, H : Interfaces.C.size_t;
      Dest : System.Address)
     with Import, Convention => C, External_Name => "coyote_canvas_pack_rgba";

   function Packed (P : Gdk.Pixbuf.Gdk_Pixbuf) return Unbounded_String is
      use Interfaces.C;
      W : constant Positive := Positive (Gdk.Pixbuf.Get_Width (P));
      H : constant Positive := Positive (Gdk.Pixbuf.Get_Height (P));
      N : constant Positive := Coyote_Canvas.Images.Packed_Byte_Count (W, H);
      Result : Unbounded_String;
      procedure Fill (Pixels : out String) is
      begin
         Pack (Read_Pixels (P.Get_Object),
               size_t (Gdk.Pixbuf.Get_Rowstride (P)),
               int (Gdk.Pixbuf.Get_N_Channels (P)), size_t (W), size_t (H),
               Pixels (Pixels'First)'Address);
      end Fill;
   begin
      Ada.Strings.Unbounded.Aux.Set_String (Result, N, Fill'Access);
      return Result;
   end Packed;

   procedure Mark_Dirty (S : aliased in out Instance);

   procedure Agent_Result
     (S : in out Instance; Status : Service.Result; Text : String) is
   begin
      Service.Finish (S.Service, Status, Text);
      S.Background_Status := To_Unbounded_String
        ((case Status is
          when Service.Ok => "Agent images added to Drawings at native size.",
          when Service.Unknown => "Canvas import durability is uncertain.",
          when Service.Rejected => "Agent image import rejected: " & Text));
      Set_Status (S, To_String (S.Background_Status));
   end Agent_Result;

   procedure Import_Agent
     (S : Instance_Access; Pixels : Jobs.Image_List; Error : String)
   is
      Candidate : Rev.Workspace;
      Assets : Recovery_Jobs.Disk.Raster_Set;
      Sizes : Rev.Image_Sizes (Pixels'Range);
      First : Rev.Revision_Id;
      Remaining : Natural := MAX_IMAGE_BYTES - S.Image_Bytes;
      Reply : Unbounded_String;
   begin
      if not Can_Edit (S.all) or else S.Job /= null or else S.Drawing
        or else Cropping (S.all)
      then
         Agent_Result (S.all, Service.Rejected, "Canvas is busy or read-only");
         return;
      elsif Pixels'Length = 0 then
         Agent_Result (S.all, Service.Rejected, Error);
         return;
      end if;
      for I in Pixels'Range loop
         Sizes (I) := (Positive (Gdk.Pixbuf.Get_Width (Pixels (I))),
                       Positive (Gdk.Pixbuf.Get_Height (Pixels (I))));
         if Sizes (I).Height > Remaining / (Sizes (I).Width * 4) then
            Agent_Result (S.all, Service.Rejected, "Canvas raster limit reached");
            return;
         end if;
         Remaining := Remaining - Sizes (I).Height * Sizes (I).Width * 4;
      end loop;
      Rev.Recovery.Copy (Candidate, S.Document);
      Assets := S.Disk_Pixels;
      Rev.Add_Originals (Candidate, Sizes, First);
      for I in Pixels'Range loop
         declare
            J : constant Positive := I - Pixels'First + 1;
            Id : constant Rev.Revision_Id := First + J - 1;
            Label : constant String := To_String (S.Import_Labels (J));
         begin
            Rev.Set_Original_Label (Candidate, Id, Label);
            Assets (Id) := Packed (Pixels (I));
            Append (Reply, Label & ASCII.HT & Rev.Drawing_Key (Candidate, Id) &
                    ASCII.HT & Rev.Revision_Key (Candidate, Id) & ASCII.LF);
         end;
      end loop;
      S.Import_Bytes := MAX_IMAGE_BYTES - Remaining;
      if Length (S.Parent) = 0 then
         S.Disk_Pixels := Assets;
         Rev.Recovery.Adopt_Added_Originals (S.Document, Candidate);
         S.Image_Bytes := S.Import_Bytes;
         Agent_Result (S.all, Service.Ok, To_String (Reply));
         Extend_Tree (S.all);
         Refresh (S.all);
      else
         S.Import_Reply := Reply;
         Recovery_Jobs.Start
           (S.Job, Recovery_Jobs.Save_Store, To_String (S.Parent),
            To_String (S.UUID), Candidate, Assets, To_String (S.Session_File));
         S.Import_Count := Pixels'Length;
         Refresh (S.all);
      end if;
   exception
      when Rev.Capacity_Error =>
         Agent_Result (S.all, Service.Rejected, "Canvas revision limit reached");
      when others =>
         if S.Import_Count = 0 then
            Agent_Result (S.all, Service.Rejected, "Cannot prepare Canvas batch");
         end if;
   end Import_Agent;

   procedure Import_Complete
     (Token : System.Address; Pixels : Jobs.Image_List; Error : String)
   is
      I : constant Request_Index := Find_Request (Token);
      S : Instance_Access;
      Origin : Image_Origin;
      Sizes : Rev.Image_Sizes (Pixels'Range);
      First : Rev.Revision_Id;
      Remaining : Natural;
      Raster_Data : array (Pixels'Range) of Unbounded_String;
   begin
      if I = 0 then
         return;
      end if;
      S := Requests (I).Owner;
      Origin := Requests (I).Origin;
      Requests (I) := (others => <>);
      if S = null then
         return;
      elsif Origin = Agent_Image then
         Import_Agent (S, Pixels, Error);
         return;
      elsif not Can_Edit (S.all) then
         return;
      elsif Pixels'Length = 0 then
         Report_Import_Error (S, Error);
         return;
      end if;
      Remaining := MAX_IMAGE_BYTES - S.Image_Bytes;
      for J in Pixels'Range loop
         declare
            Image : constant Gdk.Pixbuf.Gdk_Pixbuf := Pixels (J);
            Width : constant Positive := Positive (Gdk.Pixbuf.Get_Width (Image));
            Height : constant Positive := Positive (Gdk.Pixbuf.Get_Height (Image));
            Stride : Positive := Positive (Gdk.Pixbuf.Get_Rowstride (Image));
         begin
            if Length (S.Parent) /= 0 then
               Stride := Width * 4;
            end if;
            if Height > Remaining / Stride then
               Report_Import_Error (S, "Canvas image memory limit reached.");
               return;
            end if;
            Remaining := Remaining - Height * Stride;
            Sizes (J) := (Width, Height);
            if Length (S.Parent) /= 0 then
               Raster_Data (J) := Packed (Image);
            end if;
         end;
      end loop;
      Rev.Add_Originals (S.Document, Sizes, First);
      for J in Pixels'Range loop
         declare
            Id : constant Rev.Revision_Id := First + (J - Pixels'First);
         begin
            S.Images (Id).Origin := Origin;
            if Length (S.Parent) = 0 then
               Pixels (J).Ref;
               S.Images (Id).Pixels := Pixels (J);
            else
               S.Disk_Pixels (Id) := Raster_Data (J);
            end if;
         end;
      end loop;
      S.Image_Bytes := MAX_IMAGE_BYTES - Remaining;
      Mark_Dirty (S.all);
      Extend_Tree (S.all);
      Refresh (S.all);
      Set_Status
        (S.all, (if Pixels'Length = 1 then "Image added to Drawings at its original size."
                 else "Images added to Drawings at their original sizes."));
   exception
      when Rev.Capacity_Error =>
         Report_Import_Error (S, "Canvas revision limit reached.");
      when Storage_Error =>
         Report_Import_Error (S, "Not enough memory for the Canvas import.");
   end Import_Complete;

   procedure Import_Failed (Token : System.Address; Error : String) is
   begin
      Import_Complete (Token, (1 .. 0 => null), Error);
   end Import_Failed;

   --  GtkAda's Request_Contents binding omits per-request user data.
   --  The native form lets the callback carry the leased slot instead of a
   --  frontend address that could outlive its session or window.
   type Clipboard_Callback is access procedure
     (Clipboard, Data, Token : System.Address) with Convention => C;
   procedure Request_Contents
     (Clipboard : System.Address;
      Target : Gdk.Types.Gdk_Atom;
      Callback : not null Clipboard_Callback;
      Token : System.Address)
     with Import, Convention => C,
          External_Name => "gtk_clipboard_request_contents";

   function Atom (Name : String) return Gdk.Types.Gdk_Atom is
     (Gdk.Property.Atom_Intern (Name, Only_If_Exists => False));

   procedure Clipboard_Data (Clipboard, Data, Token : System.Address)
     with Convention => C;
   procedure Clipboard_Targets (Clipboard, Data, Token : System.Address)
     with Convention => C;

   procedure Clipboard_Data (Clipboard, Data, Token : System.Address) is
      pragma Unreferenced (Clipboard);
      use Gtk.Selection_Data;
      use Ada.Strings.Unbounded;
      I : constant Request_Index := Find_Request (Token);
   begin
      if I = 0 then
         return;
      elsif Requests (I).Owner = null then
         Requests (I) := (others => <>);
         return;
      end if;
      declare
         Selection : constant Gtk_Selection_Data := From_Object (Data);
         Size : constant Glib.Gint := Get_Length (Selection);
         Expected : constant Raster.Format := Requests (I).Expected;
         Target : constant Gdk.Types.Gdk_Atom :=
           Atom ((if Expected = Raster.PNG then "image/png" else "image/jpeg"));
         Address : constant System.Address := Get_Data (Selection);
      begin
         if Size < 3 or else Size > Raster.MAX_ENCODED_BYTES
           or else Get_Format (Selection) /= 8
           or else Get_Data_Type (Selection) /= Target
           or else Get_Target (Selection) /= Target
           or else Address = System.Null_Address
         then
            Import_Failed (Token,
                             "Clipboard image is invalid or exceeds 8 MiB.");
            return;
         end if;
         declare
            Bytes : String (1 .. Natural (Size)) with Import, Address => Address;
            Copy : Unbounded_String;
            Accepted : Boolean;
         begin
            if Raster.Detect (Bytes) /= Expected then
               Import_Failed (Token,
                                "Clipboard data does not match its image type.");
               return;
            end if;
            Copy := To_Unbounded_String (Bytes);
            Jobs.Submit_Bytes (Copy, Expected, Token,
                               Import_Complete'Access, Accepted);
            if not Accepted then
               Import_Failed (Token, "Image import queue is full.");
            end if;
         end;
      end;
   exception
      when others =>
         --  Do not propagate Ada exceptions across the GTK C callback.
         Import_Failed (Token, "Could not read clipboard image.");
   end Clipboard_Data;

   procedure Clipboard_Targets (Clipboard, Data, Token : System.Address) is
      use Gtk.Selection_Data;
      I : constant Request_Index := Find_Request (Token);
      PNG : constant Gdk.Types.Gdk_Atom := Atom ("image/png");
      JPEG : constant Gdk.Types.Gdk_Atom := Atom ("image/jpeg");
      Choice : Raster.Format := Raster.Unknown;
   begin
      if I = 0 then
         return;
      elsif Requests (I).Owner = null then
         Requests (I) := (others => <>);
         return;
      end if;
      declare
         Selection : constant Gtk_Selection_Data := From_Object (Data);
      begin
         if Get_Length (Selection) in 1 .. 4_096 then
            for Offered of Get_Targets (Selection) loop
               if Offered = PNG then
                  Choice := Raster.PNG;
                  exit;
               elsif Offered = JPEG then
                  Choice := Raster.JPEG;
               end if;
            end loop;
         end if;
      end;
      if Choice = Raster.Unknown then
         Import_Failed (Token,
                          "The clipboard does not offer a PNG or JPEG image.");
      else
         Requests (I).Expected := Choice;
         Request_Contents
           (Clipboard, (if Choice = Raster.PNG then PNG else JPEG),
            Clipboard_Data'Access, Token);
      end if;
   exception
      when others =>
         Import_Failed (Token, "Could not read clipboard formats.");
   end Clipboard_Targets;

   procedure Paste (S : Instance_Access) is
      Focus : constant Gtk.Widget.Gtk_Widget := S.Canvas_Window.Get_Focus;
      Clip : Gtk.Clipboard.Gtk_Clipboard;
      I : Request_Index;
   begin
      if Focus /= null and then Focus.all in Gtk.GEntry.Gtk_Entry_Record'Class
      then
         Gtk.GEntry.Gtk_Entry (Focus).Paste_Clipboard;
         return;
      end if;
      Invalidate (S.all, Paste_Only => True);
      I := Acquire (S, Clipboard_Image);
      if I = 0 then
         Report_Import_Error (S, "Too many pending image requests.");
      else
         Clip := Gtk.Clipboard.Get_For_Display
           (S.Canvas_Window.Get_Display, Atom ("CLIPBOARD"));
         Set_Status (S.all, "Reading clipboard image...");
         Request_Contents
           (Clip.Get_Object, Atom ("TARGETS"), Clipboard_Targets'Access,
            Requests (I)'Address);
      end if;
   end Paste;

   procedure File_Response
     (Dialog : access Gtk.Dialog.Gtk_Dialog_Record'Class;
      Response : Glib.Gint; S : Instance_Access)
   is
      pragma Unreferenced (Dialog);
      use Ada.Strings.Unbounded;
      use Gtk.Enums.String_SList;
      Files : GSlist := Null_List;
      Cursor : GSlist;
      Paths : Jobs.Path_List (1 .. Jobs.MAX_FILES);
      Count : Natural := 0;
      I : Request_Index := 0;
      Accepted : Boolean;
   begin
      if Gtk.Dialog.Gtk_Response_Type (Response) = Gtk.Dialog.Gtk_Response_OK
      then
         Files := S.File_Selection.Get_Filenames;
      end if;
      S.File_Selection.Destroy;
      S.File_Selection := null;
      if Length (Files) > Glib.Guint (Jobs.MAX_FILES) then
         Gtk.Enums.Free_String_List (Files);
         Report_Import_Error (S, "Select at most eight images per import.");
         return;
      end if;
      Cursor := Files;
      while Cursor /= Null_List loop
         Count := Count + 1;
         Paths (Count) := To_Unbounded_String (Get_Data (Cursor));
         Cursor := Next (Cursor);
      end loop;
      Gtk.Enums.Free_String_List (Files);
      if Count = 0 then
         return;
      end if;
      --  GTK does not promise click order or visual sort order here.
      for J in 2 .. Count loop
         declare
            Key : constant Unbounded_String := Paths (J);
            K   : Positive := J;
         begin
            while K > 1 and then Key < Paths (K - 1) loop
               Paths (K) := Paths (K - 1);
               K := K - 1;
            end loop;
            Paths (K) := Key;
         end;
      end loop;
      I := Acquire (S, File_Image);
      if I = 0 then
         Report_Import_Error (S, "Too many pending image requests.");
      else
         Set_Status (S.all, "Reading selected images...");
         Jobs.Submit_Files (Paths (1 .. Count), Requests (I)'Address,
                            Import_Complete'Access, Accepted);
         if not Accepted then
            Import_Failed (Requests (I)'Address, "Image import queue is full.");
         end if;
      end if;
   exception
      when others =>
         Gtk.Enums.Free_String_List (Files);
         if I /= 0 then
            Requests (I) := (others => <>);
         end if;
         Report_Import_Error (S, "Could not import the selected images.");
   end File_Response;

   procedure Choose_File (S : Instance_Access) is
      Button : Gtk.Widget.Gtk_Widget;
      pragma Unreferenced (Button);
   begin
      if S.File_Selection = null then
         Gtk.File_Chooser_Dialog.Gtk_New
           (S.File_Selection, "coyote : File Selection", S.Canvas_Window,
            Gtk.File_Chooser.Action_Open);
         S.File_Selection.Set_Name ("coyote-canvas-file-selection");
         S.File_Selection.Set_Local_Only (True);
         S.File_Selection.Set_Select_Multiple (True);
         Button := S.File_Selection.Add_Button
           ("_Cancel", Gtk.Dialog.Gtk_Response_Cancel);
         Button := S.File_Selection.Add_Button
           ("_Import", Gtk.Dialog.Gtk_Response_OK);
         S.File_Selection.Set_Default_Response (Gtk.Dialog.Gtk_Response_OK);
         Dialog_Callback.Connect
           (S.File_Selection, "response",
            Dialog_Callback.To_Marshaller (File_Response'Access), S);
         S.File_Selection.Show;
      end if;
      S.File_Selection.Present;
   end Choose_File;

   procedure On_Field
     (Field : access Gtk.GEntry.Gtk_Entry_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Field);
   begin
      Refresh (S.all);
   end On_Field;

   procedure Open_Help (S : in out Instance; Topic : String) is
   begin
      if not Coyote_Help.Open (Topic) then
         Set_Status (S, "Unable to open Help: Yelp is not available.");
      end if;
   end Open_Help;

   procedure Disable_Click_Help (S : in out Instance) is
   begin
      if S.Help_Mode then
         S.Help_Mode := False;
         Gdk.Window.Set_Cursor (S.Canvas_Window.Get_Window, null);
         Update_Zoom_Cursor (S);
         Set_Status (S, "Click for Help ended.");
      end if;
   end Disable_Click_Help;

   function On_Help_Click
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean
   is
   begin
      if not S.Help_Mode or else Gdk.Event.Get_Event_Type (Event) /=
        Gdk.Event.Button_Press or else Gdk.Event.Get_Button (Event) /= 1
      then
         return False;
      end if;
      Disable_Click_Help (S.all);
      Open_Help (S.all, (if Widget.Get_Name = "coyote-canvas-drawings"
                        then "canvas-revisions" else "canvas-editing"));
      return True;
   end On_Help_Click;

   function On_Toolbar_Focus
     (Toolbar : access Gtk.Box.Gtk_Box_Record'Class;
      Params  : Glib.Values.GValues; S : Instance_Access) return Boolean
   is
      pragma Unreferenced (Toolbar);
      Direction : constant Gtk.Enums.Gtk_Direction_Type :=
        Gtk.Enums.Gtk_Direction_Type'Val
          (Glib.Values.Get_Enum (Glib.Values.Nth (Params, 1)));
      Focus : constant Gtk.Widget.Gtk_Widget := S.Canvas_Window.Get_Focus;
   begin
      --  GTK skips the radio group if its active button is disabled.
      if Direction in Gtk.Enums.Dir_Tab_Forward | Gtk.Enums.Dir_Tab_Backward
        and then not S.Buttons (Active_Tool (S.all)).Is_Sensitive
        and then S.Buttons (Zoom_In).Is_Sensitive
        and then Focus /= Gtk.Widget.Gtk_Widget (S.Buttons (Zoom_In))
        and then Focus /= Gtk.Widget.Gtk_Widget (S.Buttons (Zoom_Out))
        and then not S.Pencil_Color.Is_Sensitive
      then
         S.Buttons
           ((if Direction in Gtk.Enums.Dir_Tab_Forward then Zoom_In
             else Zoom_Out)).Grab_Focus;
         return True;
      end if;
      return False;
   end On_Toolbar_Focus;

   procedure On_Tool_Button
     (Button : access Gtk.Radio_Button.Gtk_Radio_Button_Record'Class;
      S      : Instance_Access)
   is
   begin
      if not S.Syncing_Tools and then Button.Get_Active then
         Find_Button : for Tool in Tool_Kind loop
            if S.Buttons (Tool) = Button then
               Select_Tool (S.all, Tool, Focus_Fields => False);
               exit Find_Button;
            end if;
         end loop Find_Button;
      end if;
   end On_Tool_Button;

   procedure On_Tool_Menu
     (Item : access Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record'Class;
      S    : Instance_Access)
   is
      use Gtk.Check_Menu_Item;
   begin
      if not S.Syncing_Tools and then Item.Get_Active then
         Find_Item : for Tool in Editing_Tool loop
            if Gtk_Check_Menu_Item (S.Tool_Menu (Tool)) = Item then
               Select_Tool (S.all, Tool, Focus_Fields => True);
               exit Find_Item;
            end if;
         end loop Find_Item;
      end if;
   end On_Tool_Menu;

   procedure On_Markup
     (Item : access Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record'Class;
      S    : Instance_Access)
   is
   begin
      Cancel_Gesture (S.all, Keep_Zoom => True);
      S.Show_Ink := Item.Get_Active;
      Refresh (S.all);
   end On_Markup;

   procedure On_Edit_With_Finger
     (Item : access Gtk.Check_Menu_Item.Gtk_Check_Menu_Item_Record'Class;
      S    : Instance_Access)
   is
   begin
      S.Edit_With_Finger := Item.Get_Active;
      if not S.Edit_With_Finger and then S.Finger_Sequence /= null then
         Cancel_Gesture (S.all);
      end if;
      Refresh (S.all);
   end On_Edit_With_Finger;

   procedure Freeze_Attachments (S : aliased in out Instance);

   procedure On_Attach_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
   begin
      Freeze_Attachments (S.all);
   end On_Attach_Clicked;

   procedure Remember_Attach_Focus
     (Window : access Gtk.Window.Gtk_Window_Record'Class;
      S      : Instance_Access)
   is
      Focus : constant Gtk.Widget.Gtk_Widget := Window.Get_Focus;
   begin
      --  Tabbing to Attach must not switch from the draft to selected rows.
      if Focus /= Gtk.Widget.Gtk_Widget (S.Attach_Button) then
         S.Attach_From_Drawing :=
           Focus = Gtk.Widget.Gtk_Widget (S.Drawing_Area);
      end if;
   end Remember_Attach_Focus;

   procedure Apply_Reveal (S : in out Instance);
   procedure Clear_Display (S : in out Instance);

   procedure On_Action
     (Item : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class;
      S    : Instance_Access);

   function Tool_Name (Tool : Tool_Kind) return String is
     (case Tool is when Pencil => "pencil", when Eraser => "eraser",
                   when Crop => "crop", when Zoom_In => "zoom-in",
                   when Zoom_Out => "zoom-out");

   function Tool_Text (Tool : Tool_Kind) return String is
     (case Tool is when Pencil => "Pencil", when Eraser => "Eraser",
                   when Crop => "Crop", when Zoom_In => "Zoom In",
                   when Zoom_Out => "Zoom Out");

   function Tool_Icon
     (Area : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context : Cairo.Cairo_Context; Tool : Tool_Kind) return Boolean
   is
      use Cairo;
      use type Glib.Gdouble;
      Side : constant Glib.Gdouble := 22.0;
      Color : Gdk.RGBA.Gdk_RGBA;
   begin
      declare
         Button : constant Gtk.Widget.Gtk_Widget := Area.Get_Parent;
      begin
         Gtk.Style_Context.Get_Style_Context (Button).Get_Color
           (Button.Get_State_Flags, Color);
      end;
      Save (Context);
      Translate
        (Context, (Glib.Gdouble (Area.Get_Allocated_Width) - Side) / 2.0,
         (Glib.Gdouble (Area.Get_Allocated_Height) - Side) / 2.0);
      Set_Source_Rgba (Context, Color.Red, Color.Green, Color.Blue, Color.Alpha);
      Set_Line_Width (Context, 1.8);
      Set_Line_Cap (Context, Cairo_Line_Cap_Round);
      Set_Line_Join (Context, Cairo_Line_Join_Round);
      case Tool is
         when Pencil =>
            Move_To (Context, 3.5, 18.5);
            Line_To (Context, 4.7, 12.9);
            Line_To (Context, 15.8, 1.8);
            Line_To (Context, 20.2, 6.2);
            Line_To (Context, 9.1, 17.3);
            Close_Path (Context);
            Move_To (Context, 13.1, 4.5);
            Line_To (Context, 17.5, 8.9);
            Move_To (Context, 4.7, 12.9);
            Line_To (Context, 9.1, 17.3);
         when Eraser =>
            Move_To (Context, 2.6, 12.8);
            Line_To (Context, 12.8, 2.6);
            Line_To (Context, 19.8, 9.6);
            Line_To (Context, 11.0, 18.4);
            Line_To (Context, 8.2, 18.4);
            Close_Path (Context);
            Move_To (Context, 7.2, 8.2);
            Line_To (Context, 14.2, 15.2);
            Move_To (Context, 11.0, 18.4);
            Line_To (Context, 20.0, 18.4);
         when Crop =>
            Move_To (Context, 5.5, 2.0);
            Line_To (Context, 5.5, 16.5);
            Line_To (Context, 20.0, 16.5);
            Move_To (Context, 2.0, 5.5);
            Line_To (Context, 16.5, 5.5);
            Line_To (Context, 16.5, 20.0);
            Move_To (Context, 16.5, 5.5);
            Line_To (Context, 20.0, 2.0);
         when Zoom_In | Zoom_Out =>
            Arc (Context, 8.8, 8.8, 6.2, 0.0, 6.283_185_307_179_586);
            Move_To (Context, 13.3, 13.3);
            Line_To (Context, 19.8, 19.8);
            Move_To (Context, 5.9, 8.8);
            Line_To (Context, 11.7, 8.8);
            if Tool = Zoom_In then
               Move_To (Context, 8.8, 5.9);
               Line_To (Context, 8.8, 11.7);
            end if;
      end case;
      Stroke (Context);
      Restore (Context);
      return True;
   end Tool_Icon;

   --  GtkAda does not expose the widget's ATK object.
   function Accessible (Widget : System.Address) return System.Address
     with Import, Convention => C, External_Name => "gtk_widget_get_accessible";
   procedure Set_Accessible_Name
     (Object : System.Address; Name : Interfaces.C.char_array)
     with Import, Convention => C, External_Name => "atk_object_set_name";

   function Ink_Value (Value : Glib.Gdouble) return Natural is
     (Natural (Long_Float'Rounding
        (Long_Float'Max (0.0, Long_Float'Min (Long_Float (Value), 1.0)) * 255.0)));

   function Pencil_Color_Value
     (Button : access Gtk.Color_Button.Gtk_Color_Button_Record'Class)
      return Rev.Ink_Color
   is
      Color : Gdk.RGBA.Gdk_RGBA;
   begin
      Button.Get_Rgba (Color);
      return Rev.Ink_Color
        (Ink_Value (Color.Red) * 16#01_00_00#
         + Ink_Value (Color.Green) * 16#00_01_00#
         + Ink_Value (Color.Blue));
   end Pencil_Color_Value;

   procedure On_Pencil_Color_Set
     (Button : access Gtk.Color_Button.Gtk_Color_Button_Record'Class;
      S      : Instance_Access)
   is
      Color : Gdk.RGBA.Gdk_RGBA;
   begin
      if S = null then
         return;
      end if;
      if not Can_Select_Tool (S.all) or else Cropping (S.all) then
         Button.Set_Rgba
           ((Red => Glib.Gdouble ((S.Ink_Color / 16#01_00_00#) mod 256)
              / 255.0,
            Green => Glib.Gdouble ((S.Ink_Color / 16#00_01_00#) mod 256)
              / 255.0,
            Blue => Glib.Gdouble (S.Ink_Color mod 256) / 255.0,
            Alpha => 1.0));
         return;
      end if;
      Button.Get_Rgba (Color);
      Color.Alpha := 1.0;
      Button.Set_Rgba (Color);
      S.Ink_Color := Pencil_Color_Value (Button);
   end On_Pencil_Color_Set;

   procedure Build_Window
     (S      : aliased in out Instance;
      Parent :            not null access Gtk.Window.Gtk_Window_Record'Class)
   is
      Outer, Toolbar, Body_Box, Side : Gtk.Box.Gtk_Box;
      Footer, Status_Box    : Gtk.Box.Gtk_Box;
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

      procedure Build_Tool_Menu is
         Members : Gtk.Widget.Widget_SList.GSlist :=
           Gtk.Widget.Widget_SList.Null_List;
      begin
         for Tool in Editing_Tool loop
            Gtk.Radio_Menu_Item.Gtk_New_With_Mnemonic
              (S.Tool_Menu (Tool), Members,
               (if Tool = Pencil then "Penci_l" else "_" & Tool_Text (Tool)));
            Members := S.Tool_Menu (Tool).Get_Group;
            S.Tool_Menu (Tool).Set_Name ("canvas-" & Tool_Name (Tool));
            Menu.Append (S.Tool_Menu (Tool));
            Check_Callback.Connect
              (S.Tool_Menu (Tool), "activate", On_Tool_Menu'Access, State,
               After => True);
         end loop;
      end Build_Tool_Menu;

      procedure Build_Toolbar is
         Members : Gtk.Widget.Widget_SList.GSlist :=
           Gtk.Widget.Widget_SList.Null_List;
         Icon : Gtk.Drawing_Area.Gtk_Drawing_Area;
         Style : Gtk.Css_Provider.Gtk_Css_Provider;
         CSS : constant String :=
           "radiobutton { padding: 4px; border-radius: 4px; } "
           & "radiobutton:hover { background-color: alpha(currentColor, 0.08); } "
           & "radiobutton:checked { background-color: alpha(currentColor, 0.13); "
           & "box-shadow: inset 0 -2px currentColor; } "
           & "radiobutton radio { min-width: 0; min-height: 0; margin: 0; "
           & "padding: 0; border: 0; box-shadow: none; background: none; "
           & "-gtk-icon-source: none; -gtk-icon-shadow: none; }";
         Style_Loaded : Boolean;

         procedure Build_Brush_Size (Tool : Ink_Tool) is
            Group : Gtk.Box.Gtk_Box;
            Caption, Units : Gtk.Label.Gtk_Label;
            Control : Gtk.Spin_Button.Gtk_Spin_Button renames
              S.Brush_Size (Tool);
            Title : constant String := Tool_Text (Tool) & " size";
         begin
            Gtk.Box.Gtk_New_Hbox (Group, False, 4);
            Gtk.Spin_Button.Gtk_New (Control, Min => 1.0, Max => 64.0,
                                     Step => 1.0);
            Control.Set_Name ("canvas-" & Tool_Name (Tool) & "-size");
            Control.Set_Numeric (True);
            Control.Set_Snap_To_Ticks (True);
            Control.Set_Update_Policy (Gtk.Spin_Button.Update_If_Valid);
            Control.Set_Value (DEFAULT_BRUSH_SIZE (Tool));
            Control.Set_Width_Chars (2);
            Control.Set_Tooltip_Text (Title & " in source pixels");
            Set_Accessible_Name
              (Accessible (Control.Get_Object), Interfaces.C.To_C (Title));
            Gtk.Label.Gtk_New (Caption, Title & ":");
            Caption.Set_Mnemonic_Widget (Control);
            Gtk.Label.Gtk_New (Units, "px");
            Group.Pack_Start (Caption, False, False, 0);
            Group.Pack_Start (Control, False, False, 0);
            Group.Pack_Start (Units, False, False, 0);
            Toolbar.Pack_Start (Group, False, False, 3);
            Event_Callback.Connect
              (Control, "button-press-event",
               Event_Marshaller.To_Marshaller (On_Help_Click'Access), State);
         end Build_Brush_Size;
      begin
         Gtk.Css_Provider.Gtk_New (Style);
         Style_Loaded := Style.Load_From_Data (CSS, null);
         Gtk.Box.Gtk_New_Hbox (Toolbar, False, 4);
         Toolbar.Set_Name ("coyote-canvas-toolbar");
         Toolbar.Set_Margin_Start (6);
         Toolbar.Set_Margin_End (6);
         Gtk.Label.Gtk_New (Label, "Tool:");
         Toolbar.Pack_Start (Label, False, False, 0);
         for Tool in Tool_Kind loop
            Gtk.Radio_Button.Gtk_New (S.Buttons (Tool), Members);
            Members := S.Buttons (Tool).Get_Group;
            --  Set_Mode (False) also disables GTK's arrow-key selection.
            --  Style away the indicator without changing the widget mode.
            if Style_Loaded then
               Gtk.Style_Context.Get_Style_Context (S.Buttons (Tool))
                 .Add_Provider
                   (Gtk.Css_Provider."+" (Style),
                    Glib.Guint (Gtk.Style_Provider.Priority_Application));
            end if;
            S.Buttons (Tool).Set_Name ("canvas-tool-" & Tool_Name (Tool));
            S.Buttons (Tool).Set_Tooltip_Text (Tool_Text (Tool));
            Set_Accessible_Name
              (Accessible (S.Buttons (Tool).Get_Object),
               Interfaces.C.To_C (Tool_Text (Tool)));
            Gtk.Drawing_Area.Gtk_New (Icon);
            Icon.Set_Size_Request (22, 22);
            S.Buttons (Tool).Add (Icon);
            Icon_Callback.Connect
              (Icon, "draw", Icon_Marshaller.To_Marshaller (Tool_Icon'Access),
               Tool);
            Toolbar.Pack_Start (S.Buttons (Tool), False, False, 0);
            Event_Callback.Connect
              (S.Buttons (Tool), "button-press-event",
               Event_Marshaller.To_Marshaller (On_Help_Click'Access), State);
            Tool_Callback.Connect
              (S.Buttons (Tool), "toggled", On_Tool_Button'Access, State);
         end loop;
         Gtk.Color_Button.Gtk_New_With_Rgba
           (S.Pencil_Color,
            (Red => 13.0 / 255.0, Green => 13.0 / 255.0,
             Blue => 13.0 / 255.0, Alpha => 1.0));
         S.Pencil_Color.Set_Name ("canvas-pencil-color");
         S.Pencil_Color.Set_Title ("Pencil color");
         S.Pencil_Color.Set_Tooltip_Text ("Pencil color");
         S.Pencil_Color.Set_Use_Alpha (False);
         Set_Accessible_Name
           (Accessible (S.Pencil_Color.Get_Object),
            Interfaces.C.To_C ("Pencil color"));
         Gtk.Label.Gtk_New (Label, "Pencil color:");
         Toolbar.Pack_Start (Label, False, False, 6);
         Toolbar.Pack_Start (S.Pencil_Color, False, False, 0);
         Event_Callback.Connect
           (S.Pencil_Color, "button-press-event",
            Event_Marshaller.To_Marshaller (On_Help_Click'Access), State);
         Color_Callback.Connect
           (S.Pencil_Color, "color-set", On_Pencil_Color_Set'Access, State);
         for Tool in Ink_Tool loop
            Build_Brush_Size (Tool);
         end loop;
         Style.Unref;
         Toolbar_Callback.Connect
           (Toolbar, "focus", On_Toolbar_Focus'Access, State, After => True);
         Outer.Pack_Start (Toolbar, False, False, 3);
      end Build_Toolbar;

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
      S.New_Item := Action ("_New", "new", Gdk.Types.Keysyms.GDK_LC_n);
      S.Import_Item := Action ("_Import...", "import");
      S.Save_Item := Action ("_Save", "save", Gdk.Types.Keysyms.GDK_LC_s);
      Item        := Action ("_Close", "close", Gdk.Types.Keysyms.GDK_LC_w);
      Group ("_Selected");
      S.Attach_Item := Action ("_Attach", "attach");
      Group ("_Edit");
      S.Undo_Item   := Action ("_Undo", "undo", Gdk.Types.Keysyms.GDK_LC_z);
      S.Redo_Item   :=
        Action
          ("_Redo", "redo", Gdk.Types.Keysyms.GDK_LC_z,
           Gdk.Types.Control_Mask or Gdk.Types.Shift_Mask);
      S.Paste_Item := Action ("_Paste", "paste", Gdk.Types.Keysyms.GDK_LC_v);
      Build_Tool_Menu;
      S.Apply_Item  := Action ("_Apply Crop", "apply");
      S.Cancel_Item := Action ("Ca_ncel Crop", "cancel");
      Group ("_View");
      S.Draft_Item := Action ("Show _Working Copy", "draft");
      S.Fit_Item   := Action ("_Fit", "fit");
      S.Zoom_In_Item  := Action ("Zoom _In", "zoom-in");
      S.Zoom_Out_Item := Action ("Zoom _Out", "zoom-out");
      S.Actual_Item   := Action ("_Actual Size", "actual");
      Gtk.Check_Menu_Item.Gtk_New_With_Mnemonic (Markup, "Show _Markup");
      Markup.Set_Active (True);
      Markup.Set_Name ("canvas-markup");
      Menu.Append (Markup);
      Check_Callback.Connect (Markup, "toggled", On_Markup'Access, State);
      Group ("_Options");
      Gtk.Check_Menu_Item.Gtk_New_With_Mnemonic
        (S.Finger_Item, "Edit with _Finger");
      S.Finger_Item.Set_Name ("canvas-edit-with-finger");
      Menu.Append (S.Finger_Item);
      Check_Callback.Connect
        (S.Finger_Item, "toggled", On_Edit_With_Finger'Access, State);
      Group ("_Help");
      Item := Action ("_Click for Help", "help-click", Gdk.Types.Keysyms.GDK_F1,
                      Gdk.Types.Shift_Mask);
      Item := Action ("_Overview", "help", Gdk.Types.Keysyms.GDK_F1, 0);
      Item := Action ("_Drawing and Editing", "help-editing");
      Item := Action ("_Revisions and Attachments", "help-revisions");
      Item := Action ("_Index", "help-index");
      Item := Action ("_Keys & Shortcuts", "help-keys");
      Item := Action ("_Product Information", "help-product");
      Item.Set_Sensitive (S.On_Product /= null);
      Outer.Pack_Start (Bar, False, False, 0);
      Accels.Unref;
      Build_Toolbar;
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
      Event_Callback.Connect
        (S.Drawing_Tree, "button-press-event",
         Event_Marshaller.To_Marshaller (On_Help_Click'Access), State);
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
         Gdk.Event.Pointer_Motion_Mask or Gdk.Event.Button_Motion_Mask or
         Gdk.Event.Touch_Mask);
      Event_Callback.Connect
        (S.Drawing_Area, "touch-event",
         Event_Marshaller.To_Marshaller (On_Touch'Access), State);
      Draw_Callback.Connect
        (S.Drawing_Area, "draw",
         Draw_Context_Marshaller.To_Marshaller (On_Draw'Access), State);
      Event_Callback.Connect
        (S.Drawing_Area, "button-press-event",
         Event_Marshaller.To_Marshaller (On_Help_Click'Access), State);
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
      Gtk.Scrolled_Window.Gtk_New (S.Viewport);
      S.Viewport.Set_Name ("coyote-canvas-viewport");
      S.Viewport.Set_Shadow_Type (Gtk.Enums.Shadow_None);
      S.Viewport.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      --  Image coordinates start at the left edge in either UI direction.
      S.Drawing_Area.Set_Direction (Gtk.Enums.Text_Dir_Ltr);
      S.Drawing_Area.Set_Halign (Gtk.Widget.Align_Start);
      S.Drawing_Area.Set_Valign (Gtk.Widget.Align_Start);
      S.Viewport.Add (S.Drawing_Area);
      Viewport_Callback.Connect
        (S.Viewport, "size-allocate", Apply_Zoom_Anchor'Access, State,
         After => True);
      S.Root.Pack_Start (S.Viewport, True, True, 0);
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
      Gtk.Box.Gtk_New_Hbox (Footer, False, 8);
      Gtk.Box.Gtk_New_Vbox (Status_Box, False, 0);
      Footer.Pack_Start (Status_Box, True, True, 0);
      Outer.Pack_Start (Footer, False, False, 0);
      Gtk.Label.Gtk_New (S.Tool_Label, "Tool: Pencil");
      S.Tool_Label.Set_Name ("coyote-canvas-tool");
      S.Tool_Label.Set_Halign (Gtk.Widget.Align_Start);
      Status_Box.Pack_Start (S.Tool_Label, False, False, 4);
      Gtk.Label.Gtk_New (S.Status, "Blank drawing workspace");
      S.Status.Set_Name ("coyote-canvas-status");
      S.Status.Set_Halign (Gtk.Widget.Align_Start);
      Status_Box.Pack_Start (S.Status, False, False, 4);
      Gtk.Label.Gtk_New (S.Storage_Label, "Drawings are in memory only.");
      S.Storage_Label.Set_Name ("coyote-canvas-storage-status");
      S.Storage_Label.Set_Halign (Gtk.Widget.Align_Start);
      Status_Box.Pack_Start (S.Storage_Label, False, False, 4);
      Gtk.Button.Gtk_New (S.Attach_Button, "Attach");
      S.Attach_Button.Set_Name ("canvas-attach-button");
      S.Attach_Button.Set_Valign (Gtk.Widget.Align_End);
      S.Attach_Button.Set_Margin_Bottom (8);
      Gtk.Widget.Set_Focus_On_Click
        (Gtk.Widget.Gtk_Widget (S.Attach_Button), False);
      Footer.Pack_End (S.Attach_Button, False, False, 8);
      Button_Callback.Connect
        (S.Attach_Button, "clicked", On_Attach_Clicked'Access, State);
      Window_Callback.Connect
        (S.Canvas_Window, "set-focus", Remember_Attach_Focus'Access,
         State, After => True);
      Outer.Show_All;
      S.Crop_Grid.Hide;
   end Build_Window;

   package Recovery_Timer is new Glib.Main.Generic_Sources (Instance_Access);

   procedure Finish_Job (S : in out Instance) is
      Status, Claim_Status : Persistence.Result;
   begin
      Recovery_Jobs.Finish (S.Job, S.Document, S.Disk_Pixels, S.Lease,
                            Status, Claim_Status,
                            Adopt_Additions => S.Import_Count /= 0);
      if S.Import_Count /= 0 then
         S.Import_Count := 0;
         if Status in Persistence.Ok | Persistence.Uncertain then
            S.Image_Bytes := S.Import_Bytes;
            S.Pending_Save := Status = Persistence.Uncertain;
            S.Save_Failed := S.Pending_Save;
            Agent_Result
              (S, (if Status = Persistence.Ok then Service.Ok else Service.Unknown),
               (if Status = Persistence.Ok then To_String (S.Import_Reply)
                else "Canvas import outcome unknown; inspect Drawings before resubmitting"));
            Extend_Tree (S);
         else
            Agent_Result (S, Service.Rejected, "Canvas commit failed: " & Status'Image);
         end if;
         S.Import_Reply := Null_Unbounded_String;
         Refresh (S);
      elsif S.Loading then
         S.Loading := False;
         if Status in Persistence.Ok | Persistence.Missing then
            S.Writable := Claim_Status = Persistence.Ok;
            if Status = Persistence.Ok then
               for Id in 1 .. Rev.Count (S.Document) loop
                  if Length (S.Disk_Pixels (Id)) /= 0 then
                     S.Images (Id).Origin := File_Image;
                     S.Image_Bytes := S.Image_Bytes + Length (S.Disk_Pixels (Id));
                  end if;
               end loop;
               S.Has_Drawing := Rev.Base (S.Document) /= Rev.NO_REVISION;
               Extend_Tree (S);
            end if;
            if S.Writable then
               Storage_Status (S, (if Status = Persistence.Ok then
                 "Session Canvas restored." else "Canvas autosave enabled."));
            else
               Storage_Status (S, "Read-only: another window owns this Canvas.");
            end if;
         else
            Storage_Status (S, "Canvas recovery unavailable; editing is disabled.");
         end if;
         Apply_Reveal (S);
         Refresh (S);
      else
         S.Save_Failed := Status /= Persistence.Ok;
         if S.Save_Failed then
            S.Pending_Save := True;
            Storage_Status (S, "Canvas autosave failed. Changes are still in memory.");
         elsif not S.Pending_Save then
            Storage_Status (S, "Canvas recovery saved.");
         end if;
         Refresh (S);
      end if;
   end Finish_Job;

   procedure Start_Save (S : in out Instance) is
   begin
      Recovery_Jobs.Start
        (S.Job, Recovery_Jobs.Save_Store, To_String (S.Parent),
         To_String (S.UUID), S.Document, S.Disk_Pixels,
         To_String (S.Session_File));
      S.Pending_Save := False;
      S.Save_Failed := False;
      Storage_Status (S, "Saving Canvas recovery...");
   exception
      when others =>
         S.Save_Failed := True;
         Storage_Status (S, "Cannot start Canvas autosave.");
         Refresh (S);
   end Start_Save;

   function Poll_Recovery (S : Instance_Access) return Boolean is
   begin
      if Recovery_Jobs.Ready (S.Job) then
         Finish_Job (S.all);
      end if;
      if S.Job = null and then S.Writable and then S.Pending_Save
        and then not S.Save_Failed and then not S.Suspended
        and then Ada.Real_Time.Clock >= S.Save_After
      then
         Start_Save (S.all);
      end if;
      if S.Job = null and then (not S.Pending_Save or else S.Save_Failed
                              or else not S.Writable or else S.Suspended)
      then
         S.Timer := 0;
         return False;
      end if;
      return True;
   end Poll_Recovery;

   procedure Wake_Recovery (S : aliased in out Instance) is
   begin
      if S.Timer = 0 then
         S.Timer := Recovery_Timer.Timeout_Add
           (50, Poll_Recovery'Access, S'Unchecked_Access);
      end if;
   end Wake_Recovery;

   procedure Mark_Dirty (S : aliased in out Instance) is
   begin
      if S.Writable then
         S.Pending_Save := True;
         S.Save_Failed := False;
         S.Save_After := Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (350);
         Storage_Status (S, "Canvas recovery pending.");
         Wake_Recovery (S);
      end if;
   end Mark_Dirty;

   procedure Ensure_Load (S : aliased in out Instance) is
   begin
      if not S.Load_Started and then Length (S.Parent) /= 0 then
         S.Load_Started := True;
         S.Loading := True;
         Storage_Status (S, "Opening session Canvas...");
         Recovery_Jobs.Start
           (S.Job, Recovery_Jobs.Open_Store, To_String (S.Parent),
            To_String (S.UUID), S.Document, S.Disk_Pixels, To_String (S.Session_File));
         Wake_Recovery (S);
      end if;
   exception
      when others =>
         Recovery_Jobs.Discard (S.Job);
         S.Loading := False;
         Storage_Status (S, "Cannot open session Canvas.");
   end Ensure_Load;

   function Poll_Import (S : Instance_Access) return Boolean is
      Data : Service.Text_List (1 .. Service.MAX_FILES);
      Count : Natural;
      Slot : Request_Index;
      Accepted : Boolean;
   begin
      if S.Import_Count /= 0 and then Recovery_Jobs.Ready (S.Job) then
         Finish_Job (S.all);
      end if;
      if not Service.Pending (S.Service) then
         return True;
      end if;
      if not S.Suspended then
         Ensure_Load (S.all);
         if S.Job /= null then
            return True;
         end if;
      end if;
      Service.Take (S.Service, Data, S.Import_Labels, Count);
      if Count = 0 then
         return True;
      end if;
      if not Can_Edit (S.all) then
         Agent_Result (S.all, Service.Rejected, "Canvas is read-only or switching sessions");
         return True;
      end if;
      Slot := Acquire (S, Agent_Image);
      if Slot /= 0 then
         Jobs.Submit_Batch (Data (1 .. Count), Requests (Slot)'Address,
                            Import_Complete'Access, Accepted);
         if Accepted then
            return True;
         end if;
         Requests (Slot) := (others => <>);
      end if;
      Agent_Result (S.all, Service.Rejected, "Canvas decode queue is full");
      return True;
   exception
      when others =>
         if S.Import_Count = 0 then
            Agent_Result (S.all, Service.Rejected, "Cannot dispatch Canvas batch");
         end if;
         return True;
   end Poll_Import;

   procedure Bind (S : aliased in out Instance; Parent, UUID : String;
                   Session_File : String := "";
                   Publication : Service.Binding_Access := null) is
      Target : Service.Endpoint;
   begin
      S.Parent := To_Unbounded_String (Parent);
      S.UUID := To_Unbounded_String (UUID);
      S.Session_File := To_Unbounded_String (Session_File);
      S.Suspended := False;
      if Publication /= null and then UUID /= "" then
         S.Publication := Publication;
         begin
            Service.Start (S.Service, Target);
            if Service.Running (S.Service) then
               S.Import_Timer := Recovery_Timer.Timeout_Add
                 (50, Poll_Import'Access, S'Unchecked_Access);
               if S.Import_Timer = 0 then
                  Service.Stop (S.Service);
                  Target := (others => Null_Unbounded_String);
               end if;
            end if;
         exception
            when others =>
               Service.Stop (S.Service);
               Target := (others => Null_Unbounded_String);
         end;
         Publication.Set (UUID, Target);
      end if;
      Refresh (S);
   end Bind;

   procedure Suspend (S : in out Instance; Value : Boolean) is
   begin
      S.Suspended := Value;
      if Value then
         for R of Requests loop
            if R.Owner /= null and then R.Owner.all'Address = S'Address
              and then R.Origin = Agent_Image
            then
               Agent_Result (S, Service.Rejected, "Canvas session transition");
            end if;
         end loop;
         Invalidate (S);
         Destroy_Import_Dialogs (S);
         if S.Canvas_Window /= null then
            Cancel_Gesture (S);
         end if;
      end if;
      Refresh (S);
   end Suspend;

   function Flush (S : in out Instance) return Boolean is
   begin
      if S.Job /= null and then not S.Loading then
         Finish_Job (S);
      end if;
      if S.Pending_Save and then S.Writable then
         Start_Save (S);
         if S.Job /= null then
            Finish_Job (S);
         end if;
      end if;
      return not S.Pending_Save and then not S.Save_Failed
        and then (Length (S.Parent) /= 0 or else Rev.Count (S.Document) = 0);
   end Flush;

   procedure Show
     (S      : aliased in out Instance;
      Parent :            not null access Gtk.Window.Gtk_Window_Record'Class)
   is
   begin
      if S.Canvas_Window = null then
         Build_Window (S, Parent);
         Extend_Tree (S);
         if Length (S.Background_Status) /= 0 then
            Set_Status (S, To_String (S.Background_Status));
         end if;
      end if;
      Ensure_Load (S);
      S.Canvas_Window.Show;
      S.Canvas_Window.Present;
      Refresh (S);
   end Show;

   procedure Set_Attach_Handler (S : in out Instance; Handler : Attach_Handler) is
   begin
      S.On_Attach := Handler;
      Refresh (S);
   end Set_Attach_Handler;

   procedure Set_Product_Handler
     (S : in out Instance; Handler : Product_Handler) is
   begin
      S.On_Product := Handler;
   end Set_Product_Handler;

   procedure Apply_Reveal (S : in out Instance) is
   begin
      if Length (S.Reveal_Revision) = 0 or else S.Loading then
         return;
      end if;
      for Id in 1 .. Rev.Count (S.Document) loop
         if Rev.Revision_Key (S.Document, Id) = S.Reveal_Revision and then
           Rev.Drawing_Key (S.Document, Id) = S.Reveal_Drawing
         then
            declare
               Path : constant TM.Gtk_Tree_Path := S.Store.Get_Path (S.Rows (Id));
            begin
               S.Drawing_Tree.Expand_To_Path (Path);
               S.Drawing_Tree.Get_Selection.Unselect_All;
               S.Drawing_Tree.Get_Selection.Select_Path (Path);
               S.Editing_Draft := False;
               S.Preview_Revision := Id;
               Clear_Display (S);
               Refresh (S);
               TM.Path_Free (Path);
            end;
            S.Reveal_Drawing := Null_Unbounded_String;
            S.Reveal_Revision := Null_Unbounded_String;
            return;
         end if;
      end loop;
      S.Reveal_Drawing := Null_Unbounded_String;
      S.Reveal_Revision := Null_Unbounded_String;
      Set_Status (S, "The recorded revision is not available in this Canvas.");
   end Apply_Reveal;

   procedure Reveal
     (S : aliased in out Instance;
      Parent : not null access Gtk.Window.Gtk_Window_Record'Class;
      Drawing_Id, Revision_Id : String) is
   begin
      Show (S, Parent);
      S.Reveal_Drawing := To_Unbounded_String (Drawing_Id);
      S.Reveal_Revision := To_Unbounded_String (Revision_Id);
      Apply_Reveal (S);
   end Reveal;

   procedure Clear_Display (S : in out Instance) is
   begin
      Coyote_Canvas.Composite.Clear (S.Live_Erase);
      if S.Image_Surface /= Cairo.Null_Surface then
         Cairo.Surface_Destroy (S.Image_Surface);
         S.Image_Surface := Cairo.Null_Surface;
      end if;
   end Clear_Display;

   procedure Reset (S : in out Instance) is
   begin
      Disable_Click_Help (S);
      S.Resetting := True;
      S.Reveal_Drawing := Null_Unbounded_String;
      S.Reveal_Revision := Null_Unbounded_String;
      if S.Publication /= null then
         S.Publication.Clear;
         S.Publication := null;
      end if;
      if S.Import_Timer /= 0 then
         Glib.Main.Remove (S.Import_Timer);
         S.Import_Timer := 0;
      end if;
      if S.Import_Count /= 0 then
         Finish_Job (S);
      end if;
      Service.Stop (S.Service);
      S.Background_Status := Null_Unbounded_String;
      if S.Timer /= 0 then
         Glib.Main.Remove (S.Timer);
         S.Timer := 0;
      end if;
      Recovery_Jobs.Discard (S.Job);
      Persistence.Release (S.Lease);
      S.Parent := Null_Unbounded_String;
      S.UUID := Null_Unbounded_String;
      S.Session_File := Null_Unbounded_String;
      S.Disk_Pixels := (others => Null_Unbounded_String);
      S.Load_Started := False;
      S.Loading := False;
      S.Writable := False;
      S.Pending_Save := False;
      S.Save_Failed := False;
      S.Suspended := False;
      Storage_Status (S, "Drawings are in memory only.");
      Invalidate (S);
      Destroy_Import_Dialogs (S);
      Clear_Display (S);
      for Asset of S.Images loop
         if Asset.Pixels /= null then
            Asset.Pixels.Unref;
         end if;
         Asset := (others => <>);
      end loop;
      S.Image_Bytes := 0;
      S.Drawing := False;
      S.Finger_Sequence := null;
      S.Stroke_Points.Clear;
      S.Crop_Drag   := False;
      S.Tool := Pencil;
      if S.Pencil_Color /= null then
         S.Pencil_Color.Set_Rgba
           ((Red => 13.0 / 255.0, Green => 13.0 / 255.0,
             Blue => 13.0 / 255.0, Alpha => 1.0));
      end if;
      for Tool in Ink_Tool loop
         if S.Brush_Size (Tool) /= null then
            S.Brush_Size (Tool).Set_Value (DEFAULT_BRUSH_SIZE (Tool));
         end if;
      end loop;
      S.Ink_Color := Rev.DEFAULT_INK_COLOR;
      S.Gesture_Color := Rev.DEFAULT_INK_COLOR;
      Leave_Zoom_Tool (S);
      S.Anchor_Pending := False;
      S.Previous_Ink_Tool := Pencil;
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
      S.Edit_With_Finger := False;
      if S.Finger_Item /= null then
         S.Finger_Item.Set_Active (False);
      end if;
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
      S.Viewport    := null;
      S.Fit_Item    := null;
      S.Finger_Item := null;
      S.Store        := null;
      S.Drawing_Tree := null;
      S.Status       := null;
      S.Storage_Label := null;
      S.Crop_Grid    := null;
      S.X_Field      := null;
      S.Y_Field      := null;
      S.Width_Field  := null;
      S.Height_Field := null;
      S.Apply_Crop   := null;
      S.Cancel_Crop  := null;
      S.Attach_Button := null;
      S.Zoom         := 1.0;
      S.Show_Ink     := True;
      S.Tool_Label  := null;
      S.Pencil_Color := null;
      S.Brush_Size   := (others => null);
      S.Buttons     := (others => null);
      S.Tool_Menu   := (others => null);
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
      if S = null or else not Can_Edit (S.all) then
         return;
      end if;
      Cancel_Gesture (S.all);
      Rev.New_Drawing (S.Document, 800, 600);
      Mark_Dirty (S.all);
      Clear_Display (S.all);
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
      if S = null or else not Can_Edit (S.all) or else Cropping (S.all)
        or else S.Drawing
      then
         return;
      end if;
      if S.Editing_Draft and then Rev.Changed (S.Document) then
         Rev.Save (S.Document);
         Mark_Dirty (S.all);
         Extend_Tree (S.all);
         Set_Status
           (S.all, (if S.Writable then "Working copy checkpointed; autosave pending."
                    else "Working copy checkpointed in memory"));
      elsif S.Save_Failed then
         Mark_Dirty (S.all);
      end if;
      Refresh (S.all);
   exception
      when Coyote_Canvas.Revisions.Capacity_Error =>
         Set_Status (S.all, "Revision capacity reached; draft retained");
   end On_Save;

   function Prepare_Working_Copy (S : aliased in out Instance)
     return Boolean
   is
   begin
      if not Can_Draw (S) then
         return False;
      elsif not S.Editing_Draft then
         --  Browsing and canceled gestures leave the previous draft alone.
         --  Edit checkpoints it if dirty before taking the selected base.
         Rev.Edit (S.Document, S.Preview_Revision);
         Mark_Dirty (S);
         Clear_Display (S);
         S.Has_Drawing := True;
         S.Editing_Draft := True;
         Extend_Tree (S);
         Set_Status
           (S, "Working copy from revision" &
              Rev.Revision_Id'Image (S.Preview_Revision));
      end if;
      return True;
   exception
      when Rev.Capacity_Error =>
         Set_Status (S, "Cannot checkpoint current draft; edit not applied.");
         return False;
   end Prepare_Working_Copy;

   procedure On_Undo
     (Button : access Gtk.Button.Gtk_Button_Record'Class; S : Instance_Access)
   is
      pragma Unreferenced (Button);
   begin
      if S /= null and then Can_Edit (S.all) and then S.Editing_Draft
        and then not (Cropping (S.all) or else S.Drawing)
      then
         Coyote_Canvas.Revisions.Undo (S.Document);
         Mark_Dirty (S.all);
         Clear_Display (S.all);
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
      if S /= null and then Can_Edit (S.all) and then S.Editing_Draft
        and then not (Cropping (S.all) or else S.Drawing)
      then
         Coyote_Canvas.Revisions.Redo (S.Document);
         Mark_Dirty (S.all);
         Clear_Display (S.all);
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

   procedure Select_Tool
     (S : in out Instance; Tool : Tool_Kind; Focus_Fields : Boolean)
   is
      Abandoned_Crop : constant Boolean := Cropping (S);
   begin
      if Tool in Zoom_In | Zoom_Out then
         if Can_Zoom (S, Display_Extent (S)) and then Active_Tool (S) /= Tool
         then
            S.Zoom_Tool := (if Tool = Zoom_In then Magnify else Reduce);
            Update_Zoom_Cursor (S);
            Set_Status
              (S, "Click or tap the drawing to zoom; Escape leaves zoom.");
         end if;
         Refresh (S);
         return;
      elsif not Can_Select_Tool (S) then
         Refresh (S);
         return;
      end if;
      if S.Zoom_Tool /= No_Zoom then
         Leave_Zoom_Tool (S);
         Set_Status (S, "Zoom tool inactive.");
      end if;
      if S.Tool = Tool then
         Refresh (S);
         return;
      end if;
      Cancel_Gesture (S);
      if Tool = Crop then
         S.Previous_Ink_Tool := S.Tool;
      end if;
      S.Tool := Tool;
      if Cropping (S) then
         Set_Crop_Fields (S, Doc.EMPTY_RECTANGLE);
         S.Crop_Grid.Show;
         if Focus_Fields then
            S.X_Field.Grab_Focus;
         end if;
         Set_Status (S, "Drag a crop region or enter exact pixel bounds");
      elsif Abandoned_Crop then
         Set_Status (S, "Pending crop discarded.");
      end if;
      Refresh (S);
   end Select_Tool;

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
      Region : Doc.Rectangle;
      E      : Doc.Rectangle;
      use type Doc.Rectangle;
   begin
      if S = null or else not Can_Draw (S.all) or else not Cropping (S.all)
        or else S.Crop_Drag
      then
         return;
      end if;
      Region := Pending (S.all);
      if not Doc.Is_Nonempty (Region) then
         Set_Status (S.all, "Crop must be non-empty and within the drawing");
         return;
      end if;
      E := Display_Extent (S.all);
      if Region = Doc.Full_Extent (E.Right - E.Left, E.Bottom - E.Top) then
         On_Cancel_Crop (Button, S);
         Set_Status (S.all, "Crop leaves the drawing unchanged");
         return;
      elsif not Prepare_Working_Copy (S.all) then
         return;
      end if;
      Rev.Crop (S.Document, Region);
      Mark_Dirty (S.all);
      Clear_Display (S.all);
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
         Disable_Click_Help (S.all);
         Cancel_Gesture (S.all);
         Refresh (S.all);
         Invalidate (S.all, Keep_Agent => True);
         Destroy_Import_Dialogs (S.all);
         Clear_Display (S.all);
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
                  "Saved revision" &
                  Rev.Revision_Id'Image (S.Preview_Revision));
            end if;
         end if;
      elsif not S.Editing_Draft then
         Cancel_Gesture (S.all);
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
      elsif Name = "canvas-import" then
         if Can_Edit (S.all) then
            Choose_File (S);
         end if;
      elsif Name = "canvas-paste" then
         if Can_Edit (S.all) then
            Paste (S);
         end if;
      elsif Name = "canvas-save" then
         On_Save (null, S);
      elsif Name = "canvas-attach" then
         Freeze_Attachments (S.all);
      elsif Name = "canvas-undo" then
         On_Undo (null, S);
      elsif Name = "canvas-redo" then
         On_Redo (null, S);
      elsif Name = "canvas-cancel" then
         On_Cancel_Crop (null, S);
      elsif Name = "canvas-apply" then
         On_Apply_Crop (null, S);
      elsif Name = "canvas-close" then
         On_Close (Item, S);
      elsif Name = "canvas-help-click" then
         if S.Drawing or else S.Crop_Drag then
            Cancel_Gesture (S.all);
         end if;
         Refresh (S.all);
         declare
            Cursor : constant Gdk.Gdk_Cursor :=
              Gdk.Cursor.Gdk_Cursor_New (Gdk.Cursor.Question_Arrow);
         begin
            S.Help_Mode := True;
            Gdk.Window.Set_Cursor (S.Canvas_Window.Get_Window, Cursor);
            Update_Zoom_Cursor (S.all);
            Gdk.Cursor.Unref (Cursor);
         end;
         Set_Status
           (S.all, "Click the toolbar, drawing or Drawings list for Help.");
      elsif Name = "canvas-help-product" then
         if S.On_Product /= null then
            S.On_Product (S.Canvas_Window);
         end if;
      elsif Name in "canvas-help" | "canvas-help-editing" |
                    "canvas-help-revisions" | "canvas-help-index" |
                    "canvas-help-keys"
      then
         Disable_Click_Help (S.all);
         Open_Help (S.all,
           (if Name = "canvas-help" then "canvas"
            elsif Name = "canvas-help-editing" then "canvas-editing"
            elsif Name = "canvas-help-revisions" then "canvas-revisions"
            elsif Name = "canvas-help-keys" then "keyboard-shortcuts#canvas"
            else ""));
      elsif Name = "canvas-fit" then
         Fit_View (S.all);
      elsif Name in "canvas-zoom-in" | "canvas-zoom-out" | "canvas-actual" then
         if Can_Zoom (S.all, Display_Extent (S.all)) then
            if Name = "canvas-actual" then
               S.Anchor_Pending := False;
               S.Zoom := 1.0;
               Refresh (S.all);
            else
               declare
                  H : constant Gtk.Adjustment.Gtk_Adjustment :=
                    S.Viewport.Get_Hadjustment;
                  V : constant Gtk.Adjustment.Gtk_Adjustment :=
                    S.Viewport.Get_Vadjustment;
               begin
                  Zoom_At
                    (S.all, H.Get_Value + H.Get_Page_Size / 2.0,
                     V.Get_Value + V.Get_Page_Size / 2.0,
                     Increase => Name = "canvas-zoom-in");
               end;
            end if;
         end if;
      elsif Name = "canvas-draft" then
         Cancel_Gesture (S.all);
         S.Editing_Draft := True;
         Set_Status (S.all, "Working copy (in memory)");
         Refresh (S.all);
      end if;
   end On_Action;

   procedure Outline (Context : Cairo.Cairo_Context; R : Doc.Rectangle) is
   begin
      Cairo.Rectangle
        (Context, Glib.Gdouble (R.Left), Glib.Gdouble (R.Top),
         Glib.Gdouble (R.Right - R.Left), Glib.Gdouble (R.Bottom - R.Top));
   end Outline;

   procedure With_Background
     (S : Instance; Id : Rev.Revision_Id;
      Render : not null access procedure
        (Bytes : Ada.Streams.Stream_Element_Array; Stride : Positive;
         Has_Alpha : Boolean))
   is
      use Ada.Streams;
      use type Interfaces.C.size_t;
      package Composite renames Coyote_Canvas.Composite;
      Background : constant Rev.Revision_Id := Rev.Background (S.Document, Id);
      function Byte_Length (Pixbuf : System.Address) return Interfaces.C.size_t
        with Import, Convention => C,
             External_Name => "gdk_pixbuf_get_byte_length";
   begin
      if Background = Rev.NO_REVISION then
         Render ((1 .. 0 => 0), 1, False);
      elsif Length (S.Disk_Pixels (Background)) /= 0 then
         declare
            E : constant Doc.Rectangle := Rev.Extent (S.Document, Background);
            Data : Ada.Strings.Unbounded.Aux.Big_String_Access;
            Size : Natural;
         begin
            Ada.Strings.Unbounded.Aux.Get_String
              (S.Disk_Pixels (Background), Data, Size);
            declare
               Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Size))
                 with Import, Address => Data (1)'Address;
            begin
               Render (Bytes, E.Right * 4, True);
            end;
         end;
      else
         declare
            Pixbuf : constant Gdk.Pixbuf.Gdk_Pixbuf :=
              S.Images (Background).Pixels;
         begin
            if Pixbuf = null then
               raise Composite.Render_Error with "Missing Canvas raster asset";
            end if;
            declare
               Data : constant System.Address := Read_Pixels (Pixbuf.Get_Object);
               Size : constant Interfaces.C.size_t := Byte_Length (Pixbuf.Get_Object);
               Stride : constant Glib.Gint := Gdk.Pixbuf.Get_Rowstride (Pixbuf);
            begin
               if Data = System.Null_Address or else Size = 0
                 or else Size > Interfaces.C.size_t (MAX_IMAGE_BYTES)
                 or else Stride <= 0
               then
                  raise Composite.Render_Error with "Invalid Canvas raster asset";
               end if;
               declare
                  --  Borrow the owned, immutable source only for Render.
                  Bytes : Stream_Element_Array
                    (1 .. Stream_Element_Offset (Size))
                    with Import, Address => Data;
               begin
                  Render
                    (Bytes, Positive (Stride),
                     Gdk.Pixbuf.Get_Has_Alpha (Pixbuf));
               end;
            end;
         end;
      end if;
   end With_Background;

   procedure Compose
     (S : Instance; Id : Rev.Revision_Id;
      Image : in out Coyote_Canvas.Composite.Image; Include_Ink : Boolean)
   is
      package Composite renames Coyote_Canvas.Composite;

      procedure Render
        (Bytes : Ada.Streams.Stream_Element_Array; Stride : Positive;
         Has_Alpha : Boolean)
      is
      begin
         if Bytes'Length = 0 then
            Composite.Render (S.Document, Id, Image, Include_Ink);
         else
            Composite.Render
              (S.Document, Id, Bytes, Stride, Has_Alpha, Image, Include_Ink);
         end if;
      end Render;
   begin
      With_Background (S, Id, Render'Access);
   end Compose;

   procedure Update_Live_Erase (S : in out Instance; Id : Rev.Revision_Id)
   is
      package Composite renames Coyote_Canvas.Composite;

      procedure Render
        (Bytes : Ada.Streams.Stream_Element_Array; Stride : Positive;
         Has_Alpha : Boolean)
      is
      begin
         if Bytes'Length = 0 then
            Composite.Update_Erase
              (S.Live_Erase, S.Document, Id, S.Stroke_Points);
         else
            Composite.Update_Erase
              (S.Live_Erase, S.Document, Id, S.Stroke_Points,
               Bytes, Stride, Has_Alpha);
         end if;
      end Render;
   begin
      With_Background (S, Id, Render'Access);
   exception
      when Composite.Render_Error | Coyote_Canvas.Images.Invalid_Buffer
         | Storage_Error =>
         --  Keep the canonical display and guide usable for this stroke.
         Composite.Clear (S.Live_Erase);
         S.Erase_Preview_Failed := True;
         Set_Status (S, "Live erase preview unavailable for this stroke.");
   end Update_Live_Erase;

   procedure Freeze_Attachments (S : aliased in out Instance) is
      package Composite renames Coyote_Canvas.Composite;
      Images : LLM.Types.User_Images.Vector;
      Ids : array (1 .. LLM.User_Images.Max_Count) of Rev.Revision_Id;
      Count : Natural := 0;
      Total : Natural := 0;
      Selection : constant Gtk.Tree_Selection.Gtk_Tree_Selection :=
        S.Drawing_Tree.Get_Selection;
      Is_Draft : constant Boolean := S.Editing_Draft and then
        (Selection.Count_Selected_Rows = 0 or else
         Has_Drawing_Focus (S));
      TOO_LARGE : constant String :=
        "Image is too large to attach. Crop it and try again.";

      function Fits_Attachment (Id : Rev.Revision_Id) return Boolean is
         E : constant Doc.Rectangle := Rev.Extent (S.Document, Id);
      begin
         return LLM.User_Images.Fits_Geometry
           (E.Right - E.Left, E.Bottom - E.Top);
      end Fits_Attachment;
   begin
      if not Can_Attach (S) then
         return;
      end if;
      if Is_Draft then
         if not S.Has_Drawing then
            return;
         elsif not Fits_Attachment (Rev.NO_REVISION) then
            Set_Status (S, TOO_LARGE);
            return;
         end if;
         Rev.Save (S.Document);
         Mark_Dirty (S);
         Extend_Tree (S);
         Refresh (S);
         Count := 1;
         Ids (Count) := Rev.Base (S.Document);
      else
         --  Rows are appended in sibling order, not traversal order.
         --  GTK supplies paths in tree order, independent of click order.
         declare
            Model : TM.Gtk_Tree_Model;
            use TM.Gtk_Tree_Path_List;
            Paths, Cursor : Glist;
         begin
            if Selection.Count_Selected_Rows > Glib.Gint (Ids'Length) then
               Set_Status (S, "Attach at most eight revisions at a time.");
               return;
            end if;
            Selection.Get_Selected_Rows (Model, Paths);
            Cursor := Paths;
            while Cursor /= Null_List loop
               declare
                  Path : constant TM.Gtk_Tree_Path := Get_Data (Cursor);
                  Iter : constant TM.Gtk_Tree_Iter := TM.Get_Iter (Model, Path);
               begin
                  Count := Count + 1;
                  Ids (Count) := Rev.Revision_Id (TM.Get_Int (Model, Iter, 1));
                  TM.Path_Free (Path);
                  Cursor := Next (Cursor);
               end;
            end loop;
            Free (Paths);
         end;
         for I in 1 .. Count loop
            if not Fits_Attachment (Ids (I)) then
               Set_Status (S, TOO_LARGE);
               return;
            end if;
         end loop;
      end if;
      for I in 1 .. Count loop
         declare
            Id : constant Rev.Revision_Id := Ids (I);
            Original : Rev.Revision_Id := Id;
            Image : Composite.Image;
            Snapshot : LLM.Types.User_Image;
         begin
            while Rev.Parent (S.Document, Original) /= Rev.NO_REVISION loop
               Original := Rev.Parent (S.Document, Original);
            end loop;
            declare
               Label : constant String := Rev.Original_Label (S.Document, Original);
            begin
               Snapshot.Label := To_Unbounded_String
                 ((if Label /= "" then Label else "Drawing" &
                   Rev.Revision_Id'Image (Original)) &
                  (if Id = Original then " (Original)" else
                   " / Revision" & Rev.Revision_Id'Image (Id)));
            end;
            if Total >= LLM.User_Images.Max_Turn then
               raise Composite.PNG_Limit_Error;
            end if;
            Compose (S, Id, Image, Include_Ink => True);
            Snapshot.PNG := Composite.Encode_PNG
              (Image, Positive'Min (Composite.MAX_PNG_BYTES,
                                    LLM.User_Images.Max_Turn - Total));
            Total := Total + Length (Snapshot.PNG);
            Snapshot.Width := Composite.Width (Image);
            Snapshot.Height := Composite.Height (Image);
            Snapshot.Drawing_Id := To_Unbounded_String (Rev.Drawing_Key (S.Document, Id));
            Snapshot.Revision_Id := To_Unbounded_String (Rev.Revision_Key (S.Document, Id));
            Images.Append (Snapshot);
         end;
      end loop;
      if not Images.Is_Empty then
         if Length (S.Parent) /= 0 and then not Flush (S) then
            Set_Status (S, "Cannot save the attachment revisions; retry Canvas Save.");
         elsif not S.On_Attach (Images) then
            Set_Status (S, "Could not stage this batch in the prompt composer.");
         else
            Set_Status (S, "Native-size images attached to the prompt draft.");
         end if;
      end if;
   exception
      when Composite.PNG_Limit_Error =>
         Set_Status (S, "Canvas PNG limit reached; no images attached.");
      when others =>
         Set_Status (S, "Could not freeze Canvas images; no images attached.");
   end Freeze_Attachments;

   procedure Update_Display (S : in out Instance; Id : Rev.Revision_Id) is
      package Composite renames Coyote_Canvas.Composite;
      Image : Composite.Image;
   begin
      if S.Image_Surface /= Cairo.Null_Surface
        and then S.Cached_Revision = Id and then S.Cached_Ink = S.Show_Ink
      then
         return;
      end if;
      Clear_Display (S);
      Compose (S, Id, Image, S.Show_Ink);
      S.Image_Surface := Composite.Display_Surface (Image);
      S.Cached_Revision := Id;
      S.Cached_Ink := S.Show_Ink;
   end Update_Display;

   function On_Draw
     (Area    : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context : Cairo.Cairo_Context; S : Instance_Access) return Boolean
   is
      pragma Unreferenced (Area);
      E        : constant Doc.Rectangle   := Display_Extent (S.all);
      Region   : constant Doc.Rectangle   := Pending (S.all);
      Revision : constant Rev.Revision_Id :=
        (if S.Editing_Draft then Rev.NO_REVISION else S.Preview_Revision);
      Live : Cairo.Cairo_Surface := Cairo.Null_Surface;
   begin
      if not Doc.Is_Nonempty (E) then
         return False;
      end if;
      if S.Drawing and then S.Gesture_Operation = Rev.Erase
        and then Can_Draw (S.all) and then not S.Erase_Preview_Failed
      then
         Update_Live_Erase (S.all, Revision);
         Live := Coyote_Canvas.Composite.Surface (S.Live_Erase);
      end if;
      begin
         if Live = Cairo.Null_Surface then
            Update_Display (S.all, Revision);
         end if;
      exception
         when Coyote_Canvas.Composite.Render_Error
            | Coyote_Canvas.Images.Invalid_Buffer
            | Storage_Error =>
            Set_Status (S.all, "Canvas display could not be rendered.");
            return False;
      end;
      Cairo.Save (Context);
      Cairo.Scale (Context, Glib.Gdouble (S.Zoom), Glib.Gdouble (S.Zoom));
      Outline (Context, Doc.Full_Extent (E.Right - E.Left, E.Bottom - E.Top));
      Cairo.Clip (Context);
      Cairo.Set_Source_Rgb (Context, 1.0, 1.0, 1.0);
      Cairo.Paint (Context);
      Cairo.Set_Source_Surface
        (Context, (if Live = Cairo.Null_Surface then S.Image_Surface
                   else Live), 0.0, 0.0);
      Cairo.Paint (Context);
      if S.Show_Ink and then S.Drawing then
         declare
            package Ink renames Coyote_Canvas.Ink;
         begin
            if S.Gesture_Operation = Rev.Paint then
               Ink.Set_Color (Context, S.Gesture_Color);
               Ink.Draw (S.Stroke_Points, Context, Rev.Deposited);
            else
               --  A cursor guide, not part of the canonical pixels.
               declare
                  Point : constant Rev.Sample := S.Stroke_Points.Last_Element;
               begin
                  Cairo.Arc (Context, Glib.Gdouble (Point.X),
                             Glib.Gdouble (Point.Y),
                             Glib.Gdouble (Point.Width / 2.0),
                             0.0, 6.283_185_307_179_586);
                  Cairo.Set_Line_Width (Context, Glib.Gdouble (2.0 / S.Zoom));
                  Cairo.Set_Source_Rgb (Context, 1.0, 1.0, 1.0);
                  Cairo.Stroke_Preserve (Context);
                  Cairo.Set_Line_Width (Context, Glib.Gdouble (1.0 / S.Zoom));
                  Cairo.Set_Source_Rgb (Context, 0.15, 0.32, 0.70);
                  Cairo.Stroke (Context);
               end;
            end if;
         end;
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

   STYLUS_ZOOM_IN  : constant Glib.Guint := 2;
   STYLUS_ZOOM_OUT : constant Glib.Guint := 3;

   function Has_Input_Source
     (Event : Gdk.Event.Gdk_Event; Kind : Gdk.Types.Gdk_Input_Source)
      return Boolean
   is
      --  The event's master pointer can be a mouse even when a pen sent it.
      function Source_Device (E : Gdk.Event.Gdk_Event) return System.Address
        with Import, Convention => C,
          External_Name => "gdk_event_get_source_device";
      --  GTK 3 has source values (e.g. tablet-pad) absent from GtkAda's enum.
      function Input_Source (Device : System.Address) return Glib.Gint
        with Import, Convention => C, External_Name => "gdk_device_get_source";
      Source : constant System.Address := Source_Device (Event);
   begin
      return Source /= System.Null_Address
        and then Input_Source (Source) = Gdk.Types.Gdk_Input_Source'Pos (Kind);
   end Has_Input_Source;

   function Is_Stylus_Zoom_Button
     (Event : Gdk.Event.Gdk_Event; Button : Glib.Guint) return Boolean is
     (Button in STYLUS_ZOOM_IN | STYLUS_ZOOM_OUT
      and then not Gdk.Event.Get_Pointer_Emulated (Event)
      and then Has_Input_Source (Event, Gdk.Types.Source_Pen));

   function Pointer_Alpha (S : Instance; Event : Gdk.Event.Gdk_Event)
     return Rev.Ink_Alpha
   is
      Pressure : Glib.Gdouble;
   begin
      if S.Gesture_Operation = Rev.Paint
        and then Has_Input_Source (Event, Gdk.Types.Source_Pen)
        and then Read_Axis (Event, Gdk.Types.Axis_Pressure, Pressure) /= 0
        and then Pressure in 0.0 .. 1.0
      then
         return Rev.Ink_Alpha (Pressure);
      end if;
      return 1.0;
   end Pointer_Alpha;

   procedure Begin_Ink (S : in out Instance; Tool : Ink_Tool) is
      Control : constant Gtk.Spin_Button.Gtk_Spin_Button := S.Brush_Size (Tool);
   begin
      S.Gesture_Color := S.Ink_Color;
      S.Gesture_Operation := (if Tool = Eraser then Rev.Erase else Rev.Paint);
      S.Gesture_Width := Long_Float (Control.Get_Value_As_Int);
   end Begin_Ink;

   procedure Add_Point
     (S : in out Instance; X, Y : Glib.Gdouble; Alpha : Rev.Ink_Alpha := 1.0)
   is
      E : constant Doc.Rectangle := Display_Extent (S);
      PX : constant Long_Float := Long_Float (X) / S.Zoom;
      PY : constant Long_Float := Long_Float (Y) / S.Zoom;
   begin
      declare
         Point : constant Rev.Sample :=
           (X => Long_Float'Max
              (0.0, Long_Float'Min (PX, Long_Float (E.Right - E.Left))),
            Y => Long_Float'Max
              (0.0, Long_Float'Min (PY, Long_Float (E.Bottom - E.Top))),
            Width => S.Gesture_Width, Alpha => Alpha);
         use type Rev.Sample;
      begin
         if not S.Stroke_Points.Is_Empty
           and then S.Stroke_Points.Last_Element = Point
         then
            return;
         end if;
         if S.Stroke_Points.Length >= 4_096 then
            raise Rev.Capacity_Error with "Canvas gesture sample limit reached";
         end if;
         S.Stroke_Points.Append (Point);
      end;
   end Add_Point;

   procedure Commit_Stroke (S : aliased in out Instance) is
   begin
      if (for some Point of S.Stroke_Points => Point.Alpha > 0.0)
        and then Prepare_Working_Copy (S)
      then
         Rev.Add_Stroke
           (S.Document, S.Stroke_Points, S.Gesture_Operation,
            S.Gesture_Color,
            (if S.Gesture_Operation = Rev.Paint then Rev.Deposited
             else Rev.Classic));
         Mark_Dirty (S);
         Clear_Display (S);
      end if;
   end Commit_Stroke;

   function On_Touch
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event; S : Instance_Access) return Boolean
   is
      Kind : constant Gdk.Event.Gdk_Event_Type :=
        Gdk.Event.Get_Event_Type (Event);
      Sequence : constant Gdk.Event.Gdk_Event_Sequence :=
        Gdk.Event.Get_Event_Sequence (Event);
      X, Y : Glib.Gdouble;
   begin
      if Kind = Gdk.Event.Touch_Begin and then S.Help_Mode then
         Disable_Click_Help (S.all);
         Open_Help (S.all, "canvas-editing");
         return True;
      end if;
      if S.Finger_Sequence /= null and then Sequence = S.Finger_Sequence then
         if not Can_Edit_With_Finger (S.all)
           or else Kind = Gdk.Event.Touch_Cancel
         then
            Cancel_Gesture (S.all);
         elsif Kind in Gdk.Event.Touch_Update | Gdk.Event.Touch_End then
            if Read_Coords (Event, X, Y) /= 0 then
               Add_Point (S.all, X, Y);
            end if;
            if Kind = Gdk.Event.Touch_End then
               Commit_Stroke (S.all);
               Cancel_Gesture (S.all);
            end if;
         end if;
         Refresh (S.all);
         return True;
      end if;
      --  Extra contacts cannot take over an existing or canceled stroke.
      if Can_Edit_With_Finger (S.all)
        and then Kind = Gdk.Event.Touch_Begin and then Sequence /= null
        and then not (S.Drawing or else S.Crop_Drag or else S.Anchor_Pending)
        and then Read_Coords (Event, X, Y) /= 0
      then
         Widget.Grab_Focus;
         Begin_Ink (S.all, Ink_Tool (S.Tool));
         Add_Point (S.all, X, Y);
         S.Finger_Sequence := Sequence;
         S.Drawing := True;
         Refresh (S.all);
      end if;
      --  A declined touch would otherwise reach GTK's default handler,
      --  which can synthesize mouse events. The scroller has already had
      --  its capture-phase opportunity when kinetic scrolling is enabled.
      return True;
   exception
      when Rev.Capacity_Error =>
         Cancel_Gesture (S.all);
         Set_Status (S.all, "Canvas capacity reached; stroke discarded");
         Refresh (S.all);
         return True;
   end On_Touch;

   procedure Drag_Crop (S : in out Instance; X, Y : Long_Float) is
      E    : constant Doc.Rectangle := Display_Extent (S);
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
      Button : constant Glib.Guint := Gdk.Event.Get_Button (Event);
      Kind : constant Gdk.Event.Gdk_Event_Type :=
        Gdk.Event.Get_Event_Type (Event);
      X, Y : Glib.Gdouble;
   begin
      if Is_Stylus_Zoom_Button (Event, Button) then
         --  GTK can emit a double/triple-click event after the actual press.
         if Kind = Gdk.Event.Button_Press and then not S.Help_Mode
           and then Read_Coords (Event, X, Y) /= 0
         then
            Zoom_Over_Drawing (S.all, X, Y,
                               Increase => Button = STYLUS_ZOOM_IN);
         end if;
         return True;
      end if;
      if S.Drawing or else S.Crop_Drag
        or else Gdk.Event.Get_Pointer_Emulated (Event)
        or else Kind /= Gdk.Event.Button_Press
        or else Button /= 1
        or else Read_Coords (Event, X, Y) = 0
      then
         return False;
      end if;
      if S.Zoom_Tool /= No_Zoom then
         Zoom_Over_Drawing (S.all, X, Y, Increase => S.Zoom_Tool = Magnify);
         return True;
      end if;
      if not Can_Draw (S.all) then
         return False;
      end if;
      Widget.Grab_Focus;
      if Cropping (S.all) then
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
         declare
            Tool : constant Gdk.Device_Tool.Gdk_Device_Tool :=
              Gdk.Event.Get_Device_Tool (Event);
         begin
            Begin_Ink
              (S.all, (if S.Tool = Eraser
                 or else Has_Input_Source (Event, Gdk.Types.Source_Eraser)
                 or else (Tool /= null and then Tool.Get_Tool_Type =
                    Gdk.Device_Tool.Gdk_Device_Tool_Type_Eraser)
               then Eraser else Pencil));
         end;
         Add_Point (S.all, X, Y, Alpha => Pointer_Alpha (S.all, Event));
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
        or else S.Finger_Sequence /= null
        or else Gdk.Event.Get_Pointer_Emulated (Event)
        or else Read_Coords (Event, X, Y) = 0
      then
         return False;
      end if;
      if S.Crop_Drag then
         Drag_Crop (S.all, Long_Float (X) / S.Zoom, Long_Float (Y) / S.Zoom);
      else
         Add_Point (S.all, X, Y, Alpha => Pointer_Alpha (S.all, Event));
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
      Button : constant Glib.Guint := Gdk.Event.Get_Button (Event);
      X, Y : Glib.Gdouble;
   begin
      if Is_Stylus_Zoom_Button (Event, Button) then
         return True;
      end if;
      if Button /= 1 or else S.Finger_Sequence /= null
        or else Gdk.Event.Get_Pointer_Emulated (Event)
        or else not (S.Drawing or else S.Crop_Drag)
      then
         return False;
      end if;
      if S.Drawing then
         if S.Gesture_Operation = Rev.Erase
           and then Read_Coords (Event, X, Y) /= 0
         then
            Add_Point (S.all, X, Y);
         end if;
         Commit_Stroke (S.all);
      elsif Read_Coords (Event, X, Y) /= 0 then
         Drag_Crop (S.all, Long_Float (X) / S.Zoom, Long_Float (Y) / S.Zoom);
      end if;
      S.Drawing := False;
      S.Stroke_Points.Clear;
      Coyote_Canvas.Composite.Clear (S.Live_Erase);
      S.Erase_Preview_Failed := False;
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
      if S.Help_Mode and then
        (not Is_Key or else
         Gdk.Event.Get_Key_Val (Event) = Gdk.Types.Keysyms.GDK_Escape)
      then
         Disable_Click_Help (S.all);
         return Is_Key;
      end if;
      if Is_Key and then S.Zoom_Tool /= No_Zoom
        and then Gdk.Event.Get_Key_Val (Event) = Gdk.Types.Keysyms.GDK_Escape
      then
         Leave_Zoom_Tool (S.all);
         Refresh (S.all);
         Set_Status (S.all, "Zoom tool inactive.");
         return True;
      end if;
      if (S.Crop_Drag or else S.Drawing
          or else (Is_Key and then Cropping (S.all)))
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
