with Ada.Strings.Unbounded;
with Coyote_Canvas.Document;
with Coyote_Canvas.Revisions;
with Cairo;

--  Asynchronously renders a tiled Canvas region without retaining GTK state.
--  Start a job, poll Ready, then Finish to take its owned surface or Discard
--  it. Preview jobs return a bounded surface suitable for scaling to Region.
--  Discard requests cancellation and waits for any active native render call.
package Coyote_GUI.Canvas_Tile_Views is
   package Rev renames Coyote_Canvas.Revisions;
   package Doc renames Coyote_Canvas.Document;

   type Job is limited private;
   type Job_Access is access Job;

   procedure Start
     (Item : out Job_Access;
      Parent, UUID, Digest : String;
      W : Rev.Workspace;
      Id : Rev.Revision_Id;
      Region : Doc.Rectangle;
      Include_Ink : Boolean;
      Preview : Boolean);

   function Ready (Item : Job_Access) return Boolean;

   procedure Finish
     (Item : in out Job_Access;
      Surface : out Cairo.Cairo_Surface);

   --  Marks a job cancelled without waiting; Ready/Finish can reap it later.
   procedure Cancel (Item : Job_Access);

   --  Cancels, waits for worker shutdown, and releases all owned resources.
   procedure Discard (Item : in out Job_Access);

private
   protected type Completion is
      procedure Signal;
      procedure Cancel;
      entry Wait;
      function Is_Ready return Boolean;
      function Is_Cancelled return Boolean;
   private
      Done : Boolean := False;
      Cancelled : Boolean := False;
   end Completion;

   task type Worker (Item : not null Job_Access);
   type Worker_Access is access Worker;

   type Job is limited record
      Parent, UUID, Digest : Ada.Strings.Unbounded.Unbounded_String;
      Workspace : Rev.Workspace;
      Revision : Rev.Revision_Id := Rev.NO_REVISION;
      Region : Doc.Rectangle := Doc.EMPTY_RECTANGLE;
      Include_Ink : Boolean := True;
      Preview : Boolean := False;
      Completed : Completion;
      Result : Cairo.Cairo_Surface := Cairo.Null_Surface;
      Thread : Worker_Access;
   end record;
end Coyote_GUI.Canvas_Tile_Views;
