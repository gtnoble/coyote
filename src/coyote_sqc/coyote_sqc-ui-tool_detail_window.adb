--  Coyote_SQC.UI.Tool_Detail_Window body.
--
--  Project: coyote

with Ada.Calendar.Formatting;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Gdk.Pixbuf;
with Glib;                   use Glib;
with Glib.Error;
with Glib.Properties;         use Glib.Properties;
with GNAT.OS_Lib;
with GNATCOLL.JSON;
with Gtk.Box;
with Gtk.Text_Iter;
with Gtk.Css_Provider;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Image;
with Gtk.Label;
with Gtk.Scrolled_Window;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Text_Buffer;
with Gtk.Text_View;
with Gtk.Widget;
with Gtk.Settings;
with Gtk.Window;
with Pango.Enums;
with Pango.Font;

package body Coyote_SQC.UI.Tool_Detail_Window is

   use type GNATCOLL.JSON.JSON_Value_Type;

   use Pango.Enums;
   use Pango.Font;

   --  System monospace font helpers
   --
   --  Read the system font size from Gtk.Settings lazily so that
   --  "monospace" resolves to the user configured monospace font.

   System_Font_Size_Pt : Integer := 10;
   System_Font_Inited  : Boolean := False;

   procedure Ensure_System_Font_Init is
      Settings : constant Gtk.Settings.Gtk_Settings :=
        Gtk.Settings.Get_Default;
      Font_Str : constant String :=
        Glib.Properties.Get_Property
          (Settings,
           Gtk.Settings.Gtk_Font_Name_Property);
      FD : Pango_Font_Description :=
        Pango.Font.From_String (Font_Str);
   begin
      System_Font_Size_Pt :=
        Integer (Pango.Font.Get_Size (FD)) / Pango_Scale;
      System_Font_Inited := True;
      Pango.Font.Free (FD);
   exception
      when others =>
         null;
   end Ensure_System_Font_Init;

   function Mono_Font_Str return String is
   begin
      return "monospace "
        & Integer'Image (System_Font_Size_Pt)
            (2 .. Integer'Image (System_Font_Size_Pt)'Last);
   end Mono_Font_Str;

   --  ── Base64 decoder ────────────────────────────────────────────────────

   function Char_Val (C :  Character) return Integer is
   begin
      case C is
         when 'A' .. 'Z' =>
            return Character'Pos (C) - Character'Pos ('A');
         when 'a' .. 'z' =>
            return 26 + Character'Pos (C) - Character'Pos ('a');
         when '0' .. '9' =>
            return 52 + Character'Pos (C) - Character'Pos ('0');
         when '+' => return 62;
         when '/' => return 63;
         when others => return -1;
      end case;
   end Char_Val;

   function Decode_Base64 (Input :  String) return String is
      Max_Len : constant Natural := (Input'Length * 3) / 4 + 4;
      Output  : String (1 .. Max_Len);
      Pos     : Natural := 0;
      I       : Natural := Input'First;
      V0, V1, V2, V3 : Integer;
   begin
      while I + 3 <= Input'Last loop
         V0 := Char_Val (Input (I));
         V1 := Char_Val (Input (I + 1));
         V2 := Char_Val (Input (I + 2));
         V3 := Char_Val (Input (I + 3));

         if V0 >= 0 and then V1 >= 0 then
            Pos := Pos + 1;
            Output (Pos) := Character'Val (V0 * 4 + V1 / 16);
         end if;
         if V2 >= 0 and then Input (I + 2) /= '=' then
            Pos := Pos + 1;
            Output (Pos) := Character'Val ((V1 mod 16) * 16 + V2 / 4);
         end if;
         if V3 >= 0 and then Input (I + 3) /= '=' then
            Pos := Pos + 1;
            Output (Pos) := Character'Val ((V2 mod 4) * 64 + V3);
         end if;

         I := I + 4;
      end loop;
      return Output (1 .. Pos);
   end Decode_Base64;

   --  Write Decoded to a new temp file; return the filename on success.
   --  Returns empty string on failure.
   function Write_Temp_Image (Decoded : String) return String is
      FD      : GNAT.OS_Lib.File_Descriptor;
      Name    : GNAT.OS_Lib.String_Access;
      Written : Integer;
      pragma Unreferenced (Written);
      use type GNAT.OS_Lib.File_Descriptor;
      use type GNAT.OS_Lib.String_Access;
   begin
      GNAT.OS_Lib.Create_Temp_File (FD, Name);
      if FD = GNAT.OS_Lib.Invalid_FD or else Name = null then
         return "";
      end if;
      Written := GNAT.OS_Lib.Write (FD, Decoded'Address, Decoded'Length);
      GNAT.OS_Lib.Close (FD);
      declare
         Path : constant String := Name.all;
      begin
         GNAT.OS_Lib.Free (Name);
         return Path;
      end;
   exception
      when E : others =>
         if Name /= null then
            GNAT.OS_Lib.Free (Name);
         end if;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "coyote_sqc: Write_Temp_Image failed: "
            & Ada.Exceptions.Exception_Information (E));
         return "";
   end Write_Temp_Image;

   --  ── CSS helper ────────────────────────────────────────────────────────

   procedure Apply_Banner_Css
     (Label  : not null access Gtk.Label.Gtk_Label_Record'Class;
      Status :  Coyote_Renderer.Session_View.Tool_End_Status)
   is
      use Gtk.Css_Provider;
      use Gtk.Style_Context;
      use Gtk.Style_Provider;
      CSS : constant String :=
        (case Status is
            when Coyote_Renderer.Session_View.Success   =>
               "label { background-color: #d4edda; color: #155724;"
               & " padding: 4px; font-weight: bold; }",
            when Coyote_Renderer.Session_View.Error     =>
               "label { background-color: #f8d7da; color: #721c24;"
               & " padding: 4px; font-weight: bold; }",
            when Coyote_Renderer.Session_View.Cancelled =>
               "label { background-color: #e2e3e5; color: #383d41;"
               & " padding: 4px; font-weight: bold; }");
      Provider : Gtk_Css_Provider;
      Ignored  : Boolean;
      Error    : aliased Glib.Error.GError;
      pragma Unreferenced (Ignored);
   begin
      Gtk_New (Provider);
      Ignored := Provider.Load_From_Data (CSS, Error'Access);
      Get_Style_Context (Label).Add_Provider
        (Implements_Gtk_Style_Provider.To_Interface (Provider),
         Guint (Priority_Application));
   end Apply_Banner_Css;

   --  ── Arguments section builder ─────────────────────────────────────────

   procedure Build_Args_Section
     (Container : not null access Gtk.Box.Gtk_Box_Record'Class;
      Arguments :  String)
   is
      use Gtk.Box;
      use Gtk.Label;
      use Gtk.Scrolled_Window;
      use Gtk.Text_Buffer;
      use Gtk.Text_View;
      use Gtk.Enums;

      procedure Add_Field (Name : String; Value : String) is
         Hdr    : Gtk.Label.Gtk_Label;
         Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
         TV     : Gtk.Text_View.Gtk_Text_View;
         Buf    : Gtk.Text_Buffer.Gtk_Text_Buffer;
         Iter   : Gtk.Text_Iter.Gtk_Text_Iter;
      begin
         Gtk.Label.Gtk_New (Hdr);
         Hdr.Set_Markup ("<b>" & Name & "</b>");
         Hdr.Set_Xalign (0.0);
         Container.Pack_Start (Hdr, False, False, 2);

         Gtk.Text_Buffer.Gtk_New (Buf);
         Gtk.Text_View.Gtk_New (TV, Buf);
         TV.Set_Editable (False);
         TV.Set_Wrap_Mode (Wrap_Word_Char);
         if not System_Font_Inited then
            Ensure_System_Font_Init;
         end if;
         declare
            use Pango.Font;
            Fd : Pango.Font.Pango_Font_Description;
         begin
            Fd := From_String (Mono_Font_Str);
            TV.Modify_Font (Fd);
            Free (Fd);
         end;
         Buf.Get_End_Iter (Iter);
         Buf.Insert (Iter, Value);
         Gtk.Scrolled_Window.Gtk_New (Scroll);
         Scroll.Set_Policy (Policy_Never, Policy_Automatic);
         Scroll.Set_Size_Request (-1, 100);
         Scroll.Add (TV);
         Container.Pack_Start (Scroll, False, False, 2);
      end Add_Field;

      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Arguments);
   begin
      if Parsed.Success
        and then Parsed.Value.Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         --  Iterate fields in JSON source order.
         --  Note: GNATCOLL.JSON.Map_JSON_Object may not preserve key order;
         --  this is an accepted limitation of the current implementation.
         declare
            procedure Handle_Field
              (Field_Name  : GNATCOLL.JSON.UTF8_String;
               Field_Value : GNATCOLL.JSON.JSON_Value)
            is
               Val : constant String :=
                 (if Field_Value.Kind = GNATCOLL.JSON.JSON_String_Type
                  then Field_Value.Get
                  else Field_Value.Write);
            begin
               Add_Field (Field_Name, Val);
            end Handle_Field;
         begin
            Parsed.Value.Map_JSON_Object (Handle_Field'Access);
         end;
      else
         --  Non-object or unparseable: show raw string in a single view.
         Add_Field ("arguments", Arguments);
      end if;
   end Build_Args_Section;

   --  ── Public ────────────────────────────────────────────────────────────

   procedure Show
     (Tool_Name    :  String;
      Arguments    :  String;
      Result_Text  :  String;
      Is_Image     :  Boolean;
      Status       :  Coyote_Renderer.Session_View.Tool_End_Status;
      Turn_Index   :  Positive;
      Call_In_Turn :  Positive;
      Session      :  Coyote_SQC.Data_Model.Session_Record;
      Main_Window  : not null access Gtk.Window.Gtk_Window_Record'Class)
   is
      use Gtk.Box;
      use Gtk.Enums;
      use Gtk.Frame;
      use Gtk.Grid;
      use Gtk.Label;
      use Gtk.Scrolled_Window;
      use Gtk.Text_Buffer;
      use Gtk.Text_View;
      use Ada.Strings.Unbounded;
      use Ada.Strings.Fixed;

      --  ── Helpers ────────────────────────────────────────────────────────

      function Trim_Path (P :  String) return String is
         Home : constant String := GNAT.OS_Lib.Getenv ("HOME").all;
      begin
         if P'Length > Home'Length
           and then P (P'First .. P'First + Home'Length - 1) = Home
         then
            return "~" & P (P'First + Home'Length .. P'Last);
         end if;
         return P;
      end Trim_Path;

      function Status_Icon return String is
      begin
         case Status is
            when Coyote_Renderer.Session_View.Success   => return UC_CHECK;
            when Coyote_Renderer.Session_View.Error     => return UC_CROSS;
            when Coyote_Renderer.Session_View.Cancelled => return "-";
         end case;
      end Status_Icon;

      function Banner_Text return String is
      begin
         case Status is
            when Coyote_Renderer.Session_View.Success   =>
               return UC_CHECK & " success";
            when Coyote_Renderer.Session_View.Error     =>
               return UC_CROSS & " error";
            when Coyote_Renderer.Session_View.Cancelled =>
               return "- cancelled";
         end case;
      end Banner_Text;

      function Format_Datetime return String is
         use Ada.Calendar.Formatting;
      begin
         return Image (Session.Start_Time, Time_Zone => 0);
      end Format_Datetime;

      function Format_Short_Datetime return String is
         Full : constant String := Format_Datetime;
      begin
         --  "YYYY-MM-DD HH:MM"
         if Full'Length >= 16 then
            return Full (Full'First .. Full'First + 15);
         end if;
         return Full;
      end Format_Short_Datetime;

      --  ── Widget references ──────────────────────────────────────────────
      Win    : Gtk.Window.Gtk_Window;
      Outer  : Gtk.Box.Gtk_Box;
      Grid   : Gtk.Grid.Gtk_Grid;
      Frame  : Gtk.Frame.Gtk_Frame;
      Lbl    : Gtk.Label.Gtk_Label;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Args_Box : Gtk.Box.Gtk_Box;

      Title  : constant String :=
        Status_Icon & " " & Tool_Name
        & " -- Turn "
        & Trim (Positive'Image (Turn_Index), Ada.Strings.Left)
        & " -- " & Format_Short_Datetime;
   begin
      --  ── Create window ──────────────────────────────────────────────────
      Gtk.Window.Gtk_New (Win);
      Win.Set_Title (Title);
      Win.Set_Transient_For (Main_Window);
      Win.Set_Default_Size (600, 400);

      Gtk.Box.Gtk_New_Vbox (Outer, Homogeneous => False, Spacing => 6);
      Outer.Set_Border_Width (8);
      Win.Add (Outer);

      --  ── Header section ─────────────────────────────────────────────────
      Gtk.Grid.Gtk_New (Grid);
      Grid.Set_Column_Spacing (8);
      Grid.Set_Row_Spacing (4);

      --  Row 0: Datetime
      Gtk.Label.Gtk_New (Lbl, "Datetime:");
      Lbl.Set_Xalign (0.0);
      Grid.Attach (Lbl, 0, 0);
      Gtk.Label.Gtk_New (Lbl, Format_Datetime);
      Lbl.Set_Xalign (0.0);
      Grid.Attach (Lbl, 1, 0);

      --  Row 1: Model
      Gtk.Label.Gtk_New (Lbl, "Model:");
      Lbl.Set_Xalign (0.0);
      Grid.Attach (Lbl, 0, 1);
      Gtk.Label.Gtk_New (Lbl, To_String (Session.Model));
      Lbl.Set_Xalign (0.0);
      Grid.Attach (Lbl, 1, 1);

      --  Row 2: Directory
      Gtk.Label.Gtk_New (Lbl, "Directory:");
      Lbl.Set_Xalign (0.0);
      Grid.Attach (Lbl, 0, 2);
      Gtk.Label.Gtk_New
        (Lbl, Trim_Path (To_String (Session.Source_Directory)));
      Lbl.Set_Xalign (0.0);
      Grid.Attach (Lbl, 1, 2);

      --  Row 3: Turn
      Gtk.Label.Gtk_New (Lbl, "Turn:");
      Lbl.Set_Xalign (0.0);
      Grid.Attach (Lbl, 0, 3);
      Gtk.Label.Gtk_New
        (Lbl,
         "Turn "
         & Trim (Positive'Image (Turn_Index), Ada.Strings.Left)
         & ", call "
         & Trim (Positive'Image (Call_In_Turn), Ada.Strings.Left));
      Lbl.Set_Xalign (0.0);
      Grid.Attach (Lbl, 1, 3);

      Outer.Pack_Start (Grid, False, False, 0);

      --  ── Arguments section ──────────────────────────────────────────────
      Gtk.Frame.Gtk_New (Frame, "Arguments");
      Gtk.Box.Gtk_New_Vbox (Args_Box, Homogeneous => False, Spacing => 4);
      Args_Box.Set_Border_Width (4);
      Build_Args_Section (Args_Box, Arguments);
      Frame.Add (Args_Box);
      Outer.Pack_Start (Frame, False, False, 0);

      --  ── Result section ─────────────────────────────────────────────────
      Gtk.Frame.Gtk_New (Frame, "Result");
      declare
         Result_Box : Gtk.Box.Gtk_Box;
         Banner     : Gtk.Label.Gtk_Label;
      begin
         Gtk.Box.Gtk_New_Vbox
           (Result_Box, Homogeneous => False, Spacing => 4);
         Result_Box.Set_Border_Width (4);

         --  Status banner.
         Gtk.Label.Gtk_New (Banner, Banner_Text);
         Banner.Set_Xalign (0.0);
         Apply_Banner_Css (Banner, Status);
         Result_Box.Pack_Start (Banner, False, False, 2);

         if Is_Image then
            --  Decode base64, write to temp file, load as GtkImage.
            declare
               Decoded   : constant String  := Decode_Base64 (Result_Text);
               Temp_Path : constant String  := Write_Temp_Image (Decoded);
            begin
               if Temp_Path /= "" then
                  declare
                     Img : Gtk.Image.Gtk_Image;
                  begin
                     Gtk.Image.Gtk_New (Img, Temp_Path);
                     Gtk.Scrolled_Window.Gtk_New (Scroll);
                     Scroll.Set_Policy (Policy_Automatic, Policy_Automatic);
                     Scroll.Add (Img);
                     Result_Box.Pack_Start (Scroll, True, True, 0);
                  end;
               else
                  Gtk.Label.Gtk_New (Lbl, "[ Image result - decode failed ]");
                  Result_Box.Pack_Start (Lbl, False, False, 0);
               end if;
            end;
         else
            --  Text result: read-only monospace GtkTextView.
            declare
               TV  : Gtk.Text_View.Gtk_Text_View;
               Buf : Gtk.Text_Buffer.Gtk_Text_Buffer;
               Iter : Gtk.Text_Iter.Gtk_Text_Iter;
            begin
               Gtk.Text_Buffer.Gtk_New (Buf);
               Gtk.Text_View.Gtk_New (TV, Buf);
               TV.Set_Editable (False);
               TV.Set_Wrap_Mode (Wrap_Word_Char);
               if not System_Font_Inited then
                  Ensure_System_Font_Init;
               end if;
               declare
                  use Pango.Font;
                  Fd : Pango.Font.Pango_Font_Description;
               begin
                  Fd := From_String (Mono_Font_Str);
                  TV.Modify_Font (Fd);
                  Free (Fd);
               end;
               Buf.Get_End_Iter (Iter);
               Buf.Insert (Iter, Result_Text);
               Gtk.Scrolled_Window.Gtk_New (Scroll);
               Scroll.Set_Policy (Policy_Automatic, Policy_Automatic);
               Scroll.Add (TV);
               Result_Box.Pack_Start (Scroll, True, True, 0);
            end;
         end if;

         Frame.Add (Result_Box);
      end;
      Outer.Pack_Start (Frame, True, True, 0);

      Win.Show_All;
   end Show;

end Coyote_SQC.UI.Tool_Detail_Window;
