with AUnit;
with AUnit.Test_Fixtures;

package LLM_Auth_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Load_Credentials (T : in out Test);
   procedure Test_Save_Credentials (T : in out Test);
   procedure Test_Token_Expired (T : in out Test);
   procedure Test_Get_Base_Url (T : in out Test);
   procedure Test_Get_Base_Url_Fallback (T : in out Test);
   procedure Test_Refresh_Token (T : in out Test);

end LLM_Auth_Tests;
