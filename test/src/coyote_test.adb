with Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Text_IO;
with AUnit.Options;
with AUnit.Run;
with AUnit.Reporter.Text;
with AUnit.Test_Filters;
with AUnit.Test_Results;
with Test_Suites;
with Test_Verbose_Result;

procedure Coyote_Test is
   --  Use Test_Runner_With_Results so the custom result preserves each test
   --  status before the usual summary report from the Text_Reporter.
   procedure Runner is
     new AUnit.Run.Test_Runner_With_Results (Test_Suites.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Results  : Test_Verbose_Result.Verbose_Result;
   Filter   : aliased AUnit.Test_Filters.Name_Filter;
   Options  : AUnit.Options.AUnit_Options;
begin
   Options.Global_Timer := True;
   Options.Test_Case_Timer := True;
   Options.Report_Successes := False;
   Ada.Environment_Variables.Set
     ("COYOTE_TEST_FAST_RETRY",
      Ada.Environment_Variables.Value ("COYOTE_TEST_FAST_RETRY", "1"));
   Ada.Environment_Variables.Set
     ("COYOTE_TEST_NO_CATALOGUE_REFRESH",
      Ada.Environment_Variables.Value
        ("COYOTE_TEST_NO_CATALOGUE_REFRESH", "1"));

   if Ada.Command_Line.Argument_Count > 1 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "usage: coyote_test [name-prefix]");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   if Ada.Command_Line.Argument_Count = 1 then
      Filter.Set_Name (Ada.Command_Line.Argument (1));
      Options.Filter := Filter'Unchecked_Access;
   end if;

   AUnit.Test_Results.Clear (AUnit.Test_Results.Result (Results));
   Runner (Reporter, Results, Options);

   if Natural
        (AUnit.Test_Results.Test_Count
           (AUnit.Test_Results.Result (Results))) = 0
   then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "error: test filter matched no tests");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   elsif not AUnit.Test_Results.Successful
     (AUnit.Test_Results.Result (Results))
   then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Coyote_Test;
