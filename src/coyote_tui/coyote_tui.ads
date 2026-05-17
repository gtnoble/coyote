--  Coyote_TUI — root package for the terminal UI subsystem.
--
--  Child packages implement the layered TUI architecture:
--    Coyote_TUI.Segments     — pure data types (Segment, Vector)
--    Coyote_TUI.Segment_Ops  — pure operations on Segment vectors
--    Coyote_TUI.Viewport     — viewport cursor and height-cache types
--    Coyote_TUI.Scroll       — pure scroll arithmetic
--    Coyote_TUI.Search       — pure search (Compute_Matches, Advance)
--    Coyote_TUI.Commands     — pure command parser (":verb arg" → Command)
--    Coyote_TUI.Sink         — abstract output sink interface
--    Coyote_TUI.Render       — renderer (works over Sink'Class)
--    Coyote_TUI.Store        — protected Conversation wrapper
--    Coyote_TUI.Prompt_Queue — protected real FIFO for user prompts
--    Coyote_TUI.Nav_State    — protected viewport/search/stop state
--    Coyote_TUI.UI           — UI_Task_T (ncurses input + render loop)
--
--  Design principle: all logic lives in pure (non-protected, non-task)
--  subprograms in Layers 0-3; concurrency is a thin wrapper in Layer 4;
--  terminal I/O is confined to Layer 5 (UI).  Layers 0-4 are fully
--  testable in AUnit without a real terminal.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package Coyote_TUI is


end Coyote_TUI;
