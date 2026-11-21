with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Image_Decoder;
with Interfaces.C;

package body Coyote_Canvas.Rasters is
   use type Interfaces.C.int;

   function Raw_Width (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_width";

   function Raw_Height (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_height";

   PNG_Signature : constant String :=
     Character'Val (137) & "PNG" & ASCII.CR & ASCII.LF
     & Character'Val (26) & ASCII.LF;

   function Byte (Data : String; Offset : Positive) return Natural is
     (Character'Pos (Data (Data'First + Offset - 1)));

   function Big_Endian_32 (Data : String; Offset : Positive)
      return Natural is
      Value : constant Long_Long_Integer :=
        Long_Long_Integer (Byte (Data, Offset)) * 16#100_0000#
        + Long_Long_Integer (Byte (Data, Offset + 1)) * 16#1_0000#
        + Long_Long_Integer (Byte (Data, Offset + 2)) * 16#100#
        + Long_Long_Integer (Byte (Data, Offset + 3));
   begin
      if Value > Long_Long_Integer (Natural'Last) then
         return Natural'Last;
      end if;
      return Natural (Value);
   end Big_Endian_32;

   function Detect (Data : String) return Format is
   begin
      if Data'Length >= PNG_Signature'Length
        and then Data (Data'First .. Data'First + 7) = PNG_Signature
      then
         return PNG;
      elsif Data'Length >= 3
        and then Byte (Data, 1) = 16#FF#
        and then Byte (Data, 2) = 16#D8#
        and then Byte (Data, 3) = 16#FF#
      then
         return JPEG;
      end if;
      return Unknown;
   end Detect;

   procedure PNG_Dimensions
     (Data : String; Width, Height : out Natural; Valid : out Boolean)
   is
   begin
      Width := 0;
      Height := 0;
      Valid := False;
      if Data'Length >= 24 and then Big_Endian_32 (Data, 9) = 13
        and then Data (Data'First + 12 .. Data'First + 15)
        = "IHDR"
      then
         Width := Big_Endian_32 (Data, 17);
         Height := Big_Endian_32 (Data, 21);
         Valid := Width > 0 and then Height > 0;
      end if;
   end PNG_Dimensions;

   procedure JPEG_Dimensions
     (Data : String; Width, Height : out Natural; Valid : out Boolean)
   is
      Position : Positive := 3;
   begin
      Width := 0;
      Height := 0;
      Valid := False;
      while Position < Data'Length loop
         if Byte (Data, Position) /= 16#FF# then
            return;
         end if;
         while Position <= Data'Length
           and then Byte (Data, Position) = 16#FF#
         loop
            Position := Position + 1;
         end loop;
         exit when Position > Data'Length;
         declare
            Marker : constant Natural := Byte (Data, Position);
         begin
            Position := Position + 1;
            if Marker = 16#D9# or else Marker = 16#DA# then
               return;
            elsif Marker = 16#D8# or else Marker = 1
              or else Marker in 16#D0# .. 16#D7#
            then
               null;
            else
               if Position + 1 > Data'Length then
                  return;
               end if;
               declare
                  Segment_Length : constant Natural :=
                    Byte (Data, Position) * 256 + Byte (Data, Position + 1);
               begin
                  if Segment_Length < 2
                    or else Position + Segment_Length - 1 > Data'Length
                  then
                     return;
                  end if;
                  if Marker in 16#C0# .. 16#C3#
                    or else Marker in 16#C5# .. 16#C7#
                    or else Marker in 16#C9# .. 16#CB#
                    or else Marker in 16#CD# .. 16#CF#
                  then
                     if Segment_Length < 7 then
                        return;
                     end if;
                     Height := Byte (Data, Position + 3) * 256
                       + Byte (Data, Position + 4);
                     Width := Byte (Data, Position + 5) * 256
                       + Byte (Data, Position + 6);
                     Valid := Width > 0 and then Height > 0;
                     return;
                  end if;
                  Position := Position + Segment_Length;
               end;
            end if;
         end;
      end loop;
   end JPEG_Dimensions;

   --  The native decoder must agree with preflight before full allocation.
   procedure Confirm_Size
     (Loader : Coyote_Image_Decoder.Loader_Handle;
      Width, Height : Interfaces.C.int;
      State : Coyote_Image_Decoder.State_Access)
     with Convention => C;

   procedure Confirm_Size
     (Loader : Coyote_Image_Decoder.Loader_Handle;
      Width, Height : Interfaces.C.int;
      State : Coyote_Image_Decoder.State_Access) is
   begin
      if Width /= Interfaces.C.int (State.Expected_Width)
        or else Height /= Interfaces.C.int (State.Expected_Height)
      then
         State.Invalid := True;
         Coyote_Image_Decoder.Set_Size (Loader, 1, 1);
      end if;
   end Confirm_Size;

   procedure Decode
     (Data     :     String;
      Expected :     Format;
      Pixels   : out Coyote_Image_Decoder.Pixbuf_Handle;
      Width    : out Natural;
      Height   : out Natural;
      Error    : out Unbounded_String)
   is
      Loader        : Coyote_Image_Decoder.Loader_Handle :=
        Coyote_Image_Decoder.Null_Loader;
      Kind          : constant Format := Detect (Data);
      Header_Width  : Natural := 0;
      Header_Height : Natural := 0;
      Header_Valid  : Boolean := False;
      Closed        : Boolean := False;
      State         : aliased Coyote_Image_Decoder.Decode_State;
   begin
      Pixels := Coyote_Image_Decoder.Null_Pixbuf;
      Width := 0;
      Height := 0;
      Error := Null_Unbounded_String;
      if Data'Length > MAX_ENCODED_BYTES then
         Error := To_Unbounded_String ("Encoded image exceeds the size limit");
         return;
      elsif Kind = Unknown then
         Error := To_Unbounded_String ("Unsupported image signature");
         return;
      elsif Expected /= Unknown and then Expected /= Kind then
         Error :=
           To_Unbounded_String ("Image format does not match expected format");
         return;
      end if;

      if Kind = PNG then
         PNG_Dimensions (Data, Header_Width, Header_Height, Header_Valid);
      else
         JPEG_Dimensions (Data, Header_Width, Header_Height, Header_Valid);
      end if;
      if not Header_Valid then
         Error := To_Unbounded_String ("Image dimensions are unavailable");
         return;
      elsif Header_Width > MAX_SIDE or else Header_Height > MAX_SIDE
        or else Header_Width > MAX_PIXELS / Header_Height
      then
         Error :=
           To_Unbounded_String ("Image dimensions exceed the allowed limit");
         return;
      end if;

      begin
         Loader := Coyote_Image_Decoder.New_Loader
           ((if Kind = PNG then "png" else "jpeg"));
         if Coyote_Image_Decoder.Is_Null (Loader) then
            Error :=
              To_Unbounded_String ("Image decoder could not be created");
         else
            State.Expected_Width := Header_Width;
            State.Expected_Height := Header_Height;
            Coyote_Image_Decoder.Connect_Size_Prepared
              (Loader, Confirm_Size'Access, State'Unchecked_Access);
            declare
               Write_Error : constant String :=
                 Coyote_Image_Decoder.Write (Loader, Data);
            begin
               if State.Invalid then
                  Error := To_Unbounded_String ("Image dimensions mismatch");
               elsif Write_Error'Length > 0 then
                  Error := To_Unbounded_String ("Image data is invalid or corrupt");
               end if;
            end;
            declare
               Close_Error : constant String :=
                 Coyote_Image_Decoder.Close (Loader);
            begin
               Closed := True;
               if State.Invalid then
                  Error := To_Unbounded_String ("Image dimensions mismatch");
               elsif Close_Error'Length > 0 and then Length (Error) = 0 then
                  Error := To_Unbounded_String ("Image data is invalid or corrupt");
               end if;
            end;
            if Length (Error) = 0 then
               declare
                  Name : constant String := Coyote_Image_Decoder.Format_Name
                    (Coyote_Image_Decoder.Get_Format (Loader));
               begin
                  if (Kind = PNG and then Name /= "png")
                    or else (Kind = JPEG and then Name /= "jpeg")
                  then
                     Error := To_Unbounded_String ("Decoded image format mismatch");
                  end if;
               end;
            end if;
            if Length (Error) = 0 then
               Pixels := Coyote_Image_Decoder.Get_Raw_Pixbuf (Loader);
               if Coyote_Image_Decoder.Is_Null (Pixels) then
                  Error := To_Unbounded_String ("Image decoder produced no image");
               else
                  Width := Natural (Raw_Width (Pixels));
                  Height := Natural (Raw_Height (Pixels));
                  if Width /= Header_Width or else Height /= Header_Height then
                     Error := To_Unbounded_String ("Decoded image dimensions mismatch");
                  end if;
               end if;
            end if;
         end if;
      exception
         when others =>
            Error := To_Unbounded_String ("Image decoding failed");
      end;
      if not Closed and then not Coyote_Image_Decoder.Is_Null (Loader) then
         begin
            declare
               Ignored : constant String := Coyote_Image_Decoder.Close (Loader);
               pragma Unreferenced (Ignored);
            begin
               null;
            end;
         exception
            when others =>
               null;
         end;
      end if;
      Coyote_Image_Decoder.Free (Loader);
      if Length (Error) > 0 then
         Coyote_Image_Decoder.Release (Pixels);
         Width := 0;
         Height := 0;
      end if;
   exception
      when others =>
         Coyote_Image_Decoder.Free (Loader);
         Coyote_Image_Decoder.Release (Pixels);
         Width := 0;
         Height := 0;
         Error := To_Unbounded_String ("Image decoding failed");
   end Decode;
end Coyote_Canvas.Rasters;
