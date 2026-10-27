with Ada.Strings.Unbounded;

package body Math_Source is
   use Ada.Strings.Unbounded;

   procedure Create
     (Text       : String;
      Item       : out Source;
      Diagnostic : out Diagnostic_Kind;
      Error_Byte : out Natural) is
      Position : Integer := Text'First;
      Scalar   : Natural := 0;
      UTF16    : Natural := 0;
      First_Byte : Natural;
      Lead     : Natural;
      Value    : Natural;
      Need     : Natural;
   begin
      Item := (others => <>);
      Diagnostic := No_Error;
      Error_Byte := 0;
      if Text'Length > Max_Source_Bytes then
         Diagnostic := Source_Too_Large;
         Error_Byte := Max_Source_Bytes + 1;
         return;
      elsif Text'Length = 0 then
         Diagnostic := Empty_Source;
         return;
      end if;
      Item.Value := To_Unbounded_String (Text);
      Item.Byte_Map.Append (0);
      Item.UTF16_Map.Append (0);
      while Position <= Text'Last loop
         First_Byte := Natural (Position - Text'First);
         Lead := Character'Pos (Text (Position));
         if Lead < 16#80# then
            Value := Lead;
            Need := 0;
         elsif Lead in 16#C2# .. 16#DF# then
            Value := Lead mod 32;
            Need := 1;
         elsif Lead in 16#E0# .. 16#EF# then
            Value := Lead mod 16;
            Need := 2;
         elsif Lead in 16#F0# .. 16#F4# then
            Value := Lead mod 8;
            Need := 3;
         else
            Diagnostic := Invalid_UTF8;
            Error_Byte := First_Byte;
            return;
         end if;
         if Position + Integer (Need) > Text'Last then
            Diagnostic := Invalid_UTF8;
            Error_Byte := First_Byte;
            return;
         end if;
         for Offset in 1 .. Need loop
            declare
               Next_Byte : constant Natural :=
                 Character'Pos (Text (Position + Integer (Offset)));
            begin
               if Next_Byte not in 16#80# .. 16#BF# then
                  Diagnostic := Invalid_UTF8;
                  Error_Byte := First_Byte;
                  return;
               end if;
               Value := Value * 64 + Next_Byte mod 64;
            end;
         end loop;
         if (Need = 2 and then Value < 16#800#) or
           (Need = 3 and then Value < 16#10000#) or
           Value in 16#D800# .. 16#DFFF# or Value > 16#10FFFF#
         then
            Diagnostic := Invalid_UTF8;
            Error_Byte := First_Byte;
            return;
         end if;
         if Value = 0 or else
           (Value < 32 and then Value not in 9 | 10 | 13) or else
           Value = 127
         then
            Diagnostic := Forbidden_Control;
            Error_Byte := First_Byte;
            return;
         end if;
         Scalar := Scalar + 1;
         UTF16 := UTF16 + (if Value > 16#FFFF# then 2 else 1);
         Item.Byte_Map.Append (First_Byte + Need + 1);
         Item.UTF16_Map.Append (UTF16);
         Position := Position + Integer (Need) + 1;
      end loop;
      Item.Byte_Count := Text'Length;
      Item.Scalar_Count := Scalar;
      Item.UTF16_Count := UTF16;
      Item.Valid := True;
   end Create;

   function Is_Valid (Item : Source) return Boolean is (Item.Valid);
   function Text (Item : Source) return String is (To_String (Item.Value));
   function Byte_Length (Item : Source) return Natural is (Item.Byte_Count);
   function Scalar_Length (Item : Source) return Natural is (Item.Scalar_Count);
   function UTF16_Length (Item : Source) return Natural is (Item.UTF16_Count);

   function Byte_Offset
     (Item : Source; Scalar_Boundary : Natural) return Natural is
   begin
      if not Item.Valid or Scalar_Boundary > Item.Scalar_Count then
         return 0;
      elsif Scalar_Boundary = 0 then
         return 0;
      else
         return Item.Byte_Map.Element (Positive (Scalar_Boundary + 1));
      end if;
   end Byte_Offset;

   function UTF16_Offset
     (Item : Source; Scalar_Boundary : Natural) return Natural is
   begin
      if not Item.Valid or Scalar_Boundary > Item.Scalar_Count then
         return 0;
      elsif Scalar_Boundary = 0 then
         return 0;
      else
         return Item.UTF16_Map.Element (Positive (Scalar_Boundary + 1));
      end if;
   end UTF16_Offset;

   function Scalar_Boundary
     (Item : Source; Byte_Offset : Natural) return Natural is
   begin
      if not Item.Valid or Byte_Offset > Item.Byte_Count then
         return 0;
      end if;
      for Index in 0 .. Item.Scalar_Count loop
         if Item.Byte_Map.Element (Positive (Index + 1)) = Byte_Offset then
            return Index;
         end if;
      end loop;
      return 0;
   end Scalar_Boundary;
end Math_Source;
