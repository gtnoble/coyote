with AUnit;
with AUnit.Test_Fixtures;

package LLM_Agent_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Single_Turn_Prompt               (T : in out Test);
   procedure Test_Tool_Call_Loop                   (T : in out Test);
   procedure Test_Two_Tool_Call_Loop               (T : in out Test);
   procedure Test_Tool_Execution_Failure           (T : in out Test);
   procedure Test_Switch_Session_Loads_History     (T : in out Test);
   procedure Test_Abort_Request                    (T : in out Test);
   procedure Test_Abort_Batched_Tools_Keep_History_Valid
     (T : in out Test);
   procedure Test_Session_File_Written_Only_After_Turn_End
     (T : in out Test);
   procedure Test_Session_Resume                   (T : in out Test);

end LLM_Agent_Tests;
