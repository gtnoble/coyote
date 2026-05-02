--  LLM.SSE — incremental Server-Sent Events parser.
--
--  The parser accepts arbitrary byte chunks and yields complete SSE events
--  once a blank-line terminator is seen.  It is shared by streaming OpenAI
--  and Anthropic provider adapters.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package LLM.SSE is

   type Parser is limited private;

   --  Feed raw bytes to the parser.
   --  Data may contain complete events, multiple events, or partial
   --  fragments.
   procedure Feed (P : in out Parser; Data : String);

   --  Retrieve the next complete SSE event, if one is buffered.
   --  Returns False when no complete event is available.
   --  Event_Name is "" for data-only events.
   --  Data is the raw concatenated data payload.
   --  "ping" events are consumed silently and not returned.
   function Next_Event
     (P          : in out Parser;
      Event_Name :    out Ada.Strings.Unbounded.Unbounded_String;
      Data       :    out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;

   --  Reset the parser to its initial empty state.
   procedure Reset (P : in out Parser);

private

   type Parser is limited record
      Buffer : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end LLM.SSE;
