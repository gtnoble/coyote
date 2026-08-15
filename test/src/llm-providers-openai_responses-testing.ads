package LLM.Providers.OpenAI_Responses.Testing is

   --  Test-only helper to exercise the provider's non-streaming branch.
   procedure Set_Streaming
     (P       : in out Provider;
      Enabled :        Boolean);

end LLM.Providers.OpenAI_Responses.Testing;
