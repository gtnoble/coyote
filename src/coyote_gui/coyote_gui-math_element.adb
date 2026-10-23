--  Coyote_GUI.Math_Element body.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Cairo;
with Cairo.Image_Surface;
with Cairo.Surface;
with Gdk.Cairo;
with Gdk.Pixbuf;
with Gdk.RGBA;
with Coyote_Math_Resources;
with Glib; use Glib;
with Glib.Error;
with Gtk.Css_Provider;
with Gtk.Drawing_Area;
with Gtk.Enums;
with Gtk.Handlers;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Widget;

package body Coyote_GUI.Math_Element is
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Drawing_Area.Gtk_Drawing_Area;
   use type Gtk.Label.Gtk_Label;
   use type Cairo.Cairo_Context;
   use type Cairo.Cairo_Surface;
   use type Cairo.Cairo_Status;

   package Draw_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Drawing_Area.Gtk_Drawing_Area_Record, Boolean, Instance_Access);
   package Draw_Context_Marshaller is new Draw_Callback.Marshallers
     .Generic_Marshaller (Cairo.Cairo_Context, Cairo.Get_Context);

   function On_Draw
     (Area : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context : Cairo.Cairo_Context;
      Element : Instance_Access) return Boolean;

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

   procedure Measure (Element : in out Instance) is
      Em : Long_Float;
      Width : Long_Float;
      Height : Long_Float;
   begin
      Element.Parsed := Math_Syntax.Parse (To_String (Element.LaTeX_Text));
      Element.Layout := Math_Layout.Build
        (Element.Parsed, Math_Layout.Display_Style);
      Element.Valid := Math_Syntax.Is_Valid (Element.Parsed)
        and then Element.Layout.Valid;
      if Element.Valid then
         Em := 24.0 * Element.Math_Scale;
         Width := Element.Layout.Width * Em;
         Height := (Element.Layout.Ascent + Element.Layout.Descent) * Em;
         if not Width'Valid or else not Height'Valid
           or else Width > 8_188.0 or else Height > 4_092.0
         then
            Element.Valid := False;
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
      if not Element.Valid then
         Element.Math_Width := 0;
         Element.Math_Baseline := 0;
         Element.Math_Height := 1;
      end if;
   exception
      when others =>
         Element.Valid := False;
         Element.Math_Width := 0;
         Element.Math_Height := 1;
         Element.Math_Baseline := 0;
   end Measure;

   procedure Update_Visibility (Element : in out Instance) is
   begin
      if Element.Root = null then
         return;
      end if;
      if Element.Valid then
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
      Gdk.Cairo.Set_Source_RGBA (Context, Color);
      Math_Painter.Draw
        (Element.Fonts, Context, Element.Layout, X,
         Long_Float (Element.Math_Baseline),
         24.0 * Element.Math_Scale);
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
      Element.Source_Text := To_Unbounded_String (Source);
      Element.LaTeX_Text := To_Unbounded_String (LaTeX);
      Element.Math_Scale := Safe_Scale;
      Element.Detached := False;
      if Element.Root = null then
         Gtk.Box.Gtk_New_Vbox (Element.Root, False, 2);
         Gtk.Drawing_Area.Gtk_New (Element.Area);
         Gtk.Label.Gtk_New (Element.Fallback, Source);
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
      end if;
      Math_Painter.Load (Element.Fonts, Coyote_Math_Resources.Font_Directory);
      Measure (Element);
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
   end Render_Inline;

   function Widget (Element : Instance) return Gtk.Box.Gtk_Box is
   begin
      return Element.Root;
   end Widget;

   procedure Set_LaTeX
     (Element : in out Instance; LaTeX : String; Source : String) is
   begin
      Element.Source_Text := To_Unbounded_String (Source);
      Element.LaTeX_Text := To_Unbounded_String (LaTeX);
      Measure (Element);
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
      Element.Math_Scale := Safe_Scale;
      Measure (Element);
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
