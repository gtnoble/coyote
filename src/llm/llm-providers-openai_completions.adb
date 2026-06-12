--  LLM.Providers.OpenAI_Completions body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.SSE;

package body LLM.Providers.OpenAI_Completions is

   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;

   type Tool_Call_State is record
      Seen           : Boolean := False;
      Tool_Call_Id   : Unbounded_String;
      Tool_Name      : Unbounded_String;
      Arguments_Json : Unbounded_String;
   end record;

   package Tool_Call_State_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Natural,
     Element_Type => Tool_Call_State);

   EMPTY_TOOL_CALL_STATE : constant Tool_Call_State :=
      (Seen           => False,
     Tool_Call_Id   => Null_Unbounded_String,
     Tool_Name      => Null_Unbounded_String,
     Arguments_Json => Null_Unbounded_String);

   type Response_State is record
      Parser            : LLM.SSE.Parser;
      Text_Started      : Boolean := False;
      Thinking_Started  : Boolean := False;
      Stop              : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Tok_Usage         : LLM.Types.Usage := (others => 0);
      Tool_Calls        : Tool_Call_State_Vectors.Vector;
      Done              : Boolean := False;
      Saw_Stream_Event  : Boolean := False;
      Raw_Response_Body : Unbounded_String;
   end record;

   function Create
      (Base_Url : String;
     Api_Key  : String) return Provider
   is
   begin
      return Result : Provider do
         Result.Base_Url := To_Unbounded_String (Base_Url);
         Result.Api_Key := To_Unbounded_String (Api_Key);
      end return;
   end Create;

   procedure Set_Base_Url
      (P        : in out Provider;
     Base_Url :        String)
   is
   begin
      P.Base_Url := To_Unbounded_String (Base_Url);
   end Set_Base_Url;

   function Get_Base_Url (P : Provider) return String is
   begin
      return To_String (P.Base_Url);
   end Get_Base_Url;

   procedure Set_Api_Key
      (P       : in out Provider;
     Api_Key :        String)
   is
   begin
      P.Api_Key := To_Unbounded_String (Api_Key);
   end Set_Api_Key;

   function Get_Api_Key (P : Provider) return String is
   begin
      return To_String (P.Api_Key);
   end Get_Api_Key;

   procedure Add_Header
      (P     : in out Provider;
     Name  :        String;
     Value :        String)
   is
   begin
      P.Extra_Headers.Append
         ((Name  => To_Unbounded_String (Name),
            Value => To_Unbounded_String (Value)));
   end Add_Header;

   function Reasoning_Effort
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
   end Reasoning_Effort;

   procedure Customize_Request
      (P        : in out Provider;
     Model_Id :        String;
     Thinking :        LLM.Providers.Thinking_Level;
     Request  :        GNATCOLL.JSON.JSON_Value)
   is
      pragma Unreferenced (P);
      pragma Unreferenced (Model_Id);

      Effort : constant String := Reasoning_Effort (Thinking);
   begin
      if Effort'Length = 0 then
         return;
      end if;

      declare
         Reasoning : constant GNATCOLL.JSON.JSON_Value :=
            GNATCOLL.JSON.Create_Object;
      begin
         Reasoning.Set_Field ("effort", Effort);
         Request.Set_Field ("reasoning", Reasoning);
      end;
   end Customize_Request;

   function Endpoint_Url (Base_Url : String) return String is
   begin
      if Base_Url'Length = 0 then
         return "/chat/completions";
      elsif Base_Url (Base_Url'Last) = '/' then
         return Base_Url & "chat/completions";
      else
         return Base_Url & "/chat/completions";
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

   --  Some OpenRouter models append a trailing LF after every streamed
   --  reasoning token; others (e.g. MiniMax M2.7) prepend leading newlines
   --  to each token instead.  Strip both ends so thinking renders as flowing
   --  text rather than one fragment per line.
   function Normalize_Thinking_Delta (Text : String) return String is
      First : Natural := Text'First;
      Last  : Natural := Text'Last;
   begin
      while First <= Last
        and then (Text (First) = ASCII.LF or else Text (First) = ASCII.CR)
      loop
         First := First + 1;
      end loop;
      while Last >= First
        and then (Text (Last) = ASCII.LF or else Text (Last) = ASCII.CR)
      loop
         Last := Last - 1;
      end loop;
      return Text (First .. Last);
   end Normalize_Thinking_Delta;

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

   function Get_Array_Field
      (Value : GNATCOLL.JSON.JSON_Value;
     Field : String) return GNATCOLL.JSON.JSON_Array
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
         and then Value.Has_Field (Field)
         and then Value.Get (Field).Kind = GNATCOLL.JSON.JSON_Array_Type
      then
         return Value.Get (Field).Get;
      end if;

      return GNATCOLL.JSON.Empty_Array;
   end Get_Array_Field;

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

   function To_Stop_Reason (Finish_Reason : String) return LLM.Types.Stop_Reason
   is
   begin
      if Finish_Reason = "stop" then
         return LLM.Types.Stop;
      elsif Finish_Reason = "length" then
         return LLM.Types.Length;
      elsif Finish_Reason = "tool_calls" then
         return LLM.Types.Tool_Use;
      elsif Finish_Reason = "content_filter" then
         return LLM.Types.Error_Stop;
      else
         return LLM.Types.Unknown_Stop;
      end if;
   end To_Stop_Reason;

   function Parse_Usage
      (Value : GNATCOLL.JSON.JSON_Value) return LLM.Types.Usage
   is
      --  OpenAI returns cached input tokens inside a nested
      --  prompt_tokens_details object:
      --    "usage": {
      --      "prompt_tokens": N,
      --      "completion_tokens": M,
      --      "prompt_tokens_details": {
      --        "cached_tokens": C
      --      }
      --    }
      --  The Cache_Read field captures these cached tokens;
      --  Cache_Write is left at 0 because OpenAI does not
      --  charge a separate creation premium for automatic
      --  caching.
      Details : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Value, "prompt_tokens_details");
      Comp_Det : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Value, "completion_tokens_details");
   begin
      return
         (Input       => Get_Natural_Field (Value, "prompt_tokens"),
       Output      => Get_Natural_Field (Value, "completion_tokens"),
       Cache_Read  => Get_Natural_Field (Details, "cached_tokens"),
      Cache_Write => 0,
      Thinking    => Get_Natural_Field (Comp_Det, "reasoning_tokens"));
   end Parse_Usage;

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

   function Message_Text (Msg : LLM.Types.Message) return String is
      Result : Unbounded_String;
   begin
      for Block of Msg.Content loop
         case Block.Kind is
            when LLM.Types.Text_Block =>
               Append (Result, To_String (Block.Text));
            when others =>
               null;
         end case;
      end loop;

      return To_String (Result);
   end Message_Text;

   procedure Append_System_Message
      (Messages      : in out GNATCOLL.JSON.JSON_Array;
       System_Prompt :        String)
   is
      --  Emit the system prompt as a single system message with a
      --  cache_control breakpoint so OpenAI's automatic prompt
      --  caching can reuse it across turns.
      Message      : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
      Cache_Marker : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
   begin
      if System_Prompt'Length = 0 then
         return;
      end if;

      Cache_Marker.Set_Field ("type", "ephemeral");
      Message.Set_Field ("role", "system");
      Message.Set_Field ("content", System_Prompt);
      Message.Set_Field ("cache_control", Cache_Marker);
      GNATCOLL.JSON.Append (Messages, Message);
   end Append_System_Message;

   procedure Append_User_Message
      (Messages : in out GNATCOLL.JSON.JSON_Array;
     Msg      :        LLM.Types.Message)
   is
      Message : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
   begin
      Message.Set_Field ("role", "user");
      Message.Set_Field ("content", Message_Text (Msg));
      GNATCOLL.JSON.Append (Messages, Message);
   end Append_User_Message;

   procedure Append_Assistant_Message
      (Messages : in out GNATCOLL.JSON.JSON_Array;
     Msg      :        LLM.Types.Message)
   is
      Message        : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
      Tool_Calls     : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Has_Tool_Calls : Boolean                  := False;
   begin
      Message.Set_Field ("role", "assistant");

      for Block of Msg.Content loop
         if Block.Kind = LLM.Types.Tool_Call_Block then
            declare
               Tool_Call : constant GNATCOLL.JSON.JSON_Value :=
                  GNATCOLL.JSON.Create_Object;
               Func      : constant GNATCOLL.JSON.JSON_Value :=
                  GNATCOLL.JSON.Create_Object;
            begin
               Has_Tool_Calls := True;
               Tool_Call.Set_Field ("id", To_String (Block.Tool_Call_Id));
               Tool_Call.Set_Field ("type", "function");
               Func.Set_Field ("name", To_String (Block.Tool_Name));
               Func.Set_Field ("arguments", To_String (Block.Arguments_Json));
               Tool_Call.Set_Field ("function", Func);
               GNATCOLL.JSON.Append (Tool_Calls, Tool_Call);
            end;
         end if;
      end loop;

      if Has_Tool_Calls then
         Message.Set_Field ("content", GNATCOLL.JSON.JSON_Null);
         Message.Set_Field ("tool_calls", Tool_Calls);
      else
         Message.Set_Field ("content", Message_Text (Msg));
      end if;

      GNATCOLL.JSON.Append (Messages, Message);
   end Append_Assistant_Message;

   procedure Append_Tool_Result_Message
      (Messages : in out GNATCOLL.JSON.JSON_Array;
     Msg      :        LLM.Types.Message)
   is
      Message      : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
      Tool_Call_Id : Unbounded_String;
      Result_Text  : Unbounded_String;
      Media_Type   : Unbounded_String;
   begin
      for Block of Msg.Content loop
         case Block.Kind is
            when LLM.Types.Tool_Result_Block =>
               if Length (Tool_Call_Id) = 0 then
                  Tool_Call_Id := Block.Result_Id;
               end if;
               if Length (Block.Media_Type) > 0 then
                  Media_Type  := Block.Media_Type;
               end if;
               Append (Result_Text, To_String (Block.Result_Text));
            when LLM.Types.Text_Block =>
               Append (Result_Text, To_String (Block.Text));
            when others =>
               null;
         end case;
      end loop;

      Message.Set_Field ("role", "tool");
      Message.Set_Field ("tool_call_id", To_String (Tool_Call_Id));

      if Length (Media_Type) > 0 then
         --  OpenAI chat-completions does not support vision content inside
         --  tool-role messages.  Emit a plain-text stub in the tool message
         --  then follow it with a user message carrying the image_url so the
         --  model can actually see the image.
         Message.Set_Field ("content", "[image result]");
         GNATCOLL.JSON.Append (Messages, Message);
         declare
            User_Msg   : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Content    : GNATCOLL.JSON.JSON_Array :=
              GNATCOLL.JSON.Empty_Array;
            Image_Part : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
            Image_Url  : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Create_Object;
         begin
            Image_Url.Set_Field
              ("url",
               "data:" & To_String (Media_Type) & ";base64,"
               & To_String (Result_Text));
            Image_Part.Set_Field ("type", "image_url");
            Image_Part.Set_Field ("image_url", Image_Url);
            GNATCOLL.JSON.Append (Content, Image_Part);
            User_Msg.Set_Field ("role", "user");
            User_Msg.Set_Field
              ("content", GNATCOLL.JSON.Create (Content));
            GNATCOLL.JSON.Append (Messages, User_Msg);
         end;
      else
         Message.Set_Field ("content", To_String (Result_Text));
         GNATCOLL.JSON.Append (Messages, Message);
      end if;
   end Append_Tool_Result_Message;

   function Build_Request_Body
      (P             : in out Provider'Class;
     Model_Id      :        String;
     System_Prompt :        String;
     Messages      :        LLM.Types.Message_Vectors.Vector;
     Tools_Json    :        String;
     Thinking      :        LLM.Providers.Thinking_Level;
     Max_Tokens    :        Positive) return String
   is
      Request    : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
      Msgs       : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Tools_Read : GNATCOLL.JSON.Read_Result;
   begin
      Request.Set_Field ("model", Model_Id);
      Request.Set_Field ("stream", P.Use_Streaming);
      Request.Set_Field ("max_completion_tokens", Integer (Max_Tokens));

      Append_System_Message (Msgs, System_Prompt);

      for Msg of Messages loop
         case Msg.Role is
            when LLM.Types.User | LLM.Types.Compaction_Summary =>
               Append_User_Message (Msgs, Msg);
            when LLM.Types.Assistant =>
               Append_Assistant_Message (Msgs, Msg);
            when LLM.Types.Tool_Result =>
               Append_Tool_Result_Message (Msgs, Msg);
         end case;
      end loop;

      Request.Set_Field ("messages", Msgs);

      if Tools_Json'Length > 0 then
         Tools_Read := GNATCOLL.JSON.Read (Tools_Json);
         if not Tools_Read.Success then
            raise Constraint_Error with
               "Invalid tools JSON: "
               & GNATCOLL.JSON.Format_Parsing_Error (Tools_Read.Error);
         elsif Tools_Read.Value.Kind /= GNATCOLL.JSON.JSON_Array_Type then
            raise Constraint_Error with "Invalid tools JSON: expected array";
         else
            declare
               Raw_Tools : constant GNATCOLL.JSON.JSON_Array :=
                  Tools_Read.Value.Get;
            begin
               if GNATCOLL.JSON.Length (Raw_Tools) > 0 then
                  --  Add a cache_control breakpoint on the last tool
                  --  definition so the tool schema is cached across
                  --  turns with OpenAI-compatible providers.
                  declare
                     Cached_Tools : GNATCOLL.JSON.JSON_Array :=
                       GNATCOLL.JSON.Empty_Array;
                     Cache_Marker : constant GNATCOLL.JSON.JSON_Value :=
                       GNATCOLL.JSON.Create_Object;
                  begin
                     Cache_Marker.Set_Field ("type", "ephemeral");
                     for I in
                       1 .. GNATCOLL.JSON.Length (Raw_Tools)
                     loop
                        declare
                           Item : constant GNATCOLL.JSON.JSON_Value :=
                             GNATCOLL.JSON.Get (Raw_Tools, I);
                        begin
                           if I =
                             GNATCOLL.JSON.Length (Raw_Tools)
                           then
                              --  Set_Field mutates the underlying JSON
                              --  object through the reference-counted
                              --  handle even on a constant view.
                              declare
                                 Item_Copy : constant GNATCOLL.JSON.JSON_Value :=
                                   GNATCOLL.JSON.Get (Raw_Tools, I);
                              begin
                                 Item_Copy.Set_Field
                                   ("cache_control", Cache_Marker);
                                 GNATCOLL.JSON.Append
                                   (Cached_Tools, Item_Copy);
                              end;
                           else
                              GNATCOLL.JSON.Append
                                (Cached_Tools, Item);
                           end if;
                        end;
                     end loop;
                     Request.Set_Field ("tools", Cached_Tools);
                  end;
               end if;
            end;
         end if;
      end if;

      Customize_Request (P, Model_Id, Thinking, Request);
      return GNATCOLL.JSON.Write (Request);
   end Build_Request_Body;

   procedure Ensure_Tool_Call_Slot
      (States : in out Tool_Call_State_Vectors.Vector;
     Index  :        Natural)
   is
   begin
      while States.Length <= Ada.Containers.Count_Type (Index) loop
         States.Append (EMPTY_TOOL_CALL_STATE);
      end loop;
   end Ensure_Tool_Call_Slot;

   procedure Process_Tool_Calls
      (Delta_Value :        GNATCOLL.JSON.JSON_Value;
     State       : in out Response_State;
     Handler     :        LLM.Providers.Event_Handler)
   is
      Tool_Calls : constant GNATCOLL.JSON.JSON_Array :=
         Get_Array_Field (Delta_Value, "tool_calls");
   begin
      for I in 1 .. GNATCOLL.JSON.Length (Tool_Calls) loop
         declare
            Item           : constant GNATCOLL.JSON.JSON_Value :=
               GNATCOLL.JSON.Get (Tool_Calls, I);
            Function_Value : constant GNATCOLL.JSON.JSON_Value :=
               Get_Object_Field (Item, "function");
            Index          : constant Natural :=
               Get_Natural_Field (Item, "index", I - 1);
            Id_Fragment    : constant String :=
               Get_String_Field (Item, "id");
            Name_Fragment  : constant String :=
               Get_String_Field (Function_Value, "name");
            Args_Fragment  : constant String :=
               Get_String_Field (Function_Value, "arguments");
            Delta_Fragment : constant String :=
               (if Args_Fragment'Length > 0 then Args_Fragment else Name_Fragment);
         begin
            Ensure_Tool_Call_Slot (State.Tool_Calls, Index);

            declare
               Tool_State : Tool_Call_State := State.Tool_Calls.Element (Index);
            begin
               if Id_Fragment'Length > 0 then
                  if Length (Tool_State.Tool_Call_Id) = 0 then
                     Tool_State.Tool_Call_Id := To_Unbounded_String (Id_Fragment);
                  else
                     Append (Tool_State.Tool_Call_Id, Id_Fragment);
                  end if;
               end if;

               if Name_Fragment'Length > 0 then
                  Append (Tool_State.Tool_Name, Name_Fragment);
               end if;

               if Args_Fragment'Length > 0 then
                  Append (Tool_State.Arguments_Json, Args_Fragment);
               end if;

               if not Tool_State.Seen then
                  Tool_State.Seen := True;
                  Emit_Update
                     (Handler       => Handler,
               Kind          => LLM.Events.Tool_Call_Start,
               Content_Index => Index,
               Tool_Call_Id  => To_String (Tool_State.Tool_Call_Id),
               Tool_Name     => To_String (Tool_State.Tool_Name));
               end if;

               Emit_Update
                  (Handler       => Handler,
             Kind          => LLM.Events.Tool_Call_Delta,
             Delta_Text    => Delta_Fragment,
             Content_Index => Index,
             Tool_Call_Id  => To_String (Tool_State.Tool_Call_Id),
             Tool_Name     => To_String (Tool_State.Tool_Name));

               State.Tool_Calls.Replace_Element (Index, Tool_State);
            end;
         end;
      end loop;
   end Process_Tool_Calls;

   procedure Finalize_Message
      (State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
   begin
      if State.Thinking_Started then
         Emit_Update (Handler, LLM.Events.Thinking_End);
         State.Thinking_Started := False;
      end if;

      if State.Text_Started then
         Emit_Update (Handler, LLM.Events.Text_End);
         State.Text_Started := False;
      end if;

      for Index in State.Tool_Calls.First_Index .. State.Tool_Calls.Last_Index
      loop
         declare
            Tool_State : constant Tool_Call_State :=
               State.Tool_Calls.Element (Index);
         begin
            if Tool_State.Seen then
               Emit_Update
                  (Handler       => Handler,
             Kind          => LLM.Events.Tool_Call_End,
             Delta_Text    => To_String (Tool_State.Arguments_Json),
             Content_Index => Index,
             Tool_Call_Id  => To_String (Tool_State.Tool_Call_Id),
             Tool_Name     => To_String (Tool_State.Tool_Name));
            end if;
         end;
      end loop;

      Emit_Message_End
         (Handler   => Handler,
       Stop      => State.Stop,
       Tok_Usage => State.Tok_Usage);
      State.Done := True;
   end Finalize_Message;

   procedure Process_Stream_Event
      (Json_Data :        String;
     State     : in out Response_State;
     Handler   :        LLM.Providers.Event_Handler)
   is
      Root    : constant GNATCOLL.JSON.JSON_Value :=
         Parse_Json (Json_Data, "Invalid OpenAI streaming event");
      Choices : constant GNATCOLL.JSON.JSON_Array :=
         Get_Array_Field (Root, "choices");
   begin
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
         and then Root.Has_Field ("usage")
         and then Root.Get ("usage").Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         State.Tok_Usage := Parse_Usage (Root.Get ("usage"));
      end if;

      if GNATCOLL.JSON.Length (Choices) = 0 then
         return;
      end if;

      declare
         Choice      : constant GNATCOLL.JSON.JSON_Value :=
            GNATCOLL.JSON.Get (Choices, 1);
         Delta_Value : constant GNATCOLL.JSON.JSON_Value :=
            Get_Object_Field (Choice, "delta");
      begin
         if Has_String_Field (Choice, "finish_reason") then
            State.Stop := To_Stop_Reason (Choice.Get ("finish_reason").Get);
         end if;

         if Has_String_Field (Delta_Value, "reasoning") or else Has_String_Field (Delta_Value, "reasoning_content") then
            if not State.Thinking_Started then
               Emit_Update (Handler, LLM.Events.Thinking_Start);
               State.Thinking_Started := True;
            end if;

            Emit_Update
               (Handler    => Handler,
           Kind       => LLM.Events.Thinking_Delta,
           Delta_Text => Normalize_Thinking_Delta
                           (Get_String_Field (Delta_Value, "reasoning") & Get_String_Field (Delta_Value, "reasoning_content")));
         end if;

      declare
         Content : constant String := Get_String_Field (Delta_Value, "content");
      begin
         if State.Thinking_Started and then Content'Length > 0 then
            Emit_Update (Handler, LLM.Events.Thinking_End);
            State.Thinking_Started := False;
         end if;
         if not State.Text_Started then
            Emit_Update (Handler, LLM.Events.Text_Start);
            State.Text_Started := True;
         end if;

         if Content'Length > 0 then
            Emit_Update
               (Handler    => Handler,
                Kind       => LLM.Events.Text_Delta,
                Delta_Text => Content);
         end if;
      end;
         if Delta_Value.Kind = GNATCOLL.JSON.JSON_Object_Type
            and then Delta_Value.Has_Field ("tool_calls")
            and then Delta_Value.Get ("tool_calls").Kind
                   = GNATCOLL.JSON.JSON_Array_Type
         then
            if State.Thinking_Started then
               Emit_Update (Handler, LLM.Events.Thinking_End);
               State.Thinking_Started := False;
            end if;
            Process_Tool_Calls (Delta_Value, State, Handler);
         end if;
      end;
   end Process_Stream_Event;

   procedure Process_Stream_Data
      (Chunk   :        String;
     State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
      Event_Name : Unbounded_String;
      Event_Data : Unbounded_String;
   begin
      LLM.SSE.Feed (State.Parser, Chunk);

      while LLM.SSE.Next_Event (State.Parser, Event_Name, Event_Data) loop
         State.Saw_Stream_Event := True;

         declare
            Data : constant String := To_String (Event_Data);
         begin
            if Data = "[DONE]" then
               Finalize_Message (State, Handler);
            else
               Process_Stream_Event (Data, State, Handler);
            end if;
         end;
      end loop;
   end Process_Stream_Data;

   procedure Process_Non_Streaming_Response
      (Payload :        String;
     State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
      Root    : constant GNATCOLL.JSON.JSON_Value :=
         Parse_Json (Payload, "Invalid OpenAI response");
      Choices : constant GNATCOLL.JSON.JSON_Array :=
         Get_Array_Field (Root, "choices");
   begin
      if Root.Kind = GNATCOLL.JSON.JSON_Object_Type
         and then Root.Has_Field ("usage")
         and then Root.Get ("usage").Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         State.Tok_Usage := Parse_Usage (Root.Get ("usage"));
      end if;

      if GNATCOLL.JSON.Length (Choices) = 0 then
         Finalize_Message (State, Handler);
         return;
      end if;

      declare
         Choice  : constant GNATCOLL.JSON.JSON_Value :=
            GNATCOLL.JSON.Get (Choices, 1);
         Message : constant GNATCOLL.JSON.JSON_Value :=
            Get_Object_Field (Choice, "message");
         Content : constant String := Get_String_Field (Message, "content");
      begin
         if Has_String_Field (Choice, "finish_reason") then
            State.Stop := To_Stop_Reason (Choice.Get ("finish_reason").Get);
         end if;

         if Has_String_Field (Message, "reasoning") or else Has_String_Field (Message, "reasoning_content") then
            Emit_Update (Handler, LLM.Events.Thinking_Start);
            Emit_Update
               (Handler    => Handler,
           Kind       => LLM.Events.Thinking_Delta,
           Delta_Text => Get_String_Field (Message, "reasoning") & Get_String_Field (Message, "reasoning_content"));
            State.Thinking_Started := True;
         end if;

         if Content'Length > 0 then
            Emit_Update (Handler, LLM.Events.Text_Start);
            Emit_Update
               (Handler    => Handler,
           Kind       => LLM.Events.Text_Delta,
           Delta_Text => Content);
            State.Text_Started := True;
         end if;

         if Message.Kind = GNATCOLL.JSON.JSON_Object_Type
            and then Message.Has_Field ("tool_calls")
            and then Message.Get ("tool_calls").Kind
                   = GNATCOLL.JSON.JSON_Array_Type
         then
            if State.Thinking_Started then
               Emit_Update (Handler, LLM.Events.Thinking_End);
               State.Thinking_Started := False;
            end if;
            Process_Tool_Calls (Message, State, Handler);
         end if;
      end;

      Finalize_Message (State, Handler);
   end Process_Non_Streaming_Response;

   procedure Send_Request
      (P             : in out Provider'Class;
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
      begin
         Append (State.Raw_Response_Body, Data);

         if P.Use_Streaming then
            Process_Stream_Data (Data, State, Handler);
         end if;
      end On_Chunk;
   begin
      Emit_Agent_Start (Handler);
      Emit_Message_Start (Handler);

      LLM.HTTP.Add_Header (Headers, "Content-Type", "application/json");
      LLM.HTTP.Add_Header
         (Headers, "Authorization", "Bearer " & To_String (P.Api_Key));

      for Header of P.Extra_Headers loop
         LLM.HTTP.Add_Header
            (Headers,
         To_String (Header.Name),
         To_String (Header.Value));
      end loop;

      LLM.HTTP.Post
         (URL      => Endpoint_Url (To_String (P.Base_Url)),
       Headers  => Headers,
       Payload  => Request_Body,
       On_Chunk => On_Chunk'Access,
       Status   => Status);

      if Status /= 200 then
         raise Constraint_Error with
            "OpenAI chat completion failed with HTTP"
            & Natural'Image (Status)
            & ": "
            & To_String (State.Raw_Response_Body);
      end if;

      if not P.Use_Streaming then
         Process_Non_Streaming_Response
            (Payload => To_String (State.Raw_Response_Body),
         State   => State,
         Handler => Handler);
      elsif not State.Done then
         if not State.Saw_Stream_Event
            and then Length (State.Raw_Response_Body) > 0
         then
            LLM.SSE.Reset (State.Parser);
            Process_Stream_Data
               (Chunk   => To_String (State.Raw_Response_Body),
           State   => State,
           Handler => Handler);
         end if;

         if not State.Done then
            Finalize_Message (State, Handler);
         end if;
      end if;

      Emit_Agent_End (Handler);
      End_Event_Sent := True;
   exception
      when others =>
         if not End_Event_Sent then
            Emit_Agent_End (Handler);
         end if;
         raise;
   end Send_Request;

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
   begin
      Send_Request
         (P             => P,
          Model_Id      => Model_Id,
          System_Prompt => System_Prompt,
          Messages      => Messages,
          Tools_Json    => Tools_Json,
          Thinking      => Thinking,
          Max_Tokens    => Max_Tokens,
          Handler       => Handler);
   end Send;

end LLM.Providers.OpenAI_Completions;
