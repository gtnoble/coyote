with Ada.Command_Line;
with Ada.Text_IO;
with Math_Layout;
with Math_Model;
with Math_Syntax;

procedure Math_Delimiter_Probe is
   use Math_Model;
   use Math_Layout;
   procedure Check (Source : String; Expected : Natural) is
      B : constant Box := Build (Math_Syntax.Parse (Source));
      Count : Natural := 0;
      Seen_Top, Seen_Repeat, Seen_Bottom : Boolean := False;
      Seen_Middle : Boolean := False;
   begin
      if not B.Valid then
         Ada.Text_IO.Put_Line ("FAIL invalid: " & Source);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;
      for C of B.Commands loop
         if C.Font = Size_4 and then C.Code_Point in 16#239B# .. 16#23AD# then
            Count := Count + 1;
            Seen_Top := Seen_Top or C.Code_Point in 16#239B# | 16#239E# or
              C.Code_Point in 16#23A1# | 16#23A4# or
              C.Code_Point in 16#23A7# | 16#23AB#;
            Seen_Repeat := Seen_Repeat or C.Code_Point in 16#239C# .. 16#239F# or
              C.Code_Point in 16#23A2# .. 16#23A5# or C.Code_Point = 16#23AA#;
            Seen_Bottom := Seen_Bottom or C.Code_Point in 16#239D# | 16#23A0# or
              C.Code_Point in 16#23A3# | 16#23A6# or
              C.Code_Point in 16#23A9# | 16#23AD#;
            Seen_Middle := Seen_Middle or C.Code_Point in 16#23A8# | 16#23AC#;
         end if;
      end loop;
      if Expected > 0 and then
        ((Count < Expected) or else not (Seen_Top and Seen_Bottom) or else
         ((Expected > 4) and then not (Seen_Repeat or Seen_Middle))) then
         Ada.Text_IO.Put_Line ("FAIL pieces: " & Source & Natural'Image (Count));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      else
         Ada.Text_IO.Put_Line ("PASS " & Source & Natural'Image (Count) &
           " " & Long_Float'Image (B.Ascent + B.Descent));
      end if;
   end Check;
begin
   Check ("\left(\frac{\frac{\frac{\frac{\frac{\frac{a}{b}}{c}}{d}}{e}}{f}}{g}\right)", 4);
   Check ("\left[\frac{\frac{\frac{\frac{\frac{\frac{a}{b}}{c}}{d}}{e}}{f}}{g}\right]", 4);
   Check ("\left\{\frac{\frac{\frac{\frac{\frac{\frac{a}{b}}{c}}{d}}{e}}{f}}{g}\right\}", 6);
   Check ("\begin{cases}x&x>0\\-x&x<0\end{cases}", 0);
   Check ("\begin{pmatrix}a&b\\c&d\end{pmatrix}", 0);
   Check ("\left(\begin{matrix}a&b\\c&d\end{matrix}\right.", 0);
   Check ("\left(x\right.", 0);
   Check ("\begin{pmatrix}a&b\\c&d\\e&f\\g&h\\i&j\\k&l\\m&n\\o&p\\q&r\\s&t\\u&v\\w&x\\y&z\end{pmatrix}", 0);
end Math_Delimiter_Probe;
