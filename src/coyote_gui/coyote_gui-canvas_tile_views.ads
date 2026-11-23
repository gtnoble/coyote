with Ada.Strings.Unbounded;
with Coyote_Canvas.Document;
with Coyote_Canvas.Revisions;
with Cairo;
with Interfaces.C;

--  Asynchronously renders a tiled Canvas region without retaining GTK state.
--  Start a job, poll Ready, then Finish to take its owned surface or Discard
--  it. A job owns the temporary levels until Finish returns them.
--  Discard requests cancellation and waits for any active native render call.
package Coyote_GUI.Canvas_Tile_Views is
   package Rev renames Coyote_Canvas.Revisions;
   package Doc renames Coyote_Canvas.Document;

   --  Level 0 is the authoritative Original, opened only by the worker.
   --  Reduced levels are private, unlinked files containing display pixels.
   subtype Level is Natural range 0 .. 15;
   type Level_Cache is limited private;
   procedure Clear (Cache : in out Level_Cache);

   type Job is limited private;
   type Job_Access is access Job;

   procedure Start
     (Item : out Job_Access;
      Parent, UUID, Digest : String;
      W : Rev.Workspace;
      Id : Rev.Revision_Id;
      Region : Doc.Rectangle;
      Include_Ink : Boolean; Resolution : Level;
      Cache : in out Level_Cache);

   function Ready (Item : Job_Access) return Boolean;

   procedure Finish
     (Item : in out Job_Access;
      Cache : in out Level_Cache; Surface : out Cairo.Cairo_Surface);

   --  Marks a job cancelled without waiting; Ready/Finish can reap it later.
   procedure Cancel (Item : Job_Access; Keep_Levels : Boolean := False);

   --  Cancels, waits for worker shutdown, and releases all owned resources.
   procedure Discard (Item : in out Job_Access);

private
   use type Interfaces.C.int;
   type Level_FDs is array (Level range 1 .. Level'Last) of Interfaces.C.int;
   type Level_Cache is limited record
      FDs : Level_FDs := (others => -1);
   end record;

   protected type Completion is
      procedure Signal;
      procedure Cancel (Keep_Levels : Boolean);
      entry Wait;
      function Is_Ready return Boolean;
      function Is_Cancelled return Boolean;
      function Stop_Levels return Boolean;
   private
      Done : Boolean := False;
      Cancelled, Stop_Build : Boolean := False;
   end Completion;

   task type Worker (Item : not null Job_Access);
   type Worker_Access is access Worker;

   type Job is limited record
      Parent, UUID, Digest : Ada.Strings.Unbounded.Unbounded_String;
      Workspace : Rev.Workspace;
      Revision : Rev.Revision_Id := Rev.NO_REVISION;
      Region : Doc.Rectangle := Doc.EMPTY_RECTANGLE;
      Include_Ink : Boolean := True;
      Resolution : Level := 0;
      Cache : Level_Cache;
      Completed : aliased Completion;
      Result : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Thread : Worker_Access;
   end record;
end Coyote_GUI.Canvas_Tile_Views;
