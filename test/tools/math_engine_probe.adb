with Ada.Command_Line;
with Ada.Containers;
with Ada.Text_IO;
with Math_Engine;
with Math_Layout;
with Math_Macros;
with Math_Model;
with Math_Semantics;
with Math_Syntax;

procedure Math_Engine_Probe is
   use type Ada.Containers.Count_Type;
   use type Math_Engine.Status_Kind;
   use type Math_Layout.Command_Kind;
   use type Math_Model.Node_Kind;
   Checks : Natural := 0;
   Failures : Natural := 0;
   Shared : aliased Math_Macros.Context;

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
      Check (Outp.Status = Math_Engine.Ready,
        "default color command request remains syntactically ready");
      declare
         Red_Glyphs : Natural := 0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Red_Glyphs = 3,
           "default color command colors following math atoms");
      end;
      Opt.Settings.Color_Is_Text_Color := True;
      Math_Engine.Parse ("\color{red}x+y", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready,
        "text-color compatibility request remains syntactically ready");
      declare
         Red_Glyphs : Natural := 0;
      begin
         for Command of Outp.Geometry.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              Command.Has_Color and then Command.Red = 1.0 and then
              Command.Green = 0.0 and then Command.Blue = 0.0
            then
               Red_Glyphs := Red_Glyphs + 1;
            end if;
         end loop;
         Check (Red_Glyphs = 1,
           "text-color compatibility command colors its argument only");
      end;

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
      Math_Engine.Parse ("\gdef\facade{Q}", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Parse_Error and
        Math_Macros.Is_Defined (Shared, "\facade"),
        "global definitions persist in caller context");
      Opt.Global_Group := False;
      Math_Engine.Parse ("\facade", Shared'Access, Opt, Outp);
      Check (Outp.Status = Math_Engine.Ready and
        Math_Syntax.Source (Outp.Parsed) = "\facade",
        "shared macro expands with source identity preserved");
      Check (Math_Macros.Scope_Depth (Shared) = 0,
        "shared scope restored after requests");
   end Run;
begin
   Run;
   Ada.Text_IO.Put_Line ("ASSERTIONS" & Natural'Image (Checks) &
     " failures=" & Natural'Image (Failures));
   if Checks < 18 or else Failures /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Engine_Probe;
