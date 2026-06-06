--  LLM.Model_Registry body.
--
--  Project: coyote
--  For revision history, see the project version-control log.

with Ada.Characters.Handling;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with LLM.Auth;
with LLM.Auth.GitHub_Copilot;
with LLM.Providers.GitHub_Copilot.Catalogue;
with LLM.Providers.OpenCode_Go.Catalogue;
use type LLM.Providers.OpenCode_Go.Catalogue.Wire_Kind;
with LLM.Providers.OpenRouter.Catalogue;
with LLM.Providers.Ollama.Catalogue;
with LLM.Settings;
with LLM.Providers.Ollama.Catalogue;

package body LLM.Model_Registry is

  Registry : Model_Info_Vectors.Vector;

  function Provider_Key (Provider : String) return String is
  begin
    return Ada.Characters.Handling.To_Lower (Provider);
  end Provider_Key;

  function Provider_Key (Provider : Unbounded_String) return String is
  begin
    return Provider_Key (To_String (Provider));
  end Provider_Key;

  function Has_GitHub_Copilot_Credentials return Boolean is
    Creds : constant LLM.Auth.Provider_Credentials :=
      LLM.Auth.Load_Credentials ("github-copilot");
  begin
    return Length (Creds.Refresh_Token) > 0
      or else Length (Creds.Access_Token) > 0;
  end Has_GitHub_Copilot_Credentials;

  function Has_OpenRouter_Key return Boolean is
  begin
    return LLM.Settings.Resolve_Api_Key ("openrouter")'Length > 0;
  end Has_OpenRouter_Key;

  function Has_Anthropic_Key return Boolean is
  begin
    return LLM.Settings.Resolve_Api_Key ("anthropic")'Length > 0;
  end Has_Anthropic_Key;

  function Has_OpenCode_Go_Key return Boolean is
  begin
    return LLM.Settings.Resolve_Api_Key ("opencode-go")'Length > 0;
  end Has_OpenCode_Go_Key;

  function Has_Ollama_Key return Boolean is
  begin
    return LLM.Settings.Resolve_Api_Key ("ollama")'Length > 0;
  end Has_Ollama_Key;

  function To_Model_Info
    (Item : LLM.Providers.OpenCode_Go.Catalogue.Model_Info)
    return Model_Info
  is
  begin
    return
      (Model_Id            => Item.Model_Id,
       Name                => Item.Name,
       Provider            => To_Unbounded_String ("opencode-go"),
       Context_Window      => Item.Context_Window,
       Max_Tokens          => Item.Max_Tokens,
       Reasoning           => Item.Reasoning,
       Supports_Tools      => Item.Supports_Tools,
       Supports_Images     => Item.Supports_Images,
       Max_Thinking_Budget => 0,
       Min_Thinking_Budget => 0,
       Wire_Format         =>
         (if Item.Wire =
            LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire
          then To_Unbounded_String ("anthropic-messages")
          else To_Unbounded_String ("openai-completions")),
       Cost                => (others => 0.0));
  end To_Model_Info;

  function Default_OpenCode_Go_Model (Model_Id : String) return Model_Info
  is
     Wire : constant LLM.Providers.OpenCode_Go.Catalogue.Wire_Kind :=
       LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For (Model_Id);
  begin
    return
      (Model_Id            => To_Unbounded_String (Model_Id),
       Name                => To_Unbounded_String (Model_Id),
       Provider            => To_Unbounded_String ("opencode-go"),
       Context_Window      => 128_000,
       Max_Tokens          => 16_384,
       Reasoning           => False,
       Supports_Tools      => True,
       Supports_Images     => False,
       Max_Thinking_Budget => 0,
       Min_Thinking_Budget => 0,
       Wire_Format         =>
         (if Wire =
            LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire
          then To_Unbounded_String ("anthropic-messages")
          else To_Unbounded_String ("openai-completions")),
       Cost                => (others => 0.0));
  end Default_OpenCode_Go_Model;

  procedure Remove_Provider_Entries (Provider : String) is
    Want : constant String := Provider_Key (Provider);
  begin
    if Registry.Is_Empty then
      return;
    end if;

    for Index in reverse Registry.First_Index .. Registry.Last_Index loop
      if Provider_Key (Registry.Element (Index).Provider) = Want then
        Registry.Delete (Index);
      end if;
    end loop;
  end Remove_Provider_Entries;

  function To_Model_Info
    (Item : LLM.Providers.GitHub_Copilot.Catalogue.Model_Capability_Info)
    return Model_Info
  is
  begin
    return
      (Model_Id            => Item.Model_Id,
       Name                => Item.Name,
       Provider            => To_Unbounded_String ("github-copilot"),
       Context_Window      => Item.Context_Window,
       Max_Tokens          => Item.Max_Tokens,
       Reasoning           => Item.Reasoning,
       Supports_Tools      => Item.Supports_Tools,
       Supports_Images     => Item.Supports_Images,
       Max_Thinking_Budget => Item.Max_Thinking_Budget,
       Min_Thinking_Budget => Item.Min_Thinking_Budget,
       Wire_Format         =>
         (if Item.Supports_Anthropic
          then To_Unbounded_String ("anthropic-messages")
          else To_Unbounded_String ("openai-completions")),
       Cost                => (others => 0.0));
  end To_Model_Info;

  function To_Model_Info
    (Item : LLM.Providers.OpenRouter.Catalogue.Model_Info)
    return Model_Info
  is
  begin
    return
      (Model_Id            => Item.Model_Id,
       Name                => Item.Name,
       Provider            => To_Unbounded_String ("openrouter"),
       Context_Window      => Item.Context_Window,
       Max_Tokens          => Item.Max_Tokens,
       Reasoning           => Item.Reasoning,
       Supports_Tools      => Item.Supports_Tools,
       Supports_Images     => Item.Supports_Images,
       Max_Thinking_Budget => 0,
       Min_Thinking_Budget => 0,
       Wire_Format         => To_Unbounded_String ("openai-completions"),
       Cost                =>
         (Input       => Item.Cost_Input,
          Output      => Item.Cost_Output,
          Cache_Read  => Item.Cost_Cache_Read,
          Cache_Write => Item.Cost_Cache_Write));
  end To_Model_Info;

  function To_Model_Info
    (Item : LLM.Providers.Ollama.Catalogue.Model_Info)
    return Model_Info
  is
  begin
    return
      (Model_Id            => Item.Model_Id,
       Name                => Item.Name,
       Provider            => To_Unbounded_String ("ollama"),
       Context_Window      => Item.Context_Window,
       Max_Tokens          => Item.Max_Tokens,
       Reasoning           => Item.Reasoning,
       Supports_Tools      => Item.Supports_Tools,
       Supports_Images     => Item.Supports_Images,
       Max_Thinking_Budget => 0,
       Min_Thinking_Budget => 0,
       Wire_Format         => To_Unbounded_String ("ollama"),
       Cost                => (others => 0.0));
  end To_Model_Info;

  function Default_Ollama_Model (Model_Id : String) return Model_Info is
  begin
    return
      (Model_Id            => To_Unbounded_String (Model_Id),
       Name                => To_Unbounded_String (Model_Id),
       Provider            => To_Unbounded_String ("ollama"),
       Context_Window      => 128_000,
       Max_Tokens          => 16_384,
       Reasoning           => False,
       Supports_Tools      => True,
       Supports_Images     => False,
       Max_Thinking_Budget => 0,
       Min_Thinking_Budget => 0,
       Wire_Format         => To_Unbounded_String ("ollama"),
       Cost                => (others => 0.0));
  end Default_Ollama_Model;

  function Default_OpenRouter_Model (Model_Id : String) return Model_Info is
  begin
    return
      (Model_Id            => To_Unbounded_String (Model_Id),
       Name                => To_Unbounded_String (Model_Id),
       Provider            => To_Unbounded_String ("openrouter"),
       Context_Window      => 128_000,
       Max_Tokens          => 4_096,
       Reasoning           => False,
       Supports_Tools      => True,
       Supports_Images     => False,
       Max_Thinking_Budget => 0,
       Min_Thinking_Budget => 0,
       Wire_Format         => To_Unbounded_String ("openai-completions"),
       Cost                => (others => 0.0));
  end Default_OpenRouter_Model;

  procedure Add_Anthropic_Model
    (Model_Id     : String;
     Name         : String;
     Context_Size : Natural;
     Max_Tokens   : Natural;
     Reasoning    : Boolean) is
  begin
    Registry.Append
      ((Model_Id            => To_Unbounded_String (Model_Id),
        Name                => To_Unbounded_String (Name),
        Provider            => To_Unbounded_String ("anthropic"),
        Context_Window      => Context_Size,
        Max_Tokens          => Max_Tokens,
        Reasoning           => Reasoning,
        Supports_Tools      => True,
        Supports_Images     => False,
        Max_Thinking_Budget => 0,
        Min_Thinking_Budget => 0,
        Wire_Format         => To_Unbounded_String ("anthropic-messages"),
        Cost                => (others => 0.0)));
  end Add_Anthropic_Model;

    procedure Refresh_Ollama is
    Models : LLM.Providers.Ollama.Catalogue.Catalogue_Vectors.Vector;
  begin
    Remove_Provider_Entries ("ollama");

    if not Has_Ollama_Key then
      return;
    end if;

    -- use settings to allow local baseUrl and apiKey overrides
    declare
      Root : constant GNATCOLL.JSON.JSON_Value :=
        LLM.Settings.Load_Json_File (LLM.Settings.Models_Path);
      Prov : constant GNATCOLL.JSON.JSON_Value :=
        LLM.Settings.Find_Provider_Config (Root, "ollama");
      Base_Url : String := "";
      Api_Key  : String := "";
    begin
      if Prov.Kind = GNATCOLL.JSON.JSON_Object_Type then
        if Prov.Has_Field ("baseUrl") and then Prov.Get ("baseUrl").Kind = GNATCOLL.JSON.JSON_String_Type then
          Base_Url := Prov.Get ("baseUrl").Get;
        end if;
        if Prov.Has_Field ("apiKey") and then Prov.Get ("apiKey").Kind = GNATCOLL.JSON.JSON_String_Type then
          Api_Key := Prov.Get ("apiKey").Get;
        end if;
      end if;
      if Api_Key = "" then
        Api_Key := LLM.Settings.Resolve_Api_Key ("ollama");
      end if;

      LLM.Providers.Ollama.Catalogue.Load_Catalogue (Models, Base_Url, Api_Key);
    end;

    for Item of Models loop
      Registry.Append (To_Model_Info (Item));
    end loop;
  end Refresh_Ollama;

