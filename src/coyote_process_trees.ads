--  Coyote_Process_Trees — process discovery and descendant signalling.
--  Project: coyote

package Coyote_Process_Trees is

   type Process_Record is record
      Pid    : Integer;
      Parent : Integer;
   end record;

   type Process_Record_Array is array (Positive range <>) of Process_Record;
   type PID_Array is array (Positive range <>) of Integer;

   --  Parse a Linux /proc/<pid>/stat record.  False denotes malformed input
   --  and clears Parent_Pid to zero.
   function Parse_Stat
     (Line       : String;
      Pid        : Integer;
      Parent_Pid : out Integer) return Boolean;

   --  Return breadth-first descendants from a process snapshot.
   --  Root_Pid is included as a traversal sentinel even if not present;
   --  cycles are visited once.  Root_Pid <= 1 returns an empty result.
   function Descendants
     (Root_Pid : Integer;
      Records  : Process_Record_Array) return PID_Array;

   --  Best-effort discovery and signalling of a process group and descendants.
   --  The root group is signalled before nested descendant groups.
   procedure Signal_Group_Tree (Root_Pid : Integer; Signal : Integer);

end Coyote_Process_Trees;
