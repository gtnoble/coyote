with Ada.Containers;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Numerics.Long_Elementary_Functions;
with Math_Metrics;
with Math_Model;
with Math_Syntax;
with Math_Paths;
with Math_Stretchy;
with Math_Radical_Paths;
with Math_Work_Control;
with Math_Text_Shaping;

--  Geometry uses the checked-in KaTeX 0.16.22 metric tables and the supported
--  syntax declared by Math_Syntax. Unsupported forms fail rather than being
--  approximated as successful output; no external process or GTK is used.
package body Math_Layout is
   use Ada.Strings.Unbounded;
   use Math_Model;
   use type Ada.Containers.Count_Type;
   use type Math_Syntax.Delimiter_Kind;
   use type Math_Metrics.Advance_Source_Access;
   use type Math_Stretchy.Brace_Kind;

   Layout_Failure : exception;
   Max_Layout_Depth  : constant Natural    := 256;
   Max_Draw_Commands : constant            := 131_072;
   Max_Geometry      : constant Long_Float := 16_384.0;
   Default_Rule_Thickness : constant Long_Float := 0.04;
   Fraction_Axis     : constant Long_Float := 0.25;

   type Rule_Parameters is record
      Minimum  : Long_Float;
      Effective : Long_Float;
      Work : Math_Work_Control.Context_Access := null;
      Pixel_Em : Long_Float := 0.0;
      Advance_Source : Math_Metrics.Advance_Source_Access := null;
   end record;
   X_Height          : constant Long_Float := 0.431;

   type Style_Level is
     (Display_Level, Display_Cramped_Level,
      Text_Level, Text_Cramped_Level,
      Script_Level, Script_Cramped_Level,
      Scriptscript_Level, Scriptscript_Cramped_Level);

   procedure Reject (Why : String) is
   begin
      raise Layout_Failure with Why;
   end Reject;

   procedure Poll (Thickness : Rule_Parameters) is
   begin
      Math_Work_Control.Poll (Thickness.Work);
   end Poll;

   procedure Append_Command
     (Target : in out Box; Command : Draw_Command;
      Work : Math_Work_Control.Context_Access := null)
   is
   begin
      if Target.Commands.Length mod 128 = 0 then
         Math_Work_Control.Poll (Work);
      end if;
      if Target.Commands.Length >= Max_Draw_Commands then
         Reject ("draw-command limit exceeded");
      end if;
      Target.Commands.Append (Command);
   end Append_Command;

   function Is_Cramped (Level : Style_Level) return Boolean is
   begin
      return Level in Display_Cramped_Level | Text_Cramped_Level |
        Script_Cramped_Level | Scriptscript_Cramped_Level;
   end Is_Cramped;

   function Is_Display (Level : Style_Level) return Boolean is
   begin
      return Level in Display_Level | Display_Cramped_Level;
   end Is_Display;

   function Is_Tight (Level : Style_Level) return Boolean is
   begin
      return Level in Script_Level | Script_Cramped_Level |
        Scriptscript_Level | Scriptscript_Cramped_Level;
   end Is_Tight;

   function Cramped (Level : Style_Level) return Style_Level is
   begin
      case Level is
         when Display_Level | Display_Cramped_Level =>
            return Display_Cramped_Level;
         when Text_Level | Text_Cramped_Level =>
            return Text_Cramped_Level;
         when Script_Level | Script_Cramped_Level =>
            return Script_Cramped_Level;
         when Scriptscript_Level | Scriptscript_Cramped_Level =>
            return Scriptscript_Cramped_Level;
      end case;
   end Cramped;

   function Smaller (Level : Style_Level) return Style_Level is
   begin
      case Level is
         when Display_Level | Display_Cramped_Level |
              Text_Level | Text_Cramped_Level =>
            return Script_Level;
         when Script_Level | Script_Cramped_Level |
              Scriptscript_Level | Scriptscript_Cramped_Level =>
            return Scriptscript_Level;
      end case;
   end Smaller;

   function Sup_Style (Level : Style_Level) return Style_Level is
   begin
      case Level is
         when Display_Level | Text_Level =>
            return Script_Level;
         when Display_Cramped_Level | Text_Cramped_Level =>
            return Script_Cramped_Level;
         when Script_Level | Scriptscript_Level =>
            return Scriptscript_Level;
         when Script_Cramped_Level | Scriptscript_Cramped_Level =>
            return Scriptscript_Cramped_Level;
      end case;
   end Sup_Style;

   function Sub_Style (Level : Style_Level) return Style_Level is
   begin
      return Cramped (Smaller (Level));
   end Sub_Style;

   function Fraction_Numerator (Level : Style_Level) return Style_Level is
   begin
      case Level is
         when Display_Level => return Text_Level;
         when Display_Cramped_Level => return Text_Cramped_Level;
         when Text_Level => return Script_Level;
         when Text_Cramped_Level => return Script_Cramped_Level;
         when Script_Level => return Scriptscript_Level;
         when Script_Cramped_Level => return Scriptscript_Cramped_Level;
         when Scriptscript_Level => return Scriptscript_Level;
         when Scriptscript_Cramped_Level => return Scriptscript_Cramped_Level;
      end case;
   end Fraction_Numerator;

   function Fraction_Denominator (Level : Style_Level) return Style_Level is
   begin
      return Cramped (Fraction_Numerator (Level));
   end Fraction_Denominator;

   --  Match KaTeX genfrac.adjustStyle: display fractions shrink in
   --  script styles, while text fractions retain non-display input style.
   function Adjusted_Fraction_Style
     (Level : Style_Level; Value : Math_Syntax.Node) return Style_Level
   is
      Kind : constant Fraction_Style := Value.Fraction_Type;
   begin
      if Value.Fraction_Type = Default_Fraction and then
        Value.Fraction_Style_Mode /= Natural_Style then
         return
           (case Value.Fraction_Style_Mode is
              when Natural_Style => Level,
              when Display_Style =>
                (if Is_Cramped (Level) then Display_Cramped_Level
                 else Display_Level),
              when Text_Style =>
                (if Is_Cramped (Level) then Text_Cramped_Level
                 else Text_Level),
              when Script_Style => Script_Level,
              when Script_Script_Style => Scriptscript_Level);
      end if;
      case Kind is
         when Display_Fraction =>
            if Is_Tight (Level) then
               return (if Is_Cramped (Level)
                       then Text_Cramped_Level else Text_Level);
            end if;
            return (if Is_Cramped (Level)
                    then Display_Cramped_Level else Display_Level);
         when Text_Fraction =>
            if Is_Display (Level) then
               return (if Is_Cramped (Level)
                       then Text_Cramped_Level else Text_Level);
            end if;
            return Level;
         when Default_Fraction =>
            return Level;
      end case;
   end Adjusted_Fraction_Style;
   function Scaled_Metric
     (Font : Font_Kind; Point : Natural; Scale : Long_Float;
      Thickness : Rule_Parameters)
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
      Result.Skew    := Result.Skew * Scale;
      if Thickness.Advance_Source /= null then
         declare
            Measured : constant Long_Float := Math_Metrics.Advance
              (Thickness.Advance_Source.all, Font, Point,
               Thickness.Pixel_Em * Scale) / Thickness.Pixel_Em;
         begin
            if not Measured'Valid or else Measured < 0.0 or else
              Measured > Max_Geometry
            then
               Reject ("invalid measured glyph advance");
            end if;
            Result.Width := Measured;
         end;
      end if;
      return Result;
   end Scaled_Metric;

   function Style_Scale (Level : Style_Level) return Long_Float is
   begin
      case Level is
         when Display_Level | Display_Cramped_Level |
              Text_Level | Text_Cramped_Level =>
            return 1.0;
         when Script_Level | Script_Cramped_Level =>
            return 0.7;
         when Scriptscript_Level | Scriptscript_Cramped_Level =>
            return 0.5;
      end case;
   end Style_Scale;

   --  KaTeX fontMetrics.js has separate text, script and scriptscript
   --  parameters. Glyph scaling alone cannot reproduce these dimensions.
   function Style_Metric
     (Level : Style_Level; Text, Script, Scriptscript : Long_Float)
      return Long_Float is
   begin
      case Level is
         when Display_Level | Display_Cramped_Level |
              Text_Level | Text_Cramped_Level => return Text;
         when Script_Level | Script_Cramped_Level => return Script;
         when Scriptscript_Level | Scriptscript_Cramped_Level =>
            return Scriptscript;
      end case;
   end Style_Metric;

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

   function Is_Character_Box
     (Item : Math_Syntax.Document; Id : Node_Id) return Boolean
   is
      Value : constant Math_Syntax.Node :=
        Math_Syntax.Element (Item, Positive (Id));
   begin
      case Value.Kind is
         when Glyph_Node =>
            return Value.Class /= Operator_Atom;
         when Row_Node =>
            if Value.First = No_Node then
               return False;
            end if;
            declare
               Child : constant Math_Syntax.Node :=
                 Math_Syntax.Element (Item, Positive (Value.First));
            begin
               return Child.Next = No_Node and then
                 Is_Character_Box (Item, Value.First);
            end;
         when Accent_Node =>
            return Value.First /= No_Node and then
              Is_Character_Box (Item, Value.First);
         when others =>
            return False;
      end case;
   end Is_Character_Box;

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
      if Value.Kind in Row_Node | Glyph_Node | Scripts_Node | Fraction_Node |
        Overlay_Node | Overlap_Node | Dual_Node | Poor_Bold_Node |
        Verbatim_Node | Annotation_Node
      then
         if (if Value.Kind = Poor_Bold_Node
             then Value.Poor_Bold_Class = Binary_Atom
             else Value.Class = Binary_Atom)
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
      Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters) return Box;

   function Compose_Array
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters) return Box;

   function Compose_Delimiter
     (Kind : Math_Syntax.Delimiter_Kind; Right_Side : Boolean;
      Need_Height, Scale : Long_Float; Thickness : Rule_Parameters) return Box
   is
      Result : Box;
      Point, Top, Repeat, Bottom : Natural;
      Middle : Natural := 0;
      Font : Font_Kind := Size_4;
      Metric : Math_Metrics.Glyph_Metric;
      Total : Long_Float := 0.0;
      Pieces : Natural := 0;
      Overlap : constant Long_Float := 0.008 * Scale;
      Top_H, Repeat_H, Middle_H, Bottom_H : Long_Float;
      Minimum, Required, Cursor : Long_Float;
      Factor : Natural := 1;
      procedure Add_Piece (Code : Natural; Baseline : Long_Float) is
         M : constant Math_Metrics.Glyph_Metric :=
           Scaled_Metric (Font, Code, Scale, Thickness);
      begin
         Append_Command (Result, Draw_Command'
           (Kind => Glyph_Command, Font => Font, Code_Point => Code,
             X => 0.0, Y => Baseline, Scale => Scale, Width => M.Width,
             Height => M.Ascent + M.Descent, others => <>), Thickness.Work);
      end Add_Piece;
      function Piece_Height (Code : Natural) return Long_Float is
         M : constant Math_Metrics.Glyph_Metric :=
           Scaled_Metric (Font, Code, Scale, Thickness);
      begin
         return M.Ascent + M.Descent;
      end Piece_Height;
   begin
      if Kind in Math_Syntax.Bar_Delimiter | Math_Syntax.Double_Bar_Delimiter then
         Metric := Scaled_Metric (Main_Regular, 16#7C#, Scale, Thickness);
         Result.Width := Metric.Width *
           (if Kind = Math_Syntax.Double_Bar_Delimiter then 2.0 else 1.0) +
           (if Kind = Math_Syntax.Double_Bar_Delimiter then 0.04 * Scale else 0.0);
         if Metric.Ascent + Metric.Descent >= Need_Height then
            declare
               Axis : constant Long_Float := Fraction_Axis * Scale;
               Height : constant Long_Float :=
                 (Metric.Ascent + Metric.Descent) * Scale;
               Baseline : constant Long_Float :=
                 (Metric.Ascent - Metric.Descent) * Scale / 2.0 - Axis;
            begin
               Append_Command (Result, Draw_Command'
                 (Kind => Glyph_Command, Font => Main_Regular,
                  Code_Point => 16#7C#, X => 0.0, Y => Baseline,
                  Scale => Scale, Width => Metric.Width * Scale,
                  Height => Height, others => <>), Thickness.Work);
               if Kind = Math_Syntax.Double_Bar_Delimiter then
                  Append_Command (Result, Draw_Command'
                    (Kind => Glyph_Command, Font => Main_Regular,
                     Code_Point => 16#7C#,
                     X => Metric.Width * Scale + 0.04 * Scale,
                     Y => Baseline, Scale => Scale,
                     Width => Metric.Width * Scale, Height => Height,
                     others => <>), Thickness.Work);
               end if;
               Result.Ascent := Height / 2.0 + Axis;
               Result.Descent := Height / 2.0 - Axis;
            end;
         else
            if Need_Height > Max_Geometry then
               Reject ("delimiter assembly bounds exceeded");
            end if;
            Append_Command (Result, Draw_Command'(Kind => Rule_Command, Font => Main_Regular,
                Code_Point => 0, X => 0.0, Y => -Need_Height / 2.0,
                Scale => Scale, Width => Thickness.Effective * Scale,
                Height => Need_Height, others => <>), Thickness.Work);
            Result.Width := Thickness.Effective * Scale *
              (if Kind = Math_Syntax.Double_Bar_Delimiter then 2.0 else 1.0);
            Result.Ascent := Need_Height / 2.0;
            Result.Descent := Need_Height / 2.0;
         end if;
         Result.Valid := True;
         return Result;
      end if;
      case Kind is
         when Math_Syntax.Parenthesis_Delimiter =>
            Point := (if Right_Side then 16#29# else 16#28#);
            Top := (if Right_Side then 16#239E# else 16#239B#);
            Repeat := (if Right_Side then 16#239F# else 16#239C#);
            Bottom := (if Right_Side then 16#23A0# else 16#239D#);
         when Math_Syntax.Bracket_Delimiter =>
            Point := (if Right_Side then 16#5D# else 16#5B#);
            Top := (if Right_Side then 16#23A4# else 16#23A1#);
            Repeat := (if Right_Side then 16#23A5# else 16#23A2#);
            Bottom := (if Right_Side then 16#23A6# else 16#23A3#);
         when Math_Syntax.Brace_Delimiter =>
            Point := (if Right_Side then 16#7D# else 16#7B#);
            Top := (if Right_Side then 16#23AB# else 16#23A7#);
            Middle := (if Right_Side then 16#23AC# else 16#23A8#);
            Bottom := (if Right_Side then 16#23AD# else 16#23A9#);
            Repeat := 16#23AA#;
         when Math_Syntax.Angle_Delimiter =>
            Point := (if Right_Side then 16#27E9# else 16#27E8#);
         when Math_Syntax.Floor_Delimiter =>
            Point := (if Right_Side then 16#230B# else 16#230A#);
            Top := (if Right_Side then 16#23A4# else 16#23A1#);
            Repeat := (if Right_Side then 16#23A5# else 16#23A2#);
            Bottom := (if Right_Side then 16#23A6# else 16#23A3#);
         when Math_Syntax.Ceiling_Delimiter =>
            Point := (if Right_Side then 16#2309# else 16#2308#);
            Top := (if Right_Side then 16#23A1# else 16#23A4#);
            Repeat := (if Right_Side then 16#23A2# else 16#23A5#);
            Bottom := (if Right_Side then 16#23A3# else 16#23A6#);
         when others =>
            return Result;
      end case;
      Metric := Scaled_Metric (Main_Regular, Point, Scale, Thickness);
      if Metric.Ascent + Metric.Descent > Need_Height then
         Font := Main_Regular;
         Total := Metric.Ascent + Metric.Descent;
      end if;
      for Index in Font_Kind'Pos (Size_1) .. Font_Kind'Pos (Size_4) loop
         exit when Total > 0.0;
         Font := Font_Kind'Val (Index);
         Metric := Scaled_Metric (Font, Point, Scale, Thickness);
         if Metric.Ascent + Metric.Descent > Need_Height then
            Total := Metric.Ascent + Metric.Descent;
            exit;
         end if;
      end loop;
      if Total = 0.0 and then Kind = Math_Syntax.Angle_Delimiter then
         Font := Size_4;
         Metric := Scaled_Metric (Font, Point, Scale, Thickness);
         Total := Metric.Ascent + Metric.Descent;
      end if;
      if Total = 0.0 and then Kind /= Math_Syntax.Angle_Delimiter then
         Font := Size_4;
         Metric := Scaled_Metric (Font, Point, Scale, Thickness);
         Top_H := Piece_Height (Top);
         Repeat_H := Piece_Height (Repeat);
         Bottom_H := Piece_Height (Bottom);
         Middle_H := (if Middle = 0 then 0.0 else Piece_Height (Middle));
         if Middle /= 0 then
            Factor := 2;
         end if;
         Minimum := Top_H + Bottom_H + Middle_H;
         Required := Long_Float'Max (Need_Height, Minimum);
         if Required > Max_Geometry or Repeat_H <= Overlap then
            Reject ("delimiter assembly bounds exceeded");
         end if;
         Pieces := Natural'Max
           (0, Natural'Min
             (16_000, Natural (Long_Float'Ceiling
               ((Required - Minimum) /
                (Long_Float (Factor) * Repeat_H)))));
         Total := Minimum + Long_Float (Pieces * Factor) * Repeat_H;
         if Total > Max_Geometry then
            Reject ("delimiter assembly bounds exceeded");
         end if;
         Cursor := -Total / 2.0 - Fraction_Axis * Scale;
         declare
            H : constant Long_Float := Piece_Height (Bottom);
         begin
            Add_Piece (Bottom, Cursor + H / 2.0);
            Cursor := Cursor + H - Overlap;
         end;
         for I in 1 .. Pieces loop
            Add_Piece (Repeat, Cursor + Repeat_H / 2.0);
            Cursor := Cursor + Repeat_H - Overlap;
         end loop;
         if Middle /= 0 then
            Add_Piece (Middle, Cursor + Middle_H / 2.0);
            Cursor := Cursor + Middle_H - Overlap;
            for I in 1 .. Pieces loop
               Add_Piece (Repeat, Cursor + Repeat_H / 2.0);
               Cursor := Cursor + Repeat_H - Overlap;
            end loop;
         end if;
         Add_Piece (Top, Cursor + Top_H / 2.0);
         Result.Width := Metric.Width;
         Result.Ascent := Total / 2.0 + Fraction_Axis * Scale;
         Result.Descent := Total / 2.0 - Fraction_Axis * Scale;
         Result.Valid := True;
         return Result;
      end if;
      Append_Command (Result, Draw_Command'
        (Kind => Glyph_Command, Font => Font, Code_Point => Point,
          X => 0.0,
          Y => (Metric.Ascent - Metric.Descent) / 2.0 -
            Fraction_Axis * Scale,
          Scale => Scale, Width => Metric.Width,
          Height => Metric.Ascent + Metric.Descent, others => <>), Thickness.Work);
      Result.Width := Metric.Width;
      Result.Ascent := (Metric.Ascent + Metric.Descent) / 2.0 +
        Fraction_Axis * Scale;
      Result.Descent := (Metric.Ascent + Metric.Descent) / 2.0 -
        Fraction_Axis * Scale;
      Result.Valid := True;
      return Result;
   end Compose_Delimiter;

   procedure Append_At
     (Target : in out Box; Source : Box; X_Offset, Y_Offset : Long_Float;
      Work : Math_Work_Control.Context_Access := null)
   is
      Command : Draw_Command;
   begin
      if not Source.Valid then
         Reject (To_String (Source.Message));
      end if;
      if not Source.Commands.Is_Empty then
         for Index in Source.Commands.First_Index .. Source.Commands.Last_Index
         loop
            Math_Work_Control.Poll (Work);
            Command   := Source.Commands (Index);
            Command.X := Command.X + X_Offset;
            Command.Y := Command.Y + Y_Offset;
            Append_Command (Target, Command, Work);
         end loop;
      end if;
   end Append_At;

   function Compose_Row
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters) return Box
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
      Baseline_Offset   : Long_Float := 0.0;
      Line_Ascent       : Long_Float := 0.0;
      Line_Descent      : Long_Float := 0.0;
      Main_Extents      : Math_Metrics.Font_Line_Extent;
      Fragment_Extents : Math_Metrics.Font_Line_Extent;
   begin
      if Thickness.Advance_Source /= null then
         Main_Extents := Math_Metrics.Font_Line_Extents
           (Thickness.Advance_Source.all, Main_Regular,
            Thickness.Pixel_Em * Scale);
         declare
            Leading : constant Long_Float := Long_Float'Max
              (0.0, Long_Float'Max
                 (1.2 * Scale,
                  Main_Extents.Height / Thickness.Pixel_Em) -
                    (Main_Extents.Ascent + Main_Extents.Descent) /
                      Thickness.Pixel_Em);
         begin
            Line_Ascent :=
              (Main_Extents.Ascent / Thickness.Pixel_Em) + Leading / 2.0;
            Line_Descent :=
              (Main_Extents.Descent / Thickness.Pixel_Em) + Leading / 2.0;
         end;
      end if;
      while Probe /= No_Node loop
         Poll (Thickness);
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
         Poll (Thickness);
         Probe_Node := Math_Syntax.Element (Item, Positive (Current));
         Explicit_Space := Probe_Node.Kind = Space_Node;
         if not Explicit_Space then
            Position := Position + 1;
            Current_Class := Effective_Class (Item, Current, Position, Total);
         else
            Current_Class := Ordinary;
         end if;
         if Probe_Node.Break = Forced_Break then
            Result.Width := Long_Float'Max (Result.Width, Offset);
            Baseline_Offset := Baseline_Offset +
              Long_Float'Max
                (1.2 * Scale, Line_Ascent + Line_Descent) +
              Probe_Node.Amount;
            Offset := 0.0;
            Line_Ascent :=
              (if Thickness.Advance_Source = null then 0.0 else
                 Main_Extents.Ascent / Thickness.Pixel_Em +
                   Long_Float'Max
                     (0.0, Long_Float'Max
                        (1.2 * Scale,
                         Main_Extents.Height / Thickness.Pixel_Em) -
                           (Main_Extents.Ascent + Main_Extents.Descent) /
                             Thickness.Pixel_Em) / 2.0);
            Line_Descent :=
              (if Thickness.Advance_Source = null then 0.0 else
                 Main_Extents.Descent / Thickness.Pixel_Em +
                   Long_Float'Max
                     (0.0, Long_Float'Max
                        (1.2 * Scale,
                         Main_Extents.Height / Thickness.Pixel_Em) -
                           (Main_Extents.Ascent + Main_Extents.Descent) /
                             Thickness.Pixel_Em) / 2.0);
            Prior_Class := Ordinary;
            Previous_Class := Ordinary;
            Has_Previous_Atom := False;
            Last_Child_Italic := 0.0;
         else
            if Current_Class = Binary_Atom then
               Next_Id := Probe_Node.Next;
               Has_Next_Atom := False;
               while Next_Id /= No_Node loop
                  Poll (Thickness);
                  Next_Node := Math_Syntax.Element
                    (Item, Positive (Next_Id));
                  exit when Next_Node.Kind /= Space_Node;
                  Next_Id := Next_Node.Next;
               end loop;
               if Next_Id /= No_Node then
                  Has_Next_Atom := True;
                  Next_Node := Math_Syntax.Element
                    (Item, Positive (Next_Id));
                  Next_Class := Effective_Class
                    (Item, Next_Id, Position + 1, Total);
               end if;
               if Position = 1
                 or else Previous_Class in
                   Binary_Atom | Operator_Atom | Relation_Atom | Opening
                   | Punctuation
                 or else
                   (Has_Next_Atom and then Next_Class in
                      Relation_Atom | Closing | Punctuation)
                 or else not Has_Next_Atom
               then
                  Current_Class := Ordinary;
               end if;
            end if;
            if not Explicit_Space and Has_Previous_Atom then
               Offset := Offset + Spacing
                 (Prior_Class, Current_Class, Is_Tight (Level), Scale);
            end if;
            Child := Compose
              (Item, Current, Level, Scale, Depth + 1, Thickness);
            Append_At
              (Result, Child, Offset, Baseline_Offset, Thickness.Work);
            Offset := Offset + Child.Width;
            if Thickness.Advance_Source /= null and then
              not Child.Commands.Is_Empty
            then
               for Command of Child.Commands loop
                  Poll (Thickness);
                  if Command.Kind = Glyph_Command then
                     Fragment_Extents := Math_Metrics.Font_Line_Extents
                       (Thickness.Advance_Source.all, Command.Font,
                        Thickness.Pixel_Em * Command.Scale);
                     declare
                        Leading : constant Long_Float := Long_Float'Max
                          (0.0, 1.2 * Command.Scale -
                             (Fragment_Extents.Ascent +
                                Fragment_Extents.Descent) /
                               Thickness.Pixel_Em);
                     begin
                        Line_Ascent := Long_Float'Max
                          (Line_Ascent,
                           Fragment_Extents.Ascent / Thickness.Pixel_Em +
                             Leading / 2.0 - Command.Y);
                        Line_Descent := Long_Float'Max
                          (Line_Descent,
                           Fragment_Extents.Descent / Thickness.Pixel_Em +
                             Leading / 2.0 + Command.Y);
                     end;
                  end if;
               end loop;
            end if;
            Line_Ascent := Long_Float'Max (Line_Ascent, Child.Ascent);
            Line_Descent := Long_Float'Max (Line_Descent, Child.Descent);
            if Child.Ascent > 0.0 or else Child.Descent > 0.0 or else
              not Child.Commands.Is_Empty
            then
               Result.Ascent := Long_Float'Max
                 (Result.Ascent, Child.Ascent - Baseline_Offset);
               Result.Descent := Long_Float'Max
                 (Result.Descent, Child.Descent + Baseline_Offset);
            end if;
            if not Explicit_Space then
               Last_Child_Italic := Child.Italic;
               Prior_Class := Current_Class;
               Previous_Class := Current_Class;
               Has_Previous_Atom := True;
            end if;
         end if;
         Current := Probe_Node.Next;
      end loop;
      Result.Width := Long_Float'Max (Result.Width, Offset);
      Result.Italic := Last_Child_Italic;
      Result.Valid := True;
      return Result;
   end Compose_Row;

   function Compose_Fraction
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters;
      No_Rule : Boolean := False) return Box
   is
      Result          : Box;
      Effective_Level : constant Style_Level :=
        Adjusted_Fraction_Style (Level, Value);
      Num_Level       : constant Style_Level :=
        Fraction_Numerator (Effective_Level);
      Den_Level       : constant Style_Level :=
        Fraction_Denominator (Effective_Level);
      --  Convert into the requested fraction style once, then size each
      --  operand relative to that style rather than the caller's style.
      Adjusted_Scale  : constant Long_Float :=
        Child_Scale (Scale, Level, Effective_Level);
      Num_Scale       : constant Long_Float :=
        Adjusted_Scale * Style_Scale (Num_Level) /
          Style_Scale (Effective_Level);
      Den_Scale       : constant Long_Float :=
        Adjusted_Scale * Style_Scale (Den_Level) /
          Style_Scale (Effective_Level);
      Numerator       : Box                  :=
        Compose (Item, Value.First, Num_Level, Num_Scale, Depth + 1, Thickness);
      Denominator     : Box                  :=
        Compose (Item, Value.Second, Den_Level, Den_Scale, Depth + 1, Thickness);
      Num_Shift       : Long_Float;
      Den_Shift       : Long_Float;
      Clearance       : Long_Float;
      Rule            : Draw_Command;
      Has_Rule        : constant Boolean :=
        not No_Rule and then Value.Fraction_Bar /= Math_Model.No_Rule;
      Rule_Thickness  : constant Long_Float :=
        (if Value.Fraction_Rule_Thickness >= 0.0 then
           Long_Float'Max (Value.Fraction_Rule_Thickness, Thickness.Minimum)
         else Long_Float'Max
           (Thickness.Effective, Style_Metric (Level, 0.04, 0.049, 0.049)));
      Rule_Spacing    : constant Long_Float :=
        Style_Metric (Effective_Level, 0.04, 0.049, 0.049) * Scale;
      Half_Rule       : constant Long_Float :=
        (if not Has_Rule then 0.0
         else Rule_Thickness * Scale / 2.0);
      --  Null fraction delimiters retain their reference side bearings.
      Margin          : constant Long_Float :=
        (if No_Rule then 0.0
         elsif Value.Fraction_Continued then 0.12 * Scale
         elsif Value.Left_Delimiter = Math_Syntax.No_Delimiter and then
           Value.Right_Delimiter = Math_Syntax.No_Delimiter then
           0.12 * Scale / Style_Scale (Level)
         else 0.0);
      Axis            : constant Long_Float := Fraction_Axis * Scale;
      Fraction_Width  : constant Long_Float :=
        Maximum (Numerator.Width, Denominator.Width);
      Left_Box        : Box;
      Right_Box       : Box;
      Left_Width      : Long_Float := 0.0;
      Right_Width     : Long_Float := 0.0;
      Numerator_X     : Long_Float;
      Denominator_X   : Long_Float;
   begin
      if Value.Fraction_Continued then
         Numerator.Ascent := Long_Float'Max (Numerator.Ascent, 0.85 * Scale);
         Numerator.Descent :=
           Long_Float'Max (Numerator.Descent, 0.35 * Scale);
      end if;
      if Value.Fraction_Type = Display_Fraction or else
        (Value.Fraction_Type = Default_Fraction and then
         Is_Display (Effective_Level))
      then
         Num_Shift := Style_Metric (Level, 0.677, 0.732, 0.925) * Scale;
         Den_Shift := Style_Metric (Level, 0.686, 0.752, 1.025) * Scale;
         Clearance := 3.0 * Rule_Thickness * Scale;
      else
         Num_Shift := (if not Has_Rule then 0.444
                       else Style_Metric (Level, 0.394, 0.384, 0.387)) * Scale;
         Den_Shift := Style_Metric (Level, 0.345, 0.344, 0.532) * Scale;
         Clearance := Rule_Thickness * Scale;
      end if;
      if not Has_Rule then
         Clearance := (if Is_Display (Effective_Level) or else
           Value.Fraction_Type = Display_Fraction then 7.0 else 3.0) *
             Rule_Spacing;
         declare
            Candidate : constant Long_Float :=
              (Num_Shift - Numerator.Descent) -
                (Denominator.Ascent - Den_Shift);
            Extra : constant Long_Float :=
              Long_Float'Max (0.0, Clearance - Candidate);
         begin
            Num_Shift := Num_Shift + Extra / 2.0;
            Den_Shift := Den_Shift + Extra / 2.0;
         end;
      else
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
      end if;
      if not No_Rule and then Value.Left_Delimiter /= Math_Syntax.No_Delimiter then
         declare
            Delimiter_Level : constant Style_Level :=
              (if Is_Display (Effective_Level) then Display_Level
               elsif Effective_Level in Scriptscript_Level |
                 Scriptscript_Cramped_Level then Script_Level
               else Level);
            Minimum : constant Long_Float :=
              (if Is_Display (Effective_Level) then 2.390
               elsif Effective_Level in Scriptscript_Level |
                 Scriptscript_Cramped_Level then
                 Style_Metric (Delimiter_Level, 1.010, 1.157, 1.420)
               else Style_Metric (Effective_Level, 1.010, 1.157, 1.420));
            Delimiter_Scale : constant Long_Float :=
              Child_Scale (Scale, Level, Delimiter_Level);
         begin
            Left_Box := Compose_Delimiter
              (Value.Left_Delimiter, False,
               Long_Float'Max
                 (Numerator.Ascent + Denominator.Descent,
                  Minimum * Delimiter_Scale),
               Delimiter_Scale, Thickness);
                        Left_Width := Left_Box.Width + 0.1 * Scale;
         end;
      end if;
      if not No_Rule and then not Value.Fraction_Continued and then
        Value.Right_Delimiter /= Math_Syntax.No_Delimiter
      then
         declare
            Delimiter_Level : constant Style_Level :=
              (if Is_Display (Effective_Level) then Display_Level
               elsif Effective_Level in Scriptscript_Level |
                 Scriptscript_Cramped_Level then Script_Level
               else Level);
            Minimum : constant Long_Float :=
              (if Is_Display (Effective_Level) then 2.390
               elsif Effective_Level in Scriptscript_Level |
                 Scriptscript_Cramped_Level then
                 Style_Metric (Delimiter_Level, 1.010, 1.157, 1.420)
               else Style_Metric (Effective_Level, 1.010, 1.157, 1.420));
            Delimiter_Scale : constant Long_Float :=
              Child_Scale (Scale, Level, Delimiter_Level);
         begin
            Right_Box := Compose_Delimiter
              (Value.Right_Delimiter, True,
               Long_Float'Max
                 (Numerator.Ascent + Denominator.Descent,
                  Minimum * Delimiter_Scale),
               Delimiter_Scale, Thickness);
                        Right_Width := Right_Box.Width + 0.1 * Scale;
         end;
      end if;
      if Value.Fraction_Alignment_Mode = Left_Fraction then
         Numerator_X := 0.0;
         Denominator_X := 0.0;
      elsif Value.Fraction_Alignment_Mode = Right_Fraction then
         Numerator_X := Fraction_Width - Numerator.Width;
         Denominator_X := Fraction_Width - Denominator.Width;
      else
         Numerator_X := (Fraction_Width - Numerator.Width) / 2.0;
         Denominator_X := (Fraction_Width - Denominator.Width) / 2.0;
      end if;
      Append_At (Result, Numerator, Left_Width + Margin + Numerator_X, -Num_Shift, Thickness.Work);
      Append_At (Result, Denominator, Left_Width + Margin + Denominator_X, Den_Shift, Thickness.Work);
      if Has_Rule then
         Rule.Kind := Rule_Command;
         Rule.Y := -Axis - Half_Rule;
         Rule.X := Left_Width + Margin;
         Rule.Width := Fraction_Width;
         Rule.Height := Rule_Thickness * Scale;
         Append_Command (Result, Rule, Thickness.Work);
      end if;
      if not No_Rule and then Value.Left_Delimiter /= Math_Syntax.No_Delimiter then
         Append_At (Result, Left_Box, 0.0, 0.0, Thickness.Work);
      end if;
      if not No_Rule and then not Value.Fraction_Continued and then
        Value.Right_Delimiter /= Math_Syntax.No_Delimiter
      then
         Append_At
           (Result, Right_Box,
            Left_Width + Margin + Fraction_Width + Margin, 0.0, Thickness.Work);
      end if;
      Result.Width := Left_Width + Margin + Fraction_Width +
        (if No_Rule or else Value.Fraction_Continued then 0.0
         else Margin + Right_Width);
      Result.Ascent := Maximum
        (Num_Shift + Numerator.Ascent,
         (if not Has_Rule then 0.0
          else Axis + Half_Rule), Left_Box.Ascent);
      Result.Descent := Maximum
        (Maximum
           (Den_Shift + Denominator.Descent,
            (if not Has_Rule then 0.0 else Half_Rule - Axis),
            (if Value.Left_Delimiter = Math_Syntax.No_Delimiter then 0.0
             else Left_Box.Descent)),
         Right_Box.Descent);
      if Effective_Level /= Level then
         --  genfrac rescales the finished vlist after sizing its operands
         --  in the incoming options. Do not apply this ratio twice to them.
         declare
            Ratio : constant Long_Float :=
              Style_Scale (Effective_Level) / Style_Scale (Level);
         begin
            for I in Result.Commands.First_Index ..
              Result.Commands.Last_Index
            loop
               Poll (Thickness);
               declare
                  C : Draw_Command := Result.Commands (I);
               begin
                  C.X := C.X * Ratio;
                  C.Y := C.Y * Ratio;
                  C.Scale := C.Scale * Ratio;
                  C.Width := C.Width * Ratio;
                  C.Height := C.Height * Ratio;
                  if C.Kind = Path_Command then
                     for J in C.Path_Data.First_Index ..
                       C.Path_Data.Last_Index
                     loop
                        declare
                           P : Math_Paths.Segment := C.Path_Data (J);
                        begin
                           P.First.X := P.First.X * Ratio;
                           P.First.Y := P.First.Y * Ratio;
                           P.Second.X := P.Second.X * Ratio;
                           P.Second.Y := P.Second.Y * Ratio;
                           P.Third.X := P.Third.X * Ratio;
                           P.Third.Y := P.Third.Y * Ratio;
                           C.Path_Data.Replace_Element (J, P);
                        end;
                     end loop;
                  end if;
                  Result.Commands.Replace_Element (I, C);
               end;
            end loop;
            Result.Width := Result.Width * Ratio;
            Result.Ascent := Result.Ascent * Ratio;
            Result.Descent := Result.Descent * Ratio;
         end;
      end if;
      Result.Valid   := True;
      return Result;
   end Compose_Fraction;

   function Compose_Radical
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters) return Box
   is
      Result              : Box;
      Radicand            : Box := Compose
        (Item, Value.First, Cramped (Level), Scale, Depth + 1, Thickness);
      Index_Box           : Box;
      Has_Index           : constant Boolean := Value.Second /= No_Node;
      Theta               : constant Long_Float := Long_Float'Max
        (Thickness.Effective, Style_Metric (Level, 0.04, 0.049, 0.049)) * Scale;
      Base_Scale          : constant Long_Float := Scale / Style_Scale (Level);
      Image_Scale         : Long_Float := Scale;
      Rule_Width          : Long_Float := Thickness.Effective * Scale;
      Extra_Vinculum      : constant Long_Float :=
        Long_Float'Max (0.0, Thickness.Effective - 0.04);
      Phi                 : constant Long_Float :=
        (if Is_Display (Level)
         then X_Height * Scale else Theta);
      Body_Height         : constant Long_Float :=
        Radicand.Ascent + Radicand.Descent;
      Minimum_Delimiter   : constant Long_Float :=
        Body_Height + Theta + Phi / 4.0 + Theta;
      Delimiter_Maximum   : constant array (1 .. 4) of Long_Float :=
        (1.2, 1.8, 2.4, 3.0);
      Chosen              : Font_Kind := Main_Regular;
      Tall                : Boolean := False;
      Image_Height        : Long_Float := Scale;
      Advance_Width       : Long_Float := 0.833 * Scale;
      Line_Clearance      : Long_Float := Theta + Phi / 4.0;
      Image_Shift         : Long_Float;
      Image_Depth         : Long_Float;
      Index_Scale         : constant Long_Float := Scale * 0.5;
      Index_X             : Long_Float := 0.0;
      Index_Y             : Long_Float := 0.0;
   begin
      if Has_Index then
         Index_Box :=
           Compose
             (Item, Value.Second, Smaller (Smaller (Level)), Index_Scale,
              Depth + 1, Thickness);
         Index_X := 0.05 * Scale;
      end if;

      --  Surd candidates use base-sized fonts, not the argument's script
      --  scaling. This mirrors delimiter.sqrtImage's independent sizing.
      if Minimum_Delimiter / Scale < 1.0 then
         Image_Height := (1.0 + Extra_Vinculum) * Scale;
      elsif Minimum_Delimiter / Scale < 1.4 and then
        Minimum_Delimiter < Base_Scale
      then
         Image_Height := (1.0 + Extra_Vinculum) * Scale / 0.7;
         Image_Scale := Scale / 0.7;
         Rule_Width := Thickness.Effective * 0.7 * Scale;
      else
         Chosen := Size_1;
         for Index in Delimiter_Maximum'Range loop
            if Minimum_Delimiter < Delimiter_Maximum (Index) * Base_Scale then
               Chosen := Font_Kind'Val (Font_Kind'Pos (Size_1) + Index - 1);
               Image_Height :=
                 (Delimiter_Maximum (Index) + Extra_Vinculum) * Base_Scale;
               Image_Scale := Base_Scale;
               Advance_Width := Base_Scale;
               Rule_Width := Thickness.Effective * Style_Scale (Level) * Scale;
               exit;
            elsif Index = Delimiter_Maximum'Last then
               Tall := True;
               Image_Height := Minimum_Delimiter + Extra_Vinculum * Scale;
               Advance_Width := 1.056 * Scale;
            end if;
         end loop;
      end if;
      if Chosen = Main_Regular then
         Advance_Width := 0.833 * Image_Scale;
      end if;
      Image_Depth := Image_Height - Rule_Width;
      if Image_Depth > Body_Height + Line_Clearance then
         Line_Clearance :=
           (Line_Clearance + Image_Depth - Body_Height) / 2.0;
      end if;
      Image_Shift :=
        Image_Height - Radicand.Ascent - Line_Clearance - Rule_Width;

      declare
         Path_Size : constant Natural :=
           (if Chosen = Main_Regular then 0
            else Font_Kind'Pos (Chosen) - Font_Kind'Pos (Size_1) + 1);
         Raw_Path : constant Math_Paths.Path :=
           (if Tall then
              Math_Stretchy.Tall_Radical
                (Image_Height / Scale, Extra_Vinculum, Advance_Width / Scale)
            else
              Math_Radical_Paths.Build
                (Path_Size, Extra_Vinculum, Advance_Width + Radicand.Width));
         Scaled : constant Math_Paths.Path := Math_Paths.Transform
           (Raw_Path, 0.001 * Image_Scale, 0.0, 0.0,
            0.001 * Image_Scale, 0.0, 0.0);
         Command : Draw_Command;
      begin
         if not Math_Paths.Is_Valid (Scaled) then
            Reject ("invalid radical SVG path: " & Math_Paths.Error (Raw_Path));
         end if;
         Command.Kind := Path_Command;
         Command.Y := -Radicand.Ascent - Line_Clearance -
           80.0 * 0.001 * Image_Scale;
         Command.Width := Advance_Width + Radicand.Width;
         Command.Height := Image_Height + 0.08 * Image_Scale;
         Command.Has_Clip := True;
         Command.Clip_X := 0.0;
         Command.Clip_Y := 0.0;
         Command.Clip_W := Command.Width;
         Command.Clip_H := Command.Height;
         for Part in 1 .. Math_Paths.Count (Scaled) loop
            Poll (Thickness);
            Command.Path_Data.Append (Math_Paths.Element (Scaled, Part));
         end loop;
         Append_Command (Result, Command, Thickness.Work);
      end;

      Append_At (Result, Radicand, Advance_Width, 0.0, Thickness.Work);
      Result.Width := Advance_Width + Radicand.Width;
      Result.Ascent := Image_Height + Rule_Width - Image_Shift;
      Result.Descent := Image_Shift;

      if Has_Index then
         Index_Y := -0.6 * (Result.Ascent - Result.Descent);
         Append_At (Result, Index_Box, Index_X, Index_Y, Thickness.Work);
         Result.Width := Maximum (Result.Width, Index_X + Index_Box.Width);
         Result.Ascent :=
           Maximum (Result.Ascent, Index_Box.Ascent - Index_Y, 0.0);
         Result.Descent :=
           Maximum (Result.Descent, Index_Box.Descent + Index_Y, 0.0);
      end if;
      Result.Valid := True;
      return Result;
   end Compose_Radical;

   function Compose_Brace
     (Item : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural;
      Thickness : Rule_Parameters) return Box is
      pragma Unreferenced (Level);
      Result : Box;
      Kind : constant Math_Stretchy.Brace_Kind :=
        (if Value.Code_Point = Over_Brace_Code_Point
         then Math_Stretchy.Over_Brace else Math_Stretchy.Under_Brace);
      Body_Box : constant Box := Compose
        (Item, Value.First, Display_Level, Scale, Depth + 1, Thickness);
      Brace_Width : constant Long_Float :=
        Long_Float'Max (Body_Box.Width, 1.6 * Scale);
      Brace_Height : constant Long_Float := 0.548 * Scale;
      Brace_Y : constant Long_Float :=
        (if Kind = Math_Stretchy.Over_Brace
         then -(Body_Box.Ascent + 0.1 * Scale + Brace_Height)
         else Body_Box.Descent + 0.1 * Scale);
      procedure Add_Part
        (Part : Math_Stretchy.Brace_Part; Clip_X, Clip_W : Long_Float) is
         Path : constant Math_Paths.Path :=
           Math_Stretchy.Brace_Part_For (Kind, Part);
         Bounds : constant Math_Paths.Bounds := Math_Paths.Extent (Path);
         Offset_X : constant Long_Float :=
           (case Part is
              when Math_Stretchy.Left_Part => 0.0,
              when Math_Stretchy.Middle_Part => Brace_Width / 2.0 -
                200.0 * Scale,
              when Math_Stretchy.Right_Part => Brace_Width - 400.0 * Scale);
         Geometry : Draw_Command;
      begin
         if not Math_Paths.Is_Valid (Path) or else not Bounds.Valid or else
           Bounds.Max_X <= Bounds.Min_X or else Bounds.Max_Y <= Bounds.Min_Y
         then
            Reject ("invalid trusted stretchy brace path");
         end if;
         Geometry.Kind := Path_Command;
         Geometry.X := Offset_X;
         Geometry.Y := Brace_Y;
         Geometry.Width := Brace_Width;
         Geometry.Height := Brace_Height;
         Geometry.Has_Clip := True;
         Geometry.Clip_X := Clip_X - Offset_X;
         Geometry.Clip_Y := 0.0;
         Geometry.Clip_W := Clip_W;
         Geometry.Clip_H := Brace_Height;
         declare
            Scaled_Path : constant Math_Paths.Path :=
              Math_Paths.Transform
                (Path, 0.001 * Scale, 0.0, 0.0, 0.001 * Scale,
                 0.0, 0.0);
         begin
            for Segment in 1 .. Math_Paths.Count (Scaled_Path) loop
               Poll (Thickness);
               Geometry.Path_Data.Append
                 (Math_Paths.Element (Scaled_Path, Segment));
            end loop;
         end;
         Append_Command (Result, Geometry, Thickness.Work);
      end Add_Part;
   begin
      if Value.First = No_Node then
         Reject ("brace accent has no body");
      end if;
      Append_At (Result, Body_Box, 0.0, 0.0, Thickness.Work);
      Add_Part (Math_Stretchy.Left_Part, 0.0, 0.251 * Brace_Width);
      Add_Part
        (Math_Stretchy.Middle_Part, 0.25 * Brace_Width,
         0.5 * Brace_Width);
      Add_Part
        (Math_Stretchy.Right_Part, 0.749 * Brace_Width,
         0.251 * Brace_Width);
      Result.Width := Brace_Width;
      if Kind = Math_Stretchy.Over_Brace then
         Result.Ascent := Body_Box.Ascent + 0.1 * Scale + Brace_Height;
         Result.Descent := Body_Box.Descent;
      else
         Result.Ascent := Body_Box.Ascent;
         Result.Descent := Body_Box.Descent + 0.1 * Scale + Brace_Height;
      end if;
      Result.Valid := True;
      return Result;
   end Compose_Brace;

   function Compose_Stretchy
     (Item : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural;
      Thickness : Rule_Parameters) return Box
   is
      Name : constant String := To_String (Value.Stretchy_Name);
      Result : Box;
      Labelled : constant Boolean := Value.Code_Point = 1;
      Under : constant Boolean :=
        Value.Annotation_Type = Under_Annotation;
      Base : Box;
      Upper : Box;
      Lower : Box;
      View_Height : Long_Float;
      Min_Width : Long_Float;
      Width : Long_Float;
      Arrow_Height : Long_Float;
      Pad : constant Long_Float := 0.3 * Scale;
      CD_Left_Pad : constant Long_Float := 0.27778 * Scale;
      CD_Right_Pad : constant Long_Float := 0.55556 * Scale;
      Is_CD : constant Boolean := Name in
        "cdrightarrow" | "cdleftarrow" | "cdlongequal" |
        "\\cdrightarrow" | "\\cdleftarrow" | "\\cdlongequal" |
        "\cdrightarrow" | "\cdleftarrow" | "\cdlongequal";
      Axis : constant Long_Float := Fraction_Axis * Scale;
      Path_Width : constant Long_Float := 400.0 * Scale;
      function Make_Part
        (Part : Positive; Part_Width, Left : Long_Float) return Draw_Command
      is
         Path : constant Math_Paths.Path := Math_Stretchy.PartPath
           (Name, Part);
         Bounds : constant Math_Paths.Bounds := Math_Paths.Extent (Path);
         Align : constant Math_Stretchy.Part_Align :=
           Math_Stretchy.PartAlignFor (Name, Part);
         Offset : constant Long_Float :=
           (case Align is
              when Math_Stretchy.Min_Align => 0.0,
              when Math_Stretchy.Mid_Align => (Part_Width - Path_Width) / 2.0,
              when Math_Stretchy.Max_Align => Part_Width - Path_Width);
         Command : Draw_Command;
      begin
         if not Math_Paths.Is_Valid (Path) or else not Bounds.Valid or else
           Bounds.Max_X <= Bounds.Min_X or else Math_Paths.Count (Path) = 0
         then
            Reject ("invalid or empty trusted stretchy path: " & Name);
         end if;
         Command.Kind := Path_Command;
         Command.X := Left + Offset;
         Command.Width := Part_Width;
         Command.Height := Arrow_Height;
         Command.Has_Clip := True;
         Command.Clip_X := -Offset;
         Command.Clip_W := Part_Width;
         Command.Clip_H := Arrow_Height;
         Command.Y :=
           (if Labelled then -Axis - Arrow_Height / 2.0
            elsif Under then Base.Descent
            else -(Base.Ascent + Arrow_Height));
         declare
            Scaled : constant Math_Paths.Path := Math_Paths.Transform
              (Path, 0.001 * Scale, 0.0, 0.0, 0.001 * Scale, 0.0, 0.0);
         begin
            for I in 1 .. Math_Paths.Count (Scaled) loop
               Poll (Thickness);
               Command.Path_Data.Append (Math_Paths.Element (Scaled, I));
            end loop;
         end;
         return Command;
      end Make_Part;
   begin
      if Name'Length = 0 or else Math_Stretchy.PartCount (Name) = 0 or else
        Value.Code_Point not in 0 | 1 or else
        (Labelled and then Value.First = No_Node) or else
        (not Labelled and then Value.Second /= No_Node)
      then
         Reject ("invalid stretchy node metadata");
      end if;
      View_Height := Math_Stretchy.ViewBoxHeightFor (Name);
      Min_Width := Math_Stretchy.MinWidthFor (Name) * Scale;
      if not View_Height'Valid or else not Min_Width'Valid or else
        View_Height <= 0.0 or else View_Height > Max_Geometry or else
        Min_Width <= 0.0 or else Min_Width > Max_Geometry
      then
         Reject ("invalid stretchy reference dimensions: " & Name);
      end if;
      Arrow_Height := View_Height * Scale / 1_000.0;
      if Labelled then
         Upper := Compose
           (Item, Value.First, Smaller (Level),
            Child_Scale (Scale, Level, Smaller (Level)), Depth + 1,
            Thickness);
         if Value.Second /= No_Node then
            Lower := Compose
              (Item, Value.Second, Sub_Style (Level),
               Child_Scale (Scale, Level, Sub_Style (Level)), Depth + 1,
               Thickness);
         end if;
         Width := Long_Float'Max
           (Min_Width, Upper.Width +
             (if Is_CD then CD_Left_Pad + CD_Right_Pad else 2.0 * Pad));
         if Value.Second /= No_Node then
            Width := Long_Float'Max
              (Width, Lower.Width +
                (if Is_CD then CD_Left_Pad + CD_Right_Pad else 2.0 * Pad));
         end if;
         for Part in 1 .. Math_Stretchy.PartCount (Name) loop
            declare
               Count : constant Natural := Math_Stretchy.PartCount (Name);
               Part_Width : constant Long_Float :=
                 (if Count = 1 then Width
                  elsif Count = 3 then
                    (if Part = 2 then Width / 2.0
                     else 0.251 * Width)
                  else 0.502 * Width);
               Left : constant Long_Float :=
                 (if Count = 1 then 0.0
                  elsif Count = 3 then
                    (case Part is
                       when 1 => 0.0,
                       when 2 => Width * 0.25,
                       when others => Width * 0.749)
                  else (if Part = 1 then 0.0 else Width * 0.498));
            begin
               Append_Command (Result, Make_Part (Part, Part_Width, Left), Thickness.Work);
            end;
         end loop;
         declare
            Upper_Shift : constant Long_Float := Axis + Arrow_Height / 2.0 +
              0.111 * Scale +
              (if Is_CD and then Upper.Descent <= 0.25 * Scale
               then 0.0 else Upper.Descent);
            Lower_Shift : constant Long_Float := Arrow_Height / 2.0 - Axis +
              0.111 * Scale + Lower.Ascent;
         begin
            Append_At
              (Result, Upper,
               (Width - Upper.Width) / 2.0 +
                 (if Is_CD then (CD_Left_Pad - CD_Right_Pad) / 2.0
                  else 0.0),
               -Upper_Shift, Thickness.Work);
            Result.Ascent := Long_Float'Max
              (Axis + Arrow_Height / 2.0, Upper_Shift + Upper.Ascent);
            Result.Descent := Long_Float'Max
              (Arrow_Height / 2.0 - Axis, Upper.Descent - Upper_Shift);
            if Value.Second /= No_Node then
               Append_At
                 (Result, Lower,
                  (Width - Lower.Width) / 2.0 +
                    (if Is_CD then (CD_Left_Pad - CD_Right_Pad) / 2.0
                     else 0.0),
                  Lower_Shift, Thickness.Work);
               Result.Descent := Long_Float'Max
                 (Result.Descent, Lower_Shift + Lower.Descent);
            end if;
         end;
      else
         if Value.First = No_Node then
            Reject ("stretchy accent has no body");
         end if;
         Base := Compose
           (Item, Value.First, (if Under then Level else Cramped (Level)),
            Scale, Depth + 1, Thickness);
         Width := Long_Float'Max (Min_Width, Base.Width);
         if Math_Stretchy.PartCount (Name) = 1 then
            Append_Command (Result, Make_Part (1, Width, 0.0), Thickness.Work);
         else
            for Part in 1 .. Math_Stretchy.PartCount (Name) loop
               declare
                  Count : constant Natural := Math_Stretchy.PartCount (Name);
                  Part_Width : constant Long_Float :=
                    (if Count = 1 then Width
                     elsif Count = 3 then
                       (if Part = 2 then Width / 2.0
                        else 0.251 * Width)
                     else 0.502 * Width);
                  Left : constant Long_Float :=
                    (if Count = 1 then 0.0
                     elsif Count = 3 then
                       (case Part is
                          when 1 => 0.0,
                          when 2 => Width * 0.25,
                          when others => Width * 0.749)
                     else (if Part = 1 then 0.0 else Width * 0.498));
               begin
                  Append_Command (Result, Make_Part (Part, Part_Width, Left), Thickness.Work);
               end;
            end loop;
         end if;
         Append_At
           (Result, Base, (Width - Base.Width) / 2.0, 0.0, Thickness.Work);
         Result.Width := Width;
         if Under then
            Result.Ascent := Base.Ascent;
            Result.Descent := Base.Descent + Arrow_Height +
              (if Name = "utilde" then 0.12 * Scale else 0.0);
         else
            Result.Ascent := Base.Ascent + Arrow_Height;
            Result.Descent := Base.Descent;
         end if;
      end if;
      Result.Width := Width;
      Result.Valid := True;
      return Result;
   end Compose_Stretchy;

   function Compose_CD_Arrow
     (Item : Math_Syntax.Document; Value : Math_Syntax.Node;
      Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters)
      return Box
   is
      Result : Box;
      Left_Label, Right_Label : Box;
      Top : constant Natural :=
        (if Value.Code_Point = 16#2191# then 16#2191# else 16#23D0#);
      Bottom : constant Natural :=
        (if Value.Code_Point = 16#2191# then 16#23D0# else 16#2193#);
      Top_M : constant Math_Metrics.Glyph_Metric :=
        Scaled_Metric (Size_1, Top, Scale, Thickness);
      Bottom_M : constant Math_Metrics.Glyph_Metric :=
        Scaled_Metric (Size_1, Bottom, Scale, Thickness);
      Repeat_M : constant Math_Metrics.Glyph_Metric :=
        Scaled_Metric (Size_1, 16#23D0#, Scale, Thickness);
      Top_H : constant Long_Float := Top_M.Ascent + Top_M.Descent;
      Bottom_H : constant Long_Float := Bottom_M.Ascent + Bottom_M.Descent;
      Repeat_H : constant Long_Float := Repeat_M.Ascent + Repeat_M.Descent;
      Count : Natural;
      Total, Depth_Value, Cursor : Long_Float;
      Width : constant Long_Float := Top_M.Width;
      procedure Piece (Point : Natural; M : Math_Metrics.Glyph_Metric;
                       Top_Y : Long_Float) is
      begin
         Append_Command (Result,
           (Kind => Glyph_Command, Font => Size_1, Code_Point => Point,
            X => 0.0, Y => Top_Y + M.Ascent, Scale => Scale,
            Width => M.Width, Height => M.Ascent + M.Descent,
            others => <>), Thickness.Work);
      end Piece;
   begin
      if Value.Code_Point not in 16#2191# | 16#2193# or else
        Value.First = No_Node or else Value.Second = No_Node or else
        Repeat_H <= 0.0
      then
         Reject ("invalid CD vertical arrow metadata");
      end if;
      Count := Natural'Max (0, Integer (Long_Float'Ceiling
        ((1.8 * Scale - Top_H - Bottom_H) / Repeat_H)));
      Total := Top_H + Bottom_H + Long_Float (Count) * Repeat_H;
      Depth_Value := Total / 2.0 - Fraction_Axis * Scale;
      Cursor := Depth_Value - Bottom_H;
      Piece (Bottom, Bottom_M, Cursor);
      Cursor := Depth_Value - Total + Top_H - 0.008 * Scale;
      Append_Command (Result,
        (Kind => Rule_Command,
         X => (Width - 0.333 * Scale) / 2.0 + 0.145 * Scale,
         Y => Cursor,
         Width => 43.0 / 1_000.0 * Scale,
         Height => Total - Top_H - Bottom_H + 0.016 * Scale,
         others => <>), Thickness.Work);
      Cursor := Depth_Value - Total;
      Piece (Top, Top_M, Cursor);
      Left_Label := Compose
        (Item, Value.First, Script_Level, Scale * 0.7,
         Depth + 1, Thickness);
      Right_Label := Compose
        (Item, Value.Second, Script_Level, Scale * 0.7,
         Depth + 1, Thickness);
      Append_At (Result, Left_Label,
        Width / 2.0 - 0.3 * Scale - Left_Label.Width,
        -0.8 * Scale + Left_Label.Descent, Thickness.Work);
      Append_At (Result, Right_Label, Width / 2.0 + 0.3 * Scale,
        -0.8 * Scale + Right_Label.Descent, Thickness.Work);
      Result.Width := Width;
      Result.Ascent := Total - Depth_Value;
      Result.Descent := Depth_Value;
      Result.Valid := True;
      return Result;
   end Compose_CD_Arrow;

   function Compose_Scripts
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters) return Box
   is
      Result         : Box;
      Base           : Box :=
        Compose (Item, Value.First, Level, Scale, Depth + 1, Thickness);
      Shift_Base     : Box := Base;
      Sup            : Box;
      Sub            : Box;
      Has_Sup        : constant Boolean := Value.Second /= No_Node;
      Has_Sub        : constant Boolean := Value.Third /= No_Node;
      Character_Base : Boolean := False;
      Script_Level   : constant Style_Level := Smaller (Level);
      Script_Scale   : constant Long_Float :=
        Child_Scale (Scale, Level, Script_Level);
      Sup_Shift      : Long_Float := 0.0;
      Sub_Shift      : Long_Float := 0.0;
      Min_Sup        : Long_Float;
      Min_Sub        : Long_Float;
      Gap            : constant Long_Float := 4.0 * Thickness.Effective * Scale;
      Psi            : Long_Float;
      Sup_X          : Long_Float;
      Sub_X          : Long_Float;
      Base_X         : Long_Float := 0.0;
      Group_Width    : Long_Float;
      Limit_Mode     : Boolean :=
        Value.Code_Point = 1 or else
        (Value.Code_Point /= 2 and then
           Value.Script_Type = Limit_Scripts and then Is_Display (Level));
   begin
      declare
         Base_Node : constant Math_Syntax.Node :=
           Math_Syntax.Element (Item, Positive (Value.First));
      begin
         Character_Base := Is_Character_Box (Item, Value.First);
         if Base_Node.Kind = Accent_Node and then
           Base_Node.Code_Point in Over_Brace_Code_Point |
             Under_Brace_Code_Point
         then
            Character_Base := False;
            Limit_Mode :=
              (Base_Node.Code_Point = Over_Brace_Code_Point and Has_Sup) or
              (Base_Node.Code_Point = Under_Brace_Code_Point and Has_Sub);
            Shift_Base :=
              Compose (Item, Base_Node.First, Level, Scale, Depth + 1,
                       Thickness);
         elsif Base_Node.Kind = Accent_Node and then
           Is_Character_Box (Item, Base_Node.First)
         then
            Shift_Base :=
              Compose (Item, Base_Node.First, Level, Scale, Depth + 1, Thickness);
         end if;
         if Value.Code_Point = 0 and then Is_Display (Level) and then
           ((Base_Node.Kind = Row_Node and then
               Base_Node.Class = Operator_Atom and then
               Base_Node.Code_Point in Character'Pos ('l') |
                 Character'Pos ('m')) or else
             (Base_Node.Kind = Glyph_Node and then
               Base_Node.Class = Operator_Atom and then
               Base_Node.Code_Point in 16#2211# | 16#220F#))
         then
            Limit_Mode := True;
         end if;
      end;
      if not Has_Sup and not Has_Sub then
         Reject ("scripts node has no scripts");
      end if;
      if Has_Sup then
         Sup := Compose
           (Item, Value.Second, Sup_Style (Level), Script_Scale,
            Depth + 1, Thickness);
         if not Character_Base then
            Sup_Shift := Maximum
              (Shift_Base.Ascent -
                 Style_Metric (Sup_Style (Level), 0.386, 0.353, 0.494) *
                   Script_Scale,
               0.0);
         end if;
      end if;
      if Has_Sub then
         Sub := Compose
           (Item, Value.Third, Sub_Style (Level), Script_Scale,
            Depth + 1, Thickness);
         if not Character_Base then
            Sub_Shift := Shift_Base.Descent +
              Style_Metric (Sub_Style (Level), 0.05, 0.071, 0.1) * Script_Scale;
         end if;
      end if;
      if Level = Display_Level then
         Min_Sup := Style_Metric (Level, 0.413, 0.503, 0.504) * Scale;
      elsif Is_Cramped (Level) then
         Min_Sup := Style_Metric (Level, 0.289, 0.286, 0.294) * Scale;
      else
         Min_Sup := Style_Metric (Level, 0.363, 0.431, 0.404) * Scale;
      end if;
      if Has_Sup then
         Sup_Shift := Maximum (Sup_Shift, Min_Sup);
         Sup_Shift := Maximum
           (Sup_Shift, Sup.Descent +
              0.25 * X_Height * Scale);
         if Limit_Mode then
            Sup_Shift := Base.Ascent +
              (if Value.Code_Point = 1 then 0.3 else 0.2) * Scale +
              Sup.Descent;
         end if;
      end if;
      if Has_Sub then
         if Has_Sup then
            Min_Sub := Style_Metric (Level, 0.247, 0.286, 0.4) * Scale;
         else
            Min_Sub := Style_Metric (Level, 0.15, 0.143, 0.2) * Scale;
         end if;
         Sub_Shift := Maximum
           (Sub_Shift, Min_Sub, Sub.Ascent - 0.8 * X_Height * Scale);
         if Limit_Mode then
            Sub_Shift := Base.Descent +
              (if Value.Code_Point = 1 then 0.3 else 0.2) * Scale +
              Sub.Ascent;
         end if;
      end if;
      if Has_Sup and Has_Sub then
         if (Sup_Shift - Sup.Descent) - (Sub.Ascent - Sub_Shift) < Gap then
            Sub_Shift := Gap - (Sup_Shift - Sup.Descent) + Sub.Ascent;
            Psi := 0.8 * X_Height * Scale -
              (Sup_Shift - Sup.Descent);
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
      Append_At (Result, Base, Base_X, 0.0, Thickness.Work);
      if Has_Sup then
         Append_At (Result, Sup, Sup_X, -Sup_Shift, Thickness.Work);
      end if;
      if Has_Sub then
         Append_At (Result, Sub, Sub_X, Sub_Shift, Thickness.Work);
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
      if not Limit_Mode then
         --  TeX scriptspace is a font-size-independent 0.5 pt.
         Result.Width := Result.Width + 0.05;
      end if;
      Result.Italic := Base.Italic;
      Result.Valid  := True;
      return Result;
   end Compose_Scripts;

   function Compose_Array
     (Item  : Math_Syntax.Document; Value : Math_Syntax.Node;
      Level : Style_Level; Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters) return Box
   is
      use Math_Syntax;
      Max_Rows    : constant Positive :=
        Math_Syntax.Max_Array_Rows +
          (if Value.Array_Type = CD_Array then 1 else 0);
      Max_Columns : constant Positive := Math_Syntax.Max_Array_Columns;
      type Box_Grid is
        array
          (Positive range 1 .. Max_Rows,
           Positive range 1 .. Max_Columns) of Box;
      type Metric_Array is array (Positive range 1 .. Max_Rows) of Long_Float;
      type Row_Flags is array (1 .. Max_Rows) of Boolean;
      Visible_Rows : Row_Flags := (others => False);
      type Width_Array is
        array (Positive range 1 .. Max_Columns) of Long_Float;
      type Alignment_Array is
        array (Positive range 1 .. Max_Columns) of Column_Alignment;
      type Rule_Offset_Array is
        array (Positive range 1 .. Max_Columns) of Long_Float;
      Alignments        : Alignment_Array := (others => Center_Column);
      Rule_Offsets      : Rule_Offset_Array := (others => 0.0);
      Cells             : Box_Grid;
      Row_Ascents       : Metric_Array        := (others => 0.0);
      Row_Descents      : Metric_Array        := (others => 0.0);
      Column_Widths     : Width_Array         := (others => 0.0);
      Row_Id            : Node_Id             := Value.First;
      Cell_Id           : Node_Id;
      Column            : Natural;
      Rows              : Natural             := 0;
      Visible_Count     : Natural             := 0;
      Columns           : Natural             := 0;
      Link_Count        : Natural             := 0;
      Cell_Count        : Natural;
      Row_Value         : Math_Syntax.Node;
      Cell_Value        : Math_Syntax.Node;
      Result            : Box;
      X_Offset          : Long_Float          := 0.0;
      Y_Offset          : Long_Float          := 0.0;
      First_Boundary_Y  : Long_Float          := 0.0;
      Cell_Level : constant Style_Level :=
        (case Value.Math_Style is
           when Display_Style => Display_Level,
           when Text_Style => Text_Level,
           when Script_Style => Script_Level,
           when Script_Script_Style => Scriptscript_Level,
           when Natural_Style =>
             (if Value.Array_Type = Aligned_Array then Level
              else Text_Level));
      Cell_Scale : constant Long_Float :=
        Child_Scale (Scale, Level, Cell_Level);
      Stretch : constant Long_Float :=
        (if Value.Amount > 0.0 then Value.Amount else 1.0);
      Column_Gap        : constant Long_Float :=
        (if Value.Math_Style = Script_Style then 5.0 / 18.0
         elsif Value.Array_Type = Aligned_Array then 0.2
         elsif Value.Array_Type = Cases_Array then 1.0
         else 0.5) * Scale;
      Row_Gap           : constant Long_Float :=
        (if Value.Array_Type = CD_Array then 0.0
         elsif Value.Array_Type = Aligned_Array then
           (if Value.Row_Spacing > 0.0 then Value.Row_Spacing else 0.16)
         elsif Value.Row_Spacing > 0.0 and then
           Value.Array_Type not in Matrix_Array | Cases_Array then
           Value.Row_Spacing
         else 0.0) * Scale;
      Total_Height      : Long_Float          := 0.0;
      Total_Width       : Long_Float          := 0.0;
      Rule_Count        : Natural := 0;
      Horizontal_Rule_Count : Natural := 0;
      Row_Center        : Long_Float;
      Column_Start      : Long_Float;
      function Rules_At (Boundary : Natural) return Natural is
         Count : Natural := 0;
      begin
         if not Value.Array_Rules.Is_Empty then
            for Rule of Value.Array_Rules loop
               if Rule.Boundary = Boundary then
                  Count := Count + 1;
               end if;
            end loop;
         end if;
         return Count;
      end Rules_At;
      Delimiter_Gap : constant Long_Float := 0.1 * Scale;
      Need_Height : Long_Float;
      Left_Delimiter : Box;
      Right_Delimiter : Box;
      Left_Width : Long_Float := 0.0;
      Right_Width : Long_Float := 0.0;
      procedure Measure_Delimiter (Kind : Delimiter_Kind; Right_Side : Boolean) is
         D : Box;
      begin
         if Kind = Math_Syntax.No_Delimiter then return; end if;
         D := Compose_Delimiter (Kind, Right_Side, Need_Height, Scale, Thickness);
         if Right_Side then
            Right_Delimiter := D; Right_Width := D.Width + Delimiter_Gap;
            if Kind = Math_Syntax.Double_Bar_Delimiter then Right_Width := Right_Width + D.Width + Delimiter_Gap; end if;
         else
            Left_Delimiter := D; Left_Width := D.Width + Delimiter_Gap;
            if Kind = Math_Syntax.Double_Bar_Delimiter then Left_Width := Left_Width + D.Width + Delimiter_Gap; end if;
         end if;
      end Measure_Delimiter;
      procedure Add_Delimiter (D : Box; X : Long_Float) is
      begin Append_At (Result, D, X, 0.0, Thickness.Work); end Add_Delimiter;
   begin
      Row_Id := Value.First;
      while Row_Id /= No_Node loop
         Poll (Thickness);
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
         Visible_Rows (Rows) := Row_Value.First /= No_Node;
         if Visible_Rows (Rows) then
            Visible_Count := Visible_Count + 1;
            if Visible_Count > Math_Syntax.Max_Array_Rows then
               Reject ("array row limit exceeded");
            end if;
         end if;
         Cell_Id    := Row_Value.First;
         Column     := 0;
         Cell_Count := 0;
         while Cell_Id /= No_Node loop
            Poll (Thickness);
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
            if Cell_Value.Kind /= Math_Model.Row_Node or else
              (Cell_Value.First = No_Node and then
               Value.Array_Type /= CD_Array)
            then
               Reject ("invalid array cell expression");
            end if;
            Cells (Rows, Column)   :=
              Compose
                (Item, Cell_Id,
                 Cell_Level, Cell_Scale, Depth + 1, Thickness);
            Column_Widths (Column) :=
              Maximum
                (Column_Widths (Column),
                 Cells (Rows, Column).Width + Cells (Rows, Column).Italic);
            Row_Ascents (Rows)     :=
              Maximum (Row_Ascents (Rows), Cells (Rows, Column).Ascent);
            Row_Descents (Rows)    :=
              Maximum (Row_Descents (Rows), Cells (Rows, Column).Descent);
            Cell_Id                := Cell_Value.Next;
         end loop;
         if Column = 0 and then Value.Array_Type /= CD_Array then
            Reject ("empty array row");
         end if;
         Columns := Natural'Max (Columns, Column);
         Row_Id  := Row_Value.Next;
      end loop;
      if not Value.Array_Rules.Is_Empty then
         if Value.Array_Rules.Length > Math_Syntax.Max_Nodes then
            Reject ("array rule metadata limit exceeded");
         end if;
         for Rule of Value.Array_Rules loop
            if Rule.Boundary > Rows or else
              Rule.Kind not in Solid_Array_Rule | Dashed_Array_Rule
            then
               Reject ("invalid array rule metadata");
            end if;
         end loop;
      end if;
      if Rows = 0 or Columns = 0 then
         if Value.Array_Type = CD_Array and then Columns = 0 then
            Result.Width := 0.0;
            Result.Ascent := 0.0;
            Result.Descent := 0.0;
            Result.Valid := True;
            return Result;
         end if;
         Reject ("empty array");
      end if;
      if Length (Value.Column_Spec) > 0 and then
        Value.Array_Type /= Aligned_Array
      then
         declare
            Column : Natural := 0;
            Rules_Before : Natural := 0;
         begin
            for C of To_String (Value.Column_Spec) loop
               if C in 'l' | 'c' | 'r' then
                  Column := Column + 1;
                  if Column > Max_Columns then
                     Reject ("array column specification limit exceeded");
                  end if;
                  Rule_Offsets (Column) :=
                    Long_Float (Rules_Before) * 0.24 * Scale;
                  Alignments (Column) :=
                    (if C = 'l' then Left_Column else
                     (if C = 'r' then Right_Column else Center_Column));
               elsif C = '|' then
                  Rule_Count := Rule_Count + 1;
                  Rules_Before := Rules_Before + 1;
               end if;
            end loop;
            if Column /= Columns then
               Reject ("array column specification does not match cells");
            end if;
         end;
      end if;
      if Value.Array_Type /= Aligned_Array then
         for I in 1 .. Rows loop
            if Value.Array_Type = CD_Array then
               --  KaTeX 3ex strut plus 3pt row-depth addition at 10pt.
               Row_Ascents (I) := Long_Float'Max
                 (Row_Ascents (I), 0.9051 * Scale * Stretch);
               Row_Descents (I) := Long_Float'Max
                 (Row_Descents (I), 0.3879 * Scale * Stretch) +
                   0.3 * Scale;
            else
               --  KaTeX array.js uses a 12 pt baseline strut.
               Row_Ascents (I) := Long_Float'Max
                 (Row_Ascents (I), 0.84 * Scale * Stretch);
               Row_Descents (I) := Long_Float'Max
                 (Row_Descents (I), 0.36 * Scale * Stretch);
            end if;
         end loop;
      end if;
      for I in 1 .. Rows loop
         Total_Height := Total_Height + Row_Ascents (I) + Row_Descents (I);
         Horizontal_Rule_Count := Horizontal_Rule_Count + Rules_At (I - 1);
         if Rules_At (I - 1) > 1 then
            Total_Height := Total_Height +
              0.25 * Scale * Long_Float (Rules_At (I - 1) - 1);
         end if;
      end loop;
      Horizontal_Rule_Count := Horizontal_Rule_Count + Rules_At (Rows);
      if Rules_At (Rows) > 1 then
         Total_Height := Total_Height +
           0.25 * Scale * Long_Float (Rules_At (Rows) - 1);
      end if;
      if Rows > 1 then
         Total_Height := Total_Height + Row_Gap * Long_Float (Rows - 1);
      end if;
      for I in 1 .. Columns loop

         Total_Width := Total_Width + Column_Widths (I);
      end loop;
      if Columns > 1 then
         Total_Width := Total_Width +
           Column_Gap * Long_Float (Columns - 1);
      end if;
      Total_Width := Total_Width + Long_Float (Rule_Count) *
        (Thickness.Effective * Scale + 0.2 * Scale);
      Need_Height := Total_Height + 0.2 * Scale;
      if Value.Array_Type = Cases_Array then
         Need_Height := Long_Float'Max
           (1.802 * Total_Height / 2.0,
            Total_Height - 0.5 * Scale);
      end if;
      if Value.Array_Type /= Aligned_Array and then
        Value.Math_Style = Natural_Style
      then
         Total_Height := Long_Float'Max
           (Total_Height, 2.4 * Scale);
      end if;
      Measure_Delimiter (Value.Left_Delimiter, False);
      Measure_Delimiter (Value.Right_Delimiter, True);
      Y_Offset :=
        (if Value.Array_Type = CD_Array then
           -Total_Height / 2.0 - Fraction_Axis * Scale
         elsif Value.Array_Type = Aligned_Array then -Total_Height / 2.0
         elsif Value.Math_Style /= Natural_Style then
           -Total_Height / 2.0 - Fraction_Axis * Scale
         else -0.95 * Scale);
      First_Boundary_Y := Y_Offset;
      for I in 1 .. Rows loop
         Row_Center := Y_Offset + Row_Ascents (I);
         X_Offset   := Left_Width;
         for J in 1 .. Columns loop
            Column_Start := X_Offset;
            if J <= Max_Columns and then Cells (I, J).Valid then
               if Length (Value.Column_Spec) > 0 then
                  X_Offset := X_Offset + Rule_Offsets (J);
                  Column_Start := X_Offset;
               end if;
               if Value.Array_Type = Aligned_Array then
                  if J mod 2 = 1 then
                     X_Offset :=
                       X_Offset + Column_Widths (J) - Cells (I, J).Width;
                  end if;
               elsif Value.Array_Type in Matrix_Array | CD_Array then
                  case Alignments (J) is
                     when Left_Column => null;
                     when Center_Column =>
                        X_Offset := X_Offset +
                          (Column_Widths (J) - Cells (I, J).Width) / 2.0;
                     when Right_Column =>
                        X_Offset := X_Offset + Column_Widths (J) -
                          Cells (I, J).Width;
                  end case;
               end if;
               Append_At (Result, Cells (I, J), X_Offset, Row_Center, Thickness.Work);
               if Value.Array_Type in Matrix_Array | CD_Array then
                  X_Offset := Column_Start + Column_Widths (J);
               else
                  X_Offset := X_Offset + Cells (I, J).Width;
               end if;
               if J < Columns then
                  X_Offset := X_Offset + Column_Gap;
               end if;
            else
               if Value.Array_Type = Aligned_Array and then J mod 2 = 1 then
                  X_Offset := X_Offset + Column_Widths (J);
               elsif Value.Array_Type in Matrix_Array | CD_Array then
                  X_Offset := X_Offset + Column_Widths (J);
               end if;
               if J < Columns then
                  X_Offset := X_Offset + Column_Gap;
               end if;
            end if;
         end loop;
         if Value.Array_Type /= CD_Array or else Visible_Rows (I)
         then
            Result.Ascent  :=
              Maximum (Result.Ascent, -Row_Center + Row_Ascents (I), 0.0);
            Result.Descent :=
              Maximum (Result.Descent, Row_Center + Row_Descents (I), 0.0);
         end if;
         Y_Offset := Y_Offset + Row_Ascents (I) + Row_Descents (I) + Row_Gap +
           0.25 * Scale * Long_Float (Natural'Max (0, Rules_At (I) - 1));
      end loop;
      Total_Width  := Left_Width + Total_Width + Right_Width;
      Result.Width := Total_Width;
      if Rule_Count > 0 then
         declare
            X : Long_Float := Left_Width;
            Column : Natural := 0;
            Rules_Before : Natural := 0;
         begin
            for C of To_String (Value.Column_Spec) loop
               if C in 'l' | 'c' | 'r' then
                  Column := Column + 1;
                  X := X + Column_Widths (Column);
                  if Column < Columns then
                     X := X + Column_Gap;
                  end if;
               elsif C = '|' then
                  Append_Command (Result, Draw_Command'
                       (Kind => Rule_Command, X => X,
                        Y => -Total_Height / 2.0,
                        Width => Thickness.Effective * Scale,
                        Height => Total_Height, Scale => Scale,
                        others => <>), Thickness.Work);
                  Rules_Before := Rules_Before + 1;
                  X := Left_Width;
                  for Prior in 1 .. Column loop
                     X := X + Column_Widths (Prior) +
                       (if Prior < Columns then Column_Gap else 0.0);
                  end loop;
                  X := X + Long_Float (Rules_Before) *
                    (0.24 * Scale);
               end if;
            end loop;
         end;
      end if;
      if Value.Left_Delimiter /= Math_Syntax.No_Delimiter then
         Add_Delimiter (Left_Delimiter, 0.0);
      end if;
      if Value.Left_Delimiter = Math_Syntax.Double_Bar_Delimiter then
         declare
            Bar : Box := Left_Delimiter;
            C : Draw_Command;
         begin
            for I in Bar.Commands.First_Index .. Bar.Commands.Last_Index loop
               Poll (Thickness);
               C := Bar.Commands (I);
               C.X := C.X + Bar.Width + Delimiter_Gap;
               Bar.Commands.Replace_Element (I, C);
            end loop;
            Append_At (Result, Bar, 0.0, 0.0, Thickness.Work);
         end;
      end if;
      if Value.Right_Delimiter /= Math_Syntax.No_Delimiter then
         Add_Delimiter (Right_Delimiter,
           Total_Width - Right_Width + Delimiter_Gap);
      end if;
      if Value.Right_Delimiter = Math_Syntax.Double_Bar_Delimiter then
         declare Bar : Box := Right_Delimiter; begin
            Bar.Commands.Clear;
            Append_Command (Bar, Draw_Command' (Kind => Glyph_Command, Font => Main_Regular,
              Code_Point => 16#7C#, X => 0.0, Y => 0.0, Scale => Scale,
              Width => Right_Delimiter.Width, Height => Need_Height, others => <>), Thickness.Work);
            Append_At (Result, Bar, Total_Width - Right_Width +
              2.0 * Right_Delimiter.Width + 2.0 * Delimiter_Gap, 0.0, Thickness.Work);
         end;
      end if;
      if Horizontal_Rule_Count > 0 then
         declare
            Boundary_Y : Long_Float := First_Boundary_Y;
            Stroke : constant Long_Float := Long_Float'Max
              (Thickness.Effective * Scale, Thickness.Minimum * Scale);
         begin
            for Boundary in 0 .. Rows loop
               declare
                  Count : constant Natural := Rules_At (Boundary);
               begin
                  if Count > 0 then
                     for Rule_Index in 1 .. Count loop
                        declare
                           Rule_Command_Value : Draw_Command;
                           begin
                              declare
                                 Is_Dashed : Boolean := False;
                                 Seen : Natural := 0;
                              begin
                                 for Rule of Value.Array_Rules loop
                                    if Rule.Boundary = Boundary then
                                       Seen := Seen + 1;
                                       if Seen = Rule_Index then
                                          Is_Dashed :=
                                            Rule.Kind = Dashed_Array_Rule;
                                          exit;
                                       end if;
                                    end if;
                                 end loop;
                                 Rule_Command_Value.Kind := Rule_Command;
                                 Rule_Command_Value.X := Left_Width;
                                 Rule_Command_Value.Y :=
                                   Boundary_Y - Stroke;
                                 Rule_Command_Value.Width :=
                                   Total_Width - Left_Width - Right_Width;
                                 Rule_Command_Value.Height := Stroke;
                                 Rule_Command_Value.Scale := Scale;
                                 if Is_Dashed then
                                    declare
                                       Dash_Width : constant Long_Float :=
                                         3.0 * Stroke;
                                       Cursor : Long_Float := Left_Width;
                                       Limit : constant Long_Float :=
                                         Left_Width + Rule_Command_Value.Width;
                                    begin
                                       while Cursor < Limit loop
                                          Rule_Command_Value.X := Cursor;
                                          Rule_Command_Value.Width :=
                                            Long_Float'Min (Dash_Width, Limit - Cursor);
                                          Append_Command
                                            (Result, Rule_Command_Value, Thickness.Work);
                                          Result.Ascent := Long_Float'Max
                                            (Result.Ascent, -Rule_Command_Value.Y);
                                          Result.Descent := Long_Float'Max
                                            (Result.Descent,
                                             Rule_Command_Value.Y + Stroke);
                                          Cursor := Cursor + 2.0 * Dash_Width;
                                       end loop;
                                    end;
                                 else
                                    Append_Command
                                      (Result, Rule_Command_Value,
                                       Thickness.Work);
                                    Result.Ascent := Long_Float'Max
                                      (Result.Ascent, -Rule_Command_Value.Y);
                                    Result.Descent := Long_Float'Max
                                      (Result.Descent,
                                       Rule_Command_Value.Y + Stroke);
                                 end if;
                              end;
                              Boundary_Y := Boundary_Y +
                                (if Rule_Index < Count then 0.25 * Scale
                                 else 0.0);
                        end;
                     end loop;
                  end if;
               end;
               if Boundary < Rows then
                  Boundary_Y := Boundary_Y +
                    0.25 * Scale * Long_Float
                      (Natural'Max (0, Rules_At (Boundary) - 1)) +
                    Row_Ascents (Boundary + 1) +
                    Row_Descents (Boundary + 1) + Row_Gap;
               end if;
            end loop;
         end;
      end if;
      if Value.Array_Type = Aligned_Array then
         Result.Ascent := Maximum
           (Result.Ascent, Total_Height / 2.0, 0.0);
         Result.Descent := Maximum
           (Result.Descent, Total_Height / 2.0, 0.0);
      elsif Value.Array_Type = CD_Array then
         null;
      elsif Value.Math_Style /= Natural_Style then
         Result.Ascent := Long_Float'Max
           (Result.Ascent,
            Long_Float'Max (Total_Height / 2.0 + Fraction_Axis * Scale,
              Long_Float'Max
                (Left_Delimiter.Ascent, Right_Delimiter.Ascent)));
         Result.Descent := Long_Float'Max
           (Result.Descent,
            Long_Float'Max
              (Long_Float'Max
                 (0.0, Total_Height / 2.0 - Fraction_Axis * Scale),
               Long_Float'Max
                 (Left_Delimiter.Descent, Right_Delimiter.Descent)));
      else
         Result.Ascent := 1.45 * Scale;
         Result.Descent := 0.95 * Scale;
      end if;
      Result.Valid := True;
      return Result;
   end Compose_Array;

   function Compose
     (Item  : Math_Syntax.Document; Id : Node_Id; Level : Style_Level;
      Scale : Long_Float; Depth : Natural; Thickness : Rule_Parameters) return Box
   is
      Value   : Math_Syntax.Node;
      Result  : Box;
      Metric  : Math_Metrics.Glyph_Metric;
      Command : Draw_Command;
      Op_Font : Font_Kind;
   begin
      Poll (Thickness);
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
            Result := Compose_Row (Item, Value, Level, Scale, Depth, Thickness);
         when Glyph_Node =>
            if Value.Code_Point in 16#222F# | 16#2230# then
               declare
                  Name : constant String :=
                    (if Value.Code_Point = 16#222F# then "oiint" else "oiiint");
                  Base_Point : constant Natural :=
                    (if Value.Code_Point = 16#222F# then 16#222C# else 16#222D#);
                  Size_Name : constant String := Name & "Size" &
                    (if Is_Display (Level) then "2" else "1");
                  Base_Font : constant Font_Kind :=
                    (if Is_Display (Level) then Size_2 else Size_1);
                  Base_Metric : constant Math_Metrics.Glyph_Metric :=
                    Scaled_Metric (Base_Font, Base_Point, Scale, Thickness);
                  Path : constant Math_Paths.Path :=
                    Math_Stretchy.Geometry_For (Size_Name);
                  Svg_Width : constant Long_Float :=
                    Math_Stretchy.Svg_Width_For (Size_Name) * Scale;
                  Svg_Height : constant Long_Float :=
                    Math_Stretchy.Svg_Height_For (Size_Name) * Scale;
                  Svg_Y_Shift : constant Long_Float :=
                    Math_Stretchy.Svg_Y_Shift_For (Size_Name) * Scale;
                  View_Width : constant Long_Float :=
                    Math_Stretchy.Svg_Width_For (Size_Name) * 1_000.0;
                  View_Height : constant Long_Float :=
                    Math_Stretchy.Svg_Height_For (Size_Name) * 1_000.0;
                  Base_Width : constant Long_Float := Base_Metric.Width;
                  Oval : Draw_Command;
                  Scaled_Path : Math_Paths.Path;
               begin
                  if Value.Class /= Operator_Atom or else
                    not Math_Metrics.Lookup (Base_Font, Base_Point).Found or else
                    not Math_Paths.Is_Valid (Path) or else
                    Svg_Width <= 0.0 or else Svg_Height <= 0.0 or else
                    not View_Width'Valid or else not View_Height'Valid
                  then
                     Reject ("invalid contour integral overlay geometry");
                  end if;
                  Scaled_Path := Math_Paths.Transform
                    (Path, Svg_Width / View_Width, 0.0, 0.0,
                     Svg_Height / View_Height, 0.0, 0.0, Thickness.Work);
                  if not Math_Paths.Is_Valid (Scaled_Path) then
                     Reject ("invalid contour integral overlay path");
                  end if;
                  Command := (Kind => Glyph_Command, Font => Base_Font,
                    Code_Point => Base_Point, X => 0.0,
                    Y => (Base_Metric.Ascent - Base_Metric.Descent) / 2.0 -
                      Fraction_Axis * Scale,
                    Scale => Scale, Width => Base_Width,
                    Height => Base_Metric.Ascent + Base_Metric.Descent,
                    others => <>);
                  Append_Command (Result, Command, Thickness.Work);
                  Oval.Kind := Path_Command;
                  Oval.X := (Base_Width - Svg_Width) / 2.0;
                  Oval.Y := (Base_Metric.Ascent - Base_Metric.Descent) / 2.0 -
                    Fraction_Axis * Scale - Svg_Height + Svg_Y_Shift;
                  Oval.Width := Svg_Width;
                  Oval.Height := Svg_Height;
                  Oval.Has_Clip := True;
                  Oval.Clip_X := 0.0;
                  Oval.Clip_Y := 0.0;
                  Oval.Clip_W := Svg_Width;
                  Oval.Clip_H := Svg_Height;
                  for Part in 1 .. Math_Paths.Count (Scaled_Path) loop
                     Poll (Thickness);
                     Oval.Path_Data.Append
                       (Math_Paths.Element (Scaled_Path, Part));
                  end loop;
                  Append_Command (Result, Oval, Thickness.Work);
                  Result.Width := Base_Width;
                  Result.Ascent := Maximum
                    (Base_Metric.Ascent,
                     Fraction_Axis * Scale + Svg_Height - Svg_Y_Shift, 0.0);
                  Result.Descent := Maximum
                    (Base_Metric.Descent,
                     Svg_Y_Shift - Fraction_Axis * Scale, 0.0);
                  Result.Italic := Base_Metric.Italic;
                  Result.Valid := True;
               end;
            else
               if Value.Class = Operator_Atom and then
                 Math_Metrics.Lookup (Size_1, Value.Code_Point).Found
               then
                  if Value.Code_Point = 16#222B# then
                     Op_Font := Size_1;
                  elsif Is_Display (Level) then
                     Op_Font := Size_2;
                  else
                     Op_Font := Size_1;
                  end if;
               end if;
               Metric := Scaled_Metric
                 (Op_Font, Value.Code_Point, Scale, Thickness);
               Command.Font       := Op_Font;
               Command.Code_Point := Value.Code_Point;
               Command.Scale      := Scale;
               Command.Width      := Metric.Width;
               Command.Height     := Metric.Ascent + Metric.Descent;
               Append_Command (Result, Command, Thickness.Work);
               Result.Width   := Metric.Width;
               Result.Ascent  := Maximum (Metric.Ascent, 0.0);
               Result.Descent := Maximum (Metric.Descent, 0.0);
               Result.Italic  := Metric.Italic;
               Result.Valid   := True;
            end if;
         when Verbatim_Node =>
            declare
               Text : constant String := To_String (Value.Verbatim_Text);
               Offset : Natural := 0;
               Point : Natural;
               Step : Natural;
               Metric : Math_Metrics.Glyph_Metric;
               Command : Draw_Command;
            begin
               if Value.First /= No_Node or Value.Second /= No_Node or
                 Value.Third /= No_Node or Value.Fourth /= No_Node or
                 Value.Class /= Ordinary or
                 Value.Font /= Typewriter_Regular
               then
                  Reject ("invalid verbatim node");
               end if;
               while Offset < Text'Length loop
                  Poll (Thickness);
                  declare
                     Lead : constant Natural := Character'Pos
                       (Text (Text'First + Offset));
                  begin
                     if Lead < 16#80# then
                        Point := Lead;
                        Step := 1;
                     elsif Lead < 16#E0# then
                        Point := (Lead mod 32) * 64 +
                          (Character'Pos
                            (Text (Text'First + Offset + 1)) mod 64);
                        Step := 2;
                     elsif Lead < 16#F0# then
                        Point := (Lead mod 16) * 4_096 +
                          (Character'Pos
                            (Text (Text'First + Offset + 1)) mod 64) * 64 +
                          (Character'Pos
                            (Text (Text'First + Offset + 2)) mod 64);
                        Step := 3;
                     else
                        Point := (Lead mod 8) * 262_144 +
                          (Character'Pos
                            (Text (Text'First + Offset + 1)) mod 64) * 4_096 +
                          (Character'Pos
                            (Text (Text'First + Offset + 2)) mod 64) * 64 +
                          (Character'Pos
                            (Text (Text'First + Offset + 3)) mod 64);
                        Step := 4;
                     end if;
                  end;
                  if Point = Character'Pos (' ') then
                     Point := (if Value.Verbatim_Starred
                       then 16#2423# else 16#00A0#);
                  end if;
                  Metric := Scaled_Metric (Typewriter_Regular, Point, Scale, Thickness);
                  Command := (Kind => Glyph_Command,
                     Font => Typewriter_Regular, Code_Point => Point,
                     X => Result.Width,
                     Y => 0.0,
                     Scale => Scale, Width => Metric.Width,
                     Height => Metric.Ascent + Metric.Descent,
                     others => <>);
                  Append_Command (Result, Command, Thickness.Work);
                  Result.Width := Result.Width + Metric.Width;
                  Result.Ascent := Maximum (Result.Ascent, Metric.Ascent, 0.0);
                  Result.Descent := Maximum (Result.Descent, Metric.Descent, 0.0);
                  Offset := Offset + Step;
               end loop;
               Result.Valid := True;
            end;
         when Text_Run_Node =>
            declare
               Text : constant String := To_String (Value.Text_Run_Text);
               Shaped : Math_Text_Shaping.Metrics;
               Run_Command : Draw_Command;
            begin
               if Value.First /= No_Node or Value.Second /= No_Node or
                 Value.Third /= No_Node or Value.Fourth /= No_Node or
                 Value.Class /= Ordinary or Text'Length = 0 or
                 Text'Length > Math_Syntax.Max_Source_Bytes
               then
                  Reject ("invalid fallback text run");
               end if;
               Shaped := Math_Text_Shaping.Measure
                 (Text, Value.Text_Run_Profile,
                  Thickness.Pixel_Em, Thickness.Work);
               Run_Command.Kind := Text_Run_Command;
               Run_Command.Text_Run_Text := Value.Text_Run_Text;
               Run_Command.Text_Run_Profile := Value.Text_Run_Profile;
               Run_Command.Scale := Scale;
               Run_Command.Width := Shaped.Advance * Scale;
               Run_Command.Height := (Shaped.Ascent + Shaped.Descent) * Scale;
               Append_Command (Result, Run_Command, Thickness.Work);
               Result.Width := Run_Command.Width;
               Result.Ascent := Shaped.Ascent * Scale;
               Result.Descent := Shaped.Descent * Scale;
               Result.Valid := True;
            end;
         when Fraction_Node =>
            if Value.First = No_Node or Value.Second = No_Node or
              Value.Third /= No_Node
            then
               Reject ("invalid fraction children");
            end if;
            Result := Compose_Fraction (Item, Value, Level, Scale, Depth, Thickness);
         when Radical_Node =>
            if Value.First = No_Node or Value.Third /= No_Node then
               Reject ("invalid radical children");
            end if;
            Result := Compose_Radical (Item, Value, Level, Scale, Depth, Thickness);
         when Scripts_Node =>
            if Value.First = No_Node then
               Reject ("scripts node has no base");
            end if;
            Result := Compose_Scripts (Item, Value, Level, Scale, Depth, Thickness);
         when Array_Node =>
            Result := Compose_Array (Item, Value, Level, Scale, Depth, Thickness);
         when Overlay_Node =>
            declare
               Base  : Box :=
                 Compose (Item, Value.First, Level, Scale, Depth + 1, Thickness);
               Slash : Box :=
                 Compose (Item, Value.Second, Level, Scale * 0.9, Depth + 1, Thickness);
            begin
               Append_At (Base, Slash, Base.Width * 0.35, 0.0, Thickness.Work);
               Base.Width :=
                 Long_Float'Max (Base.Width, Base.Width * 0.35 + Slash.Width);
               Result     := Base;
            end;
         when Overlap_Node =>
            declare
               Content : constant Box :=
                 Compose (Item, Value.First, Level, Scale, Depth + 1, Thickness);
               Offset : constant Long_Float :=
                 (case Value.Overlap_Mode is
                    when Right_Overlap => -Content.Width,
                    when Left_Overlap => 0.0,
                    when Center_Overlap => -Content.Width / 2.0);
            begin
               Append_At (Result, Content, Offset, 0.0, Thickness.Work);
               Result.Width := 0.0;
               Result.Ascent := Content.Ascent;
               Result.Descent := Content.Descent;
               Result.Valid := True;
            end;
         when Accent_Node =>
            if Value.Code_Point in Over_Brace_Code_Point |
              Under_Brace_Code_Point
            then
               Result := Compose_Brace
                 (Item, Value, Level, Scale, Depth, Thickness);
            else
               declare
                  Base   : Box :=
                 Compose (Item, Value.First, Cramped (Level), Scale,
                          Depth + 1, Thickness);
               Mark   : Math_Metrics.Glyph_Metric;
               Accent : Draw_Command;
               Accent_Font : Font_Kind := Main_Regular;
               Accent_Font_Found : Boolean := False;
            begin
               Result := Base;
               if Value.Code_Point = 0 then
                  Accent.Kind   := Rule_Command;
                  Accent.X      := 0.05 * Scale;
                  Accent.Width  :=
                    Long_Float'Max (Base.Width - 0.1 * Scale, 0.05 * Scale);
                  Accent.Height := Thickness.Effective * Scale;
                  if Value.Amount = 1.0 then
                     Accent.Y := Base.Descent + 0.08 * Scale;
                     Result.Descent :=
                       Base.Descent + 0.12 * Scale + Accent.Height;
                  else
                     Accent.Y := -(Base.Ascent + 0.08 * Scale);
                     Result.Ascent := Base.Ascent + 0.12 * Scale;
                  end if;
               elsif Value.Code_Point in
                 Over_Right_Arrow_Code_Point | Over_Left_Arrow_Code_Point
               then
                  declare
                     Synthetic : Math_Syntax.Node := Value;
                     Name : constant String :=
                       (if Value.Code_Point = Over_Right_Arrow_Code_Point
                        then "overrightarrow" else "overleftarrow");
                  begin
                     Synthetic.Kind := Stretchy_Node;
                     Synthetic.Stretchy_Name := To_Unbounded_String (Name);
                     Synthetic.Code_Point := 0;
                     Synthetic.Annotation_Type := Over_Annotation;
                     Result := Compose_Stretchy
                       (Item, Synthetic, Level, Scale, Depth, Thickness);
                     Result.Ascent := Base.Ascent + 0.522 * Scale;
                     Result.Descent := Base.Descent;
                  end;
               elsif Value.Code_Point in Wide_Hat_Code_Point ..
                 Under_Tilde_Code_Point
               then
                  declare
                     Name : constant String :=
                       (if Value.Code_Point = Wide_Check_Code_Point then
                          "widecheck"
                        elsif Value.Code_Point = Under_Tilde_Code_Point then
                          "utilde"
                        elsif Value.Code_Point = Wide_Hat_Code_Point then
                          "widehat" else "widetilde");
                     function Character_Count return Positive is
                        Base_Node : constant Math_Syntax.Node :=
                          Math_Syntax.Element
                            (Item, Positive (Value.First));
                        Current : Node_Id := Base_Node.First;
                        Count : Natural := 0;
                     begin
                        if Base_Node.Kind /= Row_Node then
                           return 1;
                        end if;
                        while Current /= No_Node loop
                           Poll (Thickness);
                           Count := Count + 1;
                           Current := Math_Syntax.Element
                             (Item, Positive (Current)).Next;
                        end loop;
                        return Natural'Max (1, Count);
                     end Character_Count;
                     Character_Total : constant Positive :=
                       Character_Count;
                     function Variant_Height return Long_Float is
                     begin
                        if Name = "widehat" or else Name = "widecheck" then
                           return (case Character_Total is
                              when 1 => 0.24,
                              when 2 .. 5 => 0.30,
                              when others => 0.42);
                        else
                           return (case Character_Total is
                              when 1 => 0.26,
                              when 2 .. 3 => 0.286,
                              when 4 .. 5 => 0.30,
                              when others => 0.34);
                        end if;
                     end Variant_Height;
                     function View_Height return Long_Float is
                     begin
                        if Name = "widehat" or else Name = "widecheck" then
                           return (case Character_Total is
                              when 1 => 239.0,
                              when 2 .. 5 => 300.0,
                              when others => 420.0);
                        else
                           return (case Character_Total is
                              when 1 => 260.0,
                              when 2 => 286.0,
                              when 3 .. 5 => 306.0,
                              when others => 312.0);
                        end if;
                     end View_Height;
                     function View_Width return Long_Float is
                     begin
                        if Name = "widehat" or else Name = "widecheck" then
                           return (if Character_Total = 1 then 1_062.0 else 2_364.0);
                        else
                           return (case Character_Total is
                              when 1 => 600.0,
                              when 2 => 1_033.0,
                              when 3 => 2_339.0,
                              when others => 2_340.0);
                        end if;
                     end View_Width;
                     Path : constant Math_Paths.Path :=
                       Math_Stretchy.Accent_Path_For
                         (Name, Character_Total);
                     Bounds : constant Math_Paths.Bounds :=
                       Math_Paths.Extent (Path);
                     Fit_X : Long_Float;
                     Fit_Y : Long_Float;
                     Offset_X : Long_Float;
                     Offset_Y : Long_Float;
                     Geometry : Draw_Command;
                     --  The SVG spans the complete body, including the
                     --  trailing italic margin used by measured layout.
                     Accent_Width : constant Long_Float := Base.Width +
                       (if Thickness.Advance_Source /= null then
                          Base.Italic else 0.0);
                  begin
                     if not Math_Paths.Is_Valid (Path) or else
                       not Bounds.Valid or else
                       Bounds.Max_X <= Bounds.Min_X or else
                       Bounds.Max_Y <= Bounds.Min_Y
                     then
                        Reject ("invalid trusted stretchy accent path");
                     end if;
                     Fit_X := Accent_Width / View_Width;
                     Fit_Y := Variant_Height * Scale / View_Height;
                     Offset_X := -Bounds.Min_X * Fit_X;
                     Offset_Y :=
                       (if Value.Code_Point = Under_Tilde_Code_Point then
                          Base.Descent + 0.12 * Scale - Bounds.Min_Y * Fit_Y
                        else -Base.Ascent - Variant_Height * Scale);
                     Geometry.Kind := Path_Command;
                     Geometry.X := Offset_X;
                     Geometry.Y := Offset_Y;
                     Geometry.Width := Accent_Width;
                     Geometry.Height := Variant_Height * Scale;
                     Geometry.Has_Clip := True;
                     Geometry.Clip_X := 0.0;
                     Geometry.Clip_Y := 0.0;
                     Geometry.Clip_W := Accent_Width;
                     Geometry.Clip_H := Variant_Height * Scale;
                     declare
                        Scaled : constant Math_Paths.Path :=
                          Math_Paths.Transform
                            (Path, Fit_X, 0.0, 0.0, Fit_Y, 0.0, 0.0);
                     begin
                        for I in 1 .. Math_Paths.Count (Scaled) loop
               Poll (Thickness);
                           Geometry.Path_Data.Append
                             (Math_Paths.Element (Scaled, I));
                        end loop;
                     end;
                     Result := Base;
                     Append_Command (Result, Geometry, Thickness.Work);
                     Result.Width := Accent_Width;
                     if Value.Code_Point = Under_Tilde_Code_Point then
                        Result.Ascent := Base.Ascent;
                        Result.Descent := Base.Descent + 0.12 * Scale +
                          Geometry.Height;
                     else
                        Result.Ascent := Base.Ascent + Geometry.Height;
                        Result.Descent := Base.Descent;
                     end if;
                     Accent.Kind := Path_Command;
                  end;
               else
                  if Value.Accent_Type = Above_Accent and then
                    Thickness.Advance_Source /= null
                  then
                     --  The accent vlist owns the body's trailing margin;
                     --  include it once, including for nested accents.
                     Base.Width := Base.Width + Base.Italic;
                     Base.Italic := 0.0;
                     Result.Width := Base.Width;
                     Result.Italic := 0.0;
                  end if;
                  if Value.Accent_Type /= Full_Accent and then
                    not Base.Commands.Is_Empty
                  then
                     for Command of Base.Commands loop
                        Poll (Thickness);
                        if Command.Kind = Glyph_Command then
                           Accent_Font := Command.Font;
                           Accent_Font_Found := True;
                           exit;
                        end if;
                     end loop;
                  end if;
                  Mark := Math_Metrics.Lookup
                    ((if Accent_Font_Found then Accent_Font
                      else Main_Regular), Value.Code_Point);
                  if not Mark.Found and then
                    Value.Accent_Type /= Full_Accent
                  then
                     Accent_Font_Found := False;
                     Accent_Font := Main_Regular;
                     Mark := Math_Metrics.Lookup
                       (Main_Regular, Value.Code_Point);
                  end if;
                  if not Mark.Found then
                     Reject ("accent glyph metric unavailable");
                  end if;
                  Accent.Font       :=
                    (if Value.Accent_Type = Full_Accent then Main_Regular
                     elsif Accent_Font_Found then Accent_Font
                     else Main_Regular);
                  Accent.Code_Point := Value.Code_Point;
                  Accent.X          := (Base.Width - Mark.Width * Scale) / 2.0;
                  if Value.Accent_Type = Full_Accent then
                     Result.Width := Long_Float'Max
                       (Base.Width, Mark.Width * Scale);
                     Accent.X := (Result.Width - Mark.Width * Scale) / 2.0;
                     declare
                        Base_Shift : constant Long_Float :=
                          (Result.Width - Base.Width) / 2.0;
                     begin
                        if Base_Shift > 0.0 then
                           for Index in Base.Commands.First_Index ..
                             Base.Commands.Last_Index
                           loop
                              Poll (Thickness);
                              declare
                                 Command : Draw_Command :=
                                   Result.Commands (Index);
                              begin
                                 Command.X := Command.X + Base_Shift;
                                 Result.Commands.Replace_Element
                                   (Index, Command);
                              end;
                           end loop;
                        end if;
                     end;
                     Accent.Y := -Mark.Descent * Scale + 0.2 * Scale;
                     Result.Ascent := Long_Float'Max
                       (Base.Ascent, Mark.Ascent * Scale + Mark.Descent * Scale);
                     Result.Descent := Long_Float'Max
                       (Base.Descent, Mark.Descent * Scale - Mark.Descent * Scale);
                  elsif Value.Accent_Type = Below_Accent then
                     Accent.X := (Base.Width - Mark.Width * Scale) / 2.0 +
                       Base.Italic;
                     Accent.Y := 0.0;
                     Result.Descent := Long_Float'Max
                       (Base.Descent, Mark.Descent * Scale);
                  else
                     declare
                        Clearance : constant Long_Float :=
                          Long_Float'Min (Base.Ascent, X_Height * Scale);
                        Skew : Long_Float := 0.0;
                        Nucleus_Id : Node_Id := Value.First;
                     begin
                        --  Only singleton groups, colors and flattened font
                        --  arguments expose a character nucleus. Painted
                        --  glyph counts also admit smash/enclosure bodies.
                        Nucleus_Search :
                        for Step in 1 .. Math_Syntax.Max_Depth loop
                           Poll (Thickness);
                           exit Nucleus_Search when Nucleus_Id = No_Node;
                           declare
                              Nucleus : constant Math_Syntax.Node :=
                                Math_Syntax.Element
                                  (Item, Positive (Nucleus_Id));
                           begin
                              case Nucleus.Kind is
                                 when Row_Node =>
                                    exit Nucleus_Search when
                                      Nucleus.First = No_Node;
                                    exit Nucleus_Search when
                                      Math_Syntax.Element
                                        (Item, Positive (Nucleus.First)).Next
                                          /= No_Node;
                                    Nucleus_Id := Nucleus.First;
                                 when Color_Node =>
                                    Nucleus_Id := Nucleus.First;
                                 when Glyph_Node =>
                                    if Nucleus.Class /= Operator_Atom then
                                       Metric := Math_Metrics.Lookup
                                         (Nucleus.Font, Nucleus.Code_Point);
                                       if Metric.Found then
                                          Skew := Metric.Skew * Scale;
                                       end if;
                                    end if;
                                    exit Nucleus_Search;
                                 when others =>
                                    exit Nucleus_Search;
                              end case;
                           end;
                        end loop Nucleus_Search;
                        Accent.X := Base.Width / 2.0 + Skew -
                          Mark.Width * Scale / 2.0;
                        Accent.Y := -Base.Ascent + Clearance -
                          Mark.Descent * Scale;
                        Result.Ascent := Long_Float'Max
                          (Base.Ascent, Mark.Ascent * Scale - Accent.Y);
                        Result.Descent := Long_Float'Max
                          (Base.Descent, Accent.Y + Mark.Descent * Scale);
                     end;
                  end if;
                  Accent.Scale  := Scale;
                  Accent.Width  := Mark.Width * Scale;
                  Accent.Height := (Mark.Ascent + Mark.Descent) * Scale;
                  Result.Ascent := Long_Float'Max
                    (Result.Ascent, Base.Ascent);
               end if;
               if Value.Code_Point not in Wide_Hat_Code_Point ..
                 Under_Tilde_Code_Point
               then
                  Append_Command (Result, Accent, Thickness.Work);
               end if;
               Result.Valid := True;
            end;
            end if;
         when Delimited_Node =>
            if Value.Code_Point = 4 then
               declare
                  Bar : constant Math_Metrics.Glyph_Metric :=
                    Scaled_Metric
                      (Main_Regular, Character'Pos ('|'), Scale, Thickness);
               begin
                  Result.Width := Bar.Width;
                  Result.Ascent := Bar.Ascent;
                  Result.Descent := Bar.Descent;
                  Append_Command
                    (Result, Draw_Command'
                       (Kind => Glyph_Command, Font => Main_Regular,
                        Code_Point => Character'Pos ('|'), X => 0.0, Y => 0.0,
                        Scale => Scale, Width => Bar.Width,
                        Height => Bar.Ascent + Bar.Descent, others => <>),
                     Thickness.Work);
                  Result.Valid := True;
               end;
            elsif Value.First = No_Node and then
              Value.Amount in 1.2 | 1.8 | 2.4 | 3.0
            then
               declare
                  Size : constant Font_Kind :=
                    (if Value.Amount <= 1.2 then Size_1
                     elsif Value.Amount <= 1.8 then Size_2
                     elsif Value.Amount <= 2.4 then Size_3
                     else Size_4);
                  Right_Side : constant Boolean := Value.Code_Point = 3;
                  Point : constant Natural :=
                    (case Value.Left_Delimiter is
                       when Math_Syntax.Parenthesis_Delimiter =>
                         (if Right_Side then 16#29# else 16#28#),
                       when Math_Syntax.Bracket_Delimiter =>
                         (if Right_Side then 16#5D# else 16#5B#),
                       when Math_Syntax.Brace_Delimiter =>
                         (if Right_Side then 16#7D# else 16#7B#),
                       when Math_Syntax.Angle_Delimiter =>
                         (if Right_Side then 16#27E9# else 16#27E8#),
                       when Math_Syntax.Floor_Delimiter =>
                         (if Right_Side then 16#230B# else 16#230A#),
                       when Math_Syntax.Ceiling_Delimiter =>
                         (if Right_Side then 16#2309# else 16#2308#),
                       when Math_Syntax.Bar_Delimiter |
                         Math_Syntax.Double_Bar_Delimiter => 16#7C#,
                       when others => 0);
                  Metric : constant Math_Metrics.Glyph_Metric :=
                    Math_Metrics.Lookup (Size, Point);
                  Height : constant Long_Float := Value.Amount * Scale;
                  Is_Bar : constant Boolean :=
                    Value.Left_Delimiter in Math_Syntax.Bar_Delimiter |
                      Math_Syntax.Double_Bar_Delimiter;
               begin
                  if Value.Amount not in 1.2 | 1.8 | 2.4 | 3.0 or else
                    (Point /= 0 and then not Is_Bar and then not Metric.Found)
                  then
                     Reject ("invalid sized delimiter");
                  end if;
                  if Point = 0 then
                     Result.Valid := True;
                     return Result;
                  elsif Is_Bar then
                     declare
                        Bar_Metric : constant Math_Metrics.Glyph_Metric :=
                          Scaled_Metric (Main_Regular, 16#7C#, Scale,
                            Thickness);
                        Bar_Width : constant Long_Float := Bar_Metric.Width;
                        Gap : constant Long_Float := 0.04 * Scale;
                        Copies : constant Natural :=
                          (if Value.Left_Delimiter =
                            Math_Syntax.Double_Bar_Delimiter then 2 else 1);
                     begin
                        Result.Width := Long_Float (Copies) * Bar_Width +
                          Long_Float (Copies - 1) * Gap;
                        Result.Ascent := Height / 2.0 + Fraction_Axis * Scale;
                        Result.Descent := Height / 2.0 - Fraction_Axis * Scale;
                        for I in 1 .. Copies loop
                           Append_Command (Result, Draw_Command'
                             (Kind => Glyph_Command, Font => Main_Regular,
                              Code_Point => 16#7C#,
                              X => Long_Float (I - 1) * (Bar_Width + Gap),
                              Y => -Height / 2.0 - Fraction_Axis * Scale,
                              Scale => Scale, Width => Bar_Width,
                              Height => Height, others => <>), Thickness.Work);
                        end loop;
                     end;
                  else
                     Result.Width := Metric.Width * Scale;
                     Result.Ascent := Metric.Ascent * Scale;
                     Result.Descent := Metric.Descent * Scale;
                     Append_Command (Result, Draw_Command'(Kind => Glyph_Command, Font => Size,
                         Code_Point => Point, X => 0.0, Y => 0.0,
                         Scale => Scale, Width => Result.Width,
                         Height =>
                           (Metric.Ascent + Metric.Descent) * Scale,
                         others => <>), Thickness.Work);
                  end if;
                  Result.Valid := True;
               end;
            else
               declare
                  Inner : constant Box := Compose
                    (Item, Value.First, Level, Scale, Depth + 1, Thickness);
                  Gap : constant Long_Float := 0.1 * Scale;
                  Axis : constant Long_Float := Fraction_Axis * Scale;
                  Max_Distance : constant Long_Float := Long_Float'Max
                    (Inner.Ascent - Axis, Inner.Descent + Axis);
                  Need : constant Long_Float := Long_Float'Max
                    (Max_Distance * 901.0 / 500.0,
                     2.0 * Max_Distance - 0.5 * Scale);
                  Left : Box := Compose_Delimiter
                    (Value.Left_Delimiter, False, Need, Scale, Thickness);
                  Right : Box := Compose_Delimiter
                    (Value.Right_Delimiter, True, Need, Scale, Thickness);
                  Left_Width : Long_Float :=
                    (if Value.Left_Delimiter = Math_Syntax.No_Delimiter then 0.0
                     else Left.Width + Gap);
                  Right_Width : Long_Float :=
                    (if Value.Right_Delimiter = Math_Syntax.No_Delimiter then 0.0
                     else Right.Width + Gap);
               begin
                  if Value.Left_Delimiter /= Math_Syntax.No_Delimiter then
                     Append_At (Result, Left, 0.0, 0.0, Thickness.Work);
                  end if;
                  Append_At (Result, Inner, Left_Width, 0.0, Thickness.Work);
                  if Value.Right_Delimiter /= Math_Syntax.No_Delimiter then
                     Append_At (Result, Right,
                       Left_Width + Inner.Width + Gap, 0.0, Thickness.Work);
                  end if;
                  Result.Width := Left_Width + Inner.Width + Right_Width;
                  Result.Ascent := Long_Float'Max
                    (Inner.Ascent,
                     Long_Float'Max (Left.Ascent, Right.Ascent));
                  Result.Descent := Long_Float'Max
                    (Inner.Descent,
                     Long_Float'Max (Left.Descent, Right.Descent));
                  Result.Valid := True;
               end;
            end if;
         when Binomial_Node =>
            if Value.First = No_Node or else Value.Second = No_Node then
               Reject ("invalid binomial children");
            end if;
            declare
               Fraction : Math_Syntax.Node := Value;
               Parenthesized : Box;
               Need : Long_Float;
               Left : Box;
               Right : Box;
               Gap : constant Long_Float := 0.1 * Scale;
            begin
               Fraction.Kind := Fraction_Node;
               Fraction.Fraction_Type :=
                 (if Value.Math_Style = Display_Style then Display_Fraction
                  elsif Value.Math_Style = Text_Style then Text_Fraction
                  else Default_Fraction);
               Parenthesized := Compose_Fraction
                 (Item, Fraction, Level, Scale, Depth, Thickness, True);
               Need := Parenthesized.Ascent + Parenthesized.Descent + 0.2 * Scale;
               Left := Compose_Delimiter (Math_Syntax.Parenthesis_Delimiter, False, Need, Scale, Thickness);
               Right := Compose_Delimiter (Math_Syntax.Parenthesis_Delimiter, True, Need, Scale, Thickness);
               Append_At (Result, Left, 0.0, 0.0, Thickness.Work);
               Append_At (Result, Parenthesized, Left.Width + Gap, 0.0, Thickness.Work);
               Append_At (Result, Right, Left.Width + Gap + Parenthesized.Width + Gap, 0.0, Thickness.Work);
               Result.Width := Left.Width + Parenthesized.Width + Right.Width + 2.0 * Gap;
               Result.Ascent := Long_Float'Max (Parenthesized.Ascent, Need / 2.0);
               Result.Descent := Long_Float'Max (Parenthesized.Descent, Need / 2.0);
               Result.Valid := True;
            end;
         when Stretchy_Node =>
            Result := Compose_Stretchy
              (Item, Value, Level, Scale, Depth, Thickness);
         when CD_Arrow_Node =>
            Result := Compose_CD_Arrow
              (Item, Value, Scale, Depth, Thickness);
         when Annotation_Node =>
            declare
               Base_Value : constant Math_Syntax.Node :=
                 Math_Syntax.Element (Item, Positive (Value.First));
               Base : Box := Compose
                 (Item, Value.First,
                  (if Value.Code_Point = 1 then Level else Cramped (Level)),
                  Scale, Depth + 1, Thickness);
               Mark_Level : constant Style_Level := Smaller (Level);
               Mark : Box := Compose (Item, Value.Second, Mark_Level,
                 Child_Scale (Scale, Level, Mark_Level), Depth + 1, Thickness);
               Gap : constant Long_Float :=
                 (if Value.Code_Point = 1 then 0.3 else 0.1) * Scale;
               Shift : Long_Float;
               Is_Limit_Annotation : constant Boolean := Value.Code_Point = 1;
            begin
               if Value.First = No_Node or else Value.Second = No_Node then
                  Reject ("invalid annotation children");
               end if;
               if Is_Limit_Annotation then
                  if Value.Annotation_Type = Over_Annotation then
                     Shift := Base.Ascent + Mark.Descent + Gap;
                     Append_At
                       (Result, Mark, (Base.Width - Mark.Width) / 2.0,
                        -Shift, Thickness.Work);
                     Append_At
                       (Result, Base, 0.0, 0.0, Thickness.Work);
                     Result.Ascent := Long_Float'Max
                       (Base.Ascent, Shift + Mark.Ascent);
                     Result.Descent := Base.Descent;
                  else
                     Shift := Base.Descent + Mark.Ascent + Gap;
                     Append_At
                       (Result, Base, 0.0, 0.0, Thickness.Work);
                     Append_At
                       (Result, Mark, (Base.Width - Mark.Width) / 2.0,
                        Shift, Thickness.Work);
                     Result.Ascent := Base.Ascent;
                     Result.Descent := Long_Float'Max
                       (Base.Descent, Shift + Mark.Descent);
                  end if;
               elsif Value.Annotation_Type = Over_Annotation then
                  Shift := Base.Ascent + Mark.Descent + Gap;
                  Append_At (Result, Mark, (Base.Width - Mark.Width) / 2.0, -Shift, Thickness.Work);
                  Append_At (Result, Base, 0.0, 0.0, Thickness.Work);
                  Result.Ascent := Long_Float'Max (Base.Ascent, Shift + Mark.Ascent);
                  Result.Descent := Base.Descent;
               else
                  Shift := Base.Descent + Mark.Ascent + Gap;
                  Append_At (Result, Base, 0.0, 0.0, Thickness.Work);
                  Append_At (Result, Mark, (Base.Width - Mark.Width) / 2.0, Shift, Thickness.Work);
                  Result.Ascent := Base.Ascent;
                  Result.Descent := Long_Float'Max (Base.Descent, Shift + Mark.Descent);
               end if;
               Result.Width := Long_Float'Max (Base.Width, Mark.Width);
               Result.Valid := True;
            end;
         when Boxed_Node =>
            Result := Compose (Item, Value.First, Level, Scale, Depth + 1, Thickness);
            declare
               Padding : constant Long_Float := 0.15 * Scale;
               T : constant Long_Float := Thickness.Effective * Scale;
               R : Draw_Command;
            begin
               for I in Result.Commands.First_Index .. Result.Commands.Last_Index loop
                  Poll (Thickness);
                  declare C : Draw_Command := Result.Commands (I); begin
                     C.X := C.X + Padding;
                     C.Y := C.Y;
                     Result.Commands.Replace_Element (I, C);
                  end;
               end loop;
               R.Kind := Rule_Command;
               R.X := 0.0; R.Y := -(Result.Ascent + Padding);
               R.Width := Result.Width + 2.0 * Padding; R.Height := T;
               Append_Command (Result, R, Thickness.Work);
               R.Y := Result.Descent + Padding;
               Append_Command (Result, R, Thickness.Work);
               R.X := 0.0; R.Y := -(Result.Ascent + Padding);
               R.Width := T; R.Height := Result.Ascent + Result.Descent + 2.0 * Padding;
               Append_Command (Result, R, Thickness.Work);
               R.X := Result.Width + 2.0 * Padding - T;
               Append_Command (Result, R, Thickness.Work);
               Result.Width := Result.Width + 2.0 * Padding;
               Result.Ascent := Result.Ascent + Padding;
               Result.Descent := Result.Descent + Padding;
            end;
         when Phantom_Node =>
            Result := Compose (Item, Value.First, Level, Scale, Depth + 1, Thickness);
            if Value.Code_Point = 0 then
               Result.Commands.Clear;
            elsif Value.Code_Point = 1 then
               Result.Commands.Clear;
               Result.Ascent := 0.0;
               Result.Descent := 0.0;
            elsif Value.Code_Point = 2 then
               Result.Commands.Clear;
               Result.Width := 0.0;
            elsif Value.Code_Point = 3 then
               Result.Ascent := 0.0;
               Result.Descent := 0.0;
            end if;
         when Color_Node =>
            Result := Compose (Item, Value.First, Level, Scale, Depth + 1, Thickness);
            for I in Result.Commands.First_Index .. Result.Commands.Last_Index loop
                  Poll (Thickness);
               declare C : Draw_Command := Result.Commands (I); begin
                  if not C.Has_Color then
                     C.Has_Color := True;
                     C.Red := Value.Color.Red; C.Green := Value.Color.Green;
                     C.Blue := Value.Color.Blue; C.Alpha := Value.Color.Alpha;
                     Result.Commands.Replace_Element (I, C);
                  end if;
               end;
            end loop;
         when Style_Node =>
            declare
               Target : constant Style_Level :=
                 (case Value.Math_Style is
                    when Natural_Style => Level,
                    when Display_Style =>
                      (if Is_Cramped (Level) then Display_Cramped_Level
                       else Display_Level),
                    when Text_Style =>
                      (if Is_Cramped (Level) then Text_Cramped_Level
                       else Text_Level),
                    when Script_Style =>
                      (if Is_Cramped (Level) then Script_Cramped_Level
                       else Script_Level),
                    when Script_Script_Style =>
                      (if Is_Cramped (Level) then Scriptscript_Cramped_Level
                       else Scriptscript_Level));
            begin
               Result := Compose (Item, Value.First, Target,
                 Child_Scale (Scale, Level, Target), Depth + 1, Thickness);
            end;
         when Dual_Node =>
            if Value.First = No_Node or Value.Second = No_Node then
               Reject ("dual node has a missing branch");
            end if;
            Result := Compose
              (Item,
               (if Value.Dual_Type = Visual_First then Value.First
                else Value.Second),
               Level, Scale, Depth + 1, Thickness);
         when MathChoice_Node =>
            if Value.First = No_Node or Value.Second = No_Node or
              Value.Third = No_Node or Value.Fourth = No_Node
            then
               Reject ("mathchoice node has a missing branch");
            end if;
            declare
               Chosen_Node : constant Node_Id :=
                 (case Level is
                    when Display_Level | Display_Cramped_Level =>
                      Value.First,
                    when Text_Level | Text_Cramped_Level => Value.Second,
                    when Script_Level | Script_Cramped_Level => Value.Third,
                    when Scriptscript_Level | Scriptscript_Cramped_Level =>
                      Value.Fourth);
            begin
               Result := Compose
                 (Item, Chosen_Node, Level, Scale, Depth + 1, Thickness);
            end;
         when Tagged_Node =>
            if Value.First = No_Node then
               Reject ("tagged node has missing content");
            end if;
            declare
               Content : constant Box := Compose
                 (Item, Value.First, Display_Level, Scale, Depth + 1, Thickness);
            begin
               Append_At (Result, Content, 0.0, 0.0, Thickness.Work);
               Result.Width := Content.Width;
               Result.Ascent := Content.Ascent;
               Result.Descent := Content.Descent;
               if Value.Second = No_Node then
                  Result.Valid := True;
               else
                  declare
                     Tag : constant Box := Compose
                       (Item, Value.Second, Text_Level, Scale,
                        Depth + 1, Thickness);
                     Gap : constant Long_Float := 1.0;
                     Tag_X : constant Long_Float :=
                       (if Value.Tag_Is_Left then 0.0
                        else Content.Width + Gap);
                  begin
                     if Value.Tag_Is_Left then
                        Result.Commands.Clear;
                        Append_At (Result, Content, Tag.Width + Gap, 0.0, Thickness.Work);
                     end if;
                     Append_At (Result, Tag, Tag_X, 0.0, Thickness.Work);
                     Result.Width := Content.Width + Gap + Tag.Width;
                     Result.Ascent := Long_Float'Max
                       (Content.Ascent, Tag.Ascent);
                     Result.Descent := Long_Float'Max
                       (Content.Descent, Tag.Descent);
                     Result.Valid := True;
                  end;
               end if;
            end;
         when Space_Node =>
            if Value.Amount < -100.0 or Value.Amount > 100.0 then
               Reject ("space amount out of bounds");
            end if;
            Result.Width := Value.Amount * Scale;
            Result.Valid := True;
         when Rule_Node =>
            if Value.Width < 0.0 or Value.Height < 0.0 or
              abs Value.Amount > Max_Geometry
            then
               Reject ("invalid rule dimensions");
            end if;
            Result.Width := Value.Width * Scale;
            Result.Ascent := Long_Float'Max
              (0.0, (Value.Height + Value.Amount) * Scale);
            Result.Descent := Long_Float'Max
              (0.0, -Value.Amount * Scale);
            Command.Kind := Rule_Command;
            Command.Y := -(Value.Height + Value.Amount) * Scale;
            Command.Width := Result.Width;
            Command.Height := Value.Height * Scale;
            Append_Command (Result, Command, Thickness.Work);
            Result.Valid := True;
         when Sized_Node =>
            if Value.Scale <= 0.0 or Value.Scale > 100.0 or
              Value.First = No_Node
            then
               Reject ("invalid sized node");
            end if;
            Result := Compose
              (Item, Value.First, Level,
               Value.Scale / Style_Scale (Level),
               Depth + 1, Thickness);
         when Raised_Node =>
            if Value.First = No_Node or abs Value.Amount > Max_Geometry then
               Reject ("invalid raised node");
            end if;
            Result := Compose
              (Item, Value.First, Level, Scale, Depth + 1, Thickness);
            declare
               Shift : constant Long_Float := Value.Amount * Scale;
            begin
               for I in Result.Commands.First_Index .. Result.Commands.Last_Index loop
                  Poll (Thickness);
                  Command := Result.Commands (I);
                  Command.Y := Command.Y - Shift;
                  Result.Commands.Replace_Element (I, Command);
               end loop;
               Result.Ascent := Long_Float'Max (0.0, Result.Ascent + Shift);
               Result.Descent := Long_Float'Max (0.0, Result.Descent - Shift);
            end;
         when VCenter_Node =>
            if Value.First = No_Node or else Value.Second /= No_Node or else
              Value.Third /= No_Node or else Value.Fourth /= No_Node
            then
               Reject ("vcenter has invalid boxed content");
            end if;
            Result := Compose
              (Item, Value.First, Level, Scale, Depth + 1, Thickness);
            declare
               Shift : constant Long_Float :=
                 Fraction_Axis * Scale -
                 (Result.Ascent - Result.Descent) / 2.0;
            begin
               if Result.Ascent + Result.Descent > Max_Geometry then
                  Reject ("vcenter box geometry limit exceeded");
               end if;
               for Index in Result.Commands.First_Index ..
                 Result.Commands.Last_Index
               loop
                  Poll (Thickness);
                  declare
                     Command : Draw_Command := Result.Commands (Index);
                  begin
                     Command.Y := Command.Y - Shift;
                     Result.Commands.Replace_Element (Index, Command);
                  end;
               end loop;
               Result.Ascent := Long_Float'Max (0.0, Result.Ascent + Shift);
               Result.Descent := Long_Float'Max (0.0, Result.Descent - Shift);
               Result.Valid := True;
            end;
         when Poor_Bold_Node =>
            if Value.First = No_Node or else Value.Second /= No_Node or else
              Value.Third /= No_Node or else Value.Fourth /= No_Node or else
              Value.Poor_Bold_Class not in Ordinary | Binary_Atom |
                Relation_Atom or else
              Value.Poor_Bold_Shadow_X /= 0.02 or else
              Value.Poor_Bold_Shadow_Y /= 0.01 or else
              Value.Poor_Bold_Blur_Px /= 0.04
            then
               Reject ("invalid poor-man bold content or style");
            end if;
            Result := Compose
              (Item, Value.First, Level, Scale, Depth + 1, Thickness);
            for Index in Result.Commands.First_Index ..
              Result.Commands.Last_Index
            loop
               Poll (Thickness);
               declare
                  Command : Draw_Command := Result.Commands (Index);
               begin
                  Command.Has_Shadow := True;
                  Command.Shadow_X := Value.Poor_Bold_Shadow_X * Scale;
                  Command.Shadow_Y := Value.Poor_Bold_Shadow_Y * Scale;
                  Command.Shadow_Blur_Px := Value.Poor_Bold_Blur_Px;
                  Result.Commands.Replace_Element (Index, Command);
               end;
            end loop;
            Result.Valid := True;
         when Enclosed_Node =>
            if Value.First = No_Node then
               Reject ("enclosure has no content");
            end if;
            Result := Compose
              (Item, Value.First, Level, Scale, Depth + 1, Thickness);
            if Value.Enclosure in Color_Box_Enclosure |
              Framed_Color_Box_Enclosure
            then
               declare
                  Is_Framed : constant Boolean :=
                    Value.Enclosure = Framed_Color_Box_Enclosure;
                  Border_Thickness : constant Long_Float :=
                    (if Is_Framed then Long_Float'Max
                       (Value.Box_Border_Thickness, Thickness.Effective)
                     else 0.0) * Scale;
                  Pad : constant Long_Float := 0.3 * Scale;
                  Child_Commands : constant Command_Vectors.Vector :=
                    Result.Commands;
                  Background : Draw_Command;
                  Edge : Draw_Command;
                  Box_Width : constant Long_Float :=
                    Result.Width + 2.0 * (Pad + Border_Thickness);
                  Box_Height : constant Long_Float :=
                    Result.Ascent + Result.Descent +
                    2.0 * (Pad + Border_Thickness);
                  Content_X : constant Long_Float := Pad + Border_Thickness;
               begin
                  if not Result.Valid or else Box_Width < 0.0 or else
                    Box_Height < 0.0 or else Box_Width > Max_Geometry or else
                    Box_Height > Max_Geometry or else
                    abs (Box_Width) > Max_Geometry or else
                    abs (Box_Height) > Max_Geometry
                  then
                     Reject ("invalid color-box geometry");
                  end if;
                  Result.Commands.Clear;
                  Background.Kind := Rule_Command;
                  Background.Width := Box_Width;
                  Background.Height := Box_Height;
                  Background.X := 0.0;
                  Background.Y := -(Result.Ascent + Pad + Border_Thickness);
                  Background.Has_Color := True;
                  Background.Has_Clip := True;
                  Background.Clip_X := 0.0;
                  Background.Clip_Y := 0.0;
                  Background.Clip_W := Box_Width;
                  Background.Clip_H := Box_Height;
                  Background.Red := Value.Box_Background.Red;
                  Background.Green := Value.Box_Background.Green;
                  Background.Blue := Value.Box_Background.Blue;
                  Background.Alpha := Value.Box_Background.Alpha;
                  Append_Command (Result, Background, Thickness.Work);
                  for Command of Child_Commands loop
                     Poll (Thickness);
                     declare
                        Shifted : Draw_Command := Command;
                     begin
                        Shifted.X := Shifted.X + Content_X;
                        Append_Command (Result, Shifted, Thickness.Work);
                     end;
                  end loop;
                  if Is_Framed then
                     Edge.Kind := Rule_Command;
                     Edge.Has_Color := True;
                     Edge.Has_Clip := True;
                     Edge.Red := Value.Box_Border.Red;
                     Edge.Green := Value.Box_Border.Green;
                     Edge.Blue := Value.Box_Border.Blue;
                     Edge.Alpha := Value.Box_Border.Alpha;
                     Edge.Height := Border_Thickness;
                     Edge.Width := Box_Width;
                     Edge.X := 0.0;
                     Edge.Y := -(Result.Ascent + Pad + Border_Thickness);
                     Edge.Clip_X := 0.0;
                     Edge.Clip_Y := 0.0;
                     Edge.Clip_W := Edge.Width;
                     Edge.Clip_H := Edge.Height;
                     Append_Command (Result, Edge, Thickness.Work);
                     Edge.Y := Result.Descent + Pad;
                     Edge.Clip_Y := 0.0;
                     Append_Command (Result, Edge, Thickness.Work);
                     Edge.X := 0.0;
                     Edge.Y := -(Result.Ascent + Pad + Border_Thickness);
                     Edge.Width := Border_Thickness;
                     Edge.Height := Box_Height;
                     Edge.Clip_X := 0.0;
                     Edge.Clip_Y := 0.0;
                     Edge.Clip_W := Edge.Width;
                     Edge.Clip_H := Edge.Height;
                     Append_Command (Result, Edge, Thickness.Work);
                     Edge.X := Box_Width - Border_Thickness;
                     Edge.Clip_X := 0.0;
                     Append_Command (Result, Edge, Thickness.Work);
                  end if;
                  Result.Width := Box_Width;
                  Result.Ascent := Result.Ascent + Pad + Border_Thickness;
                  Result.Descent := Result.Descent + Pad + Border_Thickness;
                  Result.Valid := True;
               end;
            elsif Value.Enclosure = Phase_Enclosure then
               declare
                  Content_Commands : constant Command_Vectors.Vector :=
                    Result.Commands;
                  Rule : constant Long_Float :=
                    Long_Float'Max (0.06 * Scale,
                      Thickness.Effective * Scale);
                  Clearance : constant Long_Float := 0.35 * X_Height * Scale;
                  Total_Height : constant Long_Float :=
                    Result.Ascent + Result.Descent + Rule + Clearance;
                  View_Height : constant Natural := Natural
                    (Long_Float'Min (1_000_000.0,
                      Long_Float'Max (80.0,
                        Long_Float'Floor (Total_Height * 1_000.0))));
                  Path : constant Math_Paths.Path :=
                    Math_Stretchy.Phase_Path (View_Height);
                  Pad : constant Long_Float := Total_Height / 2.0 + Rule;
                  Angle : Draw_Command;
                  Scaled : Math_Paths.Path;
               begin
                  if not Result.Valid or else not Math_Paths.Is_Valid (Path)
                    or else Total_Height <= 0.0 or else
                    Total_Height > Max_Geometry or else
                    Pad + Result.Width > Max_Geometry
                  then
                     Reject ("invalid phase enclosure geometry");
                  end if;
                  Scaled := Math_Paths.Transform
                    (Path, 0.001 * Scale, 0.0, 0.0,
                     Scale / 1_000.0, 0.0, 0.0);
                  Result.Commands.Clear;
                  Angle.Kind := Path_Command;
                  Angle.Width := Pad + Result.Width;
                  Angle.Height := Total_Height;
                  Angle.Y := -Result.Ascent;
                  Angle.Has_Clip := True;
                  Angle.Clip_X := 0.0;
                  Angle.Clip_Y := 0.0;
                  Angle.Clip_W := Pad + Result.Width;
                  Angle.Clip_H := Total_Height;
                  for Segment in 1 .. Math_Paths.Count (Scaled) loop
                     Poll (Thickness);
                     Angle.Path_Data.Append
                       (Math_Paths.Element (Scaled, Segment));
                  end loop;
                  Append_Command (Result, Angle, Thickness.Work);
                  for Command of Content_Commands loop
                     Poll (Thickness);
                     declare
                        Shifted : Draw_Command := Command;
                     begin
                        Shifted.X := Shifted.X + Pad;
                        Append_Command (Result, Shifted, Thickness.Work);
                     end;
                  end loop;
                  Result.Width := Result.Width + Pad;
                  Result.Ascent := Result.Ascent;
                  Result.Descent := Result.Descent + Rule + Clearance;
                  Result.Valid := True;
               end;
            elsif Value.Enclosure = Actuarial_Enclosure then
               declare
                  Default_Rule : constant Long_Float :=
                    Style_Metric (Level, 0.04, 0.049, 0.049) * Scale;
                  Rule : constant Long_Float :=
                    Long_Float'Max (Default_Rule, Thickness.Minimum * Scale);
                  Side_Pad : constant Long_Float := 0.03889 * Scale;
                  Top_Pad : constant Long_Float := 4.0 * Rule;
                  Bottom_Pad : constant Long_Float :=
                    Long_Float'Max (0.0, 0.25 * Scale - Result.Descent);
                  Edge : Draw_Command;
               begin
                  if not Result.Valid or else Result.Width <= 0.0 or else
                    Result.Width + 2.0 * Side_Pad > Max_Geometry
                  then
                     Reject ("invalid actuarial enclosure geometry");
                  end if;
                  for Index in Result.Commands.First_Index ..
                    Result.Commands.Last_Index
                  loop
                     Poll (Thickness);
                     declare
                        Shifted : Draw_Command := Result.Commands (Index);
                     begin
                        Shifted.X := Shifted.X + Side_Pad;
                        Result.Commands.Replace_Element (Index, Shifted);
                     end;
                  end loop;
                  Edge.Kind := Rule_Command;
                  Edge.X := 0.0;
                  Edge.Y := -(Result.Ascent + Top_Pad);
                  Edge.Width := Result.Width + 2.0 * Side_Pad;
                  Edge.Height := Rule;
                  Append_Command (Result, Edge, Thickness.Work);
                  Edge.X := Result.Width + 2.0 * Side_Pad - Rule;
                  Edge.Y := -(Result.Ascent + Top_Pad);
                  Edge.Width := Rule;
                  Edge.Height := Result.Ascent + Result.Descent +
                    Top_Pad + Bottom_Pad;
                  Append_Command (Result, Edge, Thickness.Work);
                  Result.Width := Result.Width + 2.0 * Side_Pad;
                  Result.Ascent := Result.Ascent + Top_Pad;
                  Result.Descent := Result.Descent + Bottom_Pad;
                  Result.Valid := True;
               end;
            else
               declare
                  Stroke : constant Long_Float := Long_Float'Max
                    (0.066667 * Scale, Thickness.Effective * Scale);
               Pad : constant Long_Float :=
                 (if Is_Character_Box (Item, Value.First)
                  then 0.2 * Scale else 0.0);
               Geometry : Draw_Command;
               P : Math_Paths.Segment;
               X1 : constant Long_Float := -Pad;
               X2 : constant Long_Float := Result.Width + Pad;
               Y1 : constant Long_Float := -Result.Ascent - Pad;
               Y2 : constant Long_Float := Result.Descent + Pad;
               procedure Add_Point
                 (Kind : Math_Paths.Command_Kind; X, Y : Long_Float) is
               begin
                  P := (Kind => Kind,
                        First => (X => X, Y => Y),
                        Second => (others => 0.0), Third => (others => 0.0));
                  Geometry.Path_Data.Append (P);
               end Add_Point;
            begin
               Geometry.Kind := Path_Command;
               Geometry.Width := Result.Width + 2.0 * Pad;
               Geometry.Height := Result.Ascent + Result.Descent + 2.0 * Pad;
               if Value.Enclosure = Strike_Enclosure then
                  Geometry.Kind := Rule_Command;
                  Geometry.Y := -0.5 * X_Height * Scale - Stroke / 2.0;
                  Geometry.Width := Result.Width;
                  Geometry.Height := Stroke;
               else
                  declare
                     DX : constant Long_Float := X2 - X1;
                     DY : constant Long_Float := Y2 - Y1;
                     Length : constant Long_Float :=
                       Ada.Numerics.Long_Elementary_Functions.Sqrt
                         (DX * DX + DY * DY);
                     NX : constant Long_Float := -DY * Stroke / (2.0 * Length);
                     NY : constant Long_Float := DX * Stroke / (2.0 * Length);
                  begin
                     if Value.Enclosure in BCancel_Enclosure |
                       XCancel_Enclosure
                     then
                        Add_Point (Math_Paths.Move_To, X1 + NX, Y1 + NY);
                        Add_Point (Math_Paths.Line_To, X2 + NX, Y2 + NY);
                        Add_Point (Math_Paths.Line_To, X2 - NX, Y2 - NY);
                        Add_Point (Math_Paths.Line_To, X1 - NX, Y1 - NY);
                        Add_Point (Math_Paths.Close_Path, 0.0, 0.0);
                     end if;
                     if Value.Enclosure in Cancel_Enclosure |
                       XCancel_Enclosure
                     then
                        Add_Point (Math_Paths.Move_To, X1 - NX, Y2 + NY);
                        Add_Point (Math_Paths.Line_To, X2 - NX, Y1 + NY);
                        Add_Point (Math_Paths.Line_To, X2 + NX, Y1 - NY);
                        Add_Point (Math_Paths.Line_To, X1 + NX, Y2 - NY);
                        Add_Point (Math_Paths.Close_Path, 0.0, 0.0);
                     end if;
                  end;
                  Geometry.Height := Stroke;
               end if;
               --  The SVG extends beyond the content but TeX cancellation
               --  retains the original logical height/depth (enclose.js).
               Append_Command (Result, Geometry, Thickness.Work);
               Result.Valid := True;
            end;
            end if;
      end case;
      return Result;
   end Compose;

   function Build
     (Item : Math_Syntax.Document; Style : Math_Style := Text_Style;
      Work : Math_Work_Control.Context_Access := null) return Box is
   begin
      return Build (Item, Style, (others => <>), Work);
   end Build;

   function Build
     (Item : Math_Syntax.Document; Style : Math_Style;
      Settings : Layout_Settings;
      Work : Math_Work_Control.Context_Access := null) return Box
   is
      Result    : Box;
      Level     : constant Style_Level :=
        (if Style = Display_Style then Display_Level else Text_Level);
      Root_Id   : Node_Id;
      Root_Node : Math_Syntax.Node;
   begin
      Math_Work_Control.Poll (Work);
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
      if Root_Node.Kind not in Row_Node | Tagged_Node or else
        Root_Node.Next /= No_Node
      then
         Reject ("invalid document root");
      end if;
      if Settings.Max_Size > 100 then
         Reject ("maxSize must be in 1..100");
      end if;
      if Settings.Advance_Source /= null then
         if not Settings.Pixel_Em'Valid or else
           Settings.Pixel_Em /= Settings.Pixel_Em or else
           Settings.Pixel_Em <= 0.0 or else Settings.Pixel_Em > 256.0
         then
            Reject ("advance source requires pixel em in (0, 256]");
         end if;
      elsif not Settings.Pixel_Em'Valid or else Settings.Pixel_Em /= 0.0 then
         Reject ("pixel em requires an advance source");
      end if;
      if Settings.Min_Rule_Thickness < 0.0 or else
        Settings.Min_Rule_Thickness > 100.0 or else
        Settings.Min_Rule_Thickness /= Settings.Min_Rule_Thickness
      then
         Reject ("minRuleThickness must be finite and in 0..100");
      end if;
      Result := Compose
        (Item, Root_Id, Level, 1.0, 0,
         Rule_Parameters'(
           Minimum => Settings.Min_Rule_Thickness,
           Effective => Long_Float'Max (Default_Rule_Thickness,
             Settings.Min_Rule_Thickness),
           Work => Work, Pixel_Em => Settings.Pixel_Em,
           Advance_Source => Settings.Advance_Source));
      if Result.Width > Max_Geometry or else Result.Ascent > Max_Geometry
        or else Result.Descent > Max_Geometry
      then
         Reject ("layout geometry limit exceeded");
      end if;
      if Result.Commands.Length > Max_Draw_Commands then
         Reject ("draw-command limit exceeded");
      end if;
      for Command of Result.Commands loop
         Poll (Rule_Parameters'(Minimum => 0.0, Effective => 0.0,
           Work => Work, Pixel_Em => 0.0, Advance_Source => null));
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
            Italic        => 0.0,
            Left_Aligned => False,
            Left_Indent  => 0.0,
            Message       =>
              To_Unbounded_String (Ada.Exceptions.Exception_Message (E)),
            Commands => Command_Vectors.Empty_Vector);
         return Result;
   end Build;

end Math_Layout;
