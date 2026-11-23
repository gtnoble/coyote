with Ada.Finalization;
with Ada.Strings.Unbounded;
with Interfaces;
with Interfaces.C;
with Coyote_Canvas.Rasters;

--  Private Canvas transport and checked session lifecycle operations.
package Coyote_Canvas.Store is
   --  Allow all retained samples even with four v5 round-trip fields.
   MAX_MANIFEST_BYTES : constant := 16 * 1_024 * 1_024;
   MAX_ASSET_BYTES    : constant := 4 * Rasters.MAX_PIXELS;
   type Result is (Ok, Missing, Busy, Invalid, IO_Error, Uncertain);

   --  Parent must be a trusted, resolved absolute session directory.
   --  UUID is a canonical lowercase UUID. Only its private sibling sidecar
   --  is accessed. Reads never return partial bytes and do not take a lock.
   procedure Read
     (Parent, UUID : String; Data : out Ada.Strings.Unbounded.Unbounded_String;
      Status : out Result);

   --  This serializes individual manifest writes, NOT session writers.
   --  Uncertain means rename succeeded but directory fsync failed: the new
   --  version may be visible but is not confirmed durable. All other failures
   --  leave the previous manifest intact. No JSON validation occurs here.
   procedure Write (Parent, UUID, Data : String; Status : out Result);
   --  Raw immutable asset I/O. The caller verifies dimensions and digest.
   --  Read_Asset caps the file at Expected_Bytes and rejects short reads.
   procedure Read_Asset
     (Parent, UUID, Digest : String; Expected_Bytes : Positive;
      Data : out Ada.Strings.Unbounded.Unbounded_String; Status : out Result);

   --  Never replaces a different file at the same digest name.
   procedure Write_Asset
     (Parent, UUID, Digest, Data : String; Status : out Result);
   --  The source tile descriptor remains caller-owned. On success the
   --  digest names a durable immutable tiled asset. An uncertain write
   --  must not be referenced until a successful retry.
   subtype Tile_Digest is String (1 .. 64);
   procedure Write_Tile
     (Parent, UUID : String; FD : Interfaces.C.int;
      Digest : out Tile_Digest; Status : out Result);

   --  Verify the content digest and layout before handing over an open
   --  read-only descriptor. The caller closes it; failure returns -1.
   procedure Open_Tile
     (Parent, UUID, Digest : String; FD : out Interfaces.C.int;
      Status : out Result);
   procedure Close_Tile (FD : in out Interfaces.C.int);

   --  Exclusive GTK ownership, independent of the per-write lock. Reads
   --  remain possible without a lease. This does not lock the JSONL writer.
   type Writer_Lease is limited private;
   procedure Claim (Parent, UUID : String; Lease : in out Writer_Lease;
                    Status : out Result);
   procedure Release (Lease : in out Writer_Lease);
   procedure Move (Target, Source : in out Writer_Lease);

   --  Lifecycle operations require the corresponding session guard. An
   --  empty Log_Name is only for rollback of a newly reserved fork. An
   --  empty UUID removes a legacy JSONL file with no Canvas binding.
   procedure Reserve_Fork (Parent, UUID : String; Status : out Result);
   procedure Remove_Session
     (Parent, UUID, Log_Name : String; Status : out Result);

   type Reclaim_Report is record
      Files : Natural := 0;
      Bytes : Interfaces.Unsigned_64 := 0;
   end record;

private
   --  Only Workspaces may supply a validated keep set. The shared session
   --  guard covers both calls and verification of the committed workspace.
   procedure Reclaim_Header
     (Parent, UUID : String; Orphan : Boolean;
      Header : out Ada.Strings.Unbounded.Unbounded_String; Status : out Result);
   procedure Reclaim_Checked
     (Parent, UUID, Manifest, Keep : String; Orphan, Apply : Boolean;
      Report : out Reclaim_Report; Status : out Result);

   type Writer_Lease is new Ada.Finalization.Limited_Controlled with record
      FD : Interfaces.C.int := Interfaces.C.int'First;
   end record;
   overriding procedure Finalize (Lease : in out Writer_Lease);
end Coyote_Canvas.Store;
