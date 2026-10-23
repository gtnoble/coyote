with Ada.Containers;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Math_Metrics;
with Math_Model;
with Math_Syntax;

--  Geometry uses the checked-in KaTeX 0.16.22 metric tables and the supported
--  syntax declared by Math_Syntax. Unsupported forms fail rather than being
--  approximated as successful output; no external process or GTK is used.
package body Math_Layout is
   use Ada.Strings.Unbounded;
   use Math_Model;
   use type Ada.Containers.Count_Type;
   use type Math_Syntax.Delimiter_Kind;

   Layout_Failure : exception;
   Max_Layout_Depth  : constant Natural    := 64;
   Max_Draw_Commands : constant            := 16_384;
   Max_Geometry      : constant Long_Float := 16_384.0;
   Rule_Thickness    : constant Long_Float := 0.04;
   Fraction_Axis     : constant Long_Float := 0.25;
   X_Height          : constant Long_Float := 0.431;

   type Style_Level is
     (Display_Level, Text_Level, Script_Level, Scriptscript_Level);

   procedure Reject (Why : String) is
   begin
      raise Layout_Failure with Why;
   end Reject;

   function Is_Tight (Level : Style_Level) return Boolean is
   begin
      return Level = Script_Level or Level = Scriptscript_Level;
   end Is_Tight;

   function Smaller (Level : Style_Level) return Style_Level is
   begin
      case Level is
         when Display_Level | Text_Level =>
            return Script_Level;
         when Script_Level | Scriptscript_Level =>
            return Scriptscript_Level;
      end case;
   end Smaller;

   function Scaled_Metric
     (Font : Font_Kind; Point : Natural; Scale : Long_Float)
      return Math_Metrics.Glyph_Metric
   is
      Result : Math_Metrics.Glyph_Metric := Math_Metrics.Lookup (Font, Point);
   begin
      if not Result.Found or Scale <= 0.0 or Result.Width < 0.0 or
        Result.Italic < 0.0
      then
         Reject ("missing glyph metric");
      end if;
      --  Signed ascent and descent are valid font metrics; preserve them
      --  for glyph placement and clamp only when aggregating box extents.
      Result.Width   := Result.Width * Scale;
      Result.Ascent  := Result.Ascent * Scale;
      Result.Descent := Result.Descent * Scale;
      Result.Italic  := Result.Italic * Scale;
      return Result;
   end Scaled_Metric;

   function Style_Scale (Level : Style_Level) return Long_Float is
   begin
      case Level is
         when Display_Level | Text_Level =>
            return 1.0;
         when Script_Level =>
            return 0.7;
         when Scriptscript_Level =>
            return 0.5;
      end case;
   end Style_Scale;

   function Child_Scale
     (Parent : Long_Float; From_Level, To_Level : Style_Level)
      return Long_Float
   is
   begin
      return Parent * Style_Scale (To_Level) / Style_Scale (From_Level);
   end Child_Scale;

   function Maximum (First, Second : Long_Float) return Long_Float is
   begin
      return Long_Float'Max (First, Second);
   end Maximum;

   function Maximum (First, Second, Third : Long_Float) return Long_Float is
   begin
      return Maximum (First, Maximum (Second, Third));
   end Maximum;

   function Spacing
     (Left, Right : Atom_Class; Tight : Boolean; Scale : Long_Float)
      return Long_Float
   is
      Thin   : constant Long_Float := 3.0 / 18.0;
      Medium : constant Long_Float := 4.0 / 18.0;
      Thick  : constant Long_Float := 5.0 / 18.0;
      Result : Long_Float          := 0.0;
   begin
      if Tight then
         if (Left = Ordinary and Right = Operator_Atom)
           or else
           (Left = Operator_Atom
            and then (Right = Ordinary or Right = Operator_Atom))
           or else (Left = Closing and Right = Operator_Atom)
           or else (Left = Inner and Right = Operator_Atom)
         then
            Result := Thin;
         end if;
      else
         case Left is
            when Ordinary =>
               case Right is
                  when Operator_Atom | Inner =>
                     Result := Thin;
                  when Binary_Atom =>
                     Result := Medium;
                  when Relation_Atom =>
                     Result := Thick;
                  when others =>
                     null;
               end case;
            when Operator_Atom =>
               case Right is
                  when Ordinary | Operator_Atom | Inner =>
                     Result := Thin;
                  when Relation_Atom =>
                     Result := Thick;
                  when others =>
                     null;
               end case;
            when Binary_Atom =>
               if Right in Ordinary | Operator_Atom | Opening | Inner then
                  Result := Medium;
               end if;
            when Relation_Atom =>
               if Right in Ordinary | Operator_Atom | Opening | Inner then
                  Result := Thick;
               end if;
            when Opening =>
               null;
            when Closing =>
               case Right is
                  when Operator_Atom =>
                     Result := Thin;
                  when Binary_Atom =>
                     Result := Medium;
                  when Relation_Atom =>
                     Result := Thick;
                  when Inner =>
                     Result := Thin;
                  when others =>
                     null;
               end case;
            when Punctuation =>
               if Right = Opening or Right = Ordinary or
                 Right = Operator_Atom or Right = Relation_Atom or
                 Right = Closing or Right = Punctuation or Right = Inner
               then
                  Result := Thin;
               end if;
            when Inner =>
               case Right is
                  when Ordinary | Operator_Atom | Opening | Punctuation
                    | Inner =>
                     Result := Thin;
                  when Binary_Atom =>
                     Result := Medium;
                  when Relation_Atom =>
                     Result := Thick;
                  when others =>
                     null;
               end case;
         end case;
      end if;
      return Result * Scale;
   end Spacing;

   function Effective_Class
     (Item : Math_Syntax.Document; Id : Node_Id; Position, Total : Natural)
      return Atom_Class
   is
      Value : constant Math_Syntax.Node :=
        Math_Syntax.Element (Item, Positive (Id));
   begin
      if Value.Kind in Row_Node | Glyph_Node | Scripts_Node | Fraction_Node
      then
         if Value.Class = Binary_Atom
           and then (Position = 1 or Position = Total)
         then
            return Ordinary;
         end if;
         return Value.Class;
      end if;
      return Ordinary;
   end Effective_Class;

   function Compose
     (Item  : Math_Syntax.Document; Id : Node_Id; Level : Style_Level;
      Scale : Long_Float; Depth : Natural) return Box;

   function Compose_Array
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural) return Box;

   procedure Append_At
     (Target : in out Box; Source : Box; X_Offset, Y_Offset : Long_Float)
   is
      Command : Draw_Command;
   begin
      if not Source.Valid then
         Reject (To_String (Source.Message));
      end if;
      if not Source.Commands.Is_Empty then
         for Index in Source.Commands.First_Index .. Source.Commands.Last_Index
         loop
            if Target.Commands.Length >= Max_Draw_Commands then
               Reject ("draw-command limit exceeded");
            end if;
            Command   := Source.Commands (Index);
            Command.X := Command.X + X_Offset;
            Command.Y := Command.Y + Y_Offset;
            Target.Commands.Append (Command);
         end loop;
      end if;
   end Append_At;

   function Compose_Row
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural) return Box
   is
      Result            : Box;
      Current           : Node_Id    := Value.First;
      Child             : Box;
      Prior_Class       : Atom_Class := Ordinary;
      Current_Class     : Atom_Class;
      Offset            : Long_Float := 0.0;
      Position          : Natural    := 0;
      Total             : Natural    := 0;
      Link_Count        : Natural    := 0;
      Probe             : Node_Id    := Value.First;
      Probe_Node        : Math_Syntax.Node;
      Previous_Class    : Atom_Class := Ordinary;
      Last_Child_Italic : Long_Float := 0.0;
      Next_Id           : Node_Id;
      Next_Node         : Math_Syntax.Node;
      Next_Class        : Atom_Class;
      Has_Next_Atom     : Boolean;
      Has_Previous_Atom : Boolean    := False;
      Explicit_Space    : Boolean;
   begin
      while Probe /= No_Node loop
         if Probe > Math_Syntax.Count (Item) or
           Link_Count >= Math_Syntax.Count (Item)
         then
            Reject ("invalid or cyclic row link");
         end if;
         Link_Count := Link_Count + 1;
         Probe_Node := Math_Syntax.Element (Item, Positive (Probe));
         if Probe_Node.Kind /= Space_Node then
            Total := Total + 1;
         end if;
         Probe := Probe_Node.Next;
      end loop;
      if Link_Count = 0 then
         Result.Valid := True;
         return Result;
      end if;
      while Current /= No_Node loop
         Probe_Node     := Math_Syntax.Element (Item, Positive (Current));
         Explicit_Space := Probe_Node.Kind = Space_Node;
         if not Explicit_Space then
            Position      := Position + 1;
            Current_Class := Effective_Class (Item, Current, Position, Total);
         else
            Current_Class := Ordinary;
         end if;
         if Current_Class = Binary_Atom then
            Next_Id       := Probe_Node.Next;
            Has_Next_Atom := False;
            while Next_Id /= No_Node loop
               Next_Node := Math_Syntax.Element (Item, Positive (Next_Id));
               exit when Next_Node.Kind /= Space_Node;
               Next_Id := Next_Node.Next;
            end loop;
            if Next_Id /= No_Node then
               Has_Next_Atom := True;
               Next_Node     := Math_Syntax.Element (Item, Positive (Next_Id));
               Next_Class    :=
                 Effective_Class (Item, Next_Id, Position + 1, Total);
            end if;
            if Position = 1
              or else Previous_Class in
                Binary_Atom | Operator_Atom | Relation_Atom | Opening
                | Punctuation
              or else
              (Has_Next_Atom
               and then Next_Class in Relation_Atom | Closing | Punctuation)
              or else not Has_Next_Atom
            then
               Current_Class := Ordinary;
            end if;
         end if;
         if not Explicit_Space and Has_Previous_Atom then
            Offset :=
              Offset +
              Spacing (Prior_Class, Current_Class, Is_Tight (Level), Scale);
         end if;
         Child := Compose (Item, Current, Level, Scale, Depth + 1);
         Append_At (Result, Child, Offset, 0.0);
         Offset         := Offset + Child.Width;
         Result.Ascent  := Maximum (Result.Ascent, Child.Ascent, 0.0);
         Result.Descent := Maximum (Result.Descent, Child.Descent, 0.0);
         if not Explicit_Space then
            Last_Child_Italic := Child.Italic;
            Prior_Class       := Current_Class;
            Previous_Class    := Current_Class;
            Has_Previous_Atom := True;
         end if;
         Current := Probe_Node.Next;
      end loop;
      Result.Width  := Offset;
      Result.Italic := Last_Child_Italic;
      Result.Valid  := True;
      return Result;
   end Compose_Row;

   function Compose_Fraction
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural) return Box
   is
      Result          : Box;
      Effective_Level : constant Style_Level :=
        (if Value.Fraction_Type = Display_Fraction then Display_Level
         elsif Value.Fraction_Type = Text_Fraction then Text_Level else Level);
      Num_Level       : constant Style_Level :=
        (if Effective_Level = Display_Level then Text_Level
         else
           (if Effective_Level = Text_Level then Script_Level
            else Scriptscript_Level));
      Den_Level       : constant Style_Level := Num_Level;
      Num_Scale       : constant Long_Float  :=
        Child_Scale (Scale, Level, Num_Level) * Style_Scale (Effective_Level) /
        Style_Scale (Level);
      Den_Scale       : constant Long_Float  :=
        Child_Scale (Scale, Level, Den_Level) * Style_Scale (Effective_Level) /
        Style_Scale (Level);
      Numerator       : Box                  :=
        Compose (Item, Value.First, Num_Level, Num_Scale, Depth + 1);
      Denominator     : Box                  :=
        Compose (Item, Value.Second, Den_Level, Den_Scale, Depth + 1);
      Num_Shift       : Long_Float;
      Den_Shift       : Long_Float;
      Clearance       : Long_Float;
      Rule            : Draw_Command;
      Half_Rule       : constant Long_Float  := Rule_Thickness * Scale / 2.0;
      Axis            : constant Long_Float  := Fraction_Axis * Scale;
      Fraction_Width  : constant Long_Float  :=
        Maximum (Numerator.Width, Denominator.Width);
   begin
      if Effective_Level = Display_Level then
         Num_Shift := 0.677 * Scale;
         Den_Shift := 0.686 * Scale;
         Clearance := 3.0 * Rule_Thickness * Scale;
      else
         Num_Shift := 0.394 * Scale;
         Den_Shift := 0.345 * Scale;
         Clearance := Rule_Thickness * Scale;
      end if;
      if (Num_Shift - Numerator.Descent) - (Axis + Half_Rule) < Clearance then
         Num_Shift :=
           Num_Shift + Clearance -
           ((Num_Shift - Numerator.Descent) - (Axis + Half_Rule));
      end if;
      if (Axis - Half_Rule) - (Denominator.Ascent - Den_Shift) < Clearance then
         Den_Shift :=
           Den_Shift + Clearance -
           ((Axis - Half_Rule) - (Denominator.Ascent - Den_Shift));
      end if;
      Append_At
        (Result, Numerator, (Fraction_Width - Numerator.Width) / 2.0,
         -Num_Shift);
      Append_At
        (Result, Denominator, (Fraction_Width - Denominator.Width) / 2.0,
         Den_Shift);
      Rule.Kind   := Rule_Command;
      Rule.Y      := -Axis - Half_Rule;
      Rule.Width  := Fraction_Width;
      Rule.Height := Rule_Thickness * Scale;
      Result.Commands.Append (Rule);
      Result.Width   := Fraction_Width;
      Result.Ascent  :=
        Maximum (Num_Shift + Numerator.Ascent, Axis + Half_Rule, 0.0);
      Result.Descent :=
        Maximum (Den_Shift + Denominator.Descent, Half_Rule - Axis, 0.0);
      Result.Valid   := True;
      return Result;
   end Compose_Fraction;

   function Compose_Radical
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural) return Box
   is
      Result         : Box;
      Radicand : Box := Compose (Item, Value.First, Level, Scale, Depth + 1);
      Index_Box      : Box;
      Has_Index      : constant Boolean    := Value.Second /= No_Node;
      Need           : constant Long_Float :=
        Radicand.Ascent + Radicand.Descent + 0.25 * Scale +
        Rule_Thickness * Scale;
      Chosen         : Font_Kind           := Size_4;
      Metric         : Math_Metrics.Glyph_Metric;
      Found_Size     : Boolean             := False;
      Glyph          : Draw_Command;
      Rule           : Draw_Command;
      Clearance      : constant Long_Float := 0.25 * Scale;
      Overbar_Top    : Long_Float;
      Glyph_Baseline : Long_Float;
      Index_Scale    : constant Long_Float := Scale * 0.5;
      Index_X        : Long_Float          := 0.0;
      Index_Y        : Long_Float          := 0.0;
      Size           : Font_Kind;
   begin
      if Has_Index then
         Index_Box :=
           Compose
             (Item, Value.Second, Smaller (Smaller (Level)), Index_Scale,
              Depth + 1);
         Index_X   := 0.05 * Scale;
         Index_Y   := -0.55 * Scale;
      end if;
      for Index in Font_Kind'Pos (Size_1) .. Font_Kind'Pos (Size_4) loop
         Size   := Font_Kind'Val (Index);
         Metric := Scaled_Metric (Size, 16#221A#, Scale);
         if Metric.Ascent + Metric.Descent >= Need then
            Chosen     := Size;
            Found_Size := True;
            exit;
         end if;
      end loop;
      if not Found_Size then
         Reject ("radicand exceeds largest natural radical metric");
      end if;
      Metric           := Scaled_Metric (Chosen, 16#221A#, Scale);
      Overbar_Top := -(Radicand.Ascent + Clearance + Rule_Thickness * Scale);
      Glyph_Baseline   := Overbar_Top + Metric.Ascent;
      Glyph.Font       := Chosen;
      Glyph.Code_Point := 16#221A#;
      Glyph.Scale      := Scale;
      Glyph.Y          := Glyph_Baseline;
      Glyph.Width      := Metric.Width;
      Glyph.Height     := Metric.Ascent + Metric.Descent;
      Result.Commands.Append (Glyph);
      if Has_Index then
         Append_At (Result, Index_Box, Index_X, Index_Y);
      end if;
      Append_At (Result, Radicand, Metric.Width, 0.0);
      Rule.Kind   := Rule_Command;
      Rule.X      := Metric.Width;
      Rule.Y      := Overbar_Top;
      Rule.Width  := Radicand.Width;
      Rule.Height := Rule_Thickness * Scale;
      Result.Commands.Append (Rule);
      Result.Width := Metric.Width + Radicand.Width;
      if Has_Index then
         Result.Width := Maximum (Result.Width, Index_X + Index_Box.Width);
      end if;
      Result.Ascent :=
        Maximum
          (Metric.Ascent - Glyph_Baseline,
           Radicand.Ascent + Clearance + Rule.Height, 0.0);
      if Has_Index then
         Result.Ascent :=
           Maximum (Result.Ascent, Index_Box.Ascent - Index_Y, 0.0);
      end if;
      Result.Descent :=
        Maximum (Metric.Descent + Glyph_Baseline, Radicand.Descent, 0.0);
      if Has_Index then
         Result.Descent :=
           Maximum (Result.Descent, Index_Box.Descent + Index_Y, 0.0);
      end if;
      Result.Valid := True;
      return Result;
   end Compose_Radical;

   function Compose_Scripts
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural) return Box
   is
      Result       : Box;
      Base : Box := Compose (Item, Value.First, Level, Scale, Depth + 1);
      Sup          : Box;
      Sub          : Box;
      Has_Sup      : constant Boolean     := Value.Second /= No_Node;
      Has_Sub      : constant Boolean     := Value.Third /= No_Node;
      Script_Level : constant Style_Level := Smaller (Level);
      Script_Scale : constant Long_Float  :=
        Child_Scale (Scale, Level, Script_Level);
      Sup_Shift    : Long_Float           := 0.0;
      Sub_Shift    : Long_Float           := 0.0;
      Min_Sup      : Long_Float;
      Min_Sub      : constant Long_Float  := 0.247 * Scale;
      Gap          : constant Long_Float  := 4.0 * Rule_Thickness * Scale;
      Psi          : Long_Float;
      Sup_X        : Long_Float;
      Sub_X        : Long_Float;
      Base_X       : Long_Float           := 0.0;
      Group_Width  : Long_Float;
      Limit_Mode   : Boolean              := Value.Script_Type = Limit_Scripts;
   begin
      declare
         Base_Node : constant Math_Syntax.Node :=
           Math_Syntax.Element (Item, Positive (Value.First));
      begin
         if Level = Display_Level and then Base_Node.Kind = Glyph_Node
           and then Base_Node.Code_Point in 16#2211# | 16#220F#
         then
            Limit_Mode := True;
         end if;
      end;
      if not Has_Sup and not Has_Sub then
         Reject ("scripts node has no scripts");
      end if;
      if Has_Sup then
         Sup       :=
           Compose (Item, Value.Second, Script_Level, Script_Scale, Depth + 1);
         Sup_Shift := Maximum (Base.Ascent - 0.353 * Script_Scale, 0.0);
      end if;
      if Has_Sub then
         Sub       :=
           Compose (Item, Value.Third, Script_Level, Script_Scale, Depth + 1);
         Sub_Shift := Base.Descent + 0.071 * Script_Scale;
      end if;
      if Level = Display_Level then
         Min_Sup := 0.413 * Scale;
      elsif Is_Tight (Level) then
         Min_Sup := 0.289 * Scale;
      else
         Min_Sup := 0.363 * Scale;
      end if;
      if Has_Sup then
         Sup_Shift := Maximum (Sup_Shift, Min_Sup);
         Sup_Shift :=
           Maximum (Sup_Shift, Sup.Descent + 0.25 * X_Height * Scale);
         if Limit_Mode then
            Sup_Shift := Base.Ascent + 0.2 * Scale + Sup.Descent;
         end if;
      end if;
      if Has_Sub then
         Sub_Shift :=
           Maximum (Sub_Shift, Min_Sub, Sub.Ascent - 0.8 * X_Height * Scale);
         if Limit_Mode then
            Sub_Shift := Base.Descent + 0.2 * Scale + Sub.Ascent;
         end if;
      end if;
      if Has_Sup and Has_Sub then
         if (Sup_Shift - Sup.Descent) - (Sub.Ascent - Sub_Shift) < Gap then
            Sub_Shift := Gap - (Sup_Shift - Sup.Descent) + Sub.Ascent;
            Psi       := 0.8 * X_Height * Scale - (Sup_Shift - Sup.Descent);
            if Psi > 0.0 then
               Sup_Shift := Sup_Shift + Psi;
               Sub_Shift := Sub_Shift - Psi;
            end if;
         end if;
      end if;
      Group_Width := Base.Width;
      if Limit_Mode then
         if Has_Sup then
            Group_Width := Maximum (Group_Width, Sup.Width);
         end if;
         if Has_Sub then
            Group_Width := Maximum (Group_Width, Sub.Width);
         end if;
         Base_X := (Group_Width - Base.Width) / 2.0;
      end if;
      Sup_X :=
        (if Limit_Mode then (Group_Width - Sup.Width) / 2.0
         else Base.Width + Base.Italic);
      Sub_X :=
        (if Limit_Mode then (Group_Width - Sub.Width) / 2.0 else Base.Width);
      Append_At (Result, Base, Base_X, 0.0);
      if Has_Sup then
         Append_At (Result, Sup, Sup_X, -Sup_Shift);
      end if;
      if Has_Sub then
         Append_At (Result, Sub, Sub_X, Sub_Shift);
      end if;
      Result.Width   := (if Limit_Mode then Group_Width else Base.Width);
      Result.Ascent  := Maximum (Base.Ascent, 0.0);
      Result.Descent := Maximum (Base.Descent, 0.0);
      if Has_Sup then
         if not Limit_Mode then
            Result.Width := Maximum (Result.Width, Sup_X + Sup.Width);
         end if;
         Result.Ascent := Maximum (Result.Ascent, Sup_Shift + Sup.Ascent, 0.0);
         Result.Descent :=
           Maximum (Result.Descent, Sup.Descent - Sup_Shift, 0.0);
      end if;
      if Has_Sub then
         if not Limit_Mode then
            Result.Width := Maximum (Result.Width, Sub_X + Sub.Width);
         end if;
         Result.Ascent := Maximum (Result.Ascent, Sub.Ascent - Sub_Shift, 0.0);
         Result.Descent :=
           Maximum (Result.Descent, Sub_Shift + Sub.Descent, 0.0);
      end if;
      Result.Italic := Base.Italic;
      Result.Valid  := True;
      return Result;
   end Compose_Scripts;

   function Compose_Array
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural) return Box
   is
      use Math_Syntax;
      Max_Rows    : constant Positive := Math_Syntax.Max_Array_Rows;
      Max_Columns : constant Positive := Math_Syntax.Max_Array_Columns;
      type Box_Grid is
        array
          (Positive range 1 .. Max_Rows,
           Positive range 1 .. Max_Columns) of Box;
      type Metric_Array is array (Positive range 1 .. Max_Rows) of Long_Float;
      type Width_Array is
        array (Positive range 1 .. Max_Columns) of Long_Float;
      Cells             : Box_Grid;
      Row_Ascents       : Metric_Array        := (others => 0.0);
      Row_Descents      : Metric_Array        := (others => 0.0);
      Column_Widths     : Width_Array         := (others => 0.0);
      Row_Id            : Node_Id             := Value.First;
      Cell_Id           : Node_Id;
      Column            : Natural;
      Rows              : Natural             := 0;
      Columns           : Natural             := 0;
      Link_Count        : Natural             := 0;
      Cell_Count        : Natural;
      Row_Value         : Math_Syntax.Node;
      Cell_Value        : Math_Syntax.Node;
      Result            : Box;
      X_Offset          : Long_Float          := 0.0;
      Y_Offset          : Long_Float          := 0.0;
      Column_Gap        : constant Long_Float :=
        (if Value.Array_Type = Aligned_Array then 0.2 else 0.5) * Scale;
      Row_Gap           : constant Long_Float := 0.25 * Scale;
      Total_Height      : Long_Float          := 0.0;
      Total_Width       : Long_Float          := 0.0;
      Row_Center        : Long_Float;
      Delimiter_Font    : Font_Kind;
      Delimiter_Metric  : Math_Metrics.Glyph_Metric;
      Delimiter_Command : Draw_Command;
      Delimiter_Gap     : constant Long_Float := 0.1 * Scale;
      Need_Height       : Long_Float;
      Found_Size        : Boolean;
      Size              : Font_Kind;
      Left_Width        : Long_Float          := 0.0;
      Right_Width       : Long_Float          := 0.0;
      procedure Measure_Delimiter (Kind : Delimiter_Kind) is
         Point : Natural;
      begin
         if Kind = Math_Syntax.No_Delimiter then
            return;
         end if;
         case Kind is
            when Math_Syntax.Parenthesis_Delimiter =>
               Point := 16#28#;
            when Math_Syntax.Bracket_Delimiter =>
               Point := 16#5B#;
            when Math_Syntax.Brace_Delimiter =>
               Point := 16#7B#;
            when Math_Syntax.Bar_Delimiter =>
               Point := 16#7C#;
            when Math_Syntax.Double_Bar_Delimiter =>
               Point := 16#7C#;
            when Math_Syntax.No_Delimiter =>
               return;
         end case;
         Found_Size := False;
         if Kind in Bar_Delimiter | Double_Bar_Delimiter then
            Delimiter_Metric := Scaled_Metric (Main_Regular, Point, Scale);
            if Kind = Double_Bar_Delimiter then
               Delimiter_Metric.Width :=
                 Delimiter_Metric.Width * 2.0 + 0.1 * Scale;
            end if;
            Delimiter_Font := Main_Regular;
            Found_Size     := True;
         else
            for Index in Font_Kind'Pos (Size_1) .. Font_Kind'Pos (Size_4) loop
               Size             := Font_Kind'Val (Index);
               Delimiter_Metric := Scaled_Metric (Size, Point, Scale);
               if Delimiter_Metric.Ascent + Delimiter_Metric.Descent >=
                 Need_Height
               then
                  Delimiter_Font := Size;
                  Found_Size     := True;
                  exit;
               end if;
            end loop;
         end if;
         if not Found_Size then
            Reject ("array exceeds largest natural delimiter metric");
         end if;
      end Measure_Delimiter;
      procedure Add_Delimiter
        (Kind : Delimiter_Kind; X : Long_Float; Right_Side : Boolean)
      is
         Point : Natural;
      begin
         if Kind = Math_Syntax.No_Delimiter then
            return;
         end if;
         case Kind is
            when Math_Syntax.Parenthesis_Delimiter =>
               Point := (if Right_Side then 16#29# else 16#28#);
            when Math_Syntax.Bracket_Delimiter =>
               Point := (if Right_Side then 16#5D# else 16#5B#);
            when Math_Syntax.Brace_Delimiter =>
               Point := (if Right_Side then 16#7D# else 16#7B#);
            when Math_Syntax.Bar_Delimiter =>
               Point := 16#7C#;
            when Math_Syntax.Double_Bar_Delimiter =>
               Point := 16#7C#;
            when Math_Syntax.No_Delimiter =>
               return;
         end case;
         Delimiter_Metric := Scaled_Metric (Delimiter_Font, Point, Scale);
         Delimiter_Command.Font       := Delimiter_Font;
         Delimiter_Command.Code_Point := Point;
         Delimiter_Command.X          := X;
         Delimiter_Command.Y          :=
           (Delimiter_Metric.Ascent - Delimiter_Metric.Descent) / 2.0;
         Delimiter_Command.Scale      := Scale;
         Delimiter_Command.Width      :=
           Scaled_Metric (Delimiter_Font, Point, Scale).Width;
         Delimiter_Command.Height     :=
           Delimiter_Metric.Ascent + Delimiter_Metric.Descent;
         Result.Commands.Append (Delimiter_Command);
         if Kind = Double_Bar_Delimiter then
            Delimiter_Command.X := X + Delimiter_Command.Width + Delimiter_Gap;
            Result.Commands.Append (Delimiter_Command);
         end if;
      end Add_Delimiter;
   begin
      Row_Id := Value.First;
      while Row_Id /= No_Node loop
         if Row_Id > Math_Syntax.Count (Item)
           or else Link_Count >= Math_Syntax.Count (Item)
         then
            Reject ("invalid or cyclic array row link");
         end if;
         Link_Count := Link_Count + 1;
         Rows       := Rows + 1;
         if Rows > Max_Rows then
            Reject ("array row limit exceeded");
         end if;
         Row_Value := Math_Syntax.Element (Item, Positive (Row_Id));
         if Row_Value.Kind /= Math_Model.Row_Node then
            Reject ("invalid array row node");
         end if;
         Cell_Id    := Row_Value.First;
         Column     := 0;
         Cell_Count := 0;
         while Cell_Id /= No_Node loop
            if Cell_Id > Math_Syntax.Count (Item)
              or else Cell_Count >= Math_Syntax.Count (Item)
            then
               Reject ("invalid or cyclic array cell link");
            end if;
            Cell_Count := Cell_Count + 1;
            Column     := Column + 1;
            if Column > Max_Columns then
               Reject ("array column limit exceeded");
            end if;
            Cell_Value := Math_Syntax.Element (Item, Positive (Cell_Id));
            if Cell_Value.Kind /= Math_Model.Row_Node or
              Cell_Value.First = No_Node
            then
               Reject ("invalid array cell expression");
            end if;
            Cells (Rows, Column)   :=
              Compose (Item, Cell_Id, Level, Scale, Depth + 1);
            Column_Widths (Column) :=
              Maximum (Column_Widths (Column), Cells (Rows, Column).Width);
            Row_Ascents (Rows)     :=
              Maximum (Row_Ascents (Rows), Cells (Rows, Column).Ascent);
            Row_Descents (Rows)    :=
              Maximum (Row_Descents (Rows), Cells (Rows, Column).Descent);
            Cell_Id                := Cell_Value.Next;
         end loop;
         if Column = 0 then
            Reject ("empty array row");
         end if;
         Columns := Natural'Max (Columns, Column);
         Row_Id  := Row_Value.Next;
      end loop;
      if Rows = 0 or Columns = 0 then
         Reject ("empty array");
      end if;
      for I in 1 .. Rows loop
         Total_Height := Total_Height + Row_Ascents (I) + Row_Descents (I);
      end loop;
      Total_Height := Total_Height + Row_Gap * Long_Float (Rows - 1);
      for I in 1 .. Columns loop
         Total_Width := Total_Width + Column_Widths (I);
      end loop;
      Total_Width := Total_Width + Column_Gap * Long_Float (Columns - 1);
      Need_Height := Total_Height + 0.2 * Scale;
      Measure_Delimiter (Value.Left_Delimiter);
      if Value.Left_Delimiter /= Math_Syntax.No_Delimiter then
         Left_Width := Delimiter_Metric.Width + Delimiter_Gap;
         if Value.Left_Delimiter = Double_Bar_Delimiter then
            Left_Width := Left_Width + Delimiter_Metric.Width + Delimiter_Gap;
         end if;
      end if;
      Measure_Delimiter (Value.Right_Delimiter);
      if Value.Right_Delimiter /= Math_Syntax.No_Delimiter then
         Right_Width := Delimiter_Metric.Width + Delimiter_Gap;
         if Value.Right_Delimiter = Double_Bar_Delimiter then
            Right_Width :=
              Right_Width + Delimiter_Metric.Width + Delimiter_Gap;
         end if;
      end if;
      Y_Offset := -Total_Height / 2.0;
      for I in 1 .. Rows loop
         Row_Center := Y_Offset + Row_Ascents (I);
         X_Offset   := Left_Width;
         for J in 1 .. Columns loop
            if J <= Max_Columns and then Cells (I, J).Valid then
               if Value.Array_Type = Aligned_Array then
                  if J mod 2 = 1 then
                     X_Offset :=
                       X_Offset + Column_Widths (J) - Cells (I, J).Width;
                  end if;
               elsif Value.Array_Type = Matrix_Array then
                  X_Offset :=
                    X_Offset + (Column_Widths (J) - Cells (I, J).Width) / 2.0;
               end if;
               Append_At (Result, Cells (I, J), X_Offset, Row_Center);
               X_Offset := X_Offset + Cells (I, J).Width;
               if J < Columns then
                  X_Offset := X_Offset + Column_Gap;
               end if;
            else
               if Value.Array_Type = Aligned_Array and then J mod 2 = 1 then
                  X_Offset := X_Offset + Column_Widths (J);
               end if;
               if J < Columns then
                  X_Offset := X_Offset + Column_Gap;
               end if;
            end if;
         end loop;
         Result.Ascent  :=
           Maximum (Result.Ascent, -Row_Center + Row_Ascents (I), 0.0);
         Result.Descent :=
           Maximum (Result.Descent, Row_Center + Row_Descents (I), 0.0);
         Y_Offset := Y_Offset + Row_Ascents (I) + Row_Descents (I) + Row_Gap;
      end loop;
      Total_Width  := Left_Width + Total_Width + Right_Width;
      Result.Width := Total_Width;
      Need_Height  := Total_Height + 0.2 * Scale;
      Measure_Delimiter (Value.Left_Delimiter);
      Add_Delimiter (Value.Left_Delimiter, 0.0, False);
      Measure_Delimiter (Value.Right_Delimiter);
      Add_Delimiter
        (Value.Right_Delimiter, Total_Width - Right_Width + Delimiter_Gap,
         True);
      Result.Ascent  := Maximum (Result.Ascent, Total_Height / 2.0, 0.0);
      Result.Descent := Maximum (Result.Descent, Total_Height / 2.0, 0.0);
      Result.Valid   := True;
      return Result;
   end Compose_Array;

   function Compose
     (Item  : Math_Syntax.Document; Id : Node_Id; Level : Style_Level;
      Scale : Long_Float; Depth : Natural) return Box
   is
      Value   : Math_Syntax.Node;
      Result  : Box;
      Metric  : Math_Metrics.Glyph_Metric;
      Command : Draw_Command;
      Op_Font : Font_Kind;
   begin
      if Depth > Max_Layout_Depth or Id = No_Node then
         Reject ("invalid node reference or excessive layout depth");
      end if;
      if Id > Math_Syntax.Count (Item) then
         Reject ("invalid node reference or excessive layout depth");
      end if;
      Value   := Math_Syntax.Element (Item, Positive (Id));
      Op_Font := Value.Font;
      case Value.Kind is
         when Row_Node =>
            Result := Compose_Row (Item, Value, Level, Scale, Depth);
         when Glyph_Node =>
            if Value.Class = Operator_Atom and
              (Value.Code_Point = 16#2211# or Value.Code_Point = 16#220F# or
               Value.Code_Point = 16#222B#)
            then
               if Value.Code_Point = 16#222B# then
                  Op_Font := Size_1;
               elsif Level = Display_Level then
                  Op_Font := Size_2;
               else
                  Op_Font := Size_1;
               end if;
            end if;
            Metric := Scaled_Metric (Op_Font, Value.Code_Point, Scale);
            Command.Font       := Op_Font;
            Command.Code_Point := Value.Code_Point;
            Command.Scale      := Scale;
            Command.Width      := Metric.Width;
            Command.Height     := Metric.Ascent + Metric.Descent;
            Result.Commands.Append (Command);
            Result.Width   := Metric.Width;
            Result.Ascent  := Maximum (Metric.Ascent, 0.0);
            Result.Descent := Maximum (Metric.Descent, 0.0);
            Result.Italic  := Metric.Italic;
            Result.Valid   := True;
         when Fraction_Node =>
            if Value.First = No_Node or Value.Second = No_Node or
              Value.Third /= No_Node
            then
               Reject ("invalid fraction children");
            end if;
            Result := Compose_Fraction (Item, Value, Level, Scale, Depth);
         when Radical_Node =>
            if Value.First = No_Node or Value.Third /= No_Node then
               Reject ("invalid radical children");
            end if;
            Result := Compose_Radical (Item, Value, Level, Scale, Depth);
         when Scripts_Node =>
            if Value.First = No_Node then
               Reject ("scripts node has no base");
            end if;
            Result := Compose_Scripts (Item, Value, Level, Scale, Depth);
         when Array_Node =>
            Result := Compose_Array (Item, Value, Level, Scale, Depth);
         when Overlay_Node =>
            declare
               Base  : Box :=
                 Compose (Item, Value.First, Level, Scale, Depth + 1);
               Slash : Box :=
                 Compose (Item, Value.Second, Level, Scale * 0.9, Depth + 1);
            begin
               Append_At (Base, Slash, Base.Width * 0.35, 0.0);
               Base.Width :=
                 Long_Float'Max (Base.Width, Base.Width * 0.35 + Slash.Width);
               Result     := Base;
            end;
         when Accent_Node =>
            declare
               Base   : Box :=
                 Compose (Item, Value.First, Level, Scale, Depth + 1);
               Mark   : Math_Metrics.Glyph_Metric;
               Accent : Draw_Command;
            begin
               Result := Base;
               if Value.Code_Point = 0 then
                  Accent.Kind   := Rule_Command;
                  Accent.X      := 0.05 * Scale;
                  Accent.Y      := -(Base.Ascent + 0.08 * Scale);
                  Accent.Width  :=
                    Long_Float'Max (Base.Width - 0.1 * Scale, 0.05 * Scale);
                  Accent.Height := Rule_Thickness * Scale;
                  Result.Ascent := Base.Ascent + 0.12 * Scale;
               else
                  Mark := Math_Metrics.Lookup (Main_Regular, Value.Code_Point);
                  if not Mark.Found then
                     Reject ("accent glyph metric unavailable");
                  end if;
                  Accent.Font       := Main_Regular;
                  Accent.Code_Point := Value.Code_Point;
                  Accent.X          := (Base.Width - Mark.Width * Scale) / 2.0;
                  Accent.Y          := -(Base.Ascent + 0.12 * Scale);
                  Accent.Scale      := Scale;
                  Accent.Width      := Mark.Width * Scale;
                  Accent.Height     := (Mark.Ascent + Mark.Descent) * Scale;
                  Result.Ascent := Base.Ascent + Accent.Height + 0.12 * Scale;
               end if;
               Result.Commands.Append (Accent);
               Result.Valid := True;
            end;
         when Delimited_Node =>
            declare
               Inner        : Box                 :=
                 Compose (Item, Value.First, Level, Scale, Depth + 1);
               Left_Point   : Natural             := 0;
               Right_Point  : Natural             := 0;
               Left_Metric  : Math_Metrics.Glyph_Metric;
               Right_Metric : Math_Metrics.Glyph_Metric;
               Delimiter    : Draw_Command;
               Gap          : constant Long_Float := 0.1 * Scale;
               Total_Height : constant Long_Float :=
                 Inner.Ascent + Inner.Descent + 0.2 * Scale;
               Font         : Font_Kind           := Main_Regular;
               Found        : Boolean             := False;
               Size         : Font_Kind;
            begin
               case Value.Left_Delimiter is
                  when Math_Syntax.Parenthesis_Delimiter =>
                     Left_Point := 16#28#;
                  when Math_Syntax.Bracket_Delimiter =>
                     Left_Point := 16#5B#;
                  when Math_Syntax.Brace_Delimiter =>
                     Left_Point := 16#7B#;
                  when Math_Syntax.Bar_Delimiter =>
                     Left_Point := 16#7C#;
                  when Math_Syntax.Double_Bar_Delimiter =>
                     Left_Point := 16#7C#;
                  when Math_Syntax.No_Delimiter =>
                     null;
               end case;
               case Value.Right_Delimiter is
                  when Math_Syntax.Parenthesis_Delimiter =>
                     Right_Point := 16#29#;
                  when Math_Syntax.Bracket_Delimiter =>
                     Right_Point := 16#5D#;
                  when Math_Syntax.Brace_Delimiter =>
                     Right_Point := 16#7D#;
                  when Math_Syntax.Bar_Delimiter =>
                     Right_Point := 16#7C#;
                  when Math_Syntax.Double_Bar_Delimiter =>
                     Right_Point := 16#7C#;
                  when Math_Syntax.No_Delimiter =>
                     null;
               end case;
               if Value.Left_Delimiter in
                   Math_Syntax.Bar_Delimiter | Math_Syntax.Double_Bar_Delimiter
                 or else Value.Right_Delimiter in
                   Math_Syntax.Bar_Delimiter | Math_Syntax.Double_Bar_Delimiter
               then
                  Font  := Main_Regular;
                  Found := True;
               else
                  for I in Font_Kind'Pos (Size_1) .. Font_Kind'Pos (Size_4)
                  loop
                     Size         := Font_Kind'Val (I);
                     Left_Metric  :=
                       (if Left_Point = 0 then (Found => True, others => 0.0)
                        else Math_Metrics.Lookup (Size, Left_Point));
                     Right_Metric :=
                       (if Right_Point = 0 then (Found => True, others => 0.0)
                        else Math_Metrics.Lookup (Size, Right_Point));
                     if Left_Metric.Found and then Right_Metric.Found
                       and then
                         Long_Float'Max
                           (Left_Metric.Ascent + Left_Metric.Descent,
                            Right_Metric.Ascent + Right_Metric.Descent) >=
                         Total_Height
                     then
                        Font  := Size;
                        Found := True;
                        exit;
                     end if;
                  end loop;
               end if;
               if not Found then
                  Reject ("delimited expression exceeds natural glyph sizes");
               end if;
               if Left_Point /= 0 then
                  Left_Metric := Scaled_Metric (Font, Left_Point, Scale);
                  Delimiter   :=
                    (Kind       => Glyph_Command, Font => Font,
                     Code_Point => Left_Point, X => 0.0,
                     Y => (Left_Metric.Ascent - Left_Metric.Descent) / 2.0,
                     Scale      => Scale, Width => Left_Metric.Width,
                     Height     => Left_Metric.Ascent + Left_Metric.Descent);
                  Result.Commands.Append (Delimiter);
                  if Value.Left_Delimiter = Math_Syntax.Double_Bar_Delimiter
                  then
                     Delimiter.X := Left_Metric.Width + Gap;
                     Result.Commands.Append (Delimiter);
                  end if;
               end if;
               Append_At
                 (Result, Inner,
                  (if Left_Point = 0 then 0.0
                   else Left_Metric.Width *
                     (if
                        Value.Left_Delimiter = Math_Syntax.Double_Bar_Delimiter
                      then 2.0
                      else 1.0) +
                     Gap),
                  0.0);
               if Right_Point /= 0 then
                  Right_Metric := Scaled_Metric (Font, Right_Point, Scale);
                  Delimiter.Code_Point := Right_Point;
                  Delimiter.X          :=
                    (if Left_Point = 0 then 0.0
                     else Left_Metric.Width +
                       (if
                          Value.Left_Delimiter =
                          Math_Syntax.Double_Bar_Delimiter
                        then Left_Metric.Width + Gap
                        else 0.0) +
                       Gap) +
                    Inner.Width + Gap;
                  Delimiter.Y          :=
                    (Right_Metric.Ascent - Right_Metric.Descent) / 2.0;
                  Delimiter.Width      := Right_Metric.Width;
                  Delimiter.Height     :=
                    Right_Metric.Ascent + Right_Metric.Descent;
                  Result.Commands.Append (Delimiter);
                  if Value.Right_Delimiter = Math_Syntax.Double_Bar_Delimiter
                  then
                     Delimiter.X := Delimiter.X + Right_Metric.Width + Gap;
                     Result.Commands.Append (Delimiter);
                  end if;
               end if;
               Result.Width   :=
                 Inner.Width +
                 (if Left_Point = 0 then 0.0
                  else Left_Metric.Width *
                    (if Value.Left_Delimiter = Math_Syntax.Double_Bar_Delimiter
                     then 2.0
                     else 1.0) +
                    Gap) +
                 (if Right_Point = 0 then 0.0
                  else Right_Metric.Width *
                    (if
                       Value.Right_Delimiter = Math_Syntax.Double_Bar_Delimiter
                     then 2.0
                     else 1.0) +
                    Gap);
               Result.Ascent  :=
                 Long_Float'Max (Inner.Ascent, Total_Height / 2.0);
               Result.Descent :=
                 Long_Float'Max (Inner.Descent, Total_Height / 2.0);
               Result.Valid   := True;
            end;
         when Space_Node =>
            if Value.Amount < -10.0 or Value.Amount > 10.0 then
               Reject ("space amount out of bounds");
            end if;
            Result.Width := Value.Amount * Scale;
            Result.Valid := True;
      end case;
      return Result;
   end Compose;

   function Build
     (Item : Math_Syntax.Document; Style : Math_Style := Text_Style) return Box
   is
      Result    : Box;
      Level     : constant Style_Level :=
        (if Style = Display_Style then Display_Level else Text_Level);
      Root_Id   : Node_Id;
      Root_Node : Math_Syntax.Node;
   begin
      if not Math_Syntax.Is_Valid (Item) then
         Result.Message :=
           To_Unbounded_String ("invalid syntax: " & Math_Syntax.Error (Item));
         return Result;
      end if;
      Root_Id := Math_Syntax.Root (Item);
      if Root_Id = No_Node or Root_Id > Math_Syntax.Count (Item) then
         Reject ("invalid document root");
      end if;
      Root_Node := Math_Syntax.Element (Item, Positive (Root_Id));
      if Root_Node.Kind /= Row_Node or Root_Node.Next /= No_Node then
         Reject ("invalid document root");
      end if;
      Result := Compose (Item, Root_Id, Level, 1.0, 0);
      if Result.Width > Max_Geometry or else Result.Ascent > Max_Geometry
        or else Result.Descent > Max_Geometry
      then
         Reject ("layout geometry limit exceeded");
      end if;
      for Command of Result.Commands loop
         if abs Command.X > Max_Geometry or else abs Command.Y > Max_Geometry
           or else Command.Width > Max_Geometry
           or else Command.Height > Max_Geometry
           or else Command.Scale > Max_Geometry
         then
            Reject ("draw-command geometry limit exceeded");
         end if;
      end loop;
      Result.Valid := True;
      return Result;
   exception
      when E : Layout_Failure =>
         Result :=
           (Valid    => False, Width => 0.0, Ascent => 0.0, Descent => 0.0,
            Italic   => 0.0,
            Message  =>
              To_Unbounded_String (Ada.Exceptions.Exception_Message (E)),
            Commands => Command_Vectors.Empty_Vector);
         return Result;
   end Build;

end Math_Layout;
