--  Bounded asynchronous raster imports for the canvas workspace.
--  Submit from the GTK main task. Accepted requests complete exactly once
--  on the GTK main context after it is pumped. The callback borrows Pixels;
--  take a reference to retain it. Rejected requests never call the callback.
--  File imports are for paths selected by the user in a local file chooser.
--  Opens require a regular file and reject a symlink at the final component;
--  ancestor path components follow normal operating-system resolution.
with Ada.Strings.Unbounded;
with Coyote_Canvas.Rasters;
with Gdk.Pixbuf;
with System;

package Coyote_GUI.Canvas_Import_Jobs is
   type Completion is not null access procedure
     (Token  : System.Address;
      Pixels : Gdk.Pixbuf.Gdk_Pixbuf;
      Error  : String);

   --  At most two requests, including running and completed requests, are
   --  outstanding. One worker performs decoding at a time.
   Max_Outstanding : constant Positive := 2;
   function Pending_Count return Natural;

   procedure Submit_Bytes
     (Data     : in out Ada.Strings.Unbounded.Unbounded_String;
      Expected :        Coyote_Canvas.Rasters.Format;
      Token    :        System.Address;
      Callback :        Completion;
      Accepted :    out Boolean);

   procedure Submit_File
     (Path     :        String;
      Token    :        System.Address;
      Callback :        Completion;
      Accepted :    out Boolean);
end Coyote_GUI.Canvas_Import_Jobs;
