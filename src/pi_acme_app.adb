--  Pi_Acme_App body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;          use GNATCOLL.JSON;
with GNATCOLL.OS.FS;
with GNATCOLL.OS.Process;
with LLM.Agent;
with LLM.Events;
with LLM.Model_Registry;
with LLM.Providers;
with LLM.Settings;
with LLM.Types;
with Nine_P;                 use Nine_P;
with Nine_P.Client;          use Nine_P.Client;
with Nine_P.Proto;
with Acme.Event_Parser;
with Acme.Raw_Events;
with Acme.Window;
with Pi_Acme_App.History;    use Pi_Acme_App.History;
with Pi_Acme_App.Dispatch;   use Pi_Acme_App.Dispatch;
with Pi_Acme_App.Utils;      use Pi_Acme_App.Utils;
with Session_Lister;         use Session_Lister;

package body Pi_Acme_App is

   use type LLM.Events.Message_Update_Kind;

   --  POSIX getpid() — used to build window-specific selector tokens.
   function Getpid return Integer;
   pragma Import (C, Getpid, "getpid");

   --  ── App_State body ────────────────────────────────────────────────────

   protected body App_State is

      function Session_Id         return String  is
        (To_String (P_Session_Id));
      function Current_Model      return String  is
        (To_String (P_Model));
      function Current_Agent      return String  is
        (To_String (P_Agent));
      function Current_Thinking   return String  is
        (To_String (P_Thinking));
      function Is_Streaming       return Boolean is (P_Streaming);
      function Is_Compacting      return Boolean is (P_Compacting);
      function Was_Aborted        return Boolean is (P_Aborted);
      function Is_Retrying        return Boolean is (P_Is_Retrying);
      function Text_Emitted       return Boolean is (P_Text_Emitted);
      function Has_Tool_In_Turn return Boolean is (P_Has_Tool_In_Turn);
      function Pending_Stats      return Boolean is (P_Pending_Stats);
      function Models_Pending     return Boolean is (P_Models_Pending);
      function Context_Window     return Natural is (P_Ctx_Win);
      function Turn_Input_Tokens  return Natural is (P_Turn_In);
      function Turn_Output_Tokens return Natural is (P_Turn_Out);
      function Turn_Count         return Natural is (P_Turn_Count);
      function Turn_Cost_Dmil     return Natural is (P_Turn_Cost);
      function Session_Cost_Dmil  return Natural is (P_Sess_Cost);
      function Session_Input_Tokens  return Natural is (P_Sess_In);
      function Session_Output_Tokens return Natural is (P_Sess_Out);
      function Session_Cache_Read    return Natural is (P_Sess_Cache_R);
      function Session_Cache_Write   return Natural is (P_Sess_Cache_W);
      function Session_Total_Tokens  return Natural is (P_Sess_Total);
      function Win_Name           return String  is
        (To_String (P_Win_Name));

      procedure Set_Session_Id (Id : String) is
      begin
         P_Session_Id := To_Unbounded_String (Id);
      end Set_Session_Id;

      procedure Set_Model (Model : String) is
      begin
         P_Model := To_Unbounded_String (Model);
      end Set_Model;

      procedure Set_Agent (Agent : String) is
      begin
         P_Agent := To_Unbounded_String (Agent);
      end Set_Agent;

      procedure Set_Thinking (Level : String) is
      begin
         P_Thinking := To_Unbounded_String (Level);
      end Set_Thinking;

      procedure Set_Streaming (Value : Boolean) is
      begin
         P_Streaming := Value;
      end Set_Streaming;

      procedure Set_Compacting (Value : Boolean) is
      begin
         P_Compacting := Value;
      end Set_Compacting;

      procedure Set_Aborted (Value : Boolean) is
      begin
         P_Aborted := Value;
      end Set_Aborted;

      procedure Set_Is_Retrying (Value : Boolean) is
      begin
         P_Is_Retrying := Value;
      end Set_Is_Retrying;

      procedure Set_Text_Emitted (Value : Boolean) is
      begin
         P_Text_Emitted := Value;
      end Set_Text_Emitted;

      function Has_Text_Delta return Boolean is (P_Has_Text_Delta);

      procedure Set_Has_Text_Delta (Value : Boolean) is
      begin
         P_Has_Text_Delta := Value;
      end Set_Has_Text_Delta;

      procedure Set_Has_Tool_In_Turn (Value : Boolean) is
      begin
         P_Has_Tool_In_Turn := Value;
      end Set_Has_Tool_In_Turn;

      function Last_Stop_Reason return String is
        (To_String (P_Last_Stop_Reason));

      procedure Set_Last_Stop_Reason (Value : String) is
      begin
         P_Last_Stop_Reason := To_Unbounded_String (Value);
      end Set_Last_Stop_Reason;

      function Last_Error_Message return String is
        (To_String (P_Last_Error_Message));

      procedure Set_Last_Error_Message (Value : String) is
      begin
         P_Last_Error_Message := To_Unbounded_String (Value);
      end Set_Last_Error_Message;

      procedure Set_Pending_Stats (Value : Boolean) is
      begin
         P_Pending_Stats := Value;
      end Set_Pending_Stats;

      procedure Set_Models_Pending (Value : Boolean) is
      begin
         P_Models_Pending := Value;
      end Set_Models_Pending;

      procedure Set_Context_Window (N : Natural) is
      begin
         P_Ctx_Win := N;
      end Set_Context_Window;

      procedure Set_Turn_Tokens (Input, Output : Natural) is
      begin
         P_Turn_In  := Input;
         P_Turn_Out := Output;
      end Set_Turn_Tokens;

      procedure Set_Turn_Cost (Dmil : Natural) is
      begin
         P_Turn_Cost := Dmil;
      end Set_Turn_Cost;

      procedure Set_Session_Stats
        (Cost_Dmil   : Natural;
         Input       : Natural;
         Output      : Natural;
         Cache_Read  : Natural;
         Cache_Write : Natural;
         Total       : Natural)
      is
      begin
         P_Sess_Cost    := Cost_Dmil;
         P_Sess_In      := Input;
         P_Sess_Out     := Output;
         P_Sess_Cache_R := Cache_Read;
         P_Sess_Cache_W := Cache_Write;
         P_Sess_Total   := Total;
      end Set_Session_Stats;

      procedure Set_Win_Name (Name : String) is
      begin
         P_Win_Name := To_Unbounded_String (Name);
      end Set_Win_Name;

      procedure Increment_Turn_Count is
      begin
         P_Turn_Count := P_Turn_Count + 1;
      end Increment_Turn_Count;

      procedure Set_Turn_Count (N : Natural) is
      begin
         P_Turn_Count := N;
      end Set_Turn_Count;

      procedure Reset_Turn_Count is
      begin
         P_Turn_Count := 0;
      end Reset_Turn_Count;

      procedure Set_One_Shot_Result (Json : String) is
      begin
         --  First write wins; ignore subsequent calls so that the exception
         --  handler cannot clobber an already-captured success result.
         if Length (P_One_Shot_Result) = 0 then
            P_One_Shot_Result := To_Unbounded_String (Json);
         end if;
      end Set_One_Shot_Result;

      function One_Shot_Result return String is
      begin
         return To_String (P_One_Shot_Result);
      end One_Shot_Result;

      procedure Signal_Shutdown is
      begin
         P_Shutdown := True;
      end Signal_Shutdown;

      entry Wait_Shutdown when P_Shutdown is
      begin
         null;
      end Wait_Shutdown;

      procedure Request_Reload (UUID : String) is
      begin
         P_Reload_UUID      := To_Unbounded_String (UUID);
         P_Reload_Requested := True;
         P_Restart_Complete := False;
         P_Restart_Was_Done := False;
      end Request_Reload;

      procedure Consume_Reload
        (UUID          : out Ada.Strings.Unbounded.Unbounded_String;
         Was_Requested : out Boolean)
      is
      begin
         Was_Requested      := P_Reload_Requested;
         UUID               := P_Reload_UUID;
         P_Reload_Requested := False;
      end Consume_Reload;

      procedure Signal_Restart_Done is
      begin
         P_Restart_Was_Done := True;
         P_Restart_Complete := True;
      end Signal_Restart_Done;

      procedure Signal_Restart_Aborted is
      begin
         P_Restart_Was_Done := False;
         P_Restart_Complete := True;
      end Signal_Restart_Aborted;

      entry Wait_Restart_Complete (Was_Restarted : out Boolean)
        when P_Restart_Complete
      is
      begin
         Was_Restarted      := P_Restart_Was_Done;
         P_Restart_Complete := False;
         P_Restart_Was_Done := False;
      end Wait_Restart_Complete;

   end App_State;

   --  ── Agent command queue ───────────────────────────────────────────────

   type Agent_Command_Kind is
     (Prompt_Command,
      New_Session_Command,
      Switch_Session_Command,
      Set_Model_Command,
      Set_Thinking_Command,
      Shutdown_Command);

   MAX_PENDING_COMMANDS : constant Positive := 64;

   subtype Command_Slot is Positive range 1 .. MAX_PENDING_COMMANDS;

   type Command_Kind_Array is array (Command_Slot) of Agent_Command_Kind;
   type Command_Text_Array is array (Command_Slot) of Unbounded_String;
   type Command_Flag_Array is array (Command_Slot) of Boolean;

   protected type Agent_Command_Queue is
      entry Enqueue
        (Kind     : Agent_Command_Kind;
         Text     : String := "";
         Is_Steer : Boolean := False);
      entry Dequeue
        (Kind     : out Agent_Command_Kind;
         Text     : out Unbounded_String;
         Is_Steer : out Boolean);
      procedure Signal_Shutdown;
   private
      Kinds      : Command_Kind_Array := (others => Shutdown_Command);
      Texts      : Command_Text_Array;
      Steer_Flag : Command_Flag_Array := (others => False);
      Head       : Command_Slot := Command_Slot'First;
      Tail       : Command_Slot := Command_Slot'First;
      Count      : Natural := 0;
      Done       : Boolean := False;
   end Agent_Command_Queue;

   protected body Agent_Command_Queue is

      entry Enqueue
        (Kind     : Agent_Command_Kind;
         Text     : String := "";
         Is_Steer : Boolean := False)
        when Count < MAX_PENDING_COMMANDS and then not Done
      is
      begin
         Kinds (Tail) := Kind;
         Texts (Tail) := To_Unbounded_String (Text);
         Steer_Flag (Tail) := Is_Steer;
         if Tail = Command_Slot'Last then
            Tail := Command_Slot'First;
         else
            Tail := Tail + 1;
         end if;
         Count := Count + 1;
      end Enqueue;

      entry Dequeue
        (Kind     : out Agent_Command_Kind;
         Text     : out Unbounded_String;
         Is_Steer : out Boolean)
        when Count > 0 or else Done
      is
      begin
         if Count = 0 then
            Kind := Shutdown_Command;
            Text := Null_Unbounded_String;
            Is_Steer := False;
            return;
         end if;

         Kind := Kinds (Head);
         Text := Texts (Head);
         Is_Steer := Steer_Flag (Head);
         Texts (Head) := Null_Unbounded_String;
         Steer_Flag (Head) := False;

         if Head = Command_Slot'Last then
            Head := Command_Slot'First;
         else
            Head := Head + 1;
         end if;
         Count := Count - 1;
      end Dequeue;

      procedure Signal_Shutdown is
      begin
         Done := True;
      end Signal_Shutdown;

   end Agent_Command_Queue;

   function Thinking_Level_Of
     (Name : String) return LLM.Providers.Thinking_Level
   is
      Value : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      if Value = "minimal" then
         return LLM.Providers.Minimal;
      elsif Value = "low" then
         return LLM.Providers.Low;
      elsif Value = "medium" then
         return LLM.Providers.Medium;
      elsif Value = "high" then
         return LLM.Providers.High;
      elsif Value = "xhigh" or else Value = "x_high" then
         return LLM.Providers.X_High;
      else
         return LLM.Providers.Off;
      end if;
   end Thinking_Level_Of;

   procedure Split_Model_Spec
     (Spec     :     String;
      Provider : out Unbounded_String;
      Model_Id : out Unbounded_String)
   is
      Slash : constant Natural := Ada.Strings.Fixed.Index (Spec, "/");
   begin
      if Slash = 0
        or else Slash = Spec'First
        or else Slash = Spec'Last
      then
         raise Constraint_Error with
           "Model spec must be provider/model-id: " & Spec;
      end if;

      Provider := To_Unbounded_String (Spec (Spec'First .. Slash - 1));
      Model_Id := To_Unbounded_String (Spec (Slash + 1 .. Spec'Last));
   end Split_Model_Spec;

   --  ── Run ───────────────────────────────────────────────────────────────

   procedure Run (Opts : Options) is
      Tag_Extra : constant String :=
        (if Opts.One_Shot
         then " | Stop Steer"
         else " | Send Stop Steer New Compact Clear"
              & " Models Sessions Thinking Stats");

      --  Process ID used to build window-specific selector tokens.
      My_PID : constant String := Natural_Image (Natural (Getpid));

      --  ── List_Sessions_Text ──────────────────────────────────────────
      --
      --  Returns one PID-tagged session token per line:
      --    llm-chat+PID/UUID<TAB>name<TAB>date<TAB>snippet
      --
      --  The PID prefix ensures that button-3 in the +sessions window
      --  routes the plumb message only to this pi-acme instance.
      --  Referencing My_PID directly avoids a redundant string build.
      function List_Sessions_Text return String is
         Sessions : constant Session_Vectors.Vector :=
           List_Sessions (Ada.Directories.Current_Directory);
         Result   : Unbounded_String;
      begin
         Append
           (Result,
            "# Button-3 any llm-chat+ token to load that session."
            & ASCII.LF & ASCII.LF);
         for Session of Sessions loop
            Append
              (Result,
               "llm-chat+" & My_PID & "/" & To_String (Session.UUID)
               & ASCII.HT & To_String (Session.Name)
               & ASCII.HT & To_String (Session.Date)
               & ASCII.HT & To_String (Session.Snippet)
               & ASCII.LF);
         end loop;
         return To_String (Result);
      end List_Sessions_Text;

      --  Shared objects — all tasks close over these:
      Win_FS : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
      Win    : Acme.Window.Win := Acme.Window.New_Win (Win_FS'Access);
      State         : App_State;
      Agent_Session : LLM.Agent.Session;
      Commands      : Agent_Command_Queue;

      function Status_Label return String is
      begin
         if State.Is_Compacting then
            return "compacting";
         elsif State.Is_Retrying then
            return "retrying";
         elsif State.Is_Streaming then
            return "running";
         else
            return "ready";
         end if;
      end Status_Label;

      procedure Initiate_Shutdown is
      begin
         LLM.Agent.Request_Abort (Agent_Session);
         Commands.Signal_Shutdown;
         State.Signal_Shutdown;
      exception
         when others =>
            Commands.Signal_Shutdown;
            State.Signal_Shutdown;
      end Initiate_Shutdown;

      --  ── Inner task declarations ────────────────────────────────────────

      task Agent_Task;
      task Acme_Event_Task;
      task Plumb_Model_Task;
      task Plumb_Session_Task;
      task Plumb_Thinking_Task;

      --  ── Agent_Task ────────────────────────────────────────────────────

      task body Agent_Task is
         My_FS            : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Section          : Section_Kind             := No_Section;
         Current_Thinking : Unbounded_String := Null_Unbounded_String;
         Current_Text     : Unbounded_String := Null_Unbounded_String;
         Final_Text       : Unbounded_String := Null_Unbounded_String;
         Final_Error      : Unbounded_String := Null_Unbounded_String;
         Was_Aborted      : Boolean          := False;

         procedure Reset_One_Shot_Tracking is
         begin
            Current_Text := Null_Unbounded_String;
            Final_Text := Null_Unbounded_String;
            Final_Error := Null_Unbounded_String;
            Was_Aborted := False;
         end Reset_One_Shot_Tracking;

         procedure Track_Event (E : LLM.Events.Agent_Event'Class) is
         begin
            if E in LLM.Events.Message_Update_Event then
               declare
                  Event : constant LLM.Events.Message_Update_Event :=
                    LLM.Events.Message_Update_Event (E);
               begin
                  if Event.Kind = LLM.Events.Text_Delta then
                     Append (Current_Text, To_String (Event.Delta_Text));
                  end if;
               end;
            elsif E in LLM.Events.Message_End_Event then
               declare
                  Event : constant LLM.Events.Message_End_Event :=
                    LLM.Events.Message_End_Event (E);
               begin
                  if Event.Stop in LLM.Types.Stop | LLM.Types.Length then
                     Final_Text := Current_Text;
                  end if;
                  if Length (Event.Err_Msg) > 0 then
                     Final_Error := Event.Err_Msg;
                  end if;
                  Current_Text := Null_Unbounded_String;
               end;
            elsif E in LLM.Events.Agent_End_Event then
               Was_Aborted :=
                 LLM.Events.Agent_End_Event (E).Was_Aborted;
            end if;
         end Track_Event;

         procedure Dispatch_Event (E : LLM.Events.Agent_Event'Class) is
         begin
            Track_Event (E);
            Dispatch_Pi_Event
              (Event   => E,
               Win     => Win,
               FS      => My_FS'Access,
               State   => State,
               Section => Section,
               PID     => My_PID);
         end Dispatch_Event;

         procedure Emit_Model_Select is
            Model_Spec : constant String :=
              LLM.Agent.Current_Model_Spec (Agent_Session);
            Provider   : Unbounded_String;
            Model_Id   : Unbounded_String;
         begin
            if Model_Spec'Length = 0 then
               return;
            end if;

            Split_Model_Spec (Model_Spec, Provider, Model_Id);
            declare
               Event : constant LLM.Events.Model_Select_Event :=
                 (LLM.Events.Agent_Event with
                  Provider       => Provider,
                  Model_Id       => Model_Id,
                  Context_Window => LLM.Agent.Context_Window (Agent_Session));
            begin
               Dispatch_Event (Event);
            end;
         end Emit_Model_Select;

         procedure Emit_Session_Info is
            Event : constant LLM.Events.Session_Info_Event :=
              (LLM.Events.Agent_Event with
               Session_Id     =>
                 To_Unbounded_String (LLM.Agent.Session_Id (Agent_Session)),
               Thinking_Level => Current_Thinking);
         begin
            Dispatch_Event (Event);
         end Emit_Session_Info;

         procedure Emit_Bootstrap is
         begin
            Emit_Model_Select;
            Emit_Session_Info;
         end Emit_Bootstrap;

         procedure Append_Task_Warning (Message : String) is
         begin
            Acme.Window.Append
              (Win,
               My_FS'Access,
               ASCII.LF & "[!] " & Message & ASCII.LF);
         end Append_Task_Warning;

         procedure Render_Loaded_Session (UUID : String) is
            Short_Id : constant String :=
              (if UUID'Length >= 8
               then UUID (UUID'First .. UUID'First + 7)
               else UUID);
         begin
            Acme.Window.Append
              (Win,
               My_FS'Access,
               ASCII.LF
               & "[Loading session " & Short_Id & UC_ELLIP & "]"
               & ASCII.LF);
            Render_Session_History
              (UUID  => UUID,
               Win   => Win,
               FS    => My_FS'Access,
               State => State);
         end Render_Loaded_Session;

         procedure Reset_Session_State is
         begin
            State.Set_Streaming (False);
            State.Set_Compacting (False);
            State.Set_Aborted (False);
            State.Set_Is_Retrying (False);
            State.Set_Text_Emitted (False);
            State.Set_Has_Text_Delta (False);
            State.Set_Has_Tool_In_Turn (False);
            State.Set_Last_Stop_Reason ("");
            State.Set_Last_Error_Message ("");
            State.Set_Pending_Stats (False);
            State.Set_Models_Pending (False);
            State.Set_Turn_Tokens (0, 0);
            State.Set_Turn_Cost (0);
            State.Set_Session_Stats (0, 0, 0, 0, 0, 0);
            State.Reset_Turn_Count;
         end Reset_Session_State;

         procedure Store_One_Shot_Result is
            Result : constant JSON_Value := Create_Object;
         begin
            if Was_Aborted then
               State.Set_One_Shot_Result ("{""error"":""aborted""}");
            elsif Length (Final_Text) > 0 then
               Result.Set_Field
                 ("session_id", Create (LLM.Agent.Session_Id (Agent_Session)));
               Result.Set_Field ("output", Create (To_String (Final_Text)));
               State.Set_One_Shot_Result (Write (Result));
            elsif Length (Final_Error) > 0 then
               Result.Set_Field ("error", Create (To_String (Final_Error)));
               State.Set_One_Shot_Result (Write (Result));
            else
               State.Set_One_Shot_Result
                 ("{""error"":""No response from pi""}");
            end if;
         end Store_One_Shot_Result;

         procedure Run_Queued_Prompt
           (Prompt   : String;
            Is_Steer : Boolean) is
            pragma Unreferenced (Is_Steer);
         begin
            Reset_One_Shot_Tracking;
            LLM.Agent.Run_Prompt
              (S        => Agent_Session,
               Prompt   => Prompt,
               On_Event => Dispatch_Event'Access);
            if Opts.One_Shot then
               Store_One_Shot_Result;
               Initiate_Shutdown;
            end if;
         exception
            when Ex : others =>
               Append_Task_Warning
                 ("prompt failed: "
                  & Ada.Exceptions.Exception_Message (Ex));
               if Opts.One_Shot then
                  State.Set_One_Shot_Result
                    ("{""error"":""prompt failed: "
                     & Ada.Exceptions.Exception_Message (Ex)
                     & """}");
                  Initiate_Shutdown;
               end if;
         end Run_Queued_Prompt;

      begin
         declare
            Settings_Value : constant LLM.Settings.Settings :=
              LLM.Settings.Load_Settings;
         begin
            Current_Thinking := Settings_Value.Default_Thinking;
         end;

         if Length (Opts.Agent) > 0 then
            State.Set_Agent (To_String (Opts.Agent));
         end if;

         LLM.Agent.Create
           (S             => Agent_Session,
            Model_Spec    => To_String (Opts.Model),
            System_Prompt => To_String (Opts.Agent),
            No_Tools      => Opts.No_Tools,
            Session_Id    => To_String (Opts.Session_Id));

         if Length (Opts.Session_Id) > 0 then
            Render_Loaded_Session (To_String (Opts.Session_Id));
         end if;

         Emit_Bootstrap;

         if Opts.One_Shot then
            if Length (Opts.Initial_Prompt) = 0 then
               State.Set_One_Shot_Result
                 ("{""error"":""one-shot requires --prompt""}");
               Initiate_Shutdown;
            else
               declare
                  Prompt : constant String := To_String (Opts.Initial_Prompt);
               begin
                  Acme.Window.Append
                    (Win,
                     My_FS'Access,
                     ASCII.LF & UC_TRI_R & " " & Prompt & ASCII.LF);
                  Run_Queued_Prompt (Prompt, False);
               end;
            end if;
         else
            Command_Loop : loop
               declare
                  Kind     : Agent_Command_Kind;
                  Text     : Unbounded_String;
                  Is_Steer : Boolean;
               begin
                  Commands.Dequeue (Kind, Text, Is_Steer);
                  exit Command_Loop when Kind = Shutdown_Command;

                  case Kind is
                  when Prompt_Command =>
                     Run_Queued_Prompt (To_String (Text), Is_Steer);

                  when New_Session_Command =>
                     begin
                        LLM.Agent.New_Session (Agent_Session);
                        Reset_Session_State;
                        Emit_Bootstrap;
                     exception
                        when Ex : others =>
                           Append_Task_Warning
                             ("new session failed: "
                              & Ada.Exceptions.Exception_Message (Ex));
                     end;

                  when Switch_Session_Command =>
                     begin
                        LLM.Agent.Switch_Session
                          (S    => Agent_Session,
                           UUID => To_String (Text));
                        Reset_Session_State;
                        Render_Loaded_Session (To_String (Text));
                        Emit_Bootstrap;
                     exception
                        when Ex : others =>
                           Append_Task_Warning
                             ("session switch failed: "
                              & Ada.Exceptions.Exception_Message (Ex));
                     end;

                  when Set_Model_Command =>
                     begin
                        LLM.Agent.Set_Model
                          (S    => Agent_Session,
                           Spec => To_String (Text));
                        Emit_Model_Select;
                     exception
                        when Ex : others =>
                           Append_Task_Warning
                             ("model change failed: "
                              & Ada.Exceptions.Exception_Message (Ex));
                     end;

                  when Set_Thinking_Command =>
                     begin
                        Current_Thinking := Text;
                        LLM.Agent.Set_Thinking
                          (S     => Agent_Session,
                           Level => Thinking_Level_Of (To_String (Text)));
                        Acme.Window.Replace_Line1
                          (Win,
                           My_FS'Access,
                           Format_Status (State, Status_Label));
                     exception
                        when Ex : others =>
                           Append_Task_Warning
                             ("thinking change failed: "
                              & Ada.Exceptions.Exception_Message (Ex));
                     end;

                  when Shutdown_Command =>
                     exit Command_Loop;
                  end case;
               end;
            end loop Command_Loop;
         end if;
      exception
         when Ex : others =>
            Acme.Window.Append
              (Win,
               My_FS'Access,
               ASCII.LF & "[!] Agent task: "
               & Ada.Exceptions.Exception_Message (Ex) & ASCII.LF);
            if Opts.One_Shot then
               State.Set_One_Shot_Result
                 ("{""error"":""agent task failed: "
                  & Ada.Exceptions.Exception_Message (Ex)
                  & """}");
            end if;
            Initiate_Shutdown;
      end Agent_Task;

      --  ── Acme_Event_Task ───────────────────────────────────────────────
      --
      --  Opens the window event file directly via 9P and parses raw acme
      --  events using Acme.Raw_Events — no external acmeevent process.

      task body Acme_Event_Task is
         My_FS   : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
         Ev_File : aliased Nine_P.Client.File :=
           Open (My_FS'Access,
                 Acme.Window.Event_Path (Win),
                 O_READ);
         Parser       : Acme.Raw_Events.Event_Parser;
         Got_Shutdown : Boolean := False;

         --  Launch  llm-chat-open Token  and wait for it.
         --  On non-zero exit, appends a warning line to the window.
         procedure Run_Llm_Chat_Open (Token : String) is
            use GNATCOLL.OS.FS;
            use GNATCOLL.OS.Process;
            Null_In            : constant File_Descriptor :=
              Open (Null_File, Read_Mode);
            Stderr_R, Stderr_W : File_Descriptor;
            Args               : Argument_List;
            Handle             : Process_Handle;
            Exit_Code          : Integer;
         begin
            Open_Pipe (Stderr_R, Stderr_W);
            Args.Append ("llm-chat-open");
            Args.Append (Token);
            Handle := Start
              (Args   => Args,
               Stdin  => Null_In,
               Stdout => Stderr_W,
               Stderr => Stderr_W);
            Close (Null_In);
            Close (Stderr_W);
            Exit_Code := Wait (Handle);
            if Exit_Code /= 0 then
               declare
                  Buffer  : String (1 .. 256);
                  Bytes   : Integer;
                  Err_Msg : Unbounded_String;
               begin
                  loop
                     Bytes := Read (Stderr_R, Buffer);
                     exit when Bytes <= 0;
                     Append (Err_Msg, Buffer (1 .. Bytes));
                  end loop;
                  if Length (Err_Msg) > 0 then
                     Acme.Window.Append
                       (Win,
                        My_FS'Access,
                        ASCII.LF & UC_WARN & " llm-chat-open: "
                        & To_String (Err_Msg) & ASCII.LF);
                  end if;
               end;
            end if;
            Close (Stderr_R);
         exception
            when Ex : others =>
               Acme.Window.Append
                 (Win,
                  My_FS'Access,
                  ASCII.LF & UC_WARN & " llm-chat-open error: "
                  & Ada.Exceptions.Exception_Message (Ex) & ASCII.LF);
         end Run_Llm_Chat_Open;

         --  Scan a ±200-rune context window around the click position for
         --  a llm-chat+.../tool/... URI.  If found and the click lands
         --  within the token, launch llm-chat-open and return True.
         function Try_Open_Tool_URI
           (Ev : Acme.Event_Parser.Event) return Boolean
         is
            Anchor    : constant Natural :=
              (if Ev.Eq1 > Ev.Eq0
               then (Ev.Eq0 + Ev.Eq1) / 2
               else Ev.Q0);
            Ctx_Start : constant Natural :=
              (if Anchor > 200 then Anchor - 200 else 0);
            Ctx_End   : constant Natural := Anchor + 200;
         begin
            declare
               Context : constant String :=
                 Acme.Window.Read_Chars
                   (Win, My_FS'Access, Ctx_Start, Ctx_End);
               Token   : constant String :=
                 Scan_Tool_Token (Context, Ctx_Start, Anchor);
            begin
               if Token'Length = 0 then
                  return False;
               end if;
               Run_Llm_Chat_Open (Token);
               return True;
            end;
         exception
            when others =>
               return False;
         end Try_Open_Tool_URI;

         --  Spawn a new pi_acme window containing the session history of
         --  UUID truncated after After_Turn complete turns.
         procedure Fork_And_Open (UUID : String; After_Turn : Positive) is
            use GNATCOLL.OS.FS;
            use GNATCOLL.OS.Process;
            Cwd      : constant String := Ada.Directories.Current_Directory;
            New_UUID : constant String :=
              Session_Lister.Fork_Session (UUID, After_Turn, Cwd);
            Null_FD  : File_Descriptor;
            Args     : Argument_List;
            Handle   : Process_Handle;
            pragma Unreferenced (Handle);
         begin
            if New_UUID'Length = 0 then
               Acme.Window.Append
                 (Win,
                  My_FS'Access,
                  ASCII.LF & UC_WARN & " Fork failed (turn "
                  & Natural_Image (After_Turn)
                  & " not found in session)." & ASCII.LF);
               return;
            end if;
            Null_FD := Open (Null_File, Read_Mode);
            Args.Append (Ada.Command_Line.Command_Name);
            Args.Append ("--session");
            Args.Append (New_UUID);
            Handle := Start
              (Args   => Args,
               Stdin  => Null_FD,
               Stdout => Null_FD,
               Stderr => Null_FD,
               Cwd    => Cwd);
            Close (Null_FD);
            Acme.Window.Append
              (Win,
               My_FS'Access,
               ASCII.LF & "[Forked -> "
               & New_UUID (New_UUID'First .. New_UUID'First + 7)
               & "...]" & ASCII.LF);
         exception
            when Ex : others =>
               Acme.Window.Append
                 (Win,
                  My_FS'Access,
                  ASCII.LF & UC_WARN & " Fork_And_Open: "
                  & Ada.Exceptions.Exception_Message (Ex) & ASCII.LF);
         end Fork_And_Open;

         --  Scan a ±200-rune context window around the click for a
         --  fork+PID/UUID/N token.  If found and the PID matches this
         --  process, call Fork_And_Open and return True.
         function Try_Fork_URI
           (Ev : Acme.Event_Parser.Event) return Boolean
         is
            Anchor    : constant Natural :=
              (if Ev.Eq1 > Ev.Eq0
               then (Ev.Eq0 + Ev.Eq1) / 2
               else Ev.Q0);
            Ctx_Start : constant Natural :=
              (if Anchor > 200 then Anchor - 200 else 0);
            Ctx_End   : constant Natural := Anchor + 200;
         begin
            declare
               Context : constant String :=
                 Acme.Window.Read_Chars
                   (Win, My_FS'Access, Ctx_Start, Ctx_End);
               Token   : constant String :=
                 Scan_Fork_Token (Context, Ctx_Start, Anchor);
            begin
               if Token'Length = 0 then
                  return False;
               end if;
               declare
                  After_Plus  : constant Natural := Token'First + 5;
                  First_Slash : Natural          := 0;
                  Last_Slash  : Natural          := 0;
               begin
                  for I in After_Plus .. Token'Last loop
                     if Token (I) = '/' then
                        if First_Slash = 0 then
                           First_Slash := I;
                        end if;
                        Last_Slash := I;
                     end if;
                  end loop;
                  if First_Slash = 0 or else First_Slash = Last_Slash then
                     return False;
                  end if;
                  declare
                     Token_PID : constant String :=
                       Token (After_Plus .. First_Slash - 1);
                     Sess_UUID : constant String :=
                       Token (First_Slash + 1 .. Last_Slash - 1);
                     Turn_Str  : constant String :=
                       Token (Last_Slash + 1 .. Token'Last);
                     Turn_N    : Positive;
                  begin
                     if Token_PID /= My_PID then
                        return False;
                     end if;
                     Turn_N := Positive'Value (Turn_Str);
                     Fork_And_Open (Sess_UUID, Turn_N);
                     return True;
                  exception
                     when Constraint_Error =>
                        return False;
                  end;
               end;
            end;
         exception
            when others =>
               return False;
         end Try_Fork_URI;

         procedure Open_Models_Window is
            Parent  : constant String :=
              Ada.Directories.Current_Directory & "/+pi";
            Models  : constant LLM.Model_Registry.Model_Info_Vectors.Vector :=
              LLM.Model_Registry.Available_Models;
            Content : Unbounded_String;
         begin
            for Model of Models loop
               Append
                 (Content,
                  "model+" & My_PID & "/"
                  & To_String (Model.Provider) & "/"
                  & To_String (Model.Model_Id) & ASCII.LF);
            end loop;
            Open_Sub_Window
              (My_FS'Access,
               Parent,
               "+models",
               (if Length (Content) > 0
                then To_String (Content)
                else "(no models available)" & ASCII.LF));
         end Open_Models_Window;

      begin
         Event_Loop : loop
            select
               State.Wait_Shutdown;
               Got_Shutdown := True;
            then abort
               declare
                  Data : constant Byte_Array :=
                    Read_Once (Ev_File'Access);
               begin
                  exit Event_Loop when Data'Length = 0;
                  Acme.Raw_Events.Feed (Parser, Data);
                  Raw_Event_Loop : loop
                     declare
                        Ev : Acme.Event_Parser.Event;
                     begin
                        exit Raw_Event_Loop when not
                          Acme.Raw_Events.Next_Event (Parser, Ev);
                        declare
                           C2   : constant Character := Ev.C2;
                           Text : constant String :=
                             Ada.Strings.Fixed.Trim
                               (To_String (Ev.Text), Ada.Strings.Both);
                        begin
                           if C2 in 'X' | 'x' then
                              if Text = "Send" then
                                 declare
                                    Sel : constant String :=
                                      Acme.Window.Selection_Text
                                        (Win, My_FS'Access);
                                 begin
                                    if Sel'Length > 0 then
                                       if State.Is_Streaming
                                         or else State.Is_Retrying
                                       then
                                          Acme.Window.Append
                                            (Win,
                                             My_FS'Access,
                                             ASCII.LF & UC_WARN
                                             & " Agent is running"
                                             & (if State.Is_Retrying
                                                then " (retrying)"
                                                else "")
                                             & " -- use Steer to redirect"
                                             & " or Stop first."
                                             & ASCII.LF);
                                       else
                                          Acme.Window.Append
                                            (Win,
                                             My_FS'Access,
                                             ASCII.LF & UC_TRI_R
                                             & " " & Sel & ASCII.LF);
                                          Commands.Enqueue
                                            (Prompt_Command, Sel);
                                       end if;
                                    end if;
                                 end;
                              elsif Text = "Stop" then
                                 if State.Is_Streaming
                                   or else State.Is_Retrying
                                 then
                                    State.Set_Aborted (True);
                                 end if;
                                 LLM.Agent.Request_Abort (Agent_Session);
                              elsif Text = "Steer" then
                                 declare
                                    Sel : constant String :=
                                      Acme.Window.Selection_Text
                                        (Win, My_FS'Access);
                                 begin
                                    if Sel'Length > 0 then
                                       Acme.Window.Append
                                         (Win,
                                          My_FS'Access,
                                          ASCII.LF & UC_HOOK_L
                                          & " Steer: " & Sel & ASCII.LF);
                                       if State.Is_Streaming
                                         or else State.Is_Retrying
                                       then
                                          State.Set_Aborted (True);
                                          LLM.Agent.Request_Abort
                                            (Agent_Session);
                                       end if;
                                       Commands.Enqueue
                                         (Prompt_Command, Sel, True);
                                    end if;
                                 end;
                              elsif Text = "New" then
                                 Acme.Window.Append
                                   (Win,
                                    My_FS'Access,
                                    ASCII.LF
                                    & UC_HORIZ & UC_HORIZ & " New session "
                                    & UC_HORIZ & UC_HORIZ & ASCII.LF);
                                 if State.Is_Streaming
                                   or else State.Is_Retrying
                                 then
                                    State.Set_Aborted (True);
                                    LLM.Agent.Request_Abort (Agent_Session);
                                 end if;
                                 Commands.Enqueue (New_Session_Command);
                              elsif Text = "Compact" then
                                 if not State.Is_Streaming
                                   and then not State.Is_Compacting
                                 then
                                    State.Set_Compacting (True);
                                    Acme.Window.Append
                                      (Win,
                                       My_FS'Access,
                                       ASCII.LF & UC_GEAR
                                       & " Compacting context"
                                       & UC_ELLIP & ASCII.LF);
                                    Acme.Window.Replace_Line1
                                      (Win,
                                       My_FS'Access,
                                       Format_Status (State, "compacting"));
                                    Acme.Window.Append
                                      (Win,
                                       My_FS'Access,
                                       ASCII.LF
                                       & "[Compact not yet implemented]"
                                       & ASCII.LF);
                                    State.Set_Compacting (False);
                                    Acme.Window.Replace_Line1
                                      (Win,
                                       My_FS'Access,
                                       Format_Status (State, Status_Label));
                                 end if;
                              elsif Text = "Clear" then
                                 Acme.Window.Replace_Match
                                   (Win, My_FS'Access, "1,$", "");
                                 Acme.Window.Append
                                   (Win,
                                    My_FS'Access,
                                    Format_Status (State, "ready")
                                    & ASCII.LF);
                              elsif Text = "Models" then
                                 Open_Models_Window;
                              elsif Text = "Sessions" then
                                 declare
                                    Parent  : constant String :=
                                      Ada.Directories.Current_Directory
                                      & "/+pi";
                                    Content : constant String :=
                                      List_Sessions_Text;
                                 begin
                                    Open_Sub_Window
                                      (My_FS'Access,
                                       Parent,
                                       "+sessions",
                                       (if Content'Length > 0
                                        then Content
                                        else "(no sessions found)"
                                             & ASCII.LF));
                                 end;
                              elsif Text = "Thinking" then
                                 declare
                                    Parent  : constant String :=
                                      Ada.Directories.Current_Directory
                                      & "/+pi";
                                    Content : constant String :=
                                      "thinking+" & My_PID & "/low" & ASCII.LF
                                      & "thinking+" & My_PID & "/medium"
                                      & ASCII.LF
                                      & "thinking+" & My_PID & "/high"
                                      & ASCII.LF;
                                 begin
                                    Open_Sub_Window
                                      (My_FS'Access,
                                       Parent,
                                       "+thinking",
                                       Content);
                                 end;
                              elsif Text = "Stats" then
                                 declare
                                    Parent    : constant String :=
                                      Ada.Directories.Current_Directory
                                      & "/+pi";
                                    Turn_In   : constant Natural :=
                                      State.Turn_Input_Tokens;
                                    Turn_Out  : constant Natural :=
                                      State.Turn_Output_Tokens;
                                    Ctx_Win   : constant Natural :=
                                      State.Context_Window;
                                    Sess_In   : constant Natural :=
                                      State.Session_Input_Tokens;
                                    Sess_Out  : constant Natural :=
                                      State.Session_Output_Tokens;
                                    Sess_CR   : constant Natural :=
                                      State.Session_Cache_Read;
                                    Sess_CW   : constant Natural :=
                                      State.Session_Cache_Write;
                                    Sess_Tot  : constant Natural :=
                                      State.Session_Total_Tokens;
                                    Sess_Cost : constant Natural :=
                                      State.Session_Cost_Dmil;
                                    Buf       : Unbounded_String;
                                 begin
                                    Append
                                      (Buf,
                                       "# Session statistics"
                                       & ASCII.LF & ASCII.LF);
                                    Append
                                      (Buf,
                                       "Session:  "
                                       & State.Session_Id & ASCII.LF);
                                    if State.Current_Model'Length > 0 then
                                       Append
                                         (Buf,
                                          "Model:    "
                                          & State.Current_Model);
                                       if Ctx_Win > 0 then
                                          Append
                                            (Buf,
                                             " ("
                                             & Format_Kilo (Ctx_Win)
                                             & " ctx)");
                                       end if;
                                       Append (Buf, "" & ASCII.LF);
                                    end if;
                                    if State.Current_Thinking'Length > 0 then
                                       Append
                                         (Buf,
                                          "Thinking: "
                                          & State.Current_Thinking
                                          & ASCII.LF);
                                    end if;
                                    Append (Buf, "" & ASCII.LF);
                                    if Sess_Tot > 0 then
                                       Append
                                         (Buf,
                                          "Tokens this session:" & ASCII.LF);
                                       Append
                                         (Buf,
                                          "  Input:        "
                                          & Natural_Image (Sess_In)
                                          & ASCII.LF);
                                       Append
                                         (Buf,
                                          "  Output:       "
                                          & Natural_Image (Sess_Out)
                                          & ASCII.LF);
                                       if Sess_CR > 0 then
                                          Append
                                            (Buf,
                                             "  Cache read:   "
                                             & Natural_Image (Sess_CR)
                                             & ASCII.LF);
                                       end if;
                                       if Sess_CW > 0 then
                                          Append
                                            (Buf,
                                             "  Cache write:  "
                                             & Natural_Image (Sess_CW)
                                             & ASCII.LF);
                                       end if;
                                       Append
                                         (Buf,
                                          "  Total:        "
                                          & Natural_Image (Sess_Tot)
                                          & ASCII.LF);
                                       if Sess_Cost > 0 then
                                          Append
                                            (Buf,
                                             ASCII.LF & "Cost:     "
                                             & Format_Cost (Sess_Cost)
                                             & ASCII.LF);
                                       end if;
                                    else
                                       Append
                                         (Buf,
                                          "(No statistics yet"
                                          & " -- complete a turn first.)"
                                          & ASCII.LF);
                                    end if;
                                    if Turn_In > 0 or else Turn_Out > 0 then
                                       Append
                                         (Buf,
                                          ASCII.LF & "Last turn:" & ASCII.LF);
                                       if Turn_Out > 0 then
                                          Append
                                            (Buf,
                                             "  Output:  "
                                             & Natural_Image (Turn_Out)
                                             & ASCII.LF);
                                       end if;
                                       if Turn_In > 0 and then Ctx_Win > 0 then
                                          Append
                                            (Buf,
                                             "  Context: "
                                             & Natural_Image (Turn_In)
                                             & "/"
                                             & Natural_Image (Ctx_Win)
                                             & " ("
                                             & Natural_Image
                                                 (Turn_In * 100 / Ctx_Win)
                                             & "%)" & ASCII.LF);
                                       end if;
                                    end if;
                                    Open_Sub_Window
                                      (My_FS'Access,
                                       Parent,
                                       "+stats",
                                       To_String (Buf));
                                 end;
                              else
                                 Acme.Window.Send_Event
                                   (Win,
                                    My_FS'Access,
                                    Ev.C1,
                                    Ev.C2,
                                    Ev.Q0,
                                    Ev.Q1);
                              end if;
                           elsif C2 in 'L' | 'l' then
                              if not Try_Fork_URI (Ev)
                                and then not Try_Open_Tool_URI (Ev)
                              then
                                 Acme.Window.Send_Event
                                   (Win,
                                    My_FS'Access,
                                    Ev.C1,
                                    Ev.C2,
                                    Ev.Q0,
                                    Ev.Q1);
                              end if;
                           end if;
                        end;
                     end;
                  end loop Raw_Event_Loop;
               end;
            end select;
            exit Event_Loop when Got_Shutdown;
         end loop Event_Loop;
         Initiate_Shutdown;
      exception
         when Ex : Nine_P.Proto.P9_Error =>
            if Ada.Exceptions.Exception_Message (Ex) /= "deleted window" then
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "Acme_Event_Task terminated: "
                  & Ada.Exceptions.Exception_Information (Ex));
            end if;
            Initiate_Shutdown;
         when Ex : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Acme_Event_Task terminated: "
               & Ada.Exceptions.Exception_Information (Ex));
            Initiate_Shutdown;
      end Acme_Event_Task;

      --  ── Plumb_Model_Task ──────────────────────────────────────────────

      task body Plumb_Model_Task is
         Pl_FS        : aliased Nine_P.Client.Fs   := Ns_Mount ("plumb");
         My_FS        : aliased Nine_P.Client.Fs   := Ns_Mount ("acme");
         Port         : aliased Nine_P.Client.File :=
           Open (Pl_FS'Access, "/pi-model", O_READ);
         Got_Shutdown : Boolean := False;
      begin
         Plumb_Loop : loop
            select
               State.Wait_Shutdown;
               Got_Shutdown := True;
            then abort
               declare
                  Raw  : constant Byte_Array :=
                    Nine_P.Client.Read_Once (Port'Access);
                  Data : constant String := Extract_Plumb_Data (Raw);
               begin
                  exit Plumb_Loop when Raw'Length = 0;
                  if Data'Length > 0 then
                     declare
                        First_Slash : Natural := 0;
                     begin
                        for I in Data'Range loop
                           if Data (I) = '/' then
                              First_Slash := I;
                              exit;
                           end if;
                        end loop;
                        if First_Slash > 0
                          and then Data (Data'First .. First_Slash - 1)
                                   = "model+" & My_PID
                        then
                           declare
                              Rest : constant String :=
                                Data (First_Slash + 1 .. Data'Last);
                           begin
                              Commands.Enqueue (Set_Model_Command, Rest);
                              Acme.Window.Append
                                (Win,
                                 My_FS'Access,
                                 ASCII.LF & "[Model -> " & Rest
                                 & "]" & ASCII.LF);
                           end;
                        end if;
                     end;
                  end if;
               end;
            end select;
            exit Plumb_Loop when Got_Shutdown;
         end loop Plumb_Loop;
      exception
         when Ex : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Plumb_Model_Task terminated: "
               & Ada.Exceptions.Exception_Information (Ex));
      end Plumb_Model_Task;

      --  ── Plumb_Session_Task ────────────────────────────────────────────
      --
      --  Reads the pi-session plumb port.  Tokens written by our own
      --  +sessions window are PID-tagged ("llm-chat+PID/UUID"); bare
      --  "llm-chat+UUID" tokens (no PID, backward-compat) are also
      --  accepted.  Tokens belonging to other pi-acme instances are
      --  silently ignored.

      task body Plumb_Session_Task is
         Pl_FS        : aliased Nine_P.Client.Fs   := Ns_Mount ("plumb");
         Pid_Prefix   : constant String :=
           "llm-chat+" & My_PID & "/";
         Port         : aliased Nine_P.Client.File :=
           Open (Pl_FS'Access, "/pi-session", O_READ);
         Got_Shutdown : Boolean := False;
      begin
         Plumb_Loop : loop
            select
               State.Wait_Shutdown;
               Got_Shutdown := True;
            then abort
               declare
                  Raw  : constant Byte_Array :=
                    Nine_P.Client.Read_Once (Port'Access);
                  Data : constant String := Extract_Plumb_Data (Raw);
               begin
                  exit Plumb_Loop when Raw'Length = 0;
                  if Data'Length > 0 then
                     declare
                        UUID : constant String :=
                          Parse_Session_Token (Data, Pid_Prefix);
                     begin
                        if UUID'Length > 0 then
                           if State.Is_Streaming or else State.Is_Retrying then
                              State.Set_Aborted (True);
                              LLM.Agent.Request_Abort (Agent_Session);
                           end if;
                           Commands.Enqueue (Switch_Session_Command, UUID);
                        end if;
                     end;
                  end if;
               end;
            end select;
            exit Plumb_Loop when Got_Shutdown;
         end loop Plumb_Loop;
      exception
         when Ex : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Plumb_Session_Task terminated: "
               & Ada.Exceptions.Exception_Information (Ex));
      end Plumb_Session_Task;

      --  ── Plumb_Thinking_Task ───────────────────────────────────────────

      task body Plumb_Thinking_Task is
         Pl_FS        : aliased Nine_P.Client.Fs   := Ns_Mount ("plumb");
         My_FS        : aliased Nine_P.Client.Fs   := Ns_Mount ("acme");
         Port         : aliased Nine_P.Client.File :=
           Open (Pl_FS'Access, "/pi-thinking", O_READ);
         Got_Shutdown : Boolean := False;
      begin
         Plumb_Loop : loop
            select
               State.Wait_Shutdown;
               Got_Shutdown := True;
            then abort
               declare
                  Raw   : constant Byte_Array :=
                    Nine_P.Client.Read_Once (Port'Access);
                  Level : constant String := Extract_Plumb_Data (Raw);
               begin
                  exit Plumb_Loop when Raw'Length = 0;
                  if Level'Length > 0 then
                     declare
                        Slash : Natural := 0;
                     begin
                        for I in reverse Level'Range loop
                           if Level (I) = '/' then
                              Slash := I;
                              exit;
                           end if;
                        end loop;
                        declare
                           Plus_Pos  : Natural := 0;
                           Token_PID : Unbounded_String;
                        begin
                           for I in Level'Range loop
                              if Level (I) = '+' then
                                 Plus_Pos := I;
                                 exit;
                              end if;
                           end loop;
                           if Plus_Pos > 0 and then Slash > Plus_Pos then
                              Token_PID :=
                                To_Unbounded_String
                                  (Level (Plus_Pos + 1 .. Slash - 1));
                           end if;
                           if To_String (Token_PID) = My_PID then
                              declare
                                 Parsed : constant String :=
                                   (if Slash > 0
                                    then Level (Slash + 1 .. Level'Last)
                                    else Level);
                              begin
                                 State.Set_Thinking (Parsed);
                                 Commands.Enqueue
                                   (Set_Thinking_Command, Parsed);
                                 Acme.Window.Append
                                   (Win,
                                    My_FS'Access,
                                    ASCII.LF & "[Thinking -> "
                                    & Parsed & "]" & ASCII.LF);
                                 Acme.Window.Replace_Line1
                                   (Win,
                                    My_FS'Access,
                                    Format_Status (State, Status_Label));
                              end;
                           end if;
                        end;
                     end;
                  end if;
               end;
            end select;
            exit Plumb_Loop when Got_Shutdown;
         end loop Plumb_Loop;
      exception
         when Ex : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Plumb_Thinking_Task terminated: "
               & Ada.Exceptions.Exception_Information (Ex));
      end Plumb_Thinking_Task;

   begin
      --  ── Initial window setup ──────────────────────────────────────────
      Acme.Window.Ctl (Win, Win_FS'Access, "cleartag");
      Acme.Window.Append_Tag (Win, Win_FS'Access, Tag_Extra);
      Acme.Window.Set_Name
        (Win,
         Win_FS'Access,
         Ada.Directories.Current_Directory & "/+pi"
         & (if Length (Opts.Name) > 0
            then ":" & To_String (Opts.Name)
            else ""));
      Acme.Window.Append
        (Win, Win_FS'Access, UC_BULLET & " starting..." & ASCII.LF);
      Acme.Window.Ctl (Win, Win_FS'Access, "clean");

      --  ── Wait for window-closed shutdown ───────────────────────────────
      State.Wait_Shutdown;

      --  ── One-shot teardown ─────────────────────────────────────────────
      --  Print the JSON result line for the spawning extension to read.
      --  If no result was stored (e.g. the user closed the window
      --  manually), emit a generic error object.
      if Opts.One_Shot then
         declare
            Json : constant String := State.One_Shot_Result;
         begin
            Ada.Text_IO.Put_Line
              ((if Json'Length > 0
                then Json
                else
                  "{""error"":""subagent closed before producing"
                  & " output""}"));
         end;
      end if;

      begin
         Acme.Window.Ctl (Win, Win_FS'Access, "delete");
      exception
         when others =>
            null;
      end;
   end Run;

end Pi_Acme_App;
