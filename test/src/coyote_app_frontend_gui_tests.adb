with AUnit.Test_Caller;
--  Coyote_App_Frontend_GUI_Tests body.
--
--  Project: coyote

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Real_Time;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with Coyote_App.Agent_RPC;
with Coyote_Canvas.Store;
with Coyote_Canvas.Store.Workspaces;
with Coyote_Canvas.Revisions;
with Coyote_Canvas.Document;
with Coyote_Canvas.Import_Service;
with Coyote_Utils;
with GNATCOLL.JSON;
with LLM.Tools.Shell;
with Coyote_App.Agent_RPC.Transport;
with Coyote_App.Frontend.GUI.Testing;
with Coyote_GUI;
with Coyote_GUI.Prompt_Queue;
with Coyote_GUI.Canvas_Import_Jobs;
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
with Gdk.Device;
with Gdk.Display;
with Gdk.Event;
with Gdk.Seat;
with Gdk.Window;
with Gdk.Types.Keysyms;
with Gdk.Pixbuf;
with Gdk.Property;
with Gdk.RGBA;
with Gtk.Box;
with Gtk.Adjustment;
with Gtk.Bin;
with Gtk.Button;
with Gtk.Color_Button;
with Gtk.Spin_Button;
with Gtk.Handlers;
with Gtk.Drawing_Area;
with Gtk.Radio_Button;
with Gtkada.Types;
with Gtk.Combo_Box_Text;
with LLM.User_Images;
with Gtk.Check_Menu_Item;
with Gtk.Clipboard;
with Gtk.GEntry;
with Gtk.Tree_Selection;
with System;
with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with Gtk.Container;
with Gtk.Dialog;
with Gtk.Enums;
with Gtk.Image;
with Gtk.Icon_Theme;
with Gtk.Main;
with Gtk.Label;
with Gtk.Menu_Item;
with Gtk.Progress_Bar;
with Gtk.Scrolled_Window;
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

   package Color_Signals is new Gtk.Handlers.Callback
     (Gtk.Color_Button.Gtk_Color_Button_Record);

   procedure Choose_Pencil_Color
     (Swatch : Gtk.Color_Button.Gtk_Color_Button;
      Color  : Gdk.RGBA.Gdk_RGBA)
   is
   begin
      Swatch.Set_Rgba (Color);
      Color_Signals.Emit_By_Name (Swatch, "color-set");
   end Choose_Pencil_Color;

   procedure Test_Canvas_Workspace (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
      use Gtk.Tree_Model;
      use type Gtk.Tree_Model.Gtk_Tree_Iter;
      use type Gdk.Pixbuf.Rgb_Record;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Canvas : Gtk.Window.Gtk_Window;
      Tree : Gtk.Tree_View.Gtk_Tree_View;
      Area : Gtk.Widget.Gtk_Widget;
      Model : Gtk_Tree_Model;
      Swatch : Gtk.Color_Button.Gtk_Color_Button;
      Pencil_Size : Gtk.Spin_Button.Gtk_Spin_Button;
      Eraser_Size : Gtk.Spin_Button.Gtk_Spin_Button;
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

      function Tool_Button
        (Name : String) return Gtk.Radio_Button.Gtk_Radio_Button
      is (Gtk.Radio_Button.Gtk_Radio_Button (Control ("canvas-tool-" & Name)));

      function Brush_Size
        (Name : String) return Gtk.Spin_Button.Gtk_Spin_Button is
        (Gtk.Spin_Button.Gtk_Spin_Button
           (Control ("canvas-" & Name & "-size")));

      procedure Check_Brush_Controls (Enabled : Boolean) is
      begin
         Assert (Pencil_Size.Get_Sensitive = Enabled and then
                   Eraser_Size.Get_Sensitive = Enabled,
                 "Brush sizes follow Canvas editing sensitivity");
      end Check_Brush_Controls;

      procedure Check_Icon (Name, Title : String) is
         use Interfaces.C.Strings;
         use type System.Address;
         Button : constant Gtk.Radio_Button.Gtk_Radio_Button :=
           Tool_Button (Name);
         Child : constant Gtk.Widget.Gtk_Widget :=
           Gtk.Bin.Get_Child (Gtk.Bin.Gtk_Bin (Button));
         function Accessible (Widget : System.Address) return System.Address
           with Import, Convention => C,
             External_Name => "gtk_widget_get_accessible";
         function Accessible_Name (Object : System.Address) return chars_ptr
           with Import, Convention => C, External_Name => "atk_object_get_name";
         Object : constant System.Address := Accessible (Button.Get_Object);
         Label  : chars_ptr;
      begin
         Assert (Child /= null and then Child.Get_Visible and then
                   Child.all in Gtk.Drawing_Area.Gtk_Drawing_Area_Record'Class,
                 "Toolbar displays an icon, not a text label: " & Title);
         Assert (Button.Get_Tooltip_Text = Title, "Tool tooltip: " & Title);
         Assert (Object /= System.Null_Address, "Accessible tool: " & Title);
         Label := Accessible_Name (Object);
         Assert (Label /= Null_Ptr and then Value (Label) = Title,
                 "Screen-reader tool name: " & Title);
      end Check_Icon;

      procedure Check_Tool (Expected : String; Enabled : Boolean := True) is
         procedure Check (Name : String) is
            Item : constant Gtk.Check_Menu_Item.Gtk_Check_Menu_Item :=
              Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
                (Control ("canvas-" & Name));
         begin
            Assert
              (Tool_Button (Name).Get_Active = (Name = Expected) and then
               Item.Get_Active = (Name = Expected),
               "Toolbar and Edit show only " & Expected & " active: " & Name);
            Assert
              (Tool_Button (Name).Get_Sensitive = Enabled and then
               Item.Get_Sensitive = Enabled,
               "Tool sensitivity matches in toolbar and Edit: " & Name);
         end Check;
      begin
         Check ("pencil");
         Check ("eraser");
         Check ("crop");
      end Check_Tool;

      procedure Press_Escape is
         Event : aliased Gdk.Event.Gdk_Event_Key :=
           (The_Type => Gdk.Event.Key_Press, Window => Canvas.Get_Window,
            Send_Event => 1, Time => 0, State => 0,
            Keyval => Gdk.Types.Keysyms.GDK_Escape, Length => 0,
            String => Gtkada.Types.Null_Ptr, Hardware_Keycode => 0,
            Group => 0, Is_Modifier => 0);
      begin
         Assert (Canvas.Event (Gdk.Event.To_Event (Event'Access)),
                 "Escape leaves the active zoom tool or pending crop");
      end Press_Escape;

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

      procedure Check_Fit (Pan_First : Boolean := False) is
         Scroll : constant Gtk.Scrolled_Window.Gtk_Scrolled_Window :=
           Gtk.Scrolled_Window.Gtk_Scrolled_Window
             (Control ("coyote-canvas-viewport"));
         X : constant Gtk.Adjustment.Gtk_Adjustment := Scroll.Get_Hadjustment;
         Y : constant Gtk.Adjustment.Gtk_Adjustment := Scroll.Get_Vadjustment;
      begin
         --  A crop panel can change the layout before the user opens View.
         Canvas.Check_Resize;
         Drain_Events;
         if Pan_First then
            Scroll.Set_Overlay_Scrolling (False);
            Activate ("zoom-in");
            Activate ("zoom-in");
            Canvas.Check_Resize;
            Drain_Events;
            X.Set_Value (X.Get_Upper);
            Y.Set_Value (Y.Get_Upper);
            Assert (X.Get_Value > X.Get_Lower and then
                      Y.Get_Value > Y.Get_Lower, "Pan before fitting");
         end if;
         Assert (Control ("canvas-fit").Get_Sensitive, "Can fit the drawing");
         Activate ("fit");
         Canvas.Check_Resize;
         Drain_Events;
         Area.Get_Size_Request (W, H);
         Assert (W <= Scroll.Get_Allocated_Width and then
                   H <= Scroll.Get_Allocated_Height and then
                   (W = Scroll.Get_Allocated_Width or else
                    H = Scroll.Get_Allocated_Height),
                 "Fit uses the full viewport and leaves no clipping:"
                 & W'Image & H'Image & " in"
                 & Scroll.Get_Allocated_Width'Image
                 & Scroll.Get_Allocated_Height'Image);
         Assert (abs (3 * W - 4 * H) <= 4,
                 "Fit preserves the 800 by 600 aspect ratio");
         Assert (X.Get_Value = X.Get_Lower and then Y.Get_Value = Y.Get_Lower
                   and then X.Get_Page_Size = X.Get_Upper
                   and then Y.Get_Page_Size = Y.Get_Upper,
                 "Fit returns to the origin and clears both scroll ranges");
      end Check_Fit;

      procedure Check_Pixel
        (Expected : Gdk.Pixbuf.Rgb_Record;
         X : Glib.Gint := 30;
         Y : Glib.Gint := 30;
         Tolerance : Natural := 0)
      is
         Surface : constant Cairo.Cairo_Surface := Cairo.Image_Surface.Create
           (Cairo.Image_Surface.Cairo_Format_RGB24, 64, 64);
         Context : constant Cairo.Cairo_Context := Cairo.Create (Surface);
         Sample  : Gdk.Pixbuf.Gdk_Pixbuf;
         Actual  : Gdk.Pixbuf.Rgb_Record;
      begin
         Canvas.Check_Resize;
         Drain_Events;
         Area.Draw (Context);
         Cairo.Destroy (Context);
         Sample := Gdk.Pixbuf.Get_From_Surface (Surface, X, Y, 1, 1);
         Actual := Gdk.Pixbuf.Get_Pixels (Sample) (0);
         Sample.Unref;
         Cairo.Surface_Destroy (Surface);
         Assert (abs (Integer (Actual.Red) - Integer (Expected.Red)) <=
                   Tolerance and then
                 abs (Integer (Actual.Green) - Integer (Expected.Green)) <=
                   Tolerance and then
                 abs (Integer (Actual.Blue) - Integer (Expected.Blue)) <=
                   Tolerance,
                 "Canvas pixel at" & X'Image & Y'Image & ": expected red"
                 & Expected.Red'Image & ", got" & Actual.Red'Image);
      end Check_Pixel;

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
      procedure Motion (X, Y : Glib.Gdouble) is
         Raw : aliased Gdk.Event.Gdk_Event_Motion :=
           (The_Type => Gdk.Event.Motion_Notify, Window => Area.Get_Window,
            Send_Event => 1, Time => 0, X => X, Y => Y, Axes => null,
            State => Gdk.Types.Button1_Mask, Is_Hint => 0,
            Device => System.Null_Address, X_Root => X, Y_Root => Y);
      begin
         Assert (Area.Event (Gdk.Event.From_Address (Raw'Address)),
                 "Canvas did not handle pointer motion");
      end Motion;

      procedure Tap_Zoom (X, Y : Glib.Gdouble) is
         Raw : aliased Gdk.Event.Gdk_Event_Button :=
           (The_Type => Gdk.Event.Button_Release, Window => Area.Get_Window,
            Send_Event => 1, Time => 0, X => X, Y => Y, Axes => null,
            State => 0, Button => 1, Device => System.Null_Address,
            X_Root => X, Y_Root => Y);
      begin
         Pointer (Gdk.Event.Button_Press, X, Y);
         Assert (not Area.Event (Gdk.Event.To_Event (Raw'Access)),
                 "Zoom does not start a stroke or crop drag");
         Canvas.Check_Resize;
         Drain_Events;
      end Tap_Zoom;

      procedure Check_Zoom_Clicks is
         Scroll : constant Gtk.Scrolled_Window.Gtk_Scrolled_Window :=
           Gtk.Scrolled_Window.Gtk_Scrolled_Window
             (Control ("coyote-canvas-viewport"));
         X : constant Gtk.Adjustment.Gtk_Adjustment := Scroll.Get_Hadjustment;
         Y : constant Gtk.Adjustment.Gtk_Adjustment := Scroll.Get_Vadjustment;
      begin
         Scroll.Set_Overlay_Scrolling (False);
         Activate ("zoom-in");
         Activate ("zoom-in");
         Canvas.Check_Resize;
         Drain_Events;
         Size (1250, 938);
         X.Set_Value (100.0);
         Y.Set_Value (120.0);
         Tool_Button ("zoom-in").Clicked;
         Assert (Tool_Button ("zoom-in").Get_Active and then
                   not Tool_Button ("pencil").Get_Active,
                 "The magnifier is the only active toolbar tool");
         Size (1250, 938);
         Tap_Zoom (300.0, 320.0);
         Size (1563, 1172);
         Assert (abs (X.Get_Value - 175.0) < 1.0 and then
                   abs (Y.Get_Value - 200.0) < 1.0,
                 "Zoom In retains the tapped point in a scrolled view: "
                 & X.Get_Value'Image & Y.Get_Value'Image);
         Tool_Button ("zoom-in").Grab_Focus;
         Assert (Tool_Button ("zoom-in").Child_Focus (Gtk.Enums.Dir_Right)
                   and then Tool_Button ("zoom-out").Get_Active,
                 "Arrow navigation reaches the Zoom Out magnifier");
         Tap_Zoom (375.0, 400.0);
         Size (1250, 938);
         Assert (abs (X.Get_Value - 100.0) < 1.0 and then
                   abs (Y.Get_Value - 120.0) < 1.0,
                 "Zoom Out retains the same tapped point");
         Press_Escape;
         Check_Tool ("pencil");
         Size (1250, 938);
         Activate ("fit");
         Canvas.Check_Resize;
         Drain_Events;
         Activate ("actual");
         Size (800, 600);
      end Check_Zoom_Clicks;

      procedure Check_Stylus_Input is
         use Interfaces.C.Strings;
         use type System.Address;
         Scroll : constant Gtk.Scrolled_Window.Gtk_Scrolled_Window :=
           Gtk.Scrolled_Window.Gtk_Scrolled_Window
             (Control ("coyote-canvas-viewport"));
         X : constant Gtk.Adjustment.Gtk_Adjustment := Scroll.Get_Hadjustment;
         Y : constant Gtk.Adjustment.Gtk_Adjustment := Scroll.Get_Vadjustment;
         Display : constant Gdk.Display.Gdk_Display := Area.Get_Display;
         Seat : constant Gdk.Seat.Gdk_Seat := Gdk.Seat.Gdk_Seat
           (Display.Get_Default_Seat);
         Mouse : constant Gdk.Device.Gdk_Device :=
           Gdk.Device.Gdk_Device (Seat.Get_Pointer);
         Focus : constant Gtk.Widget.Gtk_Widget := Canvas.Get_Focus;
         Pen : System.Address := System.Null_Address;
         Tip_Eraser : System.Address := System.Null_Address;
         Saved_Axis : constant Gdk.Types.Gdk_Axis_Use := Mouse.Get_Axis_Use (0);

         function New_Device
           (Typ : Glib.GType; Count : Glib.Guint; Names, Values : System.Address)
            return System.Address
           with Import, Convention => C,
             External_Name => "g_object_new_with_properties";
         function Source_Type return Glib.GType
           with Import, Convention => C,
             External_Name => "gdk_input_source_get_type";
         procedure Unref_Device (Device : System.Address)
           with Import, Convention => C, External_Name => "g_object_unref";

         function Test_Device (Source : Gdk.Types.Gdk_Input_Source)
           return System.Address
         is
            type Property_Names is array (1 .. 3) of chars_ptr;
            Names : Property_Names :=
              (New_String ("display"), New_String ("name"),
               New_String ("input-source"));
            Values : Glib.Values.GValue_Array (1 .. 3);
            Result : System.Address;
         begin
            --  Construct a separate device of the backend's concrete type.
            Glib.Values.Init (Values (1), Gdk.Display.Get_Type);
            Glib.Values.Set_Object (Values (1), Display);
            Glib.Values.Init_Set_String (Values (2), "Canvas test pen");
            Glib.Values.Init (Values (3), Source_Type);
            Glib.Values.Set_Enum
              (Values (3), Gdk.Types.Gdk_Input_Source'Pos (Source));
            Result := New_Device
              (Glib.Object.Get_Type (Glib.Object.GObject (Mouse)),
               3, Names'Address, Values'Address);
            for Value of Values loop
               Glib.Values.Unset (Value);
            end loop;
            for Name of Names loop
               Free (Name);
            end loop;
            return Result;
         end Test_Device;

         procedure Send_Button
           (Kind : Gdk.Event.Gdk_Event_Type; Button : Glib.Guint;
            At_X, At_Y : Glib.Gdouble; Source : System.Address;
            Pressure : Glib.Gdouble := -1.0; Expected : Boolean := True)
         is
            function New_Event (Event_Kind : Gdk.Event.Gdk_Event_Type)
              return Gdk.Event.Gdk_Event
              with Import, Convention => C, External_Name => "gdk_event_new";
            procedure Set_Source
              (Event : Gdk.Event.Gdk_Event; Device : System.Address)
              with Import, Convention => C,
                External_Name => "gdk_event_set_source_device";
            Event : constant Gdk.Event.Gdk_Event := New_Event (Kind);
            Raw : Gdk.Event.Gdk_Event_Button
              with Import, Address => Gdk.Event.To_Address (Event);
            Axes : array (0 .. Mouse.Get_N_Axes - 1) of aliased Glib.Gdouble :=
              (0 => Pressure, others => 0.0);
            Handled : Boolean;
         begin
            Gdk.Window.Ref (Area.Get_Window);
            Raw := (The_Type => Kind, Window => Area.Get_Window,
                    Send_Event => 1, Time => 0, X => At_X, Y => At_Y,
                    Axes => null, State => 0, Button => Button,
                    Device => Mouse.Get_Object, X_Root => At_X, Y_Root => At_Y);
            Gdk.Device.Set_Device (Event, Mouse);
            Set_Source (Event, Source);
            if Pressure >= 0.0 then
               --  GDK reads the supplied axes using the event device's
               --  local axis mapping; the X server is not changed.
               Mouse.Set_Axis_Use (0, Gdk.Types.Axis_Pressure);
               Raw.Axes := Axes (0)'Unchecked_Access;
            end if;
            Handled := Area.Event (Event);
            Mouse.Set_Axis_Use (0, Saved_Axis);
            Raw.Axes := null;
            Gdk.Event.Free (Event);
            Assert (Handled = Expected, "Canvas handles the expected input");
         exception
            when others =>
               Mouse.Set_Axis_Use (0, Saved_Axis);
               raise;
         end Send_Button;

         procedure Side_Button
           (Kind : Gdk.Event.Gdk_Event_Type; Button : Glib.Guint;
            At_X, At_Y : Glib.Gdouble; Use_Pen : Boolean := True)
         is
         begin
            Send_Button (Kind, Button, At_X, At_Y,
                         (if Use_Pen then Pen else Mouse.Get_Object),
                         Expected => Use_Pen);
         end Side_Button;
      begin
         Pen := Test_Device (Gdk.Types.Source_Pen);
         Assert (Pen /= System.Null_Address, "Created test pen source");
         Activate ("zoom-in");
         Activate ("zoom-in");
         Canvas.Check_Resize;
         Drain_Events;
         X.Set_Value (100.0);
         Y.Set_Value (120.0);
         Side_Button (Gdk.Event.Button_Press, 2, 300.0, 320.0,
                      Use_Pen => False);
         Side_Button (Gdk.Event.Button_Press, 3, 300.0, 320.0,
                      Use_Pen => False);
         Side_Button (Gdk.Event.Button_Press, 2, -1.0, 320.0);
         Size (1250, 938);
         Side_Button (Gdk.Event.Button_Press, 2, 300.0, 320.0);
         Side_Button (Gdk.Event.Double_Button_Press, 2, 300.0, 320.0);
         Side_Button (Gdk.Event.Button_Release, 2, 300.0, 320.0);
         Canvas.Check_Resize;
         Drain_Events;
         Size (1563, 1172);
         Assert (abs (X.Get_Value - 175.0) < 1.0 and then
                 abs (Y.Get_Value - 200.0) < 1.0,
                 "Pen zoom-in preserves the panned anchor in one step");
         Side_Button (Gdk.Event.Button_Press, 3, 375.0, 400.0);
         Side_Button (Gdk.Event.Button_Release, 3, 300.0, 320.0);
         Canvas.Check_Resize;
         Drain_Events;
         Size (1250, 938);
         Assert (abs (X.Get_Value - 100.0) < 1.0 and then
                 abs (Y.Get_Value - 120.0) < 1.0 and then
                 Canvas.Get_Focus = Focus,
                 "Pen zoom-out preserves the anchor and keyboard focus");
         Check_Tool ("pencil");
         Activate ("actual");
         Canvas.Check_Resize;
         Drain_Events;
         Pointer (Gdk.Event.Button_Press, 30.0, 30.0);
         Side_Button (Gdk.Event.Button_Press, 2, 30.0, 30.0);
         Side_Button (Gdk.Event.Button_Release, 2, 30.0, 30.0);
         Size (800, 600);
         Assert (not Control ("canvas-fit").Get_Sensitive,
                 "Side buttons do not end an active stroke");
         Press_Escape;
         Activate ("crop");
         Pointer (Gdk.Event.Button_Press, 40.0, 50.0);
         Side_Button (Gdk.Event.Button_Press, 2, 40.0, 50.0);
         Side_Button (Gdk.Event.Button_Release, 2, 40.0, 50.0);
         Size (800, 600);
         Pointer (Gdk.Event.Button_Release, 100.0, 130.0);
         Side_Button (Gdk.Event.Button_Press, 2, 40.0, 50.0);
         Side_Button (Gdk.Event.Button_Release, 2, 40.0, 50.0);
         Canvas.Check_Resize;
         Drain_Events;
         Size (1000, 750);
         Check_Tool ("crop");
         Assert (Control ("canvas-apply").Get_Sensitive and then
                 Gtk.GEntry.Gtk_Entry
                   (Control ("coyote-canvas-crop-width")).Get_Text = "60" and then
                 Gtk.GEntry.Gtk_Entry
                   (Control ("coyote-canvas-crop-height")).Get_Text = "80",
                 "Pen zoom leaves the pending crop in source coordinates");
         Press_Escape;
         Activate ("actual");
         Size (800, 600);

         Pencil_Size.Set_Value (9.0);
         Send_Button (Gdk.Event.Button_Press, 1, 48.0, 48.0, Pen, 0.0);
         Check_Pixel ((255, 255, 255), 48, 48);
         Send_Button (Gdk.Event.Button_Release, 1, 48.0, 48.0, Pen);
         Send_Button (Gdk.Event.Button_Press, 1, 48.0, 48.0, Pen, 0.5);
         Check_Pixel ((134, 134, 134), 51, 48, Tolerance => 1);
         Send_Button (Gdk.Event.Button_Release, 1, 48.0, 48.0, Pen);
         Check_Pixel ((134, 134, 134), 51, 48, Tolerance => 1);
         Activate ("undo");
         Check_Pixel ((255, 255, 255), 51, 48);
         Send_Button (Gdk.Event.Button_Press, 1, 48.0, 48.0, Pen, 1.0);
         Check_Pixel ((13, 13, 13), 51, 48);
         Press_Escape;
         Send_Button (Gdk.Event.Button_Press, 1, 48.0, 48.0, Pen);
         Check_Pixel ((13, 13, 13), 51, 48);
         Press_Escape;
         Pencil_Size.Set_Value (3.0);

         Tip_Eraser := Test_Device (Gdk.Types.Source_Eraser);
         Eraser_Size.Set_Value (40.0);
         Send_Button (Gdk.Event.Button_Press, 1, 47.0, 30.0, Tip_Eraser);
         Check_Pixel ((255, 255, 255));
         Send_Button (Gdk.Event.Button_Release, 1, 47.0, 30.0, Tip_Eraser);
         Check_Pixel ((255, 255, 255));
         Check_Tool ("pencil");
         Activate ("undo");
         Check_Pixel ((13, 13, 13));
         Eraser_Size.Set_Value (16.0);
         Unref_Device (Tip_Eraser);
         Unref_Device (Pen);
      exception
         when others =>
            if Tip_Eraser /= System.Null_Address then
               Unref_Device (Tip_Eraser);
            end if;
            if Pen /= System.Null_Address then
               Unref_Device (Pen);
            end if;
            raise;
      end Check_Stylus_Input;
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
      Assert (Control ("coyote-canvas-toolbar").Get_Visible,
              "Canvas displays a tool strip");
      Check_Icon ("pencil", "Pencil");
      Check_Icon ("eraser", "Eraser");
      Check_Icon ("crop", "Crop");
      Check_Icon ("zoom-in", "Zoom In");
      Check_Icon ("zoom-out", "Zoom Out");
      Swatch := Gtk.Color_Button.Gtk_Color_Button
        (Control ("canvas-pencil-color"));
      Pencil_Size := Brush_Size ("pencil");
      Eraser_Size := Brush_Size ("eraser");
      Assert (Pencil_Size.Get_Value_As_Int = 3 and then
                Eraser_Size.Get_Value_As_Int = 16,
              "Pencil and Eraser have independent default sizes");
      Check_Brush_Controls (Enabled => False);
      Assert (not Swatch.Get_Sensitive and then not Swatch.Get_Use_Alpha
              and then Swatch.Get_Tooltip_Text = "Pencil color",
              "Opaque Pencil color is unavailable on an empty Canvas");
      Assert (not Tool_Button ("zoom-in").Get_Sensitive and then
                not Tool_Button ("zoom-out").Get_Sensitive,
              "Magnifiers are disabled without a drawing");
      Assert (not Control ("canvas-fit").Get_Sensitive,
              "Fit is disabled without a drawing");
      Check_Tool ("pencil", Enabled => False);
      Activate ("new");
      Drain_Events;
      Check_Tool ("pencil");
      Check_Brush_Controls (Enabled => True);
      Assert
        (Control ("coyote-canvas-toolbar").Child_Focus
           (Gtk.Enums.Dir_Tab_Forward) and then
         Canvas.Get_Focus = Gtk.Widget.Gtk_Widget (Tool_Button ("pencil")),
         "Tab enters the tool group at the selected tool");
      Assert (Tool_Button ("pencil").Child_Focus (Gtk.Enums.Dir_Right),
              "Right arrow navigates the tool group");
      Check_Tool ("eraser");
      Assert (Tool_Button ("eraser").Child_Focus (Gtk.Enums.Dir_Left),
              "Left arrow returns to Pencil");
      Check_Tool ("pencil");
      Assert (Control ("coyote-canvas-toolbar").Child_Focus
                (Gtk.Enums.Dir_Tab_Forward) and then
                Canvas.Get_Focus = Gtk.Widget.Gtk_Widget (Swatch),
              "Tab from the tool group reaches the color swatch");
      Assert (Swatch.Get_Sensitive, "Pencil color is available on a drawing");
      Assert (Control ("coyote-canvas-toolbar").Child_Focus
                (Gtk.Enums.Dir_Tab_Forward) and then
                Canvas.Get_Focus = Gtk.Widget.Gtk_Widget (Pencil_Size),
              "Tab from the color swatch reaches Pencil size");
      Assert (Control ("coyote-canvas-toolbar").Child_Focus
                (Gtk.Enums.Dir_Tab_Forward) and then
                Canvas.Get_Focus = Gtk.Widget.Gtk_Widget (Eraser_Size),
              "Tab from Pencil size reaches Eraser size");
      Choose_Pencil_Color (Swatch, (1.0, 0.0, 0.0, 1.0));
      Check_Tool ("pencil");
      Pencil_Size.Set_Value (9.0);
      Eraser_Size.Set_Value (24.0);
      Assert (Pencil_Size.Get_Value_As_Int = 9 and then
                Eraser_Size.Get_Value_As_Int = 24,
              "Pencil and Eraser size changes remain independent");
      Pencil_Size.Set_Value (3.0);
      Eraser_Size.Set_Value (16.0);
      Assert (not Control ("canvas-save").Get_Sensitive
              and then not Control ("canvas-undo").Get_Sensitive,
              "Choosing a color is not a drawing edit");
      Size (800, 600);
      Assert (Get_Iter_From_String (Model, "0") /= Null_Iter,
              "New creates an Original");
      Check_Pixel ((255, 255, 255));
      Pointer (Gdk.Event.Button_Press, 30.0, 30.0);
      Assert (not Control ("canvas-fit").Get_Sensitive and then
                not Tool_Button ("zoom-in").Get_Sensitive and then
                not Control ("canvas-zoom-out").Get_Sensitive,
              "No zoom control can interrupt an ink gesture");
      Assert (not Swatch.Get_Sensitive,
              "Pencil color cannot change during a stroke");
      Check_Brush_Controls (Enabled => False);
      Activate ("fit");
      Size (800, 600);
      Check_Pixel ((255, 0, 0));
      Choose_Pencil_Color (Swatch, (0.0, 0.0, 1.0, 1.0));
      Pointer (Gdk.Event.Button_Release, 30.0, 30.0);
      Check_Pixel ((255, 0, 0));
      Check_Brush_Controls (Enabled => True);
      Choose_Pencil_Color
        (Swatch, (13.0 / 255.0, 13.0 / 255.0, 13.0 / 255.0, 1.0));
      Check_Pixel ((255, 0, 0));
      Activate ("undo");
      Check_Pixel ((255, 255, 255));
      Activate ("redo");
      Check_Pixel ((255, 0, 0));
      Activate ("undo");
      Pencil_Size.Set_Value (9.0);
      Pointer (Gdk.Event.Button_Press, 30.0, 30.0);
      Assert (not Pencil_Size.Get_Sensitive and then
                Pencil_Size.Get_Value_As_Int = 9,
              "Active stroke retains its snapshotted Pencil width");
      Check_Pixel ((13, 13, 13), 33, 30);
      Pointer (Gdk.Event.Button_Release, 30.0, 30.0);
      Check_Pixel ((13, 13, 13), 33, 30);
      Activate ("undo");
      Check_Pixel ((255, 255, 255), 33, 30);
      Activate ("redo");
      Check_Pixel ((13, 13, 13), 33, 30);
      Activate ("undo");
      Pencil_Size.Set_Value (3.0);
      Pointer (Gdk.Event.Button_Press, 30.0, 30.0);
      Assert (not Pencil_Size.Get_Sensitive and then
                Pencil_Size.Get_Value_As_Int = 3,
              "Next Pencil stroke snapshots the updated width");
      Press_Escape;
      Assert (Pencil_Size.Get_Sensitive,
              "Canceling a stroke unlocks its brush-size control");
      Pointer (Gdk.Event.Button_Press, 30.0, 30.0);
      Pointer (Gdk.Event.Button_Release, 30.0, 30.0);
      Check_Pixel ((13, 13, 13));
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Control ("canvas-markup")).Set_Active (False);
      Check_Tool ("pencil", Enabled => False);
      Check_Pixel ((255, 255, 255));
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Control ("canvas-markup")).Set_Active (True);
      Check_Pixel ((13, 13, 13));
      Tool_Button ("eraser").Clicked;
      Check_Tool ("eraser");
      Assert (Gtk.Label.Get_Text (Gtk.Label.Gtk_Label
                (Control ("coyote-canvas-tool"))) = "Tool: Eraser",
              "eraser mode is indicated in text");
      Pointer (Gdk.Event.Button_Press, 15.0, 30.0);
      Assert (not Control ("canvas-attach-button").Get_Sensitive and then
                not Control ("canvas-attach").Get_Sensitive and then
                not Control ("canvas-save").Get_Sensitive,
              "Save and Attach stay unavailable during an erase gesture");
      Check_Brush_Controls (Enabled => False);
      Motion (30.0, 30.0);
      Check_Pixel ((255, 255, 255));
      Motion (40.0, 30.0);
      Check_Pixel ((255, 255, 255));
      Assert (Get_Iter_From_String (Model, "0:0") = Null_Iter,
              "Live erasure is not published as a revision");
      Pointer (Gdk.Event.Button_Release, 45.0, 30.0);
      Check_Pixel ((255, 255, 255));
      Check_Brush_Controls (Enabled => True);
      Activate ("undo");
      Check_Pixel ((13, 13, 13));
      Activate ("redo");
      Check_Pixel ((255, 255, 255));
      Activate ("undo");
      Activate ("pencil");
      Check_Tool ("pencil");
      Check_Pixel ((13, 13, 13));
      Check_Zoom_Clicks;
      Check_Stylus_Input;
      Check_Pixel ((13, 13, 13));
      Check_Fit (Pan_First => True);
      Activate ("actual");
      Size (800, 600);
      Check_Pixel ((13, 13, 13));
      Activate ("save");
      Assert (Get_Iter_From_String (Model, "0:0") /= Null_Iter,
              "Pointer stroke saves as a child of Original");

      Activate ("eraser");
      Pointer (Gdk.Event.Button_Press, 15.0, 30.0);
      Motion (30.0, 30.0);
      Check_Pixel ((255, 255, 255));
      Press_Escape;
      Check_Pixel ((13, 13, 13));
      Assert (Get_Iter_From_String (Model, "0:0:0") = Null_Iter,
              "Canceled erasure restores ink without saving a revision");

      Activate ("eraser");
      Check_Tool ("eraser");
      Tool_Button ("crop").Clicked;
      Check_Tool ("crop");
      Pointer (Gdk.Event.Button_Press, 40.0, 50.0);
      Assert (not Control ("canvas-fit").Get_Sensitive and then
                not Tool_Button ("zoom-out").Get_Sensitive,
              "No zoom control can interrupt a crop drag");
      Check_Brush_Controls (Enabled => False);
      Pointer (Gdk.Event.Button_Release, 100.0, 130.0);
      Tool_Button ("zoom-in").Clicked;
      Tap_Zoom (60.0, 70.0);
      Activate ("crop");
      Check_Tool ("crop");
      Assert (Control ("canvas-apply").Get_Sensitive and then
                not Control ("canvas-attach").Get_Sensitive,
              "Returning to Crop through Edit preserves its pending bounds");
      Check_Fit;
      Check_Tool ("crop");
      Assert (Control ("canvas-apply").Get_Sensitive,
              "Fit preserves the pending crop and Apply eligibility");
      Activate ("apply");
      Check_Tool ("eraser");
      Activate ("actual");
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
      Tool_Button ("pencil").Clicked;
      Check_Tool ("pencil");
      Assert (not Control ("canvas-apply-button").Is_Visible,
              "Switching tools closes the pending crop controls");
      Size (60, 80);

      Activate ("eraser");
      Activate ("crop");
      Check_Tool ("crop");
      Assert (not Control ("canvas-apply").Get_Sensitive,
              "Crop starts with fresh bounds after switching tools");
      Pointer (Gdk.Event.Button_Press, 4.0, 7.0);
      Pointer (Gdk.Event.Button_Release, 19.0, 29.0);
      Press_Escape;
      Check_Tool ("eraser");
      Size (60, 80);
      Activate ("crop");
      Activate ("cancel");
      Check_Tool ("eraser");
      Size (60, 80);
      Activate ("save");
      Assert (Get_Iter_From_String (Model, "0:0:0") /= Null_Iter,
              "Only the applied crop was checkpointed");

      Activate ("crop");
      Pointer (Gdk.Event.Button_Press, 3.0, 4.0);
      Pointer (Gdk.Event.Button_Release, 19.0, 24.0);
      Activate ("apply");
      Size (16, 20);
      Activate ("crop");
      Tree.Get_Selection.Select_Iter (Get_Iter_From_String (Model, "0"));
      Check_Tool ("eraser");
      Assert (not Control ("canvas-apply-button").Is_Visible,
              "Selecting a revision cancels the previous pending crop");
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Control ("canvas-markup")).Set_Active (False);
      Check_Tool ("eraser", Enabled => False);
      Check_Brush_Controls (Enabled => False);
      Canvas.Set_Focus (null);
      Assert (Control ("coyote-canvas-toolbar").Child_Focus
                (Gtk.Enums.Dir_Tab_Forward) and then
                Canvas.Get_Focus = Gtk.Widget.Gtk_Widget
                  (Tool_Button ("zoom-in")) and then
                not Tool_Button ("zoom-in").Get_Active,
              "Tab reaches an enabled magnifier without selecting it");
      Tool_Button ("zoom-in").Clicked;
      Tap_Zoom (50.0, 75.0);
      Size (1000, 750);
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Control ("canvas-markup")).Set_Active (False);
      Tool_Button ("zoom-out").Clicked;
      Tap_Zoom (62.5, 93.75);
      Size (800, 600);
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Control ("canvas-markup")).Set_Active (True);
      Press_Escape;
      Check_Brush_Controls (Enabled => True);
      Check_Fit;
      Check_Tool ("eraser");
      Activate ("actual");
      Size (800, 600);
      Check_Pixel ((255, 255, 255));
      Activate ("pencil");
      Pointer (Gdk.Event.Button_Press, 30.0, 30.0);
      Press_Escape;
      Check_Pixel ((255, 255, 255));
      Assert (Get_Iter_From_String (Model, "0:0:0:0") = Null_Iter,
              "Browsing, zoom and canceled ink don't checkpoint a draft");
      Activate ("draft");
      Size (16, 20);
      Tree.Get_Selection.Unselect_All;
      Tree.Get_Selection.Select_Iter (Get_Iter_From_String (Model, "0"));
      Pointer (Gdk.Event.Button_Press, 30.0, 30.0);
      Pointer (Gdk.Event.Button_Release, 30.0, 30.0);
      Check_Pixel ((13, 13, 13));
      Assert (Get_Iter_From_String (Model, "0:0:0:0") /= Null_Iter and then
                Get_Iter_From_String (Model, "0:1") = Null_Iter,
              "Direct ink checkpoints only the previous dirty draft");
      Activate ("undo");
      Check_Pixel ((255, 255, 255));
      Activate ("redo");
      Check_Pixel ((13, 13, 13));
      Activate ("save");
      Activate ("save");
      Assert (Get_Iter_From_String (Model, "0:1") /= Null_Iter and then
                Get_Iter_From_String (Model, "0:1:0") = Null_Iter,
              "Save creates exactly one child of the selected Original");
      Tree.Get_Selection.Unselect_All;
      Tree.Get_Selection.Select_Iter (Get_Iter_From_String (Model, "0"));
      Check_Pixel ((255, 255, 255));
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
      Check_Tool ("pencil", Enabled => False);
      Check_Brush_Controls (Enabled => False);
      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
      Assert (Canvas_Window (Frontend) = null,
              "Destroying the conversation tears down its Canvas");
   exception
      when others =>
         if Main_Window (Frontend) /= null then
            Frontend.Request_Shutdown;
            Main_Window (Frontend).Destroy;
         end if;
         raise;
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
              "Imported clipboard image has an immutable Original");
      Gtk.Tree_View.Get_Selection (Tree).Select_Iter (Row);
      Drain_Events;
      Area.Get_Size_Request (Width, Height);
      Assert (Width = 37 and then Height = 23,
              "Selecting clipboard image shows native dimensions");
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
      use Gtk.Enums.String_SList;
      use type Glib.Error.GError;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Canvas   : Gtk.Window.Gtk_Window;
      Tree     : Gtk.Tree_View.Gtk_Tree_View;
      Model    : Gtk_Tree_Model;
      Area     : Gtk.Widget.Gtk_Widget;
      Folder   : Unbounded_String;
      Paths    : array (1 .. 3) of Unbounded_String;

      function Make_Temp_Directory
        (Template : System.Address) return System.Address
        with Import, Convention => C, External_Name => "mkdtemp";
      W, H     : Glib.Gint;
      Selected_Count : Glib.Gint;
      Draft_Sensitive : Boolean;

      function Control (Name : String) return Gtk.Widget.Gtk_Widget is
        (Find_Canvas_Widget (Gtk.Widget.Gtk_Widget (Canvas), Name));

      procedure Write_Fixture (Index : Positive; Content : String) is
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create
           (File, Ada.Text_IO.Out_File, To_String (Paths (Index)));
         Ada.Text_IO.Put (File, Content);
         Ada.Text_IO.Close (File);
      end Write_Fixture;

      procedure Choose (First_Path : String; File_Count : Positive) is
         Top      : Gtk.Window.Gtk_Window;
         Chooser  : Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog;
         Deadline : constant Time := Clock + Seconds (3);
      begin
         Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-import")).Activate;
         Top := Canvas_Toplevel ("coyote-canvas-file-selection");
         Assert (Top /= null and then not Top.Get_Modal,
                 "Import opens a modeless File Selection");
         Chooser := Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog (Top);
         Assert (Chooser.Get_Select_Multiple,
                 "File Selection permits multiple files");
         Assert (Chooser.Select_Filename (First_Path),
                 "GTK selects the first fixture");
         Await_First : loop
            Drain_Events;
            exit Await_First when Chooser.Get_Filename = First_Path;
            Assert (Clock < Deadline, "First file did not resolve");
            delay 0.01;
         end loop Await_First;
         if File_Count > 1 then
            Chooser.Select_All;
         end if;
         declare
            Files : GSlist := Chooser.Get_Filenames;
            Selected : constant Glib.Guint := Length (Files);
         begin
            Gtk.Enums.Free_String_List (Files);
            Assert (Selected = Glib.Guint (File_Count),
                    "All fixture files selected");
         end;
         Gtk.Dialog.Gtk_Dialog (Chooser).Response (Gtk.Dialog.Gtk_Response_OK);
      end Choose;

      procedure Check_Original (Index : Positive; Width, Height : Glib.Gint) is
         Iter  : constant Gtk_Tree_Iter :=
           Nth_Child (Model, Null_Iter, Glib.Gint (Index - 1));
         Label : Glib.Values.GValue;
      begin
         Assert (Iter /= Null_Iter, "Missing imported Original row");
         Get_Value (Model, Iter, 0, Label);
         declare
            Value : constant String := Glib.Values.Get_String (Label);
         begin
            Glib.Values.Unset (Label);
            Assert
              (Value'Length >= 14 and then Value (1 .. 14) = "Imported Image",
               "Batch row is an imported Original");
         end;
         Tree.Get_Selection.Unselect_All;
         Tree.Get_Selection.Select_Iter (Iter);
         Area.Get_Size_Request (W, H);
         Assert (W = Width and then H = Height,
                 "Imported Original retains its native dimensions");
      end Check_Original;

      procedure Write_Large_PNG (Path : String) is
         use type Interfaces.Unsigned_32;
         use type Ada.Directories.File_Size;
         Side : constant := 1_800;
         Image : constant Gdk.Pixbuf.Gdk_Pixbuf :=
           Gdk.Pixbuf.Gdk_New (Has_Alpha => False, Width => Side,
                               Height => Side);
         Pixels : constant Gdk.Pixbuf.Rgb_Buffer_Access :=
           Gdk.Pixbuf.Get_Pixels (Image);
         State : Interfaces.Unsigned_32 := 16#C022_2F15#;
         Error : Glib.Error.GError;
      begin
         --  The RGB rows have no padding at this width.
         for I in Glib.Guint range 0 .. Side * Side - 1 loop
            State := State xor Interfaces.Shift_Left (State, 13);
            State := State xor Interfaces.Shift_Right (State, 17);
            State := State xor Interfaces.Shift_Left (State, 5);
            Pixels (I) :=
              (Red => Glib.Guchar (State and 255),
               Green => Glib.Guchar (Interfaces.Shift_Right (State, 8)
                                     and 255),
               Blue => Glib.Guchar (Interfaces.Shift_Right (State, 16)
                                    and 255));
         end loop;
         Gdk.Pixbuf.Save (Image, Path, Gdk.Pixbuf.PNG, Error);
         Image.Unref;
         Assert (Error = null, "Generated high-entropy PNG fixture");
         Assert (Ada.Directories.Size (Path) > 8 * 1_024 * 1_024,
                 "PNG exceeds the previous encoded-byte cap");
      end Write_Large_PNG;

      procedure Read_Import_Error is
         Dialog   : Gtk.Window.Gtk_Window := null;
         Deadline : constant Time := Clock + Seconds (3);
      begin
         Poll : loop
            Drain_Events;
            Dialog := Canvas_Toplevel ("coyote-canvas-import-error");
            exit Poll when Dialog /= null;
            Assert (Clock < Deadline, "Invalid batch did not report an error");
            delay 0.01;
         end loop Poll;
         Gtk.Dialog.Gtk_Dialog (Dialog).Response (Gtk.Dialog.Gtk_Response_Close);
      end Read_Import_Error;
   begin
      if not T.Display_Available then
         return;
      end if;
      declare
         use type System.Address;
         Template : String := "/tmp/coyote-canvas-batch-XXXXXX" & ASCII.NUL;
         Found : constant System.Address := Make_Temp_Directory (Template'Address);
      begin
         Assert (Found /= System.Null_Address, "Made private fixture folder");
         Folder := To_Unbounded_String (Template (1 .. Template'Last - 1));
      end;
      Paths (1) := Folder & "/a.svg";
      Paths (2) := Folder & "/b.jpeg";
      Paths (3) := Folder & "/z-invalid";
      Write_Fixture
        (1, "<svg xmlns=""http://www.w3.org/2000/svg"" "
         & "width=""31"" height=""17"" viewBox=""0 0 31 17"">"
         & "<rect width=""31"" height=""17"" fill=""red""/>"
         & "</svg>");
      declare
         Image : constant Gdk.Pixbuf.Gdk_Pixbuf :=
           Gdk.Pixbuf.Gdk_New (Width => 675, Height => 44);
         Error : Glib.Error.GError;
      begin
         Gdk.Pixbuf.Fill (Image, 16#336699FF#);
         Gdk.Pixbuf.Save (Image, To_String (Paths (2)), Gdk.Pixbuf.JPEG, Error);
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
      Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-new")).Activate;
      Selected_Count := Tree.Get_Selection.Count_Selected_Rows;
      Draft_Sensitive := Control ("canvas-draft").Get_Sensitive;

      Choose (To_String (Paths (1)), 2);
      Finish_Canvas_Jobs;
      Assert (N_Children (Model) = 3,
              "Batch import adds two Originals beside the working copy");
      Assert
        (Tree.Get_Selection.Count_Selected_Rows = Selected_Count
         and then Control ("canvas-draft").Get_Sensitive = Draft_Sensitive,
         "Batch import leaves draft and selection unchanged");
      Area.Get_Size_Request (W, H);
      Assert (W = 800 and then H = 600, "Batch leaves the displayed draft");
      Check_Original (2, 31, 17);
      Check_Original (3, 675, 44);

      Tree.Get_Selection.Unselect_All;
      Selected_Count := Tree.Get_Selection.Count_Selected_Rows;
      Draft_Sensitive := Control ("canvas-draft").Get_Sensitive;
      Write_Fixture (3, "not an image");
      Choose (To_String (Paths (1)), 3);
      Finish_Canvas_Jobs;
      Read_Import_Error;
      Assert (N_Children (Model) = 3,
              "Failed batch adds no partial Original");
      Assert
        (Tree.Get_Selection.Count_Selected_Rows = Selected_Count
         and then Control ("canvas-draft").Get_Sensitive = Draft_Sensitive,
         "Failed batch leaves draft and selection unchanged");

      declare
         Large_Path : constant String := To_String (Folder) & "/large.png";
      begin
         Write_Large_PNG (Large_Path);
         Choose (Large_Path, 1);
         Finish_Canvas_Jobs;
         Assert (N_Children (Model) = 4,
                 "File chooser imports PNG above the old cap");
         Check_Original (4, 1_800, 1_800);
      end;

      Choose (To_String (Paths (1)), 1);
      Assert (Coyote_GUI.Canvas_Import_Jobs.Pending_Count > 0,
              "File import is pending before session reset");
      Reset_Agents_From_Task (Frontend);
      Finish_Canvas_Jobs;
      Assert (N_Children (Model) = 0, "Session reset drops pending imports");
      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
      Ada.Directories.Delete_Tree (To_String (Folder));
   exception
      when others =>
         if Main_Window (Frontend) /= null then
            Frontend.Request_Shutdown;
            Main_Window (Frontend).Destroy;
         end if;
         if Length (Folder) > 0 then
            Ada.Directories.Delete_Tree (To_String (Folder));
         end if;
         raise;
   end Test_Canvas_File_Import;

   procedure Test_Canvas_Session_Recovery (T : in out Test) is
      use Ada.Strings.Unbounded;
      use Ada.Real_Time;
      use Coyote_App.Frontend.GUI.Testing;
      use Gtk.Tree_Model;
      use type System.Address;
      use type Coyote_Canvas.Store.Result;
      use type Coyote_Canvas.Document.Rectangle;
      package Disk renames Coyote_Canvas.Store.Workspaces;
      package Rev renames Coyote_Canvas.Revisions;

      A : constant String := "55be8400-e29b-41d4-a716-446655440000";
      B : constant String := "55be8400-e29b-41d4-a716-446655440001";
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Canvas   : Gtk.Window.Gtk_Window;
      Model    : Gtk_Tree_Model;
      Tree     : Gtk.Tree_View.Gtk_Tree_View;
      Root     : Unbounded_String;
      W, H     : Glib.Gint;
      Status   : Coyote_Canvas.Store.Result;
      Other    : Coyote_Canvas.Store.Writer_Lease;
      Saved    : Rev.Workspace;
      Pixels   : Disk.Raster_Set;
      Key      : Rev.Stable_Id;
      Pattern  : String := "/tmp/coyote-canvas-live-XXXXXX" & ASCII.NUL;

      function Make_Temp_Directory (P : System.Address) return System.Address
        with Import, Convention => C, External_Name => "mkdtemp";

      function Control (Name : String) return Gtk.Widget.Gtk_Widget is
        (Find_Canvas_Widget (Gtk.Widget.Gtk_Widget (Canvas), Name));

      procedure Activate (Name : String) is
      begin
         Gtk.Menu_Item.Gtk_Menu_Item (Control ("canvas-" & Name)).Activate;
      end Activate;

      procedure Wait_Status (Expected : String) is
         By : constant Time := Clock + Seconds (5);
      begin
         Wait_Loop : loop
            Drain_Events;
            exit Wait_Loop when Gtk.Label.Gtk_Label
              (Control ("coyote-canvas-storage-status")).Get_Text = Expected;
            Assert (Clock < By, "Canvas status did not reach: " & Expected);
            delay 0.01;
         end loop Wait_Loop;
      end Wait_Status;

      procedure Open (UUID : String; Parent : String) is
      begin
         Frontend.Set_Session_Identity
           (UUID, Parent, (if Parent = "" then "" else Parent & "/" & UUID & ".jsonl"));
         Drain_Events;
         Canvas_Item (Frontend).Activate;
         Canvas := Canvas_Window (Frontend);
         Tree := Gtk.Tree_View.Gtk_Tree_View (Control ("coyote-canvas-drawings"));
         Model := Tree.Get_Model;
      end Open;

      procedure Field (Name, Value : String) is
      begin
         Gtk.GEntry.Gtk_Entry
           (Control ("coyote-canvas-crop-" & Name)).Set_Text (Value);
      end Field;
   begin
      if not T.Display_Available then
         return;
      end if;
      Assert (Make_Temp_Directory (Pattern'Address) /= System.Null_Address,
              "create isolated session directory");
      Root := To_Unbounded_String (Pattern (1 .. Pattern'Last - 1));
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File,
                             To_String (Root) & "/" & A & ".jsonl");
         Ada.Text_IO.Close (File);
      end;
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File,
                             To_String (Root) & "/blue.svg");
         Ada.Text_IO.Put_Line
           (File, "<svg xmlns='http://www.w3.org/2000/svg' width='8' height='6'>"
            & "<rect width='8' height='6' fill='blue'/></svg>");
         Ada.Text_IO.Close (File);
      end;
      Coyote_App.Frontend.GUI.Create
        (Frontend, "Canvas recovery test", Pop_Under => True);
      Open (A, To_String (Root));
      Wait_Status ("Canvas autosave enabled.");
      Coyote_Canvas.Store.Claim (To_String (Root), A, Other, Status);
      Assert (Status = Coyote_Canvas.Store.Busy, "live GTK Canvas owns lease");
      Activate ("import");
      declare
         Dialog : constant Gtk.Window.Gtk_Window :=
           Canvas_Toplevel ("coyote-canvas-file-selection");
         Chooser : constant Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog :=
           Gtk.File_Chooser_Dialog.Gtk_File_Chooser_Dialog (Dialog);
         File : constant String := To_String (Root) & "/blue.svg";
         By : constant Time := Clock + Seconds (3);
      begin
         Assert (Chooser.Select_Filename (File), "select SVG recovery fixture");
         Wait_File : loop
            Drain_Events;
            exit Wait_File when Chooser.Get_Filename = File;
            Assert (Clock < By, "file selection timed out");
            delay 0.01;
         end loop Wait_File;
         Gtk.Dialog.Gtk_Dialog (Dialog).Response (Gtk.Dialog.Gtk_Response_OK);
      end;
      Finish_Canvas_Jobs;
      Assert (N_Children (Model) = 1, "one imported Original");
      Tree.Get_Selection.Select_Iter (Get_Iter_First (Model));
      Activate ("crop");
      Field ("x", "1");
      Field ("y", "2");
      Field ("width", "4");
      Field ("height", "3");
      Activate ("apply");
      Activate ("close");
      Wait_Status ("Canvas recovery saved.");
      Disk.Load (To_String (Root), A, Saved, Pixels, Status);
      Assert (Status = Coyote_Canvas.Store.Ok and then Rev.Changed (Saved)
              and then Rev.Count (Saved) = 1
              and then Rev.Extent (Saved) = (1, 2, 5, 5),
              "autosave preserves dirty crop without creating a revision");
      Assert (Length (Pixels (1)) = 8 * 6 * 4
              and then Slice (Pixels (1), 1, 4) =
                (ASCII.NUL & ASCII.NUL & Character'Val (255) & Character'Val (255)),
              "autosave preserves native source pixels");
      Key := Rev.Revision_Key (Saved, 1);
      Reset_Agents_From_Task (Frontend);
      Open (B, "");
      Assert (N_Children (Model) = 0, "no stale rows after session change");
      Activate ("new");
      Assert (N_Children (Model) = 1 and then not Ada.Directories.Exists
                (To_String (Root) & "/" & B & ".canvas"),
              "memory-only binding does not create a sidecar");
      Reset_Agents_From_Task (Frontend);
      Coyote_Canvas.Store.Claim (To_String (Root), A, Other, Status);
      Assert (Status = Coyote_Canvas.Store.Ok, "switch releases Canvas lease");
      Open (A, To_String (Root));
      Wait_Status ("Read-only: another window owns this Canvas.");
      Assert (N_Children (Model) = 1 and then not Control ("canvas-new").Get_Sensitive,
              "competing Canvas restores but cannot edit");
      Tree.Get_Selection.Select_Iter (Get_Iter_First (Model));
      Assert (not Control ("canvas-pencil").Get_Sensitive and then
                not Control ("canvas-crop").Get_Sensitive,
              "A selected revision cannot bypass the Canvas writer lease");
      Coyote_Canvas.Store.Release (Other);
      Reset_Agents_From_Task (Frontend);
      Open (A, To_String (Root));
      Wait_Status ("Session Canvas restored.");
      Control ("coyote-canvas-drawing-area").Get_Size_Request (W, H);
      Assert (W = 4 and then H = 3 and then N_Children (Model) = 1,
              "reopened GTK Canvas shows recovered dirty crop");
      declare
         --  A directory cannot be removed as an abandoned temporary file.
         Temp : constant String := To_String (Root) & "/" & A
           & ".canvas/.canvas.tmp";
      begin
         Ada.Directories.Create_Directory (Temp);
         Activate ("save");
         Wait_Status ("Canvas autosave failed. Changes are still in memory.");
         Disk.Load (To_String (Root), A, Saved, Pixels, Status);
         Assert (Status = Coyote_Canvas.Store.Ok and then Rev.Count (Saved) = 1
                 and then Control ("canvas-save").Get_Sensitive,
                 "failed commit retains manifest and enables retry");
         Ada.Directories.Delete_Directory (Temp);
         Activate ("save");
         Wait_Status ("Canvas recovery saved.");
      end;
      Disk.Load (To_String (Root), A, Saved, Pixels, Status);
      Assert (Status = Coyote_Canvas.Store.Ok and then Rev.Count (Saved) = 2
              and then Rev.Revision_Key (Saved, 1) = Key
              and then Rev.Drawing_Key (Saved, 2) = Key,
              "checkpoint after reopen preserves original identity");
      Reset_Agents_From_Task (Frontend);
      Open (B, To_String (Root));
      Wait_Status ("Canvas recovery unavailable; editing is disabled.");
      Assert (not Control ("canvas-new").Get_Sensitive and then
                not Ada.Directories.Exists (To_String (Root) & "/" & B & ".canvas"),
              "a session removed before Canvas opens cannot get a sidecar");
      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
      Ada.Directories.Delete_Tree (To_String (Root));
   exception
      when others =>
         if Main_Window (Frontend) /= null then
            Frontend.Request_Shutdown;
            Main_Window (Frontend).Destroy;
         end if;
         if Length (Root) > 0 then
            Ada.Directories.Delete_Tree (To_String (Root));
         end if;
         raise;
   end Test_Canvas_Session_Recovery;

   package Coyote_App_Frontend_GUI_Caller is new AUnit.Test_Caller
     (Coyote_App_Frontend_GUI_Tests.Test);

   procedure Test_Canvas_Agent_Import (T : in out Test) is
      use Ada.Directories;
      use Ada.Real_Time;
      use Ada.Strings.Unbounded;
      use Coyote_App.Frontend.GUI.Testing;
      use type System.Address;
      use type Coyote_Canvas.Store.Result;
      use type LLM.Tools.Shell.Execution_Status;
      package Importer renames Coyote_Canvas.Import_Service;
      package Disk renames Coyote_Canvas.Store.Workspaces;
      package Rev renames Coyote_Canvas.Revisions;

      A : constant String := "55be8400-e29b-41d4-a716-446655440000";
      B : constant String := "55be8400-e29b-41d4-a716-446655440001";
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Target : Importer.Endpoint;
      W : Rev.Workspace;
      Pixels : Disk.Raster_Set;
      Status : Coyote_Canvas.Store.Result;
      Root : Unbounded_String;
      Pattern : String := "/tmp/coyote-canvas-agent-XXXXXX" & ASCII.NUL;
      Runtime_Was_Set : constant Boolean :=
        Ada.Environment_Variables.Exists ("XDG_RUNTIME_DIR");
      Old_Runtime : constant String :=
        Ada.Environment_Variables.Value ("XDG_RUNTIME_DIR", "");
      CLI : constant String := GNAT.OS_Lib.Normalize_Pathname
        (Containing_Directory (Coyote_Utils.Active_Executable_Path)
         & "/../../bin/coyote");

      function Make_Directory (P : System.Address) return System.Address
        with Import, Convention => C, External_Name => "mkdtemp";

      procedure Put_File (Name, Text : String) is
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File,
                             To_String (Root) & "/" & Name);
         Ada.Text_IO.Put_Line (File, Text);
         Ada.Text_IO.Close (File);
      end Put_File;

      function Invoke (Target : Importer.Endpoint; Operands : String;
                       Success : Boolean) return String is
         Args : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
         Output, Media : Unbounded_String;
         Failed : Boolean := True;
         Outcome : LLM.Tools.Shell.Execution_Status;
         task Run is
            entry Start;
         end Run;
         task body Run is
         begin
            accept Start do
               null;
            end Start;
            LLM.Tools.Shell.Execute_With_Status
              (GNATCOLL.JSON.Write (Args), Output, Media, Failed, Outcome,
               Canvas_Target => Target);
         end Run;
         Deadline : constant Time := Clock + Seconds (15);
      begin
         Args.Set_Field ("command", "cd " & Coyote_Utils.Shell_Quote
           (To_String (Root)) & " && " & Coyote_Utils.Shell_Quote (CLI)
           & " canvas add -- " & Operands);
         Args.Set_Field ("timeout", Integer (12));
         Run.Start;
         Await_Exit : while not Run'Terminated loop
            Drain_Events;
            Assert (Clock < Deadline, "shell import test deadline");
            delay 0.01;
         end loop Await_Exit;
         Assert ((not Failed and then Outcome = LLM.Tools.Shell.Completed) =
                 Success, "unexpected shell result: " & To_String (Output));
         return To_String (Output);
      end Invoke;

      procedure Cleanup is
      begin
         if Main_Window (Frontend) /= null then
            Frontend.Request_Shutdown;
            Main_Window (Frontend).Destroy;
         end if;
         if Runtime_Was_Set then
            Ada.Environment_Variables.Set ("XDG_RUNTIME_DIR", Old_Runtime);
         else
            Ada.Environment_Variables.Clear ("XDG_RUNTIME_DIR");
         end if;
         if Length (Root) /= 0 then
            Delete_Tree (To_String (Root));
         end if;
      end Cleanup;
   begin
      if not T.Display_Available then
         return;
      end if;
      Assert (Exists (CLI), "build the development CLI before running this test");
      Assert (Make_Directory (Pattern'Address) /= System.Null_Address,
              "create private fixture runtime directory");
      Root := To_Unbounded_String (Pattern (1 .. Pattern'Last - 1));
      Ada.Environment_Variables.Set ("XDG_RUNTIME_DIR", To_String (Root));
      Put_File (A & ".jsonl", "{}");
      Put_File ("first.svg", "<svg xmlns='http://www.w3.org/2000/svg'"
                & " width='9' height='7'><rect width='9' height='7'"
                & " fill='blue'/></svg>");
      Put_File ("-second.svg", "<svg xmlns='http://www.w3.org/2000/svg'"
                & " width='4' height='3'><rect width='4' height='3'"
                & " fill='red'/></svg>");
      Put_File ("bad.svg", "not an image");
      Frontend.Create ("Canvas shell import test", Pop_Under => True);
      Frontend.Set_Session_Identity
        (A, To_String (Root), To_String (Root) & "/" & A & ".jsonl",
         Enable_Canvas_Import => True);
      Drain_Events;
      Target := Frontend.Canvas_Target (A);
      Assert (Length (Target.Capability) = 64 and then
              Length (Frontend.Canvas_Target (B).Path) = 0,
              "authority bound to the current root UUID");
      declare
         Reply : constant String := Invoke (Target, "first.svg -second.svg", True);
      begin
         Disk.Load (To_String (Root), A, W, Pixels, Status);
         Assert (Status = Coyote_Canvas.Store.Ok and then Rev.Count (W) = 2,
                 "successful shell exit requires a committed Canvas batch");
         Assert (Reply = "first.svg" & ASCII.HT & Rev.Drawing_Key (W, 1)
                 & ASCII.HT & Rev.Revision_Key (W, 1) & ASCII.LF
                 & "-second.svg" & ASCII.HT & Rev.Drawing_Key (W, 2)
                 & ASCII.HT & Rev.Revision_Key (W, 2) & ASCII.LF,
                 "ordered labels and stable IDs match the manifest: " & Reply);
         Assert (Rev.Original_Label (W, 1) = "first.svg" and then
                 Rev.Original_Label (W, 2) = "-second.svg" and then
                 Length (Pixels (1)) = 9 * 7 * 4 and then
                 Length (Pixels (2)) = 4 * 3 * 4 and then Rev.Base (W) = 0,
                 "native-sized Originals do not start or change the draft");
         Assert (Canvas_Window (Frontend) = null, "import does not open Canvas");
      end;
      declare
         Reply : constant String := Invoke (Target, "first.svg bad.svg", False);
      begin
         Assert (Reply'Length > 0, "failed decode reports an error");
      end;
      declare
         Temp : constant String := To_String (Root) & "/" & A
           & ".canvas/.canvas.tmp";
      begin
         Create_Directory (Temp);
         declare
            Reply : constant String := Invoke (Target, "first.svg", False);
         begin
            Assert (Reply'Length > 0, "failed persistence reports an error");
         end;
         Delete_Directory (Temp);
      end;
      Canvas_Item (Frontend).Activate;
      Drain_Events;
      declare
         Tree : constant Gtk.Tree_View.Gtk_Tree_View := Gtk.Tree_View.Gtk_Tree_View
           (Find_Canvas_Widget (Gtk.Widget.Gtk_Widget (Canvas_Window (Frontend)),
                                "coyote-canvas-drawings"));
      begin
         Assert (Gtk.Tree_Model.N_Children (Tree.Get_Model) = 2,
                 "decode and persistence failures add no live rows");
         Assert (Gtk.Tree_Selection.Count_Selected_Rows (Tree.Get_Selection) = 0,
                 "background import does not select a drawing");
      end;
      Reset_Agents_From_Task (Frontend);
      Frontend.Set_Session_Identity (B, Enable_Canvas_Import => True);
      Drain_Events;
      declare
         Reply : constant String := Invoke (Target, "first.svg", False);
      begin
         Assert (Reply'Length > 0 and then not Exists (To_String (Target.Path)),
                 "previous endpoint disappears on reset");
      end;
      declare
         Reply : constant String :=
           Invoke (Frontend.Canvas_Target (B), "first.svg", True);
      begin
         Assert (Reply'Length > 0 and then
                 not Exists (To_String (Root) & "/" & B & ".canvas"),
                 "memory-only import has no durable side effects");
      end;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Canvas_Agent_Import;

   procedure Test_Canvas_Help (T : in out Test) is
      use Ada.Real_Time;
      use Coyote_App.Frontend.GUI.Testing;
      package Env renames Ada.Environment_Variables;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Canvas : Gtk.Window.Gtk_Window;
      Template : aliased String := "/tmp/coyote-canvas-help-XXXXXX" & ASCII.NUL;
      Root : String renames Template (1 .. Template'Last - 1);
      File : Ada.Text_IO.File_Type;
      Had_Path : constant Boolean := Env.Exists ("PATH");
      Old_Path : constant String := Env.Value ("PATH", "");
      Have_Root, Have_Window : Boolean := False;
      use type System.Address;
      use type Interfaces.C.int;

      function Make_Temp_Directory (Name : System.Address) return System.Address
        with Import, Convention => C, External_Name => "mkdtemp";
      function Chmod (Name : Interfaces.C.char_array; Mode : Interfaces.C.unsigned)
        return Interfaces.C.int
        with Import, Convention => C, External_Name => "chmod";

      function Control (Name : String) return Gtk.Widget.Gtk_Widget is
        (Find_Canvas_Widget (Gtk.Widget.Gtk_Widget (Canvas), Name));

      procedure Activate (Name : String) is
         Item : constant Gtk.Widget.Gtk_Widget := Control ("canvas-" & Name);
      begin
         Assert (Item /= null, "missing Canvas Help action " & Name);
         Gtk.Menu_Item.Gtk_Menu_Item (Item).Activate;
      end Activate;

      procedure Check_Target (Topic : String) is
         By : constant Time := Clock + Seconds (3);
      begin
         while not Ada.Directories.Exists (Root & "/topic") loop
            Assert (Clock < By, "Yelp was not launched for " & Topic);
            delay 0.01;
         end loop;
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Root & "/topic");
         Assert (Ada.Text_IO.Get_Line (File) = Topic, "Yelp URI: " & Topic);
         Ada.Text_IO.Close (File);
         Ada.Directories.Delete_File (Root & "/topic");
      end Check_Target;

      procedure Cleanup is
      begin
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         if Had_Path then
            Env.Set ("PATH", Old_Path);
         else
            Env.Clear ("PATH");
         end if;
         if Have_Window then
            Frontend.Request_Shutdown;
            Main_Window (Frontend).Destroy;
         end if;
         if Have_Root then
            Ada.Directories.Delete_Tree (Root);
         end if;
      end Cleanup;
   begin
      if not T.Display_Available then
         return;
      end if;
      Have_Root := Make_Temp_Directory (Template'Address) /= System.Null_Address;
      Assert (Have_Root, "create private Yelp fixture");
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Root & "/yelp");
      Ada.Text_IO.Put_Line (File, "#!/bin/sh");
      Ada.Text_IO.Put_Line (File, "printf '%s\n' ""$1"" > '" & Root & "/pending'");
      Ada.Text_IO.Put_Line (File, "/bin/mv '" & Root & "/pending' '" & Root & "/topic'");
      Ada.Text_IO.Close (File);
      Assert (Chmod (Interfaces.C.To_C (Root & "/yelp"), 8#700#) = 0,
              "make isolated Yelp fixture executable");
      Env.Set ("PATH", Root);
      Coyote_App.Frontend.GUI.Create (Frontend, "Canvas Help", Pop_Under => True);
      Have_Window := True;
      Canvas_Item (Frontend).Activate;
      Canvas := Canvas_Window (Frontend);
      Activate ("help");
      Check_Target ("help:coyote/canvas");
      Activate ("help-keys");
      Check_Target ("help:coyote/keyboard-shortcuts#canvas");
      Activate ("help-index");
      Check_Target ("help:coyote");
      Activate ("new");
      Gtk.Radio_Button.Gtk_Radio_Button (Control ("canvas-tool-zoom-in"))
        .Clicked;
      Activate ("help-click");
      declare
         Area : constant Gtk.Widget.Gtk_Widget :=
           Control ("coyote-canvas-drawing-area");
         Raw : aliased Gdk.Event.Gdk_Event_Button :=
           (The_Type => Gdk.Event.Button_Press, Window => Area.Get_Window,
            Send_Event => 1, Time => 0, X => 20.0, Y => 20.0, Axes => null,
            State => 0, Button => 1, Device => System.Null_Address,
            X_Root => 20.0, Y_Root => 20.0);
      begin
         Assert (Area.Event (Gdk.Event.To_Event (Raw'Access)),
                 "Click for Help consumes a drawing press");
         Check_Target ("help:coyote/canvas-editing");
         Raw.The_Type := Gdk.Event.Button_Release;
         Assert (not Area.Event (Gdk.Event.To_Event (Raw'Access)) and then
                   not Control ("canvas-undo").Get_Sensitive,
                 "the Help click did not start an ink gesture");
         declare
            W, H : Glib.Gint;
         begin
            Area.Get_Size_Request (W, H);
            Assert (W = 800 and then H = 600 and then
                      Gtk.Radio_Button.Gtk_Radio_Button
                        (Control ("canvas-tool-zoom-in")).Get_Active,
                    "Click for Help preserves the scale and magnifier");
         end;
      end;
      Activate ("help-click");
      declare
         Eraser : constant Gtk.Radio_Button.Gtk_Radio_Button :=
           Gtk.Radio_Button.Gtk_Radio_Button (Control ("canvas-tool-eraser"));
         Raw : aliased Gdk.Event.Gdk_Event_Button :=
           (The_Type => Gdk.Event.Button_Press, Window => Eraser.Get_Window,
            Send_Event => 1, Time => 0, X => 5.0, Y => 5.0, Axes => null,
            State => 0, Button => 1, Device => System.Null_Address,
            X_Root => 5.0, Y_Root => 5.0);
      begin
         Assert (Eraser.Event (Gdk.Event.To_Event (Raw'Access)),
                 "Click for Help consumes a toolbar press");
         Check_Target ("help:coyote/canvas-editing");
         Raw.The_Type := Gdk.Event.Button_Release;
         declare
            Handled : constant Boolean :=
              Eraser.Event (Gdk.Event.To_Event (Raw'Access));
            pragma Unreferenced (Handled);
         begin
            Assert (not Eraser.Get_Active,
                    "Help does not select a different tool");
         end;
      end;
      Env.Set ("PATH", "/dev/null");
      Activate ("help-revisions");
      Assert (Gtk.Label.Get_Text (Gtk.Label.Gtk_Label
                (Control ("coyote-canvas-status"))) =
                  "Unable to open Help: Yelp is not available.",
              "Canvas reports missing Yelp locally");
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Canvas_Help;

   procedure Test_Canvas_Attachments (T : in out Test) is
      use Ada.Strings.Unbounded;
      use Coyote_App.Frontend.GUI.Testing;
      use Gtk.Tree_Model;
      use Coyote_GUI.Prompt_Queue;
      Id : constant String := "55be8400-e29b-41d4-a716-446655440000";
      F : Coyote_App.Frontend.GUI.Instance;
      Canvas : Gtk.Window.Gtk_Window;
      Tree : Gtk.Tree_View.Gtk_Tree_View;
      Model : Gtk_Tree_Model;
      It : Item;
      PNG : Unbounded_String;
      Attach : Gtk.Button.Gtk_Button;
      Choice : Gtk.Combo_Box_Text.Gtk_Combo_Box_Text;
      Narrow_Width : constant Glib.Gint := 640;

      function Widget (Name : String; In_Canvas : Boolean := True)
        return Gtk.Widget.Gtk_Widget is
        (Find_Canvas_Widget
           (Gtk.Widget.Gtk_Widget ((if In_Canvas then Canvas else Main_Window (F))),
            Name));

      procedure Activate (Name : String) is
      begin
         Gtk.Menu_Item.Gtk_Menu_Item (Widget ("canvas-" & Name)).Activate;
      end Activate;

      procedure Field (Name, Value : String) is
      begin
         Gtk.GEntry.Gtk_Entry (Widget ("coyote-canvas-crop-" & Name)).Set_Text (Value);
      end Field;

      procedure Click (Name : String) is
      begin
         Gtk.Button.Gtk_Button (Widget (Name, False)).Clicked;
         Drain_Events;
      end Click;

      procedure Check_Actions
        (Width : Glib.Gint; Rejected : Boolean := False)
      is
         use type Ada.Real_Time.Time;
         Win : constant Gtk.Window.Gtk_Window := Main_Window (F);
         Deadline : constant Ada.Real_Time.Time :=
           Ada.Real_Time.Clock + Ada.Real_Time.Seconds (1);

         procedure Check_Button (Name : String) is
            Button : constant Gtk.Widget.Gtk_Widget :=
              Widget ("canvas-attachment-" & Name, False);
            X, Y, Minimum, Natural_Width : Glib.Gint;
            Translated : Boolean;
         begin
            Button.Translate_Coordinates (Win, 0, 0, X, Y, Translated);
            Button.Get_Preferred_Width (Minimum, Natural_Width);
            Assert (Translated and then Button.Is_Visible
                    and then Button.Get_Allocated_Width >= Natural_Width
                    and then X >= 0 and then Y >= 0
                    and then X + Button.Get_Allocated_Width <= Width
                    and then Y + Button.Get_Allocated_Height <=
                      Win.Get_Allocated_Height,
                    "Attachment button fits at" & Width'Image & ": " & Name);
         end Check_Button;
      begin
         Win.Resize (Width, 700);
         loop
            Drain_Events;
            exit when Win.Get_Allocated_Width = Width
              or else Ada.Real_Time.Clock >= Deadline;
            delay 0.01;
         end loop;
         Win.Check_Resize;
         Assert (Win.Get_Allocated_Width = Width,
                 "Attachment row permits width" & Width'Image & "; got" &
                   Win.Get_Allocated_Width'Image);
         Check_Button ("up");
         Check_Button ("down");
         Check_Button ("remove");
         Check_Button ("show");
         if Rejected then
            Check_Button ("restore");
         else
            Assert (not Widget ("canvas-attachment-restore", False).Get_Visible,
                    "Restore Draft does not take space in the normal row");
         end if;
      end Check_Actions;
   begin
      if not T.Display_Available then
         return;
      end if;
      F.Create ("Canvas attachment test", Pop_Under => True);
      F.Set_Session_Identity (Id);
      Drain_Events;
      Canvas_Item (F).Activate;
      Canvas := Canvas_Window (F);
      Tree := Gtk.Tree_View.Gtk_Tree_View (Widget ("coyote-canvas-drawings"));
      Model := Tree.Get_Model;
      Assert (Widget ("canvas-attach-button") /= null,
              "Canvas has a footer Attach button");
      Attach := Gtk.Button.Gtk_Button (Widget ("canvas-attach-button"));
      Drain_Events;
      Check_Footer : declare
         X, Y : Glib.Gint;
         Translated : Boolean;
      begin
         Attach.Translate_Coordinates (Canvas, 0, 0, X, Y, Translated);
         Assert (Translated and then Attach.Get_Visible
                 and then Attach.Get_Label = "Attach"
                 and then Canvas.Get_Allocated_Width - X -
                   Attach.Get_Allocated_Width in 0 .. 16
                 and then Canvas.Get_Allocated_Height - Y -
                   Attach.Get_Allocated_Height in 0 .. 16,
                 "Attach is visible in the bottom-right corner");
      end Check_Footer;
      Assert (not Attach.Get_Sensitive, "Empty workspace dims Attach");
      Activate ("new");
      Assert (Attach.Get_Sensitive, "A new drawing enables Attach");
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Widget ("canvas-markup")).Set_Active (False);
      Assert (not Attach.Get_Sensitive, "Hidden markup dims Attach");
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Widget ("canvas-markup")).Set_Active (True);
      Activate ("crop");
      Assert (not Attach.Get_Sensitive
              and then not Widget ("canvas-attach").Get_Sensitive,
              "Pending crop dims both Attach controls");
      Field ("x", "3");
      Field ("y", "4");
      Field ("width", "7");
      Field ("height", "5");
      Activate ("apply");
      Activate ("attach");
      Assert (Attachment_Count (F) = 1, "working copy is checkpointed and staged");
      Choice := Gtk.Combo_Box_Text.Gtk_Combo_Box_Text
        (Widget ("canvas-attachment-choice", False));
      Check_Long_Label : declare
         Long_Label : constant String := "[Image 2: " & (1 .. 240 => 'W')
           & ", 800 x 600]  9b291635-2110-4e57-a6db-380fba522ca5";
         Narrow_Choice, Wide_Choice : Glib.Gint;
      begin
         Choice.Append_Text (Long_Label);
         Choice.Set_Active (1);
         Check_Actions (Narrow_Width);
         Narrow_Choice := Choice.Get_Allocated_Width;
         Assert (Choice.Get_Active_Text = Long_Label
                 and then Choice.Get_Tooltip_Text = Long_Label,
                 "The picker retains and exposes the full name and revision");
         Check_Actions (1_100);
         Wide_Choice := Choice.Get_Allocated_Width;
         Assert (Wide_Choice > Narrow_Choice,
                 "Extra width goes to the attachment picker");
         Choice.Remove (1);
         Choice.Set_Active (0);
         Assert (Choice.Get_Tooltip_Text = Choice.Get_Active_Text,
                 "The tooltip follows the attachment selection");
         Check_Actions (Narrow_Width);
      end Check_Long_Label;
      Activate ("fit");
      declare
         Area : constant Gtk.Widget.Gtk_Widget :=
           Widget ("coyote-canvas-drawing-area");
         Button : constant Gtk.Radio_Button.Gtk_Radio_Button :=
           Gtk.Radio_Button.Gtk_Radio_Button (Widget ("canvas-tool-zoom-out"));
         Raw : aliased Gdk.Event.Gdk_Event_Button :=
           (The_Type => Gdk.Event.Button_Press, Window => Area.Get_Window,
            Send_Event => 1, Time => 0, X => 4.0, Y => 4.0, Axes => null,
            State => 0, Button => 1, Device => System.Null_Address,
            X_Root => 4.0, Y_Root => 4.0);
      begin
         Button.Clicked;
         Assert (Button.Get_Active and then
                   Area.Event (Gdk.Event.To_Event (Raw'Access)),
                 "Zoom an attachable revision with the toolbar");
         Canvas.Check_Resize;
         Drain_Events;
      end;
      Tree.Get_Selection.Select_Iter (Get_Iter_From_String (Model, "0"));
      Activate ("draft");
      Widget ("coyote-canvas-drawing-area").Grab_Focus;
      Attach.Grab_Focus;
      Assert (Canvas.Get_Focus = Gtk.Widget.Gtk_Widget (Attach)
              and then Gtk.Widget.Activate (Gtk.Widget.Gtk_Widget (Attach)),
              "Attach is keyboard-focusable and activatable");
      Wait_For_Draft : declare
         use type Ada.Real_Time.Time;
         Deadline : constant Ada.Real_Time.Time :=
           Ada.Real_Time.Clock + Ada.Real_Time.Seconds (1);
      begin
         while Attachment_Count (F) /= 2
           and then Ada.Real_Time.Clock < Deadline
         loop
            delay 0.01;
            Drain_Events;
         end loop;
      end Wait_For_Draft;
      Assert (Attachment_Count (F) = 2,
              "Activating Attach from the drawing stages the draft");
      Activate ("undo");
      Activate ("new");
      Tree.Get_Selection.Select_Iter (Get_Iter_From_String (Model, "1"));
      Tree.Get_Selection.Select_Iter (Get_Iter_From_String (Model, "0"));
      Tree.Grab_Focus;
      Attach.Clicked;
      Assert (Attachment_Count (F) = 4,
              "Clicking Attach stages selected revisions in one batch");
      Choice.Set_Active (2);
      Click ("canvas-attachment-up");
      Click ("canvas-attachment-up");
      Click_Send (F);
      Drain_Events;
      Assert (Attachment_Count (F) = 4, "unsupported model retains draft");
      F.Canvas_Model (True);
      Drain_Events;
      Click_Send (F);
      It := F.Read_Item;
      Assert (It.Kind = Canvas_Prompt and then Length (It.Canvas_Text) = 0
             and then Natural (It.Images.Length) = 4 and then It.Canvas_Session = Id,
              "image-only Send hands off a complete, session-scoped prompt");
      Assert (It.Images (1).Width = 800 and then It.Images (2).Width = 7
              and then It.Images (2).Height = 5 and then It.Images (4).Width = 800
              and then It.Images (1).Drawing_Id = It.Images (2).Drawing_Id
              and then It.Images (4).Drawing_Id /= It.Images (1).Drawing_Id,
              "tree order, manual reorder and frozen pre-undo crop are preserved");
      Assert (It.Images (3).Width = 7 and then It.Images (3).Height = 5
                and then It.Images (2).Revision_Id = It.Images (3).Revision_Id
                and then It.Images (2).PNG = It.Images (3).PNG,
              "Button and menu stage the draft, not the selected Original");
      PNG := It.Images (2).PNG;
      F.Canvas_Prompt_Result (Id, It.Request_Id, False);
      Drain_Events;
      Check_Actions (Narrow_Width, Rejected => True);
      Click ("canvas-attachment-restore");
      Click_Send (F);
      It := F.Read_Item;
      Assert (It.Images (2).PNG = PNG, "rejected prompt restores exact PNG bytes");
      F.Begin_Image_Request ("", It.Images);
      F.Canvas_Prompt_Result (Id, It.Request_Id, True);
      Drain_Events;
      Assert (Attachment_Count (F) = 0 and then
              Widget ("coyote-user-image-show", False) /= null,
              "successful send clears staging and presents a revision action");
      Click ("coyote-user-image-show");
      Assert (Canvas.Get_Visible, "recorded revision can be opened in Canvas");
      Assert (Widget ("canvas-crop").Get_Sensitive and then
                not Widget ("canvas-save").Get_Sensitive,
              "A revealed revision can be edited but is not yet dirty");
      Activate ("crop");
      Field ("x", "10");
      Field ("width", "12");
      Field ("height", "13");
      Activate ("apply");
      Activate ("save");
      Assert (Get_Iter_From_String (Model, "0:1") /= Null_Iter and then
                Attachment_Count (F) = 0,
              "Direct crop of the revealed Original saves a new branch");
      F.Request_Shutdown;
      Main_Window (F).Destroy;
   exception
      when others =>
         if Main_Window (F) /= null then
            F.Request_Shutdown;
            Main_Window (F).Destroy;
         end if;
         raise;
   end Test_Canvas_Attachments;

   procedure Test_Canvas_Finger_Drawing (T : in out Test) is
      use Coyote_App.Frontend.GUI.Testing;
      use Gtk.Tree_Model;
      use type Gdk.Pixbuf.Rgb_Record;
      Frontend : Coyote_App.Frontend.GUI.Instance;
      Canvas : Gtk.Window.Gtk_Window;
      Area : Gtk.Widget.Gtk_Widget;
      Tree : Gtk.Tree_View.Gtk_Tree_View;
      Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
      Toggle : Gtk.Check_Menu_Item.Gtk_Check_Menu_Item;
      Blue_Ink : constant Gdk.Pixbuf.Rgb_Record := (0, 0, 255);
      First_Contact, Second_Contact : aliased Integer := 0;

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

      procedure Touch
        (Kind : Gdk.Event.Gdk_Event_Type; X, Y : Glib.Gdouble;
         Contact : System.Address)
      is
         Seat : constant Gdk.Seat.Gdk_Seat := Gdk.Seat.Gdk_Seat
           (Area.Get_Display.Get_Default_Seat);
         function New_Event (Kind : Gdk.Event.Gdk_Event_Type)
           return Gdk.Event.Gdk_Event
           with Import, Convention => C, External_Name => "gdk_event_new";
         procedure Set_Device (Event : Gdk.Event.Gdk_Event;
                               Device : System.Address)
           with Import, Convention => C, External_Name => "gdk_event_set_device";
         procedure Set_Source_Device (Event : Gdk.Event.Gdk_Event;
                                      Device : System.Address)
           with Import, Convention => C,
             External_Name => "gdk_event_set_source_device";
         Event : constant Gdk.Event.Gdk_Event := New_Event (Kind);
         Raw : Gdk.Event.Gdk_Event_Touch
           with Import, Address => Gdk.Event.To_Address (Event);
         Device : constant System.Address := Seat.Get_Pointer.Get_Object;
         Actual : Boolean;
      begin
         Gdk.Window.Ref (Area.Get_Window);
         Raw := (The_Type => Kind, Window => Area.Get_Window,
            Send_Event => 1, Time => 0, X => X, Y => Y, Axes => null,
            State => 0, Sequence => Gdk.Event.Gdk_Event_Sequence
              (Glib.C_Proxy'(Glib.To_Proxy (Contact))),
            Emulating_Pointer => False, Device => Device,
            X_Root => X, Y_Root => Y);
         Set_Device (Event, Device);
         Set_Source_Device (Event, Device);
         Actual := Area.Event (Event);
         Gdk.Event.Free (Event);
         Assert (Actual, "Canvas consumes touch event: " & Kind'Image);
      end Touch;

      procedure Foreign_Release is
         Raw : aliased Gdk.Event.Gdk_Event_Button :=
           (The_Type => Gdk.Event.Button_Release, Window => Area.Get_Window,
            Send_Event => 1, Time => 0, X => 80.0, Y => 80.0, Axes => null,
            State => 0, Button => 1, Device => System.Null_Address,
            X_Root => 80.0, Y_Root => 80.0);
      begin
         Assert (not Area.Event (Gdk.Event.To_Event (Raw'Access)),
                 "A pointer release cannot finish a finger stroke");
      end Foreign_Release;

      procedure Check_Pixel
        (X, Y : Glib.Gint; Expected : Gdk.Pixbuf.Rgb_Record)
      is
         Surface : constant Cairo.Cairo_Surface := Cairo.Image_Surface.Create
           (Cairo.Image_Surface.Cairo_Format_RGB24, 96, 96);
         Context : constant Cairo.Cairo_Context := Cairo.Create (Surface);
         Sample : Gdk.Pixbuf.Gdk_Pixbuf;
         Actual : Gdk.Pixbuf.Rgb_Record;
      begin
         Canvas.Check_Resize;
         Drain_Events;
         Area.Draw (Context);
         Cairo.Destroy (Context);
         Sample := Gdk.Pixbuf.Get_From_Surface (Surface, X, Y, 1, 1);
         Actual := Gdk.Pixbuf.Get_Pixels (Sample) (0);
         Sample.Unref;
         Cairo.Surface_Destroy (Surface);
         Assert (Actual = Expected, "Finger ink pixel:" & X'Image & Y'Image);
      end Check_Pixel;
   begin
      if not T.Display_Available then
         return;
      end if;
      Frontend.Create ("Canvas finger drawing", Pop_Under => True);
      Canvas_Item (Frontend).Activate;
      Canvas := Canvas_Window (Frontend);
      Area := Control ("coyote-canvas-drawing-area");
      Scroll := Gtk.Scrolled_Window.Gtk_Scrolled_Window
        (Control ("coyote-canvas-viewport"));
      Toggle := Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Control ("canvas-edit-with-finger"));
      Assert
        (Gtk.Menu_Item.Gtk_Menu_Item (Toggle).Get_Label = "Edit with _Finger",
         "The shared finger-edit toggle has the expected mnemonic label");
      Tree := Gtk.Tree_View.Gtk_Tree_View (Control ("coyote-canvas-drawings"));
      Activate ("new");
      Tree.Get_Selection.Select_Iter (Get_Iter_First (Tree.Get_Model));
      Drain_Events;
      Assert (not Toggle.Get_Active and then Scroll.Get_Kinetic_Scrolling,
              "Finger mode defaults off with touch scrolling available");
      Touch (Gdk.Event.Touch_Begin, 30.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_End, 60.0, 30.5, First_Contact'Address);
      Assert (not Control ("canvas-undo").Get_Sensitive,
              "An opted-out touch doesn't add ink");

      Choose_Pencil_Color
        (Gtk.Color_Button.Gtk_Color_Button (Control ("canvas-pencil-color")),
         (0.0, 0.0, 1.0, 1.0));
      Toggle.Set_Active (True);
      Assert (not Scroll.Get_Kinetic_Scrolling,
              "Finger Pencil suppresses scroller gesture capture");
      Touch (Gdk.Event.Touch_Begin, 30.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 45.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Begin, 20.0, 65.5, Second_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 50.0, 65.5, Second_Contact'Address);
      Foreign_Release;
      Assert (not Control ("canvas-save").Get_Sensitive and then
                not Control ("canvas-undo").Get_Sensitive and then
                not Control ("canvas-fit").Get_Sensitive,
              "Live finger ink is only a view overlay");
      Check_Pixel (40, 30, Blue_Ink);
      Touch (Gdk.Event.Touch_End, 60.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 55.0, 65.5, Second_Contact'Address);
      Touch (Gdk.Event.Touch_End, 65.0, 65.5, Second_Contact'Address);
      Check_Pixel (55, 30, Blue_Ink);
      Check_Pixel (55, 29, Blue_Ink);
      Check_Pixel (55, 31, Blue_Ink);
      Check_Pixel (55, 28, (255, 255, 255));
      Check_Pixel (55, 32, (255, 255, 255));
      Check_Pixel (45, 65, (255, 255, 255));
      Activate ("undo");
      Assert (not Control ("canvas-undo").Get_Sensitive,
              "One touch stroke is one undo operation");
      Check_Pixel (55, 30, (255, 255, 255));
      Activate ("redo");
      Check_Pixel (55, 30, Blue_Ink);

      Activate ("zoom-in");
      Canvas.Check_Resize;
      Drain_Events;
      Touch (Gdk.Event.Touch_Begin, 37.5, 63.125, First_Contact'Address);
      Touch (Gdk.Event.Touch_End, 75.0, 63.125, First_Contact'Address);
      Activate ("actual");
      Check_Pixel (55, 50, Blue_Ink);
      Check_Pixel (55, 49, Blue_Ink);
      Check_Pixel (55, 48, (255, 255, 255));

      Touch (Gdk.Event.Touch_Begin, 30.0, 70.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 60.0, 70.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Cancel, 60.0, 70.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_End, 60.0, 70.5, First_Contact'Address);
      Check_Pixel (55, 70, (255, 255, 255));
      Touch (Gdk.Event.Touch_Begin, 55.0, 70.5, First_Contact'Address);
      Toggle.Set_Active (False);
      Toggle.Set_Active (True);
      Touch (Gdk.Event.Touch_End, 60.0, 70.5, First_Contact'Address);
      Check_Pixel (55, 70, (255, 255, 255));
      Activate ("eraser");
      Assert (not Scroll.Get_Kinetic_Scrolling,
              "Enabled finger eraser suppresses kinetic scrolling");
      Touch (Gdk.Event.Touch_Begin, 55.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_End, 55.0, 30.5, First_Contact'Address);
      Check_Pixel (55, 30, (255, 255, 255));
      Activate ("undo");
      Check_Pixel (55, 30, Blue_Ink);
      Activate ("pencil");
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Control ("canvas-markup")).Set_Active (False);
      Assert (Scroll.Get_Kinetic_Scrolling, "Hidden markup doesn't draw");
      Gtk.Check_Menu_Item.Gtk_Check_Menu_Item
        (Control ("canvas-markup")).Set_Active (True);
      Activate ("eraser");
      Toggle.Set_Active (False);
      Assert (Scroll.Get_Kinetic_Scrolling,
              "Disabled finger eraser preserves touch scrolling");
      Touch (Gdk.Event.Touch_Begin, 55.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_End, 55.0, 30.5, First_Contact'Address);
      Check_Pixel (55, 30, Blue_Ink);
      Toggle.Set_Active (True);
      Assert (not Scroll.Get_Kinetic_Scrolling,
              "Finger eraser suppresses kinetic scrolling");
      Touch (Gdk.Event.Touch_Begin, 45.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 55.0, 30.5, First_Contact'Address);
      Assert (not Control ("canvas-save").Get_Sensitive and then
                not Control ("canvas-attach").Get_Sensitive and then
                Get_Iter_From_String (Tree.Get_Model, "0:0:0") = Null_Iter,
              "Live finger erasure cannot save, attach, or create a revision");
      Check_Pixel (55, 30, (255, 255, 255));
      Touch (Gdk.Event.Touch_Cancel, 55.0, 30.5, First_Contact'Address);
      Check_Pixel (55, 30, Blue_Ink);

      Activate ("zoom-in");
      Canvas.Check_Resize;
      Drain_Events;
      Touch (Gdk.Event.Touch_Begin, 56.25, 38.125, First_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 68.75, 38.125, First_Contact'Address);
      Touch (Gdk.Event.Touch_Begin, 68.75, 63.125, Second_Contact'Address);
      Foreign_Release;
      Touch (Gdk.Event.Touch_End, 68.75, 38.125, First_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 70.0, 63.125, Second_Contact'Address);
      Touch (Gdk.Event.Touch_End, 71.25, 63.125, Second_Contact'Address);
      Activate ("actual");
      Check_Pixel (55, 50, Blue_Ink);
      Check_Pixel (55, 30, (255, 255, 255));
      Check_Pixel (38, 30, (255, 255, 255));
      Check_Pixel (36, 30, Blue_Ink);
      Check_Pixel (30, 30, Blue_Ink);
      Activate ("undo");
      Check_Pixel (55, 30, Blue_Ink);
      Check_Pixel (38, 30, Blue_Ink);
      Check_Pixel (55, 50, Blue_Ink);
      Check_Pixel (30, 30, Blue_Ink);
      Activate ("redo");
      Assert (not Control ("canvas-redo").Get_Sensitive,
              "One redo restores the finger erase gesture");
      Check_Pixel (55, 30, (255, 255, 255));
      Touch (Gdk.Event.Touch_Begin, 30.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 35.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Cancel, 35.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_End, 35.0, 30.5, First_Contact'Address);
      Check_Pixel (30, 30, Blue_Ink);
      Touch (Gdk.Event.Touch_Begin, 30.0, 30.5, First_Contact'Address);
      Toggle.Set_Active (False);
      Touch (Gdk.Event.Touch_End, 35.0, 30.5, First_Contact'Address);
      Check_Pixel (30, 30, Blue_Ink);
      Assert (Scroll.Get_Kinetic_Scrolling,
              "Disabling finger editing restores touch scrolling");
      Toggle.Set_Active (True);
      Activate ("pencil");
      Touch (Gdk.Event.Touch_Begin, 55.0, 70.5, First_Contact'Address);
      Activate ("close");
      Canvas_Item (Frontend).Activate;
      Assert (Toggle.Get_Active, "Hiding Canvas keeps the session setting");
      Touch (Gdk.Event.Touch_End, 60.0, 70.5, First_Contact'Address);
      Check_Pixel (55, 70, (255, 255, 255));
      Activate ("save");
      Assert (Get_Iter_From_String (Tree.Get_Model, "0:0") /= Null_Iter,
              "Direct finger drawing on the Original saves a child");
      Tree.Get_Selection.Select_Iter
        (Get_Iter_From_String (Tree.Get_Model, "0:0"));
      Check_Pixel (30, 30, Blue_Ink);
      Activate ("eraser");
      Touch (Gdk.Event.Touch_Begin, 25.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_Update, 35.0, 30.5, First_Contact'Address);
      Check_Pixel (30, 30, (255, 255, 255));
      Touch (Gdk.Event.Touch_Cancel, 35.0, 30.5, First_Contact'Address);
      Check_Pixel (30, 30, Blue_Ink);
      Assert
        (Get_Iter_From_String (Tree.Get_Model, "0:0:0") = Null_Iter
         and then Tree.Get_Selection.Iter_Is_Selected
           (Get_Iter_From_String (Tree.Get_Model, "0:0")),
         "Canceled erase restores the selected revision without a branch");
      Activate ("eraser");
      Touch (Gdk.Event.Touch_Begin, 30.0, 30.5, First_Contact'Address);
      Touch (Gdk.Event.Touch_End, 30.0, 30.5, First_Contact'Address);
      Check_Pixel (30, 30, (255, 255, 255));
      Activate ("save");
      Assert (Get_Iter_From_String (Tree.Get_Model, "0:0:0") /= Null_Iter,
              "Finger erasing saves a child of the selected revision");
      Tree.Get_Selection.Unselect_All;
      Tree.Get_Selection.Select_Iter
        (Get_Iter_From_String (Tree.Get_Model, "0:0"));
      Check_Pixel (30, 30, Blue_Ink);
      Reset_Agents_From_Task (Frontend);
      Drain_Events;
      Assert (not Toggle.Get_Active and then Scroll.Get_Kinetic_Scrolling,
              "Session reset clears the opt-in");
      Frontend.Request_Shutdown;
      Main_Window (Frontend).Destroy;
   exception
      when others =>
         if Main_Window (Frontend) /= null then
            Frontend.Request_Shutdown;
            Main_Window (Frontend).Destroy;
         end if;
         raise;
   end Test_Canvas_Finger_Drawing;

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
           ("Coyote.GUI Canvas finger drawing",
            Test_Canvas_Finger_Drawing'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Canvas clipboard image import",
            Test_Canvas_Clipboard_Import'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Canvas file import and session reset",
            Test_Canvas_File_Import'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Canvas session recovery and writer lease",
            Test_Canvas_Session_Recovery'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Canvas authorized shell import",
            Test_Canvas_Agent_Import'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Canvas typed attachments", Test_Canvas_Attachments'Access));
      Result.Add_Test
        (Coyote_App_Frontend_GUI_Caller.Create
           ("Coyote.GUI Help Canvas topics and contextual click",
            Test_Canvas_Help'Access));
      return Result;
   end Suite;

end Coyote_App_Frontend_GUI_Tests;
