--  Coyote_GUI.Notification_Policy body.
--
--  Project: coyote

package body Coyote_GUI.Notification_Policy is

   function Should_Notify_Completion
     (Allowed       : Boolean;
      Enabled       : Boolean;
      Window_Active : Boolean) return Boolean
   is
   begin
      return Allowed and then Enabled and then not Window_Active;
   end Should_Notify_Completion;

end Coyote_GUI.Notification_Policy;
