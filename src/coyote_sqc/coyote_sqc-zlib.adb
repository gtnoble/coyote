with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;

with Interfaces.C;
with System;

--  Coyote_SQC.Zlib body — streaming deflate implementation.
--
--  Project: coyote

package body Coyote_SQC.Zlib is

   use type Interfaces.C.int;
   use type Interfaces.C.unsigned_long;

   --  Internal C-oriented byte array for FFI.
   subtype C_Byte is Interfaces.C.unsigned_char;
   type C_Byte_Array is array (Natural range <>) of C_Byte;

   --  z_stream mirror (x86_64 Linux).
   type z_stream is record
      next_in   : System.Address;
      avail_in  : Interfaces.C.unsigned;
      total_in  : Interfaces.C.unsigned_long;
      next_out  : System.Address;
      avail_out : Interfaces.C.unsigned;
      total_out : Interfaces.C.unsigned_long;
      msg       : System.Address;
      state     : System.Address;
      zalloc    : System.Address;
      zfree     : System.Address;
      opaque    : System.Address;
      data_type : Interfaces.C.int;
      adler     : Interfaces.C.unsigned_long;
      reserved  : Interfaces.C.unsigned_long;
   end record;
   pragma Convention (C, z_stream);

   type z_stream_Access is access all z_stream;

   --  zlib constants.
   Z_DEFLATED         : constant := 8;
   Z_FINISH           : constant Interfaces.C.int := 4;
   MAX_WBITS          : constant := 15;
   MAX_MEM_LEVEL      : constant := 8;
   Z_DEFAULT_STRATEGY : constant := 0;

   --  C imports.
   function c_deflateInit2
     (strm        : System.Address;
      level       : Interfaces.C.int;
      method      : Interfaces.C.int;
      windowBits  : Interfaces.C.int;
      memLevel    : Interfaces.C.int;
      strategy    : Interfaces.C.int;
      version     : System.Address;
      stream_size : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "deflateInit2_";

   function c_deflateSetDictionary
     (strm       : System.Address;
      dictionary : System.Address;
      dictLength : Interfaces.C.unsigned) return Interfaces.C.int
     with Import, Convention => C, External_Name => "deflateSetDictionary";

   function c_deflate
     (strm  : System.Address;
      flush : Interfaces.C.int) return Interfaces.C.int
     with Import, Convention => C, External_Name => "deflate";

   function c_deflateResetKeep
     (strm : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "deflateResetKeep";

   function c_deflateEnd
     (strm : System.Address) return Interfaces.C.int
     with Import, Convention => C, External_Name => "deflateEnd";

   ZLIB_VERSION : constant String := "1.2.13" & ASCII.NUL;

   function To_Access is
     new Ada.Unchecked_Conversion (System.Address, z_stream_Access);

   procedure Free_zstream is
     new Ada.Unchecked_Deallocation (z_stream, z_stream_Access);

   --  ==================================================================

   function Init_Stream (Level : Interfaces.C.int) return ZStream is
      Raw : z_stream_Access := new z_stream;
      Rc  : Interfaces.C.int;
   begin
      Raw.all := (others => <>);

      Rc := c_deflateInit2
        (Raw.all'Address,
         Level,
         Z_DEFLATED,
         MAX_WBITS,
         MAX_MEM_LEVEL,
         Z_DEFAULT_STRATEGY,
         ZLIB_VERSION'Address,
         Interfaces.C.int (z_stream'Size / 8));

      if Rc /= Z_OK then
         raise Program_Error with "zlib deflateInit2_ failed";
      end if;

      return (Raw => Raw.all'Address);
   end Init_Stream;

   --  ==================================================================

   procedure Set_Dict (S : in out ZStream; Dict : String) is
      Ptr : constant z_stream_Access := To_Access (S.Raw);
      Rc  : Interfaces.C.int;
   begin
      Rc := c_deflateSetDictionary
        (Ptr.all'Address,
         Dict'Address,
         Interfaces.C.unsigned (Dict'Length));
      if Rc /= Z_OK then
         raise Program_Error with "zlib deflateSetDictionary failed";
      end if;
   end Set_Dict;

   --  ==================================================================

   procedure Compress_Stream
     (S        : in out ZStream;
      Source   : String;
      Dest     : out Interfaces.C.char_array;
      Dest_Len : out uLongf)
   is
      Ptr    : constant z_stream_Access := To_Access (S.Raw);
      Rc     : Interfaces.C.int;
      C_Dest : C_Byte_Array (0 .. Dest'Length - 1);
      pragma Import (Ada, C_Dest);
      for C_Dest'Address use Dest'Address;
   begin
      Ptr.next_in   := Source'Address;
      Ptr.avail_in  := Interfaces.C.unsigned (Source'Length);
      Ptr.next_out  := C_Dest'Address;
      Ptr.avail_out := Interfaces.C.unsigned (Dest'Length);
      Ptr.total_out := 0;

      Rc := c_deflate (Ptr.all'Address, Z_FINISH);
      if Rc /= Z_STREAM_END then
         raise Program_Error with "zlib deflate failed";
      end if;

      Dest_Len := uLongf (Ptr.total_out);

      Rc := c_deflateResetKeep (Ptr.all'Address);
      if Rc /= Z_OK then
         raise Program_Error with "zlib deflateResetKeep failed";
      end if;
   end Compress_Stream;

   --  ==================================================================

   procedure Free_Stream (S : in out ZStream) is
      Ptr    : z_stream_Access := To_Access (S.Raw);
      Ignore : Interfaces.C.int;
   begin
      Ignore := c_deflateEnd (Ptr.all'Address);
      S.Raw := System.Null_Address;
      Free_zstream (Ptr);
   end Free_Stream;

   --  ==================================================================

   function Compress_With_Dict
     (Source : String;
      Level  : Interfaces.C.int;
      Dict   : String) return Natural
   is
      Ctx  : ZStream := Init_Stream (Level);
      Bound : constant uLong := Compress_Bound (uLong (Source'Length));
      Dest : Interfaces.C.char_array (0 .. Interfaces.C.size_t (Bound - 1));
      Dlen : aliased uLongf;
   begin
      Set_Dict (Ctx, Dict);
      Compress_Stream (Ctx, Source, Dest, Dlen);
      Free_Stream (Ctx);
      return Natural (Dlen);
   exception
      when others =>
         Free_Stream (Ctx);
         return 0;
   end Compress_With_Dict;

end Coyote_SQC.Zlib;
