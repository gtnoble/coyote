with Ada.Containers;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Math_Engine;
with Math_Layout;
with Math_Macros;
with Math_Tokens;
with Math_Source;
with Math_Model;
with Math_Syntax;
with Math_Semantics;
with Math_Stretchy;
with Math_Paths;
with Math_Metrics;

procedure Math_Additional_Probe is
   use Math_Model;
   use type Ada.Containers.Count_Type;
   use type Math_Engine.Status_Kind;
   use type Math_Syntax.Delimiter_Kind;
   use type Math_Syntax.Diagnostic_Kind;
   use type Math_Semantics.Child_Role;
   use type Ada.Strings.Unbounded.Unbounded_String;
   use type Math_Layout.Command_Kind;
   use type Math_Source.Diagnostic_Kind;
   use type Math_Tokens.Diagnostic_Kind;
   use type Math_Tokens.Token_Kind;
   use type Math_Macros.Diagnostic_Kind;

   Shared : aliased Math_Macros.Context;

   type Test_Advance_Source is new Math_Metrics.Advance_Source with null record;

   overriding function Advance
     (Item       : Test_Advance_Source;
      Font       : Font_Kind;
      Code_Point : Natural;
      Pixel_Em   : Long_Float) return Long_Float;

   overriding function Font_Line_Extents
     (Item     : Test_Advance_Source;
      Font     : Font_Kind;
      Pixel_Em : Long_Float) return Math_Metrics.Font_Line_Extent;

   overriding function Font_Line_Height
     (Item     : Test_Advance_Source;
      Font     : Font_Kind;
      Pixel_Em : Long_Float) return Long_Float;

   overriding function Advance
     (Item       : Test_Advance_Source;
      Font       : Font_Kind;
      Code_Point : Natural;
      Pixel_Em   : Long_Float) return Long_Float is
      pragma Unreferenced (Item);
      pragma Unreferenced (Code_Point);
   begin
      if Font /= Typewriter_Regular then
         raise Program_Error with "measured source got unexpected font";
      end if;
      return Pixel_Em * 0.75;
   end Advance;

   overriding function Font_Line_Extents
     (Item     : Test_Advance_Source;
      Font     : Font_Kind;
      Pixel_Em : Long_Float) return Math_Metrics.Font_Line_Extent is
      pragma Unreferenced (Item, Font);
   begin
      return
        (Ascent => Pixel_Em * 0.8,
         Descent => Pixel_Em * 0.2,
         Height => Pixel_Em * 1.25);
   end Font_Line_Extents;

   overriding function Font_Line_Height
     (Item     : Test_Advance_Source;
      Font     : Font_Kind;
      Pixel_Em : Long_Float) return Long_Float is
      pragma Unreferenced (Item, Font);
   begin
      return Pixel_Em * 1.25;
   end Font_Line_Height;

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

   procedure Check_Internal_Class
     (Class_Name, Body_Name : String; Expected : Atom_Class) is
      Source : Math_Source.Source;
      Stream : Math_Tokens.Stream;
      Source_Diagnostic : Math_Source.Diagnostic_Kind;
      Token_Diagnostic : Math_Tokens.Diagnostic_Kind;
      Macro_Diagnostic : Math_Macros.Diagnostic_Kind;
      Error_Byte : Natural;
      Replacement : Math_Macros.Token_Sequence (1 .. 1);
      Parsed : Math_Syntax.Document;
      Root : Math_Syntax.Node;
      Value : Math_Syntax.Node;
      Semantics : Math_Semantics.Document;
   begin
      Math_Source.Create (Class_Name, Source, Source_Diagnostic, Error_Byte);
      Math_Tokens.Lex (Source, Stream, Token_Diagnostic, Error_Byte);
      Replacement (1) := Math_Tokens.Element (Stream, 1);
      Replacement (1).Kind := Math_Tokens.Control_Word;
      Replacement (1).Lexeme := Ada.Strings.Unbounded.To_Unbounded_String
        (Class_Name);
      Math_Macros.Define_Tokens
        (Shared, "\class", 0, Replacement, False, Macro_Diagnostic);
      if Source_Diagnostic /= Math_Source.No_Error or else
        Token_Diagnostic /= Math_Tokens.No_Error or else
        Macro_Diagnostic /= Math_Macros.No_Error
      then
         raise Program_Error with "internal mclass token setup failed";
      end if;
      Math_Source.Create (Body_Name, Source, Source_Diagnostic, Error_Byte);
      Math_Tokens.Lex (Source, Stream, Token_Diagnostic, Error_Byte);
      Replacement (1) := Math_Tokens.Element (Stream, 1);
      Replacement (1).Kind := Math_Tokens.Control_Word;
      Replacement (1).Lexeme := Ada.Strings.Unbounded.To_Unbounded_String
        (Body_Name);
      Math_Macros.Define_Tokens
        (Shared, "\body", 0, Replacement, False, Macro_Diagnostic);
      if Macro_Diagnostic /= Math_Macros.No_Error then
         raise Program_Error with "internal mclass body token setup failed";
      end if;
      Math_Source.Create ("\@binrel", Source, Source_Diagnostic, Error_Byte);
      Math_Tokens.Lex (Source, Stream, Token_Diagnostic, Error_Byte);
      Replacement (1) := Math_Tokens.Element (Stream, 1);
      Replacement (1).Kind := Math_Tokens.Control_Word;
      Replacement (1).Lexeme := Ada.Strings.Unbounded.To_Unbounded_String
        ("\\@binrel");
      Math_Macros.Define_Tokens
        (Shared, "\binrel", 0, Replacement, False, Macro_Diagnostic);
      if Macro_Diagnostic /= Math_Macros.No_Error then
         raise Program_Error with "internal mclass function setup failed";
      end if;
      Parsed := Math_Syntax.Parse
        ("\binrel{" & Class_Name & "{=}}{\alpha}", Shared'Access);
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with "internal mclass parse failed: " &
           Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Value := Math_Syntax.Element (Parsed, Positive (Root.First));
      Semantics := Math_Semantics.Project (Parsed);
      if Value.Class /= Expected or else
        not Math_Layout.Build (Parsed).Valid or else
        not Math_Semantics.Is_Valid (Semantics) or else
        Math_Semantics.Element
          (Semantics, Positive (Math_Semantics.Root (Semantics) + 1)).Class /=
            Expected
      then
         raise Program_Error with "wrong internal mclass class transfer: AST=" &
           Value.Class'Image & " expected=" & Expected'Image & " semantic=" &
           Math_Semantics.Element
             (Semantics, Positive (Math_Semantics.Root (Semantics) + 1)).Class'Image;
      end if;
      Ada.Text_IO.Put_Line ("PASS internal mclass " & Class_Name);
   end Check_Internal_Class;

   procedure Check_Internal_Fraction
     (Name, Call, Expected_Name : String;
      Bar : Fraction_Bar_Mode;
      Left : Math_Syntax.Delimiter_Kind := Math_Syntax.No_Delimiter;
      Thickness : Long_Float := -1.0) is
      Source : Math_Source.Source;
      Stream : Math_Tokens.Stream;
      Source_Diagnostic : Math_Source.Diagnostic_Kind;
      Token_Diagnostic : Math_Tokens.Diagnostic_Kind;
      Macro_Diagnostic : Math_Macros.Diagnostic_Kind;
      Error_Byte : Natural;
      Replacement : Math_Macros.Token_Sequence (1 .. 1);
      Parsed : Math_Syntax.Document;
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
   begin
      Math_Source.Create (Expected_Name, Source, Source_Diagnostic, Error_Byte);
      Math_Tokens.Lex (Source, Stream, Token_Diagnostic, Error_Byte);
      if Source_Diagnostic /= Math_Source.No_Error or else
        Token_Diagnostic /= Math_Tokens.No_Error
      then
         raise Program_Error with "internal command token setup failed";
      end if;
      Replacement (1) := Math_Tokens.Element (Stream, 1);
      Replacement (1).Kind := Math_Tokens.Control_Word;
      Replacement (1).Lexeme :=
        Ada.Strings.Unbounded.To_Unbounded_String (Expected_Name);
      Math_Macros.Define_Tokens
        (Shared, Name, 0, Replacement, False, Macro_Diagnostic);
      if Macro_Diagnostic /= Math_Macros.No_Error then
         raise Program_Error with "internal command macro definition failed";
      end if;
      Parsed := Math_Syntax.Parse (Call, Shared'Access);
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Call & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind /= Fraction_Node or else Item.Fraction_Bar /= Bar or else
        Item.Left_Delimiter /= Left or else
        abs (Item.Fraction_Rule_Thickness - Thickness) > 0.000_000_001 or else
        not Math_Layout.Build (Parsed).Valid or else
        not Math_Semantics.Is_Valid (Math_Semantics.Project (Parsed))
      then
         raise Program_Error with "internal helper payload/layout failed: " &
           Expected_Name;
      end if;
      Ada.Text_IO.Put_Line ("PASS internal fraction " & Expected_Name);
   end Check_Internal_Fraction;

   procedure Check_Internal_Command
     (Name, Call, Expected_Name : String;
      Expected_Kind : Node_Kind;
      Expected_Stretchy : Boolean := False) is
      Source : Math_Source.Source;
      Stream : Math_Tokens.Stream;
      Source_Diagnostic : Math_Source.Diagnostic_Kind;
      Token_Diagnostic : Math_Tokens.Diagnostic_Kind;
      Macro_Diagnostic : Math_Macros.Diagnostic_Kind;
      Error_Byte : Natural;
      Replacement : Math_Macros.Token_Sequence (1 .. 1);
      Parsed : Math_Syntax.Document;
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
      Meaning : Math_Semantics.Document;
   begin
      Math_Source.Create (Expected_Name, Source, Source_Diagnostic, Error_Byte);
      Math_Tokens.Lex (Source, Stream, Token_Diagnostic, Error_Byte);
      if Source_Diagnostic /= Math_Source.No_Error or else
        Token_Diagnostic /= Math_Tokens.No_Error
      then
         raise Program_Error with "internal command token setup failed";
      end if;
      Replacement (1) := Math_Tokens.Element (Stream, 1);
      Replacement (1).Kind := Math_Tokens.Control_Word;
      Replacement (1).Lexeme :=
        Ada.Strings.Unbounded.To_Unbounded_String
          ((if Expected_Name (Expected_Name'First) = '\'
            then Expected_Name else "\\" & Expected_Name));
      Math_Macros.Define_Tokens
        (Shared, Name, 0, Replacement, False, Macro_Diagnostic);
      if Macro_Diagnostic /= Math_Macros.No_Error then
         raise Program_Error with "internal command macro definition failed";
      end if;
      Parsed := Math_Syntax.Parse (Call, Shared'Access);
      Meaning := Math_Semantics.Project (Parsed);
      if not Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with Call & ": " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind /= Expected_Kind or else
        not Math_Layout.Build (Parsed).Valid or else
        not Math_Semantics.Is_Valid (Meaning)
      then
         raise Program_Error with "internal command branch failed: " & Name &
           " kind=" & Item.Kind'Image & " layout=" &
           Boolean'Image (Math_Layout.Build (Parsed).Valid) &
           " semantics=" & Boolean'Image
             (Math_Semantics.Is_Valid (Meaning)) & " stretchy=" &
           Ada.Strings.Unbounded.To_String (Item.Stretchy_Name);
      end if;
      if Expected_Stretchy and then
        Ada.Strings.Unbounded.To_String (Item.Stretchy_Name) /=
          (if Expected_Name (Expected_Name'First) = '\'
           then Expected_Name (Expected_Name'First + 1 .. Expected_Name'Last)
           else Expected_Name)
      then
         raise Program_Error with "internal CD arrow name changed: " & Name;
      end if;
      Ada.Text_IO.Put_Line ("PASS internal command " & Name);
   end Check_Internal_Command;

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

   procedure Check_Accent_Geometry
     (Source : String; Selector : Natural; Name : String;
      Under : Boolean := False)
   is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
      Found : Boolean := False;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid then
         raise Program_Error with "accent geometry rejected: " & Source;
      end if;
      Root := Math_Syntax.Element (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind /= Accent_Node or else Item.Code_Point /= Selector or else
        Item.Accent_Type /= (if Under then Below_Accent else Above_Accent)
      then
         raise Program_Error with "accent metadata mismatch: " & Source;
      end if;
      for Command of Geometry.Commands loop
         if Command.Kind = Math_Layout.Path_Command and then
           not Command.Path_Data.Is_Empty
         then
            Found := True;
         end if;
      end loop;
      if not Found then
         raise Program_Error with "accent path missing: " & Source;
      end if;
      declare
         Semantics : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
      begin
         if not Math_Semantics.Is_Valid (Semantics) or else
           Math_Semantics.Accent_Command
             (Semantics, Positive (Math_Semantics.Root (Semantics) + 1)) /=
               "\" & Name
         then
            raise Program_Error with "accent semantics invalid: " & Source;
         end if;
      end;
      Ada.Text_IO.Put_Line ("PASS accent " & Name & " " & Source);
   end Check_Accent_Geometry;

   procedure Check_Enclosure_Geometry
     (Source : String; Kind : Enclosure_Kind)
   is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
      Found_Path : Boolean := False;
      Found_Top : Boolean := False;
      Found_Right : Boolean := False;
      Bad_Actuarial_Rule : Boolean := False;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid then
         raise Program_Error with "enclosure geometry rejected: " & Source;
      end if;
      Root := Math_Syntax.Element (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind /= Enclosed_Node or else Item.Enclosure /= Kind then
         raise Program_Error with "enclosure metadata mismatch: " & Source;
      end if;
      for Command of Geometry.Commands loop
         if Kind = Phase_Enclosure and then
           Command.Kind = Math_Layout.Path_Command and then
           Command.Has_Clip and then not Command.Path_Data.Is_Empty
         then
            Found_Path := True;
         elsif Kind = Actuarial_Enclosure and then
           Command.Kind = Math_Layout.Rule_Command
         then
            if abs (Command.X) <= 0.000_001 and then
              abs (Command.Y + Geometry.Ascent) <= 0.000_001 and then
              abs (Command.Height - 0.04) <= 0.000_001 and then
              abs (Command.Width - Geometry.Width) <= 0.000_001
            then
               Found_Top := True;
            elsif abs (Command.X - (Geometry.Width - 0.04)) <=
              0.000_001 and then
              abs (Command.Y + Geometry.Ascent) <= 0.000_001 and then
              abs (Command.Width - 0.04) <= 0.000_001 and then
              abs (Command.Height - (Geometry.Ascent + Geometry.Descent)) <=
                0.000_001
            then
               Found_Right := True;
            else
               Bad_Actuarial_Rule := True;
            end if;
         end if;
      end loop;
      if (Kind = Phase_Enclosure and then not Found_Path) or else
        (Kind = Actuarial_Enclosure and then
         (abs (Geometry.Ascent - 0.590_56) > 0.000_01 or else
          abs (Geometry.Descent - 0.25) > 0.000_01 or else
          not Found_Top or else not Found_Right or else
          Bad_Actuarial_Rule))
      then
         raise Program_Error with "enclosure edge/path missing: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS enclosure " & Kind'Image & " " & Source);
   end Check_Enclosure_Geometry;

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
         raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed) &
           " at byte " & Natural'Image (Math_Syntax.Error_Position (Parsed));
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Operator := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Operator.Kind = Scripts_Node then
         Scripts := Operator;
      else
         while Operator.Next /= No_Node loop
            Operator := Math_Syntax.Element
              (Parsed, Positive (Operator.Next));
            exit when Operator.Kind = Scripts_Node;
         end loop;
         Scripts := Operator;
      end if;
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

   procedure Check_Poor_Bold (Source : String; Expected : Atom_Class) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Root : Math_Syntax.Node;
      Wrapper : Math_Syntax.Node;
      Semantics : constant Math_Semantics.Document :=
        Math_Semantics.Project (Parsed);
      Semantic : Math_Semantics.Semantic_Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid or else
        not Math_Semantics.Is_Valid (Semantics)
      then
         raise Program_Error with "pmb parse/layout/projection failed: " &
           Source;
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Wrapper := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Wrapper.Kind /= Poor_Bold_Node or else
        Wrapper.Poor_Bold_Class /= Expected or else
        Wrapper.Class /= Expected or else Wrapper.First = No_Node
      then
         raise Program_Error with "pmb lost argument/class: " & Source;
      end if;
      Semantic := Math_Semantics.Element
        (Semantics, Positive (Math_Semantics.Root (Semantics) + 1));
      if Semantic.Kind /= Poor_Bold_Node or else
        Semantic.Poor_Bold_Class /= Expected or else
        Semantic.Child_Count /= 1 or else
        Math_Semantics.Element
          (Semantics, Positive (Math_Semantics.Root (Semantics) + 2)).Role /=
            Math_Semantics.Poor_Bold_Content
      then
         raise Program_Error with "pmb semantic projection lost class/child";
      end if;
      if Geometry.Commands.Is_Empty then
         raise Program_Error with "pmb emitted no drawing commands";
      end if;
      for Command of Geometry.Commands loop
         if not Command.Has_Shadow or else
           Command.Shadow_X /= 0.02 or else Command.Shadow_Y /= 0.01 or else
           Command.Shadow_Blur_Px /= 0.04
         then
            raise Program_Error with "pmb CSS shadow parameters changed";
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("PASS pmb semantics/shadow " & Source);
   end Check_Poor_Bold;

   procedure Check_Text_Poor_Bold is
      Parsed : constant Math_Syntax.Document :=
        Math_Syntax.Parse ("\text{a \pmb{b}}");
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Found : Boolean := False;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid then
         raise Program_Error with "text-mode pmb parse/layout failed";
      end if;
      for Index in 1 .. Math_Syntax.Count (Parsed) loop
         declare
            Item : constant Math_Syntax.Node :=
              Math_Syntax.Element (Parsed, Index);
         begin
            if Item.Kind = Poor_Bold_Node then
               Found := True;
               if Item.Poor_Bold_Class /= Ordinary or else
                 Item.First = No_Node
               then
                  raise Program_Error with "text-mode pmb AST is invalid";
               end if;
            end if;
         end;
      end loop;
      if not Found then
         raise Program_Error with "text-mode pmb node missing";
      end if;
      Ada.Text_IO.Put_Line ("PASS pmb allowed in text mode");
   end Check_Text_Poor_Bold;

   procedure Check_VCenter (Source, Box_Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Semantics : constant Math_Semantics.Document :=
        Math_Semantics.Project (Parsed);
      Root : Math_Syntax.Node;
      Wrapper : Math_Syntax.Node;
      Semantic : Math_Semantics.Semantic_Node;
      Child_Box : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse (Box_Source));
      Expected_Ascent : constant Long_Float :=
        (Child_Box.Ascent + Child_Box.Descent) / 2.0 + 0.25;
      Expected_Descent : constant Long_Float :=
        (Child_Box.Ascent + Child_Box.Descent) / 2.0 - 0.25;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid or else
        not Math_Semantics.Is_Valid (Semantics) or else not Child_Box.Valid
      then
         raise Program_Error with "vcenter parse/layout/projection failed";
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Wrapper := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Wrapper.Kind /= VCenter_Node or else Wrapper.First = No_Node then
         raise Program_Error with "vcenter AST wrapper lost";
      end if;
      Semantic := Math_Semantics.Element
        (Semantics, Positive (Math_Semantics.Root (Semantics) + 1));
      if Semantic.Kind /= VCenter_Node or else Semantic.Child_Count /= 1 or else
        Math_Semantics.Element
          (Semantics, Positive (Math_Semantics.Root (Semantics) + 2)).Role /=
            Math_Semantics.VCenter_Content
      then
         raise Program_Error with "vcenter semantic child lost";
      end if;
      if abs (Geometry.Ascent - Long_Float'Max (0.0, Expected_Ascent)) >
           0.000_001 or else
        abs (Geometry.Descent - Long_Float'Max (0.0, Expected_Descent)) >
          0.000_001
      then
         raise Program_Error with "vcenter axis shift differs: actual=" &
           Long_Float'Image (Geometry.Ascent) & "/" &
           Long_Float'Image (Geometry.Descent) & " expected=" &
           Long_Float'Image (Long_Float'Max (0.0, Expected_Ascent)) & "/" &
           Long_Float'Image (Long_Float'Max (0.0, Expected_Descent));
      end if;
      Ada.Text_IO.Put_Line ("PASS vcenter axis layout " & Source);
   end Check_VCenter;

   procedure Check_Invalid_Command (Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
   begin
      if Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with "accepted invalid vcenter mode/box: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS rejected invalid vcenter " & Source);
   end Check_Invalid_Command;

   procedure Check_Verbatim (Source, Payload : String; Starred : Boolean) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Semantics : constant Math_Semantics.Document :=
        Math_Semantics.Project (Parsed);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
      Semantic : Math_Semantics.Semantic_Node;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else
        not Geometry.Valid or else not Math_Semantics.Is_Valid (Semantics)
      then
         raise Program_Error with "verb parse/layout/projection failed: " &
           Source & " " & Math_Syntax.Error (Parsed);
      end if;
      Root := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      Semantic := Math_Semantics.Element
        (Semantics, Positive (Math_Semantics.Root (Semantics) + 1));
      if Item.Kind /= Verbatim_Node or else Item.Class /= Ordinary or else
        Item.Font /= Typewriter_Regular or else Item.First /= No_Node or else
        Item.Verbatim_Text /= Ada.Strings.Unbounded.To_Unbounded_String
          (Payload) or else Item.Verbatim_Starred /= Starred or else
        Item.Position /= 1 or else Semantic.Kind /= Verbatim_Node or else
        Semantic.Child_Count /= 0 or else
        Semantic.Verbatim_Text /= Item.Verbatim_Text or else
        Semantic.Verbatim_Starred /= Starred
      then
         raise Program_Error with "verb AST/semantic payload mismatch: " &
           Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS verb AST/projection " & Source);
   end Check_Verbatim;

   procedure Check_Invalid_Verbatim (Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
   begin
      if Math_Syntax.Is_Valid (Parsed) then
         raise Program_Error with "accepted invalid verb: " & Source;
      end if;
      Ada.Text_IO.Put_Line ("PASS rejected verb " & Source);
   end Check_Invalid_Verbatim;

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

   procedure Check_Space_Control
     (Source : String; Expected_Amount : Long_Float;
      Expected_Break : Break_Kind := No_Break_Metadata) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Semantics : constant Math_Semantics.Document :=
        Math_Semantics.Project (Parsed);
      Root : Math_Syntax.Node;
      Item : Math_Syntax.Node;
      Semantic_Found : Boolean := False;
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid or else
        not Math_Semantics.Is_Valid (Semantics)
      then
         raise Program_Error with "space command rejected: " & Source;
      end if;
      Root := Math_Syntax.Element (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Item := Math_Syntax.Element (Parsed, Positive (Root.First));
      if Item.Kind /= Space_Node or else
        Item.Amount /= Expected_Amount or else Item.Break /= Expected_Break
      then
         raise Program_Error with "space payload mismatch: " & Source;
      end if;
      if Expected_Break /= No_Break_Metadata then
         for Index in 1 .. Math_Semantics.Count (Semantics) loop
            declare
               Semantic_Value : constant Math_Semantics.Semantic_Node :=
                 Math_Semantics.Element (Semantics, Index);
            begin
               if Semantic_Value.Kind = Space_Node and then
                 Semantic_Value.Break = Expected_Break
               then
                  Semantic_Found := True;
               end if;
            end;
         end loop;
         if not Semantic_Found or else
           (Expected_Amount = 0.0 and then Geometry.Width /= 0.0)
         then
            raise Program_Error with
              "break metadata lost or assigned visible width: " & Source;
         end if;
      end if;
      Ada.Text_IO.Put_Line ("PASS spacing/break metadata " & Source);
   end Check_Space_Control;

begin
      declare
         Strict_Phase : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\phase", (Strict => Math_Syntax.Strict_Error, others => <>));
         Strict_Angle : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\angl", (Strict => Math_Syntax.Strict_Error, others => <>));
      begin
         if Math_Syntax.Is_Valid (Strict_Phase) or else
           Math_Syntax.Is_Valid (Strict_Angle) or else
           Math_Syntax.Error (Strict_Phase)'Length = 0 or else
           Math_Syntax.Error (Strict_Angle)'Length = 0
         then
            raise Program_Error with "strict malformed enclosure accepted";
         end if;
      end;
      declare
         Strict_Cedilla : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\c{c}", (Strict => Math_Syntax.Strict_Error, others => <>));
         Strict_Circle : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\textcircled{R}",
            (Strict => Math_Syntax.Strict_Error, others => <>));
      begin
         if Math_Syntax.Is_Valid (Strict_Cedilla) or else
           Math_Syntax.Error (Strict_Cedilla)'Length = 0 or else
           Math_Syntax.Error (Strict_Cedilla) (1 .. 7) /= "refused" or else
           Math_Syntax.Is_Valid (Strict_Circle)
         then
            raise Program_Error with "strict text accent refusal mismatch";
         end if;
      end;
      declare
         Settings : Math_Syntax.Options := (Strict => Math_Syntax.Strict_Ignore,
                                             others => <>);
         Parsed : Math_Syntax.Document;
      begin
         declare
            Accents : constant array (Positive range 1 .. 11) of
              Ada.Strings.Unbounded.Unbounded_String :=
                (Ada.Strings.Unbounded.To_Unbounded_String ("\`"),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\'"),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\^"),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\~"),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\="),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\."),
                 Ada.Strings.Unbounded.To_Unbounded_String
                   ("\" & Character'Val (34)),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\u"),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\v"),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\r"),
                 Ada.Strings.Unbounded.To_Unbounded_String ("\H"));
         begin
            for Accent of Accents loop
               Parsed := Math_Syntax.Parse
                 ("\text{" & Ada.Strings.Unbounded.To_String (Accent) &
                  "{a}}", Settings);
               if not Math_Syntax.Is_Valid (Parsed) then
                  raise Program_Error with
                    "text accent parse failed: " &
                    Ada.Strings.Unbounded.To_String (Accent) & ": " &
                    Math_Syntax.Error (Parsed);
               elsif not Math_Layout.Build (Parsed).Valid then
                  raise Program_Error with
                    "text accent layout failed: " &
                    Ada.Strings.Unbounded.To_String (Accent);
               end if;
            end loop;
         end;
         declare
            Italic : constant Math_Syntax.Document := Math_Syntax.Parse
              ("\text{\textit{\^{a}}}", Settings);
            Layout : constant Math_Layout.Box := Math_Layout.Build (Italic);
            Found : Boolean := False;
         begin
            for Command of Layout.Commands loop
               if Command.Code_Point = 16#02C6# then
                  Found := Command.Font = Main_Italic;
               end if;
            end loop;
            if not Layout.Valid or else not Found then
               raise Program_Error with
                 "text accent did not inherit the selected italic face";
            end if;
         end;
         Ada.Text_IO.Put_Line ("PASS text accents in text font mode");
      end;
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\text{\c{c}}+x");
      begin
         if not Math_Syntax.Is_Valid (Parsed) then
            raise Program_Error with
              "cedilla text parse failed: " & Math_Syntax.Error (Parsed);
         end if;
         declare
            Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
            Semantics : constant Math_Semantics.Document :=
              Math_Semantics.Project (Parsed);
            Root : constant Math_Syntax.Node := Math_Syntax.Element
              (Parsed, Positive (Math_Syntax.Root (Parsed)));
            Text_Row : constant Math_Syntax.Node := Math_Syntax.Element
              (Parsed, Positive (Root.First));
            Accent : constant Math_Syntax.Node := Math_Syntax.Element
              (Parsed, Positive (Text_Row.First));
            Base_Row : constant Math_Syntax.Node := Math_Syntax.Element
              (Parsed, Positive (Accent.First));
            Base : constant Math_Syntax.Node := Math_Syntax.Element
              (Parsed, Positive (Base_Row.First));
            Semantic_Role_Found : Boolean := False;
            Found : Boolean := False;
            Mark : Math_Layout.Draw_Command;
         begin
            for Index in 1 .. Math_Semantics.Count (Semantics) loop
               if Math_Semantics.Element (Semantics, Index).Role =
                 Math_Semantics.Accent_Under_Base
               then
                  Semantic_Role_Found := True;
               end if;
            end loop;
            for Command of Geometry.Commands loop
               if Command.Code_Point = 16#00B8# then
                  Found := True;
                  Mark := Command;
               end if;
            end loop;
            if not Geometry.Valid or else
              not Math_Semantics.Is_Valid (Semantics) or else
              Accent.Kind /= Accent_Node or else
              Accent.Code_Point /= 16#00B8# or else
              Accent.Accent_Type /= Below_Accent or else
              Accent.Position /= 7 or else Base.Kind /= Glyph_Node or else
              Base.Font /= Main_Regular or else not Semantic_Role_Found or else
              not Found or else Mark.Font /= Main_Regular or else
              Mark.Kind /= Math_Layout.Glyph_Command or else Mark.Y /= 0.0 or else
              Mark.Height <= 0.0
            then
               raise Program_Error with
                 "cedilla typed below layout mismatch";
            end if;
            Ada.Text_IO.Put_Line
              ("PASS cedilla typed below-role and glyph paint");
         end;
      end;
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\text{\textcircled{R}}");
         Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Root : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Text_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Root.First));
         Accent : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Text_Row.First));
         Base : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Accent.First));
         Found : Boolean := False;
         Circle : Math_Layout.Draw_Command;
      begin
         for Command of Geometry.Commands loop
            if Command.Code_Point = 16#25EF# then
               Found := True;
               Circle := Command;
            end if;
         end loop;
         if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid or else
           Accent.Kind /= Accent_Node or else
           Accent.Accent_Type /= Full_Accent or else
           Accent.Code_Point /= 16#25EF# or else Accent.Position /= 7 or else
           Base.Font /= Main_Regular or else not Found or else
           Circle.Font /= Main_Regular or else
           Circle.Kind /= Math_Layout.Glyph_Command or else
           Circle.X /= 0.0 or else abs (Circle.Y - 0.005_56) > 0.000_01 or else
           Geometry.Width < Circle.Width
         then
            raise Program_Error with "textcircled did not paint pinned bigcirc";
         end if;
         Ada.Text_IO.Put_Line ("PASS textcircled full-width bigcirc glyph");
      end;
      Check_Verbatim ("\verb|a b\alpha%{}#^&_|", "a b\alpha%{}#^&_", False);
      Check_Verbatim ("\verb*|a b~|", "a b~", True);
      Check_Verbatim ("\verb|}|", "}", False);
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\frac\verb|{|{x}");
         Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Root : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Fraction : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Root.First));
         Numerator : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Fraction.First));
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid or else
           Fraction.Kind /= Fraction_Node or else
           Numerator.Kind /= Verbatim_Node or else
           Numerator.Verbatim_Text /=
             Ada.Strings.Unbounded.To_Unbounded_String ("{") or else
           Fraction.Second = No_Node
         then
            raise Program_Error with
              "verbatim fraction argument altered payload or structure";
         end if;
         Ada.Text_IO.Put_Line ("PASS verb atomicity in fraction argument");
      end;
      Check_Verbatim ("\verb|$|", "$", False);
      Check_Verbatim ("\verb|^|", "^", False);
      Check_Verbatim ("\verb|_|", "_", False);
      Check_Verbatim ("\verb|&|", "&", False);
      Check_Verbatim ("\verb|{|", "{", False);
      Check_Verbatim ("\verb|~|", "~", False);
      Check_Verbatim ("\verb|\|", "\", False);
      Check_Verbatim ("\verb|%|", "%", False);
      Check_Invalid_Node ("{x");
      Check_Invalid_Node ("x}");
      declare
         Source : constant String := "\hbox{\verb|$|}";
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
         Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Semantics : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
         Found : Boolean := False;
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid or else
           not Math_Semantics.Is_Valid (Semantics) or else
           Math_Semantics.Count (Semantics) < 4
         then
            raise Program_Error with
              "hbox verbatim dollar was parsed as a math boundary";
         end if;
         for Command of Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Code_Point = Character'Pos ('$')
            then
               Found := True;
            end if;
         end loop;
         if not Found then
            raise Program_Error with "hbox verbatim dollar glyph was lost";
         end if;
         Ada.Text_IO.Put_Line ("PASS hbox atomic verbatim dollar");
      end;
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\verb|😀|");
         Root : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Item : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Root.First));
         Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Semantics : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
         Semantic : constant Math_Semantics.Semantic_Node :=
           Math_Semantics.Element
             (Semantics, Positive (Math_Semantics.Root (Semantics) + 1));
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else Geometry.Valid or else
           not Math_Semantics.Is_Valid (Semantics) or else
           Semantic.Verbatim_Text /= Item.Verbatim_Text or else
           Item.Kind /= Verbatim_Node or else Item.Position /= 1 or else
           Item.Verbatim_Text /= Ada.Strings.Unbounded.To_Unbounded_String
             ("😀")
         then
            raise Program_Error with "UTF-8 verb payload or missing metric";
         end if;
      end;
      Check_Invalid_Verbatim ("\verb");
      Check_Invalid_Verbatim ("\verb|unfinished");
      declare
         Metric : constant Math_Metrics.Glyph_Metric :=
           Math_Metrics.Lookup (Typewriter_Regular, Character'Pos ('A'));
      begin
         if not Metric.Found or else Metric.Width /= 0.525 then
            raise Program_Error with
              "pinned Typewriter A width is not 0.525 em";
         end if;
         declare
            procedure Check_Scaled (Source : String) is
               Parsed : constant Math_Syntax.Document :=
                 Math_Syntax.Parse (Source);
               Geometry : constant Math_Layout.Box :=
                 Math_Layout.Build (Parsed);
               Command : Math_Layout.Draw_Command;
            begin
               if not Math_Syntax.Is_Valid (Parsed) or else
                 not Geometry.Valid or else Geometry.Commands.Length /= 1
               then
                  raise Program_Error with
                    "scaled verb parse/layout failed: " & Source;
               end if;
               Command := Geometry.Commands (1);
               if Command.Scale = 1.0 or else
                 abs (Command.Width / Command.Scale - Metric.Width) >
                   0.000_001
               then
                  raise Program_Error with
                    "scaled verb width differs from pinned metric: " & Source;
               end if;
            end Check_Scaled;
         begin
            Check_Scaled ("\tiny{\verb*|A|}");
            Check_Scaled ("\scriptsize{\verb*|A|}");
            Check_Scaled ("\Huge{\verb*|A|}");
         end;
      end;
      declare
         Payload : constant String :=
           " !" & Character'Val (34) & "#$%&'()*+,-./:;<=>?@[" &
           Character'Val (92) & "]^_`{|}~ ";
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\verb*§" & Payload & "§");
         Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Index : Natural := 0;
      begin
         if not Geometry.Valid or else
           Natural (Geometry.Commands.Length) /= Payload'Length
         then
            raise Program_Error with "verb punctuation layout invalid";
         end if;
         for Char of Payload loop
            Index := Index + 1;
            declare
               Command : constant Math_Layout.Draw_Command :=
                 Geometry.Commands (Positive (Index));
               Metric_Point : constant Natural :=
                 (if Char = ' ' then Character'Pos (' ')
                  else Character'Pos (Char));
               Metric : constant Math_Metrics.Glyph_Metric :=
                 Math_Metrics.Lookup (Typewriter_Regular, Metric_Point);
            begin
               if Command.Kind /= Math_Layout.Glyph_Command or else
                 Command.Font /= Typewriter_Regular or else
                 Command.Code_Point /=
                   (if Char = ' ' then 16#2423# else Character'Pos (Char)) or else
                 not Metric.Found or else Metric.Width /= 0.525 or else
                 abs (Command.Width - Metric.Width * Command.Scale) >
                   0.000_001
               then
                  raise Program_Error with
                    "verb punctuation differs from pinned font metric";
               end if;
            end;
         end loop;
         if abs (Geometry.Width -
           Long_Float (Payload'Length) * 0.525) > 0.000_001
         then
            raise Program_Error with "verb punctuation logical width changed";
         end if;
      end;
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\verb*| |");
         Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      begin
         if not Geometry.Valid or else Geometry.Commands.Length /= 1 or else
           Geometry.Commands (1).Code_Point /= 16#2423# or else
           abs (Geometry.Width - 0.525) > 0.000_001
         then
            raise Program_Error with "verb starred-space width changed";
         end if;
      end;
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("x\verb|😀|y");
         Root : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Prefix : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Root.First));
         Verbatim : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Prefix.Next));
      begin
         if Verbatim.Position /= 2 or else Verbatim.Next = No_Node or else
           Math_Syntax.Element
             (Parsed, Positive (Verbatim.Next)).Position /= 13
         then
            raise Program_Error with "verb UTF-8 source byte span wrong";
         end if;
      end;
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
      Check_Node ("\sqrt[[x]]{x}", Radical_Node);
      Check_Dimension ("\kern100em", 100, 100.0);
      Check_Dimension ("\kern1bp", 100, 0.100375);
      Check_Dimension ("\kern1pt", 100, 0.1);
      Check_Dimension ("\kern.2em", 100, 0.2);
      Check_Dimension ("\kern-.2em", 100, -0.2);
      Check_Dimension ("\kern-.1667em", 100, -0.1667);
      Check_Dimension ("\kern{-.5ex}", 100, -0.2155);
      Check_Space_Control ("\:", 4.0 / 18.0);
      Check_Space_Control ("\>", 4.0 / 18.0);
      Check_Space_Control ("\allowbreak", 0.0, Allow_Break);
      Check_Space_Control ("\nobreak", 0.0, Forbid_Break);
      declare
         procedure Check_Empty_Root (Source : String) is
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
            Root : Math_Syntax.Node;
            Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
            Meaning : constant Math_Semantics.Document :=
              Math_Semantics.Project (Parsed);
         begin
            if not Math_Syntax.Is_Valid (Parsed) or else
              not Layout.Valid or else Layout.Width /= 0.0 or else
              Layout.Ascent /= 0.0 or else Layout.Descent /= 0.0 or else
              not Math_Semantics.Is_Valid (Meaning)
            then
               raise Program_Error with "empty command root invalid: " & Source;
            end if;
            Root := Math_Syntax.Element
              (Parsed, Positive (Math_Syntax.Root (Parsed)));
            Ada.Text_IO.Put_Line ("PASS empty command root " & Source);
         end Check_Empty_Root;
      begin
         declare
            Inline_Options : Math_Syntax.Options := (others => <>);
            Display_Options : Math_Syntax.Options := (others => <>);
            Inline : constant Math_Syntax.Document :=
              Math_Syntax.Parse ("x\newline y", Inline_Options);
            Spaced : constant Math_Syntax.Document :=
              Math_Syntax.Parse ("x\\[.5em]y", Inline_Options);
            Warn_Display : Math_Syntax.Document;
            Ignore_Display : Math_Syntax.Document;
            Inline_Box : Math_Layout.Box;
            Spaced_Box : Math_Layout.Box;
            Warn_Box : Math_Layout.Box;
            Ignore_Box : Math_Layout.Box;
            Literal_Box : Math_Layout.Box;
            Inline_Semantics : Math_Semantics.Document;
            Saw_Break : Boolean := False;
            function Has_Break
              (Parsed : Math_Syntax.Document;
               Kind : Break_Kind;
               Amount : Long_Float := Long_Float'First)
               return Boolean
            is
            begin
               for Index in 1 .. Math_Syntax.Count (Parsed) loop
                  declare
                     Item : constant Math_Syntax.Node :=
                       Math_Syntax.Element (Parsed, Index);
                  begin
                     if Item.Kind = Space_Node and then
                       Item.Code_Point = 7 and then Item.Break = Kind and then
                       (Amount = Long_Float'First or else
                        Item.Amount = Amount)
                     then
                        return True;
                     end if;
                  end;
               end loop;
               return False;
            end Has_Break;
         begin
            Display_Options.Display_Mode := True;
            Warn_Display := Math_Syntax.Parse
              ("x\newline y", Display_Options);
            Display_Options.Strict := Math_Syntax.Strict_Ignore;
            Ignore_Display := Math_Syntax.Parse
              ("x\\[.5em]y", Display_Options);
            Inline_Box := Math_Layout.Build (Inline);
            Spaced_Box := Math_Layout.Build (Spaced);
            Warn_Box := Math_Layout.Build (Warn_Display);
            Ignore_Box := Math_Layout.Build (Ignore_Display);
            for Index in 1 .. Math_Syntax.Count (Ignore_Display) loop
               declare
                  Value : constant Math_Syntax.Node :=
                    Math_Syntax.Element (Ignore_Display, Index);
               begin
                  if Value.Code_Point = 7 then
                     Ada.Text_IO.Put_Line
                       ("newline margin" & Long_Float'Image (Value.Amount));
                  end if;
               end;
            end loop;
            Inline_Semantics := Math_Semantics.Project (Inline);
            declare
               Macro_Context : aliased Math_Macros.Context;
               Macro_Source : Math_Source.Source;
               Macro_Stream : Math_Tokens.Stream;
               Source_Status : Math_Source.Diagnostic_Kind;
               Token_Status : Math_Tokens.Diagnostic_Kind;
               Macro_Status : Math_Macros.Diagnostic_Kind;
               Error_Byte : Natural;
               Replacement : Math_Macros.Token_Sequence (1 .. 2);
               Expanded : Math_Syntax.Document;
               Expanded_Box : Math_Layout.Box;
               Expanded_Literal : Math_Syntax.Document;
               Expanded_Literal_Box : Math_Layout.Box;
            Native_Literal : constant Math_Syntax.Document :=
              Math_Syntax.Parse ("x\newline[.5em]y", Macro_Context'Access);
            Native_Literal_Box : Math_Layout.Box;
            Alias_Literal : constant Math_Syntax.Document :=
              Math_Syntax.Parse
                ("\\def\\br{\\newline}x\\br[.5em]y",
                 Macro_Context'Access);
            Alias_Literal_Box : Math_Layout.Box;
            begin
               Math_Source.Create
                 ("\\\relax", Macro_Source, Source_Status, Error_Byte);
               Math_Tokens.Lex
                 (Macro_Source, Macro_Stream, Token_Status, Error_Byte);
               if Source_Status /= Math_Source.No_Error or else
                 Token_Status /= Math_Tokens.No_Error or else
                 Math_Tokens.Count (Macro_Stream) /= 3
               then
                  raise Program_Error with "newline replacement tokens failed";
               end if;
               Replacement (1) := Math_Tokens.Element (Macro_Stream, 1);
               Replacement (2) := Math_Tokens.Element (Macro_Stream, 2);
               if Replacement (1).Kind /= Math_Tokens.Control_Symbol or else
                 Replacement (1).Lexeme /= "\\" or else
                 Replacement (2).Kind /= Math_Tokens.Control_Word or else
                 Replacement (2).Lexeme /= "\relax"
               then
                  raise Program_Error with "newline macro expansion differs from KaTeX";
               end if;
               Math_Macros.Define_Tokens
                 (Macro_Context, "\expandednewline", 0, Replacement,
                  False, Macro_Status);
               Expanded := Math_Syntax.Parse
                 ("x\expandednewline y", Macro_Context'Access);
               Expanded_Box := Math_Layout.Build (Expanded);
               Expanded_Literal := Math_Syntax.Parse
                 ("x\expandednewline[.5em]y", Macro_Context'Access);
               Expanded_Literal_Box := Math_Layout.Build (Expanded_Literal);
               Native_Literal_Box := Math_Layout.Build (Native_Literal);
               Alias_Literal_Box := Math_Layout.Build (Alias_Literal);
               if Macro_Status /= Math_Macros.No_Error or else
                 not Math_Syntax.Is_Valid (Alias_Literal) or else
                 not Alias_Literal_Box.Valid or else
                 (for some Command of Alias_Literal_Box.Commands =>
                    Command.Kind = Math_Layout.Glyph_Command and then
                    Command.Code_Point = Character'Pos ('[')) = False or else
                 (for some Command of Alias_Literal_Box.Commands =>
                    Command.Kind = Math_Layout.Glyph_Command and then
                    Command.Code_Point = Character'Pos (']')) = False or else
                 Has_Break (Alias_Literal, Forced_Break, 0.5) or else
                 not Math_Syntax.Is_Valid (Native_Literal) or else
                 not Native_Literal_Box.Valid or else
                 (for some Command of Native_Literal_Box.Commands =>
                    Command.Kind = Math_Layout.Glyph_Command and then
                    Command.Code_Point = Character'Pos ('[')) = False or else
                 (for some Command of Native_Literal_Box.Commands =>
                    Command.Kind = Math_Layout.Glyph_Command and then
                    Command.Code_Point = Character'Pos (']')) = False or else
                 Has_Break (Native_Literal, Forced_Break, 0.5) or else
                 not Math_Syntax.Is_Valid (Expanded) or else
                 not Has_Break (Expanded, Forced_Break) or else
                 not Expanded_Box.Valid or else
                 not Math_Syntax.Is_Valid (Expanded_Literal) or else
                 not Expanded_Literal_Box.Valid or else
                 Expanded_Literal_Box.Commands.Length < 8 or else
                 (for some Command of Expanded_Literal_Box.Commands =>
                    Command.Kind = Math_Layout.Glyph_Command and then
                    Command.Code_Point = Character'Pos ('[')) = False or else
                 Has_Break (Expanded_Literal, Forced_Break, 0.5)
               then
                  raise Program_Error with
                    "expanded newline did not leave optional-looking brackets literal";
               end if;
               Ada.Text_IO.Put_Line
                 ("PASS newline macro expansion preserves token behavior");
            end;
            if not Has_Break (Warn_Display, Forced_Break) or else
              not Has_Break (Ignore_Display, Forced_Break) or else
              not Has_Break (Ignore_Display, Forced_Break, 0.5) or else
              not Has_Break (Spaced, Forced_Break, 0.5) or else
              not Math_Syntax.Is_Valid (Inline) or else
              not Math_Syntax.Is_Valid (Spaced) or else
              not Math_Syntax.Is_Valid (Warn_Display) or else
              not Math_Syntax.Is_Valid (Ignore_Display) or else
              not Inline_Box.Valid or else not Spaced_Box.Valid or else
              not Warn_Box.Valid or else not Ignore_Box.Valid or else
              Inline_Box.Commands.Length < 2 or else
              Spaced_Box.Commands.Length < 2 or else
              Warn_Box.Commands.Length < 2 or else
              Ignore_Box.Commands.Length < 2
            then
               raise Program_Error with "newline layout did not emit lines";
            end if;
            declare
               First : constant Math_Layout.Draw_Command :=
                 Inline_Box.Commands (Inline_Box.Commands.First_Index);
               Second : constant Math_Layout.Draw_Command :=
                 Inline_Box.Commands (Inline_Box.Commands.Last_Index);
               Spaced_First : constant Math_Layout.Draw_Command :=
                 Spaced_Box.Commands (Spaced_Box.Commands.First_Index);
               Spaced_Second : constant Math_Layout.Draw_Command :=
                 Spaced_Box.Commands (Spaced_Box.Commands.Last_Index);
            begin
               if Second.Y - First.Y < 1.19 or else
                 Spaced_Second.Y - Spaced_First.Y < 1.69 or else
                 abs (Spaced_Second.Y - Spaced_First.Y -
                   (Second.Y - First.Y) - 0.5) > 0.001 or else
                 Inline_Box.Ascent + Inline_Box.Descent < 1.19 or else
                 Spaced_Box.Ascent + Spaced_Box.Descent < 1.69
               then
                  raise Program_Error with "newline baseline spacing mismatch";
               end if;
            end;
            for Index in 1 .. Math_Semantics.Count (Inline_Semantics) loop
               declare
                  Semantic : constant Math_Semantics.Semantic_Node :=
                    Math_Semantics.Element (Inline_Semantics, Index);
               begin
                  if Semantic.Break = Forced_Break then
                     Saw_Break := True;
                  end if;
               end;
            end loop;
            if not Saw_Break or else Ignore_Box.Width <= 0.0 then
               raise Program_Error with "newline semantic payload missing";
            end if;
            Ada.Text_IO.Put_Line
              ("PASS forced newline layout and semantic metadata");
         end;
         Check_Empty_Root ("\notag");
         Check_Empty_Root ("\nonumber");
         Check_Empty_Root ("\relax");
         Check_Empty_Root ("{}");
         Check_Empty_Root ("\gdef\saved{x}");
         Check_Empty_Root ("\newline");
         declare
            Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
              ("\newline \kern.5em");
            Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         begin
            if not Math_Syntax.Is_Valid (Parsed) or else
              not Geometry.Valid or else Geometry.Width /= 0.5 or else
              Geometry.Ascent /= 0.0 or else Geometry.Descent /= 0.0 or else
              not Geometry.Commands.Is_Empty
            then
               raise Program_Error with
                 "kern after an empty line must retain width, not height";
            end if;
            Ada.Text_IO.Put_Line ("PASS kern after empty line retains width");
         end;
      end;
      declare
         Source : constant String :=
           "\ne \neq \not= a\ne b \not\mathrel{=}";
         Initial_Count : constant Natural :=
           Math_Macros.Definition_Count (Shared);
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           (Source, Shared'Access);
         Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Semantics : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else not Layout.Valid or else
           not Math_Semantics.Is_Valid (Semantics) or else
           Math_Macros.Definition_Count (Shared) /= Initial_Count or else
           Math_Macros.Is_Defined (Shared, "\ne") or else
           Math_Macros.Is_Defined (Shared, "\neq") or else
           Math_Macros.Is_Defined (Shared, "\not")
         then
            raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
         end if;
         Ada.Text_IO.Put_Line ("PASS raw not-equal aliases and relations");
      end;
      declare
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse ("≘");
         Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Semantics : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
         Root : Math_Syntax.Node;
         Value : Math_Syntax.Node;
      begin
         if not Math_Syntax.Is_Valid (Parsed) then
            raise Program_Error with
              "raw ≘ builtin macro parse failed: " & Math_Syntax.Error (Parsed);
         end if;
         Root := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Value := Math_Syntax.Element (Parsed, Positive (Root.First));
         if Value.Kind /= Dual_Node or else Value.First = No_Node or else
           Value.Second = No_Node or else not Layout.Valid or else
           not Math_Semantics.Is_Valid (Semantics) or else
           Math_Macros.Is_Defined (Shared, "\ne") or else
           Math_Macros.Is_Defined (Shared, "\neq") or else
           Math_Macros.Is_Defined (Shared, "\not")
         then
            raise Program_Error with "raw ≘ dual parse/layout/projection failed";
         end if;
         Ada.Text_IO.Put_Line ("PASS raw ≘ dual AST/layout/projection");
      end;
      declare
         Source : constant String := "a≘b";
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
         Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Semantics : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else not Layout.Valid or else
           not Math_Semantics.Is_Valid (Semantics) or else
           Math_Macros.Is_Defined (Shared, "\ne") or else
           Math_Macros.Is_Defined (Shared, "\neq") or else
           Math_Macros.Is_Defined (Shared, "\not")
         then
            raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
         end if;
         Ada.Text_IO.Put_Line ("PASS composed ≘ macro expansion");
      end;
      declare
         Settings : Math_Syntax.Options := (Display_Mode => True, others => <>);
         Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
           ("\tag{A}x", Settings);
         Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
         Root : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Tag_Node_Value : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Root.First));
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else
           Root.Kind /= Row_Node or else Root.Next /= No_Node or else
           Tag_Node_Value.Kind /= Tagged_Node or else
           Tag_Node_Value.Second = No_Node or else
           not Layout.Valid
         then
            raise Program_Error with "display public tag parse/layout failed";
         end if;
         Ada.Text_IO.Put_Line ("PASS display public tag parse/layout");
      end;
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
   Check_Internal_Class ("\mathbin", "\alpha", Binary_Atom);
   Check_Internal_Class ("\mathrel", "\alpha", Relation_Atom);
   Check_Internal_Class ("\mathord", "\alpha", Ordinary);
   Check_Internal_Fraction ("\atopfrac", "\atopfrac{a}{b}",
     "\\atopfrac", No_Rule);
   Check_Internal_Fraction ("\bracefrac", "\bracefrac{a}{b}",
     "\\bracefrac", No_Rule, Math_Syntax.Brace_Delimiter);
   Check_Internal_Fraction ("\brackfrac", "\brackfrac{a}{b}",
     "\\brackfrac", No_Rule, Math_Syntax.Bracket_Delimiter);
   Check_Internal_Fraction ("\abovefrac", "\abovefrac{a}{0.2pt}{b}",
     "\\abovefrac", Custom_Rule, Thickness => 0.02);
   Check_Internal_Command
     ("\internalcdleft", "\internalcdleft{a}", "\\cdleft", Style_Node);
   Check_Internal_Command
     ("\internalcdright", "\internalcdright{a}", "\\cdright", Style_Node);
   Check_Internal_Command
     ("\internalcdparent", "\internalcdparent{a}", "\\cdparent", Row_Node);
   Check_Internal_Command
     ("\internalcdleftarrow", "\internalcdleftarrow[b]{a}", "cdleftarrow",
      Stretchy_Node, True);
   Check_Internal_Command
     ("\internalcdrightarrow", "\internalcdrightarrow[b]{a}", "cdrightarrow",
      Stretchy_Node, True);
   Check_Internal_Command
     ("\internalcdlongequal", "\internalcdlongequal[b]{a}", "cdlongequal",
      Stretchy_Node, True);
   declare
      procedure Check_CD_Arrow_Roles (Call : String) is
         Parsed : constant Math_Syntax.Document :=
           Math_Syntax.Parse (Call, Shared'Access);
         Meaning : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
         Arrow : constant Math_Semantics.Semantic_Node :=
           Math_Semantics.Element
             (Meaning, Positive (Math_Semantics.Root (Meaning) + 1));
         Upper : constant Math_Semantics.Semantic_Node :=
           Math_Semantics.Element (Meaning, Positive (Arrow.First_Child));
         Lower : constant Math_Semantics.Semantic_Node :=
           Math_Semantics.Element
             (Meaning, Positive (Upper.Next_Sibling));
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else
           not Math_Semantics.Is_Valid (Meaning) or else
           Arrow.Child_Count /= 2 or else
           Upper.Role /= Math_Semantics.CD_Arrow_Left_Label or else
           Lower.Role /= Math_Semantics.CD_Arrow_Right_Label
         then
            raise Program_Error with "CD arrow label roles failed: " & Call;
         end if;
      end Check_CD_Arrow_Roles;
   begin
      Check_CD_Arrow_Roles ("\internalcdleftarrow[b]{a}");
      Check_CD_Arrow_Roles ("\internalcdrightarrow[b]{a}");
      Check_CD_Arrow_Roles ("\internalcdlongequal[b]{a}");
      Ada.Text_IO.Put_Line ("PASS CD arrow semantic label roles");
   end;
   declare
      procedure Check_CD_Wrapper_Role
        (Call : String; Expected_Kind : Node_Kind;
         Expected_Role : Math_Semantics.Child_Role) is
         Parsed : constant Math_Syntax.Document :=
           Math_Syntax.Parse (Call, Shared'Access);
         Meaning : constant Math_Semantics.Document :=
           Math_Semantics.Project (Parsed);
         Wrapper : constant Math_Semantics.Semantic_Node :=
           Math_Semantics.Element
             (Meaning, Positive (Math_Semantics.Root (Meaning) + 1));
         Child : constant Math_Semantics.Semantic_Node :=
           Math_Semantics.Element (Meaning, Positive (Wrapper.First_Child));
      begin
         if not Math_Syntax.Is_Valid (Parsed) or else
           not Math_Semantics.Is_Valid (Meaning) or else
           Wrapper.Kind /= Expected_Kind or else Wrapper.Child_Count /= 1 or else
           Child.Role /= Expected_Role
         then
            raise Program_Error with "CD wrapper role failed: " & Call;
         end if;
      end Check_CD_Wrapper_Role;
   begin
      Check_CD_Wrapper_Role ("\internalcdleft{a}", Style_Node,
        Math_Semantics.CD_Arrow_Left_Label);
      Check_CD_Wrapper_Role ("\internalcdright{a}", Style_Node,
        Math_Semantics.CD_Arrow_Left_Label);
      Check_CD_Wrapper_Role ("\internalcdparent{a}", Row_Node,
        Math_Semantics.CD_Arrow_Right_Label);
      Ada.Text_IO.Put_Line ("PASS CD label and parent semantic roles");
   end;
   Check_Space_Control ("\space", 0.333, Forbid_Break);
   Check_Node ("\stackrel{n}{=}", Annotation_Node);
   declare
      Relation_Layout : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("a\stackrel{n}{=}b"));
      Overset_Layout : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("a\overset{n}{=}b"));
      Underset_Layout : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse ("a\underset{n}{=}b"));
   begin
      if not Relation_Layout.Valid or else not Overset_Layout.Valid or else
        not Underset_Layout.Valid
      then
         raise Program_Error with "stacked relation layout failed";
      end if;
      Ada.Text_IO.Put_Line ("PASS stacked relations in expression context");
   end;
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
   declare
      procedure Check_Delimiters is
         Parsed : Math_Syntax.Document;
         Root : Math_Syntax.Node;
         Item : Math_Syntax.Node;
         procedure Expect
           (Source : String; Left, Right : Math_Syntax.Delimiter_Kind) is
         begin
            Parsed := Math_Syntax.Parse (Source);
            if not Math_Syntax.Is_Valid (Parsed) then
               raise Program_Error with Source & ": " & Math_Syntax.Error (Parsed);
            end if;
            Root := Math_Syntax.Element
              (Parsed, Positive (Math_Syntax.Root (Parsed)));
            Item := Math_Syntax.Element (Parsed, Positive (Root.First));
            if Item.Kind /= Delimited_Node or else
              Item.Left_Delimiter /= Left or else
              Item.Right_Delimiter /= Right
            then
               raise Program_Error with "wrong delimiter AST: " & Source;
            end if;
            declare
               Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
            begin
               if not Layout.Valid then
                  raise Program_Error with "delimiter layout failed: " & Source;
               end if;
            end;
         end Expect;
      begin
         Expect ("\left\langle x \right\rangle",
           Math_Syntax.Angle_Delimiter, Math_Syntax.Angle_Delimiter);
         Expect ("\left< x \right>",
           Math_Syntax.Angle_Delimiter, Math_Syntax.Angle_Delimiter);
         Expect ("\left\lfloor x \right\rfloor",
           Math_Syntax.Floor_Delimiter, Math_Syntax.Floor_Delimiter);
         Expect ("\left\lceil x \right\rceil",
           Math_Syntax.Ceiling_Delimiter, Math_Syntax.Ceiling_Delimiter);
         Parsed := Math_Syntax.Parse ("a|b");
         if not Math_Syntax.Is_Valid (Parsed) then
            raise Program_Error with "raw vertical bar rejected";
         end if;
         Parsed := Math_Syntax.Parse
           ("\left\langle a \middle| b \right\rangle");
         if not Math_Syntax.Is_Valid (Parsed) then
            raise Program_Error with "bra-ket middle bar rejected";
         end if;
         declare
            Found_Middle : Boolean := False;
         begin
            for Index in 1 .. Math_Syntax.Count (Parsed) loop
               declare
                  Middle_Node : constant Math_Syntax.Node :=
                    Math_Syntax.Element (Parsed, Index);
               begin
                  if Middle_Node.Kind = Delimited_Node and then
                    Middle_Node.Code_Point = 4
                  then
                     Found_Middle := True;
                     if Middle_Node.Amount /= 1.0 then
                        raise Program_Error with
                          "middle delimiter size mismatch";
                     end if;
                  end if;
               end;
            end loop;
            if not Found_Middle then
               raise Program_Error with "middle delimiter node missing";
            end if;
         end;
         Ada.Text_IO.Put_Line
           ("PASS angle/floor/ceiling delimiters, bra-ket, and raw bar");
      end Check_Delimiters;
   begin
      Check_Delimiters;
   end;

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
   Check_Accent_Geometry ("\widecheck{x}", Wide_Check_Code_Point,
     "widecheck");
   Check_Accent_Geometry ("\widecheck{xy}", Wide_Check_Code_Point,
     "widecheck");
   Check_Accent_Geometry ("\widecheck{xyz}", Wide_Check_Code_Point,
     "widecheck");
   Check_Accent_Geometry ("\widecheck{wxyz}", Wide_Check_Code_Point,
     "widecheck");
   Check_Accent_Geometry ("\widecheck{vwxyz}", Wide_Check_Code_Point,
     "widecheck");
   Check_Accent_Geometry ("\widecheck{uvwxyz}", Wide_Check_Code_Point,
     "widecheck");
   Check_Accent_Geometry ("\widecheck{abcdefg}", Wide_Check_Code_Point,
     "widecheck");
   Check_Accent_Geometry ("\utilde{x}", Under_Tilde_Code_Point,
     "utilde", Under => True);
   Check_Accent_Geometry ("\utilde{xy}", Under_Tilde_Code_Point,
     "utilde", Under => True);
   Check_Accent_Geometry ("\utilde{xyz}", Under_Tilde_Code_Point,
     "utilde", Under => True);
   Check_Accent_Geometry ("\utilde{wxyz}", Under_Tilde_Code_Point,
     "utilde", Under => True);
   Check_Accent_Geometry ("\utilde{uvwxyz}", Under_Tilde_Code_Point,
     "utilde", Under => True);
   Check_Enclosure_Geometry ("\phase{x}", Phase_Enclosure);
   Check_Enclosure_Geometry ("\phase{\frac{x}{y}}", Phase_Enclosure);
   Check_Enclosure_Geometry ("\angl{x}", Actuarial_Enclosure);
   Check_Enclosure_Geometry ("\angl{xy}", Actuarial_Enclosure);
   Check_Invalid_Node ("\phase");
   Check_Invalid_Node ("\angl");
   Check_Node ("\cancel{x}", Enclosed_Node);
   Check_Node ("\bcancel{x}", Enclosed_Node);
   Check_Node ("\xcancel{x}", Enclosed_Node);
   Check_Node ("\sout{x}", Enclosed_Node);
   Check_Node ("\rule{2em}{0.5em}", Rule_Node);
   Check_Node ("\raisebox{2pt}{x}", Raised_Node);
   Check_Poor_Bold ("\pmb{x}", Ordinary);
   Check_Poor_Bold ("\pmb{+}", Binary_Atom);
   Check_Poor_Bold ("\pmb{\le}", Relation_Atom);
   Check_Text_Poor_Bold;
   Check_VCenter ("\vcenter{\hbox{$\frac{a+b}{\dfrac{c}{d}}$}}",
     "\hbox{$\frac{a+b}{\dfrac{c}{d}}$}");
   Check_Invalid_Command ("\text{\vcenter{\hbox{x}}}");
   Check_Invalid_Command ("\vcenter");
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
   declare
      Source : aliased Test_Advance_Source;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\verb|AB|");
      Normalized : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Measured_12 : constant Math_Layout.Box := Math_Layout.Build
        (Parsed, Math_Layout.Text_Style,
         (Pixel_Em => 12.0, Advance_Source => Source'Unchecked_Access,
          others => <>));
      Measured_16 : constant Math_Layout.Box := Math_Layout.Build
        (Parsed, Math_Layout.Text_Style,
         (Pixel_Em => 16.0, Advance_Source => Source'Unchecked_Access,
          others => <>));
      Measured_20 : constant Math_Layout.Box := Math_Layout.Build
        (Parsed, Math_Layout.Text_Style,
         (Pixel_Em => 20.0, Advance_Source => Source'Unchecked_Access,
          others => <>));
      Measured_24 : constant Math_Layout.Box := Math_Layout.Build
        (Parsed, Math_Layout.Text_Style,
         (Pixel_Em => 24.0, Advance_Source => Source'Unchecked_Access,
          others => <>));
      Measured_32 : constant Math_Layout.Box := Math_Layout.Build
        (Parsed, Math_Layout.Text_Style,
         (Pixel_Em => 32.0, Advance_Source => Source'Unchecked_Access,
          others => <>));
      Measured_48 : constant Math_Layout.Box := Math_Layout.Build
        (Parsed, Math_Layout.Text_Style,
         (Pixel_Em => 48.0, Advance_Source => Source'Unchecked_Access,
          others => <>));
   begin
      if not Normalized.Valid or else not Measured_12.Valid or else
        not Measured_16.Valid or else not Measured_20.Valid or else
        not Measured_24.Valid or else not Measured_32.Valid or else
        not Measured_48.Valid or else
        abs (Normalized.Width - 1.05) > 0.000_001 or else
        abs (Measured_12.Width - 1.5) > 0.000_001 or else
        abs (Measured_16.Width - 1.5) > 0.000_001 or else
        abs (Measured_20.Width - 1.5) > 0.000_001 or else
        abs (Measured_24.Width - 1.5) > 0.000_001 or else
        abs (Measured_32.Width - 1.5) > 0.000_001 or else
        abs (Measured_48.Width - 1.5) > 0.000_001 or else
        Measured_12.Commands (1).Width /= 0.75 or else
        Measured_16.Commands (1).Width /= 0.75 or else
        Measured_20.Commands (1).Width /= 0.75 or else
        Measured_24.Commands (1).Width /= 0.75 or else
        Measured_32.Commands (1).Width /= 0.75 or else
        Measured_48.Commands (1).Width /= 0.75 or else
        Math_Syntax.Source (Parsed) /= "\verb|AB|"
      then
         raise Program_Error with
           "measured advances not normalized or input AST changed";
      end if;
      Ada.Text_IO.Put_Line
        ("PASS measured advances normalized across 12/16/20/24/32/48 px em");
      declare
         Sizes : constant array (Positive range 1 .. 3) of Long_Float :=
           (12.0, 24.0, 48.0);
      begin
         for Pixel_Em of Sizes loop
         declare
            Extents : constant Math_Metrics.Font_Line_Extent :=
              Math_Metrics.Font_Line_Extents
                (Math_Metrics.Advance_Source'Class (Source),
                 Main_Regular, Pixel_Em);
         begin
            if Extents.Ascent /= Pixel_Em * 0.8 or else
              Extents.Descent /= Pixel_Em * 0.2 or else
              Extents.Height /= Pixel_Em * 1.25
            then
               raise Program_Error with
                 "font line extents did not preserve measured scale";
            end if;
            end;
         end loop;
      end;
      Ada.Text_IO.Put_Line
        ("PASS font line extents preserve measured ascent/descent/height");
   end;
   declare
      Source : aliased Test_Advance_Source;
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\verb|A|");
      Bad : constant Math_Layout.Box := Math_Layout.Build
        (Parsed, Math_Layout.Text_Style,
         (Advance_Source => Source'Unchecked_Access, others => <>));
   begin
      if Bad.Valid then
         raise Program_Error with "provider accepted nonpositive pixel em";
      end if;
      Ada.Text_IO.Put_Line ("PASS measured provider requires positive pixel em");
   end;
   declare
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\verb|A|");
      Bad : constant Math_Layout.Box := Math_Layout.Build
        (Parsed, Math_Layout.Text_Style, (Pixel_Em => 12.0, others => <>));
   begin
      if Bad.Valid then
         raise Program_Error with "pixel em accepted without advance source";
      end if;
      Ada.Text_IO.Put_Line ("PASS pixel em requires borrowed advance source");
   end;
   declare
      Source : constant String := "\colorbox{red}{a b}";
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Root : constant Math_Syntax.Node := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Box_Node : constant Math_Syntax.Node := Math_Syntax.Element
        (Parsed, Positive (Root.First));
      Content : constant Math_Syntax.Node := Math_Syntax.Element
        (Parsed, Positive (Box_Node.First));
      Semantics : constant Math_Semantics.Document :=
        Math_Semantics.Project (Parsed);
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Background_Command : constant Math_Layout.Draw_Command :=
        Geometry.Commands (Geometry.Commands.First_Index);
      Last_Command : constant Math_Layout.Draw_Command :=
        Geometry.Commands (Geometry.Commands.Last_Index);
      Saw_Space : Boolean := False;
      Saw_Glyph_After_Space : Boolean := False;
      Current : Math_Syntax.Node := Math_Syntax.Element
        (Parsed, Positive (Content.First));
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid or else
        Box_Node.Kind /= Enclosed_Node or else
        Box_Node.Enclosure /= Color_Box_Enclosure or else
        Box_Node.Position /= 1 or else Box_Node.Box_Background.Red /= 1.0 or else
        Box_Node.Box_Background.Green /= 0.0 or else
        Content.Kind /= Row_Node or else Content.First = No_Node or else
        not Math_Semantics.Is_Valid (Semantics) or else
        not Background_Command.Has_Color or else
        Background_Command.Red /= 1.0 or else
        Last_Command.Kind /= Math_Layout.Glyph_Command or else
        Last_Command.Font /= Main_Regular
      then
         raise Program_Error with "colorbox parse/layout contract failed";
      end if;
      loop
         if Current.Kind = Space_Node and then Current.Amount = 0.333 then
            Saw_Space := True;
         elsif Saw_Space and then Current.Kind = Glyph_Node then
            Saw_Glyph_After_Space := True;
         end if;
         exit when Current.Next = No_Node;
         Current := Math_Syntax.Element (Parsed, Positive (Current.Next));
      end loop;
      if not Saw_Space or else not Saw_Glyph_After_Space then
         raise Program_Error with "colorbox text whitespace was lost";
      end if;
      Ada.Text_IO.Put_Line ("PASS colorbox whitespace, regular font, and fill");
   end;
   declare
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\fcolorbox{blue}{#ffffff}{A}");
      Root : constant Math_Syntax.Node := Math_Syntax.Element
        (Parsed, Positive (Math_Syntax.Root (Parsed)));
      Box_Node : constant Math_Syntax.Node := Math_Syntax.Element
        (Parsed, Positive (Root.First));
      Geometry : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      First_Command : constant Math_Layout.Draw_Command :=
        Geometry.Commands (Geometry.Commands.First_Index);
      Last_Command : constant Math_Layout.Draw_Command :=
        Geometry.Commands (Geometry.Commands.Last_Index);
   begin
      if not Math_Syntax.Is_Valid (Parsed) or else not Geometry.Valid or else
        Box_Node.Enclosure /= Framed_Color_Box_Enclosure or else
        Box_Node.Box_Background.Red /= 1.0 or else
        Box_Node.Box_Border.Blue /= 1.0 or else
        Box_Node.Box_Border_Thickness /= 0.04 or else
        not First_Command.Has_Color or else not Last_Command.Has_Color or else
        First_Command.Red /= 1.0 or else Last_Command.Blue /= 1.0
      then
         raise Program_Error with "fcolorbox distinct fill/border failed";
      end if;
      Ada.Text_IO.Put_Line ("PASS fcolorbox distinct background and border");
   end;
   declare
      Invalid : constant Math_Syntax.Document := Math_Syntax.Parse
        ("\colorbox{not-a-color}{x}");
   begin
      if Math_Syntax.Is_Valid (Invalid) or else
        Math_Syntax.Error (Invalid)'Length = 0
      then
         raise Program_Error with "invalid colorbox color was accepted";
      end if;
      Ada.Text_IO.Put_Line ("PASS colorbox rejects unsupported color");
   end;
end Math_Additional_Probe;
