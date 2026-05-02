--  LLM.Providers.Anthropic_Messages body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Containers;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.SSE;

package body LLM.Providers.Anthropic_Messages is

   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;

   type Stream_Block_Kind is
      (No_Block,
     Thinking_Block,
     Text_Block,
     Tool_Use_Block);

   type Stream_Block_State is record
      Kind         : Stream_Block_Kind := No_Block;
      Started      : Boolean := False;
      Tool_Call_Id : Unbounded_String;
      Tool_Name    : Unbounded_String;
      Tool_Input   : Unbounded_String;
   end record;

   EMPTY_STREAM_BLOCK_STATE : constant Stream_Block_State :=
      (Kind         => No_Block,
     Started      => False,
     Tool_Call_Id => Null_Unbounded_String,
     Tool_Name    => Null_Unbounded_String,
     Tool_Input   => Null_Unbounded_String);

   package Stream_Block_State_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Natural,
     Element_Type => Stream_Block_State);

   type Response_State is record
      Parser            : LLM.SSE.Parser;
      Blocks            : Stream_Block_State_Vectors.Vector;
      Stop              : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Tok_Usage         : LLM.Types.Usage := (others => 0);
      Message_Started   : Boolean := False;
      Message_Ended     : Boolean := False;
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

   function Endpoint_Url (Base_Url : String) return String is
   begin
      if Base_Url'Length = 0 then
         return "/v1/messages";
      elsif Ada.Strings.Fixed.Index (Base_Url, "/v1/messages")
         = Base_Url'Last - 11
      then
         return Base_Url;
      elsif Base_Url (Base_Url'Last) = '/' then
         return Base_Url & "v1/messages";
      else
         return Base_Url & "/v1/messages";
      end if;
   end Endpoint_Url;

   function Uses_X_Api_Key (Base_Url : String) return Boolean is
      Lower_Base_Url : constant String :=
         Ada.Characters.Handling.To_Lower (Base_Url);
   begin
      return Ada.Strings.Fixed.Index (Lower_Base_Url, "anthropic.com") > 0;
   end Uses_X_Api_Key;

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

   function Thinking_Budget
      (Thinking : LLM.Providers.Thinking_Level) return Natural
   is
   begin
      case Thinking is
         when LLM.Providers.Off =>
            return 0;
         when LLM.Providers.Minimal =>
            return 1_024;
         when LLM.Providers.Low =>
            return 2_048;
         when LLM.Providers.Medium =>
            return 8_192;
         when LLM.Providers.High =>
            return 16_384;
         when LLM.Providers.X_High =>
            return 32_768;
      end case;
   end Thinking_Budget;

   function To_Stop_Reason
      (Stop_Reason : String) return LLM.Types.Stop_Reason
   is
   begin
      if Stop_Reason = "end_turn" then
         return LLM.Types.Stop;
      elsif Stop_Reason = "max_tokens" then
         return LLM.Types.Length;
      elsif Stop_Reason = "tool_use" then
         return LLM.Types.Tool_Use;
      elsif Stop_Reason = "error" then
         return LLM.Types.Error_Stop;
      else
         return LLM.Types.Unknown_Stop;
      end if;
   end To_Stop_Reason;

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
       Content_Index => Content_Index,
       Tool_Call_Id  => To_Unbounded_String (Tool_Call_Id),
       Tool_Name     => To_Unbounded_String (Tool_Name));
   begin
      Emit (Handler, Event);
   end Emit_Update;

   procedure Append_Text_Content
      (Content : in out GNATCOLL.JSON.JSON_Array;
     Text    :        String)
   is
      Item : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Item.Set_Field ("type", "text");
      Item.Set_Field ("text", Text);
      GNATCOLL.JSON.Append (Content, Item);
   end Append_Text_Content;

   procedure Append_Tool_Use_Content
      (Content : in out GNATCOLL.JSON.JSON_Array;
     Block   :        LLM.Types.Content_Block)
   is
      Item  : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
      Input : constant GNATCOLL.JSON.JSON_Value :=
         (if Length (Block.Arguments_Json) = 0
       then GNATCOLL.JSON.Create_Object
       else Parse_Json
         (To_String (Block.Arguments_Json),
               "Invalid Anthropic tool input JSON"));
   begin
      if Input.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         raise Constraint_Error with
            "Invalid Anthropic tool input JSON: expected object";
      end if;

      Item.Set_Field ("type", "tool_use");
      Item.Set_Field ("id", To_String (Block.Tool_Call_Id));
      Item.Set_Field ("name", To_String (Block.Tool_Name));
      Item.Set_Field ("input", Input);
      GNATCOLL.JSON.Append (Content, Item);
   end Append_Tool_Use_Content;

   procedure Append_Tool_Result_Content
      (Content : in out GNATCOLL.JSON.JSON_Array;
     Block   :        LLM.Types.Content_Block)
   is
      Item : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
   begin
      Item.Set_Field ("type", "tool_result");
      Item.Set_Field ("tool_use_id", To_String (Block.Result_Id));
      Item.Set_Field ("content", To_String (Block.Result_Text));
      GNATCOLL.JSON.Append (Content, Item);
   end Append_Tool_Result_Content;

   procedure Append_Message
      (Messages : in out GNATCOLL.JSON.JSON_Array;
     Msg      :        LLM.Types.Message)
   is
      Message : constant GNATCOLL.JSON.JSON_Value := GNATCOLL.JSON.Create_Object;
      Content : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      case Msg.Role is
         when LLM.Types.User =>
            Message.Set_Field ("role", "user");

            for Block of Msg.Content loop
               case Block.Kind is
                  when LLM.Types.Text_Block =>
                     Append_Text_Content (Content, To_String (Block.Text));
                  when others =>
                     null;
               end case;
            end loop;
         when LLM.Types.Assistant =>
            Message.Set_Field ("role", "assistant");

            for Block of Msg.Content loop
               case Block.Kind is
                  when LLM.Types.Text_Block =>
                     Append_Text_Content (Content, To_String (Block.Text));
                  when LLM.Types.Tool_Call_Block =>
                     Append_Tool_Use_Content (Content, Block);
                  when others =>
                     null;
               end case;
            end loop;
         when LLM.Types.Tool_Result =>
            Message.Set_Field ("role", "user");

            for Block of Msg.Content loop
               case Block.Kind is
                  when LLM.Types.Text_Block =>
                     Append_Text_Content (Content, To_String (Block.Text));
                  when LLM.Types.Tool_Result_Block =>
                     Append_Tool_Result_Content (Content, Block);
                  when others =>
                     null;
               end case;
            end loop;
      end case;

      Message.Set_Field ("content", Content);
      GNATCOLL.JSON.Append (Messages, Message);
   end Append_Message;

   function Build_Request_Body
      (P             : Provider;
     Model_Id      : String;
     System_Prompt : String;
     Messages      : LLM.Types.Message_Vectors.Vector;
     Tools_Json    : String;
     Thinking      : LLM.Providers.Thinking_Level;
     Max_Tokens    : Positive) return String
   is
      pragma Unreferenced (P);

      Request      : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
      Request_Msgs : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Tools_Read   : GNATCOLL.JSON.Read_Result;
      Budget       : constant Natural := Thinking_Budget (Thinking);
   begin
      Request.Set_Field ("model", Model_Id);
      Request.Set_Field ("stream", True);
      Request.Set_Field ("max_tokens", Integer (Max_Tokens));

      if System_Prompt'Length > 0 then
         Request.Set_Field ("system", System_Prompt);
      end if;

      for Msg of Messages loop
         Append_Message (Request_Msgs, Msg);
      end loop;

      Request.Set_Field ("messages", Request_Msgs);

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
               Tools_Array : constant GNATCOLL.JSON.JSON_Array :=
                  Tools_Read.Value.Get;
            begin
               if GNATCOLL.JSON.Length (Tools_Array) > 0 then
                  Request.Set_Field ("tools", Tools_Array);
               end if;
            end;
         end if;
      end if;

      if Budget > 0 then
         declare
            Thinking_Object : constant GNATCOLL.JSON.JSON_Value :=
               GNATCOLL.JSON.Create_Object;
         begin
            Thinking_Object.Set_Field ("type", "enabled");
            Thinking_Object.Set_Field ("budget_tokens", Integer (Budget));
            Request.Set_Field ("thinking", Thinking_Object);
         end;
      end if;

      return GNATCOLL.JSON.Write (Request);
   end Build_Request_Body;

   procedure Ensure_Block_Slot
      (Blocks : in out Stream_Block_State_Vectors.Vector;
     Index  :        Natural)
   is
   begin
      while Blocks.Length <= Ada.Containers.Count_Type (Index) loop
         Blocks.Append (EMPTY_STREAM_BLOCK_STATE);
      end loop;
   end Ensure_Block_Slot;

   procedure Finish_Block
      (State   : in out Response_State;
     Index   :        Natural;
     Handler :        LLM.Providers.Event_Handler)
   is
   begin
      if State.Blocks.Is_Empty or else Index > State.Blocks.Last_Index then
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
            when Text_Block =>
               Emit_Update (Handler, LLM.Events.Text_End);
            when Tool_Use_Block =>
               Emit_Update
                  (Handler       => Handler,
             Kind          => LLM.Events.Tool_Call_End,
             Delta_Text    => To_String (Block.Tool_Input),
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
         for Index in State.Blocks.First_Index .. State.Blocks.Last_Index loop
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

   procedure Process_Message_Start
      (Root    :        GNATCOLL.JSON.JSON_Value;
     State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
      Message : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Root, "message");
      Usage   : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Message, "usage");
   begin
      if not State.Message_Started then
         Emit_Message_Start (Handler);
         State.Message_Started := True;
      end if;

      State.Tok_Usage.Input := Get_Natural_Field
         (Usage, "input_tokens", State.Tok_Usage.Input);
      State.Tok_Usage.Output := Get_Natural_Field
         (Usage, "output_tokens", State.Tok_Usage.Output);
      State.Tok_Usage.Cache_Read := Get_Natural_Field
         (Usage, "cache_read_input_tokens", State.Tok_Usage.Cache_Read);
      State.Tok_Usage.Cache_Write := Get_Natural_Field
         (Usage,
       "cache_creation_input_tokens",
       State.Tok_Usage.Cache_Write);
   end Process_Message_Start;

   procedure Process_Content_Block_Start
      (Root    :        GNATCOLL.JSON.JSON_Value;
     State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
      Index         : constant Natural := Get_Natural_Field (Root, "index", 0);
      Content_Block : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Root, "content_block");
      Block_Type    : constant String :=
         Get_String_Field (Content_Block, "type");
   begin
      Ensure_Block_Slot (State.Blocks, Index);

      declare
         Block      : Stream_Block_State := State.Blocks.Element (Index);
         Input      : constant GNATCOLL.JSON.JSON_Value :=
            Get_Object_Field (Content_Block, "input");
         Input_Json : constant String :=
            (if Input.Kind = GNATCOLL.JSON.JSON_Object_Type
         then GNATCOLL.JSON.Write (Input)
         else "");
      begin
         if Block_Type = "thinking" then
            Block.Kind := Thinking_Block;
            Block.Started := True;
            Emit_Update (Handler, LLM.Events.Thinking_Start);
         elsif Block_Type = "text" then
            Block.Kind := Text_Block;
            Block.Started := True;
            Emit_Update (Handler, LLM.Events.Text_Start);
         elsif Block_Type = "tool_use" then
            Block.Kind := Tool_Use_Block;
            Block.Started := True;
            Block.Tool_Call_Id := To_Unbounded_String
               (Get_String_Field (Content_Block, "id"));
            Block.Tool_Name := To_Unbounded_String
               (Get_String_Field (Content_Block, "name"));

            if Input_Json /= "{}" then
               Block.Tool_Input := To_Unbounded_String (Input_Json);
            end if;

            Emit_Update
               (Handler       => Handler,
           Kind          => LLM.Events.Tool_Call_Start,
           Content_Index => Index,
           Tool_Call_Id  => To_String (Block.Tool_Call_Id),
           Tool_Name     => To_String (Block.Tool_Name));
         end if;

         State.Blocks.Replace_Element (Index, Block);
      end;
   end Process_Content_Block_Start;

   procedure Process_Content_Block_Delta
      (Root    :        GNATCOLL.JSON.JSON_Value;
     State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
      Index       : constant Natural := Get_Natural_Field (Root, "index", 0);
      Delta_Value : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Root, "delta");
      Delta_Type  : constant String := Get_String_Field (Delta_Value, "type");
   begin
      Ensure_Block_Slot (State.Blocks, Index);

      declare
         Block    : Stream_Block_State := State.Blocks.Element (Index);
         Fragment : constant String :=
            (if Delta_Type = "thinking_delta"
         then Get_String_Field (Delta_Value, "thinking")
         elsif Delta_Type = "text_delta"
         then Get_String_Field (Delta_Value, "text")
         elsif Delta_Type = "input_json_delta"
         then Get_String_Field (Delta_Value, "partial_json")
         else "");
      begin
         if Delta_Type = "thinking_delta" then
            Emit_Update
               (Handler    => Handler,
           Kind       => LLM.Events.Thinking_Delta,
           Delta_Text => Fragment);
         elsif Delta_Type = "text_delta" then
            Emit_Update
               (Handler    => Handler,
           Kind       => LLM.Events.Text_Delta,
           Delta_Text => Fragment);
         elsif Delta_Type = "input_json_delta" then
            Append (Block.Tool_Input, Fragment);
            Emit_Update
               (Handler       => Handler,
           Kind          => LLM.Events.Tool_Call_Delta,
           Delta_Text    => Fragment,
           Content_Index => Index,
           Tool_Call_Id  => To_String (Block.Tool_Call_Id),
           Tool_Name     => To_String (Block.Tool_Name));
            State.Blocks.Replace_Element (Index, Block);
         end if;
      end;
   end Process_Content_Block_Delta;

   procedure Process_Message_Delta
      (Root  :        GNATCOLL.JSON.JSON_Value;
     State : in out Response_State)
   is
      Delta_Value : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Root, "delta");
      Usage       : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Root, "usage");
   begin
      if Has_String_Field (Delta_Value, "stop_reason") then
         State.Stop := To_Stop_Reason (Delta_Value.Get ("stop_reason").Get);
      end if;

      State.Tok_Usage.Output := Get_Natural_Field
         (Usage, "output_tokens", State.Tok_Usage.Output);
   end Process_Message_Delta;

   procedure Process_Stream_Event
      (Event_Name :        String;
     Event_Data :        String;
     State      : in out Response_State;
     Handler    :        LLM.Providers.Event_Handler)
   is
      Root : constant GNATCOLL.JSON.JSON_Value :=
         Parse_Json (Event_Data, "Invalid Anthropic streaming event");
   begin
      if Event_Name = "message_start" then
         Process_Message_Start (Root, State, Handler);
      elsif Event_Name = "content_block_start" then
         Process_Content_Block_Start (Root, State, Handler);
      elsif Event_Name = "content_block_delta" then
         Process_Content_Block_Delta (Root, State, Handler);
      elsif Event_Name = "content_block_stop" then
         Finish_Block
            (State   => State,
         Index   => Get_Natural_Field (Root, "index", 0),
         Handler => Handler);
      elsif Event_Name = "message_delta" then
         Process_Message_Delta (Root, State);
      elsif Event_Name = "message_stop" then
         Finalize_Message (State, Handler);
      end if;
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
         Process_Stream_Event
            (Event_Name => To_String (Event_Name),
         Event_Data => To_String (Event_Data),
         State      => State,
         Handler    => Handler);
      end loop;
   end Process_Stream_Data;

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
         Process_Stream_Data (Data, State, Handler);
      end On_Chunk;
   begin
      Emit_Agent_Start (Handler);

      LLM.HTTP.Add_Header (Headers, "Content-Type", "application/json");
      LLM.HTTP.Add_Header (Headers, "anthropic-version", "2023-06-01");
      LLM.HTTP.Add_Header
         (Headers,
       "anthropic-beta",
       "interleaved-thinking-2025-05-14");

      if Length (P.Api_Key) > 0 then
         if Uses_X_Api_Key (To_String (P.Base_Url)) then
            LLM.HTTP.Add_Header (Headers, "x-api-key", To_String (P.Api_Key));
         else
            LLM.HTTP.Add_Header
               (Headers, "Authorization", "Bearer " & To_String (P.Api_Key));
         end if;
      end if;

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
            "Anthropic message request failed with HTTP"
            & Natural'Image (Status)
            & ": "
            & To_String (State.Raw_Response_Body);
      end if;

      if not State.Message_Ended then
         Finalize_Message (State, Handler);
      end if;

      Emit_Agent_End (Handler);
      End_Event_Sent := True;
   exception
      when others =>
         if not End_Event_Sent then
            Emit_Agent_End (Handler);
         end if;
         raise;
   end Send;

end LLM.Providers.Anthropic_Messages;
