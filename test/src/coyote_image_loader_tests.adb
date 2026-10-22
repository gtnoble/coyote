with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_Image_Loader;
with Coyote_Temp_Files;
with Coyote_App.Utils;
with GNAT.OS_Lib;
with Interfaces.C;
with Interfaces.C.Strings;
with System;
with Glib.Error;
with Glib;
with Glib.Object;
with Gdk.Pixbuf;

package body Coyote_Image_Loader_Tests is

   use AUnit.Assertions;
   use type Gdk.Pixbuf.Gdk_Pixbuf;
   use type Glib.Error.GError;
   use type GNAT.OS_Lib.File_Descriptor;
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Glib.Gint;

   function C_Symlink
     (Target : Interfaces.C.Strings.chars_ptr;
      Link   : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.int with
     Import, Convention => C, External_Name => "symlink";

   function C_Mkfifo
     (Path : Interfaces.C.Strings.chars_ptr;
      Mode : Interfaces.C.unsigned)
      return Interfaces.C.int with
     Import, Convention => C, External_Name => "mkfifo";

   function C_Open
     (Path  : Interfaces.C.Strings.chars_ptr;
      Flags : Interfaces.C.int;
      Mode  : Interfaces.C.unsigned)
      return Interfaces.C.int with
     Import, Convention => C, External_Name => "open";

   function C_Write
     (FD    : Interfaces.C.int;
      Data  : System.Address;
      Count : Interfaces.C.size_t)
      return Interfaces.C.long with
     Import, Convention => C, External_Name => "write";

   function C_Close (FD : Interfaces.C.int) return Interfaces.C.int with
     Import, Convention => C, External_Name => "close";

   function C_FD_Count return Natural is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Count     : Natural := 0;
   begin
      Ada.Directories.Start_Search
        (Search,
         "/proc/self/fd",
         "*",
         (Ada.Directories.Ordinary_File => True,
          Ada.Directories.Special_File  => True,
          Ada.Directories.Directory     => False));
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         Count := Count + 1;
      end loop;
      Ada.Directories.End_Search (Search);
      return Count;
   exception
      when others =>
         return 0;
   end C_FD_Count;

   procedure Write_Bytes (Path : String; Data : String) is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      File  : File_Type;
      Bytes : Stream_Element_Array (1 .. Stream_Element_Offset (Data'Length));
   begin
      for Index in Data'Range loop
         Bytes (Stream_Element_Offset (Index - Data'First + 1)) :=
           Stream_Element (Character'Pos (Data (Index)));
      end loop;
      Create (File, Out_File, Path);
      Write (File, Bytes);
      Close (File);
   end Write_Bytes;

   procedure Write_Fill (Path : String; Size : Positive) is
      Block  : aliased String (1 .. 8_192)    := (others => Character'Val (0));
      Path_C : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Path);
      FD     : Interfaces.C.int               := C_Open (Path_C, 1 + 64, 384);
      Left   : Natural                        := Size;
   begin
      Interfaces.C.Strings.Free (Path_C);
      Assert (FD >= 0, "large fixture is opened");
      while Left > 0 loop
         declare
            Amount : constant Natural := Natural'Min (Left, Block'Length);
            Wrote  : constant Interfaces.C.long :=
              C_Write
                (FD,
                 Block (Block'First)'Address,
                 Interfaces.C.size_t (Amount));
         begin
            Assert
              (Wrote = Interfaces.C.long (Amount),
               "large fixture bytes are written");
            Left := Left - Amount;
         end;
      end loop;
      declare
         Ignored : constant Interfaces.C.int := C_Close (FD);
         pragma Unreferenced (Ignored);
      begin
         null;
      end;
   end Write_Fill;

   procedure Make_Image
     (Path   : String;
      Format : Gdk.Pixbuf.File_Format;
      Width  : Positive;
      Height : Positive)
   is
      Pixbuf : constant Gdk.Pixbuf.Gdk_Pixbuf :=
        Gdk.Pixbuf.Gdk_New
          (Colorspace      => Gdk.Pixbuf.Colorspace_RGB,
           Has_Alpha       => True,
           Bits_Per_Sample => 8,
           Width           => Glib.Gint (Width),
           Height          => Glib.Gint (Height));
      Error  : Glib.Error.GError;
   begin
      Gdk.Pixbuf.Fill (Pixbuf, 16#FF00_FFFF#);
      Gdk.Pixbuf.Save (Pixbuf, Path, Format, Error);
      Assert (Error = null, "image fixture is encoded successfully");
      if Error /= null then
         Glib.Error.Error_Free (Error);
      end if;
      Glib.Object.Unref (Glib.Object.GObject (Pixbuf));
   end Make_Image;

   procedure Link_Path (Target : String; Link : String) is
      Target_C : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Target);
      Link_C   : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Link);
      Result   : Interfaces.C.int;
   begin
      Result := C_Symlink (Target_C, Link_C);
      Interfaces.C.Strings.Free (Target_C);
      Interfaces.C.Strings.Free (Link_C);
      Assert (Result = 0, "symlink fixture is created");
   end Link_Path;

   procedure Make_FIFO (Path : String) is
      Path_C : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Path);
      Result : Interfaces.C.int;
   begin
      Result := C_Mkfifo (Path_C, 384);
      Interfaces.C.Strings.Free (Path_C);
      Assert (Result = 0, "FIFO fixture is created");
   end Make_FIFO;

   procedure Check_Load
     (Root            : String;
      Destination     : String;
      Expected        : Boolean;
      Width           : Positive := 512;
      Expected_Width  : Natural  := 0;
      Expected_Height : Natural  := 0)
   is
      Pixbuf : Gdk.Pixbuf.Gdk_Pixbuf;
      Error  : Unbounded_String;
   begin
      Coyote_Image_Loader.Load (Root, Destination, Width, Pixbuf, Error);
      Assert
        ((Pixbuf /= null) = Expected,
         "unexpected pixbuf result for destination: " & Destination);
      Assert
        ((Length (Error) = 0) = Expected,
         "error output must agree with load result: " & Destination);
      if Expected then
         Assert
           (Gdk.Pixbuf.Get_Width (Pixbuf) = Glib.Gint (Expected_Width)
            or else Expected_Width = 0,
            "decoded width matches expected result");
         Assert
           (Gdk.Pixbuf.Get_Height (Pixbuf) = Glib.Gint (Expected_Height)
            or else Expected_Height = 0,
            "decoded height matches expected result");
         Glib.Object.Unref (Glib.Object.GObject (Pixbuf));
      end if;
   end Check_Load;

   overriding procedure Set_Up (T : in out Test) is
      FD   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Path : Unbounded_String;
   begin
      Coyote_Temp_Files.Create (FD, Path);
      Assert (FD /= GNAT.OS_Lib.Invalid_FD, "temporary root is created");
      GNAT.OS_Lib.Close (FD);
      Ada.Directories.Delete_File (To_String (Path));
      Ada.Directories.Create_Directory (To_String (Path));
      T.Root := Path;
      Make_Image
        (To_String (T.Root) & "/plot " & Coyote_App.Utils.UC_CHECK & ".png",
         Gdk.Pixbuf.PNG,
         4,
         4);
      Make_Image (To_String (T.Root) & "/photo.jpg", Gdk.Pixbuf.JPEG, 4, 4);
      Make_Image
        (To_String (T.Root) & "/wide.png",
         Gdk.Pixbuf.PNG,
         Coyote_Image_Loader.Max_Side + 1,
         1);
      Make_Image
        (To_String (T.Root) & "/large.png", Gdk.Pixbuf.PNG, 1_280, 1_200);
      Make_Image
        (To_String (T.Root) & "/pixels.png", Gdk.Pixbuf.PNG, 4_097, 4_097);
      Write_Bytes
        (To_String (T.Root) & "/corrupt.png",
         Character'Val (137) & "PNG" & Character'Val (13) & Character'Val (10)
         & Character'Val (26) & Character'Val (10) & "broken");
      Write_Bytes (To_String (T.Root) & "/vector.svg", "<svg></svg>");
      Write_Bytes (To_String (T.Root) & "/anim.gif", "GIF89a");
      Write_Bytes (To_String (T.Root) & "/anim.webp", "RIFFxxxxWEBPVP8X");
      Write_Fill
        (To_String (T.Root) & "/huge",
         Coyote_Image_Loader.Max_Source_Bytes + 1);
      Link_Path ("/etc/passwd", To_String (T.Root) & "/outside");
      Make_FIFO (To_String (T.Root) & "/pipe");
      Ada.Directories.Create_Directory (To_String (T.Root) & "/sub");
      Link_Path (To_String (T.Root), To_String (T.Root) & "/linked-dir");
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      if Length (T.Root) > 0 then
         begin
            Ada.Directories.Delete_Tree (To_String (T.Root));
         exception
            when others =>
               null;
         end;
         T.Root := Null_Unbounded_String;
      end if;
   end Tear_Down;

   procedure Test_Valid_Images_And_Uris (T : in out Test) is
      Root : constant String := To_String (T.Root);
   begin
      Check_Load
        (Root,
         "plot%20%E2%9C%93.png",
         True,
         Expected_Width  => 4,
         Expected_Height => 4);
      Check_Load
        (Root, "photo.jpg", True, Expected_Width => 4, Expected_Height => 4);
      Check_Load
        (Root,
         "file://" & Root & "/photo.jpg",
         True,
         Expected_Width  => 4,
         Expected_Height => 4);
      Check_Load
        ("/",
         Root & "/plot " & Coyote_App.Utils.UC_CHECK & ".png",
         True,
         Expected_Width  => 4,
         Expected_Height => 4);
   end Test_Valid_Images_And_Uris;

   procedure Test_Rejects_Uris_And_Escapes (T : in out Test) is
      Root : constant String := To_String (T.Root);
   begin
      Check_Load (Root, "file://localhost", False);
      Check_Load (Root, "file:///etc/passwd", False);
      Check_Load (Root, "https://example.invalid/image.png", False);
      Check_Load (Root, "data:image/png;base64,AAAA", False);
      Check_Load (Root, "file://remotehost/photo.jpg", False);
      Check_Load (Root, "missing.png", False);
      Check_Load (Root, "plot%Q0.png", False);
      Check_Load (Root, "plot%00.png", False);
      Check_Load (Root, "bad%0Aname.png", False);
      Check_Load (Root, "bad%1Fname.png", False);
      Check_Load (Root, "bad%7Fname.png", False);
   end Test_Rejects_Uris_And_Escapes;

   procedure Test_Rejects_Unsupported_And_Corrupt_Images (T : in out Test) is
      Root : constant String := To_String (T.Root);
   begin
      Check_Load (Root, "corrupt.png", False);
      Check_Load (Root, "vector.svg", False);
      Check_Load (Root, "anim.gif", False);
      Check_Load (Root, "anim.webp", False);
   end Test_Rejects_Unsupported_And_Corrupt_Images;

   procedure Test_Rejects_Path_Escapes_And_Special_Files (T : in out Test) is
      Root : constant String := To_String (T.Root);
   begin
      Check_Load (Root, "/etc/passwd", False);
      Check_Load (Root, "../etc/passwd", False);
      Check_Load (Root, "outside", False);
      Check_Load (Root, "linked-dir/photo.jpg", False);
      Check_Load (Root, "pipe", False);
      Check_Load (Root, "sub", False);
   end Test_Rejects_Path_Escapes_And_Special_Files;

   procedure Test_Enforces_Source_Limits (T : in out Test) is
      Root : constant String := To_String (T.Root);
   begin
      Check_Load (Root, "wide.png", False);
      Check_Load (Root, "pixels.png", False);
      Check_Load (Root, "huge", False);
   end Test_Enforces_Source_Limits;

   procedure Test_Scales_Without_Upscaling (T : in out Test) is
      Root : constant String := To_String (T.Root);
   begin
      Check_Load
        (Root,
         "photo.jpg",
         True,
         Width           => 2,
         Expected_Width  => 2,
         Expected_Height => 2);
      Check_Load
        (Root,
         "plot%20%E2%9C%93.png",
         True,
         Width           => 512,
         Expected_Width  => 4,
         Expected_Height => 4);
   end Test_Scales_Without_Upscaling;

   procedure Test_Fits_Within_Width_And_Height (T : in out Test) is
      Root : constant String := To_String (T.Root);
   begin
      Check_Load
        (Root,
         "large.png",
         True,
         Width           => 640,
         Expected_Width  => 640,
         Expected_Height => 600);
   end Test_Fits_Within_Width_And_Height;

   procedure Test_Repeated_Errors_Do_Not_Leak_Descriptors (T : in out Test) is
      Root   : constant String  := To_String (T.Root);
      Before : constant Natural := C_FD_Count;
   begin
      for Index in 1 .. 40 loop
         Check_Load (Root, "missing.png", False);
         Check_Load (Root, "outside", False);
         Check_Load (Root, "corrupt.png", False);
      end loop;
      if Before > 0 then
         Assert
           (C_FD_Count <= Before + 1,
            "repeated failures do not leak file descriptors");
      end if;
   end Test_Repeated_Errors_Do_Not_Leak_Descriptors;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Loader accepts PNG, JPEG, and local file URIs",
            Test_Valid_Images_And_Uris'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Loader rejects remote, malformed, and NUL URIs",
            Test_Rejects_Uris_And_Escapes'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Loader rejects unsupported and corrupt formats",
            Test_Rejects_Unsupported_And_Corrupt_Images'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Loader confines paths and rejects special files",
            Test_Rejects_Path_Escapes_And_Special_Files'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Loader enforces encoded source limits",
            Test_Enforces_Source_Limits'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Loader avoids upscaling small images",
            Test_Scales_Without_Upscaling'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Loader scales within width and height limits",
            Test_Fits_Within_Width_And_Height'Access));
      Result.Add_Test
        (Caller.Create
           ("Coyote.Image_Loader releases descriptors after failures",
            Test_Repeated_Errors_Do_Not_Leak_Descriptors'Access));
      return Result;
   end Suite;

end Coyote_Image_Loader_Tests;
