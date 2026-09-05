with AUnit;
with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package LLM_Auth_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Load_Credentials (T : in out Test);
   procedure Test_Save_Credentials (T : in out Test);
   procedure Test_Token_Expired (T : in out Test);
   procedure Test_Get_Base_Url (T : in out Test);
   procedure Test_Get_Base_Url_Fallback (T : in out Test);
   procedure Test_Refresh_Token (T : in out Test);
   procedure Test_Refresh_Token_Non_200_Raises (T : in out Test);
   procedure Test_Refresh_Token_Invalid_JSON_Raises (T : in out Test);
   procedure Test_Refresh_Token_Missing_Token_Field_Raises
     (T : in out Test);
   procedure Test_Refresh_Token_Missing_Expires_At_Field_Raises
     (T : in out Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end LLM_Auth_Tests;
