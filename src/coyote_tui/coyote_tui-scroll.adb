--  Coyote_TUI.Scroll body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package body Coyote_TUI.Scroll is

   --  ── Advance ──────────────────────────────────────────────────────────

   function Advance
     (Snap    : Vector;
      Heights : Height_Array;
      C       : Cursor;
      Shift   : Integer) return Cursor
   is
      Count : constant Natural := Natural (Snap.Length);
   begin
      if Count = 0 then
         return Following_Cursor;
      end if;

      --  Materialise an explicit cursor when in follow mode.
      declare
         FC  : constant Cursor :=
                 (if Viewport.Is_Following (C)
                  then Follow_Start (Snap, Heights, 1)  --  top of last seg
                  else C);
         Seg : Natural  := (if FC.Seg = 0 then Count else FC.Seg);
         Off : Integer  := Integer (FC.Offset) + Shift;
      begin
         --  Walk segments forward.
         while Off >= Eff_Height (Heights, Seg) and then Seg < Count loop
            Off := Off - Eff_Height (Heights, Seg);
            Seg := Seg + 1;
         end loop;
         --  Clamp at end.
         if Off >= Eff_Height (Heights, Seg) then
            Off := Eff_Height (Heights, Seg) - 1;
         end if;
         --  Walk segments backward.
         while Off < 0 and then Seg > 1 loop
            Seg := Seg - 1;
            Off := Off + Eff_Height (Heights, Seg);
         end loop;
         --  Clamp at beginning.
         if Off < 0 then
            Off := 0;
         end if;
         if Seg < 1 then
            Seg := 1;
         end if;
         return (Seg => Seg, Offset => Natural (Off));
      end;
   end Advance;

   --  ── Total_Lines ──────────────────────────────────────────────────────

   function Total_Lines
     (Snap    : Vector;
      Heights : Height_Array) return Natural
   is
      Total : Natural := 0;
      Count : constant Natural := Natural (Snap.Length);
   begin
      for I in 1 .. Count loop
         Total := Total + Eff_Height (Heights, I);
      end loop;
      return Total;
   end Total_Lines;

   --  ── Follow_Start ─────────────────────────────────────────────────────

   function Follow_Start
     (Snap         : Vector;
      Heights      : Height_Array;
      Visible_Rows : Positive) return Cursor
   is
      Count     : constant Natural := Natural (Snap.Length);
      Lines_Acc : Natural := 0;
      Start_Seg : Natural := Count;
   begin
      if Count = 0 then
         return Following_Cursor;
      end if;
      for J in reverse 1 .. Count loop
         Lines_Acc := Lines_Acc + Eff_Height (Heights, J);
         if Lines_Acc > Visible_Rows then
            --  J's content spills above the top of the window.
            --  Skip (Lines_Acc - Visible_Rows) lines of J.
            declare
               Skip : constant Natural := Lines_Acc - Visible_Rows;
            begin
               return (Seg => J, Offset => Skip);
            end;
         end if;
         Start_Seg := J;
      end loop;
      return (Seg => Start_Seg, Offset => 0);
   end Follow_Start;

   --  ── Cursor_To_Line ───────────────────────────────────────────────────

   function Cursor_To_Line
     (Snap    : Vector;
      Heights : Height_Array;
      C       : Cursor) return Positive
   is
      pragma Unreferenced (Snap);
      Line : Natural := 0;
   begin
      if Viewport.Is_Following (C) or else C.Seg = 0 then
         return 1;
      end if;
      for I in 1 .. C.Seg - 1 loop
         Line := Line + Eff_Height (Heights, I);
      end loop;
      return Positive'Max (1, Line + C.Offset + 1);
   end Cursor_To_Line;

   --  ── Seg_At_Line ──────────────────────────────────────────────────────

   function Seg_At_Line
     (Snap    : Vector;
      Heights : Height_Array;
      Line    : Positive) return Positive
   is
      Count : constant Natural := Natural (Snap.Length);
      Acc   : Natural := 0;
   begin
      if Count = 0 then
         return 1;
      end if;
      for I in 1 .. Count loop
         Acc := Acc + Eff_Height (Heights, I);
         if Acc >= Line then
            return I;
         end if;
      end loop;
      return Count;
   end Seg_At_Line;

   --  ── Next_Of_Kind ─────────────────────────────────────────────────────

   function Next_Of_Kind
     (Snap : Vector;
      From : Positive;
      Kind : Segment_Kind) return Natural
   is
      Count : constant Natural := Natural (Snap.Length);
   begin
      for I in From .. Count loop
         if Snap (I).Kind = Kind then
            return I;
         end if;
      end loop;
      return 0;
   end Next_Of_Kind;

   --  ── Prev_Of_Kind ─────────────────────────────────────────────────────

   function Prev_Of_Kind
     (Snap : Vector;
      From : Positive;
      Kind : Segment_Kind) return Natural
   is
   begin
      if From <= 1 then
         return 0;
      end if;
      for I in reverse 1 .. From - 1 loop
         if Snap (I).Kind = Kind then
            return I;
         end if;
      end loop;
      return 0;
   end Prev_Of_Kind;

end Coyote_TUI.Scroll;