procedure Refresh_GitHub_Copilot is
    Creds  : LLM.Auth.Provider_Credentials :=
      LLM.Auth.Load_Credentials ("github-copilot");
    Models :
      LLM.Providers.GitHub_Copilot.Catalogue.Catalogue_Vectors.Vector;
  begin
    Remove_Provider_Entries ("github-copilot");

    if Length (Creds.Refresh_Token) = 0
      and then Length (Creds.Access_Token) = 0
    then
      return;
    end if;

    LLM.Auth.GitHub_Copilot.Ensure_Valid (Creds);

    if Length (Creds.Access_Token) = 0 then
      return;
    end if;

    declare
      Base_Url : constant String :=
        LLM.Auth.GitHub_Copilot.Get_Base_Url
          (To_String (Creds.Access_Token));
    begin
      LLM.Providers.GitHub_Copilot.Catalogue.Load_Catalogue
        (Base_Url => Base_Url,
         Token    => To_String (Creds.Access_Token),
         Models   => Models);
    end;

    for Item of Models loop
      Registry.Append (To_Model_Info (Item));
    end loop;
  end Refresh_GitHub_Copilot;

  procedure Refresh_OpenRouter is
    Models : LLM.Providers.OpenRouter.Catalogue.Catalogue_Vectors.Vector;
  begin
    Remove_Provider_Entries ("openrouter");
    LLM.Providers.OpenRouter.Catalogue.Load_Catalogue (Models);

    for Item of Models loop
      Registry.Append (To_Model_Info (Item));
    end loop;
  end Refresh_OpenRouter;

  procedure Refresh_Anthropic is
  begin
    Remove_Provider_Entries ("anthropic");

    if not Has_Anthropic_Key then
      return;
    end if;

    Add_Anthropic_Model
      (Model_Id     => "claude-opus-4-20250514",
       Name         => "Claude Opus 4",
       Context_Size => 200_000,
       Max_Tokens   => 32_000,
       Reasoning    => True);
    Add_Anthropic_Model
      (Model_Id     => "claude-sonnet-4-20250514",
       Name         => "Claude Sonnet 4",
       Context_Size => 200_000,
       Max_Tokens   => 16_000,
       Reasoning    => True);
    Add_Anthropic_Model
      (Model_Id     => "claude-haiku-4-20250514",
       Name         => "Claude Haiku 4",
       Context_Size => 200_000,
       Max_Tokens   => 16_000,
       Reasoning    => True);
  end Refresh_Anthropic;

  procedure Refresh_OpenCode_Go is
    Models : LLM.Providers.OpenCode_Go.Catalogue.Catalogue_Vectors.Vector;
  begin
    Remove_Provider_Entries ("opencode-go");

    if not Has_OpenCode_Go_Key then
      return;
    end if;

    LLM.Providers.OpenCode_Go.Catalogue.Load_Catalogue (Models);

    for Item of Models loop
      Registry.Append (To_Model_Info (Item));
    end loop;
  end Refresh_OpenCode_Go;

  function Lookup
    (Provider : String;
     Model_Id : String) return Model_Info
  is
    Want_Provider : constant String := Provider_Key (Provider);
  begin
    for Item of Registry loop
      if Provider_Key (Item.Provider) = Want_Provider
        and then To_String (Item.Model_Id) = Model_Id
      then
        return Item;
      end if;
    end loop;

    if Want_Provider = "openrouter" then
      return Default_OpenRouter_Model (Model_Id);
    elsif Want_Provider = "opencode-go" then
      return Default_OpenCode_Go_Model (Model_Id);
    elsif Want_Provider = "github-copilot" then
      raise Not_Found with
        "GitHub Copilot model not found: " & Model_Id;
    elsif Want_Provider = "anthropic" then
      raise Not_Found with "Anthropic model not found: " & Model_Id;
    elsif Want_Provider = "ollama" then
      return Default_Ollama_Model (Model_Id);
    else
      raise Not_Found with "Unknown provider: " & Provider;
    end if;
  end Lookup;

  --  Compare two Model_Info values for ascending sort by provider then
  --  model identifier, both case-insensitive.
  function Model_Info_Before
    (Left  : Model_Info;
     Right : Model_Info) return Boolean
  is
    L_Prov : constant String :=
      Ada.Characters.Handling.To_Lower (To_String (Left.Provider));
    R_Prov : constant String :=
      Ada.Characters.Handling.To_Lower (To_String (Right.Provider));
  begin
    if L_Prov /= R_Prov then
      return L_Prov < R_Prov;
    end if;
    return Ada.Characters.Handling.To_Lower (To_String (Left.Model_Id))
      < Ada.Characters.Handling.To_Lower (To_String (Right.Model_Id));
  end Model_Info_Before;

  package Model_Sort is new Model_Info_Vectors.Generic_Sorting
    ("<" => Model_Info_Before);

  function Available_Models return Model_Info_Vectors.Vector is
    Result             : Model_Info_Vectors.Vector;
    Include_GitHub     : constant Boolean :=
      Has_GitHub_Copilot_Credentials;
    Include_OpenRouter : constant Boolean := Has_OpenRouter_Key;
    Include_Anthropic  : constant Boolean := Has_Anthropic_Key;
    Include_OpenCode   : constant Boolean := Has_OpenCode_Go_Key;
    Include_Ollama   : constant Boolean := Has_Ollama_Key;
  begin
    for Item of Registry loop
      declare
        Provider_Name : constant String := Provider_Key (Item.Provider);
      begin
        if (Provider_Name = "github-copilot" and then Include_GitHub)
          or else
            (Provider_Name = "openrouter" and then Include_OpenRouter)
          or else
            (Provider_Name = "anthropic" and then Include_Anthropic)
          or else
            (Provider_Name = "opencode-go" and then Include_OpenCode)
          or else
            (Provider_Name = "ollama" and then Include_Ollama)
        then
          Result.Append (Item);
        end if;
      end;
    end loop;

    Model_Sort.Sort (Result);
    return Result;
  end Available_Models;

end LLM.Model_Registry;
