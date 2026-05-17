--  Coyote_TUI_Tests — AUnit tests for the Coyote_TUI pure subsystem.
--
--  Tests Layers 0-3 (Segment_Ops, Scroll, Search, Commands, Render).
--  No ncurses, no task, no terminal required.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with AUnit.Test_Fixtures;

package Coyote_TUI_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  ── Segment_Ops ───────────────────────────────────────────────────────
   procedure Test_Append_New                (T : in out Test);
   procedure Test_Update_Last_Content       (T : in out Test);
   procedure Test_Update_Last_Empty         (T : in out Test);
   procedure Test_Set_Last_Complete         (T : in out Test);
   procedure Test_Find_Tool                 (T : in out Test);
   procedure Test_End_Tool                  (T : in out Test);
   procedure Test_Last_Kind                 (T : in out Test);

   --  ── Scroll ────────────────────────────────────────────────────────────
   procedure Test_Total_Lines               (T : in out Test);
   procedure Test_Total_Lines_Empty         (T : in out Test);
   procedure Test_Advance_Forward           (T : in out Test);
   procedure Test_Advance_Backward          (T : in out Test);
   procedure Test_Advance_Clamp_Begin       (T : in out Test);
   procedure Test_Follow_Start              (T : in out Test);
   procedure Test_Follow_Start_All_Fit      (T : in out Test);
   procedure Test_Next_Of_Kind              (T : in out Test);
   procedure Test_Prev_Of_Kind              (T : in out Test);

   --  ── Search ────────────────────────────────────────────────────────────
   procedure Test_Matches_Empty_Term        (T : in out Test);
   procedure Test_Matches_No_Match          (T : in out Test);
   procedure Test_Matches_Case_Insensitive  (T : in out Test);
   procedure Test_Matches_Byte_Offset       (T : in out Test);
   procedure Test_Matches_Multi_Segment     (T : in out Test);
   procedure Test_Search_Advance_Forward    (T : in out Test);
   procedure Test_Search_Advance_Backward   (T : in out Test);
   procedure Test_Search_Advance_Empty      (T : in out Test);

   --  ── Commands ──────────────────────────────────────────────────────────
   procedure Test_Cmd_Quit                  (T : in out Test);
   procedure Test_Cmd_Stop                  (T : in out Test);
   procedure Test_Cmd_Model_With_Arg        (T : in out Test);
   procedure Test_Cmd_Send_With_Text        (T : in out Test);
   procedure Test_Cmd_Session_With_Uuid     (T : in out Test);
   procedure Test_Cmd_Unknown               (T : in out Test);
   procedure Test_Cmd_Help                  (T : in out Test);
   procedure Test_Cmd_Compact               (T : in out Test);
   procedure Test_Cmd_Agent_Prefix_Model    (T : in out Test);
   procedure Test_Cmd_Agent_Prefix_UI_Side  (T : in out Test);

   --  ── Render ────────────────────────────────────────────────────────────
   procedure Test_Measure_Single_Line       (T : in out Test);
   procedure Test_Measure_Multi_Line        (T : in out Test);
   procedure Test_Measure_Tool_Segment      (T : in out Test);
   procedure Test_Render_User_Turn          (T : in out Test);
   procedure Test_Render_Notice_Info        (T : in out Test);
   procedure Test_Render_Tool_Running       (T : in out Test);
   procedure Test_Render_Tool_Error_Preview (T : in out Test);
   procedure Test_Render_Thinking_Block     (T : in out Test);
   procedure Test_Render_Turn_Footer        (T : in out Test);
   procedure Test_Render_Skip_Lines         (T : in out Test);
   procedure Test_Render_Attrs_Balanced     (T : in out Test);
   procedure Test_Mark_Height_Stale         (T : in out Test);
   procedure Test_Take_Stale_Seg_Clears     (T : in out Test);

end Coyote_TUI_Tests;
