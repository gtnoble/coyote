with Ada.Containers;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Math_Engine;
with Math_Layout;
with Math_Macros;
with Math_Model;
with Math_Syntax;
with Math_Semantics;
with Math_Stretchy;
with Math_Paths;

procedure Math_Additional_Probe is
   use Math_Model;
   use type Ada.Containers.Count_Type;
   use type Math_Engine.Status_Kind;
   use type Math_Syntax.Delimiter_Kind;
   use type Math_Syntax.Diagnostic_Kind;
   use type Math_Semantics.Child_Role;

   Shared : aliased Math_Macros.Context;

   procedure Check_Node
     (Source : String;
      Expected : Node_Kind;
      Under : Boolean := False)
   is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind /= Expected or else not Geometry.Valid
      then
         raise Program_Error with "unexpected node for " & Source &
           ": got " & Item.Kind'Image & ", valid=" &
           Boolean'Image (Geometry.Valid);
      end if;
      if Expected = Annotation_Node and then
        Item.Annotation_Type /= (if Under then Under_Annotation
                                 else Over_Annotation)
      then
         raise Program_Error with "wrong annotation direction: " & Source;
      end if;
      declare
         Semantics : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
      begin
         if not Math_Semantics.Is_Valid (Semantics) then
            raise Program_Error with "semantic projection failed: " & Source;
         end if;
      end;
      Ada.Text_IO.Put_Line ("PASS " & Source);
   end Check_Node;

   procedure Check_Brace (Source : String; Expected : Natural) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      if not Geometry.Valid then
         raise Program_Error with "brace layout failed for " & Source & ": " &
           Ada.Strings.Unbounded.To_String (Geometry.Message);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind /= Accent_Node or else Item.Code_Point /= Expected then
         raise Program_Error with "wrong brace accent sentinel: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS parsed brace accent " & Source);
   end Check_Brace;

   procedure Check_Fraction
     (Source : String;
      Bar : Fraction_Bar_Mode;
      Style : Math_Style_Kind := Natural_Style;
      Continued : Boolean := False;
      Left : Math_Syntax.Delimiter_Kind := Math_Syntax.No_Delimiter;
      Thickness : Long_Float := -1.0;
      Alignment : Fraction_Alignment := Center_Fraction) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
      Semantics : constant Math_Semantics.Document :=
        Math_Semantics.Project (Parsed);
      Semantic : Math_Semantics.Semantic_Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind = Style_Node then
         Item := Math_Syntax.Element (Parsed, Positive (Item.First));
      end if;
      if Item.Kind /= Fraction_Node or else Item.Fraction_Bar /= Bar or else
        Item.Fraction_Style_Mode /= Style or else
        Item.Fraction_Continued /= Continued or else
        Item.Fraction_Alignment_Mode /= Alignment or else
        Item.Left_Delimiter /= Left or else
        abs (Item.Fraction_Rule_Thickness - Thickness) > 0.000_000_001
      then
         raise Program_Error with "wrong fraction payload: " & Source &
           " bar=" & Item.Fraction_Bar'Image &
           " style=" & Item.Fraction_Style_Mode'Image &
           " continued=" & Boolean'Image (Item.Fraction_Continued) &
           " left=" & Item.Left_Delimiter'Image &
           " alignment=" & Item.Fraction_Alignment_Mode'Image &
           " expected-alignment=" & Alignment'Image &
           " thickness=" & Long_Float'Image
             (Item.Fraction_Rule_Thickness);
      end if;
      if Item.First = Item.Second then
         raise Program_Error with "fraction operand nodes aliased: " & Source;
      end if;
      if Source = "a\over bc" then
         declare
            Denominator_Row : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Positive (Item.Second));
            First_Denominator : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Positive (Denominator_Row.First));
         begin
            if First_Denominator.Next = No_Node then
               raise Program_Error with "infix denominator tail lost";
            end if;
         end;
      end if;
      declare
         Numerator : Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Item.First));
         Denominator : Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Item.Second));
      begin
         if Numerator.Kind = Row_Node and then
           Numerator.First /= No_Node and then
           Denominator.Kind = Row_Node and then
           Denominator.First /= No_Node
         then
            if Numerator.First = Denominator.First then
               raise Program_Error with "fraction operand chains aliased: " &
                 Source;
            end if;
            while Numerator.Next /= No_Node loop
               Numerator := Math_Syntax.Element
                 (Parsed, Positive (Numerator.Next));
            end loop;
            while Denominator.Next /= No_Node loop
               Denominator := Math_Syntax.Element
                 (Parsed, Positive (Denominator.Next));
            end loop;
            if Numerator.Next /= No_Node or else
              Denominator.Next /= No_Node
            then
               raise Program_Error with "fraction operand chain cycle: " &
                 Source;
            end if;
         end if;
      end;
      if not Math_Semantics.Is_Valid (Semantics) then
         raise Program_Error with "fraction projection invalid: " & Source;
      end if;
      Semantic := Math_Semantics.Element
        (Semantics, Positive (Math_Semantics.Root (Semantics) + 1));
      if Semantic.Kind = Style_Node then
         Semantic := Math_Semantics.Element
           (Semantics, Positive (Math_Semantics.Root (Semantics) + 2));
      end if;
      if Semantic.Kind /= Fraction_Node or else
        Semantic.Fraction_Bar /= Bar or else
        Semantic.Fraction_Style_Mode /= Style or else
        Semantic.Fraction_Continued /= Continued or else
        Semantic.Fraction_Alignment_Mode /= Alignment or else
        Semantic.Left_Delimiter /= Left or else
        abs (Semantic.Fraction_Rule_Thickness - Thickness) > 0.000_000_001
      then
         raise Program_Error with "fraction projection lost payload: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS fraction " & Source);
   end Check_Fraction;

   procedure Check_Invalid_Fraction (Source : String; Position : Natural) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
   begin
      if Math_Syntax.Is_Valid (Parsed) or else
        Math_Syntax.Error_Position (Parsed) /= Position
      then
         raise Program_Error with "wrong infix rejection position: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS rejected infix " & Source);
   end Check_Invalid_Fraction;

   procedure Check_Brace_Paths is
   begin
      for Kind in Math_Stretchy.Brace_Kind loop
         for Part in Math_Stretchy.Brace_Part loop
            declare
               Path : constant Math_Paths.Path :=
                 Math_Stretchy.Brace_Part_For (Kind, Part);
               Bounds : constant Math_Paths.Bounds :=
                 Math_Paths.Extent (Path);
            begin
               if not Math_Paths.Is_Valid (Path) or else
                 Math_Paths.Count (Path) = 0 or else not Bounds.Valid or else
                 Math_Stretchy.Brace_View_Width (Part) /= 400_000.0 or else
                 Math_Stretchy.Brace_View_Height (Kind) /= 548.0
               then
                  raise Program_Error with "invalid static brace geometry";
               end if;
            end;
         end loop;
      end loop;
      Ada.Text_IO.Put_Line ("PASS all six static brace paths");
   end Check_Brace_Paths;

   procedure Check_Stretchy
     (Source : String;
      Name : String;
      Mode : Natural;
      Under : Boolean := False)
   is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
      Semantics : Math_Semantics.Document;
      Semantic : Math_Semantics.Semantic_Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      if not Geometry.Valid then
         raise Program_Error with "stretchy layout failed: " & Source & ": " &
           Ada.Strings.Unbounded.To_String (Geometry.Message);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind /= Stretchy_Node or else
        Ada.Strings.Unbounded.To_String (Item.Stretchy_Name) /= Name or else
        Item.Code_Point /= Mode or else
        Item.Annotation_Type /= (if Under then Under_Annotation
                                 else Over_Annotation) or else
        (if Mode = 0 then Item.Second /= No_Node else Item.First = No_Node)
      then
         raise Program_Error with "wrong stretchy syntax payload: " & Source;
      end if;
      Semantics := Math_Semantics.Project (Parsed);
      if not Math_Semantics.Is_Valid (Semantics) or else
        Math_Semantics.Count (Semantics) < 2
      then
         raise Program_Error with "stretchy semantic projection failed: " &
           Source;
      end if;
      Semantic := Math_Semantics.Element
        (Semantics, Positive (Math_Semantics.Root (Semantics) + 1));
      if Semantic.Kind /= Stretchy_Node or else
        Ada.Strings.Unbounded.To_String (Semantic.Stretchy_Name) /= Name or else
        Semantic.Code_Point /= Mode or else
        (if Mode = 0 then Semantic.Child_Count /= 1
         else Semantic.Child_Count not in 1 .. 2)
      then
         raise Program_Error with "stretchy semantic payload lost: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS stretchy " & Source);
   end Check_Stretchy;

   procedure Check_Unsupported (Source : String) is
      Options : Math_Engine.Request;
      Result : Math_Engine.Result;
   begin
      Options.Settings.Throw_On_Error := False;
      Math_Engine.Parse (Source, Shared'Access, Options, Result);
      if Result.Status /= Math_Engine.Parse_Error or else
        Math_Syntax.Is_Valid (Result.Parsed) or else
        Math_Engine.Error (Result)'Length = 0 or else
        not Result.Geometry.Valid or else
        Result.Geometry.Commands.Length /= Source'Length
      then
         raise Program_Error with
           "unsupported input must fail with visible source fallback: " &
           Source & "; diagnostic=" & Math_Engine.Error (Result);
      end if;
      for Index in Source'Range loop
         if Result.Geometry.Commands (Index - Source'First + 1).Code_Point /=
           Character'Pos (Source (Index))
         then
            raise Program_Error with
              "fallback did not preserve source for " & Source;
         end if;
      end loop;
      Ada.Text_IO.Put_Line
        ("PASS rejected with visible fallback " & Source);
   end Check_Unsupported;

   procedure Check_Limit (Source : String; Expected : Script_Layout) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
      Operator : Math_Syntax.Node;
      Scripts : Math_Syntax.Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Operator := Math_Syntax.Element (Parsed, Positive (Root.First));
      while Operator.Next /= No_Node loop
         Operator := Math_Syntax.Element
           (Parsed, Positive (Operator.Next));
         exit when Operator.Kind = Scripts_Node;
      end loop;
      Scripts := Operator;
      if Scripts.Kind /= Scripts_Node or else
        Scripts.Script_Type /= Expected
      then
         raise Program_Error with "wrong script placement: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS " & Source);
   end Check_Limit;

   procedure Check_Environment
     (Name : String;
      Style : Math_Style_Kind;
      Amount : Long_Float;
      Left : Math_Syntax.Delimiter_Kind;
      Right : Math_Syntax.Delimiter_Kind)
   is
      Source : constant String := "\begin{" & Name &
        "}a&b\\c&d\end{" & Name & "}";
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
      Array_Value : Math_Syntax.Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Array_Value := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Array_Value.Kind /= Array_Node or else
        (Name /= "smallmatrix" and then
         Array_Value.Array_Type /= Cases_Array) or else
        Array_Value.Math_Style /= Style or else
        Array_Value.Amount /= Amount or else
        (Name /= "smallmatrix" and then
         Ada.Strings.Unbounded.To_String (Array_Value.Column_Spec) /= "ll") or else
        Array_Value.Left_Delimiter /= Left or else
        Array_Value.Right_Delimiter /= Right
      then
         raise Program_Error with "wrong environment AST metadata: " & Name;
      end if;
      Ada.Text_IO.Put_Line ("PASS AST metadata and layout " & Name);
   end Check_Environment;

   procedure Check_Invalid_Environment (Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
   begin
      if Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with "accepted non-two-column cases row: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS rejected " & Source);
   end Check_Invalid_Environment;

   procedure Check_Invalid_Node (Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
   begin
      if Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with "accepted invalid geometry: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS rejected " & Source);
   end Check_Invalid_Node;

   procedure Check_Sized_Delimiter
     (Command : String;
      Delimiter : String;
      Expected_Size : Long_Float;
      Expected_Class : Math_Model.Atom_Class;
      Expected_Role : Positive)
   is
      Source : constant String := "\" & Command & Delimiter;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
      Expected_Delimiter : Math_Syntax.Delimiter_Kind;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      Expected_Delimiter :=
        (if Delimiter in "(" | ")" then Math_Syntax.Parenthesis_Delimiter
         elsif Delimiter in "[" | "]" then Math_Syntax.Bracket_Delimiter
         elsif Delimiter in "{" | "}" then Math_Syntax.Brace_Delimiter
         else Math_Syntax.Bar_Delimiter);
      if Item.Kind /= Delimited_Node or else Item.First /= No_Node or else
        Item.Class /= Expected_Class or else Item.Amount /= Expected_Size or else
        Item.Code_Point /= Expected_Role or else
        Item.Left_Delimiter /= Expected_Delimiter or else
        Item.Right_Delimiter /= Math_Syntax.No_Delimiter
      then
         raise Program_Error with "wrong sized delimiter AST: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS sized delimiter " & Source);
   end Check_Sized_Delimiter;

   procedure Check_Unsupported_Delimiter (Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
   begin
      if Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with
           "accepted unsupported sized delimiter: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS rejected " & Source);
   end Check_Unsupported_Delimiter;

   procedure Check_Size_Declaration
     (Source : String; Expected_Scale : Long_Float; Expected_Glyphs : Natural)
   is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Sized_Found : Boolean := False;
      Glyphs : Natural := 0;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      for Index in 1 .. Math_Syntax.Count (Parsed) loop
         declare
            Item : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Index);
         begin
            if Item.Kind = Sized_Node then
               Sized_Found := Item.Scale = Expected_Scale and then
                 Item.First > 0;
            elsif Item.Kind = Glyph_Node then
               Glyphs := Glyphs + 1;
            end if;
         end;
      end loop;
      if not Sized_Found then
         raise Program_Error with "wrong size scale or empty declaration: " &
           Source;
      end if;
      if Glyphs /= Expected_Glyphs then
         raise Program_Error with "size declaration swallowed group boundary: " &
           Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS size declaration " & Source);
   end Check_Size_Declaration;

   procedure Check_Font
     (Source : String;
      Expected : Font_Kind;
      Glyph_Index : Positive := 1) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Found : Natural := 0;
   begin
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      for Index in 1 .. Math_Syntax.Count (Parsed) loop
         declare
            Item : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Index);
         begin
            if Item.Kind = Glyph_Node then
               Found := Found + 1;
               if Found = Glyph_Index then
                  if Item.Font /= Expected then
                     raise Program_Error with Source & ": expected " &
                       Expected'Image & " got " & Item.Font'Image;
                  end if;
                  Ada.Text_IO.Put_Line ("PASS font " & Source);
                  return;
               end if;
            end if;
         end;
      end loop;
      raise Program_Error with Source & ": missing glyph " &
        Positive'Image (Glyph_Index);
   end Check_Font;

   procedure Check_Dimension
     (Source : String;
      Max_Size : Positive;
      Expected : Long_Float)
   is
      Settings : Math_Syntax.Options := (others => <>);
      Parsed : Math_Syntax.Document;
      Root : Math_Syntax.Node;
      Space : Math_Syntax.Node;
   begin
      Settings.Max_Size := Max_Size;
      Parsed := Math_Syntax.Parse (Source, Settings);
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Space := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Space.Kind /= Space_Node or else Space.Amount /= Expected then
         raise Program_Error with "wrong dimension amount for " & Source &
           ": " & Long_Float'Image (Space.Amount);
      end if;
      Ada.Text_IO.Put_Line ("PASS " & Source);
   end Check_Dimension;

