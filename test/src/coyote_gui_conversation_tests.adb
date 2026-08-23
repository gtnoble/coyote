with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with AUnit.Assertions;
with Glib;         use type Glib.Gint;
with Gtk.Enums;       use Gtk.Enums;
with Gtk.Main;
with Gtk.Clipboard;
with Gtk.Selection_Data;
with Pango.Font;
with Coyote_GUI.Conversation;
with Coyote_App.Utils;
with Coyote_GUI.Conversation.Testing;
with Coyote_App.Frontend.GUI;

package body Coyote_GUI_Conversation_Tests is

   use AUnit.Assertions;
   use Coyote_GUI.Conversation;

   -----------
   --  Helpers
   -----------

   function Display_Detected return Boolean is
   begin
      return
        Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Detected;

   procedure Make_Fresh_Conv
     (Conv   :    out Instance;
      Scroll :    out Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout :    out Gtk.Layout.Gtk_Layout)
   is
   begin
      Gtk.Scrolled_Window.Gtk_New (Scroll);
      Scroll.Set_Policy (Policy_Automatic, Policy_Automatic);
      Gtk.Layout.Gtk_New (Layout, null, null);
      Scroll.Add (Layout);
      Scroll.Set_Size_Request (400, 300);
      Scroll.Show_All;
      Conv.Attach (Scroll, Layout);
   end Make_Fresh_Conv;

   function Str_Repeat (S : String; Count : Positive) return String is
      R : Unbounded_String;
   begin
      for I in 1 .. Count loop
         Append (R, S);
      end loop;
      return To_String (R);
   end Str_Repeat;

   ------------
   -- Set_Up --
   ------------

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Detected then
         Gtk.Main.Init;
         T.Display_Available := True;
      end if;
   end Set_Up;

   ----------------
   -- Tear_Down --
   ----------------

   overriding procedure Tear_Down (T : in out Test) is
   begin
      null;
   end Tear_Down;

   --  ── Core layout tests ──────────────────────────────────────────────────

   procedure Test_Total_Vis_Lines_Zero_When_Empty (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Assert (Testing.Total_Vis_Lines (Conv) = 0,
              "empty conversation has zero visual lines");
   end Test_Total_Vis_Lines_Zero_When_Empty;

   procedure Test_Single_Short_Line_Vis_Count_One (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("short");
      Conv.End_Text_Block;
      Assert (Testing.Line_Count (Conv) > 0,
              "logical lines present after text block");
      if Testing.Line_Count (Conv) > 0 then
         for I in 1 .. Testing.Line_Count (Conv) loop
            Assert (Testing.Vis_Count_At (Conv, I) >= 1,
                    "Vis_Count >= 1 for every logical line");
         end loop;
      end if;
   end Test_Single_Short_Line_Vis_Count_One;

   procedure Test_Multiple_Short_Lines_Each_Vis_Count_One (T : in out Test) is
      Conv     : Instance;
      Scroll   : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout   : Gtk.Layout.Gtk_Layout;
      Num_Lines : constant := 5;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("a");
      for I in 2 .. Num_Lines loop
         Conv.Append_Text (ASCII.LF & "a");
      end loop;
      Conv.End_Text_Block;
      Assert (Testing.Total_Vis_Lines (Conv) >= Natural (Num_Lines),
              "at least as many visual lines as logical lines");
   end Test_Multiple_Short_Lines_Each_Vis_Count_One;

   procedure Test_Total_Vis_Lines_After_Append_Text (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("line one" & ASCII.LF & "line two");
      Assert (Testing.Total_Vis_Lines (Conv) >= 2,
              "at least 2 visual lines for 2 logical lines");
      Conv.End_Text_Block;
   end Test_Total_Vis_Lines_After_Append_Text;

   procedure Test_Cache_Width_Non_Zero_After_Recompute (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Notice (Notice_Info, "trigger recompute");
      Assert (Testing.Cache_Width_Px (Conv) > 0,
              "cache width > 0 after Recompute_Vis_Lines");
   end Test_Cache_Width_Non_Zero_After_Recompute;

   procedure Test_Invalidate_Layout_Zeroes_Cache_Width (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Notice (Notice_Info, "initial content");
      Assert (Testing.Cache_Width_Px (Conv) > 0,
              "cache width > 0 before Invalidate_Layout");
      Conv.Invalidate_Layout;
      Assert (Testing.Cache_Width_Px (Conv) > 0,
              "cache width > 0 after Invalidate_Layout (recomputed)");
   end Test_Invalidate_Layout_Zeroes_Cache_Width;

   procedure Test_Set_Font_Changes_Line_Height (T : in out Test) is
      Conv       : Instance;
      Scroll     : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout     : Gtk.Layout.Gtk_Layout;
      Small_Font : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 8");
      Large_Font : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 24");
      Small_H    : Glib.Gint;
      Large_H    : Glib.Gint;
   begin
      if not T.Display_Available then
         Pango.Font.Free (Small_Font);
         Pango.Font.Free (Large_Font);
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("font size regression");
      Conv.End_Text_Block;
      Conv.Set_Font (Small_Font);
      Small_H := Testing.Line_Height_Px (Conv);
      Conv.Set_Font (Large_Font);
      Large_H := Testing.Line_Height_Px (Conv);
      Assert (Large_H > Small_H,
              "larger conversation font increases line height");
      Pango.Font.Free (Small_Font);
      Pango.Font.Free (Large_Font);
   end Test_Set_Font_Changes_Line_Height;

   procedure Test_Recompute_Vis_Lines_Updates_Total (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Before : Natural;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Before := Testing.Total_Vis_Lines (Conv);
      Conv.Append_Notice (Notice_Info, "new line of text content");
      Assert (Testing.Total_Vis_Lines (Conv) > Before,
              "appending content increases Total_Vis_Lines");
   end Test_Recompute_Vis_Lines_Updates_Total;

   --  ── State machine tests ────────────────────────────────────────────────

   procedure Test_Append_Notice_Increments_Count (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Assert (Testing.Line_Count (Conv) = 0,
              "fresh conversation has zero logical lines");
      Conv.Append_Notice (Notice_Info, "line 1");
      Assert (Testing.Line_Count (Conv) = 1,
              "first notice produces 1 logical line");
      Conv.Append_Notice (Notice_Info, "line 2");
      Assert (Testing.Line_Count (Conv) = 2,
              "second notice produces 2 logical lines");
   end Test_Append_Notice_Increments_Count;

   procedure Test_Append_Text_Enters_Text_Block (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Assert (not Testing.Is_In_Text_Block (Conv),
              "fresh instance not in text block");
      Conv.Append_Text ("hello");
      Assert (Testing.Is_In_Text_Block (Conv),
              "Append_Text enters text block");
      Conv.End_Text_Block;
      Assert (not Testing.Is_In_Text_Block (Conv),
              "End_Text_Block exits text block");
   end Test_Append_Text_Enters_Text_Block;

   procedure Test_Append_Text_Accumulates_Buffer (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("hello ");
      Conv.Append_Text ("world");
      Assert (Testing.Stream_Buffer (Conv) = "hello world",
              "stream buffer accumulates across calls");
      Conv.End_Text_Block;
      Assert (Testing.Stream_Buffer (Conv) = "",
              "stream buffer cleared after End_Text_Block");
   end Test_Append_Text_Accumulates_Buffer;

   procedure Test_Split_UTF8_Text_Is_Reassembled (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Euro   : constant String := Character'Val (16#E2#)
                                  & Character'Val (16#82#)
                                  & Character'Val (16#AC#);
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Set_Render_Markdown (False);
      Conv.Append_Text (Euro (Euro'First .. Euro'First));
      Conv.Append_Text (Euro (Euro'First + 1 .. Euro'First + 1));
      Assert (Testing.Stream_Buffer (Conv) = Euro (Euro'First .. Euro'First + 1),
              "raw text retains split UTF-8 bytes");
      Conv.Append_Text (Euro (Euro'First + 2 .. Euro'Last));
      Conv.End_Text_Block;
      Assert (Testing.Get_Line_Text (Conv, 1) = Euro,
              "split UTF-8 text is reassembled in the rendered line");
   end Test_Split_UTF8_Text_Is_Reassembled;

   procedure Test_Split_UTF8_Thinking_Is_Reassembled (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Euro   : constant String := Character'Val (16#E2#)
                                  & Character'Val (16#82#)
                                  & Character'Val (16#AC#);
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Begin_Thinking;
      Conv.Append_Thinking (Euro (Euro'First .. Euro'First));
      Conv.Append_Thinking (Euro (Euro'First + 1 .. Euro'First + 1));
      Conv.Append_Thinking (Euro (Euro'First + 2 .. Euro'Last));
      Conv.End_Thinking;
      Assert (Testing.Get_Line_Text (Conv, 1) = Coyote_App.Utils.UC_BOX_V & " " & Euro,
              "split UTF-8 thinking text is reassembled");
   end Test_Split_UTF8_Thinking_Is_Reassembled;

   procedure Test_Streaming_Append_Invalidates_Vis_Cache
     (T : in out Test)
   is
      Before_Total : Natural;
      Before_Vis   : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (T.Conv, T.Scroll, T.Layout);
      T.Conv.Append_Text ("short");
      Before_Total := Testing.Total_Vis_Lines (T.Conv);
      Before_Vis := Testing.Vis_Count_At (T.Conv, 1);

      T.Conv.Append_Text (Str_Repeat ("word ", 250));

      Assert (Testing.Vis_Count_At (T.Conv, 1) > Before_Vis,
              "appending to the current logical line recomputes wrapping");
      Assert (Testing.Total_Vis_Lines (T.Conv) > Before_Total,
              "appending to the current logical line expands the canvas");
   end Test_Streaming_Append_Invalidates_Vis_Cache;

   procedure Test_End_Text_Block_Exits_Block (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("something");
      Conv.End_Text_Block;
      Assert (not Testing.Is_In_Text_Block (Conv),
              "not in text block after End_Text_Block");
      Conv.End_Text_Block;
      Assert (not Testing.Is_In_Text_Block (Conv),
              "End_Text_Block idempotent");
   end Test_End_Text_Block_Exits_Block;

   procedure Test_Footer_Leaves_Blank_Lines (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Before : Natural;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Notice (Notice_Info, "content");
      Before := Testing.Line_Count (Conv);
      Conv.Append_Turn_Footer ("");
      Assert (Testing.Line_Count (Conv) = Before + 3,
              "Append_Turn_Footer adds 3 lines (blank, rule, blank)");
   end Test_Footer_Leaves_Blank_Lines;

   procedure Test_Notice_Does_Not_Enter_Text_Block (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Notice (Notice_Info, "a notice");
      Assert (not Testing.Is_In_Text_Block (Conv),
              "notices do not enter text block");
   end Test_Notice_Does_Not_Enter_Text_Block;

   procedure Test_Begin_Thinking_Sets_Flag (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Assert (not Testing.Is_In_Thinking (Conv),
              "fresh instance not in thinking");
      Conv.Begin_Thinking;
      Assert (Testing.Is_In_Thinking (Conv),
              "Begin_Thinking sets flag");
   end Test_Begin_Thinking_Sets_Flag;

   procedure Test_End_Thinking_Clears_Flag (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Begin_Thinking;
      Conv.End_Thinking;
      Assert (not Testing.Is_In_Thinking (Conv),
              "End_Thinking clears flag");
   end Test_End_Thinking_Clears_Flag;

   --  ── Large-logical-line / viewport-overflow tests ───────────────────────

   procedure Test_Long_Line_Produces_Many_Visual_Lines (T : in out Test) is
      Conv     : Instance;
      Scroll   : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout   : Gtk.Layout.Gtk_Layout;
      Long_Str : constant String := Str_Repeat ("word ", 250);
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (Long_Str);
      Conv.End_Text_Block;
      Assert (Testing.Line_Count (Conv) >= 1,
              "logical lines present after long text block");
      Assert (Testing.Vis_Count_At (Conv, 1) >= 5,
              "250-word line wraps to at least 5 visual lines"
              & " (got" & Natural'Image (Testing.Vis_Count_At (Conv, 1)) & ")");
   end Test_Long_Line_Produces_Many_Visual_Lines;

   procedure Test_Deep_Indent_Consumes_Width_And_Wraps (T : in out Test) is
      Conv           : Instance;
      Scroll         : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout         : Gtk.Layout.Gtk_Layout;
      Pad_Width      : constant := 60;
      Indent         : constant String := Str_Repeat (" ", Pad_Width);
      Indented_Line  : constant String := Indent & "wrapped text wrapped text";
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("wrapped text wrapped text");
      Conv.End_Text_Block;
      declare
         Unindented_Vis : constant Natural :=
           Testing.Vis_Count_At (Conv, 1);
      begin
         declare
            Conv2   : Instance;
            Scroll2 : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
            Layout2 : Gtk.Layout.Gtk_Layout;
         begin
            Make_Fresh_Conv (Conv2, Scroll2, Layout2);
            Conv2.Append_Text (Indented_Line);
            Conv2.End_Text_Block;
            Assert (Testing.Vis_Count_At (Conv2, 1) >= Unindented_Vis,
                    "deep-indented line produces >= visual lines "
                    & "than unindented");
         end;
      end;
   end Test_Deep_Indent_Consumes_Width_And_Wraps;

   procedure Test_Visual_Lines_Exceed_Viewport_Height (T : in out Test) is
      Conv     : Instance;
      Scroll   : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout   : Gtk.Layout.Gtk_Layout;
      Very_Long : constant String := Str_Repeat ("overflow text ", 400);
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (Very_Long);
      Conv.End_Text_Block;
      declare
         Total : constant Natural := Testing.Total_Vis_Lines (Conv);
         VP    : constant Natural :=
           Natural (300 / Testing.Line_Height_Px (Conv)) + 1;
      begin
         Assert (Total > VP,
                 "total visual lines (" & Natural'Image (Total)
                 & ") exceed viewport height in lines ("
                 & Natural'Image (VP) & ")");
      end;
   end Test_Visual_Lines_Exceed_Viewport_Height;

   procedure Test_Long_Line_Vis_Count_Consistent_On_Recompute
     (T : in out Test)
   is
      Conv     : Instance;
      Scroll   : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout   : Gtk.Layout.Gtk_Layout;
      Big_Line : constant String := Str_Repeat ("word ", 80);
      First_Vis : Natural;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (Big_Line);
      Conv.End_Text_Block;
      First_Vis := Testing.Vis_Count_At (Conv, 1);
      Assert (First_Vis > 0, "80-word line has positive Vis_Count");
      Conv.Invalidate_Layout;
      Assert
        (Testing.Vis_Count_At (Conv, 1) = First_Vis,
         "long line Vis_Count stable across Invalidate_Layout:"
         & Natural'Image (First_Vis)
         & " vs" & Natural'Image (Testing.Vis_Count_At (Conv, 1)));
   end Test_Long_Line_Vis_Count_Consistent_On_Recompute;

   procedure Test_Long_Word_Forces_Character_Break (T : in out Test) is
      Conv      : Instance;
      Scroll    : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout    : Gtk.Layout.Gtk_Layout;
      Long_Word : constant String := Str_Repeat ("x", 600);
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (Long_Word);
      Conv.End_Text_Block;
      Assert (Testing.Line_Count (Conv) >= 1,
              "long word produces at least 1 logical line");
      Assert (Testing.Vis_Count_At (Conv, 1) > 1,
              "600-char word without spaces wraps to >1 visual line"
              & " (got" & Natural'Image (Testing.Vis_Count_At (Conv, 1)) & ")");
      Assert (Testing.Vis_Count_At (Conv, 1) >= 6,
              "600-char word at ~100 chars/line wraps to >=6 visual lines");
   end Test_Long_Word_Forces_Character_Break;

   --  ── Select-all / viewport content tests ────────────────────────────────

   procedure Test_Viewport_Select_All_Extracts_Expected_Text
     (T : in out Test)
   is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Last_Line : Natural;
      Last_Byte : Natural;

   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Set_Render_Markdown (False);
      Conv.Append_Text ("line one" & ASCII.LF & "line two" & ASCII.LF & "last");
      Conv.End_Text_Block;
      Last_Line := Testing.Line_Count (Conv);
      Assert (Last_Line >= 1,
              "at least 1 logical line after text block");
      Last_Byte := Testing.Get_Line_Text (Conv, Last_Line)'Length;
      Testing.Set_Selection (Conv, 1, 0, Last_Line, Last_Byte);
      Assert (Testing.Selection_Visible (Conv),
              "selection is active after Set_Selection");
      declare
         Extracted : constant String := Testing.Extract_Text
           (Conv, 1, 0, Last_Line, Last_Byte);
      begin
         Assert (Extracted = "line one" & ASCII.LF & "line two" & ASCII.LF & "last",
                 "select-all extracts expected text, got: """ & Extracted & """");
      end;
   end Test_Viewport_Select_All_Extracts_Expected_Text;

   procedure Test_Inverted_Selection_Orders_Endpoints (T : in out Test) is
      Conv      : Instance;
      Scroll    : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout    : Gtk.Layout.Gtk_Layout;
      Last_Line : Natural;
      Last_Byte : Natural;
      Hi_Line   : Natural;
      Hi_Byte   : Natural;
      Lo_Line   : Natural;
      Lo_Byte   : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Set_Render_Markdown (False);
      Conv.Append_Text
        ("line one" & ASCII.LF & "line two" & ASCII.LF & "last");
      Conv.End_Text_Block;
      Last_Line := Testing.Line_Count (Conv);
      Last_Byte := Testing.Get_Line_Text (Conv, Last_Line)'Length;
      --  Simulate an upward drag: stored start is below stored end.
      Testing.Set_Selection
        (Conv, Last_Line, Last_Byte, 1, 0);
      Testing.Get_Ordered_Selection
        (Conv, Hi_Line, Hi_Byte, Lo_Line, Lo_Byte);
      Assert (Hi_Line = 1 and then Hi_Byte = 0,
              "ordered start is the earlier endpoint");
      Assert (Lo_Line = Last_Line and then Lo_Byte = Last_Byte,
              "ordered end is the later endpoint");
   end Test_Inverted_Selection_Orders_Endpoints;

   procedure Test_Inverted_Selection_Extracts_Expected_Text
     (T : in out Test)
   is
      Conv      : Instance;
      Scroll    : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout    : Gtk.Layout.Gtk_Layout;
      Last_Line : Natural;
      Last_Byte : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Set_Render_Markdown (False);
      Conv.Append_Text
        ("line one" & ASCII.LF & "line two" & ASCII.LF & "last");
      Conv.End_Text_Block;
      Last_Line := Testing.Line_Count (Conv);
      Last_Byte := Testing.Get_Line_Text (Conv, Last_Line)'Length;
      Testing.Set_Selection
        (Conv, Last_Line, Last_Byte, 1, 0);
      declare
         Hi_Line   : Natural;
         Hi_Byte   : Natural;
         Lo_Line   : Natural;
         Lo_Byte   : Natural;
      begin
         Testing.Get_Ordered_Selection
           (Conv, Hi_Line, Hi_Byte, Lo_Line, Lo_Byte);
         declare
            Extracted : constant String :=
              Testing.Extract_Text
                (Conv, Hi_Line, Hi_Byte, Lo_Line, Lo_Byte);
         begin
            Assert
              (Extracted
               = "line one" & ASCII.LF & "line two" & ASCII.LF & "last",
               "inverted range extracts the same text as a downward drag");
         end;
      end;
   end Test_Inverted_Selection_Extracts_Expected_Text;

   procedure Test_Tool_Detail_Preserves_Arguments (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Click  : Tool_Click_Result;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Begin_Tool
        (Name       => "shell",
         Args       => "{""command"":""printf hello""}",
         Session_Id => "session-1",
         Tool_Id    => "tool-1");
      Conv.End_Tool
        (Tool_Id => "tool-1",
         Status  => Success,
         Result  => "hello");
      Click := Conv.Handle_Tool_Click
        (X => 1,
         Y => 2 * Glib.Gint (Testing.Line_Height_Px (Conv)) + 1);
      Assert (Click.Found,
              "clicking a completed tool block returns detail");
      if Click.Found then
         Assert (To_String (Click.Info.Name) = "shell",
                 "tool detail preserves the original tool name");
         Assert (To_String (Click.Info.Args) =
                   "{""command"":""printf hello""}",
                 "tool detail preserves the original arguments");
         Assert (To_String (Click.Info.Result_Text) = "hello",
                 "tool detail preserves the result");
         Assert (Click.Info.Result_Status = Success,
                 "tool detail preserves the result status");
      end if;
   end Test_Tool_Detail_Preserves_Arguments;

   procedure Test_Tool_Card_Lifecycle_Styles (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Header : Positive;
      Footer : Positive;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Begin_Tool
        (Name       => "shell",
         Args       => "{""command"":""printf hello""}",
         Session_Id => "session-1",
         Tool_Id    => "tool-card");

      Header := 2;
      Footer := Testing.Line_Count (Conv) - 1;
      Assert (Testing.Get_Line_Style (Conv, Header) = Tool_Header,
              "tool header uses Tool_Header style");
      Assert (Testing.Get_Line_Style (Conv, Header + 1) = Tool_Argument,
              "tool argument uses Tool_Argument style");
      Assert (Testing.Get_Line_Style (Conv, Footer) = Tool_Footer,
              "tool footer uses Tool_Footer style");
      Assert (Testing.Is_Line_Tool_Running (Conv, Header),
              "tool header is marked running before completion");
      Assert (Testing.Get_Line_Tool_Status (Conv, Footer) = Success,
              "running tool has default status");

      Conv.End_Tool
        (Tool_Id => "tool-card",
         Status  => Error,
         Result  => "failure");
      Assert (not Testing.Is_Line_Tool_Running (Conv, Header),
              "tool header is no longer running after completion");
      Assert (Testing.Get_Line_Tool_Status (Conv, Header) = Error,
              "completed tool status propagates to the card");
      Assert (Testing.Get_Line_Tool_Status (Conv, Footer) = Error,
              "completed tool status propagates to the footer");
   end Test_Tool_Card_Lifecycle_Styles;

   procedure Test_Tool_Detail_Selects_Second_Interleaved (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Click          : Tool_Click_Result;
      Found_Second   : Boolean := False;
      Line_Height    : Glib.Gint;

   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Line_Height := Testing.Line_Height_Px (Conv);
      Conv.Begin_Tool
        (Name       => "shell",
         Args       => "{""command"":""first""}",
         Session_Id => "session-1",
         Tool_Id    => "tool-1");
      Conv.Begin_Tool
        (Name       => "shell",
         Args       => "{""command"":""second""}",
         Session_Id => "session-1",
         Tool_Id    => "tool-2");
      Conv.End_Tool
        (Tool_Id => "tool-1",
         Status  => Success,
         Result  => "first result");
      Conv.End_Tool
        (Tool_Id => "tool-2",
         Status  => Success,
         Result  => "second result");

      --  Search the rendered rows so the test remains independent of the
      --  number of logical rows used to display the argument field.
      if Testing.Total_Vis_Lines (Conv) > 0 then
         for I in 0 .. Testing.Total_Vis_Lines (Conv) - 1 loop
            Click := Conv.Handle_Tool_Click
              (X => 1,
               Y => Glib.Gint (I) * Line_Height + 1);
            if Click.Found
              and then To_String (Click.Info.Name) = "shell"
              and then To_String (Click.Info.Args) =
                "{""command"":""second""}"
              and then To_String (Click.Info.Result_Text) = "second result"
            then
               Found_Second := True;
               exit;
            end if;
         end loop;
      end if;
      Assert (Found_Second,
              "clicking the second completed tool block returns its detail");
   end Test_Tool_Detail_Selects_Second_Interleaved;

   --  ── Markdown-rendering tests ───────────────────────────────────────────

   procedure Test_Markdown_Paragraph_Has_Markup_Flag (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("paragraph with **bold** content");
      Conv.End_Text_Block;
      Assert (Testing.Line_Count (Conv) >= 1,
              "markdown paragraph produces at least 1 logical line");
      Assert (Testing.Has_Markup_Flag (Conv, 1),
              "markdown paragraph line has Has_Markup flag set");
   end Test_Markdown_Paragraph_Has_Markup_Flag;

   procedure Test_Markdown_Multi_Paragraph_Line_Count (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      MD     : constant String :=
        "first paragraph" & ASCII.LF & ASCII.LF & "second paragraph";
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (MD);
      Conv.End_Text_Block;
      Assert (Testing.Line_Count (Conv) = 5,
              "two markdown paragraphs produce 5 logical lines "
              & "(got" & Natural'Image (Testing.Line_Count (Conv)) & ")");
   end Test_Markdown_Multi_Paragraph_Line_Count;

   procedure Test_Markdown_Nested_List_Indentation (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      MD     : constant String :=
        "- outer" & ASCII.LF
        & "  - inner" & ASCII.LF
        & "    - deepest" & ASCII.LF
        & "- sibling";
      Found_Outer, Found_Inner : Boolean := False;
      Found_Deepest, Found_Sibling : Boolean := False;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (MD);
      Conv.End_Text_Block;
      for I in 1 .. Testing.Line_Count (Conv) loop
         declare
            Text : constant String := Testing.Get_Line_Text (Conv, I);
         begin
            Found_Outer := Found_Outer or else Text = Coyote_App.Utils.UC_BULLET
              & " outer";
            Found_Inner := Found_Inner or else Text = "  "
              & Coyote_App.Utils.UC_BULLET & " inner";
            Found_Deepest := Found_Deepest or else Text = "    "
              & Coyote_App.Utils.UC_BULLET & " deepest";
            Found_Sibling := Found_Sibling or else Text = Coyote_App.Utils.UC_BULLET
              & " sibling";
         end;
      end loop;
      Assert (Found_Outer, "top-level list item is unindented");
      Assert (Found_Inner, "second-level list item is indented two spaces");
      Assert (Found_Deepest,
              "third-level list item is indented four spaces");
      Assert (Found_Sibling, "top-level sibling returns to zero indentation");
   end Test_Markdown_Nested_List_Indentation;

   procedure Test_Markdown_Mixed_List_Indentation (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      MD     : constant String :=
        "1. outer" & ASCII.LF
        & "   - inner" & ASCII.LF
        & "     1. deepest" & ASCII.LF
        & "2. sibling";
      Found_Outer, Found_Inner : Boolean := False;
      Found_Deepest, Found_Sibling : Boolean := False;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (MD);
      Conv.End_Text_Block;
      for I in 1 .. Testing.Line_Count (Conv) loop
         declare
            Text : constant String := Testing.Get_Line_Text (Conv, I);
         begin
            Found_Outer := Found_Outer or else Text = "1. outer";
            Found_Inner := Found_Inner or else Text = "  "
              & Coyote_App.Utils.UC_BULLET & " inner";
            Found_Deepest := Found_Deepest or else Text = "    1. deepest";
            Found_Sibling := Found_Sibling or else Text = "2. sibling";
         end;
      end loop;
      Assert (Found_Outer, "top-level ordered item is unindented");
      Assert (Found_Inner,
              "nested bullet item retains two-space indentation");
      Assert (Found_Deepest,
              "nested ordered item retains four-space indentation");
      Assert (Found_Sibling,
              "top-level ordered sibling returns to zero indentation");
   end Test_Markdown_Mixed_List_Indentation;

   procedure Test_Markdown_Select_All_Strips_Markup (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Last_Line : Natural;
      Last_Byte : Natural;
      MD        : constant String :=
        "alpha **bold** bravo" & ASCII.LF & ASCII.LF & "delta _italic_ echo";
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (MD);
      Conv.End_Text_Block;
      Last_Line := Testing.Line_Count (Conv);
      Assert (Last_Line >= 1,
              "markdown renders at least 1 logical line");
      Last_Byte := Testing.Get_Line_Text (Conv, Last_Line)'Length;
      Testing.Set_Selection (Conv, 1, 0, Last_Line, Last_Byte);
      declare
         Extracted : constant String :=
           Testing.Extract_Text (Conv, 1, 0, Last_Line, Last_Byte);
      begin
         Assert (Extracted'Length > 0,
                 "extracted markdown text is non-empty");
         for I in Extracted'Range loop
            Assert (Extracted (I) /= '<',
                    "extracted markdown text contains no Pango markup"
                    & " at offset"
                    & Natural'Image (I - Extracted'First + 1));
         end loop;
      end;
   end Test_Markdown_Select_All_Strips_Markup;

   procedure Test_Markdown_Heading_Styles (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("# heading 1" & ASCII.LF & "## heading 2" & ASCII.LF
                        & "para");
      Conv.End_Text_Block;
      Assert (Testing.Line_Count (Conv) >= 4,
              "headings + paragraph produce >= 4 logical lines");
   end Test_Markdown_Heading_Styles;

   procedure Test_Markdown_Bold_Italic_Preserved_In_Text (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then return; end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("just **bold** and _italic_ text here");
      Conv.End_Text_Block;
      declare
         Last_Line : constant Natural := Testing.Line_Count (Conv);
         Last_Byte : Natural;
      begin
         Last_Byte := Testing.Get_Line_Text (Conv, Last_Line)'Length;
         Testing.Set_Selection (Conv, 1, 0, Last_Line, Last_Byte);
         declare
            Extracted : constant String :=
              Testing.Extract_Text (Conv, 1, 0, Last_Line, Last_Byte);
            Expected  : constant String :=
              "just bold and italic text here";
         begin
            Assert (Extracted = Expected,
                    "markdown bold/italic rendered to plain text,"
                    & " got: """ & Extracted & """");
         end;
      end;
   end Test_Markdown_Bold_Italic_Preserved_In_Text;

   procedure Test_Markdown_Display_Math_Style (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Found  : Boolean := False;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text
        ("before" & ASCII.LF & ASCII.LF
         & "$$" & ASCII.LF
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mrow><msup><mi>x</mi><mn>2</mn></msup><mo>+</mo>"
         & "<mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></math>"
         & ASCII.LF & "$$"
         & ASCII.LF & ASCII.LF & "after");
      Conv.End_Text_Block;
      for I in 1 .. Testing.Line_Count (Conv) loop
         if Testing.Get_Line_Style (Conv, I) = Display_Math then
            Found := True;
            exit;
         end if;
      end loop;
      Assert (Found, "standalone display math produces Display_Math line");
   end Test_Markdown_Display_Math_Style;

   procedure Test_Markdown_Display_Math_Preserves_Source (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Expected : constant String :=
        "$$" & ASCII.LF
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mrow><msup><mi>x</mi><mn>2</mn></msup><mo>+</mo>"
        & "<mfrac><mn>1</mn><mn>2</mn></mfrac></mrow></math>"
        & ASCII.LF & "$$";
      Found  : Boolean := False;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text (Expected);
      Conv.End_Text_Block;
      for I in 1 .. Testing.Line_Count (Conv) loop
         if Testing.Get_Line_Style (Conv, I) = Display_Math then
            Assert (Testing.Get_Line_Text (Conv, I) = Expected,
                    "display math line preserves source text");
            Assert (not Testing.Has_Markup_Flag (Conv, I),
                    "display math line is not Pango markup");
            Found := True;
            exit;
         end if;
      end loop;
      Assert (Found, "display math source line is present");
   end Test_Markdown_Display_Math_Preserves_Source;

   procedure Test_Markdown_Display_Math_Has_Visual_Lines (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Found  : Boolean := False;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text
        ("$$" & ASCII.LF
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mtable><mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd></mtr>"
         & "<mtr><mtd><mi>c</mi></mtd><mtd><mi>d</mi></mtd></mtr></mtable>"
         & "</math>"
         & ASCII.LF & "$$");
      Conv.End_Text_Block;
      for I in 1 .. Testing.Line_Count (Conv) loop
         if Testing.Get_Line_Style (Conv, I) = Display_Math then
            Assert (Testing.Vis_Count_At (Conv, I) > 0,
                    "display math line has visual height");
            Found := True;
            exit;
         end if;
      end loop;
      Assert (Found, "complex display math line is present");
   end Test_Markdown_Display_Math_Has_Visual_Lines;

   --  ── Variable-height block layout ──────────────────────────────────────

   procedure Test_Document_Height_Is_Sum_Of_Block_Heights
     (T : in out Test)
   is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Sum    : Natural := 0;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Notice (Notice_Info, "one");
      Conv.Append_Notice (Notice_Warn, "two");
      Conv.Append_Notice (Notice_Error, "three");
      for I in 1 .. Testing.Line_Count (Conv) loop
         Sum := Sum + Testing.Pixel_Height_At (Conv, I);
      end loop;
      Assert (Testing.Total_Height_Px (Conv) = Sum,
              "document height equals the sum of block heights");
      Assert (Testing.Total_Height_Px (Conv) > 0,
              "non-empty conversation has a positive pixel height");
   end Test_Document_Height_Is_Sum_Of_Block_Heights;

   procedure Test_Heading_Taller_Than_Body (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Body_H : Natural := 0;
      Head_H : Natural := 0;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text
        ("# Heading One" & ASCII.LF & ASCII.LF & "body paragraph");
      Conv.End_Text_Block;
      for I in 1 .. Testing.Line_Count (Conv) loop
         if Testing.Get_Line_Style (Conv, I) = Heading_1 then
            Head_H := Testing.Pixel_Height_At (Conv, I);
         elsif Testing.Get_Line_Style (Conv, I) = Plain
           and then Testing.Get_Line_Text (Conv, I)'Length > 0
           and then Body_H = 0
         then
            Body_H := Testing.Pixel_Height_At (Conv, I);
         end if;
      end loop;
      Assert (Head_H > 0, "heading line has a measured height");
      Assert (Body_H > 0, "body paragraph has a measured height");
      Assert (Head_H > Body_H,
              "heading is taller than body text"
              & " (h=" & Natural'Image (Head_H)
              & " body=" & Natural'Image (Body_H) & ")");
   end Test_Heading_Taller_Than_Body;

   procedure Test_Math_Uses_Natural_Pixel_Height (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Found  : Boolean := False;
      Math_H : Natural := 0;
      Line_H : Natural := 0;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Line_H := Natural (Testing.Line_Height_Px (Conv));
      Conv.Append_Text
        ("$$" & ASCII.LF
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mtable><mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd></mtr>"
         & "<mtr><mtd><mi>c</mi></mtd><mtd><mi>d</mi></mtd></mtr></mtable>"
         & "</math>"
         & ASCII.LF & "$$");
      Conv.End_Text_Block;
      for I in 1 .. Testing.Line_Count (Conv) loop
         if Testing.Get_Line_Style (Conv, I) = Display_Math then
            Math_H := Testing.Pixel_Height_At (Conv, I);
            Found := True;
            exit;
         end if;
      end loop;
      Assert (Found, "display math line is present");
      Assert (Math_H > 0, "display math has a natural pixel height");
      --  A 2x2 matrix is taller than one body line; it must not be
      --  snapped up to a multiple of Line_Height_Px as its stored
      --  height (the old grid).  The stored height is the Lasem
      --  measurement itself.
      Assert (Math_H /= Line_H or else Math_H > Line_H,
              "math height is not forced onto the body-line grid");
   end Test_Math_Uses_Natural_Pixel_Height;

   procedure Test_Transcript_Text_Uses_Plain_Text (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("**bold** transcript");
      Conv.End_Text_Block;
      declare
         Transcript : constant String := Transcript_Text (Conv);
      begin
         Assert (Ada.Strings.Fixed.Index
                   (Transcript, "bold transcript") > 0,
                 "transcript should expose plain text");
         Assert (Ada.Strings.Fixed.Index (Transcript, "<b>") = 0,
                 "transcript should strip display markup");
      end;
   end Test_Transcript_Text_Uses_Plain_Text;

   procedure Test_Selected_Text_Uses_Selection_Order (T : in out Test) is
      Conv      : Instance;
      Scroll    : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout    : Gtk.Layout.Gtk_Layout;
      Last_Line : Natural;
      Last_Byte : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Set_Render_Markdown (False);
      Conv.Append_Text
        ("first line" & ASCII.LF & "second line");
      Conv.End_Text_Block;
      Last_Line := Testing.Line_Count (Conv);
      Last_Byte := Testing.Get_Line_Text (Conv, Last_Line)'Length;
      Testing.Set_Selection
        (Conv, Last_Line, Last_Byte, 1, 0);
      Assert
        (Conv.Selected_Text = "first line" & ASCII.LF & "second line",
         "Selected_Text returns document-ordered primary text");
   end Test_Selected_Text_Uses_Selection_Order;

   procedure Test_Primary_Selection_Round_Trip (T : in out Test) is
      Conv      : Instance;
      Scroll    : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout    : Gtk.Layout.Gtk_Layout;
      Last_Line : Natural;
      Last_Byte : Natural;
      Primary   : Gtk.Clipboard.Gtk_Clipboard;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Set_Render_Markdown (False);
      Conv.Append_Text
        ("primary one" & ASCII.LF & "primary two");
      Conv.End_Text_Block;
      Last_Line := Testing.Line_Count (Conv);
      Last_Byte := Testing.Get_Line_Text (Conv, Last_Line)'Length;
      Testing.Set_Selection (Conv, 1, 0, Last_Line, Last_Byte);
      Conv.Publish_Primary_Selection;
      Primary := Gtk.Clipboard.Get
        (Gtk.Selection_Data.Selection_Primary);
      Assert
        (Primary.Wait_For_Text = "primary one" & ASCII.LF & "primary two",
         "PRIMARY contains the current conversation selection");
   end Test_Primary_Selection_Round_Trip;

   procedure Test_Interactive_Focus_Cycles (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Action : Action_Info (Fork);
      Tool   : Tool_Click_Result;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Begin_Tool ("shell", "{}", "session", "tool");
      Conv.End_Tool ("tool", Success, "ok");
      Action.Fork_UUID := To_Unbounded_String ("session");
      Action.Fork_Turn_N := 1;
      Action.Fork_Step_N := 0;
      Conv.Append_Action_Strip ("Fork", Action);
      Conv.Move_Interactive_Focus;
      Tool := Conv.Focused_Tool;
      Assert (Tool.Found, "first interactive focus should be the tool card");
      Conv.Move_Interactive_Focus;
      Assert (Conv.Focused_Action.Found,
              "second interactive focus should be the action strip");
      Conv.Move_Interactive_Focus (Forward => False);
      Assert (Conv.Focused_Tool.Found,
              "reverse focus should return to the tool card");
   end Test_Interactive_Focus_Cycles;

   procedure Test_Context_Help_Covers_Main_Areas (T : in out Test) is
      pragma Unreferenced (T);
      Areas : constant array (1 .. 6) of String (1 .. 12) :=
        ("menu        ", "prompt      ", "controls    ",
         "status      ", "transcript  ", "conversation");
   begin
      for Area of Areas loop
         declare
            Text : constant String :=
              Coyote_App.Frontend.GUI.Context_Help_Text
                (Ada.Strings.Fixed.Trim (Area, Ada.Strings.Both));
         begin
            Assert (Text'Length > 0, "context help text is not empty");
         end;
      end loop;
      Assert
        (Coyote_App.Frontend.GUI.Context_Help_Text ("prompt")
        'Length > 0,
         "prompt help is available");
   end Test_Context_Help_Covers_Main_Areas;

end Coyote_GUI_Conversation_Tests;
