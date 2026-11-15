with Math_Memory_Budget;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

procedure Math_Memory_Budget_Probe is
   use Math_Memory_Budget;

   Small          : aliased Budget (Limit => 10);
   Zero_Budget    : aliased Budget (Limit => 0);
   Other          : aliased Budget (Limit => 10);
   Parallel_Budget : aliased Budget (Limit => 10);
   Owner          : Reservation;
   Peer           : Reservation;
   Third          : Reservation;
   Check_Count    : Natural := 0;

   protected Gate is
      procedure Mark;
      entry Wait_Until_Both;
   private
      Count : Natural := 0;
   end Gate;

   protected body Gate is
      procedure Mark is
      begin
         Count := Count + 1;
      end Mark;

      entry Wait_Until_Both when Count = 2 is
      begin
         null;
      end Wait_Until_Both;
   end Gate;

   task type Parallel_Charger is
      entry Start;
   end Parallel_Charger;

   task body Parallel_Charger is
      Local : Reservation;
   begin
      accept Start;
      Reserve (Local, Parallel_Budget'Unchecked_Access, 5);
      Gate.Mark;
      Gate.Wait_Until_Both;
      Release (Local);
   end Parallel_Charger;

   procedure Check (Condition : Boolean; Label : String) is
   begin
      Check_Count := Check_Count + 1;
      if not Condition then
         raise Program_Error with Label;
      end if;
   end Check;

   procedure Expect_Exceeded
     (Item    : in out Reservation;
      Account : not null Budget_Access;
      Amount  : Natural) is
      Rejected : Boolean := False;
   begin
      begin
         Reserve (Item, Account, Amount);
      exception
         when Error : Budget_Exceeded =>
            Check
              (Ada.Exceptions.Exception_Message (Error) =
                 "math workspace memory budget exceeded",
               "Budget_Exceeded message");
            Rejected := True;
      end;
      Check (Rejected, "expected Budget_Exceeded");
   end Expect_Exceeded;

begin
   Reserve (Owner, Zero_Budget'Unchecked_Access, 0);
   Check (Used (Zero_Budget) = 0, "zero-capacity zero reservation");
   Expect_Exceeded (Owner, Zero_Budget'Unchecked_Access, 1);
   Check (Used (Zero_Budget) = 0, "zero-capacity rejection unchanged");

   Reserve (Owner, Small'Unchecked_Access, 0);
   Check (Used (Small) = 0 and then Bytes (Owner) = 0, "zero");
   Reserve (Owner, Small'Unchecked_Access, 10);
   Check (Used (Small) = 10 and then Peak (Small) = 10, "exact fit");
   Reset_Peak (Small);
   Check (Used (Small) = 10 and then Peak (Small) = 10,
          "reset preserves active charge as baseline");
   Expect_Exceeded (Owner, Small'Unchecked_Access, 11);
   Reserve (Owner, Small'Unchecked_Access, 9);
   Check (Used (Small) = 9 and then Peak (Small) = 10,
          "rejected resize then shrink preserves reset peak");
   Reserve (Owner, Small'Unchecked_Access, 10);
   Check (Peak (Small) = 10, "growth records peak after reset");
   Reset_Peak (Small);
   Check (Used (Small) = 10 and then Peak (Small) = 10,
          "second reset remains at active charge");
   Release (Owner);
   Reset_Peak (Small);
   Check (Used (Small) = 0 and then Peak (Small) = 0,
          "zero-current reset");
   Reserve (Owner, Small'Unchecked_Access, 3);
   Check (Peak (Small) = 3 and then Peak (Other) = 0,
          "reset window and independent ledger");
   Release (Owner);
   Reset_Peak (Small);
   Reserve (Owner, Small'Unchecked_Access, 10);
   Expect_Exceeded (Owner, Small'Unchecked_Access, 11);
   Check (Used (Small) = 10 and then Bytes (Owner) = 10,
          "failed resize preserve");
   Expect_Exceeded (Peer, Small'Unchecked_Access, 1);
   Expect_Exceeded (Peer, Small'Unchecked_Access, Natural'Last);
   Check (Used (Small) = 10, "overflow-safe rejection");
   Reserve (Owner, Small'Unchecked_Access, 4);
   Check (Used (Small) = 4 and then Bytes (Owner) = 4,
          "nonzero shrink preserves peak");
   Reserve (Owner, Small'Unchecked_Access, 0);
   Check (Used (Small) = 0 and then Bytes (Owner) = 0,
          "same-ledger zero resize");
   Reserve (Owner, Small'Unchecked_Access, 4);
   Check (Used (Small) = 4 and then Bytes (Owner) = 4, "shrink");
   Reserve (Peer, Small'Unchecked_Access, 4);
   Reserve (Owner, Small'Unchecked_Access, 6);
   Check (Used (Small) = 10, "overlap then grow");
   Release (Owner);
   Release (Owner);
   Check (Used (Small) = 4 and then Bytes (Owner) = 0, "idempotent");
   Release (Peer);
   Check (Used (Small) = 0, "release peer");

   Reserve (Third, Other'Unchecked_Access, 10);
   Check (Used (Other) = 10 and then Used (Small) = 0,
          "independent ledgers");
   Release (Third);

   begin
      declare
         Scoped : Reservation;
      begin
         Reserve (Scoped, Small'Unchecked_Access, 7);
         raise Constraint_Error;
      end;
   exception
      when Constraint_Error =>
         null;
   end;
   Check (Used (Small) = 0, "exception finalization");

   declare
      First  : Parallel_Charger;
      Second : Parallel_Charger;
   begin
      First.Start;
      Second.Start;
   end;
   Check (Used (Parallel_Budget) = 0, "parallel overlap release");
   Check (Peak (Parallel_Budget) = 10, "parallel peak");
   Check (Used (Small) = 0, "separate parallel ledger");
   Check (Peak (Small) = 10, "peak");

   declare
      Rejected : Boolean := False;
   begin
      Reserve (Owner, Small'Unchecked_Access, 1);
      begin
         Reserve (Owner, Other'Unchecked_Access, 1);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Check (Rejected, "expected rebind failure");
   end;
   Check (Used (Small) = 1 and then Used (Other) = 0,
          "rebind rejection");
   Check (Bytes (Owner) = 1, "rebind preserves owner bytes");
   Release (Owner);

   declare
      Default_Budget : aliased Budget;
      Large_Owner    : Reservation;
   begin
      Reserve (Large_Owner, Default_Budget'Unchecked_Access, Capacity);
      Check (Used (Default_Budget) = Capacity, "capacity exact fit");
      Reserve (Large_Owner, Default_Budget'Unchecked_Access, 0);
   end;

   Ada.Text_IO.Put_Line
     ("math_memory_budget_probe: " &
      Ada.Strings.Fixed.Trim (Natural'Image (Check_Count),
                              Ada.Strings.Both) &
      " checks passed");
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Exceptions.Exception_Information (Error));
      raise;
end Math_Memory_Budget_Probe;
