with AUnit.Test_Caller;
--  Coyote_Math_Tests body.

with AUnit.Assertions;
with Ada.Containers;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Cairo;
with Cairo.Image_Surface;
with Cairo.Surface;
with Coyote_Math_Resources;
with Math_Layout;
with Math_Metrics;
with Math_Model;
with Math_Painter;
with Math_Macros;
with Math_Syntax;
with Math_Symbols;

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

   procedure Test_Parse_Unicode_Symbols (T : in out Test) is
      pragma Unreferenced (T);
      Parsed : constant Document := Parse
        (Character'Val (16#CE#) & Character'Val (16#B1#) & "+" &
         Character'Val (16#E2#) & Character'Val (16#88#) &
         Character'Val (16#91#) & "_{i=0}^{" &
         Character'Val (16#E2#) & Character'Val (16#88#) &
         Character'Val (16#9E#) & "}" &
         Character'Val (16#E2#) & Character'Val (16#89#) &
         Character'Val (16#A4#) &
         Character'Val (16#CE#) & Character'Val (16#B2#));
      Layout : constant Box := Build (Parsed);
      Saw_Alpha : Boolean := False;
      Saw_Sum : Boolean := False;
      Saw_Infinity : Boolean := False;
      Saw_Relation : Boolean := False;
      Saw_Beta : Boolean := False;
   begin
      Assert (Is_Valid (Parsed), "registered raw Unicode parses");
      Assert (Layout.Valid, "registered raw Unicode lays out");
      for Command of Layout.Commands loop
         Saw_Alpha := Saw_Alpha or else Command.Code_Point = 16#03B1#;
         Saw_Sum := Saw_Sum or else Command.Code_Point = 16#2211#;
         Saw_Infinity := Saw_Infinity or else Command.Code_Point = 16#221E#;
         Saw_Relation := Saw_Relation or else Command.Code_Point = 16#2264#;
         Saw_Beta := Saw_Beta or else Command.Code_Point = 16#03B2#;
      end loop;
      Assert
        (Saw_Alpha and Saw_Sum and Saw_Infinity and Saw_Relation and Saw_Beta,
         "layout emits expected Unicode symbol code points");
      Assert (Math_Symbols.Lookup_Math ("\alpha").Found,
        "generated math registry includes aliases");
      Assert (Math_Symbols.Lookup_Text ("\%").Found,
        "percent escape remains available through symbol registry");
   end Test_Parse_Unicode_Symbols;

   procedure Test_Parse_Invalid_UTF8_And_Comments (T : in out Test) is
      pragma Unreferenced (T);
      Invalid : constant String :=
        ('x', Character'Val (16#C0#), 'y');
      Bad : constant Document := Parse (Invalid);
      Raw_Comment : constant Document := Parse
        ("x% comment" & Character'Val (10) & "+y");
      Escaped : constant Document := Parse ("x\%y");
   begin
      Assert (not Is_Valid (Bad), "invalid UTF-8 is rejected");
      Assert
        (Error (Bad) = "invalid UTF-8 in math source"
         and then Error_Position (Bad) = 2,
         "UTF-8 diagnostic reports exact byte");
      Assert
        (Is_Valid (Raw_Comment) and then Build (Raw_Comment).Valid,
         "raw percent comment is consumed before layout");
      Assert
        (Source (Raw_Comment) = "x% comment" & Character'Val (10) & "+y",
         "comment source remains owned exactly");
      declare
         Comment_Layout : constant Box := Build (Raw_Comment);
      begin
         Assert
           (Comment_Layout.Commands.Length = 3,
            "LF comment terminator leaves three glyphs");
         Assert
           (Comment_Layout.Commands (1).Code_Point = Character'Pos ('x'),
            "glyph before comment is x");
         Assert
           (Comment_Layout.Commands (2).Code_Point = Character'Pos ('+'),
            "LF resumes tokenization at plus");
         Assert
           (Comment_Layout.Commands (3).Code_Point = Character'Pos ('y'),
            "glyph after LF comment is y");
      end;
      Assert (Is_Valid (Escaped), "escaped percent remains a symbol");
   end Test_Parse_Invalid_UTF8_And_Comments;

   procedure Test_Parse_Macros_And_Shared_Context (T : in out Test) is
      pragma Unreferenced (T);
      Shared : aliased Math_Macros.Context;
      Expanded : constant Document := Parse
        ("\def\foo#1{#1+1}\foo{x}", Shared'Access);
      Layout : constant Box := Build (Expanded);
      Expected : constant array (Positive range 1 .. 3) of Natural :=
        (Character'Pos ('x'), Character'Pos ('+'), Character'Pos ('1'));
      Index : Positive := Expected'First;
      function Image (Value : Natural) return String is
      begin
         return Ada.Strings.Fixed.Trim
           (Natural'Image (Value), Ada.Strings.Both);
      end Image;
   begin
      Assert (Is_Valid (Expanded), "parameterized macro invocation parses");
      Assert
        (Source (Expanded) = "\def\foo#1{#1+1}\foo{x}",
         "macro parse retains exact original source");
      Assert (Layout.Valid, "parameterized macro expansion lays out");
      Assert
        (Layout.Commands.Length = Expected'Length,
         "macro expansion emits exactly three glyphs");
      for Command of Layout.Commands loop
         Assert
           (Command.Code_Point = Expected (Index),
            "macro glyph " & Image (Index) & " expected code point " &
              Image (Expected (Index)) & " but got " &
              Image (Command.Code_Point));
         Index := Index + 1;
      end loop;
      Assert
        (not Math_Macros.Is_Defined (Shared, "foo"),
         "default parse scope does not persist local definitions");
   end Test_Parse_Macros_And_Shared_Context;

   procedure Test_Parse_Macro_Scope_And_Reset (T : in out Test) is
      pragma Unreferenced (T);
      Shared : aliased Math_Macros.Context;
      Failed : constant Document := Parse
        ("\gdef\foo{A}\htmlClass{class}{x}", Shared'Access,
         (Strict => Strict_Error, others => <>));
      Persisted : constant Document := Parse ("\foo", Shared'Access);
      Local : constant Document := Parse
        ("\def\foo{B}\foo", Shared'Access, Global_Group => True);
      After_Local : constant Document := Parse ("\foo", Shared'Access);
      Shadow : constant Document := Parse
        ("\def\foo{A}{\def\foo{B}\foo}\foo", Shared'Access);
      Shadow_Layout : constant Box := Build (Shadow);
      Unbound : constant Document := Parse
        ("{\def\gone{C}}\gone", Shared'Access);
      Reset_Result : Document;
   begin
      Assert (not Is_Valid (Failed),
              "strict HTML error follows global definition");
      Assert (Diagnostic_Count (Failed) = 1 and then
              Diagnostic_At (Failed, 1).Kind = Parse_Error,
              "strict HTML failure produces a fatal parse diagnostic");
      Assert
        (Is_Valid (Persisted) and then Build (Persisted).Valid,
         "global definition persists despite later parse failure");
      declare
         Persisted_Layout : constant Box := Build (Persisted);
      begin
         Assert
           (Persisted_Layout.Commands.Length = 1,
            "persisted global macro emits one glyph");
         Assert
           (Persisted_Layout.Commands.First_Element.Code_Point =
              Character'Pos ('A'),
            "persisted global definition expands to A");
      end;
      Assert
        (Is_Valid (Local),
         "global-group local definition parses: " & Error (Local));
      Assert
        (Is_Valid (After_Local) and then Build (After_Local).Valid,
         "Global_Group preserves a local definition");
      declare
         Local_Layout : constant Box := Build (After_Local);
      begin
         Assert
           (Local_Layout.Commands.Length = 1,
            "preserved local macro emits one glyph");
         Assert
           (Local_Layout.Commands.First_Element.Code_Point =
              Character'Pos ('B'),
            "preserved local definition expands to B");
      end;
      Assert (Is_Valid (Shadow) and then Shadow_Layout.Valid,
              "nested local shadow parses and lays out");
      Assert
        (Shadow_Layout.Commands.Length = 2
         and then Shadow_Layout.Commands (1).Code_Point = Character'Pos ('B')
         and then Shadow_Layout.Commands (2).Code_Point = Character'Pos ('A'),
         "nested shadow restores prior definition before following tokens");
      Assert
        (not Is_Valid (Unbound)
         and then not Math_Macros.Is_Defined (Shared, "gone"),
         "group-local definition is removed at group exit");
      Math_Macros.Reset (Shared);
      Reset_Result := Parse ("\foo", Shared'Access);
      Assert
        (not Is_Valid (Reset_Result), "reset removes persisted definition");
   end Test_Parse_Macro_Scope_And_Reset;

   procedure Test_Parse_Macro_Tokens_Across_Requests (T : in out Test) is
      pragma Unreferenced (T);
      Shared : aliased Math_Macros.Context;
      Defined : constant Document := Parse
        ("\gdef\mystery{\unknown}x", Shared'Access);
      Expanded : constant Document := Parse ("\mystery", Shared'Access);
      Defaulted : constant Document := Parse ("\mystery");
   begin
      Assert
        (Is_Valid (Defined), "macro body can define unknown command tokens: " &
           Error (Defined));
      Assert
        (not Is_Valid (Expanded)
         and then Error (Expanded)'Length > 0,
         "expanded unknown command reports parse diagnostic");
      Assert
        (not Is_Valid (Defaulted),
         "fresh default parse does not inherit macro from prior request");
   end Test_Parse_Macro_Tokens_Across_Requests;

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
            if Command.Kind = Path_Command then
               Found_Radical := not Command.Path_Data.Is_Empty;
               Found_Rule := Command.Has_Clip and then
                 Command.Clip_W > 0.0 and then Command.Clip_H > 0.0;
            elsif Command.Kind = Glyph_Command
              and then Command.Code_Point = Character'Pos ('3')
            then
               Found_Index := True;
            end if;
         end;
      end loop;
      Assert (Found_Radical, "radical outline path is emitted");
      Assert (Found_Index, "root index glyph is emitted");
      Assert (Found_Rule, "radical and vinculum share a bounded viewport");
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
      Left_Arrow  : constant Box      := Build (Parse ("\overleftarrow{xy}"));
      Right_Arrow : constant Box      := Build (Parse ("\overrightarrow{xy}"));
      Over_Brace   : constant Box      := Build
        (Parse ("\overbrace{x+y}^{n}"));
      Under_Brace  : constant Box      := Build
        (Parse ("\underbrace{x+y}_{n}"));
      Unsupported : constant Document := Parse ("\left\langle x\right\rangle");
      Has_Index   : Boolean           := False;
      Has_Limits  : Boolean           := False;
      Has_Fonts   : Boolean           := False;
   begin
      Assert (Radical.Valid, "indexed radical succeeds");
      for C of Radical.Commands loop
         Has_Index := Has_Index or else C.Code_Point = Character'Pos ('3');
      end loop;
      Assert (Has_Index, "radical index is drawn");
      Assert (Dfrac.Valid and then Tfrac.Valid,
         "fraction style commands succeed");
      Assert
        (Dfrac.Ascent > Tfrac.Ascent,
         "dfrac uses display geometry instead of tfrac geometry");
      Assert
        (Limits.Valid and then Side.Valid,
         "operator script layouts succeed");
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
        (Left_Arrow.Valid and then Right_Arrow.Valid,
         "legacy over-arrow accents retain stretchy geometry");
      Assert
        (Over_Brace.Valid and then Under_Brace.Valid,
         "overbrace and underbrace with scripts produce geometry");
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
      Left_Bars    : Natural           := 0;
      Right_Bars   : Natural           := 0;
      Left_Min_X   : Long_Float        := Long_Float'Last;
      Left_Max_X   : Long_Float        := Long_Float'First;
      Right_Min_X  : Long_Float        := Long_Float'Last;
      Right_Max_X : Long_Float         := Long_Float'First;
      Tolerance    : constant Long_Float := 0.000_001;
   begin
      Assert (Layout.Valid, "double-bar delimiters lay out");
      Assert (Array_Layout.Valid, "Vmatrix double bars lay out");
      for C of Layout.Commands loop
         if C.Code_Point = 16#7C# then
            Bars := Bars + 1;
         end if;
      end loop;
      Assert (Bars = 4, "each double delimiter emits two spaced bars");
      for C of Array_Layout.Commands loop
         if C.Kind = Glyph_Command and then C.Code_Point = 16#7C# then
            if C.X < Array_Layout.Width / 2.0 then
               Left_Bars := Left_Bars + 1;
               Left_Min_X := Long_Float'Min (Left_Min_X, C.X);
               Left_Max_X := Long_Float'Max (Left_Max_X, C.X);
            else
               Right_Bars := Right_Bars + 1;
               Right_Min_X := Long_Float'Min (Right_Min_X, C.X);
               Right_Max_X := Long_Float'Max (Right_Max_X, C.X);
            end if;
            Bars := Bars + 1;
         elsif C.Kind = Rule_Command
           and then C.Width <= C.Height / 10.0
         then
            --  Oversized vertical bars use narrow rules, not glyphs.
            Assert
              (C.Width > 0.0 and then C.Height > 0.0
               and then C.X >= -Tolerance
               and then C.X + C.Width <= Array_Layout.Width + Tolerance,
               "Vmatrix rule bar has bounded positive geometry");
            if C.X < Array_Layout.Width / 2.0 then
               Left_Bars := Left_Bars + 1;
               Left_Min_X := Long_Float'Min (Left_Min_X, C.X);
               Left_Max_X := Long_Float'Max (Left_Max_X, C.X);
            else
               Right_Bars := Right_Bars + 1;
               Right_Min_X := Long_Float'Min (Right_Min_X, C.X);
               Right_Max_X := Long_Float'Max (Right_Max_X, C.X);
            end if;
            Bars := Bars + 1;
         end if;
      end loop;
      Assert
        (Left_Bars > 1 and then Right_Bars > 1,
         "each Vmatrix side has separated strokes: " &
           Natural'Image (Left_Bars) & "/" & Natural'Image (Right_Bars));
      Assert
        (Left_Max_X > Left_Min_X and then Right_Max_X > Right_Min_X,
         "each Vmatrix side has distinct horizontal positions");
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
           Saw_Not_Equal_Slash or else C.Code_Point = Character'Pos ('/')
             or else C.Code_Point = 16#E020#;
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

   procedure Test_Parse_Accents_And_Operator_Words (T : in out Test) is
      pragma Unreferenced (T);
      Accents : constant Document := Parse
        ("\dot T_a + \dot{T_a} + \ddot{x} + \tilde{x} + \check{x} + " &
         "\breve{x} + \acute{x} + \grave{x} + \mathring{x} + " &
         "\overline{AB} + \underline{CD}");
      Words : constant Document := Parse
        ("\sinh x + \cosh x + \tanh x + \arcsin x + \arccos x + " &
         "\arctan x + \cot x + \sec x + \csc x + \det A");
      Relations : constant Document := Parse
        ("\approx \equiv \sim \propto \subseteq \notin \implies \iff");
      Missing : constant Document := Parse ("\dot");
      Unknown : constant Document := Parse ("\unrecognizedCommand{x}");
      Relation_Layout : constant Box := Build (Relations);
      Function_Layout : constant Box := Build (Words);
      Single : constant Document := Parse ("\dot T_a");
      Grouped : constant Document := Parse ("\dot{T_a}");
      Single_Root : Node;
      Single_Script : Node;
      Group_Root : Node;
      Group_Script : Node;
      Group_Inner : Node;
   begin
      Assert (Is_Valid (Accents), "common accent forms parse");
      Single_Root := Element (Single, Positive (Root (Single)));
      Single_Script := Element (Single, Positive (Single_Root.First));
      Group_Root := Element (Grouped, Positive (Root (Grouped)));
      Group_Script := Element (Grouped, Positive (Group_Root.First));
      Group_Inner := Element (Grouped, Positive (Group_Script.First));
      Assert (Is_Valid (Single) and then Is_Valid (Grouped),
              "accent token scope examples parse");
      Assert (Single_Script.Kind = Scripts_Node and then
              Element (Single, Positive (Single_Script.First)).Kind =
                Accent_Node,
              "following subscript applies to the accented token");
      Assert (Group_Script.Kind = Accent_Node and then
              Group_Inner.Kind = Row_Node and then
              Element (Grouped, Positive (Group_Inner.First)).Kind =
                Scripts_Node,
              "braced accent argument retains its internal script");
      Assert (Is_Valid (Words), "common and named operators parse");
      Assert (Is_Valid (Relations), "common relation aliases parse");
      Assert (Function_Layout.Valid,
              "common and named operator words have metrics");
      Assert (Relation_Layout.Valid,
              "common relations use pinned glyph metrics");
      Assert (not Is_Valid (Missing), "accent without an argument fails");
      Assert (not Is_Valid (Unknown), "genuinely unknown command fails");
      Assert (Math_Metrics.Lookup (Main_Regular, 16#02D9#).Found,
              "dot accent has an embedded metric");
      Assert (Math_Metrics.Lookup (Main_Regular, 16#00A8#).Found,
              "double-dot accent has an embedded metric");
      Assert (Math_Metrics.Lookup (Main_Regular, 16#2248#).Found,
              "approximation relation has an embedded metric");
      Assert (Math_Metrics.Lookup (Main_Regular, 16#21D4#).Found,
              "iff relation has an embedded metric");
   end Test_Parse_Accents_And_Operator_Words;

   procedure Test_Parse_Untrusted_Command_Policies (T : in out Test) is
      pragma Unreferenced (T);
      Warning_Result : constant Document := Parse ("\href{url}{label}");
      Ignore_Result : constant Document := Parse
        ("\url{address}", (Strict => Strict_Ignore, others => <>));
      Strict_Result : constant Document := Parse
        ("\htmlClass{class}{x}", (Strict => Strict_Error, others => <>));
      Missing_Argument : constant Document := Parse ("\href{}{label}");
      Warn_Diagnostic : constant Diagnostic :=
        Diagnostic_At (Warning_Result, 1);
      Ignore_Diagnostic : constant Diagnostic :=
        Diagnostic_At (Ignore_Result, 1);
      HTML_Diagnostic : constant Diagnostic :=
        Diagnostic_At (Strict_Result, 1);
   begin
      Assert (Is_Valid (Warning_Result),
              "default policy keeps refused href visible");
      Assert (Diagnostic_Count (Warning_Result) = 1,
              "warning policy records one diagnostic");
      Assert (Warn_Diagnostic.Kind = Warning and then
              Ada.Strings.Unbounded.Length (Warn_Diagnostic.Message) > 0
              and then Warn_Diagnostic.Position = 1,
              "warning diagnostic identifies refusal and position");
      Assert (Is_Valid (Ignore_Result),
              "ignore policy keeps refused url visible");
      Assert (Diagnostic_Count (Ignore_Result) = 1,
              "ignore policy records one diagnostic");
      Assert (Ignore_Diagnostic.Kind = Refusal and then
              Ada.Strings.Unbounded.Length (Ignore_Diagnostic.Message) > 0
              and then Ignore_Diagnostic.Position = 1,
              "ignore diagnostic identifies refusal and position");
      Assert (not Is_Valid (Strict_Result),
              "strict-error policy rejects HTML command");
      Assert (Diagnostic_Count (Strict_Result) = 1 and then
              HTML_Diagnostic.Kind = Parse_Error and then
              Ada.Strings.Unbounded.Length (HTML_Diagnostic.Message) > 0
              and then HTML_Diagnostic.Position = 1,
              "strict HTML rejection reports positioned parse error");
      Assert (not Is_Valid (Missing_Argument) and then
              Diagnostic_Count (Missing_Argument) = 1 and then
              Diagnostic_At (Missing_Argument, 1).Kind = Parse_Error,
              "missing href argument fails during parsing");
   end Test_Parse_Untrusted_Command_Policies;

   procedure Test_Layout_Accents_And_Operator_Limits (T : in out Test) is
      pragma Unreferenced (T);
      Glyph_Accent : constant Box := Build (Parse ("\dot T_a"));
      Group_Accent : constant Box := Build (Parse ("\dot{T_a}"));
      Underline : constant Box := Build (Parse ("\underline{x}"));
      Overline : constant Box := Build (Parse ("\overline{x}"));
      Wide_Hat : constant Box := Build (Parse ("\widehat{xyz}"));
      Display_Lim : constant Box := Build
        (Parse ("\operatornamewithlimits{lim}_{x}^{+}"), Display_Style);
      Inline_Lim : constant Box := Build
        (Parse ("\operatornamewithlimits{lim}_{x}^{+}"), Text_Style);
      Display_Max : constant Box := Build
        (Parse ("\max_{i}^{n}"), Display_Style);
      Inline_Max : constant Box := Build
        (Parse ("\max_{i}^{n}"), Text_Style);
      Glyph_Accent_Y : Long_Float := 0.0;
      Group_Accent_Y : Long_Float := 0.0;
      Underline_Y : Long_Float := 0.0;
      Overline_Y : Long_Float := 0.0;
      Saw_Mark : Boolean := False;
      Saw_Wide_Hat_Path : Boolean := False;
   begin
      Assert (Glyph_Accent.Valid and then Group_Accent.Valid,
              "accented script expressions lay out");
      for C of Glyph_Accent.Commands loop
         if C.Code_Point = 16#02D9# then
            Glyph_Accent_Y := C.Y;
            Saw_Mark := True;
         end if;
      end loop;
      Assert (Saw_Mark, "dot command is retained");
      Saw_Mark := False;
      for C of Group_Accent.Commands loop
         if C.Code_Point = 16#02D9# then
            Group_Accent_Y := C.Y;
            Saw_Mark := True;
         end if;
      end loop;
      Assert (Saw_Mark, "grouped dot command is retained");
      Assert (Glyph_Accent_Y < 0.0 and then Group_Accent_Y < 0.0,
              "both accent marks are positioned above their bases");
      Assert (Underline.Valid and then Overline.Valid,
              "overline and underline produce layout");
      Assert (Wide_Hat.Valid, "widehat parses and lays out");
      for C of Wide_Hat.Commands loop
         if C.Kind = Path_Command then
            Saw_Wide_Hat_Path := True;
            Assert (not C.Path_Data.Is_Empty,
                    "widehat emits path segments");
            Assert (C.Width > 0.0 and then C.Height > 0.0,
                    "widehat path has positive geometry");
         end if;
      end loop;
      Assert (Saw_Wide_Hat_Path,
              "widehat layout emits a painter path command");
      for C of Underline.Commands loop
         if C.Kind = Rule_Command then
            Underline_Y := C.Y;
         end if;
      end loop;
      for C of Overline.Commands loop
         if C.Kind = Rule_Command then
            Overline_Y := C.Y;
         end if;
      end loop;
      Assert (Underline_Y > 0.0 and then Overline_Y < 0.0,
              "underline and overline occupy opposite sides");
      Assert (Display_Lim.Valid and then Inline_Lim.Valid and then
              Display_Max.Valid and then Inline_Max.Valid,
              "named operators with scripts lay out in both styles");
      Assert (Display_Lim.Width < Inline_Lim.Width and then
              Display_Max.Width < Inline_Max.Width,
              "display operators center limits; inline scripts stay right");
   end Test_Layout_Accents_And_Operator_Limits;

   procedure Test_Parse_Text_And_Roman_Fonts (T : in out Test) is
      pragma Unreferenced (T);
      Parsed      : constant Document := Parse ("\text{a b} \mathrm{CD}");
      Grouped     : constant Document := Parse ("{\text{a  b}}");
      Group_Layout : constant Box := Build (Grouped);
      Layout      : constant Box      := Build (Parsed);
      Found_Space : Boolean           := False;
      Found_Roman : Boolean           := False;
   begin
      Assert (Is_Valid (Parsed), "text and roman groups parse");
      Assert (Layout.Valid and then Group_Layout.Valid,
              "text and grouped text lay out");
      Assert
        (Source (Grouped) = "{\text{a  b}}",
         "grouped text retains exact source spaces");
      Assert
        (Group_Layout.Commands.Length = 3
         and then Group_Layout.Commands (2).Code_Point = 32,
         "grouped text preserves its internal repeated space");
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
      declare
         Wide_Hat_Layout : constant Box := Build (Parse ("\widehat{xyz}"));
         Path_Only : Box;
      begin
         Assert (Wide_Hat_Layout.Valid,
           "painter receives valid widehat path layout");
         Path_Only.Valid := True;
         for Command of Wide_Hat_Layout.Commands loop
            if Command.Kind = Path_Command then
               Path_Only.Commands.Append (Command);
            end if;
         end loop;
         Assert (not Path_Only.Commands.Is_Empty,
           "widehat supplies a path-only painter input");
         Math_Painter.Draw (Fonts, Context, Path_Only, 5.0, 40.0, 24.0);
         Assert (Cairo.Status (Context) = Cairo.Cairo_Status_Success,
           "painter draws widehat path without GTK");
      end;

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
           ("Coyote.Math parses registered Unicode symbols",
            Test_Parse_Unicode_Symbols'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math diagnoses invalid UTF-8 and comments",
            Test_Parse_Invalid_UTF8_And_Comments'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math expands parameterized macros in source order",
            Test_Parse_Macros_And_Shared_Context'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math scopes, shadows, and resets shared macros",
            Test_Parse_Macro_Scope_And_Reset'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math owns macro tokens across parse requests",
            Test_Parse_Macro_Tokens_Across_Requests'Access));
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
           ("Coyote.Math records strict untrusted-command policies",
            Test_Parse_Untrusted_Command_Policies'Access));
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
           ("Coyote.Math parses accents and common operator words",
            Test_Parse_Accents_And_Operator_Words'Access));
      Result.Add_Test
        (Math_Caller.Create
           ("Coyote.Math lays out accents and operator limits",
            Test_Layout_Accents_And_Operator_Limits'Access));
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
