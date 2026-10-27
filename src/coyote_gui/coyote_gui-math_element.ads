--  Coyote_GUI.Math_Element — native LaTeX display component.
--
--  All operations are called on the GTK main-loop task.

with Ada.Strings.Unbounded;
with Cairo;
with Gtk.Box;
with Gdk.Pixbuf;
with Gdk.RGBA;
with Gtk.Drawing_Area;
with Gtk.Handlers;
with Gtk.Label;
with Gtk.Expander;
with Gtk.Scrolled_Window;
with Gtk.Tree_View;
with Math_Semantics;
with Pango.Font;
with Math_Layout;
with Math_Painter;
with Math_Syntax;
with Coyote_Math_Jobs;
with Glib.Main;

package Coyote_GUI.Math_Element is
   type Instance is tagged limited private;
   type Instance_Access is access all Instance;

   function New_Element
     (LaTeX : String; Source : String; Scale : Long_Float := 1.0)
      return Instance_Access;
   procedure Create
     (Element : in out Instance; LaTeX : String; Source : String;
      Scale : Long_Float := 1.0);
   function Widget (Element : Instance) return Gtk.Box.Gtk_Box;
   function Render_Inline
     (LaTeX : String;
      Baseline : out Natural;
      Scale : Long_Float := 1.0;
      Em_Pixels : Long_Float := 20.0;
      Color : Gdk.RGBA.Gdk_RGBA :=
        (Red => 0.0, Green => 0.0, Blue => 0.0, Alpha => 1.0))
      return Gdk.Pixbuf.Gdk_Pixbuf;
   function Render_Layout_Inline
     (Parsed : Math_Syntax.Document;
      Layout : Math_Layout.Box;
      Baseline : out Natural;
      Scale : Long_Float := 1.0;
      Em_Pixels : Long_Float := 20.0;
      Color : Gdk.RGBA.Gdk_RGBA :=
        (Red => 0.0, Green => 0.0, Blue => 0.0, Alpha => 1.0))
      return Gdk.Pixbuf.Gdk_Pixbuf;
   procedure Set_LaTeX (Element : in out Instance; LaTeX : String;
      Source : String);
   procedure Set_Scale (Element : in out Instance; Scale : Long_Float);
   procedure Set_Font (Element : in out Instance;
      Desc : Pango.Font.Pango_Font_Description);
   procedure Detach (Element : in out Instance);
   procedure Free (Element : in out Instance_Access);
   function Is_Valid (Element : Instance) return Boolean;
   function Is_Pending (Element : Instance) return Boolean;
   function Source (Element : Instance) return String;
   function LaTeX (Element : Instance) return String;
   function Width (Element : Instance) return Natural;
   function Height (Element : Instance) return Natural;
   function Baseline (Element : Instance) return Natural;
   function Scale (Element : Instance) return Long_Float;
   function Retained_Raster_Bytes return Natural;
   function Max_Raster_Callback_Milliseconds return Long_Float;

private
   type Instance is tagged limited record
      Root : Gtk.Box.Gtk_Box;
      Area : Gtk.Drawing_Area.Gtk_Drawing_Area;
      Fallback : Gtk.Label.Gtk_Label;
      Accessibility : Gtk.Expander.Gtk_Expander;
      Meaning_View : Gtk.Tree_View.Gtk_Tree_View;
      Semantic_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Meaning : Math_Semantics.Document;
      Accessibility_Handler : Gtk.Handlers.Handler_Id;
      Accessibility_Connected : Boolean := False;
      Source_Text : Ada.Strings.Unbounded.Unbounded_String;
      LaTeX_Text : Ada.Strings.Unbounded.Unbounded_String;
      Parsed : Math_Syntax.Document;
      Layout : Math_Layout.Box;
      Layout_Valid : Boolean := False;
      Fonts : Math_Painter.Font_Set;
      Math_Scale : Long_Float := 1.0;
      Math_Width : Natural := 0;
      Math_Height : Natural := 1;
      Math_Baseline : Natural := 0;
      Valid : Boolean := False;
      Detached : Boolean := False;
      Draw_Handler : Gtk.Handlers.Handler_Id;
      Request : Coyote_Math_Jobs.Request_Id := 0;
      Generation : Coyote_Math_Jobs.View_Generation := 0;
      Poll_Source : Glib.Main.G_Source_Id := 0;
      Raster_Result : Coyote_Math_Jobs.Result_Access := null;
      Raster_Image : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Raster_Bytes : Natural := 0;
      Raster_Row : Natural := 0;
      Raster_Width : Natural := 0;
      Raster_Height : Natural := 0;
      Raster_Baseline : Natural := 0;
      Raster_Ready : Boolean := False;
   end record;
end Coyote_GUI.Math_Element;
