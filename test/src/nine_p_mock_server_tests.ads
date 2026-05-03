with AUnit;
with AUnit.Test_Fixtures;

package Nine_P_Mock_Server_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Read_Once_Returns_Single_Tread
     (T : in out Test);
   procedure Test_Read_Aggregates_Chunks_Until_EOF
     (T : in out Test);
   procedure Test_Write_Splits_By_IOunit
     (T : in out Test);
   procedure Test_Walk_Failure_Raises_P9_Error
     (T : in out Test);
   procedure Test_Rerror_On_Read_Raises_P9_Error
     (T : in out Test);
   procedure Test_Rversion_Failure_Raises_P9_Error
     (T : in out Test);
   procedure Test_Finalize_Sends_Tclunk
     (T : in out Test);

end Nine_P_Mock_Server_Tests;
