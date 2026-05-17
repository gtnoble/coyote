--  Coyote_TUI.Nav_State body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Coyote_TUI.Nav_State is

   protected body State is

      --  ── Viewport ──────────────────────────────────────────────────────

      procedure Set_Cursor (C : Cursor) is
      begin
         P_Cursor    := C;
         P_Following := Viewport.Is_Following (C);
         P_Render    := True;
      end Set_Cursor;

      function Get_Cursor return Cursor is
      begin
         return (if P_Following then Following_Cursor else P_Cursor);
      end Get_Cursor;

      procedure Follow is
      begin
         P_Cursor    := Following_Cursor;
         P_Following := True;
         P_Render    := True;
      end Follow;

      function Is_Following return Boolean is
      begin
         return P_Following;
      end Is_Following;

      --  ── Search ────────────────────────────────────────────────────────

      procedure Set_Search (Term    : String;
                            Matches : Search.Match_Vector)
      is
      begin
         P_Search_Term  := To_Unbounded_String (Term);
         P_Matches      := Matches;
         P_Match_Cursor := (if Matches.Is_Empty then 0 else 1);
         P_Render       := True;
      end Set_Search;

      procedure Advance_Search (Dir : Integer) is
      begin
         P_Match_Cursor :=
           Search.Advance (P_Matches, P_Match_Cursor, Dir);
         P_Render := True;
      end Advance_Search;

      function Search_Term return String is
      begin
         return To_String (P_Search_Term);
      end Search_Term;

      function Current_Match return Search.Match_Record is
         Default : constant Search.Match_Record :=
           (Seg_Index => 1, Byte_Offset => 0, Match_Len => 0);
      begin
         if P_Match_Cursor = 0 or else P_Matches.Is_Empty then
            return Default;
         end if;
         return P_Matches (P_Match_Cursor);
      end Current_Match;

      function Search_Match_Count return Natural is
      begin
         return Natural (P_Matches.Length);
      end Search_Match_Count;

      --  ── Render request ────────────────────────────────────────────────

      procedure Request_Render is
      begin
         P_Render := True;
      end Request_Render;

      procedure Take_Render_Request (Was_Set : out Boolean) is
      begin
         Was_Set  := P_Render;
         P_Render := False;
      end Take_Render_Request;

      procedure Mark_Height_Stale (Seg : Positive) is
      begin
         P_Stale_Seg := Natural (Seg);
         P_Render    := True;
      end Mark_Height_Stale;

      procedure Take_Stale_Seg (Seg : out Natural) is
      begin
         Seg         := P_Stale_Seg;
         P_Stale_Seg := 0;
      end Take_Stale_Seg;

      --  ── Lifecycle ─────────────────────────────────────────────────────

      procedure Set_Streaming (On : Boolean) is
      begin
         P_Streaming := On;
         P_Render    := True;
      end Set_Streaming;

      function Is_Streaming return Boolean is
      begin
         return P_Streaming;
      end Is_Streaming;

      procedure Stop is
      begin
         P_Stopped := True;
         P_Render  := True;
      end Stop;

      function Is_Stopped return Boolean is
      begin
         return P_Stopped;
      end Is_Stopped;

      --  ── Display metadata ──────────────────────────────────────────────

      procedure Set_Status (Text : String) is
      begin
         P_Status := To_Unbounded_String (Text);
         P_Render := True;
      end Set_Status;

      function Status_Text return String is
      begin
         return To_String (P_Status);
      end Status_Text;

      procedure Set_Win_Name (Name : String) is
      begin
         P_Win_Name := To_Unbounded_String (Name);
         P_Render   := True;
      end Set_Win_Name;

      function Win_Name return String is
      begin
         return To_String (P_Win_Name);
      end Win_Name;

      procedure Set_Stats_Summary (Text : String) is
      begin
         P_Stats_Summary := To_Unbounded_String (Text);
      end Set_Stats_Summary;

      function Stats_Summary return String is
      begin
         if Length (P_Stats_Summary) = 0 then
            return "No session stats available yet.  Run a prompt first.";
         end if;
         return To_String (P_Stats_Summary);
      end Stats_Summary;

   end State;

end Coyote_TUI.Nav_State;
