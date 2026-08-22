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

   --  Return the system prompt string for the session.
   function System_Prompt
     (S : LLM.Agent.Session) return String;

   --  Return the request history compatible with Provider and Model_Id.
   function Compatible_History
     (History  : LLM.Types.Message_Vectors.Vector;
      Provider : String;
      Model_Id : String) return LLM.Types.Message_Vectors.Vector;

end LLM.Agent.Testing;
