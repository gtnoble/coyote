--  Coyote_App.Frontend — abstract frontend interface.
--
--  All rendering of LLM agent events is routed through this interface.
--  Concrete implementations are:
--    Coyote_App.Frontend.Acme  — acme window via 9P (current default)
--    Coyote_App.Frontend.GUI   — GTK3 graphical window
--    Coyote_App.Frontend.Plain — line-oriented plain-text (pipe / --one-shot)
--
--  Design notes:
--
--    * Dispatch_Event (Coyote_App.Dispatch) takes an Instance'Class reference
--      and calls only the primitives defined here.  No Acme.Window imports
--      appear in Dispatch.
--
--    * The interface is deliberately at a higher level than raw text append:
--      Begin_Tool / End_Tool carry structured data so the GUI can maintain
--      a typed conversation buffer, while the Acme implementation simply
--      formats its existing glyph-based text from those arguments.
--
--    * All primitives are called from a single task (Agent_Task inside
--      Coyote_App.Run).  Implementations need not be internally thread-safe
--      with respect to these primitives, but they may have their own
--      concurrent internal tasks (e.g. a GTK idle callback).
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_App.Frontend is

   --  ── Instance ──────────────────────────────────────────────────────────
   --
   --  Root abstract type.  Extend with private implementation data in each
   --  concrete child package.

   type Instance is abstract tagged limited null record;
   type Instance_Access is access all Instance'Class;

   --  ── Status line ───────────────────────────────────────────────────────
   --
   --  Update the persistent one-line status display (line 1 in acme;
   --  bottom status bar in the GUI).  Text is already formatted by
   --  Coyote_App.Dispatch.Format_Status.

   procedure Set_Status
     (F    : in out Instance;
      Text : in     String) is abstract;

   --  ── Run mode ──────────────────────────────────────────────────────────
   --
   --  Reflects the current agent lifecycle phase.  Acme renders this as
   --  the tag button set; GUI renders it as an indicator in the status bar.

   type Run_Mode is (Idle, Running, Armed, Paused);

   procedure Set_Mode
     (F    : in out Instance;
      Mode : in     Run_Mode) is abstract;

   --  ── Assistant text stream ─────────────────────────────────────────────
   --
   --  Called for each Text_Delta event.  Text is raw UTF-8; may contain
   --  partial markdown.  A full assistant text block is terminated by
   --  End_Text_Block.

   procedure Append_Text
     (F    : in out Instance;
      Text : in     String) is abstract;

   procedure End_Text_Block (F : in out Instance) is abstract;

   --  ── Thinking stream ───────────────────────────────────────────────────
   --
   --  Thinking is always rendered inline (never collapsed).  Acme prefixes
   --  each line with UC_BOX_V; GUI uses a dim left-gutter character.

   procedure Begin_Thinking   (F : in out Instance) is abstract;

   procedure Append_Thinking
     (F    : in out Instance;
      Text : in     String) is abstract;

   procedure End_Thinking     (F : in out Instance) is abstract;

   --  ── Tool execution lifecycle ──────────────────────────────────────────
   --
   --  Begin_Tool opens a tool call segment.  Args_Json is the raw JSON
   --  object of tool arguments.  Session_Id and Tool_Id are used by the
   --  Acme implementation to embed a plumb token; the GUI uses Tool_Id to
   --  locate the segment when End_Tool arrives.
   --
   --  End_Tool closes the segment.  For status Success the Result_Text is
   --  empty (summary shown only); for Error the first ~80 chars of
   --  Result_Text are shown as a preview; for Cancelled it is ignored.
   --  In the GUI, clicking any tool segment opens the full
   --  detail in $PAGER regardless of status.

   type Tool_End_Status is (Success, Error, Cancelled);

   procedure Begin_Tool
     (F          : in out Instance;
      Name       : in     String;
      Args_Json  : in     String;
      Session_Id : in     String;
      Tool_Id    : in     String) is abstract;

   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     : in     String;
      Status      : in     Tool_End_Status;
      Result_Text : in     String := "") is abstract;

   --  ── Turn footer ───────────────────────────────────────────────────────
   --
   --  Appended once per completed agent turn after session stats arrive.
   --  Text is pre-formatted by Coyote_App.Utils.Format_Turn_Footer_Display.

   procedure Append_Turn_Footer
     (F    : in out Instance;
      Text : in     String) is abstract;

   --  ── Fork action ────────────────────────────────────────────────────────
   --
   --  Called after Append_Turn_Footer at every turn/step boundary.
   --  The acme frontend writes a plumb token; the GUI renders a clickable
   --  action strip; the plain frontend is a no-op.

   procedure Append_Fork_Action
     (F       : in out Instance;
      PID     : in     String;
      UUID    : in     String;
      Turn_N  : in     Positive;
      Step_N  : in     Natural := 0) is abstract;

   --  ── System notices ────────────────────────────────────────────────────
   --
   --  Inline notices that are not part of the assistant message stream:
   --  warnings, errors, retry notices, compaction notices, model changes,
   --  user prompt echoes, steer echoes, fork confirmations, etc.
   --
   --  Text is the human-readable message without any leading glyph; each
   --  implementation prepends the appropriate glyph and styling.

   type Notice_Kind is (Info, Warning, Error);

   procedure Append_Notice
     (F    : in out Instance;
      Kind : in     Notice_Kind;
      Text : in     String) is abstract;

   --  ── Supplementary detail ─────────────────────────────────────────────
   --
   --  Show a named block of content outside the main conversation view.
   --  Acme opens a sub-window; GUI opens it in $PAGER.
   --  Title is used as the sub-window name (acme) or temp-file name (GUI/plain).

   procedure Show_Detail
     (F       : in out Instance;
      Title   : in     String;
      Content : in     String) is abstract;

   --  ── Prompt input ──────────────────────────────────────────────────────
   --
   --  Blocking call; returns the next prompt string entered by the user.
   --  Returns "" when the user closes the frontend (window closed in acme;
   --  :stop command in GUI) and the agent loop should shut down.

   function Read_Prompt
     (F : in out Instance) return String is abstract;

   --  ── Lifecycle ─────────────────────────────────────────────────────────

   --  Signal the frontend to close and release resources.  Called by
   --  Coyote_App when the agent loop exits.
   procedure Shutdown (F : in out Instance) is abstract;

end Coyote_App.Frontend;
