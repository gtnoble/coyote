--  Coyote_Image_Jobs — bounded asynchronous local image loading.
--
--  Submit queues image loads and delivers every accepted request exactly once
--  on the GLib main loop. Callbacks borrow their Pixbuf for the callback
--  duration; the service unreferences it afterward. A full queue is reported
--  synchronously through Completed. The caller owns each Consumer and must
--  keep it alive until its callback; it must not be deallocated sooner.
--  At most Max_Jobs requests are outstanding and at most Max_Workers loads
--  execute concurrently. Workers are Ada tasks; no GTK widgets are accessed
--  by them. The GLib timer is started only on the first Submit and stops when
--  all requests have completed. Submit must run on the GTK main task.
with Gdk.Pixbuf;

package Coyote_Image_Jobs is
   Max_Jobs    : constant Positive := 32;
   Max_Workers : constant Positive := 2;

   type Consumer is abstract tagged limited null record;

   procedure Completed
     (Target : in out Consumer;
      Pixbuf :        Gdk.Pixbuf.Gdk_Pixbuf;
      Error  :        String) is abstract;

   type Consumer_Access is access all Consumer'Class;

   procedure Submit
     (Root        : String;
      Destination : String;
      Width       : Positive;
      Target      : not null Consumer_Access);

   function Pending_Count return Natural;
end Coyote_Image_Jobs;
