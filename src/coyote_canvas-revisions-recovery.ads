--  Internal versioned metadata snapshot. Background indices are retained;
--  the caller resolves and validates raster assets.
package Coyote_Canvas.Revisions.Recovery is
   Invalid_Snapshot : exception;

   subtype Asset_Digest is String (1 .. 64);
   NO_ASSET : constant Asset_Digest := (others => ' ');
   type Asset_References is array (Positive range 1 .. MAX_REVISIONS)
     of Asset_Digest;
   subtype Tile_References is Asset_References;

   --  Saves checkpoints and the current draft without checkpointing it.
   --  Undo and redo are intentionally transient. No file I/O occurs here.
   function Encode (W : Workspace) return String;
   function Encode
     (W : Workspace; Assets : Asset_References) return String;
   function Encode
     (W : Workspace; Assets : Asset_References; Tiles : Tile_References)
      return String;

   --  Validate into a temporary workspace before replacing W. Malformed or
   --  unsupported input raises Invalid_Snapshot and leaves W unchanged.
   procedure Decode (Data : String; W : in out Workspace);
   procedure Decode
     (Data : String; W : in out Workspace; Assets : out Asset_References);
   procedure Decode
     (Data : String; W : in out Workspace; Assets : out Asset_References;
      Tiles : out Tile_References);

   --  Deep-copy saved revisions and the current draft, dropping transient
   --  history. Allocation or validation failure leaves Target unchanged.
   procedure Copy (Target : in out Workspace; Source : Workspace);

   type Revision_Mapping is array (Positive range 1 .. MAX_REVISIONS)
     of Revision_Id;
   type Reference is record
      Drawing, Revision : Stable_Id;
   end record;
   type References is array (Positive range <>) of Reference;

   --  Keep the requested checkpoints and their ancestors, preserving their
   --  stable keys. Map destination indices to source indices. The new draft
   --  starts unmodified at the newest retained checkpoint.
   procedure Select_Revisions
     (Source : Workspace; Requested : References; Target : in out Workspace;
      Source_Ids : out Revision_Mapping);

   --  Adopt only the revision list of a copy extended by Add_Originals.
   procedure Adopt_Added_Originals (Target, Source : in out Workspace);

   --  Publish a completely validated candidate without allocating.
   procedure Move (Target, Source : in out Workspace);
end Coyote_Canvas.Revisions.Recovery;
