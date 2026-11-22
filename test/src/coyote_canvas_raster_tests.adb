with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;
with Ada.Streams;
with Ada.Unchecked_Deallocation;
with Ada.Streams.Stream_IO;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Canvas.Rasters;
with Coyote_Image_Decoder;
with Coyote_Temp_Files;
with GNAT.OS_Lib;
with Glib;
with Interfaces;
with Glib.Error;
with Glib.Object;
with Gdk.Pixbuf;

package body Coyote_Canvas_Raster_Tests is
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Glib.Error.GError;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Coyote_Canvas.Rasters.Format;
   use type Interfaces.Unsigned_32;

   type Pixel_Byte is mod 2 ** 8;
   type Pixel_Array is array (Natural range 0 .. 3) of aliased Pixel_Byte;
   pragma Convention (C, Pixel_Array);
   type Pixel_Array_Access is access all Pixel_Array;
   pragma Convention (C, Pixel_Array_Access);

   function Raw_Pixels (Pixbuf : Coyote_Image_Decoder.Pixbuf_Handle)
      return Pixel_Array_Access
     with Import, Convention => C,
       External_Name => "gdk_pixbuf_get_pixels";

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Save_Image
     (Path   : String;
      Format : Gdk.Pixbuf.File_Format;
      Width  : Positive;
      Height : Positive;
      Alpha  : Boolean := True)
   is
      Pixbuf : constant Gdk.Pixbuf.Gdk_Pixbuf :=
        Gdk.Pixbuf.Gdk_New
          (Has_Alpha => Alpha,
           Width     => Glib.Gint (Width),
           Height    => Glib.Gint (Height));
      Error : Glib.Error.GError;
   begin
      Gdk.Pixbuf.Fill (Pixbuf, 16#7B_31_22_00#);
      Gdk.Pixbuf.Save (Pixbuf, Path, Format, Error);
      Assert (Error = null, "fixture image is encoded");
      if Error /= null then
         Glib.Error.Error_Free (Error);
      end if;
      Glib.Object.Unref (Glib.Object.GObject (Pixbuf));
   end Save_Image;

   Stream_File : Ada.Streams.Stream_IO.File_Type;
   Stream_Open : Boolean := False;
   Stream_Chunk_Limit : Positive := Positive'Last;
   Cancel_After_Rewind : Boolean := False;
   Stream_Rewound : Boolean := False;

   function Stream_Read (Buffer : out String) return Integer is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      Bytes : Stream_Element_Array
        (1 .. Stream_Element_Offset
           (Natural'Min (Buffer'Length, Stream_Chunk_Limit)));
      Last : Stream_Element_Offset;
   begin
      if Cancel_After_Rewind and then Stream_Rewound then
         return -1;
      end if;
      Read (Stream_File, Bytes, Last);
      if Last = 0 then
         return 0;
      end if;
      for Index in 1 .. Natural (Last) loop
         Buffer (Buffer'First + Index - 1) :=
           Character'Val (Bytes (Stream_Element_Offset (Index)));
      end loop;
      return Natural (Last);
   end Stream_Read;

   function Stream_Rewind return Boolean is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
   begin
      Set_Index (Stream_File, 1);
      Stream_Rewound := True;
      return True;
   exception
      when others =>
         return False;
   end Stream_Rewind;

   procedure Check_Stream
     (Good           : Boolean;
      Want_W, Want_H : Natural;
      Expected_Error : String := "")
   is
      Pixels : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
      Width : Natural;
      Height : Natural;
      Error : Unbounded_String;
   begin
      Stream_Rewound := False;
      Coyote_Canvas.Rasters.Decode_Stream
        (Stream_Read'Access, Stream_Rewind'Access,
         Pixels, Width, Height, Error);
      Assert ((Length (Error) = 0) = Good,
              "stream decode status: " & To_String (Error));
      if Good then
         Assert (Width = Want_W and then Height = Want_H,
           "stream preserves native dimensions");
         Assert (not Coyote_Image_Decoder.Is_Null (Pixels),
           "stream returns pixbuf");
         Coyote_Image_Decoder.Release (Pixels);
      else
         Assert (Coyote_Image_Decoder.Is_Null (Pixels),
           "stream failure returns no pixbuf");
         Assert (Width = 0 and then Height = 0,
           "stream failure clears dimensions");
         if Expected_Error'Length > 0 then
            Assert
              (To_String (Error) = Expected_Error,
               "stream reports exact geometry diagnostic");
         end if;
      end if;
   end Check_Stream;

   function Read_Bytes (Path : String) return String is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      File : File_Type;
   begin
      Open (File, In_File, Path);
      declare
         Length : constant Stream_Element_Offset := Stream_Element_Offset (Size (File));
         Bytes  : Stream_Element_Array (1 .. Length);
         Last  : Stream_Element_Offset;
         Result : String (1 .. Natural (Length));
      begin
         Read (File, Bytes, Last);
         Assert (Last = Length, "Read the complete fixture");
         Close (File);
         for Index in Result'Range loop
            Result (Index) := Character'Val (Bytes (Stream_Element_Offset (Index)));
         end loop;
         return Result;
      end;
   end Read_Bytes;

   procedure Check_Decode
     (Data           : String;
      Expected       : Coyote_Canvas.Rasters.Format;
      Good           : Boolean;
      Want_W         : Natural := 0;
      Want_H         : Natural := 0;
      Expected_Error : String := "")
   is
      Pixels : Coyote_Image_Decoder.Pixbuf_Handle :=
        Coyote_Image_Decoder.Null_Pixbuf;
      Width  : Natural;
      Height : Natural;
      Error  : Unbounded_String;
   begin
      Coyote_Canvas.Rasters.Decode
        (Data, Expected, Pixels, Width, Height, Error);
      Assert ((Length (Error) = 0) = Good, "decode status matches expectation");
      if Good then
         Assert (not Coyote_Image_Decoder.Is_Null (Pixels), "raw pixbuf returned");
         Assert (Width = Want_W and then Height = Want_H, "native dimensions retained");
         Coyote_Image_Decoder.Release (Pixels);
      else
         Assert (Coyote_Image_Decoder.Is_Null (Pixels), "failure returns no pixbuf");
         Assert (Width = 0 and then Height = 0, "failure clears dimensions");
         Assert (Length (Error) <= 80, "error text is bounded");
         if Expected_Error'Length > 0 then
            Assert
              (To_String (Error) = Expected_Error,
               "decode reports exact geometry diagnostic");
         end if;
      end if;
   end Check_Decode;

   function CRC_Update
     (Value : Interfaces.Unsigned_32;
      Data : String) return Interfaces.Unsigned_32
   is
      Result : Interfaces.Unsigned_32 := Value;
   begin
      for Item of Data loop
         Result := Result xor
           Interfaces.Unsigned_32 (Character'Pos (Item));
         for Bit in 1 .. 8 loop
            if (Result and 1) /= 0 then
               Result := Interfaces.Shift_Right (Result, 1)
                 xor 16#EDB8_8320#;
            else
               Result := Interfaces.Shift_Right (Result, 1);
            end if;
         end loop;
      end loop;
      return Result;
   end CRC_Update;

   function Big_Endian (Value : Interfaces.Unsigned_32) return String is
      Result : String (1 .. 4);
   begin
      for Index in Result'Range loop
         Result (Index) := Character'Val
           (Natural
              (Interfaces.Shift_Right (Value, 8 * (4 - Index)) and 16#FF#));
      end loop;
      return Result;
   end Big_Endian;

   function PNG_Header (Width, Height : Positive) return String is
     (Character'Val (137) & "PNG" & ASCII.CR & ASCII.LF
      & Character'Val (26) & ASCII.LF
      & Character'Val (0) & Character'Val (0) & Character'Val (0)
      & Character'Val (13) & "IHDR"
      & Big_Endian (Interfaces.Unsigned_32 (Width))
      & Big_Endian (Interfaces.Unsigned_32 (Height)));

   procedure Make_Large_PNG (Path : String; Source : String) is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      Output : File_Type;
      Chunk_Size : constant Positive :=
        Coyote_Canvas.Rasters.MAX_ENCODED_BYTES + 1;
      Block : constant String (1 .. 4_096) := (others => 'x');
      CRC : Interfaces.Unsigned_32 :=
        CRC_Update (16#FFFF_FFFF#, "tEXt");
      Remaining : Natural := Chunk_Size;
      procedure Write_Text (Text : String) is
         Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
      begin
         for Index in Text'Range loop
            Bytes (Stream_Element_Offset (Index - Text'First + 1)) :=
              Stream_Element (Character'Pos (Text (Index)));
         end loop;
         Write (Output, Bytes);
      end Write_Text;
   begin
      Create (Output, Out_File, Path);
      Write_Text (Source (1 .. 33));
      Write_Text (Big_Endian (Interfaces.Unsigned_32 (Chunk_Size)));
      Write_Text ("tEXt");
      Write_Text ("k" & Character'Val (0));
      CRC := CRC_Update (CRC, "k" & Character'Val (0));
      Remaining := Chunk_Size - 2;
      while Remaining > 0 loop
         declare
            Count : constant Natural := Natural'Min (Remaining, Block'Length);
            Part : constant String := Block (1 .. Count);
         begin
            Write_Text (Part);
            CRC := CRC_Update (CRC, Part);
            Remaining := Remaining - Count;
         end;
      end loop;
      Write_Text (Big_Endian (not CRC));
      Write_Text (Source (34 .. Source'Last));
      Close (Output);
   end Make_Large_PNG;

   procedure Images (T : in out Test) is
      pragma Unreferenced (T);
      FD   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Path : Unbounded_String;
      PNG_Data : Unbounded_String;
      JPEG_Data : Unbounded_String;
   begin
      Coyote_Temp_Files.Create (FD, Path);
      Assert (FD /= GNAT.OS_Lib.Invalid_FD, "temporary file is created");
      GNAT.OS_Lib.Close (FD);
      Ada.Directories.Delete_File (To_String (Path));
      Save_Image (To_String (Path), Gdk.Pixbuf.PNG, 700, 40);
      PNG_Data := To_Unbounded_String (Read_Bytes (To_String (Path)));
      Assert
        (Coyote_Canvas.Rasters.Detect (To_String (PNG_Data)) =
           Coyote_Canvas.Rasters.PNG,
         "PNG signature detected");
      Check_Decode (To_String (PNG_Data), Coyote_Canvas.Rasters.Unknown,
                    True, 700, 40);
      Check_Decode (To_String (PNG_Data), Coyote_Canvas.Rasters.PNG,
                    True, 700, 40);
      declare
         Pixels : Coyote_Image_Decoder.Pixbuf_Handle :=
           Coyote_Image_Decoder.Null_Pixbuf;
         Width  : Natural;
         Height : Natural;
         Error  : Unbounded_String;
         Raw    : Pixel_Array_Access;
      begin
         Coyote_Canvas.Rasters.Decode
           (To_String (PNG_Data), Coyote_Canvas.Rasters.PNG,
            Pixels, Width, Height, Error);
         Assert (Length (Error) = 0, "transparent PNG decodes");
         Assert (Width = 700 and then Height = 40, "PNG dimensions retained");
         Raw := Raw_Pixels (Pixels);
         Assert
           (Raw (0) = 16#7B# and then Raw (1) = 16#31#
              and then Raw (2) = 16#22# and then Raw (3) = 0,
            "hidden RGB and transparent alpha are preserved");
         Coyote_Image_Decoder.Release (Pixels);
      end;
      Check_Decode (To_String (PNG_Data), Coyote_Canvas.Rasters.JPEG, False);

      Save_Image (To_String (Path), Gdk.Pixbuf.JPEG, 64, 48, False);
      JPEG_Data := To_Unbounded_String (Read_Bytes (To_String (Path)));
      Assert
        (Coyote_Canvas.Rasters.Detect (To_String (JPEG_Data)) =
           Coyote_Canvas.Rasters.JPEG,
         "JPEG signature detected");
      Check_Decode (To_String (JPEG_Data), Coyote_Canvas.Rasters.Unknown,
                    True, 64, 48);

      --  RGB keeps the real-size fixture's decoded storage smaller.
      Save_Image (To_String (Path), Gdk.Pixbuf.PNG, 7_680, 4_320, False);
      Ada.Streams.Stream_IO.Open
        (Stream_File, Ada.Streams.Stream_IO.In_File, To_String (Path));
      Stream_Open := True;
      Check_Stream (True, 7_680, 4_320);
      Ada.Streams.Stream_IO.Close (Stream_File);
      Stream_Open := False;
      declare
         Large_Data : constant String := Read_Bytes (To_String (Path));
      begin
         Check_Decode
           (Large_Data, Coyote_Canvas.Rasters.PNG, True, 7_680, 4_320);
      end;
      Coyote_Temp_Files.Delete (To_String (Path));
   exception
      when others =>
         if Stream_Open then
            Ada.Streams.Stream_IO.Close (Stream_File);
            Stream_Open := False;
         end if;
         Coyote_Temp_Files.Delete (To_String (Path));
         raise;
   end Images;

   procedure Streaming (T : in out Test) is
      pragma Unreferenced (T);
      use type Ada.Streams.Stream_IO.Count;
      FD : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Path : Unbounded_String;
      PNG_Data : Unbounded_String;
      Malformed : Unbounded_String;
   begin
      Coyote_Temp_Files.Create (FD, Path);
      Assert (FD /= GNAT.OS_Lib.Invalid_FD, "stream file created");
      GNAT.OS_Lib.Close (FD);
      Ada.Directories.Delete_File (To_String (Path));
      Save_Image (To_String (Path), Gdk.Pixbuf.PNG, 19, 13);
      PNG_Data := To_Unbounded_String (Read_Bytes (To_String (Path)));
      Make_Large_PNG (To_String (Path), To_String (PNG_Data));
      Ada.Streams.Stream_IO.Open
        (Stream_File, Ada.Streams.Stream_IO.In_File, To_String (Path));
      Stream_Open := True;
      Assert
        (Ada.Streams.Stream_IO.Size (Stream_File) >
           Coyote_Canvas.Rasters.MAX_ENCODED_BYTES,
         "fixture exceeds historical encoded-byte cap");
      Check_Stream (True, 19, 13);
      Assert (Stream_Rewind, "rewind fixture after decoding");
      Cancel_After_Rewind := True;
      Check_Stream (False, 0, 0);
      Cancel_After_Rewind := False;
      Ada.Streams.Stream_IO.Close (Stream_File);
      Stream_Open := False;

      Malformed := To_Unbounded_String
        (To_String (PNG_Data) (1 .. Natural'Min (40, Length (PNG_Data))));
      declare
         File : Ada.Streams.Stream_IO.File_Type;
         Bytes : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (Length (Malformed)));
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, To_String (Path));
         for Index in 1 .. Length (Malformed) loop
            Bytes (Ada.Streams.Stream_Element_Offset (Index)) :=
              Ada.Streams.Stream_Element
                (Character'Pos (Element (Malformed, Index)));
         end loop;
         Ada.Streams.Stream_IO.Write (File, Bytes);
         Ada.Streams.Stream_IO.Close (File);
      end;
      Ada.Streams.Stream_IO.Open
        (Stream_File, Ada.Streams.Stream_IO.In_File, To_String (Path));
      Stream_Open := True;
      Check_Stream (False, 0, 0);
      Ada.Streams.Stream_IO.Close (Stream_File);
      Stream_Open := False;

      for Geometry in 1 .. 2 loop
         declare
            Fixture : constant String :=
              (if Geometry = 1 then PNG_Header (8_193, 1)
               else PNG_Header (8_192, 4_097));
            Expected_Error : constant String :=
              (if Geometry = 1
               then "Image 8193 x 1 exceeds the 8192-pixel side limit."
               else "Image 8192 x 4097 exceeds the 33554432-pixel area limit.");
            File : Ada.Streams.Stream_IO.File_Type;
            Bytes : Ada.Streams.Stream_Element_Array (1 .. 24);
         begin
            Ada.Streams.Stream_IO.Create
              (File, Ada.Streams.Stream_IO.Out_File, To_String (Path));
            for Index in Fixture'Range loop
               Bytes (Ada.Streams.Stream_Element_Offset (Index)) :=
                 Ada.Streams.Stream_Element
                   (Character'Pos (Fixture (Index)));
            end loop;
            Ada.Streams.Stream_IO.Write (File, Bytes);
            Ada.Streams.Stream_IO.Close (File);
            Ada.Streams.Stream_IO.Open
              (Stream_File, Ada.Streams.Stream_IO.In_File, To_String (Path));
            Stream_Open := True;
            Check_Stream (False, 0, 0, Expected_Error);
            Ada.Streams.Stream_IO.Close (Stream_File);
            Stream_Open := False;
         end;
      end loop;
      Save_Image (To_String (Path), Gdk.Pixbuf.JPEG, 64, 48, False);
      Ada.Streams.Stream_IO.Open
        (Stream_File, Ada.Streams.Stream_IO.In_File, To_String (Path));
      Stream_Open := True;
      Stream_Chunk_Limit := 1;
      Check_Stream (True, 64, 48);
      Stream_Chunk_Limit := Positive'Last;
      Ada.Streams.Stream_IO.Close (Stream_File);
      Stream_Open := False;
      Coyote_Temp_Files.Delete (To_String (Path));
   exception
      when others =>
         Cancel_After_Rewind := False;
         Stream_Chunk_Limit := Positive'Last;
         if Stream_Open then
            Ada.Streams.Stream_IO.Close (Stream_File);
            Stream_Open := False;
         end if;
         Coyote_Temp_Files.Delete (To_String (Path));
         raise;
   end Streaming;

   procedure Rejects (T : in out Test) is
      pragma Unreferenced (T);
      Invalid : constant String := "not an image";
      type String_Access is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);
      Huge : String_Access;
   begin
      Check_Decode (Invalid, Coyote_Canvas.Rasters.Unknown, False);
      Check_Decode (Invalid, Coyote_Canvas.Rasters.PNG, False);
      Huge := new String (1 .. Coyote_Canvas.Rasters.MAX_ENCODED_BYTES + 1);
      Huge.all := (others => 'x');
      Check_Decode (Huge.all, Coyote_Canvas.Rasters.Unknown, False);
      Free (Huge);
      Check_Decode
        (PNG_Header (8_193, 1), Coyote_Canvas.Rasters.Unknown, False,
         Expected_Error =>
           "Image 8193 x 1 exceeds the 8192-pixel side limit.");
      Check_Decode
        (PNG_Header (8_192, 4_097), Coyote_Canvas.Rasters.Unknown, False,
         Expected_Error =>
           "Image 8192 x 4097 exceeds the 33554432-pixel area limit.");
   end Rejects;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas full-resolution PNG and JPEG decode", Images'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas streaming decode without encoded cap", Streaming'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas raster format and size rejection", Rejects'Access));
      return Result;
   end Suite;
end Coyote_Canvas_Raster_Tests;
