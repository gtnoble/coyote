--  Coyote_TUI.Sink.String_Sink — test-double sink that accumulates output.
--
--  Use in AUnit tests by instantiating Instance, passing it to any
--  renderer call, then inspecting Content, Lines, and Attrs_Balanced.
--
--  Attributes are tracked for balance: every Attr_On increments
--  Active_Attr_Count and every Attr_Off decrements it.  Attrs_Balanced
--  returns True iff the count is zero at the time of the call.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package Coyote_TUI.Sink.String_Sink is

   type Instance is new Coyote_TUI.Sink.Instance with private;

   overriding
   procedure Put
     (S    : in out Instance;
      Text :        String);

   overriding
   procedure New_Line (S : in out Instance);

   overriding
   procedure Attr_On
     (S : in out Instance;
      A :        Integer);

   overriding
   procedure Attr_Off
     (S : in out Instance;
      A :        Integer);

   overriding
   procedure Color_On
     (S    : in out Instance;
      Pair :        Integer);

   overriding
   procedure Reset_Attrs (S : in out Instance);

   overriding
   procedure Move
     (S   : in out Instance;
      Row :        Natural;
      Col :        Natural);

   overriding
   procedure Erase (S : in out Instance);

   overriding
   procedure Refresh (S : in out Instance);

   --  ── Inspection subprograms ────────────────────────────────────────────

   --  Full accumulated output as a string.
   function Content (S : Instance) return String;

   --  Number of New_Line calls (proxy for display lines emitted).
   function Lines (S : Instance) return Natural;

   --  True iff every Attr_On has been matched by an Attr_Off.
   function Attrs_Balanced (S : Instance) return Boolean;

   --  Reset all accumulated state.
   procedure Clear (S : in out Instance);

private

   type Instance is new Coyote_TUI.Sink.Instance with record
      Buf        : Ada.Strings.Unbounded.Unbounded_String;
      Line_Count : Natural := 0;
      Attr_Depth : Integer := 0;
   end record;

end Coyote_TUI.Sink.String_Sink;
