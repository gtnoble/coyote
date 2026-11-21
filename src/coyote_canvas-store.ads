with Ada.Finalization;
with Ada.Strings.Unbounded;
private with Interfaces.C;

--  Private manifest and asset transport. No session lifecycle hooks.
package Coyote_Canvas.Store is
   MAX_MANIFEST_BYTES : constant := 12 * 1_024 * 1_024;
   MAX_ASSET_BYTES    : constant := 64 * 1_024 * 1_024;
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
   --  Exclusive GTK ownership, independent of the per-write lock. Reads
   --  remain possible without a lease. This does not lock the JSONL writer.
   type Writer_Lease is limited private;
   procedure Claim (Parent, UUID : String; Lease : in out Writer_Lease;
                    Status : out Result);
   procedure Release (Lease : in out Writer_Lease);
   procedure Move (Target, Source : in out Writer_Lease);

private
   type Writer_Lease is new Ada.Finalization.Limited_Controlled with record
      FD : Interfaces.C.int := Interfaces.C.int'First;
   end record;
   overriding procedure Finalize (Lease : in out Writer_Lease);
end Coyote_Canvas.Store;
