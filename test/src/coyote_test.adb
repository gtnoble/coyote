with Ada.Command_Line;
with Ada.Environment_Variables;
with AUnit.Options;
with AUnit.Run;
with AUnit.Reporter.Text;
with AUnit.Test_Filters;
with AUnit.Test_Results;
with Test_Suites;
with Test_Verbose_Result;

procedure Coyote_Test is
   --  Use Test_Runner_With_Results so we log every test as it completes
   --  (Verbose_Result prints a one-line status per test), followed by the
   --  usual summary report from the Text_Reporter.
   procedure Runner is
     new AUnit.Run.Test_Runner_With_Results (Test_Suites.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Results  : Test_Verbose_Result.Verbose_Result;
   Filter   : aliased AUnit.Test_Filters.Name_Filter;
   Options  : AUnit.Options.AUnit_Options;
begin
   Ada.Environment_Variables.Set
     ("COYOTE_TEST_FAST_RETRY",
      Ada.Environment_Variables.Value ("COYOTE_TEST_FAST_RETRY", "1"));
   Ada.Environment_Variables.Set
     ("COYOTE_TEST_NO_CATALOGUE_REFRESH",
      Ada.Environment_Variables.Value
        ("COYOTE_TEST_NO_CATALOGUE_REFRESH", "1"));

   if Ada.Command_Line.Argument_Count > 0 then
      Filter.Set_Name (Ada.Command_Line.Argument (1));
      Options.Filter := Filter'Unchecked_Access;
   end if;
   AUnit.Test_Results.Clear (AUnit.Test_Results.Result (Results));
   Runner (Reporter, Results, Options);
end Coyote_Test;
