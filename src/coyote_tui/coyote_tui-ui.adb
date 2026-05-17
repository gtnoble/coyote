--  Coyote_TUI.UI body — terminal input and render task.
--
--  All ncurses state (windows, keys, geometry) is local to the task body.
--  External state is accessed only through the Conv/PQ/Nav discriminants.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;        use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces;
with Interfaces.C;

with Coyote_Ncurses;
with Coyote_TUI_Terminal;
with Coyote_TUI.Commands;
with Coyote_TUI.Render;
with Coyote_TUI.Scroll;
with Coyote_TUI.Search;
with Coyote_TUI.Segments;
with Coyote_TUI.Sink.Ncurses_Sink;
with Coyote_TUI.Viewport;
with LLM.Model_Registry;
with Session_Lister;
with GNATCOLL.OS.Process;
with GNATCOLL.OS.FS;
with Coyote_App.Utils;             use Coyote_App.Utils;
use type Coyote_TUI.Segments.Segment_Kind;
use type Coyote_TUI.Viewport.Height_Array_Access;

package body Coyote_TUI.UI is

   --  ── Render helpers ───────────────────────────────────────────────────

   --  Pair indices.  Must match Render body constants.
   PAIR_YELLOW : constant Interfaces.C.short := 1;
   PAIR_RED    : constant Interfaces.C.short := 2;

   --  ── External-program helpers ─────────────────────────────────────────

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
            EC : constant Integer := Wait (Handle);
            pragma Unreferenced (EC);
         begin
            null;
         end;
         Ada.Directories.Delete_File (Path);
         Coyote_Ncurses.Resume;
      end;
   exception
      when others => Coyote_Ncurses.Resume;
   end Run_Pager;

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
         return "";
   end Run_Fzf;

   procedure Run_Editor
     (PQ         : not null access Coyote_TUI.Prompt_Queue.Queue;
      Is_Steer   : Boolean)
   is
      pragma Unreferenced (Is_Steer);
      use GNATCOLL.OS.Process;
      Path_Buf : Coyote_TUI_Terminal.Tmp_Path_Buf;
      FD_Int   : Integer;
      Path_Str : String (1 .. Coyote_TUI_Terminal.TMP_PATH_CAP);
      Path_Len : Natural;
      Args     : Argument_List;
      Handle   : Process_Handle;
      Editor   : constant String :=
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
           (TF,
            "# Enter your prompt below.  Lines starting with # are stripped.");
         Ada.Text_IO.New_Line (TF);
         Ada.Text_IO.Close (TF);
         Coyote_Ncurses.Suspend;
         Args.Append (Editor);
         Args.Append (Path);
         Handle := Start (Args => Args);
         declare
            EC : constant Integer := Wait (Handle);
            pragma Unreferenced (EC);
         begin
            null;
         end;
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
                     Append (Prompt_Buf,
                             Ada.Characters.Latin_1.LF);
                  end if;
               end;
            end loop;
            Ada.Text_IO.Close (RF);
            while Length (Prompt_Buf) > 0
              and then Element (Prompt_Buf, Length (Prompt_Buf))
                         = Ada.Characters.Latin_1.LF
            loop
               Delete (Prompt_Buf,
                       Length (Prompt_Buf), Length (Prompt_Buf));
            end loop;
            if Length (Prompt_Buf) > 0 then
               PQ.Enqueue (To_String (Prompt_Buf));
            end if;
         end;
         Ada.Directories.Delete_File (Path);
         Coyote_Ncurses.Resume;
      end;
   exception
      when others => Coyote_Ncurses.Resume;
   end Run_Editor;

   --  ── Task body ────────────────────────────────────────────────────────

   task body Task_T is

      Stdscr      : Coyote_Ncurses.Window := Coyote_Ncurses.Null_Window;
      Content_Win : Coyote_Ncurses.Window := Coyote_Ncurses.Null_Window;
      Status_Win  : Coyote_Ncurses.Window := Coyote_Ncurses.Null_Window;
      Last_Rows   : Integer  := 0;
      Last_Cols   : Integer  := 0;
      Use_Col     : Boolean  := True;
      Heights     : Viewport.Height_Array_Access := null;

      Win_Name_Buf : Unbounded_String;

      --  ── Resize_Windows ────────────────────────────────────────────────

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
         Wbkgd (Status_Win, Coyote_Ncurses.A_Reverse);
         Last_Rows := Rows;
         Last_Cols := Cols;
         --  Invalidate height cache after resize.
         if Heights /= null then
            Heights.all := (others => 0);
         end if;
      end Resize_Windows;

      --  ── Do_Render ─────────────────────────────────────────────────────

      procedure Do_Render is
         Rows   : constant Integer := Coyote_Ncurses.Lines;
         Cols   : constant Integer := Coyote_Ncurses.Cols;
         Eff_R  : constant Integer := Integer'Max (4, Rows);
         Eff_C  : constant Integer := Integer'Max (20, Cols);
         Snap   : constant Coyote_TUI.Segments.Vector :=
                    Conv.Snapshot;
         VP     : constant Viewport.Cursor  := Nav.Get_Cursor;
         IsF    : constant Boolean           := Nav.Is_Following;
         Match  : constant Search.Match_Record := Nav.Current_Match;
         S_Seg  : constant Natural           :=
                    (if Nav.Search_Match_Count > 0
                     then Match.Seg_Index else 0);
         S_Off  : constant Natural           :=
                    (if S_Seg > 0 then Match.Byte_Offset else 0);
         S_Len  : constant Natural           :=
                    (if S_Seg > 0 then Match.Match_Len else 0);

         Content_Sink : Coyote_TUI.Sink.Ncurses_Sink.Instance := (Win => Content_Win);
         Status_Sink  : Coyote_TUI.Sink.Ncurses_Sink.Instance := (Win => Status_Win);
      begin
         if Eff_R /= Last_Rows or else Eff_C /= Last_Cols then
            Resize_Windows (Eff_R, Eff_C);
         end if;
         --  Invalidate cached height for any segment that transitioned from
         --  streaming to complete since the last render (so Populate_Heights
         --  will re-measure it with the full Markdown renderer).
         declare
            Stale : Natural;
         begin
            Nav.Take_Stale_Seg (Stale);
            if Stale >= 1
              and then Heights /= null
              and then Stale <= Heights'Last
            then
               Heights (Stale) := 0;
            end if;
         end;

         Coyote_TUI.Render.Render_Frame
           (Content_Out  => Content_Sink,
            Status_Out   => Status_Sink,
            Snap         => Snap,
            VP           => VP,
            Heights      => Heights,
            Win_Name     => To_String (Win_Name_Buf),
            Status_Text  => Nav.Status_Text,
            Is_Following => IsF,
            Search_Seg   => S_Seg,
            Search_Off   => S_Off,
            Search_Len   => S_Len,
            Cols         => Positive (Eff_C),
            Rows         => Positive (Eff_R),
            Use_Color    => Use_Col);

         Coyote_Ncurses.Doupdate;
      end Do_Render;

      --  ── Read_Command_Line ─────────────────────────────────────────────

      function Read_Command_Line
        (Prompt_Char : Character := ':') return String
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
            loop
               Ch := Wget_Wch (Stdscr);
               exit when Ch /= -1;
               delay 0.005;
            end loop;
            if Ch = 27 then
               Curs_Set (0);
               return "";
            elsif Ch = 13 or else Ch = 10
              or else Ch = Key_Enter
            then
               Curs_Set (0);
               return To_String (Buf);
            elsif Ch = 127 or else Ch = 8
              or else Ch = Key_Backspace
            then
               if Length (Buf) > 0 then
                  Delete (Buf, Length (Buf), Length (Buf));
                  Wmove     (Status_Win, 0, 0);
                  Waddch    (Status_Win, Prompt_Char);
                  Waddch    (Status_Win, ' ');
                  Waddstr   (Status_Win, To_String (Buf));
                  Wclrtoeol (Status_Win);
                  Wrefresh  (Status_Win);
               end if;
            elsif Ch >= 32 and then Ch < 127 then
               Append (Buf, Character'Val (Ch));
               Coyote_Ncurses.Waddch (Status_Win, Character'Val (Ch));
               Wrefresh (Status_Win);
            end if;
         end loop;
      end Read_Command_Line;

      --  ── Page_Size ─────────────────────────────────────────────────────

      function Page_Size return Natural is
         Rows : constant Integer := Coyote_Ncurses.Lines;
      begin
         return (if Rows > 4 then Natural (Rows) - 4 else 1);
      end Page_Size;

      --  ── Scroll_By ─────────────────────────────────────────────────────

      procedure Scroll_By (Shift : Integer) is
         Snap   : constant Coyote_TUI.Segments.Vector := Conv.Snapshot;
         Count  : constant Natural := Natural (Snap.Length);
         H      : Viewport.Height_Array
                    (1 .. Integer'Max (1, Count)) := (others => 1);
         VP     : Viewport.Cursor := Nav.Get_Cursor;
      begin
         if Count = 0 then
            return;
         end if;
         --  Use cached heights where available.
         if Heights /= null then
            for I in H'Range loop
               if I <= Heights'Last and then Heights (I) > 0 then
                  H (I) := Heights (I);
               end if;
            end loop;
         end if;
         if Viewport.Is_Following (VP) then
            VP := Coyote_TUI.Scroll.Follow_Start
                    (Snap, H (1 .. Count), Page_Size);
         end if;
         Nav.Set_Cursor
           (Coyote_TUI.Scroll.Advance (Snap, H (1 .. Count), VP, Shift));
      end Scroll_By;

      --  ── Jump_To_Seg ───────────────────────────────────────────────────

      procedure Jump_To_Seg (Seg : Positive) is
      begin
         Nav.Set_Cursor (Coyote_TUI.Scroll.To_Segment (Seg));
      end Jump_To_Seg;

      --  ── Seg_Under_Viewport ────────────────────────────────────────────

      function Seg_Under_Viewport return Natural is
         Snap : constant Coyote_TUI.Segments.Vector := Conv.Snapshot;
         Count : constant Natural := Natural (Snap.Length);
         VP    : constant Viewport.Cursor := Nav.Get_Cursor;
      begin
         if Count = 0 then
            return 0;
         end if;
         return (if Viewport.Is_Following (VP) then Count else VP.Seg);
      end Seg_Under_Viewport;

      --  ── Execute_UI_Command ────────────────────────────────────────────

      procedure Execute_UI_Command (Cmd : Commands.Command) is
         use Commands;
      begin
         case Cmd.Kind is

            when Send =>
               declare
                  Arg : constant String := To_String (Cmd.Arg);
               begin
                  if Arg'Length > 0 then
                     PQ.Enqueue (Arg);
                  else
                     Run_Editor (PQ, Is_Steer => Nav.Is_Streaming);
                  end if;
               end;

            when Help =>
               Run_Pager
                 ("Keybindings:" & Ada.Characters.Latin_1.LF
                  & "  i         open $EDITOR for prompt"
                  & Ada.Characters.Latin_1.LF
                  & "  :         command overlay"
                  & Ada.Characters.Latin_1.LF
                  & "  j/down    scroll down 1 line"
                  & Ada.Characters.Latin_1.LF
                  & "  k/up      scroll up 1 line"
                  & Ada.Characters.Latin_1.LF
                  & "  d         half page down"
                  & Ada.Characters.Latin_1.LF
                  & "  u         half page up"
                  & Ada.Characters.Latin_1.LF
                  & "  f/PgDn   full page down"
                  & Ada.Characters.Latin_1.LF
                  & "  b/PgUp   full page up"
                  & Ada.Characters.Latin_1.LF
                  & "  G         jump to tail (FOLLOW mode)"
                  & Ada.Characters.Latin_1.LF
                  & "  g         jump to top"
                  & Ada.Characters.Latin_1.LF
                  & "  ]         next tool segment"
                  & Ada.Characters.Latin_1.LF
                  & "  [         prev tool segment"
                  & Ada.Characters.Latin_1.LF
                  & "  }         next turn footer"
                  & Ada.Characters.Latin_1.LF
                  & "  {         prev turn footer"
                  & Ada.Characters.Latin_1.LF
                  & "  /         search"
                  & Ada.Characters.Latin_1.LF
                  & "  n/N       next/prev search match"
                  & Ada.Characters.Latin_1.LF
                  & "  q         return to FOLLOW mode"
                  & Ada.Characters.Latin_1.LF
                  & "Commands: :send, :stop, :pause, :resume, :new,"
                  & " :model, :thinking, :compact, :stats,"
                  & " :models, :sessions, :help, :clear, :q"
                  & Ada.Characters.Latin_1.LF,
                  "coyote TUI help");

            when Stats =>
               Run_Pager (Nav.Stats_Summary, "coyote stats");

            when Models_List =>
               declare
                  use LLM.Model_Registry;
                  Models : constant Model_Info_Vectors.Vector :=
                    Available_Models;
                  Buf    : Unbounded_String;
               begin
                  for M of Models loop
                     Append (Buf,
                             To_String (M.Provider) & "/"
                             & To_String (M.Model_Id));
                     Append (Buf, Ada.Characters.Latin_1.HT);
                     Append (Buf,
                             To_String (M.Provider) & "  "
                             & To_String (M.Name));
                     Append (Buf, Ada.Characters.Latin_1.LF);
                  end loop;
                  declare
                     use GNATCOLL.OS.Process;
                     Fzf_Args : Argument_List;
                  begin
                     Fzf_Args.Append ("fzf");
                     Fzf_Args.Append ("--with-nth=2..");
                     Fzf_Args.Append
                       ("--delimiter=" & Ada.Characters.Latin_1.HT);
                     Fzf_Args.Append ("--prompt=model> ");
                     declare
                        Sel : constant String :=
                          Run_Fzf (To_String (Buf), Fzf_Args);
                     begin
                        if Sel'Length > 0 then
                           declare
                              Tab : constant Natural :=
                                Ada.Strings.Fixed.Index
                                  (Sel, (1 => Ada.Characters.Latin_1.HT));
                              Mid : constant String :=
                                (if Tab > 0
                                 then Sel (Sel'First .. Tab - 1)
                                 else Sel);
                           begin
                              if Mid'Length > 0 then
                                 PQ.Enqueue (":model " & Mid);
                              end if;
                           end;
                        end if;
                     end;
                  end;
               end;

            when Sessions_List =>
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
                     Append (Buf,
                             Format_Timestamp (To_String (S.Date)));
                     Append (Buf, Ada.Characters.Latin_1.HT);
                     Append (Buf, To_String (S.Snippet));
                     Append (Buf, Ada.Characters.Latin_1.LF);
                  end loop;
                  declare
                     use GNATCOLL.OS.Process;
                     Fzf_Args : Argument_List;
                  begin
                     Fzf_Args.Append ("fzf");
                     Fzf_Args.Append ("--with-nth=2..");
                     Fzf_Args.Append
                       ("--delimiter=" & Ada.Characters.Latin_1.HT);
                     Fzf_Args.Append ("--prompt=session> ");
                     declare
                        Sel : constant String :=
                          Run_Fzf (To_String (Buf), Fzf_Args);
                     begin
                        if Sel'Length > 0 then
                           declare
                              Tab  : constant Natural :=
                                Ada.Strings.Fixed.Index
                                  (Sel, (1 => Ada.Characters.Latin_1.HT));
                              UUID : constant String :=
                                (if Tab > 0
                                 then Sel (Sel'First .. Tab - 1)
                                 else Sel);
                           begin
                              if UUID'Length > 0 then
                                 PQ.Enqueue (":session " & UUID);
                              end if;
                           end;
                        end if;
                     end;
                  end;
               end;

            when Clear =>
               Nav.Request_Render;

            when Quit =>
               Nav.Stop;
               PQ.Shutdown;

            when others =>
               --  Agent-directed command: forward via Prompt_Queue.
               declare
                  Pfx : constant String := Commands.Agent_Prefix (Cmd);
               begin
                  if Pfx'Length > 0 then
                     PQ.Enqueue (Pfx);
                  end if;
               end;
         end case;
      end Execute_UI_Command;

      --  ── Handle_Key ────────────────────────────────────────────────────

      procedure Handle_Key (Ch : Integer) is
         use Coyote_Ncurses;
         Is_Following : constant Boolean := Nav.Is_Following;
      begin
         if Ch = Key_Resize then
            Resize_Windows
              (Integer'Max (4, Lines),
               Integer'Max (20, Cols));
            Nav.Request_Render;
            return;
         end if;

         if Ch = Key_Up then
            Scroll_By (-1);
            return;
         end if;
         if Ch = Key_Down then
            if Is_Following then
               null;  --  already at tail
            else
               Scroll_By (1);
            end if;
            return;
         end if;
         if Ch = Key_Ppage then
            Scroll_By (-Page_Size);
            return;
         end if;
         if Ch = Key_Npage then
            Scroll_By (Page_Size);
            return;
         end if;

         if Ch < 0 or else Ch > 127 then
            return;
         end if;

         declare
            B : constant Character := Character'Val (Ch);
         begin
            case B is
               when 'G' =>
                  Nav.Follow;
               when 'g' =>
                  Nav.Set_Cursor ((Seg => 1, Offset => 0));
               when 'j' => Scroll_By (1);
               when 'k' => Scroll_By (-1);
               when 'd' => Scroll_By (Integer'Max (1, Page_Size / 2));
               when 'u' => Scroll_By (-Integer'Max (1, Page_Size / 2));
               when 'f' => Scroll_By (Page_Size);
               when 'b' => Scroll_By (-Page_Size);
               when 'q' =>
                  if Is_Following then
                     null;
                  else
                     Nav.Follow;
                  end if;

               when ']' =>
                  declare
                     Snap  : constant Coyote_TUI.Segments.Vector :=
                               Conv.Snapshot;
                     From  : constant Natural := Seg_Under_Viewport;
                     Next  : constant Natural :=
                       Coyote_TUI.Scroll.Next_Of_Kind
                         (Snap,
                          Natural'Max (1, From + 1),
                          Coyote_TUI.Segments.Tool_Segment);
                  begin
                     if Next > 0 then
                        Jump_To_Seg (Next);
                     end if;
                  end;

               when '[' =>
                  declare
                     Snap : constant Coyote_TUI.Segments.Vector :=
                              Conv.Snapshot;
                     From : constant Natural := Seg_Under_Viewport;
                     Prev : constant Natural :=
                       Coyote_TUI.Scroll.Prev_Of_Kind
                         (Snap,
                          Natural'Max (1, From),
                          Coyote_TUI.Segments.Tool_Segment);
                  begin
                     if Prev > 0 then
                        Jump_To_Seg (Prev);
                     end if;
                  end;

               when '}' =>
                  declare
                     Snap : constant Coyote_TUI.Segments.Vector :=
                              Conv.Snapshot;
                     From : constant Natural := Seg_Under_Viewport;
                     Next : constant Natural :=
                       Coyote_TUI.Scroll.Next_Of_Kind
                         (Snap,
                          Natural'Max (1, From + 1),
                          Coyote_TUI.Segments.Turn_Footer);
                  begin
                     if Next > 0 then
                        Jump_To_Seg (Next);
                     end if;
                  end;

               when '{' =>
                  declare
                     Snap : constant Coyote_TUI.Segments.Vector :=
                              Conv.Snapshot;
                     From : constant Natural := Seg_Under_Viewport;
                     Prev : constant Natural :=
                       Coyote_TUI.Scroll.Prev_Of_Kind
                         (Snap,
                          Natural'Max (1, From),
                          Coyote_TUI.Segments.Turn_Footer);
                  begin
                     if Prev > 0 then
                        Jump_To_Seg (Prev);
                     end if;
                  end;

               when Ada.Characters.Latin_1.CR
                  | Ada.Characters.Latin_1.LF =>
                  --  Show tool detail when viewport sits on a Tool_Segment.
                  declare
                     Seg_Idx : constant Natural := Seg_Under_Viewport;
                     Snap    : constant Coyote_TUI.Segments.Vector :=
                                 Conv.Snapshot;
                  begin
                     if Seg_Idx >= 1 and then Seg_Idx <= Natural (Snap.Length)
                     then
                        declare
                           S : constant Coyote_TUI.Segments.Segment :=
                                 Snap (Seg_Idx);
                        begin
                           if S.Kind = Coyote_TUI.Segments.Tool_Segment then
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
                     if Term'Length > 0 then
                        declare
                           Snap    : constant Coyote_TUI.Segments.Vector :=
                                       Conv.Snapshot;
                           Matches : constant Search.Match_Vector :=
                                       Coyote_TUI.Search.Compute_Matches
                                         (Snap, Term);
                        begin
                           Nav.Set_Search (Term, Matches);
                           if not Matches.Is_Empty then
                              Jump_To_Seg (Matches.First_Element.Seg_Index);
                           end if;
                        end;
                     else
                        Nav.Set_Search ("", Search.Match_Vectors.Empty_Vector);
                     end if;
                  end;

               when 'n' | 'N' =>
                  Nav.Advance_Search (if B = 'n' then +1 else -1);
                  declare
                     M : constant Search.Match_Record :=
                           Nav.Current_Match;
                  begin
                     if Nav.Search_Match_Count > 0 then
                        Jump_To_Seg (M.Seg_Index);
                     end if;
                  end;

               when 'i' =>
                  Run_Editor (PQ, Is_Steer => Nav.Is_Streaming);

               when ':' =>
                  declare
                     Str : constant String := Read_Command_Line;
                  begin
                     if Str'Length > 0 then
                        Execute_UI_Command (Commands.Parse (Str));
                     end if;
                     Nav.Request_Render;
                  end;

               when others =>
                  null;
            end case;
         end;
      end Handle_Key;

   begin  --  task body
      select
         accept Start (Win_Name : String; Use_Color : Boolean) do
            Win_Name_Buf := To_Unbounded_String (Win_Name);
            Use_Col      := Use_Color;
         end Start;
      or
         terminate;
      end select;

      --  ncurses initialisation.
      Stdscr := Coyote_Ncurses.Init;
      if Use_Col then
         Coyote_Ncurses.Init_Pair
           (PAIR_YELLOW,
            Interfaces.C.short (Coyote_Ncurses.COLOR_YELLOW),
            Interfaces.C.short (Coyote_Ncurses.COLOR_DEFAULT));
         Coyote_Ncurses.Init_Pair
           (PAIR_RED,
            Interfaces.C.short (Coyote_Ncurses.COLOR_RED),
            Interfaces.C.short (Coyote_Ncurses.COLOR_DEFAULT));
      end if;

      declare
         Rows : constant Integer :=
           Integer'Max (4,  Coyote_Ncurses.Lines);
         Cols : constant Integer :=
           Integer'Max (20, Coyote_Ncurses.Cols);
      begin
         Resize_Windows (Rows, Cols);
      end;

      Nav.Request_Render;
      Nav.Set_Win_Name (To_String (Win_Name_Buf));

      Main_Loop :
      loop
         exit Main_Loop when Nav.Is_Stopped;

         declare
            Ch : constant Integer :=
                   Coyote_Ncurses.Wget_Wch (Stdscr);
         begin
            if Ch /= -1 then
               Handle_Key (Ch);
            end if;
         end;

         declare
            Render_Pending : Boolean;
         begin
            Nav.Take_Render_Request (Render_Pending);
            if Render_Pending then
               begin
                  Do_Render;
               exception
                  when others => null;
               end;
            end if;
         end;

         delay 0.02;
      end loop Main_Loop;

      begin
         Coyote_Ncurses.Endwin;
      exception
         when others => null;
      end;

   exception
      when others =>
         begin
            Coyote_Ncurses.Endwin;
         exception
            when others => null;
         end;
   end Task_T;

end Coyote_TUI.UI;
