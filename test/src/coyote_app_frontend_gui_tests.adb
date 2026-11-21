with AUnit.Test_Caller;
--  Coyote_App_Frontend_GUI_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;
with Coyote_App.Frontend.GUI.Testing;
with Coyote_GUI;
with Coyote_GUI.Prompt_Queue;
with Coyote_GUI.Canvas_Import_Jobs;
with Coyote_Temp_Files;
with Glib.Error;
with Gtk.File_Chooser_Dialog;
with Coyote_Process_Control;
with GNAT.OS_Lib;
with GNAT.Strings;
with Glib;
with Glib.Values;
with Glib.Object;
with Cairo;
with Cairo.Image_Surface;
with Gdk.Event;
with Gdk.Pixbuf;
with Gdk.Property;
with Gtk.Box;
with Gtk.Clipboard;
with Gtk.GEntry;
with Gtk.Tree_Selection;
with System;
with Gtk.Container;
with Gtk.Dialog;
with Gtk.Enums;
with Gtk.Image;
with Gtk.Icon_Theme;
with Gtk.Main;
with Gtk.Menu_Item;
with Gtk.Progress_Bar;
with Gtk.Separator;
with Gtk.Tree_Model;
with Gtk.Tree_View;
with Gtk.Widget;
with Gtk.Window;

