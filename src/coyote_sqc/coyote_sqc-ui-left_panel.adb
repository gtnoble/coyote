--  Coyote_SQC.UI.Left_Panel body.
--
--  Project: coyote

with Ada.Containers.Generic_Array_Sort;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Coyote_SQC.App;
with Coyote_SQC.Charts;
with Coyote_SQC.UI.Chart_Canvas;
with Coyote_SQC.UI.Detail_Panel;
with Glib;                   use Glib;
with Gtk.Enums;
with Gtk.Label;
with Gtk.List_Box;
with Gtk.List_Box_Row;
with Gtk.Widget;

package body Coyote_SQC.UI.Left_Panel is
   use type Gtk.List_Box.Gtk_List_Box;

   use Coyote_SQC.Charts;

   --  Module-level reference to the ListBox.
   The_List_Box : Gtk.List_Box.Gtk_List_Box := null;

   --  Maximum GtkListBox rows.
   --  48 charts + 3 top-group separators + 19 sub-group separators = 70;
   --  96 provides comfortable headroom.
   Max_LB_Rows : constant := 96;

   --  Mapping: GtkListBox row index -> Chart_Kind (only valid when
   --  Row_Is_Chart(I) = True).  Separator rows are not chart rows.
   type Row_Map_Array   is array (0 .. Max_LB_Rows - 1) of Chart_Kind;
   type Row_Valid_Array is array (0 .. Max_LB_Rows - 1) of Boolean;

   Row_Map      : Row_Map_Array   := (others => Chart_Kind'First);
   Row_Is_Chart : Row_Valid_Array := (others => False);
   LB_Row_Count : Natural := 0;   --  total LB rows (charts + separators)

   --  ── Signal handler ────────────────────────────────────────────────────

   procedure On_Row_Activated
     (List_Box : access Gtk.List_Box.Gtk_List_Box_Record'Class;
      Row     : not null access Gtk.List_Box_Row.Gtk_List_Box_Row_Record'Class)
   is
      pragma Unreferenced (List_Box);
      Idx : constant Integer := Integer (Row.Get_Index);
   begin
      if Idx >= 0 and then Idx < LB_Row_Count
        and then Row_Is_Chart (Idx)
      then
         Coyote_SQC.App.State.Active_Chart := Row_Map (Idx);
         --  Recompute y-fit for the new chart.
         Coyote_SQC.App.Y_Fit;
         Coyote_SQC.UI.Chart_Canvas.Queue_Redraw;
         Coyote_SQC.UI.Detail_Panel.Refresh_Histogram_If_Multi;
         Coyote_SQC.UI.Detail_Panel.Refresh_Histogram_If_Single;
      end if;
   end On_Row_Activated;

   --  ── Build ─────────────────────────────────────────────────────────────

   function Build return Gtk.Scrolled_Window.Gtk_Scrolled_Window is
      use Gtk.List_Box;
      use Gtk.List_Box_Row;
      use Gtk.Label;
      use Gtk.Scrolled_Window;
      use Gtk.Enums;

      --  Pairs a chart kind with the two path components from its Group_Path.
      type Chart_Entry is record
         Top_Group : Unbounded_String;
         Sub_Group : Unbounded_String;
         Kind      : Chart_Kind;
      end record;

      Num_Charts : constant Positive :=
        Chart_Kind'Pos (Chart_Kind'Last)
        - Chart_Kind'Pos (Chart_Kind'First) + 1;

      type Chart_Entry_Array is array (Positive range <>) of Chart_Entry;

      --  Three-key comparison: top group and sub-group alphabetically, then
      --  enum position to preserve relative order within a sub-group.
      function "<" (A, B : Chart_Entry) return Boolean is
      begin
         if A.Top_Group < B.Top_Group then
            return True;
         elsif A.Top_Group > B.Top_Group then
            return False;
         elsif A.Sub_Group < B.Sub_Group then
            return True;
         elsif A.Sub_Group > B.Sub_Group then
            return False;
         else
            return Chart_Kind'Pos (A.Kind) < Chart_Kind'Pos (B.Kind);
         end if;
      end "<";

      procedure Sort_Entries is new Ada.Containers.Generic_Array_Sort
        (Index_Type   => Positive,
         Element_Type => Chart_Entry,
         Array_Type   => Chart_Entry_Array);

      --  Split "Top/Sub" on the first "/" into its two components.
      --  When no "/" is present, Top receives the full string and Sub is
      --  left empty.
      procedure Split_Path
        (Path : String;
         Top  : out Unbounded_String;
         Sub  : out Unbounded_String)
      is
         Sep : constant Natural :=
           Ada.Strings.Fixed.Index (Path, "/");
      begin
         if Sep = 0 then
            Top := To_Unbounded_String (Path);
            Sub := Null_Unbounded_String;
         else
            Top := To_Unbounded_String (Path (Path'First .. Sep - 1));
            Sub := To_Unbounded_String (Path (Sep + 1 .. Path'Last));
         end if;
      end Split_Path;

      Entries  : Chart_Entry_Array (1 .. Num_Charts);
      Scroll   : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      LB       : Gtk.List_Box.Gtk_List_Box;
      Last_Top : Unbounded_String;
      Last_Sub : Unbounded_String;

      --  Append a non-activatable separator row to the list box.
      --  Markup is Pango markup; Left_Margin is in pixels.
      procedure Add_Separator (Markup : String; Left_Margin : Glib.Gint) is
         Sep_Row : Gtk.List_Box_Row.Gtk_List_Box_Row;
         Sep_Lbl : Gtk.Label.Gtk_Label;
      begin
         Gtk.List_Box_Row.Gtk_New (Sep_Row);
         Sep_Row.Set_Activatable (False);
         Sep_Row.Set_Selectable (False);
         Gtk.Label.Gtk_New (Sep_Lbl, Markup);
         Sep_Lbl.Set_Use_Markup (True);
         Sep_Lbl.Set_Halign (Gtk.Widget.Align_Start);
         Sep_Lbl.Set_Margin_Start (Left_Margin);
         Sep_Row.Add (Sep_Lbl);
         LB.Add (Sep_Row);
         if LB_Row_Count < Max_LB_Rows then
            Row_Is_Chart (LB_Row_Count) := False;
            LB_Row_Count := LB_Row_Count + 1;
         end if;
      end Add_Separator;

   begin
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Policy_Never, Policy_Automatic);
      Scroll.Set_Size_Request (180, -1);

      Gtk.List_Box.Gtk_New (LB);
      LB.Set_Selection_Mode (Selection_Single);
      LB.On_Row_Activated (On_Row_Activated'Access);

      --  Reset state.
      Row_Map      := (others => Chart_Kind'First);
      Row_Is_Chart := (others => False);
      LB_Row_Count := 0;

      --  Collect every chart with its Group_Path split into components.
      for K in Chart_Kind loop
         declare
            Props : constant Coyote_SQC.Charts.Chart_Properties :=
              Coyote_SQC.Charts.Properties (K);
            Path  : constant String := To_String (Props.Group_Path);
            Idx   : constant Positive :=
              Chart_Kind'Pos (K) - Chart_Kind'Pos (Chart_Kind'First) + 1;
            Top, Sub : Unbounded_String;
         begin
            Split_Path (Path, Top, Sub);
            Entries (Idx) := (Top_Group => Top,
                              Sub_Group => Sub,
                              Kind      => K);
         end;
      end loop;

      --  Sort: (Top_Group, Sub_Group) alphabetically; enum order within.
      Sort_Entries (Entries);

      --  Render sorted entries into the GtkListBox.
      for E of Entries loop
         --  Bold top-group separator whenever the top-level group changes.
         if E.Top_Group /= Last_Top then
            Add_Separator
              ("<b>" & To_String (E.Top_Group) & "</b>", 0);
            Last_Top := E.Top_Group;
            Last_Sub := Null_Unbounded_String;
         end if;

         --  Italic sub-group separator whenever the sub-group changes
         --  (and a sub-group is present for this chart).
         if Length (E.Sub_Group) > 0 and then E.Sub_Group /= Last_Sub then
            Add_Separator
              ("<i>" & To_String (E.Sub_Group) & "</i>", 8);
            Last_Sub := E.Sub_Group;
         end if;

         --  Chart row: indented further than the sub-group label.
         declare
            Props : constant Coyote_SQC.Charts.Chart_Properties :=
              Coyote_SQC.Charts.Properties (E.Kind);
            Row : Gtk.List_Box_Row.Gtk_List_Box_Row;
            Lbl : Gtk.Label.Gtk_Label;
         begin
            Gtk.List_Box_Row.Gtk_New (Row);
            Gtk.Label.Gtk_New (Lbl, To_String (Props.Label));
            Lbl.Set_Halign (Gtk.Widget.Align_Start);
            Lbl.Set_Margin_Start (16);
            Row.Add (Lbl);
            LB.Add (Row);
            if LB_Row_Count < Max_LB_Rows then
               Row_Map (LB_Row_Count)      := E.Kind;
               Row_Is_Chart (LB_Row_Count) := True;
               LB_Row_Count := LB_Row_Count + 1;
            end if;
         end;
      end loop;

      Scroll.Add (LB);
      The_List_Box := LB;
      return Scroll;
   end Build;

   --  ── Refresh_Selection ─────────────────────────────────────────────────

   procedure Refresh_Selection is
   begin
      if The_List_Box = null then
         return;
      end if;
      for I in 0 .. LB_Row_Count - 1 loop
         if Row_Is_Chart (I)
           and then Row_Map (I) = Coyote_SQC.App.State.Active_Chart
         then
            The_List_Box.Select_Row
              (The_List_Box.Get_Row_At_Index (Glib.Gint (I)));
            return;
         end if;
      end loop;
   end Refresh_Selection;

end Coyote_SQC.UI.Left_Panel;
