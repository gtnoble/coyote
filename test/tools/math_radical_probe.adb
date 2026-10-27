with Ada.Text_IO;
with Math_Layout;
with Math_Syntax;

procedure Math_Radical_Probe is
   use type Math_Layout.Command_Kind;
   procedure Show (Name, Source : String) is
      Layout : constant Math_Layout.Box := Math_Layout.Build
        (Math_Syntax.Parse (Source));
      Paths : Natural := 0;
      Segments : Natural := 0;
   begin
      for Command of Layout.Commands loop
         if Command.Kind = Math_Layout.Path_Command then
            Paths := Paths + 1;
            Segments := Segments + Natural (Command.Path_Data.Length);
         end if;
      end loop;
      Ada.Text_IO.Put_Line
        (Name & " " & Boolean'Image (Layout.Valid) & " " &
         Long_Float'Image (Layout.Ascent) & " " &
         Long_Float'Image (Layout.Descent) & " " &
         Natural'Image (Paths) & " " & Natural'Image (Segments));
   end Show;
begin
   Show ("natural", "\sqrt{10}");
   Show ("tall-fraction", "\sqrt{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{x}}}}}}}}}}");
   Show ("tall-indexed", "\sqrt[3]{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{\frac{1}{x}}}}}}}}}}");
end Math_Radical_Probe;
