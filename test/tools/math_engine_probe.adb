with Ada.Command_Line;
with Ada.Containers;
with Ada.Text_IO;
with Math_Engine;
with Math_Layout;
with Math_Macros;
with Math_Model;
with Math_Semantics;
with Math_Syntax;
with Math_Work_Control;

procedure Math_Engine_Probe is
   use type Ada.Containers.Count_Type;
   use type Math_Engine.Status_Kind;
   use type Math_Layout.Command_Kind;
   use type Math_Model.Node_Kind;
   use type Math_Syntax.Diagnostic_Kind;
   Checks : Natural := 0;
   Failures : Natural := 0;
   Shared : aliased Math_Macros.Context;

   type Budget_Context is new Math_Work_Control.Context with record
      Stop_At : Natural := Natural'Last;
      Reason : Math_Work_Control.Stop_Reason :=
        Math_Work_Control.Continue_Work;
   end record;

   overriding function Check
     (Item : Budget_Context) return Math_Work_Control.Stop_Reason;

   Poll_Count : Natural := 0;
   Cancel_Context : aliased Budget_Context :=
     (Math_Work_Control.Context with Stop_At => 3,
      Reason => Math_Work_Control.Cancel_Requested);
   Deadline_Context : aliased Budget_Context :=
     (Math_Work_Control.Context with Stop_At => 3,
      Reason => Math_Work_Control.Deadline_Reached);

   overriding function Check
     (Item : Budget_Context) return Math_Work_Control.Stop_Reason is
   begin
      Poll_Count := Poll_Count + 1;
      return (if Poll_Count >= Item.Stop_At then Item.Reason
              else Math_Work_Control.Continue_Work);
   end Check;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;

   procedure Run is
      Opt : Math_Engine.Request;
      Outp : Math_Engine.Result;
      Bad_Source : constant String := "\not-a-command";
   begin
      Math_Engine.Parse ("x+\frac{a}{b}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready, "default request ready");
      Check (Math_Syntax.Is_Valid (Outp.Parsed) and
        Math_Layout.Box (Outp.Geometry).Valid, "syntax and layout valid");
      Check (Math_Semantics.Is_Valid (Outp.Meaning),
        "semantics derive from parsed AST");
      Check (Math_Syntax.Source (Outp.Parsed) = "x+\frac{a}{b}" and
        Math_Semantics.Source (Outp.Meaning) = "x+\frac{a}{b}",
        "source retained across views");
      Check (not Opt.Settings.Trust,
        "native default trust policy is false");
      Opt.Settings.Trust := True;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings and then
        Math_Engine.Error (Outp) = "trust is not supported by native math",
        "trust=true is rejected by the native untrusted policy");
      Opt := (others => <>);
      Check (not Opt.Settings.Color_Is_Text_Color,
        "colorIsTextColor defaults to false");
      Math_Engine.Parse ("\color{red}x+y", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then Outp.Geometry.Commands.Length > 0,
        "default color command produces nonempty valid geometry");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Red_Glyphs : Natural := 0;
      begin
         declare
            Expression_Row : constant Math_Syntax.Node := Math_Syntax.Element
              (Outp.Parsed, Positive (Color_Node.First));
            First_Atom : constant Math_Syntax.Node := Math_Syntax.Element
              (Outp.Parsed, Positive (Expression_Row.First));
            Binary_Atom : constant Math_Syntax.Node := Math_Syntax.Element
              (Outp.Parsed, Positive (First_Atom.Next));
            Last_Atom : constant Math_Syntax.Node := Math_Syntax.Element
              (Outp.Parsed, Positive (Binary_Atom.Next));
         begin
            Check (Color_Node.Kind = Math_Model.Color_Node and then
              Expression_Row.Kind = Math_Model.Row_Node and then
              First_Atom.Code_Point = Character'Pos ('x'),
              "default color AST wraps initial expression");
            Check (Binary_Atom.Code_Point = Character'Pos ('+'),
              "default color AST includes subsequent binary atom");
            Check (Last_Atom.Code_Point = Character'Pos ('y'),
              "default color AST includes subsequent ordinary atom");
         end;
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Red_Glyphs = 3,
           "default color command colors all expression glyphs");
      end;
      Opt.Settings.Color_Is_Text_Color := True;
      Math_Engine.Parse ("\color{red}x+y", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then Outp.Geometry.Commands.Length > 0,
        "text-color compatibility request has nonempty geometry");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Inner_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Red_Glyphs : Natural := 0;
      begin
         Check (Color_Node.Kind = Math_Model.Color_Node and then
           Inner_Node.Code_Point = Character'Pos ('x') and then
           Inner_Node.Next = Math_Model.No_Node,
           "text-color compatibility limits color node to one argument");
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Red_Glyphs = 1,
           "text-color compatibility colors only its argument");
      end;

      Opt := (others => <>);
      Math_Engine.Parse ("{\color{red}x+y}z", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then Outp.Geometry.Commands.Length > 0,
        "grouped color scope retains nonempty valid geometry");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Group_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Group_Row.First));
         Inner_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Following_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Group_Row.Next));
         Red_Glyphs : Natural := 0;
         Plain_Z : Boolean := False;
      begin
         Check (Color_Node.Kind = Math_Model.Color_Node and then
           Inner_Row.Kind = Math_Model.Row_Node and then
           Inner_Row.First /= Math_Model.No_Node,
           "nested group retains its own color node scope");
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Code_Point = Character'Pos ('z')
            then
               Plain_Z := not Command.Has_Color;
            elsif Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Following_Node.Code_Point = Character'Pos ('z') and then
           Plain_Z and then Red_Glyphs = 3,
           "nested color restores uncolored following glyphs");
      end;

      Math_Engine.Parse
        ("\begin{matrix}\color{red}a+b&c\\d&e\end{matrix}",
         Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then Outp.Geometry.Valid and
        then Outp.Geometry.Commands.Length > 0,
        "color expression respects array cell and row boundaries");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Array_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         First_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Array_Node.First));
         First_Cell : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (First_Row.First));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (First_Cell.First));
         Color_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Second_Cell : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (First_Cell.Next));
         Second_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (First_Row.Next));
         Second_Glyph_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Second_Cell.First));
         Second_Glyph : constant Math_Syntax.Node := Second_Glyph_Row;
      begin
         Check (Array_Node.Kind = Math_Model.Array_Node and then
           Color_Node.Kind = Math_Model.Color_Node and then
           Color_Row.Kind = Math_Model.Row_Node and then
           Color_Row.First /= Math_Model.No_Node and then
           Math_Syntax.Element
             (Outp.Parsed, Positive (Color_Row.First)).Next /=
               Math_Model.No_Node and then
           Second_Glyph.Code_Point = Character'Pos ('c') and then
           Second_Row.First /= Math_Model.No_Node,
           "array AST closes color before next cell and row");
      end;

      Math_Engine.Parse
        ("\left(\color{red}x+y\right)+z", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then Outp.Geometry.Valid and
        then Outp.Geometry.Commands.Length > 0,
        "color expression stops at right delimiter boundary");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Delimited_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Inner_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Delimited_Node.First));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Inner_Row.First));
         Color_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Trailing : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Delimited_Node.Next));
      begin
         Check (Delimited_Node.Kind = Math_Model.Delimited_Node and then
           Color_Node.Kind = Math_Model.Color_Node and then
           Math_Syntax.Element
             (Outp.Parsed, Positive (Color_Row.First)).Code_Point =
               Character'Pos ('x') and then
           Math_Syntax.Element
             (Outp.Parsed,
              Positive
                (Math_Syntax.Element
                   (Outp.Parsed, Positive (Color_Row.First)).Next))
                .Code_Point = Character'Pos ('+') and then
           Trailing.Code_Point = Character'Pos ('+'),
           "right delimiter remains outside color expression");
      end;

      Math_Engine.Parse
        ("\color{red}x^2+\frac{a}{b}+z", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then Outp.Geometry.Valid and
        then Outp.Geometry.Commands.Length > 0,
        "color expression with scripts and fraction has geometry");
      declare
         Root_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Color_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root_Node.First));
         Color_Row : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Node.First));
         Script_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Color_Row.First));
         Binary_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Script_Node.Next));
         Fraction_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Binary_Node.Next));
         Red_Glyphs : Natural := 0;
      begin
         Check (Color_Node.Kind = Math_Model.Color_Node and then
           Script_Node.Kind = Math_Model.Scripts_Node and then
           Fraction_Node.Kind = Math_Model.Fraction_Node and then
           Math_Syntax.Element
             (Outp.Parsed, Positive (Fraction_Node.First)).First /=
               Math_Model.No_Node and then
           Math_Syntax.Element
             (Outp.Parsed, Positive (Fraction_Node.Second)).First /=
               Math_Model.No_Node,
           "script and fraction AST remain inside color scope");
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Red_Glyphs = 7,
           "script and fraction descendant glyphs receive scoped color");
      end;

      Math_Engine.Parse ("\color{unknown}x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Syntax.Error (Outp.Parsed) = "unsupported color name" and then
        Math_Syntax.Diagnostic_Count (Outp.Parsed) = 1 and then
        Math_Syntax.Diagnostic_At (Outp.Parsed, 1).Kind =
          Math_Syntax.Parse_Error,
        "unsupported color retains its explicit parse diagnostic");
      Math_Engine.Parse ("\color{#12xz56}x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Syntax.Error (Outp.Parsed) = "invalid color value" and then
        Math_Syntax.Diagnostic_Count (Outp.Parsed) = 1,
        "malformed hex color retains its explicit parse diagnostic");

      Opt := (others => <>);
      Math_Engine.Parse ("\href{https://example.invalid}{x}",
        Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Policy_Visible_Command and then
        Math_Syntax.Is_Valid (Outp.Parsed) and then Outp.Geometry.Valid,
        "valid refused href has dedicated policy-visible status");
      Check (Outp.Geometry.Commands.Length = 5 and then
        Outp.Geometry.Commands (1).Code_Point = Character'Pos ('\') and then
        Outp.Geometry.Commands (2).Code_Point = Character'Pos ('h') and then
        Outp.Geometry.Commands (3).Code_Point = Character'Pos ('r') and then
        Outp.Geometry.Commands (4).Code_Point = Character'Pos ('e') and then
        Outp.Geometry.Commands (5).Code_Point = Character'Pos ('f'),
        "refusal draws only the original href command glyphs");
      Check (Outp.Geometry.Commands (1).Has_Color and then
        Outp.Geometry.Commands (1).Red = 204.0 / 255.0 and then
        Outp.Geometry.Commands (1).Green = 0.0 and then
        Outp.Geometry.Commands (1).Blue = 0.0 and then
        Outp.Geometry.Commands (1).Alpha = 1.0,
        "refusal command glyphs use KaTeX default red RGBA");
      Opt.Strict := Math_Syntax.Strict_Error;
      Math_Engine.Parse ("\href{}{x}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Syntax.Error (Outp.Parsed)'Length > 0 and then
        Outp.Geometry.Commands.Is_Empty,
        "strict malformed href fails before policy-visible rendering");

      Opt.Style := Math_Layout.Display_Style;
      Math_Engine.Parse ("\sum_i^n", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "display style accepted");
      Opt := (others => <>);
      Opt.Strict := Math_Syntax.Strict_Error;
      Math_Engine.Parse ("\htmlClass{class}{x}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Engine.Error (Outp)'Length > 10 and then
        Math_Engine.Error (Outp) = Math_Syntax.Error (Outp.Parsed) and then
        not Math_Syntax.Is_Valid (Outp.Parsed),
        "strict policy rejects refused HTML command");

      Opt := (others => <>);
      Opt.Settings.Throw_On_Error := False;
      Math_Engine.Parse ("x+}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        not Math_Syntax.Is_Valid (Outp.Parsed) and then
        Outp.Geometry.Valid and then
        Math_Engine.Error (Outp) = Math_Syntax.Error (Outp.Parsed),
        "nonthrowing parse error draws original source without math success");
      Check (Outp.Geometry.Commands.Length = 3 and then
        Outp.Geometry.Commands (1).Code_Point = Character'Pos ('x') and then
        Outp.Geometry.Commands (2).Code_Point = Character'Pos ('+') and then
        Outp.Geometry.Commands (3).Code_Point = Character'Pos ('}'),
        "fallback commands preserve literal source code points");
      Opt := (others => <>);
      Opt.Settings.Max_Expand := 1;
      Math_Engine.Parse ("\def\budget{\budget}\budget",
        Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Engine.Error (Outp)'Length > 10,
        "configured maxExpand enforces the expansion budget");
      Opt := (others => <>);
      Opt.Settings.Max_Expand := 10_001;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings and then
        Math_Engine.Error (Outp) = "maxExpand must be in 1..10000",
        "out-of-range maxExpand rejected explicitly");

      Opt := (others => <>);
      Math_Engine.Parse ("\frac{a}{b}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "default rule thickness request ready");
      declare
         Default_Ascent : constant Long_Float := Outp.Geometry.Ascent;
         Default_Descent : constant Long_Float := Outp.Geometry.Descent;
         Default_Rules : Natural := 0;
         Thick_Rules : Natural := 0;
         Thick_Rule_Height : Long_Float := 0.0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Default_Rules := Default_Rules + 1;
            end if;
         end loop;
         Opt.Settings.Min_Rule_Thickness := 0.2;
         Math_Engine.Parse ("\frac{a}{b}", Shared'Access, Opt, Outp);
         Check (Outp.Status = Math_Engine.Ready,
           "configured rule thickness request ready");
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Thick_Rules := Thick_Rules + 1;
               Thick_Rule_Height := Command.Height;
            end if;
         end loop;
         Check (Default_Rules = 1 and Thick_Rules = Default_Rules,
           "minimum thickness preserves fraction rule count");
         Check (Thick_Rule_Height >= 0.2,
           "fraction rule honors minimum thickness");
         Check (Outp.Geometry.Ascent > Default_Ascent and
           Outp.Geometry.Descent > Default_Descent,
           "thicker fraction expands composed clearance bounds");
      end;
      Opt := (others => <>);
      Opt.Settings.Min_Rule_Thickness := 0.02;
      Math_Engine.Parse ("\genfrac{}{}{0.01pt}{}{a}{b}",
        Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "source fraction rule parses with a configured minimum");
      declare
         Custom_Rule_Height : Long_Float := 0.0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Custom_Rule_Height := Command.Height;
            end if;
         end loop;
         Check (Custom_Rule_Height >= 0.02,
           "minimum thickness overrides a thinner source fraction rule");
      end;
      Opt.Settings.Min_Rule_Thickness := 0.0;
      Math_Engine.Parse ("\genfrac{}{}{0.01pt}{}{a}{b}",
        Shared'Access, Opt, Outp);
      declare
         Source_Rule_Height : Long_Float := 0.0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Source_Rule_Height := Command.Height;
            end if;
         end loop;
         Check (Source_Rule_Height < 0.02,
           "source thickness below legacy cutoff is retained without minimum");
      end;
      Opt := (others => <>);
      Opt.Settings.Min_Rule_Thickness := 100.1;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings,
        "out-of-range minimum rule thickness rejected");
      Opt := (others => <>);
      Opt.Settings.Max_Size := 1;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status /= Math_Engine.Unsupported_Settings,
        "minimum supported maxSize passes engine validation");
      Opt.Settings.Max_Size := 100;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "maximum supported maxSize accepted");
      Opt.Settings.Max_Size := 101;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings and then
        Math_Engine.Error (Outp) = "maxSize must be in 1..100",
        "maxSize above 100 rejected explicitly");
      Opt := (others => <>);
      Opt.Settings.Leqno := True;
      Math_Engine.Parse
        ("\begin{equation}x\tag{1}\end{equation}",
         Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "leqno accepted by engine");
      declare
         Root : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Math_Syntax.Root (Outp.Parsed)));
         Tag_Node : constant Math_Syntax.Node := Math_Syntax.Element
           (Outp.Parsed, Positive (Root.First));
      begin
         Check (Tag_Node.Kind = Math_Model.Tagged_Node and then
           Tag_Node.Tag_Is_Left,
           "leqno marks equation tag as left-positioned");
      end;
      Opt := (others => <>);
      Opt.Foreground_Set := True;
      Opt.Foreground := (Red => 0.2, Green => 0.3,
                         Blue => 0.4, Alpha => 1.0);
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "valid foreground accepted");
      declare
         Found : Boolean := False;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 0.2 and then
              Command.Green = 0.3 and then Command.Blue = 0.4
            then
               Found := True;
            end if;
         end loop;
         Check (Found, "foreground applied to uncolored glyph");
      end;

      Opt.Foreground.Red := 1.1;
      Math_Engine.Parse ("x", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Unsupported_Settings,
        "invalid foreground range rejected");

      Opt := (others => <>);
      Opt.Global_Group := True;
      Math_Engine.Parse ("\gdef\saved{x}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Macros.Is_Defined (Shared, "\saved") and then
        Outp.Geometry.Valid and then Outp.Geometry.Width = 0.0 and then
        Outp.Geometry.Ascent = 0.0 and then Outp.Geometry.Descent = 0.0 and then
        Outp.Geometry.Commands.Is_Empty,
        "command-only global definition is a valid empty rendering");
      Opt.Global_Group := False;
      Math_Engine.Parse ("\saved", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Source (Outp.Parsed) = "\saved" and then
        not Outp.Geometry.Commands.Is_Empty,
        "global macro renders in a following request");
      Math_Engine.Parse ("\def\temp{x}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        not Math_Macros.Is_Defined (Shared, "\temp") and then
        Outp.Geometry.Commands.Is_Empty,
        "local definition in command-only root rolls back");
      Math_Engine.Parse ("\gdef\saved{y}\bogus", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and then
        Math_Macros.Is_Defined (Shared, "\saved"),
        "global definition persists after later parse failure");
      Math_Engine.Parse ("\saved", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        not Outp.Geometry.Commands.Is_Empty,
        "failed request leaves updated global macro available");
      Math_Engine.Parse ("", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "empty source is engine-ready");
      Check (Outp.Geometry.Valid and then Outp.Geometry.Width = 0.0 and then
        Outp.Geometry.Ascent = 0.0 and then
        Outp.Geometry.Descent = 0.0 and then
        Outp.Geometry.Commands.Is_Empty,
        "empty source has empty valid geometry");
      Math_Engine.Parse ("\newline", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Outp.Geometry.Valid and then Outp.Geometry.Width = 0.0 and then
        Outp.Geometry.Ascent = 0.0 and then
        Outp.Geometry.Descent = 0.0 and then
        Outp.Geometry.Commands.Is_Empty,
        "standalone forced break has no rendered line extent");
      Math_Engine.Parse ("\saved", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and then
        Math_Syntax.Source (Outp.Parsed) = "\saved" and then
        not Outp.Geometry.Commands.Is_Empty,
        "shared macro expands with source identity preserved");
      Check (Math_Macros.Scope_Depth (Shared) = 0,
        "shared scope restored after requests");

      declare
         Parsed : Math_Syntax.Document;
         Geometry : Math_Layout.Box;
         Source : constant String := (1 .. 1_000 => 'x');
      begin
         Poll_Count := 0;
         Parsed := Math_Syntax.Parse (Source);
         begin
            Geometry := Math_Layout.Build
              (Parsed, Math_Layout.Text_Style, Cancel_Context'Unchecked_Access);
            Check (False, "layout cancellation propagates from row sweep");
         exception
            when Math_Work_Control.Stop_Requested =>
               Check (True, "layout cancellation propagates from row sweep");
         end;
      end;
      declare
         Parsed : Math_Syntax.Document;
         Geometry : Math_Layout.Box;
         Source : constant String := (1 .. 1_000 => 'x');
      begin
         Poll_Count := 0;
         Parsed := Math_Syntax.Parse (Source);
         begin
            Geometry := Math_Layout.Build
              (Parsed, Math_Layout.Text_Style, Deadline_Context'Unchecked_Access);
            Check (False, "layout deadline propagates distinctly");
         exception
            when Math_Work_Control.Deadline_Expired =>
               Check (True, "layout deadline propagates distinctly");
         end;
      end;
   end Run;
begin
   Run;
   Ada.Text_IO.Put_Line ("ASSERTIONS" & Natural'Image (Checks) &
     " failures=" & Natural'Image (Failures));
   if Checks < 18 or else Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Engine_Probe;
