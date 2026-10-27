with Ada.Text_IO;
with Math_Layout;
with Math_Syntax;

procedure Math_Arrays_Probe is
   use type Math_Layout.Command_Kind;
   procedure Show (Name, Source : String) is
      Parsed : constant Math_Syntax.Document := Math_Syntax.Parse (Source);
      Layout : constant Math_Layout.Box := Math_Layout.Build (Parsed);
      Rules : Natural := 0;
   begin
      if Layout.Valid then
         for Command of Layout.Commands loop
            if Command.Kind = Math_Layout.Rule_Command then
               Rules := Rules + 1;
            end if;
         end loop;
         Ada.Text_IO.Put_Line
           (Name & " OK " & Long_Float'Image (Layout.Width) & " " &
            Natural'Image (Rules));
      else
         Ada.Text_IO.Put_Line (Name & " ERROR " & Math_Syntax.Error (Parsed));
      end if;
   end Show;
begin
   Show ("array-align", "\begin{array}{lcr}a&bb&c\\xxx&y&zz\end{array}");
   Show ("array-rule", "\begin{array}{|c|r|}a&bb\\ccc&d\end{array}");
   Show ("nested", "\begin{array}{c}\begin{matrix}a&b\\c&d\end{matrix}\end{array}");
   Show ("alignedat", "\begin{alignedat}{2}a&=b&c&=d\\x&=y&z&=w\end{alignedat}");
   Show ("bad-spec", "\begin{array}{lx}a&b\end{array}");
   Show ("missing-spec", "\begin{array}a&b\end{array}");
   Show ("wrong-columns", "\begin{array}{cc}a&b&c\end{array}");
   Show ("wrong-pairs", "\begin{alignedat}{2}a&=b\end{alignedat}");
end Math_Arrays_Probe;
