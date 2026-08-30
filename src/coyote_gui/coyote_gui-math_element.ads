--  Coyote_GUI.Math_Element — native Presentation MathML component.
--
--  A math element owns a localized GTK drawing area for valid MathML and a
--  selectable source label for fallback and copy operations.  All operations
--  are called on the GTK main-loop task.
--
--  Project: coyote

with Ada.Strings.Unbounded;
with Gtk.Box;
with Gtk.Drawing_Area;
with Gtk.Label;

package Coyote_GUI.Math_Element is

   type Instance is tagged limited private;
   type Instance_Access is access all Instance;

   --  Create a heap-stable GTK element and measure MathML at Scale.
   function New_Element
     (MathML : String;
      Source : String;
      Scale  : Long_Float := 1.0) return Instance_Access;

   --  Initialize an existing element and measure MathML at Scale.
   procedure Create
     (Element : in out Instance;
      MathML  : String;
      Source  : String;
      Scale   : Long_Float := 1.0);
   --  Return the root widget to pack into a native response container.
   function Widget (Element : Instance) return Gtk.Box.Gtk_Box;

   --  Change the retained MathML and source, then remeasure.
   procedure Set_MathML
     (Element : in out Instance;
      MathML  : String;
      Source  : String);

   --  Remeasure and redraw at the requested positive scale.
   procedure Set_Scale
     (Element : in out Instance;
      Scale   : Long_Float);

   --  Mark GTK callbacks inactive before the owning component is removed.
   procedure Detach (Element : in out Instance);

   --  Release an element after its root widget has been removed.
   procedure Free (Element : in out Instance_Access);

   function Is_Valid (Element : Instance) return Boolean;
   function Source (Element : Instance) return String;
   function MathML (Element : Instance) return String;
   function Width (Element : Instance) return Natural;
   function Height (Element : Instance) return Natural;
   function Baseline (Element : Instance) return Natural;
   function Scale (Element : Instance) return Long_Float;

private

   type Instance is tagged limited record
      Root          : Gtk.Box.Gtk_Box;
      Area          : Gtk.Drawing_Area.Gtk_Drawing_Area;
      Fallback      : Gtk.Label.Gtk_Label;
      Source_Text   : Ada.Strings.Unbounded.Unbounded_String;
      MathML_Text   : Ada.Strings.Unbounded.Unbounded_String;
      Math_Scale    : Long_Float := 1.0;
      Math_Width    : Natural := 0;
      Math_Height   : Natural := 1;
      Math_Baseline : Natural := 0;
      Valid         : Boolean := False;
      Detached      : Boolean := False;
   end record;

end Coyote_GUI.Math_Element;
