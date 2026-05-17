--  Coyote_TUI.Search body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Coyote_TUI.Search is


   --  ── Compute_Matches ──────────────────────────────────────────────────

   function Compute_Matches
     (Snap : Coyote_TUI.Segments.Vector;
      Term : String) return Match_Vector
   is
      use Ada.Characters.Handling;
      use Ada.Strings.Fixed;
      Matches : Match_Vector;
      UC_Term : constant String := To_Upper (Term);
   begin
      if UC_Term'Length = 0 then
         return Matches;
      end if;
      for I in 1 .. Natural (Snap.Length) loop
         declare
            Content    : constant String :=
              To_String (Snap (I).Content);
            UC_Content : constant String := To_Upper (Content);
            Pos        : constant Natural := Index (UC_Content, UC_Term);
         begin
            if Pos > 0 then
               Matches.Append
                 ((Seg_Index   => I,
                   Byte_Offset => Pos - UC_Content'First,
                   Match_Len   => UC_Term'Length));
            end if;
         end;
      end loop;
      return Matches;
   end Compute_Matches;

   --  ── Advance ──────────────────────────────────────────────────────────

   function Advance
     (Matches : Match_Vector;
      Cursor  : Natural;
      Dir     : Integer) return Natural
   is
      N : constant Natural := Natural (Matches.Length);
   begin
      if N = 0 then
         return 0;
      end if;
      declare
         Current : constant Natural := (if Cursor = 0 then 1 else Cursor);
      begin
         return ((Current - 1 + Dir + N) mod N) + 1;
      end;
   end Advance;

end Coyote_TUI.Search;
