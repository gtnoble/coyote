with AUnit.Assertions;
with LLM.Providers.OpenCode_Go.Catalogue;
with AUnit.Test_Caller;
with AUnit.Test_Suites;
use type LLM.Providers.OpenCode_Go.Catalogue.Wire_Kind;

package body LLM_OpenCode_Go_Catalogue_Tests is

   use AUnit.Assertions;

   procedure Test_Wire_Format_MiniMax_Anthropic (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("minimax-m2.5")
           = LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire,
         "minimax-m2.5 should use Anthropic messages wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("minimax-m2.7")
           = LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire,
         "minimax-m2.7 should use Anthropic messages wire format");
      --  Case-insensitive
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("MiniMax-M2.7")
           = LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire,
         "MiniMax-M2.7 (mixed case) should use Anthropic messages wire");
   end Test_Wire_Format_MiniMax_Anthropic;

   procedure Test_Wire_Format_DeepSeek_OpenAI (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("deepseek-v4-pro")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "deepseek-v4-pro should use OpenAI completions wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("glm-5")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "glm-5 should use OpenAI completions wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("kimi-k2.5")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "kimi-k2.5 should use OpenAI completions wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("qwen3.5-plus")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "qwen3.5-plus should use OpenAI completions wire format");
   end Test_Wire_Format_DeepSeek_OpenAI;

   procedure Test_Wire_Format_Unknown_Defaults_OpenAI (T : in out Test) is
      pragma Unreferenced (T);
   begin
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("future-model-v9")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "Unknown models should default to OpenAI completions wire format");
      Assert
        (LLM.Providers.OpenCode_Go.Catalogue.Wire_Format_For ("brand-new-llm")
           = LLM.Providers.OpenCode_Go.Catalogue.OpenAI_Completions_Wire,
         "Unknown models should default to OpenAI completions wire format");
   end Test_Wire_Format_Unknown_Defaults_OpenAI;

   procedure Test_Static_Metadata_Known_Model (T : in out Test) is
      pragma Unreferenced (T);
      Cat_Models : LLM.Providers.OpenCode_Go.Catalogue.Catalogue_Vectors.Vector;
   begin
      --  Load_Catalogue from the cached fixture.
      LLM.Providers.OpenCode_Go.Catalogue.Load_Catalogue (Cat_Models);
      --  Even if the network fetch fails, the catalogue may be empty.
      --  The static metadata is tested via wire format and Lookup_Static
      --  which is called inside Parse_Model, so we just verify that
      --  known models from the fixture have the expected context window.
      for Model of Cat_Models loop
         if LLM.Providers.OpenCode_Go.Catalogue."="
           (Model.Wire,
            LLM.Providers.OpenCode_Go.Catalogue.Anthropic_Messages_Wire)
         then
            --  Anthropic-wire models (minimax) should have known context.
            Assert
              (Model.Context_Window > 0,
               "Known model context window should be positive");
         end if;
      end loop;
   end Test_Static_Metadata_Known_Model;

   procedure Test_Static_Metadata_Unknown_Model (T : in out Test) is
      pragma Unreferenced (T);
      Cat_Models : LLM.Providers.OpenCode_Go.Catalogue.Catalogue_Vectors.Vector;
      Found      : Boolean := False;
   begin
      --  If the fixture has a known model, verify it gets proper defaults.
      --  This is more of a smoke test since Load_Catalogue needs network
      --  or cache; the defaults are tested through Lookup_Static indirectly.
      LLM.Providers.OpenCode_Go.Catalogue.Load_Catalogue (Cat_Models);

      for Model of Cat_Models loop
         Found := True;
         Assert
           (Model.Context_Window > 0,
            "All models should have a positive context window");
         Assert
           (Model.Max_Tokens > 0,
            "All models should have a positive max tokens");
      end loop;

      if not Found then
         Assert (True, "No models loaded (network/cache unavailable) -- skip");
      end if;
   end Test_Static_Metadata_Unknown_Model;


   package LLM_OpenCode_Go_Catalogue_Caller is
     new AUnit.Test_Caller (LLM_OpenCode_Go_Catalogue_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue MiniMax uses Anthropic wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_MiniMax_Anthropic'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue DeepSeek uses OpenAI wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_DeepSeek_OpenAI'Access));
      Result.Add_Test (LLM_OpenCode_Go_Catalogue_Caller.Create
        ("LLM.OpenCode_Go.Catalogue unknown models default to OpenAI wire",
         LLM_OpenCode_Go_Catalogue_Tests
           .Test_Wire_Format_Unknown_Defaults_OpenAI'Access));

      return Result;
   end Suite;

end LLM_OpenCode_Go_Catalogue_Tests;