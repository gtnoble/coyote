--  Verbose_Result : AUnit test result that logs each test as it runs.
--
--  Overrides AUnit.Test_Results.Result to print a one-line status (OK / FAIL
--  / ERR) for every test immediately on completion, before the usual summary
--  report.  This gives the developer real-time feedback on which test is
--  currently executing.

with AUnit;
with AUnit.Test_Results;
with AUnit.Time_Measure;

package Test_Verbose_Result is

   type Verbose_Result is new AUnit.Test_Results.Result with private;

   overriding
   procedure Add_Success
     (R            : in out Verbose_Result;
      Test_Name    : AUnit.Message_String;
      Routine_Name : AUnit.Message_String;
      Elapsed      : AUnit.Time_Measure.Time);

   overriding
   procedure Add_Failure
     (R            : in out Verbose_Result;
      Test_Name    : AUnit.Message_String;
      Routine_Name : AUnit.Message_String;
      Failure      : AUnit.Test_Results.Test_Failure;
      Elapsed      : AUnit.Time_Measure.Time);

   overriding
   procedure Add_Error
     (R            : in out Verbose_Result;
      Test_Name    : AUnit.Message_String;
      Routine_Name : AUnit.Message_String;
      Error        : AUnit.Test_Results.Test_Error;
      Elapsed      : AUnit.Time_Measure.Time);

private
   type Verbose_Result is new AUnit.Test_Results.Result with null record;
end Test_Verbose_Result;
