with AUnit;
with AUnit.Test_Fixtures;

package LLM_Pi_Adapter_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Agent_Start_Json (T : in out Test);
   procedure Test_Text_Delta_Json (T : in out Test);
   procedure Test_Message_End_Json_Cost (T : in out Test);
   procedure Test_Tool_Execution_Start_Json (T : in out Test);

end LLM_Pi_Adapter_Tests;
