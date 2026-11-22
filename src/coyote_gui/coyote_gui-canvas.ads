with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Coyote_Canvas.Store;
with Coyote_Canvas.Import_Service;
with Coyote_GUI.Canvas_Recovery_Jobs;
with Glib.Main;
with Coyote_Canvas.Composite;
with Coyote_Canvas.Document;
with Coyote_Canvas.Revisions;
with Cairo;
with Gdk.Event;
with Gdk.Pixbuf;
with Gtk.Check_Menu_Item;
with Gtk.Box;
with Gtk.File_Chooser_Dialog;
with Gtk.Message_Dialog;
with Gtk.Button;
with Gtk.Color_Button;
with Gtk.Spin_Button;
with Gtk.Drawing_Area;
with Gtk.Grid;
with Gtk.Label;
with Gtk.GEntry;
with Gtk.Tree_View;
with Gtk.Tree_Store;
with Gtk.Tree_Model;
with Gtk.Menu_Item;
with Gtk.Radio_Button;
with Gtk.Radio_Menu_Item;
with Gtk.Scrolled_Window;
with Gtk.Window;
with LLM.Types;

--  A modeless workspace. Only the GTK task accesses the instance.
package Coyote_GUI.Canvas is
   type Instance is limited private;

   procedure Show
     (S      : aliased in out Instance;
      Parent :            not null access Gtk.Window.Gtk_Window_Record'Class);
   type Attach_Handler is access function
     (Images : LLM.Types.User_Images.Vector) return Boolean;
   procedure Set_Attach_Handler (S : in out Instance; Handler : Attach_Handler);
   type Product_Handler is access procedure (Parent : Gtk.Window.Gtk_Window);
   procedure Set_Product_Handler (S : in out Instance; Handler : Product_Handler);
   procedure Reveal
     (S : aliased in out Instance;
      Parent : not null access Gtk.Window.Gtk_Window_Record'Class;
      Drawing_Id, Revision_Id : String);
   --  An empty directory selects memory-only mode. A changed binding must
   --  follow Reset. The manifest is opened lazily when Canvas is shown.
   procedure Bind (S : aliased in out Instance; Parent, UUID : String;
                   Session_File : String := "";
                   Publication : Coyote_Canvas.Import_Service.Binding_Access := null);
   function Flush (S : in out Instance) return Boolean;
   procedure Suspend (S : in out Instance; Value : Boolean);
   procedure Reset (S : in out Instance);
   procedure Destroy (S : in out Instance);
   function Window (S : Instance) return Gtk.Window.Gtk_Window;
   function Revision_Count (S : Instance) return Natural;

private
   type Iter_Array is
     array (Positive range 1 .. Coyote_Canvas.Revisions.MAX_REVISIONS)
       of Gtk.Tree_Model.Gtk_Tree_Iter;

   type Image_Origin is (Blank, Clipboard_Image, File_Image, Agent_Image);
   type Image_Asset is record
      Pixels : Gdk.Pixbuf.Gdk_Pixbuf := null;
      Origin : Image_Origin := Blank;
   end record;
   type Image_Array is array (Iter_Array'Range) of Image_Asset;

   type Tool_Kind is (Pencil, Eraser, Crop, Zoom_In, Zoom_Out);
   subtype Editing_Tool is Tool_Kind range Pencil .. Crop;
   subtype Ink_Tool is Editing_Tool range Pencil .. Eraser;
   type Zoom_Mode is (No_Zoom, Magnify, Reduce);
   type Brush_Controls is array (Ink_Tool) of Gtk.Spin_Button.Gtk_Spin_Button;

   type Tool_Buttons is array (Tool_Kind) of Gtk.Radio_Button.Gtk_Radio_Button;
   type Tool_Items is array (Editing_Tool) of
     Gtk.Radio_Menu_Item.Gtk_Radio_Menu_Item;

   type Instance is limited record
      On_Product : Product_Handler := null;
      Help_Mode : Boolean := False;
      Tool              : Editing_Tool := Pencil;
      Zoom_Tool         : Zoom_Mode := No_Zoom;
      Previous_Ink_Tool : Ink_Tool := Pencil;
      Buttons           : Tool_Buttons := (others => null);
      Tool_Menu         : Tool_Items := (others => null);
      Syncing_Tools     : Boolean := False;
      Tool_Label        : Gtk.Label.Gtk_Label := null;
      Pencil_Color      : Gtk.Color_Button.Gtk_Color_Button := null;
      Brush_Size        : Brush_Controls := (others => null);
      Gesture_Width     : Long_Float := 3.0;
      Ink_Color         : Coyote_Canvas.Revisions.Ink_Color :=
        Coyote_Canvas.Revisions.DEFAULT_INK_COLOR;
      Gesture_Color     : Coyote_Canvas.Revisions.Ink_Color :=
        Coyote_Canvas.Revisions.DEFAULT_INK_COLOR;
      Gesture_Operation : Coyote_Canvas.Revisions.Ink_Operation :=
        Coyote_Canvas.Revisions.Paint;
      Canvas_Window : Gtk.Window.Gtk_Window               := null;
      Root                                         : Gtk.Box.Gtk_Box := null;
      Drawing_Area : Gtk.Drawing_Area.Gtk_Drawing_Area   := null;
      Viewport : Gtk.Scrolled_Window.Gtk_Scrolled_Window := null;
      Drawing_Tree : Gtk.Tree_View.Gtk_Tree_View         := null;
      Status : Gtk.Label.Gtk_Label                 := null;
      Crop_Grid                                    : Gtk.Grid.Gtk_Grid := null;
      X_Field : Gtk.GEntry.Gtk_Entry                := null;
      Y_Field : Gtk.GEntry.Gtk_Entry                := null;
      Width_Field : Gtk.GEntry.Gtk_Entry                := null;
      Height_Field : Gtk.GEntry.Gtk_Entry                := null;
      Apply_Crop : Gtk.Button.Gtk_Button               := null;
      Cancel_Crop : Gtk.Button.Gtk_Button               := null;
      Document : Coyote_Canvas.Revisions.Workspace;
      Images : Image_Array;
      Parent, UUID, Session_File : Ada.Strings.Unbounded.Unbounded_String;
      Disk_Pixels : Canvas_Recovery_Jobs.Disk.Raster_Set;
      Lease : Coyote_Canvas.Store.Writer_Lease;
      Job : Canvas_Recovery_Jobs.Job_Access;
      Timer : Glib.Main.G_Source_Id := 0;
      Service : Coyote_Canvas.Import_Service.Listener;
      Publication : Coyote_Canvas.Import_Service.Binding_Access;
      Import_Timer : Glib.Main.G_Source_Id := 0;
      Import_Count : Natural := 0;
      Attach_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      Attach_Button : Gtk.Button.Gtk_Button := null;
      Attach_From_Drawing : Boolean := False;
      On_Attach : Attach_Handler;
      Reveal_Drawing, Reveal_Revision : Ada.Strings.Unbounded.Unbounded_String;
      Import_Bytes : Natural := 0;
      Import_Reply : Ada.Strings.Unbounded.Unbounded_String;
      Import_Labels : Coyote_Canvas.Import_Service.Text_List
        (1 .. Coyote_Canvas.Import_Service.MAX_FILES);
      Background_Status : Ada.Strings.Unbounded.Unbounded_String;
      Suspended, Loading, Load_Started, Writable : Boolean := False;
      Pending_Save, Save_Failed : Boolean := False;
      Save_After : Ada.Real_Time.Time := Ada.Real_Time.Time_First;
      Storage_Label : Gtk.Label.Gtk_Label := null;
      New_Item, Import_Item, Paste_Item : Gtk.Menu_Item.Gtk_Menu_Item := null;
      Image_Bytes : Natural := 0;
      Cached_Revision : Coyote_Canvas.Revisions.Revision_Id := 0;
      Cached_Ink : Boolean := True;
      Image_Surface : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Live_Erase : Coyote_Canvas.Composite.Erase_Preview;
      Erase_Preview_Failed : Boolean := False;
      File_Selection : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
      Import_Error : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Store : Gtk.Tree_Store.Gtk_Tree_Store       := null;
      Rows                                         : Iter_Array;
      Resetting : Boolean := False;
      Listed                                       : Natural := 0;
      Save_Item, Draft_Item, Undo_Item,
      Redo_Item : Gtk.Menu_Item.Gtk_Menu_Item         := null;
      Apply_Item, Cancel_Item, Fit_Item : Gtk.Menu_Item.Gtk_Menu_Item := null;
      Zoom_In_Item, Zoom_Out_Item, Actual_Item : Gtk.Menu_Item.Gtk_Menu_Item;
      Preview_Revision : Coyote_Canvas.Revisions.Revision_Id := 0;
      Editing_Draft                                : Boolean := True;
      Has_Drawing                                  : Boolean := False;
      Show_Ink                                     : Boolean := True;
      Finger_Item : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item := null;
      Edit_With_Finger : Boolean := False;
      Finger_Sequence : Gdk.Event.Gdk_Event_Sequence := null;
      Zoom              : Long_Float := 1.0;
      Anchor_Pending    : Boolean := False;
      Anchor_Scale      : Long_Float := 1.0;
      Anchor_X, Anchor_Y : Glib.Gdouble := 0.0;
      Drawing                                      : Boolean := False;
      Crop_Drag                                    : Boolean := False;
      Crop_X1                                      : Long_Float := 0.0;
      Crop_Y1                                      : Long_Float := 0.0;
      Crop_Start : Coyote_Canvas.Document.Rectangle;
      Move_Crop                                    : Boolean := False;
      Drag_Left, Drag_Right, Drag_Top, Drag_Bottom : Boolean := False;
      Stroke_Points : Coyote_Canvas.Revisions.Samples.Vector;
   end record;
end Coyote_GUI.Canvas;
