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

end LLM.Agent.Testing;
