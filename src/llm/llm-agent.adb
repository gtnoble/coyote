--  LLM.Agent body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.HTTP;
with LLM.Model_Registry;
with LLM.Providers.Anthropic_Messages;
with LLM.Providers.GitHub_Copilot;
with LLM.Providers.OpenRouter;
with LLM.Session_Store;
with LLM.Settings;
with LLM.Tools;

package body LLM.Agent is

   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Events.Message_Update_Kind;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;
   use type LLM.Types.Stop_Reason;
   use type LLM.Types.Usage;

   type Pending_Tool is record
      Tool_Call_Id   : Unbounded_String;
      Tool_Name      : Unbounded_String;
      Arguments_Json : Unbounded_String;
   end record;

   package Pending_Tool_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Pending_Tool);

   type Open_Block_Kind is (No_Open_Block, Open_Text, Open_Thinking);

   type Assistant_Builder is record
      Content      : LLM.Types.Content_Block_Vectors.Vector;
      Open_Kind    : Open_Block_Kind := No_Open_Block;
      Open_Text    : Unbounded_String;
      Stop         : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Tok_Usage    : LLM.Types.Usage := (others => 0);
      Error_Text   : Unbounded_String;
      Saw_Content  : Boolean := False;
      Saw_Msg_End  : Boolean := False;
   end record;

   protected body Abort_Flag is

      procedure Set is
      begin
         Value := True;
      end Set;

      procedure Clear is
      begin
         Value := False;
      end Clear;

      function Requested return Boolean is
      begin
         return Value;
      end Requested;

   end Abort_Flag;

   procedure Emit
     (Handler : not null access procedure
        (E : LLM.Events.Agent_Event'Class);
      Event   : LLM.Events.Agent_Event'Class) is
   begin
      Handler.all (Event);
   end Emit;

   function Lowercase (Text : String) return String is
   begin
      return Ada.Characters.Handling.To_Lower (Text);
   end Lowercase;

   function Thinking_From_String
     (Text : String) return LLM.Providers.Thinking_Level
   is
      Value : constant String := Lowercase (Text);
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
   end Thinking_From_String;

   function Thinking_Image
     (Level : LLM.Providers.Thinking_Level) return String
   is
   begin
      case Level is
         when LLM.Providers.Off =>
            return "off";
         when LLM.Providers.Minimal =>
            return "minimal";
         when LLM.Providers.Low =>
            return "low";
         when LLM.Providers.Medium =>
            return "medium";
         when LLM.Providers.High =>
            return "high";
         when LLM.Providers.X_High =>
            return "xhigh";
      end case;
   end Thinking_Image;

   function Stop_Reason_Image
     (Reason : LLM.Types.Stop_Reason) return String
   is
   begin
      case Reason is
         when LLM.Types.Stop =>
            return "stop";
         when LLM.Types.Length =>
            return "length";
         when LLM.Types.Tool_Use =>
            return "toolUse";
         when LLM.Types.Aborted =>
            return "aborted";
         when LLM.Types.Error_Stop =>
            return "error";
         when others =>
            return "unknown";
      end case;
   end Stop_Reason_Image;

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

   function Normalized_Model_Spec
     (Info : LLM.Model_Registry.Model_Info) return String
   is
   begin
      return To_String (Info.Provider) & "/" & To_String (Info.Model_Id);
   end Normalized_Model_Spec;

   function Effective_Model_Spec (Requested : String) return String is
      Settings_Value : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;
      Available      : constant LLM.Model_Registry.Model_Info_Vectors.Vector :=
        LLM.Model_Registry.Available_Models;
   begin
      if Requested'Length > 0 then
         return Requested;
      end if;

      if Length (Settings_Value.Default_Provider) > 0
        and then Length (Settings_Value.Default_Model) > 0
      then
         return To_String (Settings_Value.Default_Provider)
           & "/"
           & To_String (Settings_Value.Default_Model);
      end if;

      if Length (Settings_Value.Default_Model) > 0
        and then Ada.Strings.Fixed.Index
          (To_String (Settings_Value.Default_Model), "/") > 0
      then
         return To_String (Settings_Value.Default_Model);
      end if;

      if not Available.Is_Empty then
         return Normalized_Model_Spec (Available.First_Element);
      end if;

      raise Constraint_Error with
        "No model configured; pass --model or set ~/.pi/agent/settings.json";
   end Effective_Model_Spec;

   function Resolved_Model_Info (Spec : String)
      return LLM.Model_Registry.Model_Info
   is
      Provider : Unbounded_String;
      Model_Id : Unbounded_String;
   begin
      Split_Model_Spec (Spec, Provider, Model_Id);
      return LLM.Model_Registry.Lookup
        (Provider => To_String (Provider),
         Model_Id => To_String (Model_Id));
   end Resolved_Model_Info;

   function Max_Tokens_For
     (Info : LLM.Model_Registry.Model_Info) return Positive
   is
   begin
      if Info.Max_Tokens = 0 then
         return 1;
      else
         return Positive (Info.Max_Tokens);
      end if;
   end Max_Tokens_For;

   procedure Finish_Open_Block (Builder : in out Assistant_Builder) is
   begin
      if Builder.Open_Kind = Open_Text then
         Builder.Content.Append
           ((Kind => LLM.Types.Text_Block,
             Text => Builder.Open_Text));
         Builder.Saw_Content := True;
      elsif Builder.Open_Kind = Open_Thinking then
         Builder.Content.Append
           ((Kind     => LLM.Types.Thinking_Block,
             Thinking => Builder.Open_Text));
         Builder.Saw_Content := True;
      end if;

      Builder.Open_Kind := No_Open_Block;
      Builder.Open_Text := Null_Unbounded_String;
   end Finish_Open_Block;

   procedure Start_Open_Block
     (Builder : in out Assistant_Builder;
      Kind    :        Open_Block_Kind) is
   begin
      if Builder.Open_Kind /= Kind then
         Finish_Open_Block (Builder);
         Builder.Open_Kind := Kind;
         Builder.Open_Text := Null_Unbounded_String;
      end if;
   end Start_Open_Block;

   procedure Consume_Update
     (Builder : in out Assistant_Builder;
      Event   :        LLM.Events.Message_Update_Event) is
   begin
      case Event.Kind is
         when LLM.Events.Thinking_Start =>
            Start_Open_Block (Builder, Open_Thinking);

         when LLM.Events.Thinking_Delta =>
            Start_Open_Block (Builder, Open_Thinking);
            Append (Builder.Open_Text, To_String (Event.Delta_Text));

         when LLM.Events.Thinking_End =>
            Finish_Open_Block (Builder);

         when LLM.Events.Text_Start =>
            Start_Open_Block (Builder, Open_Text);

         when LLM.Events.Text_Delta =>
            Start_Open_Block (Builder, Open_Text);
            Append (Builder.Open_Text, To_String (Event.Delta_Text));

         when LLM.Events.Text_End =>
            Finish_Open_Block (Builder);

         when LLM.Events.Tool_Call_Start | LLM.Events.Tool_Call_Delta =>
            null;

         when LLM.Events.Tool_Call_End =>
            Finish_Open_Block (Builder);
            Builder.Content.Append
              ((Kind           => LLM.Types.Tool_Call_Block,
                Tool_Call_Id   => Event.Tool_Call_Id,
                Tool_Name      => Event.Tool_Name,
                Arguments_Json => Event.Delta_Text));
            Builder.Saw_Content := True;
      end case;
   end Consume_Update;

   function Has_Assistant_Message
     (Builder : Assistant_Builder) return Boolean is
   begin
      return Builder.Saw_Content or else Builder.Saw_Msg_End;
   end Has_Assistant_Message;

   function Assistant_Message
     (Builder : in out Assistant_Builder) return LLM.Types.Message
   is
   begin
      Finish_Open_Block (Builder);

      return
        (Role      => LLM.Types.Assistant,
         Content   => Builder.Content,
         Tok_Usage => Builder.Tok_Usage,
         Stop      => Builder.Stop,
         Timestamp => Null_Unbounded_String);
   end Assistant_Message;

   function User_Message (Prompt : String) return LLM.Types.Message is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Prompt)));

      return
        (Role      => LLM.Types.User,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Null_Unbounded_String);
   end User_Message;

   function Tool_Result_Message
     (Tool_Call_Id : String;
      Result_Text  : String;
      Is_Error     : Boolean) return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String (Tool_Call_Id),
          Result_Text => To_Unbounded_String (Result_Text),
          Is_Error    => Is_Error));

      return
        (Role      => LLM.Types.Tool_Result,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Null_Unbounded_String);
   end Tool_Result_Message;

   function Build_Tools_Json
     (Info     : LLM.Model_Registry.Model_Info;
      No_Tools : Boolean) return String
   is
      Tools : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      if No_Tools or else not Info.Supports_Tools then
         return "[]";
      end if;

      for Descriptor of LLM.Tools.Built_In_Tools loop
         declare
            Parsed : constant GNATCOLL.JSON.Read_Result :=
              GNATCOLL.JSON.Read (To_String (Descriptor.Schema_Json));
         begin
            if not Parsed.Success then
               raise Constraint_Error with
                 "Invalid tool schema JSON for "
                 & To_String (Descriptor.Name)
                 & ": "
                 & GNATCOLL.JSON.Format_Parsing_Error (Parsed.Error);
            end if;

            if Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type then
               raise Constraint_Error with
                 "Invalid tool schema JSON for "
                 & To_String (Descriptor.Name)
                 & ": expected object";
            end if;

            if Lowercase (To_String (Info.Wire_Format)) =
              "anthropic-messages"
            then
               declare
                  Tool_Object : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Create_Object;
               begin
                  Tool_Object.Set_Field ("name", To_String (Descriptor.Name));
                  Tool_Object.Set_Field
                    ("description", To_String (Descriptor.Description));
                  Tool_Object.Set_Field ("input_schema", Parsed.Value);
                  GNATCOLL.JSON.Append (Tools, Tool_Object);
               end;
            else
               declare
                  Tool_Object : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Create_Object;
                  Function_Object : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Create_Object;
               begin
                  Function_Object.Set_Field
                    ("name", To_String (Descriptor.Name));
                  Function_Object.Set_Field
                    ("description", To_String (Descriptor.Description));
                  Function_Object.Set_Field ("parameters", Parsed.Value);
                  Tool_Object.Set_Field ("type", "function");
                  Tool_Object.Set_Field ("function", Function_Object);
                  GNATCOLL.JSON.Append (Tools, Tool_Object);
               end;
            end if;
         end;
      end loop;

      declare
         Tools_Value : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create (Tools);
      begin
         return GNATCOLL.JSON.Write (Tools_Value);
      end;
   end Build_Tools_Json;

   function Retryable_Status_Code (Message : String) return Natural is
      use type Character;

      Pos : Natural := Message'First;
   begin
      while Pos <= Message'Last loop
         if Pos + 3 <= Message'Last
           and then Message (Pos .. Pos + 3) = "HTTP"
         then
            declare
               Scan : Natural := Pos + 4;
            begin
               while Scan <= Message'Last and then Message (Scan) = ' ' loop
                  Scan := Scan + 1;
               end loop;

               if Scan + 2 <= Message'Last
                 and then Message (Scan) in '0' .. '9'
                 and then Message (Scan + 1) in '0' .. '9'
                 and then Message (Scan + 2) in '0' .. '9'
               then
                  return Natural'Value (Message (Scan .. Scan + 2));
               end if;
            end;
         end if;

         Pos := Pos + 1;
      end loop;

      if Ada.Strings.Fixed.Index (Message, "429") > 0 then
         return 429;
      elsif Ada.Strings.Fixed.Index (Message, "529") > 0 then
         return 529;
      else
         return 0;
      end if;
   end Retryable_Status_Code;

   function Is_Retryable_Error
     (Occurrence : Ada.Exceptions.Exception_Occurrence) return Boolean
   is
      Status : constant Natural :=
        Retryable_Status_Code
          (Ada.Exceptions.Exception_Message (Occurrence));
   begin
      return Status = 429
        or else Status = 529
        or else (Status >= 500 and then Status <= 599);
   end Is_Retryable_Error;

   procedure Delay_With_Abort
     (S           : in out Session;
      Delay_Ms    :        Natural;
      Was_Aborted :    out Boolean)
   is
      Remaining : Natural := Delay_Ms;
      Step_Ms   : constant Natural := 100;
   begin
      Was_Aborted := False;

      while Remaining > 0 loop
         if S.Abort_State.Requested then
            Was_Aborted := True;
            return;
         end if;

         declare
            Sleep_Ms : constant Natural :=
              (if Remaining > Step_Ms then Step_Ms else Remaining);
         begin
            delay Duration (Sleep_Ms) / 1000.0;
            Remaining := Remaining - Sleep_Ms;
         end;
      end loop;
   end Delay_With_Abort;

   function Usage_Cost_Dollars
     (Tok_Usage : LLM.Types.Usage;
      Rates     : LLM.Types.Model_Cost) return Long_Float
   is
   begin
      return Long_Float (Tok_Usage.Input)
        * Rates.Input / 1_000_000.0
        + Long_Float (Tok_Usage.Output)
        * Rates.Output / 1_000_000.0
        + Long_Float (Tok_Usage.Cache_Read)
        * Rates.Cache_Read / 1_000_000.0;
   end Usage_Cost_Dollars;

   function Usage_Cost_Dmil
     (Tok_Usage : LLM.Types.Usage;
      Rates     : LLM.Types.Model_Cost) return Natural
   is
      Cost : constant Long_Float := Usage_Cost_Dollars (Tok_Usage, Rates);
   begin
      return Natural (Long_Float'Floor (Cost * 10_000.0 + 0.5));
   end Usage_Cost_Dmil;

   function Session_Stats
     (S : Session) return LLM.Events.Session_Stats_Event
   is
      Totals                 : LLM.Types.Usage := (others => 0);
      Latest_Assistant_Usage : LLM.Types.Usage := (others => 0);
      Saw_Assistant          : Boolean         := False;
      Total_Cost            : Long_Float      := 0.0;
   begin
      for Msg of S.History loop
         Totals := Totals + Msg.Tok_Usage;

         if Msg.Role = LLM.Types.Assistant then
            Latest_Assistant_Usage := Msg.Tok_Usage;
            Saw_Assistant := True;
         end if;
      end loop;

      if Saw_Assistant then
         Total_Cost :=
           Usage_Cost_Dollars (Latest_Assistant_Usage, S.Model_Info.Cost);
      end if;

      return
        (LLM.Events.Agent_Event with
         Cost_Dmil   =>
           Natural (Long_Float'Floor (Total_Cost * 10_000.0 + 0.5)),
         Input       => Totals.Input,
         Output      => Totals.Output,
         Cache_Read  => Totals.Cache_Read,
         Cache_Write => Totals.Cache_Write,
         Total       => Totals.Input
           + Totals.Output
           + Totals.Cache_Read
           + Totals.Cache_Write);
   end Session_Stats;

   procedure Set_Model_Internal
     (S    : in out Session;
      Spec :        String) is
   begin
      S.Model_Info := Resolved_Model_Info (Spec);
      S.Model_Spec :=
        To_Unbounded_String (Normalized_Model_Spec (S.Model_Info));
   end Set_Model_Internal;

   procedure Send_With_Retry
     (S             : in out Session;
      Provider      : in out LLM.Providers.Provider'Class;
      Tools_Json    :        String;
      Builder       : in out Assistant_Builder;
      Pending_Tools : in out Pending_Tool_Vectors.Vector;
      On_Event      :        not null access procedure
        (E : LLM.Events.Agent_Event'Class))
   is
      Delays_Ms   : constant array (Positive range 1 .. 3) of Natural :=
        (2_000, 4_000, 8_000);
      Succeeded   : Boolean := False;
      Attempt     : Positive := 1;
      Retry_Used  : Boolean := False;

      procedure Provider_Event_Handler (E : LLM.Events.Agent_Event'Class) is
      begin
         if E in LLM.Events.Agent_Start_Event
           or else E in LLM.Events.Agent_End_Event
         then
            null;
         elsif E in LLM.Events.Message_Update_Event then
            declare
               Update : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (E);
            begin
               Consume_Update (Builder, Update);
               if Update.Kind = LLM.Events.Tool_Call_End then
                  Pending_Tools.Append
                    ((Tool_Call_Id   => Update.Tool_Call_Id,
                      Tool_Name      => Update.Tool_Name,
                      Arguments_Json => Update.Delta_Text));
               end if;
               Emit (On_Event, E);
            end;
         elsif E in LLM.Events.Message_End_Event then
            declare
               Msg_End : constant LLM.Events.Message_End_Event :=
                 LLM.Events.Message_End_Event (E);
               Turn_End : constant LLM.Events.Message_End_Event :=
                 (LLM.Events.Agent_Event with
                  Stop      => Msg_End.Stop,
                  Err_Msg   => Msg_End.Err_Msg,
                  Tok_Usage => Msg_End.Tok_Usage,
                  Cost_Dmil =>
                    (if Msg_End.Cost_Dmil > 0
                     then Msg_End.Cost_Dmil
                     else
                       Usage_Cost_Dmil
                         (Msg_End.Tok_Usage, S.Model_Info.Cost)));
            begin
               Builder.Stop := Turn_End.Stop;
               Builder.Tok_Usage := Turn_End.Tok_Usage;
               Builder.Error_Text := Turn_End.Err_Msg;
               Builder.Saw_Msg_End := True;
               Emit (On_Event, Turn_End);
            end;
         else
            Emit (On_Event, E);
         end if;
      end Provider_Event_Handler;
   begin
      Attempt_Loop :
      while Attempt <= Delays_Ms'Last + 1 loop
         begin
            Provider.Send
              (Model_Id      => To_String (S.Model_Info.Model_Id),
               System_Prompt => To_String (S.System_Prompt),
               Messages      => S.History,
               Tools_Json    => Tools_Json,
               Thinking      => S.Thinking,
               Max_Tokens    => Max_Tokens_For (S.Model_Info),
               Handler       => Provider_Event_Handler'Unrestricted_Access);

            if Retry_Used then
               declare
                  Event : constant LLM.Events.Auto_Retry_End_Event :=
                    (LLM.Events.Agent_Event with
                     Success     => True,
                     Attempt     => Attempt,
                     Final_Error => Null_Unbounded_String);
               begin
                  Emit (On_Event, Event);
               end;
            end if;

            Succeeded := True;
            exit Attempt_Loop;
         exception
            when Occurrence : others =>
               if S.Abort_State.Requested then
                  exit Attempt_Loop;
               elsif Is_Retryable_Error (Occurrence)
                 and then Attempt <= Delays_Ms'Last
               then
                  Retry_Used := True;
                  declare
                     Delay_Ms : constant Natural := Delays_Ms (Attempt);
                     Event    : constant LLM.Events.Auto_Retry_Start_Event :=
                       (LLM.Events.Agent_Event with
                        Attempt      => Attempt,
                        Max_Attempts => Delays_Ms'Last + 1,
                        Delay_Ms     => Delay_Ms,
                        Error_Msg    => To_Unbounded_String
                          (Ada.Exceptions.Exception_Message (Occurrence)));
                     Was_Aborted : Boolean;
                  begin
                     Emit (On_Event, Event);
                     Delay_With_Abort (S, Delay_Ms, Was_Aborted);
                     if Was_Aborted then
                        exit Attempt_Loop;
                     end if;
                  end;
               elsif Is_Retryable_Error (Occurrence) and then Retry_Used then
                  declare
                     Event : constant LLM.Events.Auto_Retry_End_Event :=
                       (LLM.Events.Agent_Event with
                        Success     => False,
                        Attempt     => Attempt,
                        Final_Error => To_Unbounded_String
                          (Ada.Exceptions.Exception_Message (Occurrence)));
                  begin
                     Emit (On_Event, Event);
                  end;
                  raise;
               else
                  raise;
               end if;
         end;

         Attempt := Attempt + 1;
      end loop Attempt_Loop;

      if not Succeeded and then S.Abort_State.Requested then
         null;
      end if;
   end Send_With_Retry;

   procedure Create
     (S             :    out Session;
      Model_Spec    :        String  := "";
      System_Prompt :        String  := "";
      No_Tools      :        Boolean := False;
      Session_Id    :        String  := "")
   is
      Effective_Spec : constant String := Effective_Model_Spec (Model_Spec);
      Settings_Value : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;
   begin
      S.Model_Spec := Null_Unbounded_String;
      S.System_Prompt := To_Unbounded_String (System_Prompt);
      S.Session_UUID := Null_Unbounded_String;
      S.History.Clear;
      S.No_Tools := No_Tools;
      S.Thinking := Thinking_From_String
        (To_String (Settings_Value.Default_Thinking));
      S.Abort_State.Clear;
      S.Streaming := False;
      S.Cwd := To_Unbounded_String (Ada.Directories.Current_Directory);
      S.Model_Info := EMPTY_MODEL_INFO;

      LLM.Model_Registry.Refresh_GitHub_Copilot;
      LLM.Model_Registry.Refresh_OpenRouter;
      LLM.Model_Registry.Refresh_Anthropic;

      Set_Model_Internal (S, Effective_Spec);

      if Session_Id'Length > 0 then
         if LLM.Session_Store.Session_File_Path (Session_Id)'Length = 0 then
            raise LLM.Session_Store.Session_Error with
              "Session not found: " & Session_Id;
         end if;

         S.Session_UUID := To_Unbounded_String (Session_Id);
         S.History := LLM.Session_Store.Load_Messages (Session_Id);
      else
         S.Session_UUID := To_Unbounded_String
           (LLM.Session_Store.Create_Session (To_String (S.Cwd)));
      end if;
   end Create;

   procedure Run_Prompt
     (S        : in out Session;
      Prompt   :        String;
      On_Event :        not null access procedure
        (E : LLM.Events.Agent_Event'Class))
   is
      Builder                : Assistant_Builder;
      Pending_Tools          : Pending_Tool_Vectors.Vector;
      Messages_To_Persist    : LLM.Types.Message_Vectors.Vector;
      Tools_Json             : constant String :=
        Build_Tools_Json (S.Model_Info, S.No_Tools);
      Prompt_Msg              : constant LLM.Types.Message :=
        User_Message (Prompt);
      Was_Aborted             : Boolean := False;
      Turn_Completed_Normally : Boolean := False;

      procedure Append_Pending_Message (Msg : LLM.Types.Message) is
      begin
         S.History.Append (Msg);
         Messages_To_Persist.Append (Msg);
      end Append_Pending_Message;

      procedure Append_Pending_Batch
        (Messages : LLM.Types.Message_Vectors.Vector)
      is
      begin
         for Msg of Messages loop
            Append_Pending_Message (Msg);
         end loop;
      end Append_Pending_Batch;

      procedure Flush_Pending_Messages is
      begin
         for Msg of Messages_To_Persist loop
            LLM.Session_Store.Append_Message
              (To_String (S.Session_UUID), Msg);
         end loop;
      end Flush_Pending_Messages;
   begin
      S.Abort_State.Clear;
      S.History.Append (Prompt_Msg);
      LLM.Session_Store.Append_Message
        (To_String (S.Session_UUID), Prompt_Msg);

      declare
         Model_Event : constant LLM.Events.Model_Select_Event :=
           (LLM.Events.Agent_Event with
            Provider       => S.Model_Info.Provider,
            Model_Id       => S.Model_Info.Model_Id,
            Context_Window => S.Model_Info.Context_Window);
         Start_Event : constant LLM.Events.Agent_Start_Event :=
           (LLM.Events.Agent_Event with null record);
      begin
         Emit (On_Event, Model_Event);
         Emit (On_Event, Start_Event);
      end;

      S.Streaming := True;

      begin
         Agentic_Loop :
         loop
            Builder :=
              (Content      => <>,
               Open_Kind    => No_Open_Block,
               Open_Text    => Null_Unbounded_String,
               Stop         => LLM.Types.Unknown_Stop,
               Tok_Usage    => (others => 0),
               Error_Text   => Null_Unbounded_String,
               Saw_Content  => False,
               Saw_Msg_End  => False);
            Pending_Tools.Clear;

            if S.Abort_State.Requested then
               exit Agentic_Loop;
            end if;

            if Lowercase (To_String (S.Model_Info.Provider)) =
              "github-copilot"
            then
               declare
                  Provider : LLM.Providers.GitHub_Copilot.Provider :=
                    LLM.Providers.GitHub_Copilot.Create;
               begin
                  Send_With_Retry
                    (S             => S,
                     Provider      => Provider,
                     Tools_Json    => Tools_Json,
                     Builder       => Builder,
                     Pending_Tools => Pending_Tools,
                     On_Event      => On_Event);
               end;
            elsif Lowercase (To_String (S.Model_Info.Provider)) =
              "openrouter"
            then
               declare
                  Provider : LLM.Providers.OpenRouter.Provider :=
                    LLM.Providers.OpenRouter.Create;
               begin
                  Send_With_Retry
                    (S             => S,
                     Provider      => Provider,
                     Tools_Json    => Tools_Json,
                     Builder       => Builder,
                     Pending_Tools => Pending_Tools,
                     On_Event      => On_Event);
               end;
            elsif Lowercase (To_String (S.Model_Info.Provider)) =
              "anthropic"
            then
               declare
                  Api_Key  : constant String :=
                    LLM.Settings.Resolve_Api_Key ("anthropic");
                  Provider : LLM.Providers.Anthropic_Messages.Provider :=
                    LLM.Providers.Anthropic_Messages.Create
                      ("https://api.anthropic.com", Api_Key);
               begin
                  Send_With_Retry
                    (S             => S,
                     Provider      => Provider,
                     Tools_Json    => Tools_Json,
                     Builder       => Builder,
                     Pending_Tools => Pending_Tools,
                     On_Event      => On_Event);
               end;
            else
               raise Constraint_Error with
                 "Unsupported provider: " & To_String (S.Model_Info.Provider);
            end if;

            Finish_Open_Block (Builder);

            if not Pending_Tools.Is_Empty then
               declare
                  Reply         : constant LLM.Types.Message :=
                    Assistant_Message (Builder);
                  Tool_Messages : LLM.Types.Message_Vectors.Vector;
                  Next_Index    : Natural := Pending_Tools.First_Index;
               begin
                  if not Has_Assistant_Message (Builder) then
                     raise Constraint_Error with
                       "Tool batch missing assistant message";
                  end if;

                  while Next_Index <= Pending_Tools.Last_Index loop
                     exit when S.Abort_State.Requested;

                     declare
                        Tool_Block : constant Pending_Tool :=
                          Pending_Tools.Element (Next_Index);
                        Start_Event : constant
                          LLM.Events.Tool_Execution_Start_Event :=
                            (LLM.Events.Agent_Event with
                             Tool_Call_Id => Tool_Block.Tool_Call_Id,
                             Tool_Name    => Tool_Block.Tool_Name,
                             Args_Json    => Tool_Block.Arguments_Json);
                        Result_Text : Unbounded_String;
                        Is_Error    : Boolean := False;
                     begin
                        Emit (On_Event, Start_Event);

                        begin
                           LLM.Tools.Execute
                             (Name      => To_String
                                (Tool_Block.Tool_Name),
                              Args_Json => To_String
                                (Tool_Block.Arguments_Json),
                              Result    => Result_Text,
                              Is_Error  => Is_Error);
                        exception
                           when Ex : others =>
                              Result_Text := To_Unbounded_String
                                (Ada.Exceptions.Exception_Message (Ex));
                              Is_Error := True;
                        end;

                        declare
                           End_Event : constant
                             LLM.Events.Tool_Execution_End_Event :=
                               (LLM.Events.Agent_Event with
                                Tool_Call_Id => Tool_Block.Tool_Call_Id,
                                Tool_Name    => Tool_Block.Tool_Name,
                                Result_Text  => Result_Text,
                                Is_Error     => Is_Error);
                        begin
                           Emit (On_Event, End_Event);
                        end;

                        Tool_Messages.Append
                          (Tool_Result_Message
                             (Tool_Call_Id => To_String
                                (Tool_Block.Tool_Call_Id),
                              Result_Text  => To_String (Result_Text),
                              Is_Error     => Is_Error));
                        Next_Index := Next_Index + 1;
                     end;
                  end loop;

                  if S.Abort_State.Requested then
                     while Next_Index <= Pending_Tools.Last_Index loop
                        declare
                           Tool_Block : constant Pending_Tool :=
                             Pending_Tools.Element (Next_Index);
                        begin
                           Tool_Messages.Append
                             (Tool_Result_Message
                                (Tool_Call_Id => To_String
                                   (Tool_Block.Tool_Call_Id),
                                 Result_Text  => "Aborted",
                                 Is_Error     => True));
                           Next_Index := Next_Index + 1;
                        end;
                     end loop;
                  end if;

                  Append_Pending_Message (Reply);
                  Append_Pending_Batch (Tool_Messages);
               end;

               exit Agentic_Loop when S.Abort_State.Requested;
            else
               exit Agentic_Loop when S.Abort_State.Requested;

               if Has_Assistant_Message (Builder) then
                  declare
                     Reply : constant LLM.Types.Message :=
                       Assistant_Message (Builder);
                  begin
                     Append_Pending_Message (Reply);
                     Turn_Completed_Normally :=
                       Reply.Stop = LLM.Types.Stop
                       or else Reply.Stop = LLM.Types.Length;
                  end;
               end if;

               exit Agentic_Loop;
            end if;
         end loop Agentic_Loop;

         if not S.Abort_State.Requested and then Turn_Completed_Normally then
            Flush_Pending_Messages;
         end if;
      exception
         when others =>
            Was_Aborted := S.Abort_State.Requested;
            S.Streaming := False;
            declare
               End_Event : constant LLM.Events.Agent_End_Event :=
                 (LLM.Events.Agent_Event with Was_Aborted => Was_Aborted);
            begin
               Emit (On_Event, End_Event);
            end;
            S.Abort_State.Clear;
            raise;
      end;

      Was_Aborted := S.Abort_State.Requested;
      S.Streaming := False;
      declare
         End_Event : constant LLM.Events.Agent_End_Event :=
           (LLM.Events.Agent_Event with Was_Aborted => Was_Aborted);
      begin
         Emit (On_Event, End_Event);
      end;
      Emit (On_Event, Session_Stats (S));
      S.Abort_State.Clear;
   end Run_Prompt;

   procedure Request_Abort (S : in out Session) is
   begin
      S.Abort_State.Set;
   end Request_Abort;

   procedure New_Session (S : in out Session) is
   begin
      S.History.Clear;
      S.Session_UUID := To_Unbounded_String
        (LLM.Session_Store.Create_Session (To_String (S.Cwd)));
      S.Abort_State.Clear;
      S.Streaming := False;
   end New_Session;

   procedure Switch_Session (S : in out Session; UUID : String) is
   begin
      if LLM.Session_Store.Session_File_Path (UUID)'Length = 0 then
         raise LLM.Session_Store.Session_Error with
           "Session not found: " & UUID;
      end if;

      S.Session_UUID := To_Unbounded_String (UUID);
      S.History := LLM.Session_Store.Load_Messages (UUID);
      S.Abort_State.Clear;
      S.Streaming := False;
   end Switch_Session;

   procedure Set_Model (S : in out Session; Spec : String) is
   begin
      Set_Model_Internal (S, Spec);
   end Set_Model;

   procedure Set_Thinking
     (S     : in out Session;
      Level :        LLM.Providers.Thinking_Level) is
   begin
      S.Thinking := Level;
   end Set_Thinking;

   function Session_Id (S : Session) return String is
   begin
      return To_String (S.Session_UUID);
   end Session_Id;

   function Current_Model_Spec (S : Session) return String is
   begin
      return To_String (S.Model_Spec);
   end Current_Model_Spec;

   function Context_Window (S : Session) return Natural is
   begin
      return S.Model_Info.Context_Window;
   end Context_Window;

   function Is_Streaming (S : Session) return Boolean is
   begin
      return S.Streaming;
   end Is_Streaming;

end LLM.Agent;
