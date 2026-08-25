--  Coyote_GUI_Conversation_Stack_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_GUI;
with Coyote_GUI.Conversation;
with Coyote_GUI.Conversation_Stack.Testing;
with Gtk.Enums;
with Gtk.Main;
with Gtk.Scrolled_Window;
with Gtk.Text_View;
with Gtk.Window;

package body Coyote_GUI_Conversation_Stack_Tests is

   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_View.Gtk_Text_View;
   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;
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
         Gtk.Window.Gtk_New (T.Parent, Gtk.Enums.Window_Toplevel);
         Create (T.Stack, T.Parent.all'Access);
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
   begin
      null;
   end Tear_Down;

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
      Assert (Transcript_Text (T.Stack) = "request" & ASCII.LF
              & "first second" & ASCII.LF & ASCII.LF,
              "streaming updates one native text component");
   end Test_Request_And_Streaming_Are_Incremental;

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

   procedure Test_Tool_Card_Uses_Summary_And_Details (T : in out Test) is
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
              "Details is disabled while the tool is running");
      declare
         Summary_Text : constant String :=
           Coyote_GUI.Conversation_Stack.Testing.Tool_Summary
             (T.Stack, "tool-summary");
      begin
         Summary_Length := Summary_Text'Length;
         Summary (1 .. Summary_Length) := Summary_Text;
      end;
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
   end Test_Tool_Card_Uses_Summary_And_Details;

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
      Assert (Transcript_Text (T.Stack) = "",
              "clear removes native transcript content");
   end Test_Clear_Removes_Exchange_State;

end Coyote_GUI_Conversation_Stack_Tests;
