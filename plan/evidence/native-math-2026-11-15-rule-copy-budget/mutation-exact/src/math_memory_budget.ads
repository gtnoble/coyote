with Ada.Finalization;

--  Transient reservation ledger for raster workspace.
--
--  Reserve charges a reservation before workspace allocation.  Release or
--  finalization returns the charge.  Each Budget has independent accounting.
--  The Account must outlive every Reservation that refers to it; callers
--  are responsible for this lifetime relationship. Operations on one
--  Reservation must not occur simultaneously. The protected ledger supports
--  concurrent operations on independent Reservations, even on one Budget.
--
--  Reserve raises Budget_Exceeded when the requested charge cannot fit.
--  Rebinding a live Reservation to another Budget raises Program_Error.
--  The ledger serializes accounting for independent owners.
package Math_Memory_Budget is
   Capacity : constant Natural := 256 * 1024 * 1024;
   subtype Byte_Limit is Natural range 0 .. Capacity;

   Budget_Exceeded : exception;

   type Budget (Limit : Byte_Limit := Capacity) is limited private;
   type Budget_Access is access all Budget;
   type Reservation is
     new Ada.Finalization.Limited_Controlled with private;

   procedure Reserve
     (Owner   : in out Reservation;
      Account : not null Budget_Access;
      Bytes   : Natural);
   procedure Release (Owner : in out Reservation);
   function Used (Account : Budget) return Natural;
   function Peak (Account : Budget) return Natural;
   --  Callers serialize measurement windows for a shared Budget.
   --  Resetting the peak never changes current reservation charges.
   procedure Reset_Peak (Account : in out Budget);
   function Bytes (Owner : Reservation) return Natural;

private
   protected type Ledger (Limit : Byte_Limit) is
      procedure Charge (Amount : Natural);
      procedure Resize (Old_Amount : Natural; New_Amount : Natural);
      procedure Uncharge (Amount : Natural);
      function Current return Natural;
      function Maximum return Natural;
      procedure Reset_Maximum;
   private
      Current_Bytes : Natural := 0;
      Peak_Bytes    : Natural := 0;
   end Ledger;

   type Budget (Limit : Byte_Limit := Capacity) is limited record
      Accounting : Ledger (Limit);
   end record;

   type Reservation is
     new Ada.Finalization.Limited_Controlled with record
      Account : Budget_Access := null;
      Amount  : Natural := 0;
   end record;

   overriding procedure Finalize (Owner : in out Reservation);
end Math_Memory_Budget;
