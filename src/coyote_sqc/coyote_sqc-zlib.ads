--  Coyote_SQC.Zlib — thin Ada binding to system zlib for compression.
--
--  Provides the minimal subset needed by Coyote_SQC.Statistics.MI:
--  compressBound and compress2.
--
--  Project: coyote

with Interfaces.C;
with System;

package Coyote_SQC.Zlib is

   --  Opaque types matching zlib's C declarations.
   subtype uLong  is Interfaces.C.unsigned_long;
   subtype uLongf is Interfaces.C.unsigned_long;

   --  Return an upper bound on the compressed size after compress2 of
   --  sourceLen bytes.
   function Compress_Bound (Source_Len : uLong) return uLong
     with Import => True,
     Convention    => C,
     External_Name => "compressBound";

   --  Compress source bytes into dest.  Returns Z_OK (0) on success.
   --  dest must be at least Compress_Bound(sourceLen) bytes.
   --  Level: 0 (no compression) to 9 (best compression).
   function Compress2
     (Dest       : out Interfaces.C.char_array;
      Dest_Len   : in out uLongf;
      Source     : Interfaces.C.char_array;
      Source_Len : uLong;
      Level      : Interfaces.C.int) return Interfaces.C.int
     with Import => True,
     Convention    => C,
     External_Name => "compress2";

   Z_OK : constant Interfaces.C.int := 0;

   Z_STREAM_END : constant Interfaces.C.int := 1;

   --  Opaque streaming deflate stream handle.
   type ZStream is limited private;

   --  Allocate and initialise a new deflate stream at the given level.
   --  Level: 0 (no compression) to 9 (best compression).
   --  Raises Program_Error on failure (zlib init error).
   function Init_Stream (Level : Interfaces.C.int) return ZStream;

   --  Load Dict into the stream's compression window.
   --  Must be called before Compress_Stream when a dictionary is desired.
   procedure Set_Dict (S : in out ZStream; Dict : String);

   --  Compress Source using the stream's current state (including any
   --  dictionary loaded via Set_Dict).  Dest must be pre-allocated with
   --  at least Compress_Bound (Source'Length) bytes.  Dest_Len receives
   --  the actual number of bytes written.
   --  The stream is reset after compression (deflateResetKeep) so it can
   --  be reused; the dictionary is preserved.
   procedure Compress_Stream
     (S        : in out ZStream;
      Source   : String;
      Dest     : out Interfaces.C.char_array;
      Dest_Len : out uLongf);

   --  Deallocate the stream.
   procedure Free_Stream (S : in out ZStream);

   --  Convenience: init stream, set dictionary, compress Source, free stream.
   --  Returns the compressed size in bytes, or 0 on failure.
   function Compress_With_Dict
     (Source : String;
      Level  : Interfaces.C.int;
      Dict   : String) return Natural;

private

   type ZStream is limited record
      Raw : System.Address;
   end record;

end Coyote_SQC.Zlib;
