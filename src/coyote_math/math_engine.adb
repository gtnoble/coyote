with Ada.Strings.Unbounded;
with Math_Metrics;
with Math_Model;
with Math_Syntax;

package body Math_Engine is
   use type Math_Layout.Command_Kind;
   use type Math_Layout.Math_Style;
   use Ada.Strings.Unbounded;

   procedure Set_Message (Output : in out Result; Text : String) is
   begin
      Output.Message := To_Unbounded_String (Text);
   end Set_Message;

   function Error (Item : Result) return String is
   begin
      return To_String (Item.Message);
   end Error;

   function Same (Left, Right : RGBA) return Boolean is
     (Left.Red = Right.Red and Left.Green = Right.Green and
      Left.Blue = Right.Blue and Left.Alpha = Right.Alpha);

   function Valid_Color (Item : RGBA) return Boolean is
     (Item.Red in 0.0 .. 1.0 and Item.Green in 0.0 .. 1.0 and
      Item.Blue in 0.0 .. 1.0 and Item.Alpha in 0.0 .. 1.0);

   procedure Parse
     (Source  : String;
      Shared  : not null access Math_Macros.Context;
      Options : Request;
      Output  : out Result) is
      Syntax_Options : Math_Syntax.Options := (others => <>);
   begin
      Output := (Status => Parse_Error, Parsed => <>, Geometry => <>,
                 Meaning => <>, Message => <>);
      if Options.Settings.Max_Expand > 10_000 then
         Output.Status := Unsupported_Settings;
         Set_Message (Output, "maxExpand must be in 1..10000");
         return;
      end if;
      if Options.Settings.Max_Size not in 1 .. 100 then
         Output.Status := Unsupported_Settings;
         Set_Message (Output, "maxSize must be in 1..100");
         return;
      end if;
      if Options.Settings.Fleqn then
         Output.Status := Unsupported_Settings;
         Set_Message (Output, "fleqn is not supported by native math");
         return;
      end if;
      if Options.Settings.Trust then
         Output.Status := Unsupported_Settings;
         Set_Message (Output, "trust is not supported by native math");
         return;
      end if;
      if Options.Settings.Min_Rule_Thickness < 0.0 or else
        Options.Settings.Min_Rule_Thickness > 100.0 or else
        Options.Settings.Min_Rule_Thickness /=
          Options.Settings.Min_Rule_Thickness
      then
         Output.Status := Unsupported_Settings;
         Set_Message (Output,
           "minRuleThickness must be finite and in 0..100");
         return;
      end if;
      Syntax_Options :=
        (Strict => Options.Strict,
         Max_Expand => Math_Syntax.Expansion_Limit (
           Options.Settings.Max_Expand),
         Max_Size => Math_Syntax.Size_Limit (Options.Settings.Max_Size),
         Display_Mode => Options.Style = Math_Layout.Display_Style,
         Left_Tags => Options.Settings.Leqno,
         Color_Is_Text_Color =>
           Options.Settings.Color_Is_Text_Color);
      if not Valid_Color (Options.Settings.Error_Color) then
         Output.Status := Unsupported_Settings;
         Set_Message (Output, "errorColor RGBA must be in 0..1");
         return;
      end if;
      if Options.Foreground_Set and not Valid_Color (Options.Foreground) then
         Output.Status := Unsupported_Settings;
         Set_Message (Output, "foreground RGBA must be in 0..1");
         return;
      end if;

      Output.Parsed := Math_Syntax.Parse
        (Source, Shared, Syntax_Options, Options.Global_Group);
      if not Math_Syntax.Is_Valid (Output.Parsed) then
         Output.Status := Parse_Error;
         Set_Message (Output, Math_Syntax.Error (Output.Parsed));
         if not Options.Settings.Throw_On_Error and then
           Source'Length > 0 and then
           Source'Length <= Math_Syntax.Max_Source_Bytes
         then
            declare
               Fallback : Math_Layout.Box;
               X : Long_Float := 0.0;
               Baseline : constant Long_Float := 0.8;
               Can_Draw : Boolean := True;
            begin
               for Char of Source loop
                  declare
                     Point : constant Natural := Character'Pos (Char);
                     Metric : Math_Metrics.Glyph_Metric :=
                       Math_Metrics.Lookup
                         (Math_Model.Typewriter_Regular, Point);
                     Font : Math_Model.Font_Kind :=
                       Math_Model.Typewriter_Regular;
                     Command : Math_Layout.Draw_Command;
                  begin
                     if not Metric.Found then
                        Font := Math_Model.Main_Regular;
                        Metric := Math_Metrics.Lookup (Font, Point);
                     end if;
                     if not Metric.Found then
                        Can_Draw := False;
                        exit;
                     end if;
                     Command.Font := Font;
                     Command.Code_Point := Point;
                     Command.X := X;
                     Command.Y := Baseline;
                     Command.Has_Color := True;
                     Command.Red := Options.Settings.Error_Color.Red;
                     Command.Green := Options.Settings.Error_Color.Green;
                     Command.Blue := Options.Settings.Error_Color.Blue;
                     Command.Alpha := Options.Settings.Error_Color.Alpha;
                     Fallback.Commands.Append (Command);
                     X := X + Metric.Width;
                     Fallback.Ascent := Long_Float'Max
                       (Fallback.Ascent, Metric.Ascent);
                     Fallback.Descent := Long_Float'Max
                       (Fallback.Descent, Metric.Descent);
                  end;
               end loop;
               if Can_Draw then
                  Fallback.Valid := True;
                  Fallback.Width := X;
                  Output.Geometry := Fallback;
               end if;
            end;
         end if;
         return;
      end if;
      Output.Meaning := Math_Semantics.Project (Output.Parsed);
      if not Math_Semantics.Is_Valid (Output.Meaning) then
         Output.Status := Layout_Error;
         Set_Message (Output, Math_Semantics.Error (Output.Meaning));
         return;
      end if;
      Output.Geometry := Math_Layout.Build
        (Output.Parsed, Options.Style,
         (Min_Rule_Thickness => Options.Settings.Min_Rule_Thickness,
          Max_Size => Options.Settings.Max_Size));
      if not Output.Geometry.Valid then
         Output.Status := Layout_Error;
         Set_Message (Output, To_String (Output.Geometry.Message));
         return;
      end if;
      if Options.Foreground_Set then
         for Index in Output.Geometry.Commands.First_Index ..
           Output.Geometry.Commands.Last_Index
         loop
            declare
               Command : Math_Layout.Draw_Command :=
                 Output.Geometry.Commands (Index);
            begin
               if not Command.Has_Color then
                  Command.Has_Color := True;
                  Command.Red := Options.Foreground.Red;
                  Command.Green := Options.Foreground.Green;
                  Command.Blue := Options.Foreground.Blue;
                  Command.Alpha := Options.Foreground.Alpha;
                  Output.Geometry.Commands.Replace_Element (Index, Command);
               end if;
            end;
         end loop;
      end if;
      Output.Status := Ready;
      for Index in 1 .. Math_Syntax.Diagnostic_Count (Output.Parsed) loop
         declare
            Diagnostic : constant Math_Syntax.Diagnostic :=
              Math_Syntax.Diagnostic_At
                (Output.Parsed, Positive (Index));
            Message : constant String := To_String (Diagnostic.Message);
         begin
            if Diagnostic.Kind in Math_Syntax.Warning |
              Math_Syntax.Refusal and then Message'Length >= 27 and then
              Message (1 .. 27) = "refused untrusted command: "
            then
               Output.Status := Policy_Visible_Command;
            end if;
         end;
      end loop;
   end Parse;
end Math_Engine;
