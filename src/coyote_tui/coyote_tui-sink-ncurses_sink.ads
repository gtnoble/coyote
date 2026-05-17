--  Coyote_TUI.Sink.Ncurses_Sink — production sink backed by a ncurses window.
--
--  This is the only file in the TUI subsystem that imports Coyote_Ncurses.
--  All other packages in Coyote_TUI are free of ncurses dependencies.
--
--  Win must be set before any output procedures are called.  Typically an
--  Instance is declared as a local variable in Do_Render and Win is passed
--  to Set_Window before the renderer is invoked.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_Ncurses;

package Coyote_TUI.Sink.Ncurses_Sink is

   type Instance is new Coyote_TUI.Sink.Instance with record
      Win : Coyote_Ncurses.Window := Coyote_Ncurses.Null_Window;
   end record;

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

end Coyote_TUI.Sink.Ncurses_Sink;
