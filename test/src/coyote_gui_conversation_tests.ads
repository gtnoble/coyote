--  Coyote_GUI_Conversation_Tests — unit tests for scrolling and layout.
--
--  Covers:
--    * Streaming text-block state machine (Append_Text / End_Text_Block)
--    * Thinking-block boundary tracking
--    * Vis_Count computation via Pango wrapping
--    * Total_Vis_Lines post-append
--    * Cache invalidation on Invalidate_Layout
--    * Logical-line accumulation
--
--  All tests that touch the widget (Append_Text, Append_Notice, etc.)
--  require a display and are skipped when DISPLAY and WAYLAND_DISPLAY
--  are both unset.  Run under xvfb-run for headless CI:
--      xvfb-run -a bin/coyote_test "*Conversation*"
--
--  Project: coyote

with AUnit;
with AUnit.Test_Fixtures;
with Gtk.Scrolled_Window;
with Gtk.Layout;
with Coyote_GUI.Conversation;

package Coyote_GUI_Conversation_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with record
      Conv              : Coyote_GUI.Conversation.Instance;
      Scroll            : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout            : Gtk.Layout.Gtk_Layout;
      Display_Available : Boolean := False;
   end record;

   overriding procedure Set_Up (T : in out Test);
   overriding procedure Tear_Down (T : in out Test);

   --  All tests below require a display (they call Append_Text,
   --  Append_Notice, End_Text_Block, or similar operations that
   --  trigger Recompute_Vis_Lines / Queue_Draw on the GtkLayout).

   procedure Test_Total_Vis_Lines_Zero_When_Empty         (T : in out Test);
   procedure Test_Single_Short_Line_Vis_Count_One         (T : in out Test);
   procedure Test_Multiple_Short_Lines_Each_Vis_Count_One (T : in out Test);
   procedure Test_Total_Vis_Lines_After_Append_Text       (T : in out Test);
   procedure Test_Cache_Width_Non_Zero_After_Recompute    (T : in out Test);
   procedure Test_Invalidate_Layout_Zeroes_Cache_Width    (T : in out Test);
   procedure Test_Set_Font_Changes_Line_Height             (T : in out Test);
   procedure Test_Recompute_Vis_Lines_Updates_Total       (T : in out Test);
   procedure Test_Append_Notice_Increments_Count          (T : in out Test);
   procedure Test_Append_Text_Enters_Text_Block           (T : in out Test);
   procedure Test_Append_Text_Accumulates_Buffer          (T : in out Test);
   procedure Test_Split_UTF8_Text_Is_Reassembled           (T : in out Test);
   procedure Test_Split_UTF8_Thinking_Is_Reassembled       (T : in out Test);
   procedure Test_Streaming_Append_Invalidates_Vis_Cache  (T : in out Test);
   procedure Test_End_Text_Block_Exits_Block              (T : in out Test);
   procedure Test_Footer_Leaves_Blank_Lines               (T : in out Test);
   procedure Test_Notice_Does_Not_Enter_Text_Block        (T : in out Test);
   procedure Test_Begin_Thinking_Sets_Flag                (T : in out Test);
   procedure Test_End_Thinking_Clears_Flag                (T : in out Test);
   procedure Test_Tool_Detail_Preserves_Arguments          (T : in out Test);
   procedure Test_Tool_Detail_Selects_Second_Interleaved    (T : in out Test);
   procedure Test_Tool_Card_Lifecycle_Styles               (T : in out Test);

   --  Large-logical-line / viewport-overflow tests

   procedure Test_Long_Line_Produces_Many_Visual_Lines (T : in out Test);
   procedure Test_Deep_Indent_Consumes_Width_And_Wraps (T : in out Test);
   procedure Test_Visual_Lines_Exceed_Viewport_Height  (T : in out Test);
   procedure Test_Long_Line_Vis_Count_Consistent_On_Recompute (T : in out Test);
   procedure Test_Long_Word_Forces_Character_Break     (T : in out Test);
   procedure Test_Viewport_Select_All_Extracts_Expected_Text (T : in out Test);
   procedure Test_Inverted_Selection_Orders_Endpoints        (T : in out Test);
   procedure Test_Inverted_Selection_Extracts_Expected_Text  (T : in out Test);

   --  Markdown-rendering tests

   procedure Test_Markdown_Paragraph_Has_Markup_Flag      (T : in out Test);
   procedure Test_Markdown_Multi_Paragraph_Line_Count     (T : in out Test);
   procedure Test_Markdown_Nested_List_Indentation        (T : in out Test);
   procedure Test_Markdown_Mixed_List_Indentation         (T : in out Test);

   procedure Test_Markdown_Select_All_Strips_Markup       (T : in out Test);
   procedure Test_Markdown_Heading_Styles                 (T : in out Test);
   procedure Test_Markdown_Bold_Italic_Preserved_In_Text   (T : in out Test);
   procedure Test_Markdown_Display_Math_Style              (T : in out Test);
   procedure Test_Markdown_Display_Math_Preserves_Source   (T : in out Test);
   procedure Test_Markdown_Display_Math_Has_Visual_Lines   (T : in out Test);

   --  Variable-height block layout

   procedure Test_Document_Height_Is_Sum_Of_Block_Heights (T : in out Test);
   procedure Test_Heading_Taller_Than_Body                (T : in out Test);
   procedure Test_Math_Uses_Natural_Pixel_Height          (T : in out Test);
   procedure Test_Transcript_Text_Uses_Plain_Text         (T : in out Test);
   procedure Test_Selected_Text_Uses_Selection_Order      (T : in out Test);
   procedure Test_Primary_Selection_Round_Trip            (T : in out Test);
   procedure Test_Interactive_Focus_Cycles               (T : in out Test);
   procedure Test_Context_Help_Covers_Main_Areas         (T : in out Test);

end Coyote_GUI_Conversation_Tests;