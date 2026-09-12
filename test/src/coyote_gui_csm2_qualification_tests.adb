--  Coyote_GUI_CSM2_Qualification_Tests body.
--
--  Project: coyote

with Glib;
with Gtk.Container;
with Gtk.Widget;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_GUI;
with Coyote_GUI.Conversation_Stack.Testing;
with Coyote_GUI.Live_Response_Renderer;
with Gtk.Enums;
with Gtk.Main;

package body Coyote_GUI_CSM2_Qualification_Tests is
   use type Glib.Gfloat;
   use type Glib.Gint;

   use AUnit.Assertions;
   use Coyote_GUI;
   use Coyote_GUI.Conversation_Stack;
   use Coyote_GUI.Conversation_Stack.Testing;
   use Ada.Strings.Fixed;

   function Display_Detected return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Detected;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Detected then
         Gtk.Main.Init;
         T.Display_Available := True;
         Gtk.Window.Gtk_New (T.Parent, Gtk.Enums.Window_Toplevel);
         Create (T.Stack, T.Parent.all'Access);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[SKIP display unavailable] CSM-2 GUI qualification fixture");
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      if T.Display_Available then
         Clear (T.Stack);
      end if;
   end Tear_Down;

   function Visible_Text (C : Conversation_Stack.Instance) return String is
      Result : Unbounded_String;
   begin
      if Text_View_Count (C) > 0 then
         for Position in 1 .. Text_View_Count (C) loop
            Append (Result, Text_View_Text (C, Position));
         end loop;
      end if;
      return To_String (Result);
   end Visible_Text;

   procedure Append_CSM (C : in out Conversation_Stack.Instance) is
   begin
      Append_Text
        (C,
         "<p>before <strong>bold</strong> and <em>em</em></p>"
         & "<h2>Title</h2><list kind=""ordered"" start=""2"">"
         & "<item>one</item><item>two</item></list>"
         & "<blockquote><p>quote</p></blockquote>"
         & "<code lang=""ada"">x &lt; y</code><hr/>"
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mrow><mi>x</mi><mo>&lt;</mo><mn>1</mn></mrow></math>"
         & "<table><row kind=""header""><cell align=""center"">Name</cell>"
         & "<cell align=""right"">Value</cell></row><row>"
         & "<cell>alpha</cell><cell>42</cell></row></table>"
         & "<p>after</p>");
   end Append_CSM;

   procedure Append_Markdown (C : in out Conversation_Stack.Instance) is
   begin
      Append_Text
        (C,
         "before **bold** and *em*" & ASCII.LF & ASCII.LF
         & "## Title" & ASCII.LF & ASCII.LF
         & "2. one" & ASCII.LF & "3. two" & ASCII.LF & ASCII.LF
         & "> quote" & ASCII.LF & ASCII.LF
         & "```ada" & ASCII.LF & "x &lt; y" & ASCII.LF & "```"
         & ASCII.LF & ASCII.LF & "---" & ASCII.LF & ASCII.LF
         & "$$" & ASCII.LF
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mrow><mi>x</mi><mo>&lt;</mo><mn>1</mn></mrow></math>"
         & ASCII.LF & "$$" & ASCII.LF & ASCII.LF
         & "| Name | Value |" & ASCII.LF & "| :---: | ---: |" & ASCII.LF
         & "| alpha | 42 |" & ASCII.LF & ASCII.LF & "after");
   end Append_Markdown;

   procedure Test_Paired_CSM2_And_Markdown_Parity (T : in out Test) is
      CSM_Text      : Unbounded_String;
      Markdown_Text : Unbounded_String;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_CSM (T.Stack);
      End_Text_Block (T.Stack);
      CSM_Text := To_Unbounded_String (Visible_Text (T.Stack));
      Assert (Index (To_String (CSM_Text), "before bold and em") > 0,
              "CSM visible text retains paragraph content");
      Assert (Index (To_String (CSM_Text), "Title") > 0,
              "CSM visible text retains heading content");
      Assert (Index (To_String (CSM_Text), "one") > 0,
              "CSM visible text retains list content");
      Assert (Index (To_String (CSM_Text), "quote") > 0,
              "CSM visible text retains quote content");
      Assert (Index (To_String (CSM_Text), "<p>") = 0,
              "completed CSM has no raw tags in visible text");
      Assert (Table_Count (T.Stack) = 1, "CSM realizes one native table");
      Assert (Table_Cell (T.Stack, 1, 1, 1).Get_Text = "Name",
              "CSM table header text is native");
      Assert (Table_Cell (T.Stack, 1, 2, 2).Get_Text = "42",
              "CSM table body text is native");
      Assert (Table_Cell (T.Stack, 1, 1, 1).Get_Xalign = 0.5,
              "CSM center alignment is retained");
      Assert (Table_Cell (T.Stack, 1, 1, 2).Get_Xalign = 1.0,
              "CSM right alignment is retained");
      Assert (Math_Element_Count (T.Stack) = 1,
              "CSM realizes one native MathML element");
      Assert (Math_Is_Valid (T.Stack, 1), "CSM MathML is valid");
      Assert (Index (Math_Source (T.Stack, 1), "<math") > 0,
              "CSM MathML source remains available");
      Assert (Text_View_Count (T.Stack) > 0,
              "CSM retains selectable text views");
      Select_All (T.Stack);
      Assert (Has_Selection (T.Stack), "CSM selection is available");
      Copy_Selection (T.Stack);
      Clear_Selection (T.Stack);
      Clear (T.Stack);
      Set_Incremental_Markup (T.Stack, False);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Markdown (T.Stack);
      End_Text_Block (T.Stack);
      Markdown_Text := To_Unbounded_String (Visible_Text (T.Stack));
      Assert (Index (To_String (Markdown_Text), "before bold and em") > 0,
              "Markdown visible text retains equivalent paragraph content");
      Assert (Index (To_String (Markdown_Text), "Title") > 0,
              "Markdown visible text retains equivalent heading content");
      Assert (Index (To_String (Markdown_Text), "quote") > 0,
              "Markdown visible text retains equivalent quote content");
      Assert (Table_Count (T.Stack) = 1,
              "Markdown reference realizes one native table");
      Assert (Table_Cell (T.Stack, 1, 2, 2).Get_Text = "42",
              "Markdown reference table body matches CSM");
      Assert (Math_Element_Count (T.Stack) = 1,
              "Markdown reference realizes one native MathML element");
      Assert (Math_Is_Valid (T.Stack, 1),
              "Markdown reference MathML is valid");
      Assert (Text_View_Count (T.Stack) > 0,
              "Markdown reference retains selectable text views");
   end Test_Paired_CSM2_And_Markdown_Parity;

   procedure Test_Response_Children_Selection_And_Reconciliation
     (T : in out Test)
   is
      Children : Gtk.Widget.Widget_List.Glist;
      Before_Count : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "<p>before ");
      Append_Text (T.Stack, "<strong>bold</strong> after</p>");
      End_Text_Block (T.Stack);
      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Response_Box (T.Stack)));
      Before_Count := Natural (Gtk.Widget.Widget_List.Length (Children));
      Assert (Response_Box (T.Stack).Get_Spacing = 2,
              "response container preserves the shared spacing policy");
      Assert (Before_Count > 0,
              "completed split CSM response has response children");
      Assert (Index (Visible_Text (T.Stack), "before bold after") > 0,
              "split CSM deltas reconcile to visible normalized text");
      Select_All (T.Stack);
      Assert (Has_Selection (T.Stack),
              "split CSM response supports selection");
      Copy_Selection (T.Stack);
      Clear_Selection (T.Stack);
      Clear (T.Stack);
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "<p>new text</p>");
      End_Text_Block (T.Stack);
      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Response_Box (T.Stack)));
      Assert (Natural (Gtk.Widget.Widget_List.Length (Children)) = 1,
              "new request removes stale response widgets");
      Assert (Index (Visible_Text (T.Stack), "new text") > 0,
              "new request leaves only reconciled normalized text");
   end Test_Response_Children_Selection_And_Reconciliation;

   procedure Test_Malformed_CSM2_Has_No_Stale_Native_Widgets
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text
        (T.Stack,
         "<table><row><cell>old</cell><cell>42</cell></row></table>");
      End_Text_Block (T.Stack);
      Assert (Table_Count (T.Stack) = 1,
              "valid prefix initially creates native table");
      Clear (T.Stack);
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text
        (T.Stack,
         "<table><row><cell>broken</cell></row><row>"
         & "<cell>x</cell><cell>y</cell></row></table>");
      End_Text_Block (T.Stack);
      Assert
        (Table_Count (T.Stack) = 0
         or else Table_Cell (T.Stack, 1, 1, 1).Get_Text /= "old",
         "malformed completion removes prior stale table content");
      Assert (Text_View_Count (T.Stack) > 0,
              "malformed completion retains visible source view");
      Assert (Index (Visible_Text (T.Stack), "<table>") > 0,
              "malformed source remains visibly selectable");
      Assert (Index (Visible_Text (T.Stack), "<row>") > 0,
              "crossing/unclosed source remains visible");
   end Test_Malformed_CSM2_Has_No_Stale_Native_Widgets;

   procedure Test_CSM2_Live_Visibility_And_Styles (T : in out Test) is
      Source : constant String :=
        "<p>live <strong>bold</strong> <em>italic</em>"
        & " <code-inline>code</code-inline><br/>tail</p>"
        & "<blockquote><p>quote</p></blockquote>"
        & "<list kind=""ordered"" start=""4""><item>item</item></list>"
        & "<code lang=""ada"">x &lt; y</code>";
      Live_Text      : Unbounded_String;
      Bold_At        : Natural;
      Italic_At      : Natural;
      Inline_Code_At : Natural;
      Quote_At       : Natural;
      Item_At        : Natural;
      Literal_At     : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      Live_Text := To_Unbounded_String (Live_Response_Text (T.Stack));
      Bold_At        := Index (To_String (Live_Text), "bold") - 1;
      Italic_At      := Index (To_String (Live_Text), "italic") - 1;
      Inline_Code_At := Index (To_String (Live_Text), "code") - 1;
      Quote_At       := Index (To_String (Live_Text), "quote") - 1;
      Item_At        := Index (To_String (Live_Text), "item") - 1;
      Literal_At     := Index (To_String (Live_Text), "x &lt; y") - 1;
      Assert (Live_Response_Present (T.Stack),
              "CSM live renderer is present before End_Text_Block");
      Assert (Index (To_String (Live_Text), "live bold italic code") > 0,
              "CSM text and inline code are visible before end");
      Assert (Index (To_String (Live_Text), "tail") > 0,
              "CSM br content is visible before end");
      Assert (Index (To_String (Live_Text), "quote") > 0,
              "CSM blockquote content is visible before end");
      Assert (Index (To_String (Live_Text), "4. item") > 0,
              "CSM list item is visible before end");
      Assert (Index (To_String (Live_Text), "x &lt; y") > 0,
              "CSM literal code is visible before end");
      Assert (Live_Response_Text_Has_Style
                (T.Stack,
                 Coyote_GUI.Live_Response_Renderer.Strong_Style,
                 Bold_At),
              "CSM strong text is styled before end");
      Assert (Live_Response_Text_Has_Style
                (T.Stack,
                 Coyote_GUI.Live_Response_Renderer.Em_Style,
                 Italic_At),
              "CSM emphasis text is styled before end");
      Assert (Live_Response_Text_Has_Style
                (T.Stack,
                 Coyote_GUI.Live_Response_Renderer.Inline_Code_Style,
                 Inline_Code_At),
              "CSM inline code is styled before end");
      Assert (Live_Response_Text_Has_Style
                (T.Stack,
                 Coyote_GUI.Live_Response_Renderer.Blockquote_Style,
                 Quote_At),
              "CSM blockquote is styled before end");
      Assert (Live_Response_Text_Has_Style
                (T.Stack,
                 Coyote_GUI.Live_Response_Renderer.List_Style,
                 Item_At),
              "CSM list item is styled before end");
      Assert (Live_Response_Text_Has_Style
                (T.Stack,
                 Coyote_GUI.Live_Response_Renderer.Code_Block_Style,
                 Literal_At),
              "CSM literal code is styled before end");
      End_Text_Block (T.Stack);
      Assert (not Live_Response_Present (T.Stack),
              "live subtree is removed by authoritative final replacement");
   end Test_CSM2_Live_Visibility_And_Styles;

   procedure Test_CSM2_Deferred_Blocks_Finalize_Only (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text
        (T.Stack,
         "<p>before</p><table><row><cell>cell</cell></row></table>"
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mi>x</mi></math>");
      Assert (Table_Count (T.Stack) = 0,
              "CSM table is deferred before End_Text_Block");
      Assert (Math_Element_Count (T.Stack) = 0,
              "CSM math is deferred before End_Text_Block");
      Assert (Index (Live_Response_Text (T.Stack), "cell") > 0,
              "deferred table remains visible as live source text");
      End_Text_Block (T.Stack);
      Assert (Table_Count (T.Stack) = 1,
              "CSM table is native after finalization");
      Assert (Math_Element_Count (T.Stack) = 1,
              "CSM math is native after finalization");
   end Test_CSM2_Deferred_Blocks_Finalize_Only;

   procedure Test_CSM2_Reset_And_Duplicate_Finalization (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "<p>first</p>");
      End_Text_Block (T.Stack);
      End_Text_Block (T.Stack);
      Assert (Index (Visible_Text (T.Stack), "first") > 0,
              "duplicate End_Text_Block preserves one final response");
      Assert (Text_View_Count (T.Stack) = 1,
              "duplicate End_Text_Block does not add a second text view");
      Assert (Table_Count (T.Stack) = 0,
              "duplicate End_Text_Block does not add a stale table");
      Clear (T.Stack);
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "<p>second</p>");
      Assert (Index (Live_Response_Text (T.Stack), "second") > 0,
              "new request resets live content");
      End_Text_Block (T.Stack);
      Assert (Index (Visible_Text (T.Stack), "first") = 0,
              "new request does not duplicate old response");
      Assert (Index (Visible_Text (T.Stack), "second") > 0,
              "new request retains only new response");
   end Test_CSM2_Reset_And_Duplicate_Finalization;

   procedure Test_CSM2_Invalid_Prefix_And_Lifecycle_Rollback
     (T : in out Test)
   is
      Source : constant String :=
        "<p>optimistic <strong>prefix</p></strong> tail";
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      Assert (Index (Live_Response_Text (T.Stack), "optimistic") > 0,
              "malformed prefix is visible optimistically");
      End_Text_Block (T.Stack);
      Assert (not Live_Response_Present (T.Stack),
              "finalization removes the optimistic subtree");
      Assert (Index (Visible_Text (T.Stack), Source) > 0,
              "malformed final response shows exact source fallback");
      Assert (Table_Count (T.Stack) = 0,
              "malformed final response has no stale table");
      Assert (Math_Element_Count (T.Stack) = 0,
              "malformed final response has no stale math");
      End_Text_Block (T.Stack);
      Assert (Index (Visible_Text (T.Stack), Source) > 0,
              "repeated finalization does not duplicate fallback");

      Clear (T.Stack);
      Set_Incremental_Markup (T.Stack, True);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text
        (T.Stack,
         "<code>literal <table><row><cell>x</cell></row></table>");
      End_Text_Block (T.Stack);
      Assert (Table_Count (T.Stack) = 0,
              "incomplete opaque code cannot create a table");
      Assert (Math_Element_Count (T.Stack) = 0,
              "incomplete opaque code cannot create math");
      Assert (Index (Visible_Text (T.Stack), "<code>literal") > 0,
              "incomplete opaque source remains visible");

      Set_Response_Format (T.Stack, Markdown_Response);
      Assert (Get_Response_Format (T.Stack) = Markdown_Response,
              "format change selects Markdown response mode");
      Assert (not Live_Response_Present (T.Stack),
              "format change detaches and clears live response state");
      Clear (T.Stack);
      Clear (T.Stack);
      Assert (Text_View_Count (T.Stack) = 0,
              "repeated clear leaves no stale text widgets");
   end Test_CSM2_Invalid_Prefix_And_Lifecycle_Rollback;

   package Caller is new AUnit.Test_Caller (Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI paired Markdown parity",
         Test_Paired_CSM2_And_Markdown_Parity'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI response children selection reconciliation",
         Test_Response_Children_Selection_And_Reconciliation'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI malformed stale-widget reconciliation",
         Test_Malformed_CSM2_Has_No_Stale_Native_Widgets'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI live visibility and styles",
         Test_CSM2_Live_Visibility_And_Styles'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI deferred blocks finalize only",
         Test_CSM2_Deferred_Blocks_Finalize_Only'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI reset and duplicate finalization",
         Test_CSM2_Reset_And_Duplicate_Finalization'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI invalid prefix and lifecycle rollback",
         Test_CSM2_Invalid_Prefix_And_Lifecycle_Rollback'Access));
      return Result;
   end Suite;

end Coyote_GUI_CSM2_Qualification_Tests;
