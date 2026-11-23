with Interfaces.C;
with System;

package body Coyote_Canvas.Store is
   use Ada.Strings.Unbounded;
   use Interfaces.C;

   function Native_Read
     (Parent, UUID : char_array; Limit : size_t;
      Data : out System.Address; Length : out size_t) return int
     with Import, Convention => C, External_Name => "coyote_canvas_store_read";

   function Native_Write
     (Parent, UUID : char_array; Data : System.Address; Length : size_t)
      return int
     with Import, Convention => C, External_Name => "coyote_canvas_store_write";

   function Native_Read_Asset
     (Parent, UUID, Digest : char_array; Limit : size_t;
      Data : out System.Address; Length : out size_t) return int
     with Import, Convention => C,
          External_Name => "coyote_canvas_store_read_asset";

   function Native_Write_Asset
     (Parent, UUID, Digest : char_array; Data : System.Address; Length : size_t)
      return int
     with Import, Convention => C,
          External_Name => "coyote_canvas_store_write_asset";

   function Native_Reserve_Fork (Parent, UUID : char_array) return int
     with Import, Convention => C,
          External_Name => "coyote_canvas_reserve_fork";

   function Native_Remove_Session
     (Parent, UUID, Log_Name : char_array) return int
     with Import, Convention => C,
          External_Name => "coyote_canvas_remove_session";

   procedure Release (Data : System.Address)
     with Import, Convention => C, External_Name => "free";

   function Safe_Parent (Parent : String) return Boolean is
   begin
      if Parent'Length = 0 or else Parent'Length > 4_095
        or else Parent (Parent'First) /= '/'
        or else (Parent'Length > 1 and then Parent (Parent'Last) = '/')
      then
         return False;
      end if;
      for Ch of Parent loop
         if Ch = ASCII.NUL then
            return False;
         end if;
      end loop;
      return True;
   end Safe_Parent;

   function Safe_Arguments (Parent, UUID : String) return Boolean is
     (Safe_Parent (Parent) and then UUID'Length = 36);

   procedure Read
     (Parent, UUID : String; Data : out Unbounded_String; Status : out Result)
   is
      Buffer : System.Address := System.Null_Address;
      Size   : size_t;
   begin
      Data := Null_Unbounded_String;
      Status := Invalid;
      if not Safe_Arguments (Parent, UUID) then
         return;
      end if;
      Status := Result'Val
        (Native_Read (To_C (Parent), To_C (UUID), MAX_MANIFEST_BYTES,
                      Buffer, Size));
      if Status = Ok and then Size > 0 then
         declare
            Bytes : String (1 .. Natural (Size))
              with Import, Address => Buffer;
         begin
            Data := To_Unbounded_String (Bytes);
         end;
      end if;
      Release (Buffer);
   exception
      when others =>
         Release (Buffer);
         raise;
   end Read;

   procedure Write (Parent, UUID, Data : String; Status : out Result) is
   begin
      Status := Invalid;
      if Safe_Arguments (Parent, UUID)
        and then Data'Length in 1 .. MAX_MANIFEST_BYTES
      then
         Status := Result'Val
           (Native_Write (To_C (Parent), To_C (UUID),
                          Data (Data'First)'Address, size_t (Data'Length)));
      end if;
   end Write;
   procedure Read_Asset
     (Parent, UUID, Digest : String; Expected_Bytes : Positive;
      Data : out Unbounded_String; Status : out Result)
   is
      Buffer : System.Address := System.Null_Address;
      Size   : size_t;
   begin
      Data := Null_Unbounded_String;
      Status := Invalid;
      if not Safe_Arguments (Parent, UUID) or else Digest'Length /= 64
        or else Expected_Bytes > MAX_ASSET_BYTES
      then
         return;
      end if;
      Status := Result'Val
        (Native_Read_Asset (To_C (Parent), To_C (UUID), To_C (Digest),
                            size_t (Expected_Bytes), Buffer, Size));
      if Status = Ok then
         if Size = size_t (Expected_Bytes) then
            declare
               Bytes : String (1 .. Expected_Bytes)
                 with Import, Address => Buffer;
            begin
               Data := To_Unbounded_String (Bytes);
            end;
         else
            Status := Invalid;
         end if;
      end if;
      Release (Buffer);
   exception
      when others =>
         Release (Buffer);
         raise;
   end Read_Asset;

   procedure Write_Asset
     (Parent, UUID, Digest, Data : String; Status : out Result) is
   begin
      Status := Invalid;
      if Safe_Arguments (Parent, UUID) and then Digest'Length = 64
        and then Data'Length in 1 .. MAX_ASSET_BYTES
      then
         Status := Result'Val
           (Native_Write_Asset (To_C (Parent), To_C (UUID), To_C (Digest),
                                Data (Data'First)'Address,
                                size_t (Data'Length)));
      end if;
   end Write_Asset;
   procedure Write_Tile
     (Parent, UUID : String; FD : int;
      Digest : out Tile_Digest; Status : out Result)
   is
      function Native_Write_Tile
        (Parent, UUID : char_array; FD : int; Digest : out char_array)
         return int
        with Import, Convention => C,
          External_Name => "coyote_canvas_store_write_tile";
      Buffer : char_array (0 .. 64) := (others => nul);
   begin
      Digest := (others => ' ');
      Status := Invalid;
      if Safe_Arguments (Parent, UUID) and then FD >= 0 then
         Status := Result'Val
           (Native_Write_Tile (To_C (Parent), To_C (UUID), FD, Buffer));
         if Status = Ok then
            Digest := To_Ada (Buffer (0 .. 63), Trim_Nul => False);
         end if;
      end if;
   end Write_Tile;

   procedure Open_Tile
     (Parent, UUID, Digest : String; FD : out int; Status : out Result)
   is
      function Native_Open_Tile
        (Parent, UUID, Digest : char_array; FD : out int) return int
        with Import, Convention => C,
          External_Name => "coyote_canvas_store_open_tile";
   begin
      FD := -1;
      Status := Invalid;
      if Safe_Arguments (Parent, UUID) and then Digest'Length = 64 then
         Status := Result'Val
           (Native_Open_Tile (To_C (Parent), To_C (UUID), To_C (Digest), FD));
      end if;
   end Open_Tile;

   function Native_Claim (Parent, UUID : char_array; FD : out int) return int
     with Import, Convention => C, External_Name => "coyote_canvas_store_claim";
   function Close (FD : int) return int
     with Import, Convention => C, External_Name => "close";

   procedure Close_Tile (FD : in out int) is
      Ignored : int;
   begin
      if FD >= 0 then
         Ignored := Close (FD);
         FD := -1;
      end if;
   end Close_Tile;

   procedure Release (Lease : in out Writer_Lease) is
      Ignored : int;
   begin
      if Lease.FD >= 0 then
         Ignored := Close (Lease.FD);
         Lease.FD := -1;
      end if;
   end Release;

   procedure Move (Target, Source : in out Writer_Lease) is
   begin
      Release (Target);
      Target.FD := Source.FD;
      Source.FD := -1;
   end Move;

   overriding procedure Finalize (Lease : in out Writer_Lease) is
   begin
      Release (Lease);
   end Finalize;

   procedure Claim (Parent, UUID : String; Lease : in out Writer_Lease;
                    Status : out Result) is
   begin
      Status := Invalid;
      if Lease.FD < 0 and then Safe_Arguments (Parent, UUID) then
         Status := Result'Val
           (Native_Claim (To_C (Parent), To_C (UUID), Lease.FD));
      end if;
   end Claim;
   procedure Reserve_Fork (Parent, UUID : String; Status : out Result) is
   begin
      Status := Invalid;
      if Safe_Arguments (Parent, UUID) then
         Status := Result'Val (Native_Reserve_Fork (To_C (Parent), To_C (UUID)));
      end if;
   end Reserve_Fork;

   procedure Remove_Session
     (Parent, UUID, Log_Name : String; Status : out Result)
   is
   begin
      Status := Invalid;
      if not Safe_Parent (Parent) or else UUID'Length not in 0 | 36 then
         return;
      end if;
      for Ch of Log_Name loop
         if Ch = ASCII.NUL then
            return;
         end if;
      end loop;
      Status := Result'Val
        (Native_Remove_Session (To_C (Parent), To_C (UUID), To_C (Log_Name)));
   end Remove_Session;
   procedure Reclaim_Header
     (Parent, UUID : String; Orphan : Boolean;
      Header : out Unbounded_String; Status : out Result)
   is
      function Inspect
        (Parent, UUID : char_array; Orphan : int; Limit : size_t;
         Data : out System.Address; Length : out size_t) return int
        with Import, Convention => C,
             External_Name => "coyote_canvas_reclaim_header";
      Buffer : System.Address := System.Null_Address;
      Size   : size_t;
   begin
      Header := Null_Unbounded_String;
      Status := Invalid;
      if not Safe_Arguments (Parent, UUID) then
         return;
      end if;
      Status := Result'Val
        (Inspect (To_C (Parent), To_C (UUID), Boolean'Pos (Orphan),
                  16 * 1_024, Buffer, Size));
      if Status = Ok and then Size > 0 then
         declare
            Text : String (1 .. Natural (Size)) with Import, Address => Buffer;
         begin
            Header := To_Unbounded_String (Text);
         end;
      end if;
      Release (Buffer);
   exception
      when others =>
         Release (Buffer);
         raise;
   end Reclaim_Header;

   procedure Reclaim_Checked
     (Parent, UUID, Manifest, Keep : String; Orphan, Apply : Boolean;
      Report : out Reclaim_Report; Status : out Result)
   is
      function Reclaim
        (Parent, UUID : char_array; Manifest : System.Address;
         Manifest_Size : size_t; Keep : System.Address; Keep_Count : size_t;
         Orphan, Apply : int; Files : out size_t;
         Bytes : out Interfaces.Unsigned_64) return int
        with Import, Convention => C, External_Name => "coyote_canvas_reclaim";
      Files : size_t;
      Bytes : Interfaces.Unsigned_64;
   begin
      Report := (Files => 0, Bytes => 0);
      Status := Invalid;
      if not Safe_Arguments (Parent, UUID) or else Keep'Length mod 69 /= 0 then
         return;
      end if;
      Status := Result'Val
        (Reclaim (To_C (Parent), To_C (UUID), Manifest'Address,
                  size_t (Manifest'Length), Keep'Address,
                  size_t (Keep'Length / 69), Boolean'Pos (Orphan),
                  Boolean'Pos (Apply), Files, Bytes));
      if Status = Ok then
         Report := (Files => Natural (Files), Bytes => Bytes);
      end if;
   end Reclaim_Checked;
end Coyote_Canvas.Store;
