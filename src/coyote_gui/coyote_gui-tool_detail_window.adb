--  Coyote_GUI.Tool_Detail_Window body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Glib;                   use Glib;
with Glib.Error;
with Glib.Properties;
with GNATCOLL.JSON;
with Gtk.Box;
with Gtk.Css_Provider;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Label;
with Gtk.Scrolled_Window;
with Gtk.Settings;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Window;
with Pango.Enums;
with Pango.Font;

package body Coyote_GUI.Tool_Detail_Window is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use Pango.Enums;
   use Pango.Font;

   System_Font_Size_Pt : Integer := 10;
   System_Font_Inited  : Boolean := False;

   procedure Ensure_System_Font_Init is
      Settings : constant Gtk.Settings.Gtk_Settings :=
        Gtk.Settings.Get_Default;
      Font_Str : constant String :=
        Glib.Properties.Get_Property
          (Settings, Gtk.Settings.Gtk_Font_Name_Property);
      FD : Pango_Font_Description := From_String (Font_Str);
   begin
      System_Font_Size_Pt := Integer (Get_Size (FD)) / Pango_Scale;
      if System_Font_Size_Pt < 6 then
         System_Font_Size_Pt := 10;
      end if;
      System_Font_Inited := True;
      Free (FD);
   exception
      when others =>
         System_Font_Size_Pt := 10;
         System_Font_Inited := True;
   end Ensure_System_Font_Init;

   function Mono_Font_String return String is
   begin
      return "monospace "
        & Integer'Image (System_Font_Size_Pt)
            (2 .. Integer'Image (System_Font_Size_Pt)'Last);
   end Mono_Font_String;

   function Escape_Markup (Value : String) return String is
      Result : Unbounded_String;
   begin
      for C of Value loop
         case C is
            when '&'    => Append (Result, "&amp;");
            when '<'    => Append (Result, "&lt;");
            when '>'    => Append (Result, "&gt;");
            when '"'    => Append (Result, "&quot;");
            when others => Append (Result, C);
         end case;
      end loop;
      return To_String (Result);
   end Escape_Markup;

   procedure Set_Monospace
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class)
   is
      FD : Pango_Font_Description;
   begin
      if not System_Font_Inited then
         Ensure_System_Font_Init;
      end if;
      FD := From_String (Mono_Font_String);
      View.Modify_Font (FD);
      Free (FD);
   end Set_Monospace;

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
      for C of Value loop
         if C = ASCII.LF then
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

   procedure Apply_Status_Css
     (Label  : not null access Gtk.Label.Gtk_Label_Record'Class;
      Status : Coyote_GUI.Conversation.Tool_End_Status)
   is
      use Gtk.Css_Provider;
      use Gtk.Style_Context;
      use Gtk.Style_Provider;
      CSS : constant String :=
        (case Status is
            when Coyote_GUI.Conversation.Success =>
               "label { background-color: #dcefe2; color: #215732;"
               & " padding: 7px 10px; font-weight: bold; }",
            when Coyote_GUI.Conversation.Error =>
               "label { background-color: #f8dede; color: #842029;"
               & " padding: 7px 10px; font-weight: bold; }",
            when Coyote_GUI.Conversation.Cancelled =>
               "label { background-color: #e9ecef; color: #495057;"
               & " padding: 7px 10px; font-weight: bold; }");
      Provider : Gtk_Css_Provider;
      Ignored  : Boolean;
      CSS_Error : aliased Glib.Error.GError;
      pragma Unreferenced (Ignored);
   begin
      Gtk_New (Provider);
      Ignored := Provider.Load_From_Data (CSS, CSS_Error'Access);
      Get_Style_Context (Label).Add_Provider
        (Implements_Gtk_Style_Provider.To_Interface (Provider),
         Guint (Priority_Application));
   end Apply_Status_Css;

   function Status_Text
     (Status : Coyote_GUI.Conversation.Tool_End_Status) return String
   is
   begin
      case Status is
         when Coyote_GUI.Conversation.Success => return UC_CHECK & " success";
         when Coyote_GUI.Conversation.Error => return UC_CROSS & " error";
         when Coyote_GUI.Conversation.Cancelled => return "- cancelled";
      end case;
   end Status_Text;

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
        (Container, Value,
         Text_View_Height (Value, 30, 120), Expand => False);
   end Add_Argument_Field;

   procedure Build_Arguments
     (Container : not null access Gtk.Box.Gtk_Box_Record'Class;
      Arguments : String)
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Arguments);
   begin
      if Arguments'Length = 0 then
         return;
      elsif Parsed.Success
        and then Parsed.Value.Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         declare
            procedure Add_Field
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
               Value : constant String :=
                 (if Field_Value.Kind = GNATCOLL.JSON.JSON_String_Type
                  then Field_Value.Get
                  else Field_Value.Write);
            begin
               Add_Argument_Field (Container, Field_Name, Value);
            end Add_Field;
         begin
            Parsed.Value.Map_JSON_Object (Add_Field'Access);
         end;
      else
         Add_Text_View
           (Container, Arguments,
            Text_View_Height (Arguments, 30, 120), Expand => False);
      end if;
   end Build_Arguments;

   procedure Add_Header_Row
     (Grid  : not null access Gtk.Grid.Gtk_Grid_Record'Class;
      Row   : Glib.Gint;
      Name  : String;
      Value : String)
   is
      Key  : Gtk.Label.Gtk_Label;
      Text : Gtk.Label.Gtk_Label;
   begin
      Gtk.Label.Gtk_New (Key);
      Key.Set_Markup ("<b>" & Escape_Markup (Name) & "</b>");
      Key.Set_Xalign (0.0);
      Grid.Attach (Key, 0, Row, 1, 1);

      Gtk.Label.Gtk_New (Text, Value);
      Text.Set_Xalign (0.0);
      Text.Set_Line_Wrap (True);
      Grid.Attach (Text, 1, Row, 1, 1);
   end Add_Header_Row;

   procedure Show
     (Info        : Coyote_GUI.Conversation.Tool_Info;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class)
   is
      use Gtk.Box;
      use Gtk.Frame;
      use Gtk.Grid;
      use Gtk.Label;

      Win        : Gtk.Window.Gtk_Window;
      Outer      : Gtk.Box.Gtk_Box;
      Header     : Gtk.Grid.Gtk_Grid;
      Args_Box   : Gtk.Box.Gtk_Box;
      Result_Box : Gtk.Box.Gtk_Box;
      Frame      : Gtk.Frame.Gtk_Frame;
      Banner     : Gtk.Label.Gtk_Label;
      Name       : constant String := To_String (Info.Name);
      Arguments  : constant String := To_String (Info.Args);
      Result     : constant String := To_String (Info.Result_Text);
      Title      : constant String := "coyote : Tool Call Details";
   begin
      Gtk.Window.Gtk_New (Win, Gtk.Enums.Window_Toplevel);
      Win.Set_Title (Title);
      Win.Set_Transient_For (Main_Window);
      Win.Set_Default_Size (760, 600);
      Win.Set_Size_Request (600, 400);

      Gtk.Box.Gtk_New_Vbox (Outer, Homogeneous => False, Spacing => 10);
      Outer.Set_Border_Width (14);
      Win.Add (Outer);

      Gtk.Grid.Gtk_New (Header);
      Header.Set_Column_Spacing (16);
      Header.Set_Row_Spacing (6);
      Add_Header_Row (Header, 0, "Tool", Name);
      Add_Header_Row
        (Header, 1, "Status", Status_Text (Info.Result_Status));
      Outer.Pack_Start (Header, False, False, 0);

      Gtk.Frame.Gtk_New (Frame, "Arguments");
      Gtk.Box.Gtk_New_Vbox (Args_Box, Homogeneous => False, Spacing => 5);
      Args_Box.Set_Border_Width (8);
      Build_Arguments (Args_Box, Arguments);
      Frame.Add (Args_Box);
      Outer.Pack_Start (Frame, False, False, 0);

      Gtk.Frame.Gtk_New (Frame, "Result");
      Gtk.Box.Gtk_New_Vbox (Result_Box, Homogeneous => False, Spacing => 6);
      Result_Box.Set_Border_Width (8);
      Gtk.Label.Gtk_New (Banner, Status_Text (Info.Result_Status));
      Banner.Set_Xalign (0.0);
      Apply_Status_Css (Banner, Info.Result_Status);
      Result_Box.Pack_Start (Banner, False, False, 0);
      Add_Text_View (Result_Box, Result, 170, Expand => True);
      Frame.Add (Result_Box);
      Outer.Pack_Start (Frame, True, True, 0);

      Win.Show_All;
   end Show;

end Coyote_GUI.Tool_Detail_Window;
