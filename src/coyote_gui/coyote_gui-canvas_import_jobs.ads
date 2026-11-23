--  Bounded asynchronous image imports for the Canvas workspace.
--  Submit from the GTK main task. Accepted requests complete exactly once
--  on the GTK main context after it is pumped. The callback borrows Pixels;
--  take references to retain the images. A failed batch returns no pixels;
--  a successful one returns one image per input, in order. Rejected requests
--  never call back.
--  File imports are for paths selected by the user in a local file chooser.
--  Opens require regular files and reject a symlink at the final component.
with Ada.Strings.Unbounded;
with Coyote_Canvas.Rasters;
with Coyote_Canvas.Import_Service;
with Gdk.Pixbuf;
with Interfaces.C;
with System;

package Coyote_GUI.Canvas_Import_Jobs is
   use type Interfaces.C.int;
   type Image_List is array (Positive range <>) of Gdk.Pixbuf.Gdk_Pixbuf;
   type Path_List is
     array (Positive range <>) of Ada.Strings.Unbounded.Unbounded_String;

   MAX_FILES : constant Positive := 8;
   MAX_BATCH_DECODED_BYTES : constant := 128 * 1_024 * 1_024;
   MAX_BATCH_ENCODED_BYTES : constant := 32 * 1_024 * 1_024;

   type Completion is not null access procedure
     (Token  : System.Address;
      Pixels : Image_List;
      Error  : String);

   Max_Outstanding : constant Positive := 2;
   function Pending_Count return Natural;

   procedure Submit_Bytes
     (Data     : in out Ada.Strings.Unbounded.Unbounded_String;
      Expected :        Coyote_Canvas.Rasters.Format;
      Token    :        System.Address;
      Callback :        Completion;
      Accepted :    out Boolean);

   procedure Submit_Batch
     (Data     : Coyote_Canvas.Import_Service.Text_List;
      Token    : System.Address;
      Callback : Completion;
      Accepted : out Boolean);

   procedure Cancel_Files (Token : System.Address);

   procedure Submit_Files
     (Paths    :        Path_List;
      Token    :        System.Address;
      Callback :        Completion;
      Accepted :    out Boolean);

   --  Tile descriptors are borrowed during On_Tiled_Complete and are closed
   --  immediately after it returns. Width and Height describe the source.
   type Tile_Source is record
      FD     : Interfaces.C.int := -1;
      Width  : Natural := 0;
      Height : Natural := 0;
   end record;
   type Tile_List is array (Positive range <>) of Tile_Source;

   type On_Tiled_Complete is not null access procedure
     (Token  : System.Address;
      Pixels : Image_List;
      Tiles  : Tile_List;
      Error  : String);

   --  Uses the regular file decoder first; files rejected only by its
   --  dimension limit are imported to temporary tile files.
   function Submit_Tiled_Files
     (Paths    : Path_List;
      Token    : System.Address;
      Callback : On_Tiled_Complete) return Boolean;
end Coyote_GUI.Canvas_Import_Jobs;
