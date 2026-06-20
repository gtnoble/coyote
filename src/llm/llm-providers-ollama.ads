--  LLM.Providers.Ollama — minimal parent spec.
--
--  The native Ollama chat provider has been retired.  All Ollama chat
--  traffic now flows through the OpenAI-compatible /v1/chat/completions
--  endpoint via LLM.Providers.OpenAI_Completions.  This spec exists only
--  so that LLM.Providers.Ollama.Catalogue remains a valid child package.
--
--  Project: coyote
--  For revision history, see the project version-control log.

package LLM.Providers.Ollama is
end LLM.Providers.Ollama;
