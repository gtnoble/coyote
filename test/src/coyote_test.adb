with Ada.Command_Line;
with AUnit.Options;
with AUnit.Run;
with AUnit.Reporter.Text;
with AUnit.Test_Filters;
with Test_Suites;

procedure Coyote_Test is
   procedure Runner is new AUnit.Run.Test_Runner (Test_Suites.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Filter   : aliased AUnit.Test_Filters.Name_Filter;
   Options  : AUnit.Options.AUnit_Options;
begin
   if Ada.Command_Line.Argument_Count > 0 then
      Filter.Set_Name (Ada.Command_Line.Argument (1));
      Options.Filter := Filter'Unchecked_Access;
   end if;
   Runner (Reporter, Options);
end Coyote_Test;
