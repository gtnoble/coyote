--  Coyote_Image_IO — descriptor operations for confined image loading.
--
--  The descriptor abstraction keeps POSIX handles out of image policy code.
package Coyote_Image_IO is
   type Descriptor is private;
   Invalid_Descriptor : constant Descriptor;

   type File_Attributes is record
      Is_Regular : Boolean;
      Size       : Long_Long_Integer;
   end record;

   procedure Open_Root (Path : String; Root : out Descriptor);
   function Duplicate (File : Descriptor) return Descriptor;
   procedure Open_Directory
     (Parent : Descriptor; Name : String; Child : out Descriptor);
   procedure Open_File
     (Parent : Descriptor; Name : String; File : out Descriptor);
   procedure Attributes (File : Descriptor; Result : out File_Attributes);
   function Read (File : Descriptor; Buffer : out String) return Integer;
   function Readlink_Root (Root : Descriptor) return String;
   procedure Close (File : in out Descriptor);

private
   type Descriptor is new Integer;
   Invalid_Descriptor : constant Descriptor := -1;
end Coyote_Image_IO;
