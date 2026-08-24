--  Coyote_GUI_Conversation_Stack_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with AUnit.Assertions;
with Coyote_GUI;
with Coyote_GUI.Conversation_Stack.Testing;
with Gtk.Main;
with Gtk.Scrolled_Window;
with Gtk.Text_View;

package body Coyote_GUI_Conversation_Stack_Tests is

   use type Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   use type Gtk.Text_View.Gtk_Text_View;
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
         Create (T.Stack);
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
