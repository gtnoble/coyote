--  Coyote_Image_Loader — bounded synchronous local raster image loading.
--
--  Load accepts a local path or local file URI beneath Root. On success,
--  Pixbuf owns one reference; on failure it is null and Error describes why.
--  No tasks are created. Load_Raw does not create a GtkAda wrapper.
with Ada.Strings.Unbounded;
with Coyote_Image_Decoder;
with Gdk.Pixbuf;
with GNAT.SHA256;

package Coyote_Image_Loader is
   Max_Source_Bytes : constant := 8 * 1_024 * 1_024;
   Max_Side         : constant := 8_192;
   Max_Pixels       : constant := 16 * 1_024 * 1_024;
   Max_Width        : constant := 640;
   Max_Height       : constant := 600;

   --  A successful preview identifies the exact bytes read, without
   --  keeping an open descriptor or a second copy of the raster.
   type Source is private;
   No_Source : constant Source;
   function Available (Item : Source) return Boolean;

   --  Use the same rooted file policy as preview loading. On success Bytes
   --  is the verified snapshot itself; the caller must not reopen the path.
   procedure Read_Original
     (Item : Source; Bytes, Error : out Ada.Strings.Unbounded.Unbounded_String);

   procedure Load_Raw
     (Root        :     String;
      Destination :     String;
      Width       :     Positive;
      Pixbuf      : out Coyote_Image_Decoder.Pixbuf_Handle;
      Error       : out Ada.Strings.Unbounded.Unbounded_String;
      Original    : out Source);

   --  Load adopts a raw reference; call only from the GTK main thread.
   procedure Load
     (Root        :     String;
      Destination :     String;
      Width       :     Positive;
      Pixbuf      : out Gdk.Pixbuf.Gdk_Pixbuf;
      Error       : out Ada.Strings.Unbounded.Unbounded_String);
private
   type Source is record
      Root, Destination : Ada.Strings.Unbounded.Unbounded_String;
      Digest : GNAT.SHA256.Message_Digest := (others => ' ');
   end record;
   No_Source : constant Source := (others => <>);
end Coyote_Image_Loader;
