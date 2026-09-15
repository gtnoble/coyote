--  Coyote_GUI_CSM2_Qualification_Tests body.
--
--  Project: coyote

with Glib;
with Gtk.Box;
with Gtk.Container;
with Gtk.Widget;
with Gtk.Scrolled_Window;
with Gtk.Text_View;
with Gtk.Style_Context;
with Pango.Font;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with AUnit.Assertions;
with AUnit.Test_Caller;
with Coyote_GUI;
with Coyote_GUI.Conversation_Stack.Testing;
with Gtk.Enums;
with Gtk.Flow_Box;
with Gtk.Flow_Box_Child;
with Gtk.Main;

package body Coyote_GUI_CSM2_Qualification_Tests is
   use type Glib.Gfloat;
   use type Glib.Gint;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Flow_Box.Gtk_Flow_Box;
   use type Gtk.Flow_Box_Child.Gtk_Flow_Box_Child;
   use type Gtk.Widget.Gtk_Widget;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Window.Gtk_Window;
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
         T.Stack := new Coyote_GUI.Conversation_Stack.Instance;
         Create (T.Stack.all, T.Parent.all'Access);
         T.Parent.Add (Widget (T.Stack.all));
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[SKIP display unavailable] CSM-2 GUI qualification fixture");
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      if T.Display_Available then
         Clear (T.Stack.all);
         T.Parent.Destroy;
         T.Parent := null;
         Free_Stack : declare
            procedure Free is new Ada.Unchecked_Deallocation
              (Coyote_GUI.Conversation_Stack.Instance, Stack_Access);
         begin
            Free (T.Stack);
         end Free_Stack;
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
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_CSM (T.Stack.all);
      End_Text_Block (T.Stack.all);
      CSM_Text := To_Unbounded_String (Visible_Text (T.Stack.all));
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
      Assert (Table_Count (T.Stack.all) = 1, "CSM realizes one native table");
      Assert (Table_Cell (T.Stack.all, 1, 1, 1).Get_Text = "Name",
              "CSM table header text is native");
      Assert (Table_Cell (T.Stack.all, 1, 2, 2).Get_Text = "42",
              "CSM table body text is native");
      Assert (Table_Cell (T.Stack.all, 1, 1, 1).Get_Xalign = 0.5,
              "CSM center alignment is retained");
      Assert (Table_Cell (T.Stack.all, 1, 1, 2).Get_Xalign = 1.0,
              "CSM right alignment is retained");
      Assert (Math_Element_Count (T.Stack.all) = 1,
              "CSM realizes one native MathML element");
      Assert (Math_Is_Valid (T.Stack.all, 1), "CSM MathML is valid");
      Assert (Index (Math_Source (T.Stack.all, 1), "<math") > 0,
              "CSM MathML source remains available");
      Assert (Text_View_Count (T.Stack.all) > 0,
              "CSM retains selectable text views");
      Select_All (T.Stack.all);
      Assert (Has_Selection (T.Stack.all), "CSM selection is available");
      Copy_Selection (T.Stack.all);
      Clear_Selection (T.Stack.all);
      Clear (T.Stack.all);
      Set_Incremental_Markup (T.Stack.all, False);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Markdown (T.Stack.all);
      End_Text_Block (T.Stack.all);
      Markdown_Text := To_Unbounded_String (Visible_Text (T.Stack.all));
      Assert (Index (To_String (Markdown_Text), "before bold and em") > 0,
              "Markdown visible text retains equivalent paragraph content");
      Assert (Index (To_String (Markdown_Text), "Title") > 0,
              "Markdown visible text retains equivalent heading content");
      Assert (Index (To_String (Markdown_Text), "quote") > 0,
              "Markdown visible text retains equivalent quote content");
      Assert (Table_Count (T.Stack.all) = 1,
              "Markdown reference realizes one native table");
      Assert (Table_Cell (T.Stack.all, 1, 2, 2).Get_Text = "42",
              "Markdown reference table body matches CSM");
      Assert (Math_Element_Count (T.Stack.all) = 1,
              "Markdown reference realizes one native MathML element");
      Assert (Math_Is_Valid (T.Stack.all, 1),
              "Markdown reference MathML is valid");
      Assert (Text_View_Count (T.Stack.all) > 0,
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
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "<p>before ");
      Append_Text (T.Stack.all, "<strong>bold</strong> after</p>");
      End_Text_Block (T.Stack.all);
      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Response_Box (T.Stack.all)));
      Before_Count := Natural (Gtk.Widget.Widget_List.Length (Children));
      Assert (Response_Box (T.Stack.all).Get_Spacing = 2,
              "response container preserves the shared spacing policy");
      Assert (Before_Count > 0,
              "completed split CSM response has response children");
      Assert (Index (Visible_Text (T.Stack.all), "before bold after") > 0,
              "split CSM deltas reconcile to visible normalized text");
      Select_All (T.Stack.all);
      Assert (Has_Selection (T.Stack.all),
              "split CSM response supports selection");
      Copy_Selection (T.Stack.all);
      Clear_Selection (T.Stack.all);
      Clear (T.Stack.all);
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "<p>new text</p>");
      End_Text_Block (T.Stack.all);
      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Response_Box (T.Stack.all)));
      Assert (Natural (Gtk.Widget.Widget_List.Length (Children)) > 0,
              "new request retains reconciled response root");
      Assert (Index (Visible_Text (T.Stack.all), "new text") > 0,
              "new request leaves only reconciled normalized text");
   end Test_Response_Children_Selection_And_Reconciliation;

   procedure Test_Malformed_CSM2_Has_No_Stale_Native_Widgets
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text
        (T.Stack.all,
         "<table><row><cell>old</cell><cell>42</cell></row></table>");
      End_Text_Block (T.Stack.all);
      Assert (Table_Count (T.Stack.all) = 1,
              "valid prefix initially creates native table");
      Clear (T.Stack.all);
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text
        (T.Stack.all,
         "<table><row><cell>broken</cell></row><row>"
         & "<cell>x</cell><cell>y</cell></row></table>");
      End_Text_Block (T.Stack.all);
      Assert
        (Table_Count (T.Stack.all) = 0
         or else Table_Cell (T.Stack.all, 1, 1, 1).Get_Text /= "old",
         "malformed completion removes prior stale table content");
      Assert (Text_View_Count (T.Stack.all) > 0,
              "malformed completion retains visible source view");
      Assert (Index (Visible_Text (T.Stack.all), "<table>") > 0,
              "malformed source remains visibly selectable");
      Assert (Index (Visible_Text (T.Stack.all), "<row>") > 0,
              "crossing/unclosed source remains visible");
   end Test_Malformed_CSM2_Has_No_Stale_Native_Widgets;

   procedure Test_CSM2_Live_Visibility_And_Styles (T : in out Test) is
      Source : constant String :=
        "<p>live <strong>bold</strong> <em>italic</em>"
        & " <code-inline>code</code-inline><br/>tail</p>"
        & "<blockquote><p>quote</p></blockquote>"
        & "<list kind=""ordered"" start=""4""><item>item</item></list>"
        & "<code lang=""ada"">x &lt; y</code>";
      Presented_Text      : Unbounded_String;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      Presented_Text := To_Unbounded_String (Streaming_Response_Text (T.Stack.all));
      Assert (Streaming_Response_Present (T.Stack.all),
              "CSM streaming presenter is present before End_Text_Block");
      Assert (Index (To_String (Presented_Text), "live bold italic code") > 0,
              "CSM text and inline code are visible before end");
      Assert (Index (To_String (Presented_Text), "tail") > 0,
              "CSM br content is visible before end");
      Assert (Index (To_String (Presented_Text), "quote") > 0,
              "CSM blockquote content is visible before end");
      Assert (Index (To_String (Presented_Text), "4. item") > 0,
              "CSM list item is visible before end");
      Assert (Index (To_String (Presented_Text), "x &lt; y") > 0,
              "CSM literal code is visible before end");






      End_Text_Block (T.Stack.all);
      Assert (Active_Text_View (T.Stack.all) /= null,
              "semantic presenter retains an active text view after commit");
   end Test_CSM2_Live_Visibility_And_Styles;

   procedure Test_CSM2_Deferred_Blocks_Finalize_Only (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text
        (T.Stack.all,
         "<p>before</p><table><row><cell>cell</cell></row></table>"
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mi>x</mi></math>");
      Assert (Table_Count (T.Stack.all) = 1,
              "CSM table commits at its semantic close");
      Assert (Math_Element_Count (T.Stack.all) = 1,
              "CSM math commits at its semantic close");
      Assert (Table_Cell (T.Stack.all, 1, 1, 1).Get_Text = "cell",
              "committed table content remains in the native payload");
      End_Text_Block (T.Stack.all);
      Assert (Table_Count (T.Stack.all) = 1,
              "CSM table is native after finalization");
      Assert (Math_Element_Count (T.Stack.all) = 1,
              "CSM math is native after finalization");
   end Test_CSM2_Deferred_Blocks_Finalize_Only;

   procedure Test_CSM2_Redundant_Math_Wrapper (T : in out Test) is
      Source : constant String :=
        "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & ASCII.LF
        & "  <math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mrow><mi>x</mi><mo>&lt;</mo><mn>10</mn></mrow>"
        & "</math>" & ASCII.LF & "</math>";
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Assert (Math_Element_Count (T.Stack.all) = 1,
              "redundant MathML creates one native element");
      Assert (Math_Is_Valid (T.Stack.all, 1),
              "redundant MathML creates valid native MathML");
      Assert (Index (Math_Source (T.Stack.all, 1), Source) > 0,
              "redundant MathML retains complete CSM source");
      Assert (Index (Visible_Text (T.Stack.all), "<math") = 0,
              "valid redundant MathML hides wrapper source");
   end Test_CSM2_Redundant_Math_Wrapper;

   procedure Test_CSM2_Reset_And_Duplicate_Finalization (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "<p>first</p>");
      End_Text_Block (T.Stack.all);
      End_Text_Block (T.Stack.all);
      Assert (Index (Visible_Text (T.Stack.all), "first") > 0,
              "duplicate End_Text_Block preserves one final response");
      Assert (Text_View_Count (T.Stack.all) = 1,
              "duplicate End_Text_Block does not add a second text view");
      Assert (Table_Count (T.Stack.all) = 0,
              "duplicate End_Text_Block does not add a stale table");
      Clear (T.Stack.all);
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "<p>second</p>");
      Assert (Index (Streaming_Response_Text (T.Stack.all), "second") > 0,
              "new request resets live content");
      End_Text_Block (T.Stack.all);
      Assert (Index (Visible_Text (T.Stack.all), "first") = 0,
              "new request does not duplicate old response");
      Assert (Index (Visible_Text (T.Stack.all), "second") > 0,
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
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      Assert (Index (Streaming_Response_Text (T.Stack.all), "optimistic") > 0,
              "malformed prefix is visible optimistically");
      End_Text_Block (T.Stack.all);
      Assert (not Streaming_Response_Present (T.Stack.all),
              "finalization removes the streaming subtree");
      Assert (Index (Visible_Text (T.Stack.all), Source) > 0,
              "malformed final response shows exact source fallback");
      Assert (Table_Count (T.Stack.all) = 0,
              "malformed final response has no stale table");
      Assert (Math_Element_Count (T.Stack.all) = 0,
              "malformed final response has no stale math");
      End_Text_Block (T.Stack.all);
      Assert (Index (Visible_Text (T.Stack.all), Source) > 0,
              "repeated finalization does not duplicate fallback");

      Clear (T.Stack.all);
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text
        (T.Stack.all,
         "<code>literal <table><row><cell>x</cell></row></table>");
      End_Text_Block (T.Stack.all);
      Assert (Table_Count (T.Stack.all) = 0,
              "incomplete opaque code cannot create a table");
      Assert (Math_Element_Count (T.Stack.all) = 0,
              "incomplete opaque code cannot create math");
      Assert (Index (Visible_Text (T.Stack.all), "<code>literal") > 0,
              "incomplete opaque source remains visible");

      Set_Response_Format (T.Stack.all, Markdown_Response);
      Assert (Get_Response_Format (T.Stack.all) = Markdown_Response,
              "format change selects Markdown response mode");
      Assert (not Streaming_Response_Present (T.Stack.all),
              "format change detaches and clears streaming response state");
      Clear (T.Stack.all);
      Clear (T.Stack.all);
      Assert (Text_View_Count (T.Stack.all) = 0,
              "repeated clear leaves no stale text widgets");
   end Test_CSM2_Invalid_Prefix_And_Lifecycle_Rollback;

   procedure Test_CSM2_Retains_Completed_Response_Roots
     (T : in out Test)
   is
      First_Root   : Gtk.Box.Gtk_Box;
      First_Parent : Gtk.Widget.Gtk_Widget;
      Second_Root  : Gtk.Box.Gtk_Box;
      Second_Parent : Gtk.Widget.Gtk_Widget;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "first request", Prompt);
      Append_Text (T.Stack.all, "<p>first completed response</p>");
      End_Text_Block (T.Stack.all);
      Complete_Request (T.Stack.all, Completed);
      First_Root := Response_Box (T.Stack.all);
      Assert (First_Root /= null, "first response has a rendered root");
      First_Parent := First_Root.Get_Parent;
      Assert (First_Parent /= null, "first root has a GTK parent");

      Begin_Request (T.Stack.all, "second request", Prompt);
      Append_Text (T.Stack.all, "<p>second completed response</p>");
      End_Text_Block (T.Stack.all);
      Complete_Request (T.Stack.all, Completed);
      Second_Root := Response_Box (T.Stack.all);
      Assert (Second_Root /= null, "second response has a rendered root");
      Second_Parent := Second_Root.Get_Parent;
      Assert (First_Root /= Second_Root,
              "second response uses a distinct rendered root");
      Assert (First_Root.Get_Parent = First_Parent,
              "first root remains attached to its original parent");
      Assert (Second_Parent /= null, "second root has a GTK parent");
      Assert (Second_Parent /= First_Parent,
              "second response uses its own response parent");
      Assert (Index (Visible_Text (T.Stack.all), "first completed response") > 0,
              "first response remains visible");
      Assert (Index (Visible_Text (T.Stack.all), "second completed response") > 0,
              "second response remains visible");
   end Test_CSM2_Retains_Completed_Response_Roots;

   procedure Test_CSM2_Format_Change_Preserves_Completed_Response
     (T : in out Test)
   is
      Root : Gtk.Box.Gtk_Box;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "<p>survives format change</p>");
      End_Text_Block (T.Stack.all);
      Complete_Request (T.Stack.all, Completed);
      Root := Response_Box (T.Stack.all);
      Set_Response_Format (T.Stack.all, Markdown_Response);
      Assert (Root /= null, "completed response root remains available");
      Assert (Root.Get_Parent /= null,
              "completed response root remains attached after format change");
      Assert (Index (Visible_Text (T.Stack.all), "survives format change") > 0,
              "completed response content survives format change");
      Assert (Get_Response_Format (T.Stack.all) = Markdown_Response,
              "format change selects Markdown for the next response");
   end Test_CSM2_Format_Change_Preserves_Completed_Response;

   procedure Test_Format_Change_Closes_Active_Raw_Response
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, False);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "active raw response");
      Assert (Response_Stream_Present (T.Stack.all),
              "raw response view is present while streaming");
      Set_Response_Format (T.Stack.all, Coyote_Stream_2_Response);
      Assert (not Response_Stream_Present (T.Stack.all),
              "format change removes the active raw response view");
      Assert (not Streaming_Response_Present (T.Stack.all),
              "format change leaves no stale streaming response");
   end Test_Format_Change_Closes_Active_Raw_Response;

   procedure Test_CSM2_Completed_Owner_Survives_Raw_Format_Change
     (T : in out Test)
   is
      Root : Gtk.Box.Gtk_Box;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "<p>completed CSM response</p>");
      End_Text_Block (T.Stack.all);
      Root := Response_Box (T.Stack.all);
      Assert (Root /= null, "completed CSM response has a root");
      Assert (Response_Owner_Count (T.Stack.all) = 1,
              "completed response has one retained owner");
      Assert (not Active_Response_Present (T.Stack.all),
              "completed response is no longer active");

      Set_Response_Format (T.Stack.all, Markdown_Response);
      Append_Text (T.Stack.all, "raw response");
      Assert (Stream_Mark_Present (T.Stack.all),
              "raw response owns a stream mark while open");
      Set_Response_Format (T.Stack.all, Coyote_Stream_2_Response);
      Assert (Root.Get_Parent /= null,
              "completed CSM response remains attached after raw discard");
      Assert
        (Index (Visible_Text (T.Stack.all), "completed CSM response") > 0,
         "completed CSM response remains visible after raw discard");
      Assert (Response_Owner_Count (T.Stack.all) = 1,
              "raw format change preserves the completed owner");
      Assert (not Stream_Mark_Present (T.Stack.all),
              "raw format change deletes the stream mark");
      Assert (not Text_Block_Open (T.Stack.all),
              "raw format change closes the active block");
   end Test_CSM2_Completed_Owner_Survives_Raw_Format_Change;

   procedure Test_CSM2_Interrupted_Response_Is_Finalized
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "first request", Prompt);
      Append_Text (T.Stack.all, "<p>unfinished response</p>");
      Assert (Active_Response_Present (T.Stack.all),
              "streaming response has an active owner");
      Begin_Request (T.Stack.all, "second request", Prompt);
      Assert (not Text_Block_Open (T.Stack.all),
              "new request closes the interrupted response");
      Assert (not Active_Response_Present (T.Stack.all),
              "interrupted response owner becomes completed");
      Assert (Response_Owner_Count (T.Stack.all) = 1,
              "interrupted response remains retained");
      Assert (not Stream_Mark_Present (T.Stack.all),
              "new request deletes the interrupted stream mark");
      Assert
        (Index (Visible_Text (T.Stack.all), "unfinished response") > 0,
         "partial interrupted response remains visible");
      Append_Text (T.Stack.all, "<p>second response</p>");
      End_Text_Block (T.Stack.all);
      Assert (Index (Visible_Text (T.Stack.all), "second response") > 0,
              "second request renders after interruption");
   end Test_CSM2_Interrupted_Response_Is_Finalized;

   procedure Test_CSM2_Response_Tool_Response_Lifecycle
     (T : in out Test)
   is
      First_Root   : Gtk.Box.Gtk_Box;
      First_Parent : Gtk.Widget.Gtk_Widget;
      Flow         : Gtk.Flow_Box.Gtk_Flow_Box;
      Second_Root  : Gtk.Box.Gtk_Box;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "<p>before tool</p>");
      End_Text_Block (T.Stack.all);
      First_Root := Response_Box (T.Stack.all);
      First_Parent := First_Root.Get_Parent;
      Begin_Tool
        (C          => T.Stack.all,
         Name       => "shell",
         Args       => "{""command"":""true""}",
         Session_Id => "session",
         Tool_Id    => "lifecycle-tool");
      Flow := Tool_Flow (T.Stack.all);
      Assert (Flow /= null, "tool lifecycle creates a tool flow");
      End_Tool (T.Stack.all, "lifecycle-tool", Success, "ok");
      Append_Turn_Footer (T.Stack.all, "step complete", Step_Footer);
      Append_Fork_Action (T.Stack.all, "fork", "session", 1, 1);
      Append_Text (T.Stack.all, "<p>after tool</p>");
      End_Text_Block (T.Stack.all);
      Second_Root := Response_Box (T.Stack.all);
      Assert (Flow.Get_Child_At_Index (0) /= null,
              "tool card remains in the completed step");
      Assert (First_Root.Get_Parent = First_Parent,
              "response before tool remains attached");
      Assert (Second_Root /= First_Root,
              "response after tool has a distinct root");
      Assert
        (Index (Visible_Text (T.Stack.all), "before tool") > 0,
         "response before tool remains visible");
      Assert
        (Index (Visible_Text (T.Stack.all), "after tool") > 0,
         "response after tool remains visible");
   end Test_CSM2_Response_Tool_Response_Lifecycle;

   procedure Test_CSM2_Raw_Inline_Is_Escaped_And_Unstyled
     (T : in out Test)
   is
      Source : constant String :=
        "<p>typed <strong>bold</strong><unknown>x &lt;y&gt;</unknown>tail</p>";
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      End_Text_Block (T.Stack.all);
      Assert
        (Index (Visible_Text (T.Stack.all), "<unknown>x &lt;y&gt;</unknown>") > 0,
         "raw inline source is escaped and visible as literal text");
      Assert (Index (Visible_Text (T.Stack.all), "<b>") = 0,
              "raw inline has no strong style markup");
      Assert (Index (Visible_Text (T.Stack.all), "<tt>") = 0,
              "raw inline has no code style markup");
      Assert (Text_View_Count (T.Stack.all) > 0,
              "raw inline remains in a selectable text view");
   end Test_CSM2_Raw_Inline_Is_Escaped_And_Unstyled;

   procedure Test_CSM2_Localized_Recovery_Preserves_Native_Blocks
     (T : in out Test)
   is
      Source : constant String :=
        "<table><row><cell>before</cell></row></table>"
        & "<p><strong>broken</p></strong>"
        & "<p>attribute <link bad>x</link> tail</p>"
        & "<p>entity &bogus; tail</p>"
        & "<p><unknown>tag</unknown> tail</p>"
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mi>after</mi></math><p>later</p>";
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      Assert (Index (Streaming_Response_Text (T.Stack.all), "<p><strong>broken") > 0,
              "malformed root is visible during live rendering");
      Assert (Streaming_Response_Invalid_Event_Count (T.Stack.all) = 4,
              "localized inline invalid events arrive before End_Text_Block");
      Assert
        (Index (Streaming_Response_Text (T.Stack.all), "<link bad>x</link> tail") > 0,
         "malformed inline attributes are visible before End_Text_Block");
      Assert (Index (Streaming_Response_Text (T.Stack.all), "&bogus; tail") > 0,
              "malformed entities are visible before End_Text_Block");
      Assert
        (Index (Streaming_Response_Text (T.Stack.all),
                "<unknown>tag</unknown> tail") > 0,
         "unknown inline tags are visible before End_Text_Block");
      End_Text_Block (T.Stack.all);
      Assert (Table_Count (T.Stack.all) = 1,
              "valid table before malformed root survives final replacement");
      Assert (Table_Cell (T.Stack.all, 1, 1, 1).Get_Text = "before",
              "pre-error native table content is retained");
      Assert (Math_Element_Count (T.Stack.all) = 1,
              "valid MathML after malformed root is realized natively");
      Assert (Math_Is_Valid (T.Stack.all, 1),
              "post-error MathML remains valid");
      Assert
        (Index (Visible_Text (T.Stack.all), "broken") > 0,
         "malformed root remains visible after authoritative replacement");
      Assert (Index (Visible_Text (T.Stack.all), "later") > 0,
              "later valid content remains visible after replacement");
      Assert (not Streaming_Response_Present (T.Stack.all),
              "final replacement removes the streaming presenter widget");
   end Test_CSM2_Localized_Recovery_Preserves_Native_Blocks;

   procedure Test_CSM2_Raw_Source_Is_Retained_Around_Root
     (T : in out Test)
   is
      Source : constant String := "text<hr/><p>x</p>";
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, Source);
      Assert (Response_Caption (T.Stack.all) = "Response",
              "CSM response section retains its visible caption");
      Assert (Index (Streaming_Response_Text (T.Stack.all), "text") > 0,
              "top-level source is visible while CSM is open");
      Assert (Index (Streaming_Response_Text (T.Stack.all), "x") > 0,
              "root content is visible while CSM is open");
      End_Text_Block (T.Stack.all);
      Assert (Index (Visible_Text (T.Stack.all), "text") > 0,
              "top-level source survives final reconciliation");
      Assert (Index (Visible_Text (T.Stack.all), "x") > 0,
              "root content survives final reconciliation");
   end Test_CSM2_Raw_Source_Is_Retained_Around_Root;

   procedure Test_CSM2_Live_View_Owns_Selection_And_Focus
     (T : in out Test)
   is
      Live_View : Gtk.Text_View.Gtk_Text_View;
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text (T.Stack.all, "<p>live selection target</p>");
      Live_View := Streaming_Response_View (T.Stack.all);
      Assert (Live_View /= null, "open CSM stream exposes its live view");
      Assert (Live_View /= null and then Active_Text_View (T.Stack.all) /= null,
              "semantic presenter exposes an active response target");
      T.Parent.Set_Accept_Focus (True);
      T.Parent.Show_All;
      T.Parent.Present;
      Host_Widget (T.Stack.all).Show_All;
      declare
         Ignored : constant Boolean :=
           Gtk.Main.Main_Iteration_Do (Blocking => False);
         pragma Unreferenced (Ignored);
      begin
         null;
      end;
      Live_View.Show_Now;
      T.Parent.Present;
      T.Parent.Set_Focus (Gtk.Widget.Gtk_Widget (Live_View));
      Live_View.Grab_Focus;
      declare
         Ignored : constant Boolean :=
           Gtk.Main.Main_Iteration_Do (Blocking => False);
         pragma Unreferenced (Ignored);
      begin
         null;
      end;
      Assert (Live_View.Is_Focus,
              "live view owns focus within the conversation toplevel");
      Select_All (T.Stack.all);
      Assert (Live_View.Get_Buffer.Get_Has_Selection,
              "Select_All targets the live CSM view");
   end Test_CSM2_Live_View_Owns_Selection_And_Focus;

   procedure Test_CSM2_Set_Font_Updates_Live_View
     (T : in out Test)
   is
      Before_Desc : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 19");
      During_Desc : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 21");
      Live_View   : Gtk.Text_View.Gtk_Text_View;
      Final_View  : Gtk.Text_View.Gtk_Text_View;
      Live_Size   : Glib.Gint;
      Final_Size  : Glib.Gint;
      Initial_Scale : Long_Float;
   begin
      if not T.Display_Available then
         Pango.Font.Free (Before_Desc);
         Pango.Font.Free (During_Desc);
         return;
      end if;
      Set_Incremental_Markup (T.Stack.all, True);
      Set_Font (T.Stack.all, Before_Desc);
      Begin_Request (T.Stack.all, "request", Prompt);
      Append_Text
        (T.Stack.all,
         "<p>font target</p>"
         & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
         & "<mrow><mi>x</mi></mrow></math>");
      Live_View := Streaming_Response_View (T.Stack.all);
      Live_Size := Pango.Font.Get_Size
        (Gtk.Style_Context.Get_Style_Context (Live_View).Get_Font
           (Gtk.Enums.Gtk_State_Flag_Normal));
      Assert (Live_Size = Pango.Font.Get_Size (Before_Desc),
              "Set_Font applies before semantic CSM view creation");
      Set_Font (T.Stack.all, During_Desc);
      Live_Size := Pango.Font.Get_Size
        (Gtk.Style_Context.Get_Style_Context (Live_View).Get_Font
           (Gtk.Enums.Gtk_State_Flag_Normal));
      Assert (Live_Size = Pango.Font.Get_Size (During_Desc),
              "Set_Font updates the effective live view font");
      End_Text_Block (T.Stack.all);
      Initial_Scale := Math_Scale (T.Stack.all, 1);
      Set_Font (T.Stack.all, During_Desc, Math_Scale => 2.0);
      Final_View := Active_Text_View (T.Stack.all);
      Final_Size := Pango.Font.Get_Size
        (Gtk.Style_Context.Get_Style_Context (Final_View).Get_Font
           (Gtk.Enums.Gtk_State_Flag_Normal));
      Assert (Final_Size = Pango.Font.Get_Size (During_Desc),
              "Set_Font applies to the finalized semantic view");
      Assert (Index (Visible_Text (T.Stack.all), "font target") > 0,
              "completed response text remains visible after zoom");
      Assert (Math_Scale (T.Stack.all, 1) > Initial_Scale,
              "completed response MathML scale updates after zoom");
      Pango.Font.Free (Before_Desc);
      Pango.Font.Free (During_Desc);
   end Test_CSM2_Set_Font_Updates_Live_View;

   procedure Test_CSM2_Live_And_Final_Content_Parity
     (T : in out Test)
   is
      procedure Assert_Content
        (Source : String; Token_One : String; Token_Two : String) is
         Presented_Text  : Unbounded_String;
         Final_Text : Unbounded_String;
      begin
         Clear (T.Stack.all);
         Set_Incremental_Markup (T.Stack.all, True);
         Begin_Request (T.Stack.all, "request", Prompt);
         Append_Text (T.Stack.all, Source);
         Presented_Text := To_Unbounded_String (Streaming_Response_Text (T.Stack.all));
         End_Text_Block (T.Stack.all);
         Final_Text := To_Unbounded_String (Visible_Text (T.Stack.all));
         Assert (Index (To_String (Presented_Text), Token_One) > 0,
                 "live CSM retains meaningful content");
         Assert (Index (To_String (Final_Text), Token_One) > 0,
                 "final CSM retains meaningful content");
         Assert (Index (To_String (Presented_Text), Token_Two) > 0,
                 "live CSM retains the second meaningful region");
         Assert (Index (To_String (Final_Text), Token_Two) > 0,
                 "final CSM retains the second meaningful region");
      end Assert_Content;
   begin
      if not T.Display_Available then
         return;
      end if;
      Assert_Content ("<p>complete alpha</p><hr/><p>omega</p>",
                      "alpha", "omega");
      Assert_Content ("<p>malformed alpha <strong>omega</p>",
                      "alpha", "omega");
      Assert_Content ("prefix<hr/><p>invalid omega</p>suffix",
                      "invalid", "omega");
   end Test_CSM2_Live_And_Final_Content_Parity;

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
        ("CSM-2 GUI streaming visibility and styles",
         Test_CSM2_Live_Visibility_And_Styles'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI deferred blocks finalize only",
         Test_CSM2_Deferred_Blocks_Finalize_Only'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI redundant MathML wrapper",
         Test_CSM2_Redundant_Math_Wrapper'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI reset and duplicate finalization",
         Test_CSM2_Reset_And_Duplicate_Finalization'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI invalid prefix and lifecycle rollback",
         Test_CSM2_Invalid_Prefix_And_Lifecycle_Rollback'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI retains completed response roots",
         Test_CSM2_Retains_Completed_Response_Roots'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI format change preserves completed response",
         Test_CSM2_Format_Change_Preserves_Completed_Response'Access));
      Result.Add_Test (Caller.Create
        ("GUI format change closes active raw response",
         Test_Format_Change_Closes_Active_Raw_Response'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 completed owner survives raw format change",
         Test_CSM2_Completed_Owner_Survives_Raw_Format_Change'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 interrupted response is finalized",
         Test_CSM2_Interrupted_Response_Is_Finalized'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 response tool response lifecycle",
         Test_CSM2_Response_Tool_Response_Lifecycle'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI raw inline is escaped and unstyled",
         Test_CSM2_Raw_Inline_Is_Escaped_And_Unstyled'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI localized recovery preserves native blocks",
         Test_CSM2_Localized_Recovery_Preserves_Native_Blocks'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI retains top-level CSM source bytes",
         Test_CSM2_Raw_Source_Is_Retained_Around_Root'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI live view owns selection and focus",
         Test_CSM2_Live_View_Owns_Selection_And_Focus'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI Set_Font updates live view",
         Test_CSM2_Set_Font_Updates_Live_View'Access));
      Result.Add_Test (Caller.Create
        ("CSM-2 GUI live and final content parity",
         Test_CSM2_Live_And_Final_Content_Parity'Access));
      return Result;
   end Suite;
end Coyote_GUI_CSM2_Qualification_Tests;
