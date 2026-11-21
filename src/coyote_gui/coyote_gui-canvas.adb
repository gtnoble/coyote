with Ada.Streams;
with Coyote_Canvas.Composite;
with Coyote_Canvas.Images;
with Coyote_Canvas.Ink;
with Interfaces.C;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Coyote_Canvas.Rasters;
with Coyote_GUI.Canvas_Import_Jobs;
with Gdk.Property;
with Glib.Object;
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
   package Raster renames Coyote_Canvas.Rasters;
   package Jobs renames Coyote_GUI.Canvas_Import_Jobs;
   use type Cairo.Cairo_Surface;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Gdk.Types.Gdk_Atom;
   use type Gtk.Dialog.Gtk_Response_Type;
   use type Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
   use type Gtk.Message_Dialog.Gtk_Message_Dialog;
   use type Gtk.Widget.Gtk_Widget;
   use type Raster.Format;
   use type System.Address;
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

   procedure Invalidate (S : Instance; Paste_Only : Boolean := False) is
   begin
      for R of Requests loop
         if R.Owner /= null and then R.Owner.all'Address = S'Address
           and then (not Paste_Only or else R.Origin = Clipboard_Image)
         then
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
               (if Ancestor /= 0 then "Revision" & Natural'Image (Id)
                else (case S.Images (Id).Origin is
                      when Clipboard_Image => "Clipboard Image",
                      when File_Image => "Imported Image",
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

   procedure Import_Complete
     (Token : System.Address; Pixels : Jobs.Image_List; Error : String)
   is
      I : constant Request_Index := Find_Request (Token);
      S : Instance_Access;
      Origin : Image_Origin;
      Sizes : Rev.Image_Sizes (Pixels'Range);
      First : Rev.Revision_Id;
      Remaining : Natural;
   begin
      if I = 0 then
         return;
      end if;
      S := Requests (I).Owner;
      Origin := Requests (I).Origin;
      Requests (I) := (others => <>);
      if S = null then
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
            Stride : constant Positive := Positive (Gdk.Pixbuf.Get_Rowstride (Image));
         begin
            if Height > Remaining / Stride then
               Report_Import_Error (S, "Canvas image memory limit reached.");
               return;
            end if;
            Remaining := Remaining - Height * Stride;
            Sizes (J) := (Width, Height);
         end;
      end loop;
      Rev.Add_Originals (S.Document, Sizes, First);
      for J in Pixels'Range loop
         Pixels (J).Ref;
         S.Images (First + (J - Pixels'First)) :=
           (Pixels => Pixels (J), Origin => Origin);
      end loop;
      S.Image_Bytes := MAX_IMAGE_BYTES - Remaining;
      Extend_Tree (S.all);
      Refresh (S.all);
      Set_Status
        (S.all, (if Pixels'Length = 1 then "Image added to Drawings at its original size."
                 else "Images added to Drawings at their original sizes."));
   exception
      when Rev.Capacity_Error =>
         Report_Import_Error (S, "Canvas revision limit reached.");
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
      Item        := Action ("_Import...", "import");
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
      Item          := Action ("_Paste", "paste", Gdk.Types.Keysyms.GDK_LC_v);
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

   procedure Clear_Display (S : in out Instance) is
   begin
      if S.Image_Surface /= Cairo.Null_Surface then
         Cairo.Surface_Destroy (S.Image_Surface);
         S.Image_Surface := Cairo.Null_Surface;
      end if;
   end Clear_Display;

   procedure Reset (S : in out Instance) is
   begin
      S.Resetting := True;
      Invalidate (S);
      Destroy_Import_Dialogs (S);
      Clear_Display (S);
      for Asset of S.Images loop
         if Asset.Pixels /= null then
            Asset.Pixels.Unref;
            Asset := (others => <>);
         end if;
      end loop;
      S.Image_Bytes := 0;
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
         Clear_Display (S.all);
         S.Has_Drawing := True;
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
      if S /= null and then S.Editing_Draft and then not S.Crop_Mode then
         Coyote_Canvas.Revisions.Redo (S.Document);
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
         Cancel_Gesture (S.all);
         Refresh (S.all);
         Invalidate (S.all);
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
      elsif Name = "canvas-import" then
         Choose_File (S);
      elsif Name = "canvas-paste" then
         Paste (S);
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

   procedure Outline (Context : Cairo.Cairo_Context; R : Doc.Rectangle) is
   begin
      Cairo.Rectangle
        (Context, Glib.Gdouble (R.Left), Glib.Gdouble (R.Top),
         Glib.Gdouble (R.Right - R.Left), Glib.Gdouble (R.Bottom - R.Top));
   end Outline;

   procedure Update_Display (S : in out Instance; Id : Rev.Revision_Id) is
      use Ada.Streams;
      use type Interfaces.C.size_t;
      package Composite renames Coyote_Canvas.Composite;
      Background : constant Rev.Revision_Id := Rev.Background (S.Document, Id);
      Image : Composite.Image;

      function Read_Pixels (Pixbuf : System.Address) return System.Address
        with Import, Convention => C,
             External_Name => "gdk_pixbuf_get_pixels";
      function Byte_Length (Pixbuf : System.Address) return Interfaces.C.size_t
        with Import, Convention => C,
             External_Name => "gdk_pixbuf_get_byte_length";
   begin
      if S.Image_Surface /= Cairo.Null_Surface
        and then S.Cached_Revision = Id and then S.Cached_Ink = S.Show_Ink
      then
         return;
      end if;
      Clear_Display (S);
      if Background = Rev.NO_REVISION then
         Composite.Render (S.Document, Id, Image, S.Show_Ink);
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
                  Composite.Render
                    (S.Document, Id, Bytes, Positive (Stride),
                     Gdk.Pixbuf.Get_Has_Alpha (Pixbuf), Image, S.Show_Ink);
               end;
            end;
         end;
      end if;
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
   begin
      if not Doc.Is_Nonempty (E) then
         return False;
      end if;
      begin
         Update_Display (S.all, Revision);
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
      Cairo.Set_Source_Surface (Context, S.Image_Surface, 0.0, 0.0);
      Cairo.Paint (Context);
      if S.Show_Ink and then S.Drawing then
         declare
            package Ink renames Coyote_Canvas.Ink;
            Shade : constant Glib.Gdouble := Glib.Gdouble (Ink.CHANNEL) / 255.0;
         begin
            Cairo.Set_Source_Rgb (Context, Shade, Shade, Shade);
            Ink.Draw (S.Stroke_Points, Context);
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
         Clear_Display (S.all);
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
