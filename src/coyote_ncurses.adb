--  Coyote_Ncurses body — Ada convenience wrappers over the imported C
--  primitives.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package body Coyote_Ncurses is

   --  ── Waddstr ───────────────────────────────────────────────────────────

   procedure Waddstr (Win : Window; Text : String) is
   begin
      if Text'Length > 0 then
         Waddnstr (Win, Text, Text'Length);
      end if;
   end Waddstr;

   --  ── Waddch ────────────────────────────────────────────────────────────

   procedure Waddch (Win : Window; Ch : Character) is
      S : constant String (1 .. 1) := (1 => Ch);
   begin
      Waddnstr (Win, S, 1);
   end Waddch;

end Coyote_Ncurses;
