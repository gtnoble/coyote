--  Coyote_Image_Loader — bounded synchronous local raster image loading.
--
--  Load accepts a local path or local file URI beneath Root. On success,
--  Pixbuf owns one reference; on failure it is null and Error describes why.
--  No tasks are created. Load_Raw does not create a GtkAda wrapper.
with Ada.Strings.Unbounded;
with Coyote_Image_Decoder;
with Gdk.Pixbuf;

package Coyote_Image_Loader is
   Max_Source_Bytes : constant := 8 * 1_024 * 1_024;
   Max_Side         : constant := 8_192;
   Max_Pixels       : constant := 16 * 1_024 * 1_024;
   Max_Width        : constant := 640;
   Max_Height       : constant := 600;

   procedure Load_Raw
     (Root        :     String;
      Destination :     String;
      Width       :     Positive;
      Pixbuf      : out Coyote_Image_Decoder.Pixbuf_Handle;
      Error       : out Ada.Strings.Unbounded.Unbounded_String);

   --  Load adopts a raw reference; call only from the GTK main thread.
   procedure Load
     (Root        :     String;
      Destination :     String;
      Width       :     Positive;
      Pixbuf      : out Gdk.Pixbuf.Gdk_Pixbuf;
      Error       : out Ada.Strings.Unbounded.Unbounded_String);
end Coyote_Image_Loader;
