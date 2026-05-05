with AUnit;
with AUnit.Test_Fixtures;

package Coyote_Utils_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Reads_File_When_Path_Exists  (T : in out Test);
   procedure Test_Returns_Arg_When_Not_A_File  (T : in out Test);
   procedure Test_Returns_Empty_For_Empty_Path (T : in out Test);
   procedure Test_Reads_Multiline_File         (T : in out Test);

   procedure Test_Strip_Session_Prefix_With_Prefix    (T : in out Test);
   procedure Test_Strip_Session_Prefix_Without_Prefix (T : in out Test);
   procedure Test_Strip_Session_Prefix_Empty           (T : in out Test);

end Coyote_Utils_Tests;
