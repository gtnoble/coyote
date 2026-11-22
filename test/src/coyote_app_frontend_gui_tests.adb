with AUnit.Test_Caller;
--  Coyote_App_Frontend_GUI_Tests body.
--
--  Project: coyote

with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Containers;
with Ada.Strings.Fixed;
with Coyote_App;
with Coyote_App.History;
with Coyote_Temp_Files;
with Gtk.Clipboard;
with Gtk.Text_Buffer;
with Gtk.Text_Iter;
with Gtk.Text_View;
with Gtk.Handlers;
with Gdk.Pixbuf;
with LLM.Session_Store;
with LLM.Types;
with Coyote_Math_Jobs;
with Coyote_GUI.Math_Element;
with AUnit.Assertions;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_RPC.Transport;
with Coyote_App.Frontend.GUI.Testing;
with Coyote_GUI;
with Coyote_GUI.Prompt_Queue;
with Coyote_Process_Control;
with GNAT.OS_Lib;
with GNAT.Strings;
with Glib;
with Glib.Values;
with Gtk.Box;
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

   package Widget_Actions is new Gtk.Handlers.Callback
     (Gtk.Widget.Gtk_Widget_Record);

   use AUnit.Assertions;
   use type Glib.Gint;
   use type Glib.Guint;
   use type Glib.Gdouble;
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

   procedure Test_Replays_Persisted_Mixed_Math
     (T : in out Test)
   is
      use Coyote_App.Frontend.GUI.Testing;
      use Ada.Strings.Unbounded;
      use type Gtk.Text_View.Gtk_Text_View;
      use type Gtk.Text_Buffer.Gtk_Text_Buffer;
      use type Ada.Real_Time.Time;
      use type LLM.Types.Role;
      use type LLM.Types.Content_Block_Kind;
      use type GNAT.OS_Lib.File_Descriptor;
      use type Ada.Directories.File_Size;
      use type Ada.Containers.Count_Type;
      use type Gdk.Pixbuf.Gdk_Pixbuf;

      type Environment_Record is record
         Is_Present : Boolean := False;
         Value      : Unbounded_String;
      end record;
      type Environment_Array is array (Positive range 1 .. 4)
        of Environment_Record;
      Environment_Names : constant array (Positive range 1 .. 4) of
        String (1 .. 36) :=
          (1 => "COYOTE_RPC_ENDPOINT                 ",
           2 => "COYOTE_RUNTIME_AGENT_ID             ",
           3 => "COYOTE_PARENT_RUNTIME_AGENT_ID      ",
           4 => "COYOTE_AGENT_LABEL                  ");

      function Snapshot_Environment return Environment_Array is
         Result : Environment_Array;
      begin
         for Index in Result'Range loop
            declare
               Name : constant String :=
                 Ada.Strings.Fixed.Trim
                   (Environment_Names (Index), Ada.Strings.Right);
            begin
               Result (Index).Is_Present :=
                 Ada.Environment_Variables.Exists (Name);
               if Result (Index).Is_Present then
                  Result (Index).Value := To_Unbounded_String
                    (Ada.Environment_Variables.Value (Name));
               end if;
            end;
         end loop;
         return Result;
      end Snapshot_Environment;

      Frontend       : Coyote_App.Frontend.GUI.Instance;
      State          : Coyote_App.App_State;
      Temp_FD        : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Temp_Path      : Unbounded_String;
      Temp_Root      : Unbounded_String;
      Root_Owned     : Boolean := False;
      Session_Id     : Unbounded_String;
      Session_Path   : Unbounded_String;
      Frontend_Ready : Boolean := False;
      Raster_Baseline : Natural;
      Home_Was_Set   : constant Boolean :=
        Ada.Environment_Variables.Exists ("HOME");
      Old_Home       : constant String :=
        Ada.Environment_Variables.Value ("HOME", "");
      Saved_Environment : constant Environment_Array :=
        Snapshot_Environment;
      Source         : constant String :=
        "Opening paragraph." & ASCII.LF & ASCII.LF
        & "$$\frac{a}{b}$$" & ASCII.LF & ASCII.LF
        & "Closing paragraph with $x+1$ and "
        & "$\unknowncommand$ preserved." & ASCII.LF & ASCII.LF
        & "$$\unknowncommand$$";
      Display_Source : constant String := "$$\frac{a}{b}$$";
      Invalid_Source : constant String := "$$\unknowncommand$$";
      Closing_Line   : constant String :=
        "Closing paragraph with $x+1$ and "
        & "$\unknowncommand$ preserved.";
      Visible_Closing_Line : constant String :=
        "Closing paragraph with  and $\unknowncommand$ preserved.";
      Quit           : Boolean;
      pragma Unreferenced (Quit);

      procedure Pump_Events is
      begin
         if Gtk.Main.Events_Pending then
            Quit := Gtk.Main.Main_Iteration_Do (False);
         else
            delay 0.01;
         end if;
      end Pump_Events;

      procedure Wait_For_Math is
         Deadline : constant Ada.Real_Time.Time :=
           Ada.Real_Time.Clock + Ada.Real_Time.Seconds (5);
      begin
         while Ada.Real_Time.Clock < Deadline
           and then
             (Conversation_Math_Count (Frontend) /= 2
              or else Conversation_Math_Is_Pending (Frontend, 1)
              or else Conversation_Math_Is_Pending (Frontend, 2)
              or else not Conversation_Is_Completed (Frontend))
         loop
            Pump_Events;
         end loop;
         Assert
           (Conversation_Math_Count (Frontend) = 2
            and then not Conversation_Math_Is_Pending (Frontend, 1)
            and then not Conversation_Math_Is_Pending (Frontend, 2)
            and then Conversation_Is_Completed (Frontend),
            "replay completion and math workers finish within five seconds");
      end Wait_For_Math;

      procedure Restore_Home;

      function Load_Persisted_Messages
         return LLM.Types.Message_Vectors.Vector
      is
         Result : LLM.Types.Message_Vectors.Vector;
      begin
         Ada.Environment_Variables.Set ("HOME", To_String (Temp_Root));
         Result := LLM.Session_Store.Load_Messages (To_String (Session_Id));
         Restore_Home;
         return Result;
      exception
         when others =>
            Restore_Home;
            raise;
      end Load_Persisted_Messages;

      procedure Check_Replayed_Content is
         View     : Gtk.Text_View.Gtk_Text_View;
         Buffer   : Gtk.Text_Buffer.Gtk_Text_Buffer;
         First    : Gtk.Text_Iter.Gtk_Text_Iter;
         Last     : Gtk.Text_Iter.Gtk_Text_Iter;
         Messages : constant LLM.Types.Message_Vectors.Vector :=
           Load_Persisted_Messages;
      begin
         Wait_For_Math;
         Assert
           (Image_Source_Directory (Frontend) = To_String (Temp_Root),
            "history restores the persisted session working directory");
         Assert
           (Messages.Length = 2,
            "native session reload restores both fixture messages");
         Assert
           (Messages.Element (1).Role = LLM.Types.Assistant
            and then Messages.Element (1).Content.Length = 1
            and then Messages.Element (1).Content.Element (0).Kind =
              LLM.Types.Text_Block
            and then To_String
              (Messages.Element (1).Content.Element (0).Text) = Source,
            "native session reload preserves the exact assistant source");
         View := Conversation_Active_View (Frontend);
         Assert (View /= null, "history replay creates an active text view");
         Buffer := Gtk.Text_View.Get_Buffer (View);
         Assert (Buffer /= null, "active math view owns a text buffer");
         Assert
           (Conversation_Math_Count (Frontend) = 2
            and then Conversation_Math_Source (Frontend, 1) = Display_Source
            and then Conversation_Math_Source (Frontend, 2) = Invalid_Source,
            "display math source survives persisted replay exactly");
         Assert
           (Conversation_Math_Is_Valid (Frontend, 1)
            and then Conversation_Math_Area_Visible (Frontend, 1)
            and then not Conversation_Math_Is_Valid (Frontend, 2)
            and then not Conversation_Math_Area_Visible (Frontend, 2)
            and then Conversation_Math_Fallback_Visible (Frontend, 2),
            "valid display renders; invalid display remains visible fallback");
         declare
            Deadline : constant Ada.Real_Time.Time :=
              Ada.Real_Time.Clock + Ada.Real_Time.Seconds (5);
            Pixbuf_Count : Natural;
         begin
            loop
               Pixbuf_Count := 0;
               Buffer.Get_Start_Iter (First);
               while not Gtk.Text_Iter.Is_End (First) loop
                  if Gtk.Text_Iter.Get_Pixbuf (First) /= null then
                     Pixbuf_Count := Pixbuf_Count + 1;
                  end if;
                  declare
                     Moved : Boolean;
                  begin
                     Gtk.Text_Iter.Forward_Char (First, Moved);
                     exit when not Moved;
                  end;
               end loop;
               exit when Pixbuf_Count >= 1
                 or else Ada.Real_Time.Clock >= Deadline;
               Pump_Events;
            end loop;
            Assert
              (Pixbuf_Count = 1,
               "valid inline formula is adopted as one GTK Pixbuf");
         end;
         Assert
           (Coyote_GUI.Math_Element.Retained_Raster_Bytes > Raster_Baseline,
            "replayed formula rasters retain bytes above entry baseline");
         Buffer.Get_Iter_At_Line (First, 0);
         Buffer.Get_Iter_At_Line (Last, 0);
         declare
            Moved : Boolean;
         begin
            Gtk.Text_Iter.Forward_To_Line_End (Last, Moved);
         end;
         Assert
           (Buffer.Get_Text (First, Last, True) = Closing_Line
            and then Buffer.Get_Text (First, Last, False) =
              Visible_Closing_Line,
            "GTK buffer retains source and hides rendered inline math only");
         Buffer.Select_Range (First, Last);
         Widget_Actions.Emit_By_Name
           (Gtk.Widget.Gtk_Widget (View), "copy-clipboard");
         Assert
           (Gtk.Clipboard.Wait_For_Text (Gtk.Clipboard.Get) = Closing_Line,
            "GTK copy-clipboard signal restores selected mixed-math source");
      end Check_Replayed_Content;

      procedure Restore_Home is
      begin
         if Home_Was_Set then
            Ada.Environment_Variables.Set ("HOME", Old_Home);
         elsif Ada.Environment_Variables.Exists ("HOME") then
            Ada.Environment_Variables.Clear ("HOME");
         end if;
      end Restore_Home;

      procedure Restore_Gui_Environment is
      begin
         for Index in Saved_Environment'Range loop
            declare
               Name : constant String :=
                 Ada.Strings.Fixed.Trim
                   (Environment_Names (Index), Ada.Strings.Right);
            begin
               if Saved_Environment (Index).Is_Present then
                  Ada.Environment_Variables.Set
                    (Name, To_String (Saved_Environment (Index).Value));
               elsif Ada.Environment_Variables.Exists (Name) then
                  Ada.Environment_Variables.Clear (Name);
               end if;
            end;
         end loop;
      end Restore_Gui_Environment;

      function Gui_Environment_Is_Restored return Boolean is
      begin
         for Index in Saved_Environment'Range loop
            declare
               Name : constant String :=
                 Ada.Strings.Fixed.Trim
                   (Environment_Names (Index), Ada.Strings.Right);
            begin
               if Ada.Environment_Variables.Exists (Name)
                 /= Saved_Environment (Index).Is_Present
               then
                  return False;
               end if;
               if Saved_Environment (Index).Is_Present
                 and then Ada.Environment_Variables.Value (Name)
                   /= To_String (Saved_Environment (Index).Value)
               then
                  return False;
               end if;
            end;
         end loop;
         return True;
      end Gui_Environment_Is_Restored;

      procedure Cleanup is
      begin
         if Frontend_Ready then
            Frontend.Request_Shutdown;
            if Main_Window (Frontend) /= null then
               Main_Window (Frontend).Destroy;
            end if;
            Frontend_Ready := False;
         end if;
         Coyote_Math_Jobs.Shutdown;
         Restore_Home;
         Restore_Gui_Environment;
         if Root_Owned
           and then Temp_Root /= Null_Unbounded_String
           and then Ada.Directories.Exists (To_String (Temp_Root))
         then
            Ada.Directories.Delete_Tree (To_String (Temp_Root));
            Root_Owned := False;
         end if;
      end Cleanup;

      procedure Append_Text_Message
        (Role : LLM.Types.Role; Text : String) is
         Content : LLM.Types.Content_Block_Vectors.Vector;
      begin
         Content.Append
           ((Kind => LLM.Types.Text_Block,
             Text => To_Unbounded_String (Text)));
         LLM.Session_Store.Append_Message
           (To_String (Session_Id),
            (Role      => Role,
             Content   => Content,
             Tok_Usage => (others => 0),
             Stop      =>
               (if Role = LLM.Types.Assistant
                then LLM.Types.Stop
                else LLM.Types.Unknown_Stop),
             Timestamp => Null_Unbounded_String));
      end Append_Text_Message;

      procedure Wait_For_Clear is
         Deadline : constant Ada.Real_Time.Time :=
           Ada.Real_Time.Clock + Ada.Real_Time.Seconds (5);
      begin
         while Ada.Real_Time.Clock < Deadline
           and then Conversation_Has_Exchange (Frontend)
         loop
            Pump_Events;
         end loop;
         Assert
           (not Conversation_Has_Exchange (Frontend)
            and then Conversation_Math_Count (Frontend) = 0,
            "queued clear removes the prior replay before the next cycle");
         Coyote_Math_Jobs.Shutdown;
         while Ada.Real_Time.Clock < Deadline
           and then Coyote_GUI.Math_Element.Retained_Raster_Bytes /=
             Raster_Baseline
         loop
            Pump_Events;
         end loop;
         Assert
           (Coyote_GUI.Math_Element.Retained_Raster_Bytes = Raster_Baseline,
            "cleared persisted replay returns raster bytes to entry baseline");
      end Wait_For_Clear;
   begin
      if not T.Display_Available then
         return;
      end if;

      Coyote_Math_Jobs.Shutdown;
      Raster_Baseline := Coyote_GUI.Math_Element.Retained_Raster_Bytes;
      Coyote_Temp_Files.Create (Temp_FD, Temp_Path);
      Assert
        (Temp_FD /= GNAT.OS_Lib.Invalid_FD,
         "unique temporary fixture root is created");
      GNAT.OS_Lib.Close (Temp_FD);
      Temp_FD := GNAT.OS_Lib.Invalid_FD;
      Ada.Directories.Delete_File (To_String (Temp_Path));
      Temp_Root := Temp_Path;
      Temp_Path := Null_Unbounded_String;
      Ada.Directories.Create_Directory (To_String (Temp_Root));
      Root_Owned := True;
      Ada.Environment_Variables.Set ("HOME", To_String (Temp_Root));
      Session_Id := To_Unbounded_String
        (LLM.Session_Store.Create_Session (To_String (Temp_Root)));
      Session_Path := To_Unbounded_String
        (LLM.Session_Store.Session_File_Path (To_String (Session_Id)));
      Append_Text_Message (LLM.Types.User, "Persisted math request");
      Append_Text_Message (LLM.Types.Assistant, Source);
      Assert
        (Ada.Directories.Exists (To_String (Session_Path))
         and then Ada.Directories.Size (To_String (Session_Path)) > 0,
         "native SessionStore writes the persisted fixture");
      Restore_Home;

      Coyote_App.Frontend.GUI.Create
        (Frontend, "coyote persisted mixed math replay test",
         Pop_Under => True,
         Notifications_Allowed => False,
         Notifications_Enabled => False);
      Frontend_Ready := True;
      for Round in 1 .. 2 loop
         Ada.Environment_Variables.Set ("HOME", To_String (Temp_Root));
         Coyote_App.History.Render_Session_History
           (UUID => To_String (Session_Id),
            Frontend => Frontend,
            State => State);
         Restore_Home;
         Assert
           (State.Turn_Count = 1,
            "one persisted assistant turn is restored");
         Check_Replayed_Content;
         Coyote_App.Frontend.GUI.Clear_Conversation (Frontend);
         Wait_For_Clear;
      end loop;
      Cleanup;
      Assert
        (Gui_Environment_Is_Restored
         and then Ada.Environment_Variables.Exists ("HOME") = Home_Was_Set
         and then Ada.Environment_Variables.Value ("HOME", "") = Old_Home,
         "GUI shutdown restores inherited environment presence and values");
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Replays_Persisted_Mixed_Math;

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
           ("Coyote_App.Frontend.GUI replays persisted mixed math",
            Coyote_App_Frontend_GUI_Tests
              .Test_Replays_Persisted_Mixed_Math'Access));

      return Result;
   end Suite;

end Coyote_App_Frontend_GUI_Tests;
