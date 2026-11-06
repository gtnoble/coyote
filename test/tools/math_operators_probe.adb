with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Math_Layout;
with Math_Metrics;
with Math_Model;
with Math_Syntax;

procedure Math_Operators_Probe is
   use type Math_Model.Atom_Class;
   use type Math_Model.Node_Kind;
   use type Math_Model.Font_Kind;
   use type Math_Layout.Command_Kind;

   Checks : Natural := 0;
   Failures : Natural := 0;

   type Operator_Case is record
      Name : String (1 .. 9);
      Code : Natural;
      Raw : String (1 .. 5);
   end record;

   Cases : constant array (Positive range 1 .. 15) of Operator_Case :=
     (("coprod   ", 16#2210#, "∐  "),
      ("iint     ", 16#222C#, "∬  "),
      ("iiint    ", 16#222D#, "∭  "),
      ("oint     ", 16#222E#, "∮  "),
      ("oiint    ", 16#222F#, "∯  "),
      ("oiiint   ", 16#2230#, "∰  "),
      ("bigwedge ", 16#22C0#, "⋀  "),
      ("bigvee   ", 16#22C1#, "⋁  "),
      ("bigcap   ", 16#22C2#, "⋂  "),
      ("bigcup   ", 16#22C3#, "⋃  "),
      ("bigodot  ", 16#2A00#, "⨀  "),
      ("bigoplus ", 16#2A01#, "⨁  "),
      ("bigotimes", 16#2A02#, "⨂  "),
      ("biguplus ", 16#2A04#, "⨄  "),
      ("bigsqcup ", 16#2A06#, "⨆  "));

   procedure Check (Condition : Boolean; Label : String) is
   begin
      Checks := Checks + 1;
      if Condition then
         Ada.Text_IO.Put_Line ("ok " & Label);
      else
         Failures := Failures + 1;
         Ada.Text_IO.Put_Line ("FAIL " & Label);
      end if;
   end Check;

   procedure Check_Operator (Expression : String; Point : Natural;
                             Label : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Expression);
      Text_Box : Math_Layout.Box;
      Display_Box : Math_Layout.Box;
      Text_Glyphs : Natural := 0;
      Display_Glyphs : Natural := 0;
      Text_Font : Math_Model.Font_Kind := Math_Model.Main_Regular;
      Display_Font : Math_Model.Font_Kind := Math_Model.Main_Regular;
      Text_Paths : Natural := 0;
      Display_Paths : Natural := 0;
      Base_Point : constant Natural :=
        (case Point is
            when 16#222F# => 16#222C#,
            when 16#2230# => 16#222D#,
            when others => Point);
      Is_Contour : constant Boolean := Point in 16#222F# | 16#2230#;
   begin
      Check (Math_Syntax.Is_Valid (Parsed), Label & " parses");
      if not Math_Syntax.Is_Valid (Parsed) then
         return;
      end if;
      declare
         Root : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Math_Syntax.Root (Parsed)));
         Atom : constant Math_Syntax.Node := Math_Syntax.Element
           (Parsed, Positive (Root.First));
      begin
         Check (Atom.Kind = Math_Model.Glyph_Node and then
           Atom.Class = Math_Model.Operator_Atom and then
           Atom.Code_Point = Point,
           Label & " is operator-class glyph");
      end;
      Text_Box := Math_Layout.Build (Parsed, Math_Layout.Text_Style);
      Display_Box := Math_Layout.Build (Parsed, Math_Layout.Display_Style);
      if Is_Contour or else
        Math_Metrics.Lookup (Math_Model.Main_Regular, Point).Found or else
        Math_Metrics.Lookup (Math_Model.Size_1, Point).Found
      then
         Check (Text_Box.Valid and Display_Box.Valid,
           Label & " text and display layout valid");
         for Command of Text_Box.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              (Command.Code_Point = Point or else
               (Is_Contour and then Command.Code_Point = Base_Point))
            then
               Text_Glyphs := Text_Glyphs + 1;
               Text_Font := Command.Font;
            elsif Command.Kind = Math_Layout.Path_Command then
               Text_Paths := Text_Paths + 1;
            end if;
         end loop;
         for Command of Display_Box.Commands loop
            if Command.Kind = Math_Layout.Glyph_Command and then
              (Command.Code_Point = Point or else
               (Is_Contour and then Command.Code_Point = Base_Point))
            then
               Display_Glyphs := Display_Glyphs + 1;
               Display_Font := Command.Font;
            elsif Command.Kind = Math_Layout.Path_Command then
               Display_Paths := Display_Paths + 1;
            end if;
         end loop;
         Check (Text_Glyphs = 1, Label & " emits one text operator glyph");
         Check (Display_Glyphs = 1,
           Label & " emits one display operator glyph");
         if Is_Contour then
            Check (Text_Font = Math_Model.Size_1 and
              Display_Font = Math_Model.Size_2 and
              Text_Paths = 1 and Display_Paths = 1,
              Label & " overlays one clipped oval on size1/size2 base");
         end if;
         Ada.Text_IO.Put_Line
           (Label & " fonts=" & Math_Model.Font_Kind'Image (Text_Font) &
            "/" & Math_Model.Font_Kind'Image (Display_Font) &
            " size1=" & Boolean'Image
              (Math_Metrics.Lookup (Math_Model.Size_1, Point).Found) &
            " size2=" & Boolean'Image
              (Math_Metrics.Lookup (Math_Model.Size_2, Point).Found));
      else
         Check (not Text_Box.Valid and not Display_Box.Valid,
           Label & " without invented glyph metrics stays unsupported");
      end if;
   end Check_Operator;

begin
   for Item of Cases loop
      declare
         Name : constant String := Ada.Strings.Fixed.Trim
           (Item.Name, Ada.Strings.Both);
      begin
         Check_Operator ("\" & Name, Item.Code, "alias \" & Name);
         Check_Operator (Item.Raw (1 .. 3), Item.Code, "raw " & Name);
      end;
   end loop;
   declare
      Unsupported : constant Math_Syntax.Document := Math_Syntax.Parse ("😀");
   begin
      Check (not Math_Syntax.Is_Valid (Unsupported),
        "unregistered emoji remains rejected");
   end;
   Ada.Text_IO.Put_Line
     ("checks=" & Natural'Image (Checks) &
      " failures=" & Natural'Image (Failures));
   if Failures > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Math_Operators_Probe;
