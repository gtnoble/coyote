package body LLM.Providers.OpenAI_Completions.Testing is

   procedure Set_Streaming
     (P       : in out Provider;
      Enabled :        Boolean) is
   begin
      P.Use_Streaming := Enabled;
   end Set_Streaming;

end LLM.Providers.OpenAI_Completions.Testing;
