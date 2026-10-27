with Ada.Characters.Latin_1;
with Ada.Containers.Vectors;

package body Math_Paths is
   use type Ada.Containers.Count_Type;

   function Parse (Data : String) return Path is
      Result : Path;
      Items : Segment_Vectors.Vector;
      I : Integer := Data'First;
      X, Y, SX, SY : Long_Float := 0.0;
      Previous : Character := ' ';
      C1, C2 : Point;
      Have_C1, Have_C2 : Boolean := False;
      Mode : Character := ' ';

      procedure Fail (Text : String) is
      begin
         Items.Clear;
         Result.Length := 0;
         Result.Good := False;
         Result.Message := (others => ' ');
         Result.Message (1 .. Text'Length) := Text;
      end Fail;

      procedure Add (Value : Segment) is
      begin
         if Items.Length >= Max_Commands then
            Fail ("too many path commands");
         else
            Items.Append (Value);
            Result.Length := Natural (Items.Length);
         end if;
      end Add;

      procedure Space is
      begin
         while I <= Data'Last and then
           (Data (I) = ' ' or Data (I) = Ada.Characters.Latin_1.HT or
            Data (I) = Ada.Characters.Latin_1.LF or
            Data (I) = Ada.Characters.Latin_1.CR)
         loop
            I := I + 1;
         end loop;
         if I <= Data'Last and then Data (I) = ',' then
            I := I + 1;
            while I <= Data'Last and then
              (Data (I) = ' ' or Data (I) = Ada.Characters.Latin_1.HT or
               Data (I) = Ada.Characters.Latin_1.LF or
               Data (I) = Ada.Characters.Latin_1.CR)
            loop
               I := I + 1;
            end loop;
            if I > Data'Last or else Data (I) = ',' or else
              Data (I) in 'A' .. 'Z' or else Data (I) in 'a' .. 'z'
            then
               return;
            end if;
         end if;
      end Space;

      function Number (Value : out Long_Float) return Boolean is
         Start : constant Integer := I;
         Digit_Count : Natural := 0;
         Fraction : Natural := 0;
         Exponent : Integer := 0;
         Negative : Boolean := False;
         Mantissa : Long_Float := 0.0;
         Sign : Integer := 1;
      begin
         Space;
         if I <= Data'Last and then (Data (I) = '+' or Data (I) = '-') then
            Negative := Data (I) = '-';
            I := I + 1;
         end if;
         while I <= Data'Last and then Data (I) in '0' .. '9' loop
            if Digit_Count < 18 then
               Mantissa := Mantissa * 10.0 +
                 Long_Float (Character'Pos (Data (I)) - Character'Pos ('0'));
            end if;
            Digit_Count := Digit_Count + 1;
            I := I + 1;
         end loop;
         if I <= Data'Last and then Data (I) = '.' then
            I := I + 1;
            while I <= Data'Last and then Data (I) in '0' .. '9' loop
               if Digit_Count < 18 then
                  Mantissa := Mantissa * 10.0 +
                    Long_Float (Character'Pos (Data (I)) - Character'Pos ('0'));
               end if;
               Fraction := Fraction + 1;
               Digit_Count := Digit_Count + 1;
               I := I + 1;
            end loop;
         end if;
         if Digit_Count = 0 then
            I := Start;
            return False;
         end if;
         if I <= Data'Last and then
           (Data (I) = 'e' or Data (I) = 'E')
         then
            I := I + 1;
            if I <= Data'Last and then
              (Data (I) = '+' or Data (I) = '-')
            then
               if Data (I) = '-' then
                  Sign := -1;
               end if;
               I := I + 1;
            end if;
            if I > Data'Last or else Data (I) not in '0' .. '9' then
               return False;
            end if;
            while I <= Data'Last and then Data (I) in '0' .. '9' loop
               if Exponent < 1000 then
                  Exponent := Exponent * 10 +
                    Character'Pos (Data (I)) - Character'Pos ('0');
               end if;
               I := I + 1;
            end loop;
         end if;
         Exponent := Sign * Exponent - Integer (Fraction);
         if Exponent > 18 or Exponent < -300 then
            return False;
         end if;
         Value := Mantissa * 10.0 ** Exponent;
         if Negative then
            Value := -Value;
         end if;
         return Value'Valid and then abs Value <= Max_Coordinate;
      exception
         when others =>
            return False;
      end Number;

      function Pair (P : out Point) return Boolean is
         A, B : Long_Float;
      begin
         if not Number (A) or else not Number (B) then
            return False;
         end if;
         if Mode in 'a' .. 'z' then
            P := (X + A, Y + B);
         else
            P := (A, B);
         end if;
         return abs P.X <= Max_Coordinate and abs P.Y <= Max_Coordinate;
      end Pair;

      P, A, B : Point;
      V : Long_Float;
   begin
      Result.Good := True;
      if Data'Length > Max_Input_Bytes then
         Fail ("path input exceeds limit");
         return Result;
      end if;
      for J in Data'Range loop
         if Data (J) = ',' then
            declare
               Left : Integer := J - 1;
               Right : Integer := J + 1;
            begin
               while Left >= Data'First and then
                 (Data (Left) = ' ' or Data (Left) =
                    Ada.Characters.Latin_1.HT or Data (Left) =
                    Ada.Characters.Latin_1.LF or Data (Left) =
                    Ada.Characters.Latin_1.CR)
               loop
                  Left := Left - 1;
               end loop;
               while Right <= Data'Last and then
                 (Data (Right) = ' ' or Data (Right) =
                    Ada.Characters.Latin_1.HT or Data (Right) =
                    Ada.Characters.Latin_1.LF or Data (Right) =
                    Ada.Characters.Latin_1.CR)
               loop
                  Right := Right + 1;
               end loop;
               if Left < Data'First or else Right > Data'Last or else
                 (Data (Left) not in '0' .. '9' and Data (Left) /= '.') or else
                 (Data (Right) not in '0' .. '9' and Data (Right) not in '+' | '-' | '.')
               then
                  Fail ("invalid comma separator");
                  return Result;
               end if;
            end;
         end if;
      end loop;
      Space;
      while I <= Data'Last loop
         if Data (I) in 'A' .. 'Z' or else Data (I) in 'a' .. 'z' then
            Mode := Data (I);
            I := I + 1;
         elsif Mode = ' ' then
            Fail ("expected SVG path command");
            return Result;
         end if;
         if Mode = 'A' or Mode = 'a' then
            Fail ("SVG arcs are unsupported");
            return Result;
         elsif Mode not in 'M' | 'm' | 'L' | 'l' | 'H' | 'h' |
           'V' | 'v' | 'C' | 'c' | 'S' | 's' | 'Q' | 'q' | 'T' | 't' |
           'Z' | 'z'
         then
            Fail ("unknown SVG path command");
            return Result;
         end if;
         if Mode = 'Z' or Mode = 'z' then
            Add ((Kind => Close_Path, others => <>));
            X := SX;
            Y := SY;
            Previous := Mode;
            Have_C1 := False;
            Have_C2 := False;
            Mode := ' ';
            Space;
            if I <= Data'Last and then Data (I) not in 'A' .. 'Z' and then
              Data (I) not in 'a' .. 'z'
            then
               Fail ("close command has no parameters");
               return Result;
            end if;
         else
         declare
            Original : constant Character := Mode;
            First_Pair : Boolean := True;
            Had_Parameters : Boolean := False;
         begin
            loop
               Space;
               exit when I > Data'Last or else Data (I) in 'A' .. 'Z' or else
                 Data (I) in 'a' .. 'z';
               Had_Parameters := True;
               if Mode in 'M' | 'm' | 'L' | 'l' | 'T' | 't' then
                  if not Number (A.X) or else not Number (A.Y) then
                     Fail ("invalid SVG coordinate pair");
                     return Result;
                  end if;
                  if Mode in 'm' | 'l' | 't' then
                     A := (X + A.X, Y + A.Y);
                  end if;
                  if Mode in 'M' | 'm' then
                     if First_Pair then
                        Add ((Kind => Move_To, First => A, others => <>));
                        SX := A.X;
                        SY := A.Y;
                     else
                        Add ((Kind => Line_To, First => A, others => <>));
                     end if;
                  elsif Mode in 'T' | 't' then
                     if Previous in 'Q' | 'q' | 'T' | 't' then
                        B := (2.0 * X - C1.X, 2.0 * Y - C1.Y);
                     else
                        B := (X, Y);
                     end if;
                     Add ((Cubic_To,
                       (X + 2.0 * (B.X - X) / 3.0,
                        Y + 2.0 * (B.Y - Y) / 3.0),
                       (A.X + 2.0 * (B.X - A.X) / 3.0,
                        A.Y + 2.0 * (B.Y - A.Y) / 3.0), A));
                     C1 := B;
                  else
                     Add ((Kind => Line_To, First => A, others => <>));
                  end if;
                  X := A.X;
                  Y := A.Y;
                  Have_C1 := Mode in 'T' | 't';
                  Have_C2 := False;
                  if Mode = 'M' then Mode := 'L';
                  elsif Mode = 'm' then Mode := 'l';
                  end if;
               elsif Mode in 'H' | 'h' then
                  if not Number (V) then
                     Fail ("invalid horizontal coordinate");
                     return Result;
                  end if;
                  X := (if Mode = 'h' then X + V else V);
                  if abs X > Max_Coordinate then
                     Fail ("coordinate exceeds limit");
                     return Result;
                  end if;
                  Add ((Kind => Line_To, First => (X, Y), others => <>));
                  Have_C1 := False;
                  Have_C2 := False;
               elsif Mode in 'V' | 'v' then
                  if not Number (V) then
                     Fail ("invalid vertical coordinate");
                     return Result;
                  end if;
                  Y := (if Mode = 'v' then Y + V else V);
                  if abs Y > Max_Coordinate then
                     Fail ("coordinate exceeds limit");
                     return Result;
                  end if;
                  Add ((Kind => Line_To, First => (X, Y), others => <>));
                  Have_C1 := False;
                  Have_C2 := False;
               elsif Mode in 'C' | 'c' then
                  if not Pair (A) or else not Pair (B) or else not Pair (P) then
                     Fail ("invalid cubic coordinates");
                     return Result;
                  end if;
                  if abs A.X > Max_Coordinate or else abs A.Y > Max_Coordinate or else
                    abs B.X > Max_Coordinate or else abs B.Y > Max_Coordinate
                  then
                     Fail ("control coordinate exceeds limit");
                     return Result;
                  end if;
                  Add ((Cubic_To, A, B, P));
                  C1 := A;
                  C2 := B;
                  Have_C1 := True;
                  Have_C2 := True;
                  X := P.X;
                  Y := P.Y;
               elsif Mode in 'S' | 's' then
                  A := (if Have_C2 then (2.0 * X - C2.X, 2.0 * Y - C2.Y)
                        else (X, Y));
                  if not Pair (B) or else not Pair (P) then
                     Fail ("invalid smooth cubic coordinates");
                     return Result;
                  end if;
                  if abs A.X > Max_Coordinate or else abs A.Y > Max_Coordinate then
                     Fail ("control coordinate exceeds limit");
                     return Result;
                  end if;
                  Add ((Cubic_To, A, B, P));
                  C2 := B;
                  Have_C1 := False;
                  Have_C2 := True;
                  X := P.X;
                  Y := P.Y;
               elsif Mode in 'Q' | 'q' then
                  if not Pair (A) or else not Pair (B) then
                     Fail ("invalid quadratic coordinates");
                     return Result;
                  end if;
                  Add ((Cubic_To, (X + 2.0 * (A.X - X) / 3.0,
                    Y + 2.0 * (A.Y - Y) / 3.0),
                    (B.X + 2.0 * (A.X - B.X) / 3.0,
                    B.Y + 2.0 * (A.Y - B.Y) / 3.0), B));
                  C1 := A;
                  Have_C1 := True;
                  Have_C2 := False;
                  X := B.X;
                  Y := B.Y;
               end if;
               Previous := Original;
               First_Pair := False;
               if not Result.Good then
                  return Result;
               end if;
            end loop;
            if not Had_Parameters then
               Fail ("truncated SVG path command");
               return Result;
            end if;
         end;
         end if;
         Space;
      end loop;
      if Result.Length = 0 then
         Fail ("empty SVG path");
      else
         Result.Items := Items;
      end if;
      return Result;
   exception
      when others =>
         Fail ("malformed SVG path");
         return Result;
   end Parse;

   function Is_Valid (Item : Path) return Boolean is (Item.Good);

   function Error (Item : Path) return String is
      Last : Integer := Item.Message'Last;
   begin
      while Last >= Item.Message'First and then Item.Message (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      if Last < Item.Message'First then
         return "";
      end if;
      return Item.Message (Item.Message'First .. Last);
   end Error;

   function Count (Item : Path) return Natural is (Item.Length);

   function Element (Item : Path; Index : Positive) return Segment is
     (Item.Items (Index));

   function Extent (Item : Path) return Bounds is
      Result : Bounds;
      procedure Include (P : Point) is
      begin
         if not Result.Valid then
            Result := (P.X, P.Y, P.X, P.Y, True);
         else
            Result.Min_X := Long_Float'Min (Result.Min_X, P.X);
            Result.Min_Y := Long_Float'Min (Result.Min_Y, P.Y);
            Result.Max_X := Long_Float'Max (Result.Max_X, P.X);
            Result.Max_Y := Long_Float'Max (Result.Max_Y, P.Y);
         end if;
      end Include;
   begin
      for I in 1 .. Item.Length loop
         case Item.Items (I).Kind is
            when Move_To | Line_To => Include (Item.Items (I).First);
            when Cubic_To =>
               Include (Item.Items (I).First);
               Include (Item.Items (I).Second);
               Include (Item.Items (I).Third);
            when Close_Path => null;
         end case;
      end loop;
      return Result;
   end Extent;

   function Transform
     (Item : Path; XX, YX, XY, YY, DX, DY : Long_Float) return Path is
      Result : Path;
      function Finite (Value : Long_Float) return Boolean is
        (Value = Value and then abs Value <= Long_Float'Last);
      function Valid_Point (P : Point) return Boolean is
        (Finite (P.X) and then Finite (P.Y) and then
         abs P.X <= Max_Coordinate and then abs P.Y <= Max_Coordinate);
      function Valid_Transform return Boolean is
        (Finite (XX) and then Finite (YX) and then Finite (XY) and then
         Finite (YY) and then Finite (DX) and then Finite (DY) and then
         abs XX <= Max_Coordinate and then abs YX <= Max_Coordinate and then
         abs XY <= Max_Coordinate and then abs YY <= Max_Coordinate and then
         abs DX <= Max_Coordinate and then abs DY <= Max_Coordinate);
      procedure Reject is
      begin
         Result.Good := False;
         Result.Message := (others => ' ');
         Result.Message (1 .. 24) := "invalid affine transform";
      end Reject;
   begin
      if not Item.Good or else not Valid_Transform then
         Reject;
         return Result;
      end if;
      for I in 1 .. Item.Length loop
         declare
            Value : Segment := Item.Items (I);
            procedure Apply (P : in out Point) is
               X0 : constant Long_Float := P.X;
               Y0 : constant Long_Float := P.Y;
            begin
               P := (XX * X0 + XY * Y0 + DX, YX * X0 + YY * Y0 + DY);
            end Apply;
         begin
            case Value.Kind is
               when Move_To | Line_To => Apply (Value.First);
               when Cubic_To =>
                  Apply (Value.First);
                  Apply (Value.Second);
                  Apply (Value.Third);
               when Close_Path => null;
            end case;
            if not Valid_Point (Value.First) or else
              (Value.Kind = Cubic_To and then
               (not Valid_Point (Value.Second) or else
                not Valid_Point (Value.Third)))
            then
               Reject;
               return Result;
            end if;
            Result.Items.Append (Value);
         end;
      end loop;
      Result.Length := Item.Length;
      Result.Good := True;
      return Result;
   exception
      when others =>
         Reject;
         return Result;
   end Transform;
end Math_Paths;