begin
      Check_Font ("\bf x", Main_Bold);
      Check_Font ("\bold x", Main_Bold);
      Check_Font ("\cal x", Caligraphic_Regular);
      Check_Font ("\frak x", Fraktur_Regular);
      Check_Font ("\it x", Math_Italic);
      Check_Font ("\rm x", Main_Regular);
      Check_Font ("\sf x", Sans_Serif_Regular);
      Check_Font ("\tt x", Typewriter_Regular);
      Check_Font ("\mathbf{x}", Main_Bold);
      Check_Font ("\mathbb{R}", AMS_Regular);
      Check_Font ("\mathnormal{x}", Math_Italic);
      Check_Font ("\mathsfit{x}", Sans_Serif_Italic);
      Check_Font ("\textbf{A}", Main_Bold);
      Check_Font ("\textit{A}", Main_Italic);
      Check_Font ("\textmd{A}", Main_Regular);
      Check_Font ("\textnormal{A}", Main_Regular);
      Check_Font ("\textrm{A}", Main_Regular);
      Check_Font ("\textsf{A}", Sans_Serif_Regular);
      Check_Font ("\texttt{A}", Typewriter_Regular);
      Check_Font ("\textup{A}", Main_Regular);
      Check_Font ("\emph{A}", Main_Italic);
      Check_Font ("\bf x\alpha", Main_Bold, 2);
      Check_Font ("\bf x\beta", Main_Bold, 2);
      Check_Font ("\cal x\mathbf{\alpha}", Main_Bold, 2);
      Check_Font ("{\bf x}y", Math_Italic, 2);
      Check_Font ("\bf x{\rm y}z", Main_Regular, 2);
      Check_Font ("\bf x{\rm y}z", Main_Bold, 3);
      Check_Dimension ("\kern100em", 10, 10.0);
      Check_Dimension ("\kern{100em}", 10, 10.0);
      Check_Dimension ("\kern500pt", 10, 10.0);
      Check_Dimension ("\kern-101em", 10, -101.0);
      Check_Invalid_Node ("\kern-16385em");
      Check_Dimension ("\kern100em", 100, 100.0);
      Check_Dimension ("\kern1bp", 100, 0.100375);
      Check_Dimension ("\kern1pt", 100, 0.1);
      declare
         Source : constant String :=
           "\approx \equiv \sim \propto \subseteq \notin " &
           "\implies \iff";
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
         Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid then
            raise Program_Error with Source & ": " &
              Math_Syntax.Error (Parsed);
         end if;
         Ada.Text_IO.Put_Line ("PASS relation expression " & Source);
      end;
      Check_Dimension ("\kern-16384em", 1, -16_384.0);
      Check_Dimension ("\kern-101em", 1, -101.0);
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\message{first}\errmessage{second}x");
         First_Message : constant Math_Syntax.Diagnostic :=
           Math_Syntax.Diagnostic_At (Parsed, 1);
         Second_Message : constant Math_Syntax.Diagnostic :=
           Math_Syntax.Diagnostic_At (Parsed, 2);
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else
           Math_Syntax.Diagnostic_Count (Parsed) /= 2 or else
           Ada.Strings.Unbounded.To_String (First_Message.Message) /= "first" or else
           First_Message.Kind /= Math_Syntax.Warning or else
           Ada.Strings.Unbounded.To_String (Second_Message.Message) /= "second" or else
           Second_Message.Kind /= Math_Syntax.Refusal
         then
            raise Program_Error with
              "primitive diagnostics lost text, severity, or parse validity";
         end if;
         Ada.Text_IO.Put_Line
           ("PASS parser retains both primitive diagnostics");
      end;
   Check_Environment
     ("smallmatrix", Script_Style, 0.5, Math_Syntax.No_Delimiter,
      Math_Syntax.No_Delimiter);
   Check_Environment
     ("cases", Text_Style, 1.2, Math_Syntax.Brace_Delimiter,
      Math_Syntax.No_Delimiter);
   Check_Environment
     ("dcases", Display_Style, 1.2, Math_Syntax.Brace_Delimiter,
      Math_Syntax.No_Delimiter);
   Check_Environment
     ("drcases", Display_Style, 1.2, Math_Syntax.No_Delimiter,
      Math_Syntax.Brace_Delimiter);
   Check_Environment
     ("rcases", Text_Style, 1.2, Math_Syntax.No_Delimiter,
      Math_Syntax.Brace_Delimiter);
   Check_Invalid_Environment
     ("\begin{dcases}a&b&c\end{dcases}");
   Check_Invalid_Environment
     ("\begin{rcases}a&b\\c\end{rcases}");
   Check_Fraction ("\frac{a}{b}", Default_Rule);
   Check_Fraction ("\genfrac{}{}{0pt}{}{a}{b}", No_Rule,
     Thickness => 0.0);
   Check_Fraction ("\genfrac{(}{)}{0.2pt}{2}{a}{b}", Custom_Rule,
     Script_Style, Left => Math_Syntax.Parenthesis_Delimiter,
     Thickness => 0.02);
   Check_Fraction ("\cfrac{a}{b}", Default_Rule, Display_Style, True);
   Check_Fraction ("\cfrac[l]{a}{b}", Default_Rule, Display_Style, True,
     Alignment => Left_Fraction);
   Check_Fraction ("a\over b", Default_Rule);
   Check_Fraction ("a\over bc", Default_Rule);
   Check_Fraction ("a\choose b", No_Rule,
     Left => Math_Syntax.Parenthesis_Delimiter);
   Check_Fraction ("a\atop b", No_Rule);
   Check_Fraction ("a\brace b", No_Rule, Left =>
     Math_Syntax.Brace_Delimiter);
   Check_Fraction ("a\brack b", No_Rule, Left =>
     Math_Syntax.Bracket_Delimiter);
   Check_Fraction ("a\above{0pt}b", No_Rule, Thickness => 0.0);
   Check_Fraction ("a\above{0.2pt}b", Custom_Rule,
     Thickness => 0.02);
   Check_Invalid_Fraction ("a\over b\choose c", 9);
   Check_Invalid_Fraction ("\over a", 1);
   Check_Invalid_Fraction ("a\over", 2);
   Check_Limit ("\sum\limits_{i}", Limit_Scripts);
   Check_Node ("\begin{matrix*}a&b\\c&d\end{matrix*}", Array_Node);
   Check_Node ("\begin{pmatrix*}a&b\\c&d\end{pmatrix*}", Array_Node);
   Check_Node ("\begin{bmatrix*}a&b\\c&d\end{bmatrix*}", Array_Node);
   Check_Node ("\begin{Bmatrix*}a&b\\c&d\end{Bmatrix*}", Array_Node);
   Check_Node ("\begin{vmatrix*}a&b\\c&d\end{vmatrix*}", Array_Node);
   Check_Node ("\begin{Vmatrix*}a&b\\c&d\end{Vmatrix*}", Array_Node);
   Check_Node ("\begin{align*}a&=b\\c&=d\end{align*}", Array_Node);
   Check_Node ("\begin{alignat*}{1}a&=b\\c&=d\end{alignat*}", Array_Node);
   Check_Node ("\begin{gather}a\\b\end{gather}", Array_Node);
   Check_Node ("\begin{gather*}a\\b\end{gather*}", Array_Node);
   Check_Node ("\begin{split}a&=b\\c&=d\end{split}", Array_Node);
   Check_Node ("\begin{darray}{lc}a&b\end{darray}", Array_Node);
   Check_Sized_Delimiter ("big", "(", 1.2, Opening, 1);
   Check_Sized_Delimiter ("Big", "[", 1.8, Opening, 1);
   Check_Sized_Delimiter ("bigg", "{", 2.4, Opening, 1);
   Check_Sized_Delimiter ("Bigg", "|", 3.0, Ordinary, 1);
   Check_Sized_Delimiter ("bigl", "(", 1.2, Opening, 2);
   Check_Sized_Delimiter ("Bigl", "[", 1.8, Opening, 2);
   Check_Sized_Delimiter ("biggl", "{", 2.4, Opening, 2);
   Check_Sized_Delimiter ("Biggl", "|", 3.0, Ordinary, 2);
   Check_Sized_Delimiter ("bigr", ")", 1.2, Closing, 3);
   Check_Sized_Delimiter ("Bigr", "]", 1.8, Closing, 3);
   Check_Sized_Delimiter ("biggr", "}", 2.4, Closing, 3);
   Check_Sized_Delimiter ("Biggr", "|", 3.0, Ordinary, 3);
   Check_Sized_Delimiter ("bigm", "|", 1.2, Ordinary, 4);
   Check_Sized_Delimiter ("Bigm", "|", 1.8, Ordinary, 4);
   Check_Sized_Delimiter ("biggm", "|", 2.4, Ordinary, 4);
   Check_Sized_Delimiter ("Biggm", "|", 3.0, Ordinary, 4);
   Check_Unsupported_Delimiter ("\big");
   Check_Unsupported_Delimiter ("\big x");
   Check_Unsupported_Delimiter ("\big\unknown");
   Check_Node ("\arcctg(x)", Row_Node);
   Check_Node ("\cosec(x)", Row_Node);
   Check_Node ("\Bbb{R}", Row_Node);
   Check_Unsupported ("\begin{gather}a&b\end{gather}");
   Check_Unsupported ("\begin{align*}a&b&c\end{align}");
   Check_Unsupported ("\begin{matrix*}a&b\end{matrix}");
   Check_Limit ("\sum\displaylimits_{i}", Limit_Scripts);
   Check_Limit ("\sum\nolimits_{i}", Side_Scripts);
   Check_Limit ("\bigcup\nolimits_{i}", Side_Scripts);
   Check_Limit ("\int\limits_{i}", Limit_Scripts);
   Check_Limit ("\sum_{i}", Limit_Scripts);
   Check_Limit ("\prod_{i}", Limit_Scripts);
   Check_Limit ("\coprod_{i}", Limit_Scripts);
   Check_Limit ("\bigcap_{i}", Limit_Scripts);
   Check_Limit ("\bigcup_{i}", Limit_Scripts);
   Check_Limit ("\bigodot_{i}", Limit_Scripts);
   Check_Limit ("\bigoplus_{i}", Limit_Scripts);
   Check_Limit ("\bigotimes_{i}", Limit_Scripts);
   Check_Limit ("\bigsqcup_{i}", Limit_Scripts);
   Check_Limit ("\biguplus_{i}", Limit_Scripts);
   Check_Limit ("\bigvee_{i}", Limit_Scripts);
   Check_Limit ("\bigwedge_{i}", Limit_Scripts);
   Check_Limit ("\int_{i}", Side_Scripts);
   Check_Limit ("\iint_{i}", Side_Scripts);
   Check_Limit ("\iiint_{i}", Side_Scripts);
   Check_Limit ("\oint_{i}", Side_Scripts);
   Check_Limit ("\limsup_{x}x", Limit_Scripts);
   Check_Limit ("\argmax_{x}f(x)", Limit_Scripts);
   Check_Node ("\Pr(A)", Row_Node);
   Check_Node ("\overset{a}{=}", Annotation_Node);
   Check_Node ("\underset{i}{=}", Annotation_Node, Under => True);

   Check_Brace ("\overbrace{x}", Over_Brace_Code_Point);
   Check_Brace ("\underbrace{x}", Under_Brace_Code_Point);
   Check_Node ("\overbrace{x+y}^{n}", Scripts_Node);
   Check_Node ("\underbrace{x+y}_{n}", Scripts_Node);
   Check_Node ("\overrightarrow{xy}", Accent_Node);
   Check_Node ("\overleftarrow{xy}", Accent_Node);
   Check_Stretchy ("\overleftharpoon[b]{a}", "overleftharpoon", 0);
   Check_Stretchy ("\overrightharpoon[b]{a}", "overrightharpoon", 0);
   Check_Brace_Paths;
   Check_Stretchy ("\underrightarrow{x}", "underrightarrow", 0,
     Under => True);
   Check_Stretchy ("\underleftarrow{x}", "underleftarrow", 0,
     Under => True);
   Check_Stretchy ("\overleftrightarrow{x}", "overleftrightarrow", 0);
   Check_Stretchy ("\underleftrightarrow{x}", "underleftrightarrow", 0,
     Under => True);
   Check_Stretchy ("\xrightarrow[b]{a}", "xrightarrow", 1);
   Check_Stretchy ("\xleftarrow[b]{a}", "xleftarrow", 1);
   Check_Stretchy ("\Overrightarrow{a}", "Overrightarrow", 0);
   Check_Stretchy ("\Overrightarrow[b]{a}", "Overrightarrow", 0);
   Check_Stretchy ("\xRightarrow{a}", "xRightarrow", 1);
   Check_Stretchy ("\xLeftarrow{a}", "xLeftarrow", 1);
   Check_Stretchy ("\overleftharpoon{a}", "overleftharpoon", 0);
   Check_Stretchy ("\overrightharpoon{a}", "overrightharpoon", 0);
   Check_Stretchy ("\xleftharpoonup{a}", "xleftharpoonup", 1);
   Check_Stretchy ("\xleftharpoondown{a}", "xleftharpoondown", 1);
   Check_Stretchy ("\xrightharpoonup{a}", "xrightharpoonup", 1);
   Check_Stretchy ("\xrightharpoondown{a}", "xrightharpoondown", 1);
   Check_Stretchy ("\xlongequal{a}", "xlongequal", 1);
   Check_Stretchy ("\xtwoheadleftarrow{a}", "xtwoheadleftarrow", 1);
   Check_Stretchy ("\xtwoheadrightarrow{a}", "xtwoheadrightarrow", 1);
   Check_Stretchy ("\xleftrightarrow{a}", "xleftrightarrow", 1);
   Check_Stretchy ("\xLeftrightarrow{a}", "xLeftrightarrow", 1);
   Check_Stretchy ("\xrightleftharpoons{a}", "xrightleftharpoons", 1);
   Check_Stretchy ("\xleftrightharpoons{a}", "xleftrightharpoons", 1);
   Check_Stretchy ("\xhookleftarrow{a}", "xhookleftarrow", 1);
   Check_Stretchy ("\xhookrightarrow{a}", "xhookrightarrow", 1);
   Check_Stretchy ("\overlinesegment{x}", "overlinesegment", 0);
   Check_Stretchy ("\underlinesegment{x}", "underlinesegment", 0,
     Under => True);
   Check_Stretchy ("\overgroup{x}", "overgroup", 0);
   Check_Stretchy ("\undergroup{x}", "undergroup", 0, Under => True);
   Check_Stretchy ("\xmapsto{a}", "xmapsto", 1);
   Check_Stretchy ("\xtofrom{a}", "xtofrom", 1);
   Check_Stretchy ("\xrightleftarrows{a}", "xrightleftarrows", 1);
   Check_Stretchy ("\xrightequilibrium{a}", "xrightequilibrium", 1);
   Check_Stretchy ("\xleftequilibrium{a}", "xleftequilibrium", 1);
   Check_Node ("\cancel{x}", Enclosed_Node);
   Check_Node ("\bcancel{x}", Enclosed_Node);
   Check_Node ("\xcancel{x}", Enclosed_Node);
   Check_Node ("\sout{x}", Enclosed_Node);
   Check_Node ("\rule{2em}{0.5em}", Rule_Node);
   Check_Node ("\raisebox{2pt}{x}", Raised_Node);
   Check_Node ("\tiny{x}", Sized_Node);
   Check_Invalid_Node ("\rule{-2em}{0.5em}");
   Check_Invalid_Node ("\rule{2em}{-0.5em}");
   Check_Invalid_Node ("\kern16385em");
   Check_Size_Declaration ("\tiny abc", 0.5, 3);
   Check_Size_Declaration ("\sixptsize abc", 0.6, 3);
   Check_Size_Declaration ("\scriptsize abc", 0.7, 3);
   Check_Size_Declaration ("{\tiny abc}d", 0.5, 4);
   Check_Size_Declaration ("\normalsize abc", 1.0, 3);
   Check_Node ("\begin{matrix}\normalsize a&b\\c&d\end{matrix}",
     Array_Node);
   declare
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\mathchoice{D}{T}{S}{Q}");
      Semantics : constant Math_Semantics.Document :=
        Math_Semantics.Project (Parsed);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Roles : constant array (Positive range 1 .. 4) of
        Math_Semantics.Child_Role :=
          (Math_Semantics.Display_Choice_Text,
           Math_Semantics.Text_Choice_Text,
           Math_Semantics.Script_Choice_Text,
           Math_Semantics.Scriptscript_Choice_Text);
      Root_Node : Math_Syntax.Node;
      Choice : Math_Syntax.Node;
      Semantic_Choice : Math_Semantics.Semantic_Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else
        not Math_Semantics.Is_Valid (Semantics) or else not Geometry.Valid
      then
         raise Program_Error with "MathChoice parse/projection/layout failed";
      end if;
      Root_Node := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Choice := Math_Syntax.Element (Parsed, Positive (Root_Node.First));
      Semantic_Choice := Math_Semantics.Element
        (Semantics, Positive (Math_Semantics.Root (Semantics) + 1));
      if Choice.Kind /= MathChoice_Node or else Choice.First = No_Node or else
        Choice.Second = No_Node or else Choice.Third = No_Node or else
        Choice.Fourth = No_Node or else Semantic_Choice.Child_Count /= 4
      then
         raise Program_Error with "MathChoice AST lost a branch";
      end if;
      for Branch in Roles'Range loop
         declare
            AST_Branch : constant Node_Id :=
              (case Branch is
                 when 1 => Choice.First,
                 when 2 => Choice.Second,
                 when 3 => Choice.Third,
                 when 4 => Choice.Fourth);
            Semantic_Branch : constant Math_Semantics.Semantic_Node :=
              Math_Semantics.Element
                (Semantics,
                 Positive (Math_Semantics.Root (Semantics) + 1 + Branch));
         begin
            if AST_Branch = No_Node or else
              Semantic_Branch.Role /= Roles (Branch) or else
              Semantic_Branch.AST_Id /= AST_Branch
            then
               raise Program_Error with "MathChoice semantic roles/order lost";
            end if;
         end;
      end loop;
      Ada.Text_IO.Put_Line ("PASS MathChoice four branches and roles");
   end;
   declare
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\hbox{a $b$ c}");
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root_Node : Math_Syntax.Node;
      Wrapper : Math_Syntax.Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid then
         raise Program_Error with "hbox parse/layout failed: " &
           Math_Syntax.Error (Parsed);
      end if;
      Root_Node := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Wrapper := Math_Syntax.Element (Parsed, Positive (Root_Node.First));
      if Wrapper.Kind /= Row_Node or else Wrapper.First = No_Node then
         raise Program_Error with "hbox row wrapper lost";
      end if;
      Ada.Text_IO.Put_Line ("PASS hbox regular-mode row wrapper");
   end;
   declare
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\hbox{$x^2$}");
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root_Node : Math_Syntax.Node;
      Wrapper : Math_Syntax.Node;
      Content : Math_Syntax.Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid then
         raise Program_Error with "hbox dollar-math script parse/layout failed: " &
           Math_Syntax.Error (Parsed);
      end if;
      Root_Node := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Wrapper := Math_Syntax.Element (Parsed, Positive (Root_Node.First));
      if Wrapper.Kind /= Row_Node or else Wrapper.First = No_Node then
         raise Program_Error with "hbox Greek/script row wrapper lost";
      end if;
      Content := Math_Syntax.Element (Parsed, Positive (Wrapper.First));
      if Content.Kind /= Row_Node or else Content.First = No_Node then
         raise Program_Error with "hbox dollar-math row failed";
      end if;
      Ada.Text_IO.Put_Line ("PASS hbox dollar-math baseline layout");
   end;
end Math_Additional_Probe;
