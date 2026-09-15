--  Coyote_GUI.Semantic_Response_Presenter — persistent semantic GTK view.
--
--  The presenter reconciles canonical semantic snapshots into stable
--  top-level response components.  All operations run on the GTK main task.
--
--  Project: coyote

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Coyote_GUI.Math_Element;
with Coyote_GUI.Response_Renderer;
with Coyote_Renderer.Semantics;
with Gtk.Box;
with Gtk.Grid;
with Gtk.Text_Buffer;
with Gtk.Text_View;
with Pango.Font;

package Coyote_GUI.Semantic_Response_Presenter is

   type Instance is tagged limited private;

   type Style_Kind is
     (Strong_Style,
      Em_Style,
      Del_Style,
      Link_Style,
      Inline_Code_Style,
      Code_Block_Style,
      Blockquote_Style,
      List_Style,
      Heading_Style);

   function Has_Style
     (Document : Coyote_Renderer.Semantics.Document;
      Style    : Style_Kind) return Boolean;

   procedure Create
     (P      : in out Instance;
      Parent : not null access Gtk.Box.Gtk_Box_Record'Class);
   procedure Mark_Dirty (P : in out Instance; Root_Id : Natural);
   procedure Record_Invalid (P : in out Instance);
   procedure Commit_Root (P : in out Instance; Root_Id : Natural);

   procedure Reconcile
     (P                       : in out Instance;
      Document                :        Coyote_Renderer.Semantics.Document;
      Normalize_Terminal_Math :        Boolean := False);

   procedure Set_Font
     (P          : in out Instance;
      Desc       :        Pango.Font.Pango_Font_Description;
      Math_Scale :        Long_Float := 1.0);

   procedure Clear (P : in out Instance);

   function Root (P : Instance) return Gtk.Box.Gtk_Box;
   function Root_Outer
     (P : Instance; Root_Id : Natural) return Gtk.Box.Gtk_Box;
   function Selection_View (P : Instance) return Gtk.Text_View.Gtk_Text_View;
   function Active_Buffer (P : Instance) return Gtk.Text_Buffer.Gtk_Text_Buffer;
   function Active_View (P : Instance) return Gtk.Text_View.Gtk_Text_View;
   function Invalid_Event_Count (P : Instance) return Natural;
   function Text_View_Count (P : Instance) return Natural;
   function Text_View_At
     (P : Instance; Index : Positive) return Gtk.Text_View.Gtk_Text_View;
   function Table_Count (P : Instance) return Natural;
   function Table_Grid_At
     (P : Instance; Index : Positive) return Gtk.Grid.Gtk_Grid;
   function Math_Element_Count (P : Instance) return Natural;
   function Math_Element_At
     (P : Instance; Index : Positive)
      return Coyote_GUI.Math_Element.Instance_Access;

private

   type Component_Kind is (Text_Component, Native_Component);

   type Component is tagged limited record
      Root_Id    : Natural := 0;
      Kind       : Component_Kind := Text_Component;
      Outer      : Gtk.Box.Gtk_Box;
      Payload    : Gtk.Box.Gtk_Box;
      View       : Gtk.Text_View.Gtk_Text_View;
      Buffer     : Gtk.Text_Buffer.Gtk_Text_Buffer;
      Renderer   : Coyote_GUI.Response_Renderer.Instance;
      Block      : Coyote_Renderer.Semantics.Block_Id;
      Committed  : Boolean := False;
      Dirty      : Boolean := True;
   end record;

   type Component_Access is access all Component;
   package Component_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Component_Access);
   package Root_Id_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Natural);

   type Instance is tagged limited record
      Parent        : Gtk.Box.Gtk_Box;
      Response      : Gtk.Box.Gtk_Box;
      Components    : Component_Vectors.Vector;
      Committed     : Root_Id_Vectors.Vector;
      Dirty_Roots   : Root_Id_Vectors.Vector;
      Font_Name     : Ada.Strings.Unbounded.Unbounded_String;
      Math_Scale    : Long_Float := 1.0;
      Active        : Gtk.Text_View.Gtk_Text_View;
      Placeholder   : Component_Access;
      Invalid_Count : Natural := 0;
   end record;

end Coyote_GUI.Semantic_Response_Presenter;
