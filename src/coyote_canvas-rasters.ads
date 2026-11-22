with Ada.Strings.Unbounded;
with Coyote_Image_Decoder;

package Coyote_Canvas.Rasters is
   type Format is (Unknown, PNG, JPEG);

   MAX_ENCODED_BYTES : constant := 8 * 1_024 * 1_024;
   MAX_SIDE          : constant := 8_192;
   MAX_PIXELS        : constant := 32 * 1_024 * 1_024;

   function Detect (Data : String) return Format;

   --  Decodes full-resolution pixels without creating a GtkAda wrapper.
   --  On success, Pixels owns a raw reference; the caller must release it.
   --  Errors are bounded, sanitized descriptions.
   procedure Decode
     (Data     :     String;
      Expected :     Format;
      Pixels   : out Coyote_Image_Decoder.Pixbuf_Handle;
      Width    : out Natural;
      Height   : out Natural;
      Error    : out Ada.Strings.Unbounded.Unbounded_String);

   --  Read returns bytes, zero at EOF, or -1 on error or cancellation.
   --  Rewind restarts the same regular file descriptor.
   procedure Decode_Stream
     (Read   : not null access function (Buffer : out String) return Integer;
      Rewind : not null access function return Boolean;
      Pixels : out Coyote_Image_Decoder.Pixbuf_Handle;
      Width  : out Natural;
      Height : out Natural;
      Error  : out Ada.Strings.Unbounded.Unbounded_String);
end Coyote_Canvas.Rasters;
