with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body LLM.Agent.Testing is

   function History_Length
     (S : LLM.Agent.Session) return Ada.Containers.Count_Type is
   begin
      return S.History.Length;
   end History_Length;

   function History_Element
     (S     : LLM.Agent.Session;
      Index :        Natural) return LLM.Types.Message is
   begin
      return S.History.Element (Index);
   end History_Element;

   function System_Prompt
     (S : LLM.Agent.Session) return String is
   begin
      return To_String (S.System_Prompt);
   end System_Prompt;

end LLM.Agent.Testing;
