--  Coyote_GUI.Math_Element body.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Ada.Real_Time;
with Interfaces;

with System;
with System.Address_To_Access_Conversions;
with System.Storage_Elements;
with Cairo;
with Cairo.Image_Surface;
with Cairo.Surface;
with Gdk.Cairo;
with Gdk.Pixbuf;
with Gdk.RGBA;
with Coyote_Math_Resources;
with Coyote_Math_Jobs;
with Glib.Main;
with Glib.Values;
with Glib; use Glib;
with Glib.Error;
with Gtk.Css_Provider;
with Gtk.Drawing_Area;
with Gtk.Expander;
with Gtk.Bin;
with Gtk.Container;
with Gtk.Enums;
with Gtk.Handlers;
with Gtk.Scrolled_Window;
with Coyote_GUI.Math_Accessibility;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Widget;

package body Coyote_GUI.Math_Element is
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Drawing_Area.Gtk_Drawing_Area;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Expander.Gtk_Expander;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Widget.Gtk_Widget;
   use type Gtk.Tree_View.Gtk_Tree_View;
   use type Cairo.Cairo_Context;
   use type Cairo.Cairo_Surface;
   use type Cairo.Cairo_Status;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Interfaces.Unsigned_32;
   use type System.Address;
   use type System.Storage_Elements.Storage_Offset;
   use type Glib.Main.G_Source_Id;
   package Raster_Bytes is new System.Address_To_Access_Conversions
     (Glib.Guchar);
   use type Glib.Main.G_Source;
   use type Coyote_Math_Jobs.Request_Id;
   use type Coyote_Math_Jobs.View_Generation;
   use type Coyote_Math_Jobs.Job_Status;
   use type Coyote_Math_Jobs.Result_Access;

   Max_Retained_Raster_Bytes : constant Natural := 64 * 1024 * 1024;
   Raster_Byte_Ledger : Natural := 0;
   Max_Raster_Callback : Ada.Real_Time.Time_Span :=
     Ada.Real_Time.Time_Span_Zero;
   Raster_Row_Budget : constant Ada.Real_Time.Time_Span :=
     Ada.Real_Time.Milliseconds (5);

   function Retained_Raster_Bytes return Natural is
     (Raster_Byte_Ledger);

   function Max_Raster_Callback_Milliseconds return Long_Float is
     (Long_Float (Ada.Real_Time.To_Duration (Max_Raster_Callback)) * 1_000.0);

   package Accessibility_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Expander.Gtk_Expander_Record, Instance_Access);
   procedure Populate_Accessibility
     (Expander : access Gtk.Expander.Gtk_Expander_Record'Class;
      Params : Glib.Values.GValues;
      Element : Instance_Access);
   Accessibility_Handler : constant Accessibility_Callback.Handler :=
     Accessibility_Callback.Handler'(Populate_Accessibility'Access);
   package Draw_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Drawing_Area.Gtk_Drawing_Area_Record, Boolean, Instance_Access);
   package Draw_Context_Marshaller is new Draw_Callback.Marshallers
     .Generic_Marshaller (Cairo.Cairo_Context, Cairo.Get_Context);

   function On_Draw
     (Area : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context : Cairo.Cairo_Context;
      Element : Instance_Access) return Boolean;

   procedure Populate_Accessibility
     (Expander : access Gtk.Expander.Gtk_Expander_Record'Class;
      Params : Glib.Values.GValues;
      Element : Instance_Access)
   is
      pragma Unreferenced (Params);
   begin
      if Element = null or else Element.Detached
        or else Element.Meaning_View /= null
        or else not Expander.Get_Expanded
        or else not Element.Valid
        or else not Math_Semantics.Is_Valid (Element.Meaning)
      then
         return;
      end if;
      Element.Meaning_View :=
        Coyote_GUI.Math_Accessibility.Create (Element.Meaning);
      Gtk.Scrolled_Window.Gtk_New (Element.Semantic_Scroll);
      Element.Semantic_Scroll.Set_Policy
        (Gtk.Enums.Policy_Automatic, Gtk.Enums.Policy_Automatic);
      Element.Semantic_Scroll.Set_Min_Content_Height (160);
      Element.Semantic_Scroll.Add (Element.Meaning_View);
      Expander.Add (Element.Semantic_Scroll);
   end Populate_Accessibility;

   procedure Clear_Accessibility (Element : in out Instance) is
   begin
      if Element.Accessibility /= null and then
        Element.Semantic_Scroll /= null
      then
         Element.Semantic_Scroll.Destroy;
      end if;
      Element.Meaning_View := null;
      Element.Semantic_Scroll := null;
   end Clear_Accessibility;

   procedure Apply_Response_Style
     (Target : not null access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      use Gtk.Css_Provider;
      use Gtk.Style_Context;
      use Gtk.Style_Provider;
      Provider : Gtk_Css_Provider;
      CSS_Error : aliased Glib.Error.GError;
      Ignored : Boolean;
      pragma Unreferenced (Ignored);
   begin
      Gtk_New (Provider);
      Ignored := Provider.Load_From_Data
        (".coyote-response-content { background-color: @theme_base_color; "
         & "color: @theme_text_color; }", CSS_Error'Access);
      Get_Style_Context (Target).Add_Class ("coyote-response-content");
      Get_Style_Context (Target).Add_Provider
        (Implements_Gtk_Style_Provider.To_Interface (Provider),
         Guint (Priority_Application));
   end Apply_Response_Style;

   procedure Update_Visibility (Element : in out Instance);

   procedure Measure_Layout (Element : in out Instance) is
      Em : Long_Float;
      Width : Long_Float;
      Height : Long_Float;
   begin
      Element.Layout_Valid := Element.Layout.Valid;
      Element.Valid := False;
      if Element.Layout_Valid then
         Em := 24.0 * Element.Math_Scale;
         Width := Element.Layout.Width * Em;
         Height := (Element.Layout.Ascent + Element.Layout.Descent) * Em;
         if not Width'Valid or else not Height'Valid
           or else Width > 8_188.0 or else Height > 4_092.0
         then
            Element.Layout_Valid := False;
         else
            Element.Math_Width := Natural'Max
              (1, Natural (Long_Float'Ceiling (Width)) + 4);
            Element.Math_Baseline := Natural'Max
              (1, Natural (Long_Float'Ceiling
                (Element.Layout.Ascent * Em)) + 2);
            Element.Math_Height := Natural'Max
              (1, Natural (Long_Float'Ceiling (Height)) + 4);
         end if;
      end if;
      if not Element.Layout_Valid then
         Element.Math_Width := 0;
         Element.Math_Baseline := 0;
         Element.Math_Height := 1;
      end if;
   exception
      when others =>
         Element.Layout_Valid := False;
         Element.Valid := False;
         Element.Math_Width := 0;
         Element.Math_Height := 1;
         Element.Math_Baseline := 0;
   end Measure_Layout;

   procedure Stop_Poll (Element : in out Instance) is
   begin
      if Element.Poll_Source /= 0 then
         if Glib.Main.Find_Source_By_Id (Element.Poll_Source) /= null then
            Glib.Main.Remove (Element.Poll_Source);
         end if;
         Element.Poll_Source := 0;
      end if;
   end Stop_Poll;

   function Poll_Result (Element : Instance_Access) return Boolean;
   function Adopt_Raster (Element : Instance_Access) return Boolean;
   procedure Clear_Raster (Element : in out Instance);
   package Poll_Sources is new Glib.Main.Generic_Sources (Instance_Access);

   procedure Clear_Raster (Element : in out Instance) is
   begin
      if Element.Raster_Result /= null then
         Coyote_Math_Jobs.Release (Element.Raster_Result);
      end if;
      if Element.Raster_Image /= Cairo.Null_Surface then
         Cairo.Surface.Destroy (Element.Raster_Image);
         Element.Raster_Image := Cairo.Null_Surface;
      end if;
      if Element.Raster_Bytes > 0 then
         Raster_Byte_Ledger := Raster_Byte_Ledger - Element.Raster_Bytes;
         Element.Raster_Bytes := 0;
      end if;
      Element.Raster_Row := 0;
      Element.Raster_Width := 0;
      Element.Raster_Height := 0;
      Element.Raster_Baseline := 0;
      Element.Raster_Ready := False;
   end Clear_Raster;

   function Adopt_Raster (Element : Instance_Access) return Boolean is
      Data : System.Address;
      Last_Row : Natural;
      Started : Ada.Real_Time.Time;
      Elapsed : Ada.Real_Time.Time_Span;
   begin
      if Element = null or else Element.Raster_Result = null then
         return False;
      end if;
      Started := Ada.Real_Time.Clock;
      Data := Cairo.Image_Surface.Get_Data_Generic
        (Element.Raster_Image);
      if Data = System.Null_Address then
         Clear_Raster (Element.all);
         return False;
      end if;
      Last_Row := Element.Raster_Row;
      Row_Loop :
         while Last_Row < Natural'Min
           (Element.Raster_Height, Element.Raster_Row + 8)
         loop
            declare
               Y : constant Natural := Last_Row;
            begin
               for X in 0 .. Element.Raster_Width - 1 loop
                  declare
                     Pixel : constant Interfaces.Unsigned_32 :=
                       Coyote_Math_Jobs.Raster_Pixel
                         (Element.Raster_Result.all, X, Y);
                     Offset : constant Natural :=
                       Y * Natural (Cairo.Image_Surface.Get_Stride
                         (Element.Raster_Image)) + X * 4;
                  begin
                     Raster_Bytes.To_Pointer
                       (Data + System.Storage_Elements.Storage_Offset
                         (Offset)).all := Glib.Guchar (Pixel and 16#FF#);
                     Raster_Bytes.To_Pointer
                       (Data + System.Storage_Elements.Storage_Offset
                         (Offset + 1)).all := Glib.Guchar
                         (Interfaces.Shift_Right (Pixel, 8) and 16#FF#);
                     Raster_Bytes.To_Pointer
                       (Data + System.Storage_Elements.Storage_Offset
                         (Offset + 2)).all := Glib.Guchar
                         (Interfaces.Shift_Right (Pixel, 16) and 16#FF#);
                     Raster_Bytes.To_Pointer
                       (Data + System.Storage_Elements.Storage_Offset
                         (Offset + 3)).all := Glib.Guchar
                         (Interfaces.Shift_Right (Pixel, 24) and 16#FF#);
                  end;
               end loop;
               Last_Row := Last_Row + 1;
            end;
            exit Row_Loop when
              Ada.Real_Time.Clock - Started >= Raster_Row_Budget;
         end loop Row_Loop;
      Element.Raster_Row := Last_Row;
      Cairo.Surface.Mark_Dirty (Element.Raster_Image);
      Elapsed := Ada.Real_Time.Clock - Started;
      if Elapsed > Max_Raster_Callback then
         Max_Raster_Callback := Elapsed;
      end if;
      if Last_Row = Element.Raster_Height then
         Coyote_Math_Jobs.Release (Element.Raster_Result);
         Element.Raster_Ready := True;
         Element.Valid := Element.Layout_Valid;
         Update_Visibility (Element.all);
         Element.Area.Queue_Draw;
         if Element.Valid and then Element.Accessibility /= null
           and then Element.Accessibility.Get_Expanded
         then
            declare
               Params : Glib.Values.GValues;
            begin
               Populate_Accessibility
                 (Element.Accessibility, Params, Element);
            end;
         end if;
         return False;
      end if;
      return True;
   exception
      when others =>
         Clear_Raster (Element.all);
         Element.Valid := False;
         Element.Math_Width := 0;
         Element.Math_Height := 1;
         Element.Math_Baseline := 0;
         Update_Visibility (Element.all);
         return False;
   end Adopt_Raster;

   procedure Cancel_Request (Element : in out Instance) is
   begin
      Stop_Poll (Element);
      if Element.Request /= 0 then
         Coyote_Math_Jobs.Abandon
           (Element.Request, Element.Generation);
         Element.Request := 0;
      end if;
   end Cancel_Request;

   function Poll_Result (Element : Instance_Access) return Boolean is
      Status : Coyote_Math_Jobs.Job_Status;
      Item : Coyote_Math_Jobs.Result_Access := null;
      Current : Coyote_Math_Jobs.Request_Id := 0;
   begin
      if Element = null or else Element.Detached then
         return False;
      end if;
      if Element.Raster_Result /= null then
         if Adopt_Raster (Element) then
            return True;
         end if;
         Update_Visibility (Element.all);
         if Element.Area /= null then
            Element.Area.Queue_Draw;
         end if;
         Element.Poll_Source := 0;
         return False;
      end if;
      Current := Element.Request;
      Coyote_Math_Jobs.Poll
        (Current, Element.Generation, Status, Item);
      if Status = Coyote_Math_Jobs.Pending then
         return True;
      end if;
      Element.Request := 0;
      if Item /= null then
         if Status = Coyote_Math_Jobs.Valid
           and then Coyote_Math_Jobs.Id (Item.all) = Current
           and then Coyote_Math_Jobs.Generation (Item.all) = Element.Generation
           and then Coyote_Math_Jobs.Source (Item.all) =
             To_String (Element.LaTeX_Text)
         then
            Element.Parsed := Coyote_Math_Jobs.Parse_Document (Item.all);
            Element.Layout := Coyote_Math_Jobs.Layout (Item.all);
            Element.Meaning := Coyote_Math_Jobs.Semantics (Item.all);
            Clear_Accessibility (Element.all);
            Measure_Layout (Element.all);
            if Coyote_Math_Jobs.Has_Raster (Item.all) then
               Element.Raster_Width :=
                 Coyote_Math_Jobs.Raster_Width (Item.all);
               Element.Raster_Height :=
                 Coyote_Math_Jobs.Raster_Height (Item.all);
               Element.Raster_Baseline :=
                 Coyote_Math_Jobs.Raster_Baseline (Item.all);
               if Element.Raster_Width > 0
                 and then Element.Raster_Height > 0
                 and then Element.Raster_Width <= 8_192
                 and then Element.Raster_Height <= 4_096
               then
                  declare
                     Required : constant Natural :=
                       Element.Raster_Width * Element.Raster_Height * 4;
                  begin
                     if Required <= Max_Retained_Raster_Bytes
                       and then Raster_Byte_Ledger <=
                         Max_Retained_Raster_Bytes - Required
                     then
                        Raster_Byte_Ledger :=
                          Raster_Byte_Ledger + Required;
                        Element.Raster_Bytes := Required;
                        Element.Raster_Image := Cairo.Image_Surface.Create
                          (Cairo.Image_Surface.Cairo_Format_ARGB32,
                           Gint (Element.Raster_Width),
                           Gint (Element.Raster_Height));
                        if Cairo.Surface.Status (Element.Raster_Image) =
                          Cairo.Cairo_Status_Success
                        then
                           Element.Raster_Result := Item;
                           Element.Raster_Row := 0;
                           Item := null;
                        else
                           Clear_Raster (Element.all);
                        end if;
                     else
                        Element.Valid := False;
                     end if;
                  end;
               else
                  Element.Valid := False;
               end if;
            end if;
         end if;
         Coyote_Math_Jobs.Release (Item);
      else
         Element.Valid := False;
         Element.Math_Width := 0;
         Element.Math_Height := 1;
         Element.Math_Baseline := 0;
      end if;
      Update_Visibility (Element.all);
      if Element.Area /= null then
         Element.Area.Queue_Draw;
      end if;
      if Element.Raster_Result /= null then
         if Adopt_Raster (Element) then
            return True;
         end if;
         Update_Visibility (Element.all);
         if Element.Area /= null then
            Element.Area.Queue_Draw;
         end if;
         Element.Poll_Source := 0;
         return False;
      end if;
      if Element.Valid and then Element.Accessibility /= null
        and then Element.Accessibility.Get_Expanded
      then
         declare
            Params : Glib.Values.GValues;
         begin
            Populate_Accessibility
              (Element.Accessibility, Params, Element);
         end;
      end if;
      Element.Poll_Source := 0;
      return False;
   exception
      when others =>
         if Item /= null then
            Coyote_Math_Jobs.Release (Item);
         end if;
         if Element /= null then
            if Current /= 0 then
               Coyote_Math_Jobs.Abandon (Current, Element.Generation);
            end if;
            Element.Poll_Source := 0;
            Element.Request := 0;
            Clear_Raster (Element.all);
            Element.Valid := False;
            Element.Math_Width := 0;
            Element.Math_Height := 1;
            Element.Math_Baseline := 0;
            Update_Visibility (Element.all);
         end if;
         return False;
   end Poll_Result;

   procedure Start_Request (Element : in out Instance) is
      Status : Coyote_Math_Jobs.Job_Status;
      Color : Gdk.RGBA.Gdk_RGBA :=
        (Red => 0.0, Green => 0.0, Blue => 0.0, Alpha => 1.0);
      Foreground : Coyote_Math_Jobs.Math_Color;
   begin
      Cancel_Request (Element);
      Element.Generation := Coyote_Math_Jobs.View_Generation
        (Natural (Element.Generation) + 1);
      Element.Layout_Valid := False;
      Element.Valid := False;
      Element.Math_Width := 0;
      Element.Math_Height := 1;
      Element.Math_Baseline := 0;
      Coyote_Math_Jobs.Start;
      if Element.Area /= null then
         Gtk.Style_Context.Get_Style_Context (Element.Area).Get_Color
           (Gtk.Enums.Gtk_State_Flag_Normal, Color);
      end if;
      Foreground :=
        (Red => Long_Float (Color.Red),
         Green => Long_Float (Color.Green),
         Blue => Long_Float (Color.Blue),
         Alpha => Long_Float (Color.Alpha));
      Coyote_Math_Jobs.Submit
        (To_String (Element.LaTeX_Text), Element.Request,
         Element.Generation, Math_Layout.Display_Style,
         Color_Enabled => True,
         Color => Foreground,
         Request_Raster => True,
         Em_Pixels => 24.0 * Element.Math_Scale,
         Font_Directory => Coyote_Math_Resources.Font_Directory,
         Status => Status);
      if Status /= Coyote_Math_Jobs.Pending then
         Element.Request := 0;
         Update_Visibility (Element);
         return;
      end if;
      Element.Poll_Source := Poll_Sources.Timeout_Add
        (10, Poll_Result'Access, Element'Unchecked_Access);
      if Element.Poll_Source = 0 then
         Coyote_Math_Jobs.Abandon (Element.Request, Element.Generation);
         Element.Request := 0;
      end if;
   exception
      when others =>
         if Element.Request /= 0 then
            Coyote_Math_Jobs.Abandon
              (Element.Request, Element.Generation);
         end if;
         Element.Valid := False;
         Element.Request := 0;
   end Start_Request;

   procedure Update_Visibility (Element : in out Instance) is
   begin
      if Element.Root = null then
         return;
      end if;
      if Element.Valid and then Element.Raster_Ready
      then
         Element.Area.Show;
         Element.Fallback.Hide;
         Element.Area.Set_Size_Request
           (Gint (Element.Math_Width), Gint (Element.Math_Height));
      else
         Element.Area.Hide;
         Element.Fallback.Set_Text (To_String (Element.Source_Text));
         Element.Fallback.Show;
         Element.Area.Set_Size_Request (-1, -1);
      end if;
   end Update_Visibility;

   function On_Draw
     (Area : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context : Cairo.Cairo_Context;
      Element : Instance_Access) return Boolean
   is
      X : Long_Float;
      Color : Gdk.RGBA.Gdk_RGBA;
   begin
      if Element = null or else Element.Detached or else not Element.Valid then
         return False;
      end if;
      X := Long_Float'Max
        (2.0, (Long_Float (Area.Get_Allocated_Width)
          - Long_Float (Element.Math_Width - 4)) / 2.0);
      Gtk.Style_Context.Get_Style_Context (Area).Get_Color
        (Gtk.Enums.Gtk_State_Flag_Normal, Color);
      if Element.Raster_Ready and then
        Element.Raster_Image /= Cairo.Null_Surface
      then
         Cairo.Set_Source_Surface
           (Context, Element.Raster_Image, Glib.Gdouble (X),
            Glib.Gdouble (Long_Float'Max
              (0.0, Long_Float (Element.Math_Baseline
                - Natural'Min (Element.Math_Baseline,
                  Element.Raster_Baseline)))));
         Cairo.Paint (Context);
      end if;
      return True;
   exception
      when others =>
         if Element /= null then
            Element.Valid := False;
            Update_Visibility (Element.all);
         end if;
         return False;
   end On_Draw;

   function New_Element
     (LaTeX : String; Source : String; Scale : Long_Float := 1.0)
      return Instance_Access
   is
      Element : Instance_Access := new Instance;
   begin
      Create (Element.all, LaTeX, Source, Scale);
      return Element;
   exception
      when others =>
         Free (Element);
         return null;
   end New_Element;

   procedure Create
     (Element : in out Instance; LaTeX : String; Source : String;
      Scale : Long_Float := 1.0)
   is
      Safe_Scale : Long_Float := 1.0;
   begin
      if Scale'Valid and then Scale >= -Long_Float'Last
        and then Scale <= Long_Float'Last
      then
         Safe_Scale := Long_Float'Min (8.0, Long_Float'Max (Scale, 0.01));
      end if;
      Clear_Raster (Element);
      Cancel_Request (Element);
      Element.Source_Text := To_Unbounded_String (Source);
      Element.LaTeX_Text := To_Unbounded_String (LaTeX);
      Element.Math_Scale := Safe_Scale;
      Element.Detached := False;
      if Element.Root = null then
         Gtk.Box.Gtk_New_Vbox (Element.Root, False, 2);
         Gtk.Drawing_Area.Gtk_New (Element.Area);
         Gtk.Label.Gtk_New (Element.Fallback, Source);
         Gtk.Expander.Gtk_New (Element.Accessibility, "Math structure");
         Element.Accessibility.Set_Expanded (False);
         Element.Accessibility.Set_Can_Focus (True);
         Element.Accessibility_Handler := Accessibility_Callback.Connect
           (Element.Accessibility, "notify::expanded",
            Accessibility_Handler, Element'Unchecked_Access);
         Element.Accessibility_Connected := True;
         Apply_Response_Style (Element.Root);
         Apply_Response_Style (Element.Area);
         Element.Area.Set_No_Show_All (True);
         Element.Fallback.Set_No_Show_All (True);
         Element.Fallback.Set_Xalign (0.0);
         Element.Fallback.Set_Line_Wrap (True);
         Element.Fallback.Set_Selectable (True);
         Element.Area.Set_Halign (Gtk.Widget.Align_Center);
         Element.Draw_Handler := Draw_Callback.Connect
           (Element.Area, Gtk.Widget.Signal_Draw,
            Draw_Context_Marshaller.To_Marshaller (On_Draw'Access),
            Element'Unchecked_Access);
         Element.Root.Pack_Start (Element.Area, False, True, 2);
         Element.Root.Pack_Start (Element.Fallback, False, True, 2);
         Element.Root.Pack_Start (Element.Accessibility, False, True, 2);
      end if;
      Math_Painter.Load (Element.Fonts, Coyote_Math_Resources.Font_Directory);
      Start_Request (Element);
      Update_Visibility (Element);
   exception
      when others =>
         Element.Valid := False;
         Update_Visibility (Element);
   end Create;

   function Render_Inline
     (LaTeX : String;
      Baseline : out Natural;
      Scale : Long_Float := 1.0;
      Em_Pixels : Long_Float := 20.0;
      Color : Gdk.RGBA.Gdk_RGBA :=
        (Red => 0.0, Green => 0.0, Blue => 0.0, Alpha => 1.0))
      return Gdk.Pixbuf.Gdk_Pixbuf
   is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (LaTeX);
      Layout : constant Math_Layout.Box :=
        Math_Layout.Build (Parsed, Math_Layout.Text_Style);
   begin
      return Render_Layout_Inline
        (Parsed, Layout, Baseline, Scale, Em_Pixels, Color);
   end Render_Inline;

   function Render_Layout_Inline
     (Parsed : Math_Syntax.Document;
      Layout : Math_Layout.Box;
      Baseline : out Natural;
      Scale : Long_Float := 1.0;
      Em_Pixels : Long_Float := 20.0;
      Color : Gdk.RGBA.Gdk_RGBA :=
        (Red => 0.0, Green => 0.0, Blue => 0.0, Alpha => 1.0))
      return Gdk.Pixbuf.Gdk_Pixbuf
   is
      Fonts : Math_Painter.Font_Set;
      Safe_Scale : Long_Float := 1.0;
      Em : Long_Float;
      Width_Value : Long_Float;
      Height_Value : Long_Float;
      Width : Natural;
      Height : Natural;
      Surface : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Context : Cairo.Cairo_Context := Cairo.Null_Context;
      Pixbuf : Gdk.Pixbuf.Gdk_Pixbuf := null;
   begin
      Baseline := 0;
      if not Math_Syntax.Is_Valid (Parsed) or else not Layout.Valid
        or else not Em_Pixels'Valid
        or else Em_Pixels < -Long_Float'Last
        or else Em_Pixels > Long_Float'Last
        or else Em_Pixels <= 0.0 or else Em_Pixels > 256.0
      then
         return null;
      end if;
      if Scale'Valid and then Scale >= -Long_Float'Last
        and then Scale <= Long_Float'Last
      then
         Safe_Scale := Long_Float'Min (8.0, Long_Float'Max (Scale, 0.01));
      end if;
      Em := Em_Pixels * Safe_Scale;
      if not Em'Valid or else Em > 256.0 then
         return null;
      end if;
      Width_Value := Layout.Width * Em;
      Height_Value := (Layout.Ascent + Layout.Descent) * Em;
      if not Width_Value'Valid or else not Height_Value'Valid
        or else Width_Value > 1_996.0 or else Height_Value > 508.0
      then
         return null;
      end if;
      Width := Natural'Max
        (1, Natural (Long_Float'Ceiling (Width_Value)) + 4);
      Height := Natural'Max
        (1, Natural (Long_Float'Ceiling (Height_Value)) + 4);
      Baseline := Natural'Max (1, Natural (Long_Float'Ceiling
        (Layout.Ascent * Em)) + 2);
      Math_Painter.Load (Fonts, Coyote_Math_Resources.Font_Directory);
      Surface := Cairo.Image_Surface.Create
        (Cairo.Image_Surface.Cairo_Format_ARGB32,
         Gint (Width), Gint (Height));
      if Cairo.Surface.Status (Surface) /= Cairo.Cairo_Status_Success then
         Cairo.Surface.Destroy (Surface);
         Surface := Cairo.Null_Surface;
         return null;
      end if;
      Context := Cairo.Create (Surface);
      if Cairo.Status (Context) /= Cairo.Cairo_Status_Success then
         Cairo.Destroy (Context);
         Context := Cairo.Null_Context;
         Cairo.Surface.Destroy (Surface);
         Surface := Cairo.Null_Surface;
         return null;
      end if;
      Gdk.Cairo.Set_Source_RGBA (Context, Color);
      Math_Painter.Draw (Fonts, Context, Layout, 2.0,
        Long_Float (Baseline), Em);
      Cairo.Destroy (Context);
      Context := Cairo.Null_Context;
      Cairo.Surface.Flush (Surface);
      Pixbuf := Gdk.Pixbuf.Get_From_Surface
        (Surface, 0, 0, Gint (Width), Gint (Height));
      Cairo.Surface.Destroy (Surface);
      Surface := Cairo.Null_Surface;
      return Pixbuf;
   exception
      when others =>
         if Context /= Cairo.Null_Context then
            Cairo.Destroy (Context);
         end if;
         if Surface /= Cairo.Null_Surface then
            Cairo.Surface.Destroy (Surface);
         end if;
         return null;
   end Render_Layout_Inline;

   function Widget (Element : Instance) return Gtk.Box.Gtk_Box is
   begin
      return Element.Root;
   end Widget;

   procedure Set_LaTeX
     (Element : in out Instance; LaTeX : String; Source : String) is
   begin
      Clear_Raster (Element);
      Clear_Accessibility (Element);
      Element.Source_Text := To_Unbounded_String (Source);
      Element.LaTeX_Text := To_Unbounded_String (LaTeX);
      Start_Request (Element);
      Update_Visibility (Element);
      if Element.Area /= null then
         Element.Area.Queue_Draw;
      end if;
   end Set_LaTeX;

   procedure Set_Scale (Element : in out Instance; Scale : Long_Float) is
      Safe_Scale : Long_Float := 1.0;
   begin
      if Scale'Valid and then Scale >= -Long_Float'Last
        and then Scale <= Long_Float'Last
      then
         Safe_Scale := Long_Float'Min (8.0, Long_Float'Max (Scale, 0.01));
      end if;
      if Element.Math_Scale = Safe_Scale then
         return;
      end if;
      Element.Math_Scale := Safe_Scale;
      Clear_Raster (Element);
      Start_Request (Element);
      Update_Visibility (Element);
      if Element.Area /= null then
         Element.Area.Queue_Draw;
      end if;
   end Set_Scale;

   procedure Set_Font (Element : in out Instance;
      Desc : Pango.Font.Pango_Font_Description) is
   begin
      if Element.Fallback /= null then
         Element.Fallback.Modify_Font (Desc);
      end if;
      if Element.Valid then
         declare
            Size : constant Glib.Gint := Pango.Font.Get_Size (Desc);
            Scale : constant Long_Float :=
              Long_Float'Max (0.01, Long_Float (Size) / (12.0 * 1024.0));
         begin
            Set_Scale (Element, Scale);
         end;
      end if;
   end Set_Font;

   procedure Detach (Element : in out Instance) is
   begin
      if Element.Detached then
         return;
      end if;
      Element.Detached := True;
      Cancel_Request (Element);
      Clear_Raster (Element);
      if Element.Accessibility /= null
        and then Element.Accessibility_Connected
      then
         Gtk.Handlers.Disconnect
           (Element.Accessibility, Element.Accessibility_Handler);
         Element.Accessibility_Connected := False;
      end if;
      if Element.Area /= null then
         if Element.Draw_Handler.Id /= Gtk.Handlers.Null_Handler_Id then
            Gtk.Handlers.Disconnect (Element.Area, Element.Draw_Handler);
            Element.Draw_Handler.Id := Gtk.Handlers.Null_Handler_Id;
         end if;
         Element.Area.Hide;
      end if;
   end Detach;

   procedure Free (Element : in out Instance_Access) is
      procedure Deallocate is new Ada.Unchecked_Deallocation
        (Instance, Instance_Access);
   begin
      if Element /= null then
         Element.all.Detach;
         Deallocate (Element);
      end if;
   end Free;

   function Is_Valid (Element : Instance) return Boolean is
   begin
      return Element.Valid and then not Element.Detached;
   end Is_Valid;
   function Is_Pending (Element : Instance) return Boolean is
   begin
      return (Element.Request /= 0 or else Element.Poll_Source /= 0
        or else Element.Raster_Result /= null)
        and then not Element.Detached;
   end Is_Pending;
   function Source (Element : Instance) return String is
     (To_String (Element.Source_Text));
   function LaTeX (Element : Instance) return String is
     (To_String (Element.LaTeX_Text));
   function Width (Element : Instance) return Natural is
     (Element.Math_Width);
   function Height (Element : Instance) return Natural is
     (Element.Math_Height);
   function Baseline (Element : Instance) return Natural is
     (Element.Math_Baseline);
   function Scale (Element : Instance) return Long_Float is
     (Element.Math_Scale);
end Coyote_GUI.Math_Element;
