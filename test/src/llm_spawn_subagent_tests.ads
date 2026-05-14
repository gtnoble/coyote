with AUnit;
with AUnit.Test_Fixtures;

package LLM_Spawn_Subagent_Tests is

   type Test is new AUnit.Test_Fixtures.Test_Fixture with null record;

   --  Existing tests.
   procedure Test_Bad_Json            (T : in out Test);
   procedure Test_Empty_Prompt        (T : in out Test);
   procedure Test_Binary_Not_Found    (T : in out Test);
   procedure Test_Abort_Before_Spawn  (T : in out Test);

   --  Validation: "name" and "names" must not both be present.
   procedure Test_Name_And_Names_Conflict (T : in out Test);

   --  Validation: "names" must not be an empty array.
   procedure Test_Names_Empty_Array (T : in out Test);

   --  Validation: every element of "names" must be a non-empty string.
   procedure Test_Names_Non_String_Element (T : in out Test);

   --  Validation: empty strings inside "names" are rejected.
   procedure Test_Names_Empty_String_Element (T : in out Test);

   --  Validation: "prompt_filter" must be a string when present.
   procedure Test_Prompt_Filter_Wrong_Type (T : in out Test);

   --  Functional: prompt_filter receives COYOTE_SUBAGENT_NAME in its
   --  environment.  The filter writes the variable's value to a temp
   --  file; the test verifies the file contains the expected name.
   --  COYOTE_BIN is set to a nonexistent path so the subsequent
   --  subagent spawn fails, but the filter will already have run.
   procedure Test_Prompt_Filter_Sets_Subagent_Name (T : in out Test);

   --  Functional: using "names" with a single element produces a
   --  labelled result section even for a single agent.  Tested via
   --  the binary-not-found path so no live coyote is required; the
   --  validation of the "names" array itself is the focus here.
   procedure Test_Names_Single_Element_Accepted (T : in out Test);

end LLM_Spawn_Subagent_Tests;
