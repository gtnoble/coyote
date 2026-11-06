package Math_Work_Control is
   type Stop_Reason is (Continue_Work, Cancel_Requested, Deadline_Reached);
   type Context is abstract tagged limited null record;
   type Context_Access is access all Context'Class;

   function Check (Item : Context) return Stop_Reason is abstract;
   procedure Poll (Item : Context_Access);

   Stop_Requested : exception;
   Deadline_Expired : exception;
end Math_Work_Control;
