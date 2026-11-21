--  Internal versioned metadata snapshot. Background indices are retained;
--  the caller resolves and validates raster assets.
package Coyote_Canvas.Revisions.Recovery is
   Invalid_Snapshot : exception;

   subtype Asset_Digest is String (1 .. 64);
   NO_ASSET : constant Asset_Digest := (others => ' ');
   type Asset_References is array (Positive range 1 .. MAX_REVISIONS)
     of Asset_Digest;

   --  Saves checkpoints and the current draft without checkpointing it.
   --  Undo and redo are intentionally transient. No file I/O occurs here.
   function Encode (W : Workspace) return String;
   function Encode
     (W : Workspace; Assets : Asset_References) return String;

   --  Validate into a temporary workspace before replacing W. Malformed or
   --  unsupported input raises Invalid_Snapshot and leaves W unchanged.
   procedure Decode (Data : String; W : in out Workspace);
   procedure Decode
     (Data : String; W : in out Workspace; Assets : out Asset_References);

   --  Deep-copy saved revisions and the current draft, dropping transient
   --  history. Allocation or validation failure leaves Target unchanged.
   procedure Copy (Target : in out Workspace; Source : Workspace);

   --  Publish a completely validated candidate without allocating.
   procedure Move (Target, Source : in out Workspace);
end Coyote_Canvas.Revisions.Recovery;
