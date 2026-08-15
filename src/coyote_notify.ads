--  Coyote_Notify — minimal native desktop-notification binding.
--
--  Calls are made only from the GTK main task.  The implementation treats
--  notification-daemon absence or delivery failure as a non-fatal condition.
--
--  Project: coyote

with Interfaces.C;

package Coyote_Notify is
   pragma Elaborate_Body;

   --  Show the standard coyote completion notification.  Returns True when
   --  libnotify accepted the notification, False when it is unavailable or
   --  the notification could not be delivered.
   function Show_Completion return Boolean;

   --  Release libnotify process-wide state.  Safe to call when uninitialised.
   procedure Finalize;

private
   function Native_Show_Completion return Interfaces.C.int
   with Import, Convention => C,
        External_Name => "coyote_notify_show_completion";

   procedure Native_Finalize
   with Import, Convention => C,
        External_Name => "coyote_notify_finalize";
end Coyote_Notify;
