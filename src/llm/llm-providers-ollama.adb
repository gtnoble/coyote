--  LLM.Providers.Ollama body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Exceptions;
with GNATCOLL.JSON;
with LLM.Events;
with LLM.HTTP;
with LLM.Settings;

package body LLM.Providers.Ollama is

   use type GNATCOLL.JSON.JSON_Value_Type;
   use type LLM.Types.Role;
   use type LLM.Types.Stop_Reason;

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

   function Endpoint_Url (Base_Url : String) return String is
   begin
      if Base_Url'Length = 0 then
         return "https://ollama.com/api/chat";
      elsif Base_Url (Base_Url'Last) = '/' then
         return Base_Url & "api/chat";
      else
         return Base_Url & "/api/chat";
      end if;
   end Endpoint_Url;

   function Get_Object_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return GNATCOLL.JSON.JSON_Value
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind =
                   GNATCOLL.JSON.JSON_Object_Type
      then
         return Value.Get (Field);
      end if;
      return GNATCOLL.JSON.JSON_Null;
   end Get_Object_Field;

   function Get_String_Field
     (Value : GNATCOLL.JSON.JSON_Value;
      Field : String) return String
   is
   begin
      if Value.Kind = GNATCOLL.JSON.JSON_Object_Type
        and then Value.Has_Field (Field)
        and then Value.Get (Field).Kind =
                   GNATCOLL.JSON.JSON_String_Type
      then
         return Value.Get (Field).Get;
      end if;
      return "";
   end Get_String_Field;

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
      Headers           : LLM.HTTP.Header_List;
      Status            : Natural := 0;
      Response_Body     : Unbounded_String;
      Text_Started      : Boolean := False;
      Tool_Call_Id      : Unbounded_String;
      Tool_Name         : Unbounded_String;
      Arguments_Json    : Unbounded_String;
      Total_Usage       : LLM.Types.Usage := (others => 0);
      Stop_Reason       : LLM.Types.Stop_Reason :=
                            LLM.Types.Unknown_Stop;

      procedure Process_Line
        (Line_Str : String;
         H        : not null access procedure
                      (E : LLM.Events.Agent_Event'Class))
      is
         Parsed : constant GNATCOLL.JSON.Read_Result :=
           GNATCOLL.JSON.Read (Line_Str);
         Root   : GNATCOLL.JSON.JSON_Value;
      begin
         if not Parsed.Success then
            return;
         end if;
         Root := Parsed.Value;
         if Root.Kind /= GNATCOLL.JSON.JSON_Object_Type then
            return;
         end if;

         --  Check for final chunk
         if Root.Has_Field ("done")
           and then Root.Get ("done").Kind =
                      GNATCOLL.JSON.JSON_Boolean_Type
           and then Root.Get ("done").Get
         then
            Stop_Reason := LLM.Types.Stop;
            --  Extract token usage from final chunk
            if Root.Has_Field ("prompt_eval_count") then
               declare
                  N : constant Long_Integer :=
                    Root.Get ("prompt_eval_count").Get;
               begin
                  if N >= 0 then
                     Total_Usage.Input :=
                       Total_Usage.Input + Natural (N);
                  end if;
               end;
            end if;
            if Root.Has_Field ("eval_count") then
               declare
                  N : constant Long_Integer :=
                    Root.Get ("eval_count").Get;
               begin
                  if N >= 0 then
                     Total_Usage.Output :=
                       Total_Usage.Output + Natural (N);
                  end if;
               end;
            end if;
            return;
         end if;

         --  Normal streaming chunk
         if Root.Has_Field ("message")
           and then Root.Get ("message").Kind =
                      GNATCOLL.JSON.JSON_Object_Type
         then
            declare
               Msg : constant GNATCOLL.JSON.JSON_Value :=
                 Root.Get ("message");
            begin
               --  Text content
               if Msg.Has_Field ("content")
                 and then Msg.Get ("content").Kind =
                            GNATCOLL.JSON.JSON_String_Type
               then
                  declare
                     Content_Delta : constant String :=
                       Msg.Get ("content").Get;
                  begin
                     if Content_Delta'Length > 0 then
                        if not Text_Started then
                           Text_Started := True;
                           H.all
                             (LLM.Events.Message_Update_Event'
                               (Kind          =>
                                  LLM.Events.Text_Start,
                                Delta_Text    =>
                                  Null_Unbounded_String,
                                Signature     =>
                                  Null_Unbounded_String,
                                Content_Index => 0,
                                Tool_Call_Id  =>
                                  Null_Unbounded_String,
                                Tool_Name     =>
                                  Null_Unbounded_String));
                        end if;
                        H.all
                          (LLM.Events.Message_Update_Event'
                            (Kind          =>
                               LLM.Events.Text_Delta,
                             Delta_Text    =>
                               To_Unbounded_String
                                 (Content_Delta),
                             Signature     =>
                               Null_Unbounded_String,
                             Content_Index => 0,
                             Tool_Call_Id  =>
                               Null_Unbounded_String,
                             Tool_Name     =>
                               Null_Unbounded_String));
                     end if;
                  end;
               end if;

               --  Tool calls
               if Msg.Has_Field ("tool_calls")
                 and then Msg.Get ("tool_calls").Kind =
                            GNATCOLL.JSON.JSON_Array_Type
               then
                  declare
                     TC_Array : constant GNATCOLL.JSON.JSON_Array :=
                       Msg.Get ("tool_calls").Get;
                  begin
                     if GNATCOLL.JSON.Length (TC_Array) > 0 then
                        declare
                           TC_Obj :
                             constant GNATCOLL.JSON.JSON_Value :=
                             GNATCOLL.JSON.Get (TC_Array, 1);
                        begin
                           if TC_Obj.Kind =
                                GNATCOLL.JSON.JSON_Object_Type
                           then
                              declare
                                 Func_Obj :
                                   constant
                                     GNATCOLL.JSON.JSON_Value :=
                                   Get_Object_Field
                                     (TC_Obj, "function");
                              begin
                                 if Func_Obj.Kind =
                                      GNATCOLL.JSON
                                        .JSON_Object_Type
                                 then
                                    Tool_Name :=
                                      To_Unbounded_String
                                        (Get_String_Field
                                           (Func_Obj,
                                            "name"));
                                    if Func_Obj
                                         .Has_Field
                                         ("arguments")
                                    then
                                       Arguments_Json :=
                                         To_Unbounded_String
                                           (GNATCOLL.JSON
                                              .Write
                                              (Func_Obj
                                                 .Get
                                                 ("arguments"
                                                 )));
                                    end if;
                                 end if;
                              end;
                           end if;
                        end;
                        --  Emit tool call delta
                        H.all
                          (LLM.Events.Message_Update_Event'
                            (Kind          =>
                               LLM.Events.Tool_Call_Delta,
                             Delta_Text    =>
                               Null_Unbounded_String,
                             Signature     =>
                               Null_Unbounded_String,
                             Content_Index => 0,
                             Tool_Call_Id  =>
                               Null_Unbounded_String,
                             Tool_Name     => Tool_Name));
                     end if;
                  end;
               end if;
            end;
         end if;
      end Process_Line;

      procedure On_Chunk (Chunk : String) is
      begin
         Append (Response_Body, Chunk);
         loop
            declare
               LF_Pos : constant Natural :=
                 Ada.Strings.Fixed.Index
                   (To_String (Response_Body), "" & ASCII.LF);
            begin
               if LF_Pos = 0 then
                  exit;
               end if;
               declare
                  Line : constant String :=
                    To_String (Response_Body)
                      (1 .. LF_Pos - 1);
               begin
                  Process_Line (Line, Handler);
               end;
               --  Remove processed line and LF
               Response_Body :=
                 To_Unbounded_String
                   (To_String (Response_Body)
                      (LF_Pos + 1 ..
                         To_String (Response_Body)'Last));
            end;
         end loop;
      end On_Chunk;

      Request_Obj  : GNATCOLL.JSON.JSON_Value :=
                       GNATCOLL.JSON.Create_Object;
      Messages_Arr : GNATCOLL.JSON.JSON_Array :=
                       GNATCOLL.JSON.Empty_Array;
      Effective_Base_Url : String :=
                             To_String (P.Base_Url);
      Effective_Api_Key  : String :=
                             To_String (P.Api_Key);
   begin
      Handler.all (LLM.Events.Agent_Start_Event'(LLM.Events.Agent_Event with null record));

      if Effective_Base_Url'Length = 0 then
         --  Resolve from settings if empty
         declare
            Root : constant GNATCOLL.JSON.JSON_Value :=
              LLM.Settings.Load_Json_File
                (LLM.Settings.Models_Path);
            Prov : constant GNATCOLL.JSON.JSON_Value :=
              LLM.Settings.Find_Provider_Config
                (Root, "ollama");
         begin
            if Prov.Kind =
                 GNATCOLL.JSON.JSON_Object_Type
            then
               Effective_Base_Url :=
                 Get_String_Field (Prov, "baseUrl");
            end if;
            if Effective_Api_Key'Length = 0 then
               Effective_Api_Key :=
                 LLM.Settings.Resolve_Api_Key ("ollama");
            end if;
         end;
      end if;

      if Effective_Api_Key'Length > 0 then
         LLM.HTTP.Add_Header
           (Headers, "Authorization",
            "Bearer " & Effective_Api_Key);
      end if;
      LLM.HTTP.Add_Header
        (Headers, "Content-Type", "application/json");

      Request_Obj.Set_Field ("model", Model_Id);
      Request_Obj.Set_Field ("stream", True);
      if Thinking /= LLM.Providers.Off then
         Request_Obj.Set_Field ("think", True);
      end if;

      --  Build messages array
      for I in Messages.First_Index .. Messages.Last_Index loop
         declare
            M      : constant LLM.Types.Message :=
              Messages.Element (I);
            Msg_Obj : GNATCOLL.JSON.JSON_Value :=
                        GNATCOLL.JSON.Create_Object;
            Content : Unbounded_String;
         begin
            case M.Role is
               when LLM.Types.User =>
                  Msg_Obj.Set_Field ("role", "user");
               when LLM.Types.Assistant =>
                  Msg_Obj.Set_Field ("role", "assistant");
               when LLM.Types.Tool_Result =>
                  Msg_Obj.Set_Field ("role", "tool");
               when LLM.Types.Compaction_Summary =>
                  Msg_Obj.Set_Field ("role", "system");
            end case;

            --  Concatenate content blocks
            for J in M.Content.First_Index .. M.Content.Last_Index loop
               declare
                  Block : constant LLM.Types.Content_Block :=
                    M.Content.Element (J);
               begin
                  case Block.Kind is
                     when LLM.Types.Text_Block =>
                        Append (Content, Block.Text);
                     when LLM.Types.Thinking_Block =>
                        Append (Content, Block.Thinking);
                     when LLM.Types.Tool_Call_Block =>
                        null;
                     when LLM.Types.Tool_Result_Block =>
                        Append (Content, Block.Result_Text);
                  end case;
               end;
            end loop;
            Msg_Obj.Set_Field
              ("content", To_String (Content));
            GNATCOLL.JSON.Append (Messages_Arr, Msg_Obj);
         end;
      end loop;
      Request_Obj.Set_Field ("messages", Messages_Arr);

      --  Tools
      if Tools_Json /= "[]" then
         declare
            Tools_Val : constant GNATCOLL.JSON.JSON_Value :=
              GNATCOLL.JSON.Read (Tools_Json).Value;
         begin
            Request_Obj.Set_Field ("tools", Tools_Val);
         end;
      end if;

      LLM.HTTP.Post
        (URL      => Endpoint_Url (Effective_Base_Url),
         Headers  => Headers,
         Payload  => GNATCOLL.JSON.Write (Request_Obj),
         On_Chunk => On_Chunk'Access,
         Status   => Status);

      Handler.all
        (LLM.Events.Message_End_Event'
          (Stop      => Stop_Reason,
           Err_Msg   => Null_Unbounded_String,
           Tok_Usage => Total_Usage,
           Cost_Dmil => 0));
      Handler.all (LLM.Events.Agent_End_Event'(LLM.Events.Agent_Event with Was_Aborted => False));

   exception
      when E : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "[!] ollama provider error: "
            & Ada.Exceptions.Exception_Message (E));
         Handler.all
           (LLM.Events.Message_End_Event'
             (Stop      => LLM.Types.Error_Stop,
              Err_Msg   => To_Unbounded_String
                             (Ada.Exceptions
                                .Exception_Message (E)),
              Tok_Usage => (others => 0),
              Cost_Dmil => 0));
         Handler.all
           (LLM.Events.Agent_End_Event'
             (Was_Aborted => False));
         raise;
   end Send;

end LLM.Providers.Ollama;
