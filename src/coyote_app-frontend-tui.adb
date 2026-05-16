--  Coyote_App.Frontend.TUI body — ncurses-based TUI frontend.
--
--  Architecture
--  ────────────
--  A single package-level UI_Task handles both rendering and keyboard
--  input.  ncurses is NOT thread-safe, so keeping all ncurses calls in
--  one task avoids any cross-task contention without requiring a mutex.
--
--  UI_Task polls Coyote_Ncurses.Wget_Wch in nodelay mode (~50 Hz),
--  dispatches key events, then re-renders whenever TUI_State signals
--  Render_Needed.  ncurses' differential update (wnoutrefresh + doupdate)
--  writes only changed cells, eliminating the full-screen flicker of the
--  previous raw-ANSI approach.
--
--  Layout (one 1-line Status_Win at bottom; Content_Win fills the rest):
--
--    row 0 .. Rows-2 : Content_Win
--    row Rows-1      : Status_Win  (A_REVERSE background)
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Interfaces;
with Interfaces.C;
with Ada.Characters.Latin_1;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;     use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Coyote_Ncurses;
with Coyote_TUI_Terminal;
with Coyote_App.Utils;          use Coyote_App.Utils;
with GNATCOLL.OS.Process;
with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with GNATCOLL.OS.FS;
with LLM.Model_Registry;
with Session_Lister;

