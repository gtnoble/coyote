with Interfaces.C;
with Interfaces.C.Strings;
with System;

package body Coyote_Image_IO is
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   function C_Open_Root
     (Path : Interfaces.C.Strings.chars_ptr) return Interfaces.C.int with
     Import, Convention => C, External_Name => "coyote_image_io_open_root";
   function C_Duplicate (File : Interfaces.C.int) return Interfaces.C.int with
     Import, Convention => C, External_Name => "coyote_image_io_duplicate";
   function C_Open_Directory
     (Parent : Interfaces.C.int;
      Name   : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.int with
     Import,
     Convention    => C,
     External_Name => "coyote_image_io_open_directory";
   function C_Open_File
     (Parent : Interfaces.C.int;
      Name   : Interfaces.C.Strings.chars_ptr)
      return Interfaces.C.int with
     Import, Convention => C, External_Name => "coyote_image_io_open_file";
   function C_Attributes
     (File       : Interfaces.C.int;
      Is_Regular : access Interfaces.C.int;
      Size       : access Interfaces.C.long_long)
      return Interfaces.C.int with
     Import, Convention => C, External_Name => "coyote_image_io_attributes";
   function C_Read
     (File   : Interfaces.C.int;
      Buffer : System.Address;
      Length : Interfaces.C.size_t)
      return Interfaces.C.long with
     Import, Convention => C, External_Name => "coyote_image_io_read";
   function C_Readlink_Root
     (File   : Interfaces.C.int;
      Buffer : System.Address;
      Length : Interfaces.C.size_t)
      return Interfaces.C.long with
     Import, Convention => C, External_Name => "coyote_image_io_readlink_root";
   function C_Close (File : Interfaces.C.int) return Interfaces.C.int with
     Import, Convention => C, External_Name => "coyote_image_io_close";

   procedure Open_Root (Path : String; Root : out Descriptor) is
      C_Path : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Path);
   begin
      Root := Descriptor (C_Open_Root (C_Path));
      Interfaces.C.Strings.Free (C_Path);
   exception
      when others =>
         Interfaces.C.Strings.Free (C_Path);
         raise;
   end Open_Root;

   function Duplicate (File : Descriptor) return Descriptor is
   begin
      return Descriptor (C_Duplicate (Interfaces.C.int (File)));
   end Duplicate;

   procedure Open_Directory
     (Parent : Descriptor; Name : String; Child : out Descriptor)
   is
      C_Name : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Name);
   begin
      Child :=
        Descriptor (C_Open_Directory (Interfaces.C.int (Parent), C_Name));
      Interfaces.C.Strings.Free (C_Name);
   exception
      when others =>
         Interfaces.C.Strings.Free (C_Name);
         raise;
   end Open_Directory;

   procedure Open_File
     (Parent : Descriptor; Name : String; File : out Descriptor)
   is
      C_Name : Interfaces.C.Strings.chars_ptr :=
        Interfaces.C.Strings.New_String (Name);
   begin
      File := Descriptor (C_Open_File (Interfaces.C.int (Parent), C_Name));
      Interfaces.C.Strings.Free (C_Name);
   exception
      when others =>
         Interfaces.C.Strings.Free (C_Name);
         raise;
   end Open_File;

   procedure Attributes (File : Descriptor; Result : out File_Attributes) is
      Is_Regular : aliased Interfaces.C.int       := 0;
      Size       : aliased Interfaces.C.long_long := 0;
      Status     : constant Interfaces.C.int      :=
        C_Attributes (Interfaces.C.int (File), Is_Regular'Access, Size'Access);
   begin
      Result :=
        (Is_Regular => Status = 0 and then Is_Regular /= 0,
         Size       => Long_Long_Integer (Size));
   end Attributes;

   function Read (File : Descriptor; Buffer : out String) return Integer is
   begin
      return
        Integer
          (C_Read
             (Interfaces.C.int (File),
              Buffer'Address,
              Interfaces.C.size_t (Buffer'Length)));
   end Read;

   function Readlink_Root (Root : Descriptor) return String is
      Buffer : aliased String (1 .. 4_096);
      Count  : constant Interfaces.C.long :=
        C_Readlink_Root
          (Interfaces.C.int (Root),
           Buffer'Address,
           Interfaces.C.size_t (Buffer'Length));
   begin
      if Count <= 0 or else Count >= Buffer'Length then
         return "";
      end if;
      return Buffer (1 .. Integer (Count));
   end Readlink_Root;

   procedure Close (File : in out Descriptor) is
      Ignore : Interfaces.C.int;
   begin
      if File /= Invalid_Descriptor then
         Ignore := C_Close (Interfaces.C.int (File));
         File   := Invalid_Descriptor;
      end if;
   end Close;
end Coyote_Image_IO;
