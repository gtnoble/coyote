--  Internal versioned metadata snapshot. Background indices are retained;
--  the caller must resolve and validate the corresponding raster assets.
package Coyote_Canvas.Revisions.Recovery is
   Invalid_Snapshot : exception;

   --  Saves checkpoints and the current draft without checkpointing it.
   --  Undo and redo are intentionally transient. No file I/O occurs here.
   function Encode (W : Workspace) return String;

   --  Validate into a temporary workspace before replacing W. Malformed or
   --  unsupported input raises Invalid_Snapshot and leaves W unchanged.
   procedure Decode (Data : String; W : in out Workspace);
end Coyote_Canvas.Revisions.Recovery;
