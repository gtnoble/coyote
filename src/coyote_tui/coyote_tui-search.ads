--  Coyote_TUI.Search — pure search operations.
--
--  Compute_Matches performs a case-insensitive scan of all segment Content
--  fields and returns one Match_Record per matching segment.
--  Advance moves the search cursor through the match list with wrapping.
--
--  No protected objects, no tasks, no I/O.  Fully testable in AUnit.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Coyote_TUI.Segments;

package Coyote_TUI.Search is

   --  ── Match record ─────────────────────────────────────────────────────

   type Match_Record is record
      Seg_Index   : Positive := 1;
      --  0-based byte offset of the first matching byte within the segment's
      --  Content string (relative to Content'First).
      Byte_Offset : Natural  := 0;
      Match_Len   : Natural  := 0;
   end record;

   package Match_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Match_Record);

   subtype Match_Vector is Match_Vectors.Vector;

   --  ── Compute_Matches ──────────────────────────────────────────────────
   --
   --  Scan Snap for segments whose Content contains Term (case-insensitive).
   --  Returns one Match_Record per matching segment (the first occurrence
   --  within the segment).  Returns an empty vector when Term is empty.
   function Compute_Matches
     (Snap : Coyote_TUI.Segments.Vector;
      Term : String) return Match_Vector;

   --  ── Advance ──────────────────────────────────────────────────────────
   --
   --  Move the 1-based search cursor by Dir (+1 forward, -1 backward),
   --  wrapping around the match list.  Returns 0 when Matches is empty.
   function Advance
     (Matches : Match_Vector;
      Cursor  : Natural;
      Dir     : Integer) return Natural;

end Coyote_TUI.Search;
