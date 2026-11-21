package body Math_Raster_Budget is
   protected Ledger is
      procedure Reserve (Bytes : Natural; Accepted : out Boolean);
      procedure Release (Bytes : Natural);
      function Used return Natural;
   private
      Current : Natural := 0;
   end Ledger;

   protected body Ledger is
      procedure Reserve (Bytes : Natural; Accepted : out Boolean) is
      begin
         Accepted := Bytes <= Capacity and then
           Current <= Capacity - Bytes;
         if Accepted then
            Current := Current + Bytes;
         end if;
      end Reserve;

      procedure Release (Bytes : Natural) is
      begin
         if Bytes > Current then
            raise Program_Error;
         end if;
         Current := Current - Bytes;
      end Release;

      function Used return Natural is
      begin
         return Current;
      end Used;
   end Ledger;

   procedure Reserve
     (Bytes : Natural; Owner : in out Lease; Accepted : out Boolean) is
   begin
      Accepted := Owner.Charge = 0 and then Bytes > 0;
      if not Accepted then
         return;
      end if;
      Ledger.Reserve (Bytes, Accepted);
      if Accepted then
         Owner.Charge := Bytes;
      end if;
   end Reserve;

   procedure Release (Owner : in out Lease) is
   begin
      if Owner.Charge > 0 then
         Ledger.Release (Owner.Charge);
         Owner.Charge := 0;
      end if;
   end Release;

   procedure Adjust
     (Owner : in out Lease; Bytes : Natural; Accepted : out Boolean)
   is
      Difference : Natural;
   begin
      if Bytes <= Owner.Charge then
         Difference := Owner.Charge - Bytes;
         if Difference > 0 then
            Ledger.Release (Difference);
         end if;
         Owner.Charge := Bytes;
         Accepted := True;
      else
         Difference := Bytes - Owner.Charge;
         Ledger.Reserve (Difference, Accepted);
         if Accepted then
            Owner.Charge := Bytes;
         end if;
      end if;
   end Adjust;

   function Bytes (Owner : Lease) return Natural is (Owner.Charge);
   function Used return Natural is (Ledger.Used);
end Math_Raster_Budget;
