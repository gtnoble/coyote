--  Coyote_GUI.Tool_Detail_Window body.
--
--  The detail window is a modeless support window.  All values are captured
--  before construction so opening it never re-reads session files.
--
--  Project: coyote

with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Coyote_Help;
with Gdk.Event;
with Gdk.Pixbuf;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Glib;                   use Glib;
with Glib.Error;
with Glib.Object;
with Glib.Properties;
with GNATCOLL.JSON;
with GNAT.OS_Lib;
with Gtk.Box;
with Gtk.Button;
with Gtk.Css_Provider;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Image;
with Gtk.Label;
with Gtk.Scrolled_Window;
with Gtk.Settings;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Widget;
with Gtk.Window;
with Pango.Enums;
with Pango.Font;

package body Coyote_GUI.Tool_Detail_Window is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Gdk.Types.Gdk_Modifier_Type;
   use Pango.Enums;
   use Pango.Font;

   --  Close the support window containing Button.  Looking up the toplevel
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
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
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
      Settings : constant Gtk.Settings.Gtk_Settings :=
        Gtk.Settings.Get_Default;
      Font_Str : constant String :=
        Glib.Properties.Get_Property
          (Settings, Gtk.Settings.Gtk_Font_Name_Property);
      Font_Description : Pango_Font_Description :=
        From_String (Font_Str);
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
         System_Font_Inited := True;
   end Ensure_System_Font_Init;

   function Mono_Font_String return String is
      Size_Image : constant String := Integer'Image (System_Font_Size_Pt);
   begin
      return "monospace " & Size_Image (Size_Image'First + 1 .. Size_Image'Last);
   end Mono_Font_String;

   function Escape_Markup (Value : String) return String is
      Result : Unbounded_String;
   begin
      for Character_Value of Value loop
         case Character_Value is
            when '&' => Append (Result, "&amp;");
            when '<' => Append (Result, "&lt;");
            when '>' => Append (Result, "&gt;");
            when '"' => Append (Result, "&quot;");
            when others => Append (Result, Character_Value);
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

   function Text_View_Height
     (Value          : String;
      Minimum_Height : Glib.Gint;
      Maximum_Height : Glib.Gint) return Glib.Gint
   is
      Characters_Per_Line : constant Positive := 72;
      Line_Height         : constant Positive := 18;
      Vertical_Padding    : constant Positive := 12;
      Lines               : Natural := 1;
      Column              : Natural := 0;
      Height              : Glib.Gint;
   begin
      for Character_Value of Value loop
         if Character_Value = ASCII.LF then
            Lines := Lines + 1;
            Column := 0;
         else
            if Column >= Characters_Per_Line then
               Lines := Lines + 1;
               Column := 0;
            end if;
            Column := Column + 1;
         end if;
      end loop;

      Height := Glib.Gint (Lines * Line_Height + Vertical_Padding);
      if Height < Minimum_Height then
         return Minimum_Height;
      elsif Height > Maximum_Height then
         return Maximum_Height;
      else
         return Height;
      end if;
   end Text_View_Height;

   procedure Add_Text_View
     (Container      : not null access Gtk.Box.Gtk_Box_Record'Class;
      Value          : String;
      Minimum_Height : Glib.Gint;
      Expand         : Boolean)
   is
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      View   : Gtk.Text_View.Gtk_Text_View;
      Buffer : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
   begin
      Gtk.Text_Buffer.Gtk_New (Buffer);
      Gtk.Text_View.Gtk_New (View, Buffer);
      View.Set_Editable (False);
      View.Set_Wrap_Mode (Gtk.Enums.Wrap_Word_Char);
      View.Set_Left_Margin (8);
      View.Set_Right_Margin (8);
      Set_Monospace (View);
      Buffer.Get_End_Iter (Iter);
      Buffer.Insert (Iter, Value);

      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      Scroll.Set_Size_Request (-1, Minimum_Height);
      Scroll.Add (View);
      Container.Pack_Start (Scroll, Expand, True, 0);
   end Add_Text_View;

   function Status_Text
     (Status : Coyote_GUI.Tool_End_Status) return String
   is
   begin
      case Status is
         when Coyote_GUI.Success =>
            return UC_CHECK & " success";
         when Coyote_GUI.Error =>
            return UC_CROSS & " error";
         when Coyote_GUI.Cancelled =>
            return "- cancelled";
      end case;
   end Status_Text;

   procedure Apply_Status_Style
     (Label  : not null access Gtk.Label.Gtk_Label_Record'Class;
      Status : Coyote_GUI.Tool_End_Status)
   is
      use Gtk.Css_Provider;
      use Gtk.Style_Context;
      use Gtk.Style_Provider;
      CSS : constant String :=
        (case Status is
            when Coyote_GUI.Success =>
               "label { font-weight: bold; padding: 7px 10px; }",
            when Coyote_GUI.Error =>
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
      Key   : Gtk.Label.Gtk_Label;
      Value_Label : Gtk.Label.Gtk_Label;
   begin
      Gtk.Label.Gtk_New (Key);
      Key.Set_Markup ("<b>" & Escape_Markup (Name) & "</b>");
      Key.Set_Xalign (0.0);
      Grid.Attach (Key, 0, Row, 1, 1);

      Gtk.Label.Gtk_New (Value_Label, Value);
      Value_Label.Set_Xalign (0.0);
      Value_Label.Set_Line_Wrap (True);
      Value_Label.Set_Selectable (True);
      Grid.Attach (Value_Label, 1, Row, 1, 1);
   end Add_Header_Row;

   procedure Add_Argument_Field
     (Container : not null access Gtk.Box.Gtk_Box_Record'Class;
      Name      : String;
      Value     : String)
   is
      Header : Gtk.Label.Gtk_Label;
   begin
      Gtk.Label.Gtk_New (Header);
      Header.Set_Markup ("<b>" & Escape_Markup (Name) & "</b>");
      Header.Set_Xalign (0.0);
      Container.Pack_Start (Header, False, False, 3);
      Add_Text_View
        (Container, Value, Text_View_Height (Value, 30, 120), False);
   end Add_Argument_Field;

   procedure Build_Arguments
     (Container : not null access Gtk.Box.Gtk_Box_Record'Class;
      Arguments : String)
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Arguments);
   begin
      if Arguments'Length = 0 then
         declare
            Empty : Gtk.Label.Gtk_Label;
         begin
            Gtk.Label.Gtk_New (Empty, "(no arguments)");
            Empty.Set_Xalign (0.0);
            Container.Pack_Start (Empty, False, False, 0);
         end;
      elsif Parsed.Success
        and then Parsed.Value.Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         declare
            Visible_Count : Natural := 0;

            procedure Add_Field
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
               Value : constant String :=
                 (if Field_Value.Kind = GNATCOLL.JSON.JSON_String_Type
                  then Field_Value.Get
                  else Field_Value.Write);
            begin
               if not Is_Hidden_Tool_Argument
                 (Field_Name, Field_Value)
               then
                  Add_Argument_Field (Container, Field_Name, Value);
                  Visible_Count := Visible_Count + 1;
               end if;
            end Add_Field;
         begin
            Parsed.Value.Map_JSON_Object (Add_Field'Access);
            if Visible_Count = 0 then
               declare
                  Empty : Gtk.Label.Gtk_Label;
               begin
                  Gtk.Label.Gtk_New (Empty, "(no arguments)");
                  Empty.Set_Xalign (0.0);
                  Container.Pack_Start (Empty, False, False, 0);
               end;
            end if;
         end;
      else
         Add_Text_View
           (Container, Arguments,
            Text_View_Height (Arguments, 30, 120), False);
      end if;
   end Build_Arguments;

   function Decode_Base64 (Input : String) return String is
      function Value_Of (Character_Value : Character) return Integer is
      begin
         case Character_Value is
            when 'A' .. 'Z' =>
               return Character'Pos (Character_Value) - Character'Pos ('A');
            when 'a' .. 'z' =>
               return 26 + Character'Pos (Character_Value)
                 - Character'Pos ('a');
            when '0' .. '9' =>
               return 52 + Character'Pos (Character_Value)
                 - Character'Pos ('0');
            when '+' => return 62;
            when '/' => return 63;
            when others => return -1;
         end case;
      end Value_Of;

      Maximum_Length : constant Natural := (Input'Length * 3) / 4 + 4;
      Output         : String (1 .. Maximum_Length);
      Output_Length  : Natural := 0;
      Position       : Natural := Input'First;
      V0, V1, V2, V3 : Integer;
   begin
      while Position + 3 <= Input'Last loop
         V0 := Value_Of (Input (Position));
         V1 := Value_Of (Input (Position + 1));
         V2 := Value_Of (Input (Position + 2));
         V3 := Value_Of (Input (Position + 3));
         if V0 >= 0 and then V1 >= 0 then
            Output_Length := Output_Length + 1;
            Output (Output_Length) := Character'Val (V0 * 4 + V1 / 16);
         end if;
         if V2 >= 0 and then Input (Position + 2) /= '=' then
            Output_Length := Output_Length + 1;
            Output (Output_Length) :=
              Character'Val ((V1 mod 16) * 16 + V2 / 4);
         end if;
         if V3 >= 0 and then Input (Position + 3) /= '=' then
            Output_Length := Output_Length + 1;
            Output (Output_Length) :=
              Character'Val ((V2 mod 4) * 64 + V3);
         end if;
         Position := Position + 4;
      end loop;
      return Output (1 .. Output_Length);
   end Decode_Base64;

   function Write_Temp_Image (Decoded : String) return String is
      Descriptor : GNAT.OS_Lib.File_Descriptor;
      Name       : GNAT.OS_Lib.String_Access;
      Written    : Integer;
      pragma Unreferenced (Written);
      use type GNAT.OS_Lib.File_Descriptor;
      use type GNAT.OS_Lib.String_Access;
   begin
      GNAT.OS_Lib.Create_Temp_File (Descriptor, Name);
      if Descriptor = GNAT.OS_Lib.Invalid_FD or else Name = null then
         return "";
      end if;
      Written := GNAT.OS_Lib.Write
        (Descriptor, Decoded'Address, Decoded'Length);
      GNAT.OS_Lib.Close (Descriptor);
      declare
         Path : constant String := Name.all;
      begin
         GNAT.OS_Lib.Free (Name);
         return Path;
      end;
   exception
      when others =>
         if Name /= null then
            GNAT.OS_Lib.Free (Name);
         end if;
         return "";
   end Write_Temp_Image;

   procedure Add_Image_Result
     (Container : not null access Gtk.Box.Gtk_Box_Record'Class;
      Data      : String)
   is
      Decoded   : constant String := Decode_Base64 (Data);
      Temp_Path : constant String := Write_Temp_Image (Decoded);
      Pixbuf    : Gdk.Pixbuf.Gdk_Pixbuf;
      Image     : Gtk.Image.Gtk_Image;
      Error     : Glib.Error.GError;
   begin
      if Temp_Path'Length = 0 then
         declare
            Failure : Gtk.Label.Gtk_Label;
         begin
            Gtk.Label.Gtk_New (Failure, "[ image result unavailable ]");
            Failure.Set_Xalign (0.0);
            Container.Pack_Start (Failure, False, False, 0);
         end;
         return;
      end if;

      Gdk.Pixbuf.Gdk_New_From_File (Pixbuf, Temp_Path, Error);
      Ada.Directories.Delete_File (Temp_Path);
      if Pixbuf = Gdk.Pixbuf.Null_Pixbuf then
         declare
            Failure : Gtk.Label.Gtk_Label;
         begin
            Gtk.Label.Gtk_New (Failure, "[ image result could not be decoded ]");
            Failure.Set_Xalign (0.0);
            Container.Pack_Start (Failure, False, False, 0);
         end;
         return;
      end if;

      Gtk.Image.Gtk_New (Image, Pixbuf);
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
         if Temp_Path'Length > 0 and then Ada.Directories.Exists (Temp_Path) then
            Ada.Directories.Delete_File (Temp_Path);
         end if;
         declare
            Failure : Gtk.Label.Gtk_Label;
         begin
            Gtk.Label.Gtk_New (Failure, "[ image result could not be displayed ]");
            Failure.Set_Xalign (0.0);
            Container.Pack_Start (Failure, False, False, 0);
         end;
   end Add_Image_Result;

   procedure Show
     (Info        : Coyote_GUI.Tool_Info;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class)
   is
      use Gtk.Box;
      use Gtk.Frame;
      use Gtk.Grid;
      use Gtk.Label;
      use Gtk.Scrolled_Window;

      Window       : Gtk.Window.Gtk_Window;
      Root         : Gtk_Box;
      Content_Scroll : Gtk_Scrolled_Window;
      Content      : Gtk_Box;
      Header       : Gtk_Grid;
      Arguments_Frame : Gtk_Frame;
      Arguments_Box : Gtk_Box;
      Result_Frame : Gtk_Frame;
      Result_Box   : Gtk_Box;
      Banner       : Gtk_Label;
      Button_Box   : Gtk_Box;
      Close_Button : Gtk.Button.Gtk_Button;
      Help_Button  : Gtk.Button.Gtk_Button;
      Name         : constant String := To_String (Info.Name);
      Arguments    : constant String := To_String (Info.Args);
      Result       : constant String := To_String (Info.Result_Text);
      Model        : constant String :=
        (if Length (Info.Model) > 0 then To_String (Info.Model) else "-");
      Directory    : constant String :=
        (if Length (Info.Source_Directory) > 0
         then To_String (Info.Source_Directory)
         else "-");
      Session_Start : constant String :=
        (if Length (Info.Session_Start) > 0
         then To_String (Info.Session_Start)
         else "-");
      Turn_Text : constant String :=
        "Turn " & Positive'Image (Info.Turn_Index)
        & ", call " & Positive'Image (Info.Call_In_Turn);
   begin
      Gtk.Window.Gtk_New (Window, Gtk.Enums.Window_Toplevel);
      Window.Set_Title ("coyote : Tool Call Details");
      Window.Set_Transient_For (Main_Window);
      Window.Set_Default_Size (760, 600);
      Window.Set_Size_Request (600, 400);
      Window.On_Key_Press_Event (On_Detail_Key_Press'Access);

      Gtk_New_Vbox (Root, Homogeneous => False, Spacing => 8);
      Root.Set_Border_Width (10);
      Window.Add (Root);

      Gtk.Scrolled_Window.Gtk_New (Content_Scroll);
      Content_Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Gtk_New_Vbox (Content, Homogeneous => False, Spacing => 8);
      Content.Set_Border_Width (4);
      Content_Scroll.Add (Content);
      Root.Pack_Start (Content_Scroll, True, True, 0);

      Gtk.Grid.Gtk_New (Header);
      Header.Set_Column_Spacing (16);
      Header.Set_Row_Spacing (6);
      Add_Header_Row (Header, 0, "Tool", Name);
      Add_Header_Row (Header, 1, "Status", Status_Text (Info.Result_Status));
      Add_Header_Row (Header, 2, "Datetime", Session_Start);
      Add_Header_Row (Header, 3, "Model", Model);
      Add_Header_Row (Header, 4, "Directory", Directory);
      Add_Header_Row (Header, 5, "Position", Turn_Text);
      Content.Pack_Start (Header, False, False, 0);

      Gtk.Frame.Gtk_New (Arguments_Frame, "Arguments");
      Gtk_New_Vbox (Arguments_Box, Homogeneous => False, Spacing => 5);
      Arguments_Box.Set_Border_Width (8);
      Build_Arguments (Arguments_Box, Arguments);
      Arguments_Frame.Add (Arguments_Box);
      Content.Pack_Start (Arguments_Frame, False, False, 0);

      Gtk.Frame.Gtk_New (Result_Frame, "Result");
      Gtk_New_Vbox (Result_Box, Homogeneous => False, Spacing => 6);
      Result_Box.Set_Border_Width (8);
      Gtk.Label.Gtk_New (Banner, Status_Text (Info.Result_Status));
      Banner.Set_Xalign (0.0);
      Apply_Status_Style (Banner, Info.Result_Status);
      Result_Box.Pack_Start (Banner, False, False, 0);
      if Length (Info.Media_Type) > 0 then
         Add_Image_Result (Result_Box, Result);
      else
         Add_Text_View (Result_Box, Result, 170, True);
      end if;
      Result_Frame.Add (Result_Box);
      Content.Pack_Start (Result_Frame, True, True, 0);

      Gtk_New_Hbox (Button_Box, Homogeneous => False, Spacing => 6);
      Gtk.Button.Gtk_New_With_Mnemonic (Help_Button, "_Help");
      Help_Button.On_Clicked (On_Help_Clicked'Access);
      Button_Box.Pack_End (Help_Button, False, False, 0);
      Gtk.Button.Gtk_New_With_Mnemonic (Close_Button, "_Close");
      Close_Button.On_Clicked (On_Close_Clicked'Access);
      Button_Box.Pack_End (Close_Button, False, False, 0);
      Root.Pack_End (Button_Box, False, False, 0);

      Window.Show_All;
      Content_Scroll.Grab_Focus;
   end Show;

end Coyote_GUI.Tool_Detail_Window;
