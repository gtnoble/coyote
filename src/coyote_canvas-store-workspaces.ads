with Coyote_Canvas.Revisions;

--  Synchronous durability API for a stable workspace and its Originals.
--  The caller supplies the session directory and serializes session writers.
package Coyote_Canvas.Store.Workspaces is
   MAX_RASTER_BYTES : constant := 128 * 1_024 * 1_024;

   --  Only imported Original indices have bytes: tightly packed, top-down
   --  straight RGBA8 at the Original extent. RGB sources use opaque alpha.
   --  All other entries are empty. Assets are immutable for each call.
   type Raster_Set is array (Positive range 1 .. Revisions.MAX_REVISIONS)
     of Ada.Strings.Unbounded.Unbounded_String;

   --  Publishes and synchronizes all assets before replacing the manifest.
   --  Failure can leave unreferenced assets; they are not reclaimed here.
   --  An uncertain asset write prevents manifest publication. Uncertain from
   --  Save therefore concerns the final manifest, not an unreferenced asset.
   procedure Save
     (Parent, UUID : String; W : Revisions.Workspace; Assets : Raster_Set;
      Status : out Result);

   --  A missing manifest returns Missing. Missing or invalid referenced
   --  assets return Invalid, with W and Assets unchanged. Restore drops
   --  transient Undo/Redo; it neither edits nor appends a revision.
   procedure Load
     (Parent, UUID : String; W : in out Revisions.Workspace;
      Assets : in out Raster_Set; Status : out Result);
end Coyote_Canvas.Store.Workspaces;
