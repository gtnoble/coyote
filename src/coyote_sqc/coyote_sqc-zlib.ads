--  Coyote_SQC.Zlib — thin Ada binding to system zlib for compression.
--
--  Provides the minimal subset needed by Coyote_SQC.Statistics.MI:
--  compressBound and compress2.
--
--  Project: coyote

with Interfaces.C;

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
     (Dest       : out Interfaces.C.Char_Array;
      Dest_Len   : in out uLongf;
      Source     : Interfaces.C.Char_Array;
      Source_Len : uLong;
      Level      : Interfaces.C.int) return Interfaces.C.int
     with Import => True,
     Convention    => C,
     External_Name => "compress2";

   Z_OK : constant Interfaces.C.int := 0;

end Coyote_SQC.Zlib;
