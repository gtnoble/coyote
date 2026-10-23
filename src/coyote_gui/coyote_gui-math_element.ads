--  Coyote_GUI.Math_Element — native LaTeX display component.
--
--  All operations are called on the GTK main-loop task.

with Ada.Strings.Unbounded;
with Gtk.Box;
with Gdk.Pixbuf;
with Gdk.RGBA;
with Gtk.Drawing_Area;
with Gtk.Handlers;
with Gtk.Label;
with Pango.Font;
with Math_Layout;
with Math_Painter;
with Math_Syntax;

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
   procedure Set_LaTeX (Element : in out Instance; LaTeX : String;
      Source : String);
   procedure Set_Scale (Element : in out Instance; Scale : Long_Float);
   procedure Set_Font (Element : in out Instance;
      Desc : Pango.Font.Pango_Font_Description);
   procedure Detach (Element : in out Instance);
   procedure Free (Element : in out Instance_Access);
   function Is_Valid (Element : Instance) return Boolean;
   function Source (Element : Instance) return String;
   function LaTeX (Element : Instance) return String;
   function Width (Element : Instance) return Natural;
   function Height (Element : Instance) return Natural;
   function Baseline (Element : Instance) return Natural;
   function Scale (Element : Instance) return Long_Float;

private
   type Instance is tagged limited record
      Root : Gtk.Box.Gtk_Box;
      Area : Gtk.Drawing_Area.Gtk_Drawing_Area;
      Fallback : Gtk.Label.Gtk_Label;
      Source_Text : Ada.Strings.Unbounded.Unbounded_String;
      LaTeX_Text : Ada.Strings.Unbounded.Unbounded_String;
      Parsed : Math_Syntax.Document;
      Layout : Math_Layout.Box;
      Fonts : Math_Painter.Font_Set;
      Math_Scale : Long_Float := 1.0;
      Math_Width : Natural := 0;
      Math_Height : Natural := 1;
      Math_Baseline : Natural := 0;
      Valid : Boolean := False;
      Detached : Boolean := False;
      Draw_Handler : Gtk.Handlers.Handler_Id;
   end record;
end Coyote_GUI.Math_Element;
