--  LLM.Providers.OpenAI_Responses body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Containers;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.SSE;

package body LLM.Providers.OpenAI_Responses is

   use type Ada.Containers.Count_Type;
   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Content_Block_Kind;
   use type LLM.Types.Stop_Reason;

   type Tool_Call_State is record
      Seen           : Boolean := False;
      Tool_Call_Id   : Unbounded_String;
      Item_Id        : Unbounded_String;
      Tool_Name      : Unbounded_String;
      Arguments_Json : Unbounded_String;
   end record;

   package Tool_Call_State_Vectors is new Ada.Containers.Vectors
      (Index_Type   => Natural,
     Element_Type => Tool_Call_State);

   EMPTY_TOOL_CALL_STATE : constant Tool_Call_State :=
      (Seen           => False,
     Tool_Call_Id   => Null_Unbounded_String,
     Item_Id        => Null_Unbounded_String,
     Tool_Name      => Null_Unbounded_String,
     Arguments_Json => Null_Unbounded_String);

   type Response_State is record
      Parser            : LLM.SSE.Parser;
      Text_Started      : Boolean := False;
      Thinking_Started  : Boolean := False;
      Stop              : LLM.Types.Stop_Reason := LLM.Types.Unknown_Stop;
      Saw_Function_Call : Boolean := False;
      Tok_Usage         : LLM.Types.Usage := (others => 0);
      Tool_Calls        : Tool_Call_State_Vectors.Vector;
      Done              : Boolean := False;
      Saw_Stream_Event  : Boolean := False;
      Raw_Response_Body : Unbounded_String;
      Thinking_Item_Id  : Unbounded_String;
      Encrypted_Content : Unbounded_String;
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
         return "/responses";
      elsif Base_Url (Base_Url'Last) = '/' then
         return Base_Url & "responses";
      else
         return Base_Url & "/responses";
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

   function Parse_Usage
      (Value : GNATCOLL.JSON.JSON_Value) return LLM.Types.Usage
   is
      Input_Det  : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Value, "input_tokens_details");
      Output_Det : constant GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Value, "output_tokens_details");
   begin
      return
         (Input       => Get_Natural_Field (Value, "input_tokens"),
       Output      => Get_Natural_Field (Value, "output_tokens"),
       Cache_Read  => Get_Natural_Field (Input_Det, "cached_tokens"),
       Cache_Write => Get_Natural_Field (Input_Det, "cache_write_tokens"),
       Thinking    => Get_Natural_Field (Output_Det, "reasoning_tokens"));
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
     Signature     : String := "";
     Content_Index : Natural := 0;
     Tool_Call_Id  : String := "";
     Tool_Name     : String := "")
   is
      Event : constant LLM.Events.Message_Update_Event :=
         (LLM.Events.Agent_Event with
       Kind          => Kind,
       Delta_Text    => To_Unbounded_String (Delta_Text),
       Signature     => To_Unbounded_String (Signature),
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

   function Make_Cache_Breakpoint return GNATCOLL.JSON.JSON_Value is
      Marker : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
   begin
      Marker.Set_Field ("mode", "explicit");
      return Marker;
   end Make_Cache_Breakpoint;

   function Pack_Reasoning_Signature
      (Item_Id   : String;
       Encrypted : String) return String
   is
      Packed : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
   begin
      if Item_Id'Length = 0 and then Encrypted'Length = 0 then
         return "";
      end if;

      if Item_Id'Length > 0 then
         Packed.Set_Field ("id", Item_Id);
      end if;
      if Encrypted'Length > 0 then
         Packed.Set_Field ("encrypted_content", Encrypted);
      end if;
      return GNATCOLL.JSON.Write (Packed);
   end Pack_Reasoning_Signature;

   function Unpack_Reasoning_Signature
      (Signature : String;
       Field     : String) return String
   is
      Parsed : constant GNATCOLL.JSON.Read_Result :=
         GNATCOLL.JSON.Read (Signature);
   begin
      if Parsed.Success
        and then Parsed.Value.Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         return Get_String_Field (Parsed.Value, Field);
      end if;

      --  Preserve compatibility with ordinary opaque signatures.
      if Field = "encrypted_content" then
         return Signature;
      end if;
      return "";
   end Unpack_Reasoning_Signature;

   procedure Append_Text_Part
      (Content    : in out GNATCOLL.JSON.JSON_Array;
     Part_Type  :        String;
     Text       :        String;
     Breakpoint :        Boolean)
   is
      Part : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
   begin
      Part.Set_Field ("type", Part_Type);
      Part.Set_Field ("text", Text);
      if Breakpoint then
         Part.Set_Field ("prompt_cache_breakpoint", Make_Cache_Breakpoint);
      end if;
      GNATCOLL.JSON.Append (Content, Part);
   end Append_Text_Part;

   procedure Append_User_Item
      (Input      : in out GNATCOLL.JSON.JSON_Array;
     Msg        :        LLM.Types.Message;
     Breakpoint :        Boolean)
   is
      Item    : constant GNATCOLL.JSON.JSON_Value :=
         GNATCOLL.JSON.Create_Object;
      Content : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Item.Set_Field ("type", "message");
      Item.Set_Field ("role", "user");
      Append_Text_Part
         (Content, "input_text", Message_Text (Msg), Breakpoint);
      Item.Set_Field ("content", Content);
      GNATCOLL.JSON.Append (Input, Item);
   end Append_User_Item;

   procedure Append_Assistant_Items
      (Input : in out GNATCOLL.JSON.JSON_Array;
     Msg   :        LLM.Types.Message)
   is
      Text : constant String := Message_Text (Msg);
   begin
      for Block of Msg.Content loop
         case Block.Kind is
            when LLM.Types.Thinking_Block =>
               declare
                  Item      : constant GNATCOLL.JSON.JSON_Value :=
                     GNATCOLL.JSON.Create_Object;
                  Summary   : GNATCOLL.JSON.JSON_Array :=
                     GNATCOLL.JSON.Empty_Array;
                  Thinking  : constant String := To_String (Block.Thinking);
                  Item_Id   : constant String :=
                     Unpack_Reasoning_Signature
                       (To_String (Block.Signature), "id");
                  Encrypted : constant String :=
                     Unpack_Reasoning_Signature
                       (To_String (Block.Signature), "encrypted_content");
               begin
                  --  Signature holds encrypted_content when the provider
                  --  returned it.  Visible thinking text is replayed as
                  --  a summary_text part.  Item ids are not stored
                  --  separately; encrypted_content is sufficient for
                  --  later-turn replay.
                  Item.Set_Field ("type", "reasoning");
                  if Item_Id'Length > 0 then
                     Item.Set_Field ("id", Item_Id);
                  end if;
                  if Encrypted'Length > 0 then
                     Item.Set_Field ("encrypted_content", Encrypted);
                  end if;
                  if Thinking'Length > 0 then
                     declare
                        Part : constant GNATCOLL.JSON.JSON_Value :=
                           GNATCOLL.JSON.Create_Object;
                     begin
                        Part.Set_Field ("type", "summary_text");
                        Part.Set_Field ("text", Thinking);
                        GNATCOLL.JSON.Append (Summary, Part);
                     end;
                  end if;
                  Item.Set_Field ("summary", Summary);
                  GNATCOLL.JSON.Append (Input, Item);
               end;
            when LLM.Types.Tool_Call_Block =>
               declare
                  Item : constant GNATCOLL.JSON.JSON_Value :=
                     GNATCOLL.JSON.Create_Object;
               begin
                  Item.Set_Field ("type", "function_call");
                  Item.Set_Field
                     ("call_id", To_String (Block.Tool_Call_Id));
                  Item.Set_Field ("name", To_String (Block.Tool_Name));
                  Item.Set_Field
                     ("arguments", To_String (Block.Arguments_Json));
                  GNATCOLL.JSON.Append (Input, Item);
               end;
            when others =>
               null;
         end case;
      end loop;

      if Text'Length > 0 then
         declare
            Item    : constant GNATCOLL.JSON.JSON_Value :=
               GNATCOLL.JSON.Create_Object;
         begin
            Item.Set_Field ("type", "message");
            Item.Set_Field ("role", "assistant");
            Item.Set_Field ("content", Text);
            GNATCOLL.JSON.Append (Input, Item);
         end;
      end if;
   end Append_Assistant_Items;

   procedure Append_Tool_Result_Item
      (Input      : in out GNATCOLL.JSON.JSON_Array;
     Msg        :        LLM.Types.Message;
     Breakpoint :        Boolean)
   is
      Item         : constant GNATCOLL.JSON.JSON_Value :=
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
                  Media_Type := Block.Media_Type;
               end if;
               Append (Result_Text, To_String (Block.Result_Text));
            when LLM.Types.Text_Block =>
               Append (Result_Text, To_String (Block.Text));
            when others =>
               null;
         end case;
      end loop;

      Item.Set_Field ("type", "function_call_output");
      Item.Set_Field ("call_id", To_String (Tool_Call_Id));

      if Length (Media_Type) > 0 then
         declare
            Output     : GNATCOLL.JSON.JSON_Array :=
               GNATCOLL.JSON.Empty_Array;
            Image_Part : constant GNATCOLL.JSON.JSON_Value :=
               GNATCOLL.JSON.Create_Object;
         begin
            Image_Part.Set_Field ("type", "input_image");
            Image_Part.Set_Field
               ("image_url",
             "data:" & To_String (Media_Type) & ";base64,"
             & To_String (Result_Text));
            if Breakpoint then
               Image_Part.Set_Field
                  ("prompt_cache_breakpoint", Make_Cache_Breakpoint);
            end if;
            GNATCOLL.JSON.Append (Output, Image_Part);
            Item.Set_Field ("output", Output);
         end;
      else
         if Breakpoint then
            declare
               Output : GNATCOLL.JSON.JSON_Array :=
                  GNATCOLL.JSON.Empty_Array;
            begin
               Append_Text_Part
                  (Output, "input_text", To_String (Result_Text), True);
               Item.Set_Field ("output", Output);
            end;
         else
            Item.Set_Field ("output", To_String (Result_Text));
         end if;
      end if;

      GNATCOLL.JSON.Append (Input, Item);
   end Append_Tool_Result_Item;

   function Last_Cacheable_Index
      (Messages : LLM.Types.Message_Vectors.Vector) return Integer
   is
   begin
      for J in reverse Messages.First_Index .. Messages.Last_Index loop
         case Messages.Element (J).Role is
            when LLM.Types.User
               | LLM.Types.Compaction_Summary
               | LLM.Types.Tool_Result =>
               return J;
            when others =>
               null;
         end case;
      end loop;

      return Integer'First;
   end Last_Cacheable_Index;

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
      Input      : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
      Tools_Read : GNATCOLL.JSON.Read_Result;
      Cache_At   : constant Integer := Last_Cacheable_Index (Messages);
      Include    : GNATCOLL.JSON.JSON_Array := GNATCOLL.JSON.Empty_Array;
   begin
      Request.Set_Field ("model", Model_Id);
      Request.Set_Field ("stream", P.Use_Streaming);
      Request.Set_Field ("max_output_tokens", Integer (Max_Tokens));

      if System_Prompt'Length > 0 then
         Request.Set_Field ("instructions", System_Prompt);
      end if;

      GNATCOLL.JSON.Append
         (Include, GNATCOLL.JSON.Create ("reasoning.encrypted_content"));
      Request.Set_Field ("include", Include);

      for J in Messages.First_Index .. Messages.Last_Index loop
         declare
            Msg        : constant LLM.Types.Message := Messages.Element (J);
            Breakpoint : constant Boolean := J = Cache_At;
         begin
            case Msg.Role is
               when LLM.Types.User | LLM.Types.Compaction_Summary =>
                  Append_User_Item (Input, Msg, Breakpoint);
               when LLM.Types.Assistant =>
                  Append_Assistant_Items (Input, Msg);
               when LLM.Types.Tool_Result =>
                  Append_Tool_Result_Item (Input, Msg, Breakpoint);
            end case;
         end;
      end loop;

      Request.Set_Field ("input", Input);

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
                  declare
                     Cached_Tools : GNATCOLL.JSON.JSON_Array :=
                        GNATCOLL.JSON.Empty_Array;
                     Last         : constant Natural :=
                        GNATCOLL.JSON.Length (Raw_Tools);
                  begin
                     for I in 1 .. Last loop
                        declare
                           Item : constant GNATCOLL.JSON.JSON_Value :=
                              GNATCOLL.JSON.Get (Raw_Tools, I);
                        begin
                           if I = Last then
                              Item.Set_Field
                                 ("prompt_cache_breakpoint",
                               Make_Cache_Breakpoint);
                           end if;
                           GNATCOLL.JSON.Append (Cached_Tools, Item);
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

   function Find_Tool_Index_By_Item
      (States  : Tool_Call_State_Vectors.Vector;
     Item_Id : String) return Integer
   is
   begin
      if Item_Id'Length = 0 then
         return Integer'First;
      end if;

      for Index in States.First_Index .. States.Last_Index loop
         if To_String (States.Element (Index).Item_Id) = Item_Id then
            return Index;
         end if;
      end loop;

      return Integer'First;
   end Find_Tool_Index_By_Item;

   procedure Close_Thinking
      (State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
   begin
      if State.Thinking_Started then
         Emit_Update
            (Handler   => Handler,
          Kind      => LLM.Events.Thinking_End,
          Signature => Pack_Reasoning_Signature
            (To_String (State.Thinking_Item_Id),
             To_String (State.Encrypted_Content)));
         State.Thinking_Started := False;
      end if;
   end Close_Thinking;

   procedure Close_Text
      (State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
   begin
      if State.Text_Started then
         Emit_Update (Handler, LLM.Events.Text_End);
         State.Text_Started := False;
      end if;
   end Close_Text;

   procedure Note_Function_Call
      (State   : in out Response_State;
     Item    :        GNATCOLL.JSON.JSON_Value;
     Handler :        LLM.Providers.Event_Handler)
   is
      Call_Id : constant String := Get_String_Field (Item, "call_id");
      Name    : constant String := Get_String_Field (Item, "name");
      Item_Id : constant String := Get_String_Field (Item, "id");
      Args    : constant String := Get_String_Field (Item, "arguments");
      Index   : Integer := Find_Tool_Index_By_Item (State.Tool_Calls, Item_Id);
   begin
      State.Saw_Function_Call := True;
      Close_Thinking (State, Handler);
      Close_Text (State, Handler);

      if Index < State.Tool_Calls.First_Index then
         Index :=
            (if State.Tool_Calls.Is_Empty
             then 0
             else State.Tool_Calls.Last_Index + 1);
         Ensure_Tool_Call_Slot (State.Tool_Calls, Index);
      end if;

      declare
         Tool_State : Tool_Call_State := State.Tool_Calls.Element (Index);
      begin
         if Call_Id'Length > 0 then
            Tool_State.Tool_Call_Id := To_Unbounded_String (Call_Id);
         end if;
         if Item_Id'Length > 0 then
            Tool_State.Item_Id := To_Unbounded_String (Item_Id);
         end if;
         if Name'Length > 0 then
            Tool_State.Tool_Name := To_Unbounded_String (Name);
         end if;
         if Args'Length > 0 then
            Tool_State.Arguments_Json := To_Unbounded_String (Args);
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

         State.Tool_Calls.Replace_Element (Index, Tool_State);
      end;
   end Note_Function_Call;

   procedure Note_Function_Arguments_Delta
      (State   : in out Response_State;
     Root    :        GNATCOLL.JSON.JSON_Value;
     Handler :        LLM.Providers.Event_Handler)
   is
      Item_Id : constant String := Get_String_Field (Root, "item_id");
      Arg_Delta_Value : constant String := Get_String_Field (Root, "delta");
      Index   : Integer := Find_Tool_Index_By_Item (State.Tool_Calls, Item_Id);
   begin
      if Index < State.Tool_Calls.First_Index then
         Index :=
            (if State.Tool_Calls.Is_Empty
             then 0
             else State.Tool_Calls.Last_Index);
         Ensure_Tool_Call_Slot (State.Tool_Calls, Index);
      end if;

      declare
         Tool_State : Tool_Call_State := State.Tool_Calls.Element (Index);
      begin
         if Item_Id'Length > 0
           and then Length (Tool_State.Item_Id) = 0
         then
            Tool_State.Item_Id := To_Unbounded_String (Item_Id);
         end if;
         if Arg_Delta_Value'Length > 0 then
            Append (Tool_State.Arguments_Json, Arg_Delta_Value);
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
         if Arg_Delta_Value'Length > 0 then
            Emit_Update
               (Handler       => Handler,
             Kind          => LLM.Events.Tool_Call_Delta,
             Delta_Text    => Arg_Delta_Value,
             Content_Index => Index,
             Tool_Call_Id  => To_String (Tool_State.Tool_Call_Id),
             Tool_Name     => To_String (Tool_State.Tool_Name));
         end if;
         State.Tool_Calls.Replace_Element (Index, Tool_State);
      end;
   end Note_Function_Arguments_Delta;

   procedure Apply_Usage_And_Status
      (State : in out Response_State;
     Root  :        GNATCOLL.JSON.JSON_Value)
   is
      Response_Obj : GNATCOLL.JSON.JSON_Value :=
         Get_Object_Field (Root, "response");
      Status       : Unbounded_String;
      Incomplete   : GNATCOLL.JSON.JSON_Value;
      Reason       : Unbounded_String;
   begin
      if Response_Obj.Kind /= GNATCOLL.JSON.JSON_Object_Type then
         Response_Obj := Root;
      end if;

      if Response_Obj.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Response_Obj.Has_Field ("usage")
        and then Response_Obj.Get ("usage").Kind
          = GNATCOLL.JSON.JSON_Object_Type
      then
         State.Tok_Usage := Parse_Usage (Response_Obj.Get ("usage"));
      elsif Root.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Root.Has_Field ("usage")
        and then Root.Get ("usage").Kind = GNATCOLL.JSON.JSON_Object_Type
      then
         State.Tok_Usage := Parse_Usage (Root.Get ("usage"));
      end if;

      Status := To_Unbounded_String (Get_String_Field (Response_Obj, "status"));
      Incomplete := Get_Object_Field (Response_Obj, "incomplete_details");
      Reason :=
         To_Unbounded_String (Get_String_Field (Incomplete, "reason"));

      if To_String (Status) = "failed" then
         State.Stop := LLM.Types.Error_Stop;
      elsif To_String (Status) = "incomplete" then
         if To_String (Reason) = "max_output_tokens" then
            State.Stop := LLM.Types.Length;
         else
            State.Stop := LLM.Types.Error_Stop;
         end if;
      elsif To_String (Status) = "completed" then
         if State.Saw_Function_Call then
            State.Stop := LLM.Types.Tool_Use;
         else
            State.Stop := LLM.Types.Stop;
         end if;
      end if;
   end Apply_Usage_And_Status;

   procedure Finalize_Message
      (State   : in out Response_State;
     Handler :        LLM.Providers.Event_Handler)
   is
   begin
      Close_Thinking (State, Handler);
      Close_Text (State, Handler);

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

      if State.Saw_Function_Call
        and then State.Stop = LLM.Types.Stop
      then
         State.Stop := LLM.Types.Tool_Use;
      end if;

      Emit_Message_End
         (Handler   => Handler,
       Stop      => State.Stop,
       Tok_Usage => State.Tok_Usage);
      State.Done := True;
   end Finalize_Message;

   procedure Process_Output_Item
      (State   : in out Response_State;
     Item    :        GNATCOLL.JSON.JSON_Value;
     Handler :        LLM.Providers.Event_Handler)
   is
      Item_Type : constant String := Get_String_Field (Item, "type");
   begin
      if Item_Type = "function_call" then
         Note_Function_Call (State, Item, Handler);
      elsif Item_Type = "reasoning" then
         declare
            Encrypted : constant String :=
               Get_String_Field (Item, "encrypted_content");
            Item_Id   : constant String := Get_String_Field (Item, "id");
         begin
            if Encrypted'Length > 0 then
               State.Encrypted_Content := To_Unbounded_String (Encrypted);
            end if;
            if Item_Id'Length > 0 then
               State.Thinking_Item_Id := To_Unbounded_String (Item_Id);
            end if;
         end;
      elsif Item_Type = "message" then
         --  The text delta events already carry streamed message content;
         --  ignore the same content repeated by output_item.done and
         --  response.completed.
         if State.Text_Started then
            return;
         end if;

         declare
            Content : constant GNATCOLL.JSON.JSON_Array :=
               Get_Array_Field (Item, "content");
         begin
            for I in 1 .. GNATCOLL.JSON.Length (Content) loop
               declare
                  Part      : constant GNATCOLL.JSON.JSON_Value :=
                     GNATCOLL.JSON.Get (Content, I);
                  Part_Type : constant String :=
                     Get_String_Field (Part, "type");
                  Text      : constant String :=
                     Get_String_Field (Part, "text");
               begin
                  if (Part_Type = "output_text" or else Part_Type = "")
                    and then Text'Length > 0
                  then
                     Close_Thinking (State, Handler);
                     if not State.Text_Started then
                        Emit_Update (Handler, LLM.Events.Text_Start);
                        State.Text_Started := True;
                     end if;
                     Emit_Update
                        (Handler    => Handler,
                      Kind       => LLM.Events.Text_Delta,
                      Delta_Text => Text);
                  elsif Part_Type = "refusal" then
                     State.Stop := LLM.Types.Error_Stop;
                  end if;
               end;
            end loop;
         end;
      end if;
   end Process_Output_Item;

   procedure Process_Stream_Event
      (Json_Data :        String;
     State     : in out Response_State;
     Handler   :        LLM.Providers.Event_Handler)
   is
      Root      : constant GNATCOLL.JSON.JSON_Value :=
         Parse_Json (Json_Data, "Invalid OpenAI Responses streaming event");
      Event_Typ : constant String := Get_String_Field (Root, "type");
   begin
      if Event_Typ = "response.created"
        or else Event_Typ = "response.in_progress"
      then
         Apply_Usage_And_Status (State, Root);
      elsif Event_Typ = "response.output_item.added"
        or else Event_Typ = "response.output_item.done"
      then
         Process_Output_Item
            (State, Get_Object_Field (Root, "item"), Handler);
      elsif Event_Typ = "response.output_text.delta" then
         declare
            Text_Delta_Value : constant String := Get_String_Field (Root, "delta");
         begin
            Close_Thinking (State, Handler);
            if not State.Text_Started then
               Emit_Update (Handler, LLM.Events.Text_Start);
               State.Text_Started := True;
            end if;
            if Text_Delta_Value'Length > 0 then
               Emit_Update
                  (Handler    => Handler,
                Kind       => LLM.Events.Text_Delta,
                Delta_Text => Text_Delta_Value);
            end if;
         end;
      elsif Event_Typ = "response.output_text.done" then
         Close_Text (State, Handler);
      elsif Event_Typ = "response.reasoning_text.delta"
        or else Event_Typ = "response.reasoning_summary_text.delta"
      then
         declare
            Text_Delta_Value : constant String := Get_String_Field (Root, "delta");
         begin
            if not State.Thinking_Started then
               Emit_Update (Handler, LLM.Events.Thinking_Start);
               State.Thinking_Started := True;
            end if;
            if Text_Delta_Value'Length > 0 then
               Emit_Update
                  (Handler    => Handler,
                Kind       => LLM.Events.Thinking_Delta,
                Delta_Text => Text_Delta_Value);
            end if;
         end;
      elsif Event_Typ = "response.reasoning_text.done"
        or else Event_Typ = "response.reasoning_summary_text.done"
      then
         --  Keep the block open until response.output_item.done.  The
         --  final encrypted_content is delivered on that item, after the
         --  reasoning text done event.
         null;
      elsif Event_Typ = "response.function_call_arguments.delta" then
         State.Saw_Function_Call := True;
         Close_Thinking (State, Handler);
         Close_Text (State, Handler);
         Note_Function_Arguments_Delta (State, Root, Handler);
      elsif Event_Typ = "response.function_call_arguments.done" then
         declare
            Item_Id : constant String := Get_String_Field (Root, "item_id");
            Name    : constant String := Get_String_Field (Root, "name");
            Args    : constant String := Get_String_Field (Root, "arguments");
            Index   : Integer :=
               Find_Tool_Index_By_Item (State.Tool_Calls, Item_Id);
         begin
            if Index < State.Tool_Calls.First_Index then
               Index :=
                  (if State.Tool_Calls.Is_Empty
                   then 0
                   else State.Tool_Calls.Last_Index);
               Ensure_Tool_Call_Slot (State.Tool_Calls, Index);
            end if;
            declare
               Tool_State : Tool_Call_State :=
                  State.Tool_Calls.Element (Index);
            begin
               if Name'Length > 0 then
                  Tool_State.Tool_Name := To_Unbounded_String (Name);
               end if;
               if Args'Length > 0 then
                  Tool_State.Arguments_Json := To_Unbounded_String (Args);
               end if;
               State.Tool_Calls.Replace_Element (Index, Tool_State);
            end;
         end;
      elsif Event_Typ = "response.completed"
        or else Event_Typ = "response.incomplete"
        or else Event_Typ = "response.failed"
      then
         Apply_Usage_And_Status (State, Root);
         declare
            Response_Obj : constant GNATCOLL.JSON.JSON_Value :=
               Get_Object_Field (Root, "response");
            Output       : constant GNATCOLL.JSON.JSON_Array :=
               Get_Array_Field (Response_Obj, "output");
         begin
            for I in 1 .. GNATCOLL.JSON.Length (Output) loop
               declare
                  Item : constant GNATCOLL.JSON.JSON_Value :=
                     GNATCOLL.JSON.Get (Output, I);
                  Item_Type : constant String :=
                     Get_String_Field (Item, "type");
               begin
                  --  Text deltas have already delivered the streamed
                  --  message.  The completed output is still needed for
                  --  reasoning ciphertext and function-call identity.
                  if Item_Type /= "message"
                    or else not State.Text_Started
                  then
                     Process_Output_Item (State, Item, Handler);
                  end if;
               end;
            end loop;
         end;
         Finalize_Message (State, Handler);
      elsif Event_Typ = "error" then
         State.Stop := LLM.Types.Error_Stop;
         Finalize_Message (State, Handler);
      elsif Event_Typ = "response.refusal.delta" then
         State.Stop := LLM.Types.Error_Stop;
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
         State.Saw_Stream_Event := True;

         declare
            Data : constant String := To_String (Event_Data);
         begin
            if Data'Length > 0 and then Data /= "[DONE]" then
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
      Root   : constant GNATCOLL.JSON.JSON_Value :=
         Parse_Json (Payload, "Invalid OpenAI Responses response");
      Output : constant GNATCOLL.JSON.JSON_Array :=
         Get_Array_Field (Root, "output");
   begin
      Apply_Usage_And_Status (State, Root);

      for I in 1 .. GNATCOLL.JSON.Length (Output) loop
         Process_Output_Item
            (State, GNATCOLL.JSON.Get (Output, I), Handler);
      end loop;

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
            "OpenAI responses request failed with HTTP"
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

end LLM.Providers.OpenAI_Responses;
