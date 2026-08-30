--  Coyote_GUI_Conversation_Stack_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Glib;
with Gtk.Button;
with Coyote_App.Utils;
with Coyote_GUI;
with Coyote_GUI.Conversation;
with Coyote_GUI.Conversation_Stack.Testing;
with Gtk.Enums;
with Gtk.Flow_Box;
with Gtk.Flow_Box_Child;
with Gtk.Frame;
with Gtk.Main;
with Gtk.Scrolled_Window;
with Gtk.Separator;
with Gtk.Text_View;

package body Coyote_GUI_Conversation_Stack_Tests is

   use type Glib.Gint;
   use type Glib.Guint;
   use type Gtk.Flow_Box.Gtk_Flow_Box;
   use type Gtk.Flow_Box_Child.Gtk_Flow_Box_Child;
   use type Gtk.Frame.Gtk_Frame;
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
      Info : Coyote_GUI.Conversation.Tool_Info;
   begin
      if not T.Display_Available then
         return;
      end if;
      Begin_Request (T.Stack, "request", Prompt);
      Begin_Tool
        (C                => T.Stack,
         Name             => "shell",
         Args             => "{""command"":""printf hello"",""timeout"":5}",
         Session_Id      => "session-1",
         Tool_Id         => "tool-summary",
         Model            => "provider/model",
         Source_Directory => "/tmp/project",
         Session_Start    => "2026-08-24 12:00:00",
         Turn_Index       => 3,
         Call_In_Turn     => 2);
      Assert (not Details_Enabled (T.Stack, "tool-summary"),
              "View Details is disabled while the tool is running");
      Assert (Details_Label (T.Stack, "tool-summary") = "View Details",
              "tool action uses an active verb");
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
      Assert (Index (Summary (1 .. Summary_Length), "command: printf hello") > 0,
              "summary contains compact argument fields");
      Assert (Index (Summary (1 .. Summary_Length), "timeout: 5") > 0,
              "summary contains each top-level argument field");
      Assert (Index (Summary (1 .. Summary_Length), "printf hello") > 0,
              "summary contains argument value");
      Assert (Index (Summary (1 .. Summary_Length), "full-result-sentinel") = 0,
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
              "Details is enabled after tool completion");
      Info := Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
        (T.Stack, "tool-summary");
      Assert (To_String (Info.Name) = "shell",
              "retained details preserve the tool name");
      Assert (To_String (Info.Args) =
                "{""command"":""printf hello"",""timeout"":5}",
              "retained details preserve raw arguments");
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

end Coyote_GUI_Conversation_Stack_Tests;
