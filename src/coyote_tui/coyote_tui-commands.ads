--  Coyote_TUI.Commands — pure command parser.
--
--  Parse converts a raw command string (the text typed after the ":" prompt,
--  with the leading colon already stripped) into a Command record.
--  It never raises an exception; unknown verbs yield Kind => Unknown.
--
--  No protected objects, no tasks, no I/O.  Fully testable in AUnit.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;

package Coyote_TUI.Commands is

   --  ── Command classification ────────────────────────────────────────────

   type Command_Kind is
     --  Commands handled directly by the UI task (terminal-side).
     (Send,           --  enqueue prompt text (arg = text, or "" → open editor)
      Help,           --  open keybinding reference in $PAGER
      Stats,          --  open stats summary in $PAGER
      Models_List,    --  run fzf model picker; selected → Set_Model
      Sessions_List,  --  run fzf session picker; selected → Load_Session
      Clear,          --  redraw
      Quit,           --  stop the TUI
      --  Commands forwarded to the agent task via Prompt_Queue.
      Stop,           --  abort current tool/generation
      Pause,          --  pause the agent loop
      Resume,         --  resume the agent loop
      Set_Model,      --  arg = "provider/model-id"
      Set_Thinking,   --  arg = level string
      New_Session,    --  start a new session
      Load_Session,   --  arg = UUID
      Compact,        --  compact context
      --  Fallback.
      Unknown);

   --  ── Command record ────────────────────────────────────────────────────

   type Command is record
      Kind : Command_Kind                         := Unknown;
      Arg  : Ada.Strings.Unbounded.Unbounded_String;
      --  True when the command was ":steer" (send prompt while streaming).
      --  Only relevant for Send.
      Is_Steer : Boolean                          := False;
   end record;

   --  ── Parse ─────────────────────────────────────────────────────────────
   --
   --  Parse a raw ":verb [arg]" string with the leading ":" already stripped.
   --  Verb matching is case-sensitive (callers normalise if needed).
   --  The Arg field receives everything after the first space following the
   --  verb, with leading/trailing ASCII spaces trimmed.
   function Parse (Str : String) return Command;

   --  ── Agent_Prefix ─────────────────────────────────────────────────────
   --
   --  Return the colon-prefixed string that Prompt_Queue should carry for
   --  agent-directed commands (e.g. ":model x/y", ":stop", etc.).
   --  Returns "" for UI-side commands (Send, Help, Stats, …, Quit, Unknown).
   function Agent_Prefix (Cmd : Command) return String;

end Coyote_TUI.Commands;
