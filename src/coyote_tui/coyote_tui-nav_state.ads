--  Coyote_TUI.Nav_State — protected viewport, search, and lifecycle state.
--
--  This replaces the former TUI_State god-object with a focused protected
--  type covering:
--    • Viewport cursor and Follow/Scroll mode
--    • Search term, match vector, and cursor
--    • Render-request flag (atomic exchange via Take_Render_Request)
--    • Streaming flag and Stop signal
--    • Status-bar text, window name, and stats summary
--
--  The render-request mechanism uses an atomic exchange: Take_Render_Request
--  reads the flag and clears it in a single protected action, so no render
--  request can be lost between the read and the clear.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded;
with Coyote_TUI.Viewport;
with Coyote_TUI.Search;

package Coyote_TUI.Nav_State is

   use Coyote_TUI.Viewport;
   use Coyote_TUI.Search;

   protected type State is

      --  ── Viewport ──────────────────────────────────────────────────────

      procedure Set_Cursor  (C : Cursor);
      function  Get_Cursor  return Cursor;
      procedure Follow;
      function  Is_Following return Boolean;

      --  ── Search ────────────────────────────────────────────────────────

      procedure Set_Search (Term    : String;
                            Matches : Search.Match_Vector);
      procedure Advance_Search (Dir : Integer);
      function  Search_Term   return String;

      --  Returns the match record for the current cursor (default if none).
      function  Current_Match return Search.Match_Record;
      function  Search_Match_Count return Natural;

      --  ── Render request ────────────────────────────────────────────────

      --  Request a render; non-blocking.
      procedure Request_Render;

      --  Atomically read and clear the render flag.  Returns True if a
      --  render was requested since the last Take call.
      --  Atomically read and clear the render flag.
      --  Was_Set is True if a render was pending.
      procedure Take_Render_Request (Was_Set : out Boolean);
      --  Mark segment Seg as needing height re-measurement (called when a
      --  streaming segment transitions to Complete).
      procedure Mark_Height_Stale (Seg : Positive);

      --  Atomically read and clear the stale-segment index.
      --  Returns 0 if no stale segment is pending.
      procedure Take_Stale_Seg (Seg : out Natural);

      --  ── Lifecycle ─────────────────────────────────────────────────────

      procedure Set_Streaming (On : Boolean);
      function  Is_Streaming  return Boolean;

      procedure Stop;
      function  Is_Stopped return Boolean;

      --  ── Display metadata ──────────────────────────────────────────────

      procedure Set_Status  (Text : String);
      function  Status_Text return String;

      procedure Set_Win_Name (Name : String);
      function  Win_Name    return String;

      procedure Set_Stats_Summary (Text : String);
      function  Stats_Summary    return String;

   private
      P_Cursor        : Cursor  := Following_Cursor;
      P_Following     : Boolean := True;
      P_Search_Term   : Ada.Strings.Unbounded.Unbounded_String;
      P_Matches       : Search.Match_Vector;
      P_Stale_Seg     : Natural  := 0;
      P_Match_Cursor  : Natural := 0;
      P_Render        : Boolean := False;
      P_Streaming     : Boolean := False;
      P_Stopped       : Boolean := False;
      P_Status        : Ada.Strings.Unbounded.Unbounded_String;
      P_Win_Name      : Ada.Strings.Unbounded.Unbounded_String;
      P_Stats_Summary : Ada.Strings.Unbounded.Unbounded_String;
   end State;

end Coyote_TUI.Nav_State;
