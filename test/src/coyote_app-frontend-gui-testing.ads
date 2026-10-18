--  Coyote_App.Frontend.GUI.Testing — test-only widget accessors.
--
--  Project: coyote

with Coyote_App.Agent_RPC;
with Coyote_GUI;
with Gtk.Box;
with Gtk.Dialog;
with Gtk.Image;
with Gtk.Menu_Item;
with Gtk.Progress_Bar;
with Gtk.Separator;
with Gtk.Tree_View;
with Gtk.Window;

package Coyote_App.Frontend.GUI.Testing is

   function Status_Text
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   function Main_Window
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Window.Gtk_Window;

   function Outer_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box;

   function Prompt_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box;

   function Status_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box;

   function Status_Content_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box;

   function Context_Progress
     (F : Coyote_App.Frontend.GUI.Instance)
     return Gtk.Progress_Bar.Gtk_Progress_Bar;

   function Conversation_Prompt_Separator
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Separator.Gtk_Separator;

   function Prompt_Status_Separator
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Separator.Gtk_Separator;

   function Agents_Window
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Window.Gtk_Window;

   function Agents_View
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Tree_View.Gtk_Tree_View;

   function Sandbox_Profiles_Item
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Menu_Item.Gtk_Menu_Item;

   function Sandbox_Profiles_Created
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean;

   function Sandbox_Profiles_Title
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   procedure Apply_Handshake
     (F               : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id        :        String;
      Parent_Agent_Id :        String;
      Label           :        String);

   procedure Apply_Handshake
     (F               : in out Coyote_App.Frontend.GUI.Instance;
      RPC_Generation  :        Natural;
      Agent_Id        :        String;
      Parent_Agent_Id :        String;
      Label           :        String);

   procedure Apply_Event
     (F          : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id   :        String;
      Sequence   :        Natural;
      Event_Name :        Coyote_App.Agent_RPC.Event_Kind;
      Payload    :        String);

   procedure Apply_Event
     (F              : in out Coyote_App.Frontend.GUI.Instance;
      RPC_Generation :        Natural;
      Agent_Id       :        String;
      Sequence       :        Natural;
      Event_Name     :        Coyote_App.Agent_RPC.Event_Kind;
      Payload        :        String);

   procedure Apply_Terminal
     (F              : in out Coyote_App.Frontend.GUI.Instance;
      RPC_Generation :        Natural;
      Agent_Id       :        String;
      Status         :        Coyote_App.Agent_RPC.Terminal_Status);

   procedure Reset_Agents_From_Task
     (F : in out Coyote_App.Frontend.GUI.Instance);

   procedure Select_Agent
     (F : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id :        String);

   function GTK_Selected_Agent
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   function RPC_Generation
     (F : Coyote_App.Frontend.GUI.Instance) return Natural;

   function RPC_Service_Running
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean;

   function RPC_Service_Endpoint
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   function Next_RPC_Endpoint
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   function Non_Root_History_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural;

   function Root_Session_Identity
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   function Registry_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural;

   function History_Entry_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural;

   function History_Update_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural;

   function Selected_Agent
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   function Root_Ready
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean;

   function Conversation_Has_Exchange
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean;

   function Conversation_Active_Text
     (F : Coyote_App.Frontend.GUI.Instance) return String;

   function Conversation_Tool_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural;

   function Tool_Status_Label
     (F       : Coyote_App.Frontend.GUI.Instance;
      Tool_Id : String)
      return String;

   function Tool_Detail
     (F       : Coyote_App.Frontend.GUI.Instance;
      Tool_Id : String)
      return Coyote_GUI.Tool_Info;

   procedure Build_Product_Information
     (F      :     Coyote_App.Frontend.GUI.Instance;
      Dialog : out Gtk.Dialog.Gtk_Dialog;
      Image  : out Gtk.Image.Gtk_Image);

end Coyote_App.Frontend.GUI.Testing;
