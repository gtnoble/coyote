--  Coyote_TUI.Segments — conversation segment data types.
--
--  This package defines the complete set of data types that model the
--  conversation buffer.  It has no body and no dependencies beyond the
--  standard library.  Every type here is safe to use in pure, concurrent,
--  and test contexts without restriction.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Coyote_TUI.Segments is

   --  ── Segment classification ────────────────────────────────────────────

   type Segment_Kind is
     (User_Turn,       --  prompt text typed by the user
      Steer_Turn,      --  steering prompt sent while agent is running
      Assistant_Text,  --  streaming or complete assistant message
      Thinking_Block,  --  model reasoning (always dim)
      Tool_Segment,    --  a tool call (header + args + status line)
      Turn_Footer,     --  per-turn stats/separator line
      System_Notice);  --  info / warning / error from the agent loop

   type Tool_Run_Status is (Running, Success, Error, Cancelled);

   type Notice_Kind is (Info, Warning, Error);

   --  ── Segment record ────────────────────────────────────────────────────
   --
   --  All fields are always present; discriminants were dropped because
   --  different segment kinds share Content in meaningfully different ways
   --  and a simple record is easier to copy and update inside protected
   --  objects.  Unused fields for a given Kind are left at their defaults.
   --
   --  NOTE: Cached_Height is deliberately absent.  Height measurement is
   --  the renderer's concern; it lives in Coyote_TUI.Nav_State.Height_Cache.

   type Segment is record
      Kind      : Segment_Kind := System_Notice;
      Content   : Ada.Strings.Unbounded.Unbounded_String;
      --  True once the full text of an Assistant_Text or Thinking_Block has
      --  been received.  False while streaming is still in progress.
      Complete  : Boolean      := False;
      --  Notice severity (only meaningful for System_Notice segments).
      Sev       : Notice_Kind  := Info;
      --  Tool-call fields (only meaningful for Tool_Segment).
      Tool_Name : Ada.Strings.Unbounded.Unbounded_String;
      Tool_Args : Ada.Strings.Unbounded.Unbounded_String;
      Tool_Id   : Ada.Strings.Unbounded.Unbounded_String;
      T_Status  : Tool_Run_Status := Running;
   end record;

   --  ── Segment vector ────────────────────────────────────────────────────

   package Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Segment);

   subtype Vector is Vectors.Vector;

end Coyote_TUI.Segments;
