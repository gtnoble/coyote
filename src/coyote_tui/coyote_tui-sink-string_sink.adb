--  Coyote_TUI.Sink.String_Sink body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Characters.Latin_1;

package body Coyote_TUI.Sink.String_Sink is

   overriding
   procedure Put
     (S    : in out Instance;
      Text :        String)
   is
   begin
      Append (S.Buf, Text);
   end Put;

   overriding
   procedure New_Line (S : in out Instance) is
   begin
      Append (S.Buf, Ada.Characters.Latin_1.LF);
      S.Line_Count := S.Line_Count + 1;
   end New_Line;

   overriding
   procedure Attr_On
     (S : in out Instance;
      A :        Integer)
   is
      pragma Unreferenced (A);
   begin
      S.Attr_Depth := S.Attr_Depth + 1;
   end Attr_On;

   overriding
   procedure Attr_Off
     (S : in out Instance;
      A :        Integer)
   is
      pragma Unreferenced (A);
   begin
      S.Attr_Depth := S.Attr_Depth - 1;
   end Attr_Off;

   overriding
   procedure Color_On
     (S    : in out Instance;
      Pair :        Integer)
   is
      pragma Unreferenced (Pair);
   begin
      S.Attr_Depth := S.Attr_Depth + 1;
   end Color_On;

   overriding
   procedure Reset_Attrs (S : in out Instance) is
   begin
      S.Attr_Depth := 0;
   end Reset_Attrs;

   overriding
   procedure Move
     (S   : in out Instance;
      Row :        Natural;
      Col :        Natural)
   is
      pragma Unreferenced (Row, Col);
   begin
      null;
   end Move;

   overriding
   procedure Erase (S : in out Instance) is
   begin
      S.Buf        := Null_Unbounded_String;
      S.Line_Count := 0;
   end Erase;

   overriding
   procedure Refresh (S : in out Instance) is
      pragma Unreferenced (S);
   begin
      null;
   end Refresh;

   --  ── Inspection subprograms ────────────────────────────────────────────

   function Content (S : Instance) return String is
   begin
      return To_String (S.Buf);
   end Content;

   function Lines (S : Instance) return Natural is
   begin
      return S.Line_Count;
   end Lines;

   function Attrs_Balanced (S : Instance) return Boolean is
   begin
      return S.Attr_Depth = 0;
   end Attrs_Balanced;

   procedure Clear (S : in out Instance) is
   begin
      S.Buf        := Null_Unbounded_String;
      S.Line_Count := 0;
      S.Attr_Depth := 0;
   end Clear;

end Coyote_TUI.Sink.String_Sink;
