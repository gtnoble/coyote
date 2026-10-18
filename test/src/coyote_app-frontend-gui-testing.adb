--  Coyote_App.Frontend.GUI.Testing — test-only widget accessors.
--
--  Project: coyote

with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Coyote_App.Agent_RPC;
with Coyote_App.Agent_Registry;
with Coyote_App.Agent_RPC.Service;
with Coyote_GUI;
with Coyote_GUI.Conversation_Stack.Testing;
with GNAT.OS_Lib;
with Glib.Values;

package body Coyote_App.Frontend.GUI.Testing is
   use type Coyote_App.Agent_Registry.Lifecycle_Status;
   use type Gtk.Tree_Model.Gtk_Tree_Iter;

   function Main_Window
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Window.Gtk_Window
   is
   begin
      return F.Win;
   end Main_Window;

   function Outer_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box
   is
   begin
      return F.Outer_Box;
   end Outer_Box;

   function Prompt_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box
   is
   begin
      return F.Prompt_Box;
   end Prompt_Box;

   function Status_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box
   is
   begin
      return F.Status_Box;
   end Status_Box;

   function Status_Content_Box
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Box.Gtk_Box
   is
   begin
      return F.Status_Content_Box;
   end Status_Content_Box;

   function Context_Progress
     (F : Coyote_App.Frontend.GUI.Instance)
     return Gtk.Progress_Bar.Gtk_Progress_Bar
   is
   begin
      return F.Context_Progress;
   end Context_Progress;

   function Conversation_Prompt_Separator
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Separator.Gtk_Separator
   is
   begin
      return F.Conversation_Prompt_Sep;
   end Conversation_Prompt_Separator;

   function Prompt_Status_Separator
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Separator.Gtk_Separator
   is
   begin
      return F.Prompt_Status_Sep;
   end Prompt_Status_Separator;

   function Agents_Window
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Window.Gtk_Window
   is
   begin
      return F.Agents_Window;
   end Agents_Window;

   function Agents_View
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Tree_View.Gtk_Tree_View
   is
   begin
      return F.Agents_View;
   end Agents_View;

   function Sandbox_Profiles_Item
     (F : Coyote_App.Frontend.GUI.Instance) return Gtk.Menu_Item.Gtk_Menu_Item
   is
   begin
      return F.Sandbox_Profiles_Item;
   end Sandbox_Profiles_Item;

   function Sandbox_Profiles_Created
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean
   is
   begin
      return
        Coyote_GUI.Sandbox_Profile_Window.Is_Created
          (F.Sandbox_Profile_Window);
   end Sandbox_Profiles_Created;

   function Sandbox_Profiles_Title
     (F : Coyote_App.Frontend.GUI.Instance) return String
   is
   begin
      return
        Coyote_GUI.Sandbox_Profile_Window.Window_Title
          (F.Sandbox_Profile_Window);
   end Sandbox_Profiles_Title;

   procedure Apply_Handshake
     (F               : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id        :        String;
      Parent_Agent_Id :        String;
      Label           :        String)
   is
   begin
      Apply_Handshake
        (F, RPC_Generation (F), Agent_Id, Parent_Agent_Id, Label);
   end Apply_Handshake;

   procedure Apply_Handshake
     (F               : in out Coyote_App.Frontend.GUI.Instance;
      RPC_Generation  :        Natural;
      Agent_Id        :        String;
      Parent_Agent_Id :        String;
      Label           :        String)
   is
      Update : Coyote_GUI.Update;
   begin
      Update.Kind           := Coyote_GUI.Rpc_Frame;
      Update.RPC_Generation := RPC_Generation;
      Update.Text :=
        To_Unbounded_String
          (Coyote_App.Agent_RPC.Encode
             (Coyote_App.Agent_RPC.Make_Handshake
                (Agent_Id        => Agent_Id,
                 Parent_Agent_Id => Parent_Agent_Id,
                 Label           => Label)));
      Coyote_App.Frontend.GUI.Apply_RPC_Frame (F, Update);
   end Apply_Handshake;

   procedure Apply_Event
     (F          : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id   :        String;
      Sequence   :        Natural;
      Event_Name :        Coyote_App.Agent_RPC.Event_Kind;
      Payload    :        String)
   is
   begin
      Apply_Event
        (F, RPC_Generation (F), Agent_Id, Sequence, Event_Name, Payload);
   end Apply_Event;

   procedure Apply_Event
     (F              : in out Coyote_App.Frontend.GUI.Instance;
      RPC_Generation :        Natural;
      Agent_Id       :        String;
      Sequence       :        Natural;
      Event_Name     :        Coyote_App.Agent_RPC.Event_Kind;
      Payload        :        String)
   is
      Update : Coyote_GUI.Update;
   begin
      Update.Kind           := Coyote_GUI.Rpc_Frame;
      Update.RPC_Generation := RPC_Generation;
      Update.Text :=
        To_Unbounded_String
          (Coyote_App.Agent_RPC.Encode
             (Coyote_App.Agent_RPC.Make_Event
                (Agent_Id     => Agent_Id,
                 Sequence     => Sequence,
                 Event_Name   => Event_Name,
                 Payload_Json => Payload)));
      Coyote_App.Frontend.GUI.Apply_RPC_Frame (F, Update);
   end Apply_Event;

   procedure Apply_Terminal
     (F              : in out Coyote_App.Frontend.GUI.Instance;
      RPC_Generation :        Natural;
      Agent_Id       :        String;
      Status         :        Coyote_App.Agent_RPC.Terminal_Status)
   is
      Update : Coyote_GUI.Update;
   begin
      Update.Kind           := Coyote_GUI.Rpc_Frame;
      Update.RPC_Generation := RPC_Generation;
      Update.Text :=
        To_Unbounded_String
          (Coyote_App.Agent_RPC.Encode
             (Coyote_App.Agent_RPC.Make_Terminal
                (Agent_Id => Agent_Id, Status => Status)));
      Coyote_App.Frontend.GUI.Apply_RPC_Frame (F, Update);
   end Apply_Terminal;

   procedure Reset_Agents_From_Task
     (F : in out Coyote_App.Frontend.GUI.Instance)
   is
      Reset_Error  : Ada.Exceptions.Exception_Occurrence;
      Reset_Failed : Boolean := False;

      task Reset_Task is
         entry Complete;
      end Reset_Task;

      task body Reset_Task is
      begin
         begin
            Coyote_App.Frontend.GUI.Reset_Agents (F);
         exception
            when Error : others =>
               Ada.Exceptions.Save_Occurrence (Reset_Error, Error);
               Reset_Failed := True;
         end;
         accept Complete;
      end Reset_Task;
   begin
      Reset_Task.Complete;
      if Reset_Failed then
         Ada.Exceptions.Reraise_Occurrence (Reset_Error);
      end if;
   end Reset_Agents_From_Task;

   procedure Select_Agent
     (F : in out Coyote_App.Frontend.GUI.Instance;
      Agent_Id :        String)
   is
      Model : constant Gtk.Tree_Model.Gtk_Tree_Model :=
        Gtk.Tree_View.Get_Model (F.Agents_View);
      Iter  : Gtk.Tree_Model.Gtk_Tree_Iter;
      Value : Glib.Values.GValue;
      Found : Boolean := False;

      procedure Find_Agent
        (Parent : Gtk.Tree_Model.Gtk_Tree_Iter)
      is
         Child : Gtk.Tree_Model.Gtk_Tree_Iter;
      begin
         if Gtk.Tree_Model.N_Children (Model, Parent) = 0 then
            return;
         end if;
         Child := Gtk.Tree_Model.Children (Model, Parent);
         while Child /= Gtk.Tree_Model.Null_Iter loop
            Gtk.Tree_Model.Get_Value (Model, Child, 2, Value);
            declare
               Runtime_Id : constant String := Glib.Values.Get_String (Value);
            begin
               Glib.Values.Unset (Value);
               if Runtime_Id = Agent_Id then
                  Iter := Child;
                  Found := True;
                  return;
               end if;
            end;
            Find_Agent (Child);
            if Found then
               return;
            end if;
            Gtk.Tree_Model.Next (Model, Child);
         end loop;
      end Find_Agent;
   begin
      Find_Agent (Gtk.Tree_Model.Null_Iter);
      if not Found then
         raise Constraint_Error with "agent row not found: " & Agent_Id;
      end if;
      Gtk.Tree_View.Get_Selection (F.Agents_View).Select_Iter (Iter);
   end Select_Agent;

   function GTK_Selected_Agent
     (F : Coyote_App.Frontend.GUI.Instance) return String
   is
      Model : Gtk.Tree_Model.Gtk_Tree_Model;
      Iter  : Gtk.Tree_Model.Gtk_Tree_Iter;
      Value : Glib.Values.GValue;
   begin
      Gtk.Tree_View.Get_Selection (F.Agents_View).Get_Selected (Model, Iter);
      if Iter = Gtk.Tree_Model.Null_Iter then
         return "";
      end if;
      Gtk.Tree_Model.Get_Value (Model, Iter, 2, Value);
      declare
         Result : constant String := Glib.Values.Get_String (Value);
      begin
         Glib.Values.Unset (Value);
         return Result;
      end;
   end GTK_Selected_Agent;

   function RPC_Generation
     (F : Coyote_App.Frontend.GUI.Instance) return Natural is
   begin
      return F.RPC_Generation;
   end RPC_Generation;

   function RPC_Service_Running
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean is
   begin
      return Coyote_App.Agent_RPC.Service.Is_Running (F.RPC_Service);
   end RPC_Service_Running;

   function RPC_Service_Endpoint
     (F : Coyote_App.Frontend.GUI.Instance) return String is
   begin
      return Coyote_App.Agent_RPC.Service.Endpoint (F.RPC_Service);
   end RPC_Service_Endpoint;

   function Next_RPC_Endpoint
     (F : Coyote_App.Frontend.GUI.Instance) return String
   is
      Pid_Image : constant String :=
        Ada.Strings.Fixed.Trim
          (Integer'Image
             (GNAT.OS_Lib.Pid_To_Integer
                (GNAT.OS_Lib.Current_Process_Id)),
           Ada.Strings.Both);
   begin
      return "/tmp/coyote-agent-" & Pid_Image & "-"
        & Ada.Strings.Fixed.Trim
            (Natural'Image
               (Natural
                  (Coyote_App.Agent_RPC.Service.Generation
                     (F.RPC_Service)) + 1),
             Ada.Strings.Both)
        & ".sock";
   end Next_RPC_Endpoint;

   function Non_Root_History_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural
   is
      Count : Natural := 0;
   begin
      for History_Item of F.Histories loop
         if To_String (History_Item.Runtime_Id)
           /= To_String (F.Root_Agent_Id)
         then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Non_Root_History_Count;

   function Root_Session_Identity
     (F : Coyote_App.Frontend.GUI.Instance) return String
   is
      Root : constant Coyote_App.Agent_Registry.Agent_Record :=
        Coyote_App.Agent_Registry.Get_Agent
          (F.Agent_Registry,
           Coyote_App.Agent_Registry.Create_Agent_Id
             (To_String (F.Root_Agent_Id)));
   begin
      return To_String (Root.Durable_Session_Id);
   end Root_Session_Identity;

   function Registry_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural is
   begin
      return Coyote_App.Agent_Registry.Agent_Count (F.Agent_Registry);
   end Registry_Count;

   function History_Entry_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural is
   begin
      return Natural (F.Histories.Length);
   end History_Entry_Count;

   function History_Update_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural is
      Count : Natural := 0;
   begin
      for History_Item of F.Histories loop
         Count := Count + Natural (History_Item.Updates.Length);
      end loop;
      return Count;
   end History_Update_Count;

   function Selected_Agent
     (F : Coyote_App.Frontend.GUI.Instance) return String is
   begin
      return To_String (F.Selected_Agent_Id);
   end Selected_Agent;

   function Root_Ready
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean is
   begin
      return Coyote_App.Agent_Registry.Get_Agent
        (F.Agent_Registry,
         Coyote_App.Agent_Registry.Create_Agent_Id
           (To_String (F.Root_Agent_Id))).Status
        = Coyote_App.Agent_Registry.Ready;
   end Root_Ready;

   function Conversation_Has_Exchange
     (F : Coyote_App.Frontend.GUI.Instance) return Boolean is
   begin
      return Coyote_GUI.Conversation_Stack.Testing.Has_Exchange (F.Stack);
   end Conversation_Has_Exchange;

   function Conversation_Active_Text
     (F : Coyote_App.Frontend.GUI.Instance) return String is
   begin
      return Coyote_GUI.Conversation_Stack.Testing.Active_Text (F.Stack);
   end Conversation_Active_Text;

   function Conversation_Tool_Count
     (F : Coyote_App.Frontend.GUI.Instance) return Natural is
   begin
      return Coyote_GUI.Conversation_Stack.Testing.Tool_Count (F.Stack);
   end Conversation_Tool_Count;

   function Tool_Status_Label
     (F       : Coyote_App.Frontend.GUI.Instance;
      Tool_Id : String)
      return String
   is
   begin
      return
        Coyote_GUI.Conversation_Stack.Testing.Tool_Status_Label
          (F.Stack, Tool_Id);
   end Tool_Status_Label;

   function Tool_Detail
     (F       : Coyote_App.Frontend.GUI.Instance;
      Tool_Id : String)
      return Coyote_GUI.Tool_Info
   is
   begin
      return
        Coyote_GUI.Conversation_Stack.Testing.Tool_Detail
          (F.Stack, Tool_Id);
   end Tool_Detail;

   procedure Build_Product_Information
     (F      :     Coyote_App.Frontend.GUI.Instance;
      Dialog : out Gtk.Dialog.Gtk_Dialog;
      Image  : out Gtk.Image.Gtk_Image)
   is
   begin
      Coyote_App.Frontend.GUI.Build_Product_Information (F.Win, Dialog, Image);
   end Build_Product_Information;

end Coyote_App.Frontend.GUI.Testing;
