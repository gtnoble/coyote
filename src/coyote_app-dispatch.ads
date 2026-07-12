--  Coyote_App.Dispatch — live LLM event dispatch and window rendering.
--
--  Dispatch_Event maps incoming native LLM events to frontend mutations
--  via the abstract Coyote_App.Frontend.Instance'Class interface.
--  Format_Status builds the one-line status string shown in line 1 of the
--  window body.  Append_Live_Turn_Footer appends the end-of-turn footer.
--  Open_Sub_Window creates a named child acme window.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Acme.Window;
with Coyote_App.Frontend;
with LLM.Events;
with Nine_P.Client;

package Coyote_App.Dispatch is

   --  Build the one-line status string placed in the first body line.
   function Format_Status
     (State : App_State;
      Extra : String := "ready") return String;

   --  Dynamic tag modes for Update_Tag.
   type Tag_Mode is (Idle_Tag, Running_Tag, Armed_Tag, Paused_Tag);

   --  Replace the acme window tag with the button set appropriate for Mode,
   --  appending Suffix (e.g. " Models Sessions Thinking Stats").
   --
   --     Idle_Tag    →  | Send Steer New Compact Clear Continue<Suffix>
   --     Running_Tag →  | Stop Steer Pause<Suffix>
   --     Armed_Tag   →  | Stop Steer Pausing<Suffix>
   --     Paused_Tag  →  | Stop Steer Send Resume<Suffix>
   procedure Update_Tag
     (Win    : in out Acme.Window.Win;
      FS     : not null access Nine_P.Client.Fs;
      Mode   : Tag_Mode;
      Suffix : String);

   --  Append the live end-of-turn footer using the current values in State,
   --  and increment State.Turn_Count.
   procedure Append_Live_Turn_Footer
     (Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State;
      PID      : String);

   --  Append a step-level turn footer for an intermediate assistant
   --  message (stop = toolUse) within a turn.  Uses the step-suffix
   --  fork token format (coyote-fork+PID/UUID/N/S) and a single-line
   --  separator to visually distinguish step boundaries from full-turn
   --  boundaries.  Does not increment Turn_Count.
   procedure Append_Step_Footer
     (Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State;
      PID      : String);

   --  Create a new acme window named Parent/Sub, write Content, mark clean.
   procedure Open_Sub_Window
     (FS      : not null access Nine_P.Client.Fs;
      Parent  : String;
      Sub     : String;
      Content : String);

   --  Dispatch one native agent event to the appropriate frontend mutation.
   --  Section tracks the current streaming content kind and is updated
   --  in place.  PID is this process's PID as a decimal string.
   procedure Dispatch_Event
     (Event    : LLM.Events.Agent_Event'Class;
      Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State;
      Section  : in out Section_Kind;
      PID      : String);

end Coyote_App.Dispatch;
