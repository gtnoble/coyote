with Ada.Strings.Unbounded;

--  Internal manifest file transport. No GTK or session lifecycle hooks.
package Coyote_Canvas.Store is
   MAX_MANIFEST_BYTES : constant := 12 * 1_024 * 1_024;
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
end Coyote_Canvas.Store;
