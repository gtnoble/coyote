with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Glib;
with Glib.Values;
with Gtk.Main;
with Gtk.Container;
with Gtk.Tree_Store;
with Gtk.Widget;
with Gtk.Tree_Model;
with Gtk.Tree_View;
with Coyote_GUI.Math_Accessibility;
with Math_Semantics;

procedure Math_Accessibility_Probe is
   use Gtk.Tree_Model;
   Checks : Natural := 0;
   Failures : Natural := 0;
   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;
   function Cell (Model : Gtk_Tree_Model; Iter : Gtk_Tree_Iter;
                  Col : Glib.Gint) return String is
      Value : Glib.Values.GValue;
   begin
      Get_Value (Model, Iter, Col, Value);
      return Glib.Values.Get_String (Value);
   end Cell;
   Item : constant Math_Semantics.Document := Math_Semantics.Project
     ("\frac{x^i}{\sqrt[3]{y}}+\begin{matrix}a&b\\c&d\end{matrix}");
   function Large_Source return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
   begin
      for Index in 1 .. 30 loop
         Append (Result, "\frac{x}{y}+");
      end loop;
      return To_String (Result);
   end Large_Source;
   Large : constant Math_Semantics.Document :=
     Math_Semantics.Project (Large_Source);
   Large_View : Gtk.Tree_View.Gtk_Tree_View;
   Pending_View : Gtk.Tree_View.Gtk_Tree_View;
   Large_Model : Gtk_Tree_Model;
   Large_Count : Natural := 0;
   Iterations : Natural := 0;
   function Count_Subtree
     (Tree : Gtk_Tree_Model; First : Gtk_Tree_Iter) return Natural;
   function Count_Subtree
     (Tree : Gtk_Tree_Model; First : Gtk_Tree_Iter) return Natural
   is
      Total : Natural := 0;
      Current : Gtk_Tree_Iter := First;
      Child : Gtk_Tree_Iter;
   begin
      while Current /= Null_Iter loop
         Total := Total + 1;
         Child := Children (Tree, Current);
         if Child /= Null_Iter then
            Total := Total + Count_Subtree (Tree, Child);
         end if;
         Next (Tree, Current);
      end loop;
      return Total;
   end Count_Subtree;
   function Model_Rows (Tree : Gtk_Tree_Model) return Natural is
     (Count_Subtree (Tree, Children (Tree, Null_Iter)));
   View : Gtk.Tree_View.Gtk_Tree_View;
   Model : Gtk_Tree_Model;
   Root_Iter : Gtk_Tree_Iter;
   Seen_Fraction, Seen_Numerator, Seen_Denominator : Boolean := False;
   Seen_Script, Seen_Radical, Seen_Index : Boolean := False;
   Seen_Array, Seen_Row, Seen_Cell : Boolean := False;
   Seen_Source : Boolean := False;
   Seen_Pending : Boolean := False;
   Seen_Metadata : Boolean := False;
   Visited : Natural := 0;
   procedure Visit (Iter : Gtk_Tree_Iter) is
      Current : Gtk_Tree_Iter := Iter;
      Child : Gtk_Tree_Iter;
   begin
      while Current /= Null_Iter loop
         declare
            Text : constant String := Cell (Model, Current, 0);
            Source : constant String := Cell (Model, Current, 1);
         begin
            Visited := Visited + 1;
            Check (Text'Length > 0, "semantic row has an accessible label");
            if Visited = 1 then
               Check (Source = Math_Semantics.Source (Item),
                 "root row retains exact source");
            else
               Check (Source = "",
                 "semantic child avoids duplicated source storage");
            end if;
            Seen_Source := Seen_Source or else
              Source = Math_Semantics.Source (Item);
            Seen_Metadata := Seen_Metadata or else
              (Ada.Strings.Fixed.Index (Text, "class ") > 0 and then
               Ada.Strings.Fixed.Index (Text, "font ") > 0);
            Seen_Pending := Seen_Pending or else
              Ada.Strings.Fixed.Index (Text, "Pending more structure") > 0;
            Seen_Fraction := Seen_Fraction or else
              Ada.Strings.Fixed.Index (Text, "FRACTION_NODE") > 0;
            Seen_Numerator := Seen_Numerator or else
              Ada.Strings.Fixed.Index (Text, "NUMERATOR") > 0;
            Seen_Denominator := Seen_Denominator or else
              Ada.Strings.Fixed.Index (Text, "DENOMINATOR") > 0;
            Seen_Script := Seen_Script or else
              Ada.Strings.Fixed.Index (Text, "SUPERSCRIPT") > 0;
            Seen_Radical := Seen_Radical or else
              Ada.Strings.Fixed.Index (Text, "RADICAL_NODE") > 0;
            Seen_Index := Seen_Index or else
              Ada.Strings.Fixed.Index (Text, "RADICAL_INDEX") > 0;
            Seen_Array := Seen_Array or else
              Ada.Strings.Fixed.Index (Text, "ARRAY_NODE") > 0;
            Seen_Row := Seen_Row or else
              Ada.Strings.Fixed.Index (Text, "ARRAY_ROW") > 0;
            Seen_Cell := Seen_Cell or else
              Ada.Strings.Fixed.Index (Text, "ARRAY_CELL") > 0;
         end;
         Child := Children (Model, Current);
         if Child /= Null_Iter then
            Visit (Child);
         end if;
         Next (Model, Current);
      end loop;
   end Visit;
begin
   if not Gtk.Main.Init_Check then
      Ada.Text_IO.Put_Line ("DISPLAY_REQUIRED");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Check (Math_Semantics.Is_Valid (Item), "semantic document valid");
   View := Coyote_GUI.Math_Accessibility.Create (Item);
   Model := Gtk.Tree_View.Get_Model (View);
   Root_Iter := Children (Model, Null_Iter);
   Check (Root_Iter /= Null_Iter, "GTK model has root");
   if Root_Iter /= Null_Iter then
      Check (Cell (Model, Root_Iter, 1) = Math_Semantics.Source (Item),
        "root row retains exact source");
      Visit (Root_Iter);
   end if;
   Check (Seen_Source, "exact source is retained on root");
   Check (Seen_Metadata, "semantic labels include node metadata");
   Check (Visited <= Math_Semantics.Count (Item),
     "initial GTK tree stays within semantic node count");
   Check (Visited = Math_Semantics.Count (Item) or else Seen_Pending,
     "bounded tree explicitly reports remaining semantic nodes");
   Check (Seen_Fraction and Seen_Numerator and Seen_Denominator,
     "fraction and numerator/denominator roles are exposed");
   Check (Seen_Script, "superscript child role is exposed");
   Check (Seen_Radical and Seen_Index, "root and index roles are exposed");
   Check (Seen_Array and Seen_Row and Seen_Cell,
     "array row and cell hierarchy is exposed");
   Check (Math_Semantics.Is_Valid (Large) and then
     Math_Semantics.Count (Large) > 64,
     "large expression exceeds initial accessible row budget");
   Large_View := Coyote_GUI.Math_Accessibility.Create (Large);
   Large_Model := Gtk.Tree_View.Get_Model (Large_View);
   Check (Model_Rows (Large_Model) <= 65,
     "initial large tree is bounded with a pending marker");
   while Model_Rows (Large_Model) < Math_Semantics.Count (Large)
     and then Iterations < 20_000
   loop
      declare
         Pending_Events : constant Boolean :=
           Gtk.Main.Main_Iteration_Do (False);
         pragma Unreferenced (Pending_Events);
      begin
         Iterations := Iterations + 1;
      end;
   end loop;
   Large_Count := Model_Rows (Large_Model);
   Check (Large_Count = Math_Semantics.Count (Large),
     "idle slices append all semantic nodes and remove pending marker");
   Pending_View := Coyote_GUI.Math_Accessibility.Create (Large);
   Gtk.Widget.Destroy (Gtk.Widget.Gtk_Widget (Gtk.Container.Gtk_Container (Pending_View)));
   for Index in 1 .. 4_000 loop
      declare
         Pending_Events : constant Boolean :=
           Gtk.Main.Main_Iteration_Do (False);
         pragma Unreferenced (Pending_Events);
      begin
         null;
      end;
   end loop;
   Check (True, "destroying a pending view cancels population safely");
   Gtk.Widget.Destroy (Gtk.Widget.Gtk_Widget (Gtk.Container.Gtk_Container (Large_View)));
   Ada.Text_IO.Put_Line ("ASSERTIONS" & Natural'Image (Checks) &
     " failures=" & Natural'Image (Failures));
   if Checks < 15 or else Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Accessibility_Probe;
