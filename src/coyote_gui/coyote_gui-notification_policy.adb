--  Coyote_GUI.Notification_Policy body.
--
--  Project: coyote

package body Coyote_GUI.Notification_Policy is

   function Should_Notify_Completion
     (Allowed       : Boolean;
      Enabled       : Boolean;
      Window_Active : Boolean)
      return Boolean
   is
   begin
      return Allowed and then Enabled and then not Window_Active;
   end Should_Notify_Completion;

   function Should_Apply_Update
     (Runtime_Agent_Id  : String;
      Selected_Agent_Id : String;
      Is_Global         : Boolean)
      return Boolean
   is
   begin
      return Is_Global
        or else Runtime_Agent_Id'Length = 0
        or else Runtime_Agent_Id = Selected_Agent_Id;
   end Should_Apply_Update;

end Coyote_GUI.Notification_Policy;
