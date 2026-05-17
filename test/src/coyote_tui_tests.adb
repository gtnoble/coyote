--  Coyote_TUI_Tests body — AUnit tests for the Coyote_TUI pure subsystem.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit.Assertions;   use AUnit.Assertions;

with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Coyote_TUI.Commands;
use type Coyote_TUI.Commands.Command_Kind;
with Coyote_TUI.Render;
with Coyote_TUI.Scroll;
with Coyote_TUI.Search;
with Coyote_TUI.Segment_Ops;
with Coyote_TUI.Segments;    use Coyote_TUI.Segments;
with Coyote_TUI.Sink.String_Sink;
with Coyote_TUI.Viewport;    use Coyote_TUI.Viewport;
with Coyote_TUI.Nav_State;

package body Coyote_TUI_Tests is

   LF : constant Character := Ada.Characters.Latin_1.LF;

   --  ── Helpers ──────────────────────────────────────────────────────────

   function Mk_Seg
     (Kind     : Segment_Kind;
      Content  : String;
      Sev      : Notice_Kind   := Info;
      Complete : Boolean       := False) return Segment
   is
   begin
      return (Kind     => Kind,
              Content  => To_Unbounded_String (Content),
              Sev      => Sev,
              Complete => Complete,
              others   => <>);
   end Mk_Seg;

   function Mk_Tool
     (Name    : String;
      Args    : String;
      Tool_Id : String;
      Status  : Tool_Run_Status := Running;
      Result  : String          := "") return Segment
   is
   begin
      return (Kind      => Tool_Segment,
              Tool_Name => To_Unbounded_String (Name),
              Tool_Args => To_Unbounded_String (Args),
              Tool_Id   => To_Unbounded_String (Tool_Id),
              T_Status  => Status,
              Content   => To_Unbounded_String (Result),
              others    => <>);
   end Mk_Tool;

   --  ── Segment_Ops ──────────────────────────────────────────────────────

   procedure Test_Append_New (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Assert (V.Is_Empty, "initially empty");
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Assistant_Text, "hello"));
      Assert (Natural (V.Length) = 1, "one segment after append");
      Assert (To_String (V (1).Content) = "hello", "content preserved");
      Assert (V (1).Kind = Assistant_Text, "kind preserved");
   end Test_Append_New;

   procedure Test_Update_Last_Content (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "foo"));
      Coyote_TUI.Segment_Ops.Update_Last_Content (V, " bar");
      Assert (To_String (V (1).Content) = "foo bar",
              "Update_Last_Content appends to existing content");
   end Test_Update_Last_Content;

   procedure Test_Update_Last_Empty (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Coyote_TUI.Segment_Ops.Update_Last_Content (V, "oops");
      Assert (V.Is_Empty, "no-op on empty vector");
   end Test_Update_Last_Empty;

   procedure Test_Set_Last_Complete (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "x"));
      Assert (not V (1).Complete, "initially not complete");
      Coyote_TUI.Segment_Ops.Set_Last_Complete (V);
      Assert (V (1).Complete, "complete after Set_Last_Complete");
   end Test_Set_Last_Complete;

   procedure Test_Find_Tool (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "a"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Tool ("shell", "{}", "t1"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Tool ("shell", "{}", "t2"));
      Assert (Coyote_TUI.Segment_Ops.Find_Tool (V, "t1") = 2,
              "Find_Tool locates first tool by Tool_Id");
      Assert (Coyote_TUI.Segment_Ops.Find_Tool (V, "t2") = 3,
              "Find_Tool locates second tool by Tool_Id");
      Assert (Coyote_TUI.Segment_Ops.Find_Tool (V, "nope") = 0,
              "Find_Tool returns 0 for unknown id");
   end Test_Find_Tool;

   procedure Test_End_Tool (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Tool ("shell", "{}", "t1"));
      Assert (V (1).T_Status = Running, "initially Running");
      Coyote_TUI.Segment_Ops.End_Tool
        (V, "t1", "ok output", Success);
      Assert (V (1).T_Status = Success, "status updated to Success");
      Assert (To_String (V (1).Content) = "ok output",
              "result text stored in Content");
   end Test_End_Tool;

   procedure Test_Last_Kind (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Assert (Coyote_TUI.Segment_Ops.Last_Kind (V) = System_Notice,
              "empty vector returns System_Notice");
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Turn_Footer, "---"));
      Assert (Coyote_TUI.Segment_Ops.Last_Kind (V) = Turn_Footer,
              "Last_Kind reflects the last segment");
   end Test_Last_Kind;

   --  ── Scroll ───────────────────────────────────────────────────────────

   procedure Test_Total_Lines (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      H : constant Height_Array (1 .. 3) := (3, 5, 2);
   begin
      for I in 1 .. 3 loop
         Coyote_TUI.Segment_Ops.Append_New
           (V, Mk_Seg (Assistant_Text, "x"));
      end loop;
      Assert (Coyote_TUI.Scroll.Total_Lines (V, H) = 10,
              "Total_Lines sums all heights (3 + 5 + 2 = 10)");
   end Test_Total_Lines;

   procedure Test_Total_Lines_Empty (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      H : constant Height_Array (1 .. 1) := (1 => 5);
   begin
      Assert (Coyote_TUI.Scroll.Total_Lines (V, H) = 0,
              "Total_Lines returns 0 for empty segment vector");
   end Test_Total_Lines_Empty;

   procedure Test_Advance_Forward (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      H : constant Height_Array (1 .. 3) := (3, 5, 2);
      C : Cursor := (Seg => 1, Offset => 0);
      R : Cursor;
   begin
      for I in 1 .. 3 loop
         Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "x"));
      end loop;
      R := Coyote_TUI.Scroll.Advance (V, H, C, 2);
      Assert (R.Seg = 1 and then R.Offset = 2,
              "advance 2 within 3-line segment stays in same segment");
      R := Coyote_TUI.Scroll.Advance (V, H, R, 1);
      Assert (R.Seg = 2 and then R.Offset = 0,
              "advance 1 more crosses into segment 2");
   end Test_Advance_Forward;

   procedure Test_Advance_Backward (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      H : constant Height_Array (1 .. 3) := (3, 5, 2);
      C : Cursor := (Seg => 2, Offset => 0);
      R : Cursor;
   begin
      for I in 1 .. 3 loop
         Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "x"));
      end loop;
      R := Coyote_TUI.Scroll.Advance (V, H, C, -1);
      Assert (R.Seg = 1 and then R.Offset = 2,
              "backward from seg 2 offset 0 reaches seg 1 offset 2 (last line)");
   end Test_Advance_Backward;

   procedure Test_Advance_Clamp_Begin (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      H : constant Height_Array (1 .. 2) := (3, 5);
      C : Cursor := (Seg => 1, Offset => 0);
      R : Cursor;
   begin
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "x"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "y"));
      R := Coyote_TUI.Scroll.Advance (V, H, C, -100);
      Assert (R.Seg = 1 and then R.Offset = 0,
              "advance clamps at very beginning of document");
   end Test_Advance_Clamp_Begin;

   procedure Test_Follow_Start (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      H : constant Height_Array (1 .. 3) := (3, 4, 5);
      R : Cursor;
   begin
      for I in 1 .. 3 loop
         Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "x"));
      end loop;
      --  Total 12 lines, 8 visible.  Backwards accumulation:
      --    seg3 (5): acc=5 <= 8, continue
      --    seg2 (4): acc=9 > 8, skip 9-8=1 line in seg2
      --  Expected: (Seg=2, Offset=1).
      R := Coyote_TUI.Scroll.Follow_Start (V, H, 8);
      Assert (R.Seg = 2 and then R.Offset = 1,
              "Follow_Start: 8 visible of 12 total starts at seg 2, offset 1");
   end Test_Follow_Start;

   procedure Test_Follow_Start_All_Fit (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      H : constant Height_Array (1 .. 2) := (3, 3);
      R : Cursor;
   begin
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "x"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "y"));
      --  6 total lines, 20 visible -> all fit, start at seg 1, offset 0.
      R := Coyote_TUI.Scroll.Follow_Start (V, H, 20);
      Assert (R.Seg = 1 and then R.Offset = 0,
              "Follow_Start when all content fits returns seg 1 offset 0");
   end Test_Follow_Start_All_Fit;

   procedure Test_Next_Of_Kind (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "a"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Turn_Footer, "---"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "b"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Turn_Footer, "---"));
      Assert (Coyote_TUI.Scroll.Next_Of_Kind (V, 1, Turn_Footer) = 2,
              "Next_Of_Kind: first Turn_Footer from seg 1 is at seg 2");
      Assert (Coyote_TUI.Scroll.Next_Of_Kind (V, 3, Turn_Footer) = 4,
              "Next_Of_Kind: second Turn_Footer from seg 3 is at seg 4");
      Assert (Coyote_TUI.Scroll.Next_Of_Kind (V, 5, Turn_Footer) = 0,
              "Next_Of_Kind: returns 0 when out of range");
   end Test_Next_Of_Kind;

   procedure Test_Prev_Of_Kind (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Turn_Footer, "---"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Assistant_Text, "b"));
      Coyote_TUI.Segment_Ops.Append_New (V, Mk_Seg (Turn_Footer, "---"));
      Assert (Coyote_TUI.Scroll.Prev_Of_Kind (V, 3, Turn_Footer) = 1,
              "Prev_Of_Kind: Turn_Footer before seg 3 is at seg 1");
      Assert (Coyote_TUI.Scroll.Prev_Of_Kind (V, 1, Turn_Footer) = 0,
              "Prev_Of_Kind: returns 0 from seg 1");
   end Test_Prev_Of_Kind;

   --  ── Search ───────────────────────────────────────────────────────────

   procedure Test_Matches_Empty_Term (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      M : Coyote_TUI.Search.Match_Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Assistant_Text, "hello"));
      M := Coyote_TUI.Search.Compute_Matches (V, "");
      Assert (M.Is_Empty, "empty term yields no matches");
   end Test_Matches_Empty_Term;

   procedure Test_Matches_No_Match (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      M : Coyote_TUI.Search.Match_Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Assistant_Text, "hello world"));
      M := Coyote_TUI.Search.Compute_Matches (V, "xyz");
      Assert (M.Is_Empty, "non-matching term yields no matches");
   end Test_Matches_No_Match;

   procedure Test_Matches_Case_Insensitive (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      M : Coyote_TUI.Search.Match_Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Assistant_Text, "hello world"));
      M := Coyote_TUI.Search.Compute_Matches (V, "HELLO");
      Assert (Natural (M.Length) = 1, "case-insensitive: HELLO matches hello");
      Assert (M (1).Seg_Index = 1, "match found in segment 1");
   end Test_Matches_Case_Insensitive;

   procedure Test_Matches_Byte_Offset (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      M : Coyote_TUI.Search.Match_Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Assistant_Text, "hello world"));
      M := Coyote_TUI.Search.Compute_Matches (V, "world");
      Assert (Natural (M.Length) = 1, "one match");
      Assert (M (1).Byte_Offset = 6,
              "byte offset of 'world' in 'hello world' is 6 (0-based)");
      Assert (M (1).Match_Len = 5, "match length equals term length (5)");
   end Test_Matches_Byte_Offset;

   procedure Test_Matches_Multi_Segment (T : in out Test) is
      pragma Unreferenced (T);
      V : Vector;
      M : Coyote_TUI.Search.Match_Vector;
   begin
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Assistant_Text, "foo bar"));
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Turn_Footer, "---"));
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Assistant_Text, "baz qux"));
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Turn_Footer, "---"));
      Coyote_TUI.Segment_Ops.Append_New
        (V, Mk_Seg (Assistant_Text, "another foo here"));
      M := Coyote_TUI.Search.Compute_Matches (V, "foo");
      Assert (Natural (M.Length) = 2,
              "two segments contain 'foo' (seg 1 and seg 5)");
      Assert (M (1).Seg_Index = 1, "first match is in segment 1");
      Assert (M (2).Seg_Index = 5, "second match is in segment 5");
   end Test_Matches_Multi_Segment;

   procedure Test_Search_Advance_Forward (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Search;
      M : Match_Vector;
   begin
      M.Append ((Seg_Index => 1, Byte_Offset => 0, Match_Len => 3));
      M.Append ((Seg_Index => 3, Byte_Offset => 0, Match_Len => 3));
      M.Append ((Seg_Index => 5, Byte_Offset => 0, Match_Len => 3));
      Assert (Coyote_TUI.Search.Advance (M, 1, +1) = 2, "1 -> 2 forward");
      Assert (Coyote_TUI.Search.Advance (M, 3, +1) = 1, "3 -> 1 wrap forward");
   end Test_Search_Advance_Forward;

   procedure Test_Search_Advance_Backward (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Search;
      M : Match_Vector;
   begin
      M.Append ((Seg_Index => 1, Byte_Offset => 0, Match_Len => 3));
      M.Append ((Seg_Index => 3, Byte_Offset => 0, Match_Len => 3));
      M.Append ((Seg_Index => 5, Byte_Offset => 0, Match_Len => 3));
      Assert (Coyote_TUI.Search.Advance (M, 1, -1) = 3,
              "1 -> 3 backward wrap");
   end Test_Search_Advance_Backward;

   procedure Test_Search_Advance_Empty (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Search;
      M : Match_Vector;
   begin
      Assert (Coyote_TUI.Search.Advance (M, 0, +1) = 0,
              "advance on empty list returns 0");
   end Test_Search_Advance_Empty;

   --  ── Commands ─────────────────────────────────────────────────────────

   procedure Test_Cmd_Quit (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_TUI.Commands.Parse ("q").Kind
              = Coyote_TUI.Commands.Quit, ":q -> Quit");
   end Test_Cmd_Quit;

   procedure Test_Cmd_Stop (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_TUI.Commands.Parse ("stop").Kind
              = Coyote_TUI.Commands.Stop, ":stop -> Stop");
   end Test_Cmd_Stop;

   procedure Test_Cmd_Model_With_Arg (T : in out Test) is
      pragma Unreferenced (T);
      Cmd : constant Coyote_TUI.Commands.Command :=
        Coyote_TUI.Commands.Parse ("model anthropic/claude-3-5");
   begin
      Assert (Cmd.Kind = Coyote_TUI.Commands.Set_Model,
              "model verb -> Set_Model");
      Assert (To_String (Cmd.Arg) = "anthropic/claude-3-5",
              "model arg is the identifier");
   end Test_Cmd_Model_With_Arg;

   procedure Test_Cmd_Send_With_Text (T : in out Test) is
      pragma Unreferenced (T);
      Cmd : constant Coyote_TUI.Commands.Command :=
        Coyote_TUI.Commands.Parse ("send hello there world");
   begin
      Assert (Cmd.Kind = Coyote_TUI.Commands.Send, "send verb -> Send");
      Assert (To_String (Cmd.Arg) = "hello there world",
              "arg includes all remaining words");
   end Test_Cmd_Send_With_Text;

   procedure Test_Cmd_Session_With_Uuid (T : in out Test) is
      pragma Unreferenced (T);
      Cmd : constant Coyote_TUI.Commands.Command :=
        Coyote_TUI.Commands.Parse ("session 1234-abcd");
   begin
      Assert (Cmd.Kind = Coyote_TUI.Commands.Load_Session,
              "session verb -> Load_Session");
      Assert (To_String (Cmd.Arg) = "1234-abcd", "UUID preserved in arg");
   end Test_Cmd_Session_With_Uuid;

   procedure Test_Cmd_Unknown (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_TUI.Commands.Parse ("gobbledygook").Kind
              = Coyote_TUI.Commands.Unknown, "unknown verb -> Unknown");
      Assert (Coyote_TUI.Commands.Parse ("").Kind
              = Coyote_TUI.Commands.Unknown, "empty string -> Unknown");
   end Test_Cmd_Unknown;

   procedure Test_Cmd_Help (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_TUI.Commands.Parse ("help").Kind
              = Coyote_TUI.Commands.Help, ":help -> Help");
   end Test_Cmd_Help;

   procedure Test_Cmd_Compact (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert (Coyote_TUI.Commands.Parse ("compact").Kind
              = Coyote_TUI.Commands.Compact, ":compact -> Compact");
   end Test_Cmd_Compact;

   procedure Test_Cmd_Agent_Prefix_Model (T : in out Test) is
      pragma Unreferenced (T);
      Cmd : constant Coyote_TUI.Commands.Command :=
        Coyote_TUI.Commands.Parse ("model x/y");
   begin
      Assert (Coyote_TUI.Commands.Agent_Prefix (Cmd) = ":model x/y",
              "Agent_Prefix for Set_Model includes the arg");
   end Test_Cmd_Agent_Prefix_Model;

   procedure Test_Cmd_Agent_Prefix_UI_Side (T : in out Test) is
      pragma Unreferenced (T);
      Cmd : constant Coyote_TUI.Commands.Command :=
        Coyote_TUI.Commands.Parse ("help");
   begin
      Assert (Coyote_TUI.Commands.Agent_Prefix (Cmd) = "",
              "UI-side commands have empty Agent_Prefix");
   end Test_Cmd_Agent_Prefix_UI_Side;

   --  ── Render ───────────────────────────────────────────────────────────

   procedure Test_Measure_Single_Line (T : in out Test) is
      pragma Unreferenced (T);
      S : constant Segment := Mk_Seg (User_Turn, "hello");
   begin
      Assert (Coyote_TUI.Render.Measure_Segment (S, 80) = 1,
              "single-line segment has height 1");
   end Test_Measure_Single_Line;

   procedure Test_Measure_Multi_Line (T : in out Test) is
      pragma Unreferenced (T);
      S : constant Segment :=
        Mk_Seg (User_Turn,
                "line one" & LF & "line two" & LF & "line three");
   begin
      Assert (Coyote_TUI.Render.Measure_Segment (S, 80) = 3,
              "three-line segment has height 3");
   end Test_Measure_Multi_Line;

   procedure Test_Measure_Tool_Segment (T : in out Test) is
      pragma Unreferenced (T);
      S : constant Segment := Mk_Tool ("shell", "{" & LF & "}", "t1");
      H : constant Positive := Coyote_TUI.Render.Measure_Segment (S, 80);
   begin
      Assert (H >= 3,
              "tool segment with LF in args measures at least 3 lines");
   end Test_Measure_Tool_Segment;

   procedure Test_Render_User_Turn (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Sink.String_Sink;
      S    : constant Segment := Mk_Seg (User_Turn, "my prompt");
      Sink : Instance;
      N    : Natural;
   begin
      N := Coyote_TUI.Render.Render_Segment
             (S, Sink, 80, Use_Color => False);
      Assert (N = 1, "user turn produces 1 display line");
      Assert (Ada.Strings.Fixed.Index (Content (Sink), "my prompt") > 0,
              "prompt text appears in rendered output");
      Assert (Attrs_Balanced (Sink), "no attribute leak");
   end Test_Render_User_Turn;

   procedure Test_Render_Notice_Info (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Sink.String_Sink;
      S    : constant Segment := Mk_Seg (System_Notice, "all good", Info);
      Sink : Instance;
      N    : Natural;
   begin
      N := Coyote_TUI.Render.Render_Segment
             (S, Sink, 80, Use_Color => False);
      Assert (N = 1, "info notice is 1 line");
      Assert (Ada.Strings.Fixed.Index (Content (Sink), "all good") > 0,
              "notice text appears in output");
   end Test_Render_Notice_Info;

   procedure Test_Render_Tool_Running (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Sink.String_Sink;
      S    : constant Segment := Mk_Tool ("shell", "{}", "t1", Running);
      Sink : Instance;
      N    : Natural;
   begin
      N := Coyote_TUI.Render.Render_Segment
             (S, Sink, 80, Use_Color => False);
      Assert (N >= 2, "running tool has at least header + status lines");
      Assert (Ada.Strings.Fixed.Index (Content (Sink), "shell") > 0,
              "tool name appears in output");
      Assert (Attrs_Balanced (Sink), "no attribute leak for running tool");
   end Test_Render_Tool_Running;

   procedure Test_Render_Tool_Error_Preview (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Sink.String_Sink;
      S    : constant Segment :=
               Mk_Tool ("shell", "{}", "t1", Error,
                        "Error: command not found");
      Sink : Instance;
      N    : Natural;
   begin
      N := Coyote_TUI.Render.Render_Segment
             (S, Sink, 80, Use_Color => False);
      Assert (N >= 1, "error tool renders at least 1 line");
      Assert (Ada.Strings.Fixed.Index
                (Content (Sink), "command not found") > 0,
              "error preview text appears in output");
   end Test_Render_Tool_Error_Preview;

   procedure Test_Render_Thinking_Block (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Sink.String_Sink;
      S    : constant Segment := Mk_Seg (Thinking_Block, "reasoning step");
      Sink : Instance;
      N    : Natural;
   begin
      N := Coyote_TUI.Render.Render_Segment
             (S, Sink, 80, Use_Color => False);
      Assert (N >= 1, "thinking block renders at least 1 line");
      Assert (Ada.Strings.Fixed.Index
                (Content (Sink), "reasoning step") > 0,
              "thinking text appears in output");
      Assert (Attrs_Balanced (Sink), "no attribute leak for thinking block");
   end Test_Render_Thinking_Block;

   procedure Test_Render_Turn_Footer (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Sink.String_Sink;
      S    : constant Segment := Mk_Seg (Turn_Footer, "tokens: 42");
      Sink : Instance;
      N    : Natural;
   begin
      N := Coyote_TUI.Render.Render_Segment
             (S, Sink, 80, Use_Color => False);
      Assert (N = 1, "turn footer is 1 line");
      Assert (Ada.Strings.Fixed.Index (Content (Sink), "tokens: 42") > 0,
              "footer text appears in output");
   end Test_Render_Turn_Footer;

   procedure Test_Render_Skip_Lines (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Sink.String_Sink;
      S    : constant Segment :=
               Mk_Seg (User_Turn, "first" & LF & "second");
      Sink : Instance;
      N    : Natural;
   begin
      N := Coyote_TUI.Render.Render_Segment
             (S, Sink, 80, Use_Color => False, Skip_Lines => 1);
      Assert (N = 1,
              "skip_lines=1 on 2-line segment emits 1 line");
      Assert (Ada.Strings.Fixed.Index (Content (Sink), "second") > 0,
              "second line is rendered");
      Assert (Ada.Strings.Fixed.Index (Content (Sink), "first") = 0,
              "first line is skipped");
   end Test_Render_Skip_Lines;

   procedure Test_Render_Attrs_Balanced (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_TUI.Sink.String_Sink;
      S    : constant Segment :=
               Mk_Seg (System_Notice, "disk full", Warning);
      Sink : Instance;
      N    : Natural;
   begin
      N := Coyote_TUI.Render.Render_Segment
             (S, Sink, 80, Use_Color => True);
      Assert (N = 1, "warning notice is 1 line");
      Assert (Attrs_Balanced (Sink),
              "Color_On/Reset_Attrs balanced for warning notice");
   end Test_Render_Attrs_Balanced;

   procedure Test_Mark_Height_Stale (T : in out Test) is
      pragma Unreferenced (T);
      Nav  : Coyote_TUI.Nav_State.State;
      Seg  : Natural;
      Pend : Boolean;
   begin
      Nav.Mark_Height_Stale (3);
      Nav.Take_Stale_Seg (Seg);
      Assert (Seg = 3,
              "Mark_Height_Stale: Take_Stale_Seg returns marked index");
      Nav.Take_Render_Request (Pend);
      Assert (Pend,
              "Mark_Height_Stale: sets render-pending flag");
   end Test_Mark_Height_Stale;

   procedure Test_Take_Stale_Seg_Clears (T : in out Test) is
      pragma Unreferenced (T);
      Nav  : Coyote_TUI.Nav_State.State;
      Seg  : Natural;
   begin
      Nav.Mark_Height_Stale (7);
      Nav.Take_Stale_Seg (Seg);
      --  Second call should return 0 (cleared).
      Nav.Take_Stale_Seg (Seg);
      Assert (Seg = 0,
              "Take_Stale_Seg: clears the stale index after first read");
   end Test_Take_Stale_Seg_Clears;

end Coyote_TUI_Tests;
