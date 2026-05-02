--  LLM.Agent.Pi_Adapter — native-event to pi-RPC JSON bridge.
--
--  Serialises native LLM.Events values into the JSON event strings already
--  consumed by Pi_Acme_App.Dispatch.Dispatch_Pi_Event.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with LLM.Events;

package LLM.Agent.Pi_Adapter is

   --  Convert a native agent event to the JSON string expected by the
   --  existing pi RPC dispatcher.
   --
   --  Returns the empty string for event kinds that have no pi-protocol
   --  equivalent.
   function To_Pi_Json
     (E : LLM.Events.Agent_Event'Class) return String;

end LLM.Agent.Pi_Adapter;
