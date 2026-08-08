--  LLM.Agent body.
--
--  Project: coyote
--  For revision history, see the project version-control log.
with Ada.Characters.Handling;
with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Compaction;
with LLM.Memory;
with LLM.HTTP;
with LLM.Model_Registry;
with LLM.Providers.Anthropic_Messages;
with LLM.Providers.GitHub_Copilot;
with LLM.Providers.OpenCode_Go;
with LLM.Providers.OpenRouter;
with LLM.Session_Store;
with LLM.Providers.OpenAI_Completions;
with LLM.Settings;
with LLM.System_Prompt;
with LLM.Tools;
with LLM.Tools.Shell;
with LLM.Tools.Temp_File;
package body LLM.Agent is

   use type Ada.Containers.Count_Type;
   use type LLM.Events.Message_Update_Kind;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;
   use type LLM.Types.Stop_Reason;
   use type LLM.Types.Usage;
   use type GNATCOLL.JSON.JSON_Value_Type;

   type Pending_Tool is record
      Tool_Call_Id   : Unbounded_String;
      Tool_Name      : Unbounded_String;
      Arguments_Json : Unbounded_String;
      Run_Group      : Natural := 0;
   end record;

   package Pending_Tool_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Pending_Tool);

   --  Extract the optional integer "run_group" from a tool call's JSON
   --  arguments.  Returns 0 when absent, non-integer, or after the JSON
   --  has been stripped (meaning "no group").
   function Extract_Run_Group (Args_Json : String) return Natural;

   --  Parse Args_Json, remove the "run_group" field if present, and
   --  return the cleaned JSON.  Returns the original string unchanged
   --  when the field is absent or the JSON is invalid.
   function Strip_Run_Group (Args_Json : String) return String;

   --  Result of one executed tool call, stored by a Worker_Task.
   type Tool_Result_Slot is record
      Result_Text : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Media_Type  : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      Is_Error    : Boolean := False;
   end record;

   type Tool_Result_Slot_Array is array (Positive range <>) of
     Tool_Result_Slot;

   --  Fork-join barrier.  Each worker calls Set once; the main task calls
   --  Wait_All to block until every slot is filled.
   protected type Results_Store (Count : Positive) is
      procedure Set
        (Index      : Positive;
         Result     : Ada.Strings.Unbounded.Unbounded_String;
         Media_Type : Ada.Strings.Unbounded.Unbounded_String;
         Is_Error   : Boolean);
      entry Wait_All;
      function Get (Index : Positive) return Tool_Result_Slot;
   private
      Slots      : Tool_Result_Slot_Array (1 .. Count);
      Done_Count : Natural := 0;
   end Results_Store;
   --  Executes one tool call and stores the result in a Results_Store.
   --  Workers never call On_Event or touch any Nine_P.Client.Fs.
   task type Worker_Task
     (Store           : not null access Results_Store;
      Abort_Flg       : access LLM.Tools.Abort_Flag;
      Context_Window  : Natural;
      Sandbox_Profile : access constant
        Ada.Strings.Unbounded.Unbounded_String)
   is
      entry Start
        (Index : Positive;
         Tool  : Pending_Tool);
   end Worker_Task;

   protected body Results_Store is

      procedure Set
        (Index      : Positive;
         Result     : Ada.Strings.Unbounded.Unbounded_String;
         Media_Type : Ada.Strings.Unbounded.Unbounded_String;
         Is_Error   : Boolean)
      is
      begin
         Slots (Index) :=
           (Result_Text => Result,
            Media_Type  => Media_Type,
            Is_Error    => Is_Error);
         Done_Count := Done_Count + 1;
      end Set;

      entry Wait_All when Done_Count = Count is
      begin
         null;
      end Wait_All;

      function Get (Index : Positive) return Tool_Result_Slot is
      begin
         return Slots (Index);
      end Get;

   end Results_Store;

   task body Worker_Task is
      My_Index   : Positive;
      My_Tool    : Pending_Tool;
      Result     : Ada.Strings.Unbounded.Unbounded_String;
      Media_Type : Ada.Strings.Unbounded.Unbounded_String;
      Is_Error   : Boolean := False;
   begin
      accept Start
        (Index : Positive;
         Tool  : Pending_Tool)
      do
         My_Index := Index;
         My_Tool  := Tool;
      end Start;

      begin
         if Ada.Strings.Unbounded.To_String (My_Tool.Tool_Name) = "shell"
         then
            LLM.Tools.Shell.Execute
              (Args_Json       => Ada.Strings.Unbounded.To_String
                                    (My_Tool.Arguments_Json),
               Result          => Result,
               Media_Type      => Media_Type,
               Is_Error        => Is_Error,
               Abort_Flg       => Abort_Flg,
               Sandbox_Profile => Ada.Strings.Unbounded.To_String
                                    (Sandbox_Profile.all));

            --  Apply the result-size cap to plain-text results.  Image
            --  results (Media_Type non-empty) are base64-encoded binary and
            --  must not be truncated.
            if Ada.Strings.Unbounded.Length (Media_Type) = 0 then
               Result := Ada.Strings.Unbounded.To_Unbounded_String
                 (LLM.Tools.Temp_File.Truncated
                    (Ada.Strings.Unbounded.To_String (Result),
                     Threshold => LLM.Tools.Temp_File.Result_Threshold
                                    (Context_Window),
                     Tool_Name => Ada.Strings.Unbounded.To_String
                                    (My_Tool.Tool_Name)));
            end if;
         else
            --  The model called a tool name that is not registered.
            Result :=
              Ada.Strings.Unbounded.To_Unbounded_String
                ("unknown tool: "
                 & Ada.Strings.Unbounded.To_String (My_Tool.Tool_Name));
            Media_Type := Ada.Strings.Unbounded.Null_Unbounded_String;
            Is_Error   := True;
         end if;
      exception
         when Ex : others =>
            Result     := Ada.Strings.Unbounded.To_Unbounded_String
              (Ada.Exceptions.Exception_Message (Ex));
            Media_Type := Ada.Strings.Unbounded.Null_Unbounded_String;
            Is_Error   := True;
      end;

      Store.Set (My_Index, Result, Media_Type, Is_Error);
   end Worker_Task;

   type Open_Block_Kind is (No_Open_Block, Open_Text, Open_Thinking);

   type Assistant_Builder is record
      Content      : LLM.Types.Content_Block_Vectors.Vector;
      Open_Kind    : Open_Block_Kind := No_Open_Block;
      Open_Text    : Unbounded_String;
      Open_Sig     : Unbounded_String;
      Stop         : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Tok_Usage    : LLM.Types.Usage := (others => 0);
      Error_Text   : Unbounded_String;
      Saw_Content  : Boolean := False;
      Saw_Msg_End  : Boolean := False;
   end record;

   procedure Emit
     (Handler : not null access procedure
        (E : LLM.Events.Agent_Event'Class);
      Event   : LLM.Events.Agent_Event'Class) is
   begin
      Handler.all (Event);
   end Emit;

   function Extract_Run_Group (Args_Json : String) return Natural is
      Max_Group : constant := 2**30;
   begin
      if Args_Json'Length = 0 then
         return 0;
      end if;

      declare
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Args_Json);
      begin
         if not Parsed.Success
           or else Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
         then
            return 0;
         end if;

         if not Parsed.Value.Has_Field ("run_group") then
            return 0;
         end if;

         declare
            Field : constant GNATCOLL.JSON.JSON_Value :=
              Parsed.Value.Get ("run_group");
         begin
            if Field.Kind /= GNATCOLL.JSON.JSON_Int_Type then
               return 0;
            end if;

            declare
               Value : constant Long_Integer := Field.Get;
            begin
               if Value < 1
                 or else Value > Long_Integer (Max_Group)
               then
                  return 0;
               else
                  return Natural (Value);
               end if;
            end;
         end;
      end;
   end Extract_Run_Group;

   function Strip_Run_Group (Args_Json : String) return String is
   begin
      if Args_Json'Length = 0 then
         return Args_Json;
      end if;

      declare
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Args_Json);
      begin
         if not Parsed.Success
           or else Parsed.Value.Kind /= GNATCOLL.JSON.JSON_Object_Type
         then
            return Args_Json;
         end if;

         if not Parsed.Value.Has_Field ("run_group") then
            return Args_Json;
         end if;

         declare
            Clean : constant GNATCOLL.JSON.JSON_Value := Parsed.Value;
         begin
            Clean.Unset_Field ("run_group");
            return GNATCOLL.JSON.Write (Clean);
         end;
      end;
   end Strip_Run_Group;

   function Lowercase (Text : String) return String is
   begin
      return Ada.Characters.Handling.To_Lower (Text);
   end Lowercase;

   function Is_Context_Overflow_Error (Msg : String) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Msg);
   begin
      return Ada.Strings.Fixed.Index (Lower, "prompt is too long") > 0
        or else Ada.Strings.Fixed.Index
          (Lower, "context_length_exceeded") > 0
        or else Ada.Strings.Fixed.Index
          (Lower, "maximum context length") > 0
        or else Ada.Strings.Fixed.Index (Lower, "too many tokens") > 0
        or else Ada.Strings.Fixed.Index
          (Lower, "reduce the length of the messages") > 0;
   end Is_Context_Overflow_Error;

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

   function Effective_Model_Spec
     (Requested : String;
      Subagent  : Boolean := False) return String
   is
      Settings_Value : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;
      Available      : constant LLM.Model_Registry.Model_Info_Vectors.Vector :=
        LLM.Model_Registry.Available_Models;
   begin
      if Requested'Length > 0 then
         return Requested;
      end if;

      if Subagent
        and then Length (Settings_Value.Default_Subagent_Provider) > 0
        and then Length (Settings_Value.Default_Subagent_Model) > 0
      then
         return To_String (Settings_Value.Default_Subagent_Provider)
           & "/"
           & To_String (Settings_Value.Default_Subagent_Model);
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
        "No model configured; pass --model or set ~/.coyote/settings.json";
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
      if Builder.Open_Kind = Open_Text
         and then Builder.Open_Text /= Null_Unbounded_String
      then
         Builder.Content.Append
           ((Kind => LLM.Types.Text_Block,
             Text => Builder.Open_Text));
         Builder.Saw_Content := True;
      elsif Builder.Open_Kind = Open_Thinking then
         Builder.Content.Append
           ((Kind      => LLM.Types.Thinking_Block,
             Thinking  => Builder.Open_Text,
             Signature => Builder.Open_Sig));
         Builder.Saw_Content := True;
      end if;

      Builder.Open_Kind := No_Open_Block;
      Builder.Open_Text := Null_Unbounded_String;
      Builder.Open_Sig  := Null_Unbounded_String;
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
            Builder.Open_Sig := Event.Signature;
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
      Is_Error     : Boolean;
      Media_Type   : String := "") return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind        => LLM.Types.Tool_Result_Block,
          Result_Id   => To_Unbounded_String (Tool_Call_Id),
          Result_Text => To_Unbounded_String (Result_Text),
          Is_Error    => Is_Error,
          Media_Type  => To_Unbounded_String (Media_Type)));

      return
        (Role      => LLM.Types.Tool_Result,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Null_Unbounded_String);
   end Tool_Result_Message;

   function Message_Text (Msg : LLM.Types.Message) return String is
      Result : Unbounded_String;
   begin
      for Block of Msg.Content loop
         if Block.Kind = LLM.Types.Text_Block then
            Append (Result, To_String (Block.Text));
            exit;
         end if;
      end loop;

      return To_String (Result);
   end Message_Text;

   function Compaction_Summary_Message
     (Summary : String) return LLM.Types.Message
   is
      Content : LLM.Types.Content_Block_Vectors.Vector;
   begin
      Content.Append
        ((Kind => LLM.Types.Text_Block,
          Text => To_Unbounded_String (Summary)));

      return
        (Role      => LLM.Types.Compaction_Summary,
         Content   => Content,
         Tok_Usage => (others => 0),
         Stop      => LLM.Types.Unknown_Stop,
         Timestamp => Null_Unbounded_String);
   end Compaction_Summary_Message;

   function Build_Tools_Json
     (Info     : LLM.Model_Registry.Model_Info;
      No_Tools : Boolean) return String
   is
      Tools : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      if No_Tools or else not Info.Supports_Tools then
         return "[]";
      end if;

      declare
         Descriptor : constant LLM.Tools.Tool_Descriptor :=
           LLM.Tools.Shell.Descriptor;
      begin
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
               Tool_Object.Set_Field
                 ("input_schema", Descriptor.Schema_Json);
               GNATCOLL.JSON.Append (Tools, Tool_Object);
            end;
         else
            declare
               Tool_Object     : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Create_Object;
               Function_Object : constant GNATCOLL.JSON.JSON_Value :=
                 GNATCOLL.JSON.Create_Object;
            begin
               Function_Object.Set_Field
                 ("name", To_String (Descriptor.Name));
               Function_Object.Set_Field
                 ("description", To_String (Descriptor.Description));
               Function_Object.Set_Field
                 ("parameters", Descriptor.Schema_Json);
               Tool_Object.Set_Field ("type", "function");
               Tool_Object.Set_Field ("function", Function_Object);
               GNATCOLL.JSON.Append (Tools, Tool_Object);
            end;
         end if;
      end;

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

   procedure Remove_Trailing_Error_Message
     (History : in out LLM.Types.Message_Vectors.Vector)
   is
   begin
      if not History.Is_Empty then
         declare
            Last_Message : constant LLM.Types.Message :=
              History.Last_Element;
         begin
            if Last_Message.Stop = LLM.Types.Error_Stop
              or else Last_Message.Stop = LLM.Types.Aborted
            then
               History.Delete_Last;
            end if;
         end;
      end if;
   end Remove_Trailing_Error_Message;

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

   --  Natural'Image without the leading space.
   function Natural_Image (N : Natural) return String is
      Img : constant String := Natural'Image (N);
   begin
      return Img (Img'First + 1 .. Img'Last);
   end Natural_Image;

   --  Format a Long_Float with at most two decimal places, trailing zeros
   --  stripped.  Only used internally for SI-prefixed token counts and
   --  cost strings.
   function Format_Compact (V : Long_Float) return String is
      Total     : constant Natural :=
        Natural (Long_Float'Rounding (V * 100.0));
      Int_Part  : constant Natural  := Total / 100;
      Frac_Part : constant Natural  := Total mod 100;
      D1        : constant Character :=
        Character'Val (Character'Pos ('0') + Frac_Part / 10);
      D2        : constant Character :=
        Character'Val (Character'Pos ('0') + Frac_Part mod 10);
   begin
      if Frac_Part = 0 then
         return Natural_Image (Int_Part);
      elsif Frac_Part mod 10 = 0 then
         return Natural_Image (Int_Part) & "." & (1 => D1);
      else
         return Natural_Image (Int_Part) & "." & (D1 & D2);
      end if;
   end Format_Compact;

   --  Format a token count with an SI prefix (k / M / G).
   function Token_Image (N : Natural) return String is
      V : constant Long_Float := Long_Float (N);
   begin
      if N >= 1_000_000_000 then
         return Format_Compact (V / 1_000_000_000.0) & "G";
      elsif N >= 1_000_000 then
         return Format_Compact (V / 1_000_000.0) & "M";
      elsif N >= 1_000 then
         return Format_Compact (V / 1_000.0) & "k";
      else
         return Natural_Image (N);
      end if;
   end Token_Image;

   --  Format a cost in deci-milli-dollar units as "$X.YYYY".
   function Cost_Image (Dmil : Natural) return String is

      function Pad4 (N : Natural) return String is
         Buf : String (1 .. 4) := "0000";
         V   : Natural         := N;
      begin
         Buf (4) := Character'Val (Character'Pos ('0') + V mod 10);
         V       := V / 10;
         Buf (3) := Character'Val (Character'Pos ('0') + V mod 10);
         V       := V / 10;
         Buf (2) := Character'Val (Character'Pos ('0') + V mod 10);
         V       := V / 10;
         Buf (1) := Character'Val (Character'Pos ('0') + V mod 10);
         return Buf;
      end Pad4;

   begin
      return "$"
        & Natural_Image (Dmil / 10_000)
        & "."
        & Pad4 (Dmil mod 10_000);
   end Cost_Image;

   function Usage_Cost_Dollars
     (Tok_Usage : LLM.Types.Usage;
      Rates     : LLM.Types.Model_Cost) return Long_Float
   is
   begin
      return Long_Float (Tok_Usage.Input - Tok_Usage.Cache_Read - Tok_Usage.Cache_Write)
        * Rates.Input / 1_000_000.0
        + Long_Float (Tok_Usage.Output)
        * Rates.Output / 1_000_000.0
        + Long_Float (Tok_Usage.Cache_Read)
        * Rates.Cache_Read / 1_000_000.0
        + Long_Float (Tok_Usage.Cache_Write) * Rates.Cache_Write / 1_000_000.0;
   end Usage_Cost_Dollars;

   function Usage_Cost_Dmil
     (Tok_Usage : LLM.Types.Usage;
      Rates     : LLM.Types.Model_Cost) return Natural
   is
      Cost : constant Long_Float := Usage_Cost_Dollars (Tok_Usage, Rates);
   begin
      return Natural (Long_Float'Floor (Cost * 10_000.0 + 0.5));
   end Usage_Cost_Dmil;

   --  Build the [coyote: ...] stats footer appended to the last tool result
   --  in each batch so the model can track context consumption and cost.
   --
   --  Turn_Usage is the Tok_Usage from the most recent Message_End_Event.
   --  S.History is the in-memory transcript before the current assistant
   --  message has been appended.  Turn_Usage is included in the session
   --  totals explicitly so the model sees the up-to-date running sums.
   --
   --  Returns "" when Turn_Usage is all zeros (no token data available).
   --  The cost segment is omitted when the active model has no pricing.
   function Format_Session_Cost_Footer
     (S          : Session;
      Turn_Usage : LLM.Types.Usage) return String
   is
      Turn_Input  : constant Natural :=
        Turn_Usage.Input
        + Turn_Usage.Cache_Read
        + Turn_Usage.Cache_Write;
      Turn_Output : constant Natural := Turn_Usage.Output;
      Sess_Input  : Natural          := Turn_Input;
      Sess_Output : Natural          := Turn_Output;
      Sess_Cost   : Long_Float       := 0.0;
      Has_Cost    : constant Boolean :=
        S.Model_Info.Cost.Input > 0.0
        or else S.Model_Info.Cost.Output > 0.0;
      Footer      : Unbounded_String;
   begin
      if Turn_Input = 0 and then Turn_Output = 0 then
         return "";
      end if;

      --  Accumulate session-wide totals from history.  The current turn's
      --  assistant message has not yet been appended to S.History at the
      --  call site, so Turn_Usage is added to the running sums above.
      for Msg of S.History loop
         Sess_Input  :=
           Sess_Input
           + Msg.Tok_Usage.Input
           + Msg.Tok_Usage.Cache_Read
           + Msg.Tok_Usage.Cache_Write;
         Sess_Output := Sess_Output + Msg.Tok_Usage.Output;
         if Msg.Role = LLM.Types.Assistant then
            Sess_Cost :=
              Sess_Cost
              + Usage_Cost_Dollars (Msg.Tok_Usage, S.Model_Info.Cost);
         end if;
      end loop;

      if Has_Cost then
         Sess_Cost :=
           Sess_Cost + Usage_Cost_Dollars (Turn_Usage, S.Model_Info.Cost);
      end if;

      Append (Footer, "[coyote: turn=");
      Append (Footer, Token_Image (Turn_Input) & "in/");
      Append (Footer, Token_Image (Turn_Output) & "out");
      Append (Footer, " session=");
      Append (Footer, Token_Image (Sess_Input) & "in/");
      Append (Footer, Token_Image (Sess_Output) & "out");
      if Has_Cost then
         declare
            Cost_Dmil : constant Natural :=
              Natural (Long_Float'Floor (Sess_Cost * 10_000.0 + 0.5));
         begin
            Append (Footer, " cost~" & Cost_Image (Cost_Dmil));
         end;
      end if;
      Append (Footer, "]");
      return To_String (Footer);
   end Format_Session_Cost_Footer;

   function Session_Stats
     (S : Session) return LLM.Events.Session_Stats_Event
   is
      Totals     : LLM.Types.Usage := (others => 0);
      Total_Cost : Long_Float      := 0.0;
   begin
      for Msg of S.History loop
         Totals := Totals + Msg.Tok_Usage;
         if Msg.Role = LLM.Types.Assistant then
            Total_Cost :=
              Total_Cost
              + Usage_Cost_Dollars (Msg.Tok_Usage, S.Model_Info.Cost);
         end if;
      end loop;

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
      Overflow_Recovery_Attempted : Boolean := False;
      Compact_OK : Boolean := False;

      procedure Reset_Attempt_State is
      begin
         Builder :=
           (Content      => <>,
            Open_Kind    => No_Open_Block,
            Open_Text    => Null_Unbounded_String,
            Open_Sig     => Null_Unbounded_String,
            Stop         => LLM.Types.Unknown_Stop,
            Tok_Usage    => (others => 0),
            Error_Text   => Null_Unbounded_String,
            Saw_Content  => False,
            Saw_Msg_End  => False);
         Pending_Tools.Clear;
      end Reset_Attempt_State;

      procedure Provider_Event_Handler (E : LLM.Events.Agent_Event'Class) is
      begin
         --  If the user clicked Stop, abort the HTTP stream immediately.
         --  Raising here causes Ada_Write_Callback to return 0 bytes to
         --  libcurl, which terminates curl_easy_perform right now rather
         --  than waiting for the full model response to arrive.
         if S.Abort_State.Requested then
            raise LLM.HTTP.Curl_Error with "aborted";
         end if;
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
                  declare
                     Args_Json : constant String :=
                       To_String (Update.Delta_Text);
                     Group     : constant Natural :=
                       Extract_Run_Group (Args_Json);
                     Cleaned   : constant String :=
                       (if Group > 0
                        then Strip_Run_Group (Args_Json)
                        else Args_Json);
                  begin
                     Pending_Tools.Append
                       ((Tool_Call_Id   => Update.Tool_Call_Id,
                         Tool_Name      => Update.Tool_Name,
                         Arguments_Json =>
                           To_Unbounded_String (Cleaned),
                         Run_Group      => Group));
                  end;
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
         declare
            Retry_Same_Attempt : Boolean := True;
         begin
            Provider_Call_Loop :
            while Retry_Same_Attempt loop
               Retry_Same_Attempt := False;

               begin
                  Provider.Send
                    (Model_Id      => To_String (S.Model_Info.Model_Id),
                     System_Prompt => To_String (S.System_Prompt),
                     Messages      => S.History,
                     Tools_Json    => Tools_Json,
                     Thinking      => S.Thinking,
                     Max_Tokens    => Max_Tokens_For (S.Model_Info),
                     Handler =>
                       Provider_Event_Handler'Unrestricted_Access);

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
                     elsif Is_Context_Overflow_Error
                       (Ada.Exceptions.Exception_Message (Occurrence))
                     then
                        if Overflow_Recovery_Attempted then
                           declare
                              Event : constant
                                LLM.Events.Auto_Compaction_End_Event :=
                                  (LLM.Events.Agent_Event with
                                   Summary    => Null_Unbounded_String,
                                   Aborted    => True,
                                   Will_Retry => False,
                                   Err_Msg    => To_Unbounded_String
                                     ("Context overflow recovery failed"
                                      & " after one attempt."));
                           begin
                              Emit (On_Event, Event);
                           end;
                           exit Attempt_Loop;
                        end if;

                        Overflow_Recovery_Attempted := True;
                        Reset_Attempt_State;
                        Remove_Trailing_Error_Message (S.History);
                        Compact (S, On_Event, "overflow", Compact_OK);

                        if S.Abort_State.Requested then
                           exit Attempt_Loop;
                        end if;
                        if not Compact_OK then
                           exit Attempt_Loop;
                        end if;

                        declare
                           Event : constant
                             LLM.Events.Auto_Compaction_End_Event :=
                               (LLM.Events.Agent_Event with
                                Summary    => Null_Unbounded_String,
                                Aborted    => False,
                                Will_Retry => True,
                                Err_Msg    => Null_Unbounded_String);
                        begin
                           Emit (On_Event, Event);
                        end;

                        Retry_Same_Attempt := True;
                     elsif Is_Retryable_Error (Occurrence)
                       and then Attempt <= Delays_Ms'Last
                     then
                        Retry_Used := True;
                        declare
                           Delay_Ms : constant Natural := Delays_Ms (Attempt);
                           Event : constant
                             LLM.Events.Auto_Retry_Start_Event :=
                               (LLM.Events.Agent_Event with
                              Attempt      => Attempt,
                              Max_Attempts => Delays_Ms'Last + 1,
                              Delay_Ms     => Delay_Ms,
                              Error_Msg    => To_Unbounded_String
                                (Ada.Exceptions.Exception_Message
                                   (Occurrence)));
                           Was_Aborted : Boolean;
                        begin
                           Emit (On_Event, Event);
                           Delay_With_Abort (S, Delay_Ms, Was_Aborted);
                           if Was_Aborted then
                              exit Attempt_Loop;
                           end if;
                        end;
                     elsif Is_Retryable_Error (Occurrence)
                       and then Retry_Used
                     then
                        declare
                           Event : constant LLM.Events.Auto_Retry_End_Event :=
                             (LLM.Events.Agent_Event with
                              Success     => False,
                              Attempt     => Attempt,
                              Final_Error => To_Unbounded_String
                                (Ada.Exceptions.Exception_Message
                                   (Occurrence)));
                        begin
                           Emit (On_Event, Event);
                        end;
                        Ada.Text_IO.Put_Line
                          (Ada.Text_IO.Standard_Error,
                           "[!] agent error (retry exhausted): "
                           & Ada.Exceptions.Exception_Message (Occurrence));
                        raise;
                     else
                        Ada.Text_IO.Put_Line
                          (Ada.Text_IO.Standard_Error,
                           "[!] agent error (non-retryable): "
                           & Ada.Exceptions.Exception_Message (Occurrence));
                        raise;
                     end if;
               end;
            end loop Provider_Call_Loop;
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
      Agent         :        String  := "";
      No_Tools      :        Boolean := False;
      Session_Id    :        String  := "";
      Subagent      :        Boolean := False)
   is
      Effective_Spec : constant String :=
        Effective_Model_Spec (Model_Spec, Subagent);
      Settings_Value : constant LLM.Settings.Settings :=
        LLM.Settings.Load_Settings;
   begin
      S.Model_Spec := Null_Unbounded_String;

      --  Determine the working directory.  When resuming an existing session,
      --  restore the directory recorded in the session header so that the
      --  system prompt and all tool calls operate in the original project
      --  tree.  Fall back to the process CWD when the saved path is absent
      --  or no longer exists.
      S.Cwd := To_Unbounded_String (Ada.Directories.Current_Directory);

      if Session_Id'Length > 0 then
         declare
            Saved_Dir : constant String :=
              LLM.Session_Store.Session_Work_Dir (Session_Id);
         begin
            if Saved_Dir'Length > 0
              and then Ada.Directories.Exists (Saved_Dir)
            then
               Ada.Directories.Set_Directory (Saved_Dir);
               S.Cwd := To_Unbounded_String (Saved_Dir);
            end if;
         end;
      end if;

      S.System_Prompt := To_Unbounded_String
        (LLM.System_Prompt.Build_System_Prompt
           (Cwd               => To_String (S.Cwd),
            No_Tools          => No_Tools,
            Has_Editing_Tools => not No_Tools,
            Agent             => Agent,
            Memory_Block      =>
              (if Ada.Environment_Variables.Value
                    ("COYOTE_ENABLE_MEMORY", "0") = "1"
               then LLM.Memory.Load_Memory_Index (To_String (S.Cwd))
                    & ASCII.LF
                    & LLM.Memory.Format_Memory_Taxonomy_For_Prompt
               else ""),
            Coordinator_Mode  => not No_Tools));
      S.Session_UUID := Null_Unbounded_String;
      S.History.Clear;
      S.No_Tools := No_Tools;
      S.Thinking := Thinking_From_String
        (To_String (Settings_Value.Default_Thinking));
      S.Sandbox_Profile :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (To_String (Settings_Value.Default_Sandbox));
      --  Inherit sandbox profile from parent subagent process.
      declare
         Inherited : constant String :=
           Ada.Environment_Variables.Value
             ("COYOTE_SANDBOX_PROFILE", "");
      begin
         if Inherited'Length > 0 then
            S.Sandbox_Profile :=
              Ada.Strings.Unbounded.To_Unbounded_String (Inherited);
         end if;
      end;
      S.Abort_State.Clear;
      S.Streaming := False;
      S.Model_Info := EMPTY_MODEL_INFO;
      S.Compact_Settings := LLM.Compaction.Default_Compact_Settings;
      S.Last_Context_Tokens := 0;

      LLM.Model_Registry.Refresh_GitHub_Copilot;
      LLM.Model_Registry.Refresh_OpenRouter;
      LLM.Model_Registry.Refresh_Anthropic;
      LLM.Model_Registry.Refresh_OpenCode_Go;

      LLM.Model_Registry.Refresh_Ollama;
      Set_Model_Internal (S, Effective_Spec);

      if Session_Id'Length > 0 then
         if LLM.Session_Store.Session_File_Path (Session_Id)'Length = 0 then
            raise LLM.Session_Store.Session_Error with
              "Session not found: " & Session_Id;
         end if;

         S.Session_UUID := To_Unbounded_String (Session_Id);
         S.Sandbox_Profile :=
           Ada.Strings.Unbounded.To_Unbounded_String
             (LLM.Session_Store.Session_Sandbox_Profile (Session_Id));
         S.History := LLM.Session_Store.Load_Messages (Session_Id);
         S.Last_Context_Tokens :=
           LLM.Compaction.Estimate_Context_Tokens (S.History);
         S.Has_Submitted_Prompts := True;
      else
         S.Session_UUID := To_Unbounded_String
           (LLM.Session_Store.Create_Session (To_String (S.Cwd)));
         S.Has_Submitted_Prompts := False;
      end if;
   end Create;

   procedure Compact
     (S        : in out Session;
      On_Event :        not null access procedure
        (E : LLM.Events.Agent_Event'Class);
      Reason    :        String := "manual";
      Succeeded :    out Boolean)
   is
      Original_History : constant LLM.Types.Message_Vectors.Vector :=
        S.History;
      Original_Last_Context_Tokens : constant Natural :=
        S.Last_Context_Tokens;
      Cut              : Natural := 0;
      Previous_Summary : Unbounded_String := Null_Unbounded_String;
      Prompt_Text      : Unbounded_String := Null_Unbounded_String;
      Summary_Text     : Unbounded_String := Null_Unbounded_String;
      Summary_Request  : LLM.Types.Message_Vectors.Vector;
      Candidate        : LLM.Types.Message_Vectors.Vector;

      procedure Emit_End_Event
        (Summary    : Unbounded_String;
         Aborted    : Boolean;
         Err_Msg    : Unbounded_String)
      is
         Event : constant LLM.Events.Auto_Compaction_End_Event :=
           (LLM.Events.Agent_Event with
            Summary    => Summary,
            Aborted    => Aborted,
            Will_Retry => False,
            Err_Msg    => Err_Msg);
      begin
         Emit (On_Event, Event);
      end Emit_End_Event;

      procedure Summary_Event_Handler
        (E : LLM.Events.Agent_Event'Class)
      is
      begin
         if S.Abort_State.Requested then
            return;
         end if;

         if E in LLM.Events.Message_Update_Event then
            declare
               Update : constant LLM.Events.Message_Update_Event :=
                 LLM.Events.Message_Update_Event (E);
            begin
               if Update.Kind = LLM.Events.Text_Delta then
                  Append (Summary_Text, To_String (Update.Delta_Text));
               end if;
            end;
         end if;
      end Summary_Event_Handler;

      function Summary_Max_Tokens return Positive is
         Raw : constant Natural :=
           (Natural (S.Compact_Settings.Reserve_Tokens) * 4) / 5;
      begin
         if Raw = 0 then
            return 1;
         else
            return Positive (Raw);
         end if;
      end Summary_Max_Tokens;
   begin
      Succeeded := False;
      declare
         Event : constant LLM.Events.Auto_Compaction_Start_Event :=
           (LLM.Events.Agent_Event with
            Reason => To_Unbounded_String (Reason));
      begin
         Emit (On_Event, Event);
      end;

      Cut := LLM.Compaction.Find_Cut_Point
        (S.History, S.Compact_Settings);
      if Cut = 0 and then S.History.Length <= 1 then
         Emit_End_Event
           (Summary => Null_Unbounded_String,
            Aborted => True,
            Err_Msg => To_Unbounded_String ("Nothing to compact"));
         return;
      end if;

      if not S.History.Is_Empty
        and then S.History.First_Element.Role = LLM.Types.Compaction_Summary
      then
         Previous_Summary := To_Unbounded_String
           (Message_Text (S.History.First_Element));
      end if;

      if Cut > 0 then
         for I in 0 .. Cut - 1 loop
            Candidate.Append (S.History.Element (I));
         end loop;
      end if;

      declare
         Serialized : constant String :=
           LLM.Compaction.Serialize_Conversation (Candidate);
      begin
         Prompt_Text := To_Unbounded_String
           (LLM.Compaction.Build_Compact_Prompt
              (Conversation     => Serialized,
               Previous_Summary =>
                 To_String (Previous_Summary),
               Is_Partial       => False));
      end;

      Summary_Request.Append (User_Message (To_String (Prompt_Text)));

      if Lowercase (To_String (S.Model_Info.Provider)) =
        "github-copilot"
      then
         declare
            Provider : LLM.Providers.GitHub_Copilot.Provider :=
              LLM.Providers.GitHub_Copilot.Create;
         begin
            Provider.Send
              (Model_Id      => To_String (S.Model_Info.Model_Id),
               System_Prompt => LLM.Compaction.Summarization_System_Prompt,
               Messages      => Summary_Request,
               Tools_Json    => "",
               Thinking      => LLM.Providers.Off,
               Max_Tokens    => Summary_Max_Tokens,
               Handler       => Summary_Event_Handler'Unrestricted_Access);
         end;
      elsif Lowercase (To_String (S.Model_Info.Provider)) = "openrouter" then
         declare
            Provider : LLM.Providers.OpenRouter.Provider :=
              LLM.Providers.OpenRouter.Create;
         begin
            Provider.Send
              (Model_Id      => To_String (S.Model_Info.Model_Id),
               System_Prompt => LLM.Compaction.Summarization_System_Prompt,
               Messages      => Summary_Request,
               Tools_Json    => "",
               Thinking      => LLM.Providers.Off,
               Max_Tokens    => Summary_Max_Tokens,
               Handler       => Summary_Event_Handler'Unrestricted_Access);
         end;
      elsif Lowercase (To_String (S.Model_Info.Provider)) = "anthropic" then
         declare
            Api_Key  : constant String :=
              LLM.Settings.Resolve_Api_Key ("anthropic");
            Provider : LLM.Providers.Anthropic_Messages.Provider :=
              LLM.Providers.Anthropic_Messages.Create
                ("https://api.anthropic.com", Api_Key);
         begin
            Provider.Send
              (Model_Id      => To_String (S.Model_Info.Model_Id),
               System_Prompt => LLM.Compaction.Summarization_System_Prompt,
               Messages      => Summary_Request,
               Tools_Json    => "",
               Thinking      => LLM.Providers.Off,
               Max_Tokens    => Summary_Max_Tokens,
               Handler       => Summary_Event_Handler'Unrestricted_Access);
         end;
      elsif Lowercase (To_String (S.Model_Info.Provider)) = "ollama" then
         declare
            Api_Key  : constant String :=
              LLM.Settings.Resolve_Api_Key ("ollama");
            Provider : LLM.Providers.OpenAI_Completions.Provider :=
              LLM.Providers.OpenAI_Completions.Create
                ("https://ollama.com/v1/", Api_Key);
         begin
            Provider.Send
              (Model_Id      => To_String (S.Model_Info.Model_Id),
               System_Prompt => LLM.Compaction.Summarization_System_Prompt,
               Messages      => Summary_Request,
               Tools_Json    => "",
               Thinking      => LLM.Providers.Off,
               Max_Tokens    => Summary_Max_Tokens,
               Handler       => Summary_Event_Handler'Unrestricted_Access);
         end;
      elsif Lowercase (To_String (S.Model_Info.Provider)) = "opencode-go" then
         declare
            Provider : LLM.Providers.OpenCode_Go.Provider :=
              LLM.Providers.OpenCode_Go.Create;
         begin
            Provider.Send
              (Model_Id      => To_String (S.Model_Info.Model_Id),
               System_Prompt => LLM.Compaction.Summarization_System_Prompt,
               Messages      => Summary_Request,
               Tools_Json    => "",
               Thinking      => LLM.Providers.Off,
               Max_Tokens    => Summary_Max_Tokens,
               Handler       => Summary_Event_Handler'Unrestricted_Access);
         end;
      else
         raise Constraint_Error with
           "Unsupported provider: " & To_String (S.Model_Info.Provider);
      end if;

      if S.Abort_State.Requested then
         Emit_End_Event
           (Summary => Null_Unbounded_String,
            Aborted => True,
            Err_Msg => Null_Unbounded_String);
         return;
      end if;

      if Length (Summary_Text) = 0 then
         Emit_End_Event
           (Summary => Null_Unbounded_String,
            Aborted => True,
            Err_Msg => To_Unbounded_String ("Empty summary returned"));
         return;
      end if;

      --  Strip the <analysis> drafting block from the summary before
      --  storing it in context (REQ-CORE-066).
      declare
         Stripped_Summary : constant String :=
           LLM.Compaction.Strip_Analysis_Block (To_String (Summary_Text));
         Tokens_Before : constant Natural :=
           (if S.Last_Context_Tokens > 0
            then S.Last_Context_Tokens
            else LLM.Compaction.Estimate_Context_Tokens (S.History));
      begin
         LLM.Session_Store.Append_Compaction
           (Session_Id       => To_String (S.Session_UUID),
            Summary          => Stripped_Summary,
            First_Kept_Index => Cut,
            Tokens_Before    => Tokens_Before);
      end;

      declare
         Stripped_Summary : constant String :=
           LLM.Compaction.Strip_Analysis_Block (To_String (Summary_Text));
         New_History : LLM.Types.Message_Vectors.Vector;
      begin
         New_History.Append
           (Compaction_Summary_Message (Stripped_Summary));

         if not S.History.Is_Empty and then Cut <= S.History.Last_Index then
            for I in Cut .. S.History.Last_Index loop
               New_History.Append (S.History.Element (I));
            end loop;
         end if;

         S.History := New_History;
      end;

      S.Last_Context_Tokens :=
        LLM.Compaction.Estimate_Context_Tokens (S.History);

      Succeeded := True;
      Emit_End_Event
        (Summary => Summary_Text,
         Aborted => False,
         Err_Msg => Null_Unbounded_String);
   exception
      when Occurrence : others =>
         S.History := Original_History;
         S.Last_Context_Tokens := Original_Last_Context_Tokens;
         Emit_End_Event
           (Summary => Null_Unbounded_String,
            Aborted => True,
            Err_Msg => To_Unbounded_String
              (Ada.Exceptions.Exception_Message (Occurrence)));
   end Compact;

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
      Prompt_With_Reminder : constant String :=
        Prompt
        & ASCII.LF
        & ASCII.LF
        & LLM.System_Prompt.Build_Reminder_Instructions
            (Has_Tools => not S.No_Tools);
      Prompt_Msg              : constant LLM.Types.Message :=
        User_Message (Prompt_With_Reminder);
      Was_Aborted             : Boolean := False;
      Turn_Completed_Normally : Boolean := False;
      Compact_OK              : Boolean := False;

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
      S.Has_Submitted_Prompts := True;
      Messages_To_Persist.Append (Prompt_Msg);
      LLM.Session_Store.Append_Model_Change
        (Session_Id => To_String (S.Session_UUID),
         Provider   => To_String (S.Model_Info.Provider),
         Model_Id   => To_String (S.Model_Info.Model_Id));

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
               Open_Sig     => Null_Unbounded_String,
               Stop         => LLM.Types.Unknown_Stop,
               Tok_Usage    => (others => 0),
               Error_Text   => Null_Unbounded_String,
               Saw_Content  => False,
               Saw_Msg_End  => False);
            Pending_Tools.Clear;

            if S.Abort_State.Requested then
               exit Agentic_Loop;
            end if;

            --  If a pause was armed, fire it now (at the turn boundary).
            --  Emit Agent_Paused_Event, block until Resume is called, then
            --  emit Agent_Resumed_Event.  A concurrent Stop clears both
            --  Armed and Paused via Request_Abort, so after unblocking we
            --  re-check the abort flag and exit when appropriate.
            S.Pause_State.Fire;
            if S.Pause_State.Is_Paused then
               Emit
                 (On_Event,
                  LLM.Events.Agent_Paused_Event'
                    (LLM.Events.Agent_Event with null record));
               S.Pause_State.Wait_If_Paused;
               exit Agentic_Loop when S.Abort_State.Requested;
               Emit
                 (On_Event,
                  LLM.Events.Agent_Resumed_Event'
                    (LLM.Events.Agent_Event with null record));
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
              "opencode-go"
            then
               declare
                  Provider : LLM.Providers.OpenCode_Go.Provider :=
                    LLM.Providers.OpenCode_Go.Create;
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
              "ollama"
            then
               declare
                  Api_Key  : constant String :=
                    LLM.Settings.Resolve_Api_Key ("ollama");
                  Provider : LLM.Providers.OpenAI_Completions.Provider :=
                    LLM.Providers.OpenAI_Completions.Create
                      ("https://ollama.com/v1/", Api_Key);
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
            --  When the user aborted during streaming and the response
            --  contains no tool calls, preserve the partial assistant
            --  message in the conversation history so the model sees
            --  how much work was done before the abort.
            --  (Tool-call responses are deferred: the partial assistant
            --  message alone would form an invalid transcript without
            --  matching tool-result messages, so we do not attempt to
            --  preserve those here.)
            if S.Abort_State.Requested then
               if Has_Assistant_Message (Builder)
                 and then Pending_Tools.Is_Empty
               then
                  declare
                     Raw   : constant LLM.Types.Message :=
                       Assistant_Message (Builder);
                     Reply : constant LLM.Types.Message :=
                       (Role      => Raw.Role,
                        Content   => Raw.Content,
                        Tok_Usage => Raw.Tok_Usage,
                        Stop      => LLM.Types.Aborted,
                        Timestamp => Raw.Timestamp);
                  begin
                     Append_Pending_Message (Reply);
                     Flush_Pending_Messages;
                     Messages_To_Persist.Clear;
                  end;
               end if;
               exit Agentic_Loop;
            end if;

            if not Pending_Tools.Is_Empty then
               declare
                  Reply         : constant LLM.Types.Message :=
                    Assistant_Message (Builder);
                  Tool_Messages : LLM.Types.Message_Vectors.Vector;
                  N             : constant Positive :=
                    Positive (Pending_Tools.Length);
                  type Worker_Access is access all Worker_Task;

                  --  Collect results in a persistent array so Phase 3
                  --  can read them regardless of execution strategy.
                  Results : Tool_Result_Slot_Array (1 .. N)
                    := (others => (others => <>));

                  --  True when every tool carries a valid run_group > 0.
                  All_Have_Groups : constant Boolean :=
                    (for all I in 1 .. N =>
                       Pending_Tools.Element (I - 1).Run_Group > 0);
               begin
                  if not Has_Assistant_Message (Builder) then
                     raise Constraint_Error with
                       "Tool batch missing assistant message";
                  end if;

                  --  Phase 1: emit Tool_Execution_Start_Event for every
                  --  tool (main task, sequential) before any worker is
                  --  spawned.
                  for I in Pending_Tools.First_Index
                    .. Pending_Tools.Last_Index
                  loop
                     declare
                        Tool_Block  : constant Pending_Tool :=
                          Pending_Tools.Element (I);
                        Start_Event : constant
                          LLM.Events.Tool_Execution_Start_Event :=
                            (LLM.Events.Agent_Event with
                             Tool_Call_Id => Tool_Block.Tool_Call_Id,
                             Tool_Name    => Tool_Block.Tool_Name,
                             Args_Json    => Tool_Block.Arguments_Json);
                     begin
                        Emit (On_Event, Start_Event);
                     end;
                  end loop;

                  if All_Have_Groups then
                     --  ── grouped execution ─────────────────────────
                     --  Collect unique group numbers, sort ascending.
                     declare
                        type Group_Map is array (1 .. N) of Natural;
                        Groups      : Group_Map := (others => 0);
                        Group_Count : Natural  := 0;

                        procedure Append_Group (Grp : Natural) is
                           Found : Boolean := False;
                        begin
                           for J in 1 .. Group_Count loop
                              if Groups (J) = Grp then
                                 Found := True;
                                 exit;
                              end if;
                           end loop;
                           if not Found then
                              Group_Count := Group_Count + 1;
                              Groups (Group_Count) := Grp;
                           end if;
                        end Append_Group;

                        procedure Sort_Groups is
                           Temp : Natural;
                        begin
                           for I in 1 .. Group_Count - 1 loop
                              for J in I + 1 .. Group_Count loop
                                 if Groups (I) > Groups (J) then
                                    Temp       := Groups (I);
                                    Groups (I) := Groups (J);
                                    Groups (J) := Temp;
                                 end if;
                              end loop;
                           end loop;
                        end Sort_Groups;

                     begin
                        for I in 1 .. N loop
                           Append_Group
                             (Pending_Tools.Element (I - 1).Run_Group);
                        end loop;
                        Sort_Groups;

                        for G in 1 .. Group_Count loop
                           exit when S.Abort_State.Requested;

                           declare
                              Group_Number : constant Natural :=
                                Groups (G);
                              Group_Size   : Natural := 0;
                              Slot_Map     : array (1 .. N)
                                of Natural := (others => 0);
                           begin
                              for I in 1 .. N loop
                                 if Pending_Tools.Element (I - 1)
                                   .Run_Group = Group_Number
                                 then
                                    Group_Size := Group_Size + 1;
                                    Slot_Map (Group_Size) := I;
                                 end if;
                              end loop;

                              declare
                                 Store   : aliased Results_Store
                                   (Count => Group_Size);
                                 Workers : array (1 .. Group_Size)
                                   of Worker_Access;
                              begin
                                 for W in 1 .. Group_Size loop
                                    Workers (W) := new Worker_Task
                                      (Store           =>
                                         Store'Unchecked_Access,
                                       Abort_Flg       =>
                                         S.Abort_State'Access,
                                       Context_Window  =>
                                         S.Model_Info
                                           .Context_Window,
                                       Sandbox_Profile =>
                                         S.Sandbox_Profile'Access);
                                    Workers (W).Start
                                      (Index => W,
                                       Tool  =>
                                         Pending_Tools.Element
                                           (Slot_Map (W) - 1));
                                 end loop;

                                 Store.Wait_All;

                                 for W in 1 .. Group_Size loop
                                    Results (Slot_Map (W)) :=
                                      Store.Get (W);
                                 end loop;
                              end;
                           end;
                        end loop;
                     end;

                  else
                     --  ── sequential execution ──────────────────────
                     for I in 1 .. N loop
                        exit when S.Abort_State.Requested;

                        declare
                           Store  : aliased Results_Store
                             (Count => 1);
                           Worker : Worker_Access;
                           Tool   : constant Pending_Tool :=
                             Pending_Tools.Element (I - 1);
                        begin
                           Worker := new Worker_Task
                             (Store           => Store'Unchecked_Access,
                              Abort_Flg       =>
                                S.Abort_State'Access,
                              Context_Window  =>
                                S.Model_Info.Context_Window,
                              Sandbox_Profile =>
                                S.Sandbox_Profile'Access);
                           Worker.Start
                             (Index => 1, Tool => Tool);
                           Store.Wait_All;
                           Results (I) := Store.Get (1);
                        end;
                     end loop;
                  end if;

                  --  Phase 3: emit Tool_Execution_End_Event for every
                  --  tool in the original call order, then build the
                  --  Tool_Messages batch.  The stats footer is appended
                  --  to the persisted result text of the last tool.
                  declare
                     Stats_Footer : constant String :=
                       Format_Session_Cost_Footer
                         (S, Builder.Tok_Usage);
                  begin
                     for I in 1 .. N loop
                        declare
                           Tool_Block  : constant Pending_Tool :=
                             Pending_Tools.Element (I - 1);
                           Slot        : constant
                             Tool_Result_Slot := Results (I);
                           End_Event   : constant
                             LLM.Events.Tool_Execution_End_Event :=
                               (LLM.Events.Agent_Event with
                                Tool_Call_Id =>
                                  Tool_Block.Tool_Call_Id,
                                Tool_Name    =>
                                  Tool_Block.Tool_Name,
                                Result_Text  =>
                                  Slot.Result_Text,
                                Is_Error     =>
                                  Slot.Is_Error,
                                Is_Cancelled =>
                                  S.Abort_State.Requested);
                           Stored_Text : constant String :=
                             Ada.Strings.Unbounded.To_String
                               (Slot.Result_Text)
                             & (if I = N
                                   and then Stats_Footer'Length > 0
                                   and then Ada.Strings.Unbounded.Length
                                              (Slot.Media_Type) = 0
                                then ASCII.LF & Stats_Footer
                                else "");
                        begin
                           Emit (On_Event, End_Event);
                           Tool_Messages.Append
                             (Tool_Result_Message
                                (Tool_Call_Id =>
                                   Ada.Strings.Unbounded.To_String
                                     (Tool_Block.Tool_Call_Id),
                                 Result_Text  => Stored_Text,
                                 Is_Error     => Slot.Is_Error,
                                 Media_Type   =>
                                   Ada.Strings.Unbounded.To_String
                                     (Slot.Media_Type)));
                        end;
                     end loop;
                  end;

                  Append_Pending_Message (Reply);
                  Append_Pending_Batch (Tool_Messages);
                  --  Persist tool results even when the user aborted,
                  --  so the partial conversation is recoverable.
                  Flush_Pending_Messages;
                  Messages_To_Persist.Clear;
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
            S.Last_Context_Tokens :=
              Builder.Tok_Usage.Input
              + Builder.Tok_Usage.Output
              + Builder.Tok_Usage.Cache_Read
              + Builder.Tok_Usage.Cache_Write;

            if not S.Abort_State.Requested
              and then LLM.Compaction.Should_Compact
                (S.Last_Context_Tokens,
                 S.Model_Info.Context_Window,
                 S.Compact_Settings)
            then
               Compact (S, On_Event, "threshold", Compact_OK);

               if Compact_OK then
                  S.Compact_Settings.Consecutive_Failures := 0;
               else
                  S.Compact_Settings.Consecutive_Failures :=
                    S.Compact_Settings.Consecutive_Failures + 1;

                  if S.Compact_Settings.Consecutive_Failures
                    >= LLM.Compaction.Max_Consecutive_Failures
                  then
                     S.Compact_Settings.Tripped := True;
                  end if;
               end if;
            end if;
         end if;
      exception
         when Occurrence : others =>
            Was_Aborted := S.Abort_State.Requested;
            S.Streaming := False;
            declare
               End_Event : constant LLM.Events.Agent_End_Event :=
                 (LLM.Events.Agent_Event with Was_Aborted => Was_Aborted);
            begin
               Emit (On_Event, End_Event);
            end;
            S.Abort_State.Clear;
            Emit (On_Event, Session_Stats (S));
            S.Pause_State.Release;
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "[!] agent error (run_prompt): "
               & Ada.Exceptions.Exception_Message (Occurrence));
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
      S.Pause_State.Release;
   end Run_Prompt;

   procedure Request_Abort (S : in out Session) is
   begin
      S.Abort_State.Set;
      S.Pause_State.Release;
   end Request_Abort;

   procedure Request_Pause (S : in out Session) is
   begin
      S.Pause_State.Arm;
   end Request_Pause;

   procedure Resume (S : in out Session) is
   begin
      S.Pause_State.Release;
   end Resume;

   function Is_Pause_Armed (S : Session) return Boolean is
   begin
      return S.Pause_State.Is_Armed;
   end Is_Pause_Armed;

   function Is_Paused (S : Session) return Boolean is
   begin
      return S.Pause_State.Is_Paused;
   end Is_Paused;

   procedure Switch_Session (S : in out Session; UUID : String) is
   begin
      if LLM.Session_Store.Session_File_Path (UUID)'Length = 0 then
         raise LLM.Session_Store.Session_Error with
           "Session not found: " & UUID;
      end if;

      S.Session_UUID := To_Unbounded_String (UUID);
      S.Sandbox_Profile :=
        Ada.Strings.Unbounded.To_Unbounded_String
          (LLM.Session_Store.Session_Sandbox_Profile (UUID));
      S.History := LLM.Session_Store.Load_Messages (UUID);
      S.Last_Context_Tokens :=
        LLM.Compaction.Estimate_Context_Tokens (S.History);
      S.Abort_State.Clear;
      S.Pause_State.Release;
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

   procedure Set_Sandbox_Profile
     (S       : in out Session;
      Profile :        String) is
   begin
      S.Sandbox_Profile :=
        Ada.Strings.Unbounded.To_Unbounded_String (Profile);
   end Set_Sandbox_Profile;

   function Current_Sandbox (S : Session) return String is
   begin
      return Ada.Strings.Unbounded.To_String (S.Sandbox_Profile);
   end Current_Sandbox;

   procedure Set_Compact_Settings
     (S        : in out Session;
      Settings :        LLM.Compaction.Compact_Settings) is
   begin
      S.Compact_Settings := Settings;
   end Set_Compact_Settings;

   function Session_Id (S : Session) return String is
   begin
      return To_String (S.Session_UUID);
   end Session_Id;

   function Has_Submitted_Prompts (S : Session) return Boolean is
   begin
      return S.Has_Submitted_Prompts;
   end Has_Submitted_Prompts;

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
