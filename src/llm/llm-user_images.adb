with Ada.Containers;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Aux;
with Coyote_Canvas.Rasters;
with Coyote_Image_Decoder;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body LLM.User_Images is
   use GNATCOLL.JSON;
   use Interfaces.C;
   use Interfaces.C.Strings;
   use type System.Address;
   use type Types.Content_Block_Kind;
   use type Types.Role;
   use type Ada.Containers.Count_Type;

   function Encode (Bytes : System.Address; Size : size_t) return chars_ptr
     with Import, Convention => C, External_Name => "g_base64_encode";
   function Decode (Text : char_array; Size : out size_t) return System.Address
     with Import, Convention => C, External_Name => "g_base64_decode";
   procedure Release (Ptr : System.Address)
     with Import, Convention => C, External_Name => "g_free";
   procedure Release (Ptr : chars_ptr)
     with Import, Convention => C, External_Name => "g_free";

   function UUID (S : String) return Boolean is
   begin
      if S'Length /= 36 then
         return False;
      end if;
      for I in 1 .. 36 loop
         if (if I in 9 | 14 | 19 | 24 then S (S'First + I - 1) /= '-'
             else S (S'First + I - 1) not in '0' .. '9' | 'a' .. 'f') then
            return False;
         end if;
      end loop;
      return True;
   end UUID;

   function Fits_Geometry (Width, Height : Natural) return Boolean is
     (Width in 1 .. Max_Side and then Height in 1 .. Max_Side
      and then Width <= Max_Pixels / Height);

   procedure Check (Image : Types.User_Image) is
      Bytes : Ada.Strings.Unbounded.Aux.Big_String_Access;
      Size : Natural;
      use type Coyote_Canvas.Rasters.Format;
      function Number (At_Byte : Positive) return Long_Long_Integer is
         N : Long_Long_Integer := 0;
      begin
         for I in At_Byte .. At_Byte + 3 loop
            N := N * 256 + Character'Pos (Bytes (I));
         end loop;
         return N;
      end Number;
   begin
      Ada.Strings.Unbounded.Aux.Get_String (Image.PNG, Bytes, Size);
      if Size not in 33 .. Max_PNG
        or else not Fits_Geometry (Image.Width, Image.Height)
        or else not UUID (To_String (Image.Drawing_Id))
        or else not UUID (To_String (Image.Revision_Id))
        or else Length (Image.Label) not in 1 .. 128
        or else Coyote_Canvas.Rasters.Detect (Bytes (1 .. 8)) /=
          Coyote_Canvas.Rasters.PNG
        or else Number (9) /= 13 or else Bytes (13 .. 16) /= "IHDR"
        or else Number (17) /= Long_Long_Integer (Image.Width)
        or else Number (21) /= Long_Long_Integer (Image.Height)
      then
         raise Invalid_Image with "Invalid Canvas PNG or revision metadata";
      end if;
      for Ch of To_String (Image.Label) loop
         if Ch not in ' ' .. '~' then
            raise Invalid_Image with "Invalid Canvas image label";
         end if;
      end loop;
   end Check;

   function Byte_Count (Images : Types.User_Images.Vector) return Natural is
      Sum : Natural := 0;
   begin
      for Image of Images loop
         Sum := Sum + Length (Image.PNG);
      end loop;
      return Sum;
   end Byte_Count;

   procedure Check_Turn (Images : Types.User_Images.Vector) is
   begin
      if Images.Length > Max_Count or else Byte_Count (Images) > Max_Turn then
         raise Invalid_Image with "Canvas turn exceeds the image or PNG byte limit";
      end if;
      for Image of Images loop
         Check (Image);
      end loop;
   end Check_Turn;

   function Has_Images (Msg : Types.Message) return Boolean is
     (for some Block of Msg.Content => Block.Kind = Types.User_Image_Block);
   function Has_Images (History : Types.Message_Vectors.Vector) return Boolean is
     (for some Msg of History => Has_Images (Msg));

   procedure Check_History (History : Types.Message_Vectors.Vector) is
      Total : Natural := 0;
   begin
      for Msg of History loop
         declare
            Count, Sum : Natural := 0;
         begin
            for Block of Msg.Content loop
               if Block.Kind = Types.User_Image_Block then
                  if Msg.Role /= Types.User then
                     raise Invalid_Image with "Canvas images require a user message";
                  end if;
                  Check (Block.Image);
                  Count := Count + 1;
                  Sum := Sum + Length (Block.Image.PNG);
                  Total := Total + 4 * ((Length (Block.Image.PNG) + 2) / 3);
                  if Count > Max_Count or else Sum > Max_Turn
                    or else Total > Max_Request
                  then
                     raise Invalid_Image with "Retained Canvas images exceed request limits";
                  end if;
               end if;
            end loop;
         end;
      end loop;
   end Check_History;

   function Ordinal (N : Positive) return String is
     ("Image" & Positive'Image (N));

   function Marker (Image : Types.User_Image; N : Positive) return String is
     ("[" & Ordinal (N) & ": " & To_String (Image.Label) & "," &
      Natural'Image (Image.Width) & " x" & Natural'Image (Image.Height) & "]");

   function Base64 (Image : Types.User_Image) return String is
      Bytes : Ada.Strings.Unbounded.Aux.Big_String_Access;
      Size : Natural;
      Ptr : chars_ptr := Null_Ptr;
   begin
      Check (Image);
      Ada.Strings.Unbounded.Aux.Get_String (Image.PNG, Bytes, Size);
      Ptr := Encode (Bytes (1)'Address, size_t (Size));
      return Result : constant String := Value (Ptr) do
         Release (Ptr);
         Ptr := Null_Ptr;
      end return;
   exception
      when others =>
         Release (Ptr);
         raise;
   end Base64;

   function To_JSON (Image : Types.User_Image) return JSON_Value is
      Value : constant JSON_Value := Create_Object;
   begin
      Value.Set_Field ("type", "image");
      Value.Set_Field ("media_type", "image/png");
      Value.Set_Field ("data", Base64 (Image));
      Value.Set_Field ("drawingId", To_String (Image.Drawing_Id));
      Value.Set_Field ("revisionId", To_String (Image.Revision_Id));
      Value.Set_Field ("label", To_String (Image.Label));
      Value.Set_Field ("width", Integer (Image.Width));
      Value.Set_Field ("height", Integer (Image.Height));
      return Value;
   end To_JSON;

   function From_JSON (Value : JSON_Value) return Types.User_Image is
      Result : Types.User_Image;
      Ptr : System.Address := System.Null_Address;
      Size : size_t;
      Pixels : Coyote_Image_Decoder.Pixbuf_Handle := Coyote_Image_Decoder.Null_Pixbuf;
      W, H : Natural;
      Error : Unbounded_String;
      function Text (Key : String) return String is
        (Get (Value.Get (Key)));
      function Side (Key : String) return Natural is
         N : constant Long_Long_Integer := Get (Value.Get (Key));
      begin
         if N not in 1 .. 8192 then
            raise Invalid_Image;
         end if;
         return Natural (N);
      end Side;
   begin
      if Text ("type") /= "image" or else Text ("media_type") /= "image/png"
      then
         raise Invalid_Image;
      end if;
      Result.Label := To_Unbounded_String (Text ("label"));
      Result.Drawing_Id := To_Unbounded_String (Text ("drawingId"));
      Result.Revision_Id := To_Unbounded_String (Text ("revisionId"));
      Result.Width := Side ("width");
      Result.Height := Side ("height");
      declare
         Data : constant String := Text ("data");
      begin
         if Data'Length not in 4 .. 4 * ((Max_PNG + 2) / 3)
           or else Data'Length mod 4 /= 0
         then
            raise Invalid_Image;
         end if;
         for Ch of Data loop
            if Ch not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '+' | '/' | '=' then
               raise Invalid_Image;
            end if;
         end loop;
         Ptr := Decode (To_C (Data), Size);
         if Ptr = System.Null_Address or else Size > Max_PNG then
            raise Invalid_Image;
         end if;
         declare
            Bytes : String (1 .. Natural (Size)) with Import, Address => Ptr;
         begin
            Result.PNG := To_Unbounded_String (Bytes);
            if Base64 (Result) /= Data then
               raise Invalid_Image;
            end if;
            Coyote_Canvas.Rasters.Decode
              (Bytes, Coyote_Canvas.Rasters.PNG, Pixels, W, H, Error);
         end;
         if Length (Error) /= 0 or else W /= Result.Width or else H /= Result.Height then
            raise Invalid_Image;
         end if;
      end;
      Coyote_Image_Decoder.Release (Pixels);
      Release (Ptr);
      return Result;
   exception
      when others =>
         Coyote_Image_Decoder.Release (Pixels);
         Release (Ptr);
         raise Invalid_Image with "Invalid stored Canvas image";
   end From_JSON;
end LLM.User_Images;
