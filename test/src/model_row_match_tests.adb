with AUnit.Assertions;
with Coyote_App.Utils;
with AUnit.Test_Caller;
with AUnit.Test_Suites;

package body Model_Row_Match_Tests is

   procedure Test_Empty_Query_Matches (T : in out Test) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Coyote_App.Utils.Model_Row_Matches
           ("openrouter", "Claude Sonnet", "openrouter/claude-sonnet", ""),
         "Empty query should match any row");
   end Test_Empty_Query_Matches;

   procedure Test_Whitespace_Query_Matches (T : in out Test) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Coyote_App.Utils.Model_Row_Matches
           ("openrouter", "Claude Sonnet", "openrouter/claude-sonnet",
            "   "),
         "Whitespace-only query should match any row");
   end Test_Whitespace_Query_Matches;

   procedure Test_Name_Substring_Casefold (T : in out Test) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Coyote_App.Utils.Model_Row_Matches
           ("openrouter", "Claude Sonnet 4", "openrouter/anthropic/claude",
            "SONNET"),
         "Case-insensitive name substring should match");
      AUnit.Assertions.Assert
        (Coyote_App.Utils.Model_Row_Matches
           ("openrouter", "Claude Sonnet 4", "openrouter/anthropic/claude",
            " sonnet "),
         "Trimmed query should still match a name substring");
   end Test_Name_Substring_Casefold;

   procedure Test_Provider_Match (T : in out Test) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Coyote_App.Utils.Model_Row_Matches
           ("github-copilot", "GPT-4o", "github-copilot/gpt-4o",
            "copilot"),
         "Provider substring should match");
   end Test_Provider_Match;

   procedure Test_Spec_Match (T : in out Test) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Coyote_App.Utils.Model_Row_Matches
           ("openrouter", "Sonnet", "openrouter/anthropic/claude-sonnet-4",
            "anthropic/claude"),
         "Spec substring should match");
   end Test_Spec_Match;

   procedure Test_No_Match (T : in out Test) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (not Coyote_App.Utils.Model_Row_Matches
           ("openrouter", "Claude Sonnet", "openrouter/claude-sonnet",
            "haiku"),
         "Unrelated query should not match");
   end Test_No_Match;

   procedure Test_Count_Unfiltered (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_App.Utils;
   begin
      AUnit.Assertions.Assert
        (Format_Model_Picker_Count (0, False) = "0 models",
         "Zero unfiltered should be '0 models'");
      AUnit.Assertions.Assert
        (Format_Model_Picker_Count (1, False) = "1 model",
         "One unfiltered should be '1 model'");
      AUnit.Assertions.Assert
        (Format_Model_Picker_Count (421, False) = "421 models",
         "Many unfiltered should be 'N models'");
   end Test_Count_Unfiltered;

   procedure Test_Count_Filtered (T : in out Test) is
      pragma Unreferenced (T);
      use Coyote_App.Utils;
   begin
      AUnit.Assertions.Assert
        (Format_Model_Picker_Count (0, True) = "0 matches",
         "Zero filtered should be '0 matches'");
      AUnit.Assertions.Assert
        (Format_Model_Picker_Count (1, True) = "1 match",
         "One filtered should be '1 match'");
      AUnit.Assertions.Assert
        (Format_Model_Picker_Count (8, True) = "8 matches",
         "Many filtered should be 'N matches'");
   end Test_Count_Filtered;


   package Model_Row_Match_Caller is
     new AUnit.Test_Caller (Model_Row_Match_Tests.Test);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;
   begin
      Result.Add_Test (Model_Row_Match_Caller.Create
        ("Model_Row_Matches: empty query matches any row",
         Model_Row_Match_Tests.Test_Empty_Query_Matches'Access));
      Result.Add_Test (Model_Row_Match_Caller.Create
        ("Model_Row_Matches: whitespace query matches any row",
         Model_Row_Match_Tests.Test_Whitespace_Query_Matches'Access));
      Result.Add_Test (Model_Row_Match_Caller.Create
        ("Model_Row_Matches: case-insensitive name substring",
         Model_Row_Match_Tests.Test_Name_Substring_Casefold'Access));
      Result.Add_Test (Model_Row_Match_Caller.Create
        ("Model_Row_Matches: provider substring",
         Model_Row_Match_Tests.Test_Provider_Match'Access));
      Result.Add_Test (Model_Row_Match_Caller.Create
        ("Model_Row_Matches: spec substring",
         Model_Row_Match_Tests.Test_Spec_Match'Access));
      Result.Add_Test (Model_Row_Match_Caller.Create
        ("Model_Row_Matches: unrelated query rejected",
         Model_Row_Match_Tests.Test_No_Match'Access));
      Result.Add_Test (Model_Row_Match_Caller.Create
        ("Format_Model_Picker_Count: unfiltered wording",
         Model_Row_Match_Tests.Test_Count_Unfiltered'Access));
      Result.Add_Test (Model_Row_Match_Caller.Create
        ("Format_Model_Picker_Count: filtered wording",
         Model_Row_Match_Tests.Test_Count_Filtered'Access));

      return Result;
   end Suite;

end Model_Row_Match_Tests;
