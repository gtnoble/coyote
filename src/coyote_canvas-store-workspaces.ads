with Coyote_Canvas.Revisions.Recovery;

--  Synchronous durability API for a stable workspace and its Originals.
--  The caller supplies the session directory and holds any editor lease.
package Coyote_Canvas.Store.Workspaces is
   MAX_RASTER_BYTES : constant := 128 * 1_024 * 1_024;

   --  Only imported Original indices have bytes: tightly packed, top-down
   --  straight RGBA8 at the Original extent. RGB sources use opaque alpha.
   --  All other entries are empty. Assets are immutable for each call.
   type Raster_Set is array (Positive range 1 .. Revisions.MAX_REVISIONS)
     of Ada.Strings.Unbounded.Unbounded_String;

   --  Holds the shared session guard across all asset and manifest writes.
   --  Returns Busy without writing if another session writer holds the guard.
   --  Failure can leave unreferenced assets; they are not reclaimed here.
   --  An uncertain asset write prevents manifest publication. Uncertain from
   --  Save therefore concerns the final manifest, not an unreferenced asset.
   procedure Save
     (Parent, UUID : String; W : Revisions.Workspace; Assets : Raster_Set;
      Status : out Result);

   --  Same write as Save, for a caller already holding the session guard.
   procedure Save_Locked
     (Parent, UUID : String; W : Revisions.Workspace; Assets : Raster_Set;
      Status : out Result);

   --  With the source guard held, restore only the requested immutable
   --  revisions and their ancestors and verify their referenced rasters.
   procedure Load_Selection
     (Parent, UUID : String; Requested : Revisions.Recovery.References;
      W : in out Revisions.Workspace; Assets : in out Raster_Set;
      Status : out Result);

   --  Inspect a single UUID in the resolved session directory. A live log
   --  requires a matching header and a fully verified manifest and rasters.
   --  Orphan requires no matching log and can remove its flat sidecar.
   --  Apply=False is inspection only (may create the shared lock entry).
   --  Busy changes no data. Uncertain may have removed some/all candidates.
   procedure Reclaim
     (Parent, UUID : String; Orphan, Apply : Boolean;
      Report : out Reclaim_Report; Status : out Result);

   --  Tries the shared session guard once for the entire restore.
   --  A missing manifest returns Missing. Missing or invalid referenced
   --  assets return Invalid, with W and Assets unchanged. Restore drops
   --  transient Undo/Redo; it neither edits nor appends a revision.
   procedure Load
     (Parent, UUID : String; W : in out Revisions.Workspace;
      Assets : in out Raster_Set; Status : out Result);

   --  Caller already holds the shared session guard (e.g. editor admission).
   procedure Load_Locked
     (Parent, UUID : String; W : in out Revisions.Workspace;
      Assets : in out Raster_Set; Status : out Result);
end Coyote_Canvas.Store.Workspaces;
