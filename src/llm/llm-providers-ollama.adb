--  LLM.Providers.Ollama body.
--
--  Implements the Ollama POST /api/chat wire format with newline-delimited
--  JSON (NDJSON) streaming.  Supports both ollama.com cloud models and
--  locally-running Ollama instances (default http://localhost:11434).
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Containers.Vectors;
with Ada.Containers;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.Settings;

package body LLM.Providers.Ollama is

   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Role;
   use type LLM.Types.Stop_Reason;

   --  One streaming content block being assembled (thinking, text, or tool
   --  use).  Ollama streams these as partial fragments inside the "message"
   --  object of each NDJSON line.
   type Stream_Block_Kind is
     (No_Block,
      Thinking_Block,
      Text_Block,
      Tool_Call_Block);

   type Stream_Block_State is record
      Kind              : Stream_Block_Kind := No_Block;
      Started           : Boolean := False;
      Tool_Call_Id      : Unbounded_String;
      Tool_Name         : Unbounded_String;
      Arguments_Json    : Unbounded_String;
      Thinking_Text     : Unbounded_String;
   end record;

   EMPTY_STREAM_BLOCK : constant Stream_Block_State :=
     (Kind              => No_Block,
      Started           => False,
      Tool_Call_Id      => Null_Unbounded_String,
      Tool_Name         => Null_Unbounded_String,
      Arguments_Json    => Null_Unbounded_String,
      Thinking_Text     => Null_Unbounded_String);

   package Stream_Block_State_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Stream_Block_State);

   type Response_State is record
      Blocks            : Stream_Block_State_Vectors.Vector;
      Stop              : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Tok_Usage         : LLM.Types.Usage := (others => 0);
      Message_Started   : Boolean := False;
      Message_Ended     : Boolean := False;
      Raw_Response_Body : Unbounded_String;
   end record;

   --  Helpers ---------------------------------------------------------------

   function To_Stop_Reason
     (Done_Reason : String) return LLM.Types.Stop_Reason
   is
      Lower : constant String :=
        Ada.Characters.Handling.To_Lower (Done_Reason);
   begin
      if Lower = "stop" then
         return LLM.Types.Stop;
      elsif Lower = "length" then
         return LLM.Types.Length;
      elsif Lower = "tool_calls" then
         return LLM.Types.Tool_Use;
      elsif Lower = "load" then
         --  Model-load-initiated stop: treat as Stop so the agent
         --  can proceed rather than treating it as an error.
         return LLM.Types.Stop;
      else
         return LLM.Types.Unknown_Stop;
      end if;
   end To_Stop_Reason;

   function Thinking_Level_String
     (Thinking : LLM.Providers.Thinking_Level) return String
   is
   begin
      case Thinking is
         when LLM.Providers.Off =>
            return "";
         when LLM.Providers.Minimal | LLM.Providers.Low =>
            return "low";
         when LLM.Providers.Medium =>
            return "medium";
         when LLM.Providers.High | LLM.Providers.X_High =>
            return "high";
      end case;
   end Thinking_Level_String;

   function Endpoint_Url (Base_Url : String) return String is
   begin
      if Base_Url'Length = 0 then
         return "http://localhost:11434/api/chat";
      elsif Base_Url (Base_Url'Last) = '/' then
         return Base_Url & "api/chat";
      else
         return Base_Url & "/api/chat";
      end if;
   end Endpoint_Url;

   function Parse_Json
     (Text : String;
      What : String) return GNATCOLL.JSON.JSON_Value
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
        GNATCOLL.JSON.Read (Text);
   begin
      if Parsed.Success then
         return Parsed.Value;
      end if;
      raise Constraint_Error with
        What & ": " & GNATCOLL.JSON.Format_Parsing_Error (Parsed.Error);
   end Parse_Json;

   function Has_String_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return Boolean
   is
   begin
      return
        Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_String_Type;
   end Has_String_Field;

   function Get_String_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : String := "") return String
   is
   begin
      if Has_String_Field (Value, Field) then
         return Value.Get (Field).Get;
      end if;
      return Default;
   end Get_String_Field;

   function Write_Arguments
     (Func_Obj : GNATCOLL.JSON.JSON_Value) return String
   is
   begin
      if Func_Obj.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Func_Obj.Has_Field ("arguments")
      then
         return GNATCOLL.JSON.Write (Func_Obj.Get ("arguments"));
      end if;
      return "";
   end Write_Arguments;

   function Has_Int_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return Boolean
   is
   begin
      return
        Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Int_Type;
   end Has_Int_Field;

   function Get_Natural_Field
     (Value   : GNATCOLL.JSON.JSON_Value;
      Field   : String;
      Default : Natural := 0) return Natural
   is
      Raw : Long_Integer;
   begin
      if Has_Int_Field (Value, Field) then
         Raw := Value.Get (Field).Get;
         if Raw >= 0 then
            return Natural (Raw);
         end if;
      end if;
      return Default;
   end Get_Natural_Field;

   function Get_Object_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Value
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Value.Get (Field);
      end if;
      return GNATCOLL.JSON.JSON_Null;
   end Get_Object_Field;

   function Has_Array_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return Boolean
   is
   begin
      return
        Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Array_Type;
   end Has_Array_Field;

   function Get_Array_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Array
   is
   begin
      if Has_Array_Field (Value, Field) then
         return Value.Get (Field).Get;
      end if;
      return GNATCOLL.JSON.Empty_Array;
   end Get_Array_Field;

   function Strip_Leading_LF (Text : String) return String is
      First : Natural := Text'First;
   begin
      while First <= Text'Last
        and then (Text (First) = ASCII.LF or else Text (First) = ASCII.CR)
      loop
         First := First + 1;
      end loop;
      return Text (First .. Text'Last);
   end Strip_Leading_LF;

   --  Event emission helpers ------------------------------------------------

   procedure Emit
     (Handler : LLM.Providers.Event_Handler;
      Event   : LLM.Events.Agent_Event'Class)
   is
   begin
      if Handler /= null then
         Handler.all (Event);
      end if;
   end Emit;

   procedure Emit_Agent_Start (Handler : LLM.Providers.Event_Handler) is
      Event : constant LLM.Events.Agent_Start_Event :=
        (LLM.Events.Agent_Event with null record);
   begin
      Emit (Handler, Event);
   end Emit_Agent_Start;

   procedure Emit_Agent_End (Handler : LLM.Providers.Event_Handler) is
      Event : constant LLM.Events.Agent_End_Event :=
        (LLM.Events.Agent_Event with Was_Aborted => False);
   begin
      Emit (Handler, Event);
   end Emit_Agent_End;

   procedure Emit_Message_Start (Handler : LLM.Providers.Event_Handler) is
      Event : constant LLM.Events.Message_Start_Event :=
        (LLM.Events.Agent_Event with null record);
   begin
      Emit (Handler, Event);
   end Emit_Message_Start;

   procedure Emit_Message_End
     (Handler   : LLM.Providers.Event_Handler;
      Stop      : LLM.Types.Stop_Reason;
      Tok_Usage : LLM.Types.Usage)
   is
      Event : constant LLM.Events.Message_End_Event :=
        (LLM.Events.Agent_Event with
         Stop      => Stop,
         Err_Msg   => Null_Unbounded_String,
         Tok_Usage => Tok_Usage,
         Cost_Dmil => 0);
   begin
      Emit (Handler, Event);
   end Emit_Message_End;

   procedure Emit_Update
     (Handler       : LLM.Providers.Event_Handler;
      Kind          : LLM.Events.Message_Update_Kind;
      Delta_Text    : String := "";
      Content_Index : Natural := 0;
      Tool_Call_Id  : String := "";
      Tool_Name     : String := "")
   is
      Event : constant LLM.Events.Message_Update_Event :=
        (LLM.Events.Agent_Event with
         Kind          => Kind,
         Delta_Text    => To_Unbounded_String (Delta_Text),
         Signature     => Null_Unbounded_String,
         Content_Index => Content_Index,
         Tool_Call_Id  => To_Unbounded_String (Tool_Call_Id),
         Tool_Name     => To_Unbounded_String (Tool_Name));
   begin
      Emit (Handler, Event);
   end Emit_Update;

   --  Stream processing -----------------------------------------------------

   procedure Ensure_Block_Slot
     (Blocks : in out Stream_Block_State_Vectors.Vector;
      Index  :        Natural)
   is
   begin
      while Blocks.Length <= Ada.Containers.Count_Type (Index) loop
         Blocks.Append (EMPTY_STREAM_BLOCK);
      end loop;
   end Ensure_Block_Slot;

   procedure Finish_Block
     (State   : in out Response_State;
      Index   :        Natural;
      Handler :        LLM.Providers.Event_Handler)
   is
   begin
      if State.Blocks.Is_Empty
        or else Index > State.Blocks.Last_Index
      then
         return;
      end if;

      declare
         Block : Stream_Block_State := State.Blocks.Element (Index);
      begin
         if not Block.Started then
            return;
         end if;

         case Block.Kind is
            when Thinking_Block =>
               Emit_Update (Handler, LLM.Events.Thinking_End);
               State.Tok_Usage.Thinking := State.Tok_Usage.Thinking
                 + Length (Block.Thinking_Text) / 4;
            when Text_Block =>
               Emit_Update (Handler, LLM.Events.Text_End);
            when Tool_Call_Block =>
               Emit_Update
                 (Handler       => Handler,
                  Kind          => LLM.Events.Tool_Call_End,
                  Delta_Text    => To_String (Block.Arguments_Json),
                  Content_Index => Index,
                  Tool_Call_Id  => To_String (Block.Tool_Call_Id),
                  Tool_Name     => To_String (Block.Tool_Name));
            when No_Block =>
               null;
         end case;

         Block.Started := False;
         State.Blocks.Replace_Element (Index, Block);
      end;
   end Finish_Block;

   procedure Finalize_Message
     (State   : in out Response_State;
      Handler :        LLM.Providers.Event_Handler)
   is
   begin
      if not State.Blocks.Is_Empty then
         for Index in
           State.Blocks.First_Index .. State.Blocks.Last_Index
         loop
            Finish_Block (State, Index, Handler);
         end loop;
      end if;

      if not State.Message_Ended then
         Emit_Message_End
           (Handler   => Handler,
            Stop      => State.Stop,
            Tok_Usage => State.Tok_Usage);
         State.Message_Ended := True;
      end if;
   end Finalize_Message;

   procedure Process_Tool_Call_Chunk
     (State   : in out Response_State;
      TC_Obj  :        GNATCOLL.JSON.JSON_Value;
      Index   :        Natural;
      Handler :        LLM.Providers.Event_Handler)
   is
   begin
      Ensure_Block_Slot (State.Blocks, Index);

      declare
         Block       : Stream_Block_State :=
           State.Blocks.Element (Index);
         Func_Obj    : constant GNATCOLL.JSON.JSON_Value :=
           Get_Object_Field (TC_Obj, "function");
         TC_Id       : constant String :=
           Get_String_Field (TC_Obj, "id");
         TC_Name     : constant String :=
           Get_String_Field (Func_Obj, "name");
         TC_Args     : constant String :=
           Write_Arguments (Func_Obj);

         --  Tool calls may arrive all-at-once or incrementally.
         --  Accumulate partial fragments and emit progressive deltas.
         Id_Delta    : constant String :=
           (if TC_Id'Length > 0 then TC_Id else "");
         Name_Delta  : constant String :=
           (if TC_Name'Length > 0 then TC_Name else "");
         Args_Delta  : constant String :=
           (if TC_Args'Length > 0 then TC_Args else "");
         Frag       : constant String :=
           (if Args_Delta'Length > 0 then Args_Delta elsif Name_Delta'Length > 0 then Name_Delta else "");
      begin
         if Id_Delta'Length > 0 then
            if Length (Block.Tool_Call_Id) = 0 then
               Block.Tool_Call_Id := To_Unbounded_String (Id_Delta);
            else
               Append (Block.Tool_Call_Id, Id_Delta);
            end if;
         end if;

         if Name_Delta'Length > 0 then
            Append (Block.Tool_Name, Name_Delta);
         end if;

         if Args_Delta'Length > 0 then
            Append (Block.Arguments_Json, Args_Delta);
         end if;

         if not Block.Started then
            Block.Kind := Tool_Call_Block;
            Block.Started := True;
            Emit_Update
              (Handler       => Handler,
               Kind          => LLM.Events.Tool_Call_Start,
               Content_Index => Index,
               Tool_Call_Id  => To_String (Block.Tool_Call_Id),
               Tool_Name     => To_String (Block.Tool_Name));
         end if;

         if Frag'Length > 0 then
            Emit_Update
              (Handler       => Handler,
               Kind          => LLM.Events.Tool_Call_Delta,
               Delta_Text    => Frag,
               Content_Index => Index,
               Tool_Call_Id  => To_String (Block.Tool_Call_Id),
               Tool_Name     => To_String (Block.Tool_Name));
         end if;

         State.Blocks.Replace_Element (Index, Block);
      end;
   end Process_Tool_Call_Chunk;

   procedure Process_Stream_Chunk
     (Chunk   :        String;
      State   : in out Response_State;
      Handler :        LLM.Providers.Event_Handler)
   is
      Root : constant GNATCOLL.JSON.JSON_Value :=
        Parse_Json (Chunk, "Invalid Ollama streaming chunk");
   begin
      --  Check for server-side error in streaming output.
      if Has_String_Field (Root, "error") then
         raise Constraint_Error with
           "Ollama error: " & Root.Get ("error").Get;
      end if;

      --  Final chunk: extract usage and stop reason.
      if Root.Has_Field ("done")
        and then Root.Get ("done").Kind =
                   GNATCOLL.JSON.JSON_Boolean_Type
        and then Root.Get ("done").Get
      then
         State.Stop := To_Stop_Reason
           (Get_String_Field (Root, "done_reason", "stop"));
         State.Tok_Usage.Input :=
           Get_Natural_Field (Root, "prompt_eval_count");
         State.Tok_Usage.Output :=
           Get_Natural_Field (Root, "eval_count");
         Finalize_Message (State, Handler);
         return;
      end if;

      --  Start the message if not yet started.
      if not State.Message_Started then
         Emit_Message_Start (Handler);
         State.Message_Started := True;
      end if;

      --  Process the message object.
      if Root.Has_Field ("message")
        and then Root.Get ("message").Kind =
                   GNATCOLL.JSON.JSON_Object_Type
      then
         declare
            Msg : constant GNATCOLL.JSON.JSON_Value :=
              Root.Get ("message");
         begin
            --  Thinking / reasoning content.
            if Has_String_Field (Msg, "thinking") then
               declare
                  Think_Text : constant String := Strip_Leading_LF
                    (Msg.Get ("thinking").Get);
               begin
                  if Think_Text'Length > 0 then
                     --  Ensure thinking block exists at index 0.
                     Ensure_Block_Slot (State.Blocks, 0);

                     declare
                        Block : Stream_Block_State :=
                          State.Blocks.Element (0);
                     begin
                        if not Block.Started then
                           Block.Kind := Thinking_Block;
                           Block.Started := True;
                           Emit_Update (Handler, LLM.Events.Thinking_Start);
                        end if;
                        Append (Block.Thinking_Text, Think_Text);
                        Emit_Update
                          (Handler    => Handler,
                           Kind       => LLM.Events.Thinking_Delta,
                           Delta_Text => Think_Text);
                        State.Blocks.Replace_Element (0, Block);
                     end;
                  end if;
               end;
            end if;

            --  Text content.
            if Has_String_Field (Msg, "content") then
               declare
                  Content_Text : constant String :=
                    Msg.Get ("content").Get;
               begin
                  if Content_Text'Length > 0 then
                     --  If thinking was in progress, end it before
                     --  starting text output.
                     if not State.Blocks.Is_Empty then
                        declare
                           Block : Stream_Block_State :=
                             State.Blocks.Element (0);
                        begin
                           if Block.Started
                             and then Block.Kind = Thinking_Block
                           then
                              Finish_Block (State, 0, Handler);
                           end if;
                        end;
                     end if;

                     --  Text block at index 1 (after thinking at 0).
                     Ensure_Block_Slot (State.Blocks, 1);
                     declare
                        Block : Stream_Block_State :=
                          State.Blocks.Element (1);
                     begin
                        if not Block.Started then
                           Block.Kind := Text_Block;
                           Block.Started := True;
                           Emit_Update (Handler, LLM.Events.Text_Start);
                        end if;
                        Emit_Update
                          (Handler    => Handler,
                           Kind       => LLM.Events.Text_Delta,
                           Delta_Text => Content_Text);
                        State.Blocks.Replace_Element (1, Block);
                     end;
                  end if;
               end;
            end if;

            --  Tool calls.
            if Has_Array_Field (Msg, "tool_calls") then
               --  End thinking if active.
               if not State.Blocks.Is_Empty then
                  declare
                     Block : Stream_Block_State :=
                       State.Blocks.Element (0);
                  begin
                     if Block.Started
                       and then Block.Kind = Thinking_Block
                     then
                        Finish_Block (State, 0, Handler);
                     end if;
                  end;
               end if;

               declare
                  TC_Array : constant GNATCOLL.JSON.JSON_Array :=
                    Get_Array_Field (Msg, "tool_calls");
               begin
                  for I in 1 .. GNATCOLL.JSON.Length (TC_Array) loop
                     declare
                        TC_Obj : constant GNATCOLL.JSON.JSON_Value :=
                          GNATCOLL.JSON.Get (TC_Array, I);
                     begin
                        if TC_Obj.Kind =
                          GNATCOLL.JSON.JSON_Object_Type
                        then
                           --  Use fixed index 2+ for tool calls
                           --  (0=thinking, 1=text).
                           Process_Tool_Call_Chunk
                             (State   => State,
                              TC_Obj  => TC_Obj,
                              Index   => I + 1,
                              Handler => Handler);
                        end if;
                     end;
                  end loop;
               end;
            end if;
         end;
      end if;
   end Process_Stream_Chunk;

   --  Request building -------------------------------------------------------

   procedure Append_Assistant_Message
     (Messages : in out GNATCOLL.JSON.JSON_Array;
      Msg      :        LLM.Types.Message)
   is
      Message        : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Tool_Calls     : GNATCOLL.JSON.JSON_Array :=
        GNATCOLL.JSON.Empty_Array;
      Has_Tool_Calls : Boolean := False;
      Content_Text   : Unbounded_String;
   begin
      Message.Set_Field ("role", "assistant");

      for Block of Msg.Content loop
         case Block.Kind is
            when LLM.Types.Text_Block =>
               if Block.Text /= Null_Unbounded_String then
                  Append (Content_Text, To_String (Block.Text));
               end if;
            when LLM.Types.Thinking_Block =>
               Append (Content_Text, To_String (Block.Thinking));
            when LLM.Types.Tool_Call_Block =>
               Has_Tool_Calls := True;
               declare
                  Tool_Call : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Create_Object;
                  Func      : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Create_Object;
               begin
                  Tool_Call.Set_Field
                    ("id", To_String (Block.Tool_Call_Id));
                  Tool_Call.Set_Field ("type", "function");
                  Func.Set_Field
                    ("name", To_String (Block.Tool_Name));
                  Func.Set_Field
                    ("arguments",
                     To_String (Block.Arguments_Json));
                  Tool_Call.Set_Field ("function", Func);
                  GNATCOLL.JSON.Append (Tool_Calls, Tool_Call);
               end;
            when LLM.Types.Tool_Result_Block =>
               Append (Content_Text, To_String (Block.Result_Text));
         end case;
      end loop;

      Message.Set_Field ("content", To_String (Content_Text));
      if Has_Tool_Calls then
         Message.Set_Field ("tool_calls", Tool_Calls);
      end if;
      GNATCOLL.JSON.Append (Messages, Message);
   end Append_Assistant_Message;

   function Build_Request_Body
     (P             : in out Provider;
      Model_Id      :        String;
      System_Prompt :        String;
      Messages      :        LLM.Types.Message_Vectors.Vector;
      Tools_Json    :        String;
      Thinking      :        LLM.Providers.Thinking_Level;
      Max_Tokens    :        Positive) return String
   is
      Request      : constant GNATCOLL.JSON.JSON_Value :=
        GNATCOLL.JSON.Create_Object;
      Request_Msgs : GNATCOLL.JSON.JSON_Array :=
        GNATCOLL.JSON.Empty_Array;
      Tools_Read   : GNATCOLL.JSON.Read_Result;
      Think_Level  : constant String := Thinking_Level_String (Thinking);
   begin
      Request.Set_Field ("model", Model_Id);
      Request.Set_Field ("stream", True);

      --  System prompt (item 1).
      if System_Prompt'Length > 0 then
         declare
            Sys_Msg : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Sys_Msg.Set_Field ("role", "system");
            Sys_Msg.Set_Field ("content", System_Prompt);
            GNATCOLL.JSON.Append (Request_Msgs, Sys_Msg);
         end;
      end if;

      --  Conversation messages.
      for Msg of Messages loop
         case Msg.Role is
            when LLM.Types.User | LLM.Types.Compaction_Summary =>
               declare
                  User_Msg   : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Create_Object;
                  Content_Text : Unbounded_String;
               begin
                  User_Msg.Set_Field ("role", "user");
                  for Block of Msg.Content loop
                     case Block.Kind is
                        when LLM.Types.Text_Block =>
                           Append (Content_Text,
                                   To_String (Block.Text));
                        when LLM.Types.Thinking_Block =>
                           Append (Content_Text,
                                   To_String (Block.Thinking));
                        when LLM.Types.Tool_Result_Block =>
                           Append (Content_Text,
                                   To_String (Block.Result_Text));
                        when others =>
                           null;
                     end case;
                  end loop;
                  User_Msg.Set_Field
                    ("content", To_String (Content_Text));
                  GNATCOLL.JSON.Append (Request_Msgs, User_Msg);
               end;
            when LLM.Types.Assistant =>
               --  Include tool_calls in history (item 6).
               Append_Assistant_Message (Request_Msgs, Msg);
            when LLM.Types.Tool_Result =>
               declare
                  Tool_Msg  : constant GNATCOLL.JSON.JSON_Value :=
                    GNATCOLL.JSON.Create_Object;
                  Result_Text : Unbounded_String;
               begin
                  Tool_Msg.Set_Field ("role", "tool");
                  for Block of Msg.Content loop
                     case Block.Kind is
                        when LLM.Types.Tool_Result_Block =>
                           Append
                             (Result_Text,
                              To_String (Block.Result_Text));
                        when LLM.Types.Text_Block =>
                           Append
                             (Result_Text,
                              To_String (Block.Text));
                        when others =>
                           null;
                     end case;
                  end loop;
                  Tool_Msg.Set_Field
                    ("content", To_String (Result_Text));
                  GNATCOLL.JSON.Append (Request_Msgs, Tool_Msg);
               end;
         end case;
      end loop;

      Request.Set_Field ("messages", Request_Msgs);

      --  Tools.
      if Tools_Json'Length > 0 then
         Tools_Read := GNATCOLL.JSON.Read (Tools_Json);
         if not Tools_Read.Success then
            raise Constraint_Error with
              "Invalid tools JSON: "
              & GNATCOLL.JSON.Format_Parsing_Error (Tools_Read.Error);
         elsif Tools_Read.Value.Kind = GNATCOLL.JSON.JSON_Array_Type
           and then
           GNATCOLL.JSON.Length (Tools_Read.Value.Get) > 0
         then
            Request.Set_Field
              ("tools", Tools_Read.Value);
         end if;
      end if;

      --  Thinking level (item 4).
      if Think_Level'Length > 0 then
         Request.Set_Field ("think", Think_Level);
      end if;

      --  Model options (items 3, 8).
      declare
         Options : constant GNATCOLL.JSON.JSON_Value :=
           GNATCOLL.JSON.Create_Object;
      begin
         Options.Set_Field
           ("num_predict", Integer (Max_Tokens));
         Request.Set_Field ("options", Options);
      end;

      return GNATCOLL.JSON.Write (Request);
   end Build_Request_Body;

   --  Public API ------------------------------------------------------------

   function Create
     (Base_Url : String := "";
      Api_Key  : String := "") return Provider
   is
   begin
      return Result : Provider do
         Result.Base_Url := To_Unbounded_String (Base_Url);
         Result.Api_Key  := To_Unbounded_String (Api_Key);
      end return;
   end Create;

   overriding
   procedure Send
     (P             : in out Provider;
      Model_Id      :        String;
      System_Prompt :        String;
      Messages      :        LLM.Types.Message_Vectors.Vector;
      Tools_Json    :        String;
      Thinking      :        LLM.Providers.Thinking_Level;
      Max_Tokens    :        Positive;
      Handler       :        LLM.Providers.Event_Handler)
   is
      Headers        : LLM.HTTP.Header_List;
      Status         : Natural := 0;
      State          : Response_State;
      End_Event_Sent : Boolean := False;
      Response_Body  : Unbounded_String;
      Effective_Base_Url : Unbounded_String := P.Base_Url;
      Effective_Api_Key  : Unbounded_String := P.Api_Key;

      Request_Body   : constant String :=
        Build_Request_Body
          (P             => P,
           Model_Id      => Model_Id,
           System_Prompt => System_Prompt,
           Messages      => Messages,
           Tools_Json    => Tools_Json,
           Thinking      => Thinking,
           Max_Tokens    => Max_Tokens);

      procedure On_Chunk (Data : String) is
         LF_Pos : Natural;
      begin
         Append (Response_Body, Data);

         --  Process complete NDJSON lines.
         loop
            LF_Pos := Ada.Strings.Fixed.Index
              (To_String (Response_Body), "" & ASCII.LF);
            exit when LF_Pos = 0;

            declare
               Line : constant String :=
                 To_String (Response_Body)
                   (1 .. LF_Pos - 1);
            begin
               if Line'Length > 0 then
                  Append (State.Raw_Response_Body, Line);
                  Process_Stream_Chunk (Line, State, Handler);
               end if;
            end;

            Response_Body :=
              To_Unbounded_String
                (To_String (Response_Body)
                   (LF_Pos + 1 ..
                      To_String (Response_Body)'Last));
         end loop;
      end On_Chunk;
   begin
      Emit_Agent_Start (Handler);

      --  Resolve base URL and API key.
      if Length (Effective_Base_Url) = 0 then
         declare
            Root : constant GNATCOLL.JSON.JSON_Value :=
              LLM.Settings.Load_Json_File
                (LLM.Settings.Models_Path);
            Prov : constant GNATCOLL.JSON.JSON_Value :=
              LLM.Settings.Find_Provider_Config (Root, "ollama");
         begin
            if Prov.Kind = GNATCOLL.JSON.JSON_Object_Type then
               Effective_Base_Url :=
                 To_Unbounded_String
                   (Get_String_Field (Prov, "baseUrl"));
            end if;
            if Length (Effective_Api_Key) = 0 then
               Effective_Api_Key :=
                 To_Unbounded_String
                   (LLM.Settings.Resolve_Api_Key ("ollama"));
            end if;
         end;
      end if;

      --  Default to localhost when no base URL configured and no API key
      --  (item 10).
      if Length (Effective_Base_Url) = 0
        and then Length (Effective_Api_Key) = 0
      then
         Effective_Base_Url :=
           To_Unbounded_String ("http://localhost:11434");
      elsif Length (Effective_Base_Url) = 0 then
         Effective_Base_Url :=
           To_Unbounded_String ("https://ollama.com");
      end if;

      if Length (Effective_Api_Key) > 0 then
         LLM.HTTP.Add_Header
           (Headers, "Authorization",
            "Bearer " & To_String (Effective_Api_Key));
      end if;
      LLM.HTTP.Add_Header
        (Headers, "Content-Type", "application/json");

      LLM.HTTP.Post
        (URL      =>
           Endpoint_Url (To_String (Effective_Base_Url)),
         Headers  => Headers,
         Payload  => Request_Body,
         On_Chunk => On_Chunk'Access,
         Status   => Status);

      if Status /= 200 then
         raise Constraint_Error with
           "Ollama chat request failed with HTTP"
           & Natural'Image (Status)
           & ": "
           & To_String (Response_Body);
      end if;

      if not State.Message_Ended then
         Finalize_Message (State, Handler);
      end if;

      Emit_Agent_End (Handler);
      End_Event_Sent := True;
   exception
      when E : others =>
         if not End_Event_Sent then
            Emit_Agent_End (Handler);
         end if;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] ollama provider error: "
            & Ada.Exceptions.Exception_Message (E));
         Emit_Message_End
           (Handler   => Handler,
            Stop      => LLM.Types.Error_Stop,
            Tok_Usage => (others => 0));
         raise;
   end Send;

end LLM.Providers.Ollama;
