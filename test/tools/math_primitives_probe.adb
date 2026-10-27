with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Ada.Containers;
with Math_Layout;
with Math_Model;
with Math_Macros;
with Math_Syntax;

procedure Math_Primitives_Probe is
   use Math_Model;
   use type Ada.Containers.Count_Type;
   Checks : Natural := 0;
   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         raise Program_Error with "FAIL " & Label;
      end if;
      Ada.Text_IO.Put_Line ("PASS " & Label);
   end Check;
   function Parse (Source : String) return Math_Syntax.Document is
     (Math_Syntax.Parse (Source));
   function Width (Source : String) return Long_Float is
      Item : constant Math_Syntax.Document := Parse (Source);
      Box : constant Math_Layout.Box := Math_Layout.Build (Item);
   begin
      if not Math_Syntax.Is_Valid (Item) or else not Box.Valid then
         raise Program_Error with Source & ": " & Math_Syntax.Error (Item);
      end if;
      return Box.Width;
   end Width;
begin
   Check (abs (Width ("x\hskip1em\relax y") -
     Width ("x y") - 1.0) < 0.0001, "hskip-em-and-relax");
   Check (abs (Width ("x\kern2ex y") - Width ("x y") - 0.862) <
     0.0001, "kern-ex");
   Check (abs (Width ("x\mkern18mu y") - Width ("x y") - 1.0) <
     0.0001, "mkern-mu");
   Check (abs (Width ("x\mskip10pt y") - Width ("x y") - 1.0) <
     0.0001, "mskip-pt");
   declare
      Clamped : constant Math_Syntax.Document := Parse ("\hskip101em");
      Root : constant Math_Syntax.Node := Math_Syntax.Element
        (Clamped, Positive (Math_Syntax.Root (Clamped)));
      Space : constant Math_Syntax.Node := Math_Syntax.Element
        (Clamped, Positive (Root.First));
   begin
      Check (Math_Syntax.Is_Valid (Clamped) and then Space.Amount = 100.0,
        "dimension-clamped-at-100em");
   end;
   Check (not Math_Syntax.Is_Valid (Parse ("x\hskip1zz")),
     "unsupported-unit");
   Check (Math_Syntax.Is_Valid (Parse ("\relax")), "relax-alone");
   declare
      Item : constant Math_Syntax.Document := Parse ("\mathrel{{x}}");
      Root : constant Math_Syntax.Node := Math_Syntax.Element
        (Item, Positive (Math_Syntax.Root (Item)));
      Wrapper : constant Math_Syntax.Node := Math_Syntax.Element
        (Item, Positive (Root.First));
   begin
      Check (Math_Syntax.Is_Valid (Item) and then Wrapper.Kind = Row_Node
        and then Wrapper.Class = Relation_Atom, "mathrel-nested-class");
   end;
   declare
      Item : constant Math_Syntax.Document := Parse ("\char64");
      Box : constant Math_Layout.Box := Math_Layout.Build (Item);
   begin
      Check (Box.Valid and then Box.Commands.First_Element.Code_Point = 64,
        "char-decimal");
   end;
   declare
      Item : constant Math_Syntax.Document := Parse ("\char`\{");
      Box : constant Math_Layout.Box := Math_Layout.Build (Item);
   begin
      Check (Box.Valid and then Box.Commands.First_Element.Code_Point = 123,
        "char-control-symbol");
   end;
   declare
      Item : constant Math_Syntax.Document := Parse ("\char64+");
      Box : constant Math_Layout.Box := Math_Layout.Build (Item);
   begin
      Check (Box.Valid and then Box.Commands.Length = 2 and then
        Box.Commands.First_Element.Code_Point = 64 and then
        Box.Commands.Last_Element.Code_Point = Character'Pos ('+'),
        "char-decimal-leaves-next-token");
   end;
   declare
      Item : constant Math_Syntax.Document := Parse
        ("\message{diagnostic}x");
   begin
      Check (Math_Syntax.Is_Valid (Item) and then
        Math_Syntax.Diagnostic_Count (Item) = 1 and then
        Ada.Strings.Unbounded.To_String
          (Math_Syntax.Diagnostic_At (Item, 1).Message) = "diagnostic",
        "primitive-diagnostic-forwarded-once");
   end;
   declare
      Right : constant Math_Syntax.Document := Parse ("\mathrlap{W}");
      Left : constant Math_Syntax.Document := Parse ("\mathllap{W}");
      Center : constant Math_Syntax.Document := Parse ("\mathclap{W}");
      Right_Box : constant Math_Layout.Box := Math_Layout.Build (Right);
      Left_Box : constant Math_Layout.Box := Math_Layout.Build (Left);
      Center_Box : constant Math_Layout.Box := Math_Layout.Build (Center);
      Right_Row : constant Math_Syntax.Node := Math_Syntax.Element
        (Right, Positive (Math_Syntax.Root (Right)));
      Left_Row : constant Math_Syntax.Node := Math_Syntax.Element
        (Left, Positive (Math_Syntax.Root (Left)));
      Center_Row : constant Math_Syntax.Node := Math_Syntax.Element
        (Center, Positive (Math_Syntax.Root (Center)));
      Right_Node : constant Math_Syntax.Node := Math_Syntax.Element
        (Right, Positive (Right_Row.First));
      Left_Node : constant Math_Syntax.Node := Math_Syntax.Element
        (Left, Positive (Left_Row.First));
      Center_Node : constant Math_Syntax.Node := Math_Syntax.Element
        (Center, Positive (Center_Row.First));
   begin
      Check (Right_Box.Valid and then Left_Box.Valid and then
        Center_Box.Valid and then Right_Box.Width = 0.0 and then
        Left_Box.Width = 0.0 and then Center_Box.Width = 0.0 and then
        Right_Node.Kind = Overlap_Node and then
        Right_Node.Overlap_Mode = Right_Overlap and then
        Left_Node.Overlap_Mode = Left_Overlap and then
        Center_Node.Overlap_Mode = Center_Overlap,
        "typed-math-overlap-zero-width");
      Check (Right_Box.Commands.First_Element.X < 0.0 and then
        Left_Box.Commands.First_Element.X = 0.0 and then
        Center_Box.Commands.First_Element.X < 0.0,
        "math-overlap-content-offsets");
   end;
   declare
      Item : constant Math_Syntax.Document := Parse ("\mathrlap{W}x");
      Box : constant Math_Layout.Box := Math_Layout.Build (Item);
      Plain : constant Math_Layout.Box := Math_Layout.Build (Parse ("x"));
   begin
      Check (Box.Valid and then abs (Box.Width - Plain.Width) < 0.0001,
        "math-overlap-does-not-advance-layout");
   end;
   declare
      Hex_Item : constant Math_Syntax.Document := Parse ("\char""338");
      Octal_Item : constant Math_Syntax.Document := Parse ("\char'101");
      Hex_Row : constant Math_Syntax.Node := Math_Syntax.Element
        (Hex_Item, Positive (Math_Syntax.Root (Hex_Item)));
      Octal_Row : constant Math_Syntax.Node := Math_Syntax.Element
        (Octal_Item, Positive (Math_Syntax.Root (Octal_Item)));
      Hex_Glyph : constant Math_Syntax.Node := Math_Syntax.Element
        (Hex_Item, Positive (Hex_Row.First));
      Octal_Glyph : constant Math_Syntax.Node := Math_Syntax.Element
        (Octal_Item, Positive (Octal_Row.First));
   begin
      Check (Math_Syntax.Is_Valid (Hex_Item) and then
        Hex_Glyph.Code_Point = 16#338#, "char-hexadecimal");
      Check (Math_Syntax.Is_Valid (Octal_Item) and then
        Octal_Glyph.Code_Point = 65, "char-octal");
   end;
   Check (Math_Syntax.Is_Valid (Parse ("\notin")), "notin-registry-alias");
   Check (Math_Syntax.Is_Valid (Parse ("\AA")), "AA-ring-accent");
   declare
      Registered : constant Math_Syntax.Document := Parse ("\textregistered");
      Row : constant Math_Syntax.Node := Math_Syntax.Element
        (Registered, Positive (Math_Syntax.Root (Registered)));
      Glyph : constant Math_Syntax.Node := Math_Syntax.Element
        (Registered, Positive (Row.First));
   begin
      Check (Math_Syntax.Is_Valid (Registered) and then
        Glyph.Kind = Glyph_Node and then Glyph.Code_Point = 16#00AE#,
        "textregistered-native-registered-glyph");
   end;
   Check (Math_Syntax.Is_Valid (Parse ("\text{\r{A}}")),
     "text-ring-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\H{o}}")),
     "text-double-acute-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\" & Character'Val (34) & "{o}}")),
     "text-diaeresis-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\`{a}}")),
     "text-grave-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\'{a}}")),
     "text-acute-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\^{a}}")),
     "text-circumflex-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\~{n}}")),
     "text-tilde-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\={a}}")),
     "text-macron-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\.{a}}")),
     "text-dot-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\u{a}}")),
     "text-breve-accent");
   Check (Math_Syntax.Is_Valid (Parse ("\text{\v{s}}")),
     "text-caron-accent");
   Check (not Math_Syntax.Is_Valid (Parse ("\text{\c{c}}")),
     "text-cedilla-not-falsely-rendered");
   declare
      procedure Check_Diagnostic (Source : String) is
         Bad : constant Math_Syntax.Document := Parse (Source);
      begin
         Check (not Math_Syntax.Is_Valid (Bad) and then
           Math_Syntax.Error_Position (Bad) in 1 .. Source'Length + 1,
           "fresh-diagnostic-in-source-range");
      end Check_Diagnostic;
   begin
      Check_Diagnostic ("\unknown");
      Check_Diagnostic ("\textcolor{blue}{\unknown}");
   end;
   declare
      Shared : aliased Math_Macros.Context;
      Defined : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\gdef\stale{\unknown}x", Shared'Access);
      Expanded : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\stale", Shared'Access);
   begin
      Check (Math_Syntax.Is_Valid (Defined), "persisted-macro-definition");
      Check (not Math_Syntax.Is_Valid (Expanded) and then
        Math_Syntax.Error_Position (Expanded) in 1 .. 7,
        "persisted-macro-diagnostic-rebased-to-invocation");
   end;
   Check (Math_Syntax.Is_Valid (Parse ("\operatorname*{lim}_x")),
     "operatorname-star-limit-macro");
   Check (Math_Syntax.Is_Valid (Parse ("\operatorname{rank} A")),
     "operatorname-at-nextchar-worker");
   declare
      Item : constant Math_Syntax.Document := Parse
        ("\boxed{$\displaystyle{x}$}");
      Box : constant Math_Layout.Box := Math_Layout.Build (Item);
   begin
      Check (Math_Syntax.Is_Valid (Item) and then Box.Valid,
        "boxed-display-math");
   end;
   Ada.Text_IO.Put_Line ("PASS total=" & Checks'Image);
end Math_Primitives_Probe;
