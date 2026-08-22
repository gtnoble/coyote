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

   function Compatible_History
     (History  : LLM.Types.Message_Vectors.Vector;
      Provider : String;
      Model_Id : String) return LLM.Types.Message_Vectors.Vector is
   begin
      return LLM.Agent.Compatible_History
        (History  => History,
         Provider => Provider,
         Model_Id => Model_Id);
   end Compatible_History;

end LLM.Agent.Testing;
