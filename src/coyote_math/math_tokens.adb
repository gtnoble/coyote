with Math_Source;
with Math_Unicode;
with Ada.Containers;

use type Ada.Containers.Count_Type;

package body Math_Tokens is
   procedure Lex
     (Input       : Math_Source.Source;
      Result      : out Stream;
      Diagnostic  : out Diagnostic_Kind;
      Error_Byte  : out Natural) is
      Text : constant String := Math_Source.Text (Input);
      Pos  : Natural := 0;
      Scalar : Natural := 0;
      UTF16 : Natural := 0;
      procedure Add
        (Kind : Token_Kind; Start_B : Natural; Start_S : Natural;
         Start_U : Natural; End_B : Natural; End_S : Natural;
         End_U : Natural; Point : Natural := 0) is
         Lexeme : Ada.Strings.Unbounded.Unbounded_String :=
           Ada.Strings.Unbounded.Null_Unbounded_String;
      begin
         if Result.Items.Length = Max_Tokens then
            Diagnostic := Token_Limit;
            Error_Byte := Start_B;
         else
            if End_B > Start_B then
               declare
                  Lexeme_End : Natural := End_B;
               begin
                  if Kind = Control_Word then
                     while Lexeme_End > Start_B and then
                       Text (Text'First + Lexeme_End - 1) in
                         Character'Val (9) | Character'Val (10) |
                         Character'Val (13) | Character'Val (32)
                     loop
                        Lexeme_End := Lexeme_End - 1;
                     end loop;
                  end if;
                  Lexeme := Ada.Strings.Unbounded.To_Unbounded_String
                    (Text (Text'First + Start_B ..
                       Text'First + Lexeme_End - 1));
               end;
            end if;
            Result.Items.Append
              (New_Item => Token'(Kind, Start_B, End_B, Start_S, End_S,
                Start_U, End_U, Point, Start_B + 1, End_B - Start_B,
                Lexeme, others => <>));
         end if;
      end Add;
      function Byte_Value (Offset : Natural) return Natural is
         First : constant Natural := Character'Pos (Text (Text'First + Offset));
      begin
         if First < 16#80# then return First;
         elsif First < 16#E0# then
            return (First mod 32) * 64 +
              Character'Pos (Text (Text'First + Offset + 1)) mod 64;
         elsif First < 16#F0# then
            return (First mod 16) * 4_096 +
              (Character'Pos (Text (Text'First + Offset + 1)) mod 64) * 64 +
              Character'Pos (Text (Text'First + Offset + 2)) mod 64;
         else
            return (First mod 8) * 262_144 +
              (Character'Pos (Text (Text'First + Offset + 1)) mod 64) * 4_096 +
              (Character'Pos (Text (Text'First + Offset + 2)) mod 64) * 64 +
              Character'Pos (Text (Text'First + Offset + 3)) mod 64;
         end if;
      end Byte_Value;
      function Width (Offset : Natural) return Natural is
         B : constant Natural := Character'Pos (Text (Text'First + Offset));
      begin
         if B < 16#80# then return 1;
         elsif B < 16#E0# then return 2;
         elsif B < 16#F0# then return 3;
         else return 4;
         end if;
      end Width;
      function Letter (Point : Natural) return Boolean is
        (Point in Character'Pos ('A') .. Character'Pos ('Z') or else
         Point in Character'Pos ('a') .. Character'Pos ('z') or else
         Point = Character'Pos ('@'));
   begin
      Result := (Original => Input, Items => Token_Vectors.Empty_Vector);
      Diagnostic := No_Error;
      Error_Byte := 0;
      if not Math_Source.Is_Valid (Input) then
         Diagnostic := Invalid_Source;
         return;
      end if;
      while Pos < Text'Length and Diagnostic = No_Error loop
         declare
            Start_B : constant Natural := Pos;
            Start_S : constant Natural := Scalar;
            Start_U : constant Natural := UTF16;
            Point : Natural := Byte_Value (Pos);
            Step : Natural := Width (Pos);
            Kind : Token_Kind := Character_Token;
         begin
            if Point = 37 then
               while Pos < Text'Length and then
                 Byte_Value (Pos) /= 10
               loop
                  Step := Width (Pos);
                  Point := Byte_Value (Pos);
                  Pos := Pos + Step;
                  Scalar := Scalar + 1;
                  UTF16 := UTF16 + (if Point > 16#FFFF# then 2 else 1);
               end loop;
            elsif Point in 9 | 10 | 13 | 32 then
               Kind := Space_Token;
               while Pos < Text'Length and then
                 Byte_Value (Pos) in 9 | 10 | 13 | 32
               loop
                  Point := Byte_Value (Pos);
                  Pos := Pos + 1;
                  Scalar := Scalar + 1;
                  UTF16 := UTF16 + 1;
               end loop;
               Add (Kind, Start_B, Start_S, Start_U, Pos, Scalar, UTF16);
            elsif Point = 92 then
               Pos := Pos + 1;
               Scalar := Scalar + 1;
               UTF16 := UTF16 + 1;
               if Pos = Text'Length then
                  Diagnostic := Trailing_Escape;
                  Error_Byte := Start_B;
               else
                  Point := Byte_Value (Pos);
                  Step := Width (Pos);
                  if Letter (Point) then
                     Kind := Control_Word;
                     while Pos < Text'Length and then
                       Letter (Byte_Value (Pos))
                     loop
                        Step := Width (Pos);
                        Pos := Pos + Step;
                        Scalar := Scalar + 1;
                        UTF16 := UTF16 + 1;
                     end loop;
                     if Pos < Text'Length and then
                       Byte_Value (Pos) in 9 | 10 | 13 | 32
                     then
                        while Pos < Text'Length and then
                          Byte_Value (Pos) in 9 | 10 | 13 | 32
                        loop
                           Point := Byte_Value (Pos);
                           Pos := Pos + 1;
                           Scalar := Scalar + 1;
                           UTF16 := UTF16 + 1;
                        end loop;
                     end if;
                  elsif Point in 9 | 10 | 13 | 32 then
                     Kind := Control_Symbol;
                     if Point = 10 then
                        Pos := Pos + 1;
                        Scalar := Scalar + 1;
                        UTF16 := UTF16 + 1;
                     else
                        while Pos < Text'Length and then
                          Byte_Value (Pos) in 9 | 13 | 32
                        loop
                           Pos := Pos + 1;
                           Scalar := Scalar + 1;
                           UTF16 := UTF16 + 1;
                        end loop;
                        if Pos < Text'Length and then
                          Byte_Value (Pos) = 10
                        then
                           Pos := Pos + 1;
                           Scalar := Scalar + 1;
                           UTF16 := UTF16 + 1;
                        end if;
                     end if;
                     while Pos < Text'Length and then
                       Byte_Value (Pos) in 9 | 13 | 32
                     loop
                        Pos := Pos + 1;
                        Scalar := Scalar + 1;
                        UTF16 := UTF16 + 1;
                     end loop;
                     Point := 32;
                  else
                     Kind := Control_Symbol;
                     Pos := Pos + Step;
                     Scalar := Scalar + 1;
                     UTF16 := UTF16 +
                       (if Point > 16#FFFF# then 2 else 1);
                  end if;
                  Add (Kind, Start_B, Start_S, Start_U, Pos, Scalar, UTF16,
                       (if Kind = Control_Symbol then Point else 0));
               end if;
            else
               if Point = 123 then Kind := Left_Group;
               elsif Point = 125 then Kind := Right_Group;
               elsif Point = 35 then Kind := Parameter;
               elsif Point = 94 then Kind := Superscript;
               elsif Point = 95 then Kind := Subscript;
               elsif Point = 38 then Kind := Alignment;
               end if;
               Pos := Pos + Step;
               Scalar := Scalar + 1;
               UTF16 := UTF16 + (if Point > 16#FFFF# then 2 else 1);
               Add (Kind, Start_B, Start_S, Start_U, Pos, Scalar, UTF16,
                    Point);
            end if;
         end;
      end loop;
      if Diagnostic = No_Error and then Math_Source.Is_Valid (Input) then
         declare
            Raw : constant Token_Vectors.Vector := Result.Items;
            Expanded : Token_Vectors.Vector := Token_Vectors.Empty_Vector;
            Consumed : array (1 .. Natural (Raw.Length)) of Boolean :=
              (others => False);
            function Read_Point (Value : String; Offset : in out Natural)
              return Natural is
               First : constant Natural := Character'Pos
                 (Value (Value'First + Offset));
               Width : Natural := 1;
               Point : Natural := First;
            begin
               if First >= 16#F0# then
                  Width := 4;
                  Point := (First mod 8) * 262_144;
               elsif First >= 16#E0# then
                  Width := 3;
                  Point := (First mod 16) * 4_096;
               elsif First >= 16#C0# then
                  Width := 2;
                  Point := (First mod 32) * 64;
               end if;
               for I in 1 .. Width - 1 loop
                  Point := Point +
                    (Character'Pos (Value (Value'First + Offset + I)) mod 64)
                    * (64 ** (Width - I - 1));
               end loop;
               Offset := Offset + Width;
               return Point;
            end Read_Point;
            function UTF8 (Point : Natural) return String is
            begin
               if Point < 16#80# then
                  return String'(1 => Character'Val (Point));
               elsif Point < 16#800# then
                  return Character'Val (16#C0# + Point / 64) &
                    Character'Val (16#80# + Point mod 64);
               elsif Point < 16#10000# then
                  return Character'Val (16#E0# + Point / 4_096) &
                    Character'Val (16#80# + (Point / 64) mod 64) &
                    Character'Val (16#80# + Point mod 64);
               else
                  return Character'Val (16#F0# + Point / 262_144) &
                    Character'Val (16#80# + (Point / 4_096) mod 64) &
                    Character'Val (16#80# + (Point / 64) mod 64) &
                    Character'Val (16#80# + Point mod 64);
               end if;
            end UTF8;
            function Synthetic
              (Kind : Token_Kind; Point : Natural; Lexeme : String;
               From : Token) return Token is
               Value : Token := From;
            begin
               Value.Kind := Kind;
               Value.Code_Point := Point;
               Value.Text_First := From.First_Byte + 1;
               Value.Text_Length := From.After_Byte - From.First_Byte;
               Value.Lexeme := Ada.Strings.Unbounded.To_Unbounded_String
                 (Lexeme);
               return Value;
            end Synthetic;
            procedure Append (Value : Token) is
            begin
               if Expanded.Length >= Max_Tokens - 1 then
                  Diagnostic := Token_Limit;
                  Error_Byte := Value.First_Byte;
               else
                  Expanded.Append (Value);
               end if;
            end Append;
            procedure Apply_Mark (Mark : Natural; Source_Token : Token) is
               Accent : constant String := Math_Unicode.Lookup_Accent
                 (Mark, Math_Unicode.Math_Mode);
               First : Natural := 1;
               Depth : Natural := 0;
            begin
               if Expanded.Is_Empty then
                  Diagnostic := Unicode_Unsupported;
                  Error_Byte := Source_Token.First_Byte;
               elsif Accent'Length = 0 then
                  Diagnostic := Unicode_Unsupported;
                  Error_Byte := Source_Token.First_Byte;
               else
                  First := Natural (Expanded.Length);
                  if Expanded.Last_Element.Kind = Right_Group then
                     for I in reverse Expanded.First_Index ..
                       Expanded.Last_Index - 1
                     loop
                        if Expanded (I).Kind = Right_Group then
                           Depth := Depth + 1;
                        elsif Expanded (I).Kind = Left_Group then
                           if Depth = 0 then
                              First := I;
                              exit;
                           end if;
                           Depth := Depth - 1;
                        end if;
                     end loop;
                  end if;
                  declare
                     Previous : Token_Vectors.Vector :=
                       Token_Vectors.Empty_Vector;
                     Last : constant Positive := Expanded.Last_Index;
                  begin
                     for I in Positive (First) .. Last loop
                        Previous.Append (Expanded (I));
                     end loop;
                     Expanded.Delete_Last
                       (Ada.Containers.Count_Type
                          (Natural (Last) - First + 1));
                     Append (Synthetic (Control_Word, 0, Accent, Source_Token));
                     Append (Synthetic (Left_Group, 123, "{", Source_Token));
                     for Item of Previous loop
                        Append (Item);
                     end loop;
                     Append (Synthetic (Right_Group, 125, "}", Source_Token));
                  end;
               end if;
            end Apply_Mark;
         begin
            for I in 1 .. Natural (Raw.Length) loop
               exit when Diagnostic /= No_Error;
               declare
                  Item : constant Token := Raw (Positive (I));
                  Decomposed : constant String :=
                    Math_Unicode.Lookup_Decomposition (Item.Code_Point);
                  Script : constant String :=
                    Math_Unicode.Lookup_Script (Item.Code_Point);
               begin
                  if Consumed (I) then
                     null;
                  elsif Item.Kind = Character_Token and then
                    Item.Code_Point in 16#300# .. 16#36F#
                  then
                     Apply_Mark (Item.Code_Point, Item);
                  elsif Item.Kind = Character_Token and then
                    Decomposed'Length > 0
                  then
                     declare
                        Offset : Natural := 0;
                        Base_Point : constant Natural :=
                          Read_Point (Decomposed, Offset);
                        Base : constant Token := Synthetic
                          (Character_Token, Base_Point,
                           UTF8 (Base_Point), Item);
                        Marks : Natural := 0;
                     begin
                        Append (Base);
                        while Offset < Decomposed'Length loop
                           Apply_Mark (Read_Point (Decomposed, Offset), Item);
                           Marks := Marks + 1;
                        end loop;
                        for J in 1 .. Marks loop
                           Append (Synthetic
                             (Right_Group, 125, "}", Item));
                        end loop;
                     end;
                  elsif Item.Kind = Character_Token and then
                    Math_Unicode.Is_Subscript_Lead (Item.Code_Point) and then
                    Script'Length > 0
                  then
                     Append (Synthetic (Subscript, 95, "_", Item));
                     Append (Synthetic (Left_Group, 123, "{", Item));
                     for J in Script'Range loop
                        Append (Synthetic (Character_Token,
                          Character'Pos (Script (J)), String'(1 => Script (J)),
                          Item));
                     end loop;
                     declare
                        Last_Byte : Natural := Item.After_Byte;
                        K : Natural := I + 1;
                     begin
                        while K <= Natural (Raw.Length) loop
                           declare
                              Next : constant Token := Raw (Positive (K));
                              Value : constant String :=
                                Math_Unicode.Lookup_Script (Next.Code_Point);
                           begin
                              exit when Next.Kind /= Character_Token or else
                                Next.First_Byte /= Last_Byte or else
                                not Math_Unicode.Is_Subscript_Lead
                                  (Next.Code_Point) or else Value'Length = 0;
                              for J in Value'Range loop
                                 Append (Synthetic (Character_Token,
                                   Character'Pos (Value (J)),
                                   String'(1 => Value (J)), Next));
                              end loop;
                              Consumed (K) := True;
                              Last_Byte := Next.After_Byte;
                              K := K + 1;
                           end;
                        end loop;
                     end;
                     Append (Synthetic (Right_Group, 125, "}", Item));
                  elsif Item.Kind = Character_Token and then Script'Length > 0
                    and then Math_Unicode.Is_Superscript (Item.Code_Point)
                  then
                     Append (Synthetic (Superscript, 94, "^", Item));
                     Append (Synthetic (Left_Group, 123, "{", Item));
                     for J in Script'Range loop
                        Append (Synthetic (Character_Token,
                          Character'Pos (Script (J)), String'(1 => Script (J)),
                          Item));
                     end loop;
                     declare
                        Last_Byte : Natural := Item.After_Byte;
                        K : Natural := I + 1;
                     begin
                        while K <= Natural (Raw.Length) loop
                           declare
                              Next : constant Token := Raw (Positive (K));
                              Value : constant String :=
                                Math_Unicode.Lookup_Script (Next.Code_Point);
                           begin
                              exit when Next.Kind /= Character_Token or else
                                Next.First_Byte /= Last_Byte or else
                                not Math_Unicode.Is_Superscript
                                  (Next.Code_Point) or else Value'Length = 0;
                              for J in Value'Range loop
                                 Append (Synthetic (Character_Token,
                                   Character'Pos (Value (J)),
                                   String'(1 => Value (J)), Next));
                              end loop;
                              Consumed (K) := True;
                              Last_Byte := Next.After_Byte;
                              K := K + 1;
                           end;
                        end loop;
                     end;
                     Append (Synthetic (Right_Group, 125, "}", Item));
                  else
                     Append (Item);
                  end if;
               end;
            end loop;
            if Diagnostic = No_Error then
               Result.Items := Expanded;
               Add (End_Of_Input, Text'Length, Scalar, UTF16,
                    Text'Length, Scalar, UTF16);
            end if;
         end;
      end if;
   end Lex;

   function Count (Item : Stream) return Natural is
     (Natural (Item.Items.Length));
   function Element (Item : Stream; Index : Positive) return Token is
     (Item.Items (Index));
   function Source (Item : Stream) return String is
     (Math_Source.Text (Item.Original));

   procedure From_Tokens
     (Original : Stream; Items : Token_Sequence; Result : out Stream) is
   begin
      if Items'Length >= Max_Tokens then
         raise Constraint_Error with "token stream exceeds maximum";
      end if;
      Result := (Original => Original.Original,
                 Items => Token_Vectors.Empty_Vector);
      for T of Items loop
         Result.Items.Append (T);
      end loop;
      Result.Items.Append (Original.Items.Last_Element);
   end From_Tokens;
end Math_Tokens;
