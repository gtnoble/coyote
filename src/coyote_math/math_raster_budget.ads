package Math_Raster_Budget is
   Capacity : constant Natural := 64 * 1_024 * 1_024;

   type Lease is limited private;
   procedure Reserve
     (Bytes : Natural; Owner : in out Lease; Accepted : out Boolean);
   procedure Release (Owner : in out Lease);
   procedure Adjust
     (Owner : in out Lease; Bytes : Natural; Accepted : out Boolean);
   function Bytes (Owner : Lease) return Natural;
   function Used return Natural;

private
   type Lease is limited record
      Charge : Natural := 0;
   end record;
end Math_Raster_Budget;
