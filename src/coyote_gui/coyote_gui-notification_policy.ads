--  Coyote_GUI.Notification_Policy — completion-notification policy.
--
--  Pure policy used by the GTK frontend after an agent turn completes.
--
--  Project: coyote

package Coyote_GUI.Notification_Policy is

   --  Return True only when notifications are allowed, enabled, and the
   --  coyote window is inactive.
   function Should_Notify_Completion
     (Allowed       : Boolean;
      Enabled       : Boolean;
      Window_Active : Boolean) return Boolean;

end Coyote_GUI.Notification_Policy;
