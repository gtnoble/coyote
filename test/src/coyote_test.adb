with AUnit.Run;
with AUnit.Reporter.Text;
with Test_Suites;

procedure Coyote_Test is
   procedure Runner is new AUnit.Run.Test_Runner (Test_Suites.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Runner (Reporter);
end Coyote_Test;
