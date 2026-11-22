with Ada.Strings.Fixed;
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

   function Dimension_Error (Width, Height : Natural; Valid : Boolean)
      return Unbounded_String
   is
      function Decimal (N : Natural) return String is
        (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left));
   begin
      if not Valid then
         return To_Unbounded_String ("Image dimensions are unavailable");
      elsif Width > MAX_SIDE or else Height > MAX_SIDE then
         return To_Unbounded_String
           ("Image " & Decimal (Width) & " x " & Decimal (Height) &
            " exceeds the " & Decimal (MAX_SIDE) & "-pixel side limit.");
      elsif Width > MAX_PIXELS / Height then
         return To_Unbounded_String
           ("Image " & Decimal (Width) & " x " & Decimal (Height) &
            " exceeds the " & Decimal (MAX_PIXELS) & "-pixel area limit.");
      else
         return Null_Unbounded_String;
      end if;
   end Dimension_Error;

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

   procedure Read_Exact
     (Read : not null access function (Buffer : out String)
        return Integer;
      Buffer : out String;
      Complete : out Boolean)
   is
      Offset : Natural := Buffer'First;
   begin
      Complete := True;
      while Offset <= Buffer'Last loop
         declare
            Part : String (Offset .. Buffer'Last);
            Count : constant Integer := Read.all (Part);
         begin
            if Count <= 0 or else Count > Part'Length then
               Complete := False;
               return;
            end if;
            Buffer (Offset .. Offset + Count - 1) :=
              Part (Offset .. Offset + Count - 1);
            Offset := Offset + Natural (Count);
         end;
      end loop;
   end Read_Exact;

   procedure Skip_Bytes
     (Read : not null access function (Buffer : out String)
        return Integer;
      Count : Natural;
      Good : out Boolean)
   is
      Remaining : Natural := Count;
   begin
      Good := True;
      while Remaining > 0 loop
         declare
            Part : String (1 .. Natural'Min (Remaining, 4_096));
            Read_Count : constant Integer := Read.all (Part);
         begin
            if Read_Count <= 0 or else Read_Count > Part'Length then
               Good := False;
               return;
            end if;
            Remaining := Remaining - Natural (Read_Count);
         end;
      end loop;
   end Skip_Bytes;

   procedure Stream_Header
     (Read : not null access function (Buffer : out String)
        return Integer;
      Kind : out Format;
      Width, Height : out Natural;
      Valid : out Boolean)
   is
      Prefix : String (1 .. 24) := (others => Character'Val (0));
      Complete : Boolean;
   begin
      Kind := Unknown;
      Width := 0;
      Height := 0;
      Valid := False;
      Read_Exact (Read, Prefix (1 .. 2), Complete);
      if not Complete then
         return;
      elsif Prefix (1 .. 2) = PNG_Signature (1 .. 2) then
         Read_Exact (Read, Prefix (3 .. 8), Complete);
         if not Complete or else Prefix (1 .. 8) /= PNG_Signature then
            return;
         end if;
         Kind := PNG;
         Read_Exact (Read, Prefix (9 .. 24), Complete);
         if Complete and then Big_Endian_32 (Prefix, 9) = 13
           and then Prefix (13 .. 16) = "IHDR"
         then
            Width := Big_Endian_32 (Prefix, 17);
            Height := Big_Endian_32 (Prefix, 21);
            Valid := Width > 0 and then Height > 0;
         end if;
      elsif Prefix (1) = Character'Val (16#FF#)
        and then Prefix (2) = Character'Val (16#D8#)
      then
         Kind := JPEG;
         declare
            Marker_Byte : String (1 .. 1);
            Length_Bytes : String (1 .. 2);
            Step_Complete : Boolean;
         begin
            loop
               Read_Exact (Read, Marker_Byte, Step_Complete);
               exit when not Step_Complete or else Marker_Byte (1) /=
                 Character'Val (16#FF#);
               loop
                  Read_Exact (Read, Marker_Byte, Step_Complete);
                  exit when not Step_Complete or else Marker_Byte (1) /=
                    Character'Val (16#FF#);
               end loop;
               exit when not Step_Complete;
               declare
                  Marker : constant Natural :=
                    Character'Pos (Marker_Byte (1));
               begin
                  if Marker = 16#D9# or else Marker = 16#DA# then
                     exit;
                  elsif Marker = 16#D8# or else Marker = 1
                    or else Marker in 16#D0# .. 16#D7#
                  then
                     null;
                  else
                     Read_Exact (Read, Length_Bytes, Step_Complete);
                     exit when not Step_Complete;
                     declare
                        Segment_Length : constant Natural :=
                          Character'Pos (Length_Bytes (1)) * 256
                          + Character'Pos (Length_Bytes (2));
                        Skipped : Boolean;
                     begin
                        exit when Segment_Length < 2;
                        if Marker in 16#C0# .. 16#C3#
                          or else Marker in 16#C5# .. 16#C7#
                          or else Marker in 16#C9# .. 16#CB#
                          or else Marker in 16#CD# .. 16#CF#
                        then
                           declare
                              Frame : String (1 .. 5);
                           begin
                              exit when Segment_Length < 7;
                              Read_Exact (Read, Frame, Step_Complete);
                              exit when not Step_Complete;
                              Height := Character'Pos (Frame (2)) * 256
                                + Character'Pos (Frame (3));
                              Width := Character'Pos (Frame (4)) * 256
                                + Character'Pos (Frame (5));
                              Skip_Bytes
                                (Read, Segment_Length - 7, Skipped);
                              Valid := Skipped and then Width > 0
                                and then Height > 0;
                              exit;
                           end;
                        else
                           Skip_Bytes
                             (Read, Segment_Length - 2, Skipped);
                           exit when not Skipped;
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end;
      end if;
   exception
      when others =>
         Valid := False;
   end Stream_Header;

   procedure Decode_Stream
     (Read : not null access function (Buffer : out String)
        return Integer;
      Rewind : not null access function return Boolean;
      Pixels : out Coyote_Image_Decoder.Pixbuf_Handle;
      Width : out Natural;
      Height : out Natural;
      Error : out Unbounded_String)
   is
      Kind : Format := Unknown;
      Header_Width : Natural := 0;
      Header_Height : Natural := 0;
      Header_Valid : Boolean := False;
      Loader : Coyote_Image_Decoder.Loader_Handle :=
        Coyote_Image_Decoder.Null_Loader;
      State : aliased Coyote_Image_Decoder.Decode_State;
      Closed : Boolean := False;
      Buffer : String (1 .. 4_096);
   begin
      Pixels := Coyote_Image_Decoder.Null_Pixbuf;
      Width := 0;
      Height := 0;
      Error := Null_Unbounded_String;
      Stream_Header
        (Read, Kind, Header_Width, Header_Height, Header_Valid);
      if Kind = Unknown then
         Error := To_Unbounded_String ("Unsupported image signature");
      else
         Error := Dimension_Error (Header_Width, Header_Height, Header_Valid);
      end if;
      if Length (Error) /= 0 then
         return;
      elsif not Rewind.all then
         Error := To_Unbounded_String ("Image stream could not be rewound");
      else
         Loader := Coyote_Image_Decoder.New_Loader
           ((if Kind = PNG then "png" else "jpeg"));
         if Coyote_Image_Decoder.Is_Null (Loader) then
            Error := To_Unbounded_String
              ("Image decoder could not be created");
         else
            State.Expected_Width := Header_Width;
            State.Expected_Height := Header_Height;
            Coyote_Image_Decoder.Connect_Size_Prepared
              (Loader, Confirm_Size'Access, State'Unchecked_Access);
            loop
               declare
                  Count : constant Integer := Read (Buffer);
               begin
                  if Count = 0 then
                     exit;
                  elsif Count < 0 or else Count > Buffer'Length then
                     Error := To_Unbounded_String
                       ("Image stream read failed");
                     exit;
                  elsif Coyote_Image_Decoder.Write
                    (Loader, Buffer (1 .. Count))'Length > 0
                  then
                     Error := To_Unbounded_String
                       ("Image data is invalid or corrupt");
                     exit;
                  elsif State.Invalid then
                     Error := To_Unbounded_String
                       ("Image dimensions mismatch");
                     exit;
                  end if;
               end;
            end loop;
            if Length (Error) = 0 then
               if Coyote_Image_Decoder.Close (Loader)'Length > 0 then
                  Error := To_Unbounded_String
                    ("Image data is invalid or corrupt");
               end if;
               Closed := True;
            end if;
            if Length (Error) = 0 then
               declare
                  Name : constant String := Coyote_Image_Decoder.Format_Name
                    (Coyote_Image_Decoder.Get_Format (Loader));
               begin
                  if (Kind = PNG and then Name /= "png")
                    or else (Kind = JPEG and then Name /= "jpeg")
                  then
                     Error := To_Unbounded_String
                       ("Decoded image format mismatch");
                  end if;
               end;
            end if;
            if Length (Error) = 0 then
               Pixels := Coyote_Image_Decoder.Get_Raw_Pixbuf (Loader);
               if Coyote_Image_Decoder.Is_Null (Pixels) then
                  Error := To_Unbounded_String
                    ("Image decoder produced no image");
               else
                  Width := Natural (Raw_Width (Pixels));
                  Height := Natural (Raw_Height (Pixels));
                  if Width /= Header_Width or else Height /= Header_Height then
                     Error := To_Unbounded_String
                       ("Decoded image dimensions mismatch");
                  end if;
               end if;
            end if;
         end if;
      end if;
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
   end Decode_Stream;

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
      Error := Dimension_Error (Header_Width, Header_Height, Header_Valid);
      if Length (Error) /= 0 then
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
