--  Coyote_GUI.Response_Renderer — shared semantic response presentation.
--
--  All operations are called from the GTK main-loop task.  The renderer owns
--  response widgets and native MathML lifetime; its caller owns exchange and
--  step lifecycle.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Coyote_GUI.Math_Element;
with Coyote_Renderer.Semantics;
with Gtk.Box;
with Gtk.Grid;
with Gtk.Label;
with Gtk.Text_Buffer;
with Gtk.Text_View;
with Gtk.Widget;
with Pango.Font;

package Coyote_GUI.Response_Renderer is

   type Instance is tagged limited private;

   --  Render a parsed semantic document in Parent.  Source is retained by
   --  the caller for compatibility/fallback policy; semantic blocks determine
   --  all realized content and source order.
   procedure Render
     (R                       : in out Instance;
      Parent                  :        not null access Gtk.Box.Gtk_Box_Record'Class;
      Document                :        Coyote_Renderer.Semantics.Document;
      Source                  :        String;
      Active_Text             :    out Gtk.Text_Buffer.Gtk_Text_Buffer;
      Active_View             :    out Gtk.Text_View.Gtk_Text_View;
      Math_Scale              :        Long_Float := 1.0;
      Use_Math_Fallback       :        Boolean := True;
      Normalize_Terminal_Math :        Boolean := False);

   --  Remove the previous renderer-owned response and realize a new semantic
   --  snapshot.  Exchange and step lifecycle remain with the caller.
   procedure Replace
     (R                       : in out Instance;
      Parent                  :        not null access Gtk.Box.Gtk_Box_Record'Class;
      Document                :        Coyote_Renderer.Semantics.Document;
      Source                  :        String;
      Active_Text             :    out Gtk.Text_Buffer.Gtk_Text_Buffer;
      Active_View             :    out Gtk.Text_View.Gtk_Text_View;
      Math_Scale              :        Long_Float := 1.0;
      Use_Math_Fallback       :        Boolean := True;
      Normalize_Terminal_Math :        Boolean := False);

   function Response_Box (R : Instance) return Gtk.Box.Gtk_Box;

   --  Shared hooks used by the incremental compatibility path while it keeps
   --  its own parser and event lifecycle.
   procedure Configure_Text_View
     (View : not null access Gtk.Text_View.Gtk_Text_View_Record'Class);
   procedure Apply_Response_Style
     (Widget : not null access Gtk.Widget.Gtk_Widget_Record'Class);
   procedure Pack_Response_Block
     (Parent : not null access Gtk.Box.Gtk_Box_Record'Class;
      Child  : not null access Gtk.Widget.Gtk_Widget_Record'Class);

   --  Serialize one semantic block using the response presentation policy.
   function Block_Markup
     (Document : Coyote_Renderer.Semantics.Document;
      Block    : Coyote_Renderer.Semantics.Block_Id) return String;

   --  Realize one native semantic block in Parent.  The caller removes any
   --  previous payload children and calls Clear before replacing it.
   procedure Render_Native_Block
     (R                       : in out Instance;
      Parent                  :        not null access Gtk.Box.Gtk_Box_Record'Class;
      Document                :        Coyote_Renderer.Semantics.Document;
      Block                   :        Coyote_Renderer.Semantics.Block_Id;
      Normalize_Terminal_Math :        Boolean := False;
      Math_Scale              :        Long_Float := 1.0);

   procedure Release_Math_Element
     (R       : in out Instance;
      Element : in out Coyote_GUI.Math_Element.Instance_Access);

   function Text_View_Count (R : Instance) return Natural;
   function Text_View_At
     (R : Instance; Index : Positive) return Gtk.Text_View.Gtk_Text_View;

   function Table_Count (R : Instance) return Natural;
   function Table_Grid_At
     (R : Instance; Index : Positive) return Gtk.Grid.Gtk_Grid;

   function Math_Element_Count (R : Instance) return Natural;
   function Math_Element_At
     (R : Instance; Index : Positive)
      return Coyote_GUI.Math_Element.Instance_Access;

   procedure Set_Font
     (R          : in out Instance; Desc : Pango.Font.Pango_Font_Description;
      Math_Scale :        Long_Float := 1.0);
   function Math_Scale (R : Instance) return Long_Float;

   procedure Clear (R : in out Instance);

private

   use type Gtk.Text_View.Gtk_Text_View;
   use type Coyote_GUI.Math_Element.Instance_Access;
   use type Gtk.Grid.Gtk_Grid;
   use type Gtk.Label.Gtk_Label;

   package Text_View_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Gtk.Text_View.Gtk_Text_View);
   package Math_Element_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Coyote_GUI.Math_Element.Instance_Access);
   package Table_Grid_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Gtk.Grid.Gtk_Grid);
   package Table_Cell_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Gtk.Label.Gtk_Label);

   type Instance is tagged limited record
      Response      : Gtk.Box.Gtk_Box;
      Text_Views    : Text_View_Vectors.Vector;
      Math_Elements : Math_Element_Vectors.Vector;
      Table_Grids   : Table_Grid_Vectors.Vector;
      Table_Cells   : Table_Cell_Vectors.Vector;
      Math_Scale    : Long_Float := 1.0;
   end record;

end Coyote_GUI.Response_Renderer;
