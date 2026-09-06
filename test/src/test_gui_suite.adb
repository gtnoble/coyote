with Coyote_GUI_Updates_Tests;
with Coyote_GUI_Prompt_Queue_Tests;
with Coyote_GUI_Notification_Policy_Tests;
with Coyote_GUI_Navigation_Tests;
with Coyote_GUI_Mode_Tests;
with Coyote_GUI_Mnemonics_Tests;
with Coyote_GUI_Session_Stats_Window_Tests;
with Coyote_App_Frontend_GUI_Tests;
with Coyote_GUI_Zoom_Tests;
with Coyote_GUI_Conversation_Stack_Tests;
with Coyote_GUI_Sandbox_Profile_Window_Tests;

package body Test_GUI_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Coyote_GUI_Updates_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Prompt_Queue_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Notification_Policy_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Navigation_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Mode_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Mnemonics_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Session_Stats_Window_Tests.Suite);
      Result.Add_Test (Coyote_App_Frontend_GUI_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Zoom_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Conversation_Stack_Tests.Suite);
      Result.Add_Test (Coyote_GUI_Sandbox_Profile_Window_Tests.Suite);

      return Result;
   end Suite;

end Test_GUI_Suite;
