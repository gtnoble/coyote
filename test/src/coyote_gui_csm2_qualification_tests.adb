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
      return Result;
   end Suite;

end Coyote_GUI_CSM2_Qualification_Tests;
