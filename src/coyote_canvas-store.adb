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

   procedure Release (Data : System.Address)
     with Import, Convention => C, External_Name => "free";

   function Safe_Arguments (Parent, UUID : String) return Boolean is
   begin
      if Parent'Length = 0 or else Parent'Length > 4_095
        or else Parent (Parent'First) /= '/'
        or else (Parent'Length > 1 and then Parent (Parent'Last) = '/')
        or else UUID'Length /= 36
      then
         return False;
      end if;
      for Ch of Parent loop
         if Ch = ASCII.NUL then
            return False;
         end if;
      end loop;
      return True;
   end Safe_Arguments;

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
end Coyote_Canvas.Store;
