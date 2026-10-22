--  Coyote_GUI.Tool_Detail_Window body.
--
--  The modeless co-primary inspector uses independent argument/result panes.
--  All values are captured; opening it never re-reads session files.
--
--  Project: coyote

with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Coyote_App.Utils;      use Coyote_App.Utils;
with Coyote_Help;
with Coyote_Temp_Files;
with Gdk.Event;
with Gdk.Pixbuf;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Gdk.Window;
with Glib;                  use Glib;
with Glib.Error;
with Glib.Object;
with Glib.Properties;
with GNATCOLL.JSON;
with GNAT.OS_Lib;
with Gtk.Accel_Group;
with Gtk.Box;
with Gtk.Button;
with Gtk.Css_Provider;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Handlers;
with Gtk.Image;
with Gtk.Label;
with Gtk.Menu;
with Gtk.Menu_Bar;
with Gtk.Menu_Item;
with Gtk.Menu_Shell;
with Gtk.Paned;
with Gtk.Scrolled_Window;
with Gtk.Settings;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;
with Pango.Enums;
with Pango.Font;
with Pango.Layout;

package body Coyote_GUI.Tool_Detail_Window is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Gdk.Types.Gdk_Modifier_Type;
   use Pango.Enums;
   use Pango.Font;

   --  Close the inspection window containing Button.  Looking up the toplevel
   --  keeps this callback independent, so multiple detail windows coexist.
   procedure On_Close_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      Window : constant Gtk.Widget.Gtk_Widget := Button.Get_Toplevel;
   begin
      Gtk.Window.Gtk_Window (Window).Destroy;
   end On_Close_Clicked;

   procedure On_Help_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      declare
         Opened : constant Boolean := Coyote_Help.Open ("ui-conversation");
         pragma Unreferenced (Opened);
      begin
         null;
      end;
   end On_Help_Clicked;

   function On_Detail_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key)
      return Boolean
   is
      use type Gdk.Types.Gdk_Key_Type;
   begin
      if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_w
        and then (Event.State and Gdk.Types.Control_Mask) /= 0
      then
         Self.Destroy;
         return True;
      elsif Event.Keyval = Gdk.Types.Keysyms.GDK_Escape then
         Self.Destroy;
         return True;
      end if;
      return False;
   end On_Detail_Key_Press;

   System_Font_Size_Pt : Integer := 10;
   System_Font_Inited  : Boolean := False;

   procedure Ensure_System_Font_Init is
      Settings         : constant Gtk.Settings.Gtk_Settings :=
        Gtk.Settings.Get_Default;
      Font_Str         : constant String                    :=
        Glib.Properties.Get_Property
          (Settings, Gtk.Settings.Gtk_Font_Name_Property);
      Font_Description : Pango_Font_Description := From_String (Font_Str);
   begin
      System_Font_Size_Pt :=
        Integer (Get_Size (Font_Description)) / Pango_Scale;
      if System_Font_Size_Pt < 6 then
         System_Font_Size_Pt := 10;
      end if;
      System_Font_Inited := True;
      Free (Font_Description);
   exception
      when others =>
         System_Font_Size_Pt := 10;
         System_Font_Inited  := True;
   end Ensure_System_Font_Init;

   function Mono_Font_String return String is
      Size_Image : constant String := Integer'Image (System_Font_Size_Pt);
   begin
      return
        "monospace " & Size_Image (Size_Image'First + 1 .. Size_Image'Last);
   end Mono_Font_String;

   function Escape_Markup (Value : String) return String is
      Result : Unbounded_String;
   begin
      for Character_Value of Value loop
         case Character_Value is
            when '&' =>
               Append (Result, "&amp;");
            when '<' =>
               Append (Result, "&lt;");
            when '>' =>
               Append (Result, "&gt;");
            when '"' =>
               Append (Result, "&quot;");
            when others =>
               Append (Result, Character_Value);
         end case;
      end loop;
      return To_String (Result);
   end Escape_Markup;

   procedure Set_Monospace
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
      Font_Description : Pango_Font_Description;
   begin
      if not System_Font_Inited then
         Ensure_System_Font_Init;
      end if;
      Font_Description := From_String (Mono_Font_String);
      View.Modify_Font (Font_Description);
      Free (Font_Description);
   end Set_Monospace;

   procedure Add_Text_View
     (Container : not null access Gtk.Box.Gtk_Box_Record'Class;
      Value     : String;
      Name      : String)
   is
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      View   : Gtk.Text_View.Gtk_Text_View;
      Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;
   begin
      Gtk.Text_Buffer.Gtk_New (Buffer);
      Buffer.Set_Text (Value);
      Gtk.Text_View.Gtk_New (View, Buffer);
      View.Set_Name (Name);
      View.Set_Editable (False);
      View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
      View.Set_Left_Margin (8);
      View.Set_Right_Margin (8);
      Set_Monospace (View);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      --  Keep both panes usable even when the user moves the divider.
      Scroll.Set_Size_Request (-1, 36);
      Scroll.Add (View);
      Container.Pack_Start (Scroll, True, True, 0);
   end Add_Text_View;

   function Status_Text (Info : Coyote_GUI.Tool_Info) return String is
   begin
      case Info.Result_Status is
         when Coyote_GUI.Queued =>
            return "Queued";
         when Coyote_GUI.Running =>
            return "Running";
         when Coyote_GUI.Success =>
            return UC_CHECK & " success";
         when Coyote_GUI.Error =>
            return UC_CROSS & " error";
         when Coyote_GUI.Timed_Out =>
            return "! timed out";
         when Coyote_GUI.Cancelled =>
            return "- cancelled";
      end case;
   end Status_Text;

   procedure Apply_Status_Style
     (Label  : not null access Gtk.Label.Gtk_Label_Record'Class;
      Status : Coyote_GUI.Tool_Status)
   is
      use Gtk.Css_Provider;
      use Gtk.Style_Context;
      use Gtk.Style_Provider;
      CSS       : constant String :=
        (case Status is
           when Coyote_GUI.Queued =>
             "label { font-weight: bold; padding: 7px 10px; }",
           when Coyote_GUI.Running =>
             "label { font-weight: bold; padding: 7px 10px; }",
           when Coyote_GUI.Success =>
             "label { font-weight: bold; padding: 7px 10px; }",
           when Coyote_GUI.Error =>
             "label { font-weight: bold; padding: 7px 10px; }",
           when Coyote_GUI.Timed_Out =>
             "label { font-weight: bold; padding: 7px 10px; }",
           when Coyote_GUI.Cancelled =>
             "label { font-weight: bold; padding: 7px 10px; }");
      Provider  : Gtk_Css_Provider;
      CSS_Error : aliased Glib.Error.GError;
      Ignored   : Boolean;
      pragma Unreferenced (Ignored);
   begin
      Gtk_New (Provider);
      Ignored := Provider.Load_From_Data (CSS, CSS_Error'Access);
      Get_Style_Context (Label).Add_Provider
        (Implements_Gtk_Style_Provider.To_Interface (Provider),
         Guint (Priority_Application));
   end Apply_Status_Style;

   procedure Add_Header_Row
     (Grid  : not null access Gtk.Grid.Gtk_Grid_Record'Class;
      Row   : Glib.Gint;
      Name  : String;
      Value : String)
   is
      Key         : Gtk.Label.Gtk_Label;
      Value_Label : Gtk.Label.Gtk_Label;
   begin
      Gtk.Label.Gtk_New (Key);
      Key.Set_Markup ("<b>" & Escape_Markup (Name) & "</b>");
      Key.Set_Xalign (0.0);
      Grid.Attach (Key, 0, Row, 1, 1);

      Gtk.Label.Gtk_New (Value_Label, Value);
      Value_Label.Set_Xalign (0.0);
      Value_Label.Set_Name ("tool-detail-" & Name);
      Value_Label.Set_Single_Line_Mode (True);
      Value_Label.Set_Ellipsize (Pango.Layout.Ellipsize_End);
      Value_Label.Set_Width_Chars (1);
      Value_Label.Set_Hexpand (True);
      Value_Label.Set_Tooltip_Text (Value);
      Value_Label.Set_Selectable (True);
      Grid.Attach (Value_Label, 1, Row, 1, 1);
   end Add_Header_Row;

   function Format_Arguments (Arguments : String) return String is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Arguments);
      Text   : Unbounded_String;

      procedure Add_Field
        (Field_Name  : GNATCOLL.JSON.UTF8_String;
         Field_Value : GNATCOLL.JSON.JSON_Value)
      is
         Value : constant String :=
           (if Field_Value.Kind = GNATCOLL.JSON.JSON_String_Type
            then Field_Value.Get
            else Field_Value.Write);
      begin
         if not Is_Hidden_Tool_Argument (Field_Name, Field_Value) then
            Append (Text, Field_Name & ":" & ASCII.LF & Value
                    & ASCII.LF & ASCII.LF);
         end if;
      end Add_Field;
   begin
      if Arguments'Length = 0 then
         return "(no arguments)";
      elsif Parsed.Success
        and then Parsed.Value.Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         Parsed.Value.Map_JSON_Object (Add_Field'Access);
         return (if Length (Text) = 0 then "(no arguments)"
                 else To_String (Text));
      else
         return Arguments;
      end if;
   end Format_Arguments;

   function Decode_Base64 (Input : String) return String is
      function Value_Of (Character_Value : Character) return Integer is
      begin
         case Character_Value is
            when 'A' .. 'Z' =>
               return Character'Pos (Character_Value) - Character'Pos ('A');
            when 'a' .. 'z' =>
               return
                 26 + Character'Pos (Character_Value) - Character'Pos ('a');
            when '0' .. '9' =>
               return
                 52 + Character'Pos (Character_Value) - Character'Pos ('0');
            when '+' =>
               return 62;
            when '/' =>
               return 63;
            when others =>
               return -1;
         end case;
      end Value_Of;

      Maximum_Length : constant Natural := (Input'Length * 3) / 4 + 4;
      Output         : String (1 .. Maximum_Length);
      Output_Length  : Natural          := 0;
      Position       : Natural          := Input'First;
      V0, V1, V2, V3 : Integer;
   begin
      while Position + 3 <= Input'Last loop
         V0 := Value_Of (Input (Position));
         V1 := Value_Of (Input (Position + 1));
         V2 := Value_Of (Input (Position + 2));
         V3 := Value_Of (Input (Position + 3));
         if V0 >= 0 and then V1 >= 0 then
            Output_Length          := Output_Length + 1;
            Output (Output_Length) := Character'Val (V0 * 4 + V1 / 16);
         end if;
         if V2 >= 0 and then Input (Position + 2) /= '=' then
            Output_Length          := Output_Length + 1;
            Output (Output_Length) :=
              Character'Val ((V1 mod 16) * 16 + V2 / 4);
         end if;
         if V3 >= 0 and then Input (Position + 3) /= '=' then
            Output_Length          := Output_Length + 1;
            Output (Output_Length) := Character'Val ((V2 mod 4) * 64 + V3);
         end if;
         Position := Position + 4;
      end loop;
      return Output (1 .. Output_Length);
   end Decode_Base64;

   function Write_Temp_Image (Decoded : String) return String is
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Path       : Unbounded_String;
      Written    : Integer;
      pragma Unreferenced (Written);
      use type GNAT.OS_Lib.File_Descriptor;
   begin
      Coyote_Temp_Files.Create (Descriptor, Path);
      if Descriptor = GNAT.OS_Lib.Invalid_FD or else Length (Path) = 0 then
         return "";
      end if;
      Written := GNAT.OS_Lib.Write
        (Descriptor, Decoded'Address, Decoded'Length);
      GNAT.OS_Lib.Close (Descriptor);
      return To_String (Path);
   exception
      when others =>
         if Descriptor /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Descriptor);
         end if;
         Coyote_Temp_Files.Delete (To_String (Path));
         return "";
   end Write_Temp_Image;

   procedure Add_Image_Result
     (Container : not null access Gtk.Box.Gtk_Box_Record'Class; Data : String)
   is
      Decoded   : constant String := Decode_Base64 (Data);
      Temp_Path : constant String := Write_Temp_Image (Decoded);
      Pixbuf    : Gdk.Pixbuf.Gdk_Pixbuf;
      Image     : Gtk.Image.Gtk_Image;
      Error     : Glib.Error.GError;
   begin
      if Temp_Path'Length = 0 then
         Add_Text_View
           (Container, "[ image result unavailable ]",
            "tool-detail-result");
         return;
      end if;

      Gdk.Pixbuf.Gdk_New_From_File (Pixbuf, Temp_Path, Error);
      Coyote_Temp_Files.Delete (Temp_Path);
      if Pixbuf = Gdk.Pixbuf.Null_Pixbuf then
         Add_Text_View
           (Container, "[ image result could not be decoded ]",
            "tool-detail-result");
         return;
      end if;

      Gtk.Image.Gtk_New (Image, Pixbuf);
      Image.Set_Name ("tool-detail-result-image");
      Glib.Object.Unref (Glib.Object.GObject (Pixbuf));
      declare
         Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      begin
         Gtk.Scrolled_Window.Gtk_New (Scroll);
         Scroll.Set_Policy
           (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
         Scroll.Add (Image);
         Container.Pack_Start (Scroll, True, True, 0);
      end;
   exception
      when others =>
         if Temp_Path'Length > 0 and then Ada.Directories.Exists (Temp_Path)
         then
            Ada.Directories.Delete_File (Temp_Path);
         end if;
         Add_Text_View
           (Container, "[ image result could not be displayed ]",
            "tool-detail-result");
   end Add_Image_Result;

   package Widget_Actions is new Gtk.Handlers.Callback
     (Gtk.Widget.Gtk_Widget_Record);

   procedure On_Menu_Close
     (Self : access Glib.Object.GObject_Record'Class)
   is
   begin
      Gtk.Window.Gtk_Window (Self).Destroy;
   end On_Menu_Close;

   procedure On_Menu_Help
     (Self : access Gtk.Menu_Item.Gtk_Menu_Item_Record'Class)
   is
      pragma Unreferenced (Self);
   begin
      On_Help_Clicked (null);
   end On_Menu_Help;

   procedure On_Menu_Copy
     (Self : access Glib.Object.GObject_Record'Class)
   is
      Focus : constant Gtk.Widget.Gtk_Widget :=
        Gtk.Window.Gtk_Window (Self).Get_Focus;
      use type Gtk.Widget.Gtk_Widget;
   begin
      if Focus /= null
        and then (Focus.all in Gtk.Text_View.Gtk_Text_View_Record'Class
                  or else Focus.all in Gtk.Label.Gtk_Label_Record'Class)
      then
         Widget_Actions.Emit_By_Name (Focus, "copy-clipboard");
      end if;
   end On_Menu_Copy;

   procedure On_Menu_Select_All
     (Self : access Glib.Object.GObject_Record'Class)
   is
      Focus : constant Gtk.Widget.Gtk_Widget :=
        Gtk.Window.Gtk_Window (Self).Get_Focus;
      First : Gtk.Text_Iter.Gtk_Text_Iter;
      Last  : Gtk.Text_Iter.Gtk_Text_Iter;
      use type Gtk.Widget.Gtk_Widget;
   begin
      if Focus = null then
         return;
      elsif Focus.all in Gtk.Text_View.Gtk_Text_View_Record'Class then
         declare
            Buffer : constant Gtk.Text_Buffer.Gtk_Text_Buffer :=
              Gtk.Text_View.Gtk_Text_View (Focus).Get_Buffer;
         begin
            Buffer.Get_Bounds (First, Last);
            Buffer.Select_Range (First, Last);
         end;
      elsif Focus.all in Gtk.Label.Gtk_Label_Record'Class then
         declare
            Label : constant Gtk.Label.Gtk_Label :=
              Gtk.Label.Gtk_Label (Focus);
            Text : constant Wide_Wide_String :=
              Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode
                (Label.Get_Text);
         begin
            --  GTK clamps selection to the ellipsized layout's length.
            --  Select against the full layout, then restore compact display.
            Label.Set_Ellipsize (Pango.Layout.Ellipsize_None);
            Label.Select_Region (0, Glib.Gint (Text'Length));
            Label.Set_Ellipsize (Pango.Layout.Ellipsize_End);
         end;
      end if;
   end On_Menu_Select_All;

   procedure Create_Menus
     (Window : not null access Gtk.Window.Gtk_Window_Record'Class;
      Root   : not null access Gtk.Box.Gtk_Box_Record'Class)
   is
      Bar        : Gtk.Menu_Bar.Gtk_Menu_Bar;
      Accels     : Gtk.Accel_Group.Gtk_Accel_Group;
      Menu       : Gtk.Menu.Gtk_Menu;
      Item       : Gtk.Menu_Item.Gtk_Menu_Item;
      Entry_Item : Gtk.Menu_Item.Gtk_Menu_Item;

      procedure Add_Menu (Label : String) is
      begin
         Gtk.Menu.Gtk_New (Menu);
         Gtk.Menu_Item.Gtk_New_With_Mnemonic (Item, Label);
         Item.Set_Submenu (Menu);
         Gtk.Menu_Shell.Append (Gtk.Menu_Shell.Gtk_Menu_Shell (Bar), Item);
      end Add_Menu;

      procedure Add_Action
        (Label : String;
         Key   : Gdk.Types.Gdk_Key_Type;
         Call  : Gtk.Menu_Item.Cb_GObject_Void)
      is
      begin
         Gtk.Menu_Item.Gtk_New_With_Mnemonic (Entry_Item, Label);
         Entry_Item.On_Activate (Call, Window);
         Entry_Item.Add_Accelerator
           ("activate", Accels, Key, Gdk.Types.Control_Mask,
            Gtk.Accel_Group.Accel_Visible);
         Gtk.Menu_Shell.Append
           (Gtk.Menu_Shell.Gtk_Menu_Shell (Menu), Entry_Item);
      end Add_Action;
   begin
      Gtk.Accel_Group.Gtk_New (Accels);
      Window.Add_Accel_Group (Accels);
      Gtk.Menu_Bar.Gtk_New (Bar);
      Bar.Set_Name ("tool-detail-menu");
      Add_Menu ("_File");
      Add_Action ("_Close", Gdk.Types.Keysyms.GDK_LC_w,
                  On_Menu_Close'Access);
      Add_Menu ("_Edit");
      Add_Action ("_Copy", Gdk.Types.Keysyms.GDK_LC_c,
                  On_Menu_Copy'Access);
      Add_Action ("Select _All", Gdk.Types.Keysyms.GDK_LC_a,
                  On_Menu_Select_All'Access);
      Add_Menu ("_Help");
      Gtk.Menu_Item.Gtk_New_With_Mnemonic (Entry_Item, "_Overview");
      Entry_Item.On_Activate (On_Menu_Help'Access);
      Entry_Item.Add_Accelerator
        ("activate", Accels, Gdk.Types.Keysyms.GDK_F1,
         0, Gtk.Accel_Group.Accel_Visible);
      Gtk.Menu_Shell.Append
        (Gtk.Menu_Shell.Gtk_Menu_Shell (Menu), Entry_Item);
      Root.Pack_Start (Bar, False, False, 0);
   end Create_Menus;

   procedure Initialize_Divider
     (Self : access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      Paned : constant Gtk.Paned.Gtk_Paned := Gtk.Paned.Gtk_Paned (Self);
   begin
      --  Mapping has a real allocation. Never reset a user-adjusted sash.
      if not Glib.Properties.Get_Property
        (Paned, Gtk.Paned.Position_Set_Property)
      then
         Paned.Set_Position (Paned.Get_Allocated_Height * 2 / 5);
      end if;
   end Initialize_Divider;

   procedure Show
     (Info        : Coyote_GUI.Tool_Info;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class)
   is
      use Gtk.Box;
      use Gtk.Frame;
      use Gtk.Grid;
      use Gtk.Label;

      Window          : Gtk.Window.Gtk_Window;
      Root            : Gtk_Box;
      Content         : Gtk_Box;
      Panes           : Gtk.Paned.Gtk_Vpaned;
      Header          : Gtk_Grid;
      Arguments_Frame : Gtk_Frame;
      Arguments_Box   : Gtk_Box;
      Result_Frame    : Gtk_Frame;
      Result_Box      : Gtk_Box;
      Banner          : Gtk_Label;
      Button_Box      : Gtk_Box;
      Close_Button    : Gtk.Button.Gtk_Button;
      Help_Button     : Gtk.Button.Gtk_Button;
      Name            : constant String := To_String (Info.Name);
      Arguments       : constant String := To_String (Info.Args);
      Result          : constant String := To_String (Info.Result_Text);
      Model           : constant String :=
        (if Length (Info.Model) > 0 then To_String (Info.Model) else "-");
      Directory       : constant String :=
        (if
           Length (Info.Source_Directory) > 0
         then
           To_String (Info.Source_Directory)
         else "-");
      Session_Start   : constant String :=
        (if Length (Info.Session_Start) > 0 then To_String (Info.Session_Start)
         else "-");
      Turn_Text       : constant String :=
        "Turn " & Positive'Image (Info.Turn_Index) & ", call "
        & Positive'Image (Info.Call_In_Turn);
   begin
      Gtk.Window.Gtk_New (Window, Gtk.Enums.Window_Toplevel);
      Window.Set_Title ("coyote : Tool Call Details");
      Window.Set_Name ("tool-detail-window");
      Window.Set_Type_Hint (Gdk.Window.Window_Type_Hint_Normal);
      Window.Set_Transient_For (Main_Window);
      Window.Set_Default_Size (760, 600);
      Window.Set_Size_Request (600, 400);
      Window.On_Key_Press_Event (On_Detail_Key_Press'Access);

      Gtk_New_Vbox (Root, Homogeneous => False, Spacing => 0);
      Window.Add (Root);
      Create_Menus (Window, Root);

      Gtk_New_Vbox (Content, Homogeneous => False, Spacing => 6);
      Content.Set_Border_Width (8);
      Root.Pack_Start (Content, True, True, 0);

      Gtk.Grid.Gtk_New (Header);
      Header.Set_Column_Spacing (16);
      Header.Set_Row_Spacing (2);
      Header.Set_Name ("tool-detail-header");
      Add_Header_Row (Header, 0, "Tool", Name);
      Add_Header_Row (Header, 1, "Status", Status_Text (Info));
      Add_Header_Row (Header, 2, "Datetime", Session_Start);
      Add_Header_Row (Header, 3, "Model", Model);
      Add_Header_Row (Header, 4, "Directory", Directory);
      Add_Header_Row (Header, 5, "Position", Turn_Text);
      Content.Pack_Start (Header, False, False, 0);

      Gtk.Paned.Gtk_New_Vpaned (Panes);
      Panes.Set_Name ("tool-detail-panes");
      Panes.On_Map (Initialize_Divider'Access);
      Content.Pack_Start (Panes, True, True, 0);

      Gtk.Frame.Gtk_New (Arguments_Frame, "Arguments");
      Gtk_New_Vbox (Arguments_Box, Homogeneous => False, Spacing => 5);
      Arguments_Box.Set_Border_Width (8);
      Add_Text_View
        (Arguments_Box, Format_Arguments (Arguments),
         "tool-detail-arguments");
      Arguments_Frame.Add (Arguments_Box);
      Panes.Pack1 (Arguments_Frame, Resize => True, Shrink => False);

      Gtk.Frame.Gtk_New (Result_Frame, "Result");
      Gtk_New_Vbox (Result_Box, Homogeneous => False, Spacing => 6);
      Result_Box.Set_Border_Width (8);
      Gtk.Label.Gtk_New (Banner, Status_Text (Info));
      Banner.Set_Xalign (0.0);
      if Info.Completed then
         Apply_Status_Style (Banner, Info.Result_Status);
      end if;
      Result_Box.Pack_Start (Banner, False, False, 0);
      if not Info.Completed then
         Add_Text_View
           (Result_Box,
            "No result is available while the tool is running.",
            "tool-detail-result");
      elsif Length (Info.Media_Type) > 0 then
         Add_Image_Result (Result_Box, Result);
      else
         Add_Text_View (Result_Box, Result, "tool-detail-result");
      end if;
      Result_Frame.Add (Result_Box);
      Panes.Pack2 (Result_Frame, Resize => True, Shrink => False);

      Gtk_New_Hbox (Button_Box, Homogeneous => False, Spacing => 6);
      Button_Box.Set_Name ("tool-detail-actions");
      Gtk.Button.Gtk_New_With_Mnemonic (Help_Button, "_Help");
      Help_Button.On_Clicked (On_Help_Clicked'Access);
      Button_Box.Pack_End (Help_Button, False, False, 0);
      Gtk.Button.Gtk_New_With_Mnemonic (Close_Button, "_Close");
      Close_Button.On_Clicked (On_Close_Clicked'Access);
      Button_Box.Pack_End (Close_Button, False, False, 0);
      Content.Pack_End (Button_Box, False, False, 0);

      Window.Show_All;
      Gtk.Scrolled_Window.Gtk_Scrolled_Window
        (Arguments_Box.Get_Child (0)).Get_Child.Grab_Focus;
   end Show;

end Coyote_GUI.Tool_Detail_Window;
