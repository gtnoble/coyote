--  Coyote_TUI.Sink.Ncurses_Sink body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Latin_1;

package body Coyote_TUI.Sink.Ncurses_Sink is

   overriding
   procedure Put
     (S    : in out Instance;
      Text :        String)
   is
   begin
      Coyote_Ncurses.Waddstr (S.Win, Text);
   end Put;

   overriding
   procedure New_Line (S : in out Instance) is
   begin
      Coyote_Ncurses.Waddch (S.Win, Ada.Characters.Latin_1.LF);
   end New_Line;

   overriding
   procedure Attr_On
     (S : in out Instance;
      A :        Integer)
   is
   begin
      Coyote_Ncurses.Wattron (S.Win, A);
   end Attr_On;

   overriding
   procedure Attr_Off
     (S : in out Instance;
      A :        Integer)
   is
   begin
      Coyote_Ncurses.Wattroff (S.Win, A);
   end Attr_Off;

   overriding
   procedure Color_On
     (S    : in out Instance;
      Pair :        Integer)
   is
   begin
      Coyote_Ncurses.Wattron (S.Win, Coyote_Ncurses.Color_Pair (Pair));
   end Color_On;

   overriding
   procedure Reset_Attrs (S : in out Instance) is
   begin
      Coyote_Ncurses.Wattrset (S.Win, Coyote_Ncurses.A_Normal);
   end Reset_Attrs;

   overriding
   procedure Move
     (S   : in out Instance;
      Row :        Natural;
      Col :        Natural)
   is
   begin
      Coyote_Ncurses.Wmove (S.Win, Row, Col);
   end Move;

   overriding
   procedure Erase (S : in out Instance) is
   begin
      Coyote_Ncurses.Werase (S.Win);
   end Erase;

   overriding
   procedure Refresh (S : in out Instance) is
   begin
      Coyote_Ncurses.Wnoutrefresh (S.Win);
   end Refresh;

end Coyote_TUI.Sink.Ncurses_Sink;
