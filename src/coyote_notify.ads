--  Coyote_Notify — minimal native desktop-notification binding.
--
--  Calls are made only from the GTK main task.  Notification-daemon absence
--  or delivery failure is treated as a non-fatal condition.
--
--  Project: coyote

package Coyote_Notify is
   pragma Elaborate_Body;

   --  Show the standard completion notification, if libnotify is available.
   --  Returns False when initialization or delivery fails.
   function Show_Completion return Boolean;

   --  Release process-wide libnotify state.  Safe before initialization.
   procedure Finalize;

end Coyote_Notify;
