package body Math_Work_Control is
   procedure Poll (Item : Context_Access) is
      Reason : Stop_Reason;
   begin
      if Item = null then
         return;
      end if;
      Reason := Check (Item.all);
      case Reason is
         when Continue_Work =>
            null;
         when Cancel_Requested =>
            raise Stop_Requested;
         when Deadline_Reached =>
            raise Deadline_Expired;
      end case;
   end Poll;
end Math_Work_Control;
