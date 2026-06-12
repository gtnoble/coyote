--  LLM.Providers.OpenRouter body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with LLM.HTTP;
with LLM.Providers.OpenRouter.Catalogue;
with LLM.Settings;

package body LLM.Providers.OpenRouter is

   function Default_Base_Url return String is
   begin
      if Ada.Environment_Variables.Exists ("COYOTE_OPENROUTER_BASE_URL") then
         declare
            Value : constant String :=
               Ada.Environment_Variables.Value ("COYOTE_OPENROUTER_BASE_URL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return "https://openrouter.ai/api/v1";
   end Default_Base_Url;

   function Create (Api_Key : String := "") return Provider is
   begin
      return Result : Provider do
         Set_Base_Url (Result, Default_Base_Url);
         Set_Api_Key (Result, Api_Key);
         Add_Header (Result, "HTTP-Referer", "https://github.com/gtnoble/coyote");
         Add_Header (Result, "X-Title", "coyote");
      end return;
   end Create;

   function Resolve_Api_Key (P : Provider) return String is
      Direct_Key : constant String := Get_Api_Key (P);
   begin
      if Direct_Key'Length > 0 then
         return Direct_Key;
      end if;

      if Ada.Environment_Variables.Exists ("OPENROUTER_API_KEY") then
         declare
            Env_Key : constant String :=
               Ada.Environment_Variables.Value ("OPENROUTER_API_KEY");
         begin
            if Env_Key'Length > 0 then
               return Env_Key;
            end if;
         end;
      end if;

      return LLM.Settings.Resolve_Api_Key ("openrouter");
   end Resolve_Api_Key;

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
      Api_Key : constant String := Resolve_Api_Key (P);
   begin
      --  Trigger a stale-cache refresh before sending so the live
      --  model catalogue is available for reasoning-effort decisions.
      declare
         Models : LLM.Providers.OpenRouter.Catalogue.Catalogue_Vectors.Vector;
      begin
         LLM.Providers.OpenRouter.Catalogue.Load_Catalogue (Models);
      end;

      if Api_Key'Length = 0 then
         raise LLM.HTTP.Curl_Error with
            "OpenRouter API key is not configured; set OPENROUTER_API_KEY or "
            & "configure providers.openrouter.apiKey";
      end if;

      if Get_Base_Url (P)'Length = 0 then
         Set_Base_Url (P, Default_Base_Url);
      end if;

      Set_Api_Key (P, Api_Key);

      LLM.Providers.OpenAI_Completions.Send_Request
         (P             => P,
          Model_Id      => Model_Id,
          System_Prompt => System_Prompt,
          Messages      => Messages,
          Tools_Json    => Tools_Json,
          Thinking      => Thinking,
          Max_Tokens    => Max_Tokens,
          Handler       => Handler);
   end Send;

end LLM.Providers.OpenRouter;
