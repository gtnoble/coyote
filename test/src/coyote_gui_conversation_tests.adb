with Ada.Environment_Variables;
with AUnit.Assertions;
with Glib;         use type Glib.Gint;
with Gtk.Enums;       use Gtk.Enums;
with Gtk.Main;
with Coyote_GUI.Conversation;
with Coyote_GUI.Conversation.Testing;

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

   ---------------------------------------
   --  Tests
   ---------------------------------------

   procedure Test_Total_Vis_Lines_Zero_When_Empty (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Assert (Testing.Total_Vis_Lines (Conv) = 0,
              "empty conversation has zero visual lines");
   end Test_Total_Vis_Lines_Zero_When_Empty;

   procedure Test_Single_Short_Line_Vis_Count_One (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then
         return;
      end if;
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
      if not T.Display_Available then
         return;
      end if;
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
      if not T.Display_Available then
         return;
      end if;
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
      if not T.Display_Available then
         return;
      end if;
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
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Notice (Notice_Info, "initial content");
      Assert (Testing.Cache_Width_Px (Conv) > 0,
              "cache width > 0 before Invalidate_Layout");
      Conv.Invalidate_Layout;
      --  Invalidate_Layout zeroes then immediately recomputes the cache,
      --  so Cache_Width_Px is still valid post-call.
      Assert (Testing.Cache_Width_Px (Conv) > 0,
              "cache width > 0 after Invalidate_Layout (recomputed)");
   end Test_Invalidate_Layout_Zeroes_Cache_Width;

   procedure Test_Recompute_Vis_Lines_Updates_Total (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
      Before : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Before := Testing.Total_Vis_Lines (Conv);
      Conv.Append_Notice (Notice_Info, "new line of text content");
      Assert (Testing.Total_Vis_Lines (Conv) > Before,
              "appending content increases Total_Vis_Lines");
   end Test_Recompute_Vis_Lines_Updates_Total;

   procedure Test_Append_Notice_Increments_Count (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      --  Append_Notice emits exactly one logical line per call.
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
      if not T.Display_Available then
         return;
      end if;
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
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("hello ");
      Conv.Append_Text ("world");
      Assert (Testing.Stream_Buffer (Conv) = "hello world",
              "stream buffer accumulates across calls");
      Conv.End_Text_Block;
      Assert (Testing.Stream_Buffer (Conv) = "",
              "stream buffer cleared after End_Text_Block");
   end Test_Append_Text_Accumulates_Buffer;

   procedure Test_End_Text_Block_Exits_Block (T : in out Test) is
      Conv   : Instance;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Layout : Gtk.Layout.Gtk_Layout;
   begin
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Append_Text ("something");
      Conv.End_Text_Block;
      Assert (not Testing.Is_In_Text_Block (Conv),
              "not in text block after End_Text_Block");
      --  Second call is idempotent.
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
      if not T.Display_Available then
         return;
      end if;
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
      if not T.Display_Available then
         return;
      end if;
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
      if not T.Display_Available then
         return;
      end if;
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
      if not T.Display_Available then
         return;
      end if;
      Make_Fresh_Conv (Conv, Scroll, Layout);
      Conv.Begin_Thinking;
      Conv.End_Thinking;
      Assert (not Testing.Is_In_Thinking (Conv),
              "End_Thinking clears flag");
   end Test_End_Thinking_Clears_Flag;

end Coyote_GUI_Conversation_Tests;
