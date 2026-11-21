with Coyote_Canvas.Document;
with Coyote_Canvas.Revisions;
with Cairo;
with Gdk.Pixbuf;
with Gtk.Box;
with Gtk.File_Chooser_Dialog;
with Gtk.Message_Dialog;
with Gtk.Button;
with Gtk.Drawing_Area;
with Gtk.Grid;
with Gtk.Label;
with Gtk.GEntry;
with Gtk.Tree_View;
with Gtk.Tree_Store;
with Gtk.Tree_Model;
with Gtk.Menu_Item;
with Gtk.Window;

--  A modeless, in-memory drawing workspace. Show creates the window
--  lazily and reuses it; Reset discards the document and hides it. GTK
--  operations belong to the GTK main task. Imports are not persisted.
package Coyote_GUI.Canvas is
   type Instance is limited private;

   procedure Show
     (S      : aliased in out Instance;
      Parent :            not null access Gtk.Window.Gtk_Window_Record'Class);
   procedure Reset (S : in out Instance);
   procedure Destroy (S : in out Instance);
   function Window (S : Instance) return Gtk.Window.Gtk_Window;
   function Revision_Count (S : Instance) return Natural;

private
   type Iter_Array is
     array (Positive range 1 .. Coyote_Canvas.Revisions.MAX_REVISIONS)
       of Gtk.Tree_Model.Gtk_Tree_Iter;

   type Image_Origin is (Blank, Clipboard_Image, File_Image);
   type Image_Asset is record
      Pixels : Gdk.Pixbuf.Gdk_Pixbuf := null;
      Origin : Image_Origin := Blank;
   end record;
   type Image_Array is array (Iter_Array'Range) of Image_Asset;

   type Instance is limited record
      Canvas_Window : Gtk.Window.Gtk_Window               := null;
      Root                                         : Gtk.Box.Gtk_Box := null;
      Drawing_Area : Gtk.Drawing_Area.Gtk_Drawing_Area   := null;
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
      Image_Bytes : Natural := 0;
      Cached_Revision : Coyote_Canvas.Revisions.Revision_Id := 0;
      Cached_Ink : Boolean := True;
      Image_Surface : Cairo.Cairo_Surface := Cairo.Null_Surface;
      File_Selection : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
      Import_Error : Gtk.Message_Dialog.Gtk_Message_Dialog;
      Store : Gtk.Tree_Store.Gtk_Tree_Store       := null;
      Rows                                         : Iter_Array;
      Resetting : Boolean := False;
      Listed                                       : Natural := 0;
      Save_Item, Edit_Item, Draft_Item, Crop_Item, Undo_Item,
      Redo_Item : Gtk.Menu_Item.Gtk_Menu_Item         := null;
      Apply_Item, Cancel_Item : Gtk.Menu_Item.Gtk_Menu_Item         := null;
      Preview_Revision : Coyote_Canvas.Revisions.Revision_Id := 0;
      Editing_Draft                                : Boolean := True;
      Has_Drawing                                  : Boolean := False;
      Show_Ink                                     : Boolean := True;
      Zoom                                         : Long_Float := 1.0;
      Drawing                                      : Boolean := False;
      Crop_Mode                                    : Boolean := False;
      Crop_Drag                                    : Boolean := False;
      Crop_X1                                      : Long_Float := 0.0;
      Crop_Y1                                      : Long_Float := 0.0;
      Crop_Start : Coyote_Canvas.Document.Rectangle;
      Move_Crop                                    : Boolean := False;
      Drag_Left, Drag_Right, Drag_Top, Drag_Bottom : Boolean := False;
      Stroke_Points : Coyote_Canvas.Revisions.Samples.Vector;
   end record;
end Coyote_GUI.Canvas;
