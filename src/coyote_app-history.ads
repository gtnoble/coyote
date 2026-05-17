--  Coyote_App.History — session JSONL file replay via Frontend'Class.
--
--  Render_Session_History reads a saved session file and replays
--  its full conversation history into any Frontend'Class instance.
--  See the body for the two-pass rendering algorithm.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_App.Frontend;

package Coyote_App.History is

   --  Read the JSONL session file for UUID and replay the full conversation
   --  history through Frontend.  Searches all session directories.
   --  Restores State.Turn_Count and State.Turn_Tokens from the replayed
   --  history so that subsequent live turns are numbered correctly.
   --  Calls Frontend.Append_Notice (Error, …) if the session file cannot
   --  be located or read.
   --
   --  PID is embedded in plumb tokens inside tool-call boxes (acme path
   --  passes My_PID; plain / GUI callers omit it or pass "" to suppress
   --  the token).
   procedure Render_Session_History
     (UUID     : String;
      Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State;
      PID      : String := "");

end Coyote_App.History;
