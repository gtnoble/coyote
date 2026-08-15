--  Coyote_Notify body.
--
--  Project: coyote

package body Coyote_Notify is

   use type Interfaces.C.int;

   function Show_Completion return Boolean is
   begin
      return Native_Show_Completion /= 0;
   end Show_Completion;

   procedure Finalize is
   begin
      Native_Finalize;
   end Finalize;

end Coyote_Notify;
