with AUnit.Test_Caller;
--  Coyote_GUI_Conversation_Stack_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Glib;
with Gtk.Button;
with Gtk.Container;
with Gtk.Widget;
with Coyote_App.Utils;
with Coyote_GUI;
with Coyote_GUI.Conversation_Stack.Testing;
with Gtk.Enums;
with Gtk.Flow_Box;
with Gtk.Flow_Box_Child;
with Gtk.Frame;
with Gtk.Grid;
with Gtk.Label;
with Gtk.Main;
with Gtk.Scrolled_Window;
with Gtk.Separator;
with Gtk.Text_View;
with Pango.Font;

package body Coyote_GUI_Conversation_Stack_Tests is

   use type Glib.Gfloat;
   use type Glib.Gint;
   use type Glib.Guint;
   use type Gtk.Flow_Box.Gtk_Flow_Box;
   use type Gtk.Flow_Box_Child.Gtk_Flow_Box_Child;
   use type Gtk.Frame.Gtk_Frame;
   use type Gtk.Grid.Gtk_Grid;
   use type Gtk.Label.Gtk_Label;
   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_View.Gtk_Text_View;
   use type Gtk.Separator.Gtk_Separator;
   use type Gtk.Button.Gtk_Button;
   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;

   Fork_Called : Boolean := False;
   Fork_UUID   : Unbounded_String;
   Fork_Turn   : Positive := 1;
   Fork_Step   : Natural := 0;

   procedure Capture_Fork
     (UUID   : String;
      Turn_N : Positive;
      Step_N : Natural)
   is
   begin
      Fork_Called := True;
      Fork_UUID := To_Unbounded_String (UUID);
      Fork_Turn := Turn_N;
      Fork_Step := Step_N;
   end Capture_Fork;
   use AUnit.Assertions;
   use Coyote_GUI;
   use Coyote_GUI.Conversation_Stack;
   use Coyote_GUI.Conversation_Stack.Testing;

   function Display_Available return Boolean is
   begin
      return Ada.Environment_Variables.Exists ("DISPLAY")
        or else Ada.Environment_Variables.Exists ("WAYLAND_DISPLAY");
   exception
      when others =>
         return False;
   end Display_Available;

   overriding procedure Set_Up (T : in out Test) is
   begin
      if Display_Available then
         Gtk.Main.Init;
         T.Display_Available := True;
         if Widget (T.Stack) = null then
            Gtk.Window.Gtk_New (T.Parent, Gtk.Enums.Window_Toplevel);
            Create (T.Stack, T.Parent.all'Access);
         else
            Clear (T.Stack);
         end if;
         Set_Render_Markdown (T.Stack, True);
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      if T.Display_Available then
         Clear (T.Stack);
      end if;
   end Tear_Down;

   procedure Test_Native_Footer_Uses_Status_Row_And_Fork_Button
     (T : in out Test)
   is
      Summary : constant String :=
        "[ctx 24k/400k (6%) | ^537 out | stop]";
   begin
      if not T.Display_Available then
         return;
      end if;
      Fork_Called := False;
      Fork_UUID := Null_Unbounded_String;
      Fork_Turn := 1;
      Fork_Step := 0;
      Set_Fork_Handler (T.Stack, Capture_Fork'Access);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "response");
      End_Text_Block (T.Stack);
      Append_Turn_Footer
        (C       => T.Stack,
         Text    => "formatted footer" & ASCII.LF
                    & Coyote_App.Utils.UC_HORIZ,
         Kind    => Final_Footer,
         Summary => Summary);
      Append_Fork_Action
        (T.Stack, "legacy label", "session-42", 3, 2);

      Assert (Footer_Separator (T.Stack) /= null,
              "footer uses a native GTK separator widget");
      Assert (Footer_Heading (T.Stack) = "Turn summary",
              "final footer uses a semantic summary heading");
      Assert (Footer_Summary (T.Stack) = Summary,
              "footer summary is rendered as a native label");
      Assert (not Footer_Summary_Selectable (T.Stack),
              "footer status label is not a selectable text control");
      Assert (Index (Footer_Summary (T.Stack),
                     Coyote_App.Utils.UC_HORIZ) = 0,
              "footer summary does not contain a terminal separator");
      Assert (Fork_Button (T.Stack) /= null,
              "footer provides a native Fork button");
      Assert (Fork_Button (T.Stack).Get_Label = "Fork",
              "fork action uses a stable active-verb label");
      Assert (Fork_Button (T.Stack).Get_Can_Focus,
              "fork action is keyboard focusable");

      Fork_Button (T.Stack).Clicked;
      Assert (Fork_Called, "Fork button invokes the registered callback");
      Assert (To_String (Fork_UUID) = "session-42",
              "Fork callback receives the session UUID");
      Assert (Fork_Turn = 3 and then Fork_Step = 2,
              "Fork callback receives the turn and step");
   end Test_Native_Footer_Uses_Status_Row_And_Fork_Button;

   procedure Test_Creates_Single_Outer_Host (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Assert (Host_Widget (T.Stack) /= null,
              "stack creates one outer scrolled window");
   end Test_Creates_Single_Outer_Host;

   procedure Test_Request_And_Streaming_Are_Incremental
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "first");
      Append_Text (T.Stack, " second");
      End_Text_Block (T.Stack);
      Assert (Has_Exchange (T.Stack), "request creates an exchange");
      Assert (Active_Text_View (T.Stack) /= null
              and then Active_Text_View (T.Stack).Get_Visible,
              "dynamically-created native text is visible");
   end Test_Request_And_Streaming_Are_Incremental;

   procedure Test_Native_Markdown_Renders_After_Streaming
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "**bold** and `code`");
      End_Text_Block (T.Stack);
      declare
         Text : constant String := Active_Text (T.Stack);
      begin
         Assert (Index (Text, "bold and code") > 0,
                 "native Markdown renders visible text after streaming");
         Assert (Index (Text, "**") = 0,
                 "native Markdown removes strong delimiters");
         Assert (Index (Text, "`") = 0,
                 "native Markdown removes code delimiters");
      end;
   end Test_Native_Markdown_Renders_After_Streaming;

   procedure Test_Native_Markdown_Toggle_Disables_Rendering
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Render_Markdown (T.Stack, False);
      Assert (not Get_Render_Markdown (T.Stack),
              "native Markdown rendering can be disabled");
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "**bold**");
      End_Text_Block (T.Stack);
      declare
         Text : constant String := Active_Text (T.Stack);
      begin
         Assert (Index (Text, "**bold**") > 0,
                 "disabled native Markdown preserves source text");
      end;
   end Test_Native_Markdown_Toggle_Disables_Rendering;

   procedure Test_Native_Table_Realizes_Grid (T : in out Test) is
      Source : constant String :=
        "| Name | Count | Ratio |" & ASCII.LF
        & "| :--- | :---: | ---: |" & ASCII.LF
        & "| alpha | 42 | 0.5 |";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      End_Text_Block (T.Stack);
      Assert (Table_Count (T.Stack) = 1,
              "completed table should create one native grid");
      Assert (Table_Grid (T.Stack, 1) /= null,
              "native table grid should be retained");
      Assert (Table_Cell (T.Stack, 1, 1, 1) /= null,
              "native table header cell should exist");
      Assert (Table_Cell (T.Stack, 1, 2, 3) /= null,
              "native table body cell should exist");
      Assert (Table_Cell (T.Stack, 1, 2, 3).Get_Text = "0.5",
              "native table cell should retain copied text");
      Assert (Table_Cell (T.Stack, 1, 1, 1).Get_Use_Markup,
              "native table header should use Pango markup");
      Assert (Table_Cell (T.Stack, 1, 1, 1).Get_Text = "Name",
              "native table header should retain visible text");
      Assert (Table_Cell (T.Stack, 1, 2, 1).Get_Xalign = 0.0,
              "left-aligned table column should use left alignment");
      Assert (Table_Cell (T.Stack, 1, 2, 2).Get_Xalign = 0.5,
              "center-aligned table column should use center alignment");
      Assert (Table_Cell (T.Stack, 1, 2, 3).Get_Xalign = 1.0,
              "right-aligned table column should use right alignment");
      Assert (not Response_Stream_Present (T.Stack),
              "native table replacement removes the raw stream view");
   end Test_Native_Table_Realizes_Grid;

   procedure Test_Native_Table_Toggle_Disables_Rendering (T : in out Test) is
      Source : constant String :=
        "| Name | Value |" & ASCII.LF
        & "| --- | --- |" & ASCII.LF
        & "| alpha | 42 |";
   begin
      if not T.Display_Available then
         return;
      end if;
      Set_Render_Markdown (T.Stack, False);
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      End_Text_Block (T.Stack);
      Assert (Table_Count (T.Stack) = 0,
              "disabled Markdown should not create a native table");
      Assert (Index (Active_Text (T.Stack), "| Name | Value |") > 0,
              "disabled Markdown should preserve table source");
   end Test_Native_Table_Toggle_Disables_Rendering;

   procedure Test_Native_Response_Table_Skips_Whitespace_Blocks
     (T : in out Test)
   is
      Source : constant String :=
        "| Name | Value |" & ASCII.LF
        & "| --- | --- |" & ASCII.LF
        & "| alpha | 42 |";
      Children : Gtk.Widget.Widget_List.Glist;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      End_Text_Block (T.Stack);
      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Response_Box (T.Stack)));
      Assert (Gtk.Widget.Widget_List.Length (Children) = 1,
              "table-only response should not create whitespace text blocks");
   end Test_Native_Response_Table_Skips_Whitespace_Blocks;

   procedure Test_Native_Response_Mixed_Blocks_Skip_Whitespace
     (T : in out Test)
   is
      Source : constant String :=
        "before" & ASCII.LF & ASCII.LF
        & "| Name | Value |" & ASCII.LF
        & "| --- | --- |" & ASCII.LF
        & "| alpha | 42 |" & ASCII.LF & ASCII.LF
        & "after";
      Children : Gtk.Widget.Widget_List.Glist;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      End_Text_Block (T.Stack);
      Children := Gtk.Container.Get_Children
        (Gtk.Container.Gtk_Container (Response_Box (T.Stack)));
      Assert (Gtk.Widget.Widget_List.Length (Children) = 3,
              "mixed response should contain only text-table-text blocks");
   end Test_Native_Response_Mixed_Blocks_Skip_Whitespace;

   procedure Test_Assistant_Content_Uses_Visible_Step_Frame
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Begin_Thinking (T.Stack);
      Append_Thinking (T.Stack, "thinking");
      End_Thinking (T.Stack);
      Append_Text (T.Stack, "response");
      End_Text_Block (T.Stack);
      Assert (Step_Frame_Count (T.Stack) = 1,
              "assistant content creates one step frame");
      Assert (Active_Step_Frame (T.Stack) /= null
              and then Active_Step_Frame (T.Stack).Get_Visible,
              "step frame is visible while streaming");
   end Test_Assistant_Content_Uses_Visible_Step_Frame;

   procedure Test_Footer_Closes_Step_Before_Next_Step
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "first response");
      End_Text_Block (T.Stack);
      Append_Turn_Footer (T.Stack, "step", Step_Footer);
      Assert (Footer_Heading (T.Stack) = "Step 1 summary",
              "step footer uses a numbered semantic summary heading");
      Append_Fork_Action
        (T.Stack, "fork step", "session", 1, 1);
      Assert (Step_Frame_Count (T.Stack) = 1,
              "step footer and fork remain in the first frame");
      Assert (Active_Step_Frame (T.Stack) = null,
              "completed step is no longer the active target");
      Append_Text (T.Stack, "final response");
      End_Text_Block (T.Stack);
      Assert (Step_Frame_Count (T.Stack) = 2,
              "next assistant response creates a second step frame");
      Append_Turn_Footer (T.Stack, "final", Final_Footer);
      Append_Fork_Action
        (T.Stack, "fork turn", "session", 1, 0);
      Complete_Request (T.Stack, Completed);
      Assert (Is_Completed (T.Stack),
              "final completion closes the exchange after its step");
   end Test_Footer_Closes_Step_Before_Next_Step;

   procedure Test_New_Request_Resets_Step_Frames
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "first request", Prompt);
      Append_Text (T.Stack, "first response");
      End_Text_Block (T.Stack);
      Assert (Step_Frame_Count (T.Stack) = 1,
              "first request creates one step frame");

      Begin_Request (T.Stack, "second request", Prompt);
      Assert (Step_Frame_Count (T.Stack) = 0,
              "new request clears prior step-frame bookkeeping");
      Append_Text (T.Stack, "second response");
      End_Text_Block (T.Stack);
      Assert (Step_Frame_Count (T.Stack) = 1,
              "second request creates a fresh step frame");
   end Test_New_Request_Resets_Step_Frames;

   procedure Test_Tool_Updates_By_Stable_Id (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Begin_Tool
        (C         => T.Stack,
         Name      => "shell",
         Args      => "{""command"":""true""}",
         Session_Id => "session",
         Tool_Id   => "tool-1");
      Begin_Tool
        (C         => T.Stack,
         Name      => "shell",
         Args      => "{}",
         Session_Id => "session",
         Tool_Id   => "tool-2");
      End_Tool (T.Stack, "tool-1", Success, "one");
      Assert (Tool_Count (T.Stack) = 2,
              "tool starts are retained by stable tool ID");
      End_Tool (T.Stack, "tool-2", Error, "two");
      Assert (Tool_Count (T.Stack) = 2,
              "tool completion updates existing card by ID");
   end Test_Tool_Updates_By_Stable_Id;

   procedure Test_Tool_Cards_Use_Responsive_Flow (T : in out Test) is
      Flow : Gtk.Flow_Box.Gtk_Flow_Box;
      First_Child : Gtk.Flow_Box_Child.Gtk_Flow_Box_Child;
      Second_Child : Gtk.Flow_Box_Child.Gtk_Flow_Box_Child;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Begin_Tool
        (C          => T.Stack,
         Name       => "shell",
         Args       => "{""command"":""one""}",
         Session_Id => "session",
         Tool_Id    => "tool-flow-1");
      Begin_Tool
        (C          => T.Stack,
         Name       => "shell",
         Args       => "{""command"":""two""}",
         Session_Id => "session",
         Tool_Id    => "tool-flow-2");

      Flow := Tool_Flow (T.Stack);
      Assert (Flow /= null, "tool cards create a native flow host");
      Assert (not Flow.Get_Homogeneous,
              "tool flow preserves natural card widths");
      Assert (Flow.Get_Row_Spacing = 4,
              "tool flow uses four pixels between rows");
      Assert (Flow.Get_Column_Spacing = 4,
              "tool flow uses four pixels between columns");
      Assert (Flow.Get_Child_At_Index (0) /= null
              and then Flow.Get_Child_At_Index (1) /= null,
              "two tool cards are inserted into the same flow host");
      First_Child := Flow.Get_Child_At_Index (0);
      Second_Child := Flow.Get_Child_At_Index (1);
      Assert (First_Child.Get_Index = 0 and then Second_Child.Get_Index = 1,
              "tool cards retain insertion order in the flow host");
   end Test_Tool_Cards_Use_Responsive_Flow;

   procedure Test_Tool_Card_Uses_Native_Labels (T : in out Test) is
      Summary : String (1 .. 4096);
      Summary_Length : Natural;
      Info : Coyote_GUI.Tool_Info;
      Tool_Args : constant String :=
        "{""command"":""printf hello"",""timeout"":5," &
        """run_group"":0,""stdin"":"""",""media_type"":null}";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Begin_Tool
        (C                => T.Stack,
         Name             => "shell",
         Args             => Tool_Args,
         Session_Id      => "session-1",
         Tool_Id         => "tool-summary",
         Model            => "provider/model",
         Source_Directory => "/tmp/project",
         Session_Start    => "2026-08-24 12:00:00",
         Turn_Index       => 3,
         Call_In_Turn     => 2);
      Assert (Details_Enabled (T.Stack, "tool-summary"),
              "View Details is enabled while the tool is running");
      Assert (Details_Label (T.Stack, "tool-summary") = "View Details",
              "tool action uses an active verb");
      Info := Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
        (T.Stack, "tool-summary");
      Assert (not Info.Completed,
              "active retained details are marked incomplete");
      Assert (To_String (Info.Tool_Id) = "tool-summary",
              "active retained details preserve the tool ID");
      Assert (To_String (Info.Session_Id) = "session-1",
              "active retained details preserve the session ID");
      declare
         Summary_Text : constant String :=
           Coyote_GUI.Conversation_Stack.Testing.Tool_Summary
             (T.Stack, "tool-summary");
      begin
         Summary_Length := Summary_Text'Length;
         Summary (1 .. Summary_Length) := Summary_Text;
      end;
      Assert (Index (Summary (1 .. Summary_Length), "Status: Running") > 0,
              "summary exposes running status text");
      Assert (Index (Summary (1 .. Summary_Length), "shell") > 0,
              "summary contains the tool name");
      Assert
        (Index (Summary (1 .. Summary_Length), "command: printf hello") > 0,
         "summary contains compact argument fields");
      Assert
        (Index (Summary (1 .. Summary_Length), "timeout: 5") > 0,
         "summary contains each visible top-level argument field");
      Assert (Index (Summary (1 .. Summary_Length), "run_group: 0") = 0,
              "summary hides the default run group");
      Assert (Index (Summary (1 .. Summary_Length), "stdin:") = 0,
              "summary hides empty stdin");
      Assert (Index (Summary (1 .. Summary_Length), "media_type:") = 0,
              "summary hides null media type");
      Assert (Index (Summary (1 .. Summary_Length), "printf hello") > 0,
              "summary contains argument value");
      Assert
        (Index (Summary (1 .. Summary_Length), "full-result-sentinel") = 0,
         "summary does not contain the full result");
      Assert (Index (Summary (1 .. Summary_Length), "{""command""") = 0,
              "summary does not contain raw argument JSON");
      Assert
        (Index (Summary (1 .. Summary_Length), Coyote_App.Utils.UC_BOX_TL) = 0,
         "summary does not use top box-drawing decoration");
      Assert
        (Index (Summary (1 .. Summary_Length), Coyote_App.Utils.UC_BOX_BL) = 0,
         "summary does not use bottom box-drawing decoration");

      End_Tool
        (C          => T.Stack,
         Tool_Id    => "tool-summary",
         Status     => Success,
         Result     => "full-result-sentinel",
         Media_Type => "image/png");
      Assert (Details_Enabled (T.Stack, "tool-summary"),
              "Details remains enabled after tool completion");
      Info := Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
        (T.Stack, "tool-summary");
      Assert (Info.Completed,
              "completed retained details are marked complete");
      Assert (To_String (Info.Tool_Id) = "tool-summary",
              "completed retained details preserve the tool ID");
      Assert (To_String (Info.Session_Id) = "session-1",
              "completed retained details preserve the session ID");
      Assert (To_String (Info.Name) = "shell",
              "retained details preserve the tool name");
      Assert
        (To_String (Info.Args) = Tool_Args,
         "retained details preserve raw arguments including hidden fields");
      Assert (To_String (Info.Result_Text) = "full-result-sentinel",
              "retained details preserve the full result");
      Assert (To_String (Info.Media_Type) = "image/png",
              "retained details preserve result media type");
      Assert (To_String (Info.Model) = "provider/model",
              "retained details preserve model metadata");
      Assert (To_String (Info.Source_Directory) = "/tmp/project",
              "retained details preserve source metadata");
      Assert (To_String (Info.Session_Start) = "2026-08-24 12:00:00",
              "retained details preserve session metadata");
      Assert (Info.Turn_Index = 3 and then Info.Call_In_Turn = 2,
              "retained details preserve call position");
   end Test_Tool_Card_Uses_Native_Labels;

   procedure Test_Footer_Kind_And_Completion_Are_Explicit
     (T : in out Test)
   is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Turn_Footer (T.Stack, "step", Step_Footer);
      Assert (not Is_Completed (T.Stack),
              "step footer does not complete exchange");
      Append_Turn_Footer (T.Stack, "final", Final_Footer);
      Complete_Request (T.Stack, Failed);
      Assert (Is_Completed (T.Stack),
              "explicit completion closes exchange");
      Assert (Last_Status (T.Stack) = Failed,
              "completion status is retained structurally");
   end Test_Footer_Kind_And_Completion_Are_Explicit;

   procedure Test_Clear_Removes_Exchange_State (T : in out Test) is
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, "content");
      Complete_Request (T.Stack, Aborted);
      Clear (T.Stack);
      Assert (not Has_Exchange (T.Stack),
              "clear removes exchange state");
      Assert (not Is_Completed (T.Stack),
              "clear removes terminal state");
   end Test_Clear_Removes_Exchange_State;

   procedure Test_Native_Display_Math_Realizes_Element
     (T : in out Test)
   is
      Source : constant String :=
        "before" & ASCII.LF
        & "$$" & ASCII.LF
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mfrac><mn>1</mn><mn>2</mn></mfrac></math>"
        & ASCII.LF & "$$" & ASCII.LF
        & "after";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      End_Text_Block (T.Stack);
      Assert (Math_Element_Count (T.Stack) = 1,
              "valid display math creates one native element");
      Assert (Math_Is_Valid (T.Stack, 1),
              "valid display math is measured successfully");
      Assert (Math_Width (T.Stack, 1) > 0
              and then Math_Height (T.Stack, 1) > 0,
              "native math element has non-zero dimensions");
      Assert (Index (Math_Source (T.Stack, 1), "$$") > 0,
              "native math element retains delimiter-wrapped source");
      Assert (not Response_Stream_Present (T.Stack),
              "native MathML replacement removes the raw stream view");
      Assert (Active_Text_View (T.Stack) /= null,
              "rendered response text remains the active text component");
      Assert (Response_Text_Has_Style (T.Stack),
              "rendered response text uses the response style");
      Assert (Math_Area_Visible (T.Stack, 1),
              "valid MathML shows the rendered area");
      Assert (not Math_Fallback_Visible (T.Stack, 1),
              "valid MathML hides the source fallback");
      Assert (Math_Has_Response_Style (T.Stack, 1),
              "rendered MathML uses the response style");
      Host_Widget (T.Stack).Show_All;
      Assert (not Math_Fallback_Visible (T.Stack, 1),
              "parent Show_All does not reveal valid MathML source");
   end Test_Native_Display_Math_Realizes_Element;

   procedure Test_Native_Display_Math_Invalid_Falls_Back
     (T : in out Test)
   is
      Source : constant String :=
        "$$" & ASCII.LF
        & "<" & ASCII.LF & "$$";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      End_Text_Block (T.Stack);
      Assert (Math_Element_Count (T.Stack) = 1,
              "invalid display math retains a native fallback element");
      Assert (not Math_Is_Valid (T.Stack, 1),
              "invalid display math is marked invalid");
      Assert (Index (Math_Source (T.Stack, 1), "<") > 0,
              "invalid display math retains readable source");
      Assert (not Math_Area_Visible (T.Stack, 1),
              "invalid MathML hides the rendered area");
      Assert (Math_Fallback_Visible (T.Stack, 1),
              "invalid MathML shows the source fallback");
   end Test_Native_Display_Math_Invalid_Falls_Back;

   procedure Test_Native_Display_Math_Protects_Code
     (T : in out Test)
   is
      Source : constant String :=
        "```" & ASCII.LF
        & "$$" & ASCII.LF
        & "<math><mi>x</mi></math>" & ASCII.LF
        & "$$" & ASCII.LF & "```";
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      End_Text_Block (T.Stack);
      Assert (Math_Element_Count (T.Stack) = 0,
              "display math inside fenced code is not realized");
      Assert (Index (Active_Text (T.Stack), "$$") > 0,
              "fenced code retains dollar delimiters");
   end Test_Native_Display_Math_Protects_Code;

   procedure Test_Native_Display_Math_Zooms (T : in out Test) is
      Source : constant String :=
        "$$" & ASCII.LF
        & "<math xmlns=""http://www.w3.org/1998/Math/MathML"">"
        & "<mi>x</mi></math>" & ASCII.LF & "$$";
      Small_Font : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 8");
      Large_Font : Pango.Font.Pango_Font_Description :=
        Pango.Font.From_String ("sans 18");
      Initial_Scale : Long_Float;
   begin
      if not T.Display_Available then
         Pango.Font.Free (Small_Font);
         Pango.Font.Free (Large_Font);
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Append_Text (T.Stack, Source);
      End_Text_Block (T.Stack);
      Initial_Scale := Math_Scale (T.Stack, 1);
      Set_Font (T.Stack, Small_Font, Math_Scale => 1.0);
      Set_Font (T.Stack, Large_Font, Math_Scale => 2.0);
      Assert (Math_Scale (T.Stack, 1) > Initial_Scale,
              "native MathML scale changes during zoom");
      Assert (Math_Height (T.Stack, 1) > 0,
              "native MathML remains measured after zoom");
      Pango.Font.Free (Small_Font);
      Pango.Font.Free (Large_Font);
   end Test_Native_Display_Math_Zooms;

   package Coyote_GUI_Conversation_Stack_Caller is
     new AUnit.Test_Caller (Coyote_GUI_Conversation_Stack_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack creates single outer host",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Creates_Single_Outer_Host'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack streams incrementally",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Request_And_Streaming_Are_Incremental'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack renders Markdown",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Markdown_Renders_After_Streaming'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack toggles Markdown rendering",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Markdown_Toggle_Disables_Rendering'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack realizes native tables",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Table_Realizes_Grid'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack toggles native tables",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Table_Toggle_Disables_Rendering'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack skips table whitespace blocks",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Response_Table_Skips_Whitespace_Blocks'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack skips mixed whitespace blocks",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Response_Mixed_Blocks_Skip_Whitespace'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack realizes display MathML",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Display_Math_Realizes_Element'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack falls back for invalid MathML",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Display_Math_Invalid_Falls_Back'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack protects code MathML",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Display_Math_Protects_Code'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack zooms display MathML",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Display_Math_Zooms'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack uses visible step frames",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Assistant_Content_Uses_Visible_Step_Frame'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack separates assistant steps",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Footer_Closes_Step_Before_Next_Step'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack resets step frames for new requests",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_New_Request_Resets_Step_Frames'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack updates tools by stable ID",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Tool_Updates_By_Stable_Id'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack uses responsive tool flow",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Tool_Cards_Use_Responsive_Flow'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack uses native labels and View Details action",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Tool_Card_Uses_Native_Labels'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack keeps footer kind explicit",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Footer_Kind_And_Completion_Are_Explicit'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack uses native footer status row",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Native_Footer_Uses_Status_Row_And_Fork_Button'Access));
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Caller.Create
        ("Coyote.GUI.Conversation_Stack clears exchange state",
         Coyote_GUI_Conversation_Stack_Tests
           .Test_Clear_Removes_Exchange_State'Access));

      return Result;
   end Suite;

end Coyote_GUI_Conversation_Stack_Tests;
