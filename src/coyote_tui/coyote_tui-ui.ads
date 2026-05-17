--  Coyote_TUI.UI — terminal input and render task.
--
--  UI_Task_T owns all ncurses window state and is the only task that may
--  call ncurses functions.  It receives state access through discriminants
--  so that two TUI instances can coexist without sharing global variables.
--
--  Start must be called once after the task is created; the task then
--  enters its main loop (poll input → dispatch keys → render on request).
--  It terminates when Nav.Is_Stopped returns True.
--
--  The task uses select/terminate before accepting Start so that if Create
--  is never called (e.g. in unit tests), the Ada runtime can terminate it
--  cleanly without hanging.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_TUI.Store;
with Coyote_TUI.Prompt_Queue;
with Coyote_TUI.Nav_State;

package Coyote_TUI.UI is

   task type Task_T
     (Conv : not null access Coyote_TUI.Store.Conversation;
      PQ   : not null access Coyote_TUI.Prompt_Queue.Queue;
      Nav  : not null access Coyote_TUI.Nav_State.State)
   is
      entry Start (Win_Name : String; Use_Color : Boolean);
   end Task_T;

   type Task_Access is access Task_T;

end Coyote_TUI.UI;
