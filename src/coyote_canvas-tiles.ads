with Interfaces;
with Interfaces.C;
with System;

package Coyote_Canvas.Tiles is
   type Result is
     (Success,
      Invalid,
      Unsupported,
      Limit_Exceeded,
      I_O_Error,
      Cancelled,
      Memory_Error,
      Unknown_Result);
   for Result use
     (Success        => 0,
      Invalid        => 1,
      Unsupported    => 2,
      Limit_Exceeded => 3,
      I_O_Error      => 4,
      Cancelled      => 5,
      Memory_Error   => 6,
      Unknown_Result => 7);

   type Dimensions is record
      Width  : Interfaces.Unsigned_32;
      Height : Interfaces.Unsigned_32;
   end record;
   pragma Convention (C, Dimensions);

   type Byte is mod 2 ** 8;
   type Tile_Buffer is array (Positive range <>) of aliased Byte;
   pragma Convention (C, Tile_Buffer);

   Tile_Side : constant := 256;

   --  Called synchronously on the import task. Return nonzero to stop.
   --  A callback must not propagate exceptions through the C decoder.
   type Cancel_Callback is access function
     (User : System.Address) return Interfaces.C.int
     with Convention => C;

   --  Descriptors remain caller-owned and open. Import writes a native tile
   --  file to an empty O_RDWR staging descriptor. A failed import truncates
   --  staging; the caller should discard it. No descriptor is closed here.
   procedure Import
     (Source_FD   : Interfaces.C.int;
      Staging_FD  : Interfaces.C.int;
      Max_Bytes   : Interfaces.Unsigned_64;
      Status      : out Result;
      Image_Size  : out Dimensions;
      Cancel      : Cancel_Callback := null;
      User        : System.Address := System.Null_Address);

   --  Inspect validates tile-file metadata and exact length, not pixel data.
   procedure Inspect
     (FD         : Interfaces.C.int;
      Status     : out Result;
      Image_Size : out Dimensions);

   --  Read a zero-based tile into caller-owned packed straight-RGBA bytes.
   --  Buffer must have positive length and enough capacity for the tile.
   --  Extent gives actual edge-tile dimensions on success.
   procedure Read_Tile
     (FD         : Interfaces.C.int;
      Tile_X     : Interfaces.Unsigned_32;
      Tile_Y     : Interfaces.Unsigned_32;
      Buffer     : in out Tile_Buffer;
      Status     : out Result;
      Extent     : out Dimensions);
end Coyote_Canvas.Tiles;
