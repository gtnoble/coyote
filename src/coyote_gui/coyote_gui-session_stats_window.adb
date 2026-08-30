--  Coyote_GUI.Session_Stats_Window body.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_App.Utils;       use Coyote_App.Utils;
with Gdk.Event;
with Gdk.Types;
with Gdk.Types.Keysyms;
with Glib;
with Glib.Properties;
with Gtk.Box;
with Gtk.Button;
with Gtk.Enums;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Label;
with Gtk.Settings;
with Gtk.Scrolled_Window;
with Gtk.Widget;
with Gtk.Window;
with Pango.Enums;
with Pango.Font;

package body Coyote_GUI.Session_Stats_Window is

   use type Gdk.Types.Gdk_Key_Type;
   use type Gdk.Types.Gdk_Modifier_Type;
   use type Glib.Gint;
   use type Gtk.Window.Gtk_Window;

   System_Font_Family  : Unbounded_String;
   System_Font_Size_Pt : Integer := 11;
   System_Font_Inited  : Boolean := False;
   Current_Window      : Gtk.Window.Gtk_Window := null;

   procedure On_Close_Clicked
     (Button : access Gtk.Button.Gtk_Button_Record'Class)
   is
      pragma Unreferenced (Button);
   begin
      if Current_Window /= null then
         Current_Window.Hide;
      end if;
   end On_Close_Clicked;

   procedure Ensure_System_Font_Init is
      Settings : constant Gtk.Settings.Gtk_Settings :=
        Gtk.Settings.Get_Default;
      Font_Str : constant String :=
        Glib.Properties.Get_Property
          (Settings, Gtk.Settings.Gtk_Font_Name_Property);
      Font_Desc : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String (Font_Str);
   begin
      System_Font_Family :=
        To_Unbounded_String (Pango.Font.Get_Family (Font_Desc));
      System_Font_Size_Pt :=
        Integer (Pango.Font.Get_Size (Font_Desc)) / Pango.Enums.Pango_Scale;
      if System_Font_Size_Pt < 6 then
         System_Font_Size_Pt := 11;
      end if;
      Pango.Font.Free (Font_Desc);
      System_Font_Inited := True;
   exception
      when others =>
         System_Font_Family := To_Unbounded_String ("sans");
         System_Font_Size_Pt := 11;
         System_Font_Inited := True;
   end Ensure_System_Font_Init;

   function Font_Size_Image return String is
      Image : constant String := Integer'Image (System_Font_Size_Pt);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Font_Size_Image;

   procedure Apply_System_Font
     (Widget : not null access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      Font_Desc : Pango.Font.Pango_Font_Description;
   begin
      if not System_Font_Inited then
         Ensure_System_Font_Init;
      end if;
      declare
         Font_Name : constant String :=
           To_String (System_Font_Family) & " " & Font_Size_Image;
      begin
         Font_Desc := Pango.Font.From_String (Font_Name);
      end;
      Widget.Modify_Font (Font_Desc);
      Pango.Font.Free (Font_Desc);
   end Apply_System_Font;

   procedure Set_Value
     (Label : not null access Gtk.Label.Gtk_Label_Record'Class;
      Text  : String)
   is
   begin
      Label.Set_Text (Text);
      Label.Set_Halign (Gtk.Widget.Align_Start);
      Label.Set_Selectable (True);
      Label.Set_Line_Wrap (True);
      Apply_System_Font (Label);
   end Set_Value;

   procedure Add_Row
     (Grid  : not null access Gtk.Grid.Gtk_Grid_Record'Class;
      Row   : Glib.Gint;
      Name  : String;
      Value : out Gtk.Label.Gtk_Label)
   is
      Key : Gtk.Label.Gtk_Label;
   begin
      Gtk.Label.Gtk_New (Key, Name & ":");
      Key.Set_Halign (Gtk.Widget.Align_Start);
      Apply_System_Font (Key);
      Gtk.Label.Gtk_New (Value, "-");
      Set_Value (Value, "-");
      Grid.Attach (Key, 0, Row, 1, 1);
      Grid.Attach (Value, 1, Row, 1, 1);
   end Add_Row;

   function On_Window_Delete
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event) return Boolean
   is
      pragma Unreferenced (Event);
   begin
      Self.Hide;
      return True;
   end On_Window_Delete;

   function On_Key_Press
     (Self  : access Gtk.Widget.Gtk_Widget_Record'Class;
      Event : Gdk.Event.Gdk_Event_Key) return Boolean
   is
      pragma Unreferenced (Self);
   begin
      if Event.Keyval = Gdk.Types.Keysyms.GDK_LC_w
        and then (Event.State and Gdk.Types.Control_Mask) /= 0
      then
         if Current_Window /= null then
            Current_Window.Hide;
         end if;
         return True;
      end if;
      return False;
   end On_Key_Press;

   procedure Update_Labels
     (S     : in out Instance;
      Stats : in Coyote_GUI.Session_Stats_Record)
   is
   begin
      Set_Value (S.Session_Id, To_String (Stats.Session_Id));
      Set_Value (S.Model, To_String (Stats.Model));
      Set_Value (S.Turn_Count, Format_SI_Count (Stats.Turn_Count));
      Set_Value (S.Last_Input, Format_SI_Count (Stats.Last_Input) & " tok");
      Set_Value (S.Last_Output, Format_SI_Count (Stats.Last_Output) & " tok");
      Set_Value (S.Last_Cost, Format_Cost (Stats.Last_Cost_Dmil));
      Set_Value (S.Input, Format_SI_Count (Stats.Input) & " tok");
      Set_Value (S.Cache_Read, Format_SI_Count (Stats.Cache_Read) & " tok");
      Set_Value (S.Cache_Write, Format_SI_Count (Stats.Cache_Write) & " tok");
      Set_Value (S.Output, Format_SI_Count (Stats.Output) & " tok");
      Set_Value (S.Cost, Format_Cost (Stats.Cost_Dmil));
   end Update_Labels;

   procedure Create
     (S           : in out Instance;
      Main_Window : not null access Gtk.Window.Gtk_Window_Record'Class)
   is
      use Gtk.Box;
      use Gtk.Frame;
      use Gtk.Grid;

      Outer         : Gtk_Box;
      Report_Box    : Gtk_Box;
      Report_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Session_Frame : Gtk.Frame.Gtk_Frame;
      Last_Frame    : Gtk.Frame.Gtk_Frame;
      Total_Frame   : Gtk.Frame.Gtk_Frame;
      Session_Grid  : Gtk_Grid;
      Last_Grid     : Gtk_Grid;
      Total_Grid    : Gtk_Grid;
      Close         : Gtk.Button.Gtk_Button;
   begin
      if S.Created then
         return;
      end if;

      Gtk.Window.Gtk_New (S.Window, Gtk.Enums.Window_Toplevel);
      Current_Window := S.Window;
      S.Window.Set_Title ("coyote : Session Stats");
      S.Window.Set_Transient_For (Main_Window);
      S.Window.Set_Default_Size (560, 430);
      S.Window.Set_Size_Request (420, 360);
      S.Window.On_Delete_Event (On_Window_Delete'Access);
      S.Window.On_Key_Press_Event (On_Key_Press'Access);

      Gtk_New_Vbox (Outer, Homogeneous => False, Spacing => 8);
      Outer.Set_Border_Width (12);
      S.Window.Add (Outer);

      Gtk_New_Vbox (Report_Box, Homogeneous => False, Spacing => 8);
      Gtk.Scrolled_Window.Gtk_New (Report_Scroll);
      Report_Scroll.Set_Policy
        (Gtk.Enums.Policy_Never, Gtk.Enums.Policy_Automatic);
      Report_Scroll.Set_Size_Request (-1, 300);
      Report_Scroll.Add (Report_Box);
      Outer.Pack_Start (Report_Scroll, True, True, 0);

      Gtk.Frame.Gtk_New (Session_Frame, "Session");
      Gtk.Grid.Gtk_New (Session_Grid);
      Session_Grid.Set_Column_Spacing (16);
      Session_Grid.Set_Row_Spacing (5);
      Add_Row (Session_Grid, 0, "Model", S.Model);
      Add_Row (Session_Grid, 1, "Session", S.Session_Id);
      Add_Row (Session_Grid, 2, "Turn", S.Turn_Count);
      Session_Frame.Add (Session_Grid);
      Session_Frame.Set_Border_Width (8);
      Report_Box.Pack_Start (Session_Frame, False, False, 0);

      Gtk.Frame.Gtk_New (Last_Frame, "Last Turn");
      Gtk.Grid.Gtk_New (Last_Grid);
      Last_Grid.Set_Column_Spacing (16);
      Last_Grid.Set_Row_Spacing (5);
      Add_Row (Last_Grid, 0, "Input", S.Last_Input);
      Add_Row (Last_Grid, 1, "Output", S.Last_Output);
      Add_Row (Last_Grid, 2, "Cost", S.Last_Cost);
      Last_Frame.Add (Last_Grid);
      Last_Frame.Set_Border_Width (8);
      Report_Box.Pack_Start (Last_Frame, False, False, 0);

      Gtk.Frame.Gtk_New (Total_Frame, "Session Totals");
      Gtk.Grid.Gtk_New (Total_Grid);
      Total_Grid.Set_Column_Spacing (16);
      Total_Grid.Set_Row_Spacing (5);
      Add_Row (Total_Grid, 0, "Input", S.Input);
      Add_Row (Total_Grid, 1, "Cache Read", S.Cache_Read);
      Add_Row (Total_Grid, 2, "Cache Write", S.Cache_Write);
      Add_Row (Total_Grid, 3, "Output", S.Output);
      Add_Row (Total_Grid, 4, "Cost", S.Cost);
      Total_Frame.Add (Total_Grid);
      Total_Frame.Set_Border_Width (8);
      Report_Box.Pack_Start (Total_Frame, True, True, 0);

      Gtk.Button.Gtk_New_With_Mnemonic (Close, "_Close");
      Close.On_Clicked (On_Close_Clicked'Access);
      Close.Set_Halign (Gtk.Widget.Align_End);
      Outer.Pack_End (Close, False, False, 0);

      S.Created := True;
      Update_Labels (S, S.Stats);
   end Create;

   function Is_Created (S : Instance) return Boolean is
   begin
      return S.Created;
   end Is_Created;

   procedure Show (S : in out Instance) is
   begin
      if not S.Created then
         return;
      end if;
      S.Window.Show_All;
      S.Window.Present;
      S.Session_Id.Grab_Focus;
   end Show;

   procedure Update
     (S     : in out Instance;
      Stats : in Coyote_GUI.Session_Stats_Record)
   is
   begin
      S.Stats := Stats;
      if S.Created then
         Update_Labels (S, Stats);
      end if;
   end Update;

   function Current_Stats
     (S : Instance) return Coyote_GUI.Session_Stats_Record
   is
   begin
      return S.Stats;
   end Current_Stats;

   procedure Clear (S : in out Instance) is
   begin
      S.Stats := (others => <>);
      if S.Created then
         Set_Value (S.Session_Id, "-");
         Set_Value (S.Model, "-");
         Set_Value (S.Turn_Count, "0");
         Set_Value (S.Last_Input, "0 tok");
         Set_Value (S.Last_Output, "0 tok");
         Set_Value (S.Last_Cost, "$0.0000");
         Set_Value (S.Input, "0 tok");
         Set_Value (S.Cache_Read, "0 tok");
         Set_Value (S.Cache_Write, "0 tok");
         Set_Value (S.Output, "0 tok");
         Set_Value (S.Cost, "$0.0000");
      end if;
   end Clear;

end Coyote_GUI.Session_Stats_Window;