package body Coyote_App.Frontend.TUI is

   --  ── Segment buffer ───────────────────────────────────────────────────

   package Segment_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Segment);

   --  ── Match buffer (for / search) ──────────────────────────────────────

   type Match_Record is record
      Seg_Index : Positive;
   end record;

   package Match_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Match_Record);

   --  Set True in Create when NO_COLOR is absent; gates all colour calls.
   Use_Color : Boolean := True;

   type Nav_Mode is (Follow, Scroll);

   --  ── Protected: Buffer ────────────────────────────────────────────────

   protected Buffer is
      procedure Append_Segment (S : Segment);
      procedure Update_Last_Content (Text : String);
      procedure Update_Last_Thinking (Text : String);
      procedure Set_Last_Complete;
      procedure End_Tool_Segment
        (Tool_Id     : String;
         Stat        : Tool_Run_Status;
         Result_Text : String);
      function  Count return Natural;
      function  Get (I : Positive) return Segment;
      function  Last_Kind return Segment_Kind;
      --  Find index of most recent Tool_Segment with matching Tool_Id;
      --  returns 0 when not found.
      function  Find_Tool (Tool_Id : String) return Natural;
      --  Reset all segments.  Used by test-support subprograms only.
      procedure Clear;
   private
      Vec : Segment_Vectors.Vector;
   end Buffer;

   protected body Buffer is

      procedure Append_Segment (S : Segment) is
      begin
         Vec.Append (S);
      end Append_Segment;

      procedure Update_Last_Content (Text : String) is
      begin
         if not Vec.Is_Empty then
            declare
               S : Segment := Vec.Last_Element;
            begin
               Append (S.Content, Text);
               Vec.Replace_Element (Vec.Last_Index, S);
            end;
         end if;
      end Update_Last_Content;

      procedure Update_Last_Thinking (Text : String) is
      begin
         if not Vec.Is_Empty then
            declare
               S : Segment := Vec.Last_Element;
            begin
               Append (S.Content, Text);
               Vec.Replace_Element (Vec.Last_Index, S);
            end;
         end if;
      end Update_Last_Thinking;

      procedure Set_Last_Complete is
      begin
         if not Vec.Is_Empty then
            declare
               S : Segment := Vec.Last_Element;
            begin
               S.Complete := True;
               Vec.Replace_Element (Vec.Last_Index, S);
            end;
         end if;
      end Set_Last_Complete;

      procedure End_Tool_Segment
        (Tool_Id     : String;
         Stat        : Tool_Run_Status;
         Result_Text : String)
      is
         Idx : constant Natural := Find_Tool (Tool_Id);
      begin
         if Idx > 0 then
            declare
               S : Segment := Vec (Idx);
            begin
               S.T_Status := Stat;
               S.Content  := To_Unbounded_String (Result_Text);
               Vec.Replace_Element (Idx, S);
            end;
         end if;
      end End_Tool_Segment;

      function Count return Natural is
      begin
         return Natural (Vec.Length);
      end Count;

      function Get (I : Positive) return Segment is
      begin
         return Vec (I);
      end Get;

      function Last_Kind return Segment_Kind is
      begin
         if Vec.Is_Empty then
            return System_Notice;
         end if;
         return Vec.Last_Element.Kind;
      end Last_Kind;

      function Find_Tool (Tool_Id : String) return Natural is
      begin
         for I in reverse Vec.First_Index .. Vec.Last_Index loop
            if Vec (I).Kind = Tool_Segment
              and then To_String (Vec (I).Tool_Id) = Tool_Id
            then
               return I;
            end if;
         end loop;
         return 0;
      end Find_Tool;

      procedure Clear is
      begin
         Vec.Clear;
      end Clear;

   end Buffer;

   --  ── Prompt queue ─────────────────────────────────────────────────────

   type Prompt_Entry is record
      Text     : Unbounded_String;
      Is_Steer : Boolean := False;
   end record;

   protected Prompt_Queue is
      procedure Enqueue (Text : String; Is_Steer : Boolean);
      entry     Dequeue (E : out Prompt_Entry);
      procedure Signal_Shutdown;
      function  Is_Shutdown return Boolean;
   private
      Queue    : Prompt_Entry;
      Has_Item : Boolean  := False;
      Shutdown : Boolean  := False;
   end Prompt_Queue;

   protected body Prompt_Queue is

      procedure Enqueue (Text : String; Is_Steer : Boolean) is
      begin
         Queue    := (Text => To_Unbounded_String (Text),
                      Is_Steer => Is_Steer);
         Has_Item := True;
      end Enqueue;

      entry Dequeue (E : out Prompt_Entry) when Has_Item or else Shutdown is
      begin
         if Has_Item then
            E        := Queue;
            Has_Item := False;
         else
            E := (Text => Null_Unbounded_String, Is_Steer => False);
         end if;
      end Dequeue;

      procedure Signal_Shutdown is
      begin
         Shutdown := True;
         Has_Item := True;  --  unblock any waiting Dequeue
      end Signal_Shutdown;

      function Is_Shutdown return Boolean is
      begin
         return Shutdown;
      end Is_Shutdown;

   end Prompt_Queue;

   --  ── Protected: TUI_State ─────────────────────────────────────────────

   protected TUI_State is
      procedure Set_Win_Name (Name : String);
      function  Win_Name return String;
      procedure Set_Status (Text : String);
      function  Status_Text return String;
      procedure Set_Nav_Mode (Mode : Nav_Mode);
      function  Current_Nav return Nav_Mode;
      procedure Set_Viewport (Top : Natural);
      procedure Set_Viewport_Silent (Top : Natural);
      function  Viewport_Top return Natural;
      procedure Signal_Render;
      procedure Clear_Render;
      procedure Set_Started;
      procedure Set_Mode (Mode : Coyote_App.Frontend.Run_Mode);
      procedure Set_Streaming (On : Boolean);
      function  Is_Streaming return Boolean;
      procedure Signal_Stop;
      function  Is_Stopped return Boolean;
      function  Render_Needed return Boolean;
      procedure Set_Search (Term : String);
      procedure Set_Stats_Summary (Text : String);
      function  Stats_Summary return String;
      procedure Set_Search_Matches (Matches : Match_Vectors.Vector);
      procedure Advance_Search (Dir : Integer);
      function  Search_Seg return Natural;
   private
      P_Win_Name   : Unbounded_String :=
        To_Unbounded_String ("coyote");
      P_Status     : Unbounded_String;
      P_Nav        : Nav_Mode  := Follow;
      P_Top        : Natural   := 0;
      P_Render     : Boolean   := False;
      P_Started    : Boolean   := False;
      P_Streaming  : Boolean   := False;
      P_Stop       : Boolean   := False;
      P_Search     : Unbounded_String;
      P_Stats_Summary  : Unbounded_String;
      P_Search_Matches : Match_Vectors.Vector;
      P_Search_Cursor  : Natural := 0;
   end TUI_State;

   protected body TUI_State is

      procedure Set_Win_Name (Name : String) is
      begin
         P_Win_Name := To_Unbounded_String (Name);
         P_Render   := True;
      end Set_Win_Name;

      function Win_Name return String is
      begin
         return To_String (P_Win_Name);
      end Win_Name;

      procedure Set_Status (Text : String) is
      begin
         P_Status := To_Unbounded_String (Text);
         P_Render := True;
      end Set_Status;

      function Status_Text return String is
      begin
         return To_String (P_Status);
      end Status_Text;

      procedure Set_Nav_Mode (Mode : Nav_Mode) is
      begin
         P_Nav    := Mode;
         P_Render := True;
      end Set_Nav_Mode;

      function Current_Nav return Nav_Mode is
      begin
         return P_Nav;
      end Current_Nav;

      procedure Set_Viewport (Top : Natural) is
      begin
         P_Top    := Top;
         P_Nav    := Scroll;
         P_Render := True;
      end Set_Viewport;

      procedure Set_Viewport_Silent (Top : Natural) is
      begin
         P_Top := Top;
      end Set_Viewport_Silent;

      function Viewport_Top return Natural is
      begin
         return P_Top;
      end Viewport_Top;

      procedure Signal_Render is
      begin
         P_Render := True;
      end Signal_Render;

      procedure Clear_Render is
      begin
         P_Render := False;
      end Clear_Render;

      procedure Set_Started is
      begin
         P_Started := True;
         P_Render  := True;
      end Set_Started;

      procedure Set_Mode (Mode : Coyote_App.Frontend.Run_Mode) is
         pragma Unreferenced (Mode);
      begin
         P_Render := True;
      end Set_Mode;

      procedure Set_Streaming (On : Boolean) is
      begin
         P_Streaming := On;
         P_Render    := True;
      end Set_Streaming;

      function Is_Streaming return Boolean is
      begin
         return P_Streaming;
      end Is_Streaming;

      procedure Signal_Stop is
      begin
         P_Stop   := True;
         P_Render := True;
      end Signal_Stop;

      function Is_Stopped return Boolean is
      begin
         return P_Stop;
      end Is_Stopped;

      function Render_Needed return Boolean is
      begin
         return P_Render;
      end Render_Needed;

      procedure Set_Search (Term : String) is
      begin
         P_Search := To_Unbounded_String (Term);
         P_Render := True;
      end Set_Search;

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

      procedure Set_Search_Matches (Matches : Match_Vectors.Vector) is
      begin
         P_Search_Matches := Matches;
         P_Search_Cursor  := (if Matches.Is_Empty then 0 else 1);
         if P_Search_Cursor > 0 then
            P_Top := P_Search_Matches (P_Search_Cursor).Seg_Index;
            P_Nav := Scroll;
         end if;
         P_Render := True;
      end Set_Search_Matches;

      procedure Advance_Search (Dir : Integer) is
         N : constant Natural := Natural (P_Search_Matches.Length);
      begin
         if N = 0 then
            return;
         end if;
         P_Search_Cursor :=
           ((P_Search_Cursor - 1 + Dir + N) mod N) + 1;
         P_Top    := P_Search_Matches (P_Search_Cursor).Seg_Index;
         P_Nav    := Scroll;
         P_Render := True;
      end Advance_Search;

      function Search_Seg return Natural is
      begin
         if P_Search_Cursor = 0 or else P_Search_Matches.Is_Empty then
            return 0;
         end if;
         return P_Search_Matches (P_Search_Cursor).Seg_Index;
      end Search_Seg;

   end TUI_State;

   --  ── Compute_Matches ──────────────────────────────────────────────────
   --
   --  Scan all buffered segments for those whose Content contains Term
   --  (case-insensitive).  Returns one Match_Record per matching segment.
   function Compute_Matches (Term : String) return Match_Vectors.Vector is
      use Ada.Characters.Handling;
      use Ada.Strings.Fixed;
      Matches  : Match_Vectors.Vector;
      Count    : constant Natural := Buffer.Count;
      UC_Term  : constant String  := To_Upper (Term);
   begin
      if UC_Term'Length = 0 then
         return Matches;
      end if;
      for I in 1 .. Count loop
         declare
            Content    : constant String := To_String (Buffer.Get (I).Content);
            UC_Content : constant String := To_Upper (Content);
         begin
            if Index (UC_Content, UC_Term) > 0 then
               Matches.Append ((Seg_Index => I));
            end if;
         end;
      end loop;
      return Matches;
   end Compute_Matches;

   --  ── ncurses window handles ────────────────────────────────────────────
   --
   --  Initialised in Create, recreated on resize by Resize_Windows.

   Stdscr      : Coyote_Ncurses.Window := Coyote_Ncurses.Null_Window;
   Content_Win : Coyote_Ncurses.Window := Coyote_Ncurses.Null_Window;
   Status_Win  : Coyote_Ncurses.Window := Coyote_Ncurses.Null_Window;
   Last_Rows   : Integer := 0;
   Last_Cols   : Integer := 0;

   --  Colour pair indices.
   PAIR_YELLOW : constant Interfaces.C.short := 1;
   PAIR_RED    : constant Interfaces.C.short := 2;

   --  ── Resize_Windows ───────────────────────────────────────────────────

   procedure Resize_Windows (Rows : Integer; Cols : Integer) is
      use Coyote_Ncurses;
   begin
      if Content_Win /= Null_Window then
         Delwin (Content_Win);
      end if;
      if Status_Win /= Null_Window then
         Delwin (Status_Win);
      end if;

      Content_Win := Newwin (Rows - 1, Cols, 0, 0);
      Status_Win  := Newwin (1, Cols, Rows - 1, 0);

      --  Status bar has a full-line reverse-video background.
      Wbkgd (Status_Win, Coyote_Ncurses.A_Reverse);

      Last_Rows := Rows;
      Last_Cols := Cols;
   end Resize_Windows;

   --  ── UTF-8 / word-wrap helpers ─────────────────────────────────────────

   --  Return the display width of one UTF-8 sequence starting at
   --  Text (Pos).  Advances Pos past the sequence.  Returns 1 on
   --  malformed input so rendering still advances.
   function Utf8_Width (Text : String; Pos : in out Positive) return Natural
   is
      use Interfaces;
      C  : constant Unsigned_32 :=
        Unsigned_32 (Character'Pos (Text (Pos)));
      CP : Unsigned_32;
      W  : Integer;
   begin
      if C < 16#80# then
         CP  := C;
         Pos := Pos + 1;
      elsif C < 16#E0# then
         if Pos + 1 <= Text'Last then
            CP  :=
              (C and 16#1F#) * 16#40#
              + (Unsigned_32 (Character'Pos (Text (Pos + 1)))
                 and 16#3F#);
            Pos := Pos + 2;
         else
            CP  := C;
            Pos := Pos + 1;
         end if;
      elsif C < 16#F0# then
         if Pos + 2 <= Text'Last then
            CP  :=
              (C and 16#0F#) * 16#1000#
              + (Unsigned_32 (Character'Pos (Text (Pos + 1)))
                 and 16#3F#) * 16#40#
              + (Unsigned_32 (Character'Pos (Text (Pos + 2)))
                 and 16#3F#);
            Pos := Pos + 3;
         else
            CP  := C;
            Pos := Pos + 1;
         end if;
      else
         if Pos + 3 <= Text'Last then
            CP  :=
              (C and 16#07#) * 16#40000#
              + (Unsigned_32 (Character'Pos (Text (Pos + 1)))
                 and 16#3F#) * 16#1000#
              + (Unsigned_32 (Character'Pos (Text (Pos + 2)))
                 and 16#3F#) * 16#40#
              + (Unsigned_32 (Character'Pos (Text (Pos + 3)))
                 and 16#3F#);
            Pos := Pos + 4;
         else
            CP  := C;
            Pos := Pos + 1;
         end if;
      end if;
      W := Coyote_Ncurses.Wcwidth (Natural (CP));
      if W < 0 then
         return 1;
      end if;
      return Natural (W);
   end Utf8_Width;

   --  Word-wrap Text at Cols columns, writing each output line to Win
   --  via Coyote_Ncurses.Waddstr with a Prefix prepended.
   --  Returns the number of terminal rows consumed.
   function Wrap_And_Put
     (Win    : Coyote_Ncurses.Window;
      Text   : String;
      Cols   : Positive;
      Prefix : String := "") return Natural
   is
      procedure Put_Line (S : String) is
      begin
         Coyote_Ncurses.Waddstr (Win, S);
         Coyote_Ncurses.Waddch  (Win, Ada.Characters.Latin_1.LF);
      end Put_Line;

      Prefix_W : Natural := 0;
      P        : Positive := Prefix'First;
   begin
      --  Measure prefix display width.
      while P <= Prefix'Last loop
         Prefix_W := Prefix_W + Utf8_Width (Prefix, P);
      end loop;

      if Cols <= Prefix_W then
         Put_Line (Prefix & Text);
         return 1;
      end if;

      declare
         Max_W    : constant Positive := Cols - Prefix_W;
         Rows_Out : Natural  := 0;
         I        : Positive := Text'First;
         Line_W   : Natural  := 0;
         Word_S   : Natural  := Text'First;
         Word_W   : Natural  := 0;
         Line_Buf : Unbounded_String;
      begin
         if Text'Length = 0 then
            Put_Line (Prefix);
            return 1;
         end if;

         while I <= Text'Last loop
            if Text (I) = Ada.Characters.Latin_1.LF then
               Put_Line (Prefix & To_String (Line_Buf));
               Rows_Out := Rows_Out + 1;
               Line_Buf := Null_Unbounded_String;
               Line_W   := 0;
               Word_S   := I + 1;
               Word_W   := 0;
               I        := I + 1;
            elsif Text (I) = ' ' then
               if Word_W > 0 then
                  if Line_W + Word_W > Max_W then
                     Put_Line (Prefix & To_String (Line_Buf));
                     Rows_Out := Rows_Out + 1;
                     Line_Buf := To_Unbounded_String (Text (Word_S .. I - 1));
                     Line_W   := Word_W;
                  else
                     if Line_W > 0 then
                        Append (Line_Buf, ' ');
                        Line_W := Line_W + 1;
                     end if;
                     Append (Line_Buf, Text (Word_S .. I - 1));
                     Line_W := Line_W + Word_W;
                  end if;
                  Word_W := 0;
               end if;
               Word_S := I + 1;
               I      := I + 1;
            else
               declare
                  I2 : Positive := I;
                  W  : constant Natural := Utf8_Width (Text, I2);
               begin
                  Word_W := Word_W + W;
                  I      := I2;
               end;
            end if;
         end loop;

         --  Flush remaining word.
         if Word_S <= Text'Last then
            if Line_W + Word_W > Max_W and then Line_W > 0 then
               Put_Line (Prefix & To_String (Line_Buf));
               Rows_Out := Rows_Out + 1;
               Put_Line (Prefix & Text (Word_S .. Text'Last));
               Rows_Out := Rows_Out + 1;
            else
               if Line_W > 0 then
                  Append (Line_Buf, ' ');
               end if;
               Append (Line_Buf, Text (Word_S .. Text'Last));
               Put_Line (Prefix & To_String (Line_Buf));
               Rows_Out := Rows_Out + 1;
            end if;
         elsif Length (Line_Buf) > 0 then
            Put_Line (Prefix & To_String (Line_Buf));
            Rows_Out := Rows_Out + 1;
         end if;

         if Rows_Out = 0 then
            Rows_Out := 1;
         end if;
         return Rows_Out;
      end;
   end Wrap_And_Put;

   --  ── Do_Render ────────────────────────────────────────────────────────

   procedure Do_Render is
      use Coyote_Ncurses;
      Rows  : constant Integer := Coyote_Ncurses.Lines;
      Cols  : constant Integer := Coyote_Ncurses.Cols;
      Used  : Natural := 0;
      Top   : constant Natural  := TUI_State.Viewport_Top;
      Nav   : constant Nav_Mode := TUI_State.Current_Nav;
      Count : constant Natural  := Buffer.Count;
      Start : Positive;
      Eff_Rows : constant Integer := (if Rows >= 4 then Rows else 4);
      Eff_Cols : constant Integer := (if Cols >= 20 then Cols else 20);
      Search_Hi : constant Natural := TUI_State.Search_Seg;
   begin
      TUI_State.Clear_Render;

      --  Re-create windows when the terminal is resized.
      if Eff_Rows /= Last_Rows or else Eff_Cols /= Last_Cols then
         Resize_Windows (Eff_Rows, Eff_Cols);
      end if;

      Werase (Content_Win);
      Wmove  (Content_Win, 0, 0);

      Start := (if Top > 0 then Top
               else (if Count > Eff_Rows - 3
                     then Count - (Eff_Rows - 3) else 1));

      if Count >= 1 then
         declare
            I : Positive := Start;
         begin
            while I <= Count and then Used < Eff_Rows - 2 loop
               declare
                  S : constant Segment := Buffer.Get (I);
                  Hi : constant Boolean := (I = Search_Hi);
                  N : Natural;
               begin
                  if Hi and then Search_Hi /= 0 then
                     Wattron  (Content_Win, A_Reverse);
                     Waddstr  (Content_Win, UC_TRI_R & " match");
                     Wattrset (Content_Win, A_Normal);
                     Waddch   (Content_Win, Ada.Characters.Latin_1.LF);
                     if Used < Eff_Rows - 2 then
                        Used := Used + 1;
                     end if;
                  end if;
                  case S.Kind is
                     when User_Turn =>
                        Wattron (Content_Win, A_Bold);
                        N := Wrap_And_Put
                               (Content_Win, To_String (S.Content),
                                Eff_Cols, Prefix => UC_TRI_R & " ");
                        Wattrset (Content_Win, A_Normal);
                        Used := Used + N;

                     when Steer_Turn =>
                        Wattron (Content_Win, A_Bold);
                        N := Wrap_And_Put
                               (Content_Win, To_String (S.Content),
                                Eff_Cols, Prefix => UC_HOOK_L & " ");
                        Wattrset (Content_Win, A_Normal);
                        Used := Used + N;

                     when Assistant_Text =>
                        N    := Wrap_And_Put
                                  (Content_Win, To_String (S.Content),
                                   Eff_Cols);
                        Used := Used + N;

                     when Thinking_Block =>
                        Wattron (Content_Win, A_Dim);
                        N    := Wrap_And_Put
                                  (Content_Win, To_String (S.Content),
                                   Eff_Cols, Prefix => UC_BOX_V & " ");
                        Wattrset (Content_Win, A_Normal);
                        Used := Used + N;

                     when Tool_Segment =>
                        --  Header line.
                        Wattron (Content_Win, A_Bold);
                        Waddstr (Content_Win,
                                 UC_BOX_TL & " " & UC_GEAR & " "
                                 & To_String (S.Tool_Name));
                        Waddch  (Content_Win, Ada.Characters.Latin_1.LF);
                        Wattrset (Content_Win, A_Normal);
                        Used := Used + 1;
                        --  Status line.
                        case S.T_Status is
                           when Running =>
                              Waddstr (Content_Win, UC_BOX_BL & " " & UC_ELLIP);
                              Waddch  (Content_Win, Ada.Characters.Latin_1.LF);
                           when Success =>
                              Waddstr (Content_Win, UC_BOX_BL & " " & UC_CHECK);
                              Waddch  (Content_Win, Ada.Characters.Latin_1.LF);
                           when Error =>
                              declare
                                 Preview : constant String :=
                                   To_String (S.Content);
                                 Plen    : constant Natural :=
                                   (if Preview'Length > 80
                                    then 80 else Preview'Length);
                              begin
                                 Waddstr (Content_Win,
                                          UC_BOX_BL & " " & UC_CROSS & " "
                                          & Preview (Preview'First
                                             .. Preview'First + Plen - 1));
                                 Waddch (Content_Win,
                                         Ada.Characters.Latin_1.LF);
                              end;
                           when Cancelled =>
                              Waddstr (Content_Win,
                                       UC_BOX_BL & " " & UC_CROSS
                                       & " cancelled");
                              Waddch  (Content_Win, Ada.Characters.Latin_1.LF);
                        end case;
                        Used := Used + 1;

                     when Turn_Footer =>
                        Waddstr (Content_Win, To_String (S.Content));
                        Waddch  (Content_Win, Ada.Characters.Latin_1.LF);
                        Used := Used + 1;

                     when System_Notice =>
                        case S.Sev is
                           when Info =>
                              Waddstr (Content_Win,
                                       UC_BULLET & " " & To_String (S.Content));
                              Waddch  (Content_Win, Ada.Characters.Latin_1.LF);
                           when Warning =>
                              if Use_Color then
                                 Wattron  (Content_Win,
                                           Color_Pair (Integer (PAIR_YELLOW)));
                              end if;
                              Waddstr  (Content_Win,
                                        UC_WARN & " " & To_String (S.Content));
                              Waddch   (Content_Win, Ada.Characters.Latin_1.LF);
                              Wattrset (Content_Win, A_Normal);
                           when Error =>
                              if Use_Color then
                                 Wattron  (Content_Win,
                                           Color_Pair (Integer (PAIR_RED)));
                              end if;
                              Waddstr  (Content_Win,
                                        "[!] " & To_String (S.Content));
                              Waddch   (Content_Win, Ada.Characters.Latin_1.LF);
                              Wattrset (Content_Win, A_Normal);
                        end case;
                        Used := Used + 1;
                  end case;
               end;
               I := I + 1;
            end loop;
         end;

         if Nav = Follow then
            TUI_State.Set_Viewport_Silent (Start);
         end if;
      end if;

      --  ── Status bar ───────────────────────────────────────────────────

      declare
         Nav_Pfx  : constant String :=
           (if Nav = Scroll then "[SCROLL] " else "");
         Bar_Text : constant String :=
           Nav_Pfx & TUI_State.Win_Name & "  " & TUI_State.Status_Text;
      begin
         Werase  (Status_Win);
         Wmove   (Status_Win, 0, 0);
         Waddstr (Status_Win, Bar_Text);
         Wclrtoeol (Status_Win);   --  fills rest of line with background (A_REVERSE)
      end;

      Wnoutrefresh (Content_Win);
      Wnoutrefresh (Status_Win);
      Doupdate;
   end Do_Render;

   --  ── Run external program ─────────────────────────────────────────────

   procedure Run_Pager (Content : String; Title : String) is
      use GNATCOLL.OS.Process;
      Path_Buf : Coyote_TUI_Terminal.Tmp_Path_Buf;
      FD_Int   : Integer;
      Path_Str : String (1 .. Coyote_TUI_Terminal.TMP_PATH_CAP);
      Path_Len : Natural;
      Args     : Argument_List;
      Handle   : Process_Handle;
      Pager    : constant String :=
        Ada.Environment_Variables.Value ("PAGER", "less");
   begin
      Coyote_TUI_Terminal.Make_Tempfile (Path_Buf, FD_Int);
      if FD_Int < 0 then
         return;
      end if;
      Interfaces.C.To_Ada (Path_Buf, Path_Str, Path_Len, Trim_Nul => True);
      declare
         Path : constant String := Path_Str (1 .. Path_Len);
         TF   : Ada.Text_IO.File_Type;
      begin
         Coyote_TUI_Terminal.Close_FD (FD_Int);
         Ada.Text_IO.Open (TF, Ada.Text_IO.Out_File, Path);
         Ada.Text_IO.Put_Line (TF, "-- " & Title);
         Ada.Text_IO.New_Line (TF);
         Ada.Text_IO.Put (TF, Content);
         Ada.Text_IO.Close (TF);

         Coyote_Ncurses.Suspend;
         Args.Append (Pager);
         Args.Append (Path);
         Handle := Start (Args => Args);
         declare
            Exit_Code : constant Integer := Wait (Handle);
            pragma Unreferenced (Exit_Code);
         begin
            null;
         end;
         Ada.Directories.Delete_File (Path);
         Coyote_Ncurses.Resume;
         TUI_State.Signal_Render;
      end;
   exception
      when others =>
         Coyote_Ncurses.Resume;
         TUI_State.Signal_Render;
   end Run_Pager;

   --  ── Run_Fzf ──────────────────────────────────────────────────────────
   --
   --  Launch fzf with Input written to its stdin.  Args must begin with
   --  "fzf" and may include additional fzf flags (e.g. --with-nth, etc.).
   --  Suspends/resumes ncurses around the child process.
   --  Returns the selected line (trailing newline stripped), or "" when the
   --  user cancels, fzf is not found, or any I/O error occurs.
   function Run_Fzf
     (Input    : String;
      Fzf_Args : GNATCOLL.OS.Process.Argument_List) return String
   is
      use GNATCOLL.OS.FS;
      use GNATCOLL.OS.Process;
      In_Read   : File_Descriptor := Invalid_FD;
      In_Write  : File_Descriptor := Invalid_FD;
      Out_Read  : File_Descriptor := Invalid_FD;
      Out_Write : File_Descriptor := Invalid_FD;
      Handle    : Process_Handle;
      Exit_Code : Integer;
      pragma Warnings (Off, Handle);
   begin
      Open_Pipe (In_Read,  In_Write);
      Open_Pipe (Out_Read, Out_Write);
      Coyote_Ncurses.Suspend;
      Handle := Start
        (Args   => Fzf_Args,
         Stdin  => In_Read,
         Stdout => Out_Write);
      Close (In_Read);
      Close (Out_Write);
      if Input'Length > 0 then
         Write (In_Write, Input);
      end if;
      Close (In_Write);
      Exit_Code := Wait (Handle);
      declare
         Result : Unbounded_String;
         Buf    : String (1 .. 4_096);
         N      : Integer;
      begin
         loop
            N := Read (Out_Read, Buf);
            exit when N <= 0;
            Append (Result, Buf (1 .. N));
         end loop;
         Close (Out_Read);
         Coyote_Ncurses.Resume;
         TUI_State.Signal_Render;
         if Exit_Code /= 0 then
            return "";
         end if;
         declare
            S : constant String := To_String (Result);
         begin
            if S'Length > 0
              and then S (S'Last) = Ada.Characters.Latin_1.LF
            then
               return S (S'First .. S'Last - 1);
            end if;
            return S;
         end;
      end;
   exception
      when others =>
         Coyote_Ncurses.Resume;
         TUI_State.Signal_Render;
         return "";
   end Run_Fzf;

   --  ── Editor flow ──────────────────────────────────────────────────────

   procedure Run_Editor (Is_Steer : Boolean) is
      use GNATCOLL.OS.Process;
      Path_Buf  : Coyote_TUI_Terminal.Tmp_Path_Buf;
      FD_Int    : Integer;
      Path_Str  : String (1 .. Coyote_TUI_Terminal.TMP_PATH_CAP);
      Path_Len  : Natural;
      Args      : Argument_List;
      Handle    : Process_Handle;
      Editor    : constant String :=
        Ada.Environment_Variables.Value ("EDITOR", "vi");
   begin
      Coyote_TUI_Terminal.Make_Tempfile (Path_Buf, FD_Int);
      if FD_Int < 0 then
         return;
      end if;
      Interfaces.C.To_Ada (Path_Buf, Path_Str, Path_Len, Trim_Nul => True);
      declare
         Path : constant String := Path_Str (1 .. Path_Len);
         TF   : Ada.Text_IO.File_Type;
      begin
         Coyote_TUI_Terminal.Close_FD (FD_Int);
         Ada.Text_IO.Create (TF, Ada.Text_IO.Out_File, Path);
         Ada.Text_IO.Put_Line
           (TF, "# Enter your prompt below.  Lines starting with # are stripped.");
         Ada.Text_IO.New_Line (TF);
         Ada.Text_IO.Close (TF);

         Coyote_Ncurses.Suspend;
         Args.Append (Editor);
         Args.Append (Path);
         Handle := Start (Args => Args);
         declare
            Exit_Code : constant Integer := Wait (Handle);
            pragma Unreferenced (Exit_Code);
         begin
            null;
         end;
         --  Read back content, strip comment lines.
         declare
            Prompt_Buf : Unbounded_String;
            RF         : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Open (RF, Ada.Text_IO.In_File, Path);
            while not Ada.Text_IO.End_Of_File (RF) loop
               declare
                  Line : constant String := Ada.Text_IO.Get_Line (RF);
               begin
                  if Line'Length = 0 or else Line (Line'First) /= '#' then
                     Append (Prompt_Buf, Line);
                     Append (Prompt_Buf, Ada.Characters.Latin_1.LF);
                  end if;
               end;
            end loop;
            Ada.Text_IO.Close (RF);
            --  Strip trailing newlines.
            while Length (Prompt_Buf) > 0
              and then Element (Prompt_Buf, Length (Prompt_Buf))
                         = Ada.Characters.Latin_1.LF
            loop
               Delete (Prompt_Buf, Length (Prompt_Buf), Length (Prompt_Buf));
            end loop;
            if Length (Prompt_Buf) > 0 then
               Prompt_Queue.Enqueue (To_String (Prompt_Buf), Is_Steer);
            end if;
         end;
         Ada.Directories.Delete_File (Path);
         Coyote_Ncurses.Resume;
         TUI_State.Signal_Render;
      end;
   exception
      when others =>
         Coyote_Ncurses.Resume;
         TUI_State.Signal_Render;
   end Run_Editor;

   --  ── Command-line overlay ─────────────────────────────────────────────
   --
   --  Called from within UI_Task; reads keystrokes in a blocking spin
   --  (nodelay=TRUE, tight 5 ms pause) and draws into Status_Win.
   --  Returns "" on Escape, the typed string on Enter.

   function Read_Command_Line (Prompt_Char : Character := ':') return String
   is
      use Coyote_Ncurses;
      Buf : Unbounded_String;
      Ch  : Integer;
   begin
      Curs_Set (1);
      Wmove     (Status_Win, 0, 0);
      Waddch    (Status_Win, Prompt_Char);
      Waddch    (Status_Win, ' ');
      Wclrtoeol (Status_Win);
      Wrefresh  (Status_Win);

      loop
         --  Spin until a key is available (nodelay is active).
         loop
            Ch := Wget_Wch (Stdscr);
            exit when Ch /= -1;
            delay 0.005;
         end loop;

         if Ch = 27 then
            --  ESC → cancel.
            Curs_Set (0);
            return "";
         elsif Ch = 13 or else Ch = 10
           or else Ch = Coyote_Ncurses.Key_Enter
         then
            --  Enter → confirm.
            Curs_Set (0);
            return To_String (Buf);
         elsif Ch = 127 or else Ch = 8
           or else Ch = Coyote_Ncurses.Key_Backspace
         then
            --  Backspace.
            if Length (Buf) > 0 then
               Delete (Buf, Length (Buf), Length (Buf));
               --  Redraw the command line.
               Wmove     (Status_Win, 0, 0);
               Waddch    (Status_Win, Prompt_Char);
               Waddch    (Status_Win, ' ');
               Waddstr   (Status_Win, To_String (Buf));
               Wclrtoeol (Status_Win);
               Wrefresh  (Status_Win);
            end if;
         elsif Ch >= 32 and then Ch < 127 then
            Append (Buf, Character'Val (Ch));
            Waddch   (Status_Win, Character'Val (Ch));
            Wrefresh (Status_Win);
         end if;
      end loop;
   end Read_Command_Line;

   --  ── Execute command ──────────────────────────────────────────────────

   procedure Execute_Command (Cmd : String) is
      First : Natural := Cmd'First;
   begin
      while First <= Cmd'Last and then Cmd (First) = ' ' loop
         First := First + 1;
      end loop;
      if First > Cmd'Last then
         return;
      end if;

      declare
         Verb_End : Natural := First;
      begin
         while Verb_End <= Cmd'Last and then Cmd (Verb_End) /= ' ' loop
            Verb_End := Verb_End + 1;
         end loop;
         declare
            Verb : constant String := Cmd (First .. Verb_End - 1);
            Rest : constant String :=
              (if Verb_End <= Cmd'Last
               then Cmd (Verb_End + 1 .. Cmd'Last)
               else "");
         begin
            if Verb = "send" then
               if Rest'Length > 0 then
                  Prompt_Queue.Enqueue (Rest, False);
               else
                  Run_Editor (Is_Steer => False);
               end if;
            elsif Verb = "help" then
               Run_Pager
                 ("Keybindings:" & Ada.Characters.Latin_1.LF
                  & "  i         open $EDITOR for prompt" & Ada.Characters.Latin_1.LF
                  & "  :         command overlay" & Ada.Characters.Latin_1.LF
                  & "  j/down    scroll down 1 line" & Ada.Characters.Latin_1.LF
                  & "  k/up      scroll up 1 line" & Ada.Characters.Latin_1.LF
                  & "  d         half page down" & Ada.Characters.Latin_1.LF
                  & "  u         half page up" & Ada.Characters.Latin_1.LF
                  & "  f/PgDn   full page down" & Ada.Characters.Latin_1.LF
                  & "  b/PgUp   full page up" & Ada.Characters.Latin_1.LF
                  & "  G         jump to tail (FOLLOW mode)" & Ada.Characters.Latin_1.LF
                  & "  g         jump to top" & Ada.Characters.Latin_1.LF
                  & "  ]         next tool segment" & Ada.Characters.Latin_1.LF
                  & "  [         prev tool segment" & Ada.Characters.Latin_1.LF
                  & "  }         next turn footer" & Ada.Characters.Latin_1.LF
                  & "  {         prev turn footer" & Ada.Characters.Latin_1.LF
                  & "  /         search" & Ada.Characters.Latin_1.LF
                  & "  n/N       next/prev search match" & Ada.Characters.Latin_1.LF
                  & "  q         return to FOLLOW mode" & Ada.Characters.Latin_1.LF
                  & "Commands: :send, :stop, :pause, :resume, :new,"
                  & " :model, :thinking, :compact, :stats,"
                  & " :models, :sessions, :help, :clear, :q" & Ada.Characters.Latin_1.LF,
                  "coyote TUI help");
            elsif Verb = "stats" then
               Run_Pager (TUI_State.Stats_Summary, "coyote stats");
            elsif Verb = "models" then
               declare
                  use LLM.Model_Registry;
                  Models : constant Model_Info_Vectors.Vector :=
                    Available_Models;
                  Buf    : Unbounded_String;
               begin
                  for M of Models loop
                     Append (Buf, To_String (M.Provider) & "/"
                             & To_String (M.Model_Id));
                     Append (Buf, Ada.Characters.Latin_1.HT);
                     Append (Buf, To_String (M.Name));
                     Append (Buf, Ada.Characters.Latin_1.LF);
                  end loop;
                  declare
                     use GNATCOLL.OS.Process;
                     Fzf_Args : Argument_List;
                     Sel      : Unbounded_String;
                  begin
                     Fzf_Args.Append ("fzf");
                     Fzf_Args.Append ("--with-nth=2..");
                     Fzf_Args.Append
                       ("--delimiter=" & Ada.Characters.Latin_1.HT);
                     Fzf_Args.Append ("--prompt=model> ");
                     Sel := To_Unbounded_String
                              (Run_Fzf (To_String (Buf), Fzf_Args));
                     if Length (Sel) > 0 then
                        declare
                           S   : constant String  := To_String (Sel);
                           Tab : constant Natural :=
                             Ada.Strings.Fixed.Index
                               (S, (1 => Ada.Characters.Latin_1.HT));
                           Mid : constant String :=
                             (if Tab > 0
                              then S (S'First .. Tab - 1) else S);
                        begin
                           if Mid'Length > 0 then
                              Prompt_Queue.Enqueue (":model " & Mid, False);
                           end if;
                        end;
                     end if;
                  end;
               end;
            elsif Verb = "sessions" then
               declare
                  use Session_Lister;
                  Sessions : constant Session_Vectors.Vector :=
                    List_Sessions (Ada.Directories.Current_Directory);
                  Buf      : Unbounded_String;
               begin
                  for S of Sessions loop
                     Append (Buf, To_String (S.UUID));
                     Append (Buf, Ada.Characters.Latin_1.HT);
                     Append (Buf, To_String (S.Name));
                     Append (Buf, Ada.Characters.Latin_1.HT);
                     Append (Buf, Format_Timestamp (To_String (S.Date)));
                     Append (Buf, Ada.Characters.Latin_1.HT);
                     Append (Buf, To_String (S.Snippet));
                     Append (Buf, Ada.Characters.Latin_1.LF);
                  end loop;
                  declare
                     use GNATCOLL.OS.Process;
                     Fzf_Args : Argument_List;
                     Sel      : Unbounded_String;
                  begin
                     Fzf_Args.Append ("fzf");
                     Fzf_Args.Append ("--with-nth=2..");
                     Fzf_Args.Append
                       ("--delimiter=" & Ada.Characters.Latin_1.HT);
                     Fzf_Args.Append ("--prompt=session> ");
                     Sel := To_Unbounded_String
                              (Run_Fzf (To_String (Buf), Fzf_Args));
                     if Length (Sel) > 0 then
                        declare
                           S    : constant String  := To_String (Sel);
                           Tab  : constant Natural :=
                             Ada.Strings.Fixed.Index
                               (S, (1 => Ada.Characters.Latin_1.HT));
                           UUID : constant String :=
                             (if Tab > 0
                              then S (S'First .. Tab - 1) else S);
                        begin
                           if UUID'Length > 0 then
                              Prompt_Queue.Enqueue
                                (":session " & UUID, False);
                           end if;
                        end;
                     end if;
                  end;
               end;
            elsif Verb = "clear" then
               TUI_State.Signal_Render;
            elsif Verb = "q" then
               Prompt_Queue.Signal_Shutdown;
            else
               --  Forward to agent: :stop, :pause, :resume, :model, etc.
               Prompt_Queue.Enqueue (":" & Cmd, False);
            end if;
         end;
      end;
   end Execute_Command;

   --  ── Scroll helpers ───────────────────────────────────────────────────

   procedure Scroll (Lines : Integer) is
      Top   : Natural := TUI_State.Viewport_Top;
      Count : constant Natural := Buffer.Count;
   begin
      if Count = 0 then
         return;
      end if;
      if Lines < 0 then
         if Top > 1 then
            if Natural (abs Lines) >= Top - 1 then
               Top := 1;
            else
               Top := Top - Natural (abs Lines);
            end if;
         end if;
      else
         Top := Top + Natural (Lines);
         if Top > Count then
            Top := Count;
         end if;
      end if;
      TUI_State.Set_Viewport (Top);
   end Scroll;

   function Page_Size return Natural is
      Rows : constant Integer := Coyote_Ncurses.Lines;
   begin
      if Rows > 4 then
         return Natural (Rows) - 4;
      end if;
      return 1;
   end Page_Size;

   function Next_Seg (From : Positive; Kind : Segment_Kind) return Natural is
      Count : constant Natural := Buffer.Count;
   begin
      for I in From .. Count loop
         if Buffer.Get (I).Kind = Kind then
            return I;
         end if;
      end loop;
      return 0;
   end Next_Seg;

   function Prev_Seg (From : Positive; Kind : Segment_Kind) return Natural is
   begin
      if From = 1 then
         return 0;
      end if;
      for I in reverse 1 .. From - 1 loop
         if Buffer.Get (I).Kind = Kind then
            return I;
         end if;
      end loop;
      return 0;
   end Prev_Seg;

   --  ── Handle_Key ───────────────────────────────────────────────────────
   --
   --  Dispatch a single key code received from Wget_Wch.  Called only
   --  from UI_Task_T so all ncurses calls are confined to one task.

   procedure Handle_Key (Ch : Integer) is
      Nav : constant Nav_Mode := TUI_State.Current_Nav;
   begin
      --  ── Resize event ─────────────────────────────────────────────────
      if Ch = Coyote_Ncurses.Key_Resize then
         declare
            Rows : constant Integer := Coyote_Ncurses.Lines;
            Cols : constant Integer := Coyote_Ncurses.Cols;
         begin
            Resize_Windows (Rows, Cols);
            TUI_State.Signal_Render;
         end;
         return;
      end if;

      --  ── Arrow / page keys ────────────────────────────────────────────
      if Ch = Coyote_Ncurses.Key_Up then
         if Nav = Follow then
            TUI_State.Set_Nav_Mode (Scroll);
            TUI_State.Set_Viewport
              (Natural'Max (1, Buffer.Count - Page_Size));
         else
            Scroll (-1);
         end if;
         return;
      end if;

      if Ch = Coyote_Ncurses.Key_Down then
         if Nav = Follow then
            TUI_State.Set_Nav_Mode (Scroll);
         else
            Scroll (1);
         end if;
         return;
      end if;

      if Ch = Coyote_Ncurses.Key_Ppage then
         if Nav = Follow then
            TUI_State.Set_Nav_Mode (Scroll);
            TUI_State.Set_Viewport
              (Natural'Max (1, Buffer.Count - Page_Size));
         end if;
         Scroll (-Page_Size);
         return;
      end if;

      if Ch = Coyote_Ncurses.Key_Npage then
         if Nav = Follow then
            TUI_State.Set_Nav_Mode (Scroll);
         end if;
         Scroll (Page_Size);
         return;
      end if;

      --  ── Character keys ───────────────────────────────────────────────
      if Ch < 0 or else Ch > 127 then
         return;
      end if;

      declare
         B : constant Character := Character'Val (Ch);
      begin
         if Nav = Follow then
            case B is
               when 'i' =>
                  Run_Editor (Is_Steer => TUI_State.Is_Streaming);
               when ':' =>
                  declare
                     Cmd : constant String := Read_Command_Line;
                  begin
                     if Cmd'Length > 0 then
                        Execute_Command (Cmd);
                     end if;
                     TUI_State.Signal_Render;
                  end;
               when 'G' =>
                  null;  --  already following tail
               when 'j' | 'k' | 'u' | 'd' | 'f' | 'b' | 'g' =>
                  TUI_State.Set_Nav_Mode (Scroll);
                  case B is
                     when 'j' => Scroll (1);
                     when 'k' => Scroll (-1);
                     when 'd' => Scroll (Page_Size / 2 + 1);
                     when 'u' => Scroll (-(Page_Size / 2 + 1));
                     when 'f' => Scroll (Page_Size);
                     when 'b' => Scroll (-Page_Size);
                     when 'g' => TUI_State.Set_Viewport (1);
                     when others => null;
                  end case;
               when others => null;
            end case;

         else  --  Scroll mode
            case B is
               when 'q' | 'G' =>
                  TUI_State.Set_Nav_Mode (Follow);
                  TUI_State.Set_Viewport
                    (Natural'Max (1, Buffer.Count - Page_Size + 1));
               when 'g' =>
                  TUI_State.Set_Viewport (1);
               when 'j' => Scroll (1);
               when 'k' => Scroll (-1);
               when 'd' => Scroll (Page_Size / 2 + 1);
               when 'u' => Scroll (-(Page_Size / 2 + 1));
               when 'f' => Scroll (Page_Size);
               when 'b' => Scroll (-Page_Size);
               when ']' =>
                  declare
                     N : constant Natural :=
                       Next_Seg
                         (Natural'Max (1, TUI_State.Viewport_Top + 1),
                          Tool_Segment);
                  begin
                     if N > 0 then
                        TUI_State.Set_Viewport (N);
                     end if;
                  end;
               when '[' =>
                  declare
                     N : constant Natural :=
                       Prev_Seg
                         (Natural'Max (1, TUI_State.Viewport_Top),
                          Tool_Segment);
                  begin
                     if N > 0 then
                        TUI_State.Set_Viewport (N);
                     end if;
                  end;
               when '}' =>
                  declare
                     N : constant Natural :=
                       Next_Seg
                         (Natural'Max (1, TUI_State.Viewport_Top + 1),
                          Turn_Footer);
                  begin
                     if N > 0 then
                        TUI_State.Set_Viewport (N);
                     end if;
                  end;
               when '{' =>
                  declare
                     N : constant Natural :=
                       Prev_Seg
                         (Natural'Max (1, TUI_State.Viewport_Top),
                          Turn_Footer);
                  begin
                     if N > 0 then
                        TUI_State.Set_Viewport (N);
                     end if;
                  end;
               when Ada.Characters.Latin_1.CR | Ada.Characters.Latin_1.LF =>
                  --  Show tool detail when the viewport is on a Tool_Segment.
                  declare
                     Top : constant Natural := TUI_State.Viewport_Top;
                  begin
                     if Top >= 1 and then Top <= Buffer.Count then
                        declare
                           S : constant Segment := Buffer.Get (Top);
                        begin
                           if S.Kind = Tool_Segment then
                              Run_Pager
                                (To_String (S.Tool_Name)
                                 & Ada.Characters.Latin_1.LF
                                 & "Args: " & Ada.Characters.Latin_1.LF
                                 & To_String (S.Tool_Args)
                                 & Ada.Characters.Latin_1.LF
                                 & "Result: " & Ada.Characters.Latin_1.LF
                                 & To_String (S.Content),
                                 "tool: " & To_String (S.Tool_Name));
                           end if;
                        end;
                     end if;
                  end;
               when '/' =>
                  declare
                     Term : constant String := Read_Command_Line ('/');
                  begin
                     TUI_State.Set_Search (Term);
                     if Term'Length > 0 then
                        TUI_State.Set_Search_Matches
                          (Compute_Matches (Term));
                     end if;
                     TUI_State.Signal_Render;
                  end;
               when 'n' | 'N' =>
                  TUI_State.Advance_Search (if B = 'n' then +1 else -1);
               when 'i' =>
                  Run_Editor (Is_Steer => TUI_State.Is_Streaming);
               when ':' =>
                  declare
                     Cmd : constant String := Read_Command_Line;
                  begin
                     if Cmd'Length > 0 then
                        Execute_Command (Cmd);
                     end if;
                     TUI_State.Signal_Render;
                  end;
               when others => null;
            end case;
         end if;
      end;
   end Handle_Key;

   --  ── UI_Task ──────────────────────────────────────────────────────────
   --
   --  Single task that owns all ncurses calls: polls Wget_Wch, dispatches
   --  keys, and re-renders whenever TUI_State.Render_Needed is set.

   task type UI_Task_T is
      entry Start;
   end UI_Task_T;

   task body UI_Task_T is
   begin
      select
         accept Start;
      or
         terminate;
      end select;

      UI_Loop :
      loop
         exit UI_Loop when TUI_State.Is_Stopped;

         declare
            Ch : constant Integer := Coyote_Ncurses.Wget_Wch (Stdscr);
         begin
            if Ch /= -1 then
               Handle_Key (Ch);
            end if;
         end;

         if TUI_State.Render_Needed then
            begin
               Do_Render;
            exception
               when others => null;
            end;
         end if;

         delay 0.02;  --  ~50 Hz
      end loop UI_Loop;

      --  Final cleanup: restore the terminal.
      begin
         Coyote_Ncurses.Endwin;
      exception
         when others => null;
      end;
   end UI_Task_T;

   --  Package-level task instance.
   UI_Task : UI_Task_T;

   --  ── Create ───────────────────────────────────────────────────────────

   procedure Create
     (F        : in out Instance;
      Win_Name : in     String)
   is
      Rows : Integer;
      Cols : Integer;
   begin
      F.Created := True;
      TUI_State.Set_Win_Name (Win_Name);

      Use_Color := not Ada.Environment_Variables.Exists ("NO_COLOR");
      Stdscr := Coyote_Ncurses.Init;

      --  Define colour pairs used in Do_Render.
      if Use_Color then
         Coyote_Ncurses.Init_Pair
           (PAIR_YELLOW,
            Interfaces.C.short (Coyote_Ncurses.COLOR_YELLOW),
            Interfaces.C.short (Coyote_Ncurses.COLOR_DEFAULT));
         Coyote_Ncurses.Init_Pair
           (PAIR_RED,
            Interfaces.C.short (Coyote_Ncurses.COLOR_RED),
            Interfaces.C.short (Coyote_Ncurses.COLOR_DEFAULT));

      end if;
      Rows := Coyote_Ncurses.Lines;
      Cols := Coyote_Ncurses.Cols;
      Resize_Windows
        ((if Rows >= 4 then Rows else 4),
         (if Cols >= 20 then Cols else 20));

      TUI_State.Set_Started;
      UI_Task.Start;
      TUI_State.Signal_Render;
   end Create;

   --  ── Set_Status ───────────────────────────────────────────────────────

   overriding
   procedure Set_Status
     (F    : in out Instance;
      Text :        String)
   is
      pragma Unreferenced (F);
   begin
      TUI_State.Set_Status (Text);
   end Set_Status;

   --  ── Set_Mode ─────────────────────────────────────────────────────────

   overriding
   procedure Set_Mode
     (F    : in out Instance;
      Mode :        Coyote_App.Frontend.Run_Mode)
   is
      pragma Unreferenced (F);
   begin
      TUI_State.Set_Mode (Mode);
      TUI_State.Set_Streaming (Mode = Running);
   end Set_Mode;

   --  ── Append_Text ──────────────────────────────────────────────────────

   overriding
   procedure Append_Text
     (F    : in out Instance;
      Text :        String)
   is
      pragma Unreferenced (F);
   begin
      if Buffer.Count = 0
        or else Buffer.Last_Kind /= Assistant_Text
      then
         declare
            S : constant Segment :=
              (Kind     => Assistant_Text,
               Complete => False,
               Content  => To_Unbounded_String (Text),
               others   => <>);
         begin
            Buffer.Append_Segment (S);
         end;
      else
         Buffer.Update_Last_Content (Text);
      end if;
      TUI_State.Signal_Render;
   end Append_Text;

   --  ── End_Text_Block ───────────────────────────────────────────────────

   overriding
   procedure End_Text_Block (F : in out Instance) is
      pragma Unreferenced (F);
   begin
      Buffer.Set_Last_Complete;
   end End_Text_Block;

   --  ── Begin_Thinking ───────────────────────────────────────────────────

   overriding
   procedure Begin_Thinking (F : in out Instance) is
      pragma Unreferenced (F);
      S : constant Segment :=
        (Kind   => Thinking_Block,
         others => <>);
   begin
      Buffer.Append_Segment (S);
      TUI_State.Signal_Render;
   end Begin_Thinking;

   --  ── Append_Thinking ──────────────────────────────────────────────────

   overriding
   procedure Append_Thinking
     (F    : in out Instance;
      Text :        String)
   is
      pragma Unreferenced (F);
   begin
      Buffer.Update_Last_Thinking (Text);
      TUI_State.Signal_Render;
   end Append_Thinking;

   --  ── End_Thinking ─────────────────────────────────────────────────────

   overriding
   procedure End_Thinking (F : in out Instance) is
      pragma Unreferenced (F);
   begin
      null;
   end End_Thinking;

   --  ── Begin_Tool ───────────────────────────────────────────────────────

   overriding
   procedure Begin_Tool
     (F          : in out Instance;
      Name       :        String;
      Args_Json  :        String;
      Session_Id :        String;
      Tool_Id    :        String)
   is
      pragma Unreferenced (F, Session_Id);
      S : constant Segment :=
        (Kind      => Tool_Segment,
         Tool_Name => To_Unbounded_String (Name),
         Tool_Args => To_Unbounded_String (Args_Json),
         Tool_Id   => To_Unbounded_String (Tool_Id),
         T_Status  => Running,
         others    => <>);
   begin
      Buffer.Append_Segment (S);
      TUI_State.Signal_Render;
   end Begin_Tool;

   --  ── End_Tool ─────────────────────────────────────────────────────────

   overriding
   procedure End_Tool
     (F           : in out Instance;
      Tool_Id     :        String;
      Status      :        Coyote_App.Frontend.Tool_End_Status;
      Result_Text :        String := "")
   is
      pragma Unreferenced (F);
      Stat : constant Tool_Run_Status :=
        (case Status is
         when Coyote_App.Frontend.Success   => Tool_Run_Status'(Success),
         when Coyote_App.Frontend.Error     => Tool_Run_Status'(Error),
         when Coyote_App.Frontend.Cancelled => Tool_Run_Status'(Cancelled));
   begin
      Buffer.End_Tool_Segment (Tool_Id, Stat, Result_Text);
      TUI_State.Signal_Render;
   end End_Tool;

   --  ── Append_Turn_Footer ───────────────────────────────────────────────

   overriding
   procedure Append_Turn_Footer
     (F    : in out Instance;
      Text :        String)
   is
      pragma Unreferenced (F);
      S : constant Segment :=
        (Kind    => Turn_Footer,
         Content => To_Unbounded_String (Text),
         others  => <>);
   begin
      Buffer.Append_Segment (S);
      TUI_State.Signal_Render;
   end Append_Turn_Footer;

   --  ── Append_Notice ────────────────────────────────────────────────────

   overriding
   procedure Append_Notice
     (F    : in out Instance;
      Kind :        Coyote_App.Frontend.Notice_Kind;
      Text :        String)
   is
      pragma Unreferenced (F);
      S : constant Segment :=
        (Kind    => System_Notice,
         Sev     => Kind,
         Content => To_Unbounded_String (Text),
         others  => <>);
   begin
      Buffer.Append_Segment (S);
      TUI_State.Signal_Render;
   end Append_Notice;

   --  ── Show_Detail ──────────────────────────────────────────────────────

   overriding
   procedure Show_Detail
     (F       : in out Instance;
      Title   :        String;
      Content :        String)
   is
      pragma Unreferenced (F);
   begin
      Run_Pager (Content, Title);
   end Show_Detail;

   --  ── Set_Stats_Summary ────────────────────────────────────────────────

   procedure Set_Stats_Summary
     (F    : in out Instance;
      Text :        String)
   is
      pragma Unreferenced (F);
   begin
      TUI_State.Set_Stats_Summary (Text);
   end Set_Stats_Summary;

   --  ── Testing-support subprograms ──────────────────────────────────────

   procedure Clear_Buffer (F : in out Instance) is
      pragma Unreferenced (F);
   begin
      Buffer.Clear;
      TUI_State.Set_Search_Matches (Match_Vectors.Empty_Vector);
      TUI_State.Set_Stats_Summary ("");
   end Clear_Buffer;

   function Match_Count_For
     (F    : in out Instance;
      Term :        String) return Natural
   is
      pragma Unreferenced (F);
      Matches : constant Match_Vectors.Vector := Compute_Matches (Term);
   begin
      TUI_State.Set_Search_Matches (Matches);
      return Natural (Matches.Length);
   end Match_Count_For;

   procedure Advance_Search (F : in out Instance; Dir : Integer) is
      pragma Unreferenced (F);
   begin
      TUI_State.Advance_Search (Dir);
   end Advance_Search;

   function Current_Search_Seg (F : Instance) return Natural is
      pragma Unreferenced (F);
   begin
      return TUI_State.Search_Seg;
   end Current_Search_Seg;

   function Stats_Summary_Text (F : Instance) return String is
      pragma Unreferenced (F);
   begin
      return TUI_State.Stats_Summary;
   end Stats_Summary_Text;


   --  ── Read_Prompt ──────────────────────────────────────────────────────

   overriding
   function Read_Prompt
     (F : in out Instance) return String
   is
      pragma Unreferenced (F);
      E : Prompt_Entry;
   begin
      Prompt_Queue.Dequeue (E);
      if Prompt_Queue.Is_Shutdown then
         return "";
      end if;
      return To_String (E.Text);
   end Read_Prompt;

   --  ── Shutdown ─────────────────────────────────────────────────────────

   overriding
   procedure Shutdown (F : in out Instance) is
      pragma Unreferenced (F);
   begin
      Prompt_Queue.Signal_Shutdown;
      TUI_State.Signal_Stop;
   end Shutdown;

end Coyote_App.Frontend.TUI;