package body Coyote_App_Frontend_GUI_Tests is

   use AUnit.Assertions;
   use type Glib.Gint;
   use type Glib.Guint;
   use type Glib.Gdouble;
   use type Glib.Object.GObject;
   use type Gtk.Enums.Gtk_Orientation;
   use type Gtk.Box.Gtk_Box;
   use type Gtk.Dialog.Gtk_Dialog;
   use type Gtk.Image.Gtk_Image;
   use type Gtk.Image.Gtk_Image_Type;
   use type Gtk.Icon_Theme.Gtk_Icon_Info;
   use type Gtk.Menu_Item.Gtk_Menu_Item;
   use type Gtk.Progress_Bar.Gtk_Progress_Bar;
   use type GNAT.Strings.String_Access;
   use type Gtk.Separator.Gtk_Separator;
   use type Gtk.Tree_View.Gtk_Tree_View;
   use type Gtk.Tree_Model.Gtk_Tree_Model;
   use type Gtk.Window.Gtk_Window;
   use type Gtk.Widget.Gtk_Widget;
   use type Coyote_GUI.Prompt_Queue.Item_Kind;
   use type Coyote_GUI.Tool_Status;

   procedure Drain_Events is
      Quit : Boolean;
      pragma Unreferenced (Quit);
   begin
      while Gtk.Main.Events_Pending loop
         Quit := Gtk.Main.Main_Iteration;
      end loop;
   end Drain_Events;

   function Display_Available return Boolean is
   begin
      return
        Ada.Environment_Variables.Exists ("DISPLAY")
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
      end if;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Test) is
      pragma Unreferenced (T);
   begin
      null;
   end Tear_Down;

   procedure Test_Layout_And_Shutdown_Lifecycle (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
      Frontend             : Coyote_App.Frontend.GUI.Instance;
      Outer                : Gtk.Box.Gtk_Box;
      Prompt               : Gtk.Box.Gtk_Box;
      Status               : Gtk.Box.Gtk_Box;
      Status_Content       : Gtk.Box.Gtk_Box;
      Progress             : Gtk.Progress_Bar.Gtk_Progress_Bar;
      Conv_Prompt          : Gtk.Separator.Gtk_Separator;
      Prompt_Status        : Gtk.Separator.Gtk_Separator;
      Agents_Window_Widget : Gtk.Window.Gtk_Window;
      Agents_Tree          : Gtk.Tree_View.Gtk_Tree_View;
      Agents_Model         : Gtk.Tree_Model.Gtk_Tree_Model;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote layout test", Pop_Under => True);
      Outer                := Outer_Box (Frontend);
      Prompt               := Prompt_Box (Frontend);
      Status               := Status_Box (Frontend);
      Status_Content       := Status_Content_Box (Frontend);
      Progress             := Context_Progress (Frontend);
      Conv_Prompt          := Conversation_Prompt_Separator (Frontend);
      Prompt_Status        := Prompt_Status_Separator (Frontend);
      Agents_Window_Widget := Agents_Window (Frontend);
      Agents_Tree          := Agents_View (Frontend);
      if Agents_Tree /= null then
         Agents_Model := Gtk.Tree_View.Get_Model (Agents_Tree);
      end if;

      Assert (Outer /= null, "GUI creates an outer layout box");
      Assert
        (Agents_Window_Widget /= null,
         "GUI creates the agents support window");
      Assert
        (Agents_Window_Widget.Get_Title = "coyote : Agents",
         "agents support window uses the IRIX function title");
      Assert
        (Agents_Window_Widget.Get_Transient_For = null,
         "agents window remains an independent top-level client");
      Assert
        (Gtk.Widget.Get_Visible (Gtk.Widget.Gtk_Widget (Agents_Window_Widget)),
         "agents support window is visible by default");
      Assert (Agents_Tree /= null, "GUI creates the agents tree view");
      Assert
        (Agents_Model /= Gtk.Tree_Model.Null_Gtk_Tree_Model
         and then Gtk.Tree_Model.N_Children (Agents_Model) = 1,
         "agents tree starts with one main-agent root row");
      Agents_Window_Widget.Hide;
      Assert
        (not Gtk.Widget.Get_Visible
           (Gtk.Widget.Gtk_Widget (Agents_Window_Widget)),
         "closing the agents support window hides it");
      Agents_Window_Widget.Show_All;
      Assert
        (Gtk.Widget.Get_Visible (Gtk.Widget.Gtk_Widget (Agents_Window_Widget)),
         "agents support window can be reopened");

      Assert
        (Conv_Prompt /= null, "GUI creates a conversation/prompt separator");
      Assert (Prompt_Status /= null, "GUI creates a prompt/status separator");
      Assert
        (Prompt /= null
         and then
           Gtk.Container.Get_Border_Width
             (Gtk.Container.Gtk_Container (Prompt))
           = 4,
         "prompt area has a four-pixel breathing-room border");
      Assert
        (Status /= null
         and then
           Gtk.Container.Get_Border_Width
             (Gtk.Container.Gtk_Container (Status))
           = 4,
         "status area has a four-pixel breathing-room border");
      Assert (Status_Content /= null, "status area creates an inner box");
      Assert (Progress /= null, "status area creates a context progress bar");
      Assert
        (Status.Get_Child (0) = Gtk.Widget.Gtk_Widget (Status_Content),
         "status area contains the inner status box");
      Assert
        (Status_Content.Get_Orientation = Gtk.Enums.Orientation_Horizontal,
         "inner status box is horizontal");
      Assert
        (Status_Content.Get_Child (1) = Gtk.Widget.Gtk_Widget (Progress),
         "inner status box contains the progress bar");
      Assert
        (Progress.Get_Fraction = 0.0,
         "context progress starts empty");

      Assert
        (Outer.Get_Child (3) = Gtk.Widget.Gtk_Widget (Conv_Prompt),
         "conversation is followed by the prompt separator");
      Assert
        (Outer.Get_Child (4) = Gtk.Widget.Gtk_Widget (Prompt),
         "prompt area follows the conversation separator");
      Assert
        (Outer.Get_Child (5) = Gtk.Widget.Gtk_Widget (Prompt_Status),
         "prompt area is followed by the status separator");
      Assert
        (Outer.Get_Child (6) = Gtk.Widget.Gtk_Widget (Status),
         "status area follows the prompt separator");

      declare
         task Reader is
            entry Complete;
         end Reader;

         Item : Coyote_GUI.Prompt_Queue.Item;

         task body Reader is
         begin
            Item := Frontend.Read_Item;
            accept Complete;
         end Reader;
      begin
         Frontend.Request_Shutdown;
         Reader.Complete;
         Assert
           (Item.Kind = Coyote_GUI.Prompt_Queue.Shutdown_Item,
            "application shutdown should release a blocked prompt reader");
      end;

      Assert
        (Coyote_Process_Control.Monitor_Should_Stop,
         "application shutdown should stop the process-control monitor");
      if Main_Window (Frontend) /= null then
         Main_Window (Frontend).Destroy;
      end if;
   end Test_Layout_And_Shutdown_Lifecycle;

   procedure Test_Agent_Tree_Expands_New_Subagents (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
      Frontend   : Coyote_App.Frontend.GUI.Instance;
      Model      : Gtk.Tree_Model.Gtk_Tree_Model;
      Root       : Gtk.Tree_Model.Gtk_Tree_Iter;
      Child      : Gtk.Tree_Model.Gtk_Tree_Iter;
      Root_Path  : Gtk.Tree_Model.Gtk_Tree_Path;
      Child_Path : Gtk.Tree_Model.Gtk_Tree_Path;
      Value      : Glib.Values.GValue;
   begin
      if not T.Display_Available then
         return;
      end if;

      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote agent tree expansion test", Pop_Under => True);
      Apply_Handshake (Frontend, "worker", "root", "worker");

      Model     := Gtk.Tree_View.Get_Model (Agents_View (Frontend));
      Root      := Gtk.Tree_Model.Get_Iter_From_String (Model, "0");
      Root_Path := Gtk.Tree_Model.Get_Path (Model, Root);
      Assert
        (Gtk.Tree_Model.N_Children (Model, Root) = 1,
         "new subagent should be inserted under the root row");
      Gtk.Tree_Model.Get_Value (Model, Root, 0, Value);
      Assert
        (Glib.Values.Get_String (Value) = "main",
         "root row label should remain main");
      Glib.Values.Unset (Value);
      Assert
        (Gtk.Tree_View.Row_Expanded (Agents_View (Frontend), Root_Path),
         "adding a subagent should expand the root row");
      Gtk.Tree_Model.Path_Free (Root_Path);

      Apply_Handshake (Frontend, "worker-child", "worker", "worker child");
      Child      := Gtk.Tree_Model.Get_Iter_From_String (Model, "0:0");
      Child_Path := Gtk.Tree_Model.Get_Path (Model, Child);
      Assert
        (Gtk.Tree_Model.N_Children (Model, Child) = 1,
         "nested subagent should be inserted under its parent row");
      Gtk.Tree_Model.Get_Value (Model, Child, 0, Value);
      Assert
        (Glib.Values.Get_String (Value) = "worker",
         "parent row label should identify the worker");
      Glib.Values.Unset (Value);
      Assert
        (Gtk.Tree_View.Row_Expanded (Agents_View (Frontend), Child_Path),
         "adding a nested subagent should expand its parent row");
      Gtk.Tree_Model.Path_Free (Child_Path);

      Frontend.Request_Shutdown;
      if Main_Window (Frontend) /= null then
         Main_Window (Frontend).Destroy;
      end if;
   end Test_Agent_Tree_Expands_New_Subagents;

   procedure Test_RPC_Tool_Lifecycle_Status (T : in out Test) is
      use Coyote_App.Agent_RPC;
      use Coyote_App.Frontend.GUI.Testing;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Info     : Coyote_GUI.Tool_Info;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote RPC tool lifecycle test", Pop_Under => True);
      Apply_Event
        (Frontend, "root", 1, Coyote_App.Agent_RPC.Request_Start,
         "{""text"":""request"",""kind"":""prompt""}");
      Apply_Event
        (Frontend, "root", 2, Coyote_App.Agent_RPC.Tool_Start,
         "{""name"":""shell"",""args"":{""command"":""sleep 2""},"
         & """sessionId"":""session"",""toolId"":""rpc-tool"","
         & """turn"":1,""call"":1,""status"":""queued""}");
      Assert
        (Tool_Status_Label (Frontend, "rpc-tool") = "Status: Queued",
         "RPC tool start preserves queued status");
      Apply_Event
        (Frontend, "root", 3, Coyote_App.Agent_RPC.Tool_Status,
         "{""toolId"":""rpc-tool"",""status"":""running""}");
      Assert
        (Tool_Status_Label (Frontend, "rpc-tool") = "Status: Running",
         "RPC tool status transitions to running");
      Apply_Event
        (Frontend, "root", 4, Coyote_App.Agent_RPC.Tool_End,
         "{""toolId"":""rpc-tool"",""result"":""timeout"","
         & """status"":""timed_out""}");
      Info := Tool_Detail (Frontend, "rpc-tool");
      Assert
        (Info.Result_Status = Coyote_GUI.Timed_Out and then Info.Completed,
         "RPC timed-out tool reaches a terminal state");
      Assert
        (Tool_Status_Label (Frontend, "rpc-tool")
         = "Status: Timed out - timeout",
         "RPC timed-out status is visible");
      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
   end Test_RPC_Tool_Lifecycle_Status;

   procedure Test_RPC_Tool_Stopwatch_Replay (T : in out Test) is
      use Coyote_App.Agent_RPC;
      use Coyote_App.Frontend.GUI.Testing;
      use Ada.Real_Time;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      T0       : constant Time := Clock - Seconds (100);
   begin
      if not T.Display_Available then
         return;
      end if;

      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote tool stopwatch replay test", Pop_Under => True);
      Apply_Handshake (Frontend, "worker", "root", "worker");
      Apply_Event
        (Frontend, "worker", 1, Request_Start,
         "{""text"":""tool request"",""kind"":""prompt""}", T0);
      Apply_Event
        (Frontend, "worker", 2, Tool_Start,
         "{""name"":""shell"",""args"":{},""toolId"":""watch"","
         & """turn"":1,""call"":1,""status"":""queued""}", T0);
      Apply_Event
        (Frontend, "worker", 3, Tool_Status,
         "{""toolId"":""watch"",""status"":""running""}",
         T0 + Seconds (10));
      Select_Agent (Frontend, "worker");
      Refresh_Tool_Times (Frontend, T0 + Seconds (15));
      Assert
        (Tool_Elapsed_Label (Frontend, "watch") = "Elapsed: 00:05",
         "running tool elapsed time starts at the running event timestamp");

      Select_Agent (Frontend, "root");
      Refresh_Tool_Times (Frontend, T0 + Seconds (15));
      Select_Agent (Frontend, "worker");
      Refresh_Tool_Times (Frontend, T0 + Seconds (15));
      Assert
        (Tool_Elapsed_Label (Frontend, "watch") = "Elapsed: 00:05",
         "replaying a running tool preserves its original start timestamp");

      Apply_Event
        (Frontend, "worker", 4, Tool_End,
         "{""toolId"":""watch"",""result"":""ok"","
         & """status"":""success""}", T0 + Seconds (30));
      Refresh_Tool_Times (Frontend, T0 + Seconds (40));
      Assert
        (Tool_Elapsed_Label (Frontend, "watch") = "Elapsed: 00:20",
         "tool end freezes elapsed time at its event timestamp");
      Select_Agent (Frontend, "root");
      Refresh_Tool_Times (Frontend, T0 + Seconds (50));
      Select_Agent (Frontend, "worker");
      Refresh_Tool_Times (Frontend, T0 + Seconds (50));
      Assert
        (Tool_Elapsed_Label (Frontend, "watch") = "Elapsed: 00:20",
         "replay of a completed tool retains its frozen duration");
      Apply_Event
        (Frontend, "worker", 5, Request_End,
         "{""status"":""completed""}", T0 + Seconds (60));
      Apply_Terminal
        (Frontend, RPC_Generation (Frontend), "worker", Completed,
         T0 + Seconds (70));
      Refresh_Tool_Times (Frontend, T0 + Seconds (80));
      Assert
        (Tool_Elapsed_Label (Frontend, "watch") = "Elapsed: 00:20",
         "terminal completion after a normal request cannot alter "
         & "frozen time");

      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
   end Test_RPC_Tool_Stopwatch_Replay;

   procedure Test_RPC_Tool_Stopwatch_Terminal (T : in out Test) is
      use Coyote_App.Agent_RPC;
      use Coyote_App.Frontend.GUI.Testing;
      use Ada.Real_Time;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      T0       : constant Time := Clock - Seconds (100);
      Terminal_States : constant array (1 .. 4) of Terminal_Status :=
        (Disconnected, Failed, Aborted, Completed);
      Id : String (1 .. 1);
   begin
      if not T.Display_Available then
         return;
      end if;

      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote tool stopwatch terminal test", Pop_Under => True);
      for Index in Terminal_States'Range loop
         Id (1) := Character'Val (Character'Pos ('a') + Index - 1);
         Apply_Handshake (Frontend, Id, "root", Id);
         Apply_Event
           (Frontend, Id, 1, Request_Start,
            "{""text"":""tool request"",""kind"":""prompt""}", T0);
         Apply_Event
           (Frontend, Id, 2, Tool_Start,
            "{""name"":""shell"",""args"":{},""toolId"":""tool-"
            & Id & """,""turn"":1,""call"":1,""status"":""queued""}",
            T0);
         Apply_Event
           (Frontend, Id, 3, Tool_Status,
            "{""toolId"":""tool-" & Id
            & """,""status"":""running""}", T0 + Seconds (10));
         Apply_Terminal
           (Frontend, RPC_Generation (Frontend), Id, Terminal_States (Index),
            T0 + Seconds (30));
         Select_Agent (Frontend, Id);
         Refresh_Tool_Times (Frontend, T0 + Seconds (50));
         Assert
           (Tool_Elapsed_Label (Frontend, "tool-" & Id) = "Elapsed: 00:20",
            "terminal status freezes unfinished tool at original "
            & "terminal time");
         Apply_Event
           (Frontend, Id, 4, Tool_Status,
            "{""toolId"":""tool-" & Id
            & """,""status"":""running""}", T0 + Seconds (60));
         Apply_Event
           (Frontend, Id, 5, Tool_End,
            "{""toolId"":""tool-" & Id & """,""result"":""late""}",
            T0 + Seconds (70));
         Refresh_Tool_Times (Frontend, T0 + Seconds (80));
         Assert
           (Tool_Elapsed_Label (Frontend, "tool-" & Id) = "Elapsed: 00:20",
            "late running and end frames cannot restart a terminal "
            & "tool clock");
      end loop;

      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
   end Test_RPC_Tool_Stopwatch_Terminal;

   procedure Test_Selected_Agent_Status (T : in out Test) is
      use Coyote_App.Agent_RPC;
      use Coyote_App.Frontend.GUI.Testing;
      Frontend : Coyote_App.Frontend.GUI.Instance;
   begin
      if not T.Display_Available then
         return;
      end if;

      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote selected agent status test", Pop_Under => True);
      Apply_Event
        (Frontend, "root", 1, Status, "{""text"":""root status""}");
      Apply_Handshake (Frontend, "worker", "root", "worker");
      Apply_Event
        (Frontend, "worker", 1, Status, "{""text"":""worker status""}");
      Assert (Status_Text (Frontend) = "root status",
              "background worker status does not replace selected root");

      Select_Agent (Frontend, "worker");
      Assert (Status_Text (Frontend) = "worker status",
              "selecting worker displays its latest status");
      Apply_Event
        (Frontend, "root", 2, Status, "{""text"":""updated root""}");
      Assert (Status_Text (Frontend) = "worker status",
              "background root status does not replace selected worker");

      Select_Agent (Frontend, "root");
      Assert (Status_Text (Frontend) = "updated root",
              "selecting root restores its latest status");
      Reset_Agents_From_Task (Frontend);
      Drain_Events;
      Assert (Status_Text (Frontend) = "ready",
              "reset clears cached status and shows root lifecycle fallback");

      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
   end Test_Selected_Agent_Status;

   procedure Test_Reset_Agents_Rejects_Old_Generation
     (T : in out Test)
   is
      use Coyote_App.Agent_RPC;
      use Coyote_App.Frontend.GUI.Testing;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Model    : Gtk.Tree_Model.Gtk_Tree_Model;
      Old_Generation : Natural;
   begin
      if not T.Display_Available then
         return;
      end if;

      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote agent reset test", Pop_Under => True);
      Old_Generation := RPC_Generation (Frontend);
      Apply_Handshake (Frontend, "worker", "root", "worker");
      Apply_Handshake (Frontend, "nested", "worker", "nested");
      Apply_Event
        (Frontend, "root", 1, Request_Start,
         "{""text"":""before reset"",""kind"":""prompt""}");
      Apply_Event
        (Frontend, "root", 2, Text_Delta,
         "{""text"":""old root response""}");
      Apply_Event
        (Frontend, "worker", 1, Request_Start,
         "{""text"":""worker request"",""kind"":""prompt""}");
      Apply_Event
        (Frontend, "worker", 2, Text_Delta,
         "{""text"":""old worker response""}");
      Assert (Registry_Count (Frontend) = 3,
              "root and nested workers register before reset");
      Assert (History_Entry_Count (Frontend) > 0,
              "RPC activity retains history before reset");
      Model := Gtk.Tree_View.Get_Model (Agents_View (Frontend));
      Assert
        (Gtk.Tree_Model.N_Children (Model,
           Gtk.Tree_Model.Get_Iter_From_String (Model, "0")) = 1,
         "nested worker is visible before reset");
      Select_Agent (Frontend, "worker");
      Assert (GTK_Selected_Agent (Frontend) = "worker"
              and then Selected_Agent (Frontend) = "worker",
              "test selects worker through GTK tree before reset");

      Reset_Agents_From_Task (Frontend);
      Drain_Events;

      Assert (RPC_Generation (Frontend) /= Old_Generation,
              "reset advances the RPC generation");
      Assert (Gtk.Tree_Model.N_Children (Model) = 1,
              "reset removes nested rows and recreates only the root");
      Assert (Registry_Count (Frontend) = 1,
              "reset keeps only the root in the registry");
      Assert (Selected_Agent (Frontend) = "root"
              and then GTK_Selected_Agent (Frontend) = "root",
              "reset selects the recreated root in registry and GTK tree");
      Assert (Root_Ready (Frontend), "reset returns root lifecycle to Ready");
      Assert (History_Entry_Count (Frontend) = 0
              and then History_Update_Count (Frontend) = 0,
              "reset clears every agent history, including root");
      Assert (not Conversation_Has_Exchange (Frontend)
              and then Conversation_Active_Text (Frontend)'Length = 0,
              "reset clears the visible root conversation");

      Apply_Handshake
        (F               => Frontend,
         RPC_Generation  => Old_Generation,
         Agent_Id        => "stale-worker",
         Parent_Agent_Id => "root",
         Label           => "stale");
      Apply_Event
        (F              => Frontend,
         RPC_Generation => Old_Generation,
         Agent_Id       => "root",
         Sequence       => 3,
         Event_Name     => Text_Delta,
         Payload        => "{""text"":""stale response""}");
      Apply_Terminal
        (F              => Frontend,
         RPC_Generation => Old_Generation,
         Agent_Id       => "root",
         Status         => Failed);
      Assert (Registry_Count (Frontend) = 1,
              "old-generation handshake cannot register an agent");
      Assert (History_Entry_Count (Frontend) = 0,
              "reset update and stale frames are absent from history");
      Assert (Root_Ready (Frontend),
              "old-generation terminal cannot change root lifecycle");
      Assert (not Conversation_Has_Exchange (Frontend),
              "old-generation root events cannot restore the old exchange");

      Apply_Event
        (Frontend, "root", 1, Request_Start,
         "{""text"":""new session"",""kind"":""prompt""}");
      Apply_Event
        (Frontend, "root", 2, Text_Delta,
         "{""text"":""fresh root response""}");
      Assert (Conversation_Active_Text (Frontend) = "fresh root response",
              "new root output is visible after reset");
      Apply_Handshake (Frontend, "fresh-worker", "root", "fresh worker");
      Apply_Event
        (Frontend, "fresh-worker", 1, Request_Start,
         "{""text"":""fresh request"",""kind"":""prompt""}");
      Apply_Event
        (Frontend, "fresh-worker", 2, Text_Delta,
         "{""text"":""fresh response""}");
      Assert (Registry_Count (Frontend) = 2,
              "fresh worker registers after reset");
      Assert (Gtk.Tree_Model.N_Children
                (Model,
                 Gtk.Tree_Model.Get_Iter_From_String (Model, "0")) = 1,
              "fresh worker is visible below the recreated root");
      Assert (History_Entry_Count (Frontend) = 2,
              "fresh root and worker activity each create fresh history");
      Assert (Conversation_Has_Exchange (Frontend)
              and then Conversation_Active_Text (Frontend)
                = "fresh root response",
              "fresh worker traffic leaves visible root exchange unchanged");

      Apply_Event
        (Frontend, "root", 1, Request_Start,
         "{""text"":""next session"",""kind"":""prompt""}");
      Apply_Event
        (Frontend, "root", 2, Text_Delta,
         "{""text"":""next-session response""}");
      Reset_Agents_From_Task (Frontend);
      Drain_Events;
      Assert (Gtk.Tree_Model.N_Children (Model) = 1
              and then Registry_Count (Frontend) = 1,
              "a second reset removes the fresh worker tree row");
      Assert (History_Entry_Count (Frontend) = 0
              and then History_Update_Count (Frontend) = 0,
              "a second reset discards intervening root and worker history");

      Coyote_App.Frontend.GUI.Request_Shutdown (Frontend);
      Main_Window (Frontend).Destroy;
   end Test_Reset_Agents_Rejects_Old_Generation;

   procedure Test_Reset_Agents_Rotation_Failure_Recovers
     (T : in out Test)
   is
      use Coyote_App.Agent_RPC;
      use Coyote_App.Agent_RPC.Transport;
      use Coyote_App.Frontend.GUI.Testing;
      Frontend             : Coyote_App.Frontend.GUI.Instance;
      Occupant             : Listener;
      Fresh_Worker         : Channel;
      Old_Probe            : Channel;
      Model                : Gtk.Tree_Model.Gtk_Tree_Model;
      Old_Endpoint_Refused : Boolean := False;
      Old_Endpoint         : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      First_Generation     : Natural := 0;
      Second_Generation    : Natural := 0;
      Created              : Boolean := False;
      Connected            : Boolean := False;
      Occupant_Created     : Boolean := False;
   begin
      if not T.Display_Available then
         return;
      end if;

      begin
         Coyote_App.Frontend.GUI.Create
           (Frontend, "coyote agent reset recovery test",
            Pop_Under => True);
         Created := True;
         Old_Endpoint := Ada.Strings.Unbounded.To_Unbounded_String
           (Ada.Environment_Variables.Value ("COYOTE_RPC_ENDPOINT", ""));
         Model := Gtk.Tree_View.Get_Model (Agents_View (Frontend));
         Apply_Handshake (Frontend, "worker", "root", "worker");
         Apply_Event
           (Frontend, "worker", 1, Request_Start,
            "{""text"":""worker request"",""kind"":""prompt""}");
         Apply_Event
           (Frontend, "worker", 2, Text_Delta,
            "{""text"":""worker response""}");
         Select_Agent (Frontend, "worker");
         Assert (Registry_Count (Frontend) = 2,
                 "worker registers before failed rotation");
         Assert (Non_Root_History_Count (Frontend) > 0,
                 "worker history exists before failed rotation");

         First_Generation := RPC_Generation (Frontend);
         Create_Listener (Occupant, Next_RPC_Endpoint (Frontend));
         Occupant_Created := True;
         Reset_Agents_From_Task (Frontend);
         Drain_Events;

         Assert (Registry_Count (Frontend) = 1,
                 "failed rotation leaves only the root registered");
         Assert (Gtk.Tree_Model.N_Children (Model) = 1,
                 "failed rotation leaves only the root tree row");
         Assert (Selected_Agent (Frontend) = "root"
                   and then GTK_Selected_Agent (Frontend) = "root",
                 "failed rotation selects the root in registry and tree");
         Assert (RPC_Generation (Frontend) > First_Generation,
                 "failed rotation advances the applied generation");
         Assert (Non_Root_History_Count (Frontend) = 0,
                 "failed rotation clears every worker history");
         Assert
           (Ada.Environment_Variables.Value ("COYOTE_RPC_ENDPOINT", "") = "",
            "failed rotation clears the inherited RPC endpoint");
         Assert
           (RPC_Service_Running (Frontend),
            "failed rotation leaves the detached RPC service running");
         Assert
           (RPC_Service_Endpoint (Frontend) = "",
            "failed rotation detaches the listener endpoint");

         Close (Occupant);
         Occupant_Created := False;
         Reset_Agents_From_Task (Frontend);
         Drain_Events;
         Second_Generation := RPC_Generation (Frontend);
         Assert (Second_Generation > First_Generation,
                 "retry advances generation after detachment");
         Assert
           (Ada.Environment_Variables.Value
              ("COYOTE_RPC_ENDPOINT", "")'Length > 0,
            "successful retry republishes the RPC endpoint");
         Assert
           (RPC_Service_Running (Frontend),
            "successful retry keeps the service running");
         Assert
           (RPC_Service_Endpoint (Frontend)
              = Ada.Environment_Variables.Value
                  ("COYOTE_RPC_ENDPOINT", ""),
            "successful retry endpoint matches service listener");

         Connect
           (Fresh_Worker,
            Ada.Environment_Variables.Value ("COYOTE_RPC_ENDPOINT", ""));
         Connected := True;
         Send_Frame
           (Fresh_Worker, Make_Handshake (Agent_Id => "fresh-worker"));
         for Attempt in 1 .. 100 loop
            exit when Registry_Count (Frontend) = 2;
            delay 0.01;
            Drain_Events;
         end loop;
         Assert (Registry_Count (Frontend) = 2,
                 "fresh endpoint handshake registers a worker");
         Assert
           (Gtk.Tree_Model.N_Children
              (Model, Gtk.Tree_Model.Get_Iter_From_String (Model, "0")) = 1,
            "fresh endpoint handshake appears beneath the root");

         if Ada.Strings.Unbounded.Length (Old_Endpoint) > 0 then
            begin
               Connect
                 (Old_Probe,
                  Ada.Strings.Unbounded.To_String (Old_Endpoint));
               Close (Old_Probe);
            exception
               when Transport_Error =>
                  Old_Endpoint_Refused := True;
            end;
            Assert (Old_Endpoint_Refused,
                    "the original worker endpoint is no longer available");
         end if;

         Coyote_App.Frontend.GUI.Set_Session_Identity
           (Frontend, "recovery-session");
         Drain_Events;
         Assert
           (Root_Session_Identity (Frontend) = "recovery-session",
            "session identity updates the reset root after recovery");
      exception
         when others =>
            if Connected then
               Close (Fresh_Worker);
            end if;
            if Occupant_Created then
               Close (Occupant);
            end if;
            if Created then
               Coyote_App.Frontend.GUI.Request_Shutdown (Frontend);
               if Main_Window (Frontend) /= null then
                  Main_Window (Frontend).Destroy;
               end if;
            end if;
            raise;
      end;

      if Connected then
         Close (Fresh_Worker);
      end if;
      if Occupant_Created then
         Close (Occupant);
      end if;
      if Created then
         Coyote_App.Frontend.GUI.Request_Shutdown (Frontend);
         if Main_Window (Frontend) /= null then
            Main_Window (Frontend).Destroy;
         end if;
      end if;
   end Test_Reset_Agents_Rotation_Failure_Recovers;

   procedure Test_Clear_Conversation_Preserves_Agents
     (T : in out Test)
   is
      use Coyote_App.Frontend.GUI.Testing;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Model    : Gtk.Tree_Model.Gtk_Tree_Model;
      Root     : Gtk.Tree_Model.Gtk_Tree_Iter;
   begin
      if not T.Display_Available then
         return;
      end if;

      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote clear conversation test", Pop_Under => True);
      Coyote_App.Frontend.GUI.Set_Source_Directory (Frontend, "/tmp/images");
      Drain_Events;
      Apply_Handshake (Frontend, "worker", "root", "worker");
      Apply_Event
        (Frontend, "root", 1, Coyote_App.Agent_RPC.Request_Start,
         "{""text"":""root request"",""kind"":""prompt""}");
      Apply_Event
        (Frontend, "root", 2, Coyote_App.Agent_RPC.Text_Delta,
         "{""text"":""response to clear""}");
      Model := Gtk.Tree_View.Get_Model (Agents_View (Frontend));
      Root  := Gtk.Tree_Model.Get_Iter_From_String (Model, "0");
      Assert (Gtk.Tree_Model.N_Children (Model, Root) = 1,
              "worker row exists before ordinary conversation clear");
      Assert (History_Entry_Count (Frontend) > 0,
              "root history exists before ordinary conversation clear");

      Coyote_App.Frontend.GUI.Clear_Conversation (Frontend);
      Drain_Events;

      Assert (Gtk.Tree_Model.N_Children (Model) = 1
              and then Gtk.Tree_Model.N_Children (Model, Root) = 1,
              "ordinary clear preserves root and worker tree rows");
      Assert (Registry_Count (Frontend) = 2,
              "ordinary clear preserves runtime agent registrations");
      Assert (History_Entry_Count (Frontend) > 0,
              "ordinary clear is not a session reset and keeps histories");
      Assert (not Conversation_Has_Exchange (Frontend),
              "ordinary clear still clears the visible conversation");
      Assert (Image_Source_Directory (Frontend) = "/tmp/images",
              "ordinary clear preserves the active image source directory");

      Coyote_App.Frontend.GUI.Request_Shutdown (Frontend);
      Main_Window (Frontend).Destroy;
   end Test_Clear_Conversation_Preserves_Agents;

   procedure Test_Product_Information_Icon (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Dialog   : Gtk.Dialog.Gtk_Dialog;
      Image    : Gtk.Image.Gtk_Image;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote product information test", Pop_Under => True);

      Build_Product_Information (Frontend, Dialog, Image);
      Assert (Dialog /= null, "Product Information creates a dialog");
      Assert
        (Dialog.Get_Title = "coyote : Product Information",
         "Product Information uses the application title");
      Assert
        (Image /= null, "Product Information includes the application icon");
      Assert
        (Gtk.Image.Get_Storage_Type (Image) = Gtk.Image.Image_Icon_Name,
         "Product Information uses the themed icon representation");
      Assert
        (Gtk.Image.Get_Pixel_Size (Image) = 96,
         "Product Information icon uses the prominent pixel size");
      declare
         Icon_Name : GNAT.Strings.String_Access := null;
         Icon_Size : Gtk.Enums.Gtk_Icon_Size;
      begin
         Gtk.Image.Get_Icon_Name (Image, Icon_Name, Icon_Size);
         Assert
           (Icon_Name /= null and then Icon_Name.all = "coyote",
            "Product Information uses the coyote icon name");
         GNAT.OS_Lib.Free (Icon_Name);
      exception
         when others =>
            if Icon_Name /= null then
               GNAT.OS_Lib.Free (Icon_Name);
            end if;
            raise;
      end;
      Assert
        (Gtk.Widget.Is_Visible (Gtk.Widget.Gtk_Widget (Image)),
         "Product Information icon is visible");
      declare
         Icon_Info : constant Gtk.Icon_Theme.Gtk_Icon_Info :=
           Gtk.Icon_Theme.Get_Default.Lookup_Icon
             ("coyote", 96, Gtk.Icon_Theme.Icon_Lookup_Force_Svg);
      begin
         Assert
           (Icon_Info /= null,
            "GTK resolves the coyote icon to an installed asset");
         if Icon_Info /= null then
            Assert
              (Gtk.Icon_Theme.Get_Filename (Icon_Info)'Length > 0,
               "GTK resolves the coyote icon to a source file");
         end if;
      end;
      Frontend.Request_Shutdown;
      Dialog.Destroy;
      Main_Window (Frontend).Destroy;
   end Test_Product_Information_Icon;

   procedure Test_Sandbox_Profiles_Menu (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Item     : Gtk.Menu_Item.Gtk_Menu_Item;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote sandbox profiles menu test", Pop_Under => True);
      Item := Sandbox_Profiles_Item (Frontend);
      Assert (Item /= null, "Options creates Sandbox Profiles item");
      Assert
        (not Sandbox_Profiles_Created (Frontend),
         "Sandbox Profiles manager is created lazily");

      Coyote_App.Frontend.GUI.Show_Sandbox_Profiles (Frontend);
      Assert
        (Sandbox_Profiles_Created (Frontend),
         "Sandbox Profiles item opens the manager");
      Assert
        (Sandbox_Profiles_Title (Frontend) = "coyote : Sandbox Profiles",
         "Sandbox Profiles manager uses the documented title");

      Coyote_App.Frontend.GUI.Show_Sandbox_Profiles (Frontend);
      Assert
        (Sandbox_Profiles_Created (Frontend),
         "reopening Sandbox Profiles reuses the manager");
      Assert
        (Sandbox_Profiles_Title (Frontend) = "coyote : Sandbox Profiles",
         "reused manager retains its title");

      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
   end Test_Sandbox_Profiles_Menu;

   function Find_Canvas_Widget
     (Root : Gtk.Widget.Gtk_Widget; Name : String)
      return Gtk.Widget.Gtk_Widget
   is
      use Gtk.Widget.Widget_List;
      use type Gtk.Widget.Widget_List.Glist;
      Children, Node : Glist;
      Found : Gtk.Widget.Gtk_Widget;
   begin
      if Root = null or else Root.Get_Name = Name then
         return Root;
      end if;
      if Root.all in Gtk.Menu_Item.Gtk_Menu_Item_Record'Class then
         Found := Find_Canvas_Widget
           (Gtk.Menu_Item.Gtk_Menu_Item (Root).Get_Submenu, Name);
         if Found /= null then
            return Found;
         end if;
      end if;
      if Root.all not in Gtk.Container.Gtk_Container_Record'Class then
         return null;
      end if;
      Children := Gtk.Container.Gtk_Container (Root).Get_Children;
      Node := First (Children);
      Walk : while Node /= Null_List loop
         Found := Find_Canvas_Widget (Get_Data (Node), Name);
         exit Walk when Found /= null;
         Node := Next (Node);
      end loop Walk;
      Free (Children);
      return Found;
   end Find_Canvas_Widget;

   procedure Test_Canvas_Workspace (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
      use Gtk.Tree_Model;
      use type Gtk.Tree_Model.Gtk_Tree_Iter;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Canvas : Gtk.Window.Gtk_Window;
      Tree : Gtk.Tree_View.Gtk_Tree_View;
      Area : Gtk.Widget.Gtk_Widget;
      Model : Gtk_Tree_Model;
      W, H : Glib.Gint;

      function Control (Name : String) return Gtk.Widget.Gtk_Widget is
         Item : constant Gtk.Widget.Gtk_Widget :=
           Find_Canvas_Widget (Gtk.Widget.Gtk_Widget (Canvas), Name);
      begin
         Assert (Item /= null, "Missing Canvas control: " & Name);
         return Item;
      end Control;

      procedure Activate (Name : String) is
      begin
         Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-" & Name)).Activate;
      end Activate;

      procedure Field (Name, Value : String) is
      begin
         Gtk.GEntry.Gtk_Entry
           (Control ("coyote-canvas-crop-" & Name)).Set_Text (Value);
      end Field;

      procedure Size (Width, Height : Glib.Gint) is
      begin
         Area.Get_Size_Request (W, H);
         Assert (W = Width and then H = Height, "Wrong displayed extent");
      end Size;

      procedure Pointer
        (Kind : Gdk.Event.Gdk_Event_Type; X, Y : Glib.Gdouble) is
         Raw : aliased Gdk.Event.Gdk_Event_Button :=
           (The_Type => Kind, Window => Area.Get_Window,
            Send_Event => 1, Time => 0, X => X, Y => Y, Axes => null,
            State => 0, Button => 1, Device => System.Null_Address,
            X_Root => X, Y_Root => Y);
      begin
         Assert (Area.Event (Gdk.Event.To_Event (Raw'Access)),
                 "Canvas did not handle pointer event");
      end Pointer;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "Canvas workspace test", Pop_Under => True);
      Assert (Canvas_Window (Frontend) = null, "Canvas is lazy");
      Canvas_Item (Frontend).Activate;
      Canvas := Canvas_Window (Frontend);
      Assert (Canvas /= null and then Canvas.Get_Visible,
              "View > Canvas opens the workspace");
      Assert (Canvas.Get_Title = "coyote : Canvas" and not Canvas.Get_Modal,
              "Canvas is modeless and has the documented title");
      Tree := Gtk.Tree_View.Gtk_Tree_View (Control ("coyote-canvas-drawings"));
      Model := Tree.Get_Model;
      Area := Control ("coyote-canvas-drawing-area");
      Activate ("new");
      Drain_Events;
      Size (800, 600);
      Assert (Get_Iter_From_String (Model, "0") /= Null_Iter,
              "New creates an Original");
      Pointer (Gdk.Event.Button_Press, 30.0, 30.0);
      Pointer (Gdk.Event.Button_Release, 30.0, 30.0);
      Activate ("save");
      Assert (Get_Iter_From_String (Model, "0:0") /= Null_Iter,
              "Pointer stroke saves as a child of Original");

      Activate ("crop");
      Pointer (Gdk.Event.Button_Press, 40.0, 50.0);
      Pointer (Gdk.Event.Button_Release, 100.0, 130.0);
      Activate ("apply");
      Size (60, 80);
      Activate ("undo");
      Size (800, 600);
      Activate ("redo");
      Size (60, 80);
      Activate ("crop");
      Field ("x", "-3");
      Field ("y", "4");
      Field ("width", "16");
      Field ("height", "20");
      Assert (not Control ("canvas-apply").Get_Sensitive,
              "Negative origin disables Apply");
      Field ("x", "3");
      Assert (Control ("canvas-apply").Get_Sensitive,
              "Valid fields enable Apply");
      Activate ("save");
      Size (60, 80);
      Activate ("cancel");
      Size (60, 80);
      Activate ("save");
      Assert (Get_Iter_From_String (Model, "0:0:0") /= Null_Iter,
              "Only the applied crop was checkpointed");

      Tree.Get_Selection.Select_Iter (Get_Iter_From_String (Model, "0"));
      Size (800, 600);
      Activate ("draft");
      Size (60, 80);
      Activate ("new");
      Assert (Get_Iter_From_String (Model, "1") /= Null_Iter,
              "New retains the first drawing and its revisions");
      Activate ("close");
      Assert (not Canvas.Get_Visible, "Close hides without losing the tree");
      Canvas_Item (Frontend).Activate;
      Assert (Canvas_Window (Frontend) = Canvas and then Canvas.Get_Visible,
              "Reopening reuses the workspace");
      Assert (Get_Iter_From_String (Model, "0:0:0") /= Null_Iter,
              "Close preserves the first drawing history");
      Tree.Get_Selection.Select_Iter (Get_Iter_From_String (Model, "0"));
      Size (800, 600);

      Reset_Agents_From_Task (Frontend);
      Drain_Events;
      Assert (not Canvas.Get_Visible and then Get_Iter_First (Model) = Null_Iter,
              "Session reset clears and hides the workspace");
      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
      Assert (Canvas_Window (Frontend) = null,
              "Destroying the conversation tears down its Canvas");
   end Test_Canvas_Workspace;

   function Canvas_Toplevel (Name : String) return Gtk.Window.Gtk_Window is
      use Gtk.Widget.Widget_List;
      use type Gtk.Widget.Widget_List.Glist;
      Windows : Glist := Gtk.Window.List_Toplevels;
      Cursor  : Glist := First (Windows);
      Result  : Gtk.Window.Gtk_Window := null;
   begin
      Scan : while Cursor /= Null_List loop
         if Get_Data (Cursor).Get_Name = Name then
            Result := Gtk.Window.Gtk_Window (Get_Data (Cursor));
            exit Scan;
         end if;
         Cursor := Next (Cursor);
      end loop Scan;
      Free (Windows);
      return Result;
   end Canvas_Toplevel;

   procedure Finish_Canvas_Jobs is
      use Ada.Real_Time;
      Deadline : constant Time := Clock + Seconds (3);
   begin
      Poll : loop
         Drain_Events;
         exit Poll when Coyote_GUI.Canvas_Import_Jobs.Pending_Count = 0;
         Assert (Clock < Deadline, "Canvas worker did not complete");
         delay 0.01;
      end loop Poll;
   end Finish_Canvas_Jobs;

   procedure Test_Canvas_Clipboard_Import (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
      use Gtk.Tree_Model;
      use Ada.Real_Time;
      use type Gdk.Pixbuf.Rgb_Record;
      Frontend  : Coyote_App.Frontend.GUI.Instance;
      Canvas    : Gtk.Window.Gtk_Window;
      Tree      : Gtk.Tree_View.Gtk_Tree_View;
      Area      : Gtk.Widget.Gtk_Widget;
      Model     : Gtk_Tree_Model;
      Width     : Glib.Gint;
      Height    : Glib.Gint;
      Clipboard : Gtk.Clipboard.Gtk_Clipboard;
      Pixbuf    : Gdk.Pixbuf.Gdk_Pixbuf;
      Failure   : Gtk.Window.Gtk_Window;
      Row       : Gtk_Tree_Iter;
      Value     : Glib.Values.GValue;
      Started   : Time;
      Imported  : Boolean := False;
      Owns_Clipboard : Boolean := False;

      function Control (Name : String) return Gtk.Widget.Gtk_Widget is
         Item : constant Gtk.Widget.Gtk_Widget :=
           Find_Canvas_Widget (Gtk.Widget.Gtk_Widget (Canvas), Name);
      begin
         Assert (Item /= null, "Missing Canvas control: " & Name);
         return Item;
      end Control;
   begin
      if not T.Display_Available then
         return;
      end if;

      Coyote_App.Frontend.GUI.Create
        (Frontend, "Canvas clipboard import test", Pop_Under => True);
      Canvas_Item (Frontend).Activate;
      Canvas := Canvas_Window (Frontend);
      Assert (Canvas /= null and then Canvas.Get_Visible,
              "Canvas opens for clipboard import");
      Tree := Gtk.Tree_View.Gtk_Tree_View
        (Control ("coyote-canvas-drawings"));
      Model := Tree.Get_Model;
      Area := Control ("coyote-canvas-drawing-area");
      Clipboard := Gtk.Clipboard.Get;
      --  Do not replace any selection advertised by an existing owner.
      if Gtk.Clipboard.Get_Owner (Clipboard) /= null
        or else Gtk.Clipboard.Wait_Is_Target_Available
          (Clipboard, Gdk.Property.Atom_Intern ("TARGETS", False))
      then
         Frontend.Request_Shutdown;
         Main_Window (Frontend).Destroy;
         return;
      end if;

      Pixbuf := Gdk.Pixbuf.Gdk_New (Width => 37, Height => 23);
      Gdk.Pixbuf.Fill (Pixbuf, 16#FF0000FF#);
      declare
         Right_Half : constant Gdk.Pixbuf.Gdk_Pixbuf :=
           Gdk.Pixbuf.Gdk_New_Subpixbuf (Pixbuf, 20, 0, 17, 23);
      begin
         Gdk.Pixbuf.Fill (Right_Half, 16#0000FFFF#);
         Right_Half.Unref;
      end;
      Gtk.Clipboard.Set_Image (Clipboard, Pixbuf);
      Owns_Clipboard := True;
      Pixbuf.Unref;
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-paste")).Activate;
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-close")).Activate;
      Canvas_Item (Frontend).Activate;
      Finish_Canvas_Jobs;
      Assert (N_Children (Model) = 0, "Close invalidates pending paste");

      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-new")).Activate;
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-paste")).Activate;
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-paste")).Activate;

      Started := Clock;
      Poll_Import : loop
         Drain_Events;
         if N_Children (Model) > 1 then
            Row := Get_Iter_From_String (Model, "1");
            Get_Value (Model, Row, 0, Value);
            declare
               Label : constant String := Glib.Values.Get_String (Value);
            begin
               Imported := Label'Length >= 15
                 and then Label (1 .. 15) = "Clipboard Image";
            end;
            Glib.Values.Unset (Value);
            exit Poll_Import when Imported;
         end if;
         exit Poll_Import when Clock - Started >= Seconds (2);
         delay 0.01;
      end loop Poll_Import;

      Assert (Imported,
              "Clipboard paste adds a root named Clipboard Image");
      Finish_Canvas_Jobs;
      Assert (N_Children (Model) = 2,
              "Superseded paste did not publish a duplicate");
      Area.Get_Size_Request (Width, Height);
      Assert (Width = 800 and then Height = 600,
              "Paste does not replace the displayed working copy");
      Assert (Tree.Get_Selection.Count_Selected_Rows = 0,
              "Paste does not change the selection");
      Assert (N_Children (Model, Row) = 0,
              "Imported clipboard image is a read-only root");
      Gtk.Tree_View.Get_Selection (Tree).Select_Iter (Row);
      Drain_Events;
      Area.Get_Size_Request (Width, Height);
      Assert (Width = 37 and then Height = 23,
              "Selecting clipboard image shows native dimensions");
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-edit")).Activate;
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-crop")).Activate;
      Gtk.GEntry.Gtk_Entry (Control ("coyote-canvas-crop-x")).Set_Text ("21");
      Gtk.GEntry.Gtk_Entry (Control ("coyote-canvas-crop-width")).Set_Text ("8");
      Gtk.GEntry.Gtk_Entry (Control ("coyote-canvas-crop-height")).Set_Text ("6");
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-apply")).Activate;
      Area.Get_Size_Request (Width, Height);
      Assert (Width = 8 and then Height = 6, "Crop has exact native bounds");
      Crop_Pixel : declare
         Surface : constant Cairo.Cairo_Surface := Cairo.Image_Surface.Create
           (Cairo.Image_Surface.Cairo_Format_RGB24, Width, Height);
         Context : constant Cairo.Cairo_Context := Cairo.Create (Surface);
         Sample : Gdk.Pixbuf.Gdk_Pixbuf;
         RGB : Gdk.Pixbuf.Rgb_Record;
      begin
         --  Process the pending resize before drawing to the test surface.
         Canvas.Check_Resize;
         Drain_Events;
         Area.Draw (Context);
         Cairo.Destroy (Context);
         Sample := Gdk.Pixbuf.Get_From_Surface (Surface, 0, 0, 1, 1);
         RGB := Gdk.Pixbuf.Get_Pixels (Sample) (0);
         Sample.Unref;
         Cairo.Surface_Destroy (Surface);
         Assert (RGB = (0, 0, 255), "Crop displays the retained source pixel");
      end Crop_Pixel;
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-undo")).Activate;
      Area.Get_Size_Request (Width, Height);
      Assert (Width = 37 and then Height = 23, "Undo restores image extent");
      Canvas.Set_Focus (Area);
      Gtk.Clipboard.Set_Text (Clipboard, "/tmp/a-file-not-an-image-offer");
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-paste")).Activate;
      Drain_Events;
      Failure := Canvas_Toplevel ("coyote-canvas-import-error");
      Assert (Failure /= null and then N_Children (Model) = 2,
              "Text-only clipboard offers explain failure and add no root");
      Gtk.Dialog.Gtk_Dialog (Failure).Response (Gtk.Dialog.Gtk_Response_Close);
      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
      if Owns_Clipboard then
         Gtk.Clipboard.Clear (Clipboard);
      end if;
   exception
      when others =>
         if Owns_Clipboard then
            Gtk.Clipboard.Clear (Clipboard);
         end if;
         if Main_Window (Frontend) /= null then
            Frontend.Request_Shutdown;
            Main_Window (Frontend).Destroy;
         end if;
         raise;
   end Test_Canvas_Clipboard_Import;

   procedure Test_Canvas_File_Import (T : in out Test) is
      use Ada.Strings.Unbounded;
      use Ada.Real_Time;
      use Coyote_App.Frontend.GUI.Testing;
      use Gtk.Tree_Model;
      use type Glib.Error.GError;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Canvas   : Gtk.Window.Gtk_Window;
      Tree     : Gtk.Tree_View.Gtk_Tree_View;
      Model    : Gtk_Tree_Model;
      Area     : Gtk.Widget.Gtk_Widget;
      Row      : Gtk_Tree_Iter;
      Path     : Unbounded_String;
      FD       : GNAT.OS_Lib.File_Descriptor;
      W, H     : Glib.Gint;

      function Control (Name : String) return Gtk.Widget.Gtk_Widget is
        (Find_Canvas_Widget (Gtk.Widget.Gtk_Widget (Canvas), Name));

      procedure Choose is
         Top : Gtk.Window.Gtk_Window;
         Chooser : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
         Deadline : constant Time := Clock + Seconds (3);
      begin
         Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-import")).Activate;
         Top := Canvas_Toplevel ("coyote-canvas-file-selection");
         Assert (Top /= null and then not Top.Get_Modal,
                 "Import opens a modeless File Selection");
         Chooser := Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog (Top);
         Assert (Chooser.Set_Filename (To_String (Path)),
                 "GTK accepts the fixture path");
         Poll : loop
            Drain_Events;
            exit Poll when Chooser.Get_Filename = To_String (Path);
            Assert (Clock < Deadline, "File Selection did not resolve path");
            delay 0.01;
         end loop Poll;
         Gtk.Dialog.Gtk_Dialog (Chooser).Response (Gtk.Dialog.Gtk_Response_OK);
      end Choose;
   begin
      if not T.Display_Available then
         return;
      end if;
      Coyote_Temp_Files.Create (FD, Path);
      GNAT.OS_Lib.Close (FD);
      declare
         Image : constant Gdk.Pixbuf.Gdk_Pixbuf :=
           Gdk.Pixbuf.Gdk_New (Width => 675, Height => 44);
         Error : Glib.Error.GError;
      begin
         Gdk.Pixbuf.Fill (Image, 16#336699FF#);
         Gdk.Pixbuf.Save (Image, To_String (Path), Gdk.Pixbuf.JPEG, Error);
         Image.Unref;
         Assert (Error = null, "Generated JPEG fixture");
      end;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "Canvas file import test", Pop_Under => True);
      Canvas_Item (Frontend).Activate;
      Canvas := Canvas_Window (Frontend);
      Area := Control ("coyote-canvas-drawing-area");
      Tree := Gtk.Tree_View.Gtk_Tree_View (Control ("coyote-canvas-drawings"));
      Model := Tree.Get_Model;
      Choose;
      Finish_Canvas_Jobs;
      Assert (N_Children (Model) = 1, "File import adds one Original");
      Row := Get_Iter_First (Model);
      Check_Label : declare
         V : Glib.Values.GValue;
      begin
         Get_Value (Model, Row, 0, V);
         declare
            Value : constant String := Glib.Values.Get_String (V);
         begin
            Glib.Values.Unset (V);
            Assert (Value'Length >= 14 and then Value (1 .. 14) = "Imported Image",
                    "File Original has an imported label");
         end;
      end Check_Label;
      Tree.Get_Selection.Select_Iter (Row);
      Area.Get_Size_Request (W, H);
      Assert (W = 675 and then H = 44, "File import is not thumbnailed");
      Choose;
      Reset_Agents_From_Task (Frontend);
      Finish_Canvas_Jobs;
      Assert (N_Children (Model) = 0, "Session reset drops the pending image");
      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
      Coyote_Temp_Files.Delete (To_String (Path));
   exception
      when others =>
         if Main_Window (Frontend) /= null then
            Frontend.Request_Shutdown;
            Main_Window (Frontend).Destroy;
         end if;
         Coyote_Temp_Files.Delete (To_String (Path));
         raise;
   end Test_Canvas_File_Import;

   package Coyote_App_Frontend_GUI_Caller is new AUnit.Test_Caller
     (Coyote_App_Frontend_GUI_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Product Information displays application icon",
            Coyote_App_Frontend_GUI_Tests.Test_Product_Information_Icon'
              Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Sandbox Profiles menu opens manager",
            Coyote_App_Frontend_GUI_Tests.Test_Sandbox_Profiles_Menu'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI layout and shutdown lifecycle",
            Coyote_App_Frontend_GUI_Tests.Test_Layout_And_Shutdown_Lifecycle'
              Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI agent tree expands new subagents",
            Coyote_App_Frontend_GUI_Tests
              .Test_Agent_Tree_Expands_New_Subagents'
              Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI RPC tool lifecycle status",
            Coyote_App_Frontend_GUI_Tests
              .Test_RPC_Tool_Lifecycle_Status'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI RPC tool stopwatch replay",
            Coyote_App_Frontend_GUI_Tests
              .Test_RPC_Tool_Stopwatch_Replay'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI RPC tool stopwatch terminal cleanup",
            Coyote_App_Frontend_GUI_Tests
              .Test_RPC_Tool_Stopwatch_Terminal'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI selected agent status",
            Coyote_App_Frontend_GUI_Tests
              .Test_Selected_Agent_Status'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI agent reset rejects old RPC generation",
            Coyote_App_Frontend_GUI_Tests
              .Test_Reset_Agents_Rejects_Old_Generation'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI reset rotation failure recovers",
            Coyote_App_Frontend_GUI_Tests
              .Test_Reset_Agents_Rotation_Failure_Recovers'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI clear conversation preserves agents",
            Coyote_App_Frontend_GUI_Tests
              .Test_Clear_Conversation_Preserves_Agents'Access));

      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Canvas workspace lifecycle and crop",
            Test_Canvas_Workspace'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Canvas clipboard image import",
            Test_Canvas_Clipboard_Import'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Canvas file import and session reset",
            Test_Canvas_File_Import'Access));
      return Result;
   end Suite;

end Coyote_App_Frontend_GUI_Tests;
