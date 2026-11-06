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
   Verbatim_Payload : constant String := "<&😀";
   Special : constant Math_Semantics.Document := Math_Semantics.Project
     ("\vcenter{x}+\pmb{a}+\verb*|" & Verbatim_Payload & "|");
   Accent_Source : constant String := "\text{\c{c}}+\widehat{x}+\text{\textcircled{R}}";
   Accent_Document : constant Math_Semantics.Document :=
     Math_Semantics.Project (Accent_Source);
   CD_Source : constant String := "\begin{CD}A@V\alpha VV&B@|C@.D\end{CD}";
   CD_Document : constant Math_Semantics.Document :=
     Math_Semantics.Project (CD_Source);
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
   Special_View : Gtk.Tree_View.Gtk_Tree_View;
   Special_Model : Gtk_Tree_Model;
   Accent_View : Gtk.Tree_View.Gtk_Tree_View;
   Accent_Model : Gtk_Tree_Model;
   CD_View : Gtk.Tree_View.Gtk_Tree_View;
   CD_Model : Gtk_Tree_Model;
   Saw_Accent_Below, Saw_Accent_Full, Saw_Circled : Boolean := False;
   Saw_CD_Array, Saw_CD_Arrow : Boolean := False;
   Saw_Left_Label, Saw_Right_Label : Boolean := False;
   Saw_VCenter_Role, Saw_Poor_Bold_Role : Boolean := False;
   Saw_Raw_Verbatim, Saw_Starred_Verbatim : Boolean := False;
   Box_Document : constant Math_Semantics.Document := Math_Semantics.Project
     ("\colorbox{red}{x}+\fcolorbox{blue}{#ffffff}{A}");
   Box_View : Gtk.Tree_View.Gtk_Tree_View;
   Box_Model : Gtk_Tree_Model;
   Saw_Red_Background, Saw_Blue_Border, Saw_White_Background : Boolean := False;
   Text_And_Rules_Source : constant String :=
     "\text{Ж}\allowbreak\begin{array}{c}\hline a\end{array}";
   Text_And_Rules : constant Math_Semantics.Document :=
     Math_Semantics.Project (Text_And_Rules_Source);
   Text_And_Rules_View : Gtk.Tree_View.Gtk_Tree_View;
   Text_And_Rules_Model : Gtk_Tree_Model;
   Saw_Text_Profile, Saw_Allow_Break : Boolean := False;
   Saw_Solid_Horizontal_Rule : Boolean := False;
   procedure Visit_Text_And_Rules (Iter : Gtk_Tree_Iter) is
      Current : Gtk_Tree_Iter := Iter;
      Child : Gtk_Tree_Iter;
   begin
      while Current /= Null_Iter loop
         declare
            Text : constant String := Cell (Text_And_Rules_Model, Current, 0);
         begin
            Saw_Text_Profile := Saw_Text_Profile or else
              (Ada.Strings.Fixed.Index (Text, "text: Ж") > 0 and then
               Ada.Strings.Fixed.Index (Text, "CYRILLIC_FALLBACK") > 0);
            Saw_Allow_Break := Saw_Allow_Break or else
              Ada.Strings.Fixed.Index (Text, "break ALLOW_BREAK") > 0;
            Saw_Solid_Horizontal_Rule := Saw_Solid_Horizontal_Rule or else
              Ada.Strings.Fixed.Index
                (Text, "horizontal rule at boundary 0 solid") > 0;
         end;
         Child := Children (Text_And_Rules_Model, Current);
         if Child /= Null_Iter then
            Visit_Text_And_Rules (Child);
         end if;
         Next (Text_And_Rules_Model, Current);
      end loop;
   end Visit_Text_And_Rules;
   procedure Visit_Special (Iter : Gtk_Tree_Iter) is
      Current : Gtk_Tree_Iter := Iter;
      Child : Gtk_Tree_Iter;
   begin
      while Current /= Null_Iter loop
         declare
            Text : constant String := Cell (Special_Model, Current, 0);
         begin
            Saw_VCenter_Role := Saw_VCenter_Role or else
              Ada.Strings.Fixed.Index (Text, "ROW_NODE - VCENTER_CONTENT") > 0;
            Saw_Poor_Bold_Role := Saw_Poor_Bold_Role or else
              Ada.Strings.Fixed.Index
                (Text, "ROW_NODE - POOR_BOLD_CONTENT") > 0;
            Saw_Raw_Verbatim := Saw_Raw_Verbatim or else
              Ada.Strings.Fixed.Index
                (Text, "raw verbatim: " & Verbatim_Payload) > 0;
            Saw_Starred_Verbatim := Saw_Starred_Verbatim or else
              (Ada.Strings.Fixed.Index (Text, "VERBATIM_NODE") > 0 and then
               Ada.Strings.Fixed.Index (Text, " - starred") > 0);
         end;
         Child := Children (Special_Model, Current);
         if Child /= Null_Iter then
            Visit_Special (Child);
         end if;
         Next (Special_Model, Current);
      end loop;
   end Visit_Special;
   procedure Visit_Accent (Iter : Gtk_Tree_Iter) is
      Current : Gtk_Tree_Iter := Iter;
      Child : Gtk_Tree_Iter;
   begin
      while Current /= Null_Iter loop
         declare
            Text : constant String := Cell (Accent_Model, Current, 0);
         begin
            Saw_Accent_Below := Saw_Accent_Below or else
              (Ada.Strings.Fixed.Index (Text, "accent \c") > 0 and then
               Ada.Strings.Fixed.Index (Text, "BELOW_ACCENT") > 0);
            Saw_Accent_Full := Saw_Accent_Full or else
              Ada.Strings.Fixed.Index (Text, "FULL_ACCENT") > 0;
            Saw_Circled := Saw_Circled or else
              Ada.Strings.Fixed.Index (Text, "textcircled") > 0;
         end;
         Child := Children (Accent_Model, Current);
         if Child /= Null_Iter then
            Visit_Accent (Child);
         end if;
         Next (Accent_Model, Current);
      end loop;
   end Visit_Accent;
   procedure Visit_Boxes (Iter : Gtk_Tree_Iter) is
      Current : Gtk_Tree_Iter := Iter;
      Child : Gtk_Tree_Iter;
   begin
      while Current /= Null_Iter loop
         declare
            Text : constant String := Cell (Box_Model, Current, 0);
         begin
            Saw_Red_Background := Saw_Red_Background or else
              (Ada.Strings.Fixed.Index (Text, "COLOR_BOX_ENCLOSURE") > 0 and then
               Ada.Strings.Fixed.Index (Text, "background RGBA") > 0 and then
               Ada.Strings.Fixed.Index
                 (Text, "1.00000000000000E+00, 0.00000000000000E+00, 0.00000000000000E+00") > 0);
            Saw_Blue_Border := Saw_Blue_Border or else
              (Ada.Strings.Fixed.Index (Text, "FRAMED_COLOR_BOX_ENCLOSURE") > 0 and then
               Ada.Strings.Fixed.Index (Text, "border RGBA") > 0 and then
               Ada.Strings.Fixed.Index
                 (Text, "0.00000000000000E+00, 0.00000000000000E+00, 1.00000000000000E+00") > 0);
            Saw_White_Background := Saw_White_Background or else
              (Ada.Strings.Fixed.Index (Text, "background RGBA") > 0 and then
               Ada.Strings.Fixed.Index
                 (Text, "1.00000000000000E+00, 1.00000000000000E+00, 1.00000000000000E+00") > 0);
         end;
         Child := Children (Box_Model, Current);
         if Child /= Null_Iter then
            Visit_Boxes (Child);
         end if;
         Next (Box_Model, Current);
      end loop;
   end Visit_Boxes;
   procedure Visit_CD (Iter : Gtk_Tree_Iter) is
      Current : Gtk_Tree_Iter := Iter;
      Child : Gtk_Tree_Iter;
   begin
      while Current /= Null_Iter loop
         declare
            Text : constant String := Cell (CD_Model, Current, 0);
         begin
            Saw_CD_Array := Saw_CD_Array or else
              (Ada.Strings.Fixed.Index (Text, "CD_ARRAY") > 0 and then
               Ada.Strings.Fixed.Index (Text, "commutative diagram") > 0);
            Saw_CD_Arrow := Saw_CD_Arrow or else
              (Ada.Strings.Fixed.Index (Text, "CD_ARROW_NODE") > 0 and then
               Ada.Strings.Fixed.Index (Text, "vertical arrow Unicode") > 0);
            Saw_Left_Label := Saw_Left_Label or else
              (Ada.Strings.Fixed.Index (Text, "CD_ARROW_LEFT_LABEL") > 0 and then
               Ada.Strings.Fixed.Index (Text, "left label") > 0);
            Saw_Right_Label := Saw_Right_Label or else
              (Ada.Strings.Fixed.Index (Text, "CD_ARROW_RIGHT_LABEL") > 0 and then
               Ada.Strings.Fixed.Index (Text, "right label") > 0);
         end;
         Child := Children (CD_Model, Current);
         if Child /= Null_Iter then
            Visit_CD (Child);
         end if;
         Next (CD_Model, Current);
      end loop;
   end Visit_CD;
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
   Check (Math_Semantics.Is_Valid (Text_And_Rules),
     "text, break and array-rule accessibility fixture is valid");
   Text_And_Rules_View :=
     Coyote_GUI.Math_Accessibility.Create (Text_And_Rules);
   Text_And_Rules_Model := Gtk.Tree_View.Get_Model (Text_And_Rules_View);
   Visit_Text_And_Rules (Children (Text_And_Rules_Model, Null_Iter));
   Check (Saw_Text_Profile, "text-run label exposes UTF-8 and Pango profile");
   Check (Saw_Allow_Break, "space label exposes break metadata");
   Check (Saw_Solid_Horizontal_Rule,
     "array label exposes horizontal rule boundary and style");
   Gtk.Widget.Destroy (Gtk.Widget.Gtk_Widget
     (Gtk.Container.Gtk_Container (Text_And_Rules_View)));
   Check (Math_Semantics.Is_Valid (Special),
     "vcenter, poor-bold, and verbatim semantic fixture valid");
   Check (Math_Semantics.Is_Valid (Accent_Document),
     "accent fixture remains a valid single semantic projection");
   Accent_View := Coyote_GUI.Math_Accessibility.Create (Accent_Document);
   Accent_Model := Gtk.Tree_View.Get_Model (Accent_View);
   Visit_Accent (Children (Accent_Model, Null_Iter));
   Check (Saw_Accent_Below, "below accent command and kind are explicit");
   Check (Saw_Accent_Full, "full accent command and kind are explicit");
   Check (Saw_Circled, "circled accent remains identifiable");
   Check (Cell (Accent_Model, Children (Accent_Model, Null_Iter), 1) =
     Accent_Source, "accent source is preserved exactly at root");
   Check (Math_Semantics.Is_Valid (Box_Document),
     "colorbox semantic fixture is valid");
   Box_View := Coyote_GUI.Math_Accessibility.Create (Box_Document);
   Box_Model := Gtk.Tree_View.Get_Model (Box_View);
   Visit_Boxes (Children (Box_Model, Null_Iter));
   Check (Saw_Red_Background and Saw_White_Background and Saw_Blue_Border,
     "accessibility labels expose box background and border RGBA");
   Gtk.Widget.Destroy
     (Gtk.Widget.Gtk_Widget (Gtk.Container.Gtk_Container (Box_View)));
   Check (Math_Semantics.Is_Valid (CD_Document),
     "CD diagram fixture is valid");
   CD_View := Coyote_GUI.Math_Accessibility.Create (CD_Document);
   CD_Model := Gtk.Tree_View.Get_Model (CD_View);
   Visit_CD (Children (CD_Model, Null_Iter));
   Check (Saw_CD_Array, "CD array is explicitly identified");
   Check (Saw_CD_Arrow, "vertical CD arrow glyph identity is explicit");
   Check (Saw_Left_Label and Saw_Right_Label,
     "CD arrow label roles are explicit");
   Check (Cell (CD_Model, Children (CD_Model, Null_Iter), 1) = CD_Source,
     "CD source is preserved exactly at root");
   Gtk.Widget.Destroy
     (Gtk.Widget.Gtk_Widget (Gtk.Container.Gtk_Container (Accent_View)));
   Gtk.Widget.Destroy
     (Gtk.Widget.Gtk_Widget (Gtk.Container.Gtk_Container (CD_View)));
   Special_View := Coyote_GUI.Math_Accessibility.Create (Special);
   Special_Model := Gtk.Tree_View.Get_Model (Special_View);
   Visit_Special (Children (Special_Model, Null_Iter));
   Check (Saw_VCenter_Role, "vcenter child role is exposed");
   Check (Saw_Poor_Bold_Role, "poor-bold child role is exposed");
   Check (Saw_Raw_Verbatim and Saw_Starred_Verbatim,
     "starred raw verbatim preserves literal markup characters and UTF-8");
   Gtk.Widget.Destroy
     (Gtk.Widget.Gtk_Widget (Gtk.Container.Gtk_Container (Special_View)));
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
