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
with Glib.Error;
with Glib.Object;
with Gdk.Pixbuf;

package body Coyote_Canvas_Raster_Tests is
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Glib.Error.GError;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Coyote_Canvas.Rasters.Format;

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
     (Data     : String;
      Expected : Coyote_Canvas.Rasters.Format;
      Good     : Boolean;
      Want_W   : Natural := 0;
      Want_H   : Natural := 0)
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
      end if;
   end Check_Decode;

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
      Ada.Directories.Delete_File (To_String (Path));
   end Images;

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
      declare
         Too_Wide : constant String :=
           Character'Val (137) & "PNG" & ASCII.CR & ASCII.LF
           & Character'Val (26) & ASCII.LF
           & Character'Val (0) & Character'Val (0) & Character'Val (0)
           & Character'Val (13) & "IHDR"
           & Character'Val (0) & Character'Val (0) & Character'Val (32)
           & Character'Val (1)
           & Character'Val (0) & Character'Val (0) & Character'Val (0)
           & Character'Val (1);
      begin
         Check_Decode (Too_Wide, Coyote_Canvas.Rasters.Unknown, False);
      end;
   end Rejects;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas full-resolution PNG and JPEG decode", Images'Access));
      Result.Add_Test (Caller.Create
        ("Coyote.Canvas raster format and size rejection", Rejects'Access));
      return Result;
   end Suite;
end Coyote_Canvas_Raster_Tests;
