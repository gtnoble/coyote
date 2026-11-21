with Ada.Finalization;
private with Interfaces.C;

--  Cooperative per-session write exclusion. Lock files must not be removed:
--  removing a held inode would let a second writer acquire a different one.
package Coyote_Session_Transactions is
   type Result is (Acquired, Busy, Unavailable);
   type Guard is limited private;

   --  Parent is the trusted, resolved directory containing the session.
   --  Id is its canonical storage identity. Try_Lock never waits for a peer.
   procedure Try_Lock (Parent, Id : String; Lock : in out Guard;
                       Status : out Result);
   procedure Unlock (Lock : in out Guard);

   function Canonical_UUID (Id : String) return Boolean;

   --  Resolve the actual JSONL path so different names for one file use the
   --  same guard. Standard UUID filenames, including timestamped names, use
   --  the UUID; other legacy filenames use a digest of the full basename.
   function Resolve (Path : String) return String;
   function Identity (Resolved_Path : String) return String;

   --  Create a private sibling staging file and publish it without replacing
   --  an existing destination. Hold the destination guard throughout.
   function Create_Stage (Resolved_Path : String) return String;
   procedure Publish (Stage, Resolved_Path : String; Status : out Result);

   --  Replace a checked regular log under its existing guard.
   procedure Replace_Log (Stage, Resolved_Path : String; Status : out Result;
                          Uncertain : out Boolean);
   function Sync_Log (Resolved_Path : String) return Boolean;

   --  A bounded retry for agent-task writes, not GTK callbacks.
   procedure Wait_For_Lock (Resolved_Path : String; Lock : in out Guard;
                            Status : out Result);

private
   type Guard is new Ada.Finalization.Limited_Controlled with record
      FD : Interfaces.C.int := Interfaces.C.int'First;
   end record;
   overriding procedure Finalize (Lock : in out Guard);
end Coyote_Session_Transactions;
