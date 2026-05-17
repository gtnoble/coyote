--  Coyote_TUI.Segment_Ops — pure operations on Segment vectors.
--
--  All subprograms operate on plain (non-protected) Segment vectors.
--  No tasks, no protected objects, no I/O.  The protected wrapper
--  (Coyote_TUI.Store) delegates entirely to these subprograms.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_TUI.Segments;

package Coyote_TUI.Segment_Ops is

   use Coyote_TUI.Segments;

   --  Append a new segment to Vec.
   procedure Append_New
     (Vec : in out Vector;
      S   :        Segment);

   --  Append Text to the Content of the last segment in Vec.
   --  No-op when Vec is empty.
   procedure Update_Last_Content
     (Vec  : in out Vector;
      Text :        String);

   --  Mark the last segment in Vec as Complete.
   --  No-op when Vec is empty.
   procedure Set_Last_Complete (Vec : in out Vector);

   --  Find the most-recent Tool_Segment whose Tool_Id matches Tool_Id,
   --  set its T_Status to Stat, and overwrite its Content with Result.
   --  No-op when not found.
   procedure End_Tool
     (Vec     : in out Vector;
      Tool_Id :        String;
      Result  :        String;
      Stat    :        Tool_Run_Status);

   --  Return the index (1-based) of the most-recent Tool_Segment in Vec
   --  whose Tool_Id matches Tool_Id, or 0 if not found.
   function Find_Tool
     (Vec     : Vector;
      Tool_Id : String) return Natural;

   --  Return the Kind of the last segment, or System_Notice when Vec is empty.
   function Last_Kind (Vec : Vector) return Segment_Kind;

end Coyote_TUI.Segment_Ops;
