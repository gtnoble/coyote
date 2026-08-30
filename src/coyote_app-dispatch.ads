--  Coyote_App.Dispatch — live LLM event dispatch and window rendering.
--
--  Dispatch_Event maps incoming native LLM events to frontend mutations
--  through the abstract Coyote_App.Frontend.Instance'Class interface.
--  Format_Status builds the status string used by supported frontends.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Coyote_App.Frontend;
with LLM.Events;

package Coyote_App.Dispatch is

   --  Build the status string for the current application state.
   function Format_Status
     (State : App_State;
      Extra : String := "ready") return String;

   --  Append the live end-of-turn footer using the current values in State,
   --  and increment State.Turn_Count.
   procedure Append_Live_Turn_Footer
     (Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State);

   --  Append a step-level turn footer for an intermediate assistant
   --  message (stop = toolUse) within a turn.  Does not increment
   --  Turn_Count.
   procedure Append_Step_Footer
     (Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State);

   --  Dispatch one native agent event to the appropriate frontend mutation.
   --  Section tracks the current streaming content kind and is updated
   --  in place.
   procedure Dispatch_Event
     (Event    : LLM.Events.Agent_Event'Class;
      Frontend : in out Coyote_App.Frontend.Instance'Class;
      State    : in out App_State;
      Section  : in out Section_Kind);

end Coyote_App.Dispatch;
