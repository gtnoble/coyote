--  Coyote_GUI.Math_Element body.
--
--  Lasem is called only on the GTK task.  Each drawing callback receives its
--  own heap-stable element access value, avoiding shared renderer state.
--
--  Project: coyote

with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Cairo;
with Coyote_Lasem;
with Glib;                   use Glib;
with Glib.Error;
with Gtk.Drawing_Area;
with Gtk.Handlers;
with Gtk.Css_Provider;
with Gtk.Style_Context;
with Gtk.Style_Provider;
with Gtk.Widget;
with Interfaces.C;
with Interfaces.C.Strings;
with Pango.Enums;

package body Coyote_GUI.Math_Element is

   use type Interfaces.C.Strings.chars_ptr;
   use type Interfaces.C.double;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Drawing_Area.Gtk_Drawing_Area;
   use type Gtk.Label.Gtk_Label;

   package Draw_Callback is new Gtk.Handlers.User_Return_Callback
     (Gtk.Drawing_Area.Gtk_Drawing_Area_Record,
      Boolean,
      Instance_Access);

   package Draw_Context_Marshaller is new
     Draw_Callback.Marshallers.Generic_Marshaller
       (Cairo.Cairo_Context, Cairo.Get_Context);

   package Destroy_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Drawing_Area.Gtk_Drawing_Area_Record,
      Instance_Access);

   function On_Draw
     (Area     : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context  : Cairo.Cairo_Context;
      Element  : Instance_Access) return Boolean;

   procedure On_Destroy
     (Area    : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Element : Instance_Access);

   procedure Queue_Redraw (Element : in out Instance);

   procedure Apply_Response_Style
     (Widget : not null access Gtk.Widget.Gtk_Widget_Record'Class)
   is
      use Gtk.Css_Provider;
      use Gtk.Style_Context;
      use Gtk.Style_Provider;
      CSS : constant String :=
        ".coyote-response-content { background-color: @theme_base_color; "
        & "color: @theme_text_color; }";
      Provider  : Gtk_Css_Provider;
      CSS_Error : aliased Glib.Error.GError;
      Ignored   : Boolean;
      pragma Unreferenced (Ignored);
   begin
      Gtk_New (Provider);
      Ignored := Provider.Load_From_Data (CSS, CSS_Error'Access);
      Get_Style_Context (Widget).Add_Class ("coyote-response-content");
      Get_Style_Context (Widget).Add_Provider
        (Implements_Gtk_Style_Provider.To_Interface (Provider),
         Guint (Priority_Application));
   end Apply_Response_Style;

   procedure Measure (Element : in out Instance) is
      C_Text  : constant Interfaces.C.char_array :=
        Interfaces.C.To_C (To_String (Element.MathML_Text),
                           Append_Nul => True);
      Width   : aliased Interfaces.C.unsigned := 0;
      Height  : aliased Interfaces.C.unsigned := 0;
      Baseline : aliased Interfaces.C.unsigned := 0;
      Error   : Interfaces.C.Strings.chars_ptr;
   begin
      Error := Coyote_Lasem.Measure_MathML
        (C_Text,
         Interfaces.C.long (Length (Element.MathML_Text)),
         Width'Access,
         Height'Access,
         Baseline'Access,
         Interfaces.C.double (Element.Math_Scale));
      if Error = Interfaces.C.Strings.Null_Ptr then
         Element.Math_Width    := Natural (Width);
         Element.Math_Height   := Natural'Max (1, Natural (Height));
         Element.Math_Baseline := Natural (Baseline);
         Element.Valid         := True;
      else
         Coyote_Lasem.Free_Error (Error);
         Element.Math_Width     := 0;
         Element.Math_Height    := 1;
         Element.Math_Baseline  := 0;
         Element.Valid          := False;
      end if;
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
     (Area     : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Context  : Cairo.Cairo_Context;
      Element  : Instance_Access) return Boolean
   is
      Error : Interfaces.C.Strings.chars_ptr;
   begin
      if Element = null or else Element.Detached or else not Element.Valid then
         return False;
      end if;
      declare
         X : constant Interfaces.C.double :=
           Interfaces.C.double'Max
             (0.0,
              (Interfaces.C.double (Area.Get_Allocated_Width)
               - Interfaces.C.double (Element.Math_Width)) / 2.0);
      begin
         Error := Coyote_Lasem.Render_MathML
           (Interfaces.C.To_C (To_String (Element.MathML_Text),
                               Append_Nul => True),
            Interfaces.C.long (Length (Element.MathML_Text)),
            Context,
            X,
            0.0,
            Interfaces.C.double (Element.Math_Scale));
         if Error /= Interfaces.C.Strings.Null_Ptr then
            Coyote_Lasem.Free_Error (Error);
            Element.Valid := False;
            Update_Visibility (Element.all);
         end if;
      end;
      return True;
   exception
      when others =>
         return False;
   end On_Draw;

   procedure On_Destroy
     (Area    : access Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class;
      Element : Instance_Access)
   is
      pragma Unreferenced (Area);
   begin
      if Element /= null then
         Element.Detached := True;
         Element.Area := null;
      end if;
   exception
      when others =>
         null;
   end On_Destroy;

   function New_Element
     (MathML : String;
      Source : String;
      Scale  : Long_Float := 1.0) return Instance_Access
   is
      Element : Instance_Access := new Instance;
   begin
      Create (Element.all, MathML, Source, Scale);
      return Element;
   exception
      when others =>
         Free (Element);
         return null;
   end New_Element;

   procedure Create
     (Element : in out Instance;
      MathML  : String;
      Source  : String;
      Scale   : Long_Float := 1.0)
   is
   begin
      Element.Source_Text := To_Unbounded_String (Source);
      Element.MathML_Text := To_Unbounded_String (MathML);
      Element.Math_Scale  := Long_Float'Max (Scale, 0.01);
      Element.Detached    := False;
      if Element.Root = null then
         Gtk.Box.Gtk_New_Vbox
           (Element.Root, Homogeneous => False, Spacing => 2);
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
         Draw_Callback.Connect
           (Element.Area,
            Gtk.Widget.Signal_Draw,
            Draw_Context_Marshaller.To_Marshaller (On_Draw'Access),
            Element'Unchecked_Access);
         Destroy_Callback.Connect
           (Element.Area,
            Gtk.Widget.Signal_Destroy,
            On_Destroy'Access,
            Element'Unchecked_Access);
         Element.Root.Pack_Start
           (Element.Area, Expand => False, Fill => True, Padding => 2);
         Element.Root.Pack_Start
           (Element.Fallback, Expand => False, Fill => True, Padding => 2);
      end if;
      Measure (Element);
      Update_Visibility (Element);
   exception
      when others =>
         Element.Valid := False;
         Update_Visibility (Element);
   end Create;

   function Widget (Element : Instance) return Gtk.Box.Gtk_Box is
   begin
      return Element.Root;
   end Widget;

   procedure Set_MathML
     (Element : in out Instance;
      MathML  : String;
      Source  : String)
   is
   begin
      Element.Source_Text := To_Unbounded_String (Source);
      Element.MathML_Text := To_Unbounded_String (MathML);
      Measure (Element);
      Update_Visibility (Element);
      Queue_Redraw (Element);
   end Set_MathML;

   procedure Set_Scale
     (Element : in out Instance;
      Scale   : Long_Float)
   is
   begin
      Element.Math_Scale := Long_Float'Max (Scale, 0.01);
      Measure (Element);
      Update_Visibility (Element);
      Queue_Redraw (Element);
   end Set_Scale;

   procedure Queue_Redraw (Element : in out Instance) is
   begin
      if Element.Area /= null and then not Element.Detached then
         Element.Area.Queue_Draw;
      end if;
   end Queue_Redraw;

   procedure Detach (Element : in out Instance) is
   begin
      Element.Detached := True;
      if Element.Area /= null then
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
   begin
      return To_String (Element.Source_Text);
   end Source;

   function MathML (Element : Instance) return String is
   begin
      return To_String (Element.MathML_Text);
   end MathML;

   function Width (Element : Instance) return Natural is
   begin
      return Element.Math_Width;
   end Width;

   function Height (Element : Instance) return Natural is
   begin
      return Element.Math_Height;
   end Height;

   function Baseline (Element : Instance) return Natural is
   begin
      return Element.Math_Baseline;
   end Baseline;

   function Scale (Element : Instance) return Long_Float is
   begin
      return Element.Math_Scale;
   end Scale;

end Coyote_GUI.Math_Element;
