with AUnit;
with AUnit.Test_Fixtures;

package Nine_P_Client_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Namespace function
   procedure Test_Namespace_Uses_Env   (T : in out Test);
   procedure Test_Namespace_Fallback   (T : in out Test);

   --  Connection and in-place open operations
   procedure Test_Connect              (T : in out Test);
   procedure Test_Open_Procedure       (T : in out Test);
   procedure Test_Connect_Reconnect    (T : in out Test);
   procedure Test_Connect_Failure      (T : in out Test);

   --  Connect_With_Retry
   procedure Test_Connect_With_Retry_Happy_Path
     (T : in out Test);
   procedure Test_Connect_With_Retry_Succeeds_On_Second_Attempt
     (T : in out Test);
   procedure Test_Connect_With_Retry_Exhausted
     (T : in out Test);

   --  Stream-level framing (no socket required)
   procedure Test_Read_Write_Message   (T : in out Test);
   procedure Test_Read_Message_Framing (T : in out Test);

end Nine_P_Client_Tests;
