--  Coyote_App body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with GNATCOLL.JSON;          use GNATCOLL.JSON;
with GNATCOLL.OS.Process;
with LLM.Compaction;
with LLM.Agent;
with LLM.Events;
with LLM.Model_Registry;
with LLM.Providers;
with LLM.Session_Store;
with LLM.Settings;
with LLM.Types;
with Nine_P;                 use Nine_P;
with Nine_P.Client;          use Nine_P.Client;
with Nine_P.Proto;
with Acme.Event_Parser;
with Acme.Raw_Events;
with Acme.Window;
with Coyote_App.Frontend.Acme_Win;
with Coyote_App.Frontend.GUI;
with Coyote_GUI.Prompt_Queue;
with Coyote_GUI;
with Coyote_Notify;
with Coyote_Spawn;
with Gtk.Main;
with Coyote_App.History;    use Coyote_App.History;
with Coyote_App.Dispatch;   use Coyote_App.Dispatch;
with Coyote_App.Utils;      use Coyote_App.Utils;
with Session_Lister;         use Session_Lister;

package body Coyote_App is

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
      function Current_Thinking   return String  is
        (To_String (P_Thinking));
      function Current_Sandbox    return String  is
        (To_String (P_Sandbox));
      function Source_Directory   return String is
        (To_String (P_Source_Directory));
      function Session_Start      return String is
        (To_String (P_Session_Start));
      function Current_Tool_Call  return Natural is
        (P_Tool_Call);
      function Is_Streaming       return Boolean is (P_Streaming);
      function Is_Compacting      return Boolean is (P_Compacting);
      function Was_Aborted        return Boolean is (P_Aborted);
      function Is_Paused          return Boolean is (P_Paused);
      function Is_Pause_Armed     return Boolean is (P_Pause_Armed);
      function Is_Retrying        return Boolean is (P_Is_Retrying);
      function Text_Emitted       return Boolean is (P_Text_Emitted);
      function Has_Tool_In_Turn return Boolean is (P_Has_Tool_In_Turn);
      function Tools_Running return Natural is (P_Tools_Running);
      function Tools_Done    return Natural is (P_Tools_Done);
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
      function Prompt_Filter      return String  is
        (To_String (P_Prompt_Filter));

      procedure Set_Session_Id (Id : String) is
      begin
         P_Session_Id := To_Unbounded_String (Id);
      end Set_Session_Id;

      procedure Set_Model (Model : String) is
      begin
         P_Model := To_Unbounded_String (Model);
      end Set_Model;

      procedure Set_Thinking (Level : String) is
      begin
         P_Thinking := To_Unbounded_String (Level);
      end Set_Thinking;

      procedure Set_Sandbox (Profile : String) is
      begin
         P_Sandbox := To_Unbounded_String (Profile);
      end Set_Sandbox;

      procedure Set_Source_Directory (Directory : String) is
      begin
         P_Source_Directory := To_Unbounded_String (Directory);
      end Set_Source_Directory;

      procedure Set_Session_Start (Start : String) is
      begin
         P_Session_Start := To_Unbounded_String (Start);
      end Set_Session_Start;

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

      procedure Set_Paused (Value : Boolean) is
      begin
         P_Paused := Value;
      end Set_Paused;

      procedure Set_Pause_Armed (Value : Boolean) is
      begin
         P_Pause_Armed := Value;
      end Set_Pause_Armed;

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

      procedure Increment_Tools_Running is
      begin
         P_Tools_Running := P_Tools_Running + 1;
      end Increment_Tools_Running;

      procedure Increment_Tools_Done is
      begin
         P_Tools_Done    := P_Tools_Done + 1;
         if P_Tools_Running > 0 then
            P_Tools_Running := P_Tools_Running - 1;
         end if;
      end Increment_Tools_Done;

      procedure Increment_Tool_Call is
      begin
         P_Tool_Call := P_Tool_Call + 1;
      end Increment_Tool_Call;

      procedure Reset_Tool_Counts is
      begin
         P_Tools_Running := 0;
         P_Tools_Done    := 0;
         P_Tool_Call     := 0;
      end Reset_Tool_Counts;

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

      procedure Set_Prompt_Filter (Cmd : String) is
      begin
         P_Prompt_Filter := To_Unbounded_String (Cmd);
      end Set_Prompt_Filter;

      function Tag_Suffix return String is
        (To_String (P_Tag_Suffix));

      procedure Set_Tag_Suffix (Suffix : String) is
      begin
         P_Tag_Suffix := To_Unbounded_String (Suffix);
      end Set_Tag_Suffix;

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

      function Turn_Step          return Natural is (P_Turn_Step);
      procedure Increment_Turn_Step is
      begin
         P_Turn_Step := P_Turn_Step + 1;
      end Increment_Turn_Step;
      procedure Reset_Turn_Step is
      begin
         P_Turn_Step := 0;
      end Reset_Turn_Step;
      procedure Set_Turn_Step (N : Natural) is
      begin
         P_Turn_Step := N;
      end Set_Turn_Step;

      function Tool_Cancelled     return Boolean is (P_Tool_Cancelled);
      procedure Set_Tool_Cancelled (Value : Boolean) is
      begin
         P_Tool_Cancelled := Value;
      end Set_Tool_Cancelled;

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

   end App_State;

   --  ── Agent command queue ───────────────────────────────────────────────

   type Agent_Command_Kind is
     (Prompt_Command,
      Compact_Command,
      Switch_Session_Command,
      Set_Model_Command,
      Set_Thinking_Command,
      Set_Sandbox_Command,
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
         else " | Send Steer New Compact Clear"
              & " Models Sessions Thinking Stats SetDefault");

      --  Process ID used to build window-specific selector tokens.
      My_PID : constant String := Natural_Image (Natural (Getpid));

      --  ── List_Sessions_Text ──────────────────────────────────────────
      --
      --  Returns one session token per line:
      --    coyote-session+UUID<TAB>name<TAB>date<TAB>snippet
      function List_Sessions_Text return String is
         Sessions : constant Session_Vectors.Vector :=
           List_Sessions (Ada.Directories.Current_Directory);
      begin
         return Coyote_App.Utils.Format_Session_List (Sessions);
      end List_Sessions_Text;

      --  Shared objects — all tasks close over these:
      Win_FS : aliased Nine_P.Client.Fs := Ns_Mount ("acme");
      Win    : aliased Acme.Window.Win := Acme.Window.New_Win (Win_FS'Access);
      State         : App_State;
      Agent_Session : LLM.Agent.Session;
      Commands      : Agent_Command_Queue;

      function Status_Label return String is
      begin
         if State.Is_Compacting then
            return "compacting";
         elsif State.Is_Retrying then
            return "retrying";
         elsif State.Is_Paused then
            return "paused";
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
      task Plumb_Thinking_Task;
      task Plumb_Fork_Task;
      task Plumb_Sandbox_Task;

      --  ── Agent_Task ────────────────────────────────────────────────────

      task body Agent_Task is
         Section          : Section_Kind      := No_Section;
         Current_Thinking : Unbounded_String := Null_Unbounded_String;
         Current_Sandbox  : Unbounded_String := Null_Unbounded_String;
         Current_Text     : Unbounded_String := Null_Unbounded_String;
         Final_Text       : Unbounded_String := Null_Unbounded_String;
         Final_Error      : Unbounded_String := Null_Unbounded_String;
         Was_Aborted      : Boolean          := False;
      begin
         declare
            My_FS       : aliased Nine_P.Client.Fs;
            My_Frontend : Coyote_App.Frontend.Acme_Win.Instance;
            Max_Retries : constant Positive := 5;
            Retry_Delay : constant Duration := 0.5;
            Connected   : Boolean := False;

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
               Coyote_App.Dispatch.Dispatch_Event
                 (Event    => E,
                  Frontend => My_Frontend,
                  State    => State,
                  Section  => Section,
                  PID      => My_PID);
            end Dispatch_Event;

            procedure Dispatch_Agent_Event
              (E : LLM.Events.Agent_Event'Class) renames Dispatch_Event;

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
                     Context_Window =>
                       LLM.Agent.Context_Window (Agent_Session));
               begin
                  Dispatch_Event (Event);
               end;
            end Emit_Model_Select;

            procedure Emit_Session_Info is
               Session_Id : constant String :=
                 LLM.Agent.Session_Id (Agent_Session);
               Event : constant LLM.Events.Session_Info_Event :=
                 (LLM.Events.Agent_Event with
                  Session_Id       => To_Unbounded_String (Session_Id),
                  Thinking_Level   => Current_Thinking,
                  Sandbox_Profile  =>
                    To_Unbounded_String
                      (LLM.Agent.Current_Sandbox (Agent_Session)),
                  Model            => To_Unbounded_String
                    (LLM.Agent.Current_Model_Spec (Agent_Session)),
                  Source_Directory => To_Unbounded_String
                    (LLM.Session_Store.Session_Work_Dir (Session_Id)),
                  Session_Start    => To_Unbounded_String
                    (LLM.Session_Store.Session_Created_At (Session_Id)));
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
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error, "[!] " & Message);
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
               My_Frontend.Append_Notice
                 (Coyote_App.Frontend.Info,
                  ASCII.LF
                  & "[Loading session " & Short_Id & UC_ELLIP & "]"
                  & ASCII.LF);
               Render_Session_History
                 (UUID     => UUID,
                  Frontend => My_Frontend,
                  PID      => My_PID,
                  State    => State);
            end Render_Loaded_Session;

            procedure Synchronize_Sandbox is
               Profile : constant String :=
                 LLM.Agent.Current_Sandbox (Agent_Session);
            begin
               Current_Sandbox := To_Unbounded_String (Profile);
               State.Set_Sandbox (Profile);
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE", Profile);
            end Synchronize_Sandbox;

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
                  Result.Set_Field ("error", Create ("aborted"));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
               elsif Length (Final_Text) > 0 then
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  Result.Set_Field ("output", Create (To_String (Final_Text)));
                  State.Set_One_Shot_Result (Write (Result));
               elsif Length (Final_Error) > 0 then
                  Result.Set_Field ("error", Create (To_String (Final_Error)));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
               else
                  Result.Set_Field
                    ("error", Create ("No response from agent"));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
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
                     declare
                        Err : constant JSON_Value := Create_Object;
                     begin
                        Err.Set_Field
                          ("error",
                           "prompt failed: "
                           & Ada.Exceptions.Exception_Message (Ex));
                        Err.Set_Field
                          ("session_id",
                           Create (LLM.Agent.Session_Id (Agent_Session)));
                        State.Set_One_Shot_Result (Write (Err));
                     end;
                     Initiate_Shutdown;
                  end if;
            end Run_Queued_Prompt;
         begin
            Connection_Retry : for Attempt in 1 .. Max_Retries loop
               begin
                  Connect (My_FS, "acme");
                  Connected := True;
                  exit Connection_Retry;
               exception
                  when Nine_P.Proto.P9_Error =>
                     exit Connection_Retry when Attempt = Max_Retries;
                     delay Retry_Delay;
               end;
            end loop Connection_Retry;

            if not Connected then
               raise Nine_P.Proto.P9_Error with
                 "Agent_Task could not connect to acme";
            end if;
            Coyote_App.Frontend.Acme_Win.Create (My_Frontend, Win'Unchecked_Access);
            My_Frontend.Set_Tag_Suffix
              (if Opts.One_Shot then "" else " Models Sessions Thinking Stats SetDefault");

            declare
               Settings_Value : constant LLM.Settings.Settings :=
                 LLM.Settings.Load_Settings;
            begin
               Current_Thinking := Settings_Value.Default_Thinking;
               --  CLI --prompt-filter wins; fall back to settings.json.
               if Length (Opts.Prompt_Filter) > 0 then
                  State.Set_Prompt_Filter (To_String (Opts.Prompt_Filter));
               else
                  State.Set_Prompt_Filter
                    (To_String (Settings_Value.Prompt_Filter));
               end if;
               --  Inherit thinking level from parent subagent process.
               declare
                  Think_Level : constant String :=
                    Ada.Environment_Variables.Value
                      ("COYOTE_THINKING_LEVEL", "");
               begin
                  if Think_Level'Length > 0 then
                     Current_Thinking :=
                       Ada.Strings.Unbounded.To_Unbounded_String (Think_Level);
                  end if;
               end;
            end;

            --  When spawned as a subagent via the shell tool, the parent
            --  coyote's COYOTE_SESSION_ID is inherited by all child
            --  processes.  Promote it to COYOTE_PARENT_SESSION so that
            --  LLM.Session_Store records the parentSession link in the
            --  new session's JSONL header.  Do this only when
            --  COYOTE_PARENT_SESSION is not already set explicitly.
            declare
               Inherited_Sid : constant String :=
                 Ada.Environment_Variables.Value ("COYOTE_SESSION_ID", "");
               Parent_Sid    : constant String :=
                 Ada.Environment_Variables.Value
                   ("COYOTE_PARENT_SESSION", "");
            begin
               if Parent_Sid'Length = 0
                 and then Inherited_Sid'Length > 0
               then
                  Ada.Environment_Variables.Set
                    ("COYOTE_PARENT_SESSION", Inherited_Sid);
               end if;
            end;
            LLM.Agent.Create
              (S          => Agent_Session,
               Model_Spec => To_String (Opts.Model),
               Agent      => To_String (Opts.Agent),
               No_Tools   => Opts.No_Tools,
               Session_Id => To_String (Opts.Session_Id),
               Subagent   => Opts.Subagent);
            Synchronize_Sandbox;
            if Opts.No_Compact then
               LLM.Agent.Set_Compact_Settings
                 (Agent_Session,
                  (Enabled              => False,
                   Reserve_Tokens       =>
                     LLM.Compaction.Default_Compact_Settings.Reserve_Tokens,
                   Keep_Recent_Tokens   =>
                     LLM.Compaction.Default_Compact_Settings
                       .Keep_Recent_Tokens,
                   Consecutive_Failures => 0,
                   Tripped              => False));
            end if;
            --  Publish the session ID so subagent child processes can record
            --  it as their parentSession.  COYOTE_SESSION_ID is inherited by
            --  every subprocess spawned from this coyote instance.
            declare
               Sess : constant String :=
                 LLM.Agent.Session_Id (Agent_Session);
            begin
               if Sess'Length > 0 then
                  Ada.Environment_Variables.Set
                    ("COYOTE_SESSION_ID", Sess);
               end if;
            end;
            --  Publish the thinking level for child subagent processes.
            if Ada.Strings.Unbounded.Length (Current_Thinking) > 0 then
               Ada.Environment_Variables.Set
                 ("COYOTE_THINKING_LEVEL",
                  Ada.Strings.Unbounded.To_String (Current_Thinking));
            else
               Ada.Environment_Variables.Set
                 ("COYOTE_THINKING_LEVEL", "");
            end if;

            --  Publish the sandbox profile for child subagent processes.
            if Ada.Strings.Unbounded.Length (Current_Sandbox) > 0 then
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE",
                  Ada.Strings.Unbounded.To_String (Current_Sandbox));
            else
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE", "");
            end if;


            if Length (Opts.Session_Id) > 0 then
               Render_Loaded_Session (To_String (Opts.Session_Id));
            end if;

            if Length (Opts.Work_Dir_Warning) > 0 then
               Append_Task_Warning (To_String (Opts.Work_Dir_Warning));
            end if;

            Emit_Bootstrap;

            if Opts.One_Shot then
               if Length (Opts.Initial_Prompt) = 0 then
                  declare
                     Err : constant JSON_Value := Create_Object;
                  begin
                     Err.Set_Field
                       ("error",
                        "one-shot requires --prompt"
                        & " (use --prompt - to read from stdin)");
                     State.Set_One_Shot_Result (Write (Err));
                  end;
                  Initiate_Shutdown;
               else
                  declare
                     Prompt : constant String :=
                       To_String (Opts.Initial_Prompt);
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
                        when Compact_Command =>
                           if not State.Is_Streaming
                             and then not State.Is_Compacting
                           then
                              declare
                                 Compact_OK : Boolean;
                              begin
                                 LLM.Agent.Compact
                                   (Agent_Session,
                                    Dispatch_Agent_Event'Unrestricted_Access,
                                    "manual",
                                    Compact_OK);
                              end;
                           end if;

                        when Switch_Session_Command =>
                           begin
                              LLM.Agent.Switch_Session
                                (S    => Agent_Session,
                                 UUID => To_String (Text));
                              Synchronize_Sandbox;
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
                              Ada.Environment_Variables.Set
                                ("COYOTE_THINKING_LEVEL",
                                 To_String (Current_Thinking));
                              LLM.Agent.Set_Thinking
                                (S     => Agent_Session,
                                 Level =>
                                   Thinking_Level_Of (To_String (Text)));
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

                        when Set_Sandbox_Command =>
                           begin
                              Current_Sandbox := Text;
                              if Ada.Strings.Unbounded.Length
                                   (Current_Sandbox) > 0
                              then
                                 Ada.Environment_Variables.Set
                                   ("COYOTE_SANDBOX_PROFILE",
                                    To_String (Current_Sandbox));
                              else
                                 Ada.Environment_Variables.Set
                                   ("COYOTE_SANDBOX_PROFILE", "");
                              end if;
                              LLM.Agent.Set_Sandbox_Profile
                                (S       => Agent_Session,
                                 Profile => To_String (Current_Sandbox));
                              State.Set_Sandbox
                                (To_String (Current_Sandbox));
                              Acme.Window.Replace_Line1
                                (Win,
                                 My_FS'Access,
                                 Format_Status (State, Status_Label));
                           exception
                              when Ex : others =>
                                 Append_Task_Warning
                                   ("sandbox profile change failed: "
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
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "[!] Agent task: "
                  & Ada.Exceptions.Exception_Message (Ex));
               begin
                  Acme.Window.Append
                    (Win,
                     My_FS'Access,
                     ASCII.LF & "[!] Agent task: "
                     & Ada.Exceptions.Exception_Message (Ex)
                     & ASCII.LF);
               exception
                  when others =>
                     null;
               end;
               if Opts.One_Shot then
                  declare
                     Err : constant JSON_Value := Create_Object;
                  begin
                     Err.Set_Field
                       ("error",
                        "agent task failed: "
                        & Ada.Exceptions.Exception_Message (Ex));
                     declare
                        Sess : constant String :=
                          LLM.Agent.Session_Id (Agent_Session);
                     begin
                        if Sess'Length > 0 then
                           Err.Set_Field
                             ("session_id", Create (Sess));
                        end if;
                     end;
                     State.Set_One_Shot_Result (Write (Err));
                  end;
               end if;
               Initiate_Shutdown;
         end;
      end Agent_Task;

      --  ── Acme_Event_Task ───────────────────────────────────────────────
      --
      --  Opens the window event file directly via 9P and parses raw acme
      --  events using Acme.Raw_Events — no external acmeevent process.

      task body Acme_Event_Task is
         Parser       : Acme.Raw_Events.Event_Parser;
         Got_Shutdown : Boolean := False;
      begin
         declare
            My_FS       : aliased Nine_P.Client.Fs;
            Ev_File     : aliased Nine_P.Client.File;
            Max_Retries : constant Positive := 5;
            Retry_Delay : constant Duration := 0.5;
            Connected   : Boolean := False;

            procedure Open_Models_Window is
               Parent  : constant String :=
                 Ada.Directories.Current_Directory & "/+coyote";
               Models  : constant
                 LLM.Model_Registry.Model_Info_Vectors.Vector :=
                   LLM.Model_Registry.Available_Models;
               Content : Unbounded_String;
            begin
               for Model of Models loop
                  declare
                     Name  : constant String :=
                       To_String (Model.Name);
                     Ctx   : constant String :=
                       Format_SI_Count (Model.Context_Window) & " ctx";
                     Price : constant String :=
                       Format_Model_Price
                         (Input_Per_MTok       => Model.Cost.Input,
                          Output_Per_MTok      => Model.Cost.Output,
                          Cache_Read_Per_MTok  => Model.Cost.Cache_Read,
                          Cache_Write_Per_MTok => Model.Cost.Cache_Write);
                  begin
                     Append
                       (Content,
                        "coyote-model+" & My_PID & "/"
                        & To_String (Model.Provider) & "/"
                        & To_String (Model.Model_Id)
                        & ASCII.HT & Name
                        & ASCII.HT & Ctx
                        & (if Price'Length > 0
                           then ASCII.HT & Price
                           else "")
                        & ASCII.LF);
                  end;
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
            Connection_Retry : for Attempt in 1 .. Max_Retries loop
               begin
                  Connect (My_FS, "acme");
                  Open
                    (Ev_File,
                     My_FS'Access,
                     Acme.Window.Event_Path (Win),
                     O_READ);
                  Connected := True;
                  exit Connection_Retry;
               exception
                  when Nine_P.Proto.P9_Error =>
                     exit Connection_Retry when Attempt = Max_Retries;
                     delay Retry_Delay;
               end;
            end loop Connection_Retry;

            if not Connected then
               raise Nine_P.Proto.P9_Error with
                 "Acme_Event_Task could not open the event file";
            end if;

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
                                       Sel  : constant String :=
                                         Acme.Window.Selection_Text
                                           (Win, My_FS'Access);
                                    begin
                                       if Sel'Length > 0 then
                                          if (State.Is_Streaming
                                            or else State.Is_Retrying)
                                            and then not State.Is_Paused
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
                                             declare
                                                Warn     : Unbounded_String;
                                                Filtered : constant String :=
                                                  Apply_Prompt_Filter
                                                    (Sel,
                                                     State.Prompt_Filter,
                                                     Warn);
                                             begin
                                                if Length (Warn) > 0 then
                                                   Acme.Window.Append
                                                     (Win,
                                                      My_FS'Access,
                                                      ASCII.LF & "[!] "
                                                      & To_String (Warn)
                                                      & ASCII.LF);
                                                end if;
                                                Acme.Window.Append
                                                  (Win,
                                                   My_FS'Access,
                                                   ASCII.LF & UC_TRI_R
                                                   & " " & Filtered
                                                   & ASCII.LF);
                                                Commands.Enqueue
                                                  (Prompt_Command, Filtered);
                                             end;
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
                                       Sel  : constant String :=
                                         Acme.Window.Selection_Text
                                           (Win, My_FS'Access);
                                    begin
                                       if Sel'Length > 0 then
                                          declare
                                             Warn     : Unbounded_String;
                                             Filtered : constant String :=
                                               Apply_Prompt_Filter
                                                 (Sel,
                                                  State.Prompt_Filter,
                                                  Warn);
                                          begin
                                             if Length (Warn) > 0 then
                                                Acme.Window.Append
                                                  (Win,
                                                   My_FS'Access,
                                                   ASCII.LF & "[!] "
                                                   & To_String (Warn)
                                                   & ASCII.LF);
                                             end if;
                                             Acme.Window.Append
                                               (Win,
                                                My_FS'Access,
                                                ASCII.LF & UC_HOOK_L
                                                & " Steer: " & Filtered
                                                & ASCII.LF);
                                             if State.Is_Streaming
                                               or else State.Is_Retrying
                                             then
                                                State.Set_Aborted (True);
                                                LLM.Agent.Request_Abort
                                                  (Agent_Session);
                                             end if;
                                             Commands.Enqueue
                                               (Prompt_Command, Filtered, True);
                                          end;
                                       end if;
                                    end;
                                 elsif Text = "New" then
                                    declare
                                       use GNATCOLL.OS.Process;
                                       Model   : constant String :=
                                         LLM.Agent.Current_Model_Spec
                                           (Agent_Session);
                                       Args    : Argument_List;
                                    begin
                                       Args.Append
                                         (Ada.Command_Line.Command_Name);
                                       if Model'Length > 0 then
                                          Args.Append ("--model");
                                          Args.Append (Model);
                                       end if;
                                       Coyote_Spawn.Spawn_Detached
                                         (Args,
                                          Cwd => Ada.Directories
                                                   .Current_Directory);
                                    end;
                                 elsif Text = "Pause" then
                                    --  Arm a pause to fire at the next turn
                                    --  boundary.  Update the tag immediately
                                    --  to show "Pausing" as visual feedback.
                                    if State.Is_Streaming
                                      and then not State.Is_Paused
                                      and then not State.Is_Pause_Armed
                                    then
                                       State.Set_Pause_Armed (True);
                                       LLM.Agent.Request_Pause (Agent_Session);
                                       Update_Tag
                                         (Win,
                                          My_FS'Access,
                                          Armed_Tag,
                                          State.Tag_Suffix);
                                    end if;
                                 elsif Text = "Resume" then
                                    --  Release the paused loop.  The
                                    --  Agent_Resumed_Event emitted by
                                    --  Run_Prompt will update the tag back
                                    --  to Running_Tag.
                                    if State.Is_Paused then
                                       State.Set_Paused (False);
                                       LLM.Agent.Resume (Agent_Session);
                                    end if;
                                 elsif Text = "Compact" then
                                    if not State.Is_Streaming
                                      and then not State.Is_Compacting
                                    then
                                       Commands.Enqueue (Compact_Command);
                                    end if;
                                 elsif Text = "Clear" then
                                    Acme.Window.Replace_Match
                                      (Win, My_FS'Access, "1,$", "");
                                    Acme.Window.Append
                                      (Win,
                                       My_FS'Access,
                                       Format_Status (State, "ready")
                                       & ASCII.LF);
                                 elsif Text = "Continue" then
                                    Acme.Window.Append
                                      (Win,
                                       My_FS'Access,
                                       ASCII.LF & UC_TRI_R
                                       & " Continue" & ASCII.LF);
                                    Commands.Enqueue
                                      (Prompt_Command, "Continue.");
                                 elsif Text = "Models" then
                                    Open_Models_Window;
                                 elsif Text = "Sessions" then
                                    declare
                                       Parent  : constant String :=
                                         Ada.Directories.Current_Directory
                                         & "/+coyote";
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
                                         & "/+coyote";
                                       Content : constant String :=
                                         "coyote-thinking+" & My_PID & "/low"
                                         & ASCII.LF
                                         & "coyote-thinking+" & My_PID
                                         & "/medium"
                                         & ASCII.LF
                                         & "coyote-thinking+" & My_PID
                                         & "/high"
                                         & ASCII.LF;
                                    begin
                                       Open_Sub_Window
                                         (My_FS'Access,
                                          Parent,
                                          "+thinking",
                                          Content);
                                    end;
                                 elsif Text = "SetDefault" then
                                    declare
                                       Model_Spec : constant String :=
                                         LLM.Agent.Current_Model_Spec
                                           (Agent_Session);
                                       Provider : Unbounded_String;
                                       Model_Id : Unbounded_String;
                                    begin
                                       if Model_Spec'Length > 0 then
                                          Split_Model_Spec
                                            (Model_Spec, Provider, Model_Id);
                                       end if;
                                       LLM.Settings.Save_Defaults
                                         (Provider    =>
                                            To_String (Provider),
                                          Model_Id    =>
                                            To_String (Model_Id),
                                          Think_Level =>
                                            State.Current_Thinking);
                                       Acme.Window.Append
                                         (Win,
                                          My_FS'Access,
                                          ASCII.LF & "[Defaults saved: "
                                          & Model_Spec
                                          & (if
                                            State.Current_Thinking'Length > 0
                                            then " ~"
                                              & State.Current_Thinking
                                            else "")
                                          & "]" & ASCII.LF);
                                    end;
                                 elsif Text = "Stats" then
                                    declare
                                       Parent    : constant String :=
                                         Ada.Directories.Current_Directory
                                         & "/+coyote";
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
                                                & Format_SI_Count (Ctx_Win)
                                                & " ctx)");
                                          end if;
                                          Append (Buf, "" & ASCII.LF);
                                       end if;
                                       if
                                         State.Current_Thinking'Length > 0
                                       then
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
                                             "Tokens this session:"
                                             & ASCII.LF);
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
                                             ASCII.LF & "Last turn:"
                                             & ASCII.LF);
                                          if Turn_Out > 0 then
                                             Append
                                               (Buf,
                                                "  Output:  "
                                                & Natural_Image (Turn_Out)
                                                & ASCII.LF);
                                          end if;
                                          if
                                            Turn_In > 0
                                              and then Ctx_Win > 0
                                          then
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
                                 Acme.Window.Send_Event
                                   (Win,
                                    My_FS'Access,
                                    Ev.C1,
                                    Ev.C2,
                                    Ev.Q0,
                                    Ev.Q1);
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
               declare
                  Msg : constant String :=
                    Ada.Exceptions.Exception_Message (Ex);
               begin
                  --  "deleted window" and "file does not exist" both mean the
                  --  acme window was closed; shut down silently in that case.
                  if Msg /= "deleted window"
                    and then Msg /= "file does not exist"
                  then
                     Ada.Text_IO.Put_Line
                       (Ada.Text_IO.Standard_Error,
                        "Acme_Event_Task terminated: "
                        & Ada.Exceptions.Exception_Information (Ex));
                  end if;
               end;
               begin
                  Acme.Window.Append
                    (Win,
                     My_FS'Access,
                     ASCII.LF & "[!] Acme event task: "
                     & Ada.Exceptions.Exception_Message (Ex)
                     & ASCII.LF);
               exception
                  when others =>
                     null;
               end;
               Initiate_Shutdown;
            when Ex : others =>
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "Acme_Event_Task terminated: "
                  & Ada.Exceptions.Exception_Information (Ex));
               begin
                  Acme.Window.Append
                    (Win,
                     My_FS'Access,
                     ASCII.LF & "[!] Acme event task: "
                     & Ada.Exceptions.Exception_Message (Ex)
                     & ASCII.LF);
               exception
                  when others =>
                     null;
               end;
               Initiate_Shutdown;
         end;
      end Acme_Event_Task;

      --  ── Plumb_Model_Task ──────────────────────────────────────────────

      task body Plumb_Model_Task is
         Got_Shutdown : Boolean := False;
      begin
         declare
            Pl_FS       : aliased Nine_P.Client.Fs;
            My_FS       : aliased Nine_P.Client.Fs;
            Port        : aliased Nine_P.Client.File;
            Max_Retries : constant Positive := 5;
            Retry_Delay : constant Duration := 0.5;
            Connected   : Boolean := False;
         begin
            Connection_Retry : for Attempt in 1 .. Max_Retries loop
               begin
                  Connect (Pl_FS, "plumb");
                  Connect (My_FS, "acme");
                  Open (Port, Pl_FS'Access, "/coyote-model", O_READ);
                  Connected := True;
                  exit Connection_Retry;
               exception
                  when Nine_P.Proto.P9_Error =>
                     exit Connection_Retry when Attempt = Max_Retries;
                     delay Retry_Delay;
               end;
            end loop Connection_Retry;

            if not Connected then
               raise Nine_P.Proto.P9_Error with
                 "Plumb_Model_Task could not open /coyote-model";
            end if;

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
                                      = "coyote-model+" & My_PID
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
         end;
      exception
         when Ex : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Plumb_Model_Task terminated: "
               & Ada.Exceptions.Exception_Information (Ex));
      end Plumb_Model_Task;

      --  ── Plumb_Thinking_Task ───────────────────────────────────────────

      task body Plumb_Thinking_Task is
         Got_Shutdown : Boolean := False;
      begin
         declare
            Pl_FS       : aliased Nine_P.Client.Fs;
            My_FS       : aliased Nine_P.Client.Fs;
            Port        : aliased Nine_P.Client.File;
            Max_Retries : constant Positive := 5;
            Retry_Delay : constant Duration := 0.5;
            Connected   : Boolean := False;
         begin
            Connection_Retry : for Attempt in 1 .. Max_Retries loop
               begin
                  Connect (Pl_FS, "plumb");
                  Connect (My_FS, "acme");
                  Open (Port, Pl_FS'Access, "/coyote-thinking", O_READ);
                  Connected := True;
                  exit Connection_Retry;
               exception
                  when Nine_P.Proto.P9_Error =>
                     exit Connection_Retry when Attempt = Max_Retries;
                     delay Retry_Delay;
               end;
            end loop Connection_Retry;

            if not Connected then
               raise Nine_P.Proto.P9_Error with
                 "Plumb_Thinking_Task could not open /coyote-thinking";
            end if;

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
         end;
      exception
         when Ex : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Plumb_Thinking_Task terminated: "
               & Ada.Exceptions.Exception_Information (Ex));
      end Plumb_Thinking_Task;

      --  ── Plumb_Fork_Task ───────────────────────────────────────────────

      task body Plumb_Fork_Task is
         use GNATCOLL.OS.Process;

         Pid_Prefix   : constant String :=
           "coyote-fork+" & My_PID & "/";
         Got_Shutdown : Boolean := False;
      begin
         declare
            Pl_FS       : aliased Nine_P.Client.Fs;
            My_FS       : aliased Nine_P.Client.Fs;
            Port        : aliased Nine_P.Client.File;
            Max_Retries : constant Positive := 5;
            Retry_Delay : constant Duration := 0.5;
            Connected   : Boolean := False;
         begin
            Connection_Retry : for Attempt in 1 .. Max_Retries loop
               begin
                  Connect (Pl_FS, "plumb");
                  Connect (My_FS, "acme");
                  Open (Port, Pl_FS'Access, "/coyote-fork", O_READ);
                  Connected := True;
                  exit Connection_Retry;
               exception
                  when Nine_P.Proto.P9_Error =>
                     exit Connection_Retry when Attempt = Max_Retries;
                     delay Retry_Delay;
               end;
            end loop Connection_Retry;

            if not Connected then
               raise Nine_P.Proto.P9_Error with
                 "Plumb_Fork_Task could not open /coyote-fork";
            end if;

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
                           UUID_US : Unbounded_String;
                           Turn_N  : Positive := 1;
                           Step_N  : Natural  := 0;
                        begin
                           if Parse_Fork_Token
                             (Data,
                              Pid_Prefix,
                              UUID_US,
                              Turn_N,
                              Step_N)
                           then
                              declare
                                 Cwd      : constant String :=
                                   Ada.Directories.Current_Directory;
                                 UUID     : constant String :=
                                   To_String (UUID_US);
                                 New_UUID : constant String :=
                                   Session_Lister.Fork_Session
                                     (UUID, Turn_N, Cwd,
                                      After_Step => Step_N);
                                 Args     : Argument_List;
                              begin
                                 if New_UUID'Length = 0 then
                                    Acme.Window.Append
                                      (Win,
                                       My_FS'Access,
                                       ASCII.LF & UC_WARN
                                       & " Fork failed (turn "
                                       & Natural_Image (Turn_N)
                                       & (if Step_N > 0
                                          then "/" & Natural_Image (Step_N)
                                          else "")
                                       & " not found in session)."
                                       & ASCII.LF);
                                 else
                                    Args.Append
                                      (Ada.Command_Line.Command_Name);
                                    Args.Append ("--session");
                                    Args.Append (New_UUID);
                                    Coyote_Spawn.Spawn_Detached
                                      (Args,
                                       Cwd => Cwd);
                                    Acme.Window.Append
                                      (Win,
                                       My_FS'Access,
                                       ASCII.LF & "[Forked -> "
                                       & New_UUID
                                         (New_UUID'First
                                          .. New_UUID'First + 7)
                                       & "...]" & ASCII.LF);
                                 end if;
                              end;
                           end if;
                        end;
                     end if;
                  end;
               end select;
               exit Plumb_Loop when Got_Shutdown;
            end loop Plumb_Loop;
         end;
      exception
         when Ex : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Plumb_Fork_Task terminated: "
               & Ada.Exceptions.Exception_Information (Ex));
      end Plumb_Fork_Task;

      --  ── Plumb_Sandbox_Task ────────────────────────────────────────────

      task body Plumb_Sandbox_Task is
         Got_Shutdown : Boolean := False;
      begin
         declare
            Pl_FS       : aliased Nine_P.Client.Fs;
            My_FS       : aliased Nine_P.Client.Fs;
            Port        : aliased Nine_P.Client.File;
            Max_Retries : constant Positive := 5;
            Retry_Delay : constant Duration := 0.5;
            Connected   : Boolean := False;
         begin
            Connection_Retry : for Attempt in 1 .. Max_Retries loop
               begin
                  Connect (Pl_FS, "plumb");
                  Connect (My_FS, "acme");
                  Open (Port, Pl_FS'Access, "/coyote-sandbox", O_READ);
                  Connected := True;
                  exit Connection_Retry;
               exception
                  when Nine_P.Proto.P9_Error =>
                     exit Connection_Retry when Attempt = Max_Retries;
                     delay Retry_Delay;
               end;
            end loop Connection_Retry;

            if not Connected then
               raise Nine_P.Proto.P9_Error with
                 "Plumb_Sandbox_Task could not open /coyote-sandbox";
            end if;

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
                                      = "coyote-sandbox+" & My_PID
                           then
                              declare
                                 Profile : constant String :=
                                   Data (First_Slash + 1 .. Data'Last);
                              begin
                                 Commands.Enqueue
                                   (Set_Sandbox_Command, Profile);
                                 Acme.Window.Append
                                   (Win,
                                    My_FS'Access,
                                    ASCII.LF & "[Sandbox -> " & Profile
                                    & "]" & ASCII.LF);
                              end;
                           end if;
                        end;
                     end if;
                  end;
               end select;
               exit Plumb_Loop when Got_Shutdown;
            end loop Plumb_Loop;
         end;
      exception
         when Ex : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Plumb_Sandbox_Task terminated: "
               & Ada.Exceptions.Exception_Information (Ex));
      end Plumb_Sandbox_Task;

   begin
      --  ── Initial window setup ──────────────────────────────────────────
      State.Set_Tag_Suffix
        (if Opts.One_Shot then "" else " Models Sessions Thinking Stats SetDefault");
      Acme.Window.Ctl (Win, Win_FS'Access, "cleartag");
      Acme.Window.Append_Tag (Win, Win_FS'Access, Tag_Extra);
      Acme.Window.Set_Name
        (Win,
         Win_FS'Access,
         Ada.Directories.Current_Directory & "/+coyote"
         & (if Length (Opts.Name) > 0
            then ":" & To_String (Opts.Name)
            else ""));
      Acme.Window.Append
        (Win, Win_FS'Access, UC_BULLET & " starting..." & ASCII.LF);
      Acme.Window.Ctl (Win, Win_FS'Access, "clean");

      --  ── Wait for window-closed shutdown ───────────────────────────────
      begin
         State.Wait_Shutdown;
      exception
         when Tasking_Error =>
            begin
               Acme.Window.Append
                 (Win,
                  Win_FS'Access,
                  ASCII.LF
                  & "[!] A task failed during startup - check stderr."
                  & ASCII.LF);
            exception
               when others =>
                  null;
            end;
            raise;
      end;

      --  ── One-shot teardown ─────────────────────────────────────────────
      --  Print the JSON result line for the spawning extension to read.
      --  If no result was stored (e.g. the user closed the window
      --  manually), emit a generic error object.
      if Opts.One_Shot then
         declare
            Json : constant String := State.One_Shot_Result;
         begin
            if Json'Length > 0 then
               Ada.Text_IO.Put_Line (Json);
            else
               declare
                  Err : constant JSON_Value := Create_Object;
               begin
                  Err.Set_Field
                    ("error",
                     "subagent closed before producing output");
                  Ada.Text_IO.Put_Line (Write (Err));
               end;
            end if;
         end;
      end if;

      --  ── Clean up empty sessions ───────────────────────────────────────
      --  If this was a freshly-created session (not resumed) and no
      --  prompts were ever submitted, delete the session file so it does
      --  not clutter the session list.
      if not Opts.One_Shot
        and then not Opts.No_Session
        and then Length (Opts.Session_Id) = 0
        and then not LLM.Agent.Has_Submitted_Prompts (Agent_Session)
      then
         declare
            S_Id : constant String := LLM.Agent.Session_Id (Agent_Session);
         begin
            if S_Id'Length > 0 then
               LLM.Session_Store.Delete_Session (S_Id);
            end if;
         exception
            when others =>
               null;
         end;
      end if;

      begin
         Acme.Window.Ctl (Win, Win_FS'Access, "delete");
      exception
         when others =>
            null;
      end;
   end Run;

   --  ── Run_GUI ───────────────────────────────────────────────────────────
   --
   --  GTK3 variant of Run.  Uses Coyote_App.Frontend.GUI instead of the
   --  acme window frontend.  No Win, no Acme_Event_Task, no Plumb_* tasks.
   --  The GUI frontend has no Input_Task; the GTK main loop runs on the main Ada task.
   --  Agent_Task reads typed items via My_Frontend.Read_Item.

   --  ── Run_GUI ───────────────────────────────────────────────────────────
   --
   --  GTK3 variant of Run.  Uses Coyote_App.Frontend.GUI.
   --  The GTK main loop runs on the main Ada task (the begin section).
   --  Agent_Task runs concurrently and communicates with GTK via the
   --  Frontend's protected Update queue.

   procedure Run_GUI (Opts : Options) is
      use type LLM.Events.Message_Update_Kind;

      My_PID   : constant String := Natural_Image (Natural (Getpid));
      Win_Name : constant String :=
        "coyote"
        & (if Length (Opts.Name) > 0
           then " : " & To_String (Opts.Name)
           else "");

      --  Shared objects closed over by Agent_Task:
      State            : App_State;
      Agent_Session    : aliased LLM.Agent.Session;
      My_Frontend      : Coyote_App.Frontend.GUI.Instance;
      Startup_Settings : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;

      function Status_Label return String is
      begin
         if State.Is_Compacting then
            return "compacting";
         elsif State.Is_Retrying then
            return "retrying";
         elsif State.Is_Paused then
            return "paused";
         elsif State.Is_Streaming then
            return "running";
         else
            return "ready";
         end if;
      end Status_Label;

      procedure Initiate_Shutdown is
      begin
         LLM.Agent.Request_Abort (Agent_Session);
         My_Frontend.Shutdown;
         State.Signal_Shutdown;
      exception
         when others =>
            My_Frontend.Shutdown;
            State.Signal_Shutdown;
      end Initiate_Shutdown;

      task Agent_Task;

      task body Agent_Task is
         Section          : Section_Kind    := No_Section;
         Current_Thinking : Unbounded_String := Null_Unbounded_String;
         Current_Sandbox  : Unbounded_String := Null_Unbounded_String;
         Current_Text     : Unbounded_String := Null_Unbounded_String;
         Final_Text         : Unbounded_String := Null_Unbounded_String;
         Final_Error        : Unbounded_String := Null_Unbounded_String;
         Completion_Pending : Boolean := False;
      begin
         declare

            procedure Track_Event
              (E : LLM.Events.Agent_Event'Class)
            is
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
                  Completion_Pending :=
                    not LLM.Events.Agent_End_Event (E).Was_Aborted
                    and then not Opts.One_Shot
                    and then not Opts.Subagent;
               elsif E in LLM.Events.Session_Stats_Event then
                  declare
                     Ev : constant LLM.Events.Session_Stats_Event :=
                       LLM.Events.Session_Stats_Event (E);
                  begin
                     My_Frontend.Set_Stats_Summary
                       ((Model          =>
                           To_Unbounded_String (State.Current_Model),
                         Session_Id     =>
                           To_Unbounded_String (State.Session_Id),
                         Turn_Count     => State.Turn_Count,
                         Last_Input     => State.Turn_Input_Tokens,
                         Last_Output    => State.Turn_Output_Tokens,
                         Last_Cost_Dmil => State.Turn_Cost_Dmil,
                         Input          => Ev.Input,
                         Cache_Read     => Ev.Cache_Read,
                         Cache_Write    => Ev.Cache_Write,
                         Output         => Ev.Output,
                         Cost_Dmil      => Ev.Cost_Dmil));
                  end;
               end if;
            end Track_Event;

            procedure Dispatch_Event
              (E : LLM.Events.Agent_Event'Class)
            is
            begin
               Track_Event (E);
               Coyote_App.Dispatch.Dispatch_Event
                 (Event    => E,
                  Frontend => My_Frontend,
                  State    => State,
                  Section  => Section,
                  PID      => My_PID);
               if E in LLM.Events.Session_Stats_Event
                 and then Completion_Pending
               then
                  My_Frontend.Notify_Completion;
                  Completion_Pending := False;
               end if;
            end Dispatch_Event;

            procedure Dispatch_Agent_Event
              (E : LLM.Events.Agent_Event'Class)
              renames Dispatch_Event;

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
                     Context_Window =>
                       LLM.Agent.Context_Window (Agent_Session));
               begin
                  Dispatch_Event (Event);
               end;
            end Emit_Model_Select;

            procedure Emit_Session_Info is
               Session_Id : constant String :=
                 LLM.Agent.Session_Id (Agent_Session);
               Event : constant LLM.Events.Session_Info_Event :=
                 (LLM.Events.Agent_Event with
                  Session_Id       => To_Unbounded_String (Session_Id),
                  Thinking_Level   => Current_Thinking,
                  Sandbox_Profile  =>
                    To_Unbounded_String
                      (LLM.Agent.Current_Sandbox (Agent_Session)),
                  Model            => To_Unbounded_String
                    (LLM.Agent.Current_Model_Spec (Agent_Session)),
                  Source_Directory => To_Unbounded_String
                    (LLM.Session_Store.Session_Work_Dir (Session_Id)),
                  Session_Start    => To_Unbounded_String
                    (LLM.Session_Store.Session_Created_At (Session_Id)));
            begin
               if Session_Id'Length > 0 then
                  My_Frontend.Set_Session_Identity (Session_Id);
               end if;
               Dispatch_Event (Event);
            end Emit_Session_Info;

            procedure Emit_Bootstrap is
            begin
               Emit_Model_Select;
               Emit_Session_Info;
            end Emit_Bootstrap;

            procedure Append_Task_Warning (Message : String) is
            begin
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error, "[!] " & Message);
               My_Frontend.Append_Notice
                 (Coyote_App.Frontend.Error, Message);
            end Append_Task_Warning;

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

            procedure Render_Loaded_Session (UUID : String) is
               Short_Id : constant String :=
                 (if UUID'Length >= 8
                  then UUID (UUID'First .. UUID'First + 7)
                  else UUID);
            begin
               My_Frontend.Append_Notice
                 (Coyote_App.Frontend.Info,
                  "Loading session " & Short_Id & UC_ELLIP);
               Render_Session_History
                 (UUID     => UUID,
                  Frontend => My_Frontend,
                  State    => State);
            end Render_Loaded_Session;

            procedure Synchronize_Sandbox is
               Profile : constant String :=
                 LLM.Agent.Current_Sandbox (Agent_Session);
            begin
               Current_Sandbox := To_Unbounded_String (Profile);
               State.Set_Sandbox (Profile);
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE", Profile);
            end Synchronize_Sandbox;

            procedure Store_One_Shot_Result is
               Result : constant JSON_Value := Create_Object;
            begin
               if State.Was_Aborted then
                  Result.Set_Field ("error", Create ("aborted"));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
               elsif Length (Final_Text) > 0 then
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  Result.Set_Field
                    ("output", Create (To_String (Final_Text)));
                  State.Set_One_Shot_Result (Write (Result));
               elsif Length (Final_Error) > 0 then
                  Result.Set_Field
                    ("error", Create (To_String (Final_Error)));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
               else
                  Result.Set_Field
                    ("error", Create ("No response from agent"));
                  Result.Set_Field
                    ("session_id",
                     Create (LLM.Agent.Session_Id (Agent_Session)));
                  State.Set_One_Shot_Result (Write (Result));
               end if;
            end Store_One_Shot_Result;

            procedure Run_Queued_Prompt
              (Prompt   : String;
               Is_Steer : Boolean)
            is
               pragma Unreferenced (Is_Steer);
            begin
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
                     declare
                        Err : constant JSON_Value := Create_Object;
                     begin
                        Err.Set_Field
                          ("error",
                           "prompt failed: "
                           & Ada.Exceptions.Exception_Message (Ex));
                        Err.Set_Field
                          ("session_id",
                           Create (LLM.Agent.Session_Id (Agent_Session)));
                        State.Set_One_Shot_Result (Write (Err));
                     end;
                     Initiate_Shutdown;
                  end if;
            end Run_Queued_Prompt;

         begin
            --  Load settings.
            declare
               Settings_Value : constant LLM.Settings.Settings :=
                 Startup_Settings;
            begin
               Current_Thinking := Settings_Value.Default_Thinking;
               if Length (Opts.Prompt_Filter) > 0 then
                  State.Set_Prompt_Filter
                    (To_String (Opts.Prompt_Filter));
               else
                  State.Set_Prompt_Filter
                    (To_String (Settings_Value.Prompt_Filter));
               end if;
               --  Inherit thinking level from parent subagent process.
               declare
                  Think_Level : constant String :=
                    Ada.Environment_Variables.Value
                      ("COYOTE_THINKING_LEVEL", "");
               begin
                  if Think_Level'Length > 0 then
                     Current_Thinking :=
                       Ada.Strings.Unbounded.To_Unbounded_String (Think_Level);
                  end if;
               end;
            end;

            My_Frontend.Set_Status ("Initializing" & UC_ELLIP);

            --  Promote inherited session ID for subagent lineage.
            declare
               Inherited_Sid : constant String :=
                 Ada.Environment_Variables.Value
                   ("COYOTE_SESSION_ID", "");
               Parent_Sid    : constant String :=
                 Ada.Environment_Variables.Value
                   ("COYOTE_PARENT_SESSION", "");
            begin
               if Parent_Sid'Length = 0
                 and then Inherited_Sid'Length > 0
               then
                  Ada.Environment_Variables.Set
                    ("COYOTE_PARENT_SESSION", Inherited_Sid);
               end if;
            end;

            LLM.Agent.Create
              (S          => Agent_Session,
               Model_Spec => To_String (Opts.Model),
               Agent      => To_String (Opts.Agent),
               No_Tools   => Opts.No_Tools,
               Session_Id => To_String (Opts.Session_Id),
               Subagent   => Opts.Subagent);
            Synchronize_Sandbox;
            My_Frontend.Register_Session (Agent_Session'Unchecked_Access);
            if Opts.No_Compact then
               LLM.Agent.Set_Compact_Settings
                 (Agent_Session,
                  (Enabled              => False,
                   Reserve_Tokens       =>
                     LLM.Compaction.Default_Compact_Settings
                       .Reserve_Tokens,
                   Keep_Recent_Tokens   =>
                     LLM.Compaction.Default_Compact_Settings
                       .Keep_Recent_Tokens,
                   Consecutive_Failures => 0,
                   Tripped              => False));
            end if;

            --  Publish session ID for child processes.
            declare
               Sess : constant String :=
                 LLM.Agent.Session_Id (Agent_Session);
            begin
               if Sess'Length > 0 then
                  Ada.Environment_Variables.Set
                    ("COYOTE_SESSION_ID", Sess);
               end if;
            end;
            --  Publish the thinking level for child subagent processes.
            if Ada.Strings.Unbounded.Length (Current_Thinking) > 0 then
               Ada.Environment_Variables.Set
                 ("COYOTE_THINKING_LEVEL",
                  Ada.Strings.Unbounded.To_String (Current_Thinking));
            else
               Ada.Environment_Variables.Set
                 ("COYOTE_THINKING_LEVEL", "");
            end if;

            --  Publish the sandbox profile for child subagent processes.
            if Ada.Strings.Unbounded.Length (Current_Sandbox) > 0 then
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE",
                  Ada.Strings.Unbounded.To_String (Current_Sandbox));
            else
               Ada.Environment_Variables.Set
                 ("COYOTE_SANDBOX_PROFILE", "");
            end if;


            if Length (Opts.Session_Id) > 0 then
               Render_Loaded_Session (To_String (Opts.Session_Id));
            end if;
            if Length (Opts.Work_Dir_Warning) > 0 then
               Append_Task_Warning (To_String (Opts.Work_Dir_Warning));
            end if;
            Emit_Bootstrap;

            --  If an initial prompt was supplied via --prompt, run it now.
            --  For --subagent / one-shot mode Run_Queued_Prompt calls
            --  Initiate_Shutdown after the turn, which marks the prompt
            --  queue for shutdown so Prompt_Loop exits immediately.
            if Length (Opts.Initial_Prompt) > 0 then
               My_Frontend.Begin_Request
                 (Text => To_String (Opts.Initial_Prompt),
                  Kind => Coyote_App.Frontend.Prompt);
               Run_Queued_Prompt
                 (Prompt   => To_String (Opts.Initial_Prompt),
                  Is_Steer => False);
            end if;

            --  Main input loop.
            Prompt_Loop : loop
               declare
                  It       : constant Coyote_GUI.Prompt_Queue.Item :=
                    My_Frontend.Read_Item;
                  Is_Steer : constant Boolean :=
                    State.Is_Streaming or else State.Is_Retrying;
               begin
                  case It.Kind is

                     when Coyote_GUI.Prompt_Queue.Shutdown_Item =>
                        exit Prompt_Loop;

                     when Coyote_GUI.Prompt_Queue.User_Prompt =>
                        declare
                           Prompt : constant String :=
                             Ada.Strings.Unbounded.To_String (It.Text);
                        begin
                           My_Frontend.Begin_Request
                             (Text => Prompt,
                              Kind =>
                                (if Is_Steer
                                 then Coyote_App.Frontend.Steer
                                 else Coyote_App.Frontend.Prompt));
                           Run_Queued_Prompt (Prompt, Is_Steer);
                        end;

                     when Coyote_GUI.Prompt_Queue.Stop =>
                        State.Set_Aborted (True);
                        LLM.Agent.Request_Abort (Agent_Session);

                     when Coyote_GUI.Prompt_Queue.Pause =>
                        if State.Is_Streaming
                          and then not State.Is_Paused
                          and then not State.Is_Pause_Armed
                        then
                           State.Set_Pause_Armed (True);
                           LLM.Agent.Request_Pause (Agent_Session);
                        end if;

                     when Coyote_GUI.Prompt_Queue.Resume =>
                        if State.Is_Paused then
                           State.Set_Paused (False);
                           LLM.Agent.Resume (Agent_Session);
                        end if;

                     when Coyote_GUI.Prompt_Queue.Compact =>
                        if not State.Is_Streaming
                          and then not State.Is_Compacting
                        then
                           declare
                              Compact_OK : Boolean;
                           begin
                              LLM.Agent.Compact
                                (Agent_Session,
                                 Dispatch_Agent_Event'Unrestricted_Access,
                                 "manual",
                                 Compact_OK);
                           end;
                        end if;

                     when Coyote_GUI.Prompt_Queue.Clear =>
                        My_Frontend.Clear_Conversation;

                     when Coyote_GUI.Prompt_Queue.New_Window =>
                        declare
                           use GNATCOLL.OS.Process;
                           Model   : constant String :=
                             LLM.Agent.Current_Model_Spec (Agent_Session);
                           Args    : Argument_List;
                        begin
                           Args.Append (Ada.Command_Line.Command_Name);
                           if Model'Length > 0 then
                              Args.Append ("--model");
                              Args.Append (Model);
                           end if;
                           Coyote_Spawn.Spawn_Detached
                             (Args,
                              Cwd => Ada.Directories.Current_Directory);
                        end;

                     when Coyote_GUI.Prompt_Queue.New_Session =>
                        begin
                           if State.Is_Streaming then
                              LLM.Agent.Request_Abort (Agent_Session);
                           end if;
                           declare
                              Settings_Value : constant LLM.Settings.Settings :=
                                LLM.Settings.Load_Settings;
                           begin
                              Ada.Environment_Variables.Set
                                ("COYOTE_THINKING_LEVEL",
                                 To_String (Settings_Value.Default_Thinking));
                              Ada.Environment_Variables.Set
                                ("COYOTE_SANDBOX_PROFILE",
                                 To_String (Settings_Value.Default_Sandbox));
                              LLM.Agent.Create
                                (S        => Agent_Session,
                                 Agent    => To_String (Opts.Agent),
                                 No_Tools => Opts.No_Tools);
                              Current_Thinking := Settings_Value.Default_Thinking;
                           end;
                           Synchronize_Sandbox;
                           My_Frontend.Register_Session
                             (Agent_Session'Unchecked_Access);
                           if Opts.No_Compact then
                              LLM.Agent.Set_Compact_Settings
                                (Agent_Session,
                                 (Enabled              => False,
                                  Reserve_Tokens       =>
                                    LLM.Compaction.Default_Compact_Settings
                                      .Reserve_Tokens,
                                  Keep_Recent_Tokens   =>
                                    LLM.Compaction.Default_Compact_Settings
                                      .Keep_Recent_Tokens,
                                  Consecutive_Failures => 0,
                                  Tripped              => False));
                           end if;
                           declare
                              Sess : constant String :=
                                LLM.Agent.Session_Id (Agent_Session);
                           begin
                              if Sess'Length > 0 then
                                 Ada.Environment_Variables.Set
                                   ("COYOTE_SESSION_ID", Sess);
                              end if;
                           end;
                           Reset_Session_State;
                           My_Frontend.Clear_Stats;
                           My_Frontend.Clear_Conversation;
                           Emit_Bootstrap;
                           My_Frontend.Append_Notice
                             (Coyote_App.Frontend.Info,
                              "New session" & UC_ELLIP);
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("new session failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Model =>
                        begin
                           LLM.Agent.Set_Model
                             (S    => Agent_Session,
                              Spec => Ada.Strings.Unbounded.To_String
                                        (It.Model_Spec));
                           Emit_Model_Select;
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("model change failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Thinking =>
                        begin
                           Current_Thinking :=
                             Ada.Strings.Unbounded.To_Unbounded_String
                               (Ada.Characters.Handling.To_Lower
                                  (LLM.Providers.Thinking_Level'Image
                                     (It.Level)));
                           LLM.Agent.Set_Thinking
                             (S     => Agent_Session,
                              Level => It.Level);
                           State.Set_Thinking (To_String (Current_Thinking));
                           Ada.Environment_Variables.Set
                             ("COYOTE_THINKING_LEVEL",
                              To_String (Current_Thinking));
                           My_Frontend.Set_Status
                             (Format_Status (State, Status_Label));
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("thinking change failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Sandbox =>
                        begin
                           Current_Sandbox := It.Profile_Name;
                           LLM.Agent.Set_Sandbox_Profile
                             (S       => Agent_Session,
                              Profile => To_String (Current_Sandbox));
                           State.Set_Sandbox
                             (To_String (Current_Sandbox));
                           Ada.Environment_Variables.Set
                             ("COYOTE_SANDBOX_PROFILE",
                              To_String (Current_Sandbox));
                           My_Frontend.Set_Status
                             (Format_Status (State, Status_Label));
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("sandbox profile change failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Switch_Session =>
                        begin
                           LLM.Agent.Switch_Session
                             (S    => Agent_Session,
                              UUID => Ada.Strings.Unbounded.To_String
                                        (It.Session_UUID));
                           Synchronize_Sandbox;
                           Reset_Session_State;
                           My_Frontend.Clear_Stats;
                           My_Frontend.Clear_Conversation;
                           Render_Loaded_Session
                             (Ada.Strings.Unbounded.To_String
                                (It.Session_UUID));
                           Emit_Bootstrap;
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("session switch failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Default =>
                        declare
                           Model_Spec : constant String :=
                             LLM.Agent.Current_Model_Spec (Agent_Session);
                           Provider : Unbounded_String;
                           Model_Id : Unbounded_String;
                        begin
                           if Model_Spec'Length > 0 then
                              Split_Model_Spec
                                (Model_Spec, Provider, Model_Id);
                           end if;
                           LLM.Settings.Save_Defaults
                             (Provider    => To_String (Provider),
                              Model_Id    => To_String (Model_Id),
                              Think_Level => State.Current_Thinking);
                           My_Frontend.Append_Notice
                             (Coyote_App.Frontend.Info,
                              "Defaults saved: " & Model_Spec
                              & (if
                                State.Current_Thinking'Length > 0
                                then " ~" & State.Current_Thinking
                                else ""));
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("saving defaults failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;

                     when Coyote_GUI.Prompt_Queue.Set_Preferences =>
                        begin
                           LLM.Settings.Save_Preferences
                             (Provider    => To_String
                                (It.Preferences.Provider),
                              Model_Id    => To_String
                                (It.Preferences.Model_Id),
                              Think_Level => Ada.Characters.Handling.To_Lower
                                (LLM.Providers.Thinking_Level'Image
                                   (It.Preferences.Thinking)),
                              Sandbox     => To_String
                                (It.Preferences.Sandbox),
                              Subagent_Provider        => To_String
                                (It.Preferences.Subagent_Provider),
                              Subagent_Model           => To_String
                                (It.Preferences.Subagent_Model),
                              Completion_Notifications =>
                                It.Preferences.Completion_Notifications);
                           My_Frontend.Set_Completion_Notifications
                             (It.Preferences.Completion_Notifications);
                           My_Frontend.Append_Notice
                             (Coyote_App.Frontend.Info,
                              "Preferences saved for new sessions");
                        exception
                           when Ex : others =>
                              Append_Task_Warning
                                ("saving preferences failed: "
                                 & Ada.Exceptions.Exception_Message (Ex));
                        end;
                  end case;
               end;
            end loop Prompt_Loop;
            My_Frontend.Shutdown;

            State.Signal_Shutdown;

         exception
            when Ex : others =>
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "[!] Agent task: "
                  & Ada.Exceptions.Exception_Message (Ex));
               My_Frontend.Append_Notice
                 (Coyote_App.Frontend.Error,
                  "Agent task: "
                  & Ada.Exceptions.Exception_Message (Ex));
               Initiate_Shutdown;
         end;
      end Agent_Task;

   begin
      --  Initialise GTK on the main task and create the window.
      --  The idle callback registered inside Create will drain the
      --  Updates queue once Gtk.Main.Main is running.
      Gtk.Main.Init;
      Coyote_App.Frontend.GUI.Create
        (F                          => My_Frontend,
         Win_Name                   => Win_Name,
         Pop_Under                  => Opts.Subagent,
         Notifications_Allowed      =>
           not Opts.One_Shot and then not Opts.Subagent,
         Notifications_Enabled     =>
           Startup_Settings.Completion_Notifications);

      if Opts.Debug_Logging then
         My_Frontend.Set_Debug_Logging (True);
      end if;

      --  Enter the GTK event loop; returns when Main_Quit is called
      --  (either from the window close handler or the Shutdown update).
      Gtk.Main.Main;
      Coyote_Notify.Finalize;

      --  For one-shot mode, wait for Agent_Task to store the result
      --  before we return (Agent_Task calls State.Signal_Shutdown just
      --  before enqueueing the Shutdown update).
      if Opts.One_Shot then
         State.Wait_Shutdown;
         declare
            Json : constant String := State.One_Shot_Result;
         begin
            if Json'Length > 0 then
               Ada.Text_IO.Put_Line (Json);
            else
               declare
                  Err : constant JSON_Value := Create_Object;
               begin
                  Err.Set_Field
                    ("error",
                     "subagent closed before producing output");
                  Ada.Text_IO.Put_Line (Write (Err));
               end;
            end if;
         end;
      end if;

      --  Delete empty sessions (not resumed, no prompts submitted).
      if not Opts.No_Session
        and then Length (Opts.Session_Id) = 0
        and then not LLM.Agent.Has_Submitted_Prompts (Agent_Session)
      then
         declare
            S_Id : constant String :=
              LLM.Agent.Session_Id (Agent_Session);
         begin
            if S_Id'Length > 0 then
               LLM.Session_Store.Delete_Session (S_Id);
            end if;
         exception
            when others =>
               null;
         end;
      end if;
   end Run_GUI;

end Coyote_App;
