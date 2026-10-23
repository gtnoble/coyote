with AUnit.Test_Caller;
--  Coyote_Math_Tests body.

with AUnit.Assertions;
with Ada.Containers;
with Cairo;
with Cairo.Image_Surface;
with Cairo.Surface;
with Coyote_Math_Resources;
with Math_Layout;
with Math_Metrics;
with Math_Model;
with Math_Painter;
with Math_Syntax;

package body Coyote_Math_Tests is

   use AUnit.Assertions;
   use Math_Layout;
   use Math_Model;
   use Math_Syntax;
   use type Ada.Containers.Count_Type;
   use type Cairo.Cairo_Status;
   use type Cairo.Cairo_Surface;
   use type Cairo.Cairo_Context;
   procedure Test_Parse_Simple_Glyph (T : in out Test) is
      pragma Unreferenced (T);
      Parsed    : constant Document := Parse ("x");
      Root_Node : Node;
   begin
      Assert (Is_Valid (Parsed), "simple glyph parses");
      Assert (Source (Parsed) = "x", "source is retained");
      Assert (Root (Parsed) > No_Node, "root node is present");
      Assert (Count (Parsed) >= 2, "row and glyph nodes are present");
      Root_Node := Element (Parsed, Positive (Root (Parsed)));
      Assert (Root_Node.Kind = Row_Node, "document root is a row");
      Assert (Root_Node.First > No_Node, "root links to its glyph");
      Assert
        (Element (Parsed, Positive (Root_Node.First)).Code_Point = 120,
         "glyph code point is x");
   end Test_Parse_Simple_Glyph;

   procedure Test_Parse_Empty_And_Unknown (T : in out Test) is
      pragma Unreferenced (T);
      Empty   : constant Document := Parse ("");
      Unknown : constant Document := Parse ("\unknown");
   begin
      Assert (not Is_Valid (Empty), "empty input is rejected");
      Assert (Error_Position (Empty) = 1, "empty error starts at byte 1");
      Assert (not Is_Valid (Unknown), "unknown command is rejected");
      Assert
        (Error (Unknown)'Length > 0 and then Error_Position (Unknown) = 1,
         "unknown command reports an error at byte 1");
      Assert (Count (Unknown) = 0, "failed parse retains no partial nodes");
   end Test_Parse_Empty_And_Unknown;

   procedure Test_Parse_Oversized_Prefix (T : in out Test) is
      pragma Unreferenced (T);
      Input  : constant String (1 .. Max_Source_Bytes + 1) := (others => 'x');
      Parsed : constant Document                           := Parse (Input);
   begin
      Assert (not Is_Valid (Parsed), "oversized input is rejected");
      Assert
        (Source (Parsed) = Input (Input'First .. Input'Last - 1),
         "only the bounded source prefix is retained");
      Assert
        (Error_Position (Parsed) = Max_Source_Bytes + 1,
         "limit error points after maximum source bytes");
   end Test_Parse_Oversized_Prefix;

   procedure Test_Parse_Deterministic_Malformed_Input (T : in out Test) is
      pragma Unreferenced (T);
      Alphabet : constant String := "{}[]^_\&%# abc012";
      Input    : String (1 .. 48);
      First    : Document;
      Again    : Document;
   begin
      for Case_Number in 1 .. 40 loop
         for Index in Input'Range loop
            Input (Index) :=
              Alphabet
                (((Index * 17 + Case_Number * 29) mod Alphabet'Length) + 1);
         end loop;
         First := Parse (Input);
         Again := Parse (Input);
         Assert
           (Is_Valid (First) = Is_Valid (Again),
            "same generated input has stable validity");
         Assert
           (Error (First) = Error (Again)
            and then Error_Position (First) = Error_Position (Again),
            "same generated input has stable diagnostics");
         Assert
           (Count (First) = Count (Again),
            "same generated input has stable node count");
      end loop;
   end Test_Parse_Deterministic_Malformed_Input;

   procedure Test_Parse_MathML_Is_Not_Accepted (T : in out Test) is
      pragma Unreferenced (T);
      Parsed : constant Document := Parse ("<math><mi>x</mi></math>");
   begin
      Assert (not Is_Valid (Parsed), "markup is not parsed as math syntax");
      Assert
        (Error (Parsed) = "XML-like markup is not supported as math syntax",
         "markup rejection gives an explicit diagnostic");
      Assert
        (Is_Valid (Parse ("x<y")),
         "less-than remains valid mathematical input");
   end Test_Parse_MathML_Is_Not_Accepted;

   procedure Test_Metrics_Known_And_Unknown_Glyph (T : in out Test) is
      pragma Unreferenced (T);
      Known   : constant Math_Metrics.Glyph_Metric :=
        Math_Metrics.Lookup (Main_Regular, 65);
      Missing : constant Math_Metrics.Glyph_Metric :=
        Math_Metrics.Lookup (Main_Regular, 16#10_FFFF#);
   begin
      Assert (Known.Found, "capital A has a metric");
      Assert (abs (Known.Width - 0.75) < 0.000_001, "A width matches data");
      Assert (not Missing.Found, "unknown code point has no metric");
   end Test_Metrics_Known_And_Unknown_Glyph;

   procedure Test_Layout_Simple_Glyph (T : in out Test) is
      pragma Unreferenced (T);
      Parsed : constant Document := Parse ("x");
      Layout : constant Box      := Build (Parsed);
   begin
      Assert (Layout.Valid, "simple glyph lays out");
      Assert (Layout.Width > 0.0, "glyph has positive width");
      Assert (Layout.Ascent > 0.0, "glyph has positive ascent");
      Assert
        (not Layout.Commands.Is_Empty
         and then Layout.Commands.First_Element.Code_Point =
           Character'Pos ('x'),
         "layout emits x glyph command");
   end Test_Layout_Simple_Glyph;

   procedure Test_Layout_Script_Scale_And_Geometry (T : in out Test) is
      pragma Unreferenced (T);
      Parsed     : constant Document := Parse ("x^2_3");
      Layout     : constant Box      := Build (Parsed);
      Saw_Script : Boolean           := False;
   begin
      Assert (Layout.Valid, "superscript and subscript lay out");
      for Index in Layout.Commands.First_Index .. Layout.Commands.Last_Index
      loop
         declare
            Command : constant Draw_Command := Layout.Commands (Index);
         begin
            if Command.Code_Point = Character'Pos ('2')
              or else Command.Code_Point = Character'Pos ('3')
            then
               Saw_Script := True;
               Assert (Command.Scale < 1.0, "script glyph is scaled down");
               Assert (abs Command.Y > 0.0, "script has displaced baseline");
            end if;
         end;
      end loop;
      Assert (Saw_Script, "script glyph commands are present");
      Assert (Layout.Width > 0.0, "script box has positive width");
      Assert
        (Layout.Ascent > 0.0 and then Layout.Descent > 0.0,
         "both script directions contribute box extents");
   end Test_Layout_Script_Scale_And_Geometry;

   procedure Test_Layout_Wide_Limit_Geometry (T : in out Test) is
      pragma Unreferenced (T);
      Numerical : constant Box :=
        Build (Parse ("\sum_{i=0}^{n+100} x"), Display_Style);
      Wide_Sup  : constant Box        :=
        Build (Parse ("\sum\limits_{i=0}^{nnnnnn}"), Display_Style);
      Wide_Sub  : constant Box        :=
        Build (Parse ("\sum\limits_{nnnnnn}^{n}"), Display_Style);
      Tolerance : constant Long_Float := 0.000_001;
      procedure Check_Bounds (Layout : Box) is
      begin
         for Command of Layout.Commands loop
            Assert (Command.X >= 0.0, "limit command origin is nonnegative");
            Assert
              (Command.X + Command.Width <= Layout.Width + Tolerance,
               "limit command right edge is within measured width");
         end loop;
      end Check_Bounds;
   begin
      Assert
        (Wide_Sup.Valid and then Wide_Sub.Valid,
         "wide superscript and subscript limits lay out");
      Assert
        (abs (Wide_Sup.Width - Wide_Sub.Width) < Tolerance,
         "wider upper and lower limit groups have equal measured widths");
      Check_Bounds (Wide_Sup);
      Check_Bounds (Wide_Sub);
      Assert (Numerical.Valid, "numeric wide limit expression lays out");
      Check_Bounds (Numerical);
   end Test_Layout_Wide_Limit_Geometry;

   procedure Test_Layout_Radical_Index_Glyph (T : in out Test) is
      pragma Unreferenced (T);
      Parsed        : constant Document := Parse ("\sqrt[3]{x}");
      Layout        : constant Box      := Build (Parsed);
      Found_Radical : Boolean           := False;
      Found_Index   : Boolean           := False;
      Found_Rule    : Boolean           := False;
   begin
      Assert (Is_Valid (Parsed), "indexed radical parses");
      Assert (Layout.Valid, "indexed radical lays out");
      for Index in Layout.Commands.First_Index .. Layout.Commands.Last_Index
      loop
         declare
            Command : constant Draw_Command := Layout.Commands (Index);
         begin
            if Command.Kind = Glyph_Command
              and then Command.Code_Point = 16#221A#
            then
               Found_Radical := True;
            elsif Command.Kind = Glyph_Command
              and then Command.Code_Point = Character'Pos ('3')
            then
               Found_Index := True;
            elsif Command.Kind = Rule_Command then
               Found_Rule := True;
            end if;
         end;
      end loop;
      Assert (Found_Radical, "radical sign command is emitted");
      Assert (Found_Index, "root index glyph is emitted");
      Assert (Found_Rule, "radical overbar rule is emitted");
   end Test_Layout_Radical_Index_Glyph;

   procedure Test_Layout_Requested_Engine_Features (T : in out Test) is
      pragma Unreferenced (T);
      Radical     : constant Box      := Build (Parse ("\sqrt[3]{x}"));
      Dfrac       : constant Box      := Build (Parse ("\dfrac{1}{2}"));
      Tfrac       : constant Box      := Build (Parse ("\tfrac{1}{2}"));
      Limits      : constant Box      :=
        Build (Parse ("\sum\limits_{i=0}^{n}"), Display_Style);
      Side : constant Box := Build (Parse ("\int_{0}^{1}"), Display_Style);
      Delimited   : constant Box := Build (Parse ("\left(\frac{a}{b}\right)"));
      Fonts       : constant Box      :=
        Build (Parse ("\mathbf{A} \mathbb{R} \mathcal{C}"));
      Hat         : constant Box      := Build (Parse ("\hat{x}"));
      Unsupported : constant Document := Parse ("\left\langle x\right\rangle");
      Has_Index   : Boolean           := False;
      Has_Limits  : Boolean           := False;
      Has_Side    : Boolean           := False;
      Has_Fonts   : Boolean           := False;
   begin
      Assert (Radical.Valid, "indexed radical succeeds");
      for C of Radical.Commands loop
         Has_Index := Has_Index or else C.Code_Point = Character'Pos ('3');
      end loop;
      Assert (Has_Index, "radical index is drawn");
      Assert (Dfrac.Valid and Tfrac.Valid, "fraction style commands succeed");
      Assert
        (Dfrac.Ascent > Tfrac.Ascent,
         "dfrac uses display geometry instead of tfrac geometry");
      Assert (Limits.Valid and Side.Valid, "operator script layouts succeed");
      for C of Limits.Commands loop
         if C.Code_Point = Character'Pos ('n')
           or else C.Code_Point = Character'Pos ('i')
         then
            Has_Limits := Has_Limits or else abs C.X > 0.0;
         end if;
      end loop;
      Assert (Has_Limits, "limit scripts have centered offsets");
      Assert (Delimited.Valid, "left/right delimited expression succeeds");
      for C of Fonts.Commands loop
         Has_Fonts :=
           Has_Fonts
           or else C.Font in Main_Bold | AMS_Regular | Caligraphic_Regular;
      end loop;
      Assert (Has_Fonts, "font commands select distinct font faces");
      Assert (Hat.Valid, "hat accent lays out");
      Assert
        (Hat.Commands.Last_Element.Code_Point = 16#2C6#
         and then Math_Metrics.Lookup (Main_Regular, 16#2C6#).Found,
         "hat uses a measured circumflex glyph");
      Assert
        (not Is_Valid (Unsupported),
         "unsupported angle delimiters fail explicitly");
   end Test_Layout_Requested_Engine_Features;

   procedure Test_Layout_Fraction_Text_And_Display (T : in out Test) is
      pragma Unreferenced (T);
      Parsed       : constant Document := Parse ("\frac{1}{2}");
      Text_Box     : constant Box      := Build (Parsed, Text_Style);
      Display_Box  : constant Box      := Build (Parsed, Display_Style);
      Text_Rule    : Boolean           := False;
      Display_Rule : Boolean           := False;
   begin
      Assert (Text_Box.Valid and then Display_Box.Valid, "fraction layouts");
      Assert
        (Text_Box.Commands.Length = 3 and then Display_Box.Commands.Length = 3,
         "each fraction has numerator, denominator, and rule");
      for Index in
        Text_Box.Commands.First_Index .. Text_Box.Commands.Last_Index
      loop
         Text_Rule :=
           Text_Rule or else Text_Box.Commands (Index).Kind = Rule_Command;
      end loop;
      for Index in
        Display_Box.Commands.First_Index .. Display_Box.Commands.Last_Index
      loop
         Display_Rule :=
           Display_Rule
           or else Display_Box.Commands (Index).Kind = Rule_Command;
      end loop;
      Assert (Text_Rule and then Display_Rule, "both fractions emit rules");
      Assert
        (abs (Text_Box.Ascent - Display_Box.Ascent) > 0.000_001
         or else abs (Text_Box.Descent - Display_Box.Descent) > 0.000_001,
         "text and display fraction geometry differs");
   end Test_Layout_Fraction_Text_And_Display;

   procedure Test_Layout_Explicit_Whitespace (T : in out Test) is
      pragma Unreferenced (T);
      Plain  : constant Box := Build (Parse ("ab"));
      Spaced : constant Box := Build (Parse ("a\quad b"));
   begin
      Assert (Plain.Valid and then Spaced.Valid, "both rows lay out");
      Assert (Spaced.Width > Plain.Width + 0.9, "quad adds about one em");
   end Test_Layout_Explicit_Whitespace;

   procedure Test_Layout_Double_Bar_Delimiters (T : in out Test) is
      pragma Unreferenced (T);
      Parsed       : constant Document := Parse ("\left\|x\right\|");
      Array_Parsed : constant Document :=
        Parse ("\begin{Vmatrix}x&y\\z&w\end{Vmatrix}");
      Layout       : constant Box      := Build (Parsed);
      Array_Layout : constant Box      := Build (Array_Parsed);
      Bars         : Natural           := 0;
   begin
      Assert (Layout.Valid, "double-bar delimiters lay out");
      Assert (Array_Layout.Valid, "Vmatrix double bars lay out");
      for C of Layout.Commands loop
         if C.Code_Point = 16#7C# then
            Bars := Bars + 1;
         end if;
      end loop;
      Assert (Bars = 4, "each double delimiter emits two spaced bars");
      Bars := 0;
      for C of Array_Layout.Commands loop
         if C.Code_Point = 16#7C# then
            Bars := Bars + 1;
         end if;
      end loop;
      Assert (Bars = 4, "Vmatrix emits two bars on each side");
   end Test_Layout_Double_Bar_Delimiters;

   procedure Test_Parse_Named_Operators_And_Aliases (T : in out Test) is
      pragma Unreferenced (T);
      Operators           : constant Document :=
        Parse ("\sin x + \sum_{i=1}^n + \lim x + \max x + \min x");
      Aliases : constant Document := Parse ("\leq \ge \to \dots \ldots \pm");
      Additional_Aliases  : constant Document := Parse ("\le \geq");
      Negation            : constant Document := Parse ("\ne \neq");
      Layout              : constant Box      := Build (Operators);
      Alias_Layout        : constant Box      := Build (Aliases);
      Negation_Layout     : constant Box      := Build (Negation);
      Saw_Not_Equal       : Boolean           := False;
      Saw_Not_Equal_Base  : Boolean           := False;
      Saw_Not_Equal_Slash : Boolean           := False;
   begin
      Assert (Is_Valid (Operators), "named operators parse");
      Assert (Layout.Valid, "named operators have supported layout");
      Assert (Is_Valid (Aliases), "accepted symbol aliases parse");
      Assert (Alias_Layout.Valid, "accepted aliases have metrics");
      Assert (Is_Valid (Negation), "ne and neq aliases parse");
      Assert (Negation_Layout.Valid, "ne and neq aliases have metrics");
      Assert
        (Is_Valid (Additional_Aliases)
         and then Build (Additional_Aliases).Valid,
         "le and geq aliases also have metrics");
      for C of Negation_Layout.Commands loop
         Saw_Not_Equal       := Saw_Not_Equal or else C.Code_Point = 16#2260#;
         Saw_Not_Equal_Base  :=
           Saw_Not_Equal_Base or else C.Code_Point = Character'Pos ('=');
         Saw_Not_Equal_Slash :=
           Saw_Not_Equal_Slash or else C.Code_Point = Character'Pos ('/');
      end loop;
      Assert
        (Saw_Not_Equal
         or else (Saw_Not_Equal_Base and then Saw_Not_Equal_Slash),
         "not-equal alias has exact glyph or measured overlay");
      Assert
        (Math_Metrics.Lookup (Main_Regular, 16#2264#).Found,
         "less-or-equal aliases have metrics");
      Assert
        (Math_Metrics.Lookup (Main_Regular, 16#2265#).Found,
         "greater-or-equal aliases have metrics");
      Assert
        (not Math_Metrics.Lookup (Main_Regular, 16#2260#).Found
         and then Math_Metrics.Lookup (Main_Regular, Character'Pos ('/'))
           .Found,
         "fallback negation components have metrics");
      Assert
        (Math_Metrics.Lookup (Main_Regular, 16#2192#).Found,
         "right-arrow aliases have metrics");
      Assert
        (Math_Metrics.Lookup (Main_Regular, 16#2026#).Found,
         "ellipsis aliases have metrics");
      Assert
        (Math_Metrics.Lookup (Main_Regular, 16#00B1#).Found,
         "plus-minus alias has metrics");
   end Test_Parse_Named_Operators_And_Aliases;

   procedure Test_Parse_Text_And_Roman_Fonts (T : in out Test) is
      pragma Unreferenced (T);
      Parsed      : constant Document := Parse ("\text{a b} \mathrm{CD}");
      Layout      : constant Box      := Build (Parsed);
      Found_Space : Boolean           := False;
      Found_Roman : Boolean           := False;
   begin
      Assert (Is_Valid (Parsed), "text and roman groups parse");
      Assert (Layout.Valid, "text and roman groups lay out");
      for Index in Layout.Commands.First_Index .. Layout.Commands.Last_Index
      loop
         declare
            Command : constant Draw_Command := Layout.Commands (Index);
         begin
            Found_Space := Found_Space or else Command.Code_Point = 32;
            Found_Roman :=
              Found_Roman
              or else
              (Command.Code_Point = Character'Pos ('C')
               and then Command.Font = Main_Regular);
         end;
      end loop;
      Assert (Found_Space, "text mode retains internal space glyph");
      Assert (Found_Roman, "roman command uses regular font");
   end Test_Parse_Text_And_Roman_Fonts;

   procedure Test_Layout_Matrix_Cases_And_Aligned (T : in out Test) is
      pragma Unreferenced (T);
      Matrix  : constant Box :=
        Build (Parse ("\begin{pmatrix}a&b\\c&d\end{pmatrix}"));
      Cases   : constant Box :=
        Build (Parse ("\begin{cases}x&y\\z&w\end{cases}"));
      Aligned : constant Box :=
        Build (Parse ("\begin{aligned}a&=b\\c&=d\end{aligned}"));
   begin
      Assert (Matrix.Valid, "parenthesized matrix lays out");
      Assert (Cases.Valid, "cases array lays out");
      Assert (Aligned.Valid, "aligned equations lay out");
      Assert
        (Matrix.Width > 0.0 and then Matrix.Ascent > 0.0,
         "matrix has positive geometry");
      Assert
        (Cases.Width > 0.0 and then Aligned.Width > 0.0,
         "cases and aligned arrays have positive widths");
   end Test_Layout_Matrix_Cases_And_Aligned;

   procedure Test_Painter_Exact_Fonts_And_Recovery (T : in out Test) is
      pragma Unreferenced (T);
      Fonts                    : Math_Painter.Font_Set;
      Surface                  : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Context                  : Cairo.Cairo_Context := Cairo.Null_Context;
      Parsed                   : constant Document   := Parse ("\frac{1}{2}");
      Layout                   : constant Box        := Build (Parsed);
      Missing_Glyph            : Box                 := Build (Parse ("x"));
      Missing_Directory_Raised : Boolean             := False;
      Missing_Glyph_Raised     : Boolean             := False;
      Bad_Em_Raised            : Boolean             := False;
      Directory : constant String     := Coyote_Math_Resources.Font_Directory;
   begin
      begin
         Math_Painter.Load (Fonts, Directory & "/missing");
      exception
         when Math_Painter.Font_Error =>
            Missing_Directory_Raised := True;
      end;
      Assert
        (Missing_Directory_Raised,
         "missing font directory raises the documented font error");

      Math_Painter.Load (Fonts, Directory);
      Surface :=
        Cairo.Image_Surface.Create
          (Cairo.Image_Surface.Cairo_Format_ARGB32, 160, 80);
      Assert
        (Cairo.Surface.Status (Surface) = Cairo.Cairo_Status_Success,
         "headless image surface is healthy");
      Context := Cairo.Create (Surface);
      Assert
        (Cairo.Status (Context) = Cairo.Cairo_Status_Success,
         "headless Cairo context is healthy");
      Math_Painter.Draw (Fonts, Context, Layout, 5.0, 40.0, 24.0);
      Assert
        (Cairo.Status (Context) = Cairo.Cairo_Status_Success,
         "exact installed fonts draw fraction without GTK");

      Missing_Glyph.Commands.Clear;
      declare
         Bad_Command : constant Draw_Command :=
           (Kind => Glyph_Command, Code_Point => 16#10_FFFF#, others => <>);
      begin
         Missing_Glyph.Commands.Append (Bad_Command);
      end;
      begin
         Math_Painter.Draw (Fonts, Context, Missing_Glyph, 5.0, 40.0, 24.0);
      exception
         when Math_Painter.Font_Error =>
            Missing_Glyph_Raised := True;
      end;
      Assert (Missing_Glyph_Raised, "missing glyph raises font error");
      Math_Painter.Draw (Fonts, Context, Layout, 5.0, 40.0, 24.0);
      Assert
        (Cairo.Status (Context) = Cairo.Cairo_Status_Success,
         "draw succeeds after missing-glyph cleanup");

      begin
         Math_Painter.Draw (Fonts, Context, Layout, 5.0, 40.0, 0.0);
      exception
         when Math_Painter.Font_Error =>
            Bad_Em_Raised := True;
      end;
      Assert (Bad_Em_Raised, "invalid em size raises font error");
      Math_Painter.Draw (Fonts, Context, Layout, 5.0, 40.0, 24.0);
      Assert
        (Cairo.Status (Context) = Cairo.Cairo_Status_Success,
         "draw succeeds after invalid-em cleanup");
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
   end Test_Painter_Exact_Fonts_And_Recovery;

   package Math_Caller is new AUnit.Test_Caller (Coyote_Math_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math parses a simple glyph",
            Test_Parse_Simple_Glyph'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math rejects empty and unknown commands",
            Test_Parse_Empty_And_Unknown'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math bounds retained oversized source",
            Test_Parse_Oversized_Prefix'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math handles deterministic malformed inputs",
            Test_Parse_Deterministic_Malformed_Input'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math does not accept MathML markup",
            Test_Parse_MathML_Is_Not_Accepted'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math looks up known and unknown glyph metrics",
            Test_Metrics_Known_And_Unknown_Glyph'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math lays out a simple glyph",
            Test_Layout_Simple_Glyph'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math scales scripts and computes geometry",
            Test_Layout_Script_Scale_And_Geometry'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math keeps wide operator limits within their group",
            Test_Layout_Wide_Limit_Geometry'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math emits indexed radical glyph and overbar",
            Test_Layout_Radical_Index_Glyph'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math distinguishes text and display fractions",
            Test_Layout_Fraction_Text_And_Display'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math supports requested production math forms",
            Test_Layout_Requested_Engine_Features'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math preserves explicit whitespace width",
            Test_Layout_Explicit_Whitespace'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math emits two strokes for double-bar delimiters",
            Test_Layout_Double_Bar_Delimiters'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math accepts named operators and aliases",
            Test_Parse_Named_Operators_And_Aliases'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math lays out text and roman fonts",
            Test_Parse_Text_And_Roman_Fonts'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math lays out matrix, cases, and aligned arrays",
            Test_Layout_Matrix_Cases_And_Aligned'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math paints exact fonts and recovers from errors",
            Test_Painter_Exact_Fonts_And_Recovery'Access));
      return Result;
   end Suite;

end Coyote_Math_Tests;
