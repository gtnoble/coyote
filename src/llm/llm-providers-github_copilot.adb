--  LLM.Providers.GitHub_Copilot body.
--
--  Project: pi_acme
--  For revision history, see the project version-control log.

with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Auth;
with LLM.Auth.GitHub_Copilot;
with LLM.Providers.Anthropic_Messages;
with LLM.Providers.GitHub_Copilot.Catalogue;
with LLM.Providers.OpenAI_Completions;

package body LLM.Providers.GitHub_Copilot is

   use type LLM.Types.Role;

   function Create return Provider is
   begin
      return Result : Provider do
         null;
      end return;
   end Create;

   function Effective_Base_Url (Access_Token : String) return String is
   begin
      if Ada.Environment_Variables.Exists
         ("PI_ACME_GITHUB_COPILOT_BASE_URL")
      then
         declare
            Value : constant String := Ada.Environment_Variables.Value
               ("PI_ACME_GITHUB_COPILOT_BASE_URL");
         begin
            if Value'Length > 0 then
               return Value;
            end if;
         end;
      end if;

      return LLM.Auth.GitHub_Copilot.Get_Base_Url (Access_Token);
   end Effective_Base_Url;

   function Initiator_Header_Value
      (Messages : LLM.Types.Message_Vectors.Vector) return String
   is
   begin
      if Messages.Is_Empty then
         return "user";
      elsif Messages.Last_Element.Role = LLM.Types.User then
         return "user";
      else
         return "agent";
      end if;
   end Initiator_Header_Value;

   procedure Add_Header_Line
      (P      : in out LLM.Providers.OpenAI_Completions.Provider;
     Header :        String)
   is
      Separator : constant Natural := Ada.Strings.Fixed.Index (Header, ": ");
   begin
      if Separator = 0 then
         return;
      end if;

      LLM.Providers.OpenAI_Completions.Add_Header
         (P     => P,
       Name  => Header (Header'First .. Separator - 1),
       Value => Header (Separator + 2 .. Header'Last));
   end Add_Header_Line;

   procedure Add_Header_Line
      (P      : in out LLM.Providers.Anthropic_Messages.Provider;
     Header :        String)
   is
      Separator : constant Natural := Ada.Strings.Fixed.Index (Header, ": ");
   begin
      if Separator = 0 then
         return;
      end if;

      LLM.Providers.Anthropic_Messages.Add_Header
         (P     => P,
       Name  => Header (Header'First .. Separator - 1),
       Value => Header (Separator + 2 .. Header'Last));
   end Add_Header_Line;

   procedure Add_Copilot_Headers
      (P         : in out LLM.Providers.OpenAI_Completions.Provider;
     Initiator :        String)
   is
   begin
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.User_Agent_Header);
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.Editor_Version_Header);
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.Editor_Plugin_Header);
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.Integration_Id_Header);
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.Intent_Header);
      LLM.Providers.OpenAI_Completions.Add_Header
         (P, "X-Initiator", Initiator);
   end Add_Copilot_Headers;

   procedure Add_Copilot_Headers
      (P         : in out LLM.Providers.Anthropic_Messages.Provider;
     Initiator :        String)
   is
   begin
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.User_Agent_Header);
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.Editor_Version_Header);
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.Editor_Plugin_Header);
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.Integration_Id_Header);
      Add_Header_Line (P, LLM.Auth.GitHub_Copilot.Intent_Header);
      LLM.Providers.Anthropic_Messages.Add_Header
         (P, "X-Initiator", Initiator);
   end Add_Copilot_Headers;

   function Supports_Anthropic
      (Model_Id : String;
     Models   : LLM.Providers.GitHub_Copilot.Catalogue.Catalogue_Vectors.Vector)
     return Boolean
   is
   begin
      for Model of Models loop
         if To_String (Model.Model_Id) = Model_Id then
            return Model.Supports_Anthropic;
         end if;
      end loop;

      return False;
   end Supports_Anthropic;

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
      pragma Unreferenced (P);

      Creds      : LLM.Auth.Provider_Credentials :=
         LLM.Auth.Load_Credentials ("github-copilot");
      Models     : LLM.Providers.GitHub_Copilot.Catalogue.Catalogue_Vectors.Vector;
      Access_Tok : Unbounded_String;
      Base_Url   : Unbounded_String;
      Initiator  : constant String := Initiator_Header_Value (Messages);
   begin
      if Length (Creds.Refresh_Token) = 0 and then Length (Creds.Access_Token) = 0 then
         raise LLM.Auth.GitHub_Copilot.Auth_Error with
            "GitHub Copilot credentials are not configured; run `pi login "
            & "github-copilot`";
      end if;

      LLM.Auth.GitHub_Copilot.Ensure_Valid (Creds);
      Access_Tok := Creds.Access_Token;

      if Length (Access_Tok) = 0 then
         raise LLM.Auth.GitHub_Copilot.Auth_Error with
            "GitHub Copilot access token is missing";
      end if;

      Base_Url := To_Unbounded_String (Effective_Base_Url (To_String (Access_Tok)));

      LLM.Providers.GitHub_Copilot.Catalogue.Load_Catalogue
         (Base_Url => To_String (Base_Url),
       Token    => To_String (Access_Tok),
       Models   => Models);

      if Supports_Anthropic (Model_Id, Models) then
         declare
            Delegate : LLM.Providers.Anthropic_Messages.Provider :=
               LLM.Providers.Anthropic_Messages.Create
                  (Base_Url => To_String (Base_Url),
             Api_Key  => To_String (Access_Tok));
         begin
            Add_Copilot_Headers (Delegate, Initiator);
            Delegate.Send
               (Model_Id      => Model_Id,
           System_Prompt => System_Prompt,
           Messages      => Messages,
           Tools_Json    => Tools_Json,
           Thinking      => Thinking,
           Max_Tokens    => Max_Tokens,
           Handler       => Handler);
         end;
      else
         declare
            Delegate : LLM.Providers.OpenAI_Completions.Provider :=
               LLM.Providers.OpenAI_Completions.Create
                  (Base_Url => To_String (Base_Url),
             Api_Key  => To_String (Access_Tok));
         begin
            Add_Copilot_Headers (Delegate, Initiator);
            Delegate.Send
               (Model_Id      => Model_Id,
           System_Prompt => System_Prompt,
           Messages      => Messages,
           Tools_Json    => Tools_Json,
           Thinking      => Thinking,
           Max_Tokens    => Max_Tokens,
           Handler       => Handler);
         end;
      end if;
   end Send;

end LLM.Providers.GitHub_Copilot;
