with Ada.Containers;
with LLM.Types;

package LLM.Agent.Testing is

   --  Return the number of in-memory transcript messages.
   function History_Length
     (S : LLM.Agent.Session) return Ada.Containers.Count_Type;

   --  Return one in-memory transcript message by zero-based index.
   function History_Element
     (S     : LLM.Agent.Session;
      Index :        Natural) return LLM.Types.Message;

end LLM.Agent.Testing;
