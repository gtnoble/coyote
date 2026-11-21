package body Coyote_Canvas.Images is

   use Ada.Streams;

   BYTES_PER_PIXEL : constant := 4;

   function Row_Bytes (Width : Positive) return Positive is
   begin
      if Width > Natural'Last / BYTES_PER_PIXEL then
         raise Invalid_Buffer with "RGBA row size overflows";
      end if;
      return Width * BYTES_PER_PIXEL;
   end Row_Bytes;

   function Packed_Byte_Count (Width, Height : Positive) return Positive is
      Row_Size : constant Positive := Row_Bytes (Width);
   begin
      if Height > Natural'Last / Row_Size then
         raise Invalid_Buffer with "packed RGBA size overflows";
      end if;
      return Row_Size * Height;
   end Packed_Byte_Count;

   procedure Copy_RGBA
     (Source                    : Stream_Element_Array;
      Image_Width, Image_Height : Positive;
      Source_Stride             : Positive;
      Region                    : Document.Rectangle;
      Destination               : out Stream_Element_Array)
   is
      Row_Size : constant Positive := Row_Bytes (Image_Width);
   begin
      if not Document.Is_Within
        (Region, Document.Full_Extent (Image_Width, Image_Height))
      then
         raise Invalid_Buffer with "RGBA crop is empty or outside the image";
      end if;
      if Source_Stride < Row_Size
        or else Image_Height - 1 > (Natural'Last - Row_Size) / Source_Stride
      then
         raise Invalid_Buffer with "invalid RGBA source stride or extent";
      end if;
      if Source'Length < (Image_Height - 1) * Source_Stride + Row_Size then
         raise Invalid_Buffer with "RGBA source buffer is truncated";
      end if;

      Crop : declare
         Width  : constant Positive := Region.Right - Region.Left;
         Height : constant Positive := Region.Bottom - Region.Top;
         Run    : constant Positive := Row_Bytes (Width);
      begin
         if Destination'Length /= Packed_Byte_Count (Width, Height) then
            raise Invalid_Buffer with "incorrect RGBA destination size";
         end if;

         for Row in 0 .. Height - 1 loop
            Offsets : declare
               Start : constant Stream_Element_Offset :=
                 Source'First + Stream_Element_Offset
                   ((Region.Top + Row) * Source_Stride
                    + Region.Left * BYTES_PER_PIXEL);
               Into : constant Stream_Element_Offset :=
                 Destination'First + Stream_Element_Offset (Row * Run);
               Last_Offset : constant Stream_Element_Offset :=
                 Stream_Element_Offset (Run - 1);
            begin
               Destination (Into .. Into + Last_Offset) :=
                 Source (Start .. Start + Last_Offset);
            end Offsets;
         end loop;
      end Crop;
   end Copy_RGBA;

end Coyote_Canvas.Images;
