with Interfaces.C;
with System;

package body Coyote_Canvas.Tiles is
   function Native_Import
     (Source_FD  : Interfaces.C.int;
      Staging_FD : Interfaces.C.int;
      Max_Bytes  : Interfaces.Unsigned_64;
      Cancel     : Cancel_Callback;
      User       : System.Address;
      Info       : access Dimensions) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "coyote_canvas_tiles_import";

   function Native_Inspect
     (FD   : Interfaces.C.int;
      Info : access Dimensions) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "coyote_canvas_tiles_inspect";

   function Native_Read
     (FD       : Interfaces.C.int;
      Tile_X   : Interfaces.Unsigned_32;
      Tile_Y   : Interfaces.Unsigned_32;
      Pixels   : System.Address;
      Capacity : Interfaces.C.size_t;
      Extent   : access Dimensions) return Interfaces.C.int
     with Import, Convention => C,
       External_Name => "coyote_canvas_tiles_read";

   function Decode_Status (Code : Interfaces.C.int) return Result is
   begin
      case Code is
         when 0 =>
            return Success;
         when 1 =>
            return Invalid;
         when 2 =>
            return Unsupported;
         when 3 =>
            return Limit_Exceeded;
         when 4 =>
            return I_O_Error;
         when 5 =>
            return Cancelled;
         when 6 =>
            return Memory_Error;
         when others =>
            return Unknown_Result;
      end case;
   end Decode_Status;

   procedure Import
     (Source_FD   : Interfaces.C.int;
      Staging_FD  : Interfaces.C.int;
      Max_Bytes   : Interfaces.Unsigned_64;
      Status      : out Result;
      Image_Size  : out Dimensions;
      Cancel      : Cancel_Callback := null;
      User        : System.Address := System.Null_Address)
   is
      Info : aliased Dimensions := (Width => 0, Height => 0);
      Code : constant Interfaces.C.int :=
        Native_Import
          (Source_FD, Staging_FD, Max_Bytes, Cancel, User, Info'Access);
   begin
      Status := Decode_Status (Code);
      Image_Size := Info;
   end Import;

   procedure Reduce
     (Source_FD, Staging_FD : Interfaces.C.int;
      Status : out Result; Cancel : Cancel_Callback := null;
      User : System.Address := System.Null_Address)
   is
      function Native_Reduce
        (Source, Staging : Interfaces.C.int;
         Stop : Cancel_Callback; Data : System.Address) return Interfaces.C.int
        with Import, Convention => C,
          External_Name => "coyote_canvas_tiles_reduce";
   begin
      Status := Decode_Status
        (Native_Reduce (Source_FD, Staging_FD, Cancel, User));
   end Reduce;

   procedure Inspect
     (FD         : Interfaces.C.int;
      Status     : out Result;
      Image_Size : out Dimensions)
   is
      Info : aliased Dimensions := (Width => 0, Height => 0);
      Code : constant Interfaces.C.int :=
        Native_Inspect (FD, Info'Access);
   begin
      Status := Decode_Status (Code);
      Image_Size := Info;
   end Inspect;

   procedure Read_Tile
     (FD         : Interfaces.C.int;
      Tile_X     : Interfaces.Unsigned_32;
      Tile_Y     : Interfaces.Unsigned_32;
      Buffer     : in out Tile_Buffer;
      Status     : out Result;
      Extent     : out Dimensions)
   is
      Info : aliased Dimensions := (Width => 0, Height => 0);
   begin
      Extent := Info;
      if Buffer'Length = 0 then
         Status := Invalid;
      else
         Status := Decode_Status
           (Native_Read
              (FD       => FD,
               Tile_X   => Tile_X,
               Tile_Y   => Tile_Y,
               Pixels   => Buffer'Address,
               Capacity => Interfaces.C.size_t (Buffer'Length),
               Extent   => Info'Access));
         Extent := Info;
      end if;
   end Read_Tile;
end Coyote_Canvas.Tiles;
