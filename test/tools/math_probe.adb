with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Cairo;
with Glib;
with Cairo.Image_Surface;
with Cairo.Png;
with Cairo.Surface;
with Math_Layout;
with Math_Metrics;
with Math_Model;
with Math_Painter;
with Math_Syntax;

procedure Math_Probe is
   use type Cairo.Cairo_Status;
   use type Cairo.Cairo_Context;
   use type Cairo.Cairo_Surface;
   use type Math_Layout.Command_Kind;
   use type Math_Layout.Math_Style;
   use type Math_Model.Font_Kind;
   use Ada.Strings.Unbounded;

   --  Test-only global teardown, after every context/font owner is gone.
   --  Never suitable for the running application or concurrent clients.
   procedure Reset_Cairo_Caches
     with Import, Convention => C,
       External_Name => "cairo_debug_reset_static_data";
   procedure Finish_Fontconfig
     with Import, Convention => C, External_Name => "FcFini";

   Assertion_Count : Natural := 0;
   Failure_Count   : Natural := 0;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      Assertion_Count := Assertion_Count + 1;
      if Condition then
         Ada.Text_IO.Put_Line ("ok " & Label);
      else
         Failure_Count := Failure_Count + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;

   function Parsed (Source : String) return Math_Syntax.Document is
   begin
      return Math_Syntax.Parse (Source);
   end Parsed;

   function Laid_Out
     (Source : String;
      Style  : Math_Layout.Math_Style := Math_Layout.Text_Style)
      return Math_Layout.Box is
   begin
      return Math_Layout.Build (Parsed (Source), Style);
   end Laid_Out;

   function Glyph_Count (Box : Math_Layout.Box) return Natural is
      Result : Natural := 0;
   begin
      if not Box.Commands.Is_Empty then
         for Index in Box.Commands.First_Index .. Box.Commands.Last_Index loop
            if Box.Commands (Index).Kind = Math_Layout.Glyph_Command then
               Result := Result + 1;
            end if;
         end loop;
      end if;
      return Result;
   end Glyph_Count;

   function Has_Glyph
     (Box   : Math_Layout.Box;
      Point : Natural;
      Font  : Math_Model.Font_Kind) return Boolean is
   begin
      if not Box.Commands.Is_Empty then
         for Index in Box.Commands.First_Index .. Box.Commands.Last_Index loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Box.Commands (Index);
            begin
               if Command.Kind = Math_Layout.Glyph_Command and then
                 Command.Code_Point = Point and then Command.Font = Font
               then
                  return True;
               end if;
            end;
         end loop;
      end if;
      return False;
   end Has_Glyph;

   function Has_Fraction_Clearance (Box : Math_Layout.Box) return Boolean is
      Bar_Y : Long_Float := 0.0;
      Bar_Height : Long_Float := 0.0;
      Numerator_Bottom : Long_Float := Long_Float'First;
      Denominator_Top : Long_Float := Long_Float'Last;
      Found_Rule : Boolean := False;
      Found_Numerator : Boolean := False;
      Found_Denominator : Boolean := False;
   begin
      if not Box.Commands.Is_Empty then
         for Index in Box.Commands.First_Index .. Box.Commands.Last_Index loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Box.Commands (Index);
            begin
               if Command.Kind = Math_Layout.Rule_Command then
                  Bar_Y := Command.Y;
                  Bar_Height := Command.Height;
                  Found_Rule := True;
               elsif Command.Kind = Math_Layout.Glyph_Command then
                  declare
                     Metric : constant Math_Metrics.Glyph_Metric :=
                       Math_Metrics.Lookup (Command.Font, Command.Code_Point);
                     Ink_Top : constant Long_Float :=
                       Command.Y - Metric.Ascent * Command.Scale;
                     Ink_Bottom : constant Long_Float :=
                       Command.Y + Metric.Descent * Command.Scale;
                  begin
                     if Command.Y < 0.0 then
                        Numerator_Bottom := Long_Float'Max
                          (Numerator_Bottom, Ink_Bottom);
                        Found_Numerator := True;
                     elsif Command.Y > 0.0 then
                        Denominator_Top := Long_Float'Min
                          (Denominator_Top, Ink_Top);
                        Found_Denominator := True;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end if;
      return Found_Rule and then Found_Numerator and then
        Found_Denominator and then
        Numerator_Bottom <= Bar_Y - 0.04 + 0.000001 and then
        Denominator_Top >= Bar_Y + Bar_Height + 0.04 - 0.000001;
   end Has_Fraction_Clearance;

   function Has_Rule (Box : Math_Layout.Box) return Boolean is
   begin
      if not Box.Commands.Is_Empty then
         for Index in Box.Commands.First_Index .. Box.Commands.Last_Index loop
            if Box.Commands (Index).Kind = Math_Layout.Rule_Command then
               return True;
            end if;
         end loop;
      end if;
      return False;
   end Has_Rule;

   function Rule_Y (Box : Math_Layout.Box) return Long_Float is
   begin
      if not Box.Commands.Is_Empty then
         for Index in Box.Commands.First_Index .. Box.Commands.Last_Index loop
            if Box.Commands (Index).Kind = Math_Layout.Rule_Command then
               return Box.Commands (Index).Y;
            end if;
         end loop;
      end if;
      return 0.0;
   end Rule_Y;

   function Has_Scale
     (Box   : Math_Layout.Box;
      Scale : Long_Float) return Boolean is
   begin
      if not Box.Commands.Is_Empty then
         for Index in Box.Commands.First_Index .. Box.Commands.Last_Index loop
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Box.Commands (Index);
            begin
               if Command.Kind = Math_Layout.Glyph_Command and then
                 abs (Command.Scale - Scale) < 0.000001
               then
                  return True;
               end if;
            end;
         end loop;
      end if;
      return False;
   end Has_Scale;

   procedure Check_Accepted (Source, Label : String) is
      Item : constant Math_Syntax.Document := Parsed (Source);
      Box  : constant Math_Layout.Box := Math_Layout.Build (Item);
   begin
      Check (Math_Syntax.Is_Valid (Item), Label & " parses");
      Check (Box.Valid, Label & " lays out");
   end Check_Accepted;

   procedure Check_Rejected
     (Source   : String;
      Position : Natural;
      Label    : String) is
      Item : constant Math_Syntax.Document := Parsed (Source);
   begin
      Check (not Math_Syntax.Is_Valid (Item), Label & " rejected");
      Check (Math_Syntax.Error_Position (Item) = Position,
        Label & " byte position");
      Check (Math_Syntax.Source (Item) = Source,
        Label & " source retained");
      Check (not Math_Layout.Build (Item).Valid,
        Label & " layout rejected");
      Check (Math_Syntax.Count (Item) = 0,
        Label & " has no retained nodes");
   end Check_Rejected;

   procedure Test_Syntax_And_Layout is
      Item : Math_Syntax.Document;
      Box  : Math_Layout.Box;
      Lower_Bound_Source : String (7 .. 9) := (others => ' ');
      Wide : Math_Layout.Box;
      Text_Fraction : Math_Layout.Box;
      Display_Fraction : Math_Layout.Box;
      Text_Sum : Math_Layout.Box;
      Nested_Scripts : Math_Layout.Box;
      Formula : constant String := [1 .. 2_048 => 'x'];
      Too_Long : constant String :=
        [1 .. Math_Syntax.Max_Source_Bytes + 1 => 'x'];
      At_Limit : String (1 .. Math_Syntax.Max_Source_Bytes) :=
        [others => ' '];
      Deep : Unbounded_String;
   begin
      Lower_Bound_Source (7 .. 9) := "x+y";
      Check_Accepted ("x+y=2", "basic operators");
      Check_Accepted ("  x" & Character'Val (9) & "+" &
        Character'Val (13) & Character'Val (10) & "y  ",
        "ASCII whitespace");
      Check_Accepted ("x+y   ", "trailing spaces");
      Check_Accepted ("  \alpha   ", "Greek with surrounding whitespace");
      Check_Accepted ("  \times   ", "operator with surrounding whitespace");
      Check_Accepted ("(x+[y])", "groups and brackets");
      Item := Parsed (Lower_Bound_Source);
      Check (Math_Syntax.Is_Valid (Item), "non-1-based source parses");
      Check (Math_Syntax.Source (Item) = "x+y",
        "non-1-based source bytes retained");
      Check_Accepted ("x^2_3", "superscript then subscript");
      Check_Accepted ("x_3^2", "subscript then superscript");
      Check_Accepted ("\frac{a+b}{c}", "fraction");
      Check_Accepted ("\frac{1}{\sqrt{x+1}}", "nested fraction root");
      Check_Accepted ("\dfrac{a}{b}", "display fraction alias");
      Check_Accepted ("\tfrac{a}{b}", "text fraction alias");
      Check (Laid_Out ("\dfrac{a}{b}").Width >
        Laid_Out ("\tfrac{a}{b}").Width,
        "fraction aliases select distinct styles");
      Check_Accepted ("\sqrt{\frac{x}{y}}", "nested root fraction");
      Check_Accepted ("\alpha+\Gamma", "Greek symbols");
      Check_Accepted ("\infty+1", "infinity");
      Check_Accepted ("\times \cdot \pm \le \ge", "named ops");
      Check_Accepted ("\ne", "not-equal composite symbol");
      Check_Accepted ("\sum_{i=1}^n i", "text-style sum scripts");
      Check_Accepted ("\sin(x)+\log(y)", "function names");
      Check_Accepted ("\frac{}{}", "blank fraction groups");
      Check_Accepted ("\sqrt{}", "blank radical group");
      Check_Accepted ("{}", "blank group");

      Check_Rejected ("x+\bogus", 3, "unknown macro");
      Check_Accepted ("\begin{matrix}x\end{matrix}",
        "matrix environment");
      Check_Rejected ("$x$", 1, "dollar delimiters");
      Check_Rejected ("x+{y", 5, "unclosed group");
      Check_Rejected ("x^a^b", 4, "duplicate superscript");
      Check_Rejected ("x_a_b", 4, "duplicate subscript");
      Check_Rejected ("x^", 3, "missing superscript argument");
      Check_Rejected ("\frac{x}", 9, "missing fraction argument");
      Check_Rejected ("x}", 2, "extra closing brace");
      Check_Accepted ("\sqrt[3]{x}", "indexed root");
      Check_Rejected ("x" & Character'Val (16#C3#) &
        Character'Val (16#A9#), 2, "UTF-8 source byte");
      Check_Rejected ("a" & Character'Val (0) & "b", 2, "NUL byte");
      Item := Parsed ("a" & Character'Val (0) & "b");
      Check (Math_Syntax.Source (Item) = "a" & Character'Val (0) & "b",
        "NUL source retained exactly");
      At_Limit (At_Limit'First) := 'x';
      Item := Parsed (At_Limit);
      Check (Math_Syntax.Is_Valid (Item), "maximum source length accepted");
      Check (Math_Syntax.Source (Item) = At_Limit,
        "maximum-length source retained");
      Item := Parsed (Too_Long);
      Check (not Math_Syntax.Is_Valid (Item), "source limit rejected");
      Check (Math_Syntax.Error_Position (Item) =
        Math_Syntax.Max_Source_Bytes + 1, "source limit position");
      Check (Math_Syntax.Source (Item)'Length = Math_Syntax.Max_Source_Bytes,
        "oversized source retention is bounded");
      Check (Math_Syntax.Count (Item) = 0,
        "oversized source has no retained nodes");

      Deep := Null_Unbounded_String;
      for Index in 1 .. Math_Syntax.Max_Depth + 2 loop
         Append (Deep, "\sqrt{");
      end loop;
      Append (Deep, "x");
      for Index in 1 .. Math_Syntax.Max_Depth + 2 loop
         Append (Deep, "}");
      end loop;
      Item := Parsed (To_String (Deep));
      Check (not Math_Syntax.Is_Valid (Item), "depth limit rejected");
      Check (Math_Syntax.Error (Item)'Length > 0, "depth error reported");

      Item := Parsed (Formula);
      Check (not Math_Syntax.Is_Valid (Item), "node budget rejected");
      Check (Math_Syntax.Error (Item)'Length > 0, "node budget error");

      Box := Laid_Out ("x");
      Check (Box.Valid, "single glyph valid");
      Check (abs (Box.Width - Math_Metrics.Lookup
        (Math_Model.Math_Italic, Character'Pos ('x')).Width) < 0.000001,
        "numeric glyph metric width");
      Check (abs (Laid_Out ("x+y").Width -
        (Math_Metrics.Lookup (Math_Model.Math_Italic,
           Character'Pos ('x')).Width +
         Math_Metrics.Lookup (Math_Model.Main_Regular,
           Character'Pos ('+')).Width + 8.0 / 18.0 +
         Math_Metrics.Lookup (Math_Model.Math_Italic,
           Character'Pos ('y')).Width)) < 0.000001,
        "binary spacing is 4/18 em on each side");
      Check (Has_Glyph (Laid_Out ("+x"), Character'Pos ('+'),
        Math_Model.Main_Regular), "unary plus uses regular font");
      Check (Has_Glyph (Laid_Out ("x=y"), Character'Pos ('='),
        Math_Model.Main_Regular), "relation equals uses regular font");
      Check (Math_Metrics.Lookup (Math_Model.Main_Regular,
        Character'Pos ('=')).Descent < 0.0,
        "negative font depth metric retained");
      Check (abs (Laid_Out ("{xy}").Width -
        Laid_Out ("xy").Width) < 0.000001, "group width equivalence");
      Check (abs (Laid_Out ("+x").Width -
        (Laid_Out ("+").Width + Laid_Out ("x").Width)) < 0.000001,
        "unary plus has no binary spacing");

      Text_Fraction := Laid_Out ("\frac{a}{b}");
      Display_Fraction := Laid_Out
        ("\frac{a}{b}", Math_Layout.Display_Style);
      Check (Text_Fraction.Valid and Has_Rule (Text_Fraction),
        "fraction rule exists");
      Check (Rule_Y (Text_Fraction) < 0.0, "fraction bar above baseline");
      Check (Has_Fraction_Clearance (Text_Fraction),
        "fraction numerator and denominator clear bar");
      Check (Has_Fraction_Clearance (Display_Fraction),
        "display fraction ink clears bar");
      Check (Text_Fraction.Ascent > 0.0 and
        Text_Fraction.Descent > 0.0, "fraction numerator denominator");
      Check (Display_Fraction.Width > Text_Fraction.Width,
        "display fraction enlarged");
      Check (Laid_Out ("\sum_i^n", Math_Layout.Display_Style).Valid,
        "display sum limits supported");

      Box := Laid_Out ("x^2");
      Check (Has_Scale (Box, 0.7), "script scale is 0.7");
      Nested_Scripts := Laid_Out ("x^{y^z}");
      Check (Has_Scale (Nested_Scripts, 0.7) and
        Has_Scale (Nested_Scripts, 0.5), "nested script scales");
      Check (not Has_Scale (Nested_Scripts, 0.35),
        "nested script scale floor");
      Check (Nested_Scripts.Ascent > Laid_Out ("x").Ascent and
        Nested_Scripts.Descent = Laid_Out ("x").Descent,
        "superscript extends above the base");
      Nested_Scripts := Laid_Out ("x_3");
      Check (Nested_Scripts.Descent > Laid_Out ("x").Descent,
        "subscript extends below the base");
      Nested_Scripts := Laid_Out ("x^2_3");
      Check (Nested_Scripts.Ascent > 0.0 and
        Nested_Scripts.Descent > 0.0,
        "combined scripts preserve both vertical extents");
      Box := Laid_Out ("\alpha+\Gamma");
      Check (Has_Glyph (Box, 16#03B1#, Math_Model.Math_Italic),
        "lowercase Greek exact code point");
      Check (Has_Glyph (Box, 16#0393#, Math_Model.Main_Regular),
        "uppercase Greek exact code point");
      Check (Has_Glyph (Laid_Out ("\infty"), 16#221E#,
        Math_Model.Main_Regular), "infinity font mapping");
      Check (Has_Glyph (Laid_Out ("\epsilon"), 16#03F5#,
        Math_Model.Math_Italic), "epsilon math-italic mapping");
      Check (Has_Glyph (Laid_Out ("\times"), 16#00D7#,
        Math_Model.Main_Regular), "times operator exact font mapping");
      Check (Has_Glyph (Laid_Out ("\le"), 16#2264#,
        Math_Model.Main_Regular), "less-equal operator exact font mapping");
      Check (Glyph_Count (Laid_Out ("\sin(x)")) = 6,
        "function output glyphs");

      Deep := Null_Unbounded_String;
      for Index in 1 .. 16 loop
         Append (Deep, "\sqrt{");
      end loop;
      Append (Deep, "x");
      for Index in 1 .. 16 loop
         Append (Deep, "}");
      end loop;
      Wide := Laid_Out (To_String (Deep));
      Check (not Wide.Valid, "oversized radical fails");
      Check (Wide.Commands.Is_Empty, "radical failure has no commands");

      Ada.Text_IO.Put_Line
        ("METRIC x width=" & Long_Float'Image (Laid_Out ("x").Width) &
         " ascent=" & Long_Float'Image (Laid_Out ("x").Ascent) &
         " descent=" & Long_Float'Image (Laid_Out ("x").Descent));
      Ada.Text_IO.Put_Line
        ("METRIC frac text width=" & Long_Float'Image
          (Text_Fraction.Width) & " display width=" & Long_Float'Image
          (Display_Fraction.Width) & " ascent=" & Long_Float'Image
          (Display_Fraction.Ascent) & " descent=" & Long_Float'Image
          (Display_Fraction.Descent));
      Text_Sum := Laid_Out ("\sum_{i=1}^n i");
      Ada.Text_IO.Put_Line
        ("METRIC sum width=" & Long_Float'Image (Text_Sum.Width) &
         " ascent=" & Long_Float'Image (Text_Sum.Ascent) &
         " descent=" & Long_Float'Image (Text_Sum.Descent));
      for Index in 1 .. 3 loop
         declare
            Source : constant String :=
              (if Index = 1 then "x" else "\frac{a}{b}");
            Mode : constant Math_Layout.Math_Style :=
              (if Index = 3 then Math_Layout.Display_Style
               else Math_Layout.Text_Style);
            Value : constant Math_Layout.Box := Laid_Out (Source, Mode);
         begin
            Ada.Text_IO.Put_Line
              ("REFERENCE|" & Source & "|" &
               (if Index = 3 then "display" else "text") & "|" &
               Long_Float'Image (Value.Ascent) & "|" &
               Long_Float'Image (Value.Descent));
         end;
      end loop;
   end Test_Syntax_And_Layout;

   procedure Check_Cairo
     (Context : Cairo.Cairo_Context;
      Surface : Cairo.Cairo_Surface) is
   begin
      Check (Cairo.Status (Context) = Cairo.Cairo_Status_Success,
        "Cairo context status");
      Check (Cairo.Surface.Status (Surface) = Cairo.Cairo_Status_Success,
        "Cairo surface status");
   end Check_Cairo;

   procedure Caption
     (Context : Cairo.Cairo_Context;
      Text    : String;
      X       : Long_Float;
      Y       : Long_Float;
      Size    : Long_Float) is
   begin
      Cairo.Select_Font_Face
        (Context, "sans-serif", Cairo.Cairo_Font_Slant_Normal,
         Cairo.Cairo_Font_Weight_Normal);
      Cairo.Set_Font_Size (Context, Glib.Gdouble (Size));
      Cairo.Move_To (Context, Glib.Gdouble (X), Glib.Gdouble (Y));
      Cairo.Show_Text (Context, Text);
   end Caption;

   procedure Render_Sheet is
      Fonts   : Math_Painter.Font_Set;
      Surface : Cairo.Cairo_Surface := Cairo.Image_Surface.Create
        (Cairo.Image_Surface.Cairo_Format_ARGB32, 1_200, 1_900);
      Context : Cairo.Cairo_Context := Cairo.Create (Surface);
      type Sample_Array is
        array (Positive range 1 .. 20) of Unbounded_String;
      Samples : constant Sample_Array :=
        [To_Unbounded_String ("x+y=2"),
         To_Unbounded_String ("x^2_3 + y_1^n"),
         To_Unbounded_String ("\frac{a+b}{c}"),
         To_Unbounded_String ("\sqrt{1+x^2}"),
         To_Unbounded_String ("\alpha+\Gamma+\infty"),
         To_Unbounded_String ("\sum_{i=1}^n i"),
         To_Unbounded_String ("\sin(x)+\log(y)"),
         To_Unbounded_String ("\frac{1}{\sqrt{x+1}}"),
         To_Unbounded_String ("\sqrt{\frac{x}{y}}"),
         To_Unbounded_String ("\frac{}{}"),
         To_Unbounded_String ("\begin{pmatrix}a&b\\c&d\end{pmatrix}"),
         To_Unbounded_String ("\begin{cases}x&x>0\\-x&x\le0\end{cases}"),
         To_Unbounded_String ("\begin{aligned}a&=b+c\\d&=e+f\end{aligned}"),
         To_Unbounded_String ("\mathbb{R}+\mathcal{L}"),
         To_Unbounded_String ("\hat{x}+\bar{y}+\vec{z}"),
         To_Unbounded_String ("\left\| x \right\|"),
         To_Unbounded_String ("\left( x \right)"),
         To_Unbounded_String ("\left\{x\right\}"),
         To_Unbounded_String ("\begin{Vmatrix}a&b\\c&d\end{Vmatrix}"),
         To_Unbounded_String ("\sum_{i=1}^n i")];
      Em : constant Long_Float := 32.0;

      procedure Draw_With_Local_Fonts (Item : Math_Layout.Box) is
         Local_Fonts : Math_Painter.Font_Set;
      begin
         Math_Painter.Load
           (Local_Fonts, Ada.Command_Line.Argument (1));
         Math_Painter.Draw (Local_Fonts, Context, Item, 42.0, 840.0, Em);
      end Draw_With_Local_Fonts;
   begin
      if Ada.Command_Line.Argument_Count /= 2 then
         raise Constraint_Error with
           "usage: math_probe FONT_DIRECTORY OUTPUT.png";
      end if;
      Check (Cairo.Surface.Status (Surface) = Cairo.Cairo_Status_Success,
        "review image created");
      Check (Cairo.Status (Context) = Cairo.Cairo_Status_Success,
        "review context created");
      Math_Painter.Load (Fonts, Ada.Command_Line.Argument (1));
      Cairo.Set_Source_Rgb (Context, 1.0, 1.0, 1.0);
      Cairo.Paint (Context);
      Cairo.Set_Source_Rgb (Context, 0.08, 0.10, 0.16);
      Caption (Context, "Coyote native math production review sheet", 36.0,
        38.0, 24.0);
      Caption
        (Context,
         "Formula glyphs use exact KaTeX font faces; captions are prose.",
         36.0, 62.0, 14.0);
      for Index in Samples'Range loop
         declare
            Column : constant Long_Float :=
              (if Index mod 2 = 1 then 42.0 else 642.0);
            Row : constant Long_Float :=
              Long_Float ((Index - 1) / 2) * 180.0 + 104.0;
            Style : constant Math_Layout.Math_Style :=
              (if Index in 3 | 20 then Math_Layout.Display_Style
               else Math_Layout.Text_Style);
            Size : constant Long_Float :=
              (if Style = Math_Layout.Display_Style then 48.0 else Em);
            Item : constant Math_Syntax.Document :=
              Parsed (To_String (Samples (Index)));
            Box : constant Math_Layout.Box := Math_Layout.Build (Item, Style);
         begin
            if not Box.Valid then
               raise Constraint_Error with
                 "review sample failed layout: " &
                 To_String (Samples (Index));
            end if;
            Caption (Context, To_String (Samples (Index)),
              Column, Row, 13.0);
            Cairo.Set_Source_Rgb (Context, 0.05, 0.05, 0.08);
            Math_Painter.Draw
              (Fonts, Context, Box, Column, Row + 68.0, Size);
            Cairo.Set_Source_Rgb (Context, 0.55, 0.58, 0.64);
            Cairo.Move_To (Context, Glib.Gdouble (Column),
              Glib.Gdouble (Row + 92.0));
            Cairo.Line_To (Context, Glib.Gdouble (Column + 520.0),
              Glib.Gdouble (Row + 92.0));
            Cairo.Stroke (Context);
            Cairo.Set_Source_Rgb (Context, 0.30, 0.32, 0.38);
            Caption (Context, "The surrounding prose baseline is shown.",
              Column, Row + 126.0, 13.0);
            Ada.Text_IO.Put_Line
              ("SHEET " & To_String (Samples (Index)) & " width=" &
               Long_Float'Image (Box.Width * Size) & " px at em=" &
               Long_Float'Image (Size));
         end;
      end loop;
      Draw_With_Local_Fonts (Laid_Out ("\alpha+x_2"));
      Check_Cairo (Context, Surface);
      Cairo.Move_To (Context, 42.0, 900.0);
      Cairo.Line_To (Context, 80.0, 900.0);
      Cairo.Stroke (Context);
      Check_Cairo (Context, Surface);
      declare
         Result : constant Cairo.Cairo_Status := Cairo.Png.Write_To_Png
           (Surface, Ada.Command_Line.Argument (2));
      begin
         Check (Result = Cairo.Cairo_Status_Success, "PNG write status");
         if Result /= Cairo.Cairo_Status_Success then
            raise Constraint_Error with "Cairo PNG write failed";
         end if;
      end;
      Check_Cairo (Context, Surface);
      Cairo.Destroy (Context);
      Context := Cairo.Null_Context;
      Cairo.Surface.Destroy (Surface);
      Surface := Cairo.Null_Surface;
   exception
      when others =>
         if Context /= Cairo.Null_Context then
            Cairo.Destroy (Context);
         end if;
         if Surface /= Cairo.Null_Surface then
            Cairo.Surface.Destroy (Surface);
         end if;
         raise;
   end Render_Sheet;

begin
   Test_Syntax_And_Layout;
   if Failure_Count = 0 then
      Render_Sheet;
   end if;
   Reset_Cairo_Caches;
   Finish_Fontconfig;
   Ada.Text_IO.Put_Line
     ("ASSERTIONS " & Natural'Image (Assertion_Count) &
      " failures=" & Natural'Image (Failure_Count));
   if Failure_Count > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "FATAL " & Ada.Exceptions.Exception_Information (Error));
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "ASSERTIONS " & Natural'Image (Assertion_Count) &
         " failures=" & Natural'Image (Failure_Count));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Math_Probe;
