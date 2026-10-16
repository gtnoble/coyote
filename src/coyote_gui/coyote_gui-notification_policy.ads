--  Coyote_GUI.Notification_Policy — completion-notification policy.
--
--  Pure policy used by the GTK frontend after an agent turn completes.
--
--  Project: coyote

package Coyote_GUI.Notification_Policy is

   --  Return True when a root-agent completion notification is permitted by
   --  user preference, interaction mode, and window activation state.
   function Should_Notify_Completion
     (Allowed       : Boolean;
      Enabled       : Boolean;
      Window_Active : Boolean)
      return Boolean;

   --  Return True when an update belongs to the selected agent or is global.
   function Should_Apply_Update
     (Runtime_Agent_Id  : String;
      Selected_Agent_Id : String;
      Is_Global         : Boolean)
      return Boolean;

end Coyote_GUI.Notification_Policy;
