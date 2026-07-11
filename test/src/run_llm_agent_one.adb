with Ada.Text_IO;
with LLM_Agent_Tests;

procedure Run_LLM_Agent_One is
   T : LLM_Agent_Tests.Test;

   procedure Run
     (Name : String;
      Proc : not null access procedure (T : in out LLM_Agent_Tests.Test))
   is
   begin
      Ada.Text_IO.Put_Line ("START " & Name);
      Proc (T);
      Ada.Text_IO.Put_Line ("DONE  " & Name);
   exception
      when others =>
         Ada.Text_IO.Put_Line ("FAIL  " & Name);
         raise;
   end Run;
begin
   Run ("Test_Single_Turn_Prompt",
        LLM_Agent_Tests.Test_Single_Turn_Prompt'Access);
   Run ("Test_Tool_Call_Loop",
        LLM_Agent_Tests.Test_Tool_Call_Loop'Access);
   Run ("Test_Two_Tool_Call_Loop",
        LLM_Agent_Tests.Test_Two_Tool_Call_Loop'Access);
   Run ("Test_Tool_Execution_Failure",
        LLM_Agent_Tests.Test_Tool_Execution_Failure'Access);
   Run ("Test_Switch_Session_Loads_History",
        LLM_Agent_Tests.Test_Switch_Session_Loads_History'Access);
   Run ("Test_Abort_Request",
        LLM_Agent_Tests.Test_Abort_Request'Access);
   Run ("Test_Abort_Batched_Tools_Keep_History_Valid",
        LLM_Agent_Tests.Test_Abort_Batched_Tools_Keep_History_Valid'Access);
   Run ("Test_Abort_During_Shell_With_Timeout",
        LLM_Agent_Tests.Test_Abort_During_Shell_With_Timeout'Access);
   Run ("Test_Session_File_Written_Only_After_Turn_End",
        LLM_Agent_Tests.Test_Session_File_Written_Only_After_Turn_End'Access);
end Run_LLM_Agent_One;
