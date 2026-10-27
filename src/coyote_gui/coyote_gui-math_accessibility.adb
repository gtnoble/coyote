with Ada.Containers.Vectors;
with Ada.Real_Time;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;
with Glib;
with Glib.Main;
with Glib.Values;
with Gtk.Cell_Renderer_Text;
with Gtk.Handlers;
with Gtk.Tree_Model;
with Gtk.Tree_Store;
with Gtk.Tree_View;
with Gtk.Tree_View_Column;
with Math_Model;

package body Coyote_GUI.Math_Accessibility is
   use type Gtk.Tree_View.Gtk_Tree_View;
   use type Math_Model.Node_Kind;
   use type Glib.Main.G_Source_Id;
   use type Glib.Main.G_Source;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Glib.Gulong;

   Max_Initial_Rows : constant := 64;
   Rows_Per_Slice : constant := 64;
   Max_Slice_Time : constant Ada.Real_Time.Time_Span :=
     Ada.Real_Time.Milliseconds (5);

   use type Gtk.Tree_Model.Gtk_Tree_Iter;

   package Iter_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive,
      Element_Type => Gtk.Tree_Model.Gtk_Tree_Iter);

   type Population_State;
   type State_Access is access all Population_State;
   type Population_State is record
      Meaning : Math_Semantics.Document;
      Store : Gtk.Tree_Store.Gtk_Tree_Store;
      Parents : Iter_Vectors.Vector;
      Next_Index : Natural := 1;
      Source_Id : Glib.Main.G_Source_Id := 0;
      Pending : Gtk.Tree_Model.Gtk_Tree_Iter;
      View : Gtk.Tree_View.Gtk_Tree_View;
      Destroy_Handler : Gtk.Handlers.Handler_Id;
   end record;

   function Populate_Slice (State : State_Access) return Boolean;
   procedure Release_State (State : in out State_Access);
   procedure Source_Destroyed (State : in out State_Access);
   package Population_Sources is new Glib.Main.Generic_Sources (State_Access);
   package View_Destroy_Callback is new Gtk.Handlers.User_Callback
     (Gtk.Tree_View.Gtk_Tree_View_Record, State_Access);

   function Node_Label
     (Meaning : Math_Semantics.Document; Index : Positive) return String
   is
      use Math_Semantics;
      N : constant Semantic_Node := Element (Meaning, Index);
      Result : Unbounded_String := To_Unbounded_String
        (Math_Model.Node_Kind'Image (N.Kind) & " - " &
         Child_Role'Image (N.Role) & " - source position" &
         Natural'Image (N.Position));
   begin
      if N.Role = Annotation_Above then
         Append (Result, " - above label");
      elsif N.Role = Annotation_Below then
         Append (Result, " - below label");
      end if;
      if N.Kind = Math_Model.Stretchy_Node and then
        (N.Code_Point = 1 or else N.Code_Point = 2)
      then
         Append (Result, " - " & To_String (N.Stretchy_Name));
      elsif N.Kind = Math_Model.Glyph_Node then
         Append (Result, " - Unicode" & Natural'Image (N.Code_Point));
      elsif N.Kind = Math_Model.Array_Node then
         Append (Result, " - " & Math_Model.Array_Kind'Image (N.Array_Type));
      elsif N.Kind = Math_Model.Sized_Node then
         Append (Result, " - sizing scale" & Long_Float'Image (N.Scale));
      elsif N.Kind = Math_Model.Raised_Node then
         Append (Result, " - raise amount" & Long_Float'Image (N.Amount));
      elsif N.Kind = Math_Model.Rule_Node then
         Append (Result, " - rule width" & Long_Float'Image (N.Width) &
           " height" & Long_Float'Image (N.Height) &
           " raise amount" & Long_Float'Image (N.Amount));
      elsif N.Kind = Math_Model.Enclosed_Node then
         Append (Result, " - enclosure " &
           Math_Model.Enclosure_Kind'Image (N.Enclosure));
      end if;
      if N.Width /= 0.0 or else N.Height /= 0.0 or else N.Depth /= 0.0 then
         Append (Result, " - width" & Long_Float'Image (N.Width) &
           " height" & Long_Float'Image (N.Height) &
           " depth" & Long_Float'Image (N.Depth));
      end if;
      Append (Result, " - class " & Math_Model.Atom_Class'Image (N.Class));
      Append (Result, " - font " & Math_Model.Font_Kind'Image (N.Font));
      if N.Amount /= 0.0 and then N.Kind not in
        Math_Model.Raised_Node | Math_Model.Rule_Node
      then
         Append (Result, " - amount" & Long_Float'Image (N.Amount));
      end if;
      if Length (N.Column_Spec) > 0 then
         Append (Result, " - columns " & To_String (N.Column_Spec));
      end if;
      return To_String (Result);
   end Node_Label;

   procedure Source_Destroyed (State : in out State_Access) is
   begin
      Release_State (State);
   end Source_Destroyed;

   procedure Release_State (State : in out State_Access) is
      procedure Deallocate is new Ada.Unchecked_Deallocation
        (Population_State, State_Access);
   begin
      if State /= null then
         Deallocate (State);
      end if;
   end Release_State;

   function Populate_Slice (State : State_Access) return Boolean is
      use Gtk.Tree_Model;
      use Gtk.Tree_Store;
      Added : Natural := 0;
      Started : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Row : Gtk_Tree_Iter;
      Parent : Gtk_Tree_Iter;
      Index : Natural;
   begin
      if State = null then
         return False;
      end if;
      while State.Next_Index <= Math_Semantics.Count (State.Meaning)
        and then Added < Rows_Per_Slice
        and then Ada.Real_Time.Clock - Started < Max_Slice_Time
      loop
         Index := State.Next_Index;
         if Index = Math_Semantics.Root (State.Meaning) then
            Parent := Null_Iter;
         else
            Parent := State.Parents.Element
              (Math_Semantics.Element
                 (State.Meaning, Positive (Index)).Parent);
         end if;
         State.Store.Append (Row, Parent);
         State.Store.Set (Row, 0, Node_Label
           (State.Meaning, Positive (Index)));
         if Index = Math_Semantics.Root (State.Meaning) then
            State.Store.Set
              (Row, 1, Math_Semantics.Source (State.Meaning));
         else
            State.Store.Set (Row, 1, "");
         end if;
         State.Parents.Append (Row);
         State.Next_Index := Index + 1;
         Added := Added + 1;
      end loop;
      if State.Next_Index <= Math_Semantics.Count (State.Meaning) then
         State.Store.Set (State.Pending, 0,
           "Pending more structure -" & Natural'Image
             (Math_Semantics.Count (State.Meaning) - State.Next_Index + 1) &
             " semantic nodes remain");
         return True;
      end if;
      State.Store.Remove (State.Pending);
      State.Pending := Null_Iter;
      return False;
   exception
      when others =>
         if State /= null then
            if State.View /= null and then
              State.Destroy_Handler.Id /= Gtk.Handlers.Null_Handler_Id
            then
               Gtk.Handlers.Disconnect
                 (State.View, State.Destroy_Handler);
            end if;
            State.Source_Id := 0;
         end if;
         return False;
   end Populate_Slice;

   procedure On_View_Destroy
     (View : access Gtk.Tree_View.Gtk_Tree_View_Record'Class;
      Params : Glib.Values.GValues;
      State : State_Access)
   is
      pragma Unreferenced (View, Params);
   begin
      if State /= null and then State.Source_Id /= 0 then
         if Glib.Main.Find_Source_By_Id (State.Source_Id) /= null then
            Glib.Main.Remove (State.Source_Id);
         end if;
      end if;
   end On_View_Destroy;

   View_Destroy_Handler : constant View_Destroy_Callback.Handler :=
     View_Destroy_Callback.Handler'(On_View_Destroy'Access);

   function Create
     (Meaning : Math_Semantics.Document)
      return Gtk.Tree_View.Gtk_Tree_View
   is
      use Gtk.Tree_Model;
      Store : Gtk.Tree_Store.Gtk_Tree_Store;
      View : Gtk.Tree_View.Gtk_Tree_View;
      Row : Gtk_Tree_Iter;
      Label_Col : constant Glib.Gint := 0;
      Source_Col : constant Glib.Gint := 1;
      Renderer : Gtk.Cell_Renderer_Text.Gtk_Cell_Renderer_Text;
      Column : Gtk.Tree_View_Column.Gtk_Tree_View_Column;
      Dummy : Glib.Gint;
      State : State_Access := null;
   begin
      Gtk.Tree_Store.Gtk_New
        (Store, (0 => Glib.GType_String, 1 => Glib.GType_String));
      Gtk.Tree_View.Gtk_New
        (View, Gtk.Tree_Store.Implements_Gtk_Tree_Model.To_Interface
           (Store));
      Gtk.Cell_Renderer_Text.Gtk_New (Renderer);
      Gtk.Tree_View_Column.Gtk_New (Column);
      Column.Set_Title ("Math structure");
      Column.Pack_Start (Renderer, Expand => True);
      Column.Add_Attribute (Renderer, "text", Label_Col);
      Dummy := Gtk.Tree_View.Append_Column (View, Column);
      View.Set_Name ("coyote-math-semantics");
      if Math_Semantics.Is_Valid (Meaning) then
         State := new Population_State;
         State.Meaning := Meaning;
         State.Store := Store;
         State.View := View;
         State.Parents.Reserve_Capacity
           (Ada.Containers.Count_Type
              (Math_Semantics.Count (Meaning)));
         for Index in 1 .. Natural'Min
           (Math_Semantics.Count (Meaning), Max_Initial_Rows)
         loop
            declare
               Parent : Gtk_Tree_Iter;
               Current : Gtk_Tree_Iter;
            begin
               if Index = Math_Semantics.Root (Meaning) then
                  Parent := Null_Iter;
               else
                  Parent := State.Parents.Element
                    (Math_Semantics.Element
                       (Meaning, Positive (Index)).Parent);
               end if;
               Store.Append (Current, Parent);
               Store.Set (Current, Label_Col,
                 Node_Label (Meaning, Positive (Index)));
               if Index = Math_Semantics.Root (Meaning) then
                  Store.Set (Current, Source_Col,
                    Math_Semantics.Source (Meaning));
               else
                  Store.Set (Current, Source_Col, "");
               end if;
               State.Parents.Append (Current);
            end;
         end loop;
         State.Next_Index := Natural'Min
           (Math_Semantics.Count (Meaning), Max_Initial_Rows) + 1;
         if State.Next_Index <= Math_Semantics.Count (Meaning) then
            Store.Append (State.Pending, Null_Iter);
            Store.Set (State.Pending, Label_Col,
              "Pending more structure -" & Natural'Image
                (Math_Semantics.Count (Meaning) - State.Next_Index + 1) &
                " semantic nodes remain");
            Store.Set (State.Pending, Source_Col, "");
            State.Source_Id := Population_Sources.Idle_Add
              (Populate_Slice'Access, State,
               Notify => Source_Destroyed'Access);
            if State.Source_Id /= 0 then
               State.Destroy_Handler := View_Destroy_Callback.Connect
                 (View, "destroy", View_Destroy_Handler, State);
            else
               Release_State (State);
            end if;
         else
            Release_State (State);
         end if;
      else
         Store.Append (Row, Null_Iter);
         Store.Set (Row, Label_Col,
           "Invalid math semantics - " & Math_Semantics.Error (Meaning));
         Store.Set (Row, Source_Col, Math_Semantics.Source (Meaning));
      end if;
      return View;
   exception
      when others =>
         if State /= null then
            if State.Source_Id /= 0 then
               if Glib.Main.Find_Source_By_Id (State.Source_Id) /= null then
                  Glib.Main.Remove (State.Source_Id);
               else
                  Release_State (State);
               end if;
            else
               Release_State (State);
            end if;
         end if;
         return View;
   end Create;
end Coyote_GUI.Math_Accessibility;
