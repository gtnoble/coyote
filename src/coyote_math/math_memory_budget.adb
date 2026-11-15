package body Math_Memory_Budget is
   protected body Ledger is
      procedure Charge (Amount : Natural) is
      begin
         if Amount > Limit - Current_Bytes then
            raise Budget_Exceeded with
              "math workspace memory budget exceeded";
         end if;
         Current_Bytes := Current_Bytes + Amount;
         if Current_Bytes > Peak_Bytes then
            Peak_Bytes := Current_Bytes;
         end if;
      end Charge;

      procedure Resize (Old_Amount : Natural; New_Amount : Natural) is
         Other_Bytes : Natural;
      begin
         Other_Bytes := Current_Bytes - Old_Amount;
         if New_Amount > Limit - Other_Bytes then
            raise Budget_Exceeded with
              "math workspace memory budget exceeded";
         end if;
         Current_Bytes := Other_Bytes + New_Amount;
         if Current_Bytes > Peak_Bytes then
            Peak_Bytes := Current_Bytes;
         end if;
      end Resize;

      procedure Uncharge (Amount : Natural) is
      begin
         Current_Bytes := Current_Bytes - Amount;
      end Uncharge;

      function Current return Natural is
      begin
         return Current_Bytes;
      end Current;

      function Maximum return Natural is
      begin
         return Peak_Bytes;
      end Maximum;

      procedure Reset_Maximum is
      begin
         Peak_Bytes := Current_Bytes;
      end Reset_Maximum;
   end Ledger;

   procedure Reserve
     (Owner   : in out Reservation;
      Account : not null Budget_Access;
      Bytes   : Natural) is
   begin
      if Owner.Account /= null then
         if Owner.Account /= Account then
            raise Program_Error;
         end if;
         if Bytes = 0 then
            Release (Owner);
         else
            Account.Accounting.Resize
              (Old_Amount => Owner.Amount,
               New_Amount => Bytes);
            Owner.Amount := Bytes;
         end if;
      elsif Bytes /= 0 then
         Account.Accounting.Charge (Bytes);
         Owner.Account := Account;
         Owner.Amount := Bytes;
      end if;
   end Reserve;

   procedure Release (Owner : in out Reservation) is
   begin
      if Owner.Account /= null then
         Owner.Account.Accounting.Uncharge (Owner.Amount);
         Owner.Account := null;
         Owner.Amount := 0;
      end if;
   end Release;

   function Used (Account : Budget) return Natural is
   begin
      return Account.Accounting.Current;
   end Used;

   function Peak (Account : Budget) return Natural is
   begin
      return Account.Accounting.Maximum;
   end Peak;

   procedure Reset_Peak (Account : in out Budget) is
   begin
      Account.Accounting.Reset_Maximum;
   end Reset_Peak;

   function Bytes (Owner : Reservation) return Natural is
   begin
      return Owner.Amount;
   end Bytes;

   overriding procedure Finalize (Owner : in out Reservation) is
   begin
      Release (Owner);
   end Finalize;
end Math_Memory_Budget;
